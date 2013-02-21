#include <sourcemod>
#define REQUIRE_EXTENSIONS
#include <connect>

enum KickType
{
    Kick_HighestPing = 1,
    Kick_ShortestTime,
    Kick_Random,
};

new Handle:g_hcvarKickType = INVALID_HANDLE;
new KickType:g_KickType = Kick_HighestPing;

public Plugin:myinfo =
{
    name = "Reserved Slots (Connect Extension)",
    author = "bl4nk",
    description = "Reserved slots, even with a full server",
    version = "1.0.0",
    url = "http://www.joe.to/"
};

public OnPluginStart()
{
    g_hcvarKickType = CreateConVar("sm_reservedslots_type", "1", "Who to kick? 1 - Highest ping (default). 2 - Shortest connection time. 3 - Random.", 0, true, 1.0, true, 3.0);
    HookConVarChange(g_hcvarKickType, OnKickTypeChanged);
}

public OnKickTypeChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
    g_KickType = KickType:StringToInt(newValue);
}

public bool:OnClientPreConnectEx(const String:name[], String:pass[255], const String:ip[], const String:authid[], String:rejectReason[255])
{
    if (GetClientCount(false) >= MaxClients)
    {
        new AdminId:admin = FindAdminByIdentity(AUTHMETHOD_STEAM, authid);

        if (admin == INVALID_ADMIN_ID)
        {
            Format(rejectReason, 255, "Server is full\nVisit http://forums.joe.to/ to request a\nfree reserved slot!");
            return false;
        }

        if (GetAdminFlag(admin, Admin_Reservation))
        {
            new target = SelectKickClient();

            if (target)
            {
                KickClientEx(target, "Slot reserved\nVisit http://forums.joe.to/ to request a\nfree reserved slot!");
            }
        }
    }

    return true;
}

SelectKickClient()
{
    new Float:highestValue;
    new highestValueId;

    new Float:highestSpecValue;
    new highestSpecValueId;

    new bool:specFound;

    new Float:value;

    for (new i=1; i<=MaxClients; i++)
    {
        if (!IsClientConnected(i))
        {
            continue;
        }

        new flags = GetUserFlagBits(i);

        if (IsFakeClient(i) || flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION || CheckCommandAccess(i, "sm_reskick_immunity", ADMFLAG_RESERVATION, false))
        {
            continue;
        }

        value = 0.0;

        if (IsClientInGame(i))
        {
            switch(g_KickType)
            {
                case Kick_HighestPing:
                    value = GetClientAvgLatency(i, NetFlow_Outgoing);
                case Kick_ShortestTime:
                    value = GetClientTime(i);
                default:
                    value = GetRandomFloat(0.0, 100.0);
            }

            if (IsClientObserver(i))
            {
                specFound = true;

                if (g_KickType == Kick_ShortestTime)
                {
                    if (value < highestSpecValue)
                    {
                        highestSpecValue = value;
                        highestSpecValueId = i;
                    }
                } 
                else if (value > highestSpecValue)
                {
                    highestSpecValue = value;
                    highestSpecValueId = i;
                }
            }
        }

        if (g_KickType == Kick_ShortestTime)
        {
            if (value <= highestValue)
            {
                highestValue = value;
                highestValueId = i;
            }
        }
        else if (value >= highestValue)
        {
            highestValue = value;
            highestValueId = i;
        }
    }

    if (specFound)
    {
        return highestSpecValueId;
    }

    return highestValueId;
}
