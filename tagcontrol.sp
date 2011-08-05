#pragma semicolon 1

#include <sourcemod>
#include <tagcontrol>

new Handle:g_hTagArray;

public Plugin:myinfo = {
    name = "TagControl",
    author = "bl4nk",
    description = "Control which tags show up and which don't",
    version = "1.0.0",
    url = "http://forums.alliedmods.net/"
};

public OnPluginStart() {
    RegAdminCmd("sm_tagcontrol_add", Command_Add, ADMFLAG_RCON, "sm_tagcontrol_add <Tag> - Blocks the supplied Tag");
    RegAdminCmd("sm_tagcontrol_remove", Command_Remove, ADMFLAG_RCON, "sm_tagcontrol_remove <Tag> - Unblocks the supplied Tag");
    RegAdminCmd("sm_tagcontrol_list", Command_List, ADMFLAG_RCON, "sm_tagcontrol_list - Lists all Tags that are being blocked");

    g_hTagArray = CreateArray(32);
}

public Action:Command_Add(iClient, iArgCount) {
    if (iArgCount < 1) {
        ReplyToCommand(iClient, "[SM] Usage: sm_tagcontrol_add <Tag> - Blocks the supplied tag");
        return Plugin_Handled;
    }

    decl String:szTag[32];
    GetCmdArg(1, szTag, sizeof(szTag));

    if (FindStringInArray(g_hTagArray, szTag) > -1) {
        ReplyToCommand(iClient, "[SM] The Tag \"%s\" is already being blocked", szTag);
        return Plugin_Handled;
    }

    PushArrayString(g_hTagArray, szTag);
    ReplyToCommand(iClient, "[SM] Now blocking Tag \"%s\"", szTag);

    return Plugin_Handled;
}

public Action:Command_Remove(iClient, iArgCount) {
    if (iArgCount < 1) {
        ReplyToCommand(iClient, "[SM] Usage: sm_tagcontrol_remove <Tag> - Unblocks the supplied Tag");
        return Plugin_Handled;
    }

    decl String:szTag[32];
    GetCmdArg(1, szTag, sizeof(szTag));

    new iIndex;
    if ((iIndex = FindStringInArray(g_hTagArray, szTag)) > -1) {
        RemoveFromArray(g_hTagArray, iIndex);

        ReplyToCommand(iClient, "[SM] The Tag \"%s\" is no longer being blocked", szTag);
        return Plugin_Handled;
    }

    ReplyToCommand(iClient, "[SM] Could not find Tag \"%s\"", szTag);

    return Plugin_Handled;
}

public Action:Command_List(iClient, iArgCount) {
    new iSize = GetArraySize(g_hTagArray);
    if (!iSize) {
        ReplyToCommand(iClient, "[SM] No Tags are being blocked");
        return Plugin_Handled;
    }

    new String:szTags[192];
    for (new i = 0; i < iSize; i++) {
        decl String:szBuffer[32];
        GetArrayString(g_hTagArray, i, szBuffer, sizeof(szBuffer));

        StrCat(szTags, sizeof(szTags), szBuffer);
    }

    ReplyToCommand(iClient, "[SM] Blocked Tags: %s", szTags);

    return Plugin_Handled;
}

public Action:OnAddTag(const String:szTag[]) {
    if (FindStringInArray(g_hTagArray, szTag) > -1) {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}