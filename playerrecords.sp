#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION "1.0.0-rc2"

new bool:g_bIsConnected[MAXPLAYERS+1];

new Handle:g_hDatabase = INVALID_HANDLE;

public Plugin:myinfo = {
    name = "PlayerRecords",
    author = "bl4nk",
    description = "Records information on each player that connects to the server",
    version = PLUGIN_VERSION,
    url = "http://forums.alliedmods.net"
};

public OnPluginStart() {
    CreateConVar("sm_playerrecords_version", PLUGIN_VERSION, "PlayerRecords Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    HookEvent("player_changename", Event_ChangeName);
    HookEvent("player_disconnect", Event_Disconnect);
}

public OnMapStart() {
    if (g_hDatabase == INVALID_HANDLE) {
        SQL_TConnect(sql_Connect);
    }
}

public OnClientAuthorized(client) {
    if (IsValidPlayer(client) && !g_bIsConnected[client]) {
        decl String:auth[32], String:ipaddr[32];
        GetClientAuthString(client, auth, sizeof(auth));
        GetClientIP(client, ipaddr, sizeof(ipaddr));
        
        decl String:clientName[32], String:clientNameBuffer[65];
        GetClientName(client, clientName, sizeof(clientName));
        SQL_EscapeString(g_hDatabase, clientName, clientNameBuffer, sizeof(clientNameBuffer));

        decl String:query[512];
        Format(query, sizeof(query), "INSERT INTO players (steamid, firstname, lastname, lastip) VALUES ('%s', '%s', '%s', '%s') ON DUPLICATE KEY UPDATE lastname = VALUES(lastname), lastip = VALUES(lastip), connections = connections + 1, lastconnect = NOW()", auth, clientNameBuffer, clientNameBuffer, ipaddr);
        SendQuery(query);

        Format(query, sizeof(query), "INSERT INTO playernames (steamid, name, last) VALUES ('%s', '%s', NOW()) ON DUPLICATE KEY UPDATE last = NOW()", auth, clientNameBuffer);
        SendQuery(query);

        Format(query, sizeof(query), "INSERT INTO playerips (steamid, ip, last) VALUES ('%s', '%s', NOW()) ON DUPLICATE KEY UPDATE last = NOW()", auth, ipaddr);
        SendQuery(query);
        
        g_bIsConnected[client] = true;
    }
}

public Event_Disconnect(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    if (IsValidPlayer(client) && g_bIsConnected[client]) {
        decl String:auth[32];
        if (GetClientAuthString(client, auth, sizeof(auth))) {
            decl String:ipaddr[32], String:clientName[32], String:clientNameBuffer[65], String:query[512];
            GetClientIP(client, ipaddr, sizeof(ipaddr));
            GetClientName(client, clientName, sizeof(clientName));
            SQL_EscapeString(g_hDatabase, clientName, clientNameBuffer, sizeof(clientNameBuffer));

            Format(query, sizeof(query), "INSERT INTO players (steamid, firstname, lastname, lastip) VALUES ('%s', '%s', '%s', '%s') ON DUPLICATE KEY UPDATE lastname = VALUES(lastname), lastip = VALUES(lastip)", auth, clientNameBuffer, clientNameBuffer, ipaddr);
            SendQuery(query);

            Format(query, sizeof(query), "INSERT INTO playernames (steamid, name, last) VALUES ('%s', '%s', NOW()) ON DUPLICATE KEY UPDATE last = NOW()", auth, clientNameBuffer);
            SendQuery(query);

            Format(query, sizeof(query), "INSERT INTO playerips (steamid, ip, last) VALUES ('%s', '%s', NOW()) ON DUPLICATE KEY UPDATE last = NOW()", auth, ipaddr);
            SendQuery(query);
        }
        
        g_bIsConnected[client] = false;
    }
}

public Action:Event_ChangeName(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (IsValidPlayer(client)) {
        decl String:auth[32];
        GetClientAuthString(client, auth, sizeof(auth));
        
        decl String:clientName[32], String:clientNameBuffer[65];
        GetEventString(event, "newname", clientName, sizeof(clientName));
        SQL_QuoteString(g_hDatabase, clientName, clientNameBuffer, sizeof(clientNameBuffer));

        decl String:query[512];
        Format(query, sizeof(query), "UPDATE players SET lastname = '%s' WHERE steamid = '%s'", clientNameBuffer, auth);
        SendQuery(query);

        Format(query, sizeof(query), "INSERT INTO playernames (steamid, name, last) VALUES ('%s', '%s', NOW()) ON DUPLICATE KEY UPDATE last = NOW()", auth, clientNameBuffer);
        SendQuery(query);
    }
}

public sql_Connect(Handle:owner, Handle:hndl, const String:error[], any:data) {
    if (hndl == INVALID_HANDLE) {
        SetFailState("Database failure: %s", error);
    } else {
        g_hDatabase = hndl;
    }

    CreateTables();
    SendQuery("SET NAMES 'utf8'");
}

public sql_Query(Handle:owner, Handle:hndl, const String:error[], any:data) {
    if (hndl == INVALID_HANDLE) {
        ResetPack(data);

        decl String:query[255];
        ReadPackString(data, query, sizeof(query));

        LogError("Query Failed! %s", error);
        LogError("Query: %s", query);
    }

    CloseHandle(data);
}

stock SendQuery(String:query[]) {
    new Handle:dp = CreateDataPack();
    WritePackString(dp, query);
    SQL_TQuery(g_hDatabase, sql_Query, query, dp);
}

CreateTables() {
    decl String:query[600];
    Format(query, sizeof(query), "\
        CREATE TABLE IF NOT EXISTS `players` ( \
          `steamid` varchar(32) NOT NULL, \
          `firstname` varchar(32) NOT NULL, \
          `lastname` varchar(32) NOT NULL, \
          `lastip` varchar(32) NOT NULL, \
          `connections` int(11) NOT NULL default 1, \
          `lastconnect` timestamp NOT NULL default CURRENT_TIMESTAMP, \
          PRIMARY KEY (`steamid`) \
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 ;");

    SendQuery(query);

    Format(query, sizeof(query), "\
        CREATE TABLE IF NOT EXISTS `playernames` ( \
          `steamid` varchar(32) NOT NULL, \
          `name` varchar(32) NOT NULL, \
          `last` timestamp NOT NULL default CURRENT_TIMESTAMP, \
          CONSTRAINT PRIMARY KEY (`steamid`, `name`) \
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;");

    SendQuery(query);

    Format(query, sizeof(query), "\
        CREATE TABLE IF NOT EXISTS `playerips` ( \
          `steamid` varchar(32) NOT NULL, \
          `ip` varchar(32) NOT NULL, \
          `last` timestamp NOT NULL default CURRENT_TIMESTAMP, \
          CONSTRAINT PRIMARY KEY (`steamid`, `ip`) \
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;");

    SendQuery(query);
}

stock bool:IsValidPlayer(iClient, bool:bAllowBots=false) {
    if (iClient) {
        if (IsFakeClient(iClient)) {
            if (bAllowBots) {
                return true;
            } else {
                return false;
            }
        }
        
        return true;
    }
    
    return false;
}