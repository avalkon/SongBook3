//go:build windows

// SongBook3 standalone native Windows GUI: no HTA, PowerShell, CMD, or
// external GUI libraries. The native scanner runs on a worker goroutine.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"unsafe"
)

const (
	wsOverlappedWindow = 0x00CF0000
	wsVisible          = 0x10000000
	wsChild            = 0x40000000
	wsTabStop          = 0x00010000
	wsBorder           = 0x00800000
	wsVScroll          = 0x00200000
	wsClipChildren     = 0x02000000
	esAutoHScroll      = 0x0080
	esMultiline        = 0x0004
	esReadOnly         = 0x0800
	esAutoVScroll      = 0x0040
	wsExClientEdge     = 0x00000200

	wmCreate        = 0x0001
	wmDestroy       = 0x0002
	wmSize          = 0x0005
	wmClose         = 0x0010
	wmCommand       = 0x0111
	wmSetFont       = 0x0030
	wmGetMinMaxInfo = 0x0024
	wmAppUpdate     = 0x8000 + 83
	wmUser          = 0x0400

	emSetSel      = 0x00B1
	emReplaceSel  = 0x00C2
	emScrollCaret = 0x00B7
	pbmSetRange32 = wmUser + 6
	pbmSetPos     = wmUser + 2

	idBrowseMusic  = 201
	idBrowsePlugin = 202
	idBuild        = 203

	mbOK        = 0
	mbIconError = 0x10
	mbIconInfo  = 0x40

	bifReturnOnlyFSDirs = 0x0001
	bifEditBox          = 0x0010
	bifNewDialogStyle   = 0x0040
	bffmInitialized     = 1
	bffmSetSelectionW   = wmUser + 103
)

var (
	dllUser   = syscall.NewLazyDLL("user32.dll")
	dllKernel = syscall.NewLazyDLL("kernel32.dll")
	dllShell  = syscall.NewLazyDLL("shell32.dll")
	dllOle    = syscall.NewLazyDLL("ole32.dll")
	dllGdi    = syscall.NewLazyDLL("gdi32.dll")
	dllCommon = syscall.NewLazyDLL("comctl32.dll")

	pRegisterClassEx     = dllUser.NewProc("RegisterClassExW")
	pCreateWindowEx      = dllUser.NewProc("CreateWindowExW")
	pDefWindowProc       = dllUser.NewProc("DefWindowProcW")
	pGetMessage          = dllUser.NewProc("GetMessageW")
	pTranslateMessage    = dllUser.NewProc("TranslateMessage")
	pDispatchMessage     = dllUser.NewProc("DispatchMessageW")
	pPostQuitMessage     = dllUser.NewProc("PostQuitMessage")
	pPostMessage         = dllUser.NewProc("PostMessageW")
	pSendMessage         = dllUser.NewProc("SendMessageW")
	pSetWindowText       = dllUser.NewProc("SetWindowTextW")
	pGetWindowText       = dllUser.NewProc("GetWindowTextW")
	pGetWindowTextLength = dllUser.NewProc("GetWindowTextLengthW")
	pGetClientRect       = dllUser.NewProc("GetClientRect")
	pMoveWindow          = dllUser.NewProc("MoveWindow")
	pEnableWindow        = dllUser.NewProc("EnableWindow")
	pMessageBox          = dllUser.NewProc("MessageBoxW")
	pDestroyWindow       = dllUser.NewProc("DestroyWindow")
	pLoadCursor          = dllUser.NewProc("LoadCursorW")
	pLoadIcon            = dllUser.NewProc("LoadIconW")
	pGetModuleHandle     = dllKernel.NewProc("GetModuleHandleW")
	pGetStockObject      = dllGdi.NewProc("GetStockObject")
	pInitCommonControls  = dllCommon.NewProc("InitCommonControlsEx")
	pCoInitializeEx      = dllOle.NewProc("CoInitializeEx")
	pCoUninitialize      = dllOle.NewProc("CoUninitialize")
	pCoTaskMemFree       = dllOle.NewProc("CoTaskMemFree")
	pSHBrowseForFolder   = dllShell.NewProc("SHBrowseForFolderW")
	pSHGetPathFromIDList = dllShell.NewProc("SHGetPathFromIDListW")
	pSHGetFolderPath     = dllShell.NewProc("SHGetFolderPathW")
)

type wndClassEx struct {
	cbSize     uint32
	style      uint32
	wndProc    uintptr
	clsExtra   int32
	wndExtra   int32
	instance   uintptr
	icon       uintptr
	cursor     uintptr
	background uintptr
	menuName   *uint16
	className  *uint16
	iconSmall  uintptr
}
type winPoint struct{ x, y int32 }
type winRect struct{ left, top, right, bottom int32 }
type minMaxInfo struct {
	reserved, maxSize, maxPosition, minTrackSize, maxTrackSize winPoint
}
type winMsg struct {
	hwnd    uintptr
	message uint32
	wParam  uintptr
	lParam  uintptr
	time    uint32
	pt      winPoint
	private uint32
}
type initControls struct{ size, classes uint32 }
type browseInfo struct {
	owner       uintptr
	root        uintptr
	displayName *uint16
	title       *uint16
	flags       uint32
	callback    uintptr
	lParam      uintptr
	image       int32
}

type guiEvent struct {
	status   BuildStatus
	finished bool
	err      error
}
type guiApplication struct {
	hwnd, caption, musicLabel, musicEdit, musicBrowse uintptr
	pluginLabel, pluginEdit, pluginBrowse             uintptr
	accountLabel, accountEdit, buildButton            uintptr
	statusLabel, progress, logEdit, footer            uintptr
	font                                              uintptr
	running                                           bool
	events                                            chan guiEvent
	outDir                                            string
}

var gui *guiApplication
var browseCallbackPointer = syscall.NewCallback(browseCallback)

func u16(s string) *uint16 { return syscall.StringToUTF16Ptr(s) }
func postEvent(e guiEvent) {
	gui.events <- e
	pPostMessage.Call(gui.hwnd, wmAppUpdate, 0, 0)
}
func sendMsg(hwnd uintptr, message uint32, wparam, lparam uintptr) uintptr {
	r, _, _ := pSendMessage.Call(hwnd, uintptr(message), wparam, lparam)
	return r
}
func putText(hwnd uintptr, s string) { pSetWindowText.Call(hwnd, uintptr(unsafe.Pointer(u16(s)))) }
func readText(hwnd uintptr) string {
	n, _, _ := pGetWindowTextLength.Call(hwnd)
	buffer := make([]uint16, int(n)+1)
	pGetWindowText.Call(hwnd, uintptr(unsafe.Pointer(&buffer[0])), uintptr(len(buffer)))
	return syscall.UTF16ToString(buffer)
}
func move(hwnd uintptr, x, y, w, h int) {
	if hwnd != 0 {
		pMoveWindow.Call(hwnd, uintptr(x), uintptr(y), uintptr(w), uintptr(h), 1)
	}
}
func enabled(hwnd uintptr, yes bool) {
	value := uintptr(0)
	if yes {
		value = 1
	}
	pEnableWindow.Call(hwnd, value)
}
func messageBox(s string, flags uintptr) {
	pMessageBox.Call(gui.hwnd, uintptr(unsafe.Pointer(u16(s))), uintptr(unsafe.Pointer(u16("SongBook3 Library Builder"))), flags)
}
func (a *guiApplication) child(class, text string, exStyle, style uint32, id int) uintptr {
	r, _, _ := pCreateWindowEx.Call(uintptr(exStyle), uintptr(unsafe.Pointer(u16(class))), uintptr(unsafe.Pointer(u16(text))),
		uintptr(wsVisible|wsChild|style), 0, 0, 80, 24, a.hwnd, uintptr(id), 0, 0)
	if r != 0 && a.font != 0 {
		sendMsg(r, wmSetFont, a.font, 1)
	}
	return r
}
func (a *guiApplication) createControls() {
	a.font, _, _ = pGetStockObject.Call(17) // DEFAULT_GUI_FONT
	a.caption = a.child("STATIC", "Fast ABC and lyrics indexer. C: artists supported; all .git directories ignored.", 0, 0, 0)
	a.musicLabel = a.child("STATIC", "LOTRO Music folder (ABC files; lyrics under Music\\lyrics)", 0, 0, 0)
	a.musicEdit = a.child("EDIT", "", wsExClientEdge, wsTabStop|esAutoHScroll, 0)
	a.musicBrowse = a.child("BUTTON", "Browse...", 0, wsTabStop, idBrowseMusic)
	a.pluginLabel = a.child("STATIC", "LOTRO PluginData folder (updates each account's AllServers)", 0, 0, 0)
	a.pluginEdit = a.child("EDIT", "", wsExClientEdge, wsTabStop|esAutoHScroll, 0)
	a.pluginBrowse = a.child("BUTTON", "Browse...", 0, wsTabStop, idBrowsePlugin)
	a.accountLabel = a.child("STATIC", "Account name (optional; only if account discovery finds none)", 0, 0, 0)
	a.accountEdit = a.child("EDIT", "", wsExClientEdge, wsTabStop|esAutoHScroll, 0)
	a.buildButton = a.child("BUTTON", "Build SongBook3 Library", 0, wsTabStop, idBuild)
	a.statusLabel = a.child("STATIC", "Ready. Indexes will also be saved beside this executable.", 0, 0, 0)
	a.progress = a.child("msctls_progress32", "", 0, 0, 0)
	sendMsg(a.progress, pbmSetRange32, 0, 100)
	a.logEdit = a.child("EDIT", "Select your folders and click Build.\r\n", wsExClientEdge, wsVScroll|esMultiline|esReadOnly|esAutoVScroll, 0)
	a.footer = a.child("STATIC", "The builder runs locally. Reload SongBook3 in LOTRO after building.", 0, 0, 0)
	prefs := readPreferences()
	lotro := filepath.Join(documentsPath(), "The Lord of the Rings Online")
	music := filepath.Join(lotro, "Music")
	plugin := filepath.Join(lotro, "PluginData")
	if prefs.Music != "" {
		music = prefs.Music
	}
	if prefs.PluginData != "" {
		plugin = prefs.PluginData
	}
	putText(a.musicEdit, music)
	putText(a.pluginEdit, plugin)
	putText(a.accountEdit, prefs.Account)
}
func (a *guiApplication) layout() {
	if a.hwnd == 0 || a.musicEdit == 0 {
		return
	}
	var r winRect
	pGetClientRect.Call(a.hwnd, uintptr(unsafe.Pointer(&r)))
	w, h := int(r.right-r.left), int(r.bottom-r.top)
	if w < 1 || h < 1 {
		return
	}
	pad := 18
	fieldWidth := w - 2*pad - 105
	if fieldWidth < 100 {
		fieldWidth = 100
	}
	move(a.caption, pad, 15, w-2*pad, 40)
	move(a.musicLabel, pad, 59, w-2*pad, 19)
	move(a.musicEdit, pad, 80, fieldWidth, 26)
	move(a.musicBrowse, pad+fieldWidth+9, 79, 95, 29)
	move(a.pluginLabel, pad, 123, w-2*pad, 19)
	move(a.pluginEdit, pad, 144, fieldWidth, 26)
	move(a.pluginBrowse, pad+fieldWidth+9, 143, 95, 29)
	move(a.accountLabel, pad, 190, w-2*pad, 19)
	move(a.accountEdit, pad, 212, w/2-pad, 26)
	move(a.buildButton, pad, 257, 215, 33)
	move(a.statusLabel, pad+229, 263, w-2*pad-229, 43)
	move(a.progress, pad, 309, w-2*pad, 17)
	logY := 342
	footerY := h - 29
	logH := footerY - logY - 10
	if logH < 65 {
		logH = 65
	}
	move(a.logEdit, pad, logY, w-2*pad, logH)
	move(a.footer, pad, footerY, w-2*pad, 20)
}
func (a *guiApplication) appendLog(s string) {
	s = strings.ReplaceAll(s, "\n", "\r\n")
	sendMsg(a.logEdit, emSetSel, ^uintptr(0), ^uintptr(0))
	sendMsg(a.logEdit, emReplaceSel, 0, uintptr(unsafe.Pointer(u16(s+"\r\n"))))
	sendMsg(a.logEdit, emScrollCaret, 0, 0)
}
func (a *guiApplication) setBusy(yes bool) {
	a.running = yes
	enabled(a.buildButton, !yes)
	enabled(a.musicBrowse, !yes)
	enabled(a.pluginBrowse, !yes)
	enabled(a.musicEdit, !yes)
	enabled(a.pluginEdit, !yes)
	enabled(a.accountEdit, !yes)
}
func (a *guiApplication) build() {
	if a.running {
		return
	}
	cfg := Config{Music: strings.TrimSpace(readText(a.musicEdit)), PluginData: strings.TrimSpace(readText(a.pluginEdit)), Account: strings.TrimSpace(readText(a.accountEdit))}
	if cfg.Music == "" || cfg.PluginData == "" {
		messageBox("Select both the Music and PluginData directories.", mbOK|mbIconError)
		return
	}
	st, err := os.Stat(cfg.Music)
	if err != nil || !st.IsDir() {
		messageBox("Music folder does not exist:\r\n"+cfg.Music, mbOK|mbIconError)
		return
	}
	savePreferences(cfg)
	a.setBusy(true)
	putText(a.logEdit, "")
	putText(a.statusLabel, "Starting library scan...")
	sendMsg(a.progress, pbmSetPos, 0, 0)
	go func() {
		var buildError error
		defer func() {
			if v := recover(); v != nil {
				buildError = fmt.Errorf("internal builder error: %v", v)
			}
			postEvent(guiEvent{finished: true, err: buildError})
		}()
		buildError = buildLibrary(cfg, a.outDir, func(s BuildStatus) { postEvent(guiEvent{status: s}) })
	}()
}
func (a *guiApplication) drainEvents() {
	for {
		select {
		case e := <-a.events:
			if e.finished {
				a.setBusy(false)
				if e.err != nil {
					putText(a.statusLabel, "Build failed. See activity log below.")
					a.appendLog("ERROR: " + e.err.Error())
					messageBox("Build failed:\r\n"+e.err.Error()+"\r\n\r\nSee the activity log for details.", mbOK|mbIconError)
				} else {
					sendMsg(a.progress, pbmSetPos, 100, 0)
					putText(a.statusLabel, "Complete! Reload SongBook3 in LOTRO.")
					messageBox("SongBook3 indexes generated and copied to the detected LOTRO accounts.\r\nReload SongBook3 in LOTRO to see the updates.", mbOK|mbIconInfo)
				}
			} else {
				if e.status.Percent >= 0 {
					sendMsg(a.progress, pbmSetPos, uintptr(e.status.Percent), 0)
				}
				putText(a.statusLabel, e.status.Message)
				if e.status.Log {
					a.appendLog(e.status.Message)
				}
			}
		default:
			return
		}
	}
}
func guiWndProc(hwnd uintptr, msg uint32, wParam, lParam uintptr) uintptr {
	switch msg {
	case wmCreate:
		gui.hwnd = hwnd
		gui.createControls()
		gui.layout()
		return 0
	case wmSize:
		gui.layout()
		return 0
	case wmGetMinMaxInfo:
		limits := (*minMaxInfo)(unsafe.Pointer(lParam))
		limits.minTrackSize = winPoint{x: 620, y: 485}
		return 0
	case wmCommand:
		switch int(wParam & 0xffff) {
		case idBrowseMusic:
			if !gui.running {
				if folder, ok := browseFolder(hwnd, "Select LOTRO Music folder", readText(gui.musicEdit)); ok {
					putText(gui.musicEdit, folder)
				}
			}
		case idBrowsePlugin:
			if !gui.running {
				if folder, ok := browseFolder(hwnd, "Select LOTRO PluginData folder", readText(gui.pluginEdit)); ok {
					putText(gui.pluginEdit, folder)
				}
			}
		case idBuild:
			gui.build()
		}
		return 0
	case wmAppUpdate:
		gui.drainEvents()
		return 0
	case wmClose:
		if gui.running {
			messageBox("The library scan is in progress. Close the window after it finishes.", mbOK|mbIconInfo)
			return 0
		}
		pDestroyWindow.Call(hwnd)
		return 0
	case wmDestroy:
		pPostQuitMessage.Call(0)
		return 0
	}
	r, _, _ := pDefWindowProc.Call(hwnd, uintptr(msg), wParam, lParam)
	return r
}

func browseFolder(hwnd uintptr, title, initial string) (string, bool) {
	display := make([]uint16, 260)
	initialUTF16 := u16(initial)
	bi := browseInfo{owner: hwnd, displayName: &display[0], title: u16(title), flags: bifReturnOnlyFSDirs | bifEditBox | bifNewDialogStyle, callback: browseCallbackPointer, lParam: uintptr(unsafe.Pointer(initialUTF16))}
	pidl, _, _ := pSHBrowseForFolder.Call(uintptr(unsafe.Pointer(&bi)))
	runtime.KeepAlive(initialUTF16)
	if pidl == 0 {
		return "", false
	}
	defer pCoTaskMemFree.Call(pidl)
	buf := make([]uint16, 32768)
	ok, _, _ := pSHGetPathFromIDList.Call(pidl, uintptr(unsafe.Pointer(&buf[0])))
	if ok == 0 {
		messageBox("Unable to read the selected folder path.", mbOK|mbIconError)
		return "", false
	}
	return syscall.UTF16ToString(buf), true
}
func browseCallback(hwnd uintptr, msg uint32, lParam, extra uintptr) uintptr {
	if msg == bffmInitialized && extra != 0 {
		sendMsg(hwnd, bffmSetSelectionW, 1, extra)
	}
	return 0
}
func documentsPath() string {
	result := make([]uint16, 260)
	hr, _, _ := pSHGetFolderPath.Call(0, 5, 0, 0, uintptr(unsafe.Pointer(&result[0]))) // CSIDL_PERSONAL
	if hr == 0 {
		if s := syscall.UTF16ToString(result); s != "" {
			return s
		}
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Documents")
}
func prefPath() string {
	dir, err := os.UserConfigDir()
	if err != nil {
		return ""
	}
	return filepath.Join(dir, "SongBook3", "builder-settings.json")
}
func readPreferences() Config {
	p := prefPath()
	var cfg Config
	if p != "" {
		if b, err := os.ReadFile(p); err == nil {
			_ = json.Unmarshal(b, &cfg)
		}
	}
	return cfg
}
func savePreferences(cfg Config) {
	p := prefPath()
	if p == "" {
		return
	}
	if err := os.MkdirAll(filepath.Dir(p), 0700); err != nil {
		return
	}
	if data, err := json.MarshalIndent(cfg, "", "  "); err == nil {
		_ = os.WriteFile(p, data, 0600)
	}
}

func main() {
	runtime.LockOSThread() // UI message loop and Shell dialog require one STA thread.
	defer runtime.UnlockOSThread()
	hr, _, _ := pCoInitializeEx.Call(0, 2) // COINIT_APARTMENTTHREADED
	if hr == 0 || hr == 1 {
		defer pCoUninitialize.Call()
	}
	common := initControls{size: uint32(unsafe.Sizeof(initControls{})), classes: 0x20} // ICC_PROGRESS_CLASS
	pInitCommonControls.Call(uintptr(unsafe.Pointer(&common)))
	exe, err := os.Executable()
	if err != nil {
		return
	}
	gui = &guiApplication{events: make(chan guiEvent, 512), outDir: filepath.Dir(exe)}
	className := u16("Sinduriel.SongBook3.NativeBuilder")
	hinst, _, _ := pGetModuleHandle.Call(0)
	icon, _, _ := pLoadIcon.Call(0, 32512)     // IDI_APPLICATION
	cursor, _, _ := pLoadCursor.Call(0, 32512) // IDC_ARROW
	wc := wndClassEx{cbSize: uint32(unsafe.Sizeof(wndClassEx{})), wndProc: syscall.NewCallback(guiWndProc), instance: hinst, icon: icon, iconSmall: icon, cursor: cursor, background: 6, className: className}
	class, _, _ := pRegisterClassEx.Call(uintptr(unsafe.Pointer(&wc)))
	if class == 0 {
		return
	}
	hwnd, _, _ := pCreateWindowEx.Call(0, uintptr(unsafe.Pointer(className)), uintptr(unsafe.Pointer(u16("SongBook3 Fast Library Builder"))),
		wsOverlappedWindow|wsVisible|wsClipChildren, 0x80000000, 0x80000000, 795, 610, 0, 0, hinst, 0)
	if hwnd == 0 {
		return
	}
	gui.hwnd = hwnd
	var m winMsg
	for {
		r, _, _ := pGetMessage.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
		if int32(r) <= 0 {
			break
		}
		pTranslateMessage.Call(uintptr(unsafe.Pointer(&m)))
		pDispatchMessage.Call(uintptr(unsafe.Pointer(&m)))
	}
}
