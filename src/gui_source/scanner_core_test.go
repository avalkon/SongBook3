package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeFile(t *testing.T, p, value string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(p), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(value), 0644); err != nil {
		t.Fatal(err)
	}
}
func TestOutputAndGitExclusion(t *testing.T) {
	root := t.TempDir()
	music := filepath.Join(root, "Music")
	plugins := filepath.Join(root, "PluginData")
	out := filepath.Join(root, "Builder")
	if err := os.MkdirAll(out, 0755); err != nil {
		t.Fatal(err)
	}
	writeFile(t, filepath.Join(music, "Folk", "Baker Street.abc"), "X:1\nT:Baker Street (2:16) - Clarinet\nC:Gerry Rafferty\n%%part-name Clarinet\nX:2\nT:Baker Street - Lute\nC:Gerry Rafferty\n")
	writeFile(t, filepath.Join(music, "Folk", ".git", "hidden.abc"), "X:1\nT:SECRET\n")
	writeFile(t, filepath.Join(music, ".GIT", "hidden.abc"), "X:1\nT:SECRET2\n")
	writeFile(t, filepath.Join(music, "lyrics", "Folk", "Baker Street.txt"), "First lyric\nSecond lyric\n")
	writeFile(t, filepath.Join(music, "lyrics", ".git", "secret.txt"), "HIDDEN LYRICS\n")
	if err := os.MkdirAll(filepath.Join(plugins, "Tester"), 0755); err != nil {
		t.Fatal(err)
	}
	if err := buildLibrary(Config{Music: music, PluginData: plugins}, out, nil); err != nil {
		t.Fatal(err)
	}
	songs, err := os.ReadFile(filepath.Join(out, "SongBook3Data.plugindata"))
	if err != nil {
		t.Fatal(err)
	}
	lyrics, err := os.ReadFile(filepath.Join(out, "SongBook3Lyrics.plugindata"))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(songs), `Artist = "Gerry Rafferty";`) || !strings.Contains(string(songs), `PartName = "Clarinet";`) {
		t.Fatalf("metadata lost: %s", songs)
	}
	if strings.Contains(string(songs), "SECRET") || strings.Contains(string(lyrics), "HIDDEN LYRICS") {
		t.Fatalf(".git data leaked")
	}
	for _, name := range []string{"SongBook3Data.plugindata", "SongBook3Lyrics.plugindata"} {
		a, err := os.ReadFile(filepath.Join(out, name))
		if err != nil {
			t.Fatal(err)
		}
		b, err := os.ReadFile(filepath.Join(plugins, "Tester", "AllServers", name))
		if err != nil {
			t.Fatal(err)
		}
		if string(a) != string(b) {
			t.Errorf("copy mismatch: %s", name)
		}
	}
}
func TestMalformedDoesNotOverwrite(t *testing.T) {
	root := t.TempDir()
	music := filepath.Join(root, "Music")
	plugin := filepath.Join(root, "PluginData")
	out := filepath.Join(root, "Builder")
	_ = os.MkdirAll(out, 0755)
	writeFile(t, filepath.Join(music, "song.abc"), "X:1\nT:Good\n")
	_ = os.MkdirAll(filepath.Join(plugin, "TestAccount"), 0755)
	if err := buildLibrary(Config{Music: music, PluginData: plugin}, out, nil); err != nil {
		t.Fatal(err)
	}
	prev, _ := os.ReadFile(filepath.Join(out, "SongBook3Data.plugindata"))
	writeFile(t, filepath.Join(music, "song.abc"), "X:1\nX:2\nT:Only one title\n")
	err := buildLibrary(Config{Music: music, PluginData: plugin}, out, nil)
	if err == nil {
		t.Fatal("malformed ABC should fail")
	}
	newData, _ := os.ReadFile(filepath.Join(out, "SongBook3Data.plugindata"))
	if string(prev) != string(newData) {
		t.Fatal("failed scan overwrote a working index")
	}
}
func TestProgressReachesComplete(t *testing.T) {
	root := t.TempDir()
	music := filepath.Join(root, "Music")
	plugin := filepath.Join(root, "PluginData")
	out := filepath.Join(root, "Builder")
	_ = os.MkdirAll(out, 0755)
	_ = os.MkdirAll(filepath.Join(plugin, "Tester"), 0755)
	writeFile(t, filepath.Join(music, "test.abc"), "X:1\nT:Song\n")
	got := []int{}
	err := buildLibrary(Config{Music: music, PluginData: plugin}, out, func(s BuildStatus) { got = append(got, s.Percent) })
	if err != nil {
		t.Fatal(err)
	}
	if len(got) < 3 || got[len(got)-1] != 100 {
		t.Fatalf("bad progress: %v", got)
	}
	for i := 1; i < len(got); i++ {
		if got[i] < got[i-1] {
			t.Fatalf("progress regressed: %v", got)
		}
	}
}
