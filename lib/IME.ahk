; IME.ahk ( eamat http://www6.atwiki.jp/eamat/ ) for AutoHotkey V2
; For Windows 11 old Microsoft IME
;
; if (imeGet = 1 && (imeGetConv = 0 || imeGetConv = 1)) { ; Korean
; } else if (imeGet = 1 && (imeGetConv = 25 || imeGetConv = 9)) { ; Japanese
; } else if (imeGetConv = 0) { ; English on Korean
; } else { ; English on Japanese
; }

imm32 := DllCall("LoadLibrary", "Str", "imm32.dll", "Ptr")

IME_GET(winTitle := "A") {
  return IME_Status(0x0005, winTitle)
}

IME_GetConvMode(winTitle := "A") {
  return IME_Status(0x001, winTitle)
}

IME_Status(wParam, winTitle := "A") {
  temp := A_DetectHiddenWindows
  DetectHiddenWindows(True)

  try {
    hwnd := ControlGetFocus(winTitle)
    if (!hwnd) {
      hwnd := WinExist(winTitle)
    }
    hIME := DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", hwnd, "UInt")
    result := SendMessage(0x0283, wParam, 0x0000, , "ahk_id " hIME)
  } catch Error as err {
    return 0
  } finally {
    DetectHiddenWindows(temp)
  }

  return result
}