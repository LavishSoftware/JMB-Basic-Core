#include "BasicCore.Common.iss"

objectdef basicCore
{
    variable taskmanager TaskManager=${LMAC.NewTaskManager["basicCore"]}

    variable basicCore_settings Settings
    variable basicCore_launcher Launcher

    variable weakref SelectedLaunchProfile

    variable weakref EditingWindowLayout

    variable jsonvalueref LatestVersion

    method Initialize()
    {
        LGUI2:LoadPackageFile[BasicCore.Uplink.lgui2Package.json]

        Settings:LoadDefaults
        if ${Settings.SettingsFileExists}
        {
            Settings:LoadFile
        }
        else
        {
            Settings:StoreFile
        }

        This:ImportGameProfiles

        if ${Settings.Launcher.Has[lastSelectedProfile]}
            This:SetSelectedLaunchProfile["${Settings.Launcher.Get[lastSelectedProfile]~}",0]

        This:AddAgentProvider
        This:VersionCheck
    }

    method Shutdown()
    {
        TaskManager:Destroy

        This:RemoveAgentProvider
        LGUI2:UnloadPackageFile[BasicCore.Uplink.lgui2Package.json]
    }

    method SetEditingWindowLayout(string name)
    {
;        echo SetEditingWindowLayout ${name~}
        variable uint id
        id:Set[${Settings.FindWindowLayout["${name~}"]}]
        if !${id}
        {
            EditingWindowLayout:SetReference[NULL]
            return
        }

        EditingWindowLayout:SetReference["Settings.WindowLayout.Get[layouts,${id}]"]

        if !${EditingWindowLayout.Has[mainRegion]}
            EditingWindowLayout:Set[mainRegion,"{}"]
        if !${EditingWindowLayout.Has[regions]}
            EditingWindowLayout:Set[regions,"[]"]

        LGUI2.Element[basicCore.events]:FireEventHandler[onEditingWindowLayoutUpdated]
    }

    method SetSelectedLaunchProfile(string name, bool storeSettings=TRUE)
    {
;        echo SetSelectedLaunchProfile ${name~}
        variable uint id
        id:Set[${Settings.FindLaunchProfile["${name~}"]}]
        if !${id}
        {
            Settings.Launcher:Erase[lastSelectedProfile]
            SelectedLaunchProfile:SetReference[NULL]
        }
        else
        {
            Settings.Launcher:SetString[lastSelectedProfile,"${name~}"]
            SelectedLaunchProfile:SetReference["Settings.Launcher.Get[profiles,${id}]"]
        }

        LGUI2.Element[basicCore.events]:FireEventHandler[onSelectedLaunchProfileUpdated]
        if ${storeSettings}
            Settings:StoreFile
    }

    method ImportGameProfiles()
    {
        variable jsonvalue joGames="${JMB.GameConfiguration.AsJSON~}"
        joGames:Erase["_set_guid"]

        joGames:ForEach["Settings:NewLaunchProfile[\"\${ForEach.Key~}\",\"\${ForEach.Key~}\"]"]
    }

    method RefreshGames()
    {
        variable jsonvalue jo="${JMB.GameConfiguration.AsJSON~}"
        jo:Erase["_set_guid"]

        variable jsonvalue jaKeys
        jaKeys:SetValue["${jo.Keys.AsJSON~}"]
        jo:SetValue["[]"]

        variable uint i
        for (i:Set[1] ; ${i}<=${jaKeys.Used} ; i:Inc)
        {
            jo:Add["$$>
            {
                "display_name":${jaKeys[${i}].AsJSON~}
            }
            <$$"]
        }
    
        Games:SetValue["${jo.AsJSON~}"]
        LGUI2.Element[basicCore.events]:FireEventHandler[onGamesUpdated]
    }

    method OnNewLaunchProfileButton()
    {
        echo OnNewLaunchProfileButton
        variable uint id
        id:Set[${Settings.FindLaunchProfile["New Launch Profile"]}]
        if ${id}
        {
            This:SetSelectedLaunchProfile["New Launch Profile",FALSE]
            return
        }

        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "name":"New Launch Profile"
        }
        <$$"]
        Settings.Launcher.Get[profiles]:Add["${jo~}"]
        This:SetSelectedLaunchProfile["New Launch Profile",FALSE]
        LGUI2.Element[basicCore.events]:FireEventHandler[onLaunchProfilesUpdated]
        return TRUE
    }

    method OnCopyLaunchProfileButton()
    {
        echo OnCopyLaunchProfileButton

        if !${SelectedLaunchProfile.Reference(exists)}
            return

        variable uint id
        id:Set[${Settings.FindLaunchProfile["${SelectedLaunchProfile.Get[name]~}"]}]
        if !${id}
        {
            return
        }
        variable jsonvalue launchProfile

        launchProfile:SetValue["${Settings.Launcher.Get[profiles,${id}]~}"]

        launchProfile:SetString[name,"Copy of ${SelectedLaunchProfile.Get[name]~}"]
        Settings.Launcher.Get[profiles]:Add["${launchProfile~}"]
        This:SetSelectedLaunchProfile["${launchProfile.Get[name]~}",FALSE]
        LGUI2.Element[basicCore.events]:FireEventHandler[onLaunchProfilesUpdated]
        return TRUE
    }

    method OnDeleteLaunchProfileButton()
    {
        echo OnDeleteLaunchProfileButton

        if !${SelectedLaunchProfile.Reference(exists)}
            return

        Settings:EraseLaunchProfile[${SelectedLaunchProfile.Get[name]~}]
        LGUI2.Element[basicCore.events]:FireEventHandler[onLaunchProfilesUpdated]
    }

    method OnNewWindowLayoutButton()
    {
        echo OnNewWindowLayoutButton
        variable uint id
        id:Set[${Settings.FindWindowLayout["New Window Layout"]}]
        if ${id}
        {
            This:SetEditingWindowLayout["New Window Layout"]
            return
        }

        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "name":"New Window Layout",
            "style":"horizontal"
        }
        <$$"]
        Settings.WindowLayout.Get[layouts]:Add["${jo~}"]
        This:SetEditingWindowLayout["New Window Layout"]
        LGUI2.Element[basicCore.events]:FireEventHandler[onWindowLayoutsUpdated]
        return TRUE
    }

    method OnCopyWindowLayoutButton()
    {
        echo OnCopyWindowLayoutButton

        if !${EditingWindowLayout.Reference(exists)}
            return

        variable uint id
        id:Set[${Settings.FindWindowLayout["${EditingWindowLayout.Get[name]~}"]}]
        if !${id}
        {
            return
        }
        variable jsonvalue windowLayout

        windowLayout:SetValue["${Settings.WindowLayout.Get[layouts,${id}]~}"]

        windowLayout:SetString[name,"Copy of ${EditingWindowLayout.Get[name]~}"]
        Settings.WindowLayout.Get[layouts]:Add["${windowLayout~}"]
        This:SetEditingWindowLayout["${windowLayout.Get[name]~}"]
        LGUI2.Element[basicCore.events]:FireEventHandler[onWindowLayoutsUpdated]
        return TRUE
    }

    method OnDeleteWindowLayoutButton()
    {
         echo OnDeleteWindowLayoutButton

        if !${EditingWindowLayout.Reference(exists)}
            return

        Settings:EraseWindowLayout[${EditingWindowLayout.Get[name]~}]
        LGUI2.Element[basicCore.events]:FireEventHandler[onWindowLayoutsUpdated]
    }

    method OnLaunchButton()
    {
        echo OnLaunchButton

        if !${SelectedLaunchProfile.Reference(exists)}
            return

        Settings:StoreFile
        Launcher:Launch[SelectedLaunchProfile]
    }

    method OnSaveAndApplyButton()
    {
        Settings:StoreFile
        ; restart agent in sessions
        relay all "JMB.Agent[\"Basic Core\"]:Stop:Start"
    }

    method OnAddSlotActivationHotkeyButton()
    {
        echo OnAddSlotActivationHotkeyButton

        Settings.Hotkeys.Get[slotHotkeys]:Add["\"NONE\""]
        LGUI2.Element[basicCore.events]:FireEventHandler[onSlotActivationHotkeysUpdated]
    }

    method OnRemoveSlotActivationHotkeyButton()
    {
        echo OnRemoveSlotActivationHotkeyButton
        variable uint idx = ${LGUI2.Element[basicCore.slotActivateHotkeysList].SelectedItem.Index}
        if !${idx}
            return

        Settings.Hotkeys.Get[slotHotkeys]:Erase[${idx}]
        LGUI2.Element[basicCore.events]:FireEventHandler[onSlotActivationHotkeysUpdated]
    }

    method OnAddWindowLayoutRegionButton()
    {
        echo OnAddWindowLayoutRegionButton
        BasicCore.EditingWindowLayout.Get[regions]:Add["{}"]
        LGUI2.Element[basicCore.events]:FireEventHandler[onEditingWindowLayoutUpdated]
    }  

    method OnRemoveWindowLayoutRegionButton()
    {
        variable uint idx=${LGUI2.Element[basicCore.windowLayoutRegionsList].SelectedItem.Index}
        echo OnRemoveWindowLayoutRegionButton ${idx}

        if ${idx}
            BasicCore.EditingWindowLayout.Get[regions]:Erase[${idx}]
        LGUI2.Element[basicCore.events]:FireEventHandler[onEditingWindowLayoutUpdated]
        
;        echo ${LGUI2.Element[basicCore.windowLayoutRegionsList].SelectedItem.Index}
    }

    method OnInstallLatestButton()
    {
        variable string command1="timed 1 "relay all -noredirect \"JMB.Agent[Basic Core]:Stop:Reload:Start\"""
        variable string command2="timed 1 \"JMB.Agent[Basic Core]:Stop:Reload:Start\""

        variable jsonvalue joTask
        joTask:SetValue["$$>
        {
            "type":"chain",
            "tasks":[
                {
                    "type":"agent.install",
                    "provider":"BasicCore",
                    "listing":"BasicCore",
                    "download":true
                },
                {
                    "type":"ls1.code",
                    "instant":true,
                    "start":${command1.AsJSON~},
                    "stop":${command2.AsJSON~}
                }
            ]
        }        
        <$$"]

        TaskManager:BeginTask["${joTask.AsJSON~}"]
    }

    method AddAgentProvider()
    {
        JMB:AddAgentProvider["","${LGUI2.Template[basicCore.agentProvider]~}"]        
    }

    method RemoveAgentProvider()
    {
        JMB.AgentProvider[BasicCore]:Remove
    }

    method VersionCheck()
    {
        ; 
        ; LatestVersion
        variable jsonvalue joTask
        joTask:SetValue["$$>
            {
                "type":"webrequest",
                "as":"json",
                "object":"BasicCore",
                "method":"OnVersionCheckComplete",
                "url":"https://raw.githubusercontent.com/LavishSoftware/JMB-Basic-Core/master/agent.json"
            }
            <$$"]

;        echo "starting task ${joTask.AsJSON~}"
        TaskManager:BeginTask["${joTask.AsJSON~}"]
    }

    method OnVersionCheckComplete()
    {
        echo OnVersionCheckComplete ${Context(type)} state=${Context.State} result=${Context.Result}

        LatestVersion:SetReference["Context.Result.Get[jsonResult]"]

        if ${LatestVersion.Get[version].NotEqual["${JMB.Agent[Basic Core].Version~}"]}
        {
            LGUI2.Element[basicCore.versionCheckPanel]:SetVisibility[Visible]
        }

        LGUI2.Element[basicCore.events]:FireEventHandler[onLatestVersionUpdated]
    }
}

objectdef basicCore_launcher
{
    member:string GetKnownGame(jsonvalueref jo)
    {
        if ${jo.Has[executable]}
        {
            switch ${jo.Get[executable]~}
            {
                case wow.exe
                case wow-t.exe
                case wowclassic.exe
                case world of warcraft launcher.exe
                    return "World of Warcraft"
                case eqgame.exe
                case testeqgame.exe
                    return "EverQuest"
            }

            if !${jo.Has[game]}
                return "${jo.Get[executable]~}"
        }

        if ${jo.Has[game]}
        {
            if ${jo.Get[game]~.Find[EverQuest]}
                return "EverQuest"
            if ${jo.Get[game]~.Find[World of Warcraft]}
                return "World of Warcraft"

            return "${jo.Get[game]~}"
        }        
    }

    method AddVirtualFile(jsonvalueref jo, string _pattern, string _replacement)
    {
        variable uint idx

        variable jsonvalueref joVirtualFiles
        if !${jo.Has[virtualFiles]}
            jo:Set[virtualFiles,"[]"]

        joVirtualFiles:SetReference["jo.Get[virtualFiles]"]

        idx:Set[${Settings.FindInArray["joVirtualFiles","pattern","${_pattern~}"]}]
        if ${idx}
        {
            joVirtualFiles.Get[${idx}]:SetString[replacement,"${_replacement~}"]
            return
        }

        joVirtualFiles:Add["$$>
        {
            "pattern":${_pattern.AsJSON~},
            "replacement":${_replacement.AsJSON~}
        }
        <$$"]

    }

    method AddDefaultVirtualFiles(uint Slot, jsonvalueref jo)
    {
        switch ${This.GetKnownGame[jo]~}
        {
            case EverQuest
                This:AddVirtualFile[jo,"*/eqclient.ini","{1}/eqclient.Generic.JMB${Slot}.ini"]
                This:AddVirtualFile[jo,"*/eqlsPlayerData.ini","{1}/eqlsPlayerData.Generic.JMB${Slot}.ini"]
                break
            case World of Warcraft
                This:AddVirtualFile[jo,"*\/Config.WTF","{1}/Config.Generic.JMB${Slot}.WTF"]
                This:AddVirtualFile[jo,"Software/Blizzard Entertainment/World of Warcraft/Client/\*","Software/Blizzard Entertainment/World of Warcraft/Client-JMB${Slot}/{1}"]
                break
        }
    }

    method InstallCharacter(uint Slot, jsonvalueref launchProfile)
    {
        if !${launchProfile.Type.Equal[object]}
            return FALSE

        variable jsonvalue jo
        jo:SetValue["${launchProfile.AsJSON~}"]

        jo:SetInteger[id,${Slot}]

        if ${launchProfile.Has[name]}
            jo:SetString[display_name,"${launchProfile.Get[name]~}"]

        if ${launchProfile.Has[game]}
            jo:SetString[gameProfile,"${launchProfile.Get[game]~} Default Profile"]

        if ${launchProfile.GetBool[useDefaultVirtualFiles]}
        {
            This:AddDefaultVirtualFiles[${Slot},jo]
        }

        JMB:AddCharacter["${jo.AsJSON~}"]
        return TRUE
    }

    ; Find a Slot that does not currently have a running game instance 
    member:uint FindEmptySlot()
    {
        variable jsonvalueref currentSlots="JMB.Slots"
        variable uint i
        for (i:Set[1] ; ${i} <= ${currentSlots.Used} ; i:Inc)
        {
            if !${currentSlots.Get[${i},"processId"]}
            {
                return ${i}
            }
        }
        return 0
    }

    method Launch(jsonvalueref launchProfile, uint Slot=0)
    {
        if !${Slot}
        {
            Slot:Set["${This.FindEmptySlot}"]
            if !${Slot}
                Slot:Set["${JMB.AddSlot.ID}"]
        }
        else
        {
            kill jmb${Slot}
        }

        This:InstallCharacter[${Slot},launchProfile]
        JMB.Slot[${Slot}]:SetCharacter[${Slot}]
        JMB.Slot[${Slot}]:Launch
    }

    method Relaunch(uint numSlot)
    {
        if !${JMB.Slot[${numSlot}].ProcessID}
            JMB.Slot[${numSlot}]:Launch
    }
    
    method RelaunchMissingSlots()
    {
        JMB.Slots:ForEach["This:Relaunch[\${ForEach.Value.Get[id]}]"]
    }
}

variable(global) basicCore BasicCore

function main()
{
    while 1
        waitframe
}