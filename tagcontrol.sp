#pragma semicolon 1

#include <sourcemod>
#include <tagcontrol>

public Plugin:myinfo = {
    name = "TagControl",
    author = "bl4nk",
    description = "Control which tags show up and which don't",
    version = "1.0.0",
    url = "http://forums.alliedmods.net/"
};

public Action:OnAddTag(const String:szTag[]) {
    if (strcmp(szTag, "friendlyfire", false) == 0) {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}