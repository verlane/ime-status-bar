#Requires AutoHotkey v2

global SETTINGS_FILE := A_ScriptDir "\settings.ini"
global CFG_ImeStatusBar := 1
global CFG_AutoActivate := 1
global CFG_MoveThreshold := 30
global CFG_HoverDelay := 100
global CFG_Processes := "cmd.exe,powershell.exe,WindowsTerminal.exe,doublecmd.exe,Code.exe,chrome.exe,idea64.exe,jetbrains_client64.exe,putty.exe,slack.exe,KakaoTalk.exe,notepad.exe,EXCEL.EXE"

; ============================================================
; INI Load / Save
; ============================================================

Settings_Load() {
    global CFG_ImeStatusBar, CFG_AutoActivate, CFG_MoveThreshold, CFG_HoverDelay, CFG_Processes

    if (!FileExist(SETTINGS_FILE)) {
        Settings_Save()
        return
    }

    CFG_ImeStatusBar := IniRead(SETTINGS_FILE, "General", "ImeStatusBar", 1)
    CFG_AutoActivate := IniRead(SETTINGS_FILE, "General", "AutoActivate", 1)
    CFG_MoveThreshold := IniRead(SETTINGS_FILE, "AutoActivate", "MoveThreshold", 30)
    CFG_HoverDelay := IniRead(SETTINGS_FILE, "AutoActivate", "HoverDelay", 100)
    CFG_Processes := IniRead(SETTINGS_FILE, "AutoActivate", "Processes", CFG_Processes)
}

Settings_Save() {
    IniWrite(CFG_ImeStatusBar, SETTINGS_FILE, "General", "ImeStatusBar")
    IniWrite(CFG_AutoActivate, SETTINGS_FILE, "General", "AutoActivate")
    IniWrite(CFG_MoveThreshold, SETTINGS_FILE, "AutoActivate", "MoveThreshold")
    IniWrite(CFG_HoverDelay, SETTINGS_FILE, "AutoActivate", "HoverDelay")
    IniWrite(CFG_Processes, SETTINGS_FILE, "AutoActivate", "Processes")
}

Settings_GetProcessList() {
    list := []
    loop parse, CFG_Processes, "," {
        trimmed := Trim(A_LoopField)
        if (trimmed != "")
            list.Push(trimmed)
    }
    return list
}

; ============================================================
; Settings GUI
; ============================================================

global SettingsGui := ""
global SettingsLV := ""
global SettingsThresholdEdit := ""
global SettingsDelayEdit := ""
global SettingsImeChk := ""
global SettingsAAChk := ""

Settings_ShowGui() {
    global SettingsGui, SettingsLV, SettingsThresholdEdit, SettingsDelayEdit
    global SettingsImeChk, SettingsAAChk

    if (SettingsGui != "") {
        try {
            SettingsGui.Show()
            return
        }
    }

    SettingsGui := Gui("+Resize -MaximizeBox", "Settings")
    SettingsGui.OnEvent("Close", (*) => SettingsGui.Hide())
    SettingsGui.OnEvent("Escape", (*) => SettingsGui.Hide())

    tab := SettingsGui.AddTab3("w460 h400", ["General", "Auto Activate"])

    ; --- Tab 1: General ---
    tab.UseTab("General")
    SettingsImeChk := SettingsGui.AddCheckbox("xm+10 y50 vImeChk", "IME Status Bar")
    SettingsImeChk.Value := CFG_ImeStatusBar
    SettingsAAChk := SettingsGui.AddCheckbox("xm+10 y80 vAAChk", "Auto Activate")
    SettingsAAChk.Value := CFG_AutoActivate

    ; --- Tab 2: Auto Activate ---
    tab.UseTab("Auto Activate")
    SettingsGui.AddText("xm+10 y50", "Processes:")
    SettingsLV := SettingsGui.AddListView("xm+10 y70 w310 h200 vProcessLV -Multi", ["Process Name"])
    SettingsLV.ModifyCol(1, 280)

    procList := Settings_GetProcessList()
    for proc in procList
        SettingsLV.Add(, proc)

    SettingsGui.AddButton("xm+330 y70 w120", "Add").OnEvent("Click", Settings_OnAdd)
    SettingsGui.AddButton("xm+330 y105 w120", "Add Running").OnEvent("Click", Settings_OnAddRunning)
    SettingsGui.AddButton("xm+330 y140 w120", "Remove").OnEvent("Click", Settings_OnRemove)

    SettingsGui.AddText("xm+10 y285", "Move Threshold:")
    SettingsThresholdEdit := SettingsGui.AddEdit("xm+120 y283 w60 vThreshold Number", CFG_MoveThreshold)
    SettingsGui.AddText("xm+190 y285", "px")

    SettingsGui.AddText("xm+10 y315", "Hover Delay:")
    SettingsDelayEdit := SettingsGui.AddEdit("xm+120 y313 w60 vDelay Number", CFG_HoverDelay)
    SettingsGui.AddText("xm+190 y315", "ms")

    ; --- Bottom buttons ---
    tab.UseTab()
    SettingsGui.AddButton("xm+270 y420 w90", "Save").OnEvent("Click", Settings_OnSave)
    SettingsGui.AddButton("xm+370 y420 w90", "Cancel").OnEvent("Click", (*) => SettingsGui.Hide())

    SettingsGui.Show("w490 h460")
}

Settings_OnAdd(*) {
    global SettingsLV
    result := InputBox("Enter process name (e.g. notepad.exe)", "Add Process", "w300 h120")
    if (result.Result = "OK" && Trim(result.Value) != "") {
        SettingsLV.Add(, Trim(result.Value))
    }
}

Settings_OnAddRunning(*) {
    global SettingsLV
    procMap := Map()
    for proc in WinGetList() {
        try {
            name := WinGetProcessName("ahk_id " proc)
            if (name != "" && !procMap.Has(name))
                procMap[name] := true
        }
    }

    procNames := []
    for name, _ in procMap
        procNames.Push(name)

    if (procNames.Length = 0) {
        MsgBox("No running processes found.", "Info")
        return
    }

    ; Build selection GUI
    selGui := Gui("+AlwaysOnTop", "Select Process")
    selGui.AddText(, "Select a process:")
    ddl := selGui.AddDropDownList("w300 vSelectedProc", procNames)
    if (procNames.Length > 0)
        ddl.Value := 1
    selGui.AddButton("w100", "OK").OnEvent("Click", (*) => Settings_AddFromDDL(selGui, ddl))
    selGui.OnEvent("Escape", (*) => selGui.Destroy())
    selGui.Show()
}

Settings_AddFromDDL(selGui, ddl) {
    global SettingsLV
    if (ddl.Value > 0) {
        SettingsLV.Add(, ddl.Text)
    }
    selGui.Destroy()
}

Settings_OnRemove(*) {
    global SettingsLV
    row := SettingsLV.GetNext(0, "Focused")
    if (row > 0)
        SettingsLV.Delete(row)
}

Settings_OnSave(*) {
    global SettingsGui, SettingsLV, SettingsThresholdEdit, SettingsDelayEdit
    global SettingsImeChk, SettingsAAChk
    global CFG_ImeStatusBar, CFG_AutoActivate, CFG_MoveThreshold, CFG_HoverDelay, CFG_Processes

    CFG_ImeStatusBar := SettingsImeChk.Value
    CFG_AutoActivate := SettingsAAChk.Value
    CFG_MoveThreshold := Integer(SettingsThresholdEdit.Value)
    CFG_HoverDelay := Integer(SettingsDelayEdit.Value)

    ; Collect processes from ListView
    procs := []
    loop SettingsLV.GetCount() {
        procs.Push(SettingsLV.GetText(A_Index))
    }

    CFG_Processes := ""
    for i, p in procs {
        CFG_Processes .= (i > 1 ? "," : "") . p
    }

    Settings_Save()
    Settings_Apply()
    SettingsGui.Hide()
}

Settings_Apply() {
    ; Apply IME Status Bar
    if (CFG_ImeStatusBar) {
        ImeStatusBar_Start()
    } else {
        ImeStatusBar_Stop()
    }

    ; Apply Auto Activate
    AutoActivate_SetProcesses(Settings_GetProcessList())
    AutoActivate_SetThreshold(CFG_MoveThreshold)
    AutoActivate_SetDelay(CFG_HoverDelay)

    if (CFG_AutoActivate) {
        if (!AutoActivate_IsRunning())
            AutoActivate_Start()
    } else {
        AutoActivate_Stop()
    }

    ; Update tray menu checks
    UpdateTrayChecks()
}
