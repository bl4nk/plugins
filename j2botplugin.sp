/**
 * Working:
 *   - Menu and voting system
 *   - Bots can be added based on class and difficulty
 *   - All bots can be kicked from the server
 *   - Melee Only, Bonk!, and Fisto modes
 * To-do:
 *   - Multiple bot modes shouldn't be allowed to be active at the same time
 *   - For bot melee modes, move all bots to one team and players to the other
 *   - Make it so bots can be individually removed
 *   - Hide messages of bots joining/leaving/bot counts changing/etc
 *   - Change bots classes back after Bonk! or Fisto modes are disabled
 *   - When all bots are removed, all modes should disable automatically
 */

#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>

enum {
    VoteType_AddBot = 0,
    VoteType_MeleeMode,
    VoteType_BonkMode,
    VoteType_FistoMode,
    VoteType_RemoveAllBots,
    VoteType_None
}

enum {
    Difficulty_Easy = 0,
    Difficulty_Normal,
    Difficulty_Hard,
    Difficulty_Expert
}

enum {
    TF2Class_Scout = 0,
    TF2Class_Soldier,
    TF2Class_Pyro,
    TF2Class_DemoMan,
    TF2Class_Heavy,
    TF2Class_Engineer,
    TF2Class_Medic,
    TF2Class_Sniper,
    TF2Class_Spy
}

static const String:g_szVoteTypes[][] = {
    "Add Bots",
    "Melee Only Mode",
    "Bonk! Mode",
    "Fisto! Mode",
    "Remove All Bots"
};

new g_iAddBotClass[MAXPLAYERS+1];
new g_iBotDifficulty;
new g_iBotQuota;
new g_iVoteStarter = -1;
new g_iVoteType = VoteType_None;

new bool:g_bCVarMeleeOnly;
new bool:g_bIsAdmin[MAXPLAYERS+1];
new bool:g_bNavExists;
new bool:g_bBonkMode;
new bool:g_bFistoMode;
new bool:g_bMeleeMode;

new Handle:g_hCurrentMenu[MAXPLAYERS+1];
new Handle:g_hCVarBotQuota;
new Handle:g_hCVarBotQuotaMode;
new Handle:g_hCVarKeepClass;
new Handle:g_hCVarMeleeOnly;

public Plugin:myinfo = {
    name = "BotPlugin",
    author = "bl4nk",
    description = "Handles adding/removing bots (as well as special bot modes) through voting",
    version = "1.0.0",
    url = "http://forums.alliedmods.net/"
};

public OnPluginStart() {
    LoadTranslations("basevotes.phrases");

    g_hCVarBotQuota = FindConVar("tf_bot_quota");
    g_hCVarBotQuotaMode = FindConVar("tf_bot_quota_mode");
    g_hCVarKeepClass = FindConVar("tf_bot_keep_class_after_death");
    g_hCVarMeleeOnly = FindConVar("tf_bot_melee_only");

    HookConVarChange(g_hCVarBotQuota, CVarChange_BotQuota);
    HookConVarChange(g_hCVarBotQuotaMode, CVarChange_BotQuotaMode);
    HookConVarChange(g_hCVarKeepClass, CVarChange_KeepClass);
    HookConVarChange(g_hCVarMeleeOnly, CVarChange_MeleeOnly);

    RegConsoleCmd("sm_bots", Command_Bots, "Control the bots on the server");

    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientAuthorized(i)) {
            g_bIsAdmin[i] = CheckCommandAccess(i, "sm_bots", ADMFLAG_GENERIC);
        }
    }
}

public OnMapStart() {
    decl String:szCurrentMap[32];
    GetCurrentMap(szCurrentMap, sizeof(szCurrentMap));

    if (!(g_bNavExists = NavFileExists(szCurrentMap))) {
        LogMessage("No .nav file for the current map (%s)", szCurrentMap);

        if (!GetClientCount2(true, false, false, false) && g_iBotQuota) {
            SetConVarInt(g_hCVarBotQuota, 0);
        }
    }
}

public OnClientPostAdminCheck(iClient) {
    g_bIsAdmin[iClient] = CheckCommandAccess(iClient, "sm_bots", ADMFLAG_GENERIC);
}

public Action:Command_Bots(iClient, iArgCount) {
    if (!g_bNavExists) {
        ReplyToCommand(iClient, "[SM] No .nav file for this map :(");
    } else if (g_iVoteType < VoteType_None) {
        ReplyToCommand(iClient, "[SM] There is a bot vote already in progress");
    } else {
        DisplayMainMenu(iClient);
    }

    return Plugin_Handled;
}

public CVarChange_BotQuota(Handle:hCVar, const String:szOldValue[], const String:szNewValue[]) {
    if (!g_iBotQuota) {
        decl String:szBotQuotaMode[12];
        GetConVarString(g_hCVarBotQuotaMode, szBotQuotaMode, sizeof(szBotQuotaMode));

        if (strcmp(szBotQuotaMode, "normal", false)) {
            SetConVarString(g_hCVarBotQuotaMode, "normal");
        }
    }

    g_iBotQuota = StringToInt(szNewValue);
}

public CVarChange_BotQuotaMode(Handle:hCVar, const String:szOldValue[], const String:szNewValue[]) {
    if (g_iBotQuota && strcmp(szNewValue, "normal", false)) {
        SetConVarString(hCVar, "normal");
    }
}

public CVarChange_KeepClass(Handle:hCVar, const String:szOldValue[], const String:szNewValue[]) {
    if (g_iBotQuota && (g_bBonkMode || g_bFistoMode) && !StringToInt(szNewValue)) {
        SetConVarBool(g_hCVarKeepClass, true);
    }
}

public CVarChange_MeleeOnly(Handle:hCVar, const String:szOldValue[], const String:szNewValue[]) {
    g_bCVarMeleeOnly = (StringToInt(szNewValue) ? true : false);

    if ((g_bBonkMode || g_bFistoMode || g_bMeleeMode) && !g_bCVarMeleeOnly) {
        SetConVarBool(g_hCVarMeleeOnly, true);
    }
}

DisplayMainMenu(iClient) {
    new Handle:hMenu = CreateMenu(MainMenuHandler, MenuAction_Select|MenuAction_End);

    if (g_bIsAdmin[iClient]) {
        SetMenuTitle(hMenu, "Choose an action:");
    } else {
        SetMenuTitle(hMenu, "Choose a vote action:");
    }

    SetMenuExitButton(hMenu, true);

    AddMenuItem(hMenu, "add", "Add Bot");

    decl String:szBuffer[24];

    Format(szBuffer, sizeof(szBuffer), "%s Bot Melee Mode", (g_bMeleeMode ? "Disable" : "Enable"));
    AddMenuItem(hMenu, "melee", szBuffer);

    Format(szBuffer, sizeof(szBuffer), "%s Bonk! Mode", (g_bBonkMode ? "Disable" : "Enable"));
    AddMenuItem(hMenu, "bonk", szBuffer);

    Format(szBuffer, sizeof(szBuffer), "%s Fisto Mode", (g_bFistoMode ? "Disable" : "Enable"));
    AddMenuItem(hMenu, "fisto", szBuffer);

    AddMenuItem(hMenu, "remove", "Remove all bots");

    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

public MainMenuHandler(Handle:hMenu, MenuAction:iAction, iParam1, iParam2) {
    if (iAction == MenuAction_Select) { // iParam1=client, iParam2=choice
        decl String:szInfo[32];
        GetMenuItem(hMenu, iParam2, szInfo, sizeof(szInfo));

        if (strcmp(szInfo, "add") == 0) {
            DisplayAddBotMenu(iParam1);
        } else if (strcmp(szInfo, "melee") == 0) {
            if (g_bIsAdmin[iParam1]) {
                g_bMeleeMode = !g_bMeleeMode;
                SetConVarBool(g_hCVarMeleeOnly, g_bMeleeMode);
            } else {
                g_iVoteType = VoteType_MeleeMode;
                StartVote(iParam1);
            }
        } else if (strcmp(szInfo, "bonk") == 0) {
            if (g_bIsAdmin[iParam1]) {
                g_bBonkMode = !g_bBonkMode;

                if (g_bBonkMode) {
                    SetConVarBool(g_hCVarKeepClass, true);
                    SetConVarBool(g_hCVarMeleeOnly, true);

                    RespawnBotsAsClass(TFClass_Scout);
                } else {
                    SetConVarBool(g_hCVarKeepClass, false);

                    if (!g_bMeleeMode) {
                        SetConVarBool(g_hCVarMeleeOnly, false);
                    }
                }
            } else {
                g_iVoteType = VoteType_BonkMode;
                StartVote(iParam1);
            }
        } else if (strcmp(szInfo, "fisto") == 0) {
            if (g_bIsAdmin[iParam1]) {
                g_bFistoMode = !g_bFistoMode;

                if (g_bBonkMode) {
                    SetConVarBool(g_hCVarKeepClass, true);
                    SetConVarBool(g_hCVarMeleeOnly, true);

                    RespawnBotsAsClass(TFClass_Heavy);
                } else {
                    SetConVarBool(g_hCVarKeepClass, false);

                    if (!g_bMeleeMode) {
                        SetConVarBool(g_hCVarMeleeOnly, false);
                    }
                }
            } else {
                g_iVoteType = VoteType_FistoMode;
                StartVote(iParam1);
            }
        } else if (strcmp(szInfo, "remove") == 0) {
            if (g_bIsAdmin[iParam1]) {
                ServerCommand("tf_bot_kick all");
            } else {
                g_iVoteType = VoteType_RemoveAllBots;
                StartVote(iParam1);
            }
        }
    } else if (iAction == MenuAction_End) { // iParam1=end reason
        ResetMenuHandle(FindMenuOwner(hMenu), hMenu);
    }
}

DisplayAddBotMenu(iClient) {
    g_hCurrentMenu[iClient] = CreateMenu(AddBotMenuHandler, MenuAction_Select|MenuAction_End);

    SetMenuTitle(g_hCurrentMenu[iClient], "Select a class:");

    SetMenuPagination(g_hCurrentMenu[iClient], 5);
    SetMenuExitBackButton(g_hCurrentMenu[iClient], true);

    AddMenuItem(g_hCurrentMenu[iClient], "scout", "Scout");
    AddMenuItem(g_hCurrentMenu[iClient], "soldier", "Soldier");
    AddMenuItem(g_hCurrentMenu[iClient], "pyro", "Pyro");
    AddMenuItem(g_hCurrentMenu[iClient], "demo", "Demoman");
    AddMenuItem(g_hCurrentMenu[iClient], "heavy", "Heavy");
    AddMenuItem(g_hCurrentMenu[iClient], "engy", "Engineer");
    AddMenuItem(g_hCurrentMenu[iClient], "medic", "Medic");
    AddMenuItem(g_hCurrentMenu[iClient], "sniper", "Sniper");
    AddMenuItem(g_hCurrentMenu[iClient], "spy", "Spy");

    DisplayMenu(g_hCurrentMenu[iClient], iClient, MENU_TIME_FOREVER);
}

public AddBotMenuHandler(Handle:hMenu, MenuAction:iAction, iParam1, iParam2) {
    if (iAction == MenuAction_Select) { // iParam1=client, iParam2=choice
        g_iAddBotClass[iParam1] = iParam2;
        DisplayDifficultyMenu(iParam1);
    } else if (iAction == MenuAction_End) { // iParam1=end reason
        if (iParam1 == MenuEnd_ExitBack) {
            DisplayMainMenu(FindMenuOwner(hMenu));
        }

        ResetMenuHandle(FindMenuOwner(hMenu), hMenu);
    }
}

DisplayDifficultyMenu(iClient) {
    g_hCurrentMenu[iClient] = CreateMenu(DifficultyMenuHandler, MenuAction_Select|MenuAction_End);

    SetMenuTitle(g_hCurrentMenu[iClient], "Choose a difficulty:");
    SetMenuExitBackButton(g_hCurrentMenu[iClient], true);

    AddMenuItem(g_hCurrentMenu[iClient], "easy", "Easy");
    AddMenuItem(g_hCurrentMenu[iClient], "normal", "Normal");
    AddMenuItem(g_hCurrentMenu[iClient], "hard", "Hard");
    AddMenuItem(g_hCurrentMenu[iClient], "expert", "Expert");

    DisplayMenu(g_hCurrentMenu[iClient], iClient, 15);
}

public DifficultyMenuHandler(Handle:hMenu, MenuAction:iAction, iParam1, iParam2) {
    if (iAction == MenuAction_Select) { // iParam1=client, iParam2=difficulty
        if (g_bIsAdmin[iParam1]) {
            decl String:szClass[32], String:szDifficulty[16];
            GetClassName(g_iAddBotClass[g_iVoteStarter], szClass, sizeof(szClass));
            GetDifficulty(g_iBotDifficulty, szDifficulty, sizeof(szDifficulty));

            if (GetTeamClientCount(_:TFTeam_Blue) > GetTeamClientCount(_:TFTeam_Red)) {
                ServerCommand("tf_bot_add 1 %s red %s", szClass, szDifficulty);
            } else {
                ServerCommand("tf_bot_add 1 %s blue %s", szClass, szDifficulty);
            }
        } else {
            g_iBotDifficulty = iParam2;
            g_iVoteStarter = iParam1;
            g_iVoteType = VoteType_AddBot;

            StartVote(iParam1);
        }
    } else if (iAction == MenuAction_End) { // iParam1=end reason
        if (iParam1 == MenuEnd_ExitBack) {
            DisplayAddBotMenu(FindMenuOwner(hMenu));
        }

        ResetMenuHandle(FindMenuOwner(hMenu), hMenu);
    }
}

StartVote(iClient) {
    decl String:szAuth[32], String:szTitle[32];
    GetClientAuthString(iClient, szAuth, sizeof(szAuth));

    switch (g_iVoteType) {
        case VoteType_AddBot: {
            decl String:szDifficulty[12], String:szClass[32];
            GetDifficulty(g_iBotDifficulty, szDifficulty, sizeof(szDifficulty));
            GetClassName(g_iAddBotClass[iClient], szClass, sizeof(szClass));

            Format(szTitle, sizeof(szTitle), "Add %s %s Bot", szDifficulty, szClass);
        }
        case VoteType_MeleeMode: {
            Format(szTitle, sizeof(szTitle), "%s Bot Melee Mode", (g_bMeleeMode ? "Disable" : "Enable"));
        }
        case VoteType_BonkMode: {
            Format(szTitle, sizeof(szTitle), "%s Bonk! Mode", (g_bBonkMode ? "Disable" : "Enable"));
        }
        case VoteType_FistoMode: {
            Format(szTitle, sizeof(szTitle), "%s Fisto Mode", (g_bFistoMode ? "Disable" : "Enable"));
        }
        default: {
            strcopy(szTitle, sizeof(szTitle), g_szVoteTypes[g_iVoteType]);
        }
    }

    decl String:szMessage[128];
    Format(szMessage, sizeof(szMessage), "%N (%s) started a %s vote", iClient, szAuth, szTitle);

    LogMessage("[SM] %s", szMessage);

    new Handle:hMenu = CreateMenu(Vote_MenuCallback, MenuAction_Select|MenuAction_VoteEnd|MenuAction_VoteCancel);
    SetVoteResultCallback(hMenu, Vote_ResultsCallback);

    SetMenuTitle(hMenu, szTitle);
    SetMenuExitButton(hMenu, true);

    AddMenuItem(hMenu, "", "");
    AddMenuItem(hMenu, "", "");
    AddMenuItem(hMenu, "", "");
    AddMenuItem(hMenu, "yes", "Yes");
    AddMenuItem(hMenu, "no", "No");

    VoteMenuToAll(hMenu, 20);
}

public Vote_MenuCallback(Handle:hMenu, MenuAction:iAction, iParam1, iParam2) {
    if (iAction == MenuAction_Select) { // iParam1=client, iParam2=choice
        decl String:szItem[32];
        GetMenuItem(hMenu, iParam2, szItem, sizeof(szItem));

        if (!strlen(szItem)) {
            RedrawClientVoteMenu(iParam1);
        }
    } else if (iAction == MenuAction_VoteCancel) {
        switch (iParam1) {
            case VoteCancel_Generic: {
                PrintToChatAll("[SM] Vote cancelled");
            }
            case VoteCancel_NoVotes: {
                PrintToChatAll("[SM] Vote failed, no votes received");
            }
        }

        g_iVoteStarter = -1;
        g_iVoteType = VoteType_None;
    }
}

public Vote_ResultsCallback(Handle:hMenu, iNumVotes, iNumClients, const iCientInfo[][2], iNumItems, const iItemInfo[][2]) {
    decl String:szItem[8];
    GetMenuItem(hMenu, iItemInfo[0][VOTEINFO_ITEM_INDEX], szItem, sizeof(szItem));

    if (strcmp(szItem, "yes") == 0) {
        PrintToChatAll("[SM] Vote successful");
        switch (g_iVoteType) {
            case VoteType_AddBot: {
                decl String:szClass[32], String:szDifficulty[16];
                GetClassName(g_iAddBotClass[g_iVoteStarter], szClass, sizeof(szClass));
                GetDifficulty(g_iBotDifficulty, szDifficulty, sizeof(szDifficulty));

                ServerCommand("tf_bot_add 1 %s %s %s", szClass, ((GetTeamClientCount(_:TFTeam_Blue) > GetTeamClientCount(_:TFTeam_Red)) ? "blue" : "red"), szDifficulty);

                g_iVoteStarter = -1;
            }
            case VoteType_MeleeMode: {
                g_bMeleeMode = !g_bMeleeMode;
                SetConVarBool(g_hCVarMeleeOnly, g_bMeleeMode);
            }
            case VoteType_BonkMode: {
                g_bBonkMode = !g_bBonkMode;

                if (g_bBonkMode) {
                    SetConVarBool(g_hCVarKeepClass, true);
                    SetConVarBool(g_hCVarMeleeOnly, true);

                    RespawnBotsAsClass(TFClass_Scout);
                } else {
                    SetConVarBool(g_hCVarKeepClass, false);

                    if (!g_bMeleeMode) {
                        SetConVarBool(g_hCVarMeleeOnly, false);
                    }
                }
            }
            case VoteType_FistoMode: {
                g_bFistoMode = !g_bFistoMode;

                if (g_bFistoMode) {
                    SetConVarBool(g_hCVarKeepClass, true);
                    SetConVarBool(g_hCVarMeleeOnly, true);

                    RespawnBotsAsClass(TFClass_Heavy);
                } else {
                    SetConVarBool(g_hCVarKeepClass, false);

                    if (!g_bMeleeMode) {
                        SetConVarBool(g_hCVarMeleeOnly, false);
                    }
                }
            }
            case VoteType_RemoveAllBots: {
                ServerCommand("tf_bot_kick all");
            }
        }
    } else {
        PrintToChatAll("[SM] Vote failed");
    }

    g_iVoteType = VoteType_None;
}

stock bool:NavFileExists(const String:szMapName[]) {
    decl String:szPath[PLATFORM_MAX_PATH];
    Format(szPath, sizeof(szPath), "maps/%s.nav", szMapName);

    return FileExists(szPath, true);
}

stock GetClientCount2(bool:bInGameOnly=true, bool:bCountBots=true, bool:bCountReplay=true, bool:bCountSourceTV=true) {
    new iCount;
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i)) {
            if (!bInGameOnly || IsClientInGame(i)) {
                if (IsFakeClient(i)) {
                    new bool:bIsReplay = IsClientReplay(i), bool:bIsSourceTV = IsClientSourceTV(i);
                    if (bIsReplay && bCountReplay || bIsSourceTV && bCountSourceTV) {
                        iCount++;
                    } else if (bCountBots) {
                        if (bIsReplay || bIsSourceTV) {
                            continue;
                        }

                        iCount++;
                    }
                } else {
                    iCount++;
                }
            }
        }
    }

    return iCount;
}

GetClassName(iClass, String:szBuffer[], iMaxLen) {
    switch (iClass) {
        case TF2Class_Scout: {
            Format(szBuffer, iMaxLen, "Scout");
        }
        case TF2Class_Soldier: {
            Format(szBuffer, iMaxLen, "Soldier");
        }
        case TF2Class_Pyro: {
            Format(szBuffer, iMaxLen, "Pyro");
        }
        case TF2Class_DemoMan: {
            Format(szBuffer, iMaxLen, "Demoman");
        }
        case TF2Class_Heavy: {
            Format(szBuffer, iMaxLen, "Heavyweapons");
        }
        case TF2Class_Engineer: {
            Format(szBuffer, iMaxLen, "Engineer");
        }
        case TF2Class_Medic: {
            Format(szBuffer, iMaxLen, "Medic");
        }
        case TF2Class_Sniper: {
            Format(szBuffer, iMaxLen, "Sniper");
        }
        case TF2Class_Spy: {
            Format(szBuffer, iMaxLen, "Spy");
        }
    }
}

GetDifficulty(iDifficulty, String:szBuffer[], iMaxLen) {
    switch (iDifficulty) {
        case Difficulty_Easy: {
            Format(szBuffer, iMaxLen, "Easy");
        }
        case Difficulty_Normal: {
            Format(szBuffer, iMaxLen, "Normal");
        }
        case Difficulty_Hard: {
            Format(szBuffer, iMaxLen, "Hard");
        }
        case Difficulty_Expert: {
            Format(szBuffer, iMaxLen, "Expert");
        }
    }
}

FindMenuOwner(Handle:hMenu) {
    for (new i = 1; i <= MaxClients; i++) {
        if (g_hCurrentMenu[i] == hMenu) {
            return i;
        }
    }

    return false;
}

ResetMenuHandle(iClient, Handle:hMenu) {
    if (hMenu == g_hCurrentMenu[iClient]) {
        g_hCurrentMenu[iClient] = INVALID_HANDLE;
    }
}

RespawnBotsAsClass(TFClassType:iClass) {
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && IsFakeClient(i)) {
            TF2_SetPlayerClass(i, iClass);

            if (IsPlayerAlive(i)) {
                TF2_RespawnPlayer(i);
            }
        }
    }
}