#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>

public Plugin:myinfo = {
    name = "Riding Crop FF Disabler",
    author = "bl4nk",
    description = "Makes the riding crop do 0 damage to friendlies when FF is on",
    version = "1.0.0",
    url = "http://forums.alliedmods.net/"
};

public OnPluginStart() {
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i)) {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
}

public OnClientPutInServer(iClient) {
    SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action:OnTakeDamage(iVictim, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType, &iWeapon, Float:fDamageForce[3], Float:fDamagePosition[3]) {
    if (iAttacker && iVictim && iAttacker <= MaxClients && iVictim <= MaxClients && GetClientTeam(iVictim) == GetClientTeam(iAttacker) && iWeapon > MaxClients && GetItemIndex(iWeapon) == 447) {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

stock GetItemIndex(iEnt) {
    return GetEntProp(iEnt, Prop_Send, "m_iItemDefinitionIndex");
}