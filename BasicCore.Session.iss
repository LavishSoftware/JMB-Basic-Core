#include "BasicCore.Common.iss"

objectdef basicCore
{
    variable basicCore_settings Settings

    method Initialize()
    {
        LGUI2:LoadPackageFile[BasicCore.Session.lgui2Package.json]
    }

    method Shutdown()
    {
        LGUI2:UnloadPackageFile[BasicCore.Session.lgui2Package.json]
    }
}

objectdef basicCore_highlighter
{
    method Initialize()
    {
    }

    method Shutdown()
    {
        This:Disable
    }

    method Enable()
    {
        LavishScript:RegisterEvent[OnFrame]
        Event[OnFrame]:AttachAtom[This:OnFrame]
    }

    method Disable()
    {
        Event[OnFrame]:DetachAtom[This:OnFrame]

        LGUI2.Element[basicCore.highlighter.border]:SetVisibility[Hidden]
        LGUI2.Element[basicCore.highlighter.number]:SetVisibility[Hidden]
    }

    member:bool IsFullSize()
    {
        if ${Display.ViewableWidth}!=${Display.Width}
            return FALSE
        if ${Display.ViewableHeight}!=${Display.Height}
            return FALSE
        return TRUE
    }

    method OnFrame()
    {
        if ${Display.Window.IsForeground}
        {
            if !${BasicCore.Settings.Highlighter.GetBool[showBorder]} || (${This.IsFullSize} && !${BasicCore.Settings.Highlighter.GetBool[highlightFullSize]})
                LGUI2.Element[basicCore.highlighter.border]:SetVisibility[Hidden]
            else
                LGUI2.Element[basicCore.highlighter.border]:SetVisibility[Visible]


            LGUI2.Element[basicCore.highlighter.number]:SetVisibility[Hidden]
        }
        else
        {
            LGUI2.Element[basicCore.highlighter.border]:SetVisibility[Hidden]

            if ${BasicCore.Settings.Highlighter.GetBool[showNumber]}
                LGUI2.Element[basicCore.highlighter.number]:SetVisibility[Visible]
            else
                LGUI2.Element[basicCore.highlighter.number]:SetVisibility[Hidden]
        }        
    }
}

objectdef basicCore_performance
{    
    method ApplyMaxFPS(string prefix, jsonvalueref json)
    {
        variable string useLine="${prefix~}"
        if ${json.Has[maxFPS]}
            useLine:Concat[" ${json.GetInteger[maxFPS]~}"]

        if ${json.Has[calculate]}
        {
            if ${json.GetBool[calculate]}
                useLine:Concat[" -calculate"]
            else
                useLine:Concat[" -absolute"]
        }
    }

    method ApplyJSON(jsonvalueref json)
    {
        if ${json.Has[lockAffinity]}
        {
            if ${json.GetBool[lockAffinity]}
                proclock on
            else
                proclock off
        }

        if ${json.Get[background].Type.Equal[object]}
        {
            This:ApplyMaxFPS["-bg","json.Get[background]"]
        }
        if ${json.Get[foreground].Type.Equal[object]}
        {
            This:ApplyMaxFPS["-fg","json.Get[foreground]"]
        }
    }
}

objectdef basicCore_windowSwitching
{
    variable string useGlobalHotkey
    variable bool HotkeyInstalled
    variable uint NumSlotHotkeys

    method Initialize()
    {
        LavishScript:RegisterEvent[On3DReset]
        LavishScript:RegisterEvent[OnHotkeyFocused]
        Event[On3DReset]:AttachAtom[This:On3DReset]        
    }

    method Shutdown()
    {
        Event[On3DReset]:DetachAtom[This:On3DReset]

        This:ClearHotkeys
    }
    
    method ClearHotkeys()
    {
        squelch globalbind -delete focus

        LGUI2:RemoveBinding[basicCore.NextWindow]
        LGUI2:RemoveBinding[basicCore.PreviousWindow]
; NumSlotHotkeys
        
        variable uint i
        for (i:Set[1] ; ${i}<=${NumSlotHotkeys} ; i:Inc)
        {
            LGUI2:RemoveBinding["basicCore.Slot${i}"]
        }
    }

    method InstallGlobalHotkey()
    {
        if ${HotkeyInstalled} || !${useGlobalHotkey.NotNULLOrEmpty}
            return
        
        HotkeyInstalled:Set[1]
        
        globalbind "focus" "${useGlobalHotkey~}" "BasicCore.WindowSwitching:OnGlobalHotkey"
    }

    method SetSlotHotkey(uint numSlot, string useHotkey)
    {
        echo "SetSlotHotkey ${numSlot}: ${useHotkey~}"
        This:InstallHotkey[basicCore.Slot${numSlot},"${useHotkey~}","BasicCore.WindowSwitching:OnSlotHotkey[${numSlot}]"]
    }

    method ApplyJSON(jsonvalueref json)
    {
        This:ClearHotkeys

        if ${json.GetBool[globalSwitchingHotkeys]}
        {
            if ${JMB.Slot}>0 && ${JMB.Slot}<=${json.Get[slotHotkeys].Used}
            {
                useGlobalHotkey:Set["${json.Get[slotHotkeys,${JMB.Slot}]~}"]
            }
            This:InstallGlobalHotkey
        }
        else
        {
            json.Get[slotHotkeys]:ForEach["This:SetSlotHotkey[\"\${ForEach.Key~}\",\"\${ForEach.Value~}\"]"]
        }

        if ${json.Has[previousWindow]}
            This:InstallHotkey[basicCore.PreviousWindow,"${json.Get[previousWindow]~}","BasicCore.WindowSwitching:PreviousWindow"]
        if ${json.Has[nextWindow]}
            This:InstallHotkey[basicCore.NextWindow,"${json.Get[nextWindow]~}","BasicCore.WindowSwitching:NextWindow"]
    }

    method On3DReset()
    {
        HotkeyInstalled:Set[0]
        squelch globalbind -delete focus
        This:InstallGlobalHotkey
    }

    method OnGlobalHotkey()
    {
        windowvisibility foreground
        Event[OnHotkeyFocused]:Execute
    }

    ; Installs a Hotkey, given a name, a key combination, and LavishScript code to execute on PRESS
    method InstallHotkey(string name, string keyCombo, string methodName)
    {
        variable jsonvalue joBinding
        ; initialize a LGUI2 input binding object with JSON
        joBinding:SetValue["$$>
        {
            "name":${name.AsJSON~},
            "combo":${keyCombo.AsJSON~},
            "eventHandler":{
                "type":"task",
                "taskManager":"basicCore",
                "task":{
                    "type":"ls1.code",
                    "start":${methodName.AsJSON~}
                }
            }
        }
        <$$"]

        ; now add the binding to LGUI2!
        LGUI2:AddBinding["${joBinding.AsJSON~}"]
    }

    member:uint GetNextSlot()
    {
        variable uint Slot=${JMB.Slot}
        if !${Slot}
            return 0

        Slot:Inc
        if ${Slot}>${JMB.Slots.Used}
            return 1

        return ${Slot}
    }

    member:uint GetPreviousSlot()
    {
        variable uint Slot=${JMB.Slot}
        if !${Slot}
            return 0

        Slot:Dec
        if !${Slot}
            return ${JMB.Slots.Used}

        return ${Slot}
    }

    method PreviousWindow()
    {
        variable uint previousSlot=${This.GetPreviousSlot}
        if !${previousSlot}
            return

        if !${Display.Window.IsForeground}
            return

        uplink focus "jmb${previousSlot}"
        relay "jmb${previousSlot}" "Event[OnHotkeyFocused]:Execute"
    }

    method NextWindow()
    {
        variable uint nextSlot=${This.GetNextSlot}
        if !${nextSlot}
            return

        if !${Display.Window.IsForeground}
            return

        uplink focus "jmb${nextSlot}"
        relay "jmb${nextSlot}" "Event[OnHotkeyFocused]:Execute"
    }

    method OnSlotHotkey(uint numSlot)
    {
        uplink focus "jmb${numSlot}"
        relay "jmb${numSlot}" "Event[OnHotkeyFocused]:Execute"
    }

}

variable(global) basicCore BasicCore

function main()
{
    while 1
        waitframe
}