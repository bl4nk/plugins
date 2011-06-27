// Flags & Bodygroup stuff borrowed from TF2 Equipment Manager: http://forums.alliedmods.net/showthread.php?t=98651

#pragma semicolon 1

#include <sourcemod>
#include <sourcemod>
#include <tf2_stocks>
#include <attachables>

#define MAX_HAT_COUNT 256

#define EF_BONEMERGE            (1 << 0)
#define EF_BRIGHTLIGHT          (1 << 1)
#define EF_DIMLIGHT             (1 << 2)
#define EF_NOINTERP             (1 << 3)
#define EF_NOSHADOW             (1 << 4)
#define EF_NODRAW               (1 << 5)
#define EF_NORECEIVESHADOW      (1 << 6)
#define EF_BONEMERGE_FASTCULL   (1 << 7)
#define EF_ITEM_BLINK           (1 << 8)
#define EF_PARENT_ANIMATES      (1 << 9)

#define FLAG_HIDE_SCOUT_HAT        (1 << 0)
#define FLAG_HIDE_SCOUT_HEADPHONES (1 << 1)
#define FLAG_HIDE_HEAVY_HANDS      (1 << 2)
#define FLAG_HIDE_ENGINEER_HELMET  (1 << 3)
#define FLAG_SHOW_SNIPER_QUIVER    (1 << 4)
#define FLAG_HIDE_SNIPER_HAT       (1 << 5)
#define FLAG_HIDE_SOLDIER_ROCKET   (1 << 6)
#define FLAG_HIDE_SOLDIER_HELMET   (1 << 7)

#define BODYGROUP_SCOUT_HAT        (1 << 0)
#define BODYGROUP_SCOUT_HEADPHONES (1 << 1)
#define BODYGROUP_HEAVY_HANDS      (1 << 0)
#define BODYGROUP_ENGINEER_HELMET  (1 << 0)
#define BODYGROUP_SNIPER_QUIVER    (1 << 0)
#define BODYGROUP_SNIPER_HAT       (1 << 1)
#define BODYGROUP_SOLDIER_ROCKET   (1 << 0)
#define BODYGROUP_SOLDIER_HELMET   (1 << 1)
#define BODYGROUP_SOLDIER_MEDAL    (1 << 2)

new g_iHatCount;
new g_iHatChoice[MAXPLAYERS+1]    = {-1, ...};
new g_iHatEntSelf[MAXPLAYERS+1]   = {-1, ...};
new g_iHatEntOthers[MAXPLAYERS+1] = {-1, ...};

new Handle:g_hSDKEquipWearable;
new Handle:g_hSDKRemoveWearable;

new Handle:g_hClientMenu[MAXPLAYERS+1] = {Handle:-1, ...};

new String:g_szDisplayName[MAX_HAT_COUNT][32];
new String:g_szModelPath[MAX_HAT_COUNT][10][PLATFORM_MAX_PATH];
new g_iHatFlags[MAX_HAT_COUNT];
new g_iHatIndex[MAX_HAT_COUNT];

public Plugin:myinfo = {
    name = "DonorHats",
    author = "bl4nk",
    description = "Give donators access to custom hats",
    version = "2.0.0-j2",
    url = "http://forums.joe.to/"
};

public OnPluginStart() {
    RegConsoleCmd("sm_hats", Command_Hats);
    
    HookEvent("post_inventory_application", Event_PostInvApp);
    HookEvent("player_death", Event_PlayerDeath);
    
    new Handle:hGameConf = LoadGameConfigFile("j2tools");
    
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "EquipWearable");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    g_hSDKEquipWearable = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "RemoveWearable");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    g_hSDKRemoveWearable = EndPrepSDKCall();
    
    if (hGameConf != INVALID_HANDLE) { CloseHandle(hGameConf); }
}

public OnPluginEnd() {
    for (new i = 1; i <= MaxClients; i++) {
        if (g_iHatChoice[i] != -1) { RemoveHat(i); }
    }
}

public OnMapStart() { ParseKVFile(); }

public bool:OnClientConnect(iClient) {
    g_iHatChoice[iClient] = g_iHatEntSelf[iClient] = g_iHatEntOthers[iClient] = -1;
    return true;
}

public OnClientDisconnect(iClient) {
    g_iHatChoice[iClient] = g_iHatEntSelf[iClient] = g_iHatEntOthers[iClient] = -1;
}

public Event_PostInvApp(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast) {
    new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    if (iClient > 0 && IsClientInGame(iClient) && IsPlayerAlive(iClient)) {
        if (g_iHatChoice[iClient] != -1){ 
            RemoveHat(iClient);
            GiveHat(iClient);
        }
    }
}

public Event_PlayerDeath(Handle:hEvent, const String:szEventName[], bool:bDontBroadcast) {
    new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
    if (iClient > 0 && IsClientInGame(iClient)) {
        RemoveHat(iClient);
    }
}

public Action:Command_Hats(iClient, iArgs) {
    if (!iClient) {
        ReplyToCommand(iClient, "[SM] This command can not be executed by the server.");
        return Plugin_Handled;
    }
    
    if (CheckAdminFlags(iClient, ADMFLAG_CUSTOM1)) {
        DisplayHatMainMenu(iClient);
    } else {
        ReplyToCommand(iClient, "[SM] This command is for donors only.");
    }
    
    return Plugin_Handled;
}

DisplayHatMainMenu(iClient) {
    new Handle:hHatsMenu = CreateMenu(MenuHandler_HatMainMenu);
    
    decl String:szBuffer[64];
    Format(szBuffer, sizeof(szBuffer), "Current Hat: %s", (g_iHatChoice[iClient]!=-1?g_szDisplayName[g_iHatChoice[iClient]]:"None"));
    
    SetMenuTitle(hHatsMenu, szBuffer);
    AddMenuItem(hHatsMenu, "", "Equip Hat", ITEMDRAW_DEFAULT);
    AddMenuItem(hHatsMenu, "", "Remove Hat", (g_iHatChoice[iClient]!=-1?ITEMDRAW_DEFAULT:ITEMDRAW_DISABLED));
    AddMenuItem(hHatsMenu, "", "Others", ITEMDRAW_DISABLED);
    
    SetMenuExitButton(hHatsMenu, true);
    DisplayMenu(hHatsMenu, iClient, 30);
}

public MenuHandler_HatMainMenu(Handle:hMenu, MenuAction:hAction, iClient, iChoice) {
    if (hAction == MenuAction_Select) {
        switch (iChoice) {
            case 0: { // Equip Hat
                DisplayHatSelectionMenu(iClient);
            }
            case 1: { // Remove Hat
                g_iHatChoice[iClient] = -1;
                
                RemoveHat(iClient);
                DisplayHatMainMenu(iClient);
            }
            case 2: { // Others
                // Nothing yet!
            }
        }
    }
}

DisplayHatSelectionMenu(iClient) {
    decl String:szNumBuffer[3];
    
    g_hClientMenu[iClient] = CreateMenu(MenuHandler_HatSelectionMenu);
    SetMenuTitle(g_hClientMenu[iClient], "Choose a hat:");
    
    for (new i = 0; i < MAX_HAT_COUNT; i++)	{
        if (strlen(g_szDisplayName[i]) > 0)	{
            IntToString(i, szNumBuffer, sizeof(szNumBuffer));
            AddMenuItem(g_hClientMenu[iClient], szNumBuffer, g_szDisplayName[i], (g_iHatChoice[iClient]==i?ITEMDRAW_DISABLED:ITEMDRAW_DEFAULT));
        }
    }

    SetMenuPagination(g_hClientMenu[iClient], 7);
    SetMenuExitBackButton(g_hClientMenu[iClient], true);

    DisplayMenu(g_hClientMenu[iClient], iClient, 30);
}

public MenuHandler_HatSelectionMenu(Handle:hMenu, MenuAction:hAction, iClient, iChoice) {
    if (hAction == MenuAction_Select) {
        RemoveHat(iClient);

        if (iChoice <= g_iHatCount) {			
            g_iHatChoice[iClient] = iChoice;
            
            if (IsPlayerAlive(iClient)) {
                GiveHat(iClient);
            }
        } else {
            g_iHatChoice[iClient] = -1;
            g_iHatEntSelf[iClient] = -1;
            g_iHatEntOthers[iClient] = -1;
        }
        
        DisplayHatSelectionMenu(iClient);
    } else if (hAction == MenuAction_End) {
        for (new i = 1; i <= MaxClients; i++) {
            if (g_hClientMenu[i] == hMenu) {
                if (iClient /* <-- The reason */ == MenuEnd_ExitBack) {
                    DisplayHatMainMenu(i);
                }
                
                g_hClientMenu[i] = Handle:-1;
                break;
            }
        }
    }
}

GiveHat(iClient) {
    new iClass = _:TF2_GetPlayerClass(iClient);
    if (strlen(g_szModelPath[g_iHatChoice[iClient]][iClass]) == 0) {
        iClass = 0;
    }
    
    new iEntSelf = CreateEntityByName("tf_wearable_item"), iTeam = GetClientTeam(iClient);
    if (iEntSelf != -1) {
        
        SetEntProp(iEntSelf, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL|EF_NOSHADOW|EF_PARENT_ANIMATES);
        SetEntProp(iEntSelf, Prop_Send, "m_iTeamNum", iTeam);
        SetEntProp(iEntSelf, Prop_Send, "m_nSkin", 0);
        SetEntProp(iEntSelf, Prop_Send, "m_CollisionGroup", 11);
        SetEntProp(iEntSelf, Prop_Send, "m_iEntityLevel", 100);
        SetEntProp(iEntSelf, Prop_Send, "m_iEntityQuality", 0);
        SetEntProp(iEntSelf, Prop_Send, "m_iItemDefinitionIndex", g_iHatIndex[g_iHatChoice[iClient]]);
        
        DispatchSpawn(iEntSelf);
        g_iHatEntSelf[iClient] = iEntSelf;
        
        SetEntityModel(iEntSelf, g_szModelPath[g_iHatChoice[iClient]][iClass]);
        SDKCall(g_hSDKEquipWearable, iClient, iEntSelf);
    }
    
    new iEntOthers = Attachable_CreateAttachable(iClient);
    if (iEntOthers != -1) {
        g_iHatEntOthers[iClient] = iEntOthers;
        SetEntProp(iEntSelf, Prop_Send, "m_nSkin", (iTeam-2));
        SetEntityModel(iEntOthers, g_szModelPath[g_iHatChoice[iClient]][iClass]);
    }
    
    SetEntProp(iClient, Prop_Send, "m_nBody", CalculateBodyGroups(iClient));
}

RemoveHat(iClient) {
    if (g_iHatEntSelf[iClient] != -1) {
        SDKCall(g_hSDKRemoveWearable, iClient, g_iHatEntSelf[iClient]);
        RemoveEdict(g_iHatEntSelf[iClient]);
        
        g_iHatEntSelf[iClient] = -1;
    }
    if (g_iHatEntOthers[iClient] != -1) {
        Attachable_UnhookEntity(g_iHatEntOthers[iClient]);
        RemoveEdict(g_iHatEntOthers[iClient]);
        
        g_iHatEntOthers[iClient] = -1;
    }
}

ParseKVFile() {
    for (new i = 0; i < MAX_HAT_COUNT; i++) {
        g_szDisplayName[i][0] = '\0';
        
        for (new j = 0; j < 10; j++) {
            g_szModelPath[i][j][0] = '\0';
        }
    }
    
    new Handle:hKeyValues = CreateKeyValues("Hats");
    
    decl String:szConfigPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, szConfigPath, sizeof(szConfigPath), "configs/donorhats.txt");
    
    if (FileExists(szConfigPath)) {
        FileToKeyValues(hKeyValues, szConfigPath);
        if (KvGotoFirstSubKey(hKeyValues)) {
            new iHatCount;
            decl String:szDepFilePathBuffer[128];
            decl String:szDepLineBuffer[128];
            
            do {
                KvGetString(hKeyValues, "name", g_szDisplayName[iHatCount], sizeof(g_szDisplayName[]));
                
                KvGetString(hKeyValues, "path_all",         g_szModelPath[iHatCount][0], sizeof(g_szModelPath[][]));
                KvGetString(hKeyValues, "path_scout",       g_szModelPath[iHatCount][1], sizeof(g_szModelPath[][]));
                KvGetString(hKeyValues, "path_sniper",      g_szModelPath[iHatCount][2], sizeof(g_szModelPath[][]));
                KvGetString(hKeyValues, "path_soldier",     g_szModelPath[iHatCount][3], sizeof(g_szModelPath[][]));
                KvGetString(hKeyValues, "path_demoman",     g_szModelPath[iHatCount][4], sizeof(g_szModelPath[][]));
                KvGetString(hKeyValues, "path_medic",       g_szModelPath[iHatCount][5], sizeof(g_szModelPath[][]));
                KvGetString(hKeyValues, "path_heavy",       g_szModelPath[iHatCount][6], sizeof(g_szModelPath[][]));
                KvGetString(hKeyValues, "path_pyro",        g_szModelPath[iHatCount][7], sizeof(g_szModelPath[][]));
                KvGetString(hKeyValues, "path_spy",         g_szModelPath[iHatCount][8], sizeof(g_szModelPath[][]));
                KvGetString(hKeyValues, "path_engineer",    g_szModelPath[iHatCount][9], sizeof(g_szModelPath[][]));
                
                g_iHatIndex[iHatCount] = KvGetNum(hKeyValues, "index");
                
                decl String:szFlags[256];
                KvGetString(hKeyValues, "flags", szFlags, sizeof(szFlags));
                
                g_iHatFlags[iHatCount] = ParseFlags(szFlags);
                
                for (new i = 0; i < 10; i++) {
                    if (strlen(g_szModelPath[iHatCount][i]) > 0) {
                        PrecacheModel(g_szModelPath[iHatCount][i]);
                    }
                }
                
                KvGetString(hKeyValues, "dep_file", szDepFilePathBuffer, sizeof(szDepFilePathBuffer));
                if (strlen(szDepFilePathBuffer) > 0 && FileExists(szDepFilePathBuffer)) {
                    new Handle:hDepFile = OpenFile(szDepFilePathBuffer, "r");
                    
                    while (ReadFileLine(hDepFile, szDepLineBuffer, sizeof(szDepLineBuffer))) {
                        new iLen = strlen(szDepLineBuffer);
                        if (iLen > 0) {
                            CleanString(szDepLineBuffer);
                            AddFileToDownloadsTable(szDepLineBuffer);
                        }
                    }
                    
                    CloseHandle(hDepFile);
                }
                
                iHatCount++;
            } while (KvGotoNextKey(hKeyValues));
            
            g_iHatCount = --iHatCount;
        }
    } else {
        SetFailState("Unable to read 'configs/donorhats.txt' file");
    }
    
    CloseHandle(hKeyValues);
}

CleanString(String:szBuffer[])
{
    new iLen = strlen(szBuffer);
    for (new iPos = 0; iPos < iLen; iPos++)
    {
        switch(szBuffer[iPos])
        {
            case '\r': szBuffer[iPos] = ' ';
            case '\n': szBuffer[iPos] = ' ';
            case '\t': szBuffer[iPos] = ' ';
        }
    }
    
    TrimString(szBuffer);
}

bool:CheckAdminFlags(client, flags)
{
    new AdminId:admin = GetUserAdmin(client);
    if (admin != INVALID_ADMIN_ID)
    {
        new count, found;
        for (new i = 0; i <= 20; i++)
        {
            if (flags & (1<<i))
            {
                count++;

                if (GetAdminFlag(admin, AdminFlag:i))
                {
                    found++;
                }
            }
        }

        if (count == found)
        {
            return true;
        }
    }

    return false;
}

ParseFlags(const String:szFlags[]) {
    new iFlags;
    if (StrContains(szFlags, "HIDE_SCOUT_HAT", false) != -1) iFlags |= FLAG_HIDE_SCOUT_HAT;
    if (StrContains(szFlags, "HIDE_SCOUT_HEADPHONES", false) != -1) iFlags |= FLAG_HIDE_SCOUT_HEADPHONES;
    if (StrContains(szFlags, "HIDE_HEAVY_HANDS", false) != -1) iFlags |= FLAG_HIDE_HEAVY_HANDS;    
    if (StrContains(szFlags, "HIDE_ENGINEER_HELMET", false) != -1) iFlags |= FLAG_HIDE_ENGINEER_HELMET;
//  if (StrContains(szFlags, "HIDE_SNIPER_QUIVER", false) != -1) iFlags |= FLAG_HIDE_SNIPER_QUIVER;
    if (StrContains(szFlags, "HIDE_SNIPER_HAT", false) != -1) iFlags |= FLAG_HIDE_SNIPER_HAT;     
    if (StrContains(szFlags, "HIDE_SOLDIER_ROCKET", false) != -1) iFlags |= FLAG_HIDE_SOLDIER_ROCKET;
    if (StrContains(szFlags, "HIDE_SOLDIER_HELMET", false) != -1) iFlags |= FLAG_HIDE_SOLDIER_HELMET;
    
    return iFlags;
}

CalculateBodyGroups(iClient)
{
    new iBodyGroups = GetEntProp(iClient, Prop_Send, "m_nBody");
    new iItemGroups = g_iHatFlags[g_iHatChoice[iClient]];
    
    switch(TF2_GetPlayerClass(iClient))
    {
        case TFClass_Heavy:
        {
            if (iItemGroups & FLAG_HIDE_HEAVY_HANDS) iBodyGroups = BODYGROUP_HEAVY_HANDS;
        }
        case TFClass_Engineer:
        {
            if (iItemGroups & FLAG_HIDE_ENGINEER_HELMET) iBodyGroups |= BODYGROUP_ENGINEER_HELMET;
        }
        case TFClass_Scout:
        {
            if (iItemGroups & FLAG_HIDE_SCOUT_HAT) iBodyGroups |= BODYGROUP_SCOUT_HAT;
            if (iItemGroups & FLAG_HIDE_SCOUT_HEADPHONES) iBodyGroups |= BODYGROUP_SCOUT_HEADPHONES;
        }
        case TFClass_Sniper:
        {
            if (iItemGroups & FLAG_SHOW_SNIPER_QUIVER) iBodyGroups |= BODYGROUP_SNIPER_QUIVER;
            if (iItemGroups & FLAG_HIDE_SNIPER_HAT) iBodyGroups |= BODYGROUP_SNIPER_HAT;
        }
        case TFClass_Soldier:
        {
            if (iItemGroups & FLAG_HIDE_SOLDIER_ROCKET) iBodyGroups |= BODYGROUP_SOLDIER_ROCKET;   
            if (iItemGroups & FLAG_HIDE_SOLDIER_HELMET) iBodyGroups |= BODYGROUP_SOLDIER_HELMET;   
        }
    }
    
    return iBodyGroups;
}