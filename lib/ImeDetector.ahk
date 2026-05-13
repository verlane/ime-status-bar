; ImeDetector.ahk - HKL-based IME state detection supporting both old and new Microsoft IME

global LANGID_KOREAN  := 0x0412
global LANGID_JAPANESE := 0x0411

; Returns { language: "ko"|"ja"|"other", isComposing: bool }
ImeDetector_GetState(winTitle := "A") {
    hwnd := ImeDetector_GetFocusedHwnd(winTitle)
    if (!hwnd)
        return { language: "other", isComposing: false }

    language := ImeDetector_GetLanguage(hwnd)
    if (language == "other")
        return { language: "other", isComposing: false }

    isComposing := ImeDetector_IsImeOpen(hwnd, language)
    return { language: language, isComposing: isComposing }
}

ImeDetector_GetFocusedHwnd(winTitle := "A") {
    temp := A_DetectHiddenWindows
    DetectHiddenWindows(True)
    hwnd := 0
    try {
        focusedControl := ControlGetFocus(winTitle)
        if (focusedControl != "") {
            try hwnd := ControlGetHwnd(focusedControl, winTitle)
        }
        if (!hwnd)
            hwnd := WinExist(winTitle)
    } catch {
        try {
            hwnd := WinExist(winTitle)
        } catch {
        }
    } finally {
        DetectHiddenWindows(temp)
    }
    return hwnd
}

ImeDetector_GetLangId(hwnd) {
    threadId := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    hkl := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
    return hkl & 0xFFFF
}

ImeDetector_GetLanguage(hwnd) {
    langId := ImeDetector_GetLangId(hwnd)
    if (langId == LANGID_KOREAN)
        return "ko"
    if (langId == LANGID_JAPANESE)
        return "ja"
    return "other"
}

ImeDetector_IsImeOpen(hwnd, language) {
    if (language == "ko") {
        ; Korean Microsoft IME: observed states:
        ; - English mode: OpenStatus=0 (definitive), or ConvMode=0/9
        ; - Hangul input: OpenStatus=1 AND ConvMode != 0/9 (e.g. 1, 65535)
        openStatus := ImeDetector_GetOpenStatus(hwnd)
        convMode := ImeDetector_GetConvMode(hwnd)
        return openStatus != 0 && convMode != 0 && convMode != 9
    }

    if (language == "ja" && ImeDetector_IsGoogleIme()) {
        ; Google IME Japanese: ConvMode is always 9 regardless of mode.
        ; OpenStatus (wParam=0x0005) is the only reliable on/off signal.
        return ImeDetector_GetOpenStatus(hwnd) != 0
    }

    ; MS IME Japanese: ConvMode=0 means ENG, non-zero means active input
    return ImeDetector_GetConvMode(hwnd) != 0
}

ImeDetector_GetOpenStatus(hwnd) {
    temp := A_DetectHiddenWindows
    DetectHiddenWindows(True)
    try {
        hIME := ImeDetector_FindImeWindow(hwnd)
        if (hIME)
            return SendMessage(0x0283, 0x0005, 0, , "ahk_id " hIME)
    } finally {
        DetectHiddenWindows(temp)
    }
    return 0
}

; ImmGetDefaultIMEWnd returns 0 for TSF-native controls (e.g. Chrome renderer).
; Walk up to root window which usually has a valid IME window association.
ImeDetector_FindImeWindow(hwnd) {
    hIME := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if (hIME)
        return hIME

    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")  ; GA_ROOT = 2
    if (root && root != hwnd)
        return DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", root, "Ptr")

    return 0
}

ImeDetector_GetConvMode(hwnd) {
    temp := A_DetectHiddenWindows
    DetectHiddenWindows(True)
    try {
        hIME := ImeDetector_FindImeWindow(hwnd)
        if (hIME)
            return SendMessage(0x0283, 0x0001, 0, , "ahk_id " hIME)
    } finally {
        DetectHiddenWindows(temp)
    }
    return 0
}

; Google IME is TSF-based: ImmGetIMEFileName returns empty, detect by process instead.
; Cached every 10s to avoid frequent ProcessExist calls on each 100ms timer tick.
ImeDetector_IsGoogleIme() {
    static cached := false
    static lastCheck := 0
    if (A_TickCount - lastCheck > 10000) {
        cached := ProcessExist("GoogleIMEJaConverter.exe") != 0
        lastCheck := A_TickCount
    }
    return cached
}

ImeDetector_GetImeFileName(hwnd) {
    threadId := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    hkl := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
    buf := Buffer(520, 0)
    DllCall("imm32\ImmGetIMEFileName", "Ptr", hkl, "Ptr", buf, "UInt", 260, "UInt")
    return StrGet(buf)
}

ImeDetector_GetImeName(hwnd) {
    language := ImeDetector_GetLanguage(hwnd)
    if (language == "ja" && ImeDetector_IsGoogleIme())
        return "Google IME"
    fileName := ImeDetector_GetImeFileName(hwnd)
    if (fileName != "")
        return "MS IME (" fileName ")"
    return "MS IME (TSF)"
}

; Diagnostic: returns a map of raw values for debugging
ImeDetector_GetDiagnostics(winTitle := "A") {
    hwnd := ImeDetector_GetFocusedHwnd(winTitle)
    if (!hwnd)
        return { hwnd: 0, rootHwnd: 0, langId: "0x0000", language: "none",
                 imeName: "", imeFileName: "", immOpenStatus: 0,
                 wm283OpenStatus: 0, wm283ConvMode: 0, wm283SentMode: 0 }

    langId      := ImeDetector_GetLangId(hwnd)
    language    := ImeDetector_GetLanguage(hwnd)
    imeName     := ImeDetector_GetImeName(hwnd)
    imeFileName := ImeDetector_GetImeFileName(hwnd)
    isComposing := ImeDetector_IsImeOpen(hwnd, language)

    root := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    if (!root)
        root := hwnd

    immOpenStatus := 0
    wm283OpenStatus := 0
    wm283ConvMode := 0
    wm283SentMode := 0

    try {
        himc := DllCall("imm32\ImmGetContext", "Ptr", hwnd, "Ptr")
        if (himc) {
            immOpenStatus := DllCall("imm32\ImmGetOpenStatus", "Ptr", himc, "Int")
            DllCall("imm32\ImmReleaseContext", "Ptr", hwnd, "Ptr", himc)
        }
    } catch {
    }

    try {
        temp := A_DetectHiddenWindows
        DetectHiddenWindows(True)
        hIME := ImeDetector_FindImeWindow(hwnd)
        if (hIME) {
            wm283OpenStatus := SendMessage(0x0283, 0x0005, 0, , "ahk_id " hIME)
            wm283ConvMode   := SendMessage(0x0283, 0x0001, 0, , "ahk_id " hIME)
            wm283SentMode   := SendMessage(0x0283, 0x0003, 0, , "ahk_id " hIME)
        }
        DetectHiddenWindows(temp)
    } catch {
    }

    return {
        hwnd: hwnd,
        rootHwnd: root,
        langId: Format("0x{:04X}", langId),
        language: language,
        isComposing: isComposing,
        imeName: imeName,
        imeFileName: imeFileName,
        immOpenStatus: immOpenStatus,
        wm283OpenStatus: wm283OpenStatus,
        wm283ConvMode: wm283ConvMode,
        wm283SentMode: wm283SentMode
    }
}
