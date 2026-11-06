#!/usr/bin/perl
use strict;
use warnings;
use File::Spec;
use File::Basename qw(dirname basename);
use File::Find qw(find);
use File::Copy qw(copy);
use File::Path qw(make_path);
use Getopt::Long qw(GetOptions);
$| = 1;

# SongBook3 library scanner. Uses only Perl core modules and native path/file
# APIs so the same script works on Windows, macOS, and Linux.
my ($music_arg, $plugin_data_arg, $help);
GetOptions(
    'music=s'      => \$music_arg,
    'plugindata=s' => \$plugin_data_arg,
    'help'         => \$help,
) or die usage();
if ($help) { print usage(); exit 0; }

my $mydir = dirname(File::Spec->rel2abs(__FILE__));
my $music_dir = defined($music_arg) && length($music_arg)
    ? File::Spec->rel2abs($music_arg)
    : File::Spec->catdir($mydir, File::Spec->updir, File::Spec->updir, 'Music');
my $plugin_data_dir = defined($plugin_data_arg) && length($plugin_data_arg)
    ? File::Spec->rel2abs($plugin_data_arg)
    : File::Spec->catdir($mydir, File::Spec->updir, File::Spec->updir, 'PluginData');

print "\nSongBook3 library builder\n";
print "Scans Music for ABC files and Music/lyrics for mirrored TXT lyric files.\n\n";

unless (-d $music_dir) {
    $music_dir = prompt_directory("Music directory not found. Enter the full path to your LOTRO Music folder:");
}
-d $music_dir or die "Music directory does not exist: $music_dir\n";
$music_dir = File::Spec->rel2abs($music_dir);

my @abc_files = find_files($music_dir, qr/\.abc\z/i);
@abc_files = sort { lc($a) cmp lc($b) || $a cmp $b } @abc_files;
print "Music directory: $music_dir\n";
print "Found " . scalar(@abc_files) . " ABC music files.\n";

# Build the song index in memory first. A malformed ABC file therefore cannot
# replace a previously generated index with a partial file.
my %song_directories = ('/' => 1);
my @songs;
for my $filepath (@abc_files) {
    my $relative = File::Spec->abs2rel($filepath, $music_dir);
    $relative =~ s!\\!/!g;
    my $dir = dirname($relative);
    $dir = '' if $dir eq '.';
    $dir =~ s!^\./!!;
    my $song_path = length($dir) ? '/' . $dir . '/' : '/';
    add_directory_and_parents(\%song_directories, $song_path);

    my ($tracks, $artist) = parse_abc($filepath);
    my $filename = basename($filepath);
    $filename =~ s/\.[^.]*\z//;
    push @songs, {
        Filepath => $song_path,
        Filename => $filename,
        Tracks   => $tracks,
        Artist   => $artist,
    };
}

# Build the mirrored lyric index. Music/songs/<relative path>/<name>.abc maps
# to Music/lyrics/<relative path>/<name>.txt.
my $lyrics_root = File::Spec->catdir($music_dir, 'lyrics');
my @lyric_files = -d $lyrics_root ? find_files($lyrics_root, qr/\.txt\z/i) : ();
@lyric_files = sort { lc($a) cmp lc($b) || $a cmp $b } @lyric_files;
print "Found " . scalar(@lyric_files) . " mirrored lyric TXT files.\n";
my %lyric_directories = ('/' => 1);
my @lyrics;
for my $filepath (@lyric_files) {
    my $relative = File::Spec->abs2rel($filepath, $lyrics_root);
    $relative =~ s!\\!/!g;
    my $dir = dirname($relative);
    $dir = '' if $dir eq '.';
    my $lyric_path = length($dir) ? '/' . $dir . '/' : '/';
    add_directory_and_parents(\%lyric_directories, $lyric_path);

    my $text = read_raw_file($filepath);
    $text =~ s/^\xEF\xBB\xBF//; # UTF-8 BOM
    my @lines = split /\r\n|\n|\r/, $text, -1;
    pop @lines if @lines && $lines[-1] eq '' && $text =~ /(?:\r\n|\n|\r)\z/;
    @lines = () if $text eq '';

    my $filename = basename($filepath);
    $filename =~ s/\.[^.]*\z//;
    push @lyrics, {
        Filepath => $lyric_path,
        Filename => $filename,
        Lines    => \@lines,
    };
}

my $song_output = File::Spec->catfile($mydir, 'SongBook3Data.plugindata');
my $lyrics_output = File::Spec->catfile($mydir, 'SongBook3Lyrics.plugindata');
write_song_index($song_output, \@songs, \%song_directories);
write_lyrics_index($lyrics_output, \@lyrics, \%lyric_directories);
print "Generated:\n  $song_output\n  $lyrics_output\n";

unless (-d $plugin_data_dir) {
    $plugin_data_dir = prompt_directory("PluginData directory not found. Enter the full path to your LOTRO PluginData folder:");
}
-d $plugin_data_dir or die "PluginData directory does not exist: $plugin_data_dir\n";
$plugin_data_dir = File::Spec->rel2abs($plugin_data_dir);

opendir(my $dh, $plugin_data_dir) or die "Cannot read PluginData directory '$plugin_data_dir': $!\n";
my @accounts = sort grep {
    $_ ne '.' && $_ ne '..' && -d File::Spec->catdir($plugin_data_dir, $_)
} readdir($dh);
closedir($dh);

if (!@accounts) {
    my $account = prompt_line("No account folders were found in PluginData. Enter your LOTRO account name:");
    length($account) or die "No account name supplied; generated indexes remain in $mydir.\n";
    push @accounts, $account;
}

print "\nCopying indexes to PluginData account folders...\n";
for my $account (@accounts) {
    my $target_dir = File::Spec->catdir($plugin_data_dir, $account, 'AllServers');
    make_path($target_dir) unless -d $target_dir;
    copy($song_output, $target_dir)
        or warn "Could not copy SongBook3Data.plugindata to '$target_dir': $!\n";
    copy($lyrics_output, $target_dir)
        or warn "Could not copy SongBook3Lyrics.plugindata to '$target_dir': $!\n";
    print "  Updated $account\\AllServers\n";
}

print "\nLibrary generation complete. Refresh SongBook3 in LOTRO if it is already loaded.\n";
exit 0;

sub usage {
    return <<'USAGE';
SongBook3_Scanner.pl [--music PATH] [--plugindata PATH] [--help]

Defaults to the Music and PluginData folders beside the Plugins directory
containing this scanner. If either default folder is missing, the script asks
for its location. Generated indexes are saved beside this script and copied to
each account's PluginData/<account>/AllServers folder.
USAGE
}

sub prompt_line {
    my ($message) = @_;
    print "$message\n> ";
    my $value = <STDIN>;
    return '' unless defined $value;
    chomp $value;
    $value =~ s/^\s+|\s+$//g;
    $value =~ s/^"(.*)"\z/$1/;
    return $value;
}

sub prompt_directory {
    my ($message) = @_;
    while (1) {
        my $path = prompt_line($message);
        return $path if length($path) && -d $path;
        print "That directory was not found. Please try again.\n";
    }
}

sub find_files {
    my ($root, $pattern) = @_;
    my @found;
    find({
        no_chdir => 1,
        wanted   => sub {
            return unless -f $_;
            return unless $_ =~ $pattern;
            push @found, File::Spec->rel2abs($File::Find::name);
        },
    }, $root);
    return @found;
}

sub read_raw_file {
    my ($path) = @_;
    open(my $fh, '<', $path) or die "Cannot read '$path': $!\n";
    binmode($fh);
    local $/;
    my $data = <$fh>;
    close($fh);
    return defined($data) ? $data : '';
}

sub parse_abc {
    my ($filepath) = @_;
    my $data = read_raw_file($filepath);
    my @lines = split /\r\n|\n|\r/, $data, -1;
    my @tracks;
    my ($tracknum, $x, $t) = (1, 0, 0);
    my $artist = "";

    for my $line (@lines) {
        if ($line =~ m/^[\xef\xbb\xbf]*X:\s*(\d+)/i) {
            push @tracks, { Id => $1 };
            $tracknum++;
            $x++;
        } elsif ($line =~ m/^T: *([[:print:]]+)/i) {
            if ($tracknum == 1 && $x == 0 && $t == 0) {
                push @tracks, { Id => '1' };
                $tracknum++;
                $x++;
            }
            next if $x == $t;
            $tracks[-1]{Name} = $1 if @tracks;
            $t++;
        } elsif ($line =~ m/^C:[ \t]*(.*)/i) {
            # C: is treated as the original artist, as requested. Prefer the
            # first nonempty credit for the whole ABC file. Also retain
            # per-tune credits for multipart ABC files.
            my $credit = $1;
            $credit =~ s/^\s+|\s+$//g;
            if (length($credit)) {
                $artist = $credit if !length($artist);
                $tracks[-1]{Artist} = $credit if @tracks && !defined($tracks[-1]{Artist});
            }
        } elsif ($line =~ m/^%%part-name[ \t]+(.+)/i) {
            # Keep the ABC title for LOTRO playback/sync matching. The in-game
            # plugin uses this part name only if the title has no instrument.
            my $part_name = $1;
            $part_name =~ s/^\s+|\s+$//g;
            $tracks[-1]{PartName} = $part_name if @tracks && length($part_name);
        }
    }

    if ($x != $t) {
        die "\nMalformed ABC file: $filepath\nThe number of X: track headers does not match the T: track titles.\nPlease correct or remove this file and run the scanner again.\n";
    }
    return (\@tracks, $artist);
}

sub lua_quote {
    my ($value) = @_;
    $value = '' unless defined $value;
    $value =~ s/\\/\\\\/g;
    $value =~ s/"/\\"/g;
    $value =~ s/\r/\\r/g;
    $value =~ s/\n/\\n/g;
    $value =~ s/\t/\\t/g;
    $value =~ s/\0/\\000/g;
    $value =~ s/([\x01-\x08\x0B\x0C\x0E-\x1F])/sprintf("\\%03d", ord($1))/eg;
    return '"' . $value . '"';
}

sub add_directory_and_parents {
    my ($directories, $path) = @_;
    $path = '/' unless defined($path) && length($path);
    $path =~ s!\\!/!g;
    $path = '/' . $path unless $path =~ m!^/!;
    my $current = '/';
    $directories->{$current} = 1;
    for my $part (grep { length($_) } split m!/!, $path) {
        $current .= $part . '/';
        $directories->{$current} = 1;
    }
}

sub write_song_index {
    my ($path, $songs, $directories) = @_;
    open(my $out, '>', $path) or die "Cannot create '$path': $!\n";
    binmode($out);
    print {$out} "return {\n\tSongs = {\n";
    for my $song (@{$songs}) {
        print {$out} "\t\t{\n";
        print {$out} "\t\t\tFilepath = " . lua_quote($song->{Filepath}) . ";\n";
        print {$out} "\t\t\tFilename = " . lua_quote($song->{Filename}) . ";\n";
        print {$out} "\t\t\tArtist = " . lua_quote($song->{Artist}) . ";\n" if length($song->{Artist} // "");
        print {$out} "\t\t\tTracks = {\n";
        for my $track (@{$song->{Tracks}}) {
            print {$out} "\t\t\t\t{\n";
            print {$out} "\t\t\t\t\tId = " . lua_quote($track->{Id}) . ";\n";
            print {$out} "\t\t\t\t\tName = " . lua_quote($track->{Name}) . ";\n" if defined $track->{Name};
            print {$out} "\t\t\t\t\tPartName = " . lua_quote($track->{PartName}) . ";\n" if defined $track->{PartName};
            print {$out} "\t\t\t\t\tArtist = " . lua_quote($track->{Artist}) . ";\n" if defined $track->{Artist};
            print {$out} "\t\t\t\t};\n";
        }
        print {$out} "\t\t\t}\n";
        print {$out} "\t\t};\n";
    }
    print {$out} "\t};\n\tDirectories = {\n";
    for my $dir (sort keys %{$directories}) {
        print {$out} "\t\t" . lua_quote($dir) . ";\n";
    }
    print {$out} "\t}\n}\n";
    close($out) or die "Cannot finish writing '$path': $!\n";
}

sub write_lyrics_index {
    my ($path, $lyrics, $directories) = @_;
    open(my $out, '>', $path) or die "Cannot create '$path': $!\n";
    binmode($out);
    print {$out} "return {\n\tLyrics = {\n";
    for my $lyric (@{$lyrics}) {
        print {$out} "\t\t{\n";
        print {$out} "\t\t\tFilepath = " . lua_quote($lyric->{Filepath}) . ";\n";
        print {$out} "\t\t\tFilename = " . lua_quote($lyric->{Filename}) . ";\n";
        print {$out} "\t\t\tLines = {\n";
        for my $line (@{$lyric->{Lines}}) {
            print {$out} "\t\t\t\t" . lua_quote($line) . ";\n";
        }
        print {$out} "\t\t\t}\n";
        print {$out} "\t\t};\n";
    }
    print {$out} "\t};\n\tDirectories = {\n";
    for my $dir (sort keys %{$directories}) {
        print {$out} "\t\t" . lua_quote($dir) . ";\n";
    }
    print {$out} "\t}\n}\n";
    close($out) or die "Cannot finish writing '$path': $!\n";
}
