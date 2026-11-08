// SongBook3 Fast Library Builder -- portable standard-library-only native builder.
// Build on Windows or cross-compile: GOOS=windows GOARCH=amd64 go build -o SongBook3_Fast_Builder.exe SongBook3_Fast_Builder.go
// Source is included with the release for transparency and reproducibility.
package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
	"unicode/utf8"
)

type Config struct {
	Music      string `json:"Music"`
	PluginData string `json:"PluginData"`
	Account    string `json:"Account"`
}
type Track struct {
	Id, Name, PartName, Artist      string
	HasName, HasPartName, HasArtist bool
}
type Song struct {
	Filepath, Filename, Artist string
	Tracks                     []Track
}
type Lyrics struct {
	Filepath, Filename string
	Lines              []string
}

var rxX = regexp.MustCompile(`(?i)^X:\s*([0-9]+)`)
var rxT = regexp.MustCompile(`(?i)^T: *(.+)`)
var rxC = regexp.MustCompile(`(?i)^C:[ \t]*(.*)`)
var rxPart = regexp.MustCompile(`(?i)^%%part-name[ \t]+(.+)`)

// BuildStatus is passed to the Windows GUI. Progress is 0..100 and Log marks
// significant stages that should be added to the scrollable activity log.
type BuildStatus struct {
	Percent int
	Message string
	Log     bool
}

type BuildReporter func(BuildStatus)

func buildLibrary(cfg Config, outDir string, report BuildReporter) error {
	start := time.Now()
	send := func(pct int, message string, addLog bool) {
		if report != nil {
			report(BuildStatus{Percent: pct, Message: message, Log: addLog})
		}
	}
	cfg.Music = strings.TrimSpace(strings.Trim(cfg.Music, `"`))
	cfg.PluginData = strings.TrimSpace(strings.Trim(cfg.PluginData, `"`))
	cfg.Account = strings.TrimSpace(cfg.Account)
	if cfg.Music == "" {
		return errors.New("select a LOTRO Music directory")
	}
	if cfg.PluginData == "" {
		return errors.New("select a LOTRO PluginData directory")
	}
	if strings.EqualFold(filepath.Base(filepath.Clean(cfg.Music)), ".git") {
		return errors.New("the Music folder cannot be a .git directory")
	}
	st, err := os.Stat(cfg.Music)
	if err != nil || !st.IsDir() {
		return fmt.Errorf("Music folder not found: %s", cfg.Music)
	}
	if err := os.MkdirAll(cfg.PluginData, 0755); err != nil {
		return fmt.Errorf("PluginData folder unavailable: %w", err)
	}
	if st, err = os.Stat(outDir); err != nil || !st.IsDir() {
		return fmt.Errorf("Builder output folder not found: %s", outDir)
	}
	send(1, "Finding ABC files...", true)
	abcPaths, err := discover(cfg.Music, ".abc")
	if err != nil {
		return fmt.Errorf("Scanning Music: %w", err)
	}
	send(4, fmt.Sprintf("Found %d ABC files. Reading metadata...", len(abcPaths)), true)
	songs := make([]Song, 0, len(abcPaths))
	songDirs := map[string]bool{"/": true}
	for i, p := range abcPaths {
		tracks, artist, err := parseABC(p)
		if err != nil {
			return fmt.Errorf("%s: %w (no indexes replaced)", p, err)
		}
		folder, err := relativeFolder(cfg.Music, p)
		if err != nil {
			return err
		}
		addDirs(songDirs, folder)
		name := strings.TrimSuffix(filepath.Base(p), filepath.Ext(p))
		songs = append(songs, Song{Filepath: folder, Filename: name, Artist: artist, Tracks: tracks})
		if (i+1)%100 == 0 || i+1 == len(abcPaths) {
			send(4+int(66*float64(i+1)/float64(len(abcPaths))), fmt.Sprintf("Reading song metadata: %d / %d", i+1, len(abcPaths)), (i+1)%1000 == 0)
		}
	}
	send(70, "Finding lyrics...", true)
	lyricsRoot := filepath.Join(cfg.Music, "lyrics")
	lyricPaths := []string{}
	if st, err := os.Stat(lyricsRoot); err == nil && st.IsDir() {
		lyricPaths, err = discover(lyricsRoot, ".txt")
		if err != nil {
			return fmt.Errorf("Scanning lyrics: %w", err)
		}
	}
	send(73, fmt.Sprintf("Found %d lyric files. Reading lyrics...", len(lyricPaths)), true)
	lyrics := make([]Lyrics, 0, len(lyricPaths))
	lyricDirs := map[string]bool{"/": true}
	for i, p := range lyricPaths {
		data, err := os.ReadFile(p)
		if err != nil {
			return fmt.Errorf("Reading lyric %s: %w", p, err)
		}
		text := decodeText(data)
		folder, err := relativeFolder(lyricsRoot, p)
		if err != nil {
			return err
		}
		addDirs(lyricDirs, folder)
		var lines []string
		if text != "" {
			lines = splitLines(text)
		}
		lyrics = append(lyrics, Lyrics{Filepath: folder, Filename: strings.TrimSuffix(filepath.Base(p), filepath.Ext(p)), Lines: lines})
		if (i+1)%100 == 0 || i+1 == len(lyricPaths) {
			send(73+int(16*float64(i+1)/float64(len(lyricPaths))), fmt.Sprintf("Reading lyrics: %d / %d", i+1, len(lyricPaths)), (i+1)%1000 == 0)
		}
	}
	send(90, fmt.Sprintf("Generating indexes: %d songs, %d lyrics...", len(songs), len(lyrics)), true)
	musicBytes := renderSongs(songs, songDirs)
	lyricsBytes := renderLyrics(lyrics, lyricDirs)
	songOutput := filepath.Join(outDir, "SongBook3Data.plugindata")
	lyricOutput := filepath.Join(outDir, "SongBook3Lyrics.plugindata")
	// Do not overwrite any existing indexes before all input files parse successfully.
	if err := writeSafely(songOutput, musicBytes); err != nil {
		return fmt.Errorf("Writing music index: %w", err)
	}
	if err := writeSafely(lyricOutput, lyricsBytes); err != nil {
		return fmt.Errorf("Writing lyrics index: %w", err)
	}
	send(94, "Indexes saved beside builder. Finding LOTRO accounts...", true)
	accounts, err := findAccounts(cfg.PluginData, cfg.Music, cfg.Account)
	if err != nil {
		return fmt.Errorf("Account discovery: %w (indexes saved beside builder)", err)
	}
	for i, account := range accounts {
		dir := filepath.Join(cfg.PluginData, account, "AllServers")
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("Create %s: %w", dir, err)
		}
		if err := writeSafely(filepath.Join(dir, "SongBook3Data.plugindata"), musicBytes); err != nil {
			return fmt.Errorf("Copy music to %s: %w", account, err)
		}
		if err := writeSafely(filepath.Join(dir, "SongBook3Lyrics.plugindata"), lyricsBytes); err != nil {
			return fmt.Errorf("Copy lyrics to %s: %w", account, err)
		}
		send(94+int(5*float64(i+1)/float64(len(accounts))), fmt.Sprintf("Updated account: %s\\AllServers", account), true)
	}
	send(100, fmt.Sprintf("COMPLETE: %d songs, %d lyrics, %d account(s), %s elapsed. Reload SongBook3 in LOTRO.", len(songs), len(lyrics), len(accounts), time.Since(start).Round(time.Millisecond)), true)
	return nil
}

func discover(root, extension string) ([]string, error) {
	files := make([]string, 0, 1000)
	err := filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() && strings.EqualFold(d.Name(), ".git") {
			return filepath.SkipDir
		}
		if d.IsDir() {
			return nil
		}
		// Never traverse directory symlinks or junctions (WalkDir does not follow symlinks).
		if d.Type().IsRegular() && strings.EqualFold(filepath.Ext(d.Name()), extension) {
			files = append(files, p)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	sort.Slice(files, func(i, j int) bool {
		a, b := strings.ToLower(files[i]), strings.ToLower(files[j])
		if a != b {
			return a < b
		}
		return files[i] < files[j]
	})
	return files, nil
}

func decodeText(data []byte) string {
	data = bytes.TrimPrefix(data, []byte{0xEF, 0xBB, 0xBF})
	if utf8.Valid(data) {
		return string(data)
	}
	// Windows ANSI compatibility for older ABC files: recover Windows-1252
	// instead of writing invalid UTF-8 into Lua plugindata.
	cp1252 := [32]rune{'€', 0x0081, '‚', 'ƒ', '„', '…', '†', '‡', 'ˆ', '‰', 'Š', '‹', 'Œ', 0x008D, 'Ž', 0x008F,
		0x0090, '‘', '’', '“', '”', '•', '–', '—', '˜', '™', 'š', '›', 'œ', 0x009D, 'ž', 'Ÿ'}
	var b strings.Builder
	for _, x := range data {
		if x < 128 {
			b.WriteByte(x)
		} else if x < 160 {
			b.WriteRune(cp1252[x-128])
		} else {
			b.WriteRune(rune(x))
		}
	}
	return b.String()
}
func splitLines(s string) []string {
	s = strings.ReplaceAll(strings.ReplaceAll(s, "\r\n", "\n"), "\r", "\n")
	arr := strings.Split(s, "\n")
	if strings.HasSuffix(s, "\n") {
		arr = arr[:len(arr)-1]
	}
	return arr
}
func parseABC(p string) ([]Track, string, error) {
	data, err := os.ReadFile(p)
	if err != nil {
		return nil, "", err
	}
	lines := splitLines(decodeText(data))
	tracks := make([]Track, 0, 8)
	x, t := 0, 0
	artist := ""
	for _, line := range lines {
		if m := rxX.FindStringSubmatch(line); m != nil {
			tracks = append(tracks, Track{Id: m[1]})
			x++
		} else if m := rxT.FindStringSubmatch(line); m != nil {
			if x == 0 && t == 0 {
				tracks = append(tracks, Track{Id: "1"})
				x++
			}
			if x == t {
				continue
			}
			tracks[len(tracks)-1].Name = m[1]
			tracks[len(tracks)-1].HasName = true
			t++
		} else if m := rxC.FindStringSubmatch(line); m != nil {
			credit := strings.TrimSpace(m[1])
			if credit != "" {
				if artist == "" {
					artist = credit
				}
				if len(tracks) > 0 && !tracks[len(tracks)-1].HasArtist {
					tracks[len(tracks)-1].Artist = credit
					tracks[len(tracks)-1].HasArtist = true
				}
			}
		} else if m := rxPart.FindStringSubmatch(line); m != nil {
			part := strings.TrimSpace(m[1])
			if part != "" && len(tracks) > 0 {
				tracks[len(tracks)-1].PartName = part
				tracks[len(tracks)-1].HasPartName = true
			}
		}
	}
	if x != t {
		return nil, "", fmt.Errorf("malformed ABC: %d X: headers but %d T: titles", x, t)
	}
	return tracks, artist, nil
}
func relativeFolder(root, p string) (string, error) {
	rel, err := filepath.Rel(root, p)
	if err != nil {
		return "", err
	}
	if rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		return "", errors.New("file lies outside Music folder")
	}
	dir := filepath.Dir(rel)
	if dir == "." {
		return "/", nil
	}
	return "/" + filepath.ToSlash(dir) + "/", nil
}
func addDirs(dirs map[string]bool, dir string) {
	dirs["/"] = true
	current := "/"
	for _, part := range strings.Split(dir, "/") {
		if part != "" {
			current += part + "/"
			dirs[current] = true
		}
	}
}
func q(s string) string {
	var b strings.Builder
	b.WriteByte('"')
	for _, r := range s {
		switch r {
		case '\\':
			b.WriteString(`\\`)
		case '"':
			b.WriteString(`\"`)
		case '\r':
			b.WriteString(`\r`)
		case '\n':
			b.WriteString(`\n`)
		case '\t':
			b.WriteString(`\t`)
		case 0:
			b.WriteString(`\000`)
		default:
			if r < 32 {
				fmt.Fprintf(&b, "\\%03d", r)
			} else {
				b.WriteRune(r)
			}
		}
	}
	b.WriteByte('"')
	return b.String()
}
func sortedDirs(m map[string]bool) []string {
	v := make([]string, 0, len(m))
	for k := range m {
		v = append(v, k)
	}
	sort.Strings(v)
	return v
}
func renderSongs(songs []Song, dirs map[string]bool) []byte {
	var b bytes.Buffer
	w := bufio.NewWriter(&b)
	fmt.Fprint(w, "return {\n\tSongs = {\n")
	for _, s := range songs {
		fmt.Fprint(w, "\t\t{\n")
		fmt.Fprintf(w, "\t\t\tFilepath = %s;\n\t\t\tFilename = %s;\n", q(s.Filepath), q(s.Filename))
		if s.Artist != "" {
			fmt.Fprintf(w, "\t\t\tArtist = %s;\n", q(s.Artist))
		}
		fmt.Fprint(w, "\t\t\tTracks = {\n")
		for _, tr := range s.Tracks {
			fmt.Fprintf(w, "\t\t\t\t{\n\t\t\t\t\tId = %s;\n", q(tr.Id))
			if tr.HasName {
				fmt.Fprintf(w, "\t\t\t\t\tName = %s;\n", q(tr.Name))
			}
			if tr.HasPartName {
				fmt.Fprintf(w, "\t\t\t\t\tPartName = %s;\n", q(tr.PartName))
			}
			if tr.HasArtist {
				fmt.Fprintf(w, "\t\t\t\t\tArtist = %s;\n", q(tr.Artist))
			}
			fmt.Fprint(w, "\t\t\t\t};\n")
		}
		fmt.Fprint(w, "\t\t\t}\n\t\t};\n")
	}
	fmt.Fprint(w, "\t};\n\tDirectories = {\n")
	for _, d := range sortedDirs(dirs) {
		fmt.Fprintf(w, "\t\t%s;\n", q(d))
	}
	fmt.Fprint(w, "\t}\n}\n")
	w.Flush()
	return b.Bytes()
}
func renderLyrics(lyrics []Lyrics, dirs map[string]bool) []byte {
	var b bytes.Buffer
	w := bufio.NewWriter(&b)
	fmt.Fprint(w, "return {\n\tLyrics = {\n")
	for _, l := range lyrics {
		fmt.Fprintf(w, "\t\t{\n\t\t\tFilepath = %s;\n\t\t\tFilename = %s;\n\t\t\tLines = {\n", q(l.Filepath), q(l.Filename))
		for _, line := range l.Lines {
			fmt.Fprintf(w, "\t\t\t\t%s;\n", q(line))
		}
		fmt.Fprint(w, "\t\t\t}\n\t\t};\n")
	}
	fmt.Fprint(w, "\t};\n\tDirectories = {\n")
	for _, d := range sortedDirs(dirs) {
		fmt.Fprintf(w, "\t\t%s;\n", q(d))
	}
	fmt.Fprint(w, "\t}\n}\n")
	w.Flush()
	return b.Bytes()
}
func validAccount(name string) bool {
	if name == "" || name == "." || name == ".." || strings.EqualFold(name, ".git") || strings.EqualFold(name, "AllServers") {
		return false
	}
	return !strings.ContainsAny(name, `\/:*?"<>|`) && !strings.HasSuffix(name, " ") && !strings.HasSuffix(name, ".")
}
func findAccounts(pluginData, music, manual string) ([]string, error) {
	entries, err := os.ReadDir(pluginData)
	if err != nil {
		return nil, err
	}
	a := make([]string, 0)
	for _, e := range entries {
		if e.IsDir() && !strings.EqualFold(e.Name(), ".git") && !strings.EqualFold(e.Name(), "AllServers") {
			a = append(a, e.Name())
		}
	}
	if len(a) == 0 {
		prefs := filepath.Join(filepath.Dir(music), "UserPreferences.ini")
		if b, err := os.ReadFile(prefs); err == nil {
			for _, line := range splitLines(decodeText(b)) {
				if strings.HasPrefix(strings.ToLower(strings.TrimSpace(line)), "username=") {
					idx := strings.Index(line, "=")
					v := strings.TrimSpace(line[idx+1:])
					if validAccount(v) {
						a = append(a, v)
					}
				}
			}
		}
	}
	if len(a) == 0 {
		if !validAccount(manual) {
			return nil, fmt.Errorf("no account folders found; enter a valid LOTRO account name")
		}
		a = append(a, manual)
	}
	seen := make(map[string]bool)
	out := make([]string, 0, len(a))
	for _, v := range a {
		if validAccount(v) && !seen[strings.ToLower(v)] {
			out = append(out, v)
			seen[strings.ToLower(v)] = true
		}
	}
	sort.Slice(out, func(i, j int) bool { return strings.ToLower(out[i]) < strings.ToLower(out[j]) })
	if len(out) == 0 {
		return nil, errors.New("no usable account folder found")
	}
	return out, nil
}
func writeSafely(path string, data []byte) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, ".songbook3-*.tmp")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if _, err = tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err = tmp.Close(); err != nil {
		return err
	}
	// On Windows os.Rename does not replace a destination reliably on all filesystems.
	// Renaming a complete staged file is safer than writing a partial index.
	if err = os.Rename(tmpName, path); err == nil {
		return nil
	}
	if _, statErr := os.Stat(path); statErr != nil {
		return err
	}
	if e := os.Remove(path); e != nil {
		return fmt.Errorf("cannot replace %s: %w", path, e)
	}
	return os.Rename(tmpName, path)
}
