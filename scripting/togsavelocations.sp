/*
	
*/

#pragma semicolon 1
#define PLUGIN_VERSION "1.1.0"

#include <sourcemod>
#include <autoexecconfig>	//https://github.com/Impact123/AutoExecConfig or http://www.togcoding.com/showthread.php?p=1862459
#include <sdkhooks>
#include <sdktools>
#include <adminmenu>

new	Handle:g_hSetNewFlag = INVALID_HANDLE;
new String:g_sSetNewFlag[30];
new	Handle:g_hTPFlag = INVALID_HANDLE;
new String:g_sTPFlag[30];
new	Handle:g_hShowGlows = INVALID_HANDLE;
new bool:g_bShowGlows;

new Handle:g_hLocCoords = INVALID_HANDLE;
new Handle:g_hLocNames = INVALID_HANDLE;

new String:g_sFile[PLATFORM_MAX_PATH];
new Handle:g_hAdminMenu;

new g_iBlueGlow;
new g_iGlowValidation = 0;

public Plugin:myinfo =
{
	name = "TOG Save Locations",
	author = "That One Guy",
	description = "Setup/save custom teleport locations for each map. Configurable access flags both for setting and using TPs.",
	version = PLUGIN_VERSION,
	url = "http://www.togcoding.com"
}

public OnPluginStart()
{
	AutoExecConfig_SetFile("togsavelocations");
	AutoExecConfig_CreateConVar("tsl_version", PLUGIN_VERSION, "TOG Save Locations: Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	g_hSetNewFlag = AutoExecConfig_CreateConVar("tsl_flag_setnew", "z", "Players with this flag will be able to create new teleport locations.");
	HookConVarChange(g_hSetNewFlag, OnCVarChange);
	GetConVarString(g_hSetNewFlag, g_sSetNewFlag, sizeof(g_sSetNewFlag));
	
	g_hTPFlag = AutoExecConfig_CreateConVar("tsl_flag_tp", "i", "Players with this flag will be able to use the saved teleports.");
	HookConVarChange(g_hTPFlag, OnCVarChange);
	GetConVarString(g_hTPFlag, g_sTPFlag, sizeof(g_sTPFlag));
	
	g_hShowGlows = AutoExecConfig_CreateConVar("tsl_showglows", "1", "Show glowing orbs at teleport locations? (0 = Disabled, 1 = Enabled).", FCVAR_NONE, true, 0.0, true, 1.0);
	HookConVarChange(g_hShowGlows, OnCVarChange);
	g_bShowGlows = GetConVarBool(g_hShowGlows);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	RegConsoleCmd("sm_locs", Command_Locations);
	RegConsoleCmd("sm_locations", Command_Locations);
	RegConsoleCmd("sm_saves", Command_Locations);
	
	RegConsoleCmd("sm_newsave", Command_NewLoc);
	RegConsoleCmd("sm_createsave", Command_NewLoc);
	RegConsoleCmd("sm_saveloc", Command_NewLoc);
	
	RegConsoleCmd("sm_reloadlocs", Command_ReloadLocs);
	
	RegConsoleCmd("sm_getcoords", Command_Coords);
	RegConsoleCmd("sm_coords", Command_Coords);
	
	g_hLocCoords = CreateArray(4);
	g_hLocNames = CreateArray(32);
	
	LoadMapCfg();
	
	new Handle:hTopmenu;
	if(LibraryExists("adminmenu") && ((hTopmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(hTopmenu);
	}
}

public OnCVarChange(Handle:hCVar, const String:sOldValue[], const String:sNewValue[])
{
	if(hCVar == g_hSetNewFlag)
	{
		GetConVarString(g_hSetNewFlag, g_sSetNewFlag, sizeof(g_sSetNewFlag));
	}
	else if(hCVar == g_hTPFlag)
	{
		GetConVarString(g_hTPFlag, g_sTPFlag, sizeof(g_sTPFlag));
	}
	else if(hCVar == g_hShowGlows)
	{
		g_bShowGlows = GetConVarBool(g_hShowGlows);
		SetGlows();
	}
}

public OnMapStart()
{
	g_iBlueGlow = PrecacheModel("sprites/purpleglow1.vmt");
	
	LoadMapCfg();
	
	SetGlows();
}

SetGlows()
{
	g_iGlowValidation++;
	
	if(g_bShowGlows)
	{
		CreateTimer(3.0, TimerCB_ShowGlows, g_iGlowValidation, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
}

public Action:TimerCB_ShowGlows(Handle:hTimer, any:iValidation)
{
	if(iValidation == g_iGlowValidation)
	{
		if(GetArraySize(g_hLocCoords))
		{
			for(new i = 0; i < GetArraySize(g_hLocCoords); i++)
			{
				new Float:a_fCoords[3];
				GetArrayArray(g_hLocCoords, i, a_fCoords);
				
				TE_SetupGlowSprite(a_fCoords, g_iBlueGlow, 3.0, 0.3, 237);
				TE_SendToAll();
			}
		}
		return Plugin_Continue;
	}
	
	return Plugin_Stop;
}

LoadMapCfg()
{
	ClearArray(g_hLocCoords);
	ClearArray(g_hLocNames);
	
	GetCurrentMap(g_sFile, sizeof(g_sFile));
	BuildPath(Path_SM, g_sFile, sizeof(g_sFile), "configs/togsavelocations/%s.cfg", g_sFile);
	if(!DirExists(g_sFile))
	{
		CreateDirectory(g_sFile, 777);
	}
	
	if(!FileExists(g_sFile))
	{
		LogMessage("No TP save location file found for map: %s", g_sFile);
		return;
	}
	
	new Handle:hFile = OpenFile(g_sFile, "r");
	decl String:sBuffer[134];
	if(hFile != INVALID_HANDLE)
	{
		while(ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
		{
			TrimString(sBuffer);
			if((StrContains(sBuffer, "//") == -1) && (!StrEqual(sBuffer, "")))		//filter out comments and blank lines
			{
				decl String:sTempArray[4][32];
				new Float:a_fCoords[3];
				ExplodeString(sBuffer, ";;", sTempArray, sizeof(sTempArray), sizeof(sTempArray[]));
				
				PushArrayString(g_hLocNames, sTempArray[0]);
				a_fCoords[0] = StringToFloat(sTempArray[1]);
				a_fCoords[1] = StringToFloat(sTempArray[2]);
				a_fCoords[2] = StringToFloat(sTempArray[3]);
				PushArrayArray(g_hLocCoords, a_fCoords);
			}
		}
	}
	
	CloseHandle(hFile);
}

public Action:Command_Locations(client, iArgs)
{
	if(!IsValidClient(client))
	{
		ReplyToCommand(client, "You must be in game to use this command!");
		return Plugin_Handled;
	}
	
	if(!HasFlags(client, g_sTPFlag))
	{
		ReplyToCommand(client, "You do not have access to this command!");
		return Plugin_Handled;
	}
	
	ListLocs(client, "tsl_listlocs", "Teleport to Location");
	return Plugin_Handled;
}

public Action:Command_ReloadLocs(client, iArgs)
{
	if(IsValidClient(client))
	{	
		if(!HasFlags(client, g_sSetNewFlag))
		{
			ReplyToCommand(client, "You do not have access to this command!");
			return Plugin_Handled;
		}
	}
	
	LoadMapCfg();
	
	ReplyToCommand(client, "Save locations are now being reloaded! Please allow a second to load coordinates from file.");
	
	return Plugin_Handled;
}

public Action:Command_Coords(client, iArgs)
{
	if(!IsValidClient(client))
	{
		ReplyToCommand(client, "You must be in game to use this command!");
		return Plugin_Handled;
	}
	
	new Float:a_fCoords[3];	
	GetClientAbsOrigin(client, a_fCoords);
	
	PrintToChat(client, "Your current X,Y,Z coordinates are:");
	PrintToChat(client, "%6.2f;;%6.2f;;%6.2f", a_fCoords[0], a_fCoords[1], a_fCoords[2]);
	
	return Plugin_Handled;
}

public Action:Command_NewLoc(client, iArgs)
{
	if(!IsValidClient(client))
	{
		ReplyToCommand(client, "You must be in game to use this command!");
		return Plugin_Handled;
	}
	
	if(!HasFlags(client, g_sSetNewFlag))
	{
		ReplyToCommand(client, "You do not have access to this command!");
		return Plugin_Handled;
	}
	
	if(!iArgs)
	{
		ReplyToCommand(client, "You must include a name for the location being saved (32 char. max)!");
		return Plugin_Handled;
	}
	
	decl String:sLocName[32];
	GetCmdArgString(sLocName, sizeof(sLocName));
	TrimString(sLocName);

	new bool:bExists = false;
	for(new i = 0; i < GetArraySize(g_hLocNames); i++)
	{
		decl String:sName[75];
		GetArrayString(g_hLocNames, i, sName, sizeof(sName));
		if(StrEqual(sName, sLocName, false))
		{
			bExists = true;
			break;
		}
	}
	
	if(bExists)
	{
		ReplyToCommand(client, "The specified name is already in use! Name: %s", sLocName);
		return Plugin_Handled;
	}
	
	CreateNewLoc(client, sLocName);
	
	return Plugin_Handled;
}

public OnAdminMenuReady(Handle:hTopMenu)
{
	/* Block us from being called twice */
	if(hTopMenu == g_hAdminMenu)
	{
		return;
	}
	
	/* Save the Handle */
	g_hAdminMenu = hTopMenu;
	
	new TopMenuObject:MenuObject = AddToTopMenu(g_hAdminMenu, "TOG_Save_Locs", TopMenuObject_Category, MenuHandler_AdminMenu, INVALID_TOPMENUOBJECT);
	if(MenuObject == INVALID_TOPMENUOBJECT)
	{
		return;
	}
	//Adminmenu_Player1
	AddToTopMenu(g_hAdminMenu, "tsl_listlocs", TopMenuObject_Item, Adminmenu_ListLocs, MenuObject, "tsl_listlocs", ADMFLAG_GENERIC, "Teleport to Location");
	AddToTopMenu(g_hAdminMenu, "tsl_deleteloc", TopMenuObject_Item, Adminmenu_ListLocs, MenuObject, "tsl_deleteloc", ADMFLAG_GENERIC, "Delete Existing Location");
	AddToTopMenu(g_hAdminMenu, "tsl_createloc", TopMenuObject_Item, Adminmenu_Instructions, MenuObject, "tsl_createloc", ADMFLAG_GENERIC, "Save New Location");
}

public MenuHandler_AdminMenu(Handle:menu, TopMenuAction:action, TopMenuObject:object_id, param1, String:sBuffer[], iMaxLength)
{
	switch(action)
	{
		case TopMenuAction_DisplayOption:
		{
			Format(sBuffer, iMaxLength, "Save Locations");
		}
		case TopMenuAction_DisplayTitle:
		{
			Format(sBuffer, iMaxLength, "Save Locations");
		}
	}
}

public Adminmenu_ListLocs(Handle:hTopMenu, TopMenuAction:action, TopMenuObject:object_id, client, String:sBuffer[], iMaxLength)
{
	decl String:sCommand[MAX_NAME_LENGTH], String:sTitle[128];
	GetTopMenuObjName(hTopMenu, object_id, sCommand, sizeof(sCommand));
	GetTopMenuInfoString(hTopMenu, object_id, sTitle, sizeof(sTitle));
	
	switch(action)
	{
		case(TopMenuAction_DisplayOption):
		{
			Format(sBuffer, iMaxLength, sTitle);
		}
		case(TopMenuAction_SelectOption):
		{
			if(StrEqual(sCommand, "tsl_listlocs", false))
			{
				if(HasFlags(client, g_sTPFlag))
				{
					ListLocs(client, sCommand, sTitle);
				}
				else
				{
					PrintToChat(client, "You do not have access to this command!");
				}
			}
			else if(StrEqual(sCommand, "tsl_deleteloc", false))
			{
				if(HasFlags(client, g_sSetNewFlag))
				{
					ListLocs(client, sCommand, sTitle);
				}
				else
				{
					PrintToChat(client, "You do not have access to this command!");
				}
			}
		}
	}
}

public Adminmenu_Instructions(Handle:hMenu,  TopMenuAction:action, TopMenuObject:object_id, client, String:sBuffer[], iMaxLen)		//command via admin menu
{
	if(action == TopMenuAction_DisplayOption)
	{
		Format(sBuffer, iMaxLen, "Save New Location");
	}
	else if(action == TopMenuAction_SelectOption)
	{
		PrintToChat(client, " \x01To save a new teleport location, type \x07!saveloc, \x01or \x07!newsave \x01in chat, followed by the name. e.g. \x09!newsave Some New Location");
	}
}

public ListLocs(client, String:sCommand[], String:sTitle[])
{
	new Handle:hMenu = CreateMenu(MenuHandler_ListLocs);
	SetMenuTitle(hMenu, sTitle);
	SetMenuExitButton(hMenu, true);
	
	if(GetArraySize(g_hLocCoords))
	{
		for(new i = 0; i < GetArraySize(g_hLocNames); i++)
		{
			decl String:sName[32], String:sInfoString[134];
			Format(sInfoString, sizeof(sInfoString), "%s;;%i", sCommand, i);
			GetArrayString(g_hLocNames, i, sName, sizeof(sName));
			AddMenuItem(hMenu, sInfoString, sName);
		}
	}
	else
	{
		AddMenuItem(hMenu, "", "No Locations Saved!", ITEMDRAW_DISABLED);
	}
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_ListLocs(Handle:hMenu, MenuAction:Selection, client, param2)
{
	switch(Selection)
	{
		case(MenuAction_End):
		{
			CloseHandle(hMenu);
		}
		case(MenuAction_Cancel):
		{
			//DisplayTopMenu(g_hAdminMenu, client, TopMenuPosition_LastCategory);	//invalid handle if done through !adminroom cmd
		}
		case(MenuAction_Select):
		{
			new String:sInfo[64];
			GetMenuItem(hMenu, param2, sInfo, sizeof(sInfo));
			decl String:sTempArray[2][32];
			ExplodeString(sInfo, ";;", sTempArray, sizeof(sTempArray), sizeof(sTempArray[]));

			if(StrEqual(sTempArray[0], "tsl_listlocs", false))
			{
				TPToLoc(client, StringToInt(sTempArray[1]));
			}
			else if(StrEqual(sTempArray[0], "tsl_deleteloc", false))
			{
				DeleteLoc(client, StringToInt(sTempArray[1]));
			}
		}
	}
}

TPToLoc(client, iIndex)
{
	if(IsValidClient(client))
	{
		if(IsPlayerAlive(client))
		{
			new Float:a_fCoords[3];
			GetArrayArray(g_hLocCoords, iIndex, a_fCoords);
			a_fCoords[2] = a_fCoords[2] + 16;	//move up slightly so that they dont get stuck in floor.
			decl String:sLocName[32];
			GetArrayString(g_hLocNames, iIndex, sLocName, sizeof(sLocName));
			
			TeleportEntity(client, a_fCoords, NULL_VECTOR, NULL_VECTOR);
			PrintToChatAll(" \x07Admin \x09%N \x07has teleported to save location: \x09%s", client, sLocName);
		}
		else
		{
			PrintToChat(client, "You must be alive to teleport!");
		}
	}
}

DeleteLoc(client, iIndex)
{
	decl String:sLocName[32];
	GetArrayString(g_hLocNames, iIndex, sLocName, sizeof(sLocName));
	Format(sLocName, sizeof(sLocName), "%s;", sLocName);
	
	RemoveFileLine_Contains(g_sFile, sLocName);
	RemoveFromArray(g_hLocNames, iIndex);
	RemoveFromArray(g_hLocCoords, iIndex);
	
	if(IsValidClient(client))
	{
		LogMessage("Save location '%s' deleted by admin %L.", sLocName, client);
	}
	else
	{
		LogMessage("Save location '%s' deleted by CONSOLE.", sLocName);
	}
}

CreateNewLoc(client, String:sLocName[])
{
	new Float:a_fCoords[3];	
	GetClientAbsOrigin(client, a_fCoords);
	decl String:sInfoString[134];
	
	Format(sInfoString, sizeof(sInfoString), "%s;;%f;;%f;;%f", sLocName, a_fCoords[0], a_fCoords[1], a_fCoords[2]);
	
	if(!FileExists(g_sFile))
	{
		LogMessage("Creating new file for save locations: %s", g_sFile);
	}
	
	//WriteLineToFile(g_sFile, "TEMP");
	//RemoveFileLine_Equal(g_sFile, "TEMP");
	
	WriteLineToFile(g_sFile, sInfoString);
	PushArrayArray(g_hLocCoords, a_fCoords);
	PushArrayString(g_hLocNames, sLocName);
	
	PrintToChat(client, "Save location '%s' created at X,Y,Z coordinates: %6.2f,%6.2f,%6.2f", sLocName, a_fCoords[0], a_fCoords[1], a_fCoords[2]);
}

WriteLineToFile(String:sPath[], String:sText[])
{
	decl String:sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, PLATFORM_MAX_PATH, "%s", sPath);
	
	new Handle:hFile = OpenFile(sFile, "a");
	
	if(hFile != INVALID_HANDLE)
	{
		WriteFileLine(hFile, sText);
		CloseHandle(hFile);
		hFile = INVALID_HANDLE;
	}
}

RemoveFileLine_Contains(String:sPath[], String:sText[])
{
	decl String:sFile[PLATFORM_MAX_PATH], String:sFileTemp[PLATFORM_MAX_PATH], String:sBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "%s", sPath);
	BuildPath(Path_SM, sFileTemp, sizeof(sFileTemp), "%s.temp", sPath);
	new Handle:hFile = OpenFile(sFile, "r+");
	new Handle:hFileTemp = OpenFile(sFileTemp, "w");
	
	if(hFile != INVALID_HANDLE)
	{
		while(ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
		{
			TrimString(sBuffer);		//remove spaces and tabs at both ends of string
			if((StrContains(sBuffer, "//") == -1) && (!StrEqual(sBuffer, "")))		//filter out comments and blank lines
			{
				if(StrContains(sBuffer, sText, false) == -1)
				{
					WriteFileLine(hFileTemp, sBuffer);
				}
			}
			else
			{
				WriteFileLine(hFileTemp, sBuffer);
			}
		}
	}
	if(hFile != INVALID_HANDLE)
	{
		CloseHandle(hFile);
		hFile = INVALID_HANDLE;
	}
	if(hFileTemp != INVALID_HANDLE)
	{
		CloseHandle(hFileTemp);
		hFileTemp = INVALID_HANDLE;
	}
	
	DeleteFile(sFile);
	RenameFile(sFile, sFileTemp);
}

stock RemoveFileLine_Equal(String:sPath[], String:sText[])
{
	decl String:sFile[PLATFORM_MAX_PATH], String:sFileTemp[PLATFORM_MAX_PATH], String:sBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "%s", sPath);
	BuildPath(Path_SM, sFileTemp, sizeof(sFileTemp), "%s.temp", sPath);
	new Handle:hFile = OpenFile(sFile, "r+");
	new Handle:hFileTemp = OpenFile(sFileTemp, "w");
	
	if(hFile != INVALID_HANDLE)
	{
		while(ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
		{
			TrimString(sBuffer);		//remove spaces and tabs at both ends of string
			if((StrContains(sBuffer, "//") == -1) && (!StrEqual(sBuffer, "")))		//filter out comments and blank lines
			{
				if(!StrEqual(sBuffer, sText))
				{
					WriteFileLine(hFileTemp, sBuffer);
				}
			}
			else
			{
				WriteFileLine(hFileTemp, sBuffer);
			}
		}
	}
	if(hFile != INVALID_HANDLE)
	{
		CloseHandle(hFile);
	}
	if(hFileTemp != INVALID_HANDLE)
	{
		CloseHandle(hFileTemp);
	}
	DeleteFile(sFile);
	RenameFile(sFile, sFileTemp);
}

bool:IsValidClient(client, bool:bAllowBots = false)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bAllowBots) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}
	return true;
}

bool:HasFlags(client, String:sFlags[])
{
	if(StrEqual(sFlags, "public", false) || StrEqual(sFlags, "", false))
	{
		return true;
	}
	
	if(StrEqual(sFlags, "none", false))
	{
		return false;
	}
	
	new AdminId:id = GetUserAdmin(client);
	if(id == INVALID_ADMIN_ID)
	{
		return false;
	}
	
	if(CheckCommandAccess(client, "sm_not_a_command", ADMFLAG_ROOT, true))
	{
		return true;
	}
	new iCount, iFound, flags;
	if(StrContains(sFlags, ";", false) != -1) //check if multiple strings
	{
		new c = 0, iStrCount = 0;
		while(sFlags[c] != '\0')
		{
			if(sFlags[c++] == ';')
			{
				iStrCount++;
			}
		}
		iStrCount++; //add one more for IP after last comma
		decl String:sTempArray[iStrCount][30];
		ExplodeString(sFlags, ";", sTempArray, iStrCount, 30);
		
		for(new i = 0; i < iStrCount; i++)
		{
			flags = ReadFlagString(sTempArray[i]);
			iCount = 0;
			iFound = 0;
			for(new j = 0; j <= 20; j++)
			{
				if(flags & (1<<j))
				{
					iCount++;

					if(GetAdminFlag(id, AdminFlag:j))
					{
						iFound++;
					}
				}
			}
			
			if(iCount == iFound)
			{
				return true;
			}
		}
	}
	else
	{
		flags = ReadFlagString(sFlags);
		iCount = 0;
		iFound = 0;
		for(new i = 0; i <= 20; i++)
		{
			if(flags & (1<<i))
			{
				iCount++;

				if(GetAdminFlag(id, AdminFlag:i))
				{
					iFound++;
				}
			}
		}

		if(iCount == iFound)
		{
			return true;
		}
	}
	return false;
}

stock Log(String:sPath[], const String:sMsg[], any:...)	//TOG logging function - path is relative to logs folder.
{
	new String:sLogFilePath[PLATFORM_MAX_PATH], String:sFormattedMsg[256];
	BuildPath(Path_SM, sLogFilePath, sizeof(sLogFilePath), "logs/%s", sPath);
	VFormat(sFormattedMsg, sizeof(sFormattedMsg), sMsg, 3);
	LogToFileEx(sLogFilePath, "%s", sFormattedMsg);
}

/*
CHANGELOG:
	1.0:
		* Plugin created.
	1.1.0:
		* Changed to purple glow.
		* Changed plugin name from 'TOG Admin Rooms' to 'TOG Save Locations', and updated text responses accordingly.
		* Timmed coordinates output to chat.
		* Changed some of the cvar descriptions.
		* Fixed two cvars having the same name.
		* Added auto-creation of configs folder if not existing.
		
*/