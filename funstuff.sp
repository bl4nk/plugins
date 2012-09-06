#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>

public Plugin:myinfo = {
    name = "Random Fun Stuff",
    author = "bl4nk",
    description = "Random commands ",
    version = "1.0.0",
    url = "http://forums.joe.to/"
};

new bool:g_bUberCharge[MAXPLAYERS+1];

public OnPluginStart() {
    LoadTranslations("common.phrases.txt");
    
    RegAdminCmd("sm_resize", Command_Resize, ADMFLAG_RCON, "sm_resize <#userid|name> <0.1 - 5.0>");
    RegAdminCmd("sm_thirdperson", Command_ThirdPerson, ADMFLAG_RCON, "sm_thirdperson <#userid|name> <0/1>");
    RegAdminCmd("sm_ubercharge", Command_UberCharge, ADMFLAG_RCON, "sm_ubercharge <#userid|name> <0/1>");
}

public OnClientPutInServer(iClient) {
    g_bUberCharge[iClient] = false;
}

public Action:Command_Resize(iClient, iArgCount) {
    if (iArgCount < 2) {
        ReplyToCommand(iClient, "[SM] Usage: sm_resize <#userid|name> <0.1 - 5.0>");
        return Plugin_Handled;
    }
    
    decl String:szArg1[32], String:szArg2[4];
    GetCmdArg(1, szArg1, sizeof(szArg1));
    GetCmdArg(2, szArg2, sizeof(szArg2));
    
    decl String:szTargetName[MAX_TARGET_LENGTH];
    decl aTargetList[MAXPLAYERS], iTargetCount, bool:bTransIsMulti;
    
    if ((iTargetCount = ProcessTargetString(
        szArg1,
        iClient,
        aTargetList,
        MAXPLAYERS,
        COMMAND_FILTER_CONNECTED,
        szTargetName,
        sizeof(szTargetName),
        bTransIsMulti)) <= 0
    ) {
        ReplyToTargetError(iClient, iTargetCount);
        return Plugin_Handled;
    }
    
    new Float:fRatio = ClampFloat(StringToFloat(szArg2), 0.1, 5.0);
    
    for (new i = 0; i < iTargetCount; i++) {
        if (IsClientInGame(aTargetList[i])) {
            ResizePlayer(aTargetList[i], fRatio);
        }
    }
    
    return Plugin_Handled;
}

public Action:Command_ThirdPerson(iClient, iArgCount) {
    if (iArgCount < 2) {
        ReplyToCommand(iClient, "[SM] Usage: sm_thirdperson <#userid|name> <seconds>");
        return Plugin_Handled;
    }
    
    decl String:szArg1[32], String:szArg2[4];
    GetCmdArg(1, szArg1, sizeof(szArg1));
    GetCmdArg(2, szArg2, sizeof(szArg2));
    
    decl String:szTargetName[MAX_TARGET_LENGTH];
    decl aTargetList[MAXPLAYERS], iTargetCount, bool:bTransIsMulti;
    
    if ((iTargetCount = ProcessTargetString(
        szArg1,
        iClient,
        aTargetList,
        MAXPLAYERS,
        COMMAND_FILTER_CONNECTED,
        szTargetName,
        sizeof(szTargetName),
        bTransIsMulti)) <= 0
    ) {
        ReplyToTargetError(iClient, iTargetCount);
        return Plugin_Handled;
    }
    
    new iMode = ClampInt(StringToInt(szArg2), 0, 2);
    
    for (new i = 0; i < iTargetCount; i++) {
        SetThirdPerson(aTargetList[i], iMode);
    }
    
    return Plugin_Handled;
}

public Action:Command_UberCharge(iClient, iArgCount) {
    if (iArgCount < 2) {
        ReplyToCommand(iClient, "[SM] Usage: sm_ubercharge <#userid|name> <seconds>");
        return Plugin_Handled;
    }
    
    decl String:szArg1[32], String:szArg2[4];
    GetCmdArg(1, szArg1, sizeof(szArg1));
    GetCmdArg(2, szArg2, sizeof(szArg2));
    
    decl String:szTargetName[MAX_TARGET_LENGTH];
    decl aTargetList[MAXPLAYERS], iTargetCount, bool:bTransIsMulti;
    
    if ((iTargetCount = ProcessTargetString(
        szArg1,
        iClient,
        aTargetList,
        MAXPLAYERS,
        COMMAND_FILTER_CONNECTED,
        szTargetName,
        sizeof(szTargetName),
        bTransIsMulti)) <= 0
    ) {
        ReplyToTargetError(iClient, iTargetCount);
        return Plugin_Handled;
    }
    
    new Float:fTime = ClampFloatMin(StringToFloat(szArg2), 0.0);
    
    for (new i = 0; i < iTargetCount; i++) {
        if (!fTime) {
            TF2_RemoveCondition(aTargetList[i], TFCond_Ubercharged);
        } else {
            TF2_AddCondition(aTargetList[i], TFCond_Ubercharged, fTime);
        }
    }
    
    return Plugin_Handled;
}

ResizePlayer(iClient, Float:fRatio) {
    SetEntPropFloat(iClient, Prop_Send, "m_flModelScale", fRatio);
    SetEntPropFloat(iClient, Prop_Send, "m_flStepSize", 18.0 * fRatio);
}

SetThirdPerson(iClient, bMode) {
    SetVariantInt(bMode);
    AcceptEntityInput(iClient, "SetForcedTauntCam");
}

stock ClampInt(iValue, iMin, iMax) {
    if (iValue < iMin) {
        return iMin;
    } else if (iValue > iMax) {
        return iMax;
    }
    
    return iValue;
}

stock Float:ClampFloat(Float:fValue, Float:fMin, Float:fMax) {
    if (fValue < fMin) {
        return fMin;
    } else if (fValue > fMax) {
        return fMax;
    }
    
    return fValue;
}

stock Float:ClampFloatMin(Float:fValue, Float:fMin) {
    if (fValue > fMin) {
        return fMin;
    }
    
    return fValue;
}