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

variable(global) basicCore BasicCore

function main()
{
    while 1
        waitframe
}