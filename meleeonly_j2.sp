#pragma semicolon 1

#include <sourcemod>

#define REQUIRE_EXTENSIONS
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#undef REQUIRE_PLUGIN
#include <adminmenu>

#define PLUGIN_VERSION "2.1.0"

#define VOTE_NO "##no##"
#define VOTE_YES "##yes##"

enum {
    WEAPONSLOT_PRIMARY = 0,
    WEAPONSLOT_SECONDARY,
    WEAPONSLOT_MELEE,
    WEAPONSLOT_OTHER1,
    WEAPONSLOT_OTHER2
};

new bool:g_bCloak = true;
new bool:g_bDisguise = true;
new bool:g_bEnabled = false;

new Handle:g_hCvarCloak;
new Handle:g_hCvarDisguise;
new Handle:g_hTopMenu;
new Handle:g_hVoteMenu;
new Handle:g_hWhiteListArray;

public Plugin:myinfo = {
    name = "Melee Only Redux",
    author = "bl4nk",
    description = "Enables gameplay using only melee weapons",
    version = PLUGIN_VERSION,
    url = "http://forums.alliedmods.net"
};

public OnPluginStart() {
    LoadTranslations("meleeonly.phrases");
    LoadTranslations("basevotes.phrases");

    RegAdminCmd("sm_meleeonly", Command_MeleeOnly, ADMFLAG_SLAY, "sm_meleeonly - Toggles melee only");
    RegAdminCmd("sm_meleeonly_vote", Command_Vote, ADMFLAG_VOTE, "sm_meleeonly_vote - Starts a vote for melee only");

    RegServerCmd("sm_meleeonly_whitelist", Command_Whitelist, "sm_meleeonly_whitelist <name> - Whitelists the given weapon name");
    RegServerCmd("sm_meleeonly_remove", Command_Remove, "sm_meleeonly_remove <name|all> - Removes the given weapon name from the whitelist");

    CreateConVar("sm_meleeonly_version", PLUGIN_VERSION, "Melee Only Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    g_hCvarCloak = CreateConVar("sm_meleeonly_cloak", "0", "1 = Allow Spies to cloak, 0 = Don't allow Spies to cloak", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    g_hCvarDisguise = CreateConVar("sm_meleeonly_disguise", "0", "1 = Allow Spies to disguise, 0 = Don't allow Spies to disguise", FCVAR_PLUGIN, true, 0.0, true, 1.0);

    HookConVarChange(g_hCvarCloak, OnConVarChanged);
    HookConVarChange(g_hCvarDisguise, OnConVarChanged);

    HookEvent("post_inventory_application", Event_PostInvApp);

    new Handle:hTopMenu;
    if (LibraryExists("adminmenu") && (hTopMenu = GetAdminTopMenu()) != INVALID_HANDLE)
    {
        OnAdminMenuReady(hTopMenu);
    }

    for (new iClient = 1; iClient <= MaxClients; iClient++) {
        if (IsClientInGame(iClient)) {
            SDKHook(iClient, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
            SDKHook(iClient, SDKHook_PostThink, Hook_PostThink);
        }
    }
}

public OnClientPutInServer(iClient) {
    if (iClient > 0) {
        SDKHook(iClient, SDKHook_WeaponSwitch, Hook_WeaponSwitch);
        SDKHook(iClient, SDKHook_PostThink, Hook_PostThink);
    }
}

public Action:Hook_WeaponSwitch(iClient, iWeapon) {
    if (g_bEnabled) {
        new iEnt = GetPlayerWeaponSlot(iClient, WEAPONSLOT_MELEE);
        if (iEnt && iWeapon != iEnt && !CheckWeaponWhiteList(iWeapon)) {
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public Hook_PostThink(iClient) {
    if (g_bEnabled && IsPlayerAlive(iClient) && TF2_GetPlayerClass(iClient) == TFClass_Spy) {
        if (g_bCloak == false) {
            if (TF2_IsPlayerInCondition(iClient, TFCond_Cloaked)) {
                TF2_RemoveCondition(iClient, TFCond_Cloaked);
            }

            SetEntPropFloat(iClient, Prop_Send, "m_flCloakMeter", 1.0);
        }

        if (g_bDisguise == false) {
            if (TF2_IsPlayerInCondition(iClient, TFCond_Disguising)) {
                TF2_RemoveCondition(iClient, TFCond_Disguising);
            }

            if (TF2_IsPlayerInCondition(iClient, TFCond_Disguised)) {
                TF2_RemoveCondition(iClient, TFCond_Disguised);
            }
        }
    }
}

public Event_PostInvApp(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast) {
    if (g_bEnabled) {
        new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
        if (iClient > 0 && !CheckWeaponWhiteList(GetPlayerWeapon(iClient))) {
            ChangePlayerWeaponSlot(iClient, WEAPONSLOT_MELEE);
        }
    }

    return true;
}

public OnMapStart() {
    g_bEnabled = false;

    if (g_hWhiteListArray == INVALID_HANDLE) {
        g_hWhiteListArray = CreateArray(32);
    } else {
        ClearArray(g_hWhiteListArray);
    }
}

public OnAdminMenuReady(Handle:hTopMenu) {
    if (hTopMenu == g_hTopMenu) {
        return;
    }

    g_hTopMenu = hTopMenu;

    new TopMenuObject:hServerCommands = FindTopMenuCategory(g_hTopMenu, ADMINMENU_SERVERCOMMANDS);
    if (hServerCommands != INVALID_TOPMENUOBJECT) {
        AddToTopMenu(g_hTopMenu,
            "sm_meleeonly",
            TopMenuObject_Item,
            AdminMenu_MeleeOnly,
            hServerCommands,
            "sm_meleeonly",
            ADMFLAG_CUSTOM2);
    }
}

public OnLibraryRemoved(const String:szName[]) {
    if (strcmp(szName, "adminmenu") == 0) {
        g_hTopMenu = INVALID_HANDLE;
    }
}

public AdminMenu_MeleeOnly(Handle:hTopMenu, TopMenuAction:iAction, TopMenuObject:iObjectID, iParam, String:szBuffer[], iMaxLen) {
    if (iAction == TopMenuAction_DisplayOption) {
        Format(szBuffer, iMaxLen, "Melee Only Options");
    } else if (iAction == TopMenuAction_SelectOption) {
        DisplayMeleeMenu(iParam);
    }
}

DisplayMeleeMenu(iClient) {
        new Handle:hMenu = CreateMenu(MeleeMenuHandler);

        switch (g_bEnabled) {
            case true: {
                AddMenuItem(hMenu, "0", "Disable Melee Only");
            }
            case false: {
                AddMenuItem(hMenu, "0", "Enable Melee Only");
            }
        }

        AddMenuItem(hMenu, "1", "Toggle Melee Only Vote");

        SetMenuExitBackButton(hMenu, true);
        DisplayMenu(hMenu, iClient, 0);
}

public MeleeMenuHandler(Handle:hMenu, MenuAction:iAction, iParam1, iParam2) {
    if (iAction == MenuAction_Select) {
        switch (iParam2) {
            case 0: {
                ToggleMeleeOnly();
            }
            case 1: {
                FakeClientCommand(iParam1, "sm_meeleeonly_vote");
            }
        }

        DisplayMeleeMenu(iParam1);
    }
}

public Action:Command_MeleeOnly(iClient, iArgs) {
    ShowActivity2(iClient, "[SM] ", "%N %s melee only", iClient, g_bEnabled ? "disabled" : "enabled");
    ToggleMeleeOnly();
    return Plugin_Handled;
}

public Action:Command_Vote(iClient, iArgs) {
    if (IsVoteInProgress()) {
        ReplyToCommand(iClient, "[SM] %t", "Vote in Progress");
        return Plugin_Handled;
    }

    g_hVoteMenu = CreateMenu(Vote_Callback, MenuAction:MENU_ACTIONS_ALL);
    SetMenuTitle(g_hVoteMenu, "%s Melee Only?", g_bEnabled ? "Disable" : "Enable");
    AddMenuItem(g_hVoteMenu, VOTE_YES, "Yes");
    AddMenuItem(g_hVoteMenu, VOTE_NO, "No");
    SetMenuExitButton(g_hVoteMenu, true);
    VoteMenuToAll(g_hVoteMenu, 20);

    return Plugin_Handled;
}

public Vote_Callback(Handle:hMenu, MenuAction:iAction, iParam1, iParam2) {
    if (iAction == MenuAction_Cancel && iParam1 == VoteCancel_NoVotes) {
        PrintToChatAll("[SM] %t", "No Votes Cast");
    } else if (iAction == MenuAction_VoteEnd) {
        decl String:szItem[64], String:szDisplay[64];
        new iVotes, iTotalVotes;

        GetMenuVoteInfo(iParam2, iVotes, iTotalVotes);
        GetMenuItem(hMenu, iParam1, szItem, sizeof(szItem), _, szDisplay, sizeof(szDisplay));

        if (strcmp(szItem, VOTE_NO) == 0 && iParam1 == 1) {
            iVotes = iTotalVotes - iVotes;
        }

        new Float:fPercent = FloatDiv(float(iVotes),float(iTotalVotes));
        new Float:fLimit = 0.60;

        if ((strcmp(szItem, VOTE_YES) == 0 && FloatCompare(fPercent,fLimit) < 0 && iParam1 == 0) || (strcmp(szItem, VOTE_NO) == 0 && iParam1 == 1))
        {
            LogAction(-1, -1, "Vote failed.");
            PrintToChatAll("[SM] %t", "Vote Failed", RoundToNearest(100.0*fLimit), RoundToNearest(100.0*fPercent), iTotalVotes);
        }
        else
        {
            PrintToChatAll("[SM] %t", "Vote Successful", RoundToNearest(100.0*fPercent), iTotalVotes);
            ToggleMeleeOnly();
        }
    }
}

public Action:Command_Whitelist(iArgs) {
    if (iArgs < 1) {
        PrintToServer("[SM] Usage: sm_meleeonly_whitelist <name> - Whitelists the given weapon name");
        return Plugin_Handled;
    }

    decl String:szArg[32];
    GetCmdArg(1, szArg, sizeof(szArg));

    if (FindStringInArray(g_hWhiteListArray, szArg) > -1) {
        PrintToServer("[SM] Weapon \"%s\" is already whitelisted", szArg);
    } else {
        PushArrayString(g_hWhiteListArray, szArg);
        PrintToServer("[SM] Weapon \"%s\" is now whitelisted", szArg);
    }
    return Plugin_Handled;
}

public Action:Command_Remove(iArgs) {
    if (iArgs < 1) {
        PrintToServer("[SM] Usage: sm_meleeonly_remove <name|all> - Removes the given weapon name from the whitelist");
        return Plugin_Handled;
    }

    decl String:szArg[32];
    GetCmdArg(1, szArg, sizeof(szArg));

    if (strcmp(szArg, "all", false) == 0) {
        ClearArray(g_hWhiteListArray);
    } else {
        new iIndex;
        if ((iIndex = FindStringInArray(g_hWhiteListArray, szArg)) > -1) {
            RemoveFromArray(g_hWhiteListArray, iIndex);
            PrintToServer("[SM] Weapon \"%s\" is no longer whitelisted", szArg);
        } else {
            PrintToServer("[SM] Weapon \"%s\" is not whitelisted", szArg);
        }
    }

    return Plugin_Handled;
}

public OnConVarChanged(Handle:hConVar, const String:szOldValue[], const String:szNewValue[]) {
    new bool:bNewValue = StringToInt(szNewValue) == 0 ? false : true;
    if (hConVar == g_hCvarCloak) {
        g_bCloak = bNewValue;
    } else /*if (hConVar == g_hCvarDisguise)*/ {
        g_bDisguise = bNewValue;
    }
}

EnableMeleeOnly() {
    g_bEnabled = true;
    for (new iClient = 1; iClient <= MaxClients; iClient++) {
        if (IsClientInGame(iClient) && IsPlayerAlive(iClient) && !CheckWeaponWhiteList(GetPlayerWeapon(iClient))) {
            ChangePlayerWeaponSlot(iClient, WEAPONSLOT_MELEE);
        }
    }

    new iEnt = -1;
    while ((iEnt = FindEntityByClassname(iEnt, "obj_sentrygun")) != -1) {
        if (IsSentryEnabled(iEnt)) {
            SetSentryEnabled(iEnt, true);
        }
    }
}

DisableMeleeOnly() {
    g_bEnabled = false;

    new iEnt = -1;
    while ((iEnt = FindEntityByClassname(iEnt, "obj_sentrygun")) != -1) {
        if (!IsSentryEnabled(iEnt)) {
            SetSentryEnabled(iEnt, false);
        }
    }
}

ToggleMeleeOnly() {
    g_bEnabled ? DisableMeleeOnly() : EnableMeleeOnly();
}

bool:CheckWeaponWhiteList(iEnt) {
    if (iEnt > MaxClients && IsValidEntity(iEnt)) {
        decl String:szEntClass[32];
        GetEdictClassname(iEnt, szEntClass, sizeof(szEntClass));

        if (FindStringInArray(g_hWhiteListArray, szEntClass) > -1) {
            return true;
        }
    }

    return false;
}

bool:ChangePlayerWeaponSlot(iClient, iSlot) {
    if (IsClientInGame(iClient) && IsPlayerAlive(iClient)) {
        new iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
        if (iWeapon > MaxClients) {
            SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iWeapon);
            return true;
        }
    }

    return false;
}

GetPlayerWeapon(iClient) {
    return GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

bool:IsSentryEnabled(iEnt) {
    return GetEntProp(iEnt, Prop_Send, "m_bDisabled") ? true : false;
}

SetSentryEnabled(iEnt, bool:iEnabled) {
    SetEntProp(iEnt, Prop_Send, "m_bDisabled", iEnabled);
}
