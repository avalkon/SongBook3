SongBook3 GUI Builder: Developer and Troubleshooting Package
=============================================================

The public release needs only SongBook3_Fast_Builder.exe (64-bit Windows).
This optional package includes source and legacy diagnostics.

GUI source files are in gui_source/:
  scanner_core.go - native scanning, metadata, library rendering, account copies
  gui_windows.go - Windows GUI, native folder picker, progress, status log
  scanner_core_test.go - scanner and .git exclusion regression tests

Build 64-bit Windows GUI with Go (only needed for development):
  cd gui_source
  go build -trimpath -ldflags="-s -w -H windowsgui" -o SongBook3_Fast_Builder.exe scanner_core.go gui_windows.go

Build 32-bit Windows GUI:
  set GOARCH=386
  go build -trimpath -ldflags="-s -w -H windowsgui" -o SongBook3_Fast_Builder_x86.exe scanner_core.go gui_windows.go

Run scanner tests (Windows or Linux with Go installed):
  go test -v scanner_core.go scanner_core_test.go

The GUI source and scanner are standard-library-only Go. No network access,
Windows drivers, services, or installs are needed to use the release EXE.
