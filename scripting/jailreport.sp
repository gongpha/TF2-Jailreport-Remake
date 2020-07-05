#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <morecolors>

#pragma semicolon 1

#define PLUGIN_VERSION "1.1.1"
#define DEFAULT_TITLE "TF2 Jailreport System (Remake)\n"
#define DEFAULT_CHAT  "{orange}[TF2 Jailreport Remake] {lime}"

int clientChosen[MAXPLAYERS];
Menu currentVoteMenu = null;

ConVar cv[3];
bool OnDelay;
Handle DelayTimer = null;

public Plugin myinfo =
{
	name = "Jailreport (Remake)",
	author = "gongpha",
	description = "Choice for players. who cannot stand for the action of guards",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnChangeEnabled(ConVar convar, char[] oldValue, char[] newValue)
{
	if (!cv[1].BoolValue)
		if (currentVoteMenu)
			delete currentVoteMenu;
}

public void OnPluginStart()
{
	cv[0] = CreateConVar("jailreport_version", PLUGIN_VERSION, "Jailreport Version", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	cv[1] = CreateConVar("jailreport_enabled", "1", "Status of this plugin", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cv[2] = CreateConVar("jailreport_delay", "20.0", "Cooldown after vote is finished", FCVAR_NOTIFY, true, 0.0);

	cv[1].AddChangeHook(OnChangeEnabled);

	OnDelay = false;
	RegConsoleCmd("sm_jailreport", Command_OpenJailReportMenu, "Open JailReport Menu");
	RegAdminCmd("sm_jailreport_cancel", Command_CancelVoteMenu, ADMFLAG_GENERIC, "Cancel the current vote");
	RegAdminCmd("sm_jailreport_reset_delay", Command_ResetDelay, ADMFLAG_GENERIC, "Reset current delay");
}

public int MH_Vote(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_VoteCancel)
	{
		CPrintToChatAll("%sAll playered aren't vote.", DEFAULT_CHAT);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action DisableDelay(Handle timer)
{
	OnDelay = false;
	DelayTimer = null;
}

public void killClient(int target_client)
{
	if (!IsPlayerAlive(target_client))
		CPrintToChatAll("%sBut Target is not alive now !", DEFAULT_CHAT);
	else
		ForcePlayerSuicide(target_client);
}

public void MH_Result(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char r[4];
	int yes = 0;
	int no = 0;
	menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], r, sizeof(r));
	int tc = StringToInt(r);
	if (num_votes > 1 && item_info[0][VOTEINFO_ITEM_INDEX] == item_info[1][VOTEINFO_ITEM_INDEX])
	{
		yes = item_info[0][VOTEINFO_ITEM_INDEX];
		no = yes;
		CPrintToChatAll("%sVote Draw ! {yellow}(%d/%d){lime} : Randomize result", DEFAULT_CHAT, num_votes, num_clients);
		if (GetRandomInt(0,1))
		{
			CPrintToChatAll("%sWin !", DEFAULT_CHAT, num_votes, num_clients);
			killClient(clientChosen[tc]);
		}
		else
		{
			CPrintToChatAll("%sLose !", DEFAULT_CHAT, num_votes, num_clients);
		}
	}
	else if (item_info[0][VOTEINFO_ITEM_INDEX] == 0)
	{
		CPrintToChatAll("%sVote Success {cyan}(%d/%d){lime} :", DEFAULT_CHAT, num_votes, num_clients);
		killClient(clientChosen[tc]);
		yes = item_info[0][VOTEINFO_ITEM_VOTES];
		if (num_items > 1) {
			no = item_info[1][VOTEINFO_ITEM_VOTES];
		}
	}
	else
	{
		CPrintToChatAll("%sVote Failed {magenta}(%d/%d){lime} :", DEFAULT_CHAT, num_votes, num_clients);
		no = item_info[0][VOTEINFO_ITEM_VOTES];
		if (num_items > 1) {
			yes = item_info[1][VOTEINFO_ITEM_VOTES];
		}
	}
	CPrintToChatAll("%sNo Vote[{gray}%d{lime}]   Yes[{darkgreen}%d{lime}] No[{darkred}%d{lime}]", DEFAULT_CHAT, num_clients - num_votes, yes, no);
	OnDelay = true;
	DelayTimer = CreateTimer(cv[2].FloatValue, DisableDelay);
	currentVoteMenu = null;
}

public int MH_Reason(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char reason_name[128];
		char player_name[64];
		char author_name[64];
		char title[128];
		menu.GetItem(param2, reason_name, sizeof(reason_name));
		GetClientName(clientChosen[param1], player_name, sizeof(player_name));
		GetClientName(param1, author_name, sizeof(author_name));
		//ServerCommand("sm_slay #%s", player_name);

		CPrintToChatAll("%s{red}%s{lime} started vote to slay {red}%s{lime} for {red}%s", DEFAULT_CHAT, author_name, player_name, reason_name);

		currentVoteMenu = new Menu(MH_Vote);
		Format(title, sizeof(title), "%s\n\n\"%s\" got voted for reason \"%s\"\nIf success, He will get slayed\n", DEFAULT_TITLE, player_name, reason_name);
		currentVoteMenu.SetTitle(title);
		currentVoteMenu.ExitButton = false;
		currentVoteMenu.NoVoteButton = true;
		char c[4];
		IntToString(param1, c, sizeof(c));
		currentVoteMenu.AddItem(c, "Yes");
		currentVoteMenu.AddItem(c, "No");
		currentVoteMenu.VoteResultCallback = MH_Result;
		currentVoteMenu.DisplayVoteToAll(20);
	}
	else if(action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			openPlayerMenu(param1);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int MH_Player(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char cl[4];
		char title[128];
		char targetname[64];
		menu.GetItem(param2, cl, sizeof(cl));
		Menu new_menu = new Menu(MH_Reason);
		int target = StringToInt(cl, 10);
		clientChosen[param1] = target;
		if (!IsPlayerAlive(target))
		{
			CPrintToChat(param1, "%sTarget is not alive !", DEFAULT_CHAT);
			delete menu;
		}
		if(IsClientInGame(target) && !IsFakeClient(target))
		{
			GetClientName(target, targetname, sizeof(targetname));
			Format(title, sizeof(title), "%s\n\nTarget Player : %s", DEFAULT_TITLE, targetname);
			new_menu.SetTitle(title);

			char file[PLATFORM_MAX_PATH];
			BuildPath(Path_SM, file, sizeof(file), "configs/jailreport.cfg");
			KeyValues kv = new KeyValues("Reason");
			kv.ImportFromFile(file);

			if (!kv.GotoFirstSubKey(false)) {
				delete kv;
		   		return;
			}
			// REASONS
			do
			{
				char rName[64];
				kv.GetString("name", rName, sizeof(rName));
				new_menu.AddItem(rName, rName);
			} while (kv.GotoNextKey());
			delete kv;
			new_menu.ExitBackButton = true;
			new_menu.ExitButton = true;
			new_menu.Display(param1, 60);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void openPlayerMenu(int client)
{
	Menu menu = new Menu(MH_Player);
	char title[128];
	Format(title, sizeof(title), "%s\n\nChoose Player on BLU :", DEFAULT_TITLE);
	menu.SetTitle(title);

	// PLAYERS
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i))
		{
			if (GetClientTeam(i) == _:TFTeam_Blue)
			{
				char cl[4];
				char name[64];
				IntToString(i, cl, sizeof(cl));
				GetClientName(i, name, sizeof(name));
				menu.AddItem(cl, name);
			}
		}
	}

	menu.ExitButton = true;
	menu.Display(client, 60);
}

public Action Command_OpenJailReportMenu(int client, int args)
{
	if (!cv[1].BoolValue)
		return Plugin_Handled;

	if (IsVoteInProgress())
	{
		CPrintToChat(client, "%sVote is in progress !", DEFAULT_CHAT);
		return Plugin_Handled;
	}

	if (OnDelay)
	{
		CPrintToChat(client, "%sThe vote is currently finished. Try again later", DEFAULT_CHAT);
		return Plugin_Handled;
	}
	openPlayerMenu(client);

	return Plugin_Handled;
}

public Action Command_CancelVoteMenu(int client, int args)
{
	if (cv[1].BoolValue && currentVoteMenu)
		delete currentVoteMenu;
	return Plugin_Handled;
}

public Action Command_ResetDelay(int client, int args)
{
	if (DelayTimer)
		KillTimer(DelayTimer);
	OnDelay = false;
	return Plugin_Handled;
}
