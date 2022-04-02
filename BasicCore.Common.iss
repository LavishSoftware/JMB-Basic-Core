objectdef basicCore_settings
{
    variable jsonvalue Launcher="{}"
    variable jsonvalue Highlighter="{}"
    variable jsonvalue Hotkeys="{}"
    variable jsonvalue Performance="{}"
    variable jsonvalue RoundRobin="{}"
    variable jsonvalue WindowLayout="{}"

    variable filepath AgentFolder="${Script.CurrentDirectory~}"

    method Initialize()
    {

    }

    method Shutdown()
    {

    }

    method FromJSON(jsonvalueref jo)
    {
        if !${jo.Type.Equal[object]}
            return

        Launcher:SetValue["${jo.Get[launcher].AsJSON~}"]
        Highlighter:SetValue["${jo.Get[highlighter].AsJSON~}"]
        Hotkeys:SetValue["${jo.Get[hotkeys].AsJSON~}"]
        Performance:SetValue["${jo.Get[performance].AsJSON~}"]
        RoundRobin:SetValue["${jo.Get[roundRobin].AsJSON~}"]
        WindowLayout:SetValue["${jo.Get[windowLayout].AsJSON~}"]

        LGUI2.Element[basicCore.events]:FireEventHandler[onLaunchProfilesUpdated]
    }

    ; Determine if our settings file exists
    member:bool SettingsFileExists()
    {
        return ${AgentFolder.FileExists[BasicCore.Settings.json]}
    }

    member:string SettingsFileName()
    {
        return "${This.AgentFolder~}/BasicCore.Settings.json"
    }

    member:uint FindInArray(jsonvalueref arr, string key, string value)
    {
        variable uint i

        for ( i:Set[1] ; ${i}<=${arr.Used} ; i:Inc )
        {
            if ${arr.Get[${i}].Assert["${key~}","${value.AsJSON~}"]}
            {
                return ${i}
            }
        }

        return 0
    }

    member:uint FindWindowLayout(string name)
    {
        return ${This.FindInArray["WindowLayout.Get[layouts]","name","${name~}"]}
    }

    member:uint FindLaunchProfile(string name)
    {
        return ${This.FindInArray["Launcher.Get[profiles]","name","${name~}"]}
    }

    method EraseLaunchProfile(string name)
    {
        variable uint id
        id:Set[${This.FindLaunchProfile["${name~}"]}]
        if !${id}
        {
            return FALSE
        }

        Launcher.Get[profiles]:Erase[${id}]
        LGUI2.Element[basicCore.events]:FireEventHandler[onLaunchProfilesUpdated]
        return TRUE
    }

    method EraseWindowLayout(string name)
    {
        variable uint id
        id:Set[${This.FindWindowLayout["${name~}"]}]
        if !${id}
        {
            return FALSE
        }

        WindowLayout.Get[layouts]:Erase[${id}]
        LGUI2.Element[basicCore.events]:FireEventHandler[onWindowLayoutsUpdated]
        return TRUE
    }

    member:jsonvalueref GetGameProfile(string gameName)
    {
        variable jsonvalue joGames="${JMB.GameConfiguration.AsJSON~}"

        return "joGames.Get[\"${gameName~}\",Profiles,\"${gameName~} Default Profile\"]"
    }

    method NewLaunchProfile(string name, string gameName="")
    {        
        if ${name.Equal[Generic]}
        {
            ; skip
            return
        }

        if !${Launcher.Type.Equal[object]}
        {
            Launcher:SetValue["{}"]            
        }

        if !${Launcher.Has[profiles]} || !${Launcher.Get[profiles].Type.Equal[array]}
            Launcher:Set[profiles,"[]"]

        variable jsonvalueref profiles
        profiles:SetReference["Launcher.Get[profiles]"]

        ; find existing profile
        variable uint i
        i:Set[${This.FindInArray["profiles",name,"${name~}"]}]
        if ${i}
        {
            return FALSE
        }

        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "name":${name.AsJSON~},
            "game":${gameName.AsJSON~}
        }
        <$$"]

        variable jsonvalueref joGameProfile
        joGameProfile:SetReference["This.GetGameProfile[\"${gameName~}\"]"]
        if ${joGameProfile.Type.Equal[object]}
        {
            if ${joGameProfile.Has[Path]}
                jo:SetString[path,"${joGameProfile.Get[Path]~}"]
            if ${joGameProfile.Has[Executable]}
                jo:SetString[executable,"${joGameProfile.Get[Executable]~}"]
            if ${joGameProfile.Has[Parameters]}
                jo:SetString[parameters,"${joGameProfile.Get[Parameters]~}"]
        }

        jo:SetBool[useDefaultVirtualFiles,1]


        ; add new profile
        profiles:AddByRef[jo]

        LGUI2.Element[basicCore.events]:FireEventHandler[onLaunchProfilesUpdated]
        return TRUE
    }

    method LoadFile()
    {
        variable jsonvalue jo

        if !${jo:ParseFile["${This.SettingsFileName~}"](exists)} || !${jo.Type.Equal[object]}
            return FALSE

        This:FromJSON[jo]
        return TRUE
    }

    method StoreFile()
    {
        variable jsonvalueref jo
        jo:SetReference["This.AsJSON"]
        if !${jo.Type.Equal[object]}
            return FALSE

        jo:WriteFile["${This.SettingsFileName~}",multiline]
        return TRUE
    }

    method LoadDefaults()
    {
        if ${LGUI2.Skin[default].Template[basicCore.defaultSettings](exists)}
            This:FromJSON["LGUI2.Skin[default].Template[basicCore.defaultSettings]"]
    }

    member:jsonvalueref AsJSON()
    {
        variable jsonvalue jo
        jo:SetValue["$$>
        {
            "$schema":"BasicCore.Schema.json",
            "launcher":${Launcher.AsJSON~},
            "highlighter":${Highlighter.AsJSON~},
            "hotkeys":${Hotkeys.AsJSON~},
            "performance":${Performance.AsJSON~},
            "roundRobin":${RoundRobin.AsJSON~},
            "windowLayout":${WindowLayout.AsJSON~}
        }
        <$$"]
        return jo
    }
}
