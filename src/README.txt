SongBook3 Windows GUI builder — song-level artist only

C: retains the first nonempty credit for the entire ABC file. Track-level Artist is no longer emitted. PartName, IDs, titles, lyrics, and .git exclusions are unchanged.

Build the standalone 64-bit GUI (Go required only to build):
  go build -trimpath -ldflags="-s -w -H windowsgui" -o SongBook3_Windows_Builder.exe scanner_core.go gui_windows.go

Cross-compile from Linux/macOS:
  GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -H windowsgui" -o SongBook3_Windows_Builder.exe scanner_core.go gui_windows.go

Run scanner tests:
  go test -v scanner_core.go scanner_core_test.go

The build is standard-library-only.
