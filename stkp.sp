#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <mystock>

// Global Definitions
#define PLUGIN_VERSION "2.0.0"

enum STKPType
{
    STKP_Punish = 1,
    STKP_Forgive,
    STKP_NoAction
}

new oldFF = -1;
new preSDFF = -1;
new g_RoundCounter;
new g_AttackerTeamkills[MAXPLAYERS + 1];
new g_AttackerPunished[MAXPLAYERS + 1];
new g_VictimTeamkilled[MAXPLAYERS + 1];
new g_VictimPunishes[MAXPLAYERS + 1];

new bool:g_bEnabled;
new bool:g_bIsBanned[MAXPLAYERS + 1];

new Handle:g_hCvarAmount;
new Handle:g_hCvarBan;
new Handle:g_hCvarFF;
new Handle:g_hCvarSlay;

new Handle:g_hDatabase;

new Handle:g_hAttackerTrie;
new Handle:g_hPlayerInfoTrie;

new Handle:g_hAttackerName;
new Handle:g_hVictimName;

// Functions
public Plugin:myinfo =
{
    name = "Simple TK Protection",
    author = "bl4nk",
    description = "Ban a player after 'x' unforgiven teamkills",
    version = PLUGIN_VERSION,
    url = "http://forums.alliedmods.net"
};

public OnPluginStart()
{
    // Initialize the convars and create the config file
    CreateConVar("sm_stkp_version", PLUGIN_VERSION, "Simple TK Protection Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    g_hCvarAmount = CreateConVar("sm_stkp_amount", "5", "Amount of unforgiven teamkills needed to ban.", FCVAR_PLUGIN, true, 1.0, false, _);
    g_hCvarBan = CreateConVar("sm_stkp_bantime", "30", "Amount of time to ban the client for.", FCVAR_PLUGIN, true, 0.0, false, _);
    g_hCvarSlay = CreateConVar("sm_stkp_slay", "0", "Amount of unpunished TKs needed to start slaying.", FCVAR_PLUGIN, true, 0.0, false, _);
    g_hCvarFF = FindConVar("mp_friendlyfire");

    AutoExecConfig(true, "plugin.stkp");

    // Hook the events
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("teamplay_game_over", Event_GameOver);
    HookEvent("teamplay_round_win", Event_RoundEnd);
    HookEvent("teamplay_round_start", Event_RoundStart);
    HookEvent("teamplay_round_stalemate", Event_SuddenDeathStart);

    // Create some tries to store information
    g_hPlayerInfoTrie = CreateTrie();
    g_hAttackerTrie = CreateTrie();

    // Create the player name arrays
    g_hAttackerName = CreateTrie();
    g_hVictimName = CreateTrie();

    // Connect to the SQL server
    SQL_TConnect(sql_Connected);
}

/* Called during map start */
public OnMapStart()
{
    ClearTrie(g_hPlayerInfoTrie);
    ClearTrie(g_hAttackerTrie);

    g_RoundCounter = 0;
    oldFF = -1;
}

/* Called when a client connects and authorizes to the server */
public OnClientAuthorized(client, const String:auth[])
{
    g_bIsBanned[client] = false;

    if (!IsFakeClient(client))
    {
        new statsArray[4];
        if (GetTrieArray(g_hPlayerInfoTrie, auth, statsArray, sizeof(statsArray)))
        {
            g_AttackerTeamkills[client] = statsArray[0];
            g_AttackerPunished[client] = statsArray[1];
            g_VictimTeamkilled[client] = statsArray[2];
            g_VictimPunishes[client] = statsArray[3];

            RemoveFromTrie(g_hPlayerInfoTrie, auth);
        }
        else
        {
            g_AttackerTeamkills[client] = 0;
            g_AttackerPunished[client] = 0;
            g_VictimTeamkilled[client] = 0;
            g_VictimPunishes[client] = 0;
        }
    }
}

/* Called when a client disconnects from the server (duh!) */
public OnClientDisconnect(client)
{
    // Is the client a real player?
    if (!IsFakeClient(client))
    {
        // Has the client authorized
        if (IsClientAuthorized(client))
        {
            // Grab the client's SteamID and save their information
            decl String:auth[32], String:query[510];
            GetClientAuthString(client, auth, sizeof(auth));

            Format(query, sizeof(query), "INSERT INTO stkp (steamid, teamkills, punished, teamkilled, punishes) VALUES ('%s', %i, %i, %i, %i) ON DUPLICATE KEY UPDATE teamkills = teamkills + VALUES(teamkills), punished = punished + VALUES(punished), teamkilled = teamkilled + VALUES(teamkilled), punishes = punishes + VALUES(punishes)", auth, g_AttackerTeamkills[client], g_AttackerPunished[client], g_VictimTeamkilled[client], g_VictimPunishes[client]);
            SendQuery(query);

            new statsArray[4];
            statsArray[0] = g_AttackerTeamkills[client];
            statsArray[1] = g_AttackerPunished[client];
            statsArray[2] = g_VictimTeamkilled[client];
            statsArray[3] = g_VictimPunishes[client];

            SetTrieArray(g_hPlayerInfoTrie, auth, statsArray, 4);
        }

        decl String:buffer[12];
        IntToString(client, buffer, sizeof(buffer));
        RemoveFromTrie(g_hAttackerTrie, buffer);
    }
}

/* Called at the start of a new round */
public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    /* If it's a "Waiting For Players" round (the first round), disable the plugin */
    if (!g_RoundCounter++)
    {
        g_bEnabled = false;
    }
    else if (!g_bEnabled)
    {
        g_bEnabled = true;
    }

    // Change FF setting back to previous value (if not during WFP)
    if (oldFF != -1 && oldFF != GetConVarInt(g_hCvarFF))
    {
        SetConVarInt(g_hCvarFF, oldFF);
        oldFF = -1;
    }

    // Change FF setting back to what it was before Sudden Death
    if (preSDFF != -1 && preSDFF != GetConVarInt(g_hCvarFF))
    {
        SetConVarInt(g_hCvarFF, preSDFF);
        preSDFF = -1;
    }
}

/* Called at the end of a round */
public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
    g_bEnabled = false;

    // If FF is disabled, enable it
    if (!(oldFF = GetConVarInt(g_hCvarFF)))
    {
        SetConVarInt(g_hCvarFF, true);
    }
}

/* Called at the start of Sudden Death */
public Event_SuddenDeathStart(Handle:event, const String:name[], bool:dontBroadcast)
{
    // If FF is enabled, disable it
    if ((preSDFF = GetConVarInt(g_hCvarFF)) == 1)
    {
        SetConVarInt(g_hCvarFF, false);
    }
}

/* Called when a player dies */
public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    // The plugin is temporarily disabled, bail out
    if (!g_bEnabled)
    {
        return;
    }

    new victim = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    // The victim is the server, was killed by world, or committed suicide
    if (!victim || !attacker || victim == attacker)
    {
        return;
    }

    // Someone's been naughty..
    if (GetClientTeam(victim) == GetClientTeam(attacker))
    {
        // Was it a feign death?
        if (GetEventInt(event, "death_flags") & (1<<5))
        {
            return;
        }

        decl String:weapon[32];
        GetEventString(event, "weapon", weapon, sizeof(weapon));

        // Ignore sentry kills, and those teamkilled by flamethrowers (glitch)
        if (!strncmp(weapon[4], "sentrygun", 9) || !strcmp(weapon, "tf_weapon_flamethrower"))
        {
            return;
        }

        // Create the TK menu and display it
        new Handle:menu = CreateMenu(MenuHandler_TeamKill);

        decl String:attackerName[32], String:victimName[32], String:buffer[64];
        GetClientName(attacker, attackerName, sizeof(attackerName));
        GetClientName(victim, victimName, sizeof(victimName));

        IntToString(victim, buffer, sizeof(buffer));
        SetTrieString(g_hVictimName, buffer, victimName);
        SetTrieString(g_hAttackerName, buffer, attackerName);

        Format(buffer, sizeof(buffer), "%s teamkilled you\nWas the TK intentional?", attackerName);
        SetMenuTitle(menu, buffer);

        AddMenuItem(menu, "", "No");
        AddMenuItem(menu, "", "Yes");

        SetMenuExitButton(menu, false);
        DisplayMenu(menu, victim, 10);

        // Record information on what happened
        IntToString(_:menu, buffer, sizeof(buffer));
        SetTrieValue(g_hAttackerTrie, buffer, GetClientUserId(attacker), true);

        IntToString(attacker, buffer, sizeof(buffer));
        SetTrieValue(g_hAttackerTrie, buffer, _:menu, true);

        g_VictimTeamkilled[victim]++;
        g_AttackerTeamkills[attacker]++;
    }
}

/* Handler for the TeamKill panel */
public MenuHandler_TeamKill(Handle:menu, MenuAction:action, victim, choice)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
    else
    {
        decl String:buffer[12];
        IntToString(_:menu, buffer, sizeof(buffer));

        new userid, attacker;
        GetTrieValue(g_hAttackerTrie, buffer, userid);
        RemoveFromTrie(g_hAttackerTrie, buffer);

        if ((attacker = GetClientOfUserId(userid)) > 0)
        {
            if (action == MenuAction_Select)
            {
                IntToString(attacker, buffer, sizeof(buffer));
                RemoveFromTrie(g_hAttackerTrie, buffer);

                if (choice == 0)
                {
                    STKP_Handler(STKP_Forgive, attacker, victim);
                }
                else if (choice == 1)
                {
                    STKP_Handler(STKP_Punish, attacker, victim);
                }
            }
            else if (action == MenuAction_Cancel && attacker > 0)
            {
                STKP_Handler(STKP_NoAction, attacker, victim);
            }
        }
    }
}

/* Called when the game ends and the scoreboard sticks up */
public Event_GameOver(Handle:event, const String:name[], bool:dontBroadcast)
{
    // Disable the plugin so TK stats can't be changed
    g_bEnabled = false;

    // Save all TK information into the DB
    decl String:query[2320];
    strcopy(query, sizeof(query), "INSERT INTO stkp (steamid, teamkills, punished, teamkilled, punishes) VALUES ");

    new count, bool:firstLoop = true;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && IsClientAuthorized(i))
        {
            if (firstLoop)
            {
                firstLoop = false;
            }
            else
            {
                StrCat(query, sizeof(query), ", ");
            }

            decl String:auth[32];
            GetClientAuthString(i, auth, sizeof(auth));

            decl String:buffer[128];
            Format(buffer, sizeof(buffer), "('%s', %i, %i, %i, %i)", auth, g_AttackerTeamkills[i], g_AttackerPunished[i], g_VictimTeamkilled[i], g_VictimPunishes[i]);
            StrCat(query, sizeof(query), buffer);

            count++;
        }
    }

    // If no clients were connected at the end of the game, bail out
    if (!count)
    {
        return;
    }

    StrCat(query, sizeof(query), " ON DUPLICATE KEY UPDATE teamkills = teamkills + VALUES(teamkills), punished = punished + VALUES(punished), teamkilled = teamkilled + VALUES(teamkilled), punishes = punishes + VALUES(punishes)");
    SendQuery(query);
}

/* Checks if the client has reached the TK limit or not */
CheckClientTK(client)
{
    if (!IsClientConnected(client) || !IsClientAuthorized(client))
    {
        return;
    }

    if (g_AttackerPunished[client] >= GetConVarInt(g_hCvarAmount) && !g_bIsBanned[client])
    {
        decl String:auth[32], String:reason[64];
        GetClientAuthString(client, auth, sizeof(auth));

        new banTime = GetConVarInt(g_hCvarBan);
        if (!banTime)
        {
            Format(reason, sizeof(reason), "Banned permanently for team killing");
        }
        else
        {
            Format(reason, sizeof(reason), "Banned for %i minutes for team killing", banTime);
        }

        LogMessage("Banned client %N (%s) for %i unforgiven TKs", client, auth, GetConVarInt(g_hCvarAmount));
        BanClient(client, banTime, BANFLAG_AUTHID, "Banned for team killing", reason, "stkp");

        g_bIsBanned[client] = true;
    }
}

/* Handles the TK menu choice (or lack there of) */
STKP_Handler(STKPType:type, attacker, victim)
{
    // Make sure both parties are still there
    if (!victim || !attacker || !IsClientConnected(victim) || !IsClientConnected(attacker))
    {
        return;
    }

    decl String:buffer[128], String:victimName[32], String:attackerName[32];
    IntToString(victim, buffer, sizeof(buffer));
    GetTrieString(g_hVictimName, buffer, victimName, sizeof(victimName));
    GetTrieString(g_hAttackerName, buffer, attackerName, sizeof(attackerName));

    // Player was punished, add a kill to their tally and log it
    if (type == STKP_Punish)
    {
        g_AttackerPunished[attacker]++;
        g_VictimPunishes[victim]++;

        LogMessage("%s did not forgive %s. (%i TK(s) before ban)", victimName, attackerName, GetConVarInt(g_hCvarAmount) - g_AttackerPunished[attacker]);
    }

    // Loop through all players to display the correct message to them via chat
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
        {
            continue;
        }

        switch (type)
        {
            case STKP_Punish:
            {
                if (i == attacker)
                {
                    Format(buffer, sizeof(buffer), "^4[SM]^1 ^3%s^1 chose to not forgive you. (^5%i^1 TK(s) before ban)", victimName, GetConVarInt(g_hCvarAmount) - g_AttackerPunished[i]);
                    ConvertColors(buffer, sizeof(buffer));
                    PrintToChat(i, buffer);

                    if (g_AttackerPunished[i] >= GetConVarInt(g_hCvarSlay) && IsPlayerAlive(i))
                    {
                         Format(buffer, sizeof(buffer), "^4[SM]^1 You were slayed for TKing (^5%i^1 TK(s) before ban)", GetConVarInt(g_hCvarAmount) - g_AttackerPunished[i]));
                         ConvertColors(buffer, sizeof(buffer));
                         PrintToChat(i, buffer);

                         ForcePlayerSuicide(i);
                    }
                }
                else if (i == victim)
                {
                    Format(buffer, sizeof(buffer), "^4[SM]^1 You chose to not forgive ^3%s^1.", attackerName);
                    ConvertColors(buffer, sizeof(buffer));
                    PrintToChat(i, buffer);
                }
                else
                {
                    Format(buffer, sizeof(buffer), "^4[SM]^1 ^3%s^3 did not forgive ^3%s^1.", victimName, attackerName);
                    ConvertColors(buffer, sizeof(buffer));
                    PrintToChat(i, buffer);
                }

                if (CheckAdminFlags(i, ADMFLAG_GENERIC))
                {
                    PrintToConsole(i, "[SM] %s has punished %i of %i people.", victimName, g_VictimPunishes[victim], g_VictimTeamkilled[victim]);
                    PrintToConsole(i, "[SM] %s has been punished %i of %i times.", attackerName, g_AttackerPunished[attacker], g_AttackerTeamkills[attacker]);
                }

                CheckClientTK(attacker);
            }
            case STKP_Forgive:
            {
                if (i == attacker)
                {
                    Format(buffer, sizeof(buffer), "^4[SM]^1 ^3%s^1 forgave you for TKing him.", victimName);
                    ConvertColors(buffer, sizeof(buffer));
                    PrintToChat(i, buffer);
                }
                else if (i == victim)
                {
                    Format(buffer, sizeof(buffer), "^4[SM]^1 You chose to forgive ^3%s^1.", attackerName);
                    ConvertColors(buffer, sizeof(buffer));
                    PrintToChat(i, buffer);
                }
                else
                {
                    Format(buffer, sizeof(buffer), "^4[SM]^1 ^3%s^1 forgave ^3%s^1.", victimName, attackerName);
                    ConvertColors(buffer, sizeof(buffer));
                    PrintToChat(i, buffer);
                }
            }
            case STKP_NoAction:
            {
                if (i == attacker)
                {
                    Format(buffer, sizeof(buffer), "^4[SM]^1 ^3%s^1 forgave you for TKing him.", victimName);
                    ConvertColors(buffer, sizeof(buffer));
                    PrintToChat(i, buffer);
                }
                else if (i == victim)
                {
                    Format(buffer, sizeof(buffer), "^4[SM] ^1You did not make a choice. ^3%s^1 was forgiven.", attackerName);
                    ConvertColors(buffer, sizeof(buffer));
                    PrintToChat(i, buffer);
                }
                else
                {
                    Format(buffer, sizeof(buffer), "^4[SM]^1 ^3%s^1 forgave ^3%s^1.", victimName, attackerName);
                    ConvertColors(buffer, sizeof(buffer));
                    PrintToChat(i, buffer);
                }
            }
        }
    }
}

ConvertColors(String:buffer[], maxlen)
{
    ReplaceString(buffer, maxlen, "^1", "\x01");
    ReplaceString(buffer, maxlen, "^2", "\x02");
    ReplaceString(buffer, maxlen, "^3", "\x03");
    ReplaceString(buffer, maxlen, "^4", "\x04");
    ReplaceString(buffer, maxlen, "^5", "\x05");
}

/* SQL Stuff */
public sql_Connected(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        SetFailState("Database failure: %s", error);
    }
    else
    {
        g_hDatabase = hndl;
    }

    CreateTables();
}

public sql_Query(Handle:owner, Handle:hndl, const String:error[], any:data)
{
    if (hndl == INVALID_HANDLE)
    {
        ResetPack(data);

        decl String:query[255];
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
    Format(query, sizeof(query), "%s%s%s%s%s%s%s%s%s",
        "CREATE TABLE IF NOT EXISTS `stkp` (",
        "  `steamid` varchar(32) NOT NULL,",
        "  `teamkills` mediumint unsigned NOT NULL,",
        "  `teamkilled` mediumint unsigned NOT NULL,",
        "  `punished` mediumint unsigned NOT NULL,",
        "  `punishes` mediumint unsigned NOT NULL,",
        "  `lastupdate` timestamp NOT NULL default CURRENT_TIMESTAMP,",
        "  PRIMARY KEY (`steamid`)",
        ") ENGINE=MyISAM DEFAULT CHARSET=latin1 ;");

    SendQuery(query);
}