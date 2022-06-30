/*
Release notes:

---- 1.0.1 (14/12/2013) ----
- Changes the map on server start

---- 1.0.2 (21/01/2020) ----
- Completely rewrote plugin to make the plugin actually function properly

---- i forgot what i did with 1.0.3

---- 1.0.4 (25/01/2020) ----
- Moved tv hook to plugin start to catch stv being enabled on srv start

*/

#pragma semicolon 1 // Force strict semicolon mode.

#include <sourcemod>
//#include <f2stocks>
#include <nextmap>
#undef REQUIRE_PLUGIN
#include <updater>

#define PLUGIN_VERSION "1.0.4"
#define UPDATE_URL      "https://raw.githubusercontent.com/stephanieLGBT/f2-plugins-updated/master/fixstvslot-updatefile.txt"

#pragma newdecls required

int stvOn;

public Plugin myinfo = {
    name = "Fix STV Slot",
    author = "F2, fixed by stephanie",
    description = "When STV is enabled, changes the map so SourceTV joins properly.",
    version = PLUGIN_VERSION,
    url = "http://sourcemod.krus.dk/"
}

public void OnPluginStart()
{
    // Set up auto updater
    if (LibraryExists("updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
    HookConVarChange(FindConVar("tv_enable"), OnSTVChanged);
    CreateTimer(2.0, CheckRGL);
}

public void OnLibraryAdded(const char[] name)
{
    // Set up auto updater
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

public Action CheckRGL(Handle timer)
{
    Handle rgl_cast = FindConVar("rgl_cast");
    if (rgl_cast != INVALID_HANDLE)
    {
        LogMessage("[FixSTVSlot] RGLQoL plugin detected! Unloading to prevent conflicts.");
        ServerCommand("sm plugins unload fixstvslot");
    }
}

public void OnSTVChanged(ConVar convar, char[] oldValue, char[] newValue)
{
    stvOn = FindConVar("tv_enable").BoolValue;
    if (stvOn == 1)
    {
        LogMessage("[FixSTVSlot] tv_enable changed to 1! Changing level in 10 seconds unless manual map change occurs before then.");
        PrintToChatAll("[FixSTVSlot] tv_enable changed to 1! Changing level in 10 seconds unless manual map change occurs before then.");
        CreateTimer(10.0, ChangeIn10, TIMER_DATA_HNDL_CLOSE | TIMER_FLAG_NO_MAPCHANGE);
    }
    else if (stvOn == 0)
    {
        LogMessage("[FixSTVSlot] tv_enable changed to 0!");
    }
}

public Action ChangeIn10(Handle timer)
{
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    ForceChangeLevel(mapName, "STV joined! Forcibly changing level.");
}