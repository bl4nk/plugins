#pragma semicolon 1

#include <sourcemod>

new Handle:hDatabase = INVALID_HANDLE;

public OnPluginStart()
{
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");

    SQL_TConnect(sql_Connect);
}

public sql_Connect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        SetFailState("Database failure: %s", error);
    }
    else
    {
        hDatabase = hndl;
    }

    CreateTables();
}

public Action:Command_Say(client, const String:command[], args)
{
    decl String:textBuffer[128], String:text[257];
    GetCmdArgString(textBuffer, sizeof(textBuffer));

    new startidx = 0;
    if (textBuffer[0] == '"')
    {
        startidx = 1;

        new len = strlen(textBuffer);
        if (textBuffer[len-1] == '"')
        {
            textBuffer[len-1] = '\0';
        }
    }

    if (CheckCommandAccess(client, "sm_say", ADMFLAG_CHAT) && textBuffer[startidx] == '@')
    {
        return Plugin_Continue;
    }

    new bool:teamOnly = false;
    if (!strcmp(command, "say_team"))
    {
        teamOnly = true;
    }

    SQL_EscapeString(hDatabase, textBuffer[startidx], text, sizeof(text));

    decl String:authid[32], String:nameBuffer[32], String:name[65], String:query[512];

    new bool:dead, team;
    if (!client)
    {
        strcopy(authid, sizeof(authid), "STEAMID_CONSOLE");
        strcopy(name, sizeof(name), "CONSOLE");
    }
    else
    {
        GetClientAuthString(client, authid, sizeof(authid));
        GetClientName(client, nameBuffer, sizeof(nameBuffer));
        SQL_EscapeString(hDatabase, nameBuffer, name, sizeof(name));
        dead = !IsPlayerAlive(client);
        team = GetClientTeam(client);
    }

    Format(query, sizeof(query), "INSERT INTO chatlogs (name, steamid, text, team, teamchat, dead) VALUES ('%s', '%s', '%s', %i, %i, %i)", name, authid, text, team, teamOnly, dead);
    SendQuery(query);
    
    return Plugin_Continue;
}

public sql_Query(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    ResetPack(data);

    if (hndl == INVALID_HANDLE)
    {
        decl String:query[255];
        ReadPackString(data, query, sizeof(query));

        LogError("Query Failed! %s", error);
        LogError("Query: %s", query);
    }

    CloseHandle(data);
    CloseHandle(hndl);
}

stock SendQuery(String:query[])
{
    new Handle:dp = CreateDataPack();
    WritePackString(dp, query);
    SQL_TQuery(hDatabase, sql_Query, query, dp);
}

CreateTables()
{
    decl String:query[512];
    Format(query, sizeof(query), "%s%s%s%s%s%s%s%s%s%s%s",
        "CREATE TABLE IF NOT EXISTS `chatlogs` (",
        "  `id` int(12) NOT NULL AUTO_INCREMENT,",
        "  `date` timestamp NOT NULL default CURRENT_TIMESTAMP,",
        "  `name` varchar(32) NOT NULL,",
        "  `steamid` varchar(32) NOT NULL,",
        "  `text` varchar(192) NOT NULL,",
        "  `team` int(1) NOT NULL,",
        "  `teamchat` bool NOT NULL,",
        "  `dead` bool NOT NULL,",
        "  PRIMARY KEY (`id`)",
        ") ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1 ;"
    );

    SendQuery(query);
}