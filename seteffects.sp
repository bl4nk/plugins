#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

new bool:g_bEnabledEffects[MAXPLAYERS+1][TFCond];

public Plugin:myinfo =
{
	name = "[J2] Set Effects",
	author = "bl4nk",
	description = "Set playercond effects on clients",
	version = "1.0.0-j2",
	url = "http://forums.joe.to"
};

public OnPluginStart()
{
	RegAdminCmd("sm_seteffect", Command_SetEffect, ADMFLAG_CHEATS);
	
	HookEvent("player_spawn", Event_SetEffects);
	HookEvent("player_changeclass", Event_SetEffects);
}

public OnClientPutInServer(iClient)
{
	for (new TFCond:i = TFCond_Slowed; i <= TFCond_Jarated; i++)
	{
		g_bEnabledEffects[iClient][i] = false;
	}
}

public Action:Command_SetEffect(iClient, iArgs)
{
	if (iArgs < 3)
	{
		ReplyToCommand(iClient, "[SM] Usage: sm_seteffect <#userid|name> <effect name> <0/1>");
		ReplyToCommand(iClient, "[SM] Valid effect names: slowed, ubercharged, teleportedglow, uberchargefading, kritzkrieged, bonked, dazed, buffed, overhealed");
		return Plugin_Handled;
	}
	
	decl String:szBuffer[32];
	GetCmdArg(1, szBuffer, sizeof(szBuffer));

	decl String:szTargetName[MAX_TARGET_LENGTH];
	decl aiTargetList[MAXPLAYERS], iTargetCount, bool:bTNisML;

	if ((iTargetCount = ProcessTargetString(
			szBuffer,
			iClient,
			aiTargetList,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			szTargetName,
			sizeof(szTargetName),
			bTNisML)) <= 0)
	{
		ReplyToTargetError(iClient, iTargetCount);
		return Plugin_Handled;
	}
	
	GetCmdArg(2, szBuffer, sizeof(szBuffer));
	
	new TFCond:iCond;
	if ((iCond = FindCond(szBuffer)) == TFCond:-1)
	{
		ReplyToCommand(iClient, "[SM] Invalid effect name");
		return Plugin_Handled;
	}
	
	GetCmdArg(3, szBuffer, sizeof(szBuffer));
	
	new iBuffer = StringToInt(szBuffer);
	
	if (iBuffer != 0 && iBuffer != 1)
	{
		ReplyToCommand(iClient, "[SM] Third arg must be 0 or 1");
		return Plugin_Handled;
	}

	new bool:bValue = bool:iBuffer;	
	for (new i = 0; i < iTargetCount; i++)
	{
		g_bEnabledEffects[iClient][iCond] = bValue;
		
		if (IsPlayerAlive(aiTargetList[i]))
		{
			SetEffect(aiTargetList[i], iCond, bValue);
		}
	}
	
	return Plugin_Handled;
}

public Event_SetEffects(Handle:hEvent, const String:szName[], bool:bDontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (iClient > 0)
	{
		for (new TFCond:i = TFCond_Slowed; i <= TFCond_Jarated; i++)
		{
			if (g_bEnabledEffects[iClient][i] == true)
			{
				SetEffect(iClient, i, true);
			}
		}
	}
}

SetEffect(iClient, TFCond:iCond, bool:bEnableEffect)
{
	if (bEnableEffect == true)
	{
		TF2_AddCondition(iClient, iCond, 9999.0);
	}
	else
	{
		TF2_RemoveCondition(iClient, iCond);
	}
}

TFCond:FindCond(const String:szBuffer[])
{
	if (strcmp(szBuffer, "slowed", false) == 0)
	{
		return TFCond_Slowed;
	}
	else if (strcmp(szBuffer, "ubercharged", false) == 0)
	{
		return TFCond_Ubercharged;
	}
	else if (strcmp(szBuffer, "teleportedglow", false) == 0)
	{
		return TFCond_TeleportedGlow;
	}
	else if (strcmp(szBuffer, "uberchargefading", false) == 0)
	{
		return TFCond_UberchargeFading;
	}
	else if (strcmp(szBuffer, "kritzkrieged", false) == 0)
	{
		return TFCond_Kritzkrieged;
	}
	else if (strcmp(szBuffer, "bonked", false) == 0)
	{
		return TFCond_Bonked;
	}
	else if (strcmp(szBuffer, "dazed", false) == 0)
	{
		return TFCond_Dazed;
	}
	else if (strcmp(szBuffer, "buffed", false) == 0)
	{
		return TFCond_Buffed;
	}
	else if (strcmp(szBuffer, "overhealed", false) == 0)
	{
		return TFCond_Overhealed;
	}
	
	return TFCond:-1;
}