#pragma semicolon 1

#include <sourcemod>

// Global Definitions
#define PLUGIN_VERSION "1.1.0"

#define DAY_IN_MINUTES 1440

public Plugin:myinfo = {
	name = "TempBan",
	author = "bl4nk",
	description = "Ban a player until the map changes",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};

public OnPluginStart() {
	LoadTranslations("common.phrases");

	CreateConVar("sm_tempban_version", PLUGIN_VERSION, "TempBan Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	RegAdminCmd("sm_tempban", Command_Tempban, ADMFLAG_BAN, "sm_tempban <#userid|name> [time|30] [reason]");
}

public Action:Command_Tempban(iClient, iArgs) {
	if (iArgs < 1) {
		ReplyToCommand(iClient, "[SM] Usage: sm_tempban <#userid|name> [time|30] [reason]");
		return Plugin_Handled;
	}

	new iLen, iTime;
	decl String:szArgs[128];
	GetCmdArgString(szArgs, sizeof(szArgs));

	decl String:szTarget[32];
	iLen = BreakString(szArgs, szTarget, sizeof(szTarget));

	decl String:szTargetName[MAX_TARGET_LENGTH];
	decl iTargetList[MAXPLAYERS], iTargetCount, bool:bTransIsMulti;

	if ((iTargetCount = ProcessTargetString(
			szTarget,
			iClient,
			iTargetList,
			MAXPLAYERS,
			COMMAND_FILTER_NO_MULTI,
			szTargetName,
			sizeof(szTargetName),
			bTransIsMulti)) <= 0) {
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}

	decl String:szTime[8], String:szReason[32];
	if (iLen > -1) {
		new next_len = BreakString(szArgs[iLen], szTime, sizeof(szTime));
		iTime = StringToInt(szTime);

		if (iTime <= 0) {
			ReplyToCommand(iClient, "[SM] You're not allowed to ban a client permanently.");
			return Plugin_Handled;
		} else if (iTime > DAY_IN_MINUTES) {
			ReplyToCommand(iClient, "[SM] You're not allowed to ban a client for more than 1 day.");
			return Plugin_Handled;
		}

		if (next_len > -1) {
			strcopy(szReason, sizeof(szReason), szArgs[iLen+next_len]);
		} else {
			strcopy(szReason, sizeof(szReason), "Temp banned");
		}
	} else {
		iTime = 30;
		strcopy(szReason, sizeof(szReason), "Temp banned");
	}

	decl String:szAuth[32];
	GetClientAuthString(iTargetList[0], szAuth, sizeof(szAuth));

	LogMessage("%N temp banned %N (%s) for %i minutes with reason: %s", iClient, iTargetList[0], szAuth, iTime, szReason);
	BanClient(iTargetList[0], iTime, BANFLAG_AUTHID, szReason, szReason, "tempban", iClient);

	return Plugin_Handled;
}