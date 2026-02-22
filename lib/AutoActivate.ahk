#Requires AutoHotkey v2

global AA_TargetProcesses := []
global AA_LastMouseX := 0
global AA_LastMouseY := 0
global AA_AnchorX := 0
global AA_AnchorY := 0
global AA_AnchorHwnd := 0
global AA_HoverStartTime := 0
global AA_ReadyToActivate := false
global AA_MoveThreshold := 30
global AA_HoverDelay := 100
global AA_Running := false

AutoActivate_Start() {
    global AA_Running := true
    CoordMode("Mouse", "Screen")
    SetTimer(AA_CheckMouseHover, AA_HoverDelay)
    Hotkey("~LButton", AA_OnClick)
    Hotkey("~RButton", AA_OnClick)
    Hotkey("~MButton", AA_OnClick)
}

AutoActivate_Stop() {
    global AA_Running := false
    SetTimer(AA_CheckMouseHover, 0)
    Hotkey("~LButton", AA_OnClick, "Off")
    Hotkey("~RButton", AA_OnClick, "Off")
    Hotkey("~MButton", AA_OnClick, "Off")
}

AutoActivate_IsRunning() {
    return AA_Running
}

AutoActivate_SetProcesses(list) {
    global AA_TargetProcesses := list
}

AutoActivate_SetThreshold(val) {
    global AA_MoveThreshold := val
}

AutoActivate_SetDelay(val) {
    global AA_HoverDelay := val
}

AA_OnClick(*) {
    global AA_ReadyToActivate, AA_AnchorX, AA_AnchorY, AA_AnchorHwnd
    MouseGetPos(&x, &y, &hwnd)
    AA_ReadyToActivate := false
    AA_AnchorX := x
    AA_AnchorY := y
    if (hwnd)
        AA_AnchorHwnd := hwnd
}

AA_CheckMouseHover() {
    global AA_TargetProcesses, AA_LastMouseX, AA_LastMouseY
    global AA_AnchorX, AA_AnchorY, AA_AnchorHwnd
    global AA_HoverStartTime, AA_ReadyToActivate, AA_MoveThreshold, AA_HoverDelay

    MouseGetPos(&x, &y, &hwnd)

    if (!hwnd)
        return

    ; Mouse moved
    if (x != AA_LastMouseX || y != AA_LastMouseY) {
        AA_LastMouseX := x
        AA_LastMouseY := y
        AA_HoverStartTime := 0

        dist := Sqrt((x - AA_AnchorX) ** 2 + (y - AA_AnchorY) ** 2)
        if (dist >= AA_MoveThreshold && hwnd != AA_AnchorHwnd)
            AA_ReadyToActivate := true

        return
    }

    if (!AA_ReadyToActivate)
        return

    if (AA_HoverStartTime = 0) {
        AA_HoverStartTime := A_TickCount
        return
    }

    if (A_TickCount - AA_HoverStartTime < AA_HoverDelay)
        return

    try {
        if (hwnd = WinGetID("A")) {
            AA_ReadyToActivate := false
            return
        }
    } catch {
        return
    }

    try {
        processName := WinGetProcessName(hwnd)

        for target in AA_TargetProcesses {
            if (processName = target) {
                ; Skip popup/menu windows (no title = bookmark menu, dropdown, etc.)
                if (WinGetTitle(hwnd) = "" && processName = WinGetProcessName("A")) {
                    AA_ReadyToActivate := false
                    return
                }
                WinActivate(hwnd)
                AA_ReadyToActivate := false
                AA_AnchorX := AA_LastMouseX
                AA_AnchorY := AA_LastMouseY
                AA_AnchorHwnd := hwnd
                return
            }
        }
    }

    AA_ReadyToActivate := false
}
