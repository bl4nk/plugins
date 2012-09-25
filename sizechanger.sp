/**
 * - TO DO: -
 * Can never fully reach max size (size reduced after dying, before set to new size)
 *
 * Spies should change to the size of their disguisee
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

new Float:g_fSizeIncrement[MAXPLAYERS+1];

new Handle:g_hConVarEnable;
new Handle:g_hConVarMaxSize;
new Handle:g_hConVarMinSize;
new Handle:g_hConVarIncrement;

public Plugin:myinfo = {
    name = "Size Changer",
    author = "bl4nk",
    description = "Change the size of players upon kill/death",
    version = "1.0.2",
    url = "http://forums.joe.to/"
};

public OnPluginStart() {
    g_hConVarEnable = CreateConVar("sm_sizechanger_enable", "1", "Enable the plugin", FCVAR_PLUGIN);
    g_hConVarMaxSize = CreateConVar("sm_sizechanger_max", "1.5", "Biggest Size Ratio a player will be changed to", FCVAR_PLUGIN);
    g_hConVarMinSize = CreateConVar("sm_sizechanger_min", "0.25", "Smallest Size Ratio a player will be changed to", FCVAR_PLUGIN);
    g_hConVarIncrement = CreateConVar("sm_sizechanger_increment", "0.05", "Amount to change a player's Size Ratio by", FCVAR_PLUGIN);

    HookEvent("player_death", Event_PlayerDeath);
}

public OnClientPutInServer(iClient) {
    g_fSizeIncrement[iClient] = 0.0;
}

public Event_PlayerDeath(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast) {
    if (!GetConVarBool(g_hConVarEnable)) {
        return;
    }

    new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

    if (iVictim != iAttacker && GetClientTeam(iVictim) != GetClientTeam(iAttacker)) {
        if (iVictim && !IsFakeClient(iVictim)) {
            g_fSizeIncrement[iVictim] -= GetConVarFloat(g_hConVarIncrement);

            ResizePlayer(
                iVictim,
                ClampFloat(
                    GetPlayerSizeRatio(iVictim) + g_fSizeIncrement[iVictim],
                    GetConVarFloat(g_hConVarMinSize),
                    GetConVarFloat(g_hConVarMaxSize)
                )
            );

            g_fSizeIncrement[iVictim] = 0.0;
        }

        if (iAttacker && !IsFakeClient(iAttacker)) {
            g_fSizeIncrement[iAttacker] += GetConVarFloat(g_hConVarIncrement);
        }
    }
}

ResizePlayer(iClient, Float:fRatio) {
    SetEntPropFloat(iClient, Prop_Send, "m_flModelScale", fRatio);
    SetEntPropFloat(iClient, Prop_Send, "m_flStepSize", 18.0 * fRatio);
}

Float:GetPlayerSizeRatio(iClient) {
    return GetEntPropFloat(iClient, Prop_Send, "m_flModelScale");
}

Float:ClampFloat(Float:fValue, Float:fMin, Float:fMax) {
    if (fValue < fMin) {
        return fMin;
    } else if (fValue > fMax) {
        return fMax;
    }

    return fValue;
}