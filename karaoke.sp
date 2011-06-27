#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

// Global Definitions
#define PLUGIN_VERSION "1.0.0"

new g_CurrentSong = -1;
new g_SongID = 0;
new maxclients;

new bool:playing;

new String:g_Paths[256][64];
new String:g_Names[256][64];
new String:g_Files[256][64];

// Functions
public Plugin:myinfo =
{
	name = "Karaoke",
	author = "bl4nk",
	description = "Play a song and display the lyrics",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net"
};

public OnPluginStart()
{
	CreateConVar("sm_karaoke_version", PLUGIN_VERSION, "Karaoke Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	RegAdminCmd("sm_karaoke", Command_Karaoke, ADMFLAG_SLAY);
}

public OnMapStart()
{
	ParseFile();
	maxclients = GetMaxClients();
}

public Action:Command_Karaoke(client, args)
{
	if (!client)
	{
		ReplyToCommand(client, "[SM] This command can not be executed by the server.");
		return Plugin_Handled;
	}

	DisplayKaraokeMenu(client);
	return Plugin_Handled;
}

DisplayKaraokeMenu(client)
{
	new Handle:menu = CreateMenu(KaraokeHandler);

	if (playing)
	{
		AddMenuItem(menu, "play", "Play a song", ITEMDRAW_DISABLED);
		AddMenuItem(menu, "stop", "Stop current songs");
	}
	else
	{
		AddMenuItem(menu, "play", "Play a song");
		AddMenuItem(menu, "stop", "Stop current songs", ITEMDRAW_DISABLED);
	}

	AddMenuItem(menu, "parse", "Parse the Karaoke file");
	SetMenuExitButton(menu, true);

	DisplayMenu(menu, client, 30);
}

public KaraokeHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0: // play song
			{
				DisplaySongsMenu(param1);
			}
			case 1: // stop songs
			{
				StopSong();
				DisplayKaraokeMenu(param1);
			}
			case 2: // parse file
			{
				ParseFile();
				DisplayKaraokeMenu(param1);
			}
		}
	}
}

DisplaySongsMenu(client)
{
	new Handle:songsMenu = CreateMenu(SongsHandler);

	for (new i = 0; i < sizeof(g_Names); i++)
	{
		if (!strcmp(g_Names[i], "\0"))
			break;

		decl String:numBuffer[5];
		IntToString(i, numBuffer, sizeof(numBuffer));

		AddMenuItem(songsMenu, numBuffer, g_Names[i]);
	}

	SetMenuPagination(songsMenu, 7);
	SetMenuExitButton(songsMenu, true);

	DisplayMenu(songsMenu, client, 30);
}

public SongsHandler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		StartSong(param1, param2);
	}
}

StartSong(client, number)
{
	decl String:path[PLATFORM_MAX_PATH+1];
	Format(path, sizeof(path), "sound/%s", g_Paths[number]);

	if (FileExists(path))
	{
		BuildPath(Path_SM, path, sizeof(path), "configs/karaoke/%s", g_Files[number]);

		if (FileExists(path))
		{
			g_CurrentSong = number;
			playing = true;
			g_SongID++;

			CreateTimer(1.0, CountDown, 15, TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			PrintCenterText(client, "ERROR: Lyrics file not found.");
		}
	}
	else
	{
		PrintCenterText(client, "ERROR: Song file not found.");
	}
}

public Action:CountDown(Handle:timer, any:timeRemaining)
{
	if (!playing)
	{
		return Plugin_Handled;
	}

	switch (timeRemaining)
	{
		case 15:
		{
			PrecacheSound("vo/announcer_attention.wav");
			EmitSoundToAll("vo/announcer_attention.wav");
		}
		case 10:
		{
			PrecacheSound("vo/announcer_begins_10sec.wav");
			EmitSoundToAll("vo/announcer_begins_10sec.wav");
		}
		case 5:
		{
			PrecacheSound("vo/announcer_begins_5sec.wav");
			EmitSoundToAll("vo/announcer_begins_5sec.wav");
		}
		case 4:
		{
			PrecacheSound("vo/announcer_begins_4sec.wav");
			EmitSoundToAll("vo/announcer_begins_4sec.wav");
		}
		case 3:
		{
			PrecacheSound("vo/announcer_begins_3sec.wav");
			EmitSoundToAll("vo/announcer_begins_3sec.wav");
		}
		case 2:
		{
			PrecacheSound("vo/announcer_begins_2sec.wav");
			EmitSoundToAll("vo/announcer_begins_2sec.wav");
		}
		case 1:
		{
			PrecacheSound("vo/announcer_begins_1sec.wav");
			EmitSoundToAll("vo/announcer_begins_1sec.wav");
		}
		case 0:
		{
			PlaySong();

			return Plugin_Handled;
		}
	}

	PrintCenterTextAll("%s \nKaraoke Will Begin in %i Seconds \nAdjust your volume now if needed!", g_Names[g_CurrentSong], timeRemaining);
	CreateTimer(1.0, CountDown, timeRemaining-1);

	return Plugin_Continue;
}

PlaySong()
{
	decl String:filePath[PLATFORM_MAX_PATH+1];
	BuildPath(Path_SM, filePath, sizeof(filePath), "configs/karaoke/%s", g_Files[g_CurrentSong]);

	EmitSoundToAll(g_Paths[g_CurrentSong]);

	new Handle:file = OpenFile(filePath, "r");

	if (IsEndOfFile(file))
	{
		PrintToChatAll("karaoke file not found, stopping");
		StopSong();
	}
	else
	{
		new Handle:dp = CreateDataPack();
		WritePackCell(dp, g_SongID);
		WritePackCell(dp, _:file);
		WritePackFloat(dp, GetEngineTime());
		WritePackFloat(dp, 0.1);
		WritePackString(dp, "\0");

		CreateTimer(0.1, DisplayLyrics, dp, TIMER_FLAG_NO_MAPCHANGE);
	}
}

StopSong()
{
	for (new i = 1; i <= maxclients; i++)
	{
		if (IsClientInGame(i))
		{
			StopSound(i, SNDCHAN_AUTO, g_Paths[g_CurrentSong]);
		}
	}

	playing = false;
	g_CurrentSong = -1;
}

public Action:StopSongsTimer(Handle:timer)
{
	playing = false;
	g_CurrentSong = -1;
}

public Action:DisplayLyrics(Handle:timer, any:data)
{
	ResetPack(data);

	decl String:text[128];
	new songID = ReadPackCell(data);
	new Handle:file = Handle:ReadPackCell(data);
	new Float:startTime = ReadPackFloat(data);
	new Float:nextTime = ReadPackFloat(data);
	ReadPackString(data, text, sizeof(text));
	
	CloseHandle(data);

	if (!playing || songID != g_SongID)
	{
		CloseHandle(file);
		return;
	}

	new Float:currTime = GetEngineTime() - startTime;
	if (currTime >= nextTime)
	{
		if (!strcmp(text[10], "**STOP**"))
		{
			playing = false;
			g_CurrentSong = -1;

			CloseHandle(file);
		}
		else
		{
			if (StrContains(text, "\\n") != -1)
			{
				decl String:buffer[3];
				Format(buffer, sizeof(buffer), "%c", 13);
				ReplaceString(text, sizeof(text), "\\n", buffer);
			}

			PrintCenterTextAll(text[10]);

			if (ReadFileLine(file, text, sizeof(text)))
			{
				decl String:sTime[10];
				strcopy(sTime, sizeof(sTime), text[1]);
				sTime[8] = '\0';

				decl String:sMinutes[4];
				new start = SplitString(sTime, ":", sMinutes, sizeof(sMinutes));

				new minutes = StringToInt(sMinutes);
				new Float:seconds = StringToFloat(sTime[start]);
				new Float:time = seconds + (minutes*60.0);

				new Handle:dp = CreateDataPack();
				WritePackCell(dp, songID);
				WritePackCell(dp, _:file);
				WritePackFloat(dp, startTime);
				WritePackFloat(dp, time);
				WritePackString(dp, text);

				CreateTimer(0.1, DisplayLyrics, dp);
			}
			else
			{
				playing = false;
				g_CurrentSong = -1;

				CloseHandle(file);
			}
		}
	}
	else
	{
		new Handle:dp = CreateDataPack();
		WritePackCell(dp, songID);
		WritePackCell(dp, _:file);
		WritePackFloat(dp, startTime);
		WritePackFloat(dp, nextTime);
		WritePackString(dp, text);

		CreateTimer(0.1, DisplayLyrics, dp);
	}
}

/* OLD FUNCTION
public Action:DisplayLyrics(Handle:timer, any:data)
{
	ResetPack(data);

	decl String:text[128];
	new Handle:file = Handle:ReadPackCell(data);
	new songID = ReadPackCell(data);
	ReadPackString(data, text, sizeof(text));
	new Float:time = ReadPackFloat(data);

	CloseHandle(data);

	if (!playing || songID != g_SongID)
	{
		CloseHandle(file);
		return;
	}

	if (StrContains(text, "\\n") != -1)
	{
		decl String:buffer[3];
		Format(buffer, sizeof(buffer), "%c", 13);
		ReplaceString(text, sizeof(text), "\\n", buffer);
	}

	PrintCenterTextAll(text);

	if (ReadFileLine(file, text, sizeof(text)))
	{
		decl String:sTime[8];
		new start = BreakString(text, sTime, sizeof(sTime));

		new Float:time = StringToFloat(sTime);
		new Handle:dp = CreateDataPack();
		WritePackCell(dp, _:file);
		WritePackCell(dp, songID);
		WritePackString(dp, text[start]);

		CreateTimer(time, DisplayLyrics, dp);
	}
	else
	{
		playing = false;
		g_CurrentSong = -1;

		CloseHandle(file);
	}
}
*/

ParseFile()
{
	for (new i = 0; i < sizeof(g_Paths); i++)
	{
		g_Paths[i] = "\0";
		g_Names[i] = "\0";
		g_Files[i] = "\0";
	}

	new Handle:KeyValues = CreateKeyValues("Karaoke");

	decl String:path[PLATFORM_MAX_PATH+1];
	BuildPath(Path_SM, path, sizeof(path), "configs/karaoke.txt");

	if (FileExists(path))
	{
		FileToKeyValues(KeyValues, path);
		KvGotoFirstSubKey(KeyValues);

		new c = 0;

		do
		{
			KvGetString(KeyValues, "path", g_Paths[c], sizeof(g_Paths[]));
			KvGetString(KeyValues, "name", g_Names[c], sizeof(g_Names[]));
			KvGetString(KeyValues, "file", g_Files[c], sizeof(g_Files[]));

			decl String:buffer[PLATFORM_MAX_PATH+1];
			Format(buffer, sizeof(buffer), "sound/%s", g_Paths[c]);

			AddFileToDownloadsTable(buffer);
			PrecacheSound(g_Paths[c]);

			c++;
		} while (KvGotoNextKey(KeyValues));
	}
	else
	{
		SetFailState("Unable to load karaoke.txt file");
	}

	CloseHandle(KeyValues);
}