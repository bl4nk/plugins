#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

new bool:g_bEnable;
new bool:g_bDisableFF;
new bool:g_bDisablePlayerFF[MAXPLAYERS+1];

public Plugin:myinfo = {
    name = "ctf_steamroll ffa disabler",
    author = "bl4nk",
    description = "No TKing in the viewing rooms on ctf_steamroll",
    version = "1.0.0",
    url = "http://forums.joe.to/"
};

public OnPluginStart() {
    HookEvent("teamplay_setup_finished", Event_SetupEnd);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("teamplay_round_win", Event_RoundEnd);
    
    for (new i = 0; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            SDKHook(i, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
        }
    }
}

public OnMapStart() {
    decl String:szMapName[32];
    GetCurrentMap(szMapName, sizeof(szMapName));
    
    g_bEnable = (strcmp(szMapName, "ctf_steamroll", false) == 0);
}

public OnClientPutInServer(iClient) {
    g_bDisablePlayerFF[iClient] = false;
    
    SDKHook(iClient, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

public Action:Hook_OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType, &iWeapon, Float:fDamageForce[3], Float:fDamagePosition[3], iDamageCustom) {
    if (g_bEnable && iVictim && iAttacker && iVictim != iAttacker && iVictim <= MaxClients && iAttacker <= MaxClients && GetClientTeam(iVictim) == GetClientTeam(iAttacker) && g_bDisablePlayerFF[iAttacker]) {
        fDamage = 0.0;
        return Plugin_Changed;
    }
    
    return Plugin_Continue;
}

public Event_SetupEnd(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast) {
    if (g_bEnable) {
        g_bDisableFF = true;
    }
}

public Event_PlayerSpawn(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast) {
    if (g_bEnable) {
        new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
        
        if (iClient && g_bDisableFF) {
            g_bDisablePlayerFF[iClient] = true;
        }
    }
}

public Event_RoundEnd(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast) {
    if (g_bEnable) {
        g_bDisableFF = false;
    }
}