#pragma semicolon 1

#include <sourcemod>

// Global Definitions
#define PLUGIN_VERSION "1.0.0"

new Handle:g_hAuthToIndex = INVALID_HANDLE;
new Handle:g_hDatabase = INVALID_HANDLE;
new Handle:g_hIndexToReason = INVALID_HANDLE;

new Handle:g_hCvarServerName = INVALID_HANDLE;
new Handle:g_hCvarServerGroup = INVALID_HANDLE;

// Functions
public Plugin:myinfo = {
    name = "SQL Bans",
    author = "bl4nk",
    description = "Bans stored in a SQL database",
    version = PLUGIN_VERSION,
    url = "http://forums.alliedmods.net"
};

public OnPluginStart() {
    RegServerCmd("addid", Command_Warn);
    RegServerCmd("removeid", Command_Warn);
    
    g_hCvarServerName = CreateConVar("sm_sqlbans_name", "", "Name of the server (e.g. tf4.joe.to)", FCVAR_PLUGIN);
    g_hCvarServerGroup = CreateConVar("sm_sqlbans_group", "", "Group name the server belongs in (e.g. TF2)", FCVAR_PLUGIN);

    StartSQL();
    g_hAuthToIndex = CreateArray(32);
    g_hIndexToReason = CreateArray(64);
}

public OnMapEnd() {
    ClearArray(g_hAuthToIndex);
    ClearArray(g_hIndexToReason);
}

public Action:Command_Warn(args) {
    PrintToServer("[SM] Please do not use this command; use the SM equivalent.");
    return Plugin_Continue;
}

public Action:OnBanClient(iClient, iTime, iFlags, const String:szReason[], const String:szKickMessage[], const String:szInfo[], any:iSource) {
    decl String:szAuth[32];
    GetClientAuthString(iClient, szAuth, sizeof(szAuth));
    
    decl String:szBannerAuth[32];
    if (iSource > 0) {
        GetClientAuthString(iSource, szBannerAuth, sizeof(szBannerAuth));
    } else {
        if (strcmp(szInfo, "stkp") == 0) {
            strcopy(szBannerAuth, sizeof(szBannerAuth), "TK Plugin");
        } else {
            strcopy(szBannerAuth, sizeof(szBannerAuth), "Console");
        }
    }

    decl String:szRealReason[32];
    strcopy(szRealReason, sizeof(szRealReason), szReason);

    new iStartIndex;
    if (szRealReason[0] == '"') {
        iStartIndex = 1;

        new iLen = strlen(szRealReason);
        if (szRealReason[iLen - 1] == '"') {
            szRealReason[iLen - 1] = '\0';
        }
    }

    decl String:szReasonBuffer[65];
    SQL_EscapeString(g_hDatabase, szRealReason[iStartIndex], szReasonBuffer, sizeof(szReasonBuffer));

    new iUnbanDate;
    if (iTime > 0) {
        iUnbanDate = GetTime() + (iTime * 60);
    }
    
    decl String:szServerName[32], String:szServerGroup[32];
    GetConVarString(g_hCvarServerName, szServerName, sizeof(szServerName));
    GetConVarString(g_hCvarServerGroup, szServerGroup, sizeof(szServerGroup));

    decl String:szQuery[512];
    Format(szQuery, sizeof(szQuery), "INSERT INTO bans (steamid, reason, banner, issued, expires, servername, servergroup) VALUES ('%s', '%s', '%s', %i, %i, '%s', '%s')", szAuth, szReasonBuffer, szBannerAuth, GetTime(), iUnbanDate, szServerName, szServerGroup);

    PushArrayString(g_hAuthToIndex, szAuth);
    PushArrayString(g_hIndexToReason, szReason);

    new Handle:hDataPack = CreateDataPack();
    WritePackString(hDataPack, szAuth);

    SQL_TQuery(g_hDatabase, T_AddBan, szQuery, hDataPack);

    return Plugin_Handled;
}

public Action:OnBanIdentity(const String:szAuth[], iTime, iFlags, const String:szReason[], const String:szInfo[], any:iSource) {    
    decl String:szBannerAuth[32];
    if (iSource > 0) {
        GetClientAuthString(iSource, szBannerAuth, sizeof(szBannerAuth));
    } else {
        strcopy(szBannerAuth, sizeof(szBannerAuth), "Console");
    }

    decl String:szRealReason[32];
    strcopy(szRealReason, sizeof(szRealReason), szReason);

    new iStartIndex;
    if (szRealReason[0] == '"') {
        new iLen = strlen(szRealReason) - 1;
        if (szRealReason[iLen] == '"') {
            szRealReason[iLen] = '\0';
            iStartIndex++;
        }
    }

    decl String:szReasonBuffer[65];
    SQL_EscapeString(g_hDatabase, szRealReason[iStartIndex], szReasonBuffer, sizeof(szReasonBuffer));

    new iUnbanDate;
    if (iTime > 0) {
        iUnbanDate = GetTime() + (iTime * 60);
    }
    
    decl String:szServerName[32], String:szServerGroup[32];
    GetConVarString(g_hCvarServerName, szServerName, sizeof(szServerName));
    GetConVarString(g_hCvarServerGroup, szServerGroup, sizeof(szServerGroup));

    decl String:szQuery[512];
    Format(szQuery, sizeof(szQuery), "INSERT INTO bans (steamid, reason, banner, issued, expires, servername, servergroup) VALUES ('%s', '%s', '%s', %i, %i, '%s', '%s')", szAuth, szReasonBuffer, szBannerAuth, GetTime(), iUnbanDate, szServerName, szServerGroup);
    SendQuery(szQuery);

    // No need to add this SteamID to the "ban queue";
    // a connected player shouldn't be banned this way.
    
    return Plugin_Handled;
}

public T_AddBan(Handle:hOwner, Handle:hHandle, const String:szError[], any:hDataPack) {
    ResetPack(hDataPack);

    decl String:szAuth[32];
    ReadPackString(hDataPack, szAuth, sizeof(szAuth));

    new iIndex = FindStringInArray(g_hAuthToIndex, szAuth);
    if (iIndex > -1) {
        RemoveFromArray(g_hAuthToIndex, iIndex);
        RemoveFromArray(g_hIndexToReason, iIndex);
    }

    CloseHandle(hDataPack);
}

public Action:OnRemoveBan(const String:szAuth[], iFlags, const String:szInfo[], any:iSource) {
    new iIndex = FindStringInArray(g_hAuthToIndex, szAuth);
    if (iIndex > -1) {
        RemoveFromArray(g_hAuthToIndex, iIndex);
        RemoveFromArray(g_hIndexToReason, iIndex);
    }
    
    decl String:szServerGroup[32];
    GetConVarString(g_hCvarServerGroup, szServerGroup, sizeof(szServerGroup));

    decl String:szQuery[255];
    Format(szQuery, sizeof(szQuery), "UPDATE bans SET unbanned = 1 WHERE steamid = '%s' AND (servergroup = '%s' OR servergroup = 'all')", szAuth, szServerGroup);
    SendQuery(szQuery);

    return Plugin_Handled;
}

public OnClientAuthorized(iClient, const String:szAuth[]) {
    if (strlen(szAuth) > 10) {
        new iIndex;
        if ((iIndex = FindStringInArray(g_hAuthToIndex, szAuth)) > -1) {
            decl String:szReason[64];
            GetArrayString(g_hIndexToReason, iIndex, szReason, sizeof(szReason));

            KickClient(iClient, "\nYou have been banned!\nBan Reason: %s\nVisit http://forums.joe.to/ to appeal your ban", szReason);
        } else {
            decl String:szServerGroup[32];
            GetConVarString(g_hCvarServerGroup, szServerGroup, sizeof(szServerGroup));
            
            decl String:szQuery[255];
            Format(szQuery, sizeof(szQuery), "SELECT expires, reason, unbanned FROM bans WHERE steamid REGEXP '^STEAM_[01]:%s$' AND (servergroup = '%s' OR servergroup = 'all')", szAuth[8], szServerGroup);
            SQL_TQuery(g_hDatabase, T_CheckBans, szQuery, GetClientUserId(iClient));
        }
    }
}

public T_CheckBans(Handle:owner, Handle:hndl, const String:error[], any:iUserId) {
    if (hndl == INVALID_HANDLE) {
        LogError("Query Failed! %s", error);
        return;
    }
    
    new iClient = GetClientOfUserId(iUserId);
    if (iUserId == 0) {
        return;
    }

    new rowCount = SQL_GetRowCount(hndl);
    if (rowCount > 0) {
        new curDate = GetTime();
        for (new i = 1; i <= rowCount; i++) {
            SQL_FetchRow(hndl);

            new unbanTime = SQL_FetchInt(hndl, 0);
            new unbanned = SQL_FetchInt(hndl, 2);

            if (!unbanned && (unbanTime > curDate || !unbanTime)) {
                decl String:reason[65];
                SQL_FetchString(hndl, 1, reason, sizeof(reason));

                new String:unbanDate[64];                
                if (unbanTime == 0) {
                    Format(unbanDate, sizeof(unbanDate), "Never");
                } else {
                    FormatBanTime(unbanTime, unbanDate, sizeof(unbanDate));
                }
                
                KickClient(iClient, "\nBan Reason: %s \nUnban In: %s \nVisit http://tf2.joe.to/ to appeal your ban", reason, unbanDate);
                break;
            }
        }
    }
}

StartSQL() {
    SQL_TConnect(GotDatabase);
}

public GotDatabase(Handle:owner, Handle:hndl, const String:error[], any:data) {
    if (hndl == INVALID_HANDLE) {
        SetFailState("Database error: %s", error);
    } else {
        g_hDatabase = hndl;
    }

    CreateTables();
    SendQuery("SET NAMES 'utf8'");
}

CreateTables() {
    new String:query[] = "\
        CREATE TABLE IF NOT EXISTS `bans` ( \
          `id` mediumint NOT NULL AUTO_INCREMENT, \
          `steamid` varchar(32) NOT NULL, \
          `reason` varchar(32) NOT NULL, \
          `banner` varchar(32) NOT NULL, \
          `issued` int NOT NULL, \
          `expires` int NOT NULL, \
          `unbanned` bool NOT NULL DEFAULT 0, \
          `servername` varchar(32) NOT NULL, \
          `servergroup` varchar(32) NOT NULL, \
          PRIMARY KEY (`id`) \
        ) ENGINE=MyISAM DEFAULT CHARSET=latin1 AUTO_INCREMENT=1;";

    SendQuery(query);
}

SendQuery(String:query[]) {
    new Handle:db = CreateDataPack();
    WritePackString(db, query);
    SQL_TQuery(g_hDatabase, T_Query, query, db);
}

public T_Query(Handle:owner, Handle:hndl, const String:error[], any:data) {
    ResetPack(data);

    decl String:query[512];
    ReadPackString(data, query, sizeof(query));
    CloseHandle(data);

    if (hndl == INVALID_HANDLE) {
        LogError("Query Failed! %s", error);
        LogError("Query: %s", query);
    }
}

FormatBanTime(iTime, String:szBuffer[], iMaxLen) {
    iTime -= GetTime();

    new iMonths = iTime / 2629744;
    iTime %= 2629744;

    if (iMonths > 0) {
        Format(szBuffer, iMaxLen, "%imo", iMonths);
    }

    new iDays = iTime / 86400;
    iTime %= 86400;

    if (iDays > 0) {
        if (iMonths > 0) {
            Format(szBuffer, iMaxLen, "%s, %id", szBuffer, iDays);
        } else {
            Format(szBuffer, iMaxLen, "%id", iDays);
        }
    }

    new iHours = iTime / 3600;
    iTime %= 3600;

    if (iMonths > 0 || iDays > 0) {
        Format(szBuffer, iMaxLen, "%s, %ih", szBuffer, iHours);
    } else {
        Format(szBuffer, iMaxLen, "%ih", iHours);
    }

    new iMinutes = iTime / 60;
    iTime %= 60;

    if (iTime > 0) {
        iMinutes += 1;
    }

    if (iMonths > 0 || iDays > 0 || iHours > 0) {
        Format(szBuffer, iMaxLen, "%s, %imin", szBuffer, iMinutes);
    } else {
        Format(szBuffer, iMaxLen, "%imin", iMinutes);
    }
}

stock FormatBanTime2(iTime, String:szBuffer[], iMaxLen) {
    static iTimeAmounts[] = { 2629744, 86400, 3600, 60 };
    static const String:szTimeNames[][] = { "months", "days", "hours", "minutes" };
    
    szBuffer[0] = '\0';
    
    new iArrayLen = sizeof(iTimeAmounts) - 1;
    for (new i = 0; i <= iArrayLen; i++) {
        if (iTimeAmounts[i] >= iTime) {
            new iAmount = iTime / iTimeAmounts[i];
            iTime -= iAmount * iTimeAmounts[i];
            
            if (i == iArrayLen && iTime) {
                iAmount++;
            }
            
            if (!strlen(szBuffer)) {
                Format(szBuffer, iMaxLen, "%i%s", iAmount, szTimeNames[i]);
            } else {
                Format(szBuffer, iMaxLen, "%s %i%s", szBuffer, iAmount, szTimeNames[i]);
            }
            
        }
    }
}