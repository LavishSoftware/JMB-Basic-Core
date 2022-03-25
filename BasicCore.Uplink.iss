#include "BasicCore.Common.iss"

objectdef basicCore
{
    variable basicCore_settings Settings

    variable weakref SelectedLauncherProfile

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
            SelectedLauncherProfile:Set["${Settings.Launcher.Get[lastSelectedProfile]}"]
    }

    method Shutdown()
    {
        LGUI2:UnloadPackageFile[BasicCore.Uplink.lgui2Package.json]
    }

    method SetSelectedLauncherProfile(string name)
    {
        echo SetSelectedLauncherProfile ${name~}
        variable uint id
        id:Set[${Settings.FindLauncherProfile["${name~}"]}]
        if !${id}
        {
            SelectedLauncherProfile:SetReference[NULL]
            return
        }

        SelectedLauncherProfile:SetReference["Settings.Launcher.Get[profiles,${id}]"]

        LGUI2.Element[BasicLauncher.events]:FireEventHandler[onSelectedLauncherProfileUpdated]
    }

    method ImportGameProfiles()
    {
        variable jsonvalue joGames="${JMB.GameConfiguration.AsJSON~}"
        joGames:Erase["_set_guid"]

        joGames:ForEach["Settings:NewLauncherProfile[\"\${ForEach.Key~}\",\"\${ForEach.Key~}\",\"\${ForEach.Key~} Default Profile\"]"]
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
        LGUI2.Element[BasicLauncher.events]:FireEventHandler[onGamesUpdated]
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

        if !${SelectedLauncherProfile.NotNULLOrEmpty}
            return

        Settings:EraseLauncherProfile[${SelectedLauncherProfile~}]
    }

}

variable(global) basicCore BasicCore

function main()
{
    while 1
        waitframe
}