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

variable(global) basicCore BasicCore

function main()
{
    while 1
        waitframe
}