#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

new Handle:g_hReset;
new Handle:g_hResetMessage;

enum {
    TFFlagStatus_AtBase = 0,
    TFFlagStatus_Carried,
    TFFlagStatus_Dropped
}

public Plugin:myinfo = {
    name = "FlagReturn",
    author = "bl4nk",
    description = "Return a downed flag when touched by someone on the same team",
    version = "2.0.0",
    url = "http://forums.alliedmods.net/"
};

public OnPluginStart() {
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN12CCaptureFlag5ResetEv", 0);
    g_hReset = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN12CCaptureFlag12ResetMessageEv", 0);
    g_hResetMessage = EndPrepSDKCall();
}

public OnMapStart() {
    decl String:mapName[32];
    GetCurrentMap(mapName, sizeof(mapName));

    if (strncmp(mapName, "ctf_sf_", 7) == 0) {
        new ent = -1;
        while ((ent = FindEntityByClassname(ent, "item_teamflag")) != -1) {
            SDKHook(ent, SDKHook_StartTouch, OnFlagStartTouch);
        }
    }
}

public OnFlagStartTouch(ent, other) {
    if ((0 < other <= MaxClients) && (GetClientTeam(other) == GetEntProp(ent, Prop_Send, "m_iTeamNum")) && (GetEntProp(ent, Prop_Send, "m_nFlagStatus") == TFFlagStatus_Dropped)) {
        SDKCall(g_hReset, ent);
        SDKCall(g_hResetMessage, ent);
    }
}