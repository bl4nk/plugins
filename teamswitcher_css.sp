#pragma semicolon 1

#include <sourcemod>
#include <cstrike>

// Global Definitions
#define PLUGIN_VERSION "1.0.1"

static const String:CSSTeamNames[4][] =
{
	"Unassigned",
	"Spectator",
	"Terrorist",
	"Counter-Terrorist"
};

// Functions
public Plugin:myinfo =
{
	name = "Team Switcher",
	author = "bl4nk",
	description = "Switch the team of a player",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("teamswitcher.phrases");

	RegAdminCmd("sm_team", Command_Team, ADMFLAG_SLAY, "sm_team <#userid|name> <t|ct|spec>");
}

public Action:Command_Team(client, args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_team <#userid|name> <t|ct|spec>");
		return Plugin_Handled;
	}

	decl String:arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg1,
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

	decl String:arg2[16];
	GetCmdArg(2, arg2, sizeof(arg2));

	new team;
	if (strcmp(arg2, "spec", false) == 0)
		team = CS_TEAM_SPECTATOR;
	else if (strcmp(arg2, "Terrorist", false) == 0 || strcmp(arg2, "T", false) == 0)
		team = CS_TEAM_T;
	else if (strcmp(arg2, "CounterTerrorist", false) == 0 || strcmp(arg2, "ct", false) == 0)
		team = CS_TEAM_CT;

	if (!team)
	{
		ReplyToCommand(client, "[SM] Invalid Team Name");
		return Plugin_Handled;
	}

	ChangeClientTeam(target_list[0], team);

	ShowActivity2(client, "[SM] ", "%t", "Switched Player", target_name, CSSTeamNames[team]);
	LogAction(client, target_list[0], "\"%L\" switched \"%L\" to %s", client, target_list[0], CSSTeamNames[team]);

	return Plugin_Handled;
}