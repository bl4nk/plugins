#pragma semicolon 1

#include <sourcemod>
#include <steamtools>

new Handle:g_hConvarID;
new Handle:g_hConvarName;
new Handle:g_hDatabase;

new String:g_szMapName[32];
new String:g_szServerName[32];
new String:g_szServerIP[24];
new String:g_szClientChoiceIP[MAXPLAYERS+1][24];

public Plugin:myinfo = {
    name = "ServerInfo2",
    author = "bl4nk",
    description = "Provides a means of viewing and connecting to our other servers",
    version = "1.0.0-j2",
    url = "http://forums.alliedmods.net/"
};

public OnPluginStart() {
    g_hConvarID = CreateConVar("sm_serverinfo_id", "0", "Position of the server on the list (starts at 1, 0 = disabled)", FCVAR_PLUGIN, true, 0.0, false, _);
    g_hConvarName = CreateConVar("sm_serverinfo_name", "Rename Me!", "Name of the server on the list", FCVAR_PLUGIN);

    RegConsoleCmd("sm_servers", Command_Servers, "sm_servers - Brings up the joe.to server list");

    new iServerIP[4];
    Steam_GetPublicIP(iServerIP);
    Format(g_szServerIP, sizeof(g_szServerIP), "%i.%i.%i.%i:%i", iServerIP[0], iServerIP[1], iServerIP[2], iServerIP[3], GetConVarInt(FindConVar("hostport")));

    HookConVarChange(g_hConvarName, OnConVarChanged);

    SQL_TConnect(SQL_Connected);
}

public OnMapStart() {
    GetCurrentMap(g_szMapName, sizeof(g_szMapName));
    UpdateServerData();
}

public bool:OnClientConnect(iClient, String:szRejectMsg[], iMaxLen) {
    UpdateServerData();
    return true;
}

public OnClientDisconnect(iClient) {
    UpdateServerData();
}

public OnConfigsExecuted() {
    GetConVarString(g_hConvarName, g_szServerName, sizeof(g_szServerName));
}

public OnConVarChanged(Handle:hConvar, const String:szOldValue[], const String:szNewValue[]) {
    strcopy(g_szServerName, sizeof(g_szServerName), szNewValue);
}

public Action:Command_Servers(iClient, iArgs) {
    if (!iClient) {
        ReplyToCommand(iClient, "[SM] This command can only be ran from in game.");
        return Plugin_Handled;
    }

    DisplayMainMenu(iClient);
    return Plugin_Handled;
}

public SQL_Connected(Handle:hOwner, Handle:hDatabase, const String:szError[], any:data) {
    if (hDatabase == INVALID_HANDLE) {
        SetFailState("Database failure: %s", szError);
    }

    g_hDatabase = hDatabase;

    SQL_CreateTables();
    SQL_SendQuery("SET NAMES 'utf8'");

    UpdateServerData();
    CreateTimer(30.0, Timer_UpdateServerData, _, TIMER_REPEAT);
}

public Action:Timer_UpdateServerData(Handle:hTimer) {
    UpdateServerData();
}

SQL_CreateTables() {
    static const String:szQuery[] =
        "CREATE TABLE IF NOT EXISTS `serverinfo` ( \
          `id` TINYINT NOT NULL default 0, \
          `name` VARCHAR(32) NOT NULL, \
          `map` VARCHAR(32) NOT NULL, \
          `clients` TINYINT NOT NULL, \
          `maxclients` TINYINT NOT NULL, \
          `ip` VARCHAR(32) NOT NULL, \
          `lastupdate` INT UNSIGNED NOT NULL, \
          PRIMARY KEY (`id`) \
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 ;";

    SQL_SendQuery(szQuery);
}

UpdateServerData() {
    new iServerID = GetConVarInt(g_hConvarID);
    if (iServerID > 0) {
        decl String:szQuery[448];
        Format(szQuery, sizeof(szQuery), "INSERT INTO `serverinfo` (id, name, map, clients, maxclients, ip, lastupdate) VALUES (%i, '%s', '%s', %i, %i, '%s', %i) ON DUPLICATE KEY UPDATE name = VALUES(name), map = VALUES(map), clients = VALUES(clients), maxclients = VALUES(maxclients), ip = VALUES(ip), lastupdate = VALUES(lastupdate)", iServerID, g_szServerName, g_szMapName, GetClientCount(false), MaxClients, g_szServerIP, GetTime());

        SQL_SendQuery(szQuery);
    }
}

DisplayMainMenu(iClient) {
    SQL_TQuery(g_hDatabase, SQL_DisplayMainMenu, "SELECT id, name, clients, maxclients, lastupdate FROM serverinfo ORDER BY id ASC", GetClientUserId(iClient));
}

public SQL_DisplayMainMenu(Handle:hOwner, Handle:hHndl, const String:szError[], any:iUserId) {
    new iClient = GetClientOfUserId(iUserId);
    if (!iClient) {
        return;
    }

    new Handle:hPanel = CreatePanel();

    SetPanelTitle(hPanel, "Servers");
    DrawPanelText(hPanel, " ");

    while (SQL_FetchRow(hHndl)) {
        decl String:szServerName[32], String:szText[64];
        SQL_FetchString(hHndl, 1, szServerName, sizeof(szServerName));

        Format(szText, sizeof(szText), "%s (%i/%i)", szServerName, SQL_FetchInt(hHndl, 2), SQL_FetchInt(hHndl, 3));

        if (SQL_FetchInt(hHndl, 0) == GetConVarInt(g_hConvarID) || (GetTime() - SQL_FetchInt(hHndl, 4)) >= 300) {
            DrawPanelItem(hPanel, szText, ITEMDRAW_DISABLED);
        } else {
            DrawPanelItem(hPanel, szText);
        }
    }

    DrawPanelText(hPanel, " ");

    SetPanelCurrentKey(hPanel, 10);
    DrawPanelItem(hPanel, "Exit");

    SendPanelToClient(hPanel, iClient, MainMenuHandler, 20);
    CloseHandle(hPanel);
}

public MainMenuHandler(Handle:hMenu, MenuAction:iAction, iClient, iChoice) {
    if (iAction == MenuAction_Select) {
        if (iChoice == 10) {
            return;
        }

        DisplaySubMenu(iClient, iChoice);
    }
}

DisplaySubMenu(iClient, iChoice) {
    decl String:szQuery[48];
    Format(szQuery, sizeof(szQuery), "SELECT id, clients, maxclients, name, map, ip FROM serverinfo WHERE id = %i", iChoice);

    SQL_TQuery(g_hDatabase, SQL_DisplaySubMenu, szQuery, GetClientUserId(iClient));
}

public SQL_DisplaySubMenu(Handle:hOwner, Handle:hHndl, const String:szError[], any:iUserId) {
    new iClient = GetClientOfUserId(iUserId);
    if (!iClient) {
        return;
    }

    SQL_FetchRow(hHndl);

    new iChoice = SQL_FetchInt(hHndl, 0);
    new iClients = SQL_FetchInt(hHndl, 1);
    new iMaxClients = SQL_FetchInt(hHndl, 2);

    decl String:szServerName[32], String:szMapName[32];
    SQL_FetchString(hHndl, 3, szServerName, sizeof(szServerName));
    SQL_FetchString(hHndl, 4, szMapName, sizeof(szMapName));
    SQL_FetchString(hHndl, 5, g_szClientChoiceIP[iClient], sizeof(g_szClientChoiceIP[]));

    decl String:szTitle[32], String:szPlayers[32];
    Format(szTitle, sizeof(szTitle), "Server #%i\n ", iChoice);
    Format(szPlayers, sizeof(szPlayers), "%i/%i Players", iClients, iMaxClients);

    new Handle:hPanel = CreatePanel();

    SetPanelTitle(hPanel, szTitle);
    DrawPanelText(hPanel, szServerName);
    DrawPanelText(hPanel, szPlayers);
    DrawPanelText(hPanel, szMapName);
    DrawPanelText(hPanel, " ");
    DrawPanelItem(hPanel, "Redirect to this server");
    DrawPanelItem(hPanel, "Go back");
    DrawPanelText(hPanel, " ");

    SetPanelCurrentKey(hPanel, 10);
    DrawPanelItem(hPanel, "Exit");

    SendPanelToClient(hPanel, iClient, SubMenuHandler, 20);
    CloseHandle(hPanel);
}

public SubMenuHandler(Handle:hMenu, MenuAction:iAction, iClient, iChoice) {
    if (iAction == MenuAction_Select) {
        switch (iChoice) {
            case 1: {
                DisplayAskConnectBox(iClient, 20.0, g_szClientChoiceIP[iClient]);
                PrintToChat(iClient, "\x04[SM]\x01 Bind a key to \x03askconnect_accept\x01 to accept the redirection.");
            }
            case 2: {
                DisplayMainMenu(iClient);
            }
        }

        g_szClientChoiceIP[iClient][0] = '\0';
    }
}

stock SQL_SendQuery(const String:szText[]) {
    new Handle:hData = CreateDataPack();
    WritePackString(hData, szText);

    SQL_TQuery(g_hDatabase, SQL_QuerySent, szText, hData);
}

public SQL_QuerySent(Handle:hOwner, Handle:hQuery, const String:szError[], any:hData) {
    if (hQuery == INVALID_HANDLE) {
        ResetPack(hData);

        decl String:szQuery[255];
        ReadPackString(hData, szQuery, sizeof(szQuery));

        LogError("Query Failed! %s", szError);
        LogError("Query: %s", szQuery);
    }

    CloseHandle(hData);
}