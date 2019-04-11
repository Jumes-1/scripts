#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma dynamic 131072
#pragma newdecls required

#define BEAM_SIZE 1.2
#define BEAM_JIGGLE 0.0

#define FRAMES 100

public Plugin myinfo = 
{
	name = "Conga",
	author = "Jumes",
	description = "Do the conga",
	version = "0.0.1",
	url = "http://www.google.com/conga"
};

bool IsLeader[MAXPLAYERS + 1] = { false, ... };
int IsFollowing[MAXPLAYERS + 1] = { -1, ... };
int CongaLines[MAXPLAYERS + 1][MAXPLAYERS + 1];

float LastPos[MAXPLAYERS + 1][3];
float CongaFrames[MAXPLAYERS + 1][FRAMES][3];

int g_BeamSprite;
int g_HaloSprite;

public void OnPluginStart()
{
	/*g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo01.vmt");*/
	
	EventHandlers();
	
	//CreateTimer(0.5, Update_Path, INVALID_HANDLE, TIMER_REPEAT);
}

void EventHandlers()
{
	RegConsoleCmd("sm_conga", Command_Conga, "Conga Plugin");
	
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userId = event.GetInt("userid");
	int client = GetClientOfUserId(userId);
	
	if (IsLeader[client] && IsValidClient(client)) {
		CongaEnd(client);
	}
	
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
	if (IsValidClient(client)) {
		if (IsLeader[client]) {
			
			float vPos[3];
			//GetClientAbsOrigin(client, vPos);
			GetEntPropVector(client, Prop_Send, "m_vecOrigin", vPos);
			
			if (IsPositionDifferent(vPos, LastPos[client])) {
				RecordCongaFrame(client);
			}
			
			LastPos[client] = vPos;
		} else if (IsFollowing[client] != -1) {
			TeleportEntity(client, CongaFrames[client][0], NULL_VECTOR, NULL_VECTOR);
		}
	}
}

void RecordCongaFrame(int client) {
	float vPos[3];
	//GetClientAbsOrigin(client, vPos);
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", vPos);
	
	InsertPosition(client, vPos);
}

void InsertPosition(int client, float vPos[3]) {
	// Make room at the front of the array
	for (int i = (FRAMES - 1); i > 0; i--) {
		CongaFrames[client][i] = CongaFrames[client][(i - 1)];
	}
	
	CongaFrames[client][0] = vPos;
	
	// Find the next player in the line
	int nextClient = FindNextClientInConga(client);
	
	if (nextClient <= 0) {
		return;
	}
	
	InsertPosition(nextClient, CongaFrames[client][19]);
} 

int FindNextClientInConga(int client) {
	// Find position of current client in their conga
	
	int position = -1;
	int leader = client;
	
	if (IsLeader[client]) {
		position = 0;
	} else {
		leader = IsFollowing[client];
	
		if (leader == -1) {
			// Used incorrectly	
			return -1;
		}
		
		position = FindPositionInConga(leader, client);
		
		if (position == -1) {
			// Incorrect
			return -1;
		}
	}
	
	if (position == -1) {
		// Incorrect
		return -1;
	}
	
	if ((position + 1) >= (MAXPLAYERS + 1)) {
		return -1;
	}
	
	return CongaLines[leader][position + 1];
}

void CongaEnd(int client) {
	// Kick all the users out of the conga
	for (int i = 1; i < MAXPLAYERS + 1; i++) {
		int target = CongaLines[client][i];
		
		if (target > 0) {
			LeaveCurrentConga(target);
		}
	}
	
	// Then fully end the conga
	IsLeader[client] = false;
	CongaLines[client][0] = -1;
}

public int CongaPlayersMenuHandler(Menu menu, MenuAction action, int client, int index) {
	switch (action) {
		case MenuAction_Select: {
			// grab the number attached to the menu option
			char clientString[32];
			menu.GetItem(index, clientString, sizeof(clientString));
		
			int target = StringToInt(clientString);
			
			if (IsLeader[target]) {
				JoinLeader(target, client);
				
				return 0;
			}
			
			if (IsFollowing[target] != -1) {
				int leader = IsFollowing[target];
				JoinLeader(leader, client);
				
				return 0;
			}
		}
	}
	
	return 0;
}

public int CongaRequestPlayersMenuHandler(Menu menu, MenuAction action, int client, int index) {
	switch (action) {
		case MenuAction_Select: {
			// grab the number attached to the menu option
			char clientString[32];
			menu.GetItem(index, clientString, sizeof(clientString));
		
			int target = StringToInt(clientString);
			
			if (target != client && !IsLeader[target]) {
				StartConga(target);
				JoinLeader(target, client);
				return 0;
			}
		}
	}
	
	return 0;
}

public int CongaMenuHandler(Menu menu, MenuAction action, int client, int index) {
	switch (action) {
		case MenuAction_Select: {
			
			char info[32];
			menu.GetItem(index, info, sizeof(info));
			
			if (strcmp(info, "start_conga", false) == 0) {
				StartConga(client);
				return 0;
			}
			
			if (strcmp(info, "request_conga", false) == 0) {
				Menu playerMenu = new Menu(CongaRequestPlayersMenuHandler, MENU_ACTIONS_ALL);
					
				playerMenu.SetTitle("Request Conga");
				
				for (int i = 1; i < MAXPLAYERS + 1; i++) {
					bool isLeader = IsLeader[i];
					
					if (!isLeader && IsValidClient(i) && i != client) {
						
						char iString[32];
						IntToString(i, iString, sizeof(iString));
						
						char realName[64];
						GetClientName(i, realName, sizeof(realName));
						
						playerMenu.AddItem(iString, realName);
					}
				}
				
				playerMenu.Display(client, 30);
				
				return 0;
			}
			
			if (strcmp(info, "join_conga", false) == 0) {
				Menu playersMenu = new Menu(CongaPlayersMenuHandler, MENU_ACTIONS_ALL);
					
				playersMenu.SetTitle("Join Conga");
				
				for (int i = 1; i < MAXPLAYERS + 1; i++) {
					bool isLeader = IsLeader[i];
					
					if (isLeader) {
						char iString[32];
						IntToString(i, iString, sizeof(iString));
						
						char realName[64];
						GetClientName(i, realName, sizeof(realName));
						
						playersMenu.AddItem(iString, realName);
					}
				}
				
				playersMenu.Display(client, 30);
				
				return 0;
			}
			
			if (strcmp(info, "exit_conga", false) == 0) {
				ExitConga(client);
				return 0;
			}
		}
	}
	
	return 0;
}

void StartConga(int client) {

	if (IsLeader[client]) {
		return;
	}
	
	if (IsFollowing[client] != -1) {
		return;
	}
	
	// Start the conga
	// Broadcast that the user has started a conga
	IsLeader[client] = true;
	CongaLines[client][0] = client;
	
	// Get users' name
	char name[64];
	GetClientName(client, name, sizeof(name));
	
	// Broadcast that the user has started a conga
	PrintToChatAll("[Conga] %s has started a conga, type !conga to join", name);
	
	return;
}

void ExitConga(int client) {
	if (!IsLeader[client]) {
		LeaveCurrentConga(client);
		return;
	}
	
	// End the current conga
	CongaEnd(client);
}

void JoinConga() {
	// Lauch another menu with the list of players currently leading a conga, possibily with the amount in the conga
}

public Action Command_Conga(int client, int args) {
	
	if (!IsValidClient(client, true)) {
		PrintToChat(client, "[Conga] You can only use conga whilst alive");
		return Plugin_Handled;
	}
	
	Menu menu = new Menu(CongaMenuHandler, MENU_ACTIONS_ALL);
	
	menu.SetTitle("Conga Menu");
	
	bool condition = (!IsLeader[client] && IsFollowing[client] == -1);
	
	if (condition) {
		menu.AddItem("start_conga", "Start Conga");
	}

	bool hasLeader = false;
	
	for (int i = 1; i < MAXPLAYERS + 1; i++) {
		int isLeader = IsLeader[i];
		
		if (isLeader && i != client) {
			hasLeader = true;
			break;
		}
	}
	
	if (IsFollowing[client] == -1 && IsValidClient(client, true)) {
		menu.AddItem("request_conga", "Request Conga");
	}
	
	if (hasLeader && IsFollowing[client] == -1) {
		menu.AddItem("join_conga", "Join Conga");
	}
	
	if (!condition) {
		menu.AddItem("exit_conga", "Exit Conga");
	}
	
	menu.Display(client, 30);
	
	return Plugin_Handled;
}

int FindRealTarget(char[] name) {
	char buffer[64];
	for (int i = 0; i < MAXPLAYERS + 1; i++) {
		if (IsValidClient(i)) {
			GetClientName(i, buffer, sizeof(buffer));
			if (StrContains(buffer, name, false) != -1) {
				return i;
			}	
		}
	}
	return -1;
}

void JoinLeader(int leader, int client) {
	for (int i = 1; i < MAXPLAYERS + 1; i++) {
		// Move next position into this one
		if (CongaLines[leader][i] <= 0) {
			CongaLines[leader][i] = client;
			IsFollowing[client] = leader;
			SetEntityMoveType(client, MOVETYPE_NOCLIP);
			return;
		}
	}
}

void LeaveCurrentConga(int client) {
	/*
	if (IsFollowing[client] == -1) {
		return;
	}*/
	
	ForcePlayerSuicide(client);
	SetEntityMoveType(client, MOVETYPE_WALK);
	
	// Get leader
	int leader = IsFollowing[client];
	
	if (leader == -1) {
		// Used incorrectly	
		return;
	}
	
	int position = FindPositionInConga(leader, client);
	
	if (position == -1) {
		// Incorrect
		return;
	}
	
	// Move all other players forward
	RemovePlayerFromConga(leader, client, position);
}

int FindPositionInConga(int leader, int client) {
	for (int i = 0; i < MAXPLAYERS + 1; i++) {
		int target = CongaLines[leader][i];
		
		if (target == client) {
			return i;
		}
	}
	
	return -1;
}

void RemovePlayerFromConga(int leader, int client, int position) {
	// start at position
	for (int i = position; (i + 1) < MAXPLAYERS + 1; i++) {
		// Move next position into this one
		CongaLines[leader][i] = CongaLines[leader][i + 1];
	}
	
	IsFollowing[client] = -1;
}

bool IsPositionDifferent(const float vPos[3], const float vPos2[3]) {
	for (int i = 0; i < 3; i++) {
		if (FloatAbs(vPos[i] - vPos2[i]) > 0.1) {
			return true;
		}
	}
	
	return false;
}

bool IsValidClient(int client, bool bAlive = false) {
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (!bAlive || IsPlayerAlive(client)));
}