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

objectdef basicCore_performance
{    
    method ApplyMaxFPS(string prefix, jsonvalueref json)
    {
        variable string useLine="${prefix~}"
        if ${json.Has[maxFPS]}
            useLine:Concat[" ${json.Get[maxFPS]~}"]

        if ${json.Has[calculate]}
        {
            if ${json.Get[calculate]}
                useLine:Concat[" -calculate"]
            else
                useLine:Concat[" -absolute"]
        }
    }

    method ApplyJSON(jsonvalueref json)
    {
        if ${json.Has[lockAffinity]}
        {
            if ${json.Get[lockAffinity]}
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