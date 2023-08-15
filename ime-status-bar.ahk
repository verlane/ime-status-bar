#Requires AutoHotkey v2
#SingleInstance Force
#Warn
Persistent
InstallKeybdHook
InstallMouseHook

#Include "%A_ScriptDir%\lib\IME.ahk"

IME_STATUS_GUI_BAR_WIDTH := 10
ACTIVE_ID := ""
SCREEN_DPI_RATE := A_ScreenDPI / 96 ; 4K 125% = 1.25

GUI_OPT := "+Owner -Caption +AlwaysOnTop -Border"
ImeStatusBarGui := Gui(GUI_OPT)
ImeStatusBarGui.MarginX := 0
ImeStatusBarGui.MarginY := 0

SetTimer(TimerHandler, 10)

TimerHandler() {
  try {
    UpdateImeStatusBar()
  } catch TargetError {
    ; ignore Error
  } catch OSError {
    ; ignore Error
  } catch Error as err {
    MsgBox err.Message
  }
}

UpdateImeStatusBar() {
  hwnd := WinExist("A")
  if (!hwnd) {
    return
  }

  activeTitle := WinGetTitle("ahk_id " hwnd)
  if (activeTitle == "" || activeTitle ~= "ファイルの削除" || activeTitle ~= "BSB Pomodoro Timer") {
    ImeStatusBarGui.Hide()
    return
  }

  activeClass := WinGetClass("ahk_id " hwnd)
  if (activeClass ~= "MultitaskingViewFrame|Shell_TrayWnd|NotifyIconOverflowWindow|Windows.UI.Core.CoreWindow|UnityWndClass|Progman") { ; check process with regex
    ImeStatusBarGui.Hide()
    return
  }

  activeProcessName := WinGetProcessName("ahk_id " hwnd)
  if (activeProcessName ~= "PotPlayerMini64.exe|PotPlayer64.exe|ShareX.exe|StarCraft.exe") { ; check process with regex
    ImeStatusBarGui.Hide()
    return
  }

  WinGetPos(&imeX, &imeY, &imeWidth, &imeHeight, "ahk_id " hwnd) ; x, y, width, height 가 중복되기때문에 변수명을 변경
  if (imeWidth >= A_ScreenWidth) { ; 크롬 전체화면시 비표시(유튜브용)
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
  } else if (A_TimeIdlePhysical > 5000) {
    ImeStatusBarGui.Hide()
  }
}

ShowImeStatusBar(imeGet, imeGetConv, x, y, width, height, activeTitle := "", activeClass := "", activeProcessName := "") {
  if (x == "" || y == "" || width == "" || height == "") {
    return
  }

  x := x - IME_STATUS_GUI_BAR_WIDTH - 4
  height := Floor(height / SCREEN_DPI_RATE) ; sCREEN_DPI_RATE 100% = 1.0

  ; 표시 위치 조정
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

  ImeStatusBarGui.Opt(GUI_OPT)
  ImeStatusBarGui.Show("x" x " y" y " w" IME_STATUS_GUI_BAR_WIDTH " h" height " NoActivate")
  WinSetExStyle(+0x20, ImeStatusBarGui) ; not clickable (toggle)
  WinSetTransparent(100, ImeStatusBarGui)
}