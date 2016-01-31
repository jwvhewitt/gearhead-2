unit arenascript;
	{ This unit holds the scripting language for GearHead. }
	{ It's pretty similar to the scripts developed for DeadCold. }
	{ Basically, certain game events will add a trigger to the }
	{ list. In the main combat procedure, if there are any pending }
	{ triggers, they will be checked against the events list to }
	{ see if anything happens. }

	{ Both the triggers and the event scripts will be stored as }
	{ normal string attributes. }

	{ This unit also handles conversations with NPCs, since those }
	{ are written using the scripting language and may use any }
	{ commands available there + a few special commands. }
{
	GearHead2, a roguelike mecha CRPG
	Copyright (C) 2005 Joseph Hewitt

	This library is free software; you can redistribute it and/or modify it
	under the terms of the GNU Lesser General Public License as published by
	the Free Software Foundation; either version 2.1 of the License, or (at
	your option) any later version.

	The full text of the LGPL can be found in license.txt.

	This library is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
	General Public License for more details. 

	You should have received a copy of the GNU Lesser General Public License
	along with this library; if not, write to the Free Software Foundation,
	Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA 
}
{$LONGSTRINGS ON}

interface

uses gears,locale,
{$IFDEF ASCII}
	vidmenus,vidgfx;
{$ELSE}
	sdlmenus,sdl;
{$ENDIF}

const
	NAG_ScriptVar = 0;
	NAG_SkillCounter = -16;	{ Counter for skill tests. }
	Max_Plots_Per_Story = 5;

	NAG_ArenaData = -18;	{ Used to store information about mecha arena combat }
		NAS_ArenaState = 1;	{ Determines what exactly is happening at the arena now. }
			NAV_AS_Vacant = 0;	{ No fight now, no fight scheduled }
			NAV_AS_Ready = 1;	{ Start fight next time PC enters scene }
			NAV_AS_Battle = 2;	{ Battle in progress }
			NAV_AS_Win = 3;		{ PC has won the battle }
			NAV_AS_Loss = 4;	{ PC hass lost the battle }
		NAS_ArenaWins = 2;	{ # of times PC has won match }
		NAS_ArenaThreat = 4;	{ Threat value of enemy mecha }
		NAS_ArenaForces = 5;	{ % of generic enemies to fight }
		NAS_ChallengerID = 6;	{ NPC challenger present during battle }
		NAS_ChallengerHome = 7;	{ Where to return champion after fight }
		NAS_ArenaRecharge = 8;	{ Time when next fight can take place }

	{ When playing in arena mode, the following string attributes will be added to the scene }
	{ following battle. }
	ARENAREPORT_CharDied = 'AR_PCDIED';
	ARENAREPORT_CharRecovered = 'AR_PCRECOVERED';
	ARENAREPORT_MechaDestroyed = 'AR_MECHADIED';
	ARENAREPORT_MechaRecovered = 'AR_MECHARECOVERED';
	ARENAREPORT_MechaObtained = 'AR_MECHAOBTAINED';
	ARENAREPORT_Personal = 'AR_PERSONAL';

var
	{ This gear pointer will be created if a dynamic scene is requested. }
	SCRIPT_DynamicEncounter: GearPtr;

	{ **************************************** }
	{ ***  INTERACTION  GLOBAL  VARIABLES  *** }
	{ **************************************** }
	{ These variables hold information that may be needed anywhere }
	{ while interaction is taking place, but are undefined if }
	{ interaction is not taking place. }
	{ IntMenu should let procedures know whether or not interaction }
	{ is currently happening or not- if IntMenu <> Nil, we're in the }
	{ middle of a conversation and all other interaction variables }
	{ should have good values. }
	IntMenu: RPGMenuPtr;	{ Interaction Menu }
	I_PC,I_NPC: GearPtr;	{ Pointers to the PC & NPC Chara gears }
	I_Rumors: SAttPtr;	{ List of rumors. }
	I_Persona: GearPtr;	{ The conversation currently being used. }

	Grabbed_Gear: GearPtr;	{ This gear can be acted upon by }
				{ generic commands. }

	lancemate_tactics_persona: GearPtr;	{ Persona for setting lancemate tactics. }
	rumor_leads: GearPtr;			{ Mini-conversations for finding rumors. }


Procedure SetLancemateOrders( GB: GameBoardPtr );
Function NumLancemateSlots( Adv,PC: GearPtr ): Integer;

Procedure BrowseMemoType( GB: GameBoardPtr; Tag: String );

Function BasicSkillTarget( Renown: Integer ): Integer;
Function HardSkillTarget( Renown: Integer ): Integer;
Function Calculate_Reward_Value( GB: GameBoardPtr; Renown,Percent: LongInt ): LongInt;

Function ScriptValue( var Event: String; GB: GameBoardPtr; Scene: GearPtr ): LongInt;

Function AS_GetString( Source: GearPtr; Key: String ): String;
Function ScriptMessage( msg_label: String; GB: GameBoardPtr; Source: GearPtr ): String;
Function NPCScriptMessage( const msg_label: String; GB: GameBoardPtr; NPC, Source: GearPtr ): String;

Procedure InvokeEvent( Event: String; GB: GameBoardPtr; Source: GearPtr; var Trigger: String );

Procedure AddLancemate( GB: GameBoardPtr; NPC: GearPtr );
Function AddLancemateFrontEnd( GB: GameBoardPtr; PC,NPC: GearPtr; CanCancel: Boolean ): Boolean;
Procedure RemoveLancemate( GB: GameBoardPtr; Mek: GearPtr; DoMessage: Boolean );

Procedure HandleInteract( GB: GameBoardPtr; PC,NPC,Persona: GearPtr );
Procedure DoTalkingWIthNPC( GB: GameBoardPtr; PC,Mek: GearPtr; ByTelephone: Boolean );

Function TriggerGearScript( GB: GameBoardPtr; Source: GearPtr; var Trigger: String ): Boolean;
Function CheckTriggerAlongPath( var T: String; GB: GameBoardPtr; Plot: GearPtr; CheckAll: Boolean ): Boolean;
Procedure HandleTriggers( GB: GameBoardPtr );


Function StartRescueScenario( GB: GameBoardPtr; PC: GearPtr; Context: String ): Boolean;


implementation

uses action,arenacfe,ability,gearutil,ghchars,gearparser,ghmodule,backpack,
     ghprop,ghweapon,grabgear,interact,menugear,playwright,rpgdice,
     services,texutil,ui4gh,wmonster,narration,description,skilluse,
	ghintrinsic,movement,minigame,customization,aibrain,mpbuilder,
{$IFDEF ASCII}
	vidmap,vidinfo;
{$ELSE}
	sdlgfx,sdlmap,sdlinfo;
{$ENDIF}

const
	CMD_Chat = -2;
	CMD_Join = -3;
	CMD_Quit = -4;
	CMD_WhereAreYou = -5;
	CMD_AskAboutRumors = -6;
	Debug_On: Boolean = False;

var
	script_macros,value_macros,Default_Scene_Scripts: SAttPtr;
	ASRD_GameBoard: GameBoardPtr;
	ASRD_MemoMessage: String;
	local_triggers: SAttPtr;

{  ******************************  }
{  ***   REDRAW  PROCEDURES   ***  }
{  ******************************  }

Procedure InteractRedraw;
	{ Redraw the screen for whatever interaction is going to go on. }
begin
	CombatDisplay( ASRD_GameBoard );
	SetupInteractDisplay( PlayerBlue );
	if I_NPC <> Nil then begin
		DisplayInteractStatus( ASRD_GameBoard , I_NPC , CHAT_React , I_Endurance );

	end;
	GameMsg( CHAT_Message , ZONE_InteractMsg , InfoHiLight );
end;

Procedure ArenaScriptReDraw;
	{ Redraw the combat screen for some menu usage. }
begin
	if ASRD_GameBoard <> Nil then CombatDisplay( ASRD_GameBoard );
end;

Procedure MemoPageReDraw;
	{ Redraw the combat screen for some menu usage. }
begin
	if ASRD_GameBoard <> Nil then CombatDisplay( ASRD_GameBoard );
	SetupMemoDisplay;
	GameMsg( ASRD_MemoMessage , ZONE_MemoText , StdWhite );
end;

Procedure ChoiceReDraw;
	{ Redraw the combat screen for some menu usage. }
begin
	if ASRD_GameBoard <> Nil then CombatDisplay( ASRD_GameBoard );
	SetupMemoDisplay;
	GameMsg( ASRD_MemoMessage , ZONE_MemoMenu , StdWhite );
end;



{  ****************************  }
{  ***   EVERYTHING  ELSE   ***  }
{  ****************************  }

Function BasicSkillTarget( Renown: Integer ): Integer;
	{ Return an appropriate target for skill rolls for someone of the listed renown. }
var
	it: Integer;
begin
	it := Renown div 8 + 3;
	if it < 5 then it := 5;
	BasicSkillTarget := it;
end;

Function HardSkillTarget( Renown: Integer ): Integer;
	{ Return a difficult target for skill rolls for someone of the listed renown. }
var
	it: Integer;
begin
	it := Renown div 7 + 10;
	if it < 9 then it := 9;
	HardSkillTarget := it;
end;

Function SocSkillTarget( GB: GameBoardPtr; Renown: Integer ): Integer;
	{ Return a social difficult target for skill rolls based on Renown and modified }
	{ by the relationship between I_PC and I_NPC. }
var
	it,react: Integer;
begin
	it := Renown div 7 + 7;
	if it < 10 then it := 10;

	{ If the PC and NPC exist, apply the special modifier. }
	if ( I_PC <> Nil ) and ( I_NPC <> Nil ) then begin
		react := ReactionScore( GB^.Scene , I_PC , I_NPC );
		it := it - ( react div 10 );
	end;

	SocSkillTarget := it;
end;


Function CreateRumorList( GB: GameBoardPtr; Rumor_Source: GearPtr; SkRoll: Integer; DoHarvest: Boolean; var Rumor_Error: Boolean; const Rumemo_Lead,Rumor_Head: String ): SAttPtr;
	{ RUMOR_HEAD is the rumor type to collect: RUMORs or RUMEMOs. }
	{ RUMEMO_LEAD is the leading message appended to a rumor if we're }
	{ harvesting them for RUMEMOs. }

	{ If DoHarvest is TRUE, all found rumors will be changed to RUMEMOs. }
	{ ...if FALSE, then SkRoll is ignored and all messages are returned. }

	{ Search through the adventure, revealing rumors as you go. When a rumor }
	{ is discovered, do the following: }
	{ - Check to see if SkRoll is high enough to reveal it. }
	{ - If so, add it to the list of rumors. }
	{ - Also convert the original rumor to a rumor memo. }
	{ If no rumors are found at all, set RUMOR_ERROR to TRUE; otherwise FALSE. }
var
	InfoList: SAttPtr;

	Function RumorSKTarget( Part: gearPtr ): Integer;
		{ Return the skill roll needed to learn this rumor. }
	var
		Plot: GearPtr;
		it: Integer;
	begin
		{ If we're dealing with a plot-based rumor, get the difficulty number from the plot. }
		Plot := PlotMaster( GB , Part );
		if Plot <> Nil then begin
			{ Use the difficulty rating for this plot. }
			it := SocSkillTarget( GB , NAttValue( Plot^.NA , NAG_Narrative , NAS_DifficultyLevel ) );
		end else begin
			it := 5;
		end;

		{ In order to keep the process somewhat unpredictable, randomize the target }
		{ just a bit. }
		it := it - 5 + RollStep( 3 );
		if Random( 3 ) = 1 then it := it + Random( 4 );

		RumorSKTarget := it;
	end;

	Procedure AddThisRumor( Part: GearPtr; Rumor: SAttPtr );
		{ Add this rumor to the list... maybe. }
	var
		msg,rh: String;
	begin
		msg := RetrieveAString( Rumor^.Info );
		if DoHarvest then begin
			if SkRoll > RumorSkTarget( Part ) then begin
				{ This rumor has been retrieved. }
				StoreSAtt( InfoList , msg );
				rh := RetrieveAPreamble( rumor^.Info );
				Rumor^.Info := 'RUMEMO' + Copy( rh , Length( Rumor_Head ) + 1 , Length( rh ) ) + ' <' + RuMemo_Lead + ' ' + msg + '>';
			end;
		end else begin
			{ We aren't converting to RUMEMO right now. Ignore the skill roll }
			{ and simply return the message without changing anything. }
			StoreSAtt( InfoList , msg );
		end;
		{ Set RUMOR_ERROR to FALSE, since we just found one. }
		RUMOR_ERROR := FALSE;
	end;

	Procedure GetRumorFromGear( P: GearPtr );
		{ Retrieve the rumor info from this gear, without caring about }
		{ what kind of gear it is. Well, for the most part, anyhow... }
	var
		Rumor: SAttPtr;
		Level: LongInt;
	begin
		{ First add the basic rumor.  }
		Rumor := FindSAtt( P^.SA , Rumor_Head );
		if Rumor <> Nil then AddThisRumor( P , Rumor );

		{ Next add the quest rumor. }
		Level := NAttValue( P^.NA , NAG_Narrative , NAS_PlotID );
		if Level < 0 then begin
			Rumor := FindSAtt( P^.SA , Rumor_Head + BStr( NAttValue( FindRoot( GB^.Scene )^.NA , NAG_PlotStatus , Level ) ) );
			if Rumor <> Nil then AddThisRumor( P , Rumor );
		end else if (( P^.G = GG_Persona ) or ( P^.G = GG_MetaScene )) and ( P^.Parent <> Nil ) and ( P^.Parent^.G = GG_Plot ) then begin
			{ Finally add the plot rumor. }
			Rumor := FindSAtt( P^.SA , Rumor_Head + BStr( NAttValue( FindRoot( GB^.Scene )^.NA , NAG_PlotStatus , Level ) ) );
			if Rumor <> Nil then AddThisRumor( P , Rumor );
		end;
	end;

	Procedure RumorWorkup( P: GearPtr ); Forward;
	Procedure ExtractData( P: GearPtr );
		{ Store all relevant info from PART. }
		{ If P is of certain types, we're gonna have to harvest the data from }
		{ its associated bits. Characters also need the data from their Personas, }
		{ gates to metascenes need to check there, and scenes get faction data. }
	var
		Persona: GearPtr;
	begin
		if ( P <> Rumor_Source ) and ( P^.G <> GG_Persona ) then begin
			if P <> GB^.Scene then GetRumorFromGear( P );
			if P^.G = GG_Character then begin
				Persona := SeekPersona( GB , NAttValue( P^.NA , NAG_Personal , NAS_CID ) );
				if Persona <> Nil then begin
					{ Previously we'd just collect the rumor from the persona }
					{ and be done with it, but since Quests have been introduced }
					{ the rumor associated with a given NPC can change depending }
					{ on quest state. }
					GetRumorFromGear( Persona );
				end;

			end else if ( P^.G = GG_MetaTerrain ) and ( P^.Stat[ STAT_Destination ] < 0 ) then begin
				{ Find the metascene, and do a complete rumor work-up of it. }
				Persona := FindActualScene( GB , P^.Stat[ STAT_Destination ] );
				if Persona <> Nil then begin
					RumorWorkup( Persona );
				end;
			end;
		end;
	end;
	Procedure RumorWorkup( P: GearPtr );
		{ Do a complete rumor workup on P, gathering info from it }
		{ and all its child gears. }
	var
		P2: GearPtr;
	begin
		if P = Nil then Exit;
		ExtractData( P );
		P2 := P^.SubCom;
		while P2 <> Nil do begin
			RumorWorkup( P2 );
			P2 := P2^.Next;
		end;
		P2 := P^.InvCom;
		while P2 <> Nil do begin
			RumorWorkup( P2 );
			P2 := P2^.Next;
		end;
	end;
var
	Part: GearPtr;

begin
	{ Assume an error until we find a rumor to prove us wrong. }
	Rumor_Error := TRUE;

	InfoList := Nil;

	Part := FindRootScene( GB^.Scene );
	RumorWorkup( Part );

	Part := GB^.Meks;
	while Part <> Nil do begin
		ExtractData( Part );
		Part := Part^.Next;
	end;

	CreateRumorList := InfoList;
end;

Function RevealRumors( GB: GameBoardPtr; NPC: GearPtr; SkRoll: Integer; var Rumor_Error: Boolean ): SAttPtr;
	{ Reveal some rumors! Call the CreateRumorList procedure with a standard reveal. }
begin
	RevealRumors := CreateRumorList( GB, NPC, SkRoll, TRUE, Rumor_Error, ReplaceHash( MsgString( '#SaidThat' ) , PilotName( NPC ) ), 'RUMOR' );
end;

Function ReviewRumorMemos( GB: GameBoardPtr ): SAttPtr;
	{ Create the list of rumor memos. }
var
	Rumor_Error: Boolean;	{ A dummy variable. }
begin
	ReviewRumorMemos := CreateRumorList( GB, Nil, 0, FALSE, Rumor_Error, '', 'RUMEMO' );
end;

Procedure BrowseMemoType( GB: GameBoardPtr; Tag: String );
	{ Create a list, then browse the memos based upon this }
	{ TAG type. Possible options are MEMO, NEWS, and EMAIL. }
var
	MemoList,M: SAttPtr;
	Adv: GearPtr;

	Procedure HarvestPlotMemos( LList: SAttPtr );
		{ This list may contain plot memos. How to tell? The first four }
		{ characters will be "MEMO". It's just like harvesting the history. }
	begin
		while LList <> Nil do begin
			if UpCase( Copy( LList^.Info , 1 , 4 ) ) = 'MEMO' then begin
				StoreSAtt( MemoList , RetrieveAString( LList^.Info ) );
			end;
			LList := LList^.Next;
		end;
	end;
	Procedure CreateMemoList( Part: GearPtr; Tag: String );
		{ Look through all gears in the structure recursively, }
		{ looking for MEMO string attributes to store in our list. }
	var
		msg: String;
		QID: LongInt;
	begin
		while Part <> Nil do begin
			if ( tag = 'MEMO' ) and ( Part^.G = GG_Plot ) then begin
				{ This is a plot. It may have subplot memos. These are }
				{ memos that have the PLOTID attached to their butts. Why? }
				{ Because I realized, somewhat late, that a plot which can }
				{ contain multiple narrative threads really needs multiple }
				{ memos as well. }
				HarvestPlotMemos( Part^.SA );
			end else begin
				{ Not a plot. Just do the regular harvesting work, then. }
				msg := SAttValue( Part^.SA , Tag );
				if msg <> '' then StoreSAtt( MemoList , msg );

				{ This part may also have a quest-related message attached }
				{ to it. See if that's so. }
				QID := NAttValue( Part^.NA , NAG_Narrative , NAS_PlotID );
				if ( QID <> 0 ) then begin
					msg := SAttValue( Part^.SA , Tag + '_' + BStr( NAttValue( Adv^.NA , NAG_PlotStatus , Qid ) ) );
					if msg <> '' then StoreSAtt( MemoList , msg );
				end;
			end;

			CreateMemoList( Part^.SubCom , Tag );
			CreateMemoList( Part^.InvCom , Tag );
			Part := Part^.Next;
		end;
	end;
	Procedure AddQuestMemos;
		{ Quest memos work a bit differently than other memos. First, }
		{ they only appear so long as the quest they're assigned to is }
		{ active (i.e. it has a nonnegative QID). }
	var
		SA,SA2: SAttPtr;
		msg_head: String;
		qid: LongInt;
	begin
		SA := Adv^.SA;
		while SA <> Nil do begin
			SA2 := SA^.next;

			{ If this string attribute is potentially a quest memo, }
			{ try to extract its QuestID. If this memo is no longer }
			{ valid then delete it. }
			if HeadMatchesString( 'MEMO_' , SA^.Info ) then begin
				msg_head := RetrieveAPreamble( SA^.Info );
				msg_head := Copy( msg_head , 6 , Length( msg_head ) );
				qid := ExtractValue( msg_head );
				if ( qid <> 0 ) and ( NAttValue( Adv^.NA , NAG_PlotStatus , Qid ) > -1 ) then begin
					{ Add it to the list. }
					StoreSAtt( MemoList , RetrieveAString( SA^.Info ) );
				end else begin
					{ Invalid quest memo. Get rid of it. }
					RemoveSAtt( Adv^.SA , SA );
				end;
			end;

			SA := SA2;
		end;
	end;
	Function PlaceMemoPhoneCall( PC: GearPtr; MMsg: String ): Boolean;
		{ We want to make a phone call to someone mentioned in this memo. }
		{ Search through all the NPCs on the game board and within the current city. }
		{ Add them to a menu. Then, query the menu, and do talking with the selected NPC. }
		{ Return TRUE if a conversation was had, or FALSE otherwise. }
		Procedure CheckAlongList( RPM: RPGMenuPtr; LList: GearPtr );
			{ Check along this list for NPCs mentioned in the memo, recursively }
			{ searching through children as well. }
			{ Add any good NPCs found to the menu, using their CID as the key. }
		var
			Name: String;
			CID: LongInt;
		begin
			while LList <> Nil do begin
				if LList^.G = GG_Character then begin
					{ This is a character. Is it somebody we're looking for? }
					Name := GearName( LList );
					CID := NAttValue( LList^.NA , NAG_Personal , NAS_CID );
					if ( CID <> 0 ) and ( Pos( Name , MMsg ) > 0 ) and CanContactByPhone( GB , LList ) then begin
						AddRPGMenuItem( RPM , GearName( LList ) , CID );
					end;
				end else begin
					{ Not a character. Recurse like mad! }
					CheckAlongList( RPM , LList^.SubCom );
					CheckAlongList( RPM , LList^.InvCom );
				end;

				LList := LList^.Next;
			end;
		end;
	var
		RPM: RPGMenuPtr;
		city,NPC: GearPtr;
		CID: LongInt;
	begin
		{ Step One- Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoMenu );
		CheckAlongList( RPM , GB^.Meks );
		City := FindRootScene( GB^.Scene );
		if City <> Nil then begin
			CheckAlongList( RPM , City^.SubCom );
			CheckAlongList( RPM , City^.InvCom );
		end;
		RPMSortAlpha( RPM );
		AlphaKeyMenu( RPM );
		if RPM^.NumItem > 0 then begin
			AddRPGMenuItem( RPM , MsgString( 'Cancel' ) , -1 );
		end else begin
			AddRPGMenuItem( RPM , MsgString( 'MEMO_CALL_NoPeople' ) , -1 );
		end;

		{ Step Two- Query the menu and locate the NPC. }
		CID := SelectMenu( RPM , @MemoPageRedraw );
		DisposeRPGMenu( RPM );

		{ Step Three- Pass the request along to HandleInteract. }
		if CID > -1 then begin
			NPC := GG_LocateNPC( CID , GB , GB^.Scene );
			if NPC <> Nil then begin
				DoTalkingWithNPC( GB , PC , NPC , True );
			end;
		end else NPC := Nil;

		PlaceMemoPhoneCall := NPC <> Nil;
	end;
	Procedure BrowseList;
		{ Actually browse the created list. }
	var
		RPM: RPGMenuPtr;
		N,D: Integer;
		PC: GearPtr;
	begin
		{ Locate the PC. We need it for the PComm capability. }
		PC := GG_LocatePC( GB );
		if MemoList <> Nil then begin
			RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoMenu );
			AddRPGMenuItem( RPM , MsgString( 'MEMO_Next' ) , 1 );
			AddRPGMenuItem( RPM , MsgString( 'MEMO_Prev' ) , 2 );
			if ( PC <> Nil ) and HasPCommCapability( PC , PCC_Phone ) then AddRPGMenuItem( RPM , MsgString( 'MEMO_Call' ) , 3 );
			AddRPGMenuKey( RPM , KeyMap[ KMC_East ].KCode , 1 );
			AddRPGMenuKey( RPM , KeyMap[ KMC_West ].KCode , 2 );
			AlphaKeyMenu( RPM );
			RPM^.Mode := RPMNoCleanup;
			N := 1;

			repeat
				M := RetrieveSAtt( MemoList , N );
				ASRD_GameBoard := GB;
				ASRD_MemoMessage := M^.Info;
				D := SelectMenu( RPM , @MemoPageRedraw );


				if D = 1 then begin
					N := N + 1;
					if N > NumSAtts( MemoList ) then N := 1;
				end else if D = 2 then begin
					N := N - 1;
					if N < 1 then N := NumSAtts( MemoList );
				end else if D = 3 then begin
					{ We want to place a phone call to someone mentioned }
					{ in this memo. Make it so. }
					PlaceMemoPhoneCall( PC , M^.Info );
					D := -1;
				end;
			until ( D = -1 ) or not KeepPlayingSC( GB );

			DisposeSAtt( MemoList );
			DisposeRPGMenu( RPM );
		end;

	end;
	Function NoMemoError: String;
		{ Return a string which will explain to the user that there are }
		{ no memos of the selected type. }
	var
		msg: String;
	begin
		msg := MsgString( 'MEMO_No_' + Tag );
		if msg = '' then msg := ReplaceHash( MsgString( 'MEMO_None' ) , LowerCase( Tag ) );
		NoMemoError := msg;
	end;
begin
	{ Error check first - we need the GB and the scene for this. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;
	tag := UpCase( Tag );
	MemoList := Nil;
	Adv := FindRoot( GB^.Scene );
	if ( Tag = 'RUMEMO' ) then begin
		MemoList := ReviewRumorMemos( GB );
	end else begin
		CreateMemoList( Adv , Tag );
	end;
	if Tag = 'MEMO' then AddQuestMemos;

	{ Sort the memo list. }
	if MemoList <> Nil then SortStringList( MemoList )
	else StoreSAtt( MemoList , NoMemoError );

	BrowseList;
end;

Function YesNoMenu( GB: GameBoardPtr; Prompt,YesMsg,NoMsg: String ): Boolean;
	{ This will open up a small window in the middle of the map }
	{ display, then prompt the user for a choice. }
	{ Return TRUE if the "yes" option was selected, or FALSE if }
	{ the "no" option was selected. }
	{ This function performs no screen cleanup. }
var
	rpm: RPGMenuPtr;
	N: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoMenu );
	AddRPGMenuItem( RPM , YesMsg , 1 );
	AddRPGMenuItem( RPM , NoMsg , -1 );
	RPM^.Mode := RPMNoCancel;

	ASRD_GameBoard := GB;
	ASRD_MemoMessage := Prompt;
	N := SelectMenu( RPM , @MemoPageRedraw );

	DisposeRPGMenu( RPM );

	{ Do cleanup before branching. }
	CombatDisplay( GB );

	YesNoMenu := N <> -1;
end;

Procedure SetLancemateOrders( GB: GameBoardPtr );
	{ Go through the lancemates, and assign any orders they might need. }
var
	PCUID,DefOrder: LongInt;
	mek: gearPtr;
begin
	{ Step one- find the PC's UID. }
	mek := GB^.meks;
	while mek <> Nil do begin
		if ( NAttValue( mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and IsMasterGear( mek ) then begin
			{ This must be the PC. }
			PCUID := NAttValue( mek^.NA , NAG_EpisodeData , NAS_UID );
		end;
		mek := mek^.Next;
	end;

	{ Step two- look for the lancemates and set their orders. }
	mek := GB^.meks;
	while mek <> Nil do begin
		if ( NAttValue( mek^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and IsMasterGear( mek ) then begin
			DefOrder := NAttValue( mek^.NA , NAG_Personal , NAS_LancemateOrders );
			if DefOrder = NAV_Passive then begin
				SetNAtt( mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_Passive );
			end else if DefOrder = NAV_Follow then begin
				SetNAtt( mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_Follow );
				SetNAtt( mek^.NA , NAG_EpisodeData , NAS_ATarget , PCUID );
			end else begin
				SetNAtt( mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_SeekAndDestroy );
			end;
		end;
		mek := mek^.Next;
	end;
end;

Function NumLancemateSlots( Adv,PC: GearPtr ): Integer;
	{ Return the number of freely-selected lancemates this PC can have. }
var
	N: Integer;
begin
	{ You get one lancemate for free. }
	N := 1;

	{ You can earn extra lancemates via merit badges. }
	if HasMeritBadge( Adv , NAS_MB_Lancemate2 ) then begin
		Inc( N );
		if HasMeritBadge( Adv, NAS_MB_Lancemate3 ) then Inc( N );
	end;

	{ Or, you can take a talent for one extra. }
	if HasTalent( PC , NAS_Entourage ) then begin
		Inc( N );
	end;

	NumLancemateSlots := N;
end;

Function CanJoinLance( GB: GameBoardPtr; PC,NPC: GearPtr ): Boolean;
	{ Return TRUE if NPC can join the lance right now, or FALSE otherwise. }
var
	ERen: Integer;	{ Lancemate Points needed, Effective Renown }
	CanJoin: Boolean;
begin
	ERen := NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned );
	if ERen < 15 then ERen := 15;
	ERen := ERen + CStat( PC , STAT_Charm );
	CanJoin := True;
	if ( NPC = Nil ) or ( NPC^.G <> GG_Character ) then begin
		CanJoin := False;
	end else if NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned ) > ERen then begin
		CanJoin := False;
	end else if ( GB <> Nil ) and ( ReactionScore( GB^.Scene , PC , NPC ) < 10 ) then begin
		CanJoin := False;
	end else if ( GB <> Nil ) and not ( OnTheMap( GB , FindRoot( NPC ) ) and IsFoundAlongTrack( GB^.Meks , FindRoot( NPC ) ) ) then begin
		{ Can only join if in the same scene as the PC. }
		CanJoin := False;
	end else if PersonaUsedByQuest( FindRoot( GB^.Scene ) , NPC ) then begin
		CanJoin := False;
	end;
	CanJoinLance := CanJoin;
end;


Function SceneName( GB: GameBoardPtr; ID: Integer; Exact: Boolean ): String;
	{ Find the name of the scene with the given ID. If no such }
	{ scene can be found, return a value that should let the player }
	{ know an error has been commited. }
	{ If EXACT=TRUE, use the EXACT_NAME attribute instead of the }
	{ regular name. The reason for this is that sometimes there's }
	{ some ambiguity with the common name of a scene: if I say "Cayley }
	{ Rock", do I mean the city in general or the main station }
	{ specifically? }
var
	msg: String;
	Part: GearPtr;
begin
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then begin
		SceneName := 'XXX';
	end else begin
		{ Look for the scene along the subcomponents of the }
		{ adventure. This is to make sure we don't accidentally }
		{ pick a dynamic scene with the right ID. }
		{ Also, if we have a metascene instead of a regular scene, then }
		{ we want the name of the entrance instead of the name of the }
		{ scene itself. }
		if ID > 0 then begin
			Part := FindActualScene( GB , ID );
		end else begin
			Part := FindSceneEntrance( FindRoot( GB^.Scene ) , GB , ID );
		end;
		if Exact then begin
			msg := SAttValue( Part^.SA , 'EXACT_NAME' );
			if msg = '' then msg := GearName( Part );
			SceneName := msg;
		end else begin
			SceneName := GearName( Part );
		end;
	end;
end;

Function FindRandomMekID( GB: GameBoardPtr; Team: Integer ): LongInt;
	{ Locate a random mek belonging to TEAM. }
var
	NumMeks,N,T,MID: Integer;
	Mek: GearPtr;
begin
	{ Start out by finding out how many meks belong to this team }
	{ anyways. }
	NumMeks := NumOperationalMasters( GB , Team );
	MID := 0;

	{ If there are actually members on this team, select one randomly. }
	if NumMeks > 0 then begin
		{ Decide what mek to take, and initialize the }
		{ search variables. }
		N := Random( NumMeks ) + 1;
		T := 0;
		Mek := GB^.Meks;

		while Mek <> Nil do begin
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = Team ) and GearOperational( Mek ) then begin
				Inc( T );
				if T = N then MID := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_UID );
			end;
			Mek := Mek^.Next;
		end;
	end;

	FindRandomMekID := MID;
end;

Function FindRandomPilotID( GB: GameBoardPtr; Team: Integer ): LongInt;
	{ Locate a random pilot belonging to TEAM. }
var
	NumMeks,N,T,MID: Integer;
	Mek,P: GearPtr;
begin
	{ Start out by finding out how many meks belong to this team }
	{ anyways. }
	NumMeks := NumOperationalMasters( GB , Team );
	MID := 0;

	{ If there are actually members on this team, select one randomly. }
	if NumMeks > 0 then begin
		{ Decide what mek to take, and initialize the }
		{ search variables. }
		N := Random( NumMeks ) + 1;
		T := 0;
		Mek := GB^.Meks;

		while Mek <> Nil do begin
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = Team ) and GearOperational( Mek ) then begin
				Inc( T );
				if T = N then begin
					P := LocatePilot( Mek );
					if P <> Nil then MID := NAttValue( P^.NA , NAG_EpisodeData , NAS_UID );
				end;
			end;
			Mek := Mek^.Next;
		end;
	end;

	FindRandomPilotID := MID;
end;

Function FindRootUID( GB: GameBoardPtr; ID: LongInt ): LongInt;
	{ Find the ID of the root of the specified gear. }
var
	Part: GearPtr;
begin
	{ First, find the part being pointed to. }
	Part := LocateMekByUID( GB , ID );

	{ Locate its root. }
	if Part <> Nil then begin
		Part := FindRoot( Part );

		{ Return the root's UID. }
		FindRootUID := NAttValue( Part^.NA , NAG_EpisodeData , NAS_UID );

	{ If there was an error locating the part, return 0. }
	end else FindRootUID := 0;
end;


Function NumPCMeks( GB: GameBoardPtr ): Integer;
	{ Return the number of mecha belonging to team 1. }
	{ It doesn't matter if they're on the board or not, nor whether or }
	{ not they are destroyed. }
var
	M: GearPtr;
	N: Integer;
begin
	N := 0;
	if GB <> Nil then begin
		M := GB^.Meks;
		while M <> Nil do begin
			{ If this is a mecha, and it belongs to team 1, }
			{ increment the counter. }
			if ( M^.G = GG_Mecha ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then Inc( N );
			M := M^.Next;
		end;
	end;
	NumPCMeks := N;
end;

Function FindPCScale( GB: GameBoardPtr ): Integer;
	{ Return the scale of the PC. Generally this will be 0 if the }
	{ PC is on foot, 1 or 2 if the PC is in a mecha, unless the PC }
	{ is a storm giant or a zentradi in which case anything goes. }
var
	PC: GearPtr;
begin
	PC := GG_LocatePC( GB );
	if PC <> Nil then begin
		FindPCScale := FindRoot( PC )^.Scale;
	end else begin
		FindPCScale := 0;
	end;
end;

Function Calculate_Reward_Value( GB: GameBoardPtr; Renown,Percent: LongInt ): LongInt;
	{ Return an appropriate reward value, based on the listed }
	{ threat level and percent scale. }
const
	Min_Reward_Value = 3000;
var
	RV: LongInt;
begin
	{ Calculate the base reward value. }
	RV := Calculate_Threat_Points( Renown + 10 , 100 ) div 64 * Percent div 100;
	if RV < Min_Reward_Value then RV := Min_Reward_Value;

	{ Modify this for the PC's talents. }
	if GB <> Nil then begin
		if TeamHasTalent( GB , NAV_DefPlayerTeam , NAS_BusinessSense ) then RV := ( RV * 5 ) div 4;
	end;

	Calculate_Reward_Value := RV;
end;

Function Calculate_Asking_Price( GB: GameBoardPtr; Renown,Percent: LongInt ): LongInt;
	{ Return an appropriate asking price, based on the listed }
	{ threat level, percent scale, and reaction score with I_NPC. }
const
	Min_Asking_Price = 3000;
var
	RV,React: LongInt;
begin
	{ Calculate the base reward value. }
	RV := Calculate_Threat_Points( Renown , 25 ) * Percent div 100;
	if RV < Min_Asking_Price then RV := Min_Asking_Price;

	{ Modify this for the reaction score. }
	if ( I_NPC <> Nil ) and ( I_PC <> Nil ) and ( GB <> Nil ) then begin
		React := ReactionScore( GB^.Scene , I_PC , I_NPC );
		if React < 0 then RV := RV * ( 100 - 2 * React ) div 100
		else if React > 20 then RV := RV * ( 220 - React ) div 200;
	end;

	Calculate_Asking_Price := RV;
end;

Function Count_Faction_Buddies( GB: GameBoardPtr; FacID: Integer ): Integer;
	{ Return the number of positive relationships the PC has with this }
	{ particular faction. }
	function CountBuddies( LList: GearPtr ): LongInt;
		{ Count the number of buddies along this path. }
	var
		N: LongInt;
	begin
		N := 0;
		while LList <> Nil do begin
			if ( LList^.G = GG_Character ) and ( NAttValue( LList^.NA , NAG_Relationship , 0 ) > 0 ) and ( GetFactionID( LList ) = FacID ) and NotDestroyed( LList ) then Inc( N );
			N := N + CountBuddies( LList^.SubCom );
			N := N + CountBuddies( LList^.InvCom );
			LList := LList^.Next;
		end;
		CountBuddies := N;
	end;
var
	Adv: GearPtr;
begin
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit( 0 );
	Adv := FindRoot( GB^.Scene );
	Count_Faction_Buddies := CountBuddies( GB^.Meks ) + CountBuddies( Adv^.SubCom ) + CountBuddies( Adv^.InvCom );
end;

Function FindLocalMacro( const cmd: String; GB: GameBoardPtr; Source: GearPtr ): String;
	{ Locate the local macro described by "cmd". }
var
	it: String;
	Plot: GearPtr;
begin
	it := SAttValue( Source^.SA , cmd );
	if it = '' then begin
		Plot := PlotMaster( GB , Source );
		if Plot <> Nil then it := SAttValue( Plot^.SA , cmd );
		if it = '' then begin
			Plot := StoryMaster( GB , Source );
			if Plot <> Nil then it := SAttValue( Plot^.SA , cmd );
		end;
	end;
	if it = '' then DialogMsg( 'ERROR: Local macro ' + cmd + ' not found.' );
	FindLocalMacro := it;
end;

Procedure InitiateMacro( GB: GameBoardPtr; Source: GearPtr; var Event: String; ProtoMacro: String );
	{ Initialize the provided macro, and stick it to the head of }
	{ event. To initialize just go through it word by word, replacing }
	{ all question marks with words taken from EVENT. }
	function NeededParameters( cmd: String ): Integer;
		{ Return the number of parameters needed by this function. }
	const
		NumStandardFunctions = 20;
		StdFunName: Array [1..NumStandardFunctions] of string = (
			'-', 'GNATT', 'GSTAT', '?PILOT', '?MECHA',
			'SKROLL', 'THREAT', 'REWARD', 'ESCENE', 'RANGE',
			'FXPNEEDED','*','MAPTILE','PCSKILLVAL','CONCERT',
			'SKILLTAR', 'HARDSKILLTAR', 'SOCSKILLTAR', 'PRICE', 'FACBUDDIES'
		);
		StdFunParam: Array [1..NumStandardFunctions] of byte = (
			1,2,1,1,1,
			1,2,2,1,2,
			1,2,2,2,2,
			1,1,1,2,1
		);
	var
		it,T: Integer;
		Mac: String;
	begin
		it := 0;
		CMD := UpCase( CMD );
		{ If a hardwired function, look up the number of parameters }
		{ from the above list. }
		for t := 1 to NumStandardFunctions do begin 
			if CMD = StdFunName[ t ] then it := StdFunParam[ t ];
		end;

		{ If a macro function, derive the number of parameters }
		{ from the number of ?s in the macro. }
		if it = 0 then begin
			Mac := SAttValue( Value_Macros , Cmd );
			if ( Mac = '' ) and ( Cmd <> '' ) and ( Cmd[1] = '&' ) then Mac := FindLocalMacro( cmd , GB , Source );
			if Mac <> '' then begin
				for t := 1 to Length( Mac ) do begin
					if Mac[ T ] = '?' then Inc( it );
				end;
			end;
		end;
		NeededParameters := it;
	end;
	function  GetSwapText: String;
		{ Grab the swap text from EVENT. If it's a function }
		{ that we just grabbed, better grab the parameters as }
		{ well. Oh, bother... }
	var
		it,cmd: String;
		N: Integer;
	begin
		{ Grab the beginning of the swap text. }
		it := ExtractWord( Event );

		{ Check to see if it's a function. Get rid of the - first }
		{ since it'll screw up our check. }
		cmd := it;
		if ( Length( cmd ) > 1 ) and ( cmd[1] = '-' ) then DeleteFirstChar( cmd );
		N := NeededParameters( cmd );
		While N > 0 do begin
			it := it + ' ' + GetSwapText();
			Dec( N );
		end;
		GetSwapText := it;
	end;
var
	Cmd,NewMacro,LastWord: String;
begin
	NewMacro := '';
	LastWord := '';

	while ProtoMacro <> '' do begin
		cmd := ExtractWord( ProtoMacro );
		if cmd = '?' then begin
			LastWord := GetSwapText;
			cmd := LastWord;
		end else if cmd = '!' then begin
			cmd := LastWord;
		end;
		NewMacro := NewMacro + ' ' + cmd;
	end;

	Event := NewMacro + ' ' + Event;
end;

Procedure InitiateLocalMacro( GB: GameBoardPtr; var Event , cmd: String; Source: GearPtr );
	{ Attempt to initiate a local macro. The local macro will be located }
	{ in Source, or its plot, or its story. }
var
	it: String;
begin
	it := FindLocalMacro( cmd , GB , Source );
	if it <> '' then InitiateMacro( GB , Source , Event , it );
end;


Function SV_Range( GB: GameBoardPtr; UID1,UID2: LongInt ): Integer;
	{ Locate the two gears pointed to by the UIDs, then calculate }
	{ the range between them. If one or both are NIL, or if one or }
	{ both are off the map, return 0. }
var
	M1,M2: GearPtr;
begin
	{ Error check. }
	if GB = Nil then Exit( 0 );

	M1 := LocateMekByUID( GB , UID1 );
	M2 := LocateMekByUID( GB , UID2 );

	if ( M1 <> Nil ) and OnTheMap( GB , M1 ) and ( M2 <> Nil ) and OnTheMap( GB , M2 ) then begin
		SV_Range := Range( GB , M1 , M2 );
	end else begin
		SV_Range := 0;
	end;
end;

Function SV_PCSkillVal( GB: GameBoardPtr; Skill,Stat: Integer ): Integer;
	{ Return the PC's base skill value. This used to be easy until those }
	{ stupid lancemates came along... Check all PCs and lancemates, and }
	{ return the highest value. }
var
	M: GearPtr;
	HiSkill,T: Integer;
begin
	{ Error check. }
	if GB = Nil then Exit( 0 );

	M := GB^.Meks;
	HiSkill := 0;
	while M <> Nil do begin
		T := NAttValue( M^.NA , NAG_Location , NAS_Team );
		if GearActive( M ) and ( ( T = NAV_DefPlayerTeam ) or ( T = NAV_LancemateTeam ) ) then begin
			T := SkillValue( M , Skill , Stat );
			if T > HiSkill then HiSkill := T;
		end;

		M := M^.Next;
	end;

	SV_PCSkillVal := HiSkill;
end;

Function SV_WorldID( GB: GameBoardPtr ): Integer;
	{ Return the ID number of the current world. }
var
	Scene: GearPtr;
begin
	Scene := FindWorld( GB , GB^.Scene );
	if Scene <> Nil then SV_WorldID := Scene^.S
	else SV_WorldID := 0;
end;



Function AV_ProcessConcert( GB: GameBoardPtr; AudienceSize,SkillTarget: Integer ): Integer;
	{ A concert is beginning! Yay! }
var
	PC: GearPtr;
begin
	PC := GG_LocatePC( GB );
	AV_ProcessConcert := DoConcert( GB , PC , AudienceSize , SkillTarget );
end;


Function ScriptValue( var Event: String; GB: GameBoardPtr; Scene: GearPtr ): LongInt;
	{ Normally, numerical values will be stored as constants. }
	{ Sometimes we may want to do algebra, or use the result of }
	{ scenario variables as the parameters for commands. That's }
	{ what this function is for. }
	{ *** IMPORTANT *** }
	{ When adding new functions, remember to add them to the InitiateMacro }
	{ procedure as well. }
	{ *** IMPORTANT *** }
var
	Old_Grabbed_Gear,PC: GearPtr;
	VCode,VC2: LongInt;
	SV: LongInt;
	SMsg,S2: String;
begin
	{ Save the grabbed gear, to restore it later. }
	Old_Grabbed_Gear := Grabbed_Gear;

	SMsg := UpCase(ExtractWord( Event ));
	SV := 0;

	{ Start by checking for value macros. }
	if SMsg = '' then begin
		{ An empty string is a bad thing. }
		SV := 0;
		DialogMsg( 'WARNING: Blank scriptvalue from ' + GearName( Scene ) );

	end else if SAttValue( Value_Macros , SMsg ) <> '' then begin
		{ Install the macro, then re-call this procedure to get }
		{ the results. }
		InitiateMacro( GB , scene , Event , SAttValue( Value_Macros , SMsg ) );
		SV := ScriptValue( Event , gb , scene );

	{ If the command starts with a &, this means it's a local macro. }
	end else if Smsg[1] = '&' then begin
		InitiateLocalMacro( GB , Event , SMsg , Scene );
		SV := ScriptValue( Event , gb , scene );

	end else if ( SMsg = 'GNATT' ) then begin
		{ Get a Numeric Attribute from the currently grabbed gear. }
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		if Grabbed_Gear <> Nil then begin
			SV := NAttValue( Grabbed_Gear^.NA , VCode , VC2 );
		end;

	end else if ( SMsg = 'GSTAT' ) then begin
		{ Get a Numeric Attribute from the currently grabbed gear. }
		VCode := ScriptValue( Event , GB , Scene );
		if ( Grabbed_Gear <> Nil ) then begin
			if ( VCode >= 1 ) and ( VCode <= NumGearStats ) then begin
				SV := Grabbed_Gear^.Stat[ VCode ];
			end;
		end;

	end else if ( SMsg = 'GV' ) then begin
		{ Get the V descriptor from the currently grabbed gear. }
		if ( Grabbed_Gear <> Nil ) then begin
			SV := Grabbed_Gear^.V;
		end;

	end else if ( SMsg = 'GS' ) then begin
		{ Get the S descriptor from the currently grabbed gear. }
		if ( Grabbed_Gear <> Nil ) then begin
			SV := Grabbed_Gear^.S;
		end;

	end else if ( SMsg = 'GSCENE' ) then begin
		{ Get the sceneID of the grabbed gear. }
		if ( Grabbed_Gear <> Nil ) then begin
			SV := FindSceneID( Grabbed_Gear , GB );
		end;

	end else if ( SMsg = 'WORLDID' ) then begin
		{ Return the ID of the current world. }
		SV := SV_WorldID( GB );

	end else if ( SMsg = 'FXPNEEDED' ) then begin
		{ Return how many faction XP points needed for next level. }
		VCode := ScriptValue( Event , GB , Scene );
		SV := ( VCode + 1 ) * 5;

	end else if ( SMsg = 'CONCERT' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := AV_ProcessConcert( GB , VCode , VC2 );

	end else if ( SMsg = 'MAPTILE' ) then begin
		{ Return the terrain of the requested map tile. }
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		if ( GB <> Nil ) and OnTheMap( GB , VCode , VC2 ) then begin
			SV := TileTerrain( GB , VCode , VC2 );
		end else begin
			SV := 0;
		end;

	end else if Attempt_Gear_Grab( SMsg , Event , GB , Scene ) then begin
		{ The correct Grabbed_Gear was set by the above call, }
		{ so just recurse to find the value we want. Am I looming }
		{ closer to functional programming or something? }
		SV := ScriptValue( Event , gb , scene );

	end else if ( SMsg = 'COMTIME' ) then begin
		{ Return the current combat time. }
		if ( GB <> Nil ) then begin
			SV := GB^.ComTime;
		end;

	end else if ( SMsg = 'NEXTDAY' ) then begin
		{ Return the start of the next day. }
		if ( GB <> Nil ) then begin
			SV := GB^.ComTime + 86400 - GB^.ComTime mod 86400;
		end;

	end else if ( SMsg = 'PCSKILLVAL' ) then begin
		{ Return the PC team's highest skill value. }
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := SV_PCSkillVal( GB , VCode , VC2 );

	end else if ( SMsg = 'SCENEID' ) then begin
		{ Return the current scene's unique ID. }
		{ Only do this if we're in the real scene! }
		SV := RealSceneID( GB^.Scene );

	end else if ( SMsg = 'REACT' ) then begin
		{ Return the current reaction score between PC & NPC. }
		if ( IntMenu <> Nil ) then begin
			if GB = Nil then begin
				SV := ReactionScore( Nil , I_PC , I_NPC );
			end else begin
				SV := ReactionScore( GB^.Scene , I_PC , I_NPC );
			end;
		end;

	end else if ( SMsg = 'SKROLL' ) then begin
		{ Return a skill roll from the PC. }
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		if ( VCode >= 1 ) and ( VCode <= NumSkill ) then begin
			SV := SkillRoll( GB , GG_LocatePC( GB ) , VCode , VC2 , 0 , 0 , True , True );
		end else begin
			DialogMsg( 'ERROR: Illegal Skill Roll ' + BStr( VCode ) + ': ' + Event );
			SV := 0;
		end;
		PC := GG_LocatePC( GB );
		if PC <> Nil then DoleSkillExperience( PC , VCode , 5 );

	end else if SMsg = 'PCMEKS' then begin
		SV := NumPCMeks( GB );

	end else if ( SMsg = 'THREAT' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := Calculate_Threat_Points( VCode , VC2 );

	end else if ( SMsg = 'FACBUDDIES' ) then begin
		{ Count the number of positive relationships the PC has }
		{ with members of the provided faction. }
		VCode := ScriptValue( Event , GB , Scene );
		SV := Count_Faction_Buddies( GB , VCode );

	end else if ( SMsg = '*' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := VCode * VC2;

	end else if ( SMsg = 'REWARD' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := Calculate_Reward_Value( GB , VCode , VC2 );

	end else if ( SMsg = 'PRICE' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := Calculate_Asking_Price( GB , VCode , VC2 );

	end else if ( SMsg = 'RANGE' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		VC2 := ScriptValue( Event , GB , Scene );
		SV := SV_Range( GB , VCode , VC2 );

	end else if ( SMsg = 'SKILLTAR' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		SV := BasicSkillTarget( VCode );

	end else if ( SMsg = 'HARDSKILLTAR' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		SV := HardSkillTarget( VCode );

	end else if ( SMsg = 'SOCSKILLTAR' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		SV := SocSkillTarget( GB , VCode );

	end else if SMsg = 'PCSCALE' then begin
		SV := FindPCScale( GB );

	end else if ( SMsg = 'ESCENE' ) then begin
		{ Find out what element to find the scene for. }
		if ( Scene <> Nil ) then begin
			VCode := ExtractValue( Event );

			{ Find out what plot we're dealing with. }
			Scene := PlotMaster( GB , Scene );

			if ( Scene <> Nil ) and ( VCode >= 1 ) and ( VCode <= Num_Plot_Elements ) then begin
				SV := ElementLocation( FindRoot( Scene ) , Scene , VCode , GB );
			end;
		end;

	end else if ( SMsg[1] = 'D' ) then begin
		{ Roll a die, return the result. }
		DeleteFirstChar( SMsg );
		Event := SMsg + ' ' + Event;
		VCode := ScriptValue( Event , GB , Scene );;
		if VCode < 1 then VCode := 1;
		SV := Random( VCode ) + 1;

	{ As a last resort, see if the first character shows up in the }
	{ scripts file. If so, use that. }
	end else if SAttValue( Value_Macros , SMsg[1] ) <> '' then begin
		{ Install the macro, then re-call this procedure to get }
		{ the results. }
		S2 := SMsg[ 1 ];
		DeleteFirstChar( SMsg );
		Event := SMsg + ' ' + Event;
		InitiateMacro( GB , scene , Event , SAttValue( Value_Macros , S2 ) );
		SV := ScriptValue( Event , gb , scene );

	end else if ( SMsg = '?PILOT' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		SV := FindRandomPilotID( GB , VCode );

	end else if ( SMsg = '?MECHA' ) then begin
		VCode := ScriptValue( Event , GB , Scene );
		SV := FindRandomMekID( GB , VCode );

	end else if ( SMsg[1] = 'T' ) and ( gb <> Nil ) then begin
		{ Return the number of gears on the provided team. }
		DeleteFirstChar( SMsg );
		VCode := ExtractValue( SMsg );
		SV := NumActiveMasters( GB , VCode );

	end else if ( SMsg[1] = '@' ) and ( gb <> Nil ) then begin
		{ Return the root gear of the gear indicated by the }
		{ rest of this expression. Return 0 if there's an error. }
		DeleteFirstChar( SMsg );
		VCode := ScriptValue( SMsg , gb , scene );
		if VCode <> 0 then SV := FindRootUID( GB , VCode )
		else SV := 0;


	end else if SMsg[1] = '-' then begin
		{ We want the negative of the value to follow. }
		DeleteFirstChar( SMsg );
		event := SMsg + ' ' + event;
		SV := -ScriptValue( event , gb , scene );

	end else begin
		{ No command was given, so this must be a constant value. }
		S2 := SMsg;
		SV := ExtractValue( SMsg );
		if ( SV = 0 ) and ( S2 <> '' ) and ( S2 <> '0' ) then begin
			DialogMsg( 'WARNING: Script value ' + S2 + ' in ' + GearName( scene ) );
			DialogMsg( 'CONTEXT: ' + event );
		end;
	end;

	{ Restore the grabbed gear before exiting. }
	Grabbed_Gear := Old_Grabbed_Gear;

	ScriptValue := SV;
end;

Function AS_GetString( Source: GearPtr; Key: String ): String;
	{ Check the SOURCE for a SAtt with the provided KEY. }
	{ If none can be found, search the default list for SOURCE's type. }
	{ Normally, getting a string attribute could be handled simply by the }
	{ SAttValue function. But, I had some trouble with my doors getting so }
	{ #$#@%! huge, so I decided to write the function as a space-saver. }
var
	msg: String;
begin
	if Source <> Nil then begin
		msg := SAttValue( Source^.SA , Key );
		if ( msg = '' ) and ( Source^.G = GG_MetaTerrain ) and ( Source^.S >= 1 ) and ( Source^.S <= NumBasicMetaTerrain ) then begin
			msg := SAttValue( Meta_Terrain_Scripts[ Source^.S ] , Key );
		end else if ( msg = '' ) and ( ( Source^.G = GG_Scene ) or ( Source^.G = GG_MetaScene ) or ( Source^.G = GG_World ) ) then begin
			msg := SAttValue( Default_Scene_Scripts , Key );
		end;
		if ( msg = '' ) and HeadMatchesString( 'CLUE_' , Key ) then begin
			msg := 'VMsg AS_YouHaveNoClue 0';
		end;
	end else begin
		msg := '';
	end;
	AS_GetString := msg;
end;

Function EncounterMapType( GB: GameBoardPtr; X,Y: Integer ): Integer;
	{ The PC has met an encounter at point X,Y on the current map. Return the }
	{ map generator which this encounter should use. }
begin
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and AStringHasBString( SAttValue( GB^.Scene^.SA , 'SPECIAL' ) , 'UNIFORM' ) then begin
		EncounterMapType := GB^.Scene^.Stat[ STAT_MapGenerator ];
	end else if GB <> Nil then begin
		EncounterMapType := TileTerrain( GB , X , Y )
	end else begin
		EncounterMapType := 1;
	end;
end;

Procedure AS_SetExit( GB: GameBoardPtr; RC: Integer );
	{ Several things need to be done when exiting the map. }
	{ This procedure should centralize most of them. }
var
	Dest,Src,SrcHome: GearPtr;
	T: Integer;
begin
	{ Only process this request if we haven't already set an exit. }
	if ( GB <> Nil ) and ( not GB^.QuitTheGame ) then begin
		GB^.QuitTheGame := True;
		GB^.ReturnCode := RC;
		if GB^.Scene <> Nil then begin
			if IsInvCom( GB^.SCene ) then begin
				SCRIPT_Gate_To_Seek := GB^.Scene^.S;
			end else begin
				SCRIPT_Gate_To_Seek := RealSceneID( GB^.Scene );
			end;

			Dest := FindActualScene( GB , RC );

			{ Set the return value for metascenes. }
			if ( Dest = Nil ) and ( SCRIPT_DynamicEncounter = Nil ) then begin
				{ If we've been asked to exit to a nonexistant scene, }
				{ try to re-enter the current scene again. }
				GB^.ReturnCode := FindGearScene( GB^.Scene , GB );

			end else if ( RC < 0 ) and ( Dest <> Nil ) then begin
				{ This is a metascene. Set the entrance value and the map generator }
				{ if appropriate. }
				if ( NAttValue( Dest^.NA , NAG_Narrative , NAS_EntranceScene ) = 0 ) and ( GB^.Scene^.G = GG_Scene ) then begin
					SetNAtt( Dest^.NA , NAG_Narrative , NAS_EntranceScene , GB^.Scene^.S );
				end;

				{ If the metascene has no map generator set, better set the map }
				{ generator from the tile the entrance is sitting upon. }
				if Dest^.Stat[ STAT_MapGenerator ] = 0 then begin
					Src := FindSceneEntrance( FindRoot( GB^.Scene ) , GB , RC );
					if ( Src <> Nil ) and OnTheMap( GB , Src ) and IsFoundAlongTrack( GB^.Meks , Src ) then begin
						Dest^.Stat[ STAT_MapGenerator ] := EncounterMapType( GB , NAttValue( Src^.NA , NAG_Location , NAS_X ) , NAttValue( Src^.NA , NAG_Location , NAS_Y ) );
						{ If this will make the encounter a space map, set the map-scroll tag. }
						if Dest^.Stat[ STAT_MapGenerator ] = TERRAIN_Space then Dest^.Stat[ STAT_SpaceMap ] := 1;
						SrcHome := GB^.Scene;
					end else begin
						{ Copy the entrance's map generator and hope for the best. }
						SrcHome := FindActualScene( GB , FindGearScene( Src , GB ) );
						if SrcHome = Nil then SrcHome := GB^.Scene;
						Dest^.Stat[ STAT_MapGenerator ] := SrcHome^.Stat[ STAT_MapGenerator ];
						{ If this will make the encounter a space map, set the map-scroll tag. }
						if Dest^.Stat[ STAT_MapGenerator ] = TERRAIN_Space then Dest^.Stat[ STAT_SpaceMap ] := 1;
					end;

					{ Also copy over the tileset + backdrop. }
					SetNAtt( Dest^.NA , NAG_SceneData , NAS_TileSet , NAttValue( SrcHome^.NA , NAG_SceneData , NAS_TileSet ) );
					SetNAtt( Dest^.NA , NAG_SceneData , NAS_Backdrop , NAttValue( SrcHome^.NA , NAG_SceneData , NAS_Backdrop ) );

					{ Copy the environmental effects from the parent scene. }
					for t := 1 to Num_Environment_Variables do begin
						SetNAtt( Dest^.NA , NAG_EnvironmentData , T , NAttValue( SrcHome^.NA , NAG_EnvironmentData , T ) );
					end;
				end;

			end else if ( Dest <> Nil ) and ( Dest^.G = GG_World ) then begin
				{ If we're exiting to the world, the gate to seek }
				{ should be the root scene. }
				Src := FindRootScene( GB^.Scene );
				if Src <> Nil then SCRIPT_Gate_To_Seek := Src^.S;
			end;
		end;
	end;
end;

Procedure ProcessExit( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ An exit command has been received. }
var
	SID: Integer;
begin
	SID := ScriptValue( Event , GB , Source );
	if ( SID < 0 ) and ( FindActualScene( GB , SID ) = Nil ) then begin
		DialogMsg( MsgString( 'AS_EXIT_NOMETASCENE' ) );
	end else begin
		AS_SetExit( GB , SID );
	end;
end;

Procedure ProcessForceExit( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ An exit command has been received and will not be denied. }
var
	SID: Integer;
begin
	SID := ScriptValue( Event , GB , Source );
	GB^.QuitTheGame := False;
	AS_SetExit( GB , SID );
end;

Procedure ProcessReturn( GB: GameBoardPtr );
	{ An exit command has been received. }
	Procedure ReturnToScene( DefaultSID: Integer );
		{ Return from the current scene to some place appropriate. If a }
		{ "ReturnTo" value has been stored, go there. Otherwise, return to }
		{ the default scene given as a parameter. }
	var
		RtS: Integer;	{ Return To Scene }
	begin
		if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
			RtS := NAttValue( GB^.Scene^.NA , NAG_Narrative , NAS_ReturnToScene );
		end else RtS := 0;
		if RtS <> 0 then begin
			SetNAtt( GB^.Scene^.NA , NAG_Narrative , NAS_ReturnToScene , 0 );
			AS_SetExit( GB , RtS );
		end else begin
			AS_SetExit( GB , DefaultSID );
		end;
	end;
begin
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and ( FindROot( GB^.Scene )^.G = GG_Adventure ) and ( FindROot( GB^.Scene )^.S = GS_ArenaCampaign ) then begin
		{ In an arena campaign, return always returns with an exit value of 1. }
		GB^.QuitTheGame := True;
		GB^.ReturnCode := 1;
	end else if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and ( GB^.Scene^.G = GG_MetaScene ) then begin
		ReturnToScene( NAttValue( GB^.Scene^.NA , NAG_Narrative , NAS_EntranceScene ) );

	end else if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and IsInvCom( GB^.Scene ) then begin
		if GB^.Scene^.S <> 0 then begin
			AS_SetExit( GB , GB^.Scene^.S );
			GB^.Scene^.S := 0;
			{ Eliminated old error check that doesn't appear to do anything anymore. In case of error, roll back to v0.420 or so. }
		end;
	end else if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and ( GB^.Scene^.Parent <> Nil ) and ( GB^.Scene^.Parent^.G = GG_Scene ) then begin
		ReturnToScene( GB^.Scene^.Parent^.S );
	end else begin
		ReturnToScene( 0 );
	end;
end;

Function FactionRankName( GB: GameBoardPtr; Source: GearPtr; FID,FRank: Integer ): String;
	{ Return the generic name of rank FRank from faction FID. }
var
	F: GearPtr;
	it: String;
begin
	{ First find the faction. }
	F := GG_LocateFaction( FID , GB , Source );

	{ Do range checking on the FRank score obtained. }
	if FRank < 0 then FRank := 0
	else if FRank > 8 then FRank := 8;

	{ If no faction was found, return the default rank title. }
	if F = Nil then begin
		it := MSgString( 'FacRank_' + BStr( FRank ) );
	end else begin
		{ First check the faction for a name there. }
		{ If the faction has no name set, use the default. }
		it := SAttValue( F^.SA , 'FacRank_' + BStr( FRank ) );
		if it = '' then it := MSgString( 'FacRank_' + BStr( FRank ) );
	end;

	FactionRankName := it;
end;

Function PCRankName( GB: GameBoardPtr; Source: GearPtr ): String;
	{ Return the name of the PC's rank with the PC's faction. }
	{ if the PC has no rank, return the basic string. }
var
	FID: Integer;
	A,F: GearPtr;
begin
	{ The PC's faction ID is located in the adventure gear, so }
	{ locate that first. }
	A := GG_LocateAdventure( GB , Source );
	if A <> Nil then begin
		{ The faction rank score is located in the faction itself. }
		{ So now, let's locate that. }
		FID := NAttValue( A^.NA , NAG_Personal , NAS_FactionID );
		F := GG_LocateFaction( FID , GB , Source );
		if F <> Nil then begin
			{ Call the general Faction Rank function. }
			PCRankName := FactionRankName( GB , Source , FID , NAttValue( A^.NA , NAG_Experience , NAS_FacLevel ) );
		end else begin
			{ No faction found. Return the default value. }
			PCRankName := MsgSTring( 'FACRANK_0' );
		end;
	end else begin
		{ Adventure not found. Return default "peon". }
		PCRankName := MsgSTring( 'FACRANK_0' );
	end;
end;

Function FormatMemoString( GB: GameBoardPtr; const Msg: String ): String;
	{ Add the name of the city to the memo. }
var
	RootScene: GearPtr;
begin
	RootScene := FindRootScene( GB^.Scene );
	if ( RootScene <> Nil ) and ( msg <> '' ) then begin
		FormatMemoString := GearName( RootScene ) + ': ' + msg;
	end else begin
		FormatMemoString := msg;
	end;
end;

Function PlotHintString( GB: GameBoardPtr; Source: GearPtr; N: LongInt; AddMemo: Boolean ): String;
	{ Determine hint string N for this plot. }
	{ Also store a rumor memo. }
	Function GenericHintString: String;
		{ We can't find a valid hint string for this plot. Just return }
		{ some generic advice. }
	begin
		GenericHintString := MsgString( 'GENERIC_HINT_STRING_' + BStr( Random( 6 ) + 1 ) );
	end;
var
	Plot: GearPtr;
	IsFound: Boolean;
	msg,memo_msg: String;
begin
	{ Find the plot. We need it if we are to proceed. }
	Plot := PlotMaster( GB , Source );
	if Plot = Nil then Exit( GenericHintString );

	{ Start looking for the correct message. }
	repeat
		msg := ScriptMessage( 'HINT_' + BStr( N ) , GB , Plot );
		DeleteWhiteSpace( msg );
		IsFound := True;
		if ( Length( msg ) > 1 ) and ( msg[1] = ':' ) then begin
			{ This is a redirect. }
			DeleteFirstChar( msg );
			N := ExtractValue( msg );
			IsFound := False;
		end;
	until IsFound;
	if msg = '' then PlotHintString := GenericHintString
	else begin
		{ We found a hint. Save the plot memo. }
		if AddMemo and ( Plot <> Nil ) and ( I_NPC <> Nil ) then begin
			memo_msg := ReplaceHash( MsgString( 'PLOT_HINT_MEMO' ) , GearName( I_NPC ) );
			memo_msg := FormatMemoString( GB , ReplaceHash( memo_msg , msg ) );
			SetSAtt( Plot^.SA , 'MEMO' + BStr( N ) + ' <' + memo_msg + '>' );
		end;
		PlotHintString := msg;
	end;
end;

Procedure FormatMessageString( var msg: String; gb: GameBoardPtr; Scene: GearPtr );
	{ There are a number of formatting commands which may be used }
	{ in an arenascript message string. }
var
	S0,S1,w: String;
	ID,ID2: LongInt;
	Part: GearPtr;
begin
	S0 := msg;
	S1 := '';

	while S0 <> '' do begin
		w := ExtractWord( S0 );

		if ( W <> '' ) and ( W[1] = '\' ) then begin
			W := UpCase( W );
			if W = '\MEK' then begin
				{ Insert the name of a specified gear. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := LocateMekByUID( GB , ID );
				if Part <> Nil then begin
					W := GearName( Part );
				end else begin
					W := 'ERROR!!!';
				end;

			end else if W = '\PILOT' then begin
				{ Insert the name of a specified gear. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := LocateMekByUID( GB , ID );
				if Part <> Nil then begin
					W := PilotName( Part );
				end else begin
					W := 'ERROR!!!';
				end;

			end else if W = '\ELEMENT' then begin
				{ Insert the name of a specified plot element. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := PlotMaster( GB , Scene );
				if Part <> Nil then begin
					W := ElementName( FindRoot( GB^.Scene ) , Part , ID , GB );
				end;

			end else if W = '\NARRATIVE' then begin
				{ Insert the name of a specified plot element. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := StoryMaster( GB , Scene );
				if Part <> Nil then begin
					W := ElementName( FindRoot( GB^.Scene ) , Part , ID , GB );
				end;

			end else if W = '\PERSONA' then begin
				{ Insert the name of a specified persona. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := GG_LocateNPC( ID , GB , Scene );
				W := GEarName( Part );

			end else if W = '\HINT' then begin
				{ Insert the hint of a specified plot element. }
				ID := ScriptValue( S0 , GB , Scene );
				W := PlotHintString( GB , Scene , ID , False );

			end else if W = '\HINT_MEMO' then begin
				{ Insert the hint of a specified plot element and store a memo about it. }
				ID := ScriptValue( S0 , GB , Scene );
				W := PlotHintString( GB , Scene , ID , True );

			end else if W = '\ITEM' then begin
				{ Insert the name of a specified item. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := GG_LocateItem( ID , GB , Scene );
				W := GEarName( Part );

			end else if W = '\ITEM_DESC' then begin
				{ Insert the description of a specified item. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := GG_LocateItem( ID , GB , Scene );
				if Part <> Nil then W := SAttValue( Part^.SA , 'ITEM_DESC' )
				else W := 'ERROR: can''t find ITEM_DESC for item ' + BStr( ID );

			end else if W = '\ITEM_HISTORY' then begin
				{ Insert the description of a specified item. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := GG_LocateItem( ID , GB , Scene );
				if Part <> Nil then W := SAttValue( Part^.SA , 'ITEM_HISTORY' )
				else W := 'ERROR: can''t find ITEM_DESC for item ' + BStr( ID );

			end else if W = '\ITEM_USAGE' then begin
				{ Insert the description of a specified item. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := GG_LocateItem( ID , GB , Scene );
				if Part <> Nil then W := SAttValue( Part^.SA , 'ITEM_USAGE' )
				else W := 'ERROR: can''t find ITEM_DESC for item ' + BStr( ID );

			end else if W = '\SECRET' then begin
				{ Insert a plot secret here. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := GG_LocateItem( ID , GB , Scene );
				if Part <> Nil then W := ScriptMessage( 'msg' , GB , Part )
				else W := 'ERROR: can''t find MSG for secret ' + BStr( ID );

			end else if W = '\FACTION' then begin
				{ Insert the name of a specified faction. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := GG_LocateFaction( ID , GB , Scene );
				W := GEarName( Part );

			end else if W = '\FACTION_DESIG' then begin
				{ Insert the name of a specified faction. }
				ID := ScriptValue( S0 , GB , Scene );
				Part := GG_LocateFaction( ID , GB , Scene );
				if Part <> Nil then W := SAttValue( Part^.SA , 'DESIG' )
				else W := 'ERROR:Faction_Not_Found';

			end else if W = '\SCENE' then begin
				{ Insert the name of a specified scene. }
				ID := ScriptValue( S0 , GB , Scene );
				W := SceneName( GB , ID , False );

			end else if W = '\EXACT_SCENE' then begin
				{ Insert the name of a specified scene. }
				ID := ScriptValue( S0 , GB , Scene );
				W := SceneName( GB , ID , True );

			end else if W = '\VAL' then begin
				{ Insert the value of a specified variable. }
				ID := ScriptValue( S0 , GB , Scene );
				W := BStr( ID );

			end else if W = '\PC' then begin
				{ The name of the PC. }
				W := GearName( LocatePilot( GG_LocatePC( GB ) ) );

			end else if W = '\PCJOB' then begin
				{ The name of the PC. }
				Part := LocatePilot( GG_LocatePC( GB ) );
				if Part <> Nil then W := LowerCase( SAttValue( Part^.SA , 'JOB' ) );

			end else if W = '\CHATNPC' then begin
				{ The name of the Chat NPC. }
				W := GearName( I_NPC );

			end else if W = '\CHATNPCMECHA' then begin
				{ The name of the Chat NPC's mecha. }
				Part := FindRoot( I_NPC );
				if ( Part <> Nil ) and ( Part^.G = GG_Mecha ) then begin
					W := FullGearName( Part );
				end else begin
					W := MsgString( 'MECHA' );
				end;

			end else if W = '\SOURCE' then begin
				{ The name of the PC. }
				W := GearName( Scene );

			end else if W = '\OPR' then begin
				{ Object Pronoun }
				ID := ScriptValue( S0 , GB , Scene );
				if ID = 0 then begin
					Part := LocatePilot( GG_LocatePC( GB ) );
				end else begin
					Part := GG_LocateNPC( ID , GB , Scene );
				end;
				if Part <> Nil then begin
					W := MsgString( 'OPR_' + BStr( NAttValue( Part^.NA , NAG_CharDescription , NAS_Gender ) ) );
				end else begin
					W := 'it';
				end;

			end else if W = '\SPR' then begin
				{ Object Pronoun }
				ID := ScriptValue( S0 , GB , Scene );
				if ID = 0 then begin
					Part := LocatePilot( GG_LocatePC( GB ) );
				end else begin
					Part := GG_LocateNPC( ID , GB , Scene );
				end;
				if Part <> Nil then begin
					W := MsgString( 'SPR_' + BStr( NAttValue( Part^.NA , NAG_CharDescription , NAS_Gender ) ) );
				end else begin
					W := 'it';
				end;

			end else if W = '\PPR' then begin
				{ Object Pronoun }
				ID := ScriptValue( S0 , GB , Scene );
				if ID = 0 then begin
					Part := LocatePilot( GG_LocatePC( GB ) );
				end else begin
					Part := GG_LocateNPC( ID , GB , Scene );
				end;
				if Part <> Nil then begin
					W := MsgString( 'PPR_' + BStr( NAttValue( Part^.NA , NAG_CharDescription , NAS_Gender ) ) );
				end else begin
					W := 'its';
				end;

			end else if W = '\OFFSPRING' then begin
				{ Son or Daughter, depending on gender }
				ID := ScriptValue( S0 , GB , Scene );
				if ID = 0 then begin
					Part := LocatePilot( GG_LocatePC( GB ) );
				end else begin
					Part := GG_LocateNPC( ID , GB , Scene );
				end;
				if Part <> Nil then begin
					if NAttValue( Part^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then W := MsgString( 'SON' )
					else W := MsgString( 'DAUGHTER' );
				end else begin
					W := 'sprog';
				end;

			end else if W = '\SIBLING' then begin
				{ Sister or Brother, depending on gender }
				ID := ScriptValue( S0 , GB , Scene );
				if ID = 0 then begin
					Part := LocatePilot( GG_LocatePC( GB ) );
				end else begin
					Part := GG_LocateNPC( ID , GB , Scene );
				end;
				if Part <> Nil then begin
					if NAttValue( Part^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then W := MsgString( 'BROTHER' )
					else W := MsgString( 'SISTER' );
				end else begin
					W := 'sib';
				end;

			end else if W = '\RANK' then begin
				{ The faction rank of the PC. }
				W := PCRankName( GB , Scene );

			end else if W = '\FACRANK' then begin
				{ A generic faction rank, not nessecarilt belonging }
				{ to the PC. }
				ID := ScriptValue( S0 , GB , Scene );
				ID2 := ScriptValue( S0 , GB , Scene );

				W := FactionRankName( GB , Scene , ID , ID2 );

			end else if W = '\DATE' then begin
				ID := ScriptValue( S0 , GB , Scene );

				W := TimeString( ID );
			end;
		end;

		if ( W <> '' ) and ( S1 <> '' ) and ( IsPunctuation( W[1] ) or ( S1[Length(S1)] = '$' ) or ( S1[Length(S1)] = '@' ) ) then begin
			S1 := S1 + W;
		end else begin
			S1 := S1 + ' ' + W;
		end;

	end;

	msg := S1;
end;

Function ConditionAccepted( Event: String; gb: GameBoardPtr; Source: GearPtr ): Boolean;
	{ Run a conditional script. }
	{ If it returns 'ACCEPT', this function returns true. }
var
	T: String;	{ The trigger to be used. }
begin
	{ Error check - an empty condition is always true. }
	if Event = '' then Exit( True );

	{ Generate the trigger. }
	T := 'null';

	{ Execute the provided event. }
	InvokeEvent( Event , GB , Source , T );

	{ If the trigger was changed, that counts as a success. }
	ConditionAccepted := T = 'ACCEPT';
end;

Function ScriptMessage( msg_label: String; GB: GameBoardPtr; Source: GearPtr ): String;
	{ Retrieve and format a message from the source. }
var
	N,T: Integer;
	C,msg: String;
	MList,M: SAttPtr;
begin
	{ Create the list of possible strings. }
	MList := Nil;
	C := AS_GetString( Source , 'C' + msg_label );

	{ The master condition must be accepted in order to continue. }
	if ConditionAccepted( C , GB , Source ) and ( Source <> Nil ) then begin
		msg := AS_GetString( Source , msg_label );
		if msg <> '' then StoreSAtt( MList , msg );

		msg := msg_label + '_';
		N := NumHeadMatches( msg , Source^.SA );
		for t := 1 to N do begin
			M := FindHeadMatch( msg , Source^.SA , T);
			C := SAttValue( Source^.SA , 'C' + RetrieveAPreamble( M^.info ) );
			if ConditionAccepted( C , GB , Source ) then begin
				StoreSAtt( MList , RetrieveAString( M^.Info ) );
			end;
		end;
	end;

	{ If any messages were found, pick one. }
	if MList <> Nil then begin
		msg := SelectRandomSAtt( MList )^.Info;
		DisposeSAtt( MList );
		FormatMessageString( msg , gb , source );
	end else begin
		msg := '';
	end;

	ScriptMessage := Msg;
end;

Function NPCScriptMessage( const msg_label: String; GB: GameBoardPtr; NPC, Source: GearPtr ): String;
	{ Get a script message, temporarily setting the I_NPC to the provided NPC. }
var
	Temp_NPC: GearPtr;
	msg: String;
begin
	Temp_NPC := I_NPC;
	I_NPC := NPC;
	msg := ScriptMessage( msg_label , GB , Source );
	I_NPC := Temp_NPC;
	NPCScriptMessage := Msg;
end;

Function GetTheMessage( head: String; idnum: Integer; GB: GameBoardPtr; Scene: GearPtr ): String;
	{ Just call the SCRIPTMESSAGE with the correct label. }
begin
	GetTheMessage := ScriptMessage( head + BStr( idnum ) , GB , Scene );
end;

Procedure ProcessPrint( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then print the specified message. }
var
	msg: String;
	id: Integer;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := getTheMessage( 'msg', id , GB , Scene );
	if msg <> '' then DialogMsg( msg );
end;

Procedure ProcessAlert( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then print the specified message. }
var
	id: Integer;
	msg: String;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := getTheMessage( 'msg', id , GB , Scene );
	if msg <> '' then begin
		YesNoMenu( GB , msg , '' , '' );
		DialogMsg( msg );
	end;
end;

Procedure ProcessGMonologue( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ An NPC is about to say something. }
var
	id: Integer;	{ Message ID }
	msg: String;
	NPC: GearPtr;
begin
	{ Record the NPC, and find the message number. }
	NPC := Grabbed_Gear;
	id := ScriptValue( Event , GB , Source );

	{ Locate the NPC and the message. }
	if NPC <> Nil then begin
		msg := NPCScriptMessage( 'msg' + BStr( id ) , GB , NPC , Source );
		if ( msg <> '' ) then begin
			Monologue( GB , NPC , msg );
			{ The monologue will do its own output. }
		end;
	end;
end;

Procedure ProcessAddDebriefing( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Add a message for a certain NPC to speak during the debriefing. }
	{ Note that the first word in the debriefing message will be the ID of the }
	{ character meant to deliver the line. }
var
	cid,id: Integer;	{ Character ID, Message ID }
	NPC: GearPtr;
	msg: String;
begin
	{ Find the two needed numeric valies. }
	cid := ScriptValue( Event , GB , Source );
	id := ScriptValue( Event , GB , Source );

	{ Locate the message. }
	NPC := GG_LocateNPC( CID , GB , Source );
	msg := NPCScriptMessage( 'msg' + BStr( id ) , GB , NPC , Source );
	if ( msg <> '' ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		SetSAtt( GB^.Scene^.SA , ARENAREPORT_Personal + ' <' + BStr( cid ) + ' ' + msg + '>' );
	end;
end;

Procedure ProcessMemo( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then store the specified message. }
var
	id: Integer;
	msg: String;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := FormatMemoString( GB , getTheMessage( 'msg', id , GB , Scene ) );
	if ( Scene <> Nil ) then SetSAtt( Scene^.SA , 'MEMO <' + msg + '>' );
end;

Procedure ProcessPMemo( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Locate and then store the specified message in the plot gear, }
	{ along with an ID number. }
var
	id,plotid: LongInt;
	msg: String;
begin
	plotid := ScriptValue( Event , GB , Source );
	id := ScriptValue( Event , GB , Source );
	msg := FormatMemoString( GB , getTheMessage( 'msg', id , GB , Source ) );
	Source := PlotMaster( GB , Source );
	if ( Source <> Nil ) then SetSAtt( Source^.SA , 'MEMO' + BStr( plotid ) + ' <' + msg + '>' );
end;

Procedure ProcessSMemo( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then store the specified message in the story gear. }
var
	id: Integer;
	msg: String;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := FormatMemoString( GB , getTheMessage( 'msg', id , GB , Scene ) );
	Scene := StoryMaster( GB , Scene );
	if ( Scene <> Nil ) then SetSAtt( Scene^.SA , 'MEMO <' + msg + '>' );
end;

Procedure ProcessQMemo( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Locate and then store the specified message. }
var
	qid,mid: LongInt;
	msg: String;
begin
	{ Determine the Quest ID and the Message ID. }
	qid := ScriptValue( Event , GB , Source );
	mid := ScriptValue( Event , GB , Source );
	msg := FormatMemoString( GB , getTheMessage( 'msg', mid , GB , Source ) );

	{ Store this message in the adventure. }
	Source := GG_LocateAdventure( GB , Source );

	{ Quest memos look like regular memos but their tag is followed by an underscore }
	{ and the Quest ID. }
	if ( Source <> Nil ) then SetSAtt( Source^.SA , 'MEMO_' + BStr( qid ) + ' <' + msg + '>' );
end;

Procedure ProcessEMail( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then store the specified message. }
var
	msg: String;
	PC: GearPtr;
	id: Integer;
begin
	id := ScriptValue( Event , GB , Scene );
	if id <> 0 then begin
		msg := getTheMessage( 'msg' , id , GB , Scene );
		if ( Scene <> Nil ) and ( msg <> '' ) then SetSAtt( Scene^.SA , 'EMAIL <' + msg + '>' );
		PC := GG_LocatePC( GB );
		if ( PC <> Nil ) and HasPCommCapability( PC , PCC_EMail ) and ( msg <> '' ) then DialogMsg( MsgString( 'AS_EMail' ) );
	end else if Scene <> Nil then begin
		SetSAtt( Scene^.SA , 'EMAIL <>' );
	end;
end;


Procedure ProcessHistory( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then store the specified message. }
var
	id: Integer;
	msg: String;
	Adv: GearPtr;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := getTheMessage( 'msg' , id , GB , Scene );
	Adv := GG_LocateAdventure( GB , Scene );
	if ( msg <> '' ) and ( Adv <> Nil ) then AddSAtt( Adv^.SA , 'HISTORY' , msg );
end;

Procedure ProcessVictory( GB: GameBoardPtr );
	{ Sum up the entire campaign in a list of SAtts, then print to }
	{ a file. }
const
	InvStr = '+';
	SubStr = '>';
	Num_Significant_Relationships = 5;
	Significant_Relationship: Array [1..Num_Significant_Relationships] of Integer = (
		NAV_ArchEnemy, NAV_ArchAlly, NAV_Friend, NAV_Family, NAV_Lover
	);
var
	VList,SA: SAttPtr;
	PC,Fac,Adv: GearPtr;
	T,V: LongInt;
	msg,fname: String;
	Procedure CheckAlongPath( Part: GearPtr; TabPos,Prefix: String );
		{ CHeck along the path specified, adding info to }
		{ the victory list. }
	var
		msg: String;
	begin
		while Part <> Nil do begin
			if ( Part^.G <> GG_AbsolutelyNothing ) then begin
				StoreSAtt( VList , tabpos + prefix + GearName( Part ) );
				msg := ExtendedDescription( GB , Part );
				if msg <> '' then StoreSAtt( VList , tabpos + ' ' + msg );
			end;
			if Part^.G <> GG_Cockpit then begin
				CheckAlongPath( Part^.InvCom , TabPos + '  ' , InvStr );
				CheckAlongPath( Part^.SubCom , TabPos + '  ' , SubStr );
			end;
			Part := Part^.Next;
		end;
	end;{CheckAlongPath}
begin
	{ Initialize our list to NIL. }
	VList := Nil;

	DialogMsg( MsgString( 'HISTORY_AnnounceVictory' ) );

	repeat
		CombatDisplay( GB );
		DoFlip;
	Until IsMoreKey( RPGKey );

	{ Locate the PC, add PC-specific information. }
	PC := LocatePilot( GG_LocatePC( GB ) );
	Adv := FindRoot( GB^.Scene );
	if PC <> Nil then begin
		{ Store the  name. }
		fname := GearName( PC );
		StoreSAtt( VList , fname );
		StoreSAtt( VList , JobAgeGenderDesc( PC ) );
		StoreSAtt( VList , TimeString( GB^.ComTime ) );
		StoreSAtt( VList , ' ' );


		{ Store the stats. }
		for t := 1 to 8 do begin
			msg := MsgString( 'StatName_' + BStr( t ) );
			while Length( msg ) < 20 do msg := msg + ' ';
			msg := msg + BStr( PC^.Stat[ T ] );
			V := ( PC^.Stat[ T ] + 2 ) div 3;
			if V > 7 then V := 7;
			msg := msg + '  (' + MsgString( 'STATRANK' + BStr( V ) ) + ')';
			StoreSAtt( VList , msg );
		end;
		StoreSAtt( VList , ' ' );

		{ Add info on the PC's XP and credits. }
		msg := MsgString( 'INFO_XP' );
		V := NAttVAlue( PC^.NA , NAG_Experience , NAS_TotalXP );
		msg := msg + ' ' + BStr( V );
		StoreSAtt( VList , msg );

		msg := MsgString( 'INFO_XPLeft' );
		V := V - NAttVAlue( PC^.NA , NAG_Experience , NAS_SpentXP );
		msg := msg + ' ' + BStr( V );
		StoreSAtt( VList , msg );

		msg := MsgString( 'INFO_Credits' );
		V := NAttVAlue( PC^.NA , NAG_Experience , NAS_Credits );
		msg := msg + ' ' + BStr( V );
		StoreSAtt( VList , msg );

		{ Store the faction and rank. }
		Fac := GG_LocateFaction( NAttValue( PC^.NA , NAG_Personal , NAS_FactionID ) , GB , Nil );
		if Fac <> Nil then begin
			msg := ReplaceHash( MsgString( 'HISTORY_FACTION' ) , PCRankName( GB , Nil ) );
			msg := ReplaceHash( msg , GearName( Fac ) );
			StoreSAtt( VList , msg );
			StoreSAtt( VList , ' ' );
		end;

		{ Store the relationships and fatalities. }
		if Adv <> Nil then begin
			for t := 1 to Num_Significant_Relationships do begin
				V := CountGearsByIDTag( Adv , NAG_Relationship , 0 , Significant_Relationship[ t ] ) + CountGearsByIDTag( GB^.Meks , NAG_Relationship , 0 , Significant_Relationship[ t ] );
				if V > 1 then begin
					StoreSAtt( VList , ReplaceHash( MsgSTring( 'HISTORY_RELATIONS_' + BStr( T ) ) , BStr( V ) ) );
				end else if V = 1 then begin
					StoreSAtt( VList , MsgSTring( 'HISTORY_RELATION_' + BStr( T ) ) );
				end;
			end;

			for t := 1 to Num_Fatality_Types do begin
				V := NAttValue( Adv^.NA , NAG_Narrative , Fatality_Base + T );
				if V > 1 then begin
					StoreSAtt( VList , ReplaceHash( MsgSTring( 'HISTORY_FATALITIES_' + BStr( T ) ) , BStr( V ) ) );
				end else if V = 1 then begin
					StoreSAtt( VList , MsgSTring( 'HISTORY_FATALITY_' + BStr( T ) ) );
				end;
			end;
		end;
		StoreSAtt( VList , ' ' );

		{ Store the personality traits. }
		for t := 1 to Num_Personality_Traits do begin
			V := NATtValue( PC^.NA , NAG_CharDescription , -T );
			if V <> 0 then begin
				Msg := ReplaceHash( MsgString( 'HISTORY_Traits' ) , PersonalityTraitDesc( T , V ) );
				Msg := ReplaceHash( msg , BStr( Abs( V ) ) );
				StoreSAtt( VList , msg );
			end;
		end;
		StoreSAtt( VList , ' ' );

		{ Store the talents. }
		V := 0;
		for t := 1 to NumTalent do begin
			if HasTalent( PC , T ) then begin
				msg := MsgString( 'TALENT' + BStr( T ) );
				StoreSAtt( VList , msg );
				msg := '  ' + MsgString( 'TALENTDESC' + BStr( T ) );
				StoreSAtt( VList , msg );
				inc( V );
			end;
		end;
		if V > 0 then StoreSAtt( VList , ' ' );

		{ Store the skill ranks. }
		for t := 1 to NumSkill do begin
			V := NATtValue( PC^.NA , NAG_Skill , T );
			if V > 0 then begin
				Msg := ReplaceHash( MsgString( 'HISTORY_Skills' ) , MsgString( 'SKILLNAME_' + BStr( T ) ) );
				Msg := ReplaceHash( msg , BStr( V ) );
				StoreSAtt( VList , msg );
			end;
		end;
		StoreSAtt( VList , ' ' );

		{ Store info on the PC's body and equipment. }
		CheckAlongPath( PC^.InvCom , '  ' , '+' );
		CheckAlongPath( PC^.SubCom , '  ' , '>' );
		StoreSAtt( VList , ' ' );

	end else begin
		{ No PC found, so filename will be "out.txt". }
		fname := 'out';
	end;

	if Adv <> Nil then begin
		{ Once the PC wins, unlock the adventure. }
		Adv^.V := 1;
		SA := Adv^.SA;
		while SA <> Nil do begin
			if UpCase( Copy( SA^.Info , 1 , 7 ) ) = 'HISTORY' then begin
				StoreSAtt( VList , RetrieveAString( SA^.Info ) );
			end;
			SA := SA^.Next;

		end;
	end;

	{ Add info on the PC's mechas. }
	PC := GB^.Meks;
	while PC <> Nil do begin
		if ( NAttValue( PC^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and ( PC^.G = GG_Mecha ) then begin
			StoreSAtt( VList , FullGearName( PC ) );

			CheckAlongPath( PC^.InvCom , '  ' , '+' );
			CheckAlongPath( PC^.SubCom , '  ' , '>' );

			StoreSAtt( VList , ' ' );
		end;
		PC := PC^.Next;
	end;

	SaveStringList( FName + '.txt' , VList );
	MoreText( VList , 1 );
	DisposeSAtt( VList );
end;

Procedure ProcessNews( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then store the specified message. }
var
	msg: String;
	id: Integer;
begin
	id := ScriptValue( Event , GB , Scene );
	msg := getTheMessage( 'msg' , id , GB , Scene );
	if ( msg <> '' ) and ( Scene <> Nil ) then SetSAtt( Scene^.SA , 'NEWS <' + msg + '>' );
end;

Procedure ProcessValueMessage( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ Locate and then print the specified message. }
var
	msg: String;
	V: LongInt;
begin
	{ FInd the message we're supposed to print. }
	msg := ExtractWord( Event );
	msg := MsgString( msg );

	{ Find the value to insert. }
	V := ScriptValue( Event , GB , Scene );

	{ Insert the value. }
	msg := ReplaceHash( msg , BStr( V ) );

	if msg <> '' then DialogMsg( msg );
end;

Procedure ProcessSay( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Locate and then print the specified message. }
var
	id: Integer;
	msg: String;
begin
	{ Error check- if not in a conversation, call the PRINT }
	{ routine instead. }
	if IntMenu = Nil then begin
		ProcessPrint( Event , GB , Source );
		Exit;
	end;

	id := ScriptValue( Event , GB , Source );
	msg := getTheMessage( 'msg' , id , GB , Source );
	if msg <> '' then begin
		CHAT_Message := msg;
	end;
end;

Procedure ProcessSayPlotMsg( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Locate and then print the specified message. }
	Procedure PauseConversation();
		{ Before moving on to the rest of the conversation, take a }
		{ minute to read this message. }
	var
		RPM: RPGMenuPtr;
	begin
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
		AddRPGMenuItem( RPM , MsgString( 'Continue' ), -1 );
		ASRD_GameBoard := GB;
		CHAT_React := ReactionScore( GB^.Scene , I_PC , I_NPC );
		SelectMenu( RPM , @InteractRedraw );
		DisposeRPGMenu( RPM );
	end;
var
	id: Integer;
	plot: GearPtr;
	msg: String;
begin
	{ Error check- if not in a conversation, call the PRINT }
	{ routine instead. }
	if IntMenu = Nil then begin
		ProcessPrint( Event , GB , Source );
		Exit;
	end;

	id := ScriptValue( Event , GB , Source );
	plot := PlotMaster( GB , Source );
	msg := getTheMessage( 'msg' , id , GB , plot );
	if msg <> '' then begin
		YesNoMenu( GB , REplaceHash( MsgString( 'Debrief_Intro' ) , PilotName( I_NPC ) ) , '' , '' );
		CHAT_Message := msg;
		PauseConversation();
	end;
end;


Procedure ProcessAddChat( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Add a new item to the IntMenu. }
var
	N: Integer;
	Msg: String;
begin
	{ Error check - this command can only work if the IntMenu is }
	{ already allocated. }
	if ( IntMenu <> Nil ) and ( Source <> Nil ) then begin
		{ First, determine the prompt number. }
		N := ScriptValue( Event , GB , Source );

		msg := getthemessage( 'PROMPT' , N , GB , Source );
		DeleteWhiteSpace( msg );
		if Msg <> '' then begin
			AddRPGMenuItem( IntMenu , Msg , N );
			RPMSortAlpha( IntMenu );
		end;
	end;
end;

Procedure ProcessSayAnything( GB: GameBoardPtr );
	{ Print a random message in the interact message area. }
	{ New- if there are any memes floating about, select one of those for the message. }
	Procedure CleanMemes( City: GearPtr );
		{ Most memes come with a "best before" date. If they are not revealed to the player }
		{ by this time, they get deleted. This can be useful for things like news events. }
	var
		M,M2: GearPtr;
	begin
		M := City^.SubCom;
		while M <> Nil do begin
			M2 := M^.Next;
			if ( M^.G = GG_Meme ) and ( NAttValue( M^.NA , NAG_MemeData , NAS_MemeTimeLimit ) > 0 ) and ( NAttValue( M^.NA , NAG_MemeData , NAS_MemeTimeLimit ) < GB^.ComTime ) then begin
				RemoveGear( City^.SubCom , M );
			end;
			M := M2;
		end;
	end;
	Function NumMeme( City: GearPtr ): Integer;
		{ Return the number of active memes in this city. }
	var
		M: GearPtr;
		N: Integer;
	begin
		if City = Nil then Exit( 0 );
		M := City^.SubCom;
		N := 0;
		while M <> Nil do begin
			if ( M^.G = GG_Meme ) or ( M^.G = GG_CityMood ) then Inc( N );
			M := M^.Next;
		end;
		NumMeme := N;
	end;
	Function GetMeme( City: GearPtr; N: Integer ): GearPtr;
		{ Return the requested meme. }
	var
		S,M: GearPtr;
	begin
		S := City^.SubCom;
		M := Nil;
		while ( S <> Nil ) and ( N > 0 ) do begin
			if ( S^.G = GG_Meme ) or ( S^.G = GG_CityMood ) then begin
				Dec( N );
				if N = 0 then M := S;
			end;
			S := S^.Next;
		end;
		GetMeme := M;
	end;
var
	N: Integer;
	City,Meme: GearPtr;
	msg: String;
begin
	City := FindRootScene( GB^.Scene );
	{ Before checking for memes, delete any expired memes that might still be kicking around. }
	if City <> Nil then CleanMemes( City );

	N := NumMeme( City );
	if ( I_NPC <> Nil ) and ( I_PC <> Nil ) and ( GB <> Nil ) and ( ReactionScore( GB^.Scene , I_PC , I_NPC ) <= -Random( 10 ) ) then begin
		{ If talking to someone who dislikes you, you're most likely to get }
		{ a brushoff. }
		msg := MsgString( 'BUZZOFF_' + BStr( Random( 5 ) + 1 ) );

	end else if N > 0 then begin
		Meme := GetMeme( City , Random( N ) + 1 );

		msg := ScriptMessage( 'Msg' , GB , Meme );

		if msg = '' then begin
			msg := IdleChatter
		end else begin
			{ A message was successfully extracted from this meme. Increment the }
			{ message counter and maybe delete it. }
			AddNAtt( Meme^.NA , NAG_MemeData , NAS_NumViews , 1 );
			if ( Meme^.G = GG_Meme ) and ( NAttValue( Meme^.NA , NAG_MemeData , NAS_NumViews ) >= NAttValue( Meme^.NA , NAG_MemeData , NAS_MaxMemeViews ) ) then begin
				RemoveGear( City^.SubCom , Meme );
			end;
		end;
	end else begin
		msg := IdleChatter;
	end;

	CHAT_Message := msg;
end;

Procedure ProcessActivateMeme( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Activate a meme. The meme should be stored in SOURCE, the plot master of SOURCE, or the }
	{ story master of SOURCE. If the named meme cannot be found this will generate an error. }
var
	MemeID,SceneID: LongInt;
	Meme,Scene: GearPtr;
begin
	{ Get the meme ID and the scene ID. }
	MemeID := ScriptValue( event , GB , source );
	SceneID := ScriptValue( event , GB , source );
	Meme := GG_LocateItem( MemeID , GB , Source );
	Scene := FindRootScene( FindActualScene( GB , SceneID ) );

	if ( Meme = Nil ) or ( Meme^.G <> GG_Meme ) then begin
		DialogMsg( 'ERROR: Meme ' + BStr( MemeID ) + ' not found. Context: ' + Event );
	end else if Scene = Nil then begin
		DialogMsg( 'ERROR: ActivateMeme failed, scene ' + BStr( SceneID ) + ' not found. Context: ' + Event );
	end else begin
		DelinkGearForMovement( GB , Meme );
		InsertSubCom( Scene , Meme );

		{ If this meme has a time limit, set that now. }
		if NAttValue( Meme^.NA , NAG_MemeData , NAS_MemeTimeLimit ) > 0 then begin
			AddNAtt( Meme^.NA , NAG_MemeData , NAS_MemeTimeLimit , GB^.ComTime );
		end;
	end;
end;

Procedure ProcessGSetNAtt( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ The script is going to assign a value to one of the scene }
	{ variables. }
var
	G,S: Integer;
	V: LongInt;
begin
	{ Find the variable ID number and the value to assign. }
	G := ScriptValue( event , GB , scene );
	S := ScriptValue( event , GB , scene );
	V := ScriptValue( event , GB , scene );
	if Debug_On then dialogmsg( 'GAddNAtt: ' + GearName( Grabbed_Gear ) + ' ' + BStr( G ) + '/' + BStr( S ) + '/' + BStr( V ) );

	if Grabbed_Gear <> Nil then SetNAtt( Grabbed_Gear^.NA , G , S , V );
end;

Procedure ProcessGAddNAtt( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ The script is going to add a value to one of the scene }
	{ variables. }
var
	G,S: Integer;
	V: LongInt;
begin
	{ Find the variable ID number and the value to assign. }
	G := ScriptValue( event , GB , scene );
	S := ScriptValue( event , GB , scene );
	V := ScriptValue( event , GB , scene );
	if Debug_On then dialogmsg( 'GAddNAtt: ' + GearName( Grabbed_Gear ) + ' ' + BStr( G ) + '/' + BStr( S ) + '/' + BStr( V ) );

	if Grabbed_Gear <> Nil then AddNAtt( Grabbed_Gear^.NA , G , S , V );
end;

Procedure ProcessGSetStat( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ The script is going to add a value to one of the scene }
	{ variables. }
var
	Slot,Value: Integer;
begin
	{ Find the variable ID number and the value to assign. }
	Slot := ScriptValue( event , GB , scene );
	Value := ScriptValue( event , GB , scene );

	if Grabbed_Gear <> Nil then Grabbed_Gear^.Stat[ Slot ] := Value;
end;

Procedure ProcessGAddStat( var Event: String; GB: GameBoardPtr; Scene: GearPtr );
	{ The script is going to add a value to one of the scene }
	{ variables. }
var
	Slot,Value: Integer;
begin
	{ Find the variable ID number and the value to assign. }
	Slot := ScriptValue( event , GB , scene );
	Value := ScriptValue( event , GB , scene );

	if Grabbed_Gear <> Nil then Grabbed_Gear^.Stat[ Slot ] := Grabbed_Gear^.Stat[ Slot ] + Value;
end;

Procedure ProcessGSetSAtt( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Store a string attribute in the grabbed gear. }
var
	Key,Info: String;
begin
	Key := ExtractWord( Event );
	Info := ExtractWord( Event );
	if Source <> Nil then Info := AS_GetString( Source , Info );
	FormatMessageString( info , GB , source );
	DeleteWhiteSpace( info );
	if Grabbed_Gear <> Nil then SetSAtt( Grabbed_Gear^.SA , Key + ' <' + Info + '>' );
end;

Procedure IfSuccess( var Event: String );
	{ An IF call has generated a "TRUE" result. Just get rid of }
	{ any ELSE clause that the event string might still be holding. }
var
	cmd: String;
begin
	{ Extract the next word from the script. }
	cmd := ExtractWord( Event );

	{ If the next word is ELSE, we have to also extract the label. }
	{ If the next word isn't ELSE, better re-assemble the line... }
	if UpCase( cmd ) = 'ELSE' then ExtractWord( Event )
	else Event := cmd + ' ' + Event;
end;

Procedure IfFailure( var Event: String; Scene: GearPtr );
	{ An IF call has generated a "FALSE" result. See if there's }
	{ a defined ELSE clause, and try to load the next line. }
var
	cmd: String;
begin
	{ Extract the next word from the script. }
	cmd := ExtractWord( Event );

	if UpCase( cmd ) = 'ELSE' then begin
		{ There's an else clause. Attempt to jump to the }
		{ specified script line. }
		cmd := ExtractWord( Event );
		Event := AS_GetString( Scene , CMD );

	end else begin
		{ There's no ELSE clause. Just cease execution of this }
		{ line by setting it to an empty string. }
		Event := '';
	end;
end;

Procedure ProcessIfGInPlay( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Return true if the Grabbed_Gear is on the map and operational. }
	{ Return false otherwise. }
begin
	if ( Grabbed_Gear <> Nil ) and OnTheMap( GB , Grabbed_Gear ) and GearOperational( Grabbed_Gear ) and IsFoundAlongTrack( GB^.Meks , FindRoot( Grabbed_Gear ) ) then begin
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessIfGOK( var Event: String; Source: GearPtr );
	{ If the grabbed gear is OK, count as true. If it is destroyed, }
	{ or if it can't be found, count as false. }
begin
	if ( Grabbed_Gear <> Nil ) and NotDestroyed( Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfGDead( var Event: String; Source: GearPtr );
	{ If the grabbed gear is dead or nil, count as true. }
begin
	if ( Grabbed_Gear = Nil ) or Destroyed( Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfGSexy( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ If the grabbed gear is sexy to the PC, count as true. If it is not, }
	{ or if it can't be found, count as false. }
var
	PC: GearPtr;
begin
	PC := GG_LOcatePC( GB );
	if ( Grabbed_Gear <> Nil ) and ( PC <> Nil ) and IsSexy( PC , Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfGSealed( var Event: String; Source: GearPtr );
	{ If the grabbed gear is EnviroSealed, count as true. If not, }
	{ count as false. }
begin
	if ( Grabbed_Gear <> Nil ) and IsEnviroSealed( Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfGArchEnemy( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ If the grabbed gear is an enemy of the PC, or belongs to a faction that's }
	{ an enemy of the PC, count as true. }
var
	Adv: GearPtr;
begin
	Adv := GG_LOcateAdventure( GB , Source );
	if ( Grabbed_Gear <> Nil ) and ( Adv <> Nil ) and IsArchEnemy( Adv , Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfGArchAlly( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ If the grabbed gear is an ally of the PC, or belongs to a faction that's }
	{ an ally of the PC, count as true. }
var
	Adv: GearPtr;
begin
	Adv := GG_LOcateAdventure( GB , Source );
	if ( Grabbed_Gear <> Nil ) and ( Adv <> Nil ) and IsArchAlly( Adv , Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfGHasSkill( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ If the grabbed gear has the skill, count as true. If it doesn't, }
	{ or if it can't be found, count as false. }
var
	Skill: Integer;
begin
	Skill := ScriptValue( Event , GB , Source );
	if ( Grabbed_Gear <> Nil ) and HasSkill( Grabbed_Gear , Skill ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfGCanJoinLance( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Return true if the Grabbed_Gear can join the PC's lance, or FALSE otherwise. }
	{ Please note that the NPC must be in play in order to join the lance. }
var
	PC: GearPtr;
begin
	PC := GG_LocatePC( GB );
	if ( Grabbed_Gear <> Nil ) and OnTheMap( GB , Grabbed_Gear ) and GearOperational( Grabbed_Gear ) and IsFoundAlongTrack( GB^.Meks , FindRoot( Grabbed_Gear ) ) and CanJoinLance( GB , PC , Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessIfMechaCanEnterScene( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Return true if the PC's mecha can enter the requested scene. }
	{ Return false otherwise. }
var
	PC,Mek,Scene: GearPtr;
	SceneID: Integer;
begin
	{ Locate the PC, the PC's mecha, and the target scene. }
	PC := FindRoot( GG_LocatePC( GB ) );
	if ( PC <> Nil ) then begin
		if PC^.G = GG_Mecha then Mek := PC
		else Mek := FindPilotsMecha( GB^.Meks , PC );
	end;
	SceneID := ScriptValue( Event , GB , Source );
	Scene := FindActualScene( GB , SceneID );

	if ( PC <> Nil ) and ( Mek <> Nil ) and ( Scene <> Nil ) and NotDestroyed( Mek ) and MekCanEnterScene( Mek , Scene ) then begin
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessIfMeritBadge( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Return true if the PC has the requested merit badge. }
	{ Return false otherwise. }
var
	Adv: GearPtr;
	Badge: Integer;
begin
	Badge := ScriptValue( Event , GB , Source );

	Adv := GG_LocateAdventure( GB , Source );

	if ( Adv <> Nil ) and HasMeritBadge( Adv , Badge ) then begin
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;


Procedure ProcessIfTeamCanSeeGG( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ If the grabbed gear can be seen by the requested team, return TRUE. }
var
	Team: Integer;
begin
	Team := ScriptValue( Event , GB , Source );
	if ( Grabbed_Gear <> Nil ) and TeamCanSeeTarget( GB , Team , Grabbed_Gear ) then begin
		IfSuccess( Event );
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfFaction( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Check to see if the requested faction is active or not. }
var
	FID: Integer;
	Fac: GearPtr;
begin
	{ Locate the requested Faction ID, and from there locate }
	{ the faction gear itself. }
	FID := ScriptValue( Event , GB , Source );
	Fac := GG_LocateFaction( FID , GB , Source );

	{ If the faction was found, see whether or not it's active. }
	if Fac <> Nil then begin
		if FactionIsInactive( Fac ) then IfFailure( Event , Source )
		else IfSuccess( Event );

	{ If said faction cannot be found, it counts as a failure. }
	end else IfFailure( Event , Source );
end;

Procedure ProcessIfStoryless( var Event: String; Source: GearPtr );
	{ Return true if the SOURCE has no story linked. }
	{ Return false otherwise. }
var
	story: GearPtr;
begin
	if Source <> Nil then begin
		story := Source^.InvCom;
		while ( story <> Nil ) and ( story^.G <> GG_Story ) do story := story^.Next;

		if Story = Nil then begin
			IfSuccess( Event );
		end else begin
			IfFailure( Event , Source );
		end;
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessIfEqual( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Two values are supplied as the arguments for this procedure. }
	{ If they are equal, that's a success. }
var
	a,b: LongInt;
begin
	{ Determine the two values. }
	A := ScriptValue( Event , gb , Source );
	B := ScriptValue( Event , gb , Source );

	if A = B then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfNotEqual( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Two values are supplied as the arguments for this procedure. }
	{ If they are not equal, that's a success. }
var
	a,b: LongInt;
begin
	{ Determine the two values. }
	A := ScriptValue( Event , gb , Source );
	B := ScriptValue( Event , gb , Source );

	if A <> B then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfGreater( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Two values are supplied as the arguments for this procedure. }
	{ If A > B, that's a success. }
var
	a,b: LongInt;
begin
	{ Determine the two values. }
	A := ScriptValue( Event , gb , Source );
	B := ScriptValue( Event , gb , Source );

	if A > B then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfKeyItem( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Process TRUE if the specified key item is in the posession of the PC. }
	{ We'll define this as being in the posession of any member of team }
	{ one... Process FALSE if it isn't. }
var
	NID: Integer;
	FoundTheItem: Boolean;
	PC: GearPtr;
begin
	{ Start by assuming FALSE, then go looking for it. }
	FoundTheItem := False;

	{ Find out what Key Item we're looking for. }
	NID := ScriptValue( Event , GB , Source );

	if ( GB <> Nil ) and ( NID <> 0 ) then begin
		{ Search through every gear on the map. }
		PC := GB^.Meks;

		while PC <> Nil do begin
			{ If this gear belongs to the player team, check it }
			{ for the wanted item. }
			if NAttValue( PC^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
				{ Set FOUNDTHEITEM to TRUE if the specified key item }
				{ is the PC gear itself, if it's in the subcoms of the PC, }
				{ or if it's somewhere in the inventory of the PC. }
				if NAttValue( PC^.NA , NAG_Narrative , NAS_NID ) = NID then FoundTheItem := True
				else if SeekGearByIDTag( PC^.SubCom , NAG_Narrative , NAS_NID , NID ) <> Nil then FoundTheItem := True
				else if SeekGearByIDTag( PC^.InvCom , NAG_Narrative , NAS_NID , NID ) <> Nil then FoundTheItem := True;
			end;

			{ Move to the next gear to check. }
			PC := PC^.Next;
		end;
	end;

	{ Finally, do something appropriate depending upon whether or not }
	{ the item was found. }
	if FoundTheItem then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfGHasItem( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Process TRUE if the specified key item is in the posession of the grabbed gear. }
var
	NID: Integer;
	FoundTheItem: Boolean;
begin
	{ Start by assuming FALSE, then go looking for it. }
	FoundTheItem := False;

	{ Find out what Key Item we're looking for. }
	NID := ScriptValue( Event , GB , Source );

	if ( Grabbed_Gear <> Nil ) and ( NID <> 0 ) then begin
		if NAttValue( Grabbed_Gear^.NA , NAG_Narrative , NAS_NID ) = NID then FoundTheItem := True
		else if SeekGearByIDTag( Grabbed_Gear^.SubCom , NAG_Narrative , NAS_NID , NID ) <> Nil then FoundTheItem := True
		else if SeekGearByIDTag( Grabbed_Gear^.InvCom , NAG_Narrative , NAS_NID , NID ) <> Nil then FoundTheItem := True;
	end;

	{ Finally, do something appropriate depending upon whether or not }
	{ the item was found. }
	if FoundTheItem then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfYesNo( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Two values are supplied as the arguments for this procedure. }
	{ If they are equal, that's a success. }
var
	Desc,YesPrompt,NoPrompt: String;
	it: Boolean;
	ID: Integer;
begin
	{ Find all the needed messages. }
	id := ScriptValue( Event , GB , Source );
	Desc := GetTheMessage( 'msg' , id , GB , Source );
	id := ScriptValue( Event , GB , Source );
	YesPrompt := GetTheMessage( 'msg' , id , GB , Source );
	id := ScriptValue( Event , GB , Source );
	NoPrompt := GetTheMessage( 'msg' , id , GB , Source );

	it := YesNoMenu( GB , Desc , YesPrompt , NoPrompt );

	if it then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessIfScene( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Return TRUE if the current scene matches the provided }
	{ description, or FALSE otherwise. }
var
	Desc: String;
begin
	Desc := ExtractWord( Event );
	if Source <> Nil then Desc := AS_GetString( Source , Desc );

	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and PartMatchesCriteria( SceneDesc( GB^.Scene ) , Desc ) then begin
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessIfSafeArea( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Return TRUE if the current scene is a Safe Area (as determined }
	{ by the function of the same name), or FALSE otherwise. }
begin
	if ( GB <> Nil ) and IsSafeArea( GB ) then begin
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessIfSkillTest( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Return TRUE if the PC makes the requested skill roll, or FALSE otherwise. }
	{ If the PC has already attempted this skill roll, he can't succeed unless }
	{ he's improved his skill level. }
var
	PC: GearPtr;
	Skill,SkStat,SkTar,SkRank,SkRoll: Integer;
begin
	PC := GG_LocatePC( GB );
	Skill := ScriptValue( Event , GB , Source );
	SkStat := ScriptValue( Event , GB , Source );
	SkRank := SkillRank( PC , Skill ) + 1;
	SkTar := ScriptValue( Event , GB , Source );
	if ( Source <> Nil ) and ( SkRank <= NAttValue( Source^.NA , NAG_SkillCounter , Skill ) ) then begin
		IfFailure( Event , Source );
	end else begin
		SkRoll := SkillRoll( GB , PC , Skill , SkStat , SkTar , 0 , True , True );
		if ( SkRoll >= SkTar ) then begin
			IfSuccess( Event );
		end else begin
			if Source <> Nil then SetNAtt( Source^.NA , NAG_SkillCounter , Skill , SkRank );
			IfFailure( Event , Source );
		end;
	end;
end;

Procedure ProcessIfUSkillTest( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Return TRUE if the PC makes the requested skill roll, or FALSE otherwise. }
var
	Skill,SkStat,SkTar,SkRoll: Integer;
begin
	Skill := ScriptValue( Event , GB , Source );
	SkStat := ScriptValue( Event , GB , Source );
	SkTar := ScriptValue( Event , GB , Source );
	SkRoll := SkillRoll( GB , GG_LocatePC( GB ) , Skill , SkStat , SkTar , 0 , IsSafeArea( GB ) , True );
	if SkRoll >= SkTar then begin
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessIfNoObjections( var Event: String; gb: GameBoardPtr; Source: GearPtr );
	{ Run a trigger through the narrative gears. }
	{ If none of them BLOCK it, then count the result as TRUE. }
var
	T: String;	{ The trigger to be used. }
	Adv: GearPtr;
begin
	{ Generate the trigger, which is in the same format as for COMPOSE. }
	{ It's a trigger label plus a numeric value. }
	T := ExtractWord( Event );
	T := T + BStr( ScriptValue( Event, GB, Source ) );

	{ Check the trigger along the adventure's invcoms, }
	{ where all the narrative components should be located. }
	Adv := GG_LocateAdventure( GB , Source );
	if Adv <> Nil then begin
		CheckTriggerAlongPath( T, GB, Adv^.InvCom , False );
	end;

	{ If the trigger wasn't blocked, that counts as a success. }
	if T <> '' then IfSuccess( Event )
	else IfFailure( Event , Source );
end;

Procedure ProcessTeamOrders( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ This procedure is used to assign a behavior type to }
	{ every master unit on the designated team. }
const
	OrderParams: Array [0..NumAITypes] of Byte = (
		0,2,1,0,0,1
	);
var
	Team: Integer;
	OrderName: String;
	T,OrderCode: Integer;
	Mek: GearPtr;
	P: Array [1..2] of Integer;
begin
	{ Record the team number. }
	Team := ScriptValue( Event , gb , Source );

	{ Figure out what order we're supposed to be assigning. }
	OrderName := UpCase( ExtractWord( Event ) );
	OrderCode := -1;
	for t := 0 to NumAITypes do begin
		if OrderName = AI_Type_Label[ t ] then OrderCode := T;
	end;

	{ If a valid order was received, process it. }
	if OrderCode > -1 then begin
		for t := 1 to OrderParams[ OrderCode ] do P[T] := ScriptValue( Event , gb , Source );

		{ Go through each of the meks and, if they are part }
		{ of the specified team, assign the specified order. }
		Mek := gb^.Meks;
		while Mek <> Nil do begin
			if NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = Team then begin
				SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Orders , OrderCode );

				{ DEFAULT BEHAVIOR- If number of params = 1, assume it to be a mek ID. }
				{ If number of params = 2, assume it to be a map location. }
				if OrderParams[ OrderCode ] = 1 then begin
					SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ATarget , P[1] );
				end else if OrderParams[ OrderCode ] = 2 then begin
					SetNAtt( Mek^.NA , NAG_Location , NAS_GX , P[1] );
					SetNAtt( Mek^.NA , NAG_Location , NAS_GY , P[2] );
				end;
			end;
			Mek := Mek^.Next;
		end;
	end;
end;

Procedure ProcessCompose( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A new item is going to be added to the scene list. }
var
	Trigger,Ev2: String;
	P: Integer;
begin
	if Source = Nil then exit;

	{ Extract the values we need. }
	Trigger := ExtractWord( Event );
	P := ScriptValue( Event , GB , Source );
	Ev2 := AS_GetString( Source , ExtractWord( Event ) );

	StoreSAtt( Source^.SA , Trigger + BStr( P ) + ' <' + Ev2 + '>' );
end;

Procedure ProcessNewChat( GB: GameBoardPtr );
	{ Reset the dialog menu with the standard options. }
begin
	{ Error check - make sure the interaction menu is active. }
	if IntMenu = Nil then begin
		Exit;

	{ If there are any menu items currently in the list, get rid }
	{ of them. }
	end else if IntMenu^.FirstItem <> Nil then begin
		ClearMenu( IntMenu );
	end;

	AddRPGMenuItem( IntMenu , MsgString( 'NEWCHAT_Goodbye' ) , -1 );
	if ( GB <> Nil ) and OnTheMap( GB , FindRoot( I_NPC ) ) and IsFoundAlongTrack( GB^.Meks , FindRoot( I_NPC ) ) then begin
		{ Only add the JOIN command if this NPC is in the same scene as the PC. }
		if ( I_PC <> Nil ) and HasTalent( I_PC , NAS_Camaraderie ) then begin
			if ( I_NPC <> Nil ) and ( NAttValue( I_NPC^.NA , NAG_Relationship , 0 ) >= NAV_Friend ) and ( NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then AddRPGMenuItem( IntMenu , MsgString( 'NEWCHAT_Join' ) , CMD_Join );
		end else begin
			if ( I_NPC <> Nil ) and ( NAttValue( I_NPC^.NA , NAG_Relationship , 0 ) >= NAV_ArchAlly ) and ( NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then AddRPGMenuItem( IntMenu , MsgString( 'NEWCHAT_Join' ) , CMD_Join );
		end;
	end;
	if ( I_NPC <> Nil ) and ( NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and ( NAttValue( I_NPC^.NA , NAG_CharDescription , NAS_CharType ) <> NAV_TempLancemate ) and IsSafeArea( GB ) and IsSubCom( GB^.Scene ) then AddRPGMenuItem( IntMenu , MsgSTring( 'NEWCHAT_QuitLance' ) , CMD_Quit );
	if not ( OnTheMap( GB , FindRoot( I_NPC ) ) and IsFoundAlongTrack( GB^.Meks , FindRoot( I_NPC ) ) ) then AddRPGMenuItem( IntMenu , MsgString( 'NewChat_WhereAreYou' ) , CMD_WhereAreYou );
	if ( NAttValue( I_NPC^.NA , NAG_Personal , NAS_RumorRecharge ) < GB^.ComTime ) and ( NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then AddRPGMenuItem( IntMenu , MsgString( 'NEWCHAT_AskAboutRumors' ) , CMD_AskAboutRumors );
	RPMSortAlpha( IntMenu );
end;

Procedure ProcessEndChat;
	{ End this conversation by clearing the menu. }
begin
	{ Error check - make sure the interaction menu is active. }
	if IntMenu = Nil then begin
		Exit;
	end else begin
		ClearMenu( IntMenu );
	end;
end;

Procedure RevertPersona( var Event: String; GB: GameBoardPtr; var Source: GearPtr );
	{ We don't wanna use this persona anymore. Attempt to locate }
	{ I_NPC's original persona, and start the GREETING event. }
var
	Adv,Persona2: GearPtr;
begin
	{ Error check- if there's no defined NPC, }
	{ we can't very well be expected to locate a persona. }
	if ( I_NPC = Nil ) or ( Source = Nil ) or ( Source^.G <> GG_Persona ) then begin
		Event := '';
		Exit;
	end;

	{ Locate the adventure and hopefully the persona. }
	Adv := GG_LocateAdventure( GB , Source );
	if Adv <> Nil then begin
		Persona2 := SeekGear( Adv , GG_Persona , NAttValue( I_NPC^.NA , NAG_Personal , NAS_CID ) , False );

		if ( Persona2 <> Nil ) and ( Persona2 <> Source ) then begin
			{ Change the event script to the requested line. }
			Event := AS_GetString( Persona2 , 'GREETING' );
			I_Persona := Persona2;
			Source := Persona2;
		end else begin
			{ A different persona wasn't found. Do nothing. }
			Event := 'NewChat SayAnything';
		end;
	end else begin
		{ The adventure wasn't found. Do nothing. }
		Event := 'NewChat SayAnything';
	end;
end;

Procedure ProcessGoto( var Event: String; Source: GearPtr );
	{ Attempt to jump to a different line of the script. }
	{ If no line label is provided, or if the label can't be }
	{ found, this procedure sets EVENT to an empty string. }
var
	destination: String;
begin
	{ Error check- if there's no defined source, we can't very }
	{ well jump to another line, can we? }
	if Source = Nil then begin
		Event := '';
		Exit;
	end;

	destination := ExtractWord( Event );
	if destination <> '' then begin
		{ Change the event script to the requested line. }
		Event := AS_GetString( Source , destination );
	end else begin
		{ No label was provided. Just return a blank line. }
		Event := '';
	end;
end;

Procedure ProcessSeekTerr( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Assign a value to SCRIPT_Terrain_To_Seek. }
var
	Terrain: Integer;
begin
	Terrain := ScriptValue( event , GB , Source );
	SCRIPT_Terrain_To_Seek := Terrain;
end;

Procedure CantOpenBusiness( var Event: String; GB: GameBoardPtr );
	{ The business can't be opened. Print an error message and }
	{ cancel the rest of the event. }
var
	Scene: Integer;
	msg: String;
begin
	Event := '';
	Scene := FindSceneID( I_NPC , GB );
	if Scene <> 0 then begin
		msg := ReplaceHash( msgString( 'CantOpenShop_WithScene' ) , SceneName( GB , Scene , True ) );
	end else begin
		msg := msgString( 'CantOpenShop' );
	end;
	CHAT_Message := msg;
end;

Procedure ProcessShop( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Retrieve the WARES line, then pass it all on to the OpenShop }
	{ procedure. }
var
	Wares: String;
begin
	{ Retrieve the WARES string. }
	Wares := ExtractWord( Event );
	if Wares <> '' then begin
		{ Change the event script to the requested line. }
		Wares := AS_GetString( Source , Wares );
	end;

	{ Only open the shop if the NPC is on the current map. }
	if IsFoundAlongTrack( GB^.Meks , FindRoot( I_NPC ) ) then begin
		{ Pass all info on to the OPENSHOP procedure. }
		OpenShop( GB , I_PC , I_NPC , Wares );
	end else begin
		{ Call the error handler. }
		CantOpenBusiness( Event , GB );
	end;
end;

Procedure ProcessSchool( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Retrieve the WARES line, then pass it all on to the OpenSchool }
	{ procedure. }
var
	Wares: String;
begin
	{ Retrieve the WARES string. }
	Wares := ExtractWord( Event );
	if Wares <> '' then begin
		{ Change the event script to the requested line. }
		Wares := AS_GetString( Source , Wares );
	end;

	{ Only open the shop if the NPC is on the current map. }
	if IsFoundAlongTrack( GB^.Meks , FindRoot( I_NPC ) ) then begin
		{ Pass all info on to the OPENSHOP procedure. }
		OpenSchool( GB , I_PC , I_NPC , Wares );
	end else begin
		{ Call the error handler. }
		CantOpenBusiness( Event , GB );
	end;
end;

Procedure ProcessExpressDelivery( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Call the ExpressDelivery procedure. }
begin
	{ Only open the shop if the NPC is on the current map. }
	if IsFoundAlongTrack( GB^.Meks , FindRoot( I_NPC ) ) then begin
		{ Pass all info on to the ExpressDelivery procedure. }
		ExpressDelivery( GB , I_PC , I_NPC );
	end else begin
		{ Call the error handler. }
		CantOpenBusiness( Event , GB );
	end;
end;

Procedure ProcessShuttle( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Call the ExpressDelivery procedure. }
begin
	{ Only open the shop if the NPC is on the current map. }
	if IsFoundAlongTrack( GB^.Meks , FindRoot( I_NPC ) ) then begin
		{ Pass all info on to the ExpressDelivery procedure. }
		ShuttleService( GB , I_PC , I_NPC );
	end else begin
		{ Call the error handler. }
		CantOpenBusiness( Event , GB );
	end;
end;

Procedure ProcessEndPlot( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ This particular plot is over- mark it for deletion. }
	{ First, though, check to see if there are any subcomponents that }
	{ need to be moved around. }
begin
	{ If we have a valid SOURCE, attempt to end the plot. }
	if ( Source <> Nil ) then begin
		{ It's possible that our SOURCE is a PERSONA rather than }
		{ a PLOT, so if SOURCE isn't a PLOT move to its parent. }
		Source := PlotMaster( GB , Source );
		if ( Source <> Nil ) and ( Source^.G = GG_Plot ) and ( NAttValue( Source^.NA , NAG_Narrative , NAS_PlotID ) > 0 ) then EndPlot( GB , Source^.Parent , Source );
		SetTrigger( GB , 'UPDATE' );
	end;
end;

Procedure ProcessEndPlotsByConID( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ End all plots associated with the requested mood. }
var
	CID: LongInt;
	Adv,Plot: GearPtr;
begin
	{ Determine the ControllerID. }
	CID := ScriptValue( Event , GB , Source );

	{ Locate the adventure. }
	Adv := GG_LocateAdventure( GB , Source );

	{ If we have a valid ADV, attempt to end the attached plots. }
	if ( Adv <> Nil ) then begin
		Plot := Adv^.InvCom;

		while Plot <> Nil do begin
			if ( Plot^.G = GG_Plot ) and ( NAttValue( Plot^.NA , NAG_Narrative , NAS_PlotID ) > 0 ) and ( NAttValue( Plot^.NA , NAG_Narrative , NAS_ControllerID ) = CID ) then begin
				EndPlot( GB , Adv , Plot );
			end;

			Plot := Plot^.Next;
		end;

		{ Finally, set an UPDATE trigger. }
		SetTrigger( GB , 'UPDATE' );
	end;
end;

Procedure CleanUpStoryPlots( GB: GameBoardPtr; Story: GearPtr );
	{ Give a CLEANUP trigger to all the story plots, then move the }
	{ plots which survive to the adventure invcoms. }
var
	T: String;
	Part,P2,Adv: GearPtr;
begin
	{ Send a CLEANUP trigger to the invcoms. }
	{ This should erase all the plots that want to be erased, }
	{ and leave all the plots which want to be moved. }
	T := 'CLEANUP';
	CheckTriggerAlongPath( T , GB , Story^.InvCom , False );

	{ Check whatever is left over. }
	Part := Story^.InvCom;
	Adv := GG_LocateAdventure( GB , STory );
	while Part <> Nil do begin
		P2 := Part^.Next;

		if Part^.G = GG_Plot then begin
			DelinkGear( Story^.InvCom , Part );
			if Adv <> Nil then begin
				InsertInvCom( Adv , Part );
			end else begin
				DisposeGear( Part );
			end;
		end;

		Part := P2;
	end;
end;

Procedure ProcessEndStory( GB: GameBoardPtr; Source: GearPtr );
	{ This particular story is over- mark it for deletion. }
	{ First, though, pass a CLEANUP trigger to any subcomponents that }
	{ may need to be cleaned up. }
begin
	Source := StoryMaster( GB , Source );
	if ( Source <> Nil ) and ( Source^.G = GG_Story ) then begin
		CleanupStoryPlots( GB , Source );

		{ Mark the story for deletion. }
		Source^.G := GG_AbsolutelyNothing;

		SetTrigger( GB , 'UPDATE' );
	end;
end;

Procedure ProcessPurgeStory( GB: GameBoardPtr; Source: GearPtr );
	{ Eliminate all plots from this story. }
begin
	{ If we have a valid SOURCE, check the invcoms. }
	if ( Source <> Nil ) and ( Source^.G = GG_Story ) then begin
		{ Send a CLEANUP trigger to the invcoms, }
		{ then move the survivors to the Adventure. }
		CleanupStoryPlots( GB , Source );

		SetTrigger( GB , 'UPDATE' );
	end;
end;

Procedure ProcessPumpNews( GB: GameBoardPtr );
	{ Once every six hours or so, check through all the QUESTs and MOODs and }
	{ see if they've got anything new to do. PumpNews will trigger the PUMPNEWS }
	{ script of the subcoms of every city in this world. }
var
	T: String;
	world,city: GearPtr;
begin
	{ Error check }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;

	{ Start by locating the world. }
	world := FindWorld( GB , GB^.Scene );
	if world = Nil then Exit;

	T := 'PUMPNEWS';

	{ Go through the world's cities, springing the trigger at each. }
	city := world^.SubCom;
	while city <> Nil do begin
		if City^.G = GG_Scene then begin
			CheckTriggerAlongPath( T , GB , City^.SubCom , False );
		end;
		city := city^.Next;
	end;
end;

Procedure ProcessTReputation( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Something has happened to affect the PC's reputation. }
	{ Record the change. }
var
	T,R,V: Integer;
begin
	{ Error check - this procedure only works if GB is defined. }
	if ( GB = Nil ) then Exit;

	T := ScriptValue( Event , GB , Source );
	R := ScriptValue( Event , GB , Source );
	V := ScriptValue( Event , GB , Source );

	SetTeamReputation( GB , T , R , V );
end;

Procedure ProcessLoseRenown( GB: GameBoardPtr );
	{ The PC has just done something to lose face. Reduce the RENOWN attribute }
	{ by 25% of its total or 5 points, whichever is more severe. }
var
	PC: GearPtr;
	Renown: Integer;
begin
	PC := LocatePilot( GG_LocatePC( GB ) );
	if PC <> Nil then begin
		Renown := NAttValue( PC^.NA , NAG_CHarDescription , NAS_Renowned );
		if Renown > 23 then begin
			AddReputation( PC , NAS_Renowned , -( Renown div 4 ) );
		end else begin
			AddReputation( PC , NAS_Renowned , -5 );
		end;
	end;
end;

Procedure ProcessMechaPrize( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ The player has just won a mecha. Cool! }
var
	Factions,FName,msg: String;
	Renown,Theme,ModPoints: Integer;
	MList,Mek,PC,Adv: GearPtr;
begin
	{ ERROR CHECK - We need the gameboard to exist!!! }
	if GB = Nil then Exit;

	{ Find the adventure; it'll be needed later. }
	Adv := GG_LocateAdventure( GB , Source );

	{ First, find the file name of the mecha file to look for. }
	{ Because this mecha is gonna be randomly determined we'll need some information }
	{ for that. First, determine the factions whose mecha will be considered. Second, }
	{ we need the renown level the mecha will be appropriate for. }
	Factions := ExtractWord( Event );
	if Source <> Nil then begin
		Factions := ScriptMessage( Factions , GB , Source );
	end;
	Renown := ScriptValue( Event , GB , Source );
	Theme := ScriptValue( Event , GB , Source );
	ModPoints := ScriptValue( Event , GB , Source );

	{ Call the random mecha picker. }
	FName := SelectMechaByFactionAndRenown( Factions , Renown );

	{ Attempt to load the suggested mecha. }
	MList := LoadGearPattern( FName , Design_Directory );

	{ Next confirm that something was loaded. }
	if MList <> Nil then begin
		{ Something was loaded. Yay! Pick one of the gears }
		{ at random, clone it, stick it on the game board, }
		{ and get rid of the list we loaded. }
		Mek := CloneGear( SelectRandomGear( MList ) );
		DisposeGear( MList );

		{ If modifications were requested, do those now. }
		if ModPoints > 0 then begin
			MechaMakeover( Mek , 0 , Theme , ModPoints );
		end;

		SetSATt( Mek^.SA , 'SDL_COLORS <' + Random_Mecha_Colors + '>' );

		SetNAtt( Mek^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );
		DeployGear( GB , Mek , False );

		if ( Adv <> Nil ) and ( Adv^.S = GS_ArenaCampaign ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
			{ This is Arena mode. Store the mecha announcement for the }
			{ mission debriefing. }
			AddSAtt( GB^.Scene^.SA , ARENAREPORT_MechaObtained , FullGearName( Mek ) );

		end else begin
			{ This is RPG mode. Report the mecha directly. }
			msg := ReplaceHash( MsgString( 'MechaPrize_Announce' ) , FullGearName( Mek ) );
			AToAn( msg );
			DialogMsg( msg );

			PC := GG_LocatePC( GB );
			if FindPilotsMecha( GB^.Meks , PC ) = Nil then AssociatePilotMek( GB^.Meks , PC , Mek );
		end;
	end;
end;

Procedure ProcessDeleteGG( GB: GameBoardPtr; var Source: GearPtr );
	{ Delete the grabbed gear. }
	{ Only physical gears can be deleted in this way. }
begin
	if ( Grabbed_Gear <> Nil ) and (( Grabbed_Gear^.G >= 0 ) or ( Grabbed_Gear^.G = GG_CityMood )) then begin
		{ Make sure we aren't currently using the grabbed gear. }
		if ( IntMenu <> Nil ) and ( I_NPC = Grabbed_Gear ) then begin
			ProcessEndChat;
			I_NPC := Nil;
		end;
		if Source = Grabbed_Gear then begin
			Source := Nil;
		end;

		{ Delete the gear, if it can be found. }
		if IsSubCom( Grabbed_Gear ) then begin
			RemoveGear( Grabbed_Gear^.Parent^.SubCom , Grabbed_Gear );

		end else if IsInvCom( Grabbed_Gear ) then begin
			RemoveGear( Grabbed_Gear^.Parent^.InvCom , Grabbed_Gear );

		end else if ( GB <> Nil ) and IsFoundAlongTrack( GB^.Meks , Grabbed_Gear) then begin
			RemoveGear( GB^.Meks , Grabbed_Gear );

		end;
	end;
end;

Procedure ProcessMoveGG( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Move the grabbed gear to the specified scene. }
	{ Only physical gears can be moved in this way. }
	{ If the specified scene is 0, the gear will be "frozen" isntead. }
var
	SID: Integer;	{ Scene ID. }
	Scene: GearPtr;
begin
	{ Check to make sure we have a valid gear to move. }
	if ( Grabbed_Gear <> Nil ) and ( Grabbed_Gear^.G >= 0 ) then begin
		DelinkGearForMovement( GB , Grabbed_Gear );

		{ Find the new scene to stick our gear into. }
		SID := ScriptValue( Event , GB , Source );

		if SID <> 0 then begin
			Scene := FindActualScene( GB , SID );
			if Scene = Nil then Scene := GG_LocateAdventure( GB , Source );
		end else begin
			Scene := GG_LocateAdventure( GB , Source );
		end;
		InsertInvCom( Scene , Grabbed_Gear );

		{ If inserting a character, better choose a team. }
		if IsAScene( Scene ) and IsMasterGear( Grabbed_Gear ) then begin
			ChooseTeam( Grabbed_Gear , Scene );
		end;
	end;
end;

Procedure ProcessMoveAndPacifyGG( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Move the grabbed gear to the specified scene, }
	{ setting its team to a nonagressive one. }
	{ Only physical gears can be moved in this way. }
	{ If the specified scene is 0, the gear will be "frozen" isntead. }
var
	SID: Integer;	{ Scene ID. }
	Scene: GearPtr;
begin
	{ Check to make sure we have a valid gear to move. }
	if ( Grabbed_Gear <> Nil ) and ( Grabbed_Gear^.G >= 0 ) then begin
		DelinkGearForMovement( GB , Grabbed_Gear );

		{ Find the new scene to stick our gear into. }
		SID := ScriptValue( Event , GB , Source );
		if SID <> 0 then begin
			Scene := FindActualScene( GB , SID );
			if Scene = Nil then Scene := GG_LocateAdventure( GB , Source );
		end else begin
			Scene := GG_LocateAdventure( GB , Source );
		end;
		InsertInvCom( Scene , Grabbed_Gear );

		{ Set the TEAMDATA here. }
		if IsACombatant( Grabbed_Gear ) then begin
			SetSAtt( Grabbed_Gear^.SA , 'TEAMDATA <SD ALLY>' );
		end else begin
			SetSAtt( Grabbed_Gear^.SA , 'TEAMDATA <PASS ALLY>' );
		end;

		{ If inserting a character, better choose a team. }
		if IsAScene( Scene ) and IsMasterGear( Grabbed_Gear ) then begin
			ChooseTeam( Grabbed_Gear , Scene );
		end;
	end;
end;

Procedure ProcessDeployGG( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Move the grabbed gear to the current scene. }
	{ Only physical gears can be moved in this way. }
var
	TID: Integer;
begin
	{ Check to make sure we have a valid gear to move. }
	if ( Grabbed_Gear <> Nil ) and ( GB <> Nil ) and ( Grabbed_Gear^.G >= 0 ) then begin
		DelinkGearForMovement( GB , Grabbed_Gear );

		{ Find the new team for our gear. }
		TID := ScriptValue( Event , GB , Source );
		SetNAtt( Grabbed_Gear^.NA , NAG_Location , NAS_Team , TID );

		{ Stick it on the map, and maybe do a redraw. }
		EquipThenDeploy( GB , Grabbed_Gear , True );
	end;
end;

Procedure ProcessDynaGG( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Move the grabbed gear to the dynamic scene. }
	{ Only physical gears can be moved in this way. }
var
	TID: Integer;	{ Team ID. }
begin
	{ Check to make sure we have a valid gear to move. }
	if ( Grabbed_Gear <> Nil ) and ( Grabbed_Gear^.G >= 0 ) and ( SCRIPT_DynamicEncounter <> Nil ) then begin
		DelinkGearForMovement( GB , Grabbed_Gear );

		{ Find out which team to stick the NPC in. }
		TID := ScriptValue( Event , GB , Source );
		SetNAtt( Grabbed_Gear^.NA , NAG_Location , NAS_Team , TID );

		{ Perform the insertion. }
		InsertInvCom( SCRIPT_DynamicEncounter , Grabbed_Gear );
	end;
end;

Procedure ProcessGiveGG( GB: GameBoardPtr );
	{ Give the grabbed gear to the PC. }
	{ Only physical gears can be moved in this way. }
var
	DelinkOK: Boolean;
	PC: GearPtr;
begin
	PC := GG_LocatePC( GB );

	if ( Grabbed_Gear <> Nil ) and ( Grabbed_Gear^.G >= 0 ) and (( PC = Nil ) or ( FindGearIndex( Grabbed_Gear , PC ) < 0 )) then begin

		{ Delink the gear, if it can be found. }
		if IsSubCom( Grabbed_Gear ) then begin
			DelinkGear( Grabbed_Gear^.Parent^.SubCom , Grabbed_Gear );
			DelinkOK := True;
		end else if IsInvCom( Grabbed_Gear ) then begin
			DelinkGear( Grabbed_Gear^.Parent^.InvCom , Grabbed_Gear );
			DelinkOK := True;
		end else if ( GB <> Nil ) and IsFoundAlongTrack( GB^.Meks , Grabbed_Gear) then begin
			DelinkGear( GB^.Meks , Grabbed_Gear );
			DelinkOK := True;
		end else begin
			DelinkOK := False;
		end;

		if DelinkOK then begin
			GivePartToPC( GB , Grabbed_Gear , PC );
		end;
	end;
end;

Procedure ProcessGNewPart( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Stick an item from the standard items list on the gameboard, }
	{ then make GRABBED_GEAR point to it. }
	{ This function will first look in the STC file, then the Monster }
	{ file, then the NPC file. }
var
	IName: String;
begin
	{ First determine the item's designation. }
	IName := ExtractWord( Event );
	if Source <> Nil then begin
		IName := AS_GetString( Source , IName );
	end;

	{ As long as we have a GB, try to stick the item there. }
	if GB <> Nil then begin
		Grabbed_Gear := LoadNewSTC( IName );
		if Grabbed_Gear = Nil then Grabbed_Gear := LoadNewMonster( IName );
		if Grabbed_Gear = Nil then Grabbed_Gear := LoadNewNPC( IName , True );
		if Grabbed_Gear = Nil then Grabbed_Gear := LoadNewItem( IName );

		{ If we found something, stick it on the map. }
		if Grabbed_Gear <> Nil then begin
			{ Clear the designation. }
			SetSAtt( Grabbed_Gear^.SA , 'DESIG <>' );

			{ Deploy the item. }
			EquipThenDeploy( GB , Grabbed_Gear , False );
		end;

		{ Any further processing must be done by other commands. }
	end;
end;

Procedure BuildGenericEncounter( GB: GameBoardPtr; Source: GearPtr; Scale: Integer );
	{ Create a SCENE gear, then do everything except stock it with }
	{ enemies. }
const
	DefaultMapSize = 50;
var
	Team,Src: GearPtr;
	T: Integer;
begin
	{ First, if for some reason there's already a dynamic encounter in }
	{ place, get rid of it. }
	if SCRIPT_DynamicEncounter <> Nil then DisposeGear( SCRIPT_DynamicEncounter );

	{ Allocate a new dynamic encounter, then fill in the blanks. }
	SCRIPT_DynamicEncounter := NewGear( Nil );
	SCRIPT_DynamicEncounter^.G := GG_Scene;
	SCRIPT_DynamicEncounter^.Stat[ STAT_MapWidth ] := DefaultMapSize;
	SCRIPT_DynamicEncounter^.Stat[ STAT_MapHeight ] := DefaultMapSize;
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then SCRIPT_DynamicEncounter^.S := GB^.Scene^.S;
	SCRIPT_DynamicEncounter^.V := Scale;

	{ Copy over the PlotID of the source. }
	Src := PlotMaster( GB , Source );
	if Src <> Nil then begin
		SetNAtt( SCRIPT_DynamicEncounter^.NA , NAG_Narrative , NAS_PlotID , NAttValue( Src^.NA , NAG_Narrative , NAS_PlotID ) );
	end;

	{ Add a TEAM gear for each of the player and the enemy teams. }
	{ We need to do this so that we'll have some control over the placement }
	{ of the player and the enemies. }
	Team := AddGear( SCRIPT_DynamicEncounter^.SubCom , SCRIPT_DynamicEncounter );
	Team^.G := GG_Team;
	Team^.S := NAV_DefPlayerTeam;
	SetNAtt( Team^.NA , NAG_SideReaction , NAV_DefEnemyTeam , NAV_AreEnemies );
	SetNAtt( Team^.NA , NAG_ParaLocation , NAS_X , DefaultMapSize div 5 );
	SetNAtt( Team^.NA , NAG_ParaLocation , NAS_Y , DefaultMapSize div 5 );

	Team := AddGear( SCRIPT_DynamicEncounter^.SubCom , SCRIPT_DynamicEncounter );
	Team^.G := GG_Team;
	Team^.S := NAV_DefEnemyTeam;
	SetNAtt( Team^.NA , NAG_SideReaction , NAV_DefPlayerTeam , NAV_AreEnemies );
	SetNAtt( Team^.NA , NAG_ParaLocation , NAS_X , ( DefaultMapSize * 4 ) div 5 );
	SetNAtt( Team^.NA , NAG_ParaLocation , NAS_Y , ( DefaultMapSize * 4 ) div 5 );
	SetSAtt( Team^.SA , 'Deploy <SetSelfFaction CurrentSceneFac   WMecha 2 DynaRenown DynaStrength>' );

	{ Set the default map generator of the Dynamic Encounter based on the position of }
	{ the PC. }
	Src := FindRoot( GG_LocatePC( GB ) );
	if ( Src <> Nil ) then begin
		SCRIPT_DynamicEncounter^.Stat[ STAT_MapGenerator ] := EncounterMapType( GB , NAttValue( Src^.NA , NAG_Location , NAS_X ) , NAttValue( Src^.NA , NAG_Location , NAS_Y ) );
		{ If this will make the encounter a space map, set the map-scroll tag. }
		if SCRIPT_DynamicEncounter^.Stat[ STAT_MapGenerator ] = TERRAIN_Space then SCRIPT_DynamicEncounter^.Stat[ STAT_SpaceMap ] := 1;
	end;

	{ If this metascene doesn't have environmental effects by default, }
	{ copy the environmental effects from the parent scene. }
	Src := FindActualScene( GB , FindGearScene( Src , GB ) );
	if Src <> Nil then begin
		{ Copy the environmental effects from the parent scene. }
		for t := 1 to Num_Environment_Variables do begin
			SetNAtt( SCRIPT_DynamicEncounter^.NA , NAG_EnvironmentData , T , NAttValue( Src^.NA , NAG_EnvironmentData , T ) );
		end;

		{ Also copy over the tileset + backdrop. }
		SetNAtt( SCRIPT_DynamicEncounter^.NA , NAG_SceneData , NAS_TileSet , NAttValue( Src^.NA , NAG_SceneData , NAS_TileSet ) );
		SetNAtt( SCRIPT_DynamicEncounter^.NA , NAG_SceneData , NAS_Backdrop , NAttValue( Src^.NA , NAG_SceneData , NAS_Backdrop ) );
	end;

	{ Set the exit values in the game board. }
	if GB <> Nil then begin
		AS_SetExit( GB , 0 );
	end;
end;

Procedure ProcessNewD( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Create a new scene for a dynamic encounter to take place on. }
var
	Scale: Integer;
begin
 	Scale := ScriptValue( Event , GB , Source );
	BuildGenericEncounter( GB , Source , Scale );
end;

Procedure ProcessWMecha( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Fill current scene with enemies. }
var
	TID,Renown,Strength,LMs: LongInt;
begin
	{ Find out the team, and how many enemies to add. }
	TID := ScriptValue( Event , GB , Source );
 	Renown := ScriptValue( Event , GB , Source );
	Strength := ScriptValue( Event , GB , Source );

	{ If this team is an enemy of the player team, add extra STRENGTH based on the number of }
	{ lancemates. This extra STRENGTH will not entirely cancel out the usefulness of lancemates, }
	{ but will reduce it slightly, thereby allowing solo PCs to exist. }
	if AreEnemies( GB , TID , NAV_DefPlayerTeam ) then begin
		LMs := LancematesPresent( GB );
		if LMs > 0 then Strength := Strength + ( 25 * LMs );
	end;

	AddTeamForces( GB , TID , Renown , Strength );
end; { ProcessWMecha }

Procedure ProcessWMonster( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Fill current scene with monsters. }
var
	TID,Renown,Strength: LongInt;
	Team: GearPtr;
	MonType: String;
begin
	{ Find out the team, and how many enemies to add. }
	TID := ScriptValue( Event , GB , Source );
	Renown := ScriptValue( Event , GB , Source );
	Strength := ScriptValue( Event , GB , Source );

	{ Determine the type of monster to add. This should be indicated by }
	{ the team to which the monsters belong. }
	Team := LocateTeam( GB , TID );
	if Team <> Nil then MonType := SAttValue( Team^.SA , 'TYPE' )
	else MonType := 'ROBOT NINJA';
	if MonType = '' then MonType := 'ROBOT NINJA';

	StockBoardWithMonsters( GB , Renown , Strength , TID , MonType );
end; { ProcessWMonster }

Function NumberOfPlots( Part: GearPtr ): Integer;
	{ Check the number of plots this PART has loaded. }
var
	P: GearPtr;
	N: Integer;
begin
	P := Part^.InvCom;
	N := 0;

	while P <> Nil do begin
		if P^.G = GG_Plot then Inc( N );
		P := P^.Next;
	end;

	NumberOfPlots := N;
end;

Function CurrentPCRenown( GB: GameBoardPtr ): Integer;
	{ Return the current renown score of the PC. }
var
	PC: GearPtr;
begin
	PC := LocatePilot( GG_LocatePC( GB ) );
	if PC <> Nil then begin
		CurrentPCRenown := NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned );
	end else begin
		CurrentPCRenown := 0;
	end;
end;

Function AS_ContentInsertion( GB: GameBoardPtr; Source: GearPtr; ConReq: String; Threat: Integer ): Boolean;
	{ Attempt to load and initialize the requested plot or story. }
var
	Adv,Slot,Plot: GearPtr;
	EList: ElementTable;
	Context,msg: String;
	T,ENum: Integer;
begin
	ClearElementTable( EList );
	Adv := GG_LocateAdventure( GB , Source );
	Context := ExtractWord( ConReq );

	{ Fill out the element table. }
	if Source^.G = GG_Faction then begin
		EList[1].EValue := Source^.S;
		EList[1].EType := 'F';
		Slot := Adv;
	end else if Source^.G = GG_Scene then begin
		EList[1].EValue := Source^.S;
		EList[1].EType := 'S';
		Slot := Adv;
	end else if Source^.G = GG_Story then begin
		Slot := Source;
	end else begin
		Slot := Adv;
	end;

	{ If this plot is being spawned by a plot or by a quest, we may need to }
	{ pass along some elements. }
	Plot := PlotMaster( GB , Source );
	if Plot <> Nil then begin
		T := 1;
		while ConReq <> '' do begin
			ENum := ExtractValue( ConReq );
			if ( ENum >= 0 ) and ( ENum <= Num_Plot_Elements ) then begin
				msg := SAttValue( Plot^.SA , 'ELEMENT' + BSTr( ENum ) );
				if msg <> '' then begin
					EList[ T ].EType := msg[1];
					EList[ T ].EValue := ElementID( Plot , ENum );
					if EList[ T ].EType = 'C' then DialogMsg( 'ERROR: Content Insertion ' + Context + ' passed character element.' )
					else if EList[ T ].EType = 'M' then DialogMsg( 'ERROR: Content Insertion ' + Context + ' passed metascene element.' );
				end else begin
					DialogMsg( 'ERROR: Content Insertion ' + Context + ' requested invalid element.' );
				end;
			end;
			Inc( T );
		end;
	end;

	if AddRandomPlot( GB , Slot , Context , EList , Threat ) then begin
		AS_ContentInsertion := True;
	end else begin
		AS_ContentInsertion := False;
	end;
end;

Procedure ProcessStartStory( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A new story gear is about to be loaded. }
var
	FName: String;
	Renown: Integer;
begin
	{ First, find the content request and the threat value to use. }
	FName := ExtractWord( Event );
	if Source <> Nil then begin
		FName := AS_GetString( Source , FName );
	end else begin
		FName := '';
	end;
	Renown := ScriptValue( Event , GB , Source );

	{ Call the above procedure to see if it works or not. }
	if AS_ContentInsertion( GB , Source , FName , Renown ) then begin
		SetTrigger( GB , 'UPDATE' );
		IfSuccess( Event );
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessStartPlot( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A new plot is being loaded, probably by a story. }
	{ For now I'm going to treat such plots as global. }
var
	FName: String;
	Renown: Integer;
begin
	{ First, find the content request and the threat value to use. }
	FName := ExtractWord( Event );
	if Source <> Nil then begin
		FName := AS_GetString( Source , FName );
	end else begin
		FName := '';
	end;
	Renown := ScriptValue( Event , GB , Source );

	if ( Source <> Nil ) and ( Source^.G = GG_Story ) and ( NumberOfPlots( Source ) >= Max_Plots_Per_Story ) then begin
		{ Can't load a new plot at this time. }
		IfFailure( Event , Source );

	end else begin
		if AS_ContentInsertion( GB , Source , FName , Renown ) then begin
			SetTrigger( GB , 'UPDATE' );
			IfSuccess( Event );
		end else begin
			{ File was not loaded successfully. }
			IfFailure( Event , Source );
		end;
	end;
end;

Procedure ProcessSetMood( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A CityMood is about to be unleashed on the game world. }
var
	ID: LongInt;
	Mood,City: GearPtr;
begin
	{ First, find the mood and the city. }
	ID := ScriptValue( Event , GB , Source );
	Mood := GG_LocateItem( ID , GB , Source );

	ID := ScriptValue( Event , GB , Source );
	City := FindRootScene( FindActualScene( GB , ID ) );

	{ Call the above procedure to see if it works or not. }
	if ( Mood <> Nil ) and ( City <> Nil ) then begin
		DelinkGearForMovement( GB , Mood );
		if InsertMood( City , Mood , GB ) then begin
			SetTrigger( GB , 'UPDATE' );
			IfSuccess( Event );
		end else begin
			IfFailure( Event , Source );
		end;
	end else begin
		IfFailure( Event , Source );
	end;
end;

Procedure ProcessUpdatePlots( var Trigger,Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Check the current city and all of its moods. Attempt to load new plots as appropriate. }
var
	Threat: Integer;
begin
	{ Final error check- based on the config options, maybe exit. }
	if Load_Plots_At_Start and ( UpCase( Trigger ) <> 'START' ) then exit
	else if ( not Load_Plots_At_Start ) and ( UpCase( Trigger ) = 'START' ) then exit;

	Threat := CurrentPCRenown( GB );
	UpdatePlots( GB , Threat );

	SetTrigger( GB , 'UPDATE' );
end;

Procedure ProcessCheckComponents( GB: GameBoardPtr; Source: GearPtr );
	{ Check to see if this source needs to load a new component. If so, }
	{ then do that. }
var
	Adv: GearPtr;
begin
	{ If we have a source, and that source has its "LoadNextComponent" value set, }
	{ then we have work to do here... }
	if ( Source <> Nil ) and ( NAttValue( Source^.NA , NAG_XXRAN , NAS_LoadNextComponent ) = 0 ) then begin
		PrepareNewComponent( Source , GB );

		SetNAtt( Source^.NA , NAG_XXRAN , NAS_LoadNextComponent , 1 );

		{ Check to see whether or not the episode number has increased. }
		if NAttValue( Source^.NA , NAG_XXRAN , NAS_EpisodeNumber ) > NAttValue( Source^.NA , NAG_XXRAN , NAS_LastEpisodeNoted ) then begin
			SetNAtt( Source^.NA , NAG_XXRAN , NAS_LastEpisodeNoted , NAttValue( Source^.NA , NAG_XXRAN , NAS_EpisodeNumber ) );
			Adv := GG_LocateAdventure( GB , Source );
			AddSAtt( Adv^.SA , 'HISTORY' , '...' );
			AddSAtt( Adv^.SA , 'HISTORY' , ReplaceHash( MsgString( 'HISTORY_NEWEPISODE' ) , BStr( NAttValue( Source^.NA , NAG_XXRAN , NAS_EpisodeNumber ) ) ) );
		end;
	end;
end;

Procedure AlterStoryDescriptors( Story: GearPtr; var Changes: String );
	{ Alter the story descriptors based on the provided changes. If the +P Propp state is changed, }
	{ reset the story's ProppAdvancement attribute. }
	{ Note that CHANGES will be utterly destroyed by the AlterDescriptors call below. }
var
	Base: String;
begin
	Base := SAttValue( Story^.SA , 'CONTEXT' );
	AlterDescriptors( Base , Changes );
	SetSAtt( Story^.SA , 'CONTEXT <' + Base + '>' );
end;

Procedure ProcessGAlterContext( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Alter the context by the changes string provided. }
var
	Story: GearPtr;
	Changes: String;
begin
	Story := Grabbed_Gear;
	Changes := ExtractWord( Event );
	Changes := SAttValue( Source^.SA , Changes );
	if Story <> Nil then begin
		AlterStoryDescriptors( Story , Changes );
	end;
end;

Procedure ProcessNextComp( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Prepare things for the next component to be loaded. }
	Procedure ContinueConversation();
		{ We want to make a choice, but there's already a conversation }
		{ going on. Best to end that conversation with a [Continue] tag, }
		{ then we can return to it later. }
	var
		RPM: RPGMenuPtr;
	begin
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
		AddRPGMenuItem( RPM , MsgString( 'Continue' ), -1 );
		ASRD_GameBoard := GB;
		CHAT_React := ReactionScore( GB^.Scene , I_PC , I_NPC );
		SelectMenu( RPM , @InteractRedraw );
		DisposeRPGMenu( RPM );
	end;
	Function SeekDCGear( Story: GearPtr; DCID: Integer ): GearPtr;
		{ Locate the plot corresponding to the dramatic choice selected }
		{ by the PC. }
	var
		LList: GearPtr;
	begin
		LList := Story^.InvCom;
		while ( LList <> Nil ) and ( ( NAttValue( LList^.NA , NAG_XXRan , NAS_IsDramaticChoicePlot ) = 0 ) or ( LList^.V <> DCID ) ) do LList := LList^.Next;
		SeekDCGear := LList;
	end;
	Procedure MakeDramaticChoice( Story: GearPtr );
		{ In order to move on, the PC must decide what they're going }
		{ to do next. }
	var
		RPM: RPGMenuPtr;
		DC: GearPtr;
		N: Integer;
		Trigger: String;
	begin
		{ Step One- create the list of dramatic choices. }
		CreateChoiceList( GB , Story );

		{ Step Two- assemble these choices into a menu. This is tougher }
		{ than it looks, since if we are currently in a conversation }
		{ we want the choices merged with the conversation. }
		if I_NPC <> Nil then begin
			ContinueConversation;
			RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
		end else begin
			RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoText );
		end;
		RPM^.Mode := RPMNoCancel;

		DC := Story^.InvCom;
		while DC <> Nil do begin
			{ How do we identify the dramatic choice options? They've been marked }
			{ with a special NA tag. Do we do any error checking to make sure }
			{ they're legit? Hell no! }
			if NAttValue( DC^.NA , NAG_XXRan , NAS_IsDramaticChoicePlot ) <> 0 then begin
				{ This is a dramatic choice. Add it to the menu. }
				AddRPGMenuItem( RPM , ScriptMessage( 'PROMPT' , GB , DC ) , DC^.V );
			end;
			DC := DC^.Next;
		end;

		if RPM^.NumItem < 1 then begin
			DialogMsg( 'ERROR: No dramatic choices found!' );
			N := -1;
		end else if I_NPC <> Nil then begin
			CHAT_Message := MsgString( 'Make_Dramatic_Choice' );
			N := SelectMenu( RPM , @InteractRedraw );
		end else begin
			ASRD_MemoMessage := MsgString( 'Make_Dramatic_Choice' );
			N := SelectMenu( RPM , @ChoiceRedraw );
		end;

		{ Step Three- record the choice and execute its initialization }
		{ script. }
		SetNAtt( Story^.NA , NAG_XXRan , NAS_DramaticChoice , N );

		{ Locate the choice's gear. }
		DC := SeekDCGear( Story , N );
		if DC <> Nil then begin
			Trigger := 'CHOICE';
			TriggerGearScript( GB , DC , Trigger );
			if I_NPC <> Nil then begin
				CHAT_Message := ScriptMessage( 'REPLY' , GB , DC );
			end else begin
				YesNoMenu( GB , ScriptMessage( 'ALERT' , GB , DC ) , '' , '' );
			end;
		end else begin
			DialogMsg( 'ERROR: Dramatic Choice ' + BStr( N ) + ' not found.' );
		end;

		{ Step Four- dispose of the remaining choices, and the menu. }
		ClearChoiceList( Story );
		DisposeRPGMenu( RPM );
	end;
var
	Story: GearPtr;
begin
	Story := StoryMaster( GB , Source );
	if Story = Nil then begin
		DialogMsg( 'ERROR: ProcessNextComp called but story not found' );
		Exit;
	end;

	if ( Story <> Nil ) and ( GB <> Nil ) then begin
		MakeDramaticChoice( Story );

		SetNAtt( Story^.NA , NAG_XXRAN , NAS_LoadNextComponent , 0 );

		{ Set this component for possible deletion. }
		{ First make sure we have the plot itself. }
		Source := PlotMaster( GB , Source );
		EndPlot( GB , Source^.Parent , Source );
		SetTrigger( GB , 'UPDATE' );
	end;
end;


Procedure ProcessAttack( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Team 1 is going to attack Team 2. }
var
	t1,T2: Integer;
	Team1,Mek: GearPtr;
begin
	{ Error check - We need that gameboard! }
	if GB = Nil then Exit;

	{ Read the script values. }
	T1 := ScriptValue( Event , GB , Source );
	T2 := ScriptValue( Event , GB , Source );

	{ Find the attacking team, and set the enemy value. }
	Team1 := LocateTeam( GB , T1 );
	if Team1 <> Nil then begin
		SetNAtt( Team1^.NA , NAG_SideReaction , T2 , NAV_AreEnemies );
	end;

	{ Locate each member of the team and set AIType to SEEK AND DESTROY. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = T1 then begin
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_SeekAndDestroy );
		end;
		Mek := Mek^.Next;
	end;
end;

Procedure ProcessSalvage( GB: GameBoardPtr );
	{ It's looting time!!! Check every mecha on the game board; if it's }
	{ not operational but not destroyed, switch its TEAM to NAV_DefPlayerTeam. }
	Function CanSalvage( M: GearPtr ): Boolean;
		{ Return TRUE if M can maybe be salvaged, or FALSE otherwise. }
	var
		Team: Integer;
	begin
		Team := NAttValue( M^.NA , NAG_Location, NAS_Team );
		CanSalvage := ( M^.G = GG_Mecha ) and ( Team <> NAV_DefPlayerTeam ) and ( Team <> NAV_LancemateTeam ) and ( not GearOperational( M ) );
	end;
var
	Mek,M2,PC: GearPtr;
	CanScavenge: Boolean;
	T: Integer;
	RPts: LongInt;
begin
	{ ERROR CHECK - GB must be defined!!! }
	if GB = Nil then Exit;

	{ Check to see if the PC has the Scavenger talent. }
	PC := GG_LocatePC( GB );
	CanScavenge := TeamHasTalent( GB , NAV_DefPlayerTeam , NAS_TechVulture );

	{ Loop through every mek on the board. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if CanSalvage( Mek ) then begin
			{ This is a salvagable part. To start with, remove its pilot(s). }
			repeat
				M2 := ExtractPilot( Mek );
				if M2 <> Nil then DeployGear( GB , M2 , False );
			until M2 = Nil;

			{ Apply emergency repair to it. }
			if CanScavenge or ( Random( 6 ) = 1 ) then begin
				for t := 0 to NumMaterial do begin
					if ( TotalRepairableDamage( Mek , T ) > 0 ) then begin
						{ Determine how many repair points it's possible }
						{ to apply. }
						RPts := RollStep( TeamSkill( GB , NAV_DefPlayerTeam , Repair_Skill_Needed[ T ] , STAT_Knowledge ) ) - 15;
						if RPts > 0 then begin
							ApplyEmergencyRepairPoints( Mek , T , RPts );
						end;
					end;
				end;	{ Checking the repair skills. }
			end;

			{ If at the end of this the mecha is NotDestroyed, it may be }
			{ added to the PC team. If it is destroyed, the PC has a chance }
			{ to use Tech Vulture. }
			if NotDestroyed( Mek ) then begin
				SetNAtt( Mek^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );
				SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Temporary , 0 );
				{ Also move off the map, to prevent the runaway salvage bug. }
				SetNAtt( Mek^.NA , NAG_Location , NAS_X , 0 );
				{ Record that this is a salvaged mek. }
				SetNAtt( Mek^.NA , NAG_MissionReport , NAS_WasSalvaged , 1 );

			end else if CanScavenge then begin
				M2 := SelectRandomGear( Mek^.SubCom );
				if NotDestroyed( M2 ) and CanBeExtracted( M2 ) and ( SkillRoll( GB , PC , NAS_Repair , STAT_Knowledge , 7 , 0 , True , True ) > 7 ) then begin
					ExtractMechaPart( Mek^.SubCom , M2 );
					SetNAtt( M2^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );
					SetSAtt( M2^.SA , 'DESIG <' + GearName( Mek ) + '>' );
					AppendGear( GB^.Meks , M2 );
					{ Record that this is a salvaged part. }
					SetNAtt( M2^.NA , NAG_MissionReport , NAS_WasSalvaged , 1 );
				end;
			end;

		end;
		Mek := Mek^.Next;
	end;
end;

Procedure ProcessRetreat( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ When this command is invoked, all the functioning masters }
	{ belonging to the listed team are removed from the map. A }
	{ Number Of Units trigger is then set. }
var
	Team: Integer;
	Mek: GearPtr;
begin
	{ ERROR CHECK - GB must be defined!!! }
	if GB = Nil then Exit;

	{ Find out which team is running away. }
	Team := ScriptValue( event , GB , Source );

	{ Loop through every mek on the board. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if GearOperational( Mek ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = Team ) then begin
			SetNAtt( Mek^.NA , NAG_Location , NAS_X , 0 );
			SetNAtt( Mek^.NA , NAG_Location , NAS_Y , 0 );
		end;
		Mek := Mek^.Next;
	end;

	{ Set the trigger. }
	SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( Team ) );
end;

Procedure ProcessAirRaidSiren( GB: GameBoardPtr );
	{ When this command is invoked, all the functioning masters }
	{ belonging to all NPC teams are ordered to run for their lives. }
var
	Mek: GearPtr;
begin
	{ ERROR CHECK - GB must be defined!!! }
	if GB = Nil then Exit;

	{ Loop through every mek on the board. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if GearOperational( Mek ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) <> NAV_DefPlayerTeam ) then begin
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_RunAway );
		end;
		Mek := Mek^.Next;
	end;
end;

Procedure ProcessGRunAway( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ When this command is invoked, the grabbed gear is removed }
	{ from the map. A Number Of Units trigger is then set. }
var
	Mek,NPC: GearPtr;
begin
	{ ERROR CHECK - GB must be defined!!! }
	if ( GB = Nil ) or ( Grabbed_Gear = Nil ) then Exit;

	{ Loop through every mek on the board. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if Mek = Grabbed_Gear then begin
			SetNAtt( Mek^.NA , NAG_Location , NAS_X , 0 );
			SetNAtt( Mek^.NA , NAG_Location , NAS_Y , 0 );

			{ Set the trigger. }
			SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( MEK^.NA , NAG_Location , NAS_Team ) ) );
		end else if IsMasterGear( Mek ) then begin
			NPC := LocatePilot( Mek );
			if ( NPC <> Nil ) and ( NPC = Grabbed_Gear ) then begin
				SetNAtt( Mek^.NA , NAG_Location , NAS_X , 0 );
				SetNAtt( Mek^.NA , NAG_Location , NAS_Y , 0 );

				{ Set the trigger. }
				SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( MEK^.NA , NAG_Location , NAS_Team ) ) );
			end;
		end;
		Mek := Mek^.Next;
	end;
end;


Procedure ProcessTime( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Advance the game clock by a specified amount. }
	{ FOr long periods of time, we don't want the PC to get hungry, as this will }
	{ result in an obscene number of "You are hungry" messages. So, break the time }
	{ into hour periods and give the PC some food between each. }
var
	N,OriginalHunger: LongInt;
	PC: GearPtr;
begin
	{ Find out how much to adjust the value by. }
	N := ScriptValue( Event , GB , Source );

	PC := LocatePilot( GG_LocatePC( GB ) );
	if PC <> Nil then begin
		OriginalHunger := NAttValue( PC^.NA , NAG_Condition , NAS_Hunger );
		if OriginalHunger > ( Hunger_Penalty_Starts - 15 ) then OriginalHunger := Hunger_Penalty_Starts - 16;
	end;

	while N > 0 do begin
		if N > 3600 then begin
			if PC <> Nil then SetNAtt( PC^.NA , NAG_Condition , NAS_Hunger , OriginalHunger );
			QuickTime( GB , 3600 );
			N := N - 3600;
		end else begin
			QuickTime( GB , N );
			N := 0;
		end;
	end;
end;

Procedure ProcessForceChat( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Force the player to talk with the specified NPC. }
var
	N: LongInt;
begin
	{ Find out which NPC to speak with. }
	N := ScriptValue( Event , GB , Source );

	if GB <> Nil then begin
		StoreSAtt( GB^.Trig , '!TALK ' + BStr( N ) );
	end;
end;

Procedure ProcessAnnounce( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ The PC has done something special; show an announcement. }
var
	tag: String;
	N: LongInt;
begin
	{ Find out which message to display. }
	tag := ExtractWord( Event );
	N := ScriptValue( Event , GB , Source );

	if GB <> Nil then begin
		StoreSAtt( GB^.Trig , '!ANNOUNCE ' + tag + BStr( N ) );
	end;
end;

Procedure ProcessTrigger( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A new trigger will be placed in the trigger queue. }
var
	BaseTrigger: String;
	N: LongInt;
begin
	{ Find out the trigger's details. }
	BaseTrigger := ExtractWord( Event );
	N := ScriptValue( Event , GB , Source );

	if GB <> Nil then begin
		StoreSAtt( GB^.Trig , BaseTrigger + BStr( N ) );
	end;
end;

Procedure ProcessTrigger0( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A new trigger will be placed in the trigger queue. }
var
	BaseTrigger: String;
begin
	{ Find out the trigger's details. }
	BaseTrigger := ExtractWord( Event );

	if GB <> Nil then begin
		StoreSAtt( GB^.Trig , BaseTrigger );
	end;
end;

Procedure ProcessLTrigger( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ A new trigger will be placed in the local trigger queue. }
var
	BaseTrigger: String;
begin
	{ Find out the trigger's details. }
	BaseTrigger := ExtractWord( Event );
	if GB <> Nil then begin
		StoreSAtt( local_triggers , BaseTrigger );
	end;
end;


Procedure ProcessTransform( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Alter the appearance of the SOURCE gear. }
var
	N: LongInt;
	S: String;
	Procedure SwapSAtts( tag: String );
	begin
		S := AS_GetString ( Source , tag + BStr( N ) );
		if S <> '' then SetSAtt( Source^.SA , tag + ' <' + S + '>' );
	end;
begin
	{ Find out which aspect to change to. }
	N := ScriptValue( Event , GB , Source );

	{Switch all known dispay descriptors. }
	SwapSAtts( 'ROGUECHAR' );
	SwapSAtts( 'NAME' );
	SwapSAtts( 'SDL_SPRITE' );
	SwapSAtts( 'SDL_COLORS' );
	SetNAtt( Source^.NA , NAG_Display , NAS_PrimaryFrame , NAttValue( Source^.NA , NAG_Display , N ) );

	if GB <> Nil then begin
		{ While we're here, redo the shadow map. }
		UpdateShadowMap( GB );
	end;
end;

Procedure ProcessMoreText( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Load and display a text file. }
var
	FName: String;
	txt,L: SAttPtr;
begin
	{ First, find the file name of the text file to look for. }
	FName := ExtractWord( Event );
	if Source <> Nil then begin
		FName := AS_GetString( Source , FName );
	end else begin
		FName := '';
	end;

	{ Secondly, load and display the file. }
	if FName <> '' then begin
		txt := LoadStringList( Series_Directory + FName );


		if txt <> Nil then begin
			{ Process the text. }
			L := txt;
			while L <> Nil do begin
				FormatMessageString( L^.Info , GB , Source );
				L := L^.Next;
			end;

			MoreText( txt , 1 );
			DisposeSAtt( txt );
		end;
	end;

end; { ProcessMoreText }

Procedure ProcessMoreMemo( var Event: String; GB: GameBoardPtr );
	{ View messages of a certain type - EMAIL, NEWS, or MEMO. }
var
	Key: String;
begin
	{ First, find the memo key to use. }
	Key := ExtractWord( Event );

	{ Secondly, send this to the memo browser. }
	BrowseMemoType( GB , Key );

	{ Finally, update the display. }
	CombatDisplay( GB );
end; { ProcessMoreMemo }

Procedure ProcessSeekGate( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Aim for a specific gate when entering the next level. }
var
	N: LongInt;
begin
	{ Find out which gate we're talking about. }
	N := ScriptValue( Event , GB , Source );

	SCRIPT_Gate_To_Seek := N;
end;

Procedure ProcessUpdateProps( GB: GameBoardPtr );
	{ Just send an UPDATE trigger to all items on the gameboard. }
var
	T: String;
begin
	T := 'UPDATE';
	if GB <> Nil then begin
		CheckTriggerAlongPath( T , GB , GB^.Meks , True );
	end;
end;

Procedure ProcessBlock( var T: String );
	{ Erase the trigger, so as to prevent other narrative gears }
	{ from acting upon it. }
begin
	{ Do I really need to comment this line? }
	T := '';
end;

Procedure ProcessAccept( var T: String );
	{ Set the trigger to ACCEPT so the CONDITIONACCEPTED function }
	{ knows that it's been accepted. }
begin
	{ Do I really need to comment this line? }
	T := 'ACCEPT';
end;

Procedure ProcessBomb( GB: GameBoardPtr );
	{ Drop a bomb on the town. Yay! }
begin
	if not GB^.QuitTheGame then RandomExplosion( GB );
end;

Procedure ProcessXPV( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Give some experience points to all PCs and lancemates. }
const
	LM_Renown_Lag = 20;	{ Lancemates will lag one renown band behind PC. }
	Procedure DoRapidLeveling( NPC,PC: GearPtr; Renown: Integer );
		{ Search through this NPC's skills. If you find one that is lower }
		{ than acceptable for the provided Renown, increase it. }
	var
		OptRank,SpecSkill,Skill,N,SkRank: Integer;
		CanGetBonus: Array [1..NumSkill] of Boolean;
	begin
		if NPC = Nil then Exit;

		{ Clamp the renown score. }
		if Renown < 1 then Renown := 1;

		{ Advance the NPC's renown. }
		if NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned ) < Renown then AddNAtt( NPC^.NA , NAG_CharDescription , NAS_Renowned , 1 );

		{ Maybe advance the NPC's reaction score. }
		{ This will depend on the current score bonus and the renown level. }
		N := Random( Renown + 5 ) div 2;
		if N > NAttValue( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) ) then AddReact( GB , PC , NPC , 1 );

		{ Determine the skill level to use. }
		OptRank := SkillRankForRenown( Renown );

		{ Determine the specialist skill of this model. }
		SpecSkill := NAttValue( NPC^.NA , NAG_Personal , NAS_SpecialistSkill );

		{ Count how many skills could use a level-up. }
		N := 0;
		for Skill := 1 to NumSkill do begin
			{ If this is the specialist skill, it can go one higher. }
			SkRank := SkillRank( NPC , Skill );
			if ( Skill = SpecSkill ) and ( SkRank > 1 ) then Dec( SkRank );
			if ( SkRank > 0 ) and ( SkRank < OptRank ) then begin
				Inc( N );
				CanGetBonus[ Skill ] := True;
			end else CanGetBonus[ Skill ] := False;
		end;

		{ If any skills need boosting, select one at random and do that now. }
		if N > 0 then begin
			{ Select one skill at random }
			N := Random( N );

			{ Find it, and give a +1 bonus. }
			for Skill := 1 to NumSkill do begin
				if CanGetBonus[ Skill ] then begin
					Dec( N );
					if N = -1 then begin
						AddNAtt( NPC^.NA , NAG_Skill , Skill , 1 );
						Break;
					end;
				end;
			end;
		end;
	end;
var
	XP,T,Renown,LMs: LongInt;
	M,PC,NPC: GearPtr;
begin
	{ Find out how much to give. }
	XP := ScriptValue( Event , GB , Source );

	{ Count the lancemates, reduce XP if too many. }
	LMs := LancematesPresent( GB );
	if LMs > 4 then LMs := 4;
	if LMs > 1 then XP := ( XP * ( 5 - LMs ) ) div 4;

	{ Locate the PC, and find its Renown score. }
	PC := LocatePilot( GG_LocatePC( GB ) );
	if PC <> Nil then begin
		Renown := NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned );
	end else begin
		Renown := 1;
	end;

	{ We'll rapidly level one of the lancemates at random. }
	{ Select a model. }
	LMs := Random( LancematesPresent( GB ) ) + 1;

	{ Search for models to give XP to. }
	if GB <> Nil then begin
		M := GB^.Meks;
		while M <> Nil do begin
			T := NAttValue( M^.NA , NAG_Location , NAS_Team );
			if ( T = NAV_DefPlayerTeam ) then begin
				DoleExperience( M , XP );
			end else if ( T = NAV_LancemateTeam ) and OnTheMap( GB , M ) then begin
				DoleExperience( M , XP );

				{ Locate the pilot. }
				NPC := LocatePilot( M );
				{ Only regular lancemates get rapid leveling- Pets and temps don't. }
				if IsRegularLancemate( M ) then begin
					Dec( LMs );
					if ( LMs = 0 ) and ( NPC <> Nil ) then DoRapidLeveling( NPC , PC , Renown - LM_Renown_Lag );

					{ Lancemates are also eligible for training events. }
					if NAttValue( NPC^.NA , NAG_Narrative , NAS_LancemateTraining_Total ) < Renown then begin
						AddNAtt( NPC^.NA , NAG_Narrative , NAS_LancemateTraining_Total , 1 );
					end;
				end;
			end;
			M := M^.Next;
		end;
	end;

	DialogMsg( ReplaceHash( MSgString( 'AS_XPV' ) , Bstr( XP ) ) );
end;


Procedure ProcessGSkillXP( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Give some skill experience points to the grabbed gear. }
var
	Sk,XP: LongInt;
begin
	{ Find out what skill to give XP for, and how much XP to give. }
	Sk := ScriptValue( Event , GB , Source );
	XP := ScriptValue( Event , GB , Source );

	{ As long as we have a grabbed gear, go for it! }
	if Grabbed_Gear <> Nil then begin
		DoleSkillExperience( Grabbed_Gear , Sk , XP );
	end;
end;

Procedure ProcessGMental( GB: GameBoardPtr );
	{ The grabbed gear is doing something. Make it wait, and spend }
	{ five mental points. }
begin
	{ As long as we have a grabbed gear, go for it! }
	if Grabbed_Gear <> Nil then begin
		WaitAMinute( GB , Grabbed_Gear , ReactionTime( Grabbed_Gear ) * 3 );
		AddMentalDown( Grabbed_Gear , 5 );
	end;
end;

Procedure ProcessGStamina( GB: GameBoardPtr );
	{ The grabbed gear is doing something. Make it wait, and spend }
	{ five stamina points. }
begin
	{ As long as we have a grabbed gear, go for it! }
	if Grabbed_Gear <> Nil then begin
		WaitAMinute( GB , Grabbed_Gear , ReactionTime( Grabbed_Gear ) * 3 );
		AddStaminaDown( Grabbed_Gear , 5 );
	end;
end;

Procedure ProcessGQuitLance( GB: GameBoardPtr );
	{ The grabbed gear will quit the lance. }
begin
	if Grabbed_Gear <> Nil then begin
		RemoveLancemate( GB , Grabbed_Gear , False );
	end;
end;

Procedure ProcessGJoinLance( GB: GameBoardPtr );
	{ The grabbed gear will join the lance. }
begin
	if Grabbed_Gear <> Nil then begin
		{ If the Grabbed_Gear is not in play, move it to the current scene. }
		if not IsFoundAlongTrack( GB^.Meks , FindRoot( Grabbed_Gear ) ) then begin
			DelinkGearForMovement( GB , Grabbed_Gear );
			SetNAtt( Grabbed_Gear^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );

			{ Stick it on the map. }
			EquipThenDeploy( GB , Grabbed_Gear , True );
		end;

		AddLancemateFrontEnd( GB , GG_LocatePC( GB ) , Grabbed_Gear , False );
	end;
end;

Procedure ProcessGSkillLevel( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Set the skill points for the grabbed gear. }
var
	Renown: Integer;
begin
	{ Find out what level the NPC should be at. }
	Renown := ScriptValue( Event , GB , Source );
	{ As long as we have a grabbed gear, go for it! }
	if ( Grabbed_Gear <> Nil ) then begin
		{ Record the character's new renown score and mark as a combatant. }
		SetNAtt( Grabbed_Gear^.NA , NAG_CharDescription , NAS_Renowned , Renown );
		SetNAtt( Grabbed_Gear^.NA , NAG_CharDescription , NAS_IsCombatant , 1 );

		SetSkillsAtLevel( Grabbed_Gear , Renown );
	end;
end;

Procedure ProcessGMoraleDmg( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Give some morale points to the grabbed gear. }
var
	M: LongInt;
begin
	{ Find out how much morale change. }
	M := ScriptValue( Event , GB , Source );

	{ As long as we have a grabbed gear, go for it! }
	if Grabbed_Gear <> Nil then begin
		AddMoraleDMG( Grabbed_Gear , M );
	end;
end;

Procedure ProcessDrawTerr( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Alter a single gameboard tile. }
var
	X,Y,T: LongInt;
begin
	{ Find out where and what to adjust. }
	X := ScriptValue( Event , GB , Source );
	Y := ScriptValue( Event , GB , Source );
	T := ScriptValue( Event , GB , Source );

	if ( GB <> NIl ) and OnTheMap( GB , X , Y ) and ( T >= 1 ) and ( T <= NumTerr ) then begin
		SetTerrain( GB , X , Y , T );
	end;
end;

Procedure ProcessArenaRep( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ The arena unit has just won or lost a mission. Adjust its reputation }
	{ accordingly. }
var
	D: LongInt;
	Adv: GearPtr;
begin
	{ Find out how much to adjust. }
	D := ScriptValue( Event , GB , Source );

	{ Find the adventure. }
	Adv := GG_LocateAdventure( GB , Source );

	if ( Adv <> NIl ) then begin
		AddNAtt( Adv^.NA , NAG_CharDescription , -6 , D );
		if NAttValue( Adv^.NA , NAG_CharDescription , -6 ) > 100 then begin
			SetNAtt( Adv^.NA , NAG_CharDescription , -6 , 100 );
		end else if NAttValue( Adv^.NA , NAG_CharDescription , -6 ) < 0 then begin
			SetNAtt( Adv^.NA , NAG_CharDescription , -6 , 0 );
		end;
	end;
end;

Procedure ProcessAddReact( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Adjust the reaction score of I_NPC. }
var
	DReact: integer;	{ How much do we want to change? }
	PC: GearPtr;
begin
	DReact := ScriptValue( Event , GB , Source );

	PC := LocatePilot( GG_LocatePC( GB ) );
	AddReact( GB , PC , I_NPC , DReact );
end;

Procedure ProcessMagicMap( GB: GameBoardPtr );
	{ Make every tile on the map visible, then redraw. }
var
	X,Y: Integer;
begin
	for X := 1 to GB^.MAP_Width do begin
		for Y := 1 to GB^.MAP_Height do begin
			SetVisibility( GB , X , Y , True );
		end;
	end;
	CombatDisplay( GB );
end;

Procedure ProcessGOpenInv( GB: GameBoardPtr );
	{ Attempt to access the inventory of the grabbed gear. }
begin
	if ( Grabbed_Gear <> Nil ) and ( GB <> Nil ) then begin
		PCTradeItems( GB , GG_LocatePC( GB ) , Grabbed_Gear );
	end;
end;

Procedure CheckMechaEquipped( GB: GameBoardPtr );
	{ A dynamic encounter is about to be entered. The PC is going to }
	{ want a mecha for it, most likely. }
var
	PC,Mek: GearPtr;
begin
	{ Error check - make sure we have a gameboard to start with. }
	if GB = Nil then Exit;

	{ Find the PC. If the PC doesn't have a mek equipped, then }
	{ prompt for one to be equipped. }
	PC := GG_LocatePC( GB );
	if ( PC <> Nil ) and ( PC^.G <> GG_Mecha ) then begin
		Mek := FindPilotsMecha( GB^.Meks , PC );
		if ( Mek = Nil ) and ( NumPCMeks( GB ) > 0 ) then begin
			GameMSG( MsgString( 'ARENASCRIPT_CheckMechaEquipped' ) , ZONE_UsagePrompt , InfoGreen );
			FHQ_SelectMechaForPilot( GB , PC );
		end;
	end;
end;

Procedure ProcessSetEncounter( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ Search for encounters leading to a specified scene. Set their activation value. }
var
	SID,DEID,AVal: LongInt;	{ SceneID, Dungeon Entrance ID, Activation Value }
	Adv: GearPtr;
	DestScene: GearPtr;
	Procedure CheckAlongPath( LList: GearPtr );
		{ Check for encounters along this list and throughout all children. }
	begin
		while LList <> Nil do begin
			if ( LList^.G = GG_MetaTerrain ) and ( LList^.S = GS_MetaEncounter ) and ( LList^.Stat[ STAT_Destination ] = SID ) then begin
				SetNAtt( LList^.NA , NAG_Narrative , NAS_EncounterActive , AVal );
			end;
			CheckALongPath( LList^.SubCom );
			CheckALongPath( LList^.InvCom );
			LList := LList^.Next;
		end;
	end;
begin
	{ Find out which scene and what value. }
	SID := ScriptValue( Event , GB , Source );
	AVal := ScriptValue( Event , GB , Source );

	{ Locate the scene. If this is a dungeon, we want to activate the encounter for }
	{ the entrance rather than the level provided. }
	DestScene := FindActualScene( GB , SID );
	if DestScene <> Nil then begin
		DEID := NAttValue( DestScene^.NA , NAG_Narrative , NAS_DungeonEntrance );
		if DEID <> 0 then SID := DEID;
	end;

	{ Locate the adventure. }
	Adv := GG_LocateAdventure( GB , Source );
	if Adv <> Nil then CheckAlongPath( Adv^.SubCom );

	{ Also check the currently deployed gears. }
	if GB <> Nil then CheckAlongPath( GB^.Meks );
end;

Procedure ProcessTrainNPC( var Event: String; GB: GameBoardPtr; Source: GearPtr );
	{ An NPC is going to learn a new skill or talent. Cool! }
const
	MaxTNPCChoices = 10;
var
	CID: LongInt;
	NPC: GearPtr;
	CList,msg: String;
	CanGainSkill,CanGainTalent: Boolean;
	N,T: Integer;
	Choices: Array [1..MaxTNPCChoices] of Integer;
begin
	{ Find out which NPC, and the list of choices. }
	CID := ScriptValue( Event , GB , Source );
	NPC := GG_LocateNPC( CID , GB , Source );
	CList := ExtractWord( Event );
	if Source <> Nil then begin
		CList := AS_GetString( Source , CList );
	end else begin
		CList := '';
	end;

	{ If this lancemate cannot develop at this time, exit. }
	if not LancemateCanDevelop( NPC ) then Exit;

	{ Find out if the NPC can learn a new skill or a new talent. }
	CanGainSkill := NumberOfSpecialties( NPC ) < NumberOfSkillSlots( NPC );
	CanGainTalent := NumFreeTalents( NPC ) > 0;

	{ Copy the choices list over to the array. }
	N := 0;
	while ( CList <> '' ) and ( N < MaxTNPCChoices ) do begin
		T := ScriptValue( CList , GB , Source );
		if (( T > 0 ) and CanGainSkill and ( NAttValue( NPC^.NA , NAG_Skill , T ) = 0 ) ) or (( T < 0 ) and CanGainTalent and ( NAttValue( NPC^.NA , NAG_Talent , Abs(T) ) = 0 ) and CanLearnTalent( NPC , Abs(T) )  ) then begin
			Inc( N );
			Choices[ N ] := T;
		end;
		DeleteWhiteSpace( CList );
	end;

	{ If we have some valid choices, pick one at random. Yay! }
	if N > 0 then begin
		msg := ReplaceHash( MsgString( 'TRAINNPC_BASIC' ) , GearName( NPC ) );
		N := Random( N ) + 1;
		if Choices[ N ] > 0 then begin
			SetNAtt( NPC^.NA , NAG_Skill , Choices[ N ] , 1 );
			msg := ReplaceHash( msg , MsgString( 'SKILLNAME_' + BStr( Choices[ N ] ) ) );
		end else begin
			ApplyTalent( NPC , Abs( Choices[ N ] ) );
			msg := ReplaceHash( msg , MsgString( 'TALENT' + BStr( Abs( Choices[ N ] ) ) ) );
		end;
	end else begin
		{ No valid choices. Um... just increase a random stat. }
		msg := ReplaceHash( MsgString( 'TRAINNPC_STATS' ) , GearName( NPC ) );
		N := Random( 8 ) + 1;
		NPC^.Stat[ N ] := NPC^.Stat[ N ] + 1;
		msg := ReplaceHash( msg , MsgString( 'STATNAME_' + BStr( N ) ) );
	end;

	{ Increase the training spent counter. }
	AddNAtt( NPC^.NA , NAG_Narrative , NAS_LancemateTraining_Spent , 1 );

	YesNoMenu( GB , msg , '' , '' );
end;


Procedure InvokeEvent( Event: String; GB: GameBoardPtr; Source: GearPtr; var Trigger: String );
	{ Do whatever is requested by game script EVENT. }
	{ SOURCE refers to the virtual gear which is currently being }
	{ used- it may be a SCENE gear, or a CONVERSATION gear, or }
	{ whatever else I might add in the future. }
var
	cmd: String;
begin
	{ Store the time this gear was last invoked. }
	if ( Source <> Nil ) and ( GB <> Nil ) then SetNAtt( Source^.NA , NAG_Narrative , NAS_ScriptActivatedTimer , GB^.ComTime );

	{ Process the event string. }
	while ( Event <> '' ) do begin
		cmd := UpCase( ExtractWord( Event ) );

		if SAttValue( Script_Macros , cmd ) <> '' then begin
			{ Install the macro. }
			InitiateMacro( GB , Source , Event , SAttValue( Script_Macros , cmd ) );

		end else if ( cmd <> '' ) and ( cmd[1] = '&' ) then begin
			{ Install a local macro. }
			InitiateLocalMacro( GB , Event , cmd , Source );

		end else if not Attempt_Gear_Grab( Cmd , Event , GB , Source ) then begin
			{ If this is a gear-grabbing command, our work here is done. }

		if cmd = 'EXIT' then ProcessExit( Event , GB , Source )
		else if cmd = 'FORCEEXIT' then ProcessForceExit( Event , GB , Source )
		else if cmd = 'GADDNATT' then ProcessGAddNAtt( Event , GB , Source )
		else if cmd = 'GSETNATT' then ProcessGSetNAtt( Event , GB , Source )
		else if cmd = 'GADDSTAT' then ProcessGAddStat( Event , GB , Source )
		else if cmd = 'GSETSTAT' then ProcessGSetStat( Event , GB , Source )
		else if cmd = 'GSETSATT' then ProcessGSetSAtt( Event , GB , Source )
		else if cmd = 'DELETEGG' then ProcessDeleteGG( GB , Source )
		else if cmd = 'MOVEGG' then ProcessMoveGG( Event , GB , Source )
		else if cmd = 'MOVEANDPACIFYGG' then ProcessMoveAndPacifyGG( Event , GB , Source )
		else if cmd = 'DEPLOYGG' then ProcessDeployGG( Event , GB , Source )
		else if cmd = 'DYNAGG' then ProcessDynaGG( Event , GB , Source )
		else if cmd = 'GIVEGG' then ProcessGiveGG( GB )
		else if cmd = 'GNEWPART' then ProcessGNewPart( Event , GB , Source )
		else if cmd = 'RETURN' then ProcessReturn( GB )
		else if cmd = 'PRINT' then ProcessPrint( Event , GB , Source )
		else if cmd = 'ALERT' then ProcessAlert( Event , GB , Source )
		else if cmd = 'GMONOLOGUE' then ProcessGMonologue( Event , GB , Source )
		else if cmd = 'ADDDEBRIEFING' then ProcessAddDebriefing( Event , GB , Source )
		else if cmd = 'MEMO' then ProcessMemo( Event , GB , Source )
		else if cmd = 'PMEMO' then ProcessPMemo( Event , GB , Source )
		else if cmd = 'SMEMO' then ProcessSMemo( Event , GB , Source )
		else if cmd = 'QMEMO' then ProcessQMemo( Event , GB , Source )
		else if cmd = 'NEWS' then ProcessNews( Event , GB , Source )
		else if cmd = 'EMAIL' then ProcessEMail( Event , GB , Source )
		else if cmd = 'HISTORY' then ProcessHistory( Event , GB , Source )
		else if cmd = 'VICTORY' then ProcessVictory( GB )
		else if cmd = 'VMSG' then ProcessValueMessage( Event , GB , Source )
		else if cmd = 'SAY' then ProcessSay( Event , GB , Source )
		else if cmd = 'SAYPLOTMSG' then ProcessSayPlotMsg( Event , GB , Source )
		else if cmd = 'SAYANYTHING' then ProcessSayAnything( GB )
		else if cmd = 'ACTIVATEMEME' then ProcessActivateMeme( Event , GB , Source )
		else if cmd = 'IFGINPLAY' then ProcessIfGInPlay( Event , GB , Source )
		else if cmd = 'IFGOK' then ProcessIfGOK( Event , Source )
		else if cmd = 'IFGDEAD' then ProcessIfGDead( Event , Source )
		else if cmd = 'IFGSEXY' then ProcessIfGSexy( Event , GB , Source )
		else if cmd = 'IFGSEALED' then ProcessIfGSealed( Event , Source )
		else if cmd = 'IFGARCHENEMY' then ProcessIfGArchEnemy( Event , GB , Source )
		else if cmd = 'IFGARCHALLY' then ProcessIfGArchAlly( Event , GB , Source )
		else if cmd = 'IFGHASSKILL' then ProcessIfGHasSkill( Event , GB , Source )
		else if cmd = 'IFGCANJOINLANCE' then ProcessIfGCanJoinLance( Event , GB , Source )
		else if cmd = 'IFMECHACANENTERSCENE' then ProcessIfMechaCanEnterScene( Event , GB , Source )
		else if cmd = 'IFTEAMCANSEEGG' then ProcessIfTeamCanSeeGG( Event , GB , Source )
		else if cmd = 'IFFACTION' then ProcessIfFaction( Event , GB , Source )
		else if cmd = 'IFSCENE' then ProcessIfScene( Event , GB , Source )
		else if cmd = 'IFSAFEAREA' then ProcessIfSafeArea( Event , GB , Source )
		else if cmd = 'IFKEYITEM' then ProcessIfKeyItem( Event , GB , Source )
		else if cmd = 'IFGHASITEM' then ProcessIfGHasItem( Event , GB , Source )
		else if cmd = 'IF=' then ProcessIfEqual( Event , GB , Source )
		else if cmd = 'IF#' then ProcessIfNotEqual( Event , GB , Source )
		else if cmd = 'IFG' then ProcessIfGreater( Event , GB , Source )
		else if cmd = 'IFSTORYLESS' then ProcessIfStoryless( Event , Source )
		else if cmd = 'IFYESNO' then ProcessIfYesNo( Event , GB , Source )
		else if cmd = 'IFSKILLTEST' then ProcessIfSkillTest( Event , GB , Source )
		else if cmd = 'IFUSKILLTEST' then ProcessIfUSkillTest( Event , GB , Source )
		else if cmd = 'IFNOOBJECTIONS' then ProcessIfNoObjections( Event , GB , Source )
		else if cmd = 'IFMERITBADGE' then ProcessIfMeritBadge( Event , GB , Source )
		else if cmd = 'TORD' then ProcessTeamOrders( Event , GB , Source )
		else if cmd = 'COMPOSE' then ProcessCompose( Event , GB , Source )
		else if cmd = 'BLOCK' then ProcessBlock( Trigger )
		else if cmd = 'ACCEPT' then ProcessAccept( Trigger )
		else if cmd = 'NEWCHAT' then ProcessNewChat( GB )
		else if cmd = 'ENDCHAT' then ProcessEndChat
		else if cmd = 'REVERTPERSONA' then RevertPersona( Event , GB , Source )
		else if cmd = 'GOTO' then ProcessGoto( Event , Source )
		else if cmd = 'ADDCHAT' then ProcessAddChat( Event , GB , Source )
		else if cmd = 'SEEKTERR' then ProcessSeekTerr( Event , GB , Source )
		else if cmd = 'SHOP' then ProcessShop( Event , GB , Source )
		else if cmd = 'SCHOOL' then ProcessSchool( Event , GB , Source )
		else if cmd = 'EXPRESSDELIVERY' then ProcessExpressDelivery( Event , GB , Source )
		else if cmd = 'SHUTTLE' then ProcessShuttle( Event , GB , Source )
		else if cmd = 'ENDPLOT' then ProcessEndPlot( Event , GB , Source )
		else if cmd = 'ENDPLOTSBYCONID' then ProcessEndPlotsByConID( Event , GB , Source )
		else if cmd = 'ENDSTORY' then ProcessEndStory( GB , Source )
		else if cmd = 'PURGESTORY' then ProcessPurgeStory( GB , Source )
		else if cmd = 'TREPUTATION' then ProcessTReputation( Event , GB , Source )
		else if cmd = 'LOSERENOWN' then ProcessLoseRenown( GB )
		else if cmd = 'XPV' then ProcessXPV( Event , GB , Source )
		else if cmd = 'MECHAPRIZE' then ProcessMechaPrize( Event , GB , Source )
		else if cmd = 'NEWD' then ProcessNewD( Event , GB , Source )
		else if cmd = 'WMECHA' then ProcessWMecha( Event , GB , Source )
		else if cmd = 'WMONSTER' then ProcessWMonster( Event , GB , Source )
		else if cmd = 'STARTPLOT' then ProcessStartPlot( Event , GB , Source )
		else if cmd = 'UPDATEPLOTS' then ProcessUpdatePlots( Trigger , Event , GB , Source )
		else if cmd = 'STARTSTORY' then ProcessStartStory( Event , GB , Source )
		else if cmd = 'SETMOOD' then ProcessSetMood( Event , GB , Source )
		else if cmd = 'CHECKCOMPONENTS' then ProcessCheckComponents( GB , Source )
		else if cmd = 'NEXTCOMP' then ProcessNextComp( Event , GB , Source )
		else if cmd = 'GALTERCONTEXT' then ProcessGAlterContext( Event , GB , Source )
		else if cmd = 'ATTACK' then ProcessAttack( Event , GB , Source )
		else if cmd = 'SALVAGE' then ProcessSalvage( GB )
		else if cmd = 'RETREAT' then ProcessRetreat( Event , GB , Source )
		else if cmd = 'GRUNAWAY' then ProcessGRunAway( Event , GB , Source )
		else if cmd = 'AIRRAIDSIREN' then ProcessAirRaidSiren( GB )
		else if cmd = 'FORCECHAT' then ProcessForceChat( Event , GB , Source )
		else if cmd = 'ANNOUNCE' then ProcessAnnounce( Event , GB , Source )
		else if cmd = 'TIME' then ProcessTime( Event , GB , Source )
		else if cmd = 'TRANSFORM' then ProcessTransform( Event , GB , Source )
		else if cmd = 'SEEKGATE' then ProcessSeekGate( Event , GB , Source )
		else if cmd = 'TRIGGER' then ProcessTrigger( Event , GB , Source )
		else if cmd = 'TRIGGER0' then ProcessTrigger0( Event , GB , Source )
		else if cmd = 'LTRIGGER' then ProcessLTrigger( Event , GB , Source )
		else if cmd = 'UPDATEPROPS' then ProcessUpdateProps( GB )
		else if cmd = 'MORETEXT' then ProcessMoreText( Event , GB , Source )
		else if cmd = 'MOREMEMO' then ProcessMoreMemo( Event , GB )
		else if cmd = 'BOMB' then ProcessBomb( GB )
		else if cmd = 'GSKILLXP' then ProcessGSkillXP( Event , GB , Source )
		else if cmd = 'GSKILLLEVEL' then ProcessGSkillLevel( Event , GB , Source )
		else if cmd = 'GMORALEDMG' then ProcessGMoraleDmg( Event , GB , Source )
		else if cmd = 'DRAWTERR' then ProcessDrawTerr( Event , GB , Source )
		else if cmd = 'MAGICMAP' then ProcessMagicMap( GB )
		else if cmd = 'GMENTAL' then ProcessGMental( GB )
		else if cmd = 'GSTAMINA' then ProcessGStamina( GB )
		else if cmd = 'GQUITLANCE' then ProcessGQuitLance( GB )
		else if cmd = 'GJOINLANCE' then ProcessGJoinLance( GB )
		else if cmd = 'GOPENINV' then ProcessGOpenInv( GB )
		else if cmd = 'ARENAREP' then ProcessArenaRep( Event , GB , Source )
		else if cmd = 'ADDREACT' then ProcessAddReact( Event , GB , Source )
		else if cmd = 'PUMPNEWS' then ProcessPumpNews( GB )
		else if cmd = 'SETENCOUNTER' then ProcessSetEncounter( Event , GB , Source )
		else if cmd = 'TRAINNPC' then ProcessTrainNPC( Event , GB , Source )
		else if cmd <> '' then begin
					DialogMsg( 'ERROR: Unknown ASL command ' + cmd );
					DialogMsg( 'CONTEXT: ' + event );
				end
		end; { If not GrabGear }
	end;

	{ Process rounding-up events here. }
	if ( SCRIPT_DynamicEncounter <> Nil ) and ( SCRIPT_DynamicEncounter^.V > 0 ) then CheckMechaEquipped( GB );
end;

Procedure HandleWhereAreYou( GB: GameBoardPtr );
	{ The PC has asked the NPC where he is. The NPC will tell the PC }
	{ his or her current location. }
var
	SID: Integer;
begin
	SID := FindSceneID( I_NPC , GB );
	if SID <> 0 then begin
		CHAT_Message := ReplaceHash( MsgString( 'WHEREAREYOU_IAMHERE' ) , SceneName( GB , SID , True ) );
	end else begin
		CHAT_Message := MsgString( 'WHEREAREYOU_Dunno' );
	end;
end;


Procedure HandleAskAboutRumors( GB: GameBoardPtr; Source: GearPtr );
	{ The PC wants to find some rumors. Make it so. }
var
	RL,RL_Skill: GearPtr;
	SkVal,BestScore,SkRoll: Integer;
	NPCDesc,RL_Script: String;
	Rumor_List,R: SAttPtr;
	Rumor_Error: Boolean;
	RPM: RPGMenuPtr;
begin
	{ Error check- no rumor scumming. }
	if NAttValue( I_NPC^.NA , NAG_Personal , NAS_RumorRecharge ) > GB^.ComTime then begin
		Chat_Message := MsgString( 'RUMOR_IAlreadyToldYou' + BStr( Random( 6 ) + 1 ) );
		Exit;
	end;

	{ Step one- Locate an appropriate skill. }
	RL_Skill := Nil;
	RL := rumor_leads;
	BestScore := 0;
	NPCDesc := XNPCDesc( GB , GG_LocateAdventure( GB , Source ) , I_NPC );
	while ( RL <> Nil ) do begin
		if ( RL^.S >= 1 ) and ( RL^.S <= NumSkill ) and HasSkill( I_PC , RL^.S ) and PartMatchesCriteria( NPCDesc , SAttValue( RL^.SA , 'REQUIRES' ) ) then begin
			{ This skill might be of use. Check it to see. }
			if RL_Skill = Nil then begin
				RL_Skill := RL;
				BestScore := SkillValue( I_PC , RL^.S , STAT_Charm );
			end else begin
				SkVal := SkillValue( I_PC , RL^.S , STAT_Charm );
				if SkVal > BestScore then begin
					RL_Skill := RL;
					BestScore := SkVal;
				end;
			end;
		end;
		RL := RL^.Next;
	end;

	{ Make the skill roll. }
	if ( RL_Skill <> Nil ) and ( BestScore > 3 ) then begin
		{ Make the skill roll here. }
		SkRoll := SkillRoll( GB , I_PC , RL_Skill^.S , STAT_Charm , BasicSkillTarget( NAttValue( I_PC^.NA , NAG_CharDescription , NAS_Renowned ) ) , 0 , False , True );
	end else begin
		{ Make a default crappy skill roll, and find the default lead. }
		SkRoll := RollStep( 3 );
		RL_Skill := SeekCurrentLevelGear( rumor_leads , GG_Persona , 0 );
	end;

	{ If this NPC has a relationship with the PC, the skill roll cannot fall }
	{ beneath an amount appropriate to the reaction score. }
	if NAttValue( I_NPC^.NA , NAG_Relationship , 0 ) > 0 then begin
		SkVal := BasicSkillTarget( ReactionScore( GB^.Scene , I_PC , I_NPC ) );
		if SkVal > SkRoll then SkRoll := SkVal;
	end;

	{ Harvest a list of rumors based on the skill roll. }
	{ As the rumors are added to the list, convert them to memos. }
	Rumor_List := RevealRumors( GB , I_NPC , SkRoll , Rumor_Error );

	{ If our rumor list is not empty, do the lead-in and then present those }
	{ rumors to the player. If it is empty, print a know nothing message. }
	if Rumor_List <> Nil then begin
		{ Play the RL_Skill dialog. }
		RL_Script := AS_GetString( RL_Skill , 'START' );

		{ Use NPCDesc as a dummy trigger. }
		InvokeEvent( RL_Script , GB , RL_Skill , NPCDesc );

		{ Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
		RPM^.Mode := RPMNoCancel;
		AddRPGMenuItem( RPM , MsgString( 'Continue' ) , 1 );

		{ Show the rumors next. }
		R := Rumor_List;
		while R <> Nil do begin
			SelectMenu( RPM , @InteractRedraw );
			Chat_Message := MadLibString( RLI_List ) + ' ' + R^.Info;
			R := R^.Next;
		end;

		{ Dispose of the rumor list. }
		DisposeSAtt( Rumor_List );
		DisposeRPGMenu( RPM );

	end else begin
		{ Set the chat message. }
		Chat_Message := MsgString( 'RUMOR_NoRumors' + BStr( Random( 6 ) + 1 ) );

	end;

	{ Set the recharge counter for this NPC. }
	if not Rumor_Error then SetNAtt( I_NPC^.NA , NAG_Personal , NAS_RumorRecharge , GB^.ComTime + 21600 + Random( 7200 ) - Random( 7200 ) )
	else SetNAtt( I_NPC^.NA , NAG_Personal , NAS_RumorRecharge , GB^.ComTime + 10 );
end;


Procedure AddLancemate( GB: GameBoardPtr; NPC: GearPtr );
	{ Add the listed NPC to the PC's lance. }
var
	Mecha,Pilot: GearPtr;
	Timer: LongInt;
begin
	{ This NPC will have to quit their current team to do this... }
	{ so, better set a trigger. }
	SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) ) );

	{ If this is the first time the lancemate has joined, add the NPC's mecha. }
	if IsACombatant( NPC ) and ( NAttValue( NPC^.NA , NAG_Narrative , NAS_GaveLMMecha ) = 0 ) then begin
		Mecha := SelectNPCMecha( GB , GB^.Scene , NPC );
		if Mecha <> Nil then begin
			SetNAtt( Mecha^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );
			DeployGear( GB , Mecha , False );
			AssociatePilotMek( GB^.Meks , NPC , Mecha );
			SetNAtt( NPC^.NA , NAG_Narrative , NAS_GaveLMMecha , 1 );
		end;
	end;

	{ Set the plot recharge timer to at least 12 hours from now. }
	Timer := NAttValue( NPC^.NA , NAG_Personal , NAS_PlotRecharge );
	if Timer < ( GB^.ComTime + 43200 ) then SetNAtt( NPC^.NA , NAG_Personal , NAS_PlotRecharge , GB^.ComTime + 43200 );

	Pilot := LocatePilot( NPC );
	if Pilot <> NPC then SetNAtt( Pilot^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );

	SetNAtt( NPC^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );
	SetLancemateOrders( GB );
end;

Function AddLancemateFrontEnd( GB: GameBoardPtr; PC,NPC: GearPtr; CanCancel: Boolean ): Boolean;
	{ NPC wants to join the lance. If NPC isn't a temp lancemate, and the lance is already }
	{ full, prompt to remove a member before NPC can join. }
	{ Return TRUE if the lancemate was added, or FALSE otherwise. }
var
	NoCancel: Boolean;
	RPM: RPGMenuPtr;
	LM: GearPtr;
	N: Integer;
begin
	NoCancel := True;

	{ Step One- Check NPC's temp status, then count up the number of lancemates }
	{ to see if there's gonna be a problem. }
	if NAttValue( NPC^.NA , NAG_CharDescription , NAS_CharType ) <> NAV_TempLancemate then begin
		{ Initialize some values. }
		ASRD_GameBoard := GB;
		ASRD_MemoMessage := ReplaceHash( MsgString( 'JOINFE_Need_Space' ) , GearName( NPC ) );

		{ Count up the number of lancemates. }
		while ( LancematesPresent( GB ) >= NumLancemateSlots( GB^.Scene , PC ) ) and NoCancel do begin
			{ Remove lancemates to make room for NPC. }
			{ Create the menu. }
			RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoMenu );

			{ Create the list. }
			LM := GB^.Meks;
			N := 1;
			while LM <> Nil do begin
				if ( NAttValue( LM^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and GearActive( LM ) and IsRegularLancemate( LM ) then begin
					AddRPGMenuItem( RPM , PilotName( LM ) , N );
				end;

				Inc( N );
				LM := LM^.Next;
			end;

			RPMSortAlpha( RPM );
			AlphaKeyMenu( RPM );
			if CanCancel then AddRPGMenuItem( RPM , MsgString( 'Cancel' ) , -1 )
			else RPM^.Mode := RPMNoCancel;

			N := SelectMenu( RPM , @MemoPageReDraw );
			DisposeRPGMenu( RPM );
			if N = -1 then NoCancel := False
			else begin
				LM := RetrieveGearSib( GB^.Meks , N );
				RemoveLancemate( GB , LM , True );
			end;
		end;
	end;

	{ Step Two- we apparently have room now. Add the lancemate to the party. }
	if NoCancel then AddLancemate( GB , NPC );

	AddLancemateFrontEnd := NoCancel;
end;

Procedure AttemptJoin( GB: GameBoardPtr );
	{ I_NPC will attempt to join the party. Yay! }
var
	LMP: Integer;	{ Lancemates Present }
begin
	{ Make sure we've got an NPC to deal with. }
	if I_NPC = Nil then Exit;
	{ Also make sure the NPC isn't currently a member of the team. }
	if NAttValue( I_NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam then Exit;

	{ Need two more available lancemate points than are currently in use. }
	if CanJoinLance( GB , I_PC , I_NPC ) then begin
		if AddLancemateFrontEnd( GB , I_PC , I_NPC , True ) then CHAT_Message := MsgString( 'JOIN_JOIN' )
		else CHAT_Message := MsgString( 'JOIN_Cancel' );
	end else begin
		LMP := LancematesPresent( GB );
		if ReactionScore( GB^.Scene , I_PC , I_NPC ) < 25 then begin
			CHAT_Message := MsgString( 'JOIN_REFUSE' );
		end else if LMP >= NumLancemateSlots( GB^.Scene , I_PC ) then begin
			CHAT_Message := MsgString( 'JOIN_NOPOINT' );
		end else begin
			CHAT_Message := MsgString( 'JOIN_BUSY' );
		end;
	end;
end;

Procedure RemoveLancemate( GB: GameBoardPtr; Mek: GearPtr; DoMessage: Boolean );
	{ Remove NPC from the party. }
	{ If this location isn't a good one for the LM, move the LM to a better place. }
var
	NPC,DestScene: GearPtr;
	msg: String;
begin
	if Mek^.G = GG_Mecha then begin
		NPC := ExtractPilot( Mek );
		if NPC = Nil then Exit;
		DeployGear( GB , NPC , False );
	end else begin
		NPC := Mek;
	end;

	if IsInvCom( GB^.Scene ) or ( not IsSafeArea( GB ) ) then begin
		{ This isn't a good place for the NPC to stay. Better move it }
		{ to somewhere else. }

		{ Step One- Locate the destination scene. }
		DestScene := SearchForScene( FindRootScene( GB^.Scene ) , Nil , GB , '(BUILDING|MEETING) PUBLIC -ENEMY' );

		if DestScene <> Nil then begin
			{ Step Two- Announce the lancemate's destination. }
			msg := ReplaceHash( MsgString( 'QUIT_LANCE_GO' ) , GearName( DestScene ) );

			{ Step Three- Delink the lancemate and send it there. }
			{  Note that NPC might actually be the NPC's mecha. Deal with it. }
			DelinkGearForMovement( GB , NPC );
			InsertInvCom( DestScene , NPC );
			SetSAtt( NPC^.SA , 'TEAMDATA <Ally>' );
			ChooseTeam( NPC , DestScene );

		end else begin
			{ Fail. Just stick the NPC here, for now. }
			msg := MsgString( 'QUIT_LANCE' );

			SetSAtt( NPC^.SA , 'TEAMDATA <Ally>' );
			ChooseTeam( NPC , GB^.Scene );
		end;
	end else begin
		{ The LM can just hang around here until the PC gets back. }
		msg := MsgString( 'QUIT_LANCE' );
		SetSAtt( NPC^.SA , 'TEAMDATA <Ally>' );
		ChooseTeam( NPC , GB^.Scene );
	end;

	{ Set the rumor recharge to six hours from now. After all, the LM }
	{ was hanging around with the PC... they need some time to hear things. }
	SetNAtt( NPC^.NA , NAG_Personal , NAS_RumorRecharge , GB^.ComTime + 21600 );

	if DoMessage then begin
		if NPC = I_NPC then begin
			CHAT_Message := msg;
		end else begin
			Monologue( GB , NPC , msg );
		end;
	end;
end;

Procedure HandleQuit( GB: GameBoardPtr );
	{ I_NPC will quit the party. }
begin
	if I_NPC = Nil then Exit;
	RemoveLancemate( GB , I_NPC , True );
end;


Procedure PruneNothings( var LList: GearPtr );
	{ Traverse the list. Anything marked as ABSOLUTELYNOTHING gets deleted, along with }
	{ all of its children gears. That's tough, but that's life... }
var
	L,L2: GearPtr;
begin
	L := LList;
	while L <> Nil do begin
		L2 := L^.Next;

		if L^.G = GG_AbsolutelyNothing then begin
			RemoveGear( LList , L );
		end else begin
			PruneNothings( L^.SubCom );
			PruneNothings( L^.InvCom );
		end;

		L := L2;
	end;
end;

Procedure HandleInteract( GB: GameBoardPtr; PC,NPC,Persona: GearPtr );
	{ The player has just entered a conversation. }
	{ HOW THIS WORKS: The interaction menu is built by an ASL script. }
	{ the player selects one of the provided responses, which will }
	{ either trigger another script ( V >= 0 ) or call one of the }
	{ standard interaction routines ( V < 0 ) }
var
	IntScr: String;		{ Interaction Script }
	N,FreeRumors: Integer;
	RTT: LongInt;		{ ReTalk Time }
	T: String;
	MI: RPGMenuItemPtr;	{ For removing options once they've been used. }
begin
	{ Start by allocating the menu. }
	IntMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InteractMenu );
	IntMenu^.Mode := RPMEscCancel;

	{ If this persona has been marked as "NoEscape", make sure the PC }
	{ can't quit the conversation just by pressing ESC. }
	if ( Persona <> Nil ) and ASTringHasBString( SAttValue( Persona^.SA , 'SPECIAL' ) , 'NOESCAPE' ) then IntMenu^.Mode := RPMNoCancel;

	{ Initialize interaction variables. }
	I_PC := PC;
	I_NPC := NPC;
	ASRD_GameBoard := GB;

	{ Since the conversation can be switched by REVERTPERSONA and maybe some other }
	{ effects, from this point onwards use I_PERSONA rather than PERSONA. }
	I_Persona := Persona;

	{ Add a divider to the skill roll history. }
	SkillCommentDivider;

	{ If the NPC is fully recharged from talking with you last time, }
	{ get full endurance of 10. Otherwise, only gets partial endurance. }
	if NAttValue( NPC^.NA , NAG_Personal , NAS_ReTalk ) > GB^.ComTime then begin
		I_Endurance := 1;
	end else begin
		I_Endurance := 10;
	end;

	{ Determine the number of "Free" rumors the PC will get. }
	FreeRumors := 0;
	N := ReactionScore( GB^.Scene , PC , NPC );
	if N > 20 then FreeRumors := ( N - 13 ) div 7;
	N := CStat( PC , STAT_Charm );
	if N > 12 then FreeRumors := FreeRumors + Random( N - 11 );

	{ Invoke the greeting event. }
	if ( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and ( NAttValue( NPC^.NA , NAG_Chardescription , NAS_CharType ) <> NAV_TempLancemate ) and (( Persona = Nil ) or (( Persona^.Parent <> Nil ) and ( Persona^.Parent^.G = GG_Scene ))) then begin
		{ Lancemates won't use their local personas while part of the lance. }
		{ Hence the mother of all conditionals above... }
		I_PERSONA := lancemate_tactics_persona;
	end;

	if I_Persona <> Nil then begin
		IntScr := AS_GetString( I_Persona , 'GREETING' );
	end else begin
		{ If there is no standard greeting, set the event to }
		{ build the default interaction menu. }
		IntScr := 'SAYANYTHING NEWCHAT';
	end;
	T := 'Greeting';
	InvokeEvent( IntScr , GB , I_Persona , T );

	repeat
		{ Print the NPC description. }
		{ This could change depending upon what the PC does. }
		if IntMenu^.NumItem > 0 then begin
			ASRD_GameBoard := GB;
			CHAT_React := ReactionScore( GB^.Scene , PC , NPC );
			N := SelectMenu( IntMenu , @InteractRedraw );

		end else begin
			{ If the menu is empty, we must leave this procedure. }
			{ More importantly, we better not do anything in }
			{ the conditional below... Set N to equal a "goodbye" result. }
			N := -1;
		end;

		if N >= 0 then begin
			{ One of the placed options have been triggered. }
			{ Attempt to find the appropriate script to }
			{ invoke. }
			IntScr := AS_GetString( I_Persona , 'RESULT' + BStr( N ) );
			InvokeEvent( IntScr , GB , I_Persona , T );

		end else if N = CMD_Join then begin
			AttemptJoin( GB );
			{ After attempting to join, remove the JOIN option. }
			MI := SetItemByValue( IntMenu , CMD_Join );
			if MI <> Nil then RemoveRPGMenuItem( IntMenu , MI );
			SetItemByPosition( IntMenu , 1 );

		end else if N = CMD_Quit then begin
			HandleQuit( GB );
			ClearMenu( IntMenu );

		end else if N = CMD_WhereAreYou then begin
			HandleWhereAreYou( GB );

		end else if N = CMD_AskAboutRumors then begin
			HandleAskAboutRumors( GB , Persona );
			MI := SetItemByValue( IntMenu , CMD_AskAboutRumors );
			if MI <> Nil then RemoveRPGMenuItem( IntMenu , MI );
			SetItemByPosition( IntMenu , 1 );
		end;

	until ( N = -1 ) or ( IntMenu^.NumItem < 1 ) or ( I_Endurance < 1 ) or ( I_NPC = Nil );

	{ If the menu is empty, pause for a minute. Or at least a keypress. }
	if IntMenu^.NumItem < 1 then begin
		InteractRedraw;
		DoFlip;
		MoreKey;
	end;

	{ If the conversation ended because the NPC ran out of patience, }
	{ store a negative reaction modifier. }
	if I_Endurance < 1 then begin
		AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) , -5 );

		{ Overchatting is a SOCIABLE action. }
		AddReputation( PC , 3 , 1 );
	end;

	{ After the conversation is over, prune any ABSOLUTELYNOTHINGs that may }
	{ have popped up. }
	if Persona <> Nil then begin
		Persona := FindRoot( Persona );
		PruneNothings( Persona );
	end;

	{ Set the ReTalk value. }
	{ Base retalk time is 1500 ticks; may be raised or lowered depending }
	{ upon the NPC's ENDURANCE and also how well the NPC likes the PC. }
	if ( I_NPC <> Nil ) and ( SCRIPT_DynamicEncounter = Nil ) then begin
		RTT := GB^.ComTime + 1500 - ( 15 * ReactionScore( GB^.Scene , PC , NPC ) ) - ( 50 * I_Endurance );
		if RTT < ( GB^.ComTime + AP_Minute ) then RTT := GB^.ComTime + AP_Minute;
		SetNAtt( NPC^.NA , NAG_Personal , NAS_ReTalk , RTT );
	end;

	{ Set the NumberOfConversations counter. }
	if I_NPC <> Nil then AddNAtt( NPC^.NA , NAG_Personal , NAS_NumConversation , 1 );
	I_NPC := Nil;

	{ Get rid of the menu. }
	DisposeRPGMenu( IntMenu );
	DisposeSAtt( I_Rumors );
end;

Procedure PCDoVerbalAttack( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ The PC wants to verbally abuse this NPC. If it's possible do so. If it }
	{ isn't possible, then explain why. }
begin
	NPC := LocatePilot( NPC );
	if CurrentMental( PC ) < 1 then begin
		DialogMsg( MsgSTring( 'VERBALATTACK_NoMP' ) );
	end else if ( NPC <> Nil ) and CanSpeakWithTarget( GB , PC , NPC ) then begin
		if AreEnemies( GB , PC , NPC ) then begin
			DoVerbalAttack( GB , PC , FindRoot( NPC ) );
			{ When the PC taunts an enemy, it takes an action. }
			SetNAtt( PC^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ReactionTime( PC ) );
		end else begin
			DialogMsg( ReplaceHash( MsgSTring( 'TAUNT_OnlyEnemies' ) , GearName( NPC ) ) );
		end;
	end else begin
		DialogMsg( ReplaceHash( MsgSTring( 'TALKING_TooFar' ) , GearName( NPC ) ) );
	end;
end;

Procedure DoTalkingWIthNPC( GB: GameBoardPtr; PC,Mek: GearPtr; ByTelephone: Boolean );
	{ Actually handle the talking with an NPC already selected. }
var
	Persona,NPC: GearPtr;
	CID: Integer;
	React: Integer;
	ReTalk: LongInt;
begin
	NPC := LocatePilot( Mek );
	if ( NPC <> Nil ) and GearOperational( NPC ) and AreEnemies( GB , Mek , PC ) and NotAnAnimal( NPC ) and IsFoundAlongTrack( GB^.Meks , FindRoot( NPC ) ) and ( NATtValue( NPC^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) <> NAV_NowSurrendered ) then begin
		PCDoVerbalAttack( GB , PC , NPC );

	end else if ( NPC <> Nil ) and GearOperational( NPC ) then begin
		if ByTelephone or CanSpeakWithTarget( GB , PC , NPC ) then begin
			CID := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
			if CID <> 0 then begin
				{ Everything should be okay to talk... Now see if the NPC wants to. }
				{ Determine the NPC's RETALK and REACT values. }
				ReTalk := NAttValue( NPC^.NA , NAG_Personal , NAS_Retalk );
				React := ReactionScore( GB^.Scene , PC , NPC );

				Persona := SeekPersona( GB , CID );

				{ Surrendered NPCs never refuse to talk. }
				if NATtValue( NPC^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) = NAV_NowSurrendered then begin
					DialogMsg( ReplaceHash( MsgSTring( 'TALKING_Start' ) , GearName( NPC ) ) );

					HandleInteract( GB , PC , NPC , Persona );
					CombatDisplay( gb );

				{ If the NPC really doesn't like the PC, }
				{ they'll refuse to talk on principle. }
				end else if ( ( React + RollStep( SkillValue ( PC , NAS_Conversation , STAT_Ego ) ) ) < -Random( 120 ) ) or ( AreEnemies( GB , NPC , PC ) and IsFoundAlongTrack( GB^.Meks , NPC ) ) then begin
					DialogMsg( ReplaceHash( MsgSTring( 'TALKING_RefuseHard' ) , GearName( NPC ) ) );
					SetNAtt( NPC^.NA , NAG_Personal , NAS_Retalk , GB^.ComTime + 1500 );

				{ If the NPC is ready to talk, is friendly with the PC, or has a PERSONA gear defined, }
				{ they'll be willing to talk. }
				end else if ( ReTalk < GB^.ComTime ) or ( Random( 50 ) < ( React + 20 ) ) or ( Persona <> Nil ) then begin
					DialogMsg( ReplaceHash( MsgSTring( 'TALKING_Start' ) , GearName( NPC ) ) );

					HandleInteract( GB , PC , NPC , Persona );
					CombatDisplay( gb );

				end else begin
					DialogMsg( ReplaceHash( MsgSTring( 'TALKING_RefuseSoft' ) , GearName( NPC ) ) );

				end;

				WaitAMinute( GB , PC , ReactionTime( PC ) );
			end else begin
				DialogMsg( MsgSTring( 'TALKING_NoReply' ) );
			end;
		end else begin
			DialogMsg( ReplaceHash( MsgSTring( 'TALKING_TooFar' ) , GearName( NPC ) ) );
		end;
	end else begin
		DialogMsg( 'Not found!' );
	end;
end;

Procedure ForceInteract( GB: GameBoardPtr; CID: LongInt );
	{ Attempt to force the PC to converse with the provided NPC. }
var
	PC,NPC,Interact: GearPtr;
begin
	{ Locate all the required elements. }
	PC := LocatePilot( GG_LocatePC( GB ) );
	NPC := SeekGearByCID( GB^.Meks , CID );
	if NPC = Nil then NPC := SeekGearByCID( FindRoot( GB^.Scene ) , CID );
	Interact := SeekPersona( GB , CID );

	if ( PC <> Nil ) and ( NPC <> Nil ) and NotDestroyed( PC ) then begin
		{ Before initiating the conversation, get rid of the }
		{ recharge timer, since the NPC initiated this chat }
		{ and won't get pissed off. }
		SetNAtt( NPC^.NA , NAG_Personal , NAS_ReTalk , 0 );

		{ Print an appropriate message. }
		if NPC^.Parent = Nil then begin
			{ The NPC has no parent, so it must be on the gameboard }
			{ and not in a mecha. Use the conversation message. }
			DialogMsg( ReplaceHash( MsgString( 'FORCECHAT_SPEAK' ) , GearName( NPC ) ) );
		end else begin
			{ Use the contact message. }
			DialogMsg( ReplaceHash( MsgString( 'FORCECHAT_CONTACT' ) , GearName( NPC ) ) );
		end;

		{ Hand everything to the interaction procedure. }
		HandleInteract( GB , PC , NPC , Interact );
	end;
end;

Function TriggerGearScript( GB: GameBoardPtr; Source: GearPtr; var Trigger: String ): Boolean;
	{ Attempt to trigger the requested script in this gear. If the }
	{ script cannot be found, then do nothing. }
var
	E: String;
	it: Boolean;
begin
	it := False;
	if Source <> Nil then begin
		E := AS_GetString( Source , Trigger );
		if E <> '' then begin
			InvokeEvent( E , GB , Source , Trigger );
			it := True;
		end;
	end;
	TriggerGearScript := it;
end;

Function CheckTriggerAlongPath( var T: String; GB: GameBoardPtr; Plot: GearPtr; CheckAll: Boolean ): Boolean;
	{ Check all the active narrative gears in this list (plots, stories, and factions) }
	{ looking for events which match the provided trigger. }
	{ Return TRUE if an event was invoked, or FALSE if no event was encountered. }
var
	P2: GearPtr;
	it,I2: Boolean;
	LT,TempList: SAttPtr;	{ Local Trigger counter }
	LT_tmp: STring;	{ The content of the local trigger currently being processed. }
begin
	it := False;
	while ( Plot <> Nil ) and ( T <> '' ) do begin
		P2 := Plot^.Next;
		if CheckAll or ( Plot^.G = GG_Plot ) or ( Plot^.G = GG_Faction ) or ( Plot^.G = GG_Story ) or ( Plot^.G = GG_Adventure ) or ( Plot^.G = GG_CityMood ) then begin
			{ FACTIONs and STORYs can hold active plots in their InvCom. }
			if ( Plot^.G = GG_Faction ) or ( Plot^.G = GG_Story ) or ( Plot^.G = GG_Adventure ) then CheckTriggerAlongPath( T , GB , Plot^.InvCom , CheckAll);

			{ Initialize the list of local triggers. }
			if local_triggers <> Nil then DisposeSATt( local_triggers );

			{ Check the trigger against this gear's scripts. }
			I2 := TriggerGearScript( GB , Plot , T );
			it := it or I2;

			{ If any local triggers were tripped, call them now. }
			while local_triggers <> Nil do begin
				TempList := local_triggers;
				local_triggers := Nil;
				while TempList <> Nil do begin
					LT := TempList;
					LT_Tmp := LT^.Info;
					RemoveSAtt( TempList , LT );
					TriggerGearScript( GB , Plot , LT_Tmp );
				end;
			end;

			{ The trigger above might have changed the }
			{ structure, so reset P2. }
			P2 := Plot^.Next;

			{ Remove the plot, if it's been advanced. }
			if Plot^.G = GG_AbsolutelyNothing then begin
				if IsInvCom( Plot ) then RemoveGear( Plot^.Parent^.InvCom , Plot )
				else if IsSubCom( Plot ) then RemoveGear( Plot^.Parent^.SubCom , Plot );
			end;
		end;
		Plot := P2;
	end;
	CheckTriggerAlongPath := it;
end;

Procedure HandleTriggers( GB: GameBoardPtr );
	{ Go through the list of triggers, enacting events if any are }
	{ found. Deallocate the triggers as they are processed. }
var
	TList,TP: SAttPtr;	{ Trigger List , Trigger Pointer }
	E,msg: String;
	City: GearPtr;
begin
	IntMenu := Nil;

	{ Only try to implement triggers if this gameboard has a scenario }
	{ defined. }
	if GB^.Scene <> Nil then begin

		{ Some of the events we process might add their own }
		{ triggers to the list. So, we check all the triggers }
		{ currently set, then look at the GB^.Trig list again }
		{ to see if any more got put there. }
		while GB^.Trig <> Nil do begin
			{ Copy the list pointer to TList, clear the }
			{ list pointer from GB, and set the pointer }
			{ to the first trigger. }
			TList := GB^.Trig;
			GB^.Trig := Nil;
			TP := TList;

			while TP <> Nil do begin
				{ Commands can be embedded in the triggers list. }
				{ The actual point of this is to allow scripts }
				{ to automatically activate interactions & props. }
				if ( Length( TP^.Info ) > 0 ) and ( TP^.Info[1] = '!' ) then begin
					{ Copy the command. }
					E := UpCase( ExtractWord( TP^.Info ) );
					DeleteFirstChar( E );

					if E = 'TALK' then begin
						ForceInteract( GB , ExtractValue( TP^.Info ) );
					end else if E = 'ANNOUNCE' then begin
						msg := msgString( TP^.Info );
						if msg <> '' then YesNoMenu( GB , msg , '' , '' );
					end;

					{ Clear this trigger. }
					TP^.Info := '';

				end else if TP^.Info <> '' then begin
					{ If there is a SAtt in the scenario description }
					{ named after this trigger description, it will }
					{ happen now. First, see if such an event exists. }

					{ Check the PLOTS, FACTIONS and STORIES in }
					{ Adventure/InvCom first. }
					if GB^.Scene^.Parent <> Nil then begin
						CheckTriggerAlongPath( TP^.Info , GB , FindRoot( GB^.Scene ) , False );
					end;

					{ Check for quests and moods in the current city next. }
					City := FindRootScene( GB^.Scene );
					if ( City <> Nil ) and ( TP^.Info <> '' ) then begin
						CheckTriggerAlongPath( TP^.Info , GB , City^.SubCom , False );
					end;

					{ Check the current scene last. }
					if TP^.Info <> '' then TriggerGearScript( GB , GB^.Scene , TP^.Info );

				end;

				TP := TP^.Next;
			end;

			{ Get rid of the trigger list. }
			DisposeSAtt( TList );

		end;
	end;
end;

Function StartRescueScenario( GB: GameBoardPtr; PC: GearPtr; Context: String ): Boolean;
	{ Attempt to load a rescue scenario for the PC. }
	Function RescueContext: String;
		{ Generate a string telling everything that needs to be told about }
		{ the PC's current location. }
	var
		RC: String;
		C: GearPtr;
	begin
		RC := Context;
		AddTraits( RC , SAttValue( GB^.Scene^.SA , 'CONTEXT' ) );
		AddTraits( RC , SATtValue( GB^.Scene^.SA , 'DESIG' ) );
		AddTraits( RC , SAttValue( GB^.Scene^.SA , 'TYPE' ) );
		AddTraits( RC , SAttValue( GB^.Scene^.SA , 'TERRAIN' ) );

		{ Next add the data for the city we're located in, its faction, and the }
		{ world that it's located in. }
		C := FindRootScene( GB^.Scene );
		if C <> Nil then begin
			AddTraits( RC , SAttValue( C^.SA , 'DESIG' ) );
			C := SeekFaction( FindRoot( GB^.Scene ) , NAttValue( C^.NA , NAG_Personal , NAS_FactionID ) );
			if C <> Nil then AddTraits( RC , SAttValue( C^.SA , 'DESIG' ) );
		end;
		RescueContext := RC;
	end;	{ RescueContext }
var
	Rescue_list,R: GearPtr;
	ItWorked: Boolean;
begin
	{ If no scene, can't be rescued. Sorry. }
	if GB^.Scene = Nil then Exit( False );

	{ Assume the rescue failed unless shown otherwise. }
	ItWorked := False;

	{ Load the rescue files. }
	Rescue_List := AggregatePattern( 'RESCUE_*.txt' , Series_Directory );

	{ Generate the complete context for the rescue. }
	Context := RescueContext;

	while Rescue_List <> Nil do begin
		R := FindNextComponent( Rescue_List , Context );

		if R <> Nil then begin
			DelinkGear( Rescue_List , R );
			SetNAtt( R^.NA , NAG_ElementID , 1 , GB^.Scene^.S );
			if InsertPlot( FindRootScene( GB^.Scene ) , FindRoot( GB^.Scene ) , R , GB , CurrentPCRenown( GB ) ) then begin
				{ Start by printing a message, since the time taken by the }
				{ rescue scenario is likely to cause a noticeable delay. }
				DialogMsg( MsgString( 'JustAMinute' ) );
				CombatDisplay( GB );
				DoFLip;

				DoCompleteRepair( PC );
				DisposeGear( Rescue_List );
				SetTrigger( GB , 'UPDATE' );
				HandleTriggers( GB );
				ItWorked := True;
			end;

		end else begin
			DisposeGear( Rescue_List );
		end;
	end;

	StartRescueScenario := ItWorked;
end;


initialization
	SCRIPT_DynamicEncounter := Nil;
	Grabbed_Gear := Nil;
	Script_Macros := LoadStringList( Script_Macro_File );
	if Script_Macros = Nil then DialogMsg( 'ERROR: Script Macros failed.' );
	Value_Macros := LoadStringList( Value_Macro_File );
	if Value_Macros = Nil then DialogMsg( 'ERROR: Value Macros failed.' );

	Default_Scene_Scripts := LoadStringList( Data_Directory + 'scene.txt' );

	lancemate_tactics_persona := LoadFile( 'lmtactics.txt' , Data_Directory );
	rumor_leads := LoadFile( 'rumor_leads.txt' , Data_Directory );

	local_triggers := Nil;

	I_NPC := Nil;
	IntMenu := Nil;

finalization
	if SCRIPT_DynamicEncounter <> Nil then begin
		DisposeGear( SCRIPT_DynamicEncounter );
	end;
	DisposeSAtt( Script_Macros );
	DisposeSAtt( Value_Macros );
	DisposeSAtt( Default_Scene_Scripts );
	DisposeGear( lancemate_tactics_persona );
	DisposeGear( rumor_leads );
	if local_triggers <> Nil then DisposeSATt( local_triggers );
end.
