#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.0.0-alpha"
#define j2f "[J2F] "

#define BUILDD __DATE__
#define BUILDT __TIME__

enum TFObjectType
{
	TFObject_Dispenser = 0,
	TFObject_Entrance,
	TFObject_Exit,
	TFObject_Sentry
}

enum TFFlagEvent
{
	TFFlag_PickedUp = 1,
	TFFlag_Captured,
	TFFlag_Defended,
	TFFlag_Dropped
}

static const String:TFObjectNames[TFObjectType][] =
{
	"Dispenser",
	"Teleporter Entrance",
	"Teleporter Exit",
	"Sentry"
};

static const String:TFFlagEventNames[TFFlagEvent][] =
{
	"",
	"picking up",
	"capturing",
	"defending",
	"dropping"
};

new playerLevel[MAXPLAYERS+1];
new playerExp[MAXPLAYERS+1];
new expNeeded[256] = {0, 100, ...};

new bool:lateLoad = false;
new bool:playerLoaded[MAXPLAYERS+1];

new Handle:hDatabase;

public Plugin:myinfo =
{
	name = "J2Fortress Base",
	author = "joe.to community",
	description = "Base for the J2F mod",
	version = PLUGIN_VERSION,
	url = "http://forums.joe.to"
};

/**
 * If the plugin is loaded in the middle of the game,
 * this tells the plugin that all clients that are
 * already authorized need to have their stats loaded.
 */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	lateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("object_destroyed", Event_ObjectDestroyed);
	HookEvent("teamplay_flag_event", Event_FlagEvent);
	HookEvent("teamplay_point_captured", Event_PointCaptured);
	HookEvent("teamplay_capture_blocked", Event_PointBlocked);
	HookEvent("player_chargedeployed", Event_UberCharge);

	RegConsoleCmd("experience", Command_Experience);
	RegConsoleCmd("exp", Command_Experience);
	RegConsoleCmd("xp", Command_Experience);
	RegConsoleCmd("level", Command_Experience);
	RegConsoleCmd("lvl", Command_Experience);
	RegConsoleCmd("save", Command_Save);
	RegConsoleCmd("info", Command_Info);

	RegAdminCmd("sm_giveexp", Command_GiveExp, ADMFLAG_CHEATS);

	SQLConnect();
}

public OnPluginEnd()
{
	SaveAllPlayerData();
}

public OnClientPutInServer(client)
{
	LoadPlayerData(client);
}

public Action:timer_CheckAuthorization(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client)
	{
		if (IsClientAuthorized(client))
		{
			decl String:auth[32], String:query[96];
			GetClientAuthString(client, auth, sizeof(auth));

			Format(query, sizeof(query), "SELECT level, experience FROM j2f_experience WHERE steamid='%s'", auth[8]);
			SQL_TQuery(hDatabase, sql_AuthQuery, query, GetClientUserId(client));

			return Plugin_Stop;
		}
	}
	else
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public sql_AuthQuery(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!client)
	{
		return;
	}

	if (!SQL_GetRowCount(hndl))
	{
		decl String:auth[32];
		GetClientAuthString(client, auth, sizeof(auth));

		decl String:query[96];
		Format(query, sizeof(query), "INSERT INTO j2f_experience (steamid) VALUES ('%s')", auth[8]);
		SendQuery(query);
	}
	else
	{
		SQL_FetchRow(hndl);

		playerLevel[client] = SQL_FetchInt(hndl, 0);
		playerExp[client] = SQL_FetchInt(hndl, 1);
	}

	playerLoaded[client] = true;
}

public OnClientDisconnect(client)
{
	if (playerLoaded[client])
	{
		SavePlayerData(client);
		playerLoaded[client] = false;
	}
}

public OnMapEnd()
{
	SaveAllPlayerData();

	if (hDatabase != INVALID_HANDLE)
	{
		CloseHandle(hDatabase);
		hDatabase = INVALID_HANDLE;
	}
}

public OnMapStart()
{
	if (hDatabase == INVALID_HANDLE)
	{
		SQLConnect();
	}
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new assister = GetClientOfUserId(GetEventInt(event, "assister"));
	new bool:dominated = GetEventBool(event, "dominated");
	new bool:revenge = GetEventBool(event, "revenge");
	new bool:assisterDominated = GetEventBool(event, "assister_dominated");
	new bool:assisterRevenge = GetEventBool(event, "assister_revenge");
	new bool:isTK = false;

	if (attacker)
	{
		isTK = (GetClientTeam(attacker) == GetClientTeam(victim));
		if (!isTK)
		{
			if (victim != attacker)
			{
				// give experience to the attacker
				PrintToChat(attacker, "%sYou gained 5 experience for killing %N.", j2f, victim);
				AddExperience(attacker, 5);
			}

			if (dominated)
			{
				PrintToChat(attacker, "%sYou gained 1 experience for dominating %Nc.", j2f, victim);
				AddExperience(attacker, 1);
			}

			if (revenge)
			{
				PrintToChat(attacker, "%sYou gained 1 experience for getting revenge on %N.", j2f, victim);
				AddExperience(attacker, 1);
			}
		}

		if (assister)
		{
			new bool:assistSameTeam = (GetClientTeam(assister) == GetClientTeam(attacker));

			if (TF2_GetPlayerClass(assister) == TFClass_Medic && assistSameTeam)
			{
				// give experience to the assister
				PrintToChat(assister, "%sYou gained 3 experience for assisting %N.", j2f, attacker);
				AddExperience(assister, 3);
			}
			else if (GetClientTeam(assister) != GetClientTeam(victim))
			{
				// give experience to the assister
				PrintToChat(assister, "%sYou gained 1 experience for assisting %N.", j2f, attacker);
				AddExperience(assister, 1);
			}

			if (!isTK)
			{
				if (assisterDominated)
				{
					PrintToChat(assister, "%sYou gained 1 experience for dominating %N.", j2f, victim);
					AddExperience(assister, 1);
				}

				if (assisterRevenge)
				{
					PrintToChat(assister, "%sYou gained 1 experience for getting revenge on %N.", j2f, victim);
					AddExperience(assister, 1);
				}
			}
		}
	}
}

public Event_ObjectDestroyed(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new TFObjectType:object = TFObjectType:GetEventInt(event, "objecttype");
	new exp;

	switch (object)
	{
		case TFObject_Sentry:
		{
			exp = 3;
		}
		case TFObject_Dispenser:
		{
			exp = 2;
		}
		case TFObject_Entrance:
		{
			exp = 1;
		}
		case TFObject_Exit:
		{
			exp = 1;
		}
	}

	// give experience for destroying an object
	PrintToChat(attacker, "%sYou gained %i experience for destroying %N's %s.", j2f, exp, victim, TFObjectNames[object]);
	AddExperience(attacker, exp);
}

public Event_FlagEvent(Handle:event, const String:name[], bool:dontBroadcast)
{
	new exp, client = GetEventInt(event, "player");
	new TFFlagEvent:type = TFFlagEvent:GetEventInt(event, "eventtype");

	switch (type)
	{
		case TFFlag_Captured:
		{
			exp = 10;
		}
		case TFFlag_Defended:
		{
			exp = 2;
		}
	}

	if (exp)
	{
		// give experience for a valid flag action
		PrintToChat(client, "%sYou gained %i experience for %s the flag.", j2f, exp, TFFlagEventNames[type]);
		AddExperience(client, exp);
	}
}

public Event_PointCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:cappers[128];
	GetEventString(event, "cappers", cappers, sizeof(cappers));

	new len = strlen(cappers);
	for (new i = 0; i < len; i++)
	{
		new client = cappers{i};

		// give experience points to the client
		PrintToChat(client, "%sYou gained 10 experience for capturing the point.", j2f);
		AddExperience(client, 10);
	}
}

public Event_PointBlocked(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetEventInt(event, "blocker");

	// give experience points for blocking a capture
	PrintToChat(client, "%sYou gained 1 experience for blocking a capture.", j2f);
	AddExperience(client, 1);
}

public Event_UberCharge(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	// give experience points for deploying an ubercharge
	PrintToChat(client, "%sYou gained 5 experience for deploying an ?bercharge.", j2f);
	AddExperience(client, 5);
}

public Action:Command_Experience(client, args)
{
	if (client)
	{
		PrintToChat(client, "%sYou are at level %i with %i/%i experience.", j2f, playerLevel[client], playerExp[client], playerLevel[client]!=255?expNeeded[playerLevel[client]+1]:expNeeded[255]);
	}

	return Plugin_Handled;
}

public Action:Command_Info(client, args)
{
	if (client)
	{
		PrintToChat(client, "%sVersion: %s Built: %s @ %s", j2f, PLUGIN_VERSION, BUILDD, BUILDT);
	}

	return Plugin_Handled;
}

public Action:Command_Save(client, args)
{
	decl String:auth[32], String:query[128];
	GetClientAuthString(client, auth, sizeof(auth));

	Format(query, sizeof(query), "UPDATE j2f_experience SET level = %i, experience = %i WHERE steamid='%s'", playerLevel[client], playerExp[client], auth[8]);
	SQL_TQuery(hDatabase, sql_SaveExp, query, GetClientUserId(client));
}

public Action:Command_GiveExp(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_giveexp <#userid|name> <amount>");
		return Plugin_Handled;
	}

	decl String:target[64], String:sAmount[64];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, sAmount, sizeof(sAmount));

	new amount = StringToInt(sAmount);
	if (!amount)
	{
		ReplyToCommand(client, "[SM] You must either give or take away experience");
		return Plugin_Handled;
	}

	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

	if ((target_count = ProcessTargetString(
			target,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (new i = 0; i < target_count; i++)
	{
		if (playerLoaded[target_list[i]])
		{
			AddExperience(target_list[i], amount);
			PrintToChat(target_list[i], "%sAn admin gave you %i experience!", j2f, amount);
		}
	}

	return Plugin_Handled;
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

	// Quoted out for testers, will error if not there
	// CreateTables();

	if (lateLoad)
	{
		LoadConnectedClients();
		lateLoad = false;
	}
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
}

public sql_SaveExp(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	new client = GetClientOfUserId(client);
	if (!client)
	{
		return;
	}

	if (hndl == INVALID_HANDLE)
	{
		LogError("SaveEXP Query Failed:");
		LogError(error);

		PrintToChat(client, "%sYour level and experience were NOT saved due to an error.", j2f);
	}
	else
	{
		PrintToChat(client, "%sYour level and experience have been saved.", j2f);
	}
}

SendQuery(String:query[])
{
	new Handle:dp = CreateDataPack();
	WritePackString(dp, query);
	SQL_TQuery(hDatabase, sql_Query, query, dp);
}

stock CreateTables()
{
	decl String:query[512];
	Format(query, sizeof(query), "%s%s%s%s%s%s",
		"CREATE TABLE IF NOT EXISTS `j2f_experience` (",
		"  `steamid` varchar(32) NOT NULL,",
		"  `level` tinyint unsigned NOT NULL default 0,",
		"  `experience` int unsigned NOT NULL default 0,",
		"  PRIMARY KEY (`steamid`)",
		") ENGINE=MyISAM DEFAULT CHARSET=latin1 ;");

	SendQuery(query);
}

AddExperience(client, amount)
{
	new bool:leveled = false;
	playerExp[client] += amount;

	if (amount > 0)
	{
		if (playerLevel[client] == 255)
		{
			playerExp[client] = expNeeded[255];
			return;
		}

		while (playerExp[client] >= expNeeded[playerLevel[client]+1])
		{
			playerLevel[client]++;
			playerExp[client] -= expNeeded[playerLevel[client]];
			leveled = true;
		}
	}
	else
	{
		while (playerExp[client] < 0)
		{
			if (!playerLevel[client])
			{
				playerExp[client] = 1;
				break;
			}

			playerLevel[client]--;
			playerExp[client] += expNeeded[playerLevel[client]];
			leveled = true;
		}
	}

	if (leveled)
	{
		if (amount < 1)
		{
			PrintToChatAll("%sPlayer %N deleveled to %i!", j2f, client, playerLevel[client]);
		}
		else
		{
			PrintToChatAll("%sPlayer %N leveled up to %i!", j2f, client, playerLevel[client]);
			// Display point selection menu to client, do other stuff...
		}
	}
}

LoadPlayerData(client)
{
	playerLoaded[client] = false;
	playerLevel[client] = 0;
	playerExp[client] = 0;

	if (IsClientAuthorized(client))
	{
		decl String:auth[32], String:query[96];
		GetClientAuthString(client, auth, sizeof(auth));

		Format(query, sizeof(query), "SELECT level, experience FROM j2f_experience WHERE steamid='%s'", auth[8]);
		SQL_TQuery(hDatabase, sql_AuthQuery, query, GetClientUserId(client));
	}
	else
	{
		CreateTimer(3.0, timer_CheckAuthorization, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE, GetClientUserId(client));
	}
}

LoadConnectedClients()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			LoadPlayerData(i);
		}
	}
}

SavePlayerData(client)
{
	if (playerLoaded[client])
	{
		decl String:auth[32], String:query[128];
		GetClientAuthString(client, auth, sizeof(auth));

		Format(query, sizeof(query), "UPDATE j2f_experience SET level = %i, experience = %i WHERE steamid = '%s'", playerLevel[client], playerExp[client], auth[8]);
		SendQuery(query);
	}
}

SaveAllPlayerData()
{
	new count, bool:first = true;

	decl String:query[2048];
	strcopy(query, sizeof(query), "INSERT INTO j2f_experience (steamid, level, experience) VALUES");

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && playerLoaded[i])
		{
			if (first)
			{
				first = false;
			}
			else
			{
				StrCat(query, sizeof(query), ", ");
			}

			decl String:auth[32], String:buffer[64];
			GetClientAuthString(i, auth, sizeof(auth));

			Format(buffer, sizeof(buffer), "('%s', %i, %i)", auth[8], playerLevel[i], playerExp[i]);
			StrCat(query, sizeof(query), buffer);
			count++;
		}
	}

	if (count)
	{
		StrCat(query, sizeof(query), " ON DUPLICATE KEY UPDATE level = VALUES(level), experience = VALUES(experience)");
		SendQuery(query);
	}
}

SQLConnect()
{
	if (SQL_CheckConfig("j2fortress"))
	{
		SQL_TConnect(sql_Connect, "j2fortress");
	}
	else
	{
		SQL_TConnect(sql_Connect);
	}
}