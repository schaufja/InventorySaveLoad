/*
* SaveLoad
* 
* Created by The Seventh
*
* 
*/

#include "../../ChatCommandManager"
#include "Jsona/Jsona"

ChatCommandSystem::ChatCommandManager@ g_ChatCommands = null;

namespace SaveLoad 
{
	bool DEBUG_MODE = true; //enable console logs
	bool DEBUG_VERBOSE = true; //enable extra console logs

	const string g_sFileName = "scripts/maps/store/saves.txt";
	
	//Template Json for proper tags
	//const string SAVE_FILE_TEMPLATE = "{\"saves\":[" + SAVE_DATA_TEMPLATE + "]}";
	const string SAVE_DATA_TEMPLATE = "{\"saveName\":\"\",\"mapName\":\"\",\"characterData\":[{}],\"globalStates\":[{}]}";
	const string CHARACTER_DATA_TEMPLATE = "{\"netName\":\"\",\"inventory\":[{}]}";
	const string ITEM_DATA_TEMPLATE = "{\"item_inventory\":\"\"}";

	void Init()
	{
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("Inside SaveLoad::Init\n");
		
		g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSay );
	
		@g_ChatCommands = ChatCommandSystem::ChatCommandManager();
		
		g_ChatCommands.AddCommand( ChatCommandSystem::ChatCommand( "!save", @Save, false, 1 ) );
		g_ChatCommands.AddCommand( ChatCommandSystem::ChatCommand( "!load", @Load, false, 1 ) );
		//g_ChatCommands.AddCommand( ChatCommandSystem::ChatCommand( "!listsaves", @ListSaves, false ) );
	}
	
	//Hook for commands
	HookReturnCode ClientSay( SayParameters@ pParams )
	{		
		if( g_ChatCommands.ExecuteCommand( pParams ) )
			return HOOK_HANDLED;

		return HOOK_CONTINUE;
	}
	
	//Main save command
	//creates or updates a save with the name specified
	void Save( SayParameters@ pParams )
	{
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("Inside SaveLoad::Save\n");
		
		//init save file
		array<Jsona::Value@>@ jvSaveFile = array<Jsona::Value@>();
		
		pParams.ShouldHide = true;
		const CCommand@ pArguments = pParams.GetArguments();
		
		//input save name parameter
		string sSaveName = pArguments[1];
		
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("Save name:" + sSaveName + "\n");
		
		//load save file
		string sSaveFile = GetFileString( g_sFileName );
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("Loaded save file with contents:" + sSaveFile + "\n");
		
		//check if save file string is empty, if it is, make a new one from template
		if ( sSaveFile == "" )
		{
			if (DEBUG_MODE)
				g_EngineFuncs.ServerPrint( "Save file empty, creating new file from template.\n" );
			//create a new save file from template
			jvSaveFile.insertLast( NewSaveFromTemplate( sSaveName ) );
		}
		else
		{
			if (DEBUG_MODE)
				g_EngineFuncs.ServerPrint( "Save file populated. Parsing...\n" );
			
			jvSaveFile = array<Jsona::Value@>(Jsona::parse( sSaveFile ));
		}
		//Update save file from input file string
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("jvSaveFile after empty check:" + SafeJsonaStringify(jvSaveFile) + "\n");
		
		jvSaveFile = UpdateExistingSaveFile( jvSaveFile, sSaveName );
		
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("jvSaveFile after update: " + SafeJsonaStringify(jvSaveFile) + "\n");
		WriteSaveToFile(jvSaveFile);
	}
	
	//Main load command
	//Loads player inventories based on a save name
	void Load( SayParameters@ pParams )
	{
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("Inside SaveLoad::Load\n");
		
		//init save file
		array<Jsona::Value@>@ jvSaveFile = array<Jsona::Value@>();
		
		int iSaveIndexToLoad = -1;
		
		pParams.ShouldHide = true;
		const CCommand@ pArguments = pParams.GetArguments();
		
		//input save name parameter
		string sSaveName = pArguments[1];
		
		//load save file
		string sSaveFile = GetFileString( g_sFileName );
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("Loaded save file with contents:" + sSaveFile + "\n");
			
		jvSaveFile = array<Jsona::Value@>(Jsona::parse( sSaveFile ));
		
		g_EngineFuncs.ServerPrint("Loaded save file:" + SafeJsonaStringify(jvSaveFile) + "\n");
		
		//Get index of save to load
		iSaveIndexToLoad = GetSaveIndex( jvSaveFile, sSaveName );
		
		if ( iSaveIndexToLoad == -1 )
		{
			if (DEBUG_MODE)
				g_EngineFuncs.ServerPrint("Save file of name :" + sSaveName + " not found!\n");
			return;
		}

		if (DEBUG_MODE)
				g_EngineFuncs.ServerPrint("Save file found :" + SafeJsonaStringify(jvSaveFile[iSaveIndexToLoad]["characterData"]) + "\n");
		//Load character data
		EquipCharactersFromSave( jvSaveFile[iSaveIndexToLoad]["characterData"] );
		
		//Load globalStates
	}
	
	void EquipCharactersFromSave ( Jsona::Value@ ajvInCharacterData )
	{
		if ( ajvInCharacterData is null )
			return;
			
		for ( int i = 0; i < ajvInCharacterData.length(); i++ )
		{
			if (DEBUG_MODE)
				g_EngineFuncs.ServerPrint("Found character: [" + i + "]" + SafeJsonaStringify( ajvInCharacterData[i]["netName"] ) + " attempting to equip player with that name...\n");
			EquipCharacter( SafeJsonaStringify( ajvInCharacterData[i]["netName"] ), ajvInCharacterData[i]["inventory"] );
		}
	}
	
	void EquipCharacter( string sInNetName, Jsona::Value jvInInventory )
	{
		sInNetName = TrimQuotationMarks( sInNetName );
	
		if ((sInNetName == ""))
		{
			if (DEBUG_MODE)
				g_EngineFuncs.ServerPrint("Netname empty in EquipCharacter\n");
			return;
		}
		
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByName(sInNetName);
		if ( pPlayer is null )
		{
			if (DEBUG_MODE)
				g_EngineFuncs.ServerPrint("Player by name " + sInNetName + " not found. Skipping...\n");
			return;
		}
		
		if (DEBUG_MODE)
				g_EngineFuncs.ServerPrint("Player found with name " + sInNetName + ". Giving inventory: " + SafeJsonaStringify(jvInInventory) + " from file\n");
				
		//iterate through inventory and spawn on player
		for ( int i = 0; i < jvInInventory.length(); i++ )
		{
			string sItemName = string(jvInInventory[i]);
			SpawnItemOnPlayer( pPlayer, sItemName );
		}
	}
	
	void SpawnItemOnPlayer ( CBasePlayer@ pPlayer, string sInputItemName )
	{
		dictionary keyvalues =
		{
			{ "model", "models/hlclassic/w_battery.mdl" },
			{ "holder_keep_on_respawn", "1" },
			{ "holder_keep_on_death", "1" },
			{ "holder_can_drop", "1" }
		};
		
		//create base entity
		CBaseEntity@ pEntity = g_EntityFuncs.CreateEntity( "item_inventory", keyvalues, false );
		
		//cast as item inventory to access item name
		CItemInventory@ pInventoryItem = cast<CItemInventory@>( pEntity );
		
		//assign item name and origin
		pInventoryItem.m_szItemName = sInputItemName;
		pEntity.pev.origin = pPlayer.pev.origin;
		g_EntityFuncs.DispatchSpawn( pInventoryItem.edict() );
	}
	
	string TrimQuotationMarks( string sInString )
	{
		sInString.Trim("\"");
		return sInString;
	}
	
	//returns a new jsona value object from the Save file template with the save name specified
	Jsona::Value@ NewSaveFromTemplate( string sSaveName )
	{
		Jsona::Value@ jvSaveFile = Jsona::parse(SAVE_DATA_TEMPLATE);
		
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("Save template loaded as:" + SafeJsonaStringify(jvSaveFile) + "\n");
		
		//null check after the parse
		if ( jvSaveFile is null)
		{
			g_EngineFuncs.ServerPrint("Could not parse templates\n");
			return Jsona::Value();
		}

		//populate save name
		jvSaveFile["saveName"] = Jsona::Value(sSaveName);
		
		//populate map name
		jvSaveFile["mapName"] = Jsona::Value(string(g_Engine.mapname));
		
		//populate character data
		jvSaveFile["characterData"].set(GetCharacterData());

		return jvSaveFile;
	}
	
	//takes save string input and save name to update and returns updated save file
	array<Jsona::Value@> UpdateExistingSaveFile( array<Jsona::Value@>@ ajvInSave, string sSaveNameToUpdate )
	{
		array<Jsona::Value@>@ jvOutSaveFile = ajvInSave;
		int iSaveIndexToUpdate = -1;
		
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("Save parsed and loaded as:" + SafeJsonaStringify(jvOutSaveFile) + "\n");
		
		//null check after the parse
		if ( jvOutSaveFile is null)
		{
			g_EngineFuncs.ServerPrint("Could not parse save file\n");
			return array<Jsona::Value@>();
		}
		
		//get index of save to update
		iSaveIndexToUpdate = GetSaveIndex( jvOutSaveFile, sSaveNameToUpdate );
		
		if (DEBUG_MODE)
			g_EngineFuncs.ServerPrint("Index found to update: " + iSaveIndexToUpdate + "\n");
			
		//found save, update character data
		if ( iSaveIndexToUpdate != -1 )
		{
			jvOutSaveFile[iSaveIndexToUpdate]["characterData"] = UpdateCharacterData(jvOutSaveFile[iSaveIndexToUpdate]);
			if (DEBUG_MODE && DEBUG_VERBOSE)
				g_EngineFuncs.ServerPrint("jvOutSaveFile before update" + SafeJsonaStringify(jvOutSaveFile) + "\n");
		}
		//if we didn't find a save by that name, make a new one
		else
		{
			jvOutSaveFile.insertLast( NewSaveFromTemplate( sSaveNameToUpdate ) );
		}
		
		return jvOutSaveFile;
	}
	
	int GetSaveIndex( array<Jsona::Value@>@ ajvSaveFile, string sSaveName )
	{
		sSaveName = "\"" + sSaveName + "\""; //Jsona appends quotation marks to their stringify returns on strings. Need to add for comparison
	
		g_EngineFuncs.ServerPrint("Inside SaveLoad::GetSaveIndex\n");
		g_EngineFuncs.ServerPrint("Save file: " + SafeJsonaStringify(ajvSaveFile) + " with save name " + sSaveName + "\n");

		for ( uint i = 0; i < ajvSaveFile.length(); i++ )
		{
			g_EngineFuncs.ServerPrint("Save file: " + SafeJsonaStringify(ajvSaveFile[i]["saveName"]) + "\n");
			if (sSaveName == SafeJsonaStringify(ajvSaveFile[i]["saveName"]))
			{
				return i;
			}
		}
		return -1;
	}
	
	//Returns an array of character data from currently online players
	array<Jsona::Value@>@ GetCharacterData()
	{
		array<Jsona::Value@>@ ajvCharacterData = array<Jsona::Value@>();
		
		for ( int i = 1; i <= g_Engine.maxClients; i++ )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
			if ( pPlayer is null )
			{
				g_EngineFuncs.ServerPrint("Index: " + i + " is not a Player\n");
				continue;
			}
			g_EngineFuncs.ServerPrint("Index: " + i + " is a Player, building character data\n");
			Jsona::Value@ jvPlayerTemplate = MakeJsonaPlayerFromTemplate(pPlayer);
			ajvCharacterData.insertLast( jvPlayerTemplate );
		}

		return ajvCharacterData;
	}
	
	Jsona::Value@ UpdateCharacterData( Jsona::Value@ ajvInSaveData )
	{
		array<Jsona::Value@>@ ajvOutCharacterData = array<Jsona::Value@>();
		
		for ( int i = 1; i <= g_Engine.maxClients; i++ )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
			if ( pPlayer is null )
			{
				g_EngineFuncs.ServerPrint("Index: " + i + " is not a Player\n");
				continue;
			}
			
			//get player's character index in existing save
			int iCharacterIndex = GetCharacterIndex( ajvOutCharacterData, pPlayer );
			
			//if character doesn't exist, add a new entry
			if ( iCharacterIndex == -1 )
			{
				g_EngineFuncs.ServerPrint("Index: " + i + " is a Player, building character data\n");
				
				Jsona::Value@ jvPlayerTemplate = MakeJsonaPlayerFromTemplate( pPlayer );
				
				ajvOutCharacterData.insertLast( jvPlayerTemplate );
			}
			else
			{
				ajvOutCharacterData[iCharacterIndex]["inventory"] = GetInventoryAsJsona( pPlayer );
			}
		}

		return ajvOutCharacterData;
	}
	
	int GetCharacterIndex ( array<Jsona::Value@> ajvInCharacterData, CBasePlayer@ pPlayer )
	{
		string sPlayerName = "\"" + pPlayer.pev.netname + "\"";
	
		for ( uint i = 0; i < ajvInCharacterData.length(); i++ )
		{
			if ( SafeJsonaStringify(ajvInCharacterData[i]["netName"]) == sPlayerName )
			return i;
		}
		
		return -1;
	}
	
	//take in a player reference and return a Jsona value with the player's netName and inventory
	Jsona::Value@ MakeJsonaPlayerFromTemplate( CBasePlayer@ pPlayer )
	{
		//init character template
		Jsona::Value@ jvCharacterTemplate = Jsona::parse(CHARACTER_DATA_TEMPLATE);
		if (jvCharacterTemplate is null)
		{
			g_EngineFuncs.ServerPrint("Could not parse template: " + SafeJsonaStringify(jvCharacterTemplate) + "\n");
			return Jsona::Value();
		}
		
		jvCharacterTemplate["netName"] = Jsona::Value(string(pPlayer.pev.netname));
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("netname: " + SafeJsonaStringify(jvCharacterTemplate["netName"]) + "\n");
		
		//initialize player inventory array
		jvCharacterTemplate["inventory"] = GetInventoryAsJsona(pPlayer);
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("inventory: " + SafeJsonaStringify(jvCharacterTemplate["inventory"]) + "\n");
			
		return jvCharacterTemplate;
	}
	
	array<Jsona::Value@>@ GetInventoryAsJsona( CBasePlayer@ pPlayer )
	{
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("Getting Player: " + pPlayer.pev.netname + "'s Inventory as Jsona\n");
		
		array<Jsona::Value@>@ jv_aOutInventory = array<Jsona::Value@>();
		
		//credit to: Deleted User 03/10/2021 #scripting
		InventoryList@ pNextIL = @pPlayer.m_pInventory;
		while (pNextIL !is null)
		{
			// Get the current item entity.
			if (DEBUG_MODE && DEBUG_VERBOSE)
				g_EngineFuncs.ServerPrint("pNextIL: " + pNextIL.hItem.GetEntity().pev.classname + "\n");
			CItemInventory@ pInventoryItem = cast<CItemInventory@>( pNextIL.hItem.GetEntity() );
			string sItemName = string(pInventoryItem.m_szItemName);
			//init item
			Jsona::Value@ jv_sItem = Jsona::Value(sItemName);
			if (DEBUG_MODE && DEBUG_VERBOSE)
				g_EngineFuncs.ServerPrint("Adding Item: " + SafeJsonaStringify(jv_sItem) + "\n");
			
			//add to output array
			jv_aOutInventory.insertLast(jv_sItem);
			// Next inventory list.
			@pNextIL = @pNextIL.pNext;
		}
		
		if (DEBUG_MODE && DEBUG_VERBOSE)
				g_EngineFuncs.ServerPrint("Inventory: " + Jsona::stringify(jv_aOutInventory) + "\n");
		return jv_aOutInventory;
	}
	
	//return first line of specified file from filesystem
	string GetFileString( string sFileName )
	{
		string sOutput = "";
		//Open file from name constant
		File@ pFile = g_FileSystem.OpenFile(sFileName, OpenFile::READ);
		if (pFile is null)
		{
			g_EngineFuncs.ServerPrint("Could not load file from " + sFileName + "\n");
			return sOutput;
		}
		
		size_t sLength;
		
		sLength = pFile.GetSize();
		
		if (DEBUG_MODE && DEBUG_VERBOSE)
			g_EngineFuncs.ServerPrint("File size " + sLength + "\n");
			
		pFile.ReadLine(sOutput);
		pFile.Close();
		return sOutput;
	}
	
	string SafeJsonaStringify( Jsona::Value@ jvInValue )
	{
		string sOutString = "";
		if (jvInValue !is null)
			sOutString = Jsona::stringify(jvInValue); //Never ever ever call stringify with a nullptr input
		else
			sOutString = "jvInValue is Null!";
			
		return sOutString;
	}
	
	string SafeJsonaStringify( array<Jsona::Value@> ajvInArrayValue )
	{
		string sOutString = "";
		if (ajvInArrayValue !is null)
			sOutString = Jsona::stringify(ajvInArrayValue); //Never ever ever call stringify with a nullptr input
		else
			sOutString = "ajvInArrayValue is Null!";
			
		return sOutString;
	}
	
	bool WriteSaveToFile( Jsona::Value@ jvSaveFile )
	{
		File@ pFile = g_FileSystem.OpenFile(g_sFileName, OpenFile::WRITE);
		if (pFile is null)
		{
			return false;
		}
		
		pFile.Write(Jsona::stringify(jvSaveFile));
		pFile.Close();
		
		return true;
	}
	
}//end namespace