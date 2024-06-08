; IME.ahk ( eamat http://www6.atwiki.jp/eamat/ ) for AutoHotkey V2
; For Windows 11 old Microsoft IME
;
; if (IME_GET() = 1 && (IME_GetConvMode() = 0 || IME_GetConvMode() = 1)) { ; Korean
; } else if (IME_GET() = 1 && (IME_GetConvMode() = 25 || IME_GetConvMode() = 9)) { ; Japanese
; } else if (IME_GetConvMode() = 0) { ; English on Korean
; } else { ; English on Japanese
; }
; if (IME_GetSentenceMode() = 0) { ; not input mode
; }

imm32 := DllCall("LoadLibrary", "Str", "imm32.dll", "Ptr")

IME_GET(winTitle := "A") {
  return IME_Status(0x0005, winTitle)
}

IME_GetConvMode(winTitle := "A") {
  return IME_Status(0x001, winTitle)
}

IME_GetSentenceMode(winTitle := "A") {
  return IME_Status(0x003, winTitle)
}

IME_GETConverting() {
  return DllCall("Imm32\ImmGetOpenStatus")
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
