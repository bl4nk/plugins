#pragma semicolon 1

#include <sourcemod>

// Global Definitions
#define PLUGIN_VERSION "1.0.0"

new MoveType:g_iOldMoveType[MAXPLAYERS+1];

// Functions
public Plugin:myinfo =
{
	name = "noclip",
	author = "bl4nk",
	description = "Enable noclip on players",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	RegAdminCmd("sm_noclip", Command_Noclip, ADMFLAG_CHEATS, "sm_noclip <#userid|name>");
}

public Action:Command_Noclip(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_noclip <#userid|name>");
		return Plugin_Handled;
	}

	decl String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;

	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for (new i = 0; i < target_count; i++)
	{
		PerformNoclip(client, target_list[i]);
	}

	return Plugin_Handled;
}

PerformNoclip(iClient, iTarget)
{
    new MoveType:iMoveType = GetEntityMoveType(iTarget);
    if (iMoveType == MOVETYPE_NOCLIP) {
        if (g_iOldMoveType[iTarget] > MOVETYPE_NONE) {
            SetEntityMoveType(iTarget, g_iOldMoveType[iTarget]);
            g_iOldMoveType[iTarget] = MOVETYPE_NONE;
        } else {
            SetEntityMoveType(iTarget, MOVETYPE_WALK);
        }
        
        LogAction(iClient, iTarget, "\"%L\" disabled noclip on \"%L\"", iClient, iTarget);
    } else {
        g_iOldMoveType[iTarget] = iMoveType;
        SetEntityMoveType(iTarget, MOVETYPE_NOCLIP);
        
        LogAction(iClient, iTarget, "\"%L\" enabled noclip on \"%L\"", iClient, iTarget);
    }
}