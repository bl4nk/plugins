#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#tryinclude <morecolors>

#define PLUGIN_VERSION "1.1.0-j2"

new bool:g_bEnable;

new Handle:g_hConVar_Enable;

new String:g_szMapName[32];

enum {
    TFFlagStatus_Home = 0,
    TFFlagStatus_Stolen,
    TFFlagStatus_Dropped
}

public Plugin:myinfo = {
    name = "FlagReturn",
    author = "bl4nk",
    description = "Return a downed flag when touched by someone on the same team",
    version = PLUGIN_VERSION,
    url = "http://forums.alliedmods.net/"
};

public OnPluginStart() {
    LoadTranslations("flagreturn.phrases");

    CreateConVar("sm_flagreturn_version", PLUGIN_VERSION, "FlashProtect Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    g_hConVar_Enable = CreateConVar("sm_flagreturn_enable", "1", "Enable/Disable the FlagReturn plugin", FCVAR_PLUGIN, true, 0.0, true, 1.0);

    HookConVarChange(g_hConVar_Enable, OnConVarChanged);
}

public OnMapStart() {
    GetCurrentMap(g_szMapName, sizeof(g_szMapName));
}

public OnConfigsExecuted() {
    if (strncmp(g_szMapName, "ctf_sf_", 7, false) == 0) {
        SetConVarBool(g_hConVar_Enable, true);

        if (!g_bEnable) {
            g_bEnable = true;
        }
    } else {
        g_bEnable = GetConVarBool(g_hConVar_Enable);
    }
}

public OnConVarChanged(Handle:hConVar, const String:szOldValue[], const String:szNewValue[]) {
    g_bEnable = !(StringToInt(szNewValue) == 0);
}

public OnEntityCreated(iEnt, const String:szClassName[]) {
    if (strcmp(szClassName, "item_teamflag", false) == 0) {
        SDKHook(iEnt, SDKHook_StartTouch, OnFlagStartTouch);
    }
}

public OnFlagStartTouch(iEnt, iOther) {
    if (g_bEnable && (0 < iOther <= MaxClients) && (GetEntProp(iEnt, Prop_Send, "m_nFlagStatus") == TFFlagStatus_Dropped)) {
        new iTeam = GetClientTeam(iOther);
        if (iTeam == GetEntProp(iEnt, Prop_Send, "m_iTeamNum")) {
            decl String:szTeamName[4];
            Format(szTeamName, sizeof(szTeamName), "%s", ((iTeam == _:TFTeam_Blue) ? "BLU" : "RED"));

            #if defined _colors_included
                CPrintToChatAllEx(iOther, "%t", "Flag Returned", iOther, szTeamName);
            #else
                PrintToChatAll("%t", "Flag Returned", iOther, szTeamName);
            #endif

            AcceptEntityInput(iEnt, "ForceReset");
        }
    }
}