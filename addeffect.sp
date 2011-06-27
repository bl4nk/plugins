#pragma semicolon 1

#include <sourcemod>
#include <tf2items>

public Plugin:myinfo = {
    name = "",
    author = "bl4nk",
    description = "",
    version = "1.0.0",
    url = "http://forums.alliedmods.net/"
};

new g_iEffect[MAXPLAYERS+1];

public OnPluginStart() {
    RegAdminCmd("sm_addeffect", Command_AddEffect, ADMFLAG_RCON, "sm_addeffect <#userid|name> <index> <effect>");
}

public OnClientPutInServer(iClient) {
    g_iEffect[iClient] = 0;
}

public Action:Command_AddEffect(iClient, iArgCount) {
    if (iArgCount < 2) {
        ReplyToCommand(iClient, "[SM] Usage: sm_addeffect <#userid|name> <effect>");
        return Plugin_Handled;
    }
    
    decl String:szTarget[65];
    GetCmdArg(1, szTarget, sizeof(szTarget));

    decl String:szTargetName[MAX_TARGET_LENGTH+1];
    decl iTargetList[MAXPLAYERS+1], iTargetCount, bool:bTnIsMl;

    if ((iTargetCount = ProcessTargetString(
            szTarget,
            iClient,
            iTargetList,
            MAXPLAYERS,
            COMMAND_FILTER_CONNECTED,
            szTargetName,
            sizeof(szTargetName),
            bTnIsMl)) <= 0)
    {
        ReplyToTargetError(iClient, iTargetCount);
        return Plugin_Handled;
    }
    
    decl String:szEffect[4];
    GetCmdArg(2, szEffect, sizeof(szEffect));
    
    new iEffect = StringToInt(szEffect);
    
    for (new i = 0; i < iTargetCount; i++)
    {
        g_iEffect[iTargetList[i]] = iEffect;
    }
    
    return Plugin_Handled;
}

public Action:TF2Items_OnGiveNamedItem(iClient, String:szClassName[], iItemDefinitionIndex, &Handle:hItem) {
    if (g_iEffect[iClient] > 0) {
        if (hItem == INVALID_HANDLE) {
            hItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES);
            TF2Items_SetNumAttributes(hItem, 1);
            TF2Items_SetAttribute(hItem, 0, 134, float(g_iEffect[iClient]));
        } else {
            new iFlags = TF2Items_GetFlags(hItem);
            if (!(iFlags & OVERRIDE_ATTRIBUTES)) {
                TF2Items_SetFlags(hItem, iFlags|OVERRIDE_ATTRIBUTES);
            }
            
            new iAttributeCount = TF2Items_GetNumAttributes(hItem);
            TF2Items_SetNumAttributes(hItem, iAttributeCount+1);
            TF2Items_SetAttribute(hItem, iAttributeCount, 134, float(g_iEffect[iClient]));
        }
        
        return Plugin_Changed;
    }
    
    return Plugin_Continue;
}