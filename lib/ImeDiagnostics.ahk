; ImeDiagnostics.ahk - Real-time IME state diagnostic GUI

global DiagGui := ""
global DiagTimer := 0
global DiagLastData := ""

ImeDiagnostics_Show() {
    global DiagGui, DiagTimer

    if (DiagGui != "") {
        try {
            DiagGui.Show()
            SetTimer(ImeDiagnostics_Update, 500)
            return
        }
    }

    DiagGui := Gui("+AlwaysOnTop", "IME Diagnostics")
    DiagGui.OnEvent("Close", ImeDiagnostics_Close)
    DiagGui.OnEvent("Escape", ImeDiagnostics_Close)

    DiagGui.AddText("w360", "Active window IME state (updates every 500ms)")
    DiagGui.AddText("xm y+10", "Language:")
    DiagGui.Add("Text", "xm+120 yp vLang w200", "...")
    DiagGui.AddText("xm y+8", "LANGID:")
    DiagGui.Add("Text", "xm+120 yp vLangId w200", "...")
    DiagGui.AddText("xm y+8", "IME Name:")
    DiagGui.Add("Text", "xm+120 yp vImeName w200", "...")
    DiagGui.AddText("xm y+8", "IME File:")
    DiagGui.Add("Text", "xm+120 yp vImeFile w200", "...")
    DiagGui.AddText("xm y+8", "isComposing:")
    DiagGui.Add("Text", "xm+120 yp vComposing w200", "...")
    DiagGui.AddText("xm y+8", "ImmOpenStatus:")
    DiagGui.Add("Text", "xm+120 yp vImmOpen w200", "...")
    DiagGui.AddText("xm y+8", "WM283 OpenStatus:")
    DiagGui.Add("Text", "xm+120 yp vWm283Open w200", "...")
    DiagGui.AddText("xm y+8", "WM283 ConvMode:")
    DiagGui.Add("Text", "xm+120 yp vWm283Conv w200", "...")
    DiagGui.AddText("xm y+8", "WM283 SentMode:")
    DiagGui.Add("Text", "xm+120 yp vWm283Sent w200", "...")
    DiagGui.AddText("xm y+8", "HWND:")
    DiagGui.Add("Text", "xm+120 yp vHwnd w200", "...")
    DiagGui.AddText("xm y+8", "Root HWND:")
    DiagGui.Add("Text", "xm+120 yp vRootHwnd w200", "...")

    DiagGui.AddButton("xm y+12 w100", "Copy to Clipboard").OnEvent("Click", ImeDiagnostics_Copy)

    DiagGui.Show("w380")
    SetTimer(ImeDiagnostics_Update, 500)
}

ImeDiagnostics_Update() {
    global DiagGui, DiagLastData
    if (!DiagGui)
        return

    try {
        d := ImeDetector_GetDiagnostics("A")
        DiagLastData := d
        DiagGui["Lang"].Value      := d.language
        DiagGui["LangId"].Value    := d.langId
        DiagGui["ImeName"].Value   := d.imeName
        DiagGui["ImeFile"].Value   := d.imeFileName
        DiagGui["Composing"].Value := d.isComposing ? "true" : "false"
        DiagGui["ImmOpen"].Value   := d.immOpenStatus
        DiagGui["Wm283Open"].Value := d.wm283OpenStatus
        DiagGui["Wm283Conv"].Value := d.wm283ConvMode
        DiagGui["Wm283Sent"].Value := d.wm283SentMode
        DiagGui["Hwnd"].Value     := Format("0x{:X}", d.hwnd)
        DiagGui["RootHwnd"].Value := Format("0x{:X}", d.rootHwnd)
    } catch {
    }
}

ImeDiagnostics_Copy(*) {
    global DiagLastData, DiagGui
    try {
        d := DiagLastData
        if (!d)
            return
        text := "Language: " d.language "`n"
            . "LANGID: " d.langId "`n"
            . "IME Name: " d.imeName "`n"
            . "IME File: " d.imeFileName "`n"
            . "isComposing: " DiagGui["Composing"].Value "`n"
            . "ImmOpenStatus: " d.immOpenStatus "`n"
            . "WM283 OpenStatus: " d.wm283OpenStatus "`n"
            . "WM283 ConvMode: " d.wm283ConvMode "`n"
            . "WM283 SentMode: " d.wm283SentMode "`n"
            . "HWND: " Format("0x{:X}", d.hwnd) "`n"
            . "Root HWND: " Format("0x{:X}", d.rootHwnd)
        A_Clipboard := text
        ToolTip("Copied!")
        SetTimer(() => ToolTip(), -1500)
    } catch {
    }
}

ImeDiagnostics_Close(*) {
    global DiagGui
    SetTimer(ImeDiagnostics_Update, 0)
    DiagGui.Hide()
}
