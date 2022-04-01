#include "BasicCore.Common.iss"

objectdef basicCore
{
    variable basicCore_settings Settings
    variable basicCore_launcher Launcher

    variable weakref SelectedLauncherProfile

    variable weakref EditingWindowLayout

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
            This:SetSelectedLauncherProfile["${Settings.Launcher.Get[lastSelectedProfile]~}",0]
    }

    method Shutdown()
    {
        LGUI2:UnloadPackageFile[BasicCore.Uplink.lgui2Package.json]
    }

    method SetEditingWindowLayout(string name)
    {
        echo SetEditingWindowLayout ${name~}
        variable uint id
        id:Set[${Settings.FindWindowLayout["${name~}"]}]
        if !${id}
        {
            EditingWindowLayout:SetReference[NULL]
            return
        }

        EditingWindowLayout:SetReference["Settings.WindowLayout.Get[layouts,${id}]"]

        LGUI2.Element[basicCore.events]:FireEventHandler[onEditingWindowLayoutUpdated]
    }

    method SetSelectedLauncherProfile(string name, bool storeSettings=TRUE)
    {
        echo SetSelectedLauncherProfile ${name~}
        variable uint id
        id:Set[${Settings.FindLauncherProfile["${name~}"]}]
        if !${id}
        {
            Settings.Launcher:Erase[lastSelectedProfile]
            SelectedLauncherProfile:SetReference[NULL]
        }
        else
        {
            Settings.Launcher:SetString[lastSelectedProfile,"${name~}"]
            SelectedLauncherProfile:SetReference["Settings.Launcher.Get[profiles,${id}]"]
        }

        LGUI2.Element[basicCore.events]:FireEventHandler[onSelectedLauncherProfileUpdated]
        if ${storeSettings}
            Settings:StoreFile
    }

    method ImportGameProfiles()
    {
        variable jsonvalue joGames="${JMB.GameConfiguration.AsJSON~}"
        joGames:Erase["_set_guid"]

        joGames:ForEach["Settings:NewLauncherProfile[\"\${ForEach.Key~}\",\"\${ForEach.Key~}\"]"]
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

    method OnCopyLaunchProfileButton()
    {
        variable uint id
        id:Set[${Settings.FindLauncherProfile["${SelectedPullLauncherProfile~}"]}]
        if !${id}
        {
            return
        }
        variable jsonvalue launcherProfile

        launcherProfile:SetValue["${Settings.Launcher.Get[profiles,${id}]~}"]

        launcherProfile:Set[name,"Copy of ${SelectedPullLauncherProfile~}"]
        Settings.Launcher.Profiles:Add["${launcherProfile~}"]
        SelectedPullLauncherProfile:Set["${launcherProfile.Get[name]~}"]
        return TRUE
    }

    method OnDeleteLaunchProfileButton()
    {
        echo OnDeleteLaunchProfileButton

        if !${SelectedLauncherProfile.Reference(exists)}
            return

        Settings:EraseLauncherProfile[${SelectedLauncherProfile.Get[name]~}]
    }

    method OnLaunchButton()
    {
        echo OnLaunchButton

        if !${SelectedLauncherProfile.Reference(exists)}
            return

        Launcher:Launch[SelectedLauncherProfile]
    }

    method OnSaveAndApplyButton()
    {
        Settings:StoreFile
        ; restart agent in sessions
        relay all "JMB.Agent[\"Basic Core\"]:Stop:Start"
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
                This:AddVirtualFile[jo,"*\/Config.WTF","{1}/Condif.Generic.JMB${Slot}.ini"]
                This:AddVirtualFile[jo,"Software/Blizzard Entertainment/World of Warcraft/Client/\*","Software/Blizzard Entertainment/World of Warcraft/Client-JMB${Slot}/{1}"]
                break
        }
    }

    method InstallCharacter(uint Slot, jsonvalueref launcherProfile)
    {
        if !${launcherProfile.Type.Equal[object]}
            return FALSE

        variable jsonvalue jo
        jo:SetValue["${launcherProfile.AsJSON~}"]

        jo:SetInteger[id,${Slot}]

        if ${launcherProfile.Has[name]}
            jo:SetString[display_name,"${launcherProfile.Get[name]~}"]

        if ${launcherProfile.Has[game]}
            jo:SetString[gameProfile,"${launcherProfile.Get[game]~} Default Profile"]

        if ${launcherProfile.GetBool[useDefaultVirtualFiles]}
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

    method Launch(jsonvalueref launcherProfile, uint Slot=0)
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

        This:InstallCharacter[${Slot},launcherProfile]
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