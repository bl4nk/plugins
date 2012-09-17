/**
 * - TO DO: -
 * Attacker shouldn't resize right away, but instead upon dying/respawning.
 * The problem with this is they'll never completely reach the max size.
 */

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

new Handle:g_hConVarMaxSize;
new Handle:g_hConVarMinSize;
new Handle:g_hConVarIncrement;

public Plugin:myinfo = {
    name = "Size Changer",
    author = "bl4nk",
    description = "Change the size of players upon kill/death",
    version = "1.0.1",
    url = "http://forums.joe.to/"
};

public OnPluginStart() {
    g_hConVarMaxSize = CreateConVar("sm_sizechanger_max", "1.5", "Biggest Size Ratio a player will be changed to", FCVAR_PLUGIN);
    g_hConVarMinSize = CreateConVar("sm_sizechanger_min", "0.25", "Smallest Size Ratio a player will be changed to", FCVAR_PLUGIN);
    g_hConVarIncrement = CreateConVar("sm_sizechanger_increment", "0.025", "Amount to change a player's Size Ratio by", FCVAR_PLUGIN);

    HookEvent("player_death", Event_PlayerDeath);
}

public Event_PlayerDeath(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast) {
    new iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    new iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

    if (iVictim != iAttacker) {
        if (iVictim && !IsFakeClient(iVictim)) {
            ResizePlayer(iVictim, ClampFloat(GetPlayerSizeRatio(iAttacker) - GetConVarFloat(g_hConVarIncrement), GetConVarFloat(g_hConVarMinSize), GetConVarFloat(g_hConVarMaxSize)));
        }

        if (iAttacker && !IsFakeClient(iAttacker)) {
            ResizePlayer(iAttacker, ClampFloat(GetPlayerSizeRatio(iAttacker) + GetConVarFloat(g_hConVarIncrement), GetConVarFloat(g_hConVarMinSize), GetConVarFloat(g_hConVarMaxSize)));
        }
    }
}

ResizePlayer(iClient, Float:fRatio) {
    SetEntPropFloat(iClient, Prop_Send, "m_flModelScale", fRatio);
    SetEntPropFloat(iClient, Prop_Send, "m_flStepSize", 18.0*fRatio);
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