objectdef basicCore_windowLayout
{
    variable weakref CurrentLayout
    variable bool Applied

    method Initialize()
    {
        LavishScript:RegisterEvent[On Activate]
        LavishScript:RegisterEvent[OnWindowStateChanging]
		LavishScript:RegisterEvent[OnMouseEnter]
		LavishScript:RegisterEvent[OnMouseExit]
        LavishScript:RegisterEvent[OnHotkeyFocused]

        Event[On Activate]:AttachAtom[This:OnActivate]
        Event[OnWindowStateChanging]:AttachAtom[This:OnWindowStateChanging]
		Event[OnMouseEnter]:AttachAtom[This:OnMouseEnter]
		Event[OnMouseExit]:AttachAtom[This:OnMouseExit]
        Event[OnHotkeyFocused]:AttachAtom[This:OnHotkeyFocused]

    }

    method Shutdown()
    {

    }

/*
    member:uint FindWindowLayout(string name)
    {
        return ${This.FindInArray["WindowLayout.Get[layouts]","name","${name~}"]}
    }
*/

    method ApplyJSON(jsonvalueref json)
    {
        variable uint useLayout
        variable string layoutName
        layoutName:Set["${json.Get[useLayout]~}"]
        useLayout:Set["${BasicCore.Settings.FindInArray["json.Get[layouts]","name","${layoutName~}"]}"]
        echo layoutName=${layoutName} useLayout=${useLayout}
        if !${useLayout}
        {
            CurrentLayout:SetReference[NULL]
            return
        }

        CurrentLayout:SetReference["json.Get[layouts,${useLayout}]"]

        windowcharacteristics -lock

        if !${CurrentLayout.Has[swapOnActivate]}
            CurrentLayout:SetBool[swapOnActivate,1]
        if !${CurrentLayout.Has[swapOnActivate]}
            CurrentLayout:SetBool[swapOnActivate,1]
        if !${CurrentLayout.Has[rescaleWindows]}
            CurrentLayout:SetBool[rescaleWindows,1]
        
        LGUI2.Element[basicCore.events]:FireEventHandler[OnWindowLayoutChanged]

        if ${CurrentLayout.GetBool[focusFollowsMouse]}
            FocusClick click
        else
            FocusClick eat

        This:ApplyWindowLayout[FALSE]
    }

#region events

    method OnActivate()
    {
        echo WindowLayout:OnActivate
        if ${CurrentLayout.GetBool[swapOnActivate]} && !${CurrentLayout.GetBool[focusFollowsMouse]}
            This:ApplyWindowLayout
        else
        {
            if !${Applied}
                This:ApplyWindowLayout[FALSE]
        }
    }

    method OnHotkeyFocused()
    {
        echo WindowLayout:OnHotkeyFocused
        ; if it would have been handled by SwapOnActivate, don't do it again here
        if (!${CurrentLayout.GetBool[swapOnActivate]} || ${CurrentLayout.GetBool[focusFollowsMouse]}) && ${CurrentLayout.GetBool[swapOnHotkeyFocused]}
        {
            This:ApplyWindowLayout
        }
        else
        {
            if !${Applied}
                This:ApplyWindowLayout[FALSE]
        }
    }

    method OnWindowStateChanging(string change)
    {
      ;  echo OnWindowStateChanging ${change~}
    }

    method OnMouseEnter()
    {
        This:ApplyFocusFollowMouse
    }

    method OnMouseExit()
    {

    }
#endregion

    method ApplyFocusFollowMouse()
    {
        if !${CurrentLayout.GetBool[focusFollowsMouse]}
            return

        This:FocusSelf
    }

    method FocusSelf()
    {
        if ${Display.Window.IsForeground}
        {
            windowvisibility foreground
            return
        }

        relay foreground "BasicCore.WindowLayout:FocusWindow[${Display.Window~}]"
    }

    method FocusSession(string name)
    {
        if !${Display.Window.IsForeground}
            return
        uplink focus "${name~}"
    }

    method FocusWindow(gdiwindow hWnd)
    {
        hWnd:SetForegroundWindow
    }

    method Fullscreen()
    {
        variable uint monitorWidth=${Display.Monitor.Width}
        variable uint monitorHeight=${Display.Monitor.Height}
        variable int monitorX=${Display.Monitor.Left}
        variable int monitorY=${Display.Monitor.Top}
        
        WindowCharacteristics -pos -viewable ${monitorX},${monitorY} -size -viewable ${monitorWidth}x${monitorHeight} -frame none        
    }


    method ApplyWindowLayout(bool setOtherSlots=TRUE)
    {
        if !${Display.Window(exists)}
            return

        if !${CurrentLayout.Reference(exists)}
            return

        switch ${CurrentLayout.Get[style]}
        {
            case horizontal
                This:ApplyHorizontalLayout[${setOtherSlots}]
                break
            case vertical
                This:ApplyVerticalLayout[${setOtherSlots}]
                break
            case custom            
                This:ApplyCustomLayout[${setOtherSlots}]
                break
            default
                echo "Unknown layout style: ${CurrentLayout.Get[style]~}"
                break
        }
    }

    method ApplyHorizontalLayout(bool setOtherSlots=TRUE)
    {
        echo ApplyHorizontalLayout ${setOtherSlots}

        variable jsonvalueref Slots="JMB.Slots"

        variable uint monitorWidth=${Display.Monitor.Width}
        variable uint monitorHeight=${Display.Monitor.Height}
        variable int monitorX=${Display.Monitor.Left}
        variable int monitorY=${Display.Monitor.Top}

        variable uint mainHeight
        variable uint numSmallRegions=${Slots.Used}
        variable uint mainWidth
        variable uint smallHeight
        variable uint smallWidth
        variable string stealthFlag

        if ${CurrentLayout.GetBool[rescaleWindows]}
            stealthFlag:Set["-stealth "]

        if ${CurrentLayout.GetBool[avoidTaskbar]}
        {
            monitorX:Set["${Display.Monitor.MaximizeLeft}"]
            monitorY:Set["${Display.Monitor.MaximizeTop}"]
            monitorWidth:Set["${Display.Monitor.MaximizeWidth}"]
            monitorHeight:Set["${Display.Monitor.MaximizeHeight}"]
        }


        ; if there's only 1 window, just go full screen windowed
        if ${numSmallRegions}==1
        {
            WindowCharacteristics -pos -viewable ${monitorX},${monitorY} -size -viewable ${monitorWidth}x${monitorHeight} -frame none
            Applied:Set[1]
            return
        }

        if !${CurrentLayout.GetBool[leaveHole]}
            numSmallRegions:Dec

        ; 2 windows is actually a 50/50 split screen and should probably handle differently..., pretend there's 3
        if ${numSmallRegions}<3
            numSmallRegions:Set[3]

        mainWidth:Set["${monitorWidth}"]
        mainHeight:Set["${monitorHeight}*${numSmallRegions}/(${numSmallRegions}+1)"]

        smallHeight:Set["${monitorHeight}-${mainHeight}"]
        smallWidth:Set["${monitorWidth}/${numSmallRegions}"]

        WindowCharacteristics -pos -viewable ${monitorX},${monitorY} -size -viewable ${mainWidth}x${mainHeight} -frame none
        Applied:Set[1]

        if !${setOtherSlots}
            return

        variable int useX
        variable uint numSlot

        variable uint slotID

        for (numSlot:Set[1] ; ${numSlot}<=${Slots.Used} ; numSlot:Inc)
        {
            slotID:Set["${Slots[${numSlot}].Get[id]~}"]
            if ${slotID}!=${JMB.Slot}
            {
                relay jmb${slotID} "WindowCharacteristics ${stealthFlag}-pos -viewable ${useX},${mainHeight} -size -viewable ${smallWidth}x${smallHeight} -frame none"
                useX:Inc["${smallWidth}"]
            }
            else
            {
                if ${CurrentLayout.GetBool[leaveHole]}
                    useX:Inc["${smallWidth}"]
            }
            
        }
    }

    method ApplyVerticalLayout(bool setOtherSlots=TRUE)
    {
        variable jsonvalueref Slots="JMB.Slots"

        variable uint monitorWidth=${Display.Monitor.Width}
        variable uint monitorHeight=${Display.Monitor.Height}
        variable int monitorX=${Display.Monitor.Left}
        variable int monitorY=${Display.Monitor.Top}

        variable uint mainHeight
        variable uint numSmallRegions=${Slots.Used}
        variable uint mainWidth
        variable uint smallHeight
        variable uint smallWidth
        variable string stealthFlag

        if ${CurrentLayout.GetBool[rescaleWindows]}
            stealthFlag:Set["-stealth "]

        if ${CurrentLayout.GetBool[avoidTaskbar]}
        {
            monitorX:Set["${Display.Monitor.MaximizeLeft}"]
            monitorY:Set["${Display.Monitor.MaximizeTop}"]
            monitorWidth:Set["${Display.Monitor.MaximizeWidth}"]
            monitorHeight:Set["${Display.Monitor.MaximizeHeight}"]
        }


        ; if there's only 1 window, just go full screen windowed
        if ${numSmallRegions}==1
        {
            WindowCharacteristics -pos -viewable ${monitorX},${monitorY} -size -viewable ${monitorWidth}x${monitorHeight} -frame none
            Applied:Set[1]
            return
        }

        if !${CurrentLayout.GetBool[leaveHole]}
            numSmallRegions:Dec

        ; 2 windows is actually a 50/50 split screen and should probably handle differently..., pretend there's 3
        if ${numSmallRegions}<3
            numSmallRegions:Set[3]

        mainHeight:Set["${monitorHeight}"]
        mainWidth:Set["${monitorWidth}*${numSmallRegions}/(${numSmallRegions}+1)"]

        smallWidth:Set["${monitorWidth}-${mainWidth}"]
        smallHeight:Set["${monitorHeight}/${numSmallRegions}"]

        WindowCharacteristics -pos -viewable ${monitorX},${monitorY} -size -viewable ${mainWidth}x${mainHeight} -frame none
        Applied:Set[1]

        if !${setOtherSlots}
            return

        variable int useY
        variable uint numSlot

        variable uint slotID

        for (numSlot:Set[1] ; ${numSlot}<=${Slots.Used} ; numSlot:Inc)
        {
            slotID:Set["${Slots[${numSlot}].Get[id]~}"]
            if ${slotID}!=${JMB.Slot}
            {
                relay jmb${slotID} "WindowCharacteristics ${stealthFlag}-pos -viewable ${mainWidth},${useY} -size -viewable ${smallWidth}x${smallHeight} -frame none"
                useY:Inc["${smallHeight}"]
            }
            else
            {
                if ${CurrentLayout.GetBool[leaveHole]}
                    useY:Inc["${smallHeight}"]
            }
            
        }
    }

    method ApplyCustomLayout(bool setOtherSlots=TRUE)
    {
        variable jsonvalueref Slots="JMB.Slots"

        variable uint numSmallRegions=${Slots.Used}

        variable uint mainHeight=${CurrentLayout.Get[mainRegion,height]}
        variable uint mainWidth=${CurrentLayout.Get[mainRegion,width]}
        variable int mainX=${CurrentLayout.Get[mainRegion,x]}
        variable int mainY=${CurrentLayout.Get[mainRegion,y]}

        variable string stealthFlag

        if ${CurrentLayout.GetBool[rescaleWindows]}
            stealthFlag:Set["-stealth "]

        WindowCharacteristics -pos -viewable ${mainX},${mainY} -size -viewable ${mainWidth}x${mainHeight} -frame none
        Applied:Set[1]

        if !${CurrentLayout.GetBool[leaveHole]}
            numSmallRegions:Dec

        if !${setOtherSlots} || !${numSmallRegions}
            return

        variable uint numSlot
        variable uint numSmallRegion=1

        variable uint slotID

        variable int smallX
        variable int smallY
        variable uint smallWidth
        variable uint smallHeight

        for (numSlot:Set[1] ; ${numSlot}<=${Slots.Used} ; numSlot:Inc)
        {
            slotID:Set["${Slots[${numSlot}].Get[id]~}"]
            if ${slotID}!=${JMB.Slot}
            {
                smallX:Set["${CurrentLayout.Get[regions,${numSmallRegion},x]~}"]
                smallY:Set["${CurrentLayout.Get[regions,${numSmallRegion},y]~}"]
                smallWidth:Set["${CurrentLayout.Get[regions,${numSmallRegion},width]~}"]
                smallHeight:Set["${CurrentLayout.Get[regions,${numSmallRegion},height]~}"]

                if ${smallWidth} && ${smallHeight}
                {
                    if ${smallWidth}==${mainWidth} && ${smallHeight}==${mainHeight}
                        relay jmb${slotID} "WindowCharacteristics -pos -viewable ${smallX},${smallY} -size -viewable ${smallWidth}x${smallHeight} -frame none"
                    else
                        relay jmb${slotID} "WindowCharacteristics ${stealthFlag}-pos -viewable ${smallX},${smallY} -size -viewable ${smallWidth}x${smallHeight} -frame none"
                }

                numSmallRegion:Inc
            }
            else
            {
                if ${CurrentLayout.GetBool[leaveHole]}
                   numSmallRegion:Inc
            }
            
        }
        
    }
}