/*
Release notes:

---- 1.0.0 (01/11/2013) ----
- Restores a player's score when he reconnects
- Stored scores are trashed on mapchange and when a new match starts


---- 1.1.1 (09/11/2013) ----
- Fixed a bug where the scores would not be restored


---- 1.1.2 (28/01/2014) ----
- Fixed a minor error when the server is closing
- Fixed a bug that sometimes caused RestoreScore not to work for certain players (SteamID fix)

---- 1.1.3 (25/01/2020) ----
- now zeros damage at start of games/maps to stop soapdm dmg from being counted on toggling scoreboard (untested)
- updated updatefile


Known errors:
- Not compatible with TFTrue.
*/

#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <f2stocks>
#undef REQUIRE_PLUGIN
#include <updater>


#define PLUGIN_VERSION  "1.1.3"
#define UPDATE_URL      "https://raw.githubusercontent.com/stephanieLGBT/f2-plugins-updated/master/restorescore-updatefile.txt"

#pragma newdecls required

public Plugin myinfo = {
    name = "Restore Score",
    author = "F2, edited by stephanie",
    description = "Restores the score of a player when reconnecting",
    version = PLUGIN_VERSION,
    url = "http://sourcemod.krus.dk/"
};

bool g_bHookActivated = false;

int g_iAddScore[MAXPLAYERS+1]; // The old scores that are currently being added to the clients.
KeyValues g_kvOldScores; // Keys are steamids of players disconnected, and values are their old scores.

public void OnPluginStart() {
    HookEvent("player_activate", Event_player_activate, EventHookMode_Post);
    HookEvent("player_disconnect", Event_player_disconnect, EventHookMode_Pre);
    HookEvent("teamplay_restart_round", Event_restart_round, EventHookMode_Post);

    g_kvOldScores = new KeyValues("OldScores");

    if (LibraryExists("updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public void OnLibraryAdded(const char[] name) {
    if (StrEqual(name, "updater"))
        Updater_AddPlugin(UPDATE_URL);
}

public void OnPluginEnd() {
    StopHook();
    delete g_kvOldScores;
}

// Clear the old scores when the match is reset and on mapchange.
void ResetOldScores() {
    // Stop the hook (for performance reasons)
    StopHook();

    // Clear the old scores
    delete g_kvOldScores;
    g_kvOldScores = new KeyValues("OldScores");

    for (int client = 1; client <= MaxClients; client++)
    {
        g_iAddScore[client] = 0;
        // reset damage when round starts (fixes soapdm dmg showing on tab)
        SetEntProp(client, Prop_Data, "m_iDamage", 0);
    }
}

public Action Event_restart_round(Event event, const char[] name, bool dontBroadcast) {
    ResetOldScores();
}

public void OnMapStart() {
    ResetOldScores();
}

// When a player connects, check if it is a returning player, and adjust his score accordingly.
public Action Event_player_activate(Event event, const char[] name, bool dontBroadcast) {
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    if (!IsRealPlayer(client))
        return;

    char steamid[64];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), false);
    g_kvOldScores.Rewind();
    if (!g_kvOldScores.JumpToKey(steamid))
        return;
    int oldscore = g_kvOldScores.GetNum("score");
    g_kvOldScores.GoBack();
    g_kvOldScores.DeleteKey(steamid);

    g_iAddScore[client] = oldscore;
    //SetEntProp(client, Prop_Send, "m_iFrags", KvGetNum(g_kvOldScores, "kills"));
    //SetEntProp(client, Prop_Send, "m_iDeaths", KvGetNum(g_kvOldScores, "deaths"));
    //SetEntProp(client, Prop_Data, "m_iAssists", KvGetNum(g_kvOldScores, "assists"));
    //SetEntProp(client, Prop_Data, "m_iDamage", KvGetNum(g_kvOldScores, "damage"));

    StartHook();
}

// When a player disconnects, remember the score.
public Action Event_player_disconnect(Event event, const char[] name, bool dontBroadcast) {
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    g_iAddScore[client] = 0;

    // Clear the old scores if the server is empty
    if (GetClientCount() == 1) {
        ResetOldScores();
        return;
    }

    if (!IsRealPlayer(client))
        return;

    // Save the score if it is above 0
    int score = TF2_GetPlayerScore(client);
    if (score <= 0)
        return;
    char steamid[64];
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), false);

    g_kvOldScores.Rewind();
    if (!g_kvOldScores.JumpToKey(steamid, true))
        return;

    g_kvOldScores.SetNum("score", score);
    //KvSetNum(g_kvOldScores, "kills", GetEntProp(client, Prop_Send, "m_iFrags"));
    //KvSetNum(g_kvOldScores, "deaths", GetEntProp(client, Prop_Send, "m_iDeaths"));
    //KvSetNum(g_kvOldScores, "assists", GetEntProp(client, Prop_Data, "m_iAssists"));
    KvGoBack(g_kvOldScores);
}

// --- This is where the magic happens! ---
void StartHook() {
    if (g_bHookActivated)
    {
        return;
    }
    g_bHookActivated = true;
    int iIndex = FindEntityByClassname(-1, "tf_player_manager");
    if (iIndex == -1)
    {
        SetFailState("Unable to find tf_player_manager entity");
    }

    SDKHook(iIndex, SDKHook_ThinkPost, Hook_OnThinkPost);
}

void StopHook() {
    if (!g_bHookActivated)
        return;
    g_bHookActivated = false;
    int iIndex = FindEntityByClassname(-1, "tf_player_manager");
    if (iIndex == -1)
        SetFailState("Unable to find tf_player_manager entity");

    SDKUnhook(iIndex, SDKHook_ThinkPost, Hook_OnThinkPost);
}

public void Hook_OnThinkPost(int iEnt) {
    static int iTotalScoreOffset = -1;
    if (iTotalScoreOffset == -1)
        iTotalScoreOffset = FindSendPropInfo("CTFPlayerResource", "m_iTotalScore");

    // Get all players' current scores
    int iTotalScore[MAXPLAYERS+1];
    GetEntDataArray(iEnt, iTotalScoreOffset, iTotalScore, MaxClients+1);

    // Add the old scores
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            iTotalScore[i] += g_iAddScore[i];
        }
    }

    // Set all players' int scores
    SetEntDataArray(iEnt, iTotalScoreOffset, iTotalScore, MaxClients+1);
}
// ----------------------------------------
