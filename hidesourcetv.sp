#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public OnMapStart() {
    new iIndex = FindEntityByClassname(MaxClients+1, "tf_player_manager");
    if (iIndex == -1) {
        SetFailState("Unable to find tf_player_manager entity");
    }
    
    SDKHook(iIndex, SDKHook_ThinkPost, Hook_OnThinkPost);
}

public Hook_OnThinkPost(iEnt) {
    static iConnectedOffset = -1;
    if (iConnectedOffset == -1) {
        iConnectedOffset = FindSendPropInfo("CTFPlayerResource", "m_bConnected");
    }
    
    new iConnected[35];
    GetEntDataArray(iEnt, iConnectedOffset, iConnected, 35);
    
    for (new i = 1; i < 35; i++) {
        if (iConnected[i] && IsFakeClient(i)) {
            iConnected[i] = 0;
        }
    }
    
    SetEntDataArray(iEnt, iConnectedOffset, iConnected, 35);
}