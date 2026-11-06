#!/usr/bin/env python3
"""Local SongBook setlist planner. Python 3, odfpy optional for ODS export."""
import csv, json, re, sys, webbrowser, threading, tempfile, os, hashlib, secrets, unicodedata, shutil, stat
from collections import Counter
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
from settings_store import SettingsStore
ROOT=Path(__file__).resolve().parent
PORT=8765
CANONICAL=['Ages','Lute','Theorbo','Fiddle','Flute','Clarinet','Horn','Harp','Drums','Bagpipe','Bassoon','Pibgorn','Cowbell']
# More specific names before generic words; preserves the LOTRO instrument type.
PATTERNS=[
 ('Ages',r'\b(?:lute\s+of\s+ages|lute\s+oa|ages)\b'),
 ('Lute',r'\b(?:lute|laute|luth)\b'),
 ('Theorbo',r'\b(?:theorbo|theorbe|theo)\b'),
 ('Fiddle',r'\b(?:fiddle|violin|viola|cello|strings?)\b'),
 ('Flute',r'\b(?:flute|woodwinds?|winds?|pipes?|whistle)\b'),
 ('Clarinet',r'\b(?:clarinet|clairnet|clar)\b'),
 ('Horn',r'\b(?:horn|trumpet|trombone|saxophone)\b'),
 ('Harp',r'\b(?:harp|keyboard|piano|keys)\b'),
 ('Drums',r'\b(?:drums?|percussion|cowbell_drums)\b'),
 ('Bagpipe',r'\b(?:bagpipes?)\b'),
 ('Bassoon',r'\b(?:bassoons?)\b'),
 ('Pibgorn',r'\b(?:pibgorn)\b'),
 ('Cowbell',r'\b(?:cowbell)\b'),
]

def read_plugindata_text(path):
    """Keep valid UTF-8, but recover occasional Windows-1252 bytes in artist names."""
    raw = path.read_bytes().decode('utf-8', errors='surrogateescape')
    return re.sub(r'[\udc80-\udcff]+',
                  lambda match: bytes(ord(ch)-0xdc00 for ch in match.group()).decode('cp1252', errors='replace'),
                  raw)

def load_aliases(path):
    aliases={}
    if path.exists():
        with path.open(encoding='utf-8-sig',newline='') as f:
            for row in csv.DictReader(f):
                k=(row.get('label') or '').strip().casefold()
                v=(row.get('instrument') or '').strip()
                if k and v:
                    aliases[re.sub(r'[^a-z0-9]','',k)]= {'Clar':'Clarinet'}.get(v,v)
    return aliases

def records_from(text, table="Songs"):
    m=re.search(r'\b'+re.escape(table)+r'\s*=\s*\{',text)
    if not m:raise ValueError(f'{table} table not found in .plugindata')
    i=m.end();records=[]
    while i<len(text):
        while i<len(text) and (text[i].isspace() or text[i]==';'):i+=1
        if i>=len(text) or text[i]=='}':break
        if text[i]!='{':i+=1;continue
        start=i;depth=0;quoted=False;escaped=False
        while i<len(text):
            c=text[i]
            if quoted:
                if escaped:escaped=False
                elif c=='\\':escaped=True
                elif c=='"':quoted=False
            else:
                if c=='"':quoted=True
                elif c=='{':depth+=1
                elif c=='}':
                    depth-=1
                    if depth==0:i+=1;break
            i+=1
        records.append(text[start:i])
    return records

def lua_field(rec,key):
    m=re.search(r'\b'+re.escape(key)+r'\s*=\s*"((?:\\.|[^"\\])*)"',rec)
    return re.sub(r'\\(["\\])',r'\1',m.group(1)) if m else ''

def candidates(name):
    # Highest-confidence: bracketed instrument labels and terminal dash suffixes.
    parts=[]
    for bracket in re.findall(r'\[([^\]]+)\]',name):parts.append(bracket)
    if ' - ' in name:parts.append(name.rsplit(' - ',1)[1])
    for match in re.findall(r'\(([^()]*)\)',name):
        if re.search(r'[a-zA-Z]',match) and not re.fullmatch(r'\s*\d+:\d+\s*',match):parts.append(match)
    parts.append(name)
    return parts

def normalize_piece(piece,aliases,allow_embedded=False):
    raw=piece.strip().replace('_',' ')
    raw=re.sub(r'\([^)]*\)',' ',raw)
    # Strip bracket wrappers, part numbering, qualifiers such as (vocals), and generic adjectives.
    raw=re.sub(r'\b(?:part|track|instrument|solo|lead|rhythm|backup|basic|bardic|lonely|mountain|misty|sprightly|brusque|traveller.s|trusty)\b',' ',raw,flags=re.I)
    raw=re.sub(r'\b\d+\b',' ',raw)
    raw=re.sub(r'[^a-zA-Z ]',' ',raw).strip().lower()
    raw=re.sub(r'\s+',' ',raw)
    if not raw:return ''
    compact=re.sub(r'[^a-z0-9]','',raw)
    if compact in aliases:return aliases[compact]
    # Match full label first, then word/phrase embedded within descriptive labels.
    for key,value in sorted(aliases.items(),key=lambda kv:-len(kv[0])):
        if len(key)>=6 and key not in ('melody','guitar','vocals','singer') and (compact.startswith(key) or compact.endswith(key)) and (len(compact)-len(key)<=12):return value
    for canonical,pattern in PATTERNS:
        if re.search(pattern,raw,re.I):return canonical
    if allow_embedded:
        # Numeric suffixes are common: e.g. fiddle3, clarinet_2.
        for canonical in CANONICAL:
            if compact.startswith(canonical.lower()) and len(compact)-len(canonical)<=8:return canonical
    return ''

def detect(name,aliases):
    opts=candidates(name)
    # Avoid interpreting whole song titles as instrument labels; only use whole name
    # when it is short and contains a strong instrument keyword.
    for piece in opts[:-1]:
        found=normalize_piece(piece,aliases,True)
        if found:return found
    full=opts[-1]
    if len(full)<36 and not re.search(r'\b(?:by|theme|song|version)\b',full,re.I):
        return normalize_piece(full,aliases,False)
    return ''


# Exact playable sounds, distinct from broad instrument families used by older aliases.
VALID_INSTRUMENTS = [
 'Basic Harp','Misty Mountain Harp','Basic Lute','Lute of Ages',
 'Basic Theorbo',"Traveller's Trusty Fiddle",
 'Basic Fiddle','Bardic Fiddle','Lonely Mountain Fiddle','Sprightly Fiddle',"Student's Fiddle",
 'Basic Flute','Basic Clarinet','Basic Horn','Basic Bassoon',
 'Lonely Mountain Bassoon','Brusque Bassoon','Basic Bagpipe','Basic Pibgorn',
 'Basic Drum','Basic Cowbell','Moor Cowbell','Jaunty Hand-Knells'
]
# Older aliases and spelling mistakes all map to one of the 23 playable sounds.
INSTRUMENT_VARIANTS = {
 'Lonely Mountain Basson':'Lonely Mountain Bassoon',
 'Basic Fiddles':'Basic Fiddle',
 'Basic Drums':'Basic Drum', 'Jaunty Hand Knells':'Jaunty Hand-Knells',
 'Travelers Trusty Fiddle':"Traveller's Trusty Fiddle",
 'Traveller Trusty Fiddle':"Traveller's Trusty Fiddle",
 'Lute':'Basic Lute', 'Ages':'Lute of Ages', 'Theorbo':'Basic Theorbo',
 'Fiddle':'Basic Fiddle', 'Flute':'Basic Flute', 'Clarinet':'Basic Clarinet',
 'Horn':'Basic Horn', 'Harp':'Basic Harp', 'Drums':'Basic Drum',
 'Drum':'Basic Drum', 'Bagpipe':'Basic Bagpipe', 'Bassoon':'Basic Bassoon',
 'Pibgorn':'Basic Pibgorn', 'Cowbell':'Basic Cowbell',
}
# The aliases CSV contains older broad-family labels. Convert them to exact sounds.
CANONICALIZE_FAMILY = {
 'Ages':'Lute of Ages', 'Lute':'Basic Lute', 'Theorbo':'Basic Theorbo',
 'Fiddle':'Basic Fiddle', 'Flute':'Basic Flute', 'Clarinet':'Basic Clarinet',
 'Horn':'Basic Horn', 'Harp':'Basic Harp', 'Drums':'Basic Drum',
 'Bagpipe':'Basic Bagpipe', 'Bassoon':'Basic Bassoon',
 'Pibgorn':'Basic Pibgorn', 'Cowbell':'Basic Cowbell'
}
def playable_instrument(name):
    if not name:
        return ''
    if name in VALID_INSTRUMENTS:
        return name
    return INSTRUMENT_VARIANTS.get(name, CANONICALIZE_FAMILY.get(name, ''))

def compact_name(value):
 return re.sub(r'[^a-z0-9]','',value.casefold())
EXACT_LOOKUP = {compact_name(k):k for k in VALID_INSTRUMENTS}
EXACT_LOOKUP.update({compact_name(k):v for k,v in INSTRUMENT_VARIANTS.items()})
def exact_instrument(name):
 # Favor bracket and final-dash annotations, then whole track text.
 pieces = candidates(name)
 for piece in pieces:
  cleaned=re.sub(r'\b(?:part|track)\s*\d+\b',' ',piece,flags=re.I)
  cleaned=re.sub(r'\b\d+\b',' ',cleaned)
  c=compact_name(cleaned)
  if c in EXACT_LOOKUP:return EXACT_LOOKUP[c]
  for alias,label in sorted(EXACT_LOOKUP.items(),key=lambda x:-len(x[0])):
   if alias in c and len(alias)>7:
    return label
 return ''

def part_name_instrument(part_name, aliases):
    """Prefer explicit SongBook PartName; numbered parts share the same instrument."""
    if not part_name or part_name.strip().casefold() == 'unknown instrument':
        return ''
    for option in part_name.split(','):
        option = option.strip()
        if not option:
            continue
        inst = exact_instrument(option)
        if inst:
            return playable_instrument(inst)
        inst = detect(option, aliases)
        if inst:
            return playable_instrument(inst)
    return ''


def parse_directories(path):
    """Also include directories declared by SongBook but not containing songs."""
    text = read_plugindata_text(path)
    m = re.search(r'\bDirectories\s*=\s*\{', text)
    if not m:
        return []
    entries = re.findall(r'"((?:\\.|[^"\\])*)"', text[m.end():])
    return sorted(set(re.sub(r'\\(["\\])', r'\1', x).replace('\\', '/').strip('/')
                      for x in entries if x.strip('/')))


def parse_library(path, aliases):
    source = read_plugindata_text(path)
    songs=[]
    for record in records_from(source):
        # Artist can appear on the song itself and/or on individual tracks.
        # The metadata prefix avoids treating the first track's Artist as a song field.
        metadata = re.split(r'\bTracks\s*=\s*\{', record, maxsplit=1)[0]
        song_artist = lua_field(metadata, 'Artist').strip()
        track_records = records_from(record, 'Tracks')
        tracks=[]
        for entry in track_records:
            tid = lua_field(entry,'Id')
            name = lua_field(entry,'Name')
            part_name = lua_field(entry,'PartName')
            artist = lua_field(entry,'Artist').strip()
            if not tid and not name:
                continue
            inst = part_name_instrument(part_name, aliases)
            if not inst:
                inst = exact_instrument(name) or detect(name,aliases)
            inst = playable_instrument(inst)
            tracks.append({'id':tid,'name':name,'partName':part_name,
                           'artist':artist,'instrument':inst})
        if not tracks:
            continue
        title = tracks[0]['name']
        title = re.sub(r'\s*\[[^\]]+\]\s*(?:\(\d+:\d+\))?\s*$','',title)
        if ' - ' in title and tracks[0]['instrument'] and detect(title.rsplit(' - ',1)[1],aliases):
            title=title.rsplit(' - ',1)[0]
        title=title.replace('_',' ').strip() or lua_field(metadata,'Filename')
        artists=list(dict.fromkeys(x for x in [song_artist]+[t['artist'] for t in tracks] if x))
        counts=Counter(t['instrument'] for t in tracks if t['instrument'])
        filepath=lua_field(metadata,'Filepath').replace('\\','/')
        songs.append({'id':len(songs),'title':title,'artist':song_artist or (artists[0] if artists else ''),
                      'artists':artists,'filename':lua_field(metadata,'Filename'),
                      'filepath':filepath,'directory':filepath,
                      'tracks':tracks,'counts':dict(counts)})
    return songs

def export_spreadsheet(songs, indices, overrides, titles, assignments, played_as, members, kind='setlist'):
    """Make the same per-player transition definitions used by the browser visible in ODS."""
    from odf.opendocument import OpenDocumentSpreadsheet
    from odf.table import Table, TableRow, TableCell, TableColumn
    from odf.text import P
    from odf.style import Style, TableCellProperties, TableColumnProperties, TextProperties, ParagraphProperties

    # HTML and ODS both count a switch only when the SAME member changes
    # performed instrument across adjacent songs. Entrants/exits are separate.
    member_names={str(m.get('id')):m.get('name') or 'Player '+str(m.get('id'))
                  for m in members if isinstance(m,dict) and m.get('id') is not None}
    def required(idx,j,track):
        return overrides.get(f'{idx}:{j}',track.get('instrument','')) or ''
    def performed(idx,j,track):
        req=required(idx,j,track)
        sound=played_as.get(f'{idx}:{j}',req)
        accepted={req}
        accepted.update({
            'Lonely Mountain Bassoon':['Basic Bassoon'],
            'Lonely Mountain Fiddle':['Basic Fiddle'],
            'Moor Cowbell':['Basic Cowbell'],
            'Lute of Ages':['Basic Lute'], 'Basic Lute':['Lute of Ages'],
            'Misty Mountain Harp':['Basic Harp'], 'Basic Harp':['Misty Mountain Harp'],
            'Basic Fiddle':['Lonely Mountain Fiddle'],
            'Basic Bassoon':['Lonely Mountain Bassoon'],
        }.get(req,[]))
        return sound if sound in accepted else req
    def member_map(idx):
        result={}
        song=songs[idx]
        for j,t in enumerate(song['tracks']):
            raw=assignments.get(f'{idx}:{j}')
            if raw is None or raw == '':continue
            try:player=str(int(raw))
            except (TypeError,ValueError):continue
            inst=performed(idx,j,t)
            if player!='0' and inst:result[player]=inst
        return result
    def required_counts(idx):
        c=Counter()
        for j,t in enumerate(songs[idx]['tracks']):
            inst=required(idx,j,t)
            if inst:c[inst]+=1
        return c
    def metrics(a,b):
        previous=member_map(a);current=member_map(b)
        switches=[(id,previous[id],current[id]) for id in member_names
                  if id in previous and id in current and previous[id]!=current[id]]
        joins=[id for id in current if id not in previous]
        leaves=[id for id in previous if id not in current]
        ac,bc=required_counts(a),required_counts(b)
        added=sum(max(0,bc[k]-ac[k]) for k in set(ac)|set(bc))
        removed=sum(max(0,ac[k]-bc[k]) for k in set(ac)|set(bc))
        return {'switches':switches,'joined':joins,'left':leaves,'replacements':max(added,removed),
                'before':previous,'after':current}

    doc=OpenDocumentSpreadsheet()
    # Two shades per data status create visible row banding without obscuring
    # timeline colors for musician switches, unchanged parts, joins and leaves.
    colors={
       'header':('#253a54','#ffffff',True),
       'normal':('#ffffff','#293548',False),
       'alternate':('#edf3f9','#293548',False),
       'switch':('#fff0bf','#7a4900',True),
       'switch_band':('#ffe0a0','#704000',True),
       'same':('#e9f6ec','#25603f',False),
       'same_band':('#d9efdf','#25603f',False),
       'join':('#e7f0ff','#204a85',False),
       'join_band':('#d8e7fc','#204a85',False),
       'leave':('#edf0f4','#5a6472',False),
       'leave_band':('#dce4ee','#505d6c',False),
       'start':('#eaf3fb','#274b69',False),
       'start_band':('#dcebf9','#274b69',False),
       'warn':('#fff1e7','#964b24',False),
       'warn_band':('#ffe5d2','#964b24',False),
    }
    styles={}
    for name,(bg,fg,bold) in colors.items():
        st=Style(name='sb10_'+name,family='table-cell')
        st.addElement(TableCellProperties(backgroundcolor=bg,padding='0.13cm',wrapoption='wrap'))
        st.addElement(TextProperties(color=fg,fontweight='bold' if bold else 'normal',fontsize='10pt'))
        doc.automaticstyles.addElement(st);styles[name]=st
    widthStyles={}
    for width in ('1.6','2.0','2.7','3.4','4.2','5.5','6.5','8.0','9.0'):
        st=Style(name='sb10_col_'+width.replace('.','_'),family='table-column')
        st.addElement(TableColumnProperties(columnwidth=width+'cm'))
        doc.automaticstyles.addElement(st);widthStyles[width]=st

    def add_table(name,headers,widths):
        table=Table(name=name);doc.spreadsheet.addElement(table)
        for i in range(len(headers)):
            table.addElement(TableColumn(stylename=widthStyles[widths[i] if i<len(widths) else '3.4']))
        row=TableRow()
        for h in headers:
            cell=TableCell(stylename=styles['header'],valuetype='string')
            cell.addElement(P(text=str(h)));row.addElement(cell)
        table.addElement(row)
        return table
    def add_row(table,values,kinds=None,rownum=0):
        tr=TableRow()
        for i,value in enumerate(values):
            # Respect explicit status colors, but use their darker alternate
            # on every second row. Unmarked cells follow the same zebra pattern.
            base=(kinds[i] if kinds and i<len(kinds) and kinds[i] else 'normal')
            style=(('alternate' if base == 'normal' else base+'_band')
                   if rownum % 2 == 0 else base)
            if style not in styles:style=base
            if isinstance(value,(int,float)) and not isinstance(value,bool):
                cell=TableCell(stylename=styles[style],valuetype='float',value=value)
            else:
                cell=TableCell(stylename=styles[style],valuetype='string')
            cell.addElement(P(text=str(value) if value is not None else ''))
            tr.addElement(cell)
        table.addElement(tr)

    # ODS worksheets display in their creation order. The musician-facing
    # timeline comes first for setlists; library export remains a single sheet.
    is_setlist=kind!='library'
    member_ids=[str(m['id']) for m in members if isinstance(m,dict) and m.get('id') is not None]
    player_table=add_table('Player timeline',['#','Song']+[member_names.get(i,'Player '+i) for i in member_ids],
                    ['1.6','6.5']+['6.5']*len(member_ids)) if is_setlist else None
    main_headers=['#','Song','Artist(s)','Player instrument changes','Who changes (from → to)',
      'Instrument replacements','Players joined','Players left','Filename','Folder',
      'Instrument parts','Original tracks','Track metadata','Player assignments','Performed instruments','Part count']
    main=add_table('Setlist',main_headers,
      ['1.6','6.5','5.5','2.7','9.0','2.7','2.0','2.0','5.5','5.5','8.0','9.0','9.0','8.0','8.0','2.0'])
    log_table=add_table('Change log',['To #','Previous song','Next song','Player','Event',
                        'From instrument','To instrument'],
                        ['1.6','6.5','6.5','3.4','2.7','5.5','5.5']) if is_setlist else None
    log_row_count=0
    for n,idx in enumerate(indices,1):
        if not isinstance(idx,int) or not 0<=idx<len(songs):continue
        song=songs[idx];counts=required_counts(idx)
        t=metrics(indices[n-2],idx) if n>1 and is_setlist else {'switches':[],'joined':[],'left':[],'replacements':0,'before':{},'after':member_map(idx)}
        changes=t['switches'];who=', '.join(f'{member_names.get(i,"Player "+i)}: {a} → {b}' for i,a,b in changes)
        mainvalues=[n,titles.get(str(idx),song['title']),', '.join(song.get('artists',[])),len(changes) if n>1 and is_setlist else '',
            who,t['replacements'] if n>1 and is_setlist else '',len(t['joined']) if n>1 and is_setlist else '',
            len(t['left']) if n>1 and is_setlist else '',song['filename'],song['filepath'],
            ', '.join(f'{k} ×{v}' for k,v in sorted(counts.items())),
            ' | '.join(tr['name'] for tr in song['tracks']),
            ' | '.join((tr['partName'] or 'Unknown part')+((' — '+tr['artist']) if tr['artist'] else '') for tr in song['tracks']),
            ' | '.join(str(j+1)+': '+member_names.get(str(assignments.get(str(idx)+':'+str(j))),'Unassigned') for j in range(len(song['tracks']))),
            ' | '.join(f'{j+1}: '+str(performed(idx,j,tr)) for j,tr in enumerate(song['tracks'])),
            len(song['tracks'])]
        main_styles=['normal']*len(mainvalues)
        if changes:main_styles[3]=main_styles[4]='switch'
        add_row(main,mainvalues,main_styles,n)
        if not is_setlist:continue
        # Timeline cells are colored by change type and retain instrument names.
        before,after=t['before'],t['after']
        timeline=[n,titles.get(str(idx),song['title'])]
        timelinestyles=['normal','normal']
        for pid in member_ids:
            if n==1:
                value='▶ '+after[pid] if pid in after else '—';style='start' if pid in after else 'normal'
            elif pid in before and pid in after:
                if before[pid]!=after[pid]:value='↻ '+before[pid]+' → '+after[pid];style='switch'
                else:value='✓ '+after[pid];style='same'
            elif pid in after:value='+ '+after[pid];style='join'
            elif pid in before:value='− '+before[pid];style='leave'
            else:value='—';style='normal'
            timeline.append(value);timelinestyles.append(style)
        add_row(player_table,timeline,timelinestyles,n)
        if n>1:
            for pid,a,b in changes:
                log_row_count+=1
                add_row(log_table,[n,titles.get(str(indices[n-2]),songs[indices[n-2]]['title']),
                     titles.get(str(idx),song['title']),member_names.get(pid,'Player '+pid),'↻ SWITCH',a,b],
                     ['normal']*4+['switch']*3,log_row_count)
            for pid in t['joined']:
                log_row_count+=1
                add_row(log_table,[n,titles.get(str(indices[n-2]),songs[indices[n-2]]['title']),
                     titles.get(str(idx),song['title']),member_names.get(pid,'Player '+pid),'+ JOIN','',after[pid]],
                     ['normal']*4+['join']*3,log_row_count)
            for pid in t['left']:
                log_row_count+=1
                add_row(log_table,[n,titles.get(str(indices[n-2]),songs[indices[n-2]]['title']),
                     titles.get(str(idx),song['title']),member_names.get(pid,'Player '+pid),'− LEAVE',before[pid],''],
                     ['normal']*4+['leave']*3,log_row_count)
    if is_setlist:
        legend=add_table('Legend',['Indicator','Meaning'],['3.4','9.0'])
        for n,(mark,meaning,style) in enumerate([
          ('↻','Instrument switch: the SAME musician plays a different instrument than in the previous song.','switch'),
          ('✓','No instrument switch: same musician continues on the same performed instrument.','same'),
          ('+','Player joins this song (no switch counted because they did not play in the previous song).','join'),
          ('−','Player leaves the active lineup (not an instrument switch).','leave'),
          ('▶','Starting lineup in the first song; no transition is counted.','start'),
          ('Replacement','Counted from differences in the REQUIRED instrument-part inventory, independent of player identity. One removal plus one addition counts as one replacement.','normal'),
          ('Substitutions','Performed instruments can differ from the required instrument; player switches use PERFORMED instruments.','normal'),
          ('Unassigned','Unassigned parts are shown in Setlist assignments and do not appear as an instrument played by a member.','warn'),
        ],1):add_row(legend,[mark,meaning],[style,'normal'],n)
    fd,path=tempfile.mkstemp(suffix='.ods');os.close(fd)
    try:doc.save(path);return Path(path).read_bytes()
    finally:os.unlink(path)

def safe_setlist_filename(name):
    """Create a readable local download filename, never a path or HTTP header payload."""
    if not isinstance(name, str) or not name.strip():
        return 'songbook-setlist.ods'
    if len(name) > 100:
        raise ValueError('Setlist name too long (maximum 100 characters).')
    cleaned = unicodedata.normalize('NFKD', name)
    cleaned = ''.join(c for c in cleaned if not unicodedata.combining(c))
    slug = re.sub(r'[^A-Za-z0-9 _-]', '', cleaned)
    slug = re.sub(r'[ _-]+', '-', slug.strip())[:80] or 'Untitled'
    return f'setlist-{slug}.ods'



# Append to the native SongBook3Setlists.plugindata format. The existing file is
# *not* re-serialized: inserting new fields immediately after the opening braces
# preserves every old list, the names order, the active list and unrelated data.
# Lua strings and field syntax are escaped, and a backup precedes the atomic write.
def lua_quote(value):
    if not isinstance(value,str):
        raise ValueError('SongBook playlist names and paths must be text.')
    if '\x00' in value or '\n' in value or '\r' in value:
        raise ValueError('Playlist names/paths cannot contain NUL or newlines.')
    return '"' + (value.replace('\\','\\\\').replace('"','\\"')
                  .replace('\t','\\t')) + '"'


def _scan_table_closing(text, left):
    """Find matching } for a Lua table, respecting quoted strings and comments."""
    if left>=len(text) or text[left]!='{':
        raise ValueError('Malformed Lua table')
    depth=0; i=left
    while i<len(text):
        c=text[i]
        if c=='-' and text[i:i+2]=='--':
            if text[i+2:i+4]=='[[':
                end=text.find(']]',i+4)
                if end<0:raise ValueError('Unclosed Lua block comment')
                i=end+2;continue
            end=text.find('\n',i+2)
            if end<0:break
            i=end+1;continue
        if c=='"' or c=="'":
            delim=c;i+=1
            while i<len(text):
                if text[i]=='\\':i+=2;continue
                if text[i]==delim:break
                i+=1
            if i>=len(text):raise ValueError('Unclosed Lua string')
        elif c=='{':depth+=1
        elif c=='}':
            depth-=1
            if depth==0:return i
        i+=1
    raise ValueError('Unclosed SongBook Lua table')


def _songbook_top_tables(text):
    """Find lists and names tables from a simple SongBook exported Lua file."""
    # Look only within the outermost returned table so a nested field cannot
    # accidentally be substituted. Use a lexical check for the matching braces.
    m=re.search(r'\breturn\s*\{',text)
    if not m:raise ValueError('Expected a Lua return { ... } structure')
    outer_start=text.index('{',m.start())
    outer_end=_scan_table_closing(text,outer_start)
    tables={}
    # Table keys may be quoted with either quote character, or bare identifiers.
    key_pattern=re.compile(r"""(?:\[\s*([\"'])(lists|names)\1\s*\]|\b(lists|names)\b)\s*=\s*\{""")
    for match in key_pattern.finditer(text,outer_start+1,outer_end):
        key=match.group(2) or match.group(3)
        start=match.end()-1
        end=_scan_table_closing(text,start)
        if end>outer_end:continue
        if key in tables:raise ValueError(f'Duplicate top-level table {key}')
        tables[key]=(start,end)
    if not {'lists','names'}<=tables.keys():
        raise ValueError('Missing SongBook lists or names table')
    return tables


def _unescape_lua_string(s):
    # Sufficient for serialized Lua quote/backslash escapes, for names/paths.
    return re.sub(r'\\([\\"\'nt])',lambda m:{'n':'\n','t':'\t'}.get(m.group(1),m.group(1)),s)


def make_appended_songbook_text(old_text,playlist_name,paths):
    """Return extended native Lua data, without changing any existing entries."""
    if not isinstance(playlist_name,str):
        raise ValueError('Playlist name must be text.')
    playlist_name=playlist_name.strip()
    if not playlist_name or len(playlist_name)>100:
        raise ValueError('Enter a playlist name of 1–100 characters.')
    if not paths or not isinstance(paths,list):
        raise ValueError('Choose at least one song before appending a playlist.')
    if len(paths)>10000:
        raise ValueError('Playlist is too large.')
    tables=_songbook_top_tables(old_text)
    list_start,list_end=tables['lists']
    names_start,names_end=tables['names']
    list_body=old_text[list_start+1:list_end]
    names_body=old_text[names_start+1:names_end]
    # A playlist name is unique even if the case differs; it must never overwrite
    # or shadow an existing list already in SongBook.
    existing_names=re.findall(r"""\[\s*\"((?:\\.|[^\"\\])*)\"\s*\]\s*=\s*\{""",list_body)
    existing_names += re.findall(r"""\[\s*\"((?:\\.|[^\"\\])*)\"\s*\]\s*=\s*\"""",names_body)
    if any(_unescape_lua_string(n).casefold()==playlist_name.casefold() for n in existing_names):
        raise FileExistsError(f'A SongBook playlist named "{playlist_name}" already exists. Choose another name.')
    indices=[int(float(s)) for s in re.findall(r'\[\s*(\d+(?:\.\d+)?)\s*\]\s*=',names_body)]
    next_index=max(indices,default=0)+1
    newline='\r\n' if '\r\n' in old_text else '\n'
    # An inserted entry ends in a comma, so the existing first field requires no
    # changes and current ordering/formatting is retained byte-for-byte.
    items=''.join(f'\t\t\t[{i}.000000] = {lua_quote(path)},'+newline for i,path in enumerate(paths,1))
    new_list=(''+newline+'\t\t['+lua_quote(playlist_name)+'] ='+newline+
              '\t\t{'+newline+items+'\t\t},'+newline)
    new_name=(newline+f'\t\t[{next_index}.000000] = {lua_quote(playlist_name)},'+newline)
    # Insert at the two locations from right to left to avoid index shifts.
    for offset,payload in sorted(((list_start+1,new_list),(names_start+1,new_name)),reverse=True):
        old_text=old_text[:offset]+payload+old_text[offset:]
    return old_text,next_index


def append_songbook_playlist(target,playlist_name,paths):
    """Append to file with backup + atomic replacement; return metadata."""
    path=Path(target).expanduser()
    if path.is_symlink():
        raise ValueError('Setlists file may not be a symlink.')
    path=path.resolve()
    if not path.is_file():
        raise FileNotFoundError('SongBook setlists file does not exist: '+str(path))
    old_bytes=path.read_bytes()
    old_text=old_bytes.decode('utf-8',errors='surrogateescape')
    updated,number=make_appended_songbook_text(old_text,playlist_name,paths)
    new_bytes=updated.encode('utf-8',errors='surrogateescape')
    # A timestamped .bak is kept alongside the plugin file. Never risk changing
    # the active file until the new content is fully written and synced.
    from datetime import datetime,timezone
    stamp=datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
    backup=path.with_name(path.name+'.'+stamp+'.bak')
    shutil.copy2(path,backup)
    fd,tmp=tempfile.mkstemp(prefix='.'+path.name+'.',suffix='.tmp',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as f:
            f.write(new_bytes);f.flush();os.fsync(f.fileno())
        os.chmod(tmp,stat.S_IMODE(path.stat().st_mode))
        os.replace(tmp,path)
    finally:
        if os.path.exists(tmp):os.unlink(tmp)
    return {'name':playlist_name,'number':number,'songs':len(paths),'path':str(path),'backup':str(backup)}

class Handler(BaseHTTPRequestHandler):
    songs=[]
    directories=[]
    library_fingerprint=""
    settings=None
    shutdown_token=secrets.token_urlsafe(32)
    setlists_path=ROOT/"SongBook3Setlists.plugindata"
    setlists_lock=threading.Lock()

    def is_local_request(self):
        # Host/origin validation prevents DNS rebinding and cross-site actions.
        # A separate unguessable token is required for the shutdown operation.
        host=self.headers.get('Host','')
        origin=self.headers.get('Origin','')
        return (host in (f'127.0.0.1:{PORT}', f'localhost:{PORT}')
                and (not origin or origin in (f'http://127.0.0.1:{PORT}',
                                             f'http://localhost:{PORT}')))

    def send(self,data,ctype='text/html; charset=utf-8',code=200,filename=None):
        if isinstance(data,str):data=data.encode('utf-8')
        self.send_response(code);self.send_header('Content-Type',ctype);self.send_header('Content-Length',str(len(data)));self.send_header('Cache-Control','no-store')
        if filename:self.send_header('Content-Disposition',f'attachment; filename="{filename}"')
        self.end_headers();self.wfile.write(data)
    def do_GET(self):
        path = urlparse(self.path).path
        if path == '/':
            try:
                stored_settings = self.settings.read()
                page = ((ROOT/'app.html').read_text(encoding='utf-8')
                    .replace('__DATA__',json.dumps(self.songs,ensure_ascii=False).replace('</','<\\/'))
                    .replace('__DIRECTORIES__',json.dumps(self.directories,ensure_ascii=False).replace('</','<\\/'))
                    .replace('__FINGERPRINT__',self.library_fingerprint)
                    .replace('__DISK_SETTINGS__',json.dumps(stored_settings,ensure_ascii=False).replace('</','<\\/'))
                    .replace('__SHUTDOWN_TOKEN__',self.shutdown_token)
                    .replace('__SETLISTS_TARGET__',json.dumps(str(self.setlists_path),ensure_ascii=False).replace('</','<\\/')))
                self.send(page)
            except (OSError, ValueError) as exc:
                self.send('Could not load settings: '+str(exc),'text/plain; charset=utf-8',500)
        elif path == '/settings':
            try:
                self.send(json.dumps(self.settings.read(),ensure_ascii=False), 'application/json; charset=utf-8')
            except ValueError as exc:
                self.send(str(exc),'text/plain; charset=utf-8',500)
        else:self.send('Not found','text/plain',404)
    def do_POST(self):
        path = urlparse(self.path).path
        if path == '/shutdown':
            if not self.is_local_request():
                self.send('Incorrect origin','text/plain',403)
                return
            supplied=self.headers.get('X-SongBook-Shutdown','')
            if not self.shutdown_token or not secrets.compare_digest(supplied,self.shutdown_token):
                self.send('Shutdown authorization required','text/plain',403)
                return
            # Respond to the browser before ending serve_forever. Shutdown must
            # run on another thread; calling it in the request handler can hang.
            self.send(json.dumps({'stopped':True}), 'application/json; charset=utf-8')
            self.wfile.flush()
            threading.Thread(target=self.server.shutdown, daemon=True).start()
            return
        if path == '/append-songbook-setlist':
            if not self.is_local_request() or not secrets.compare_digest(
                    self.headers.get('X-SongBook-Shutdown',''),self.shutdown_token):
                self.send('Write authorization required','text/plain; charset=utf-8',403);return
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0<length<=250000:raise ValueError('Invalid request size')
                payload=json.loads(self.rfile.read(length))
                name=payload.get('name','')
                indices=payload.get('indices',[])
                if not isinstance(indices,list) or not 0<len(indices)<=10000 or not all(
                        type(n) is int and 0<=n<len(self.songs) for n in indices):
                    raise ValueError('Invalid song IDs')
                paths=[]
                for idx in indices:
                    song=self.songs[idx]
                    folder=song['filepath'].replace('\\','/').rstrip('/')
                    filename=song['filename']
                    if not (folder.lower()=='/songs' or folder.lower().startswith('/songs/')) or not filename or '/' in filename or '\\' in filename:
                        raise ValueError('Song cannot be exported to SongBook: '+str(song['title']))
                    paths.append((folder+'/'+filename).casefold())
                with self.setlists_lock:
                    outcome=append_songbook_playlist(self.setlists_path,name,paths)
                self.send(json.dumps(outcome,ensure_ascii=False),'application/json; charset=utf-8')
            except FileExistsError as exc:
                self.send(str(exc),'text/plain; charset=utf-8',409)
            except (ValueError,OSError,TypeError) as exc:
                self.send(str(exc),'text/plain; charset=utf-8',400)
            return
        if path == '/settings':
            # Restrict writes to pages served by this local app (including beacon
            # requests on page close). Cross-origin websites must not modify disk.
            if not self.is_local_request():
                self.send('Incorrect origin','text/plain',403);return
            try:
                size=int(self.headers.get('Content-Length','0'))
                if not 0<size<=12*1024*1024:raise ValueError('Settings payload too large or empty.')
                data=json.loads(self.rfile.read(size))
                changed=self.settings.write(data,self.library_fingerprint)
                self.send(json.dumps({'saved':changed, 'revision':data['revision']}), 'application/json; charset=utf-8')
            except (ValueError, OSError, KeyError) as exc:
                code=409 if 'Library changed' in str(exc) else 400
                self.send(str(exc),'text/plain; charset=utf-8',code)
            return
        if path!='/export':self.send('Not found','text/plain',404);return
        try:
            data=json.loads(self.rfile.read(min(int(self.headers.get('Content-Length','0')),1000000)))
            indices=data.get('indices',[]); overrides=data.get('overrides',{});titles=data.get('titles',{});assignments=data.get('assignments',{});played_as=data.get('playedAs',{});members=data.get('members',[])
            if not isinstance(indices,list) or len(indices)>10000:raise ValueError('Invalid setlist')
            kind=data.get('kind','setlist')
            if kind not in ('setlist','library'):raise ValueError('Invalid export kind')
            filename='songbook-library.ods' if kind=='library' else safe_setlist_filename(data.get('setlistName',''))
            blob=export_spreadsheet(self.songs,indices,overrides,titles,assignments,played_as,members,kind)
            self.send(blob,'application/vnd.oasis.opendocument.spreadsheet',filename=filename)
        except Exception as exc:self.send(str(exc),'text/plain; charset=utf-8',400)
    def log_message(self,*args):pass

def main():
    args=sys.argv[1:]
    setlists_path=ROOT/'SongBook3Setlists.plugindata'
    if '--setlists' in args:
        pos=args.index('--setlists')
        if pos+1>=len(args):raise SystemExit('Usage: --setlists /path/to/SongBook3Setlists.plugindata')
        setlists_path=Path(args[pos+1]).expanduser().resolve()
        args=args[:pos]+args[pos+2:]
    if len(args)>1:raise SystemExit('Usage: songbook_planner.py [SongBook3Data.plugindata] [--setlists FILE]')
    data=Path(args[0]).expanduser().resolve() if args else ROOT/'SongBook3Data.plugindata'
    if not data.is_file():raise SystemExit(f'File not found: {data}')
    aliases=load_aliases(ROOT/'instrument-aliases.csv')
    Handler.songs=parse_library(data,aliases)
    Handler.directories=parse_directories(data)
    Handler.library_fingerprint=hashlib.sha256(data.read_bytes()).hexdigest()
    Handler.settings=SettingsStore(ROOT/'settings')
    Handler.setlists_path=setlists_path
    Handler.shutdown_token=secrets.token_urlsafe(32)
    Handler.settings.read()  # Fail visibly if a settings file cannot be read
    print(f'Loaded {len(Handler.songs)} songs, {sum(len(s["tracks"]) for s in Handler.songs)} tracks, {len(aliases)} aliases.')
    print(f'Settings folder: {Handler.settings.root}')
    print(f'SongBook setlists file: {Handler.setlists_path}')
    print(f'Open http://127.0.0.1:{PORT} — use Shut down in the app to stop')
    server=ThreadingHTTPServer(('127.0.0.1',PORT),Handler)
    threading.Timer(0.5,lambda:webbrowser.open(f'http://127.0.0.1:{PORT}')).start()
    try:server.serve_forever()
    except KeyboardInterrupt:pass
    finally:server.server_close()
if __name__=='__main__':main()
