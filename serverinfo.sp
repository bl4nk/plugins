#pragma semicolon 1

#include <sourcemod>

// Global Definitions
#define PLUGIN_VERSION "2.0.0"

#define cDefault    0x01
#define cLightGreen 0x03
#define cGreen      0x04
#define cDarkGreen  0x05

new serverID;
new serverChoice[MAXPLAYERS + 1];

new Handle:g_hCvarName;
new Handle:g_hCvarServer;
new Handle:g_hDatabase = INVALID_HANDLE;

new String:serverIP[16] = "\0";

// Functions
public Plugin:myinfo =
{
    name = "ServerInfo",
    author = "bl4nk",
    description = "Get information on other servers",
    version = PLUGIN_VERSION,
    url = "http://forums.alliedmods.net"
};

public OnPluginStart()
{
    CreateConVar("sm_serverinfo_version", PLUGIN_VERSION, "ServerInfo Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    g_hCvarServer = CreateConVar("sm_serverinfo_server", "0", "Server Number", FCVAR_PLUGIN);
    g_hCvarName = CreateConVar("sm_serverinfo_name", "Default Name", "Server Name", FCVAR_PLUGIN);

    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");

    GetConVarString(FindConVar("ip"), serverIP, sizeof(serverIP));

    CreateTimer(3.0, OnPluginStart_Delayed);
}

public OnMapEnd()
{
    if (g_hDatabase != INVALID_HANDLE)
    {
        CloseHandle(g_hDatabase);
        g_hDatabase = INVALID_HANDLE;
    }
}

public OnMapStart()
{
    if (g_hDatabase == INVALID_HANDLE)
    {
        SQL_TConnect(sql_Connected);
    }

    CreateTimer(60.0, Timer_UpdateInfo, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public bool:OnClientConnect(client, String:rejectmsg[], maxlen)
{
    if (g_hDatabase != INVALID_HANDLE)
    {
        decl String:query[255];
        Format(query, sizeof(query), "UPDATE serverinfo SET clients = clients + 1, lastupdate = %i WHERE id = %i", serverID, GetTime());
        SendQuery(query);
    }

    return true;
}

public OnClientDisconnect(client)
{
    if (g_hDatabase != INVALID_HANDLE)
    {
        decl String:query[255];
        Format(query, sizeof(query), "UPDATE serverinfo SET clients = clients - 1, lastupdate = %i WHERE id = %i", serverID, GetTime());
        SendQuery(query);
    }
}

public Action:OnPluginStart_Delayed(Handle:timer)
{
    serverID = GetConVarInt(g_hCvarServer);
    if (serverID != 0)
    {
        SQL_TConnect(sql_Connected);
    }

    HookConVarChange(g_hCvarServer, CvarChange_Server);
}

public CvarChange_Server(Handle:convar, const String:oldValue[], const String:newValue[])
{
    if (!GetConVarInt(g_hCvarServer))
    {
        if (g_hDatabase != INVALID_HANDLE)
        {
            CloseHandle(g_hDatabase);
            g_hDatabase = INVALID_HANDLE;
        }
    }
    else if (g_hDatabase == INVALID_HANDLE)
    {
        SQL_TConnect(sql_Connected);
    }
}

public Action:Timer_UpdateInfo(Handle:timer)
{
    if (g_hDatabase != INVALID_HANDLE)
    {
        decl String:query[512], String:mapName[32], String:serverName[32];
        GetCurrentMap(mapName, sizeof(mapName));
        GetConVarString(g_hCvarName, serverName, sizeof(serverName));

        Format(query, sizeof(query), "UPDATE serverinfo SET name = '%s', map = '%s', clients = %i, maxclients = %i, ip = '%s', lastupdate = %i WHERE id = %i", serverName, mapName, GetClientCount(false), MaxClients, serverIP, GetTime(), serverID);
        SendQuery(query);

        return Plugin_Continue;
    }
    else
    {
        return Plugin_Stop;
    }
}

public Action:Command_Say(client, const String:command[], args)
{
    decl String:text[192];
    GetCmdArgString(text, sizeof(text));

    new startidx = 0;
    if (text[0] == '"')
    {
        startidx = 1;

        new len = strlen(text);
        if (text[len-1] == '"')
        {
            text[len-1] = '\0';
        }
    }

    if(strcmp(text[startidx], "!servers") == 0)
    {
        if (g_hDatabase == INVALID_HANDLE)
        {
            PrintToChat(client, "[SM] That command is not available right now.");
            return Plugin_Handled;
        }

        decl String:query[255];
        Format(query, sizeof(query), "SELECT * FROM serverinfo");

        new Handle:hQuery = CreateDataPack();
        WritePackCell(hQuery, GetClientUserId(client));

        SQL_TQuery(g_hDatabase, sql_ServersMenu, query, hQuery);
    }

    return Plugin_Continue;
}

public sql_ServersMenu(Handle:owner, Handle:hndl, const String:error[], any:data)
{
        ResetPack(data);

        new client = GetClientOfUserId(ReadPackCell(data));
        CloseHandle(data);
        
        if (!client) {
            return;
        }

        new Handle:panel = CreatePanel();
        SetPanelTitle(panel, "Servers");
        DrawPanelText(panel, " ");

        new i = 1;
        while (SQL_FetchRow(hndl))
        {
            decl String:name[32];
            SQL_FetchString(hndl, 1, name, sizeof(name));
            new menu_clients = SQL_FetchInt(hndl, 3);
            new menu_maxclients = SQL_FetchInt(hndl, 4);

            decl String:menuText[64];
            Format(menuText, sizeof(menuText), "%s (%i/%i)", name, menu_clients, menu_maxclients);

            if (i == serverID || (GetTime() - SQL_FetchInt(hndl, 6) > 300))
            {
                DrawPanelItem(panel, menuText, ITEMDRAW_DISABLED);
            }
            else
            {
                DrawPanelItem(panel, menuText);
            }

            i++;
        }

        DrawPanelText(panel, " ");

        SetPanelCurrentKey(panel, 10);
        DrawPanelItem(panel, "Exit");

        SendPanelToClient(panel, client, Menu_Handler, 20);
        CloseHandle(panel);
}

public Menu_Handler(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Select)
    {
        if (param2 == 10)
            return;

        decl String:query[255];
        Format(query, sizeof(query), "SELECT * FROM serverinfo WHERE id = %i", param2);

        new Handle:hQuery = CreateDataPack();
        WritePackCell(hQuery, param1);

        SQL_TQuery(g_hDatabase, sql_ServersPanel, query, hQuery);
    }
    else if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

public sql_ServersPanel(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    ResetPack(data);

    new client = ReadPackCell(data);

    CloseHandle(data);

    new Handle:panel = CreatePanel();

    SQL_FetchRow(hndl);
    new selected = SQL_FetchInt(hndl, 0);

    decl String:panelTitle[32];
    Format(panelTitle, sizeof(panelTitle), "Server #%i\n ", selected);
    SetPanelTitle(panel, panelTitle);

    decl String:serverName[32];
    SQL_FetchString(hndl, 1, serverName, sizeof(serverName));
    DrawPanelText(panel, serverName);

    new panel_clients = SQL_FetchInt(hndl, 3);
    new panel_maxclients = SQL_FetchInt(hndl, 4);

    decl String:playersText[32];
    Format(playersText, sizeof(playersText), "%i/%i Players", panel_clients, panel_maxclients);
    DrawPanelText(panel, playersText);

    decl String:mapName[32];
    SQL_FetchString(hndl, 2, mapName, sizeof(mapName));
    DrawPanelText(panel, mapName);

    DrawPanelText(panel, " ");

    DrawPanelItem(panel, "Redirect to this server");
    DrawPanelItem(panel, "Go back");

    DrawPanelText(panel, " ");

    SetPanelCurrentKey(panel, 10);
    DrawPanelItem(panel, "Exit");

    SendPanelToClient(panel, client, Panel_Handler, 20);
    CloseHandle(panel);

    serverChoice[client] = selected;
}

public Panel_Handler(Handle:menu, MenuAction:action, param1, param2)
{
    new client = param1;
    if (action == MenuAction_Select)
    {
        decl String:query[255];
        switch (param2)
        {
            case 1:
            {
                Format(query, sizeof(query), "SELECT * FROM serverinfo WHERE id = %i", serverChoice[client]);

                new Handle:hQuery = CreateDataPack();
                WritePackCell(hQuery, client);

                SQL_TQuery(g_hDatabase, sql_Redirect, query, hQuery);

            }
            case 2:
            {
                Format(query, sizeof(query), "SELECT * FROM serverinfo");

                new Handle:hQuery = CreateDataPack();
                WritePackCell(hQuery, client);

                SQL_TQuery(g_hDatabase, sql_ServersMenu, query, hQuery);
            }
        }
    }
}

public sql_Redirect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    ResetPack(data);

    new client = ReadPackCell(data);

    CloseHandle(data);

    SQL_FetchRow(hndl);

    decl String:ipaddr[16];
    SQL_FetchString(hndl, 5, ipaddr, sizeof(ipaddr));

    DisplayAskConnectBox(client, 20.0, ipaddr);
    PrintToChat(client, "\x04[SM] \x01Bind a key to \x03askconnect_accept\x01 to accept the redirection.");
}

public sql_Connected(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        LogError("Database failure: %s", error);
    }
    else
    {
        g_hDatabase = hndl;
    }

    CreateTables();
}

public sql_Query(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    ResetPack(data);

    if (hndl == INVALID_HANDLE)
    {
        decl String:query[512];
        ReadPackString(data, query, sizeof(query));

        LogError("Query Failed! %s", error);
        LogError("Query: %s", query);
    }

    CloseHandle(data);
}

SendQuery(String:query[])
{
    new Handle:dp = CreateDataPack();
    WritePackString(dp, query);
    SQL_TQuery(g_hDatabase, sql_Query, query, dp);
}

CreateTables()
{
    decl String:query[512];
    Format(query, sizeof(query), "%s%s%s%s%s%s%s%s%s%s",
        "CREATE TABLE IF NOT EXISTS `serverinfo` (",
        "  `id` tinyint NOT NULL default 0,",
        "  `name` varchar(32) NOT NULL,",
        "  `map` varchar(32) NOT NULL,",
        "  `clients` tinyint NOT NULL,",
        "  `maxclients` tinyint NOT NULL,",
        "  `ip` varchar(32) NOT NULL,",
        "  `lastupdate` bigint unsigned NOT NULL,",
        "  PRIMARY KEY (`id`)",
        ") ENGINE=MyISAM DEFAULT CHARSET=latin1 ;");

    SendQuery(query);
    UpdateData();
}

UpdateData()
{
    serverID = GetConVarInt(g_hCvarServer);
    if (serverID != 0)
    {
        decl String:mapName[32], String:serverName[32];
        GetCurrentMap(mapName, sizeof(mapName));
        GetConVarString(g_hCvarName, serverName, sizeof(serverName));

        decl String:query[512];
        Format(query, sizeof(query), "INSERT INTO serverinfo (id, name, map, clients, maxclients, ip, lastupdate) VALUES (%i, '%s', '%s', %i, %i, '%s', %i) ON DUPLICATE KEY UPDATE name = VALUES(name), map = VALUES(map), clients = VALUES(clients), maxclients = VALUES(maxclients), ip = VALUES(ip), lastupdate = VALUES(lastupdate)", serverID, serverName, mapName, GetClientCount(false), MaxClients, serverIP, GetTime());
        SendQuery(query);
    }
}