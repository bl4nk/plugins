#pragma semicolon 1

#include <sourcemod>
#include <steamtools>

new Handle:g_hConvarID;
new Handle:g_hConvarName;
new Handle:g_hDatabase;

new String:g_szMapName[32];
new String:g_szServerName[32];
new String:g_szServerIP[24];

public Plugin:myinfo = {
    name = "ServerInfo2",
    author = "bl4nk",
    description = "",
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
    /* To do: Display menu */
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

stock SQL_SendQuery(const String:szText[]) {
    new Handle:hData = CreateDataPack();
    WritePackString(hData, szText);

    SQL_TQuery(g_hDatabase, SQL_QuerySent, szText, hData);
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
