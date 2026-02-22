#Requires AutoHotkey v2
#SingleInstance Force
#Warn
Persistent
InstallKeybdHook
InstallMouseHook

#Include "%A_ScriptDir%\lib\IME.ahk"
#Include "%A_ScriptDir%\lib\AutoActivate.ahk"
#Include "%A_ScriptDir%\lib\Settings.ahk"

if (!A_IsCompiled) {
  TraySeticon(A_ScriptDir . "\ime-status-bar.ico")
}

IME_STATUS_GUI_BAR_WIDTH := 10
ACTIVE_ID := ""
SCREEN_DPI_RATE := A_ScreenDPI / 96 ; 4K 125% = 1.25
TIMER_PERIOD := 100 ; ms

ImeStatusBarGui := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x20")
ImeStatusBarGui.MarginX := 0
ImeStatusBarGui.MarginY := 0
LastShowImeStatusTime := 0

; Alt+Tab exclude
WinSetExStyle("+0x80", ImeStatusBarGui)

; ============================================================
; Initialize
; ============================================================

Settings_Load()

; IME Status Bar
if (CFG_ImeStatusBar)
  ImeStatusBar_Start()

; Auto Activate
AutoActivate_SetProcesses(Settings_GetProcessList())
AutoActivate_SetThreshold(CFG_MoveThreshold)
AutoActivate_SetDelay(CFG_HoverDelay)
if (CFG_AutoActivate)
  AutoActivate_Start()

; ============================================================
; Tray Menu
; ============================================================

SetupTrayMenu()

SetupTrayMenu() {
  A_TrayMenu.Delete()
  A_TrayMenu.Add("IME Status Bar", TrayToggleIme)
  A_TrayMenu.Add("Auto Activate", TrayToggleAA)
  A_TrayMenu.Add()
  A_TrayMenu.Add("Settings...", (*) => Settings_ShowGui())
  A_TrayMenu.Add()
  A_TrayMenu.Add("Reload", (*) => Reload())
  A_TrayMenu.Add("Exit", (*) => ExitApp())
  UpdateTrayChecks()
}

TrayToggleIme(*) {
  global CFG_ImeStatusBar := !CFG_ImeStatusBar
  if (CFG_ImeStatusBar)
    ImeStatusBar_Start()
  else
    ImeStatusBar_Stop()
  Settings_Save()
  UpdateTrayChecks()
}

TrayToggleAA(*) {
  global CFG_AutoActivate := !CFG_AutoActivate
  if (CFG_AutoActivate)
    AutoActivate_Start()
  else
    AutoActivate_Stop()
  Settings_Save()
  UpdateTrayChecks()
}

UpdateTrayChecks() {
  if (CFG_ImeStatusBar)
    A_TrayMenu.Check("IME Status Bar")
  else
    A_TrayMenu.Uncheck("IME Status Bar")

  if (CFG_AutoActivate)
    A_TrayMenu.Check("Auto Activate")
  else
    A_TrayMenu.Uncheck("Auto Activate")
}

; ============================================================
; IME Status Bar Start / Stop
; ============================================================

ImeStatusBar_Start() {
  SetTimer(TimerHandler, TIMER_PERIOD)
}

ImeStatusBar_Stop() {
  SetTimer(TimerHandler, 0)
  ImeStatusBarGui.Hide()
}

; ============================================================
; IME Status Bar Logic
; ============================================================

TimerHandler() {
  try {
    UpdateImeStatusBar()
  } catch TargetError {
    ; ignore
  } catch OSError {
    ; ignore
  } catch Error as err {
    MsgBox err.Message
  }
}

UpdateImeStatusBar() {
  global LastShowImeStatusTime += TIMER_PERIOD

  hwnd := WinExist("A")
  if (!hwnd || hwnd == ImeStatusBarGui.Hwnd || IME_GetSentenceMode() == 0) {
    ImeStatusBarGui.Hide()
    return
  }

  activeTitle := WinGetTitle("ahk_id " hwnd)

  activeClass := WinGetClass("ahk_id " hwnd)
  if (activeClass ~= "MultitaskingViewFrame|Shell_TrayWnd|NotifyIconOverflowWindow|Windows.UI.Core.CoreWindow|UnityWndClass|Progman") {
    ImeStatusBarGui.Hide()
    return
  }

  activeProcessName := WinGetProcessName("ahk_id " hwnd)

  WinGetPos(&imeX, &imeY, &imeWidth, &imeHeight, "ahk_id " hwnd)
  if (imeWidth >= A_ScreenWidth) {
    ImeStatusBarGui.Hide()
    return
  }

  activeId := WinGetPID("ahk_id " hwnd)
  imeGet := IME_Get("ahk_id " hwnd)
  imeGetConv := IME_GetConvMode("ahk_id " hwnd)
  activeId := activeId . "_" . imeGet . "_" . imeGetConv . "_" . imeX . "_" . imeY . "_" . imeWidth . "_" . imeHeight
  if (ACTIVE_ID != activeId || (A_TimeIdlePhysical < 5000 && !WinExist("ahk_id " ImeStatusBarGui.Hwnd))) {
    ShowImeStatusBar(imeGet, imeGetConv, imeX, imeY, imeWidth, imeHeight, activeTitle, activeClass, activeProcessName)
    global ACTIVE_ID := activeId
    LastShowImeStatusTime := 0
  } else if (LastShowImeStatusTime > 5000 && A_TimeIdlePhysical > 5000) {
    ImeStatusBarGui.Hide()
  }
}

ShowImeStatusBar(imeGet, imeGetConv, x, y, width, height, activeTitle := "", activeClass := "", activeProcessName := "") {
  if (x == "" || y == "" || width == "" || height == "") {
    return
  }

  if (x > 0) {
    x := x - IME_STATUS_GUI_BAR_WIDTH - 4
  }

  height := Floor(height / SCREEN_DPI_RATE)

  if (!(activeProcessName ~= "AutoHotkey.exe|KakaoTalk.exe|SourceTree.exe|slack.exe|Ditto.exe|EXCEL.EXE|WINWORD.EXE|Code.exe|LINE.exe")) {
    x := x + Floor(10 / SCREEN_DPI_RATE)
    height := height - Floor(8 / SCREEN_DPI_RATE)
  }

  if (imeGet = 1 && (imeGetConv = 0 || imeGetConv = 1)) { ; Korean
    ImeStatusBarGui.BackColor := "46c9e2" ; blue
  } else if (imeGet = 1 && (imeGetConv = 25 || imeGetConv = 9)) { ; Japanese
    ImeStatusBarGui.BackColor := "f10f2c" ; red
  } else if (imeGetConv = 0) { ; English on Korean
    ImeStatusBarGui.BackColor := "facf2c" ; yellow
  } else { ; English on Japanese
    ImeStatusBarGui.BackColor := "00a32c" ; green
  }

  ImeStatusBarGui.Show("x" x " y" y " w" IME_STATUS_GUI_BAR_WIDTH " h" height " NoActivate")
  WinSetExStyle("+0x80", ImeStatusBarGui)
  WinSetExStyle("+0x20", ImeStatusBarGui)
  WinSetAlwaysOnTop(1, ImeStatusBarGui)
  WinSetTransparent(100, ImeStatusBarGui)
}
