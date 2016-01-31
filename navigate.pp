unit navigate;
	{ This unit is the flow controller for the RPG bits of the game. }
	{ It decides where the PC is, then when the PC exits a scene it }
	{ decides where to go next. }
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

uses gears,locale,backpack,
{$IFDEF ASCII}
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}

Const
	Max_Number_Of_Plots = 40;
	Plots_Per_Generation = 5;

Procedure SaveChar( PC: GearPtr );
Procedure SaveEgg( Egg: GearPtr );

Procedure Navigator( Camp: CampaignPtr; Scene: GearPtr; var PCForces: GearPtr );

Procedure StartCampaign( Egg: GearPtr );
Procedure RestoreCampaign( RDP: RedrawProcedureType );

implementation

uses arenaplay,arenascript,interact,gearutil,narration,texutil,ghprop,rpgdice,ability,
     ghchars,ghweapon,movement,ui4gh,gearparser,playwright,randmaps,mpbuilder,
{$IFDEF ASCII}
	vidmap,vidmenus;
{$ELSE}
	sdlmap,sdlmenus;
{$ENDIF}


Procedure DebugMessage( msg: String );
	{ Display a debugging message, and refresh the screen right away. }
begin
	DialogMsg( msg );
	ClrScreen;
	InfoBox( ZONE_Dialog );
	RedrawConsole;
	DoFlip;
end;

Procedure SaveChar( PC: GearPtr );
	{ Save this character to disk, in the "SaveGame" directory. }
var
	Leader: GearPtr;
	FName: String;		{ Filename for the character. }
	F: Text;		{ The file to write to. }
begin
	Leader := PC;
	while ( Leader <> Nil ) and ( ( Leader^.G <> GG_Character ) or ( NAttValue( Leader^.NA , NAG_CharDescription , NAS_CharType ) <> 0 ) ) do Leader := Leader^.Next;
	if Leader = Nil then Exit;

	FName := Save_Character_Base + GearName(Leader) + Default_File_Ending;
	Assign( F , FName );
	Rewrite( F );
	WriteCGears( F , PC );
	Close( F );
end;

Procedure SaveEgg( Egg: GearPtr );
	{ Save this character to disk, in the "SaveGame" directory. }
var
	Leader: GearPtr;
	FName: String;		{ Filename for the character. }
	F: Text;		{ The file to write to. }
begin
	Leader := Egg^.SubCom;
	while ( Leader <> Nil ) and ( ( Leader^.G <> GG_Character ) or ( NAttValue( Leader^.NA , NAG_CharDescription , NAS_CharType ) <> 0 ) ) do Leader := Leader^.Next;
	if Leader = Nil then Exit;

	FName := Save_Egg_Base + GearName(Leader) + Default_File_Ending;
	Assign( F , FName );
	Rewrite( F );
	WriteCGears( F , Egg );
	Close( F );
end;


Function NoLivingPlayers( PList: GearPtr ): Boolean;
	{ Return TRUE if the provided list of gears contains no }
	{ living characters. Return FALSE if it contains at least }
	{ one. }
var
	it: Boolean;
begin
	{ Start by assuming TRUE, then set to FALSE if a character is found. }
	it := TRUE;

	{ Loop through all the gears in the list. }
	while PList <> Nil do begin
		if ( PList^.G = GG_Character ) and NotDestroyed( PList ) and ( NAttValue( PList^.NA , NAG_CharDescription , NAS_CharType ) = 0 ) then begin
			it := False;
		end;
		PList := PList^.Next;
	end;

	{ Return the result. }
	NoLivingPlayers := it;
end;

Procedure CampaignUpkeep( Camp: CampaignPtr );
	{ Do some gardening work on this campaign. This procedure keeps }
	{ everything in the CAMP structure shiny, fresh, and working. }
	{ - Load a new PLOT, if appropriate. }
	{ - Delete dynamic scenes. }
var
	Part,Part2: GearPtr;
	N,N2: NAttPtr;
begin
	{ Get rid of any dynamic scenes that have outlived their usefulness. }
	{ If a SCENE is found in the InvComs, it must be dynamic. }
	Part := Camp^.Source^.InvCom;
	while Part <> Nil do begin
		Part2 := Part^.Next;

		if ( Part^.G = GG_Scene ) or ( Part^.G = GG_MetaScene ) then begin
			DeleteFrozenLocation( GearName( Part ) , Camp^.Maps );
			RemoveGear( Camp^.Source^.InvCom , Part );
		end;

		Part := Part2;
	end;

	{ Get rid of any PlotStatuses saved for plots which have concluded. }
	N := Camp^.Source^.NA;
	while N <> Nil do begin
		N2 := N^.Next;

		if ( N^.G = NAG_PlotStatus ) and ( N^.S > 0 ) then begin
			Part := SeekGearByIDTag( Camp^.Source^.InvCom , NAG_PlotStatus , N^.S , 1 );
			if Part = Nil then begin
				RemoveNAtt( Camp^.Source^.NA , N );
			end;
		end;

		N := N2;
	end;
end;

Procedure Navigator( Camp: CampaignPtr; Scene: GearPtr; var PCForces: GearPtr );
	{ This is the role-playing flow controller. It decides what scene }
	{ of an adventure gear to load next. }
var
	N: Integer;
begin
	repeat
		if SCene <> Nil then N := ScenePlayer( Camp , Scene , PCForces );

		{ Move to the destination scene, if appropriate. }
		if N > 0 then begin
			{ Perform upkeep on the campaign- delete dynamic scenes, }
			{ load new plots, yadda yadda yadda. }
			CampaignUpkeep( Camp );

			Scene := FindActualScene( Camp^.Source , N );

		end else if N < 0 then begin
			Scene := FindMetascene( Camp^.Source , N );

		{ If no destination scene was implied, check to see if there's }
		{ a dynamic scene waiting to be processed. }
		end else if SCRIPT_DynamicEncounter <> Nil then begin
			Scene := SCRIPT_DynamicEncounter;

			{ Stick the scene into the campaign. Normally scenes }
			{ are filed under SubComs, but in this case we'll store }
			{ it as an InvCom so we'll remember to delete it later. }
			InsertInvCom( Camp^.Source , Scene );

			{ Set the DynamicEncounter var to Nil, since we've moved }
			{ the scene to the campaign and don't want the ArenaScript }
			{ procedures to try and modify or delete it any more. }
			SCRIPT_DynamicEncounter := Nil;

			{ Set N to >0, since we don't want the "until..." }
			{ condition to exit. }
			N := 1;
		end;

	until ( N = 0 ) or NoLivingPlayers( PCForces ) or ( Scene = Nil );

	{ If the game is over because the PC died, do a [MORE] prompt. }
	if NoLivingPlayers( PCForces ) then begin
		MoreKey;
	end;
end;

Procedure InitializeCampaignScenes( Adv: GearPtr; var HiSceneID: Integer );
	{ Initialize the scenes of this adventure. This involves providing them all }
	{ with unique IDs, inserting content where needed, adding entrances to superscenes. }
	Procedure CheckAlongPath( S: GearPtr );
		{ Search along this path, initializing everything. }
	begin
		while S <> Nil do begin
			if S^.G = GG_Scene then begin
				S^.S := HiSceneID;
				Inc( HiSceneID );

				if AStringHasBString( SAttValue( S^.SA , 'TYPE' ) , 'DUNGEON' ) and ( SAttValue( S^.SA , 'DENTRANCE' ) <> '' ) and ( NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) = 0 ) then begin
					ExpandDungeon( S );
				end;

				ConnectScene( S , True );
			end;

			CheckAlongPath( S^.SubCom );

			S := S^.Next;
		end;
	end;
	Procedure InitNamedExits( Adv,Part: GearPtr );
		{ Search for gears with a DESTINATION string attribute. Try to }
		{ set the destination stat for these gears. }
	var
		dest: String;
		scene: GearPtr;
	begin
		while Part <> Nil do begin
			dest := SAttValue( Part^.SA , 'DESTINATION' );
			if dest <> '' then begin
				scene := SeekGearByName( Adv , dest );
				if ( Scene <> Nil ) and (( Scene^.G = GG_Scene ) or ( Scene^.G = GG_World )) and ( Part^.G = GG_MetaTerrain ) then begin
					Part^.Stat[ STAT_Destination ] := Scene^.S;
				end;
			end;
			InitNamedExits( Adv , Part^.SubCom );
			InitNamedExits( Adv , Part^.InvCom );
			Part := Part^.Next;
		end;
	end;
begin
	CheckAlongPath( Adv );

	InitNamedExits( Adv , Adv );

	{ Store the HiSceneID for later use. }
	SetNAtt( Adv^.NA , NAG_Narrative , NAS_MaxSceneID , HiSceneID );
end;

Procedure InitializeCampaignNPCs( Adv: GearPtr );
	{ Provide unique character IDs for each of the pre-loaded characters. }
	Procedure CheckAlongPath( P: GearPtr );
	var
		S: GearPtr;	{ The Persona for this NPC. }
		CID: LongInt;
	begin
		while P <> Nil do begin
			if P^.G = GG_Character then begin
				CID := NewCID( Adv );
				SetNAtt( P^.NA , NAG_Personal , NAS_CID , CID );
				S := SeekGearByName( Adv , GearName( P ) + ' PERSONA' );
				if S <> Nil then S^.S := CID;
			end;
			CheckAlongPath( P^.SubCom );
			CheckAlongPath( P^.InvCom );
			P := P^.Next;
		end;
	end;
begin
	CheckAlongPath( Adv );
end;

Procedure InitializeAdventureContent( Adv,HomeTown,Egg: GearPtr );
	{ Initialize the static adventure content. This consists mostly of }
	{ searching through the structure for content requests and filling }
	{ those recursively as needed. }
	{ Also add the content contained within the Egg. Most of this content }
	{ will require quests for placement/initialization. }
const
	NumSubQuests = 8;
var
	MasterList: GearPtr;	{ The master list of adventure content components. }

	Procedure CheckAlongPath( LList: GearPtr );
		{ Check along this list of scenes for content requests, }
		{ also checking the sub- and inv-coms. }
	var
		ConReq: String;
		SA: SAttPtr;
	begin
		while LList <> Nil do begin
			if LList^.G = GG_Scene then begin
				{ A scene can have multiple quests defined. }
				SA := LList^.SA;
				while SA <> Nil do begin
					if HeadMatchesString( 'QUEST' , SA^.Info ) then begin
						ConReq := RetrieveAString( SA^.Info );
						if not AddQuest( Adv , FindRootScene( LList ) , Nil , MasterList , ConReq ) then begin
							if XXRan_Debug then DialogMsg( 'ERROR: AddQuest failed for ' + ConReq );
						end;
					end;
					SA := SA^.Next;
				end;
			end;
			CheckAlongPath( LList^.SubCom );
			CheckAlongPath( LList^.InvCom );
			LList := LList^.Next;
		end;
	end;
	Procedure PlaceEggNPCs( LList: GearPtr );
		{ Take the NPCs from the egg and place them in the adventure. }
		{ Actually, we won't be placing them, but clones of them... }
		{ anyhow, go and do it. }
	const
		Default_NPC_Quest = '*EGG_Default';
	var
		ConReq: String;
	begin
		while LList <> Nil do begin
			if LList^.G = GG_Character then ExpandCharacter( LList );

			ConReq := SAttValue( LList^.SA , 'QUEST' );
			{ If this content request is empty, assign the default value. }
			if ConReq = '' then ConReq := Default_NPC_Quest;

			if not AddQuest( Adv , HomeTown , LList , MasterList , ConReq ) then begin
				if XXRan_Debug then DialogMsg( 'ERROR: AddQuest failed for ' + ConReq + '/' + GearName( LList ) );
			end;

			LList := LList^.Next;
		end;
	end;
begin
	{ Load the component library. }
	MasterList := LoadQuestFragments;

	{ Start checing the adventure scenes for content requests. }
	CheckAlongPath( Adv^.SubCom );

	{ Place the NPCs from the egg. Some of these will likely make use }
	{ of the quest fragments loaded above. }
	PlaceEggNPCs( Egg^.InvCom );

	{ Get rid of the master list. }
	DisposeGear( MasterList );
end;


Procedure VerifySceneExits( LList: GearPtr );
	{ Check all of the exits you can find. If any of them are negative, this is a bad thing. }
	{ Fix the problem by pointing them to their parent scene. }
	Function GetScene( S: GearPtr ): GearPtr;
		{ Locate the scene that's the most recent ancestor of S. }
	begin
		while ( S <> Nil ) and ( S^.G <> GG_Scene ) do S := S^.Parent;
		GetScene := S;
	end;
var
	Scene: GearPtr;
begin
	while LList <> Nil do begin
		if ( LList^.G = GG_MetaTerrain ) and ( LList^.Stat[ STAT_Destination ] < 0 ) then begin
			{ This metaterrain is in violation. Fix it. }
			Scene := GetScene( LList );
			if ( Scene <> Nil ) and ( Scene^.Parent <> Nil ) then begin
				LList^.Stat[ STAT_Destination ] := Scene^.Parent^.S;
				if LList^.Stat[ STAT_Destination ] < 1 then begin
					DialogMsg( 'ERROR: Invalid SceneID for ' + GearName( LList ) + '.' );
					LList^.Stat[ STAT_Destination ] := 0;
				end;
			end else begin
				DialogMsg( 'ERROR: Parent scene not found for ' + GearName( LList ) + '.' );
			end;
		end;
		VerifySceneExits( LList^.SubCom );
		VerifySceneExits( LList^.InvCom );
		LList := LList^.Next;
	end;

end;

Procedure StartCampaign( Egg: GearPtr );
	{ Start a new RPG campaign. }
	{ - Load the atlas files, then assemble them into an adventure. }
	{ - Initialize all the cities. }
	{ - Insert the PC's central story. }
const
	Default_Residence_Desig = '*EGG_RESIDENCE_Apartment';
var
	Camp: CampaignPtr;
	PCForces,TruePC,Atlas,S,S2,W,Story,Club: GearPtr;
	Factions,Artifacts: GearPtr;
	HighWorldID: Integer;
	Base,Changes: String;	{ Context Strings. }
begin
{$IFNDEF ASCII}
	Idle_Display;
{$ENDIF}

	{ Extract the PCForces from the Egg. }
	PCForces := Nil;
	while Egg^.SubCom <> Nil do begin
		S := Egg^.SubCom;
		DelinkGear( Egg^.SubCom , S );
		AppendGear( PCForces , S );
	end;

	{ Locate the TruePC. }
	TruePC := PCForces;
	while ( TruePC <> Nil ) and ( ( TruePC^.G <> GG_Character ) or ( NAttValue( TruePC^.NA , NAG_CharDescription , NAS_CharType ) <> 0 ) ) do TruePC := TruePC^.Next;

	{ Expand the TruePC. Maybe. }
	if TruePC^.SubCom = Nil then begin
		ExpandCharacter( TruePC );
	end;

	{ Give the PC a personal communicator. Maybe. }
	if TruePC^.InvCom = Nil then begin
		Artifacts := LoadNewItem( 'Personal Communicator' );
		if Artifacts <> Nil then InsertInvCom( TruePC , Artifacts );
	end;

	Camp := NewCampaign;
	Camp^.Source := LoadFile( 'adventurestub.txt' , Series_Directory );

	{ The Adventure source needs to store the PC's faction. }
	SetNAtt( Camp^.Source^.NA , NAG_Personal , NAS_FactionID , NAttValue( TruePC^.NA , NAG_Personal , NAS_FactionID ) );

	Atlas := AggregatePattern( 'ATLAS_*.txt' , Series_Directory );

	{ Insert the factions into the adventure. }
	Factions := AggregatePattern( 'FACTIONS_*.txt' , Series_Directory );
	InsertInvCom( Camp^.Source , Factions );

	{ Insert the artifacts into the adventure. }
	Artifacts := AggregatePattern( 'ARTIFACT_*.txt' , Series_Directory );
	S := AddGear( Camp^.Source^.InvCom , Camp^.Source );
	SetSAtt( S^.SA , 'name <Artifact Collection>' );
	S^.G := GG_ArtifactSet;
	InsertInvCom( S , Artifacts );

	{ Insert the unique scene content into the adventure. }
	Artifacts := AggregatePattern( 'UNICON_*.txt' , Series_Directory );
	S := AddGear( Camp^.Source^.InvCom , Camp^.Source );
	SetSAtt( S^.SA , 'name <Unique Scene Content>' );
	S^.G := GG_ContentSet;
	InsertInvCom( S , Artifacts );
	{ Assign unique IDs to all the content bits. }
	HighWorldID := 1;
	S := Artifacts;
	while S <> Nil do begin
		SetNAtt( S^.NA , NAG_Narrative , NAS_ContentID , HighWorldID );
		S := S^.Next;
		Inc( HighWorldID );
	end;


	{ Assemble the subcoms of the adventure. }
	{ First, move over all the WORLDs. Then, move over all the SCENEs. }
	{ Assign unique IDs for everything. }
	S := Atlas;
	HighWorldID := 1;
	while S <> Nil do begin
		S2 := S^.Next;

		if S^.G = GG_World then begin
			DelinkGear( Atlas , S );
			InsertSubCom( Camp^.Source , S );
			S^.S := HighWorldID;
			Inc( HighWorldID );
		end;
		S := S2;
	end;

	{ Proceed with the scenes. }
	S := Atlas;
	while S <> Nil do begin
		S2 := S^.Next;

		if S^.G = GG_Scene then begin
			DelinkGear( Atlas , S );
			W := SeekGearByName( Camp^.Source , SAttValue( S^.SA , 'WORLD' ) );
			if ( W <> Nil ) and ( ( W^.G = GG_Scene ) or ( W^.G = GG_World ) ) then begin
				InsertSubCom( W , S );
			end else begin
				InsertSubCom( Camp^.Source , S );
			end;
		end;

		S := S2;
	end;

	{ We are now finished with the atlas. Dispose of it. }
	DisposeGear( Atlas );

	{ Locate the PC's home town. Insert a "Cavalier Club" as the starting location. }
	{ Also insert the PC's residence. The residence type should be listed }
	{ in the EGG. }
	S := SeekGearByName( Camp^.Source , SAttValue( TruePC^.SA , 'HOMETOWN' ) );
	if S <> Nil then S := SeekUrbanArea( S );
	if S <> Nil then begin
		Club := LoadSingleMecha( 'stub_cavalierclub.txt' , Series_Directory );
		InsertSubCom( S , Club );

		Atlas := LoadFile( 'EGG_scenes.txt' , Series_Directory );
		Base := SAttValue( Egg^.SA , 'RESIDENCE' );
		if Base = '' then Base := Default_Residence_Desig;
		Club := SeekGearByDesig( Atlas , Base );
		if Club <> Nil then begin
			DelinkGear( Atlas , Club );
			SetSAtt( Club^.SA , 'DESIG <PCHOME>' );
			InsertSubCom( S , Club );
		end;
		DisposeGear( Atlas );
	end;

	{ Once everything is sorted where it's supposed to go, initialize the scenes. }
	{ They all need unique ID numbers, the dungeons need expansion and the cities }
	{ need random content. }
	InitializeCampaignScenes( Camp^.Source , HighWorldID );

	{ Next initialize the NPCs. }
	InitializeCampaignNPCs( Camp^.Source );

	{ Locate the PC's home town again, this time to record the scene ID. }
	{ We're also going to need this scene ID for the central story below. }
	S := SeekGearByName( Camp^.Source , SAttValue( TruePC^.SA , 'HOMETOWN' ) );
	if S <> Nil then begin
		SetNAtt( TruePC^.NA , NAG_Narrative , NAS_HomeTownID , S^.S );
	end;

	{ Insert the central story. }
	Story := LoadFile( 'corestorystub.txt' , Series_Directory );
	SetNAtt( Story^.NA , NAG_ElementID , XRP_EpisodeScene , S^.S );
	SetNAtt( Story^.NA , NAG_ElementID , XRP_AllyFac , NAttValue( TruePC^.NA , NAG_Personal , NAS_FactionID ) );
	SetNAtt( Camp^.Source^.NA , NAG_Personal , NAS_FactionID , NAttValue( TruePC^.NA , NAG_Personal , NAS_FactionID ) );

	{ Copy the PC's personal context to the story. }
	Base := SAttValue( Story^.SA , 'CONTEXT' );
	Changes := SAttValue( TruePC^.SA , 'CONTEXT' );
	AlterDescriptors( Base , Changes );
	SetSAtt( Story^.SA , 'CONTEXT <' + Base + '>' );

	InsertInvCom( Camp^.Source , Story );

	{ Insert the static adventure quests. }
	InitializeAdventureContent( Camp^.Source , S , Egg );

	{ Verify that the exits have been handled correctly. }
	VerifySceneExits( Camp^.Source );

	{ By now, we should be finished with the EGG. Get rid of it. }
	DisposeGear( Egg );

	{ Locate the Cavalier Club. This is to be the starting location. }
	{ Being the first location entered by the PC, the Cavalier Club has }
	{ the imaginative designation of "00000". }
	S := SeekGearByDesig( Camp^.Source , 'PCHOME' );
	if S <> Nil then begin
		Navigator ( Camp , S , PCForces );
	end;

	DisposeCampaign( Camp );
	DisposeGear( PCForces );
end;

Procedure RestoreCampaign( RDP: RedrawProcedureType );
	{ Select a previously saved unit from the menu. If no unit is }
	{ found, jump to the CreateNewUnit procedure above. }
var
	RPM: RPGMenuPtr;
	rpgname: String;	{ Campaign Name }
	Camp: CampaignPtr;
	F: Text;		{ A File }
	PC,Part,P2: GearPtr;
	DoSave: Boolean;
begin
	{ Create a menu listing all the units in the SaveGame directory. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Title_Screen_Menu );
	BuildFileMenu( RPM , Save_Campaign_Base + Default_Search_Pattern );

	PC := Nil;

	{ If any units are found, allow the player to load one. }
	if RPM^.NumItem > 0 then begin
		RPMSortAlpha( RPM );
		DialogMSG('Select campaign file to load.');

		rpgname := SelectFile( RPM , RDP );

		if rpgname <> '' then begin
			Assign(F, Save_Game_Directory + rpgname );
			reset(F);
			Camp := ReadCampaign(F);
			Close(F);

			Navigator( Camp , Camp^.GB^.Scene , PC );
			DoSave := Camp^.Source^.V <> 0;
			DisposeCampaign( Camp );
		end else begin
			DoSave := False;
		end;

	end else begin
		{ The menu was empty... print the info message. }
		DialogMsg( MsgString( 'NEWRPGCAMP_NoCamps' ) );
		DoSave := False;
	end;

	if ( PC <> Nil ) and ( DoSave or Always_Save_Character ) then begin
		if not NoLivingPlayers( PC ) then begin
			Part := PC;
			while Part <> Nil do begin
				P2 := Part^.Next;
				{ Lancemates don't get saved to the character file. }
				if ( Part^.G = GG_Character ) and ( NAttValue( Part^.NA , NAG_CharDescription , NAS_CharType ) <> NAV_CTPrimary ) then begin
					RemoveGear( PC , Part );
				end else begin
					{ Everything else does get saved. }
					StripNAtt( Part , NAG_Visibility );
					StripNAtt( Part , NAG_EpisodeData );
					StripNAtt( Part , NAG_WeaponModifier );
					StripNAtt( Part , NAG_Action );
					StripNAtt( Part , NAG_Location );
					StripNAtt( Part , NAG_Damage );
					StripNAtt( Part , NAG_ReactionScore );
					StripNAtt( Part , NAG_FactionScore );
					StripNAtt( Part , NAG_Condition );
					StripNAtt( Part , NAG_StatusEffect );
					StripNAtt( Part , NAG_Narrative );
				end;
				Part := P2;
			end;
			SaveChar( PC );
		end;
	end;
	if PC <> Nil then DisposeGear( PC );

	DisposeRPGMenu( RPM );
end;

end.
