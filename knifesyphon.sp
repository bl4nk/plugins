#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "2.0.0-j2"

enum {
    WEAPONSLOT_PRIMARY = 0,
    WEAPONSLOT_SECONDARY,
    WEAPONSLOT_MELEE,
    WEAPONSLOT_OTHER1,
    WEAPONSLOT_OTHER2
};

new g_iWeaponId[MAXPLAYERS+1][MAXPLAYERS+1];

new bool:g_bEnabled;

new Handle:g_hConVarEnable;
new Handle:g_hConVarLife;
new Handle:g_hConVarMaxLife;

public Plugin:myinfo = {
    name = "KnifeSyphon",
    author = "bl4nk",
    description = "Gives players a health boost when they make a knife kill.",
    version = PLUGIN_VERSION,
    url = "http://forums.joe.to/"
};

public OnPluginStart() {
    LoadTranslations("knifesyphon.phrases");

    CreateConVar("sm_knifesyphon_version", PLUGIN_VERSION, "KnifeSyphon Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    g_hConVarEnable = CreateConVar("sm_knifesyphon_enable", "1", "Enables/Disables the KnifeSyphon plugin.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    g_hConVarLife = CreateConVar("sm_knifesyphon_life", "25", "Sets the amount of health to give to a player after they kill someone with a knife.", FCVAR_PLUGIN, true, 0.0, true, 100.0);
    g_hConVarMaxLife = CreateConVar("sm_knifesyphon_maxlife", "1", "Give life only up to the player's default maximum", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    
    HookEvent("player_death", Event_PlayerDeath);
    HookConVarChange(g_hConVarEnable, ConVarChange);
    
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i)) {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public OnConfigsExecuted() {
    g_bEnabled = GetConVarBool(g_hConVarEnable);
}

public ConVarChange(Handle:hConVar, const String:szOldValue[], const String:szNewValue[]) {
    g_bEnabled = bool:StringToInt(szNewValue);
}

public OnClientPutInServer(iClient) {    
    SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType, &iWeapon, Float:fDamageForce[3], Float:fDamagePosition[3]) {
    if (iAttacker && iVictim && iAttacker <= MaxClients && iVictim <= MaxClients) {
        g_iWeaponId[iAttacker][iVictim] = iWeapon;
    }
    
    return Plugin_Continue;
}

public Event_PlayerDeath(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast) {
    if (!g_bEnabled) {
        return;
    }
    
    new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
    
    if (iVictim && !iAttacker && GetClientTeam(iVictim) == GetClientTeam(iAttacker)) {    
        new iWeapon = g_iWeaponId[iAttacker][iVictim];
        new iMelee = GetPlayerWeaponSlot(iAttacker, WEAPONSLOT_MELEE);
        
        if (iWeapon && iMelee && iWeapon == iMelee) {
            new iPlayerHealth = GetPlayerHealth(iAttacker);
            new iAddToHealth = GetConVarInt(g_hConVarLife);
            new iNewHealth = iPlayerHealth + iAddToHealth;
            
            if (GetConVarBool(g_hConVarMaxLife) && iNewHealth <= GetPlayerMaxHealth(iAttacker)) {
                SetPlayerHealth(iAttacker, iNewHealth);
            }
            
            PrintToChat(iAttacker, "[KS] %t", "Life Syphoned", iAddToHealth, iVictim);
        }
    }
}

GetPlayerHealth(iClient) {
    return GetEntProp(iClient, Prop_Send, "m_iHealth");
}

SetPlayerHealth(iClient, iAmount) {
    SetEntProp(iClient, Prop_Send, "m_iHealth", iAmount);
}

GetPlayerMaxHealth(iClient) {
    return GetEntProp(iClient, Prop_Send, "m_iMaxHealth");
}