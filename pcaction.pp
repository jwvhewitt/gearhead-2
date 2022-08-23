unit pcaction;
	{ This unit specifically handles PC actions. }
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
	Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
}
{$LONGSTRINGS ON}


interface

uses gears,locale;

Procedure PCSaveCampaign( Camp: CampaignPtr; PC: gearPtr; PrintMsg: Boolean );

Procedure GetPlayerInput( Mek: GearPtr; Camp: CampaignPtr );

Function WorldMapMain( Camp: CampaignPtr ): Integer;


implementation

uses ability,action,aibrain,arenacfe,arenascript,backpack,
     effects,gearutil,targetui,ghchars,gearparser,robotics,
     ghprop,ghswag,ghweapon,interact,menugear,movement,
     playwright,rpgdice,skilluse,texutil,ui4gh,grabgear,
     narration,description,ghintrinsic,training,ghsensor,
     wmonster,infodisplay,
{$IFDEF ASCII}
	vidgfx,vidmap,vidmenus,vidinfo;
{$ELSE}
	sdlgfx,sdlmap,sdlmenus,sdlinfo,sdl;
{$ENDIF}

const
	{ This array cross-references the RL direction key with }
	{ the gearhead direction number it corresponds to. }
	Roguelike_D: Array [1..9] of Byte = ( 3, 2, 1, 4, 0, 0, 5, 6, 7 );
	Reverse_RL_D: Array [0..7] of Byte = ( 6 , 3 , 2 , 1 , 4 , 7, 8 , 9 );


var
	PCACTIONRD_PC: GearPtr;
	PCACTIONRD_GB: GameBoardPtr;
	PCACTIONRD_Menu: RPGMenuPtr;	{ These two are for redrawing the FieldHQ }
	PCACTIONRD_Source: GearPtr;	{ with the new interface. }

Procedure PCActionRedraw;
	{ Redraw the map and the PC's info. }
begin
	CombatDisplay( PCACTIONRD_GB );
end;

Procedure PCMenuRedraw;
	{ Redraw the map and the PC's info. }
begin
	CombatDisplay( PCACTIONRD_GB );
	InfoBox( ZONE_Menu );
{$IFDEF ASCII}
	ClockBorder;
	if Tactics_Turn_In_Progess then begin
		TacticsTimeInfo( PCACTIONRD_GB );
	end else begin
		CMessage( TimeString( PCACTIONRD_GB^.ComTime ) , ZONE_Clock , StdWhite );
	end;
{$ENDIF}
end;

Procedure PCMenuPlusDescRedraw;
	{ Redraw the map and the PC's info. }
begin
	CombatDisplay( PCACTIONRD_GB );
	InfoBox( ZONE_Menu );
	InfoBox( ZONE_Info );
{$IFDEF ASCII}
	ClockBorder;
	if Tactics_Turn_In_Progess then begin
		TacticsTimeInfo( PCACTIONRD_GB );
	end else begin
		CMessage( TimeString( PCACTIONRD_GB^.ComTime ) , ZONE_Clock , StdWhite );
	end;
{$ENDIF}
end;


{$IFNDEF ASCII}
Procedure CenterMenuRedraw;
	{ Redraw the map and the PC's info. }
begin
	CombatDisplay( PCACTIONRD_GB );
	InfoBox( ZONE_CenterMenu );
end;
{$ENDIF}


Procedure FieldHQRedraw;
	{ Do a redraw for the Field HQ. }
var
	Part: GearPtr;
begin
	CombatDisplay( PCACTIONRD_GB );
	SetupFHQDisplay;
	if ( PCACTIONRD_Menu <> Nil ) and ( PCACTIONRD_Source <> Nil ) then begin
		Part := RetrieveGearSib( PCACTIONRD_Source , CurrentMenuItemValue( PCACTIONRD_Menu ) );
		if Part <> Nil then begin
			BrowserInterfaceInfo( PCACTIONRD_GB , Part , ZONE_ItemsInfo );
		end;
	end;
end;

Procedure PCSRedraw;
	{ Redraw the map and the PC's info. }
begin
	CombatDisplay( PCACTIONRD_GB );
	SetupMemoDisplay;
end;

Procedure ViewCharRedraw;
	{ Redraw the view character screen. }
begin
	CombatDisplay( PCACTIONRD_GB );
	CharacterDisplay( PCACTIONRD_PC , PCACTIONRD_GB, ZONE_CharViewChar );
	InfoBox( ZONE_CharViewMenu );
end;

Procedure FHQ_Rename( GB: GameBoardPtr; NPC: GearPtr );
	{ Enter a new name for NPC. }
var
	name: String;
begin
	name := GetStringFromUser( ReplaceHash( MsgString( 'FHQ_Rename_Prompt' ) , GearName( NPC ) ) , @PCActionRedraw );
	if name <> '' then SetSAtt( NPC^.SA , 'name <' + name + '>' );
end;

Procedure FHQ_Rejoin( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ NPC will rejoin the party if there's enough room. }
var
	CanJoin: Boolean;
begin
	{ Depending on whether the NPC in question is a robot or a pet, different procedures }
	{ must be called. }
	CanJoin := PetsPresent( GB ) < PartyPetSlots( PC );

	if CanJoin then begin
		DialogMsg( ReplaceHash( MsgString( 'REJOIN_OK' ) , GearName( NPC ) ) );
		AddLancemate( GB , NPC );
	end else begin
		DialogMsg( ReplaceHash( MsgString( 'REJOIN_DontWant' ) , GearName( NPC ) ) );
	end;
end;

Procedure AutoTraining( GB: GameBoardPtr; var NPC: GearPtr );
	{ The NPC in question is going to raise some skills. }
var
	N,T: Integer;
	FXP: LongInt;
	TrainedSome: Boolean;
	M,M2: GearPtr;
	Gene: String;
begin
	TrainedSome := False;
	repeat
		FXP := NAttValue( NPC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( NPC^.NA , NAG_Experience , NAS_SpentXP );
		{ Determine how many skills or stats may be trained. }
		N := 0;
		for t := 1 to NumSkill do begin
			if ( NAttValue( NPC^.NA , NAG_SKill , T ) > 0 ) and ( SkillAdvCost( NPC , NAttValue( NPC^.NA , NAG_SKill , T ) ) <= FXP ) then begin
				Inc( N );
			end;
		end;

		if N > 0 then begin
			N := Random( N );
			
			for t := 1 to NumSkill do begin
				if ( NAttValue( NPC^.NA , NAG_SKill , T ) > 0 ) and ( SkillAdvCost( NPC , NAttValue( NPC^.NA , NAG_SKill , T ) ) <= FXP ) then begin
					if N = 0 then begin
						AddNAtt( NPC^.NA , NAG_Experience , NAS_SpentXP , SkillAdvCost( NPC , NAttValue( NPC^.NA , NAG_SKill , T ) ) );
						AddNAtt( NPC^.NA , NAG_Skill , T , 1 );
						dialogmsg( ReplaceHash( ReplaceHash( MsgString( 'AUTOTRAIN_LEARN' ) , GearName( NPC ) ) , MsgString( 'SKILLNAME_' + BStr( T ) ) ) );
						TrainedSome := True;
						N := 5;
                        break;
					end;
					Dec( N );
				end;
			end;
		end;
	until N < 1;

	{ Free XP now becomes Freaky XP... check for evolution. }
	FXP := NAttValue( NPC^.NA , NAG_GearOps , NAS_EvolveAt );
	if ( FXP > 0 ) and ( NAttValue( NPC^.NA , NAG_Experience , NAS_TotalXP ) > FXP ) then begin
		{ Search the monster list for another creature which is: 1) from the }
		{ same genepool as our original, and 2) more powerful. }
		M := WMOnList;
		Gene := UpCase( SATtValue( NPC^.SA , 'GENEPOOL' ) );
		N := 0;
		while M <> Nil do begin
			if ( UpCase( SAttValue( M^.SA , 'GENEPOOL' ) ) = Gene ) and ( M^.V > NPC^.V ) then Inc( N );
			M := M^.Next;
		end;

		{ If at least one such monster has been found, }
		{ it's time to do the evolution! }
		if N > 0 then begin
			N := Random( N );
			M2 := Nil;
			M := WMonList;
			while M <> Nil do begin
				if ( UpCase( SAttValue( M^.SA , 'GENEPOOL' ) ) = Gene ) and ( M^.V > NPC^.V ) then begin
					Dec( N );
					if N = -1 then M2 := M;
				end;
				M := M^.Next;
			end;

			{ We've selected a new body. Change over. }
			if ( M2 <> Nil ) and ( NPC^.Parent = Nil ) then begin
				{ First, make the current monster drop everything }
				{ it's carrying. }
				ShakeDown( GB , NPC , NAttValue( NPC^.NA , NAG_Location , NAS_X ) , NAttValue( NPC^.NA , NAG_Location , NAS_Y ) );

				{ Then copy the new body to the map. }
				M := CloneGear( M2 );
				{ Insert M into the map. }
				DeployGear( GB , M , True );

				DialogMsg( ReplaceHash( ReplaceHash( MsgString( 'AUTOTRAIN_EVOLVE' ) , GearName( NPC ) ) , GearName( M ) ) );

				{ Copy over name, XP, team, location, and skills. }
				SetSAtt( M^.SA , 'name <' + GearName( NPC ) + '>' );
				SetNAtt( M^.NA , NAG_Experience , NAS_SpentXP , NAttValue( NPC^.NA , NAG_Experience , NAS_SpentXP ) );
				SetNAtt( M^.NA , NAG_Experience , NAS_TotalXP , NAttValue( NPC^.NA , NAG_Experience , NAS_TotalXP ) );
				SetNAtt( M^.NA , NAG_Location , NAS_Team , NAttValue( NPC^.NA , NAG_Location , NAS_Team ) );
				SetNAtt( M^.NA , NAG_Location , NAS_X , NAttValue( NPC^.NA , NAG_Location , NAS_X ) );
				SetNAtt( M^.NA , NAG_Location , NAS_Y , NAttValue( NPC^.NA , NAG_Location , NAS_Y ) );
				SetNAtt( M^.NA , NAG_Personal , NAS_CID , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) );
				SetNAtt( M^.NA , NAG_CharDescription , NAS_CharType , NAttValue( NPC^.NA , NAG_CharDescription , NAS_CharType ) );
				GearUp( M );

				for t := 1 to NumSkill do begin
					if NAttValue( NPC^.NA , NAG_Skill , T ) > NAttValue( M^.NA , NAG_Skill , T ) then SetNAtt( M^.NA , NAG_Skill , T , NAttValue( NPC^.NA , NAG_Skill , T ) );
				end;

				TrainedSome := True;

				{ Now, delete the original. }
				RemoveGear( GB^.Meks , NPC );
				NPC := M;
			end;
		end;
	end;

	if not TrainedSome then DialogMsg( ReplaceHash( MsgString( 'AUTOTRAIN_FAIL' ) , GearName( NPC ) ) );
end;

Procedure FHQ_Disassemble( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ Robot NPC is no longer desired. Disassemble it into spare parts, delete the NPC, }
	{ then give the parts to PC. }
var
	M: Integer;
begin
	{ Error check- NPC must be on the gameboard. }
	if not IsFoundAlongTrack( GB^.Meks , NPC ) then Exit;

	{ First, make the robot drop everything it's carrying. }
	ShakeDown( GB , NPC , NAttValue( NPC^.NA , NAG_Location , NAS_X ) , NAttValue( NPC^.NA , NAG_Location , NAS_Y ) );

	{ Print a message. }
	DialogMsg( ReplaceHash( MsgString( 'FHQ_DIS_Doing' ) , GearName( NPC ) ) );

	{ The size of the spare parts is to be determined by the weight of the robot. }
	M := GearMass( NPC );

	{ Delete the NPC. }
	RemoveGear( GB^.Meks , NPC );

	{ Get the spare parts. }
	NPC := LoadNewSTC( 'SPAREPARTS-1' );
	NPC^.V := M * 5;
	InsertInvCom( PC , NPC );
end;

Procedure FHQ_ThisLancemateWasSelected( GB: GameBoardPtr; PC,NPC: GearPtr );
	{ NPC was selected by the lancemate browser. Allow the PC to train, }
	{ equip, or dismiss this character. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	PCACTIONRD_PC := NPC;
	PCACTIONRD_GB := GB;

	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharViewMenu );
	if IsSafeArea( GB ) or OnTheMap( GB, NPC ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_LMV_Equip' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'FHQ_LMV_Train' ) , 2 );

	if ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) <> 0 ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_SelectMecha' ) , 4 );
	if ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) = 0 ) or ( UpCase( SAttValue( NPC^.SA , 'JOB' ) ) = 'ROBOT' ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_Rename' ) , 5 );
	if ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) = 0 ) and ( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_Rejoin' ) , 6 );
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and IsSubCom( GB^.Scene ) and IsSAfeArea( GB ) and OnTheMap( GB, NPC ) and ( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and ( NAttValue( NPC^.NA , NAG_CharDescription , NAS_CharType ) <> NAV_TempLancemate ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_LMV_Dismiss' ) , 3 );
	if ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) = 0 ) and ( UpCase( SAttValue( NPC^.SA , 'JOB' ) ) = 'ROBOT' ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_Disassemble' ) , 7 );

	AddRPGMenuItem( RPM , MsgString( 'FHQ_PartEditor' ) , 8 );

	AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

	repeat
		PCACTIONRD_PC := NPC;
		n := SelectMenu( RPM , @ViewCharRedraw );

		case N of
			1: 	begin
				PCActionRD_GB := GB;
				LancemateBackpack( GB , PC , NPC , @PCActionRedraw );
				end;
			2: 	if NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) <> 0 then begin
					PCACTIONRD_GB := GB;
					DoTraining( GB , NPC , @PCActionRedraw );
				end else AutoTraining( GB , NPC );
			3: 	begin
				RemoveLancemate( GB , NPC , True );
				DialogMsg( ReplaceHash( MsgString( 'FHQ_LMV_Removed' ) , GearName( NPC ) ) );
				N := -1;
				end;
			4: 	FHQ_SelectMechaForPilot( GB , NPC );
			5: 	FHQ_Rename( GB , NPC );
			6: 	FHQ_Rejoin( GB , PC , NPC );
			7:	begin
				FHQ_Disassemble( GB , PC , NPC );
				N := -1;
				end;
			8:
				MechaPartBrowser( NPC , @PCActionRedraw );

		end;
	until N = -1;
	DisposeRPGMenu( RPM );
end;

Procedure FieldHQ( GB: GameBoardPtr; PC: GearPtr );
	{ View the PC's lancemates. This menu should allow the PC to view, equip, }
	{ train and dismiss these characters. }
var
	RPM: RPGMenuPtr;
	N: Integer;
	M: GearPtr;
begin
	{ To start with, gather up all of the PC's crap from all over the city. }
	GatherFieldHQ( GB );

	repeat
		{ Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
		M := GB^.Meks;
		N := 1;
		while M <> Nil do begin
			if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) then begin
				AddRPGMenuItem( RPM , TeamMateName( M ) , N );
			end else if ( NAttValue( M^.NA , NAG_CharDescription , NAS_CharType ) = NAV_CTLancemate ) and ( NAttValue( M^.NA , NAG_Personal , NAS_CID ) = 0 ) Then begin
				AddRPGMenuItem( RPM , TeamMateName( M ) , N );
			end else if ( M^.G <> GG_Character ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then begin
				AddRPGMenuItem( RPM , TeamMateName( M ) , N );
			end;
			M := M^.Next;
			Inc( N );
		end;
		RPMSortAlpha( RPM );
		AddRPGMenuItem( RPM , MSgString( 'EXIT' ) , -1 );

		PCACTIONRD_Menu := RPM;
		PCACTIONRD_Source := GB^.Meks;


		{ Get a selection from the menu. }
		n := SelectMenu( RPM , @FieldHQRedraw );
		DisposeRPGMenu( RPM );

		if N > 0 Then begin
			M := RetrieveGearSib( GB^.Meks , N );
			if M^.G = GG_Character then begin
				FHQ_ThisLancemateWasSelected( GB , PC , M );
			end else begin
				PCActionRD_GB := GB;
				FHQ_ThisWargearWasSelected( GB , GB^.Meks , PC , M , @PCActionRedraw );
			end;
		end;

	until N = -1;
end;


Procedure CheckHiddenMetaterrain( GB: GameBoardPtr; Mek: GearPtr );
	{ Some metaterrain might be hidden. If any hidden metaterrain }
	{ is located, reveal it and run its REVEAL trigger. }
var
	MT: GearPtr;
	T: String;
	P: Point;
begin
	{ First record the PC's current position, for future reference. }
	P := GearCurrentLocation( Mek );

	{ Look through all the gears on the board, searching for metaterrain. }
	MT := GB^.Meks;
	while MT <> Nil do begin
		{ If this terrain matches our basic criteria, }
		{ we'll perform the next few tests. }
		if ( MT^.G = GG_MetaTerrain ) and ( MT^.Stat[ STAT_MetaVisibility ] > 0 ) and ( Range( MT , P.X , P.Y ) <= 1 ) then begin
			{ Roll the PC's AWARENESS skill. If it beats }
			{ the terrain's concealment score, reveal it. }
			if SkillRoll( GB , Mek , NAS_Awareness , STAT_Perception , MT^.Stat[ STAT_MetaVisibility ] , 0 , False , True ) > MT^.Stat[ STAT_MetaVisibility ] then begin
				MT^.Stat[ STAT_MetaVisibility ] := 0;
				T := 'REVEAL';
				TriggerGearScript( GB , MT , T );
				VisionCheck( GB , Mek );
			end;
		end;

		MT := MT^.Next;
	end;
end;

Procedure PCSearch( GB: GameBoardPtr; PC: GearPtr );
	{ The PC will search for enemy units and hidden things. }
	{ This action costs MENTAL. }
var
	Mek: GearPtr;
begin
	{ Costs one point of MENTAL and an action. }
	AddMentalDown( PC , 1 );
	WaitAMinute( GB , PC , ReactionTime( PC ) );

	{ Look through all the gears on the board, searching for ones }
	{ that aren't visible yet. }
	{ Note that by searching in this way, the PC will not be vunerable }
	{ to being spotted himself. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		if OnTheMap( GB, Mek ) and not MekCanSeeTarget( GB , PC , Mek ) then begin
			if IsMasterGear( Mek ) and CheckLOS( GB , PC , Mek ) then begin
				{ The mek has just been spotted. }
				RevealMek( GB , Mek , PC );
			end;
		end;
		Mek := Mek^.Next;
	end;
	CheckHiddenMetaTerrain( GB , PC );
end;

Procedure MemoBrowser( GB: GameBoardPtr; PC: GearPtr );
	{ Find all the memos that the player has accumulated, then allow }
	{ them to be browsed through, then restore the display afterwards. }
const
	m_email = 1;
	m_memo = 2;
	m_rumor = 3;
	m_news = 4;
	m_Personadex = 5;
var
	MainMenu: RPGMenuPtr;
	A: Integer;
begin
	MainMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoText );
	if HasPCommCapability( PC , NAS_EMail ) then AddRPGMenuItem( MainMenu , MsgString( 'MEMO_ReadEMail' ) , m_EMail );
	if HasPCommCapability( PC , NAS_Memo ) then begin
		AddRPGMenuItem( MainMenu , MsgString( 'MEMO_ReadMemo' ) , m_Memo );
		AddRPGMenuItem( MainMenu , MsgString( 'MEMO_ReadRumors' ) , m_Rumor );
	end;
	if HasPCommCapability( PC , NAS_News ) then AddRPGMenuItem( MainMenu , MsgString( 'MEMO_ReadNews' ) , m_News );
	if HasPCommCapability( PC , NAS_Personadex ) then AddRPGMenuItem( MainMenu , MsgString( 'MEMO_Personadex' ) , m_Personadex );

	if MainMenu^.NumItem < 1 then begin
		DialogMsg( MsgString( 'MEMO_NoBrowser' ) );
	end else if MainMenu^.NumItem = 1 then begin
		case MainMenu^.FirstItem^.Value of
			m_Memo: BrowseMemoType( GB , 'MEMO' );
			m_rumor: BrowseMemoType( GB , 'RUMEMO' );
			m_News: BrowseMemoType( GB , 'NEWS' );
			m_EMail: BrowseMemoType( GB , 'EMAIL' );
			m_Personadex: View_Personadex( GB );
		end;

	end else begin
		AlphaKeyMenu( MainMenu );

		repeat
			A := SelectMenu( MainMenu , @PCSRedraw );

			case A of
				m_Memo: BrowseMemoType( GB , 'MEMO' );
				m_rumor: BrowseMemoType( GB , 'RUMEMO' );
				m_News: BrowseMemoType( GB , 'NEWS' );
				m_EMail: BrowseMemoType( GB , 'EMAIL' );
				m_Personadex: View_Personadex( GB );
			end;

		until ( A = -1 ) or not KeepPlayingSC( GB );
	end;

	DisposeRPGMenu( MainMenu );
end;

Function InterfaceType( GB: GameBoardPtr; Mek: GearPtr ): Integer;
	{ Return the constant for the currently-being-used control type. }
begin
	if GB^.Scale > 2 then begin
		InterfaceType := WorldMapMethod;
	end else if Mek^.G = GG_Character then begin
		InterfaceType := CharacterMethod;
	end else begin
		InterfaceType := ControlMethod;
	end;
end;


Procedure PCTalk( GB: GameBoardPtr; PC: GearPtr );
	{ PC wants to do some talking. Select an NPC, then let 'er rip. }
begin
	DialogMsg( MsgSTring( 'TALKING_Prompt' ) );
	if LookAround( GB , PC ) then begin
		DoTalkingWithNPC( GB , PC , LOOKER_Gear , False );
	end else begin
		DialogMsg( MsgString( 'Cancelled' ) );
	end;
end;

Procedure PCTelephone( GB: GameBoardPtr; PC: GearPtr );
	{ Make a telephone call, if the PC has a telephone. }
var
	Name: String;
	NPC,RootScene: GearPtr;
begin
	if HasPCommCapability( PC , PCC_Phone ) then begin
		DialogMsg( MsgString( 'PHONE_Prompt' ) );
		Name := GetStringFromUser( MsgString( 'PHONE_GetName' ) , @PCActionRedraw );

		if Name = '*' then Name := SAttValue( PC^.SA , 'REDIAL' )
		else SetSAtt( PC^.SA , 'REDIAL <' + Name + '>' );

		if Name <> '' then begin
			{ First, seek the NPC on the gameboard... }
			NPC := SeekGearByName( GB^.Meks , Name );
			if NPC = Nil then begin
				{ Next, try the entire root scene... }
				RootScene := FindRootScene( GB^.Scene );
				if RootScene <> Nil then begin
					NPC := SeekChildByName( RootScene , Name );
				end;
				{ Finally, try searching by keyword. }
				if NPC = Nil then NPC := FindLocalNPCByKeyword( GB , Name );
			end;

			if CanContactByPhone( GB , NPC ) then begin
				DoTalkingWithNPC( GB , PC , NPC , True );
			end else begin
				DialogMsg( ReplaceHash( MsgString( 'PHONE_NotFound' ) , Name ) );
			end;
		end;
	end else begin
		DialogMsg( MsgString( 'PHONE_NoPhone' ) );
	end;
end;

Procedure UsePropFrontEnd( GB: GameBoardPtr; PC , Prop: GearPtr; T: String );
	{ Do everything that needs to be done when a prop is used. }
begin
	TriggerGearScript( GB , Prop , T );
	VisionCheck( GB , PC );
	WaitAMinute( GB , PC , ReactionTime( PC ) );
end;

Function SelectOneVisibleUsableGear( GB: GameBoardPtr; X,Y: Integer; Trigger: String ): GearPtr;
	{ Create a menu, then select one of the visible, usable gears }
	{ from tile X,Y. }
var
	RPM: RPGMenuPtr;
	it: GearPtr;
	N: Integer;
begin
	{ Create and fill the menu. }
    {$IFDEF ASCII}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
    {$ELSE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CenterMenu );
    {$ENDIF}
	N := NumVisibleUsableGearsXY( GB , X , Y , Trigger );
	while N > 0 do begin
		it := FindVisibleUsableGearXY( GB , X , Y , N , Trigger );
		AddRPGMenuItem( RPM , GearName( it ) , N );
		Dec( N );
	end;

	{ Select an item. }
    {$IFDEF ASCII}
	N := SelectMenu( RPM , @PCMenuRedraw );
    {$ELSE}
	N := SelectMenu( RPM , @CenterMenuRedraw );
    {$ENDIF}

	DisposeRPGMenu( RPM );

	if N > 0 then begin
		SelectOneVisibleUsableGear := FindVisibleUsableGearXY( GB , X , Y , N , Trigger );
	end else begin
		SelectOneVisibleUsableGear := Nil;
	end;
end;

Function ActivatePropAtSpot( GB: GameBoardPtr; PC: GearPtr; X,Y: Integer; Trigger: String ): Boolean;
	{ Check spot X,Y. If there are any usable items there, use one. }
	{ If there are multiple items in the spot, prompt for a selection. }
	{ Return TRUE if a prop was activated, or FALSE otherwise. }
var
	N: Integer;
	Prop: GearPtr;
begin
	{ First count how many usable items there are at the spot. }
	N := NumVisibleUsableGearsXY( GB , X , Y , Trigger );

	{ Next, choose the item which is to be used. }
	if N > 0 then begin
		if N = 1 then begin
			Prop := FindVisibleUsableGearXY( GB , X , Y , 1 , Trigger );
		end else begin
			Prop := SelectOneVisibleUsableGear( GB , X , Y , Trigger );
		end;

		if ( Prop <> Nil ) then begin
			UsePropFrontEnd( GB , PC , Prop , Trigger );
			ActivatePropAtSpot := True;
		end else begin
			ActivatePropAtSpot := False;
		end;

	end else begin
		ActivatePropAtSpot := False;
	end;
end;

Procedure PCUseProp( GB: GameBoardPtr; PC: GearPtr );
	{ PC wants to do something with a prop. Select an item, then let 'er rip. }
var
	D,PropD: Integer;
	P: Point;
begin
	{ See whether or not there's only one prop to use. }
	PropD := -1;
	P := GearCurrentLocation( PC );
	for D := 0 to 7 do begin
		if NumVisibleUsableGearsXY( GB , P.X + AngDir[ D , 1 ] , P.Y + AngDir[ D , 2 ] , 'USE' ) > 0 then begin
			if PropD = -1 then PropD := D
			else PropD := -2;
		end;
	end;

	if PropD < 0 then begin
		DialogMsg( MsgString( 'PCUS_Prompt' ) );

		PropD := DirKey( @PCActionRedraw );

	end;

	if PropD > -1 then begin
		if not ActivatePropAtSpot( GB , PC , P.X + AngDir[ PropD , 1 ] , P.Y + AngDir[ PropD , 2 ] , 'USE' ) then DialogMsg( MsgString( 'PCUS_NotFound' ) );
	end;
end;

Procedure PCEnter( GB: GameBoardPtr; PC: GearPtr );
	{ The PC is attempting to enter a place. }
	{ Seek a usable gear in this tile, then try to activate it. }
var
	P: Point;
begin
	P := GearCurrentLocation( PC );
	if not ActivatePropAtSpot( GB , PC , P.X , P.Y , 'USE' ) then DialogMsg( MsgString( 'PCUS_NotFound' ) );;
end;

Procedure PCUseSkillOnProp( GB: GameBoardPtr; PC: GearPtr; Skill: Integer );
	{ PC wants to do something with a prop. Select an item, then let 'er rip. }
var
	PropD: Integer;
	P: Point;
	Trigger: String;
begin
	P := GearCurrentLocation( PC );
	DialogMsg( MsgString( 'PCUSOP_Prompt' ) );

	PropD := DirKey( @PCActionRedraw );

	Trigger := Skill_Use_Trigger[ Skill ];

	if ( PropD = -1 ) and ( NumVisibleUsableGearsXY( GB , P.X , P.Y , Trigger ) > 0 ) then begin
		if not ActivatePropAtSpot( GB , PC , P.X , P.Y , Trigger ) then DialogMsg( MsgString( 'PCUS_NotFound' ) );;
	end else if ( PropD <> -1 ) and ( NumVisibleUsableGearsXY( GB , P.X + AngDir[ PropD , 1 ] , P.Y + AngDir[ PropD , 2 ] , Trigger ) > 0 ) then begin
		if not ActivatePropAtSpot( GB , PC , P.X + AngDir[ PropD , 1 ] , P.Y + AngDir[ PropD , 2 ] , Trigger ) then DialogMsg( MsgString( 'PCUS_NotFound' ) );
	end else if GB^.Scene <> Nil then begin
		TriggerGearScript( GB , GB^.Scene , Trigger );
	end;
end;

Procedure DoPCRepair( GB: GameBoardPtr; PC: GearPtr; Skill: Integer );
	{ The PC is going to use one of the repair skills. Call the }
	{ standard procedure, then print output. }
var
	D,Best: Integer;
	P: Point;
	Mek,Target: GearPtr;
begin
	DialogMsg( MsgString( 'PCREPAIR_Prompt' ) );

	D := DirKey( @PCActionRedraw );

	P := GearCurrentLocation( PC );
	if D <> -1 then begin
		P.X := P.X + AngDir[ D , 1 ];
		P.Y := P.Y + AngDir[ D , 2 ];
	end;

	Mek := GB^.Meks;
	Target := Nil;
	Best := 0;
	while Mek <> Nil do begin
		if ( not AreEnemies( GB , PC , Mek ) ) and ( RepairNeededBySkill( Mek , Skill ) > Best ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_X ) = P.X ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Y ) = P.Y ) then begin
			Target := Mek;
			Best := RepairNeededBySkill( Mek , Skill );
		end;
		mek := mek^.Next;
	end;
	if Target <> Nil then begin
		DoFieldRepair( GB , PC , FindRoot( Target ) , Skill );
	end else begin
		if not ActivatePropAtSpot( GB , PC , P.X , P.Y , Skill_Use_Trigger[ Skill ] ) then DialogMsg( MsgString( 'PCREPAIR_NoDamageDone' ) );
	end;
end;

Procedure DominateAnimal( GB: GameBoardPtr; PC: GearPtr );
	{ The PC will attempt to dominate this animal. Make a skill roll and see }
	{ if it's possible. If the skill roll fails, the animal may become enraged. }
	Function IsGoodTarget( M: GearPtr ): Boolean;
		{ Return TRUE if M is a good target for domination, or FALSE otherwise. }
	begin
		if GearActive( M ) and AreEnemies( GB , M , PC ) and ( NAttValue( M^.NA , NAG_PErsonal , NAS_CID ) = 0 ) then begin
			IsGoodTarget := True;
		end else if GearActive( M ) and ( NAttValue( M^.NA , NAG_PErsonal , NAS_CID ) = 0 ) and ( NAttValue( M^.NA , NAG_CharDescription , NAS_CharType ) = NAV_CTLancemate ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then begin
			IsGoodTarget := True;
		end else begin
			IsGoodTarget := False;		end;
	end;
var
	D: Integer;
	M,Target: GearPtr;
	SkTarget,SkRoll: Integer;
	P,P2: Point;
begin
	if CurrentMental( PC ) < 1 then begin
		DialogMsg( MsgString( 'DOMINATE_TOO_TIRED' ) );
		Exit;
	end;

	DialogMsg( ReplaceHash( MsgString( 'DOMINATE_Announce' ) , PilotName( PC ) ) );
	P := GearCurrentLocation( PC );

	{ Pass one - try to find a monster nearby. }
	M := GB^.Meks;
	Target := Nil;
	D := 0;
	while M <> Nil do begin
		{ Two types of animal may be dominated: those which are hostile }
		{ to the PC, and those which are already his pets. }
		P2 := GearCurrentLocation( M );
		if ( Abs( P2.X - P.X ) <= 1 ) and ( Abs( P2.Y - P.Y ) <= 1 ) and IsGoodTarget( M ) then begin
			Target := M;
			Inc( D );
		end;
		M := M^.Next;
	end;

	{ If more than one monster was found, prompt for a direction. }
	if D > 1 then begin
		DialogMsg( MsgString( 'DOMINATE_Prompt' ) );

		D := DirKey( @PCActionRedraw );

		P.X := P.X + AngDir[ D , 1 ];
		P.Y := P.Y + AngDir[ D , 2 ];

		M := GB^.Meks;
		Target := Nil;
		while M <> Nil do begin
			{ Two types of animal may be dominated: those which are hostile }
			{ to the PC, and those which are already his pets. }
			P2 := GearCurrentLocation( M );
			if ( P2.X = P.X ) and ( P2.Y = P.Y ) and IsGoodTarget( M ) then Target := M;
			M := M^.Next;
		end;
	end;

	if Target = Nil then begin
		DialogMsg( MsgString( 'DOMINATE_NotFound' ) );
		Exit;
	end else if AreEnemies( GB , Target , PC ) then begin
		{ Locate the target value for this animal. }
		{ If it has no skill target, then either it can't be dominated or }
		{ the PC has already tried and failed to dominate it. }
		SkTarget := NAttValue( Target^.NA , NAG_GearOps , NAS_DominationTarget );

		{ The PC only gets one attempt regardless... }
		SetNAtt( Target^.NA , NAG_GearOps , NAS_DominationTarget , 0 );

		if SkTarget < 1 then begin
			DialogMsg( ReplaceHash( MsgString( 'DOMINATE_Fail' ) , GearName( Target ) ) );
		end else begin
			SkRoll := SkillRoll( GB , PC , NAS_Survival , STAT_Ego , SkTarget , ToolBonus( PC , -NAS_DominateAnimal ) , False , True );

			if ( SkRoll > SkTarget ) and ( PetsPresent( GB ) < PartyPetSlots( PC ) ) then begin
				DialogMsg( ReplaceHash( MsgString( 'DOMINATE_OK' ) , GearName( Target ) ) );
				AddLancemate( GB , Target );
				SetNAtt( Target^.NA , NAG_CharDescription , NAS_CharType , NAV_CTLancemate );

				DoleExperience( Target , CStat( LocatePilot( PC ) , STAT_Knowledge ) * 50 );
				DoleSkillExperience( PC , NAS_Survival , SkTarget * 2 );
				DoleExperience( PC , Target , SkTarget );
			end else if ( SkRoll < ( SkTarget div 3 ) ) then begin
				DialogMsg( ReplaceHash( MsgString( 'DOMINATE_Enraged' ) , GearName( Target ) ) );
				for SkRoll := 6 to 10 do AddNAtt( Target^.NA , NAG_Skill , SkRoll , Random( 5 ) );
			end else begin
				DialogMsg( ReplaceHash( MsgString( 'DOMINATE_Fail' ) , GearName( Target ) ) );
				if SkTarget > 0 then DoleSkillExperience( PC , 40 , Random( 5 ) + 1 );
			end;
		end;

	end else begin
		{ This animal is an ex-member of the party. It'll come back fairly }
		{ peacefully, as long as there's room. }
		if PetsPresent( GB ) < PartyPetSlots( PC ) then begin
			DialogMsg( ReplaceHash( MsgString( 'DOMINATE_OK' ) , GearName( Target ) ) );
			AddLancemate( GB , Target );
		end else begin
			DialogMsg( ReplaceHash( MsgString( 'DOMINATE_DontWant' ) , GearName( Target ) ) );
		end;
	end;

	{ Dominating an animal costs MP and takes time. }
	{ If no animal was chosen, the procedure already exited above... }
	AddMentalDown( PC , 5 );
	WaitAMinute( GB , PC , ReactionTime( PC ) * 2 );
end;

Procedure PickPockets( GB: GameBoardPtr; PC: GearPtr );
	{ The PC will attempt to steal from a nearby NPC. }
	Function IsGoodTarget( M: GearPtr ): Boolean;
		{ Return TRUE if M is a good target for pick pockets, or FALSE otherwise. }
		{ It's a good target if it's an NPC (with CID), not a lancemate or the PC }
		{ himself, and alive. }
	var
		Team: Integer;
	begin
		if GearActive( M ) and ( M^.G = GG_Character ) and ( NAttValue( M^.NA , NAG_PErsonal , NAS_CID ) <> 0 ) then begin
			Team := NAttValue( M^.NA , NAG_Location , NAS_Team );
			IsGoodTarget := ( Team <> NAV_DefPlayerTeam ) and ( Team <> NAV_LancemateTeam );
		end else begin
			IsGoodTarget := False;
		end;
	end;
var
	D: Integer;
	M,Target: GearPtr;
	SkTarget,SkRoll: Integer;
	P,P2: Point;
	Cash,NID: LongInt;
begin
	if CurrentMental( PC ) < 1 then begin
		DialogMsg( MsgString( 'PICKPOCKET_TOO_TIRED' ) );
		Exit;
	end;

	DialogMsg( ReplaceHash( MsgString( 'PICKPOCKET_Announce' ) , PilotName( PC ) ) );
	P := GearCurrentLocation( PC );

	{ Pass one - try to find a target nearby. }
	M := GB^.Meks;
	Target := Nil;
	D := 0;
	while M <> Nil do begin
		P2 := GearCurrentLocation( M );
		if ( Abs( P2.X - P.X ) <= 1 ) and ( Abs( P2.Y - P.Y ) <= 1 ) and IsGoodTarget( M ) then begin
			Target := M;
			Inc( D );
		end;
		M := M^.Next;
	end;

	{ If more than one monster was found, prompt for a direction. }
	if D > 1 then begin
		DialogMsg( MsgString( 'PICKPOCKET_Prompt' ) );

		D := DirKey( @PCActionRedraw );

		P.X := P.X + AngDir[ D , 1 ];
		P.Y := P.Y + AngDir[ D , 2 ];

		M := GB^.Meks;
		Target := Nil;
		while M <> Nil do begin
			P2 := GearCurrentLocation( M );
			if ( P2.X = P.X ) and ( P2.Y = P.Y ) and IsGoodTarget( M ) then Target := M;
			M := M^.Next;
		end;
	end;

	{ From here on, we want to deal with the actual PC. I don't think anyone will ever }
	{ get the chance to pick pockets in a mecha, but better safe than sorry. }
	PC := LocatePilot( PC );

	if Target = Nil then begin
		DialogMsg( MsgString( 'PICKPOCKET_NotFound' ) );
		Exit;
	end else if ( NAttValue( Target^.NA , NAG_Personal , NAS_CashOnHandRestock ) > GB^.ComTime ) and ( Target^.InvCom = Nil ) then begin
		{ If the victim has nothing to steal, then the PC can't very well steal it, }
		{ can he? }
		DialogMsg( ReplaceHash( MsgString( 'PICKPOCKET_EMPTY' ) , GearName( Target ) ) );
		Exit;
	end else begin
		{ Time to start the actual stealing of stuff. }
		SkTarget := Target^.Stat[ STAT_Perception ] + 5;
		SkRoll := SkillRoll( GB ,  PC , NAS_Stealth , STAT_Craft , Target^.Stat[ STAT_Perception ] + 5 , ToolBonus( PC , -NAS_PickPockets ) , True , True );

		if SkRoll > SkTarget then begin
			{ The PC will now steal something. }
			{ Roll the amount of money claimed. }
			Cash := Calculate_Threat_Points( NAttValue( Target^.NA , NAG_CharDescription , NAS_Renowned ) * 2 , Random( 5 ) + 1 ) div 20 + Random( 10 );
			if Cash < 10 then Cash := Random( 8 ) + Random( 8 ) + 2;
			AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , Cash );

			{ Check for items... }
			M := SelectRandomGear( Target^.InvCom );
			if M <> Nil then begin
				DelinkGear( Target^.InvCom , M );
				{ mark the item as stolen... }
				SetNAtt( M^.NA , NAG_Narrative , NAS_Stolen , 1 );
				InsertInvCom( PC , M );

				{ Set the trigger for picking up an item, just in case }
				{ there are any plots tied to this item. }
				NID := NAttValue( M^.NA , NAG_Narrative , NAS_NID );
				if NID <> 0 then SetTrigger( GB , TRIGGER_GetItem + BStr( NID ) );

				DialogMsg( ReplaceHash( ReplaceHash( MsgString( 'PICKPOCKET_CASH+ITEM' ) , BStr( Cash ) ) , GearName( M ) ) );
			end else begin
				DialogMsg( ReplaceHash( MsgString( 'PICKPOCKET_CASH' ) , BStr( Cash ) ) );
			end;
			DoleSkillExperience( PC , NAS_Stealth , SkTarget div 2 );
			DoleExperience( PC , Target , SkTarget );
		end else begin
			DialogMsg( MsgString( 'PICKPOCKET_FAIL' ) );
			{ If the failure was bad, the Guardians may notice... }
			DoleSkillExperience( PC , NAS_Stealth , 1 );
			if SkRoll < ( SkTarget - 10 ) then begin
				SetTrigger( GB , 'THIEF!' );
				AddReputation( PC , 6 , -1 );
				AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( Target^.NA , NAG_PErsonal , NAS_CID ) , -20 );
			end;
		end;

		{ Picking pockets always has the consequences of Chaotic reputation }
		{ and the target will like you less. Even if they don't know it's you }
		{ stealing from them, it seems like every time they meet you they end }
		{ up poorer...? }
		if SkRoll < ( SkTarget + 10 ) then AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( Target^.NA , NAG_PErsonal , NAS_CID ) , -( 5 + Random(10) ) );
		AddReputation( PC , 2 , -2 );

		{ Also set the recharge time. }
		SetNAtt( Target^.NA , NAG_Personal , NAS_CashOnHandRestock , GB^.ComTime + 43200 + Random( 86400 ) );
	end;

	{ Stealing things takes concentration and time. }
	AddMentalDown( PC , 5 );
	WaitAMinute( GB , PC , ReactionTime( PC ) * 2 );
end;


Procedure PCActivateSkill( GB: GameBoardPtr; PC: GearPtr );
	{ Allow the PC to pick a known skill from his list, then apply }
	{ that skill to either himself or a nearby object. }
	{ There are two kinds of skills that can be activated by this }
	{ command: repair skills and clue skills. Clue skills must be }
	{ applied to an item. }
var
	RPM: RPGMenuPtr;
	N,Usage: Integer;
begin
	{ Make sure we have the actual PC first. }
	PC := LocatePilot( PC );
	if PC = Nil then Exit;

	{ Make the skill menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	AttachMenuDesc( RPM , ZONE_Info );
	RPM^.DTexColor := InfoGreen;

	{ Add all usable skills to the list, as long as the PC knows them. }
	for N := 1 to NumSkill do begin
        { EXPERIMENTAL March 2 2016: This seems to work okay in GH1, so why }
        { not here too? All skills known by the party are usable! Anarchy! }
		if ( SkillMan[ N ].Usage > 0 ) and ( TeamHasSkill( GB , NAV_DefPlayerTeam , N ) or TeamHasTalent( GB , NAV_DefPlayerTeam , NAS_JackOfAll ) ) then begin
			AddRPGMenuItem( RPM , MsgString( 'SKILLNAME_' + BStr( N ) ) , N , SkillDescription( N ) );
		end;
	end;

	{ Add all usable talents to the list too. }
	for N := 1 to NumTalent do begin
		if ( Talent_Usage[ N ] > 0 ) and TeamHasTalent( GB, NAV_DefPlayerTeam , N ) then begin
			AddRPGMenuItem( RPM , MsgString( 'TALENT' + BStr( N ) ) , -N , MsgString( 'TALENTDESC' + BStr( N ) ) );
		end;
	end;

	RPMSortAlpha( RPM );
	AlphaKeyMenu( RPM );
	AddRPGMenuItem( RPM , MsgString( 'PCAS_Cancel' ) , -1 );
	DialogMSg( MsgString( 'PCAS_Prompt' ) );


	N := SelectMenu( RPM , @PCMenuPlusDescRedraw );

	DisposeRPGMenu( RPM );

	if ( N <> -1 ) then begin
		{ Determine the usage. }
		if N > 0 then Usage := SkillMan[ N ].Usage
		else Usage := Talent_Usage[ Abs( N ) ];

		if Usage = USAGE_Repair then begin
			DoPCRepair( GB , PC , N );
		end else if Usage = USAGE_Clue then begin
			PCUseSkillOnProp( GB , PC , N );
		end else if Usage = USAGE_Performance then begin
			StartPerforming( GB , PC );
		end else if Usage = USAGE_Robotics then begin
			BuildRobot( GB , PC );
		end else if Usage = USAGE_DominateAnimal then begin
			DominateAnimal( GB , PC );
		end else if Usage = USAGE_PickPockets then begin
			PickPockets( GB , PC );
		end;

	end else begin
		DialogMsg( MsgString( 'Cancelled' ) );
	end;
end;


Procedure ForcePlot( GB: GameBoardPtr; PC,Scene: GearPtr );
	{ Debugging command - forcibly loads a plot into the adventure. }
var
	RPM: RPGMenuPtr;
	PID: Integer;
	Plot: GearPtr;
begin
	if ( scene = Nil ) or ( Scene^.Parent = Nil ) then exit;
	{ Create a menu listing all the units in the SaveGame directory. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildSiblingMenu( RPM , Standard_Plots );

	if RPM^.NumItem > 0 then begin
		RPMSortAlpha( RPM );
		DialogMSG('Select plot file to load.');

		pID := SelectMenu( RPM , @PCMenuRedraw );

		if ( PID <> -1 ) and ( RetrieveGearSib( Standard_Plots , PID )^.G = GG_Plot ) then begin
			Plot := CloneGear( RetrieveGearSib( Standard_Plots , PID ) );
			SetSAtt( Plot^.SA , 'name <DEBUG>' );

			if InsertPlot( FindRootScene( GB^.Scene ) , FindRoot( Scene ) , Plot , GB , NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned ) ) then begin
				DialogMsg( 'Plot successfully loaded.' );
			end else begin
				DialogMsg( 'Plot rejected.' );
			end;
		end;
	end;
	DisposeRPGMenu( RPM );
end;

Procedure PCSaveCampaign( Camp: CampaignPtr; PC: gearPtr; PrintMsg: Boolean );
	{ Save the campaign and all associated info to disk. }
var
	Name: String;
	F: Text;
begin
	{ Find the PC's name, open the file, and save. }
	if ( Camp^.Source <> Nil ) and ( Camp^.Source^.S = GS_ArenaCampaign ) then begin
        Name := SanitizeFilename( GearName( Camp^.Source ) );
		Name := Save_Unit_Base + Name + Default_File_Ending;
	end else begin
        Name := SanitizeFilename( PilotName( PC ) );        
		Name := Save_Campaign_Base + Name + Default_File_Ending;
	end;

	Assign( F , Name );
	Rewrite( F );
	WriteCampaign( Camp , F );
	Close( F );

	{ Let the player know that everything went fine. }
	if PrintMsg then Dialogmsg( MsgString( 'SAVEGAME_OK' ) );
end;

Procedure DoSelectPCMek( GB: GameBoardPtr; PC: GearPtr );
	{ Select one of the team 1 mecha for the player to use. }
begin
	FHQ_SelectMechaForPilot( GB , PC );
end;

Procedure PCBackpackMenu( GB: GameBoardPtr; PC: GearPtr; StartWithInv: Boolean );
	{ This is a front-end for the BackpackMenu command; all it does is }
	{ call that procedure, then redraw the map afterwards. }
begin
	PCActionRD_GB := GB;
	BackpackMenu( GB , PC , StartWithInv , @PCActionRedraw );
end;

Procedure PCFieldHQ( GB: GameBoardPtr; PC: GearPtr );
	{ This is a front-end for the BackpackMenu command; all it does is }
	{ call that procedure, then redraw the map afterwards. }
begin
	FieldHQ( GB , PC );
	CombatDisplay( GB );
end;

Procedure SetPlayOptions( GB: GameBoardPtr; Mek: GearPtr );
	{ Allow the player to set control type, default burst value settings, }
	{ and whatever other stuff you think is appropriate. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	{ The menu needs to be re-created with each iteration, since the }
	{ data in it needs to be updated. }

	N := 1;
	repeat
        {$IFDEF ASCII}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
        {$ELSE}
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CenterMenu );
        {$ENDIF}

		AddRPGMenuItem( RPM , 'Mecha Control: '+ControlTypeName[ControlMethod] , 1 );
		AddRPGMenuItem( RPM , 'Chara Control: '+ControlTypeName[CharacterMethod] , 5 );
		AddRPGMenuItem( RPM , 'Explore Control: '+ControlTypeName[WorldMapMethod] , 6 );
		AddRPGMenuItem( RPM , 'Ballistic Wpn BV: '+BVTypeName[DefBallisticBV] , 2 );
		AddRPGMenuItem( RPM , 'Energy Wpn BV: '+BVTypeName[DefBeamGunBV] , 3 );
		AddRPGMenuItem( RPM , 'Missile BV: '+BVTypeName[DefMissileBV] , 4 );

		if ( Mek^.Scale = 0 ) then begin
			if NAttValue( Mek^.NA , NAG_Prefrences , NAS_UseNonLethalAttacks ) = 0 then begin
				AddRPGMenuItem( RPM , 'NonLethal Attacks: Off' , 10 );
			end else begin
				AddRPGMenuItem( RPM , 'NonLethal Attacks: On' , 10 );
			end;
		end;

		if Thorough_Redraw then begin
			AddRPGMenuItem( RPM , 'Enable Quick Redraw' , 7 );
		end else begin
			AddRPGMenuItem( RPM , 'Disable Quick Redraw' , 7 );
		end;

		if Display_Mini_Map then begin
			AddRPGMenuItem( RPM , 'Disable Mini-Map' , 8 );
		end else begin
			AddRPGMenuItem( RPM , 'Enable Mini-Map' , 8 );
		end;

		if Use_Tall_Walls then begin
			AddRPGMenuItem( RPM , 'Walls are Full Height' , 9 );
		end else begin
			AddRPGMenuItem( RPM , 'Walls are Short' , 9 );
		end;

		if Names_Above_Heads then begin
			AddRPGMenuItem( RPM , 'Disable Name Display' , 11 );
		end else begin
			AddRPGMenuItem( RPM , 'Enable Name Display' , 11 );
		end;


		AddRPGMenuItem( RPM , '  Exit Prefrences' , -1 );
		SetItemByValue( RPM , N );

        {$IFDEF ASCII}
		N := SelectMenu( RPM , @PCMenuRedraw );
        {$ELSE}
		N := SelectMenu( RPM , @CenterMenuRedraw );
        {$ENDIF}

		DisposeRPGMenu( RPM );

		if N = 1 then begin
			if ControlMethod = MenuBasedInput then ControlMethod := RLBasedInput
			else ControlMethod := MenuBasedInput;
			WaitAMinute( GB , Mek , 1 );
		end else if N = 5 then begin
			if CharacterMethod = MenuBasedInput then CharacterMethod := RLBasedInput
			else CharacterMethod := MenuBasedInput;
			WaitAMinute( GB , Mek , 1 );
		end else if N = 6 then begin
			if WorldMapMethod = MenuBasedInput then WorldMapMethod := RLBasedInput
			else WorldMapMethod := MenuBasedInput;
			WaitAMinute( GB , Mek , 1 );
		end else if N = 2 then begin
			if DefBallisticBV = BV_Off then DefBallisticBV := BV_Max
			else DefBallisticBV := BV_Off;
		end else if N = 3 then begin
			if DefBeamGunBV = BV_Off then DefBeamGunBV := BV_Max
			else DefBeamGunBV := BV_Off;

		end else if N = 4 then begin
			DefMissileBV := DefMissileBV + 1;
			if DefMissileBV > BV_Max then DefMissileBV := BV_Off;

		end else if N = 7 then begin
			Thorough_Redraw := Not Thorough_Redraw;

		end else if N = 8 then begin
			{ Toggle the Mini-Map. }
			Display_Mini_Map := Not Display_Mini_Map;

		end else if N = 9 then begin
			{ Toggle the tall walls. }
			Use_Tall_Walls := not Use_Tall_Walls;

		end else if N = 10 then begin
			{ Toggle NonLethal attacks. }
			if NAttValue( Mek^.NA , NAG_Prefrences , NAS_UseNonLethalAttacks ) = 0 then begin
				SetNAtt( Mek^.NA , NAG_Prefrences , NAS_UseNonLethalAttacks , 1 );
			end else begin
				SetNAtt( Mek^.NA , NAG_Prefrences , NAS_UseNonLethalAttacks , 0 );
			end;

		end else if N = 11 then begin
			Names_Above_Heads := Not Names_Above_Heads;

		end;

	until N = -1;
end;

Procedure BrowsePersonalHistory( GB: GameBoardPtr; PC: GearPtr );
	{ As the PC advances throughout the campaign, she will likely }
	{ accumulate a number of history messages. This procedure will }
	{ allow those messages to be browsed. }
var
	HList,SA: SAttPtr;
	Adv: GearPtr;
begin
	HList := Nil;
	Adv := FindRoot( GB^.Scene );
	if Adv <> Nil then begin
		SA := Adv^.SA;
		while SA <> Nil do begin
			if UpCase( Copy( SA^.Info , 1 , 7 ) ) = 'HISTORY' then begin
				StoreSAtt( HList , RetrieveAString( SA^.Info ) );
			end;
			SA := SA^.Next;

		end;

		if HList <> Nil then begin
            {$IFDEF ASCII}
			MoreText( HList , 1 );
            {$ELSE}
            PCACTIONRD_GB := GB;
    		MoreText( HList , 1 , @PCActionRedraw );
            {$ENDIF}
			DisposeSAtt( HList );
		end;
	end;
end;

Procedure PCViewChar( GB: GameBoardPtr; PC: GearPtr );
	{ This procedure is supposed to allow the PC to see his/her }
	{ stats, edit mecha, access the training and option screens, }
	{ and otherwise provide a nice all-in-one command for a }
	{ bunch of different play options. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin

	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharViewMenu );

	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_BackPack' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_Injuries' ) , 3 );
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_Training' ) , 2 );
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_FieldHQ' ) , 4 );
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_SetOptions' ) , 5 );
	AddRPGMenuItem( RPM , MsgString( 'HELP_PersonalHistory' ) , 6 );
{$IFNDEF ASCII}
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_SetColor' ) , 7 );
	if PC^.G = GG_Character then AddRPGMenuItem( RPM , MsgString( 'PCVIEW_SetSprite' ) , 8 );
{$ENDIF}
	AddRPGMenuItem( RPM , MsgString( 'PCVIEW_Exit' ) , -1 );


	repeat

		PCACTIONRD_PC := PC;
		N := SelectMenu( RPM , @ViewCharRedraw );


		case N of
			1:	PCBackPackMenu( GB , PC , True );
			2:	begin
				PCACTIONRD_GB := GB;
				DoTraining( GB , PC , @PCActionRedraw );
				end;
			3:	InjuryViewer( PC , @PCActionRedraw );
			4:	FieldHQ( GB , PC );
			5:	SetPlayOptions( GB , PC );
			6:	BrowsePersonalHistory( GB , PC );
{$IFNDEF ASCII}
			7:	SelectColors( PC , @PCActionRedraw );
			8:	SelectSprite( PC , @ViewCharRedraw );
{$ENDIF}

		end;
	until N = -1;

{$IFNDEF ASCII}
	CleanSpriteList;
{$ENDIF}
	DisposeRPGMenu( RPM );
	CombatDisplay( GB );
end;

Procedure WaitOnRecharge( GB: GameBoardPtr; Mek: GearPtr );
	{ Set the mek's CALLTIME to whenever the next weapon is supposed to }
	{ be recharged. }
var
	CT: LongInt;
	procedure SeekWeapon( Part: GearPtr );
		{ Seek the weapon which will recharge soonest. }
	var
		RT: LongInt;
	begin
		while ( Part <> Nil ) do begin
			if NotDestroyed( Part ) then begin
				if ( Part^.G = GG_Module ) or ( Part^.G = GG_Weapon ) then begin
					RT := NAttValue( Part^.NA , NAG_WeaponModifier , NAS_Recharge);
					{ Set the Call Time to this weapon's recharge time if it recharges quicker }
					{ than any other seen so far, and if it is currently recharging. }
					if ( RT < CT ) and ( RT > GB^.ComTime ) then CT := RT;
				end;
				if ( Part^.SubCom <> Nil ) then SeekWeapon( Part^.SubCom );
				if ( Part^.InvCom <> Nil ) then SeekWeapon( Part^.InvCom );
			end;
			Part := Part^.Next;
		end;
	end;

begin
	{ Set a default waiting period of a single round. If no weapon will }
	{ recharge before this time, return control to the player anyhow. }
	CT := GB^.ComTime + ClicksPerRound + 1;

	{ Check through all weapons to find which one recharges soonest. }
	SeekWeapon( Mek^.SubCom );

	{ Set the call time to whatever time was found. }
	SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , CT );
end;

Procedure RLSmartAttack( GB: GameBoardPtr; Mek: GearPtr );
	{ Turn and then fire upon the PC's target. }
var
	Enemy,Weapon: GearPtr;
	CD,MoveAction,T,TX,TY,N,AtOp: Integer;
begin
	{ Find out the mek's current target. }
	T := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Target );
	Enemy := LocateMekByUID( GB , T );
	TX := NAttValue( Mek^.NA , NAG_Location , NAS_SmartX );
	TY := NAttValue( Mek^.NA , NAG_Location , NAS_SmartY );

	{ Error check- if the smart attack isn't executed within five moves, }
	{ forget about it. }
	AddNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , 1 );
	if NAttValue( Mek^.NA , NAG_Location , NAS_SmartCount ) > 5 then begin
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , 0 );
		DialogMsg( MsgString( 'PCATTACK_OutOfArc' ) );
		Exit;
	end;

	{ Find the weapon being used in the attack. }
	Weapon := LocateGearByNumber( Mek , NAttValue( Mek^.NA , NAG_Location , NAS_SmartWeapon ) );
	if ( T = -1 ) and OnTheMap( GB, TX , TY ) then begin
		{ If T=-1, the PC is firing at a spot instead of a }
		{ specific enemy. }
		if WeaponArcCheck( GB , Mek , Weapon , TX , TY ) then begin
			{ Whatever else happens, the smartattack is over. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , 0 );

			{ The enemy is within the proper arc. Fire away! }
			if RangeArcCheck( GB , Mek , Weapon , TX , TY , TerrMan[ TileTerrain( GB , TX , TY ) ].Altitude ) then begin
				{ Everything is okay. Call the attack procedure. }
				AttackerFrontEnd( GB , Mek , Weapon , TX , TY , TerrMan[ TileTerrain( GB , TX , TY ) ].Altitude , DefaultAtOp( Weapon ) );

			end else begin
				DialogMSG( MsgString( 'PCATTACK_OutOfRange' ) );
			end;
		end else begin
			{ Turn to face the target. }
			CD := NAttValue( Mek^.NA , NAG_Location , NAS_D );

			MoveAction := NAV_TurnRight;

			{ Arcs CD and CD+7mod8 don't need to be checked, since }
			{ those are covered by the current F90 arc. }
			for t := 1 to 3 do begin
				if CheckArc( Mek , TX , TY , ( CD + T ) mod 8 ) then MoveAction := NAV_TurnRight
				else if CheckArc( Mek , TX , TY , ( CD + 7 - T ) mod 8 ) then MoveAction := NAV_TurnLeft;
			end;
			PrepAction( GB , Mek , MoveAction );
		end;

	end else if ( Enemy = Nil ) or ( Not GearOperational( Enemy ) ) or ( not MekVisible( GB , Enemy ) ) or ( Weapon = Nil ) or ( not ReadyToFire( GB , Mek , Weapon ) ) then begin
		{ This mecha is no longer a good target, or the weapon }
		{ selected is no longer valid. Cancel the SmartAttack. }
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , 0 );

	end else if WeaponArcCheck( GB , Mek , Weapon , Enemy ) then begin
		{ Whatever else happens, the smartattack is over. }
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , 0 );

		{ See if we're aiming for the main body or a subcom. }
		N := NAttValue( Mek^.NA , NAG_Location , NAS_SmartTarget );
		if N > 0 then begin
			Enemy := LocateGearByNumber( Enemy , N );
			AtOp := 0;
		end else begin
			AtOp := DefaultAtOp( Weapon );
		end;

		{ The enemy is within the proper arc. Fire away! }
		if RangeArcCheck( GB , Mek , Weapon , Enemy ) then begin
			{ Everything is okay. Call the attack procedure. }
			AttackerFrontEnd( GB , Mek , Weapon , Enemy , AtOp );

		end else begin
			DialogMSG( MsgString( 'PCATTACK_OutOfRange' ) );
		end;
	end else begin
		{ Turn to face the target. }
		CD := NAttValue( Mek^.NA , NAG_Location , NAS_D );

		MoveAction := NAV_TurnRight;

		{ Arcs CD and CD+7mod8 don't need to be checked, since }
		{ those are covered by the current F90 arc. }
		for t := 1 to 3 do begin
			if CheckArc( Mek , Enemy , ( CD + T ) mod 8 ) then MoveAction := NAV_TurnRight
			else if CheckArc( Mek , Enemy , ( CD + 7 - T ) mod 8 ) then MoveAction := NAV_TurnLeft;
		end;
		PrepAction( GB , Mek , MoveAction );
	end;
end;


Procedure AimThatAttack( Mek,Weapon: GearPtr; CallShot: Boolean; GB: GameBoardPtr );
	{ A weapon has been selected; now, select a target. }
var
	WPM: RPGMenuPtr;
	N,AtOp: Integer;
begin
	if not ReadyToFire( GB , Mek , Weapon ) then begin
		DialogMsg( ReplaceHash( MsgString( 'ATA_NotReady' ) , GearName( Weapon ) ) );
		Exit;
	end;

	AtOp := DefaultAtOp( Weapon );
	if SelectTarget( GB , Mek , Weapon , CallShot , AtOp ) then begin
		{ Check to make sure the target is within maximum range, }
		{ and that it falls within the correct arc. }
		AtOp := DefaultAtOp( Weapon );

		if ( LOOKER_Gear = Nil ) and RangeArcCheck( GB , Mek , Weapon , LOOKER_X , LOOKER_Y , TerrMan[ TileTerrain( GB , LOOKER_X , LOOKER_Y ) ].Altitude ) then begin
			AttackerFrontEnd( GB , Mek , Weapon , LOOKER_X , LOOKER_Y , TerrMan[ TileTerrain( GB , LOOKER_X , LOOKER_Y ) ].Altitude , DefaultAtOp( Weapon ) );

		end else if LOOKER_Gear = Nil then begin
			if ( Range( Mek , LOOKER_X , LOOKER_Y ) > WeaponRange( GB , Weapon , RANGE_Long ) ) and ( Range( Mek , LOOKER_X , LOOKER_Y ) > ThrowingRange( GB , Mek , Weapon ) ) then begin
				DialogMSG( MsgString( 'PCATTACK_OutOfRange' ) );
			end else if InterfaceType( GB , Mek ) = MenuBasedInput then begin
				DialogMSG( MsgString( 'PCATTACK_OutOfArc' ) );
			end else begin
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , NAV_SmartAttack );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , 0 );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , FindGearIndex( Mek , Weapon ) );
				SetNAtt( Mek^.NA , NAG_EPisodeData , NAS_Target , -1 );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartX , LOOKER_X );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartY , LOOKER_Y );

				RLSmartAttack( GB , Mek );
			end;

		end else if ( FindRoot( LOOKER_Gear ) = FindRoot( Mek ) ) then begin
			DialogMSG( 'Attack cancelled.' );

		end else if RangeArcCheck( GB , Mek , Weapon , LOOKER_Gear ) then begin
			{ Call the Attack procedure with the info we've gained. }

			{ If a called shot was requested, create the menu here. }
			{ Note that called shots cannot be made using burst firing. }
			if CallShot and ( LOOKER_Gear^.SubCom <> Nil ) then begin
				{ Create a menu, fill it with bits. }
				WPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
				BuildGearMenu( WPM , LOOKER_Gear , GG_Module , False );

				{ If you have target analysis software, can make a }
				{ called shot at movement systems and weapons too! }
				if ( LOOKER_Gear^.G = GG_Mecha ) and ( SeekSoftware( Mek , S_Information , SInfo_MechaDex , True ) <> Nil ) then begin
					BuildGearMenu( WPM , LOOKER_Gear , GG_Weapon , False );
					BuildGearMenu( WPM , LOOKER_Gear , GG_MoveSys , False );
				end;

				AlphaKeyMenu( WPM );

				N := SelectMenu( WPM , @PCMenuRedraw );

				if N <> -1 then begin
					LOOKER_Gear := LocateGearByNumber( LOOKER_Gear , N );
				end;
				DisposeRPGMenu( WPM );
				AtOp := 0;
			end;

			AttackerFrontEnd( GB , Mek , Weapon , LOOKER_Gear , AtOp );

		end else begin
			if WeaponArcCheck( GB , Mek , Weapon , LOOKER_Gear ) then begin
				DialogMSG( MsgString( 'PCATTACK_OutOfRange' ) );
			end else if InterfaceType( GB , Mek ) = MenuBasedInput then begin
				DialogMSG( MsgString( 'PCATTACK_OutOfArc' ) );
			end else begin
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , NAV_SmartAttack );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , 0 );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , FindGearIndex( Mek , Weapon ) );

				if CallShot and ( LOOKER_Gear^.SubCom <> Nil ) then begin
					{ Create a menu, fill it with bits. }
					WPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
					BuildGearMenu( WPM , LOOKER_Gear , GG_Module , False );
					{ If you have target analysis software, can make a }
					{ called shot at movement systems and weapons too! }
					if ( LOOKER_Gear^.G = GG_Mecha ) and ( SeekSoftware( Mek , S_Information , SInfo_MechaDex , True ) <> Nil ) then begin
						BuildGearMenu( WPM , LOOKER_Gear , GG_Weapon , False );
						BuildGearMenu( WPM , LOOKER_Gear , GG_MoveSys , False );
					end;

					AlphaKeyMenu( WPM );

					N := SelectMenu( WPM , @PCMenuRedraw );

					if N <> -1 then begin
						SetNAtt( Mek^.NA , NAG_Location , NAS_SmartTarget , N );
					end else begin
						SetNAtt( Mek^.NA , NAG_Location , NAS_SmartTarget , 0 );
					end;
					DisposeRPGMenu( WPM );
				end else begin
					SetNAtt( Mek^.NA , NAG_Location , NAS_SmartTarget , 0 );
				end;


				RLSmartAttack( GB , Mek );
			end;
		end;
	end;

end;

Procedure DoPlayerAttack( Mek: GearPtr; GB: GameBoardPtr );
	{ The player has accessed the weapons menu. Select an active }
	{ weapon, then select a target. If the target is within range, }
	{ process the attack and report upon it to the user. }
const
	CalledShotOff = '  Called Shot: Off [/]';
	CalledShotOn = '  Called Shot: On [/]';
var
	WPM: RPGMenuPtr;	{ The Weapons Menu }
	MI,MI2: RPGMenuItemPtr;	{ For checking all the weapons. }
	Weapon: GearPtr;	{ Also for checking all the weapons. }
	N: Integer;
	CallShot: Boolean;
begin
	{ Error check - make sure that MEK is a valid, active master gear. }
	if not IsMasterGear( Mek ) then exit;

	{ *** START MENU BUILDER *** }
	{ Create the weapons menu. }
	{ Travel through the mek structure in the standard pattern }
	{ looking for things which may be attacked with. }
	{ WEAPONS - may be attacked with. Duh. }
	{ MODULES - Arms enable punching, Legs enable kicking, tails enable tail whipping. }
	{ AMMO - Missiles with Range=0 in the general inventory may be thrown. }
	WPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
	AttachMenuDesc( WPM , ZONE_Menu1 );
	WPM^.DTexColor := InfoGreen;

	BuildGearMenu( WPM , Mek , GG_Weapon );
	BuildGearMenu( WPM , Mek , GG_Module );
	BuildGearMenu( WPM , Mek , GG_Ammo );
	AlphaKeyMenu( WPM );

	{ Next, filter the generated list so that only weapons which are ready }
	{ to attack may be attacked with. }
	MI := WPM^.FirstItem;
	while MI <> Nil do begin
		MI2 := MI^.Next;

		Weapon := LocateGearByNumber( Mek , MI^.Value );

		if not ReadyToFire( GB , Mek , Weapon ) then begin
			{ This weapon isn't ready to fire. Remove it from the menu. }
			RemoveRPGMenuItem( WPM , MI );

		end else begin
			{ This weapon _is_ ready to fire. Give it a spiffy }
			{ description. }
			MI^.desc := GearName( Weapon ) + ' ' + WeaponDescription( GB , Weapon );
		end;

		MI := MI2;
	end;

	{ Add the firing options. Save the address of the called shot entry. }
	MI := AddRPGMenuItem( WPM , CalledShotOff , -4 );
	AddRPGMenuKey( WPM , '/' , -4 );
	CallShot := False;
	AddRPGMenuItem( WPM , '  Wait for recharge [.]' , -3 );
	AddRPGMenuKey( WPM , '.' , -3 );
	AddRPGMenuItem( WPM , '  Options [?]' , -2 );
	AddRPGMenuKey( WPM , '?' , -2 );
	AddRPGMenuItem( WPM , '  Cancel [ESC]' , -1 );
	{ *** END MENU BUILDER *** }

	{ Actually get a selection from the menu. }
	{ A loop is needed so that if the player wants to set options, the game }
	{ will return directly to the weapons menu afterwards. }
	repeat
		{ Need to clear the entire menu zone, just to make sure the }
		{ display looks right. }

		N := SelectMenu( WPM , @PCMenuRedraw );

		if N = -2 then SetPlayOptions( GB , Mek )
		else if N = -4 then begin
			CallShot := Not CallShot;
			if CallShot then MI^.msg := CalledShotOn
			else MI^.msg := CalledShotOff;
		end;
	until ( N <> -2 ) and ( N <> -4 );

	{ Get rid of the menu. We don't need it any more. }
	DisposeRPGMenu( WPM );

	{ If the selection wasn't cancelled, proceed with the attack. }
	if N > -1 then begin
		{ A weapon has been selected. Now, select a target. }
		Weapon := LocateGearByNumber( Mek , N );

		{ Call the LOOKER procedure to select a target. }
		AimThatAttack( Mek , Weapon , CallShot , GB );

	end else if N = -3 then begin
		{ Wait on Recharge was selected from the menu. }
		WaitOnRecharge( GB , Mek );
	end;
end;

Procedure DoEjection( GB: GameBoardPtr; Mek: GearPtr );
	{ The player wants to eject from this mecha. First prompt to }
	{ make sure that the PC is serious about this, then do the }
	{ ejection itself. }
var
	RPM: RPGMenuPtr;
	Pilot: GearPtr;
	P: Point;
begin
	{ Error check - One cannot eject from oneself. }
	{ The PC must be in a mecha to use this command. }
	if ( Mek = Nil ) or ( Mek^.G <> GG_Mecha ) then Exit;

	{ Make sure that the player is really serious about this. }
	DialogMsg( MsgString( 'EJECT_Prompt' ) );
	RPM := CreateRPGMenu( PlayerBlue , StdWhite , ZONE_Menu2 );
	AddRPGMenuItem( RPM , MsgString( 'EJECT_Yes' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'EJECT_No' ) , -1 );
	SetItemByPosition( RPM , 2 );


	if SelectMenu( RPM , @PCMenuRedraw ) <> -1 then begin

		{ Better set the following triggers. }
		SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) ) );
		SetTrigger( GB , TRIGGER_UnitEliminated + BStr( NAttValue( Mek^.NA , NAG_EpisodeData , NAS_UID ) ) );

		P := GearCurrentLocation( Mek );

		repeat
			Pilot := ExtractPilot( Mek );

			if Pilot <> Nil then begin
				DialogMsg( GearName( Pilot ) + MsgString( 'EJECT_Message' ) + GearName( Mek ) + '.' );
				{ In a safe area, deploy the pilot in the same tile as the mecha. }
				if IsSafeArea( GB ) and not MovementBlocked( Pilot , GB , P.X ,P.Y , P.X , P.Y ) then begin
					SetNAtt( Pilot^.NA , NAG_Location , NAS_X , P.X );
					SetNAtt( Pilot^.NA , NAG_Location , NAS_Y , P.Y );
					DeployGear( GB , Pilot , True );
				end else begin
					DeployGear( GB , Pilot , False );
				end;
			end;

		until Pilot = Nil;

		if IsSAfeArea( GB ) then begin
			SetSAtt( Mek^.SA , 'PILOT <>' );
		end else begin
			{ Since this mecha is being abandoned in a combat zone, set the team }
			{ value to 0. Otherwise the PC could just use ejection }
			{ as an easy out to any combat without risking losing a }
			{ mecha. If the player team wins and gets salvage, they }
			{ should get this mek back anyhow. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_Team , 0 );
		end;
	end;

	DisposeRPGMenu( RPM );
end;

Procedure DoRest( GB: GameBoardPtr; Mek: GearPtr );
	{ The PC wants to rest, probably because he's out of stamina. Take a break for }
	{ an hour or so of game time. }
begin
	if ( NAttValue( LocatePilot( Mek )^.NA , NAG_Condition , NAS_Hunger ) > HUNGER_PENALTY_STARTS ) then begin
		DialogMsg( MsgString( 'REST_TooHungry' ) );
	end else if IsSafeArea( GB ) then begin
		DialogMsg( MsgString( 'REST_OK' ) );
		QuickTime( GB , 3600 );
		WaitAMinute( GB , Mek , 1 );
	end else begin
		DialogMsg( MsgString( 'REST_NotHere' ) );
	end;
end;

Procedure KeyMapDisplay;
	{ Display the game commands and their associated keystrokes. }
var
	RPM: RPGMenuPtr;
	RPI: RPGMenuItemPtr;
	T: Integer;
begin
	DialogMSG( MSgString( 'HELP_Prompt' ) );
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
	AttachMenuDesc( RPM , ZONE_Menu1 );

	for t := 1 to NumMappedKeys do begin
		AddRPGMenuItem( RPM , KeyMap[T].CmdName , T , KeyMap[T].CmdDesc );
	end;

{$IFNDEF ASCII}
	AddRPGMenuItem( RPM , 'Zoom In' , -1 , 'Zoom the camera in.' );
	AddRPGMenuItem( RPM , 'Zoom Out' , -2 , 'Zoom the camera out.' );
	AddRPGMenuItem( RPM , 'Rotate Left' , -3 , 'Rotate the camera left.' );
	AddRPGMenuItem( RPM , 'Rotate Right' , -4 , 'Rotate the camera right.' );
{$ENDIF}

	RPMSortAlpha( RPM );
	RPI := RPM^.FirstItem;
	while RPI <> Nil do begin
		case RPI^.Value of
			-1: RPI^.msg := 'PageUp - ' + RPI^.msg;
			-2: RPI^.msg := 'PageDown - ' + RPI^.msg;
			-3: RPI^.msg := 'Insert - ' + RPI^.msg;
			-4: RPI^.msg := 'Delete - ' + RPI^.msg;
			else RPI^.msg := KeyMap[RPI^.Value].KCode + ' - ' + RPI^.msg;
		end;
		RPI := RPI^.Next;
	end;

	SelectMenu( RPM , @PCMenuRedraw );


	DisposeRPGMenu( RPM );
end;

Procedure BrowseTextFile( GB: GameBoardPtr; FName: String );
	{ Load and display a text file, then clean up afterwards. }
var
	txt: SAttPtr;
begin
	txt := LoadStringList( FName );

	if txt <> Nil then begin
        {$IFDEF ASCII}
		MoreText( txt , 1 );
		CombatDisplay( GB );
        {$ELSE}
        PCACTIONRD_GB := GB;
		MoreText( txt , 1 , @PCActionRedraw );
        {$ENDIF}
		DisposeSAtt( txt );
	end;
end;

Procedure PCRLHelp( GB: GameBoardPtr );
	{ Show help information for all the commands available to the }
	{ RogueLike interface. }
var
	RPM: RPGMenuPtr;
	A: Integer;
begin
	DialogMSG( MSgString( 'HELP_Prompt' ) );
    {$IFDEF ASCII}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
    {$ELSE}
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CenterMenu );
    {$ENDIF}

	AddRPGMenuItem( RPM , MsgString( 'HELP_KeyMap' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'HELP_Chara' ) , 2 );
	AddRPGMenuItem( RPM , MsgString( 'HELP_Mecha' ) , 3 );
	AddRPGMenuItem( RPM , MsgString( 'HELP_FieldHQ' ) , 4 );
	AddRPGMenuItem( RPM , MsgString( 'HELP_Exit' ) , -1 );

	repeat
        {$IFDEF ASCII}
		A := SelectMenu( RPM , @PCMenuRedraw );
        {$ELSE}
		A := SelectMenu( RPM , @CenterMenuRedraw );
        {$ENDIF}


		case A of
			1: KeyMapDisplay;
			2: BrowseTextFile( GB , Chara_Help_File );
			3: BrowseTextFile( GB , Mecha_Help_File );
			4: BrowseTextFile( GB , FieldHQ_Help_File );
		end;
	until A = -1;

	DisposeRPGMenu( RPM );
end;

Procedure RLQuickAttack( GB: GameBoardPtr; PC: GearPtr );
	{ Try to attack. If no weapon is ready, wait for recharge. }
var
	Weapon: GearPtr;
	procedure SeekWeapon( Part: GearPtr );
		{ Look for a weapon which is ready to fire, select }
		{ based on range. }
	var
		WR1,WR2: Integer;
	begin
		while ( Part <> Nil ) do begin

			if ReadyToFire( GB , PC , Part ) then begin
				WR1 := WeaponRange( GB , Weapon , RANGE_Long );
				if ThrowingRange( GB , PC , Weapon ) > WR1 then WR1 := ThrowingRange( GB , PC , Weapon );
				WR2 := WeaponRange( GB , Part , RANGE_Long );
				if ThrowingRange( GB , PC , Part ) > WR2 then WR2 := ThrowingRange( GB , PC , Part );

				if Weapon = Nil then Weapon := Part
				else  if WR2 > WR1 then Weapon := Part
				else  if ( WR2 = WR1 ) and ( WeaponDC(Part) > WeaponDC(Weapon) ) then Weapon := Part;
			end;

			if ( Part^.SubCom <> Nil ) then SeekWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;
var
	Target: GearPtr;
begin
	{ Start by looking for a weapon to use. }
	{ If the PC already has a target in mind, pick the weapon best suited to that target. }
	Target := LocateMekByUID( GB , NAttValue( PC^.NA , NAG_EpisodeData , NAS_Target ) );
	if ( Target <> Nil ) and OnTheMap( GB , Target ) and MekCanSeeTarget( gb , PC , Target ) and GearOperational( Target ) and ( NAttValue( Target^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) <> NAV_NowSurrendered ) then begin
		Weapon := SelectBestWeapon( GB , PC , Target );
		if Weapon = Nil then begin
			SeekWeapon( PC^.SubCom );
			SeekWeapon( PC^.InvCom );
		end;
	end else begin
		Weapon := Nil;
		SeekWeapon( PC^.SubCom );
		SeekWeapon( PC^.InvCom );
	end;

	if Weapon = Nil then begin
		DialogMsg( 'You don''t have a weapon ready!' );
		WaitOnRecharge( GB , PC );

	end else begin
		AimThatAttack( PC , Weapon , False , GB );

	end;
end;

Function CoreBumpAttack( GB: GameBoardPtr; PC,Target: GearPtr ): Boolean;
	{ Try to attack TARGET. If no weapon is ready, wait for recharge. }
	{ If an attack takes place, clear the location var SmartAction. }
var
	Weapon: GearPtr;
	function NewWeaponBetter( W1,W2: GearPtr ): Boolean;
		{ Return TRUE if W2 is better than W1 for the purposes }
		{ of smartbump attacking, or FALSE otherwise. }
		{ A better weapon is a short range one with the best damage. }
	var
		R1,R2: Integer;
	begin
		R1 := WeaponRange( Nil , W1 , RANGE_Long );
		R2 := WeaponRange( Nil , W2 , RANGE_Long );
		if ( R2 < 3 ) and ( R1 > 2 ) then begin
			NewWeaponBetter := True;
		end else if ( ( R1 div 3 ) = ( R2 div 3 ) ) and ( WeaponDC( W2 ) > WeaponDC( W1 ) ) then begin
			NewWeaponBetter := True;
		end else begin
			NewWeaponBetter := False;
		end;
	end;
	procedure SeekWeapon( Part: GearPtr );
		{ Seek a weapon which is capable of hitting target. }
		{ Preference is given to short-range weapons. }
	begin
		while ( Part <> Nil ) do begin
			if ( Part^.G = GG_Module ) or ( Part^.G = GG_Weapon ) then begin
				if ReadyToFire( GB , PC , Part ) and RangeArcCheck( GB , PC , Part , Target ) then begin
					if Weapon = Nil then Weapon := Part
					else begin
						if NewWeaponBetter( Weapon , Part ) then begin
							Weapon := Part;
						end;
					end;
				end;
			end;
			if ( Part^.SubCom <> Nil ) then SeekWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;
begin
	{ Start by looking for a weapon to use. }
	Weapon := Nil;
	SeekWeapon( PC^.SubCom );

	if Weapon = Nil then begin
		CoreBumpAttack := False;
	end else begin
		{ Note that BumpAttacks are always done at AtOp = 0. }
		AttackerFrontEnd( GB , PC , Weapon , Target , 0 );
		SetNAtt( PC^.NA , NAG_Location , NAS_SmartAction , 0 );
		CoreBumpAttack := True;
	end;
end;

Procedure RLBumpAttack( GB: GameBoardPtr; PC,Target: GearPtr );
	{ Call the core bumpattack procedure, cancelling the action if it fails. }
begin
	if not CoreBumpAttack( GB , PC , Target ) then begin
		DialogMsg( 'You don''t have a weapon ready!' );
		WaitOnRecharge( GB , PC );
		SetNAtt( PC^.NA , NAG_Location , NAS_SmartAction , 0 );
	end;
end;

Procedure ContinuousSkillUse( GB: GameBoardPtr; Mek: GearPtr );
	{ The PC is using a skill. }
var
	Skill: Integer;
begin
	Skill := NAttValue( Mek^.NA , NAG_Location , NAS_SmartSkill );

	if ( Skill >= 1 ) and ( Skill <= NumSkill ) then begin
		Case Skill of
			NAS_Performance:	PCDoPerformance( GB , Mek );
		end;

		{ Decrease the usage count by one. }
		{ If it drops to zero, end this action. }
		{ Otherwise add a delay for the next action. }
		AddNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , -1 );
		if NAttValue( Mek^.NA , NAG_Location , NAS_SmartCount ) < 1 then begin
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartSkill , 0 );
		end else WaitAMinute( GB , Mek , ReactionTime( Mek ) );
	end else begin
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartSkill , 0 );
	end;
end;

Procedure RLSmartGo( GB: GameBoardPtr; Mek: GearPtr );
	{ The PC is going somewhere. March him in the right direction. }
var
	DX,DY: Integer;
begin
	DX := NAttValue( Mek^.NA , NAG_Location , NAS_SmartX );
	DY := NAttValue( Mek^.NA , NAG_Location , NAS_SmartY );

	AddNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , -1 );

	IF NAttValue( Mek^.NA , NAG_Location , NAS_SmartCount ) < 1 then begin
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
	end else if not MOVE_MODEL_TOWARDS_SPOT( Mek , GB , DX , DY ) then begin
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
	end;
end;

Procedure RLSmartAction( GB: GameBoardPtr; Mek: GearPtr );
	{ Do the smart bump! What is smart bump? Well, in most games of }
	{ this sort bumping into another model will cause you to attack it. }
	{ In this game I wanted the player's model to react semi-intelligently }
	{ to stuff it bumps into. If it's an enemy, attack it. If it's a }
	{ friend, talk to it. If it's a wall, just look at it... }
var
	CD,SD: Integer;	{ Current Direction, Smart Direction }
	T,MoveAction: Integer;
	P,P0,P2: Point;
	M2: GearPtr;
begin
	CD := NAttValue( Mek^.NA , NAG_Location , NAS_D );
	SD := NAttValue( Mek^.NA , NAG_Location , NAS_SmartAction );

	{ First, check to see if we have chosen a continuous action other }
	{ than simply walking. }
	if SD = NAV_SmartAttack then begin
		RLSmartAttack( GB , Mek );
	end else if SD = NAV_UseSkill then begin
		ContinuousSkillUse( GB , Mek );
	end else if SD = NAV_SmartGo then begin
		RLSmartGo( GB , Mek );

	end else if CD <> Roguelike_D[ SD ] then begin
		{ Turn to face the required direction. }
		P := GearCurrentLocation( Mek );
		P.X := P.X + AngDir[ Roguelike_D[ SD ] , 1 ];
		P.Y := P.Y + AngDir[ Roguelike_D[ SD ] , 2 ];

		M2 := FindVisibleBlockerAtSpot( GB , P.X , P.Y );

		if ( M2 <> Nil ) and GearOperational( M2 ) and AreEnemies( GB , Mek , M2 ) and ( NAttValue( M2^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) <> NAV_NowSurrendered ) and CoreBumpAttack( GB , Mek , M2 ) then begin
			{ If the attack was performed, cancel the SmartAction. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );

		end else begin
			MoveAction := NAV_TurnRight;
			for t := 1 to 4 do begin
				if (( CD + T ) mod 8 ) = Roguelike_D[ SD ] then MoveAction := NAV_TurnRight
				else if (( CD + 8 - T ) mod 8 ) = Roguelike_D[ SD ] then MoveAction := NAV_TurnLeft;
			end;
			PrepAction( GB , Mek , MoveAction );
		end;

	end else begin
		{ We are already looking in the correct direction. }
		{ Do something. }
		P0 := GearCurrentLocation( Mek );
		P.X := P0.X + AngDir[ CD , 1 ];
		P.Y := P0.Y + AngDir[ CD , 2 ];

		if not MovementBlocked( Mek , GB , P0.X , P0.Y , P.X , P.Y ) then begin
			{ We can move in this direction. Do so. }
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_SmartSpeed ) = NAV_FullSpeed ) and ( CurrentStamina( Mek ) > 0 ) then begin
				PrepAction( GB , Mek , NAV_FullSpeed );
			end else begin
				PrepAction( GB , Mek , NAV_NormSpeed );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartSpeed , NAV_NormSpeed );
			end;
			{ CLear the SmartBump counter. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );

		end else begin
			{ There's something in the way of our movement. Deal with it. }
			M2 := FindVisibleBlockerAtSpot( GB , P.X , P.Y );

			if M2 = Nil then begin
				DialogMsg( MsgString( 'SMARTACTION_Blocked' ) );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
			end else if AreEnemies( GB , Mek , M2 ) and ( NAttValue( M2^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) <> NAV_NowSurrendered ) then begin
				{ M2 is an enemy! Thwack it! Thwack it now!!! }
				RLBumpAttack( GB , Mek , M2 );
			end else if ( NAttValue( M2^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and not IsBlockingTerrain( GB , Mek , TileTerrain( GB , P.X , P.Y ) ) then begin
				{ M2 is a lancemate. Try changing places with it. }
				{ This will happen outside of the normal movement code... I hope that }
				{ it won't be exploitable... }
				P := GearCurrentLocation( Mek );
				P2 := GearCurrentLocation( M2 );
				SetNAtt( Mek^.NA , NAG_Location , NAS_X , P2.X );
				SetNAtt( Mek^.NA , NAG_Location , NAS_Y , P2.Y );
				SetNAtt( M2^.NA , NAG_Location , NAS_X , P.X );
				SetNAtt( M2^.NA , NAG_Location , NAS_Y , P.Y );
				WaitAMinute( GB , Mek , CPHMoveRate( GB^.Scene , Mek , GB^.Scale ) );
				WaitAMinute( GB , M2 , CPHMoveRate( GB^.Scene , M2 , GB^.Scale ) );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );

			end else if ( M2^.G = GG_Prop ) or not IsMasterGear( M2 ) then begin
				{ M2 is an object of some type. Try using it. }
				{ CLear the SmartBump counter. }
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
				PrepAction( GB , Mek , NAV_Stop );
				UsePropFrontEnd( GB , Mek , M2 , 'USE' );

			end else begin
				{ M2 isn't an enemy... try talking to it. }
				DoTalkingWithNPC( GB , Mek , M2 , False );
				SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , 0 );
			end;
		end;
	end;
end;

Procedure RLWalker( GB: GameBoardPtr; Mek: GearPtr; D: Integer; RunNow: Boolean );
	{ The player has pressed a direction key and is preparing to }
	{ walk in that direction... or, alternatively, to attack }
	{ an enemy in that tile, or to speak with an ally in that tile. }
begin
	SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , D );
	if RunNow then begin
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartSpeed , NAV_FullSpeed );
	end else begin
		SetNAtt( Mek^.NA , NAG_Location , NAS_SmartSpeed , NAV_NormSpeed );
	end;
	RLSmartAction( GB , Mek );
end;

Procedure GameOptionMenu( Mek: GEarPtr; GB: GameBoardPtr );
	{ Let the user set options from this menu. }
	{ -> Combat Settings }
	{ -> Quit Game }
var
	N: Integer;
	RPM: RPGMenuPtr;
begin
	RPM := CreateRPGMenu( PlayerBlue , StdWhite , ZONE_Menu );
	AddRPGMenuItem( RPM , 'Inventory' , 2 );
	AddRPGMenuItem( RPM , 'Get Item' , 3 );
	AddRPGMenuItem( RPM , 'Enter Location' , 4 );
	AddRPGMEnuItem( RPM , 'Apply Skill' , 5 );
	AddRPGMenuItem( RPM , 'Combat Settings' , 1 );
	AddRPGMEnuItem( RPM , 'Eject from Mecha' , -6 );
	AddRPGMenuItem( RPM , 'Character Info' , 6 );
	AddRPGMenuItem( RPM , 'Quit Game' , -2 );
	AddRPGMenuItem( RPM , 'Return to Main' , -1 );

	DialogMsg('Advanced options menu.');

	repeat
		N := SelectMenu( RPM , @PCMenuRedraw );

		if N = 1 then SetPlayOptions( GB , Mek )
		else if N = 2 then PCBackpackMenu( GB , Mek , True )
		else if N = 3 then PCGetItem( GB , Mek )
		else if N = 4 then PCEnter( GB , Mek )
		else if N = 5 then PCActivateSkill( GB , Mek )
		else if N = 6 then PCViewChar( GB , Mek )
		else if N = -6 then DoEjection( GB , Mek )
		else if N = -2 then GB^.QuitTheGame := True;
	until ( N < 0 ) or ( NAttValue( Mek^.NA , NAG_Action , NAS_CallTime ) > GB^.ComTime );

	DisposeRPGMenu( RPM );
end;

Procedure InfoMenu( Mek: GEarPtr; GB: GameBoardPtr );
	{ This menu contains various information utilities. }
	{ -> Examine Map }
	{ -> Pilot Stats }
var
	N: Integer;
	RPM: RPGMenuPtr;
begin
	RPM := CreateRPGMenu( PlayerBlue , StdWhite , ZONE_Menu );
	AddRPGMenuItem( RPM , 'Examine Map' , 1 );
	AddRPGMenuItem( RPM , 'Mecha Browser' , 3 );
	AddRPGMenuItem( RPM , 'Return to Main' , -1 );

	DialogMsg('Information Menu.');

	repeat
		N := SelectMenu( RPM , @PCMenuRedraw );

		if N = 1 then LookAround( GB , Mek )
		else if N = 3 then MechaPartBrowser( Mek , @PCActionRedraw );


	until N < 0;

	DisposeRPGMenu( RPM );
end;

Procedure ShowRep( PC: GearPtr );
	{ Display all of the PC's reputations. }
	{ This is a debugging command. }
var
	T,N: Integer;
begin
	PC := LocatePilot( PC );
	if PC <> Nil then begin
		for t := 1 to 7 do begin
			N := NAttValue( PC^.NA , NAG_CharDescription , -T );
			if N <> 0 then DialogMsg( PersonalityTraitDesc( T , N ) + ' (' + BStr( Abs( N ) ) + ')' );
		end;
	end;
end;

Procedure DirectScript( GB: GameBoardPtr );
	{ CHEAT COMMAND! Directly invoke an ASL script. }
var
	event: String;
begin
	event := GetStringFromUser( 'DEBUG CODE 45123' , @PCActionRedraw );

	if event <> '' then begin
		CombatDisplay( GB );
		InvokeEvent( event , GB , GB^.Scene , event );
	end else begin
		CombatDisplay( GB );
	end;
end;

Procedure PCRunToggle;
	{ If the PC is running, switch to walking. If he's walking, switch to running. }
begin
	PC_SHOULD_RUN := not PC_SHOULD_RUN;
	if PC_SHOULD_RUN then begin
		DialogMsg( MsgString( 'RUN_ON' ) );
	end else begin
		DialogMsg( MsgString( 'RUN_OFF' ) );
	end;
end;

Procedure DoQuickFire( GB: GameBoardPtr; Mek: GearPtr );
	{ QUICKFIRE: The central function! }
	{ Enacts a QuickFire action. If the player has chosen a weapon to QuickFire with, }
	{ they will aim for the nearest enemy in range, and attack with that weapon. }
	{ Excellent for guns, and works okay with thrown/melee weapons, since it only }
	{ considers attack range, not throw range, and thus doesn't throw needlessly. }
	{ QuickFire tries to stick with the player's target, but will automatically }
	{ retarget if necessary. }
		{ GB: The game board upon which the Mek will QuickFire }
		{ Mek: The entity that will attack the nearest enemy in range }
var
	QFWpn: GearPtr;		{ The QuickFire weapon }
	T: GearPtr;			{ Enemy target }
	AtOp: Integer;		{ Default attack options }
begin
	QFWpn := FindQuickFireWeapon( GB , Mek );
	
	if ( QFWpn = Nil ) or ( FindMaster( QFWpn ) <> FindRoot( QFWpn ) ) then begin
		{ Couldn't find a suitable QuickFire weapon }
		DialogMsg( MsgString( 'QUICKFIRE_NoWeapon' ) );
		Exit;
	end;
	
	{ Check that weapon is ready }
	if not ReadyToFire( GB, Mek, QFWpn ) then begin
		DialogMsg( ReplaceHash( MsgString( 'ATA_NotReady' ) , GearName( QFWpn ) ) );
		Exit;
	end;
	
	{ Obtain target }
	T := LocateMekByUID( GB , NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Target ) );
	AtOp := DefaultAtOp( QFWpn );

	if ( T = Nil ) or not GearActive( T ) then T := SeekTarget( GB, Mek );
	
	{ Big targeting conditional. We fight our target, or we retarget and fight that instead. }
	if ( T <> Nil ) and ( Range( GB, Mek, T ) <= WeaponRange( GB, QFWpn , RANGE_Long ) ) and GearActive( T ) and MekCanSeeTarget( GB, Mek, T ) then begin

		{ We can fire at our last target }
		if RangeArcCheck( GB, Mek, QFWpn, T ) then begin
			AttackerFrontEnd( GB, Mek, QFWpn, T, AtOp );
		end else begin
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartCount , -5 );
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Target , NAttValue( T^.NA , NAG_EpisodeData , NAS_UID ) );
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartAction , NAV_SmartAttack );
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartWeapon , FindGearIndex( Mek , QFWpn ) );
			SetNAtt( Mek^.NA , NAG_Location , NAS_SmartTarget , 0 );
			RLSmartAttack( GB , Mek );
		end;
		
	end else begin
		DialogMsg( MsgString( 'QUICKFIRE_NoEnemies' ) );
		Exit;		
	end;
end;

Procedure SwitchPartyMode( GB: GameBoardPtr );
	{ Switch the party mode currently being used: either Clock or Tactics. }
	{ If the current mode is Tactics, you can't switch back to Clock unless this is }
	{ a safe area. If switching to tactics mode, be sure to set the TacticsTurnStart }
	{ attribute. }
var
	mode: Integer;
begin
	{ Error check- can only switch modes when we have a scene. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;

	mode := NAttValue( GB^.Scene^.NA , NAG_SceneData , NAS_PartyControlMethod );

	if mode = NAV_ClockMode then begin
		{ Switch to tactics mode. }
		DialogMsg( MsgString( 'SwitchPartyMode_GoTactics' ) );
		SetNAtt( GB^.Scene^.NA , NAG_SceneData , NAS_PartyControlMethod , NAV_TacticsMode );
		SetNAtt( GB^.Scene^.NA , NAG_SceneData , NAS_TacticsTurnStart , GB^.ComTime );
	end else begin
		{ Set the mode to clock mode. }
		if IsSafeArea( GB ) then begin
			{ It's safe to perform the switch. }
			DialogMsg( MsgString( 'SwitchPartyMode_GoClock' ) );
			SetNAtt( GB^.Scene^.NA , NAG_SceneData , NAS_PartyControlMethod , NAV_ClockMode );
		end else begin
			DialogMsg( MsgString( 'SwitchPartyMode_Fail' ) );
		end;
	end;
end;



Procedure ShowSkillXP( PC: GearPtr );
	{ Show how much skill experience this PC has. }
var
	T,XP: LongInt;
begin
	PC := LocatePilot( PC );
	if PC <> Nil then begin
		for t := 1 to NumSkill do begin
			XP := NAttValue( PC^.NA , NAG_Experience , NAS_Skill_XP_Base + T );
			if XP > 0 then begin
				DialogMsg( MsgString( 'SkillName_' + BStr( T ) ) + ': ' + BStr( XP ) + '/' + BStr( SkillAdvCost( PC , NAttValue( PC^.NA , NAG_Skill , T ) ) ) );
			end;
		end;
	end;
end;

Procedure SpitContents( M: GearPtr );
	{ Just list all the siblings in this list.}
begin
	while M <> Nil do begin
		dialogmsg( GearName( M ) + '  ' + BStr( NAttValue( M^.NA , NAG_Location , NAS_X ) ) + ',' + BStr( NAttValue( M^.NA , NAG_Location , NAS_Y ) ) );
		M := M^.Next;
	end;
end;

Function PCA_CommandProcessor( Mek: GearPtr; Camp: CampaignPtr; KCode: Integer; IsPC: Boolean ): Boolean;
	{ Process this command. KCode is one of the standard key codes; it may have been }
	{ modified by the calling procedure, i.e. holding shift turns "walk" into "run". }
	{ Branch to the appropriate procedure; return TRUE if the PC has acted, or FALSE }
	{ if the PC hasn't. }
	{ IsPC will be true if MEK is a member of the player team, and false if MEK is a }
	{ lancemate or other such indirectly controlled model. If the requested action isn't }
	{ legal for a lancemate then an error message will be printed here. }
var
	GotMove: Boolean;
begin
	GotMove := False;
{$IFNDEF ASCII}
	if KCode = KMC_SouthWest then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 3 ) ] , PC_Should_Run or ( RK_KeyState[ SDLK_RSHIFT ] = 1 ) or ( RK_KeyState[ SDLK_LSHIFT ] = 1 ) );
		GotMove := True;
	end else if KCode = KMC_South then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 2 ) ] , PC_Should_Run or ( RK_KeyState[ SDLK_RSHIFT ] = 1 ) or ( RK_KeyState[ SDLK_LSHIFT ] = 1 ) );
		GotMove := True;
	end else if KCode = KMC_SouthEast then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 1 ) ] , PC_Should_Run or ( RK_KeyState[ SDLK_RSHIFT ] = 1 ) or ( RK_KeyState[ SDLK_LSHIFT ] = 1 ) );
		GotMove := True;
	end else if KCode = KMC_West then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 4 ) ] , PC_Should_Run or ( RK_KeyState[ SDLK_RSHIFT ] = 1 ) or ( RK_KeyState[ SDLK_LSHIFT ] = 1 ) );
		GotMove := True;
	end else if KCode = KMC_East then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 0 ) ] , PC_Should_Run or ( RK_KeyState[ SDLK_RSHIFT ] = 1 ) or ( RK_KeyState[ SDLK_LSHIFT ] = 1 ) );
		GotMove := True;
	end else if KCode = KMC_NorthWest then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 5 ) ] , PC_Should_Run or ( RK_KeyState[ SDLK_RSHIFT ] = 1 ) or ( RK_KeyState[ SDLK_LSHIFT ] = 1 ) );
		GotMove := True;
	end else if KCode = KMC_North then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 6 ) ] , PC_Should_Run or ( RK_KeyState[ SDLK_RSHIFT ] = 1 ) or ( RK_KeyState[ SDLK_LSHIFT ] = 1 ) );
		GotMove := True;
	end else if KCode = KMC_NorthEast then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 7 ) ] , PC_Should_Run or ( RK_KeyState[ SDLK_RSHIFT ] = 1 ) or ( RK_KeyState[ SDLK_LSHIFT ] = 1 ) );
		GotMove := True;
{$ELSE}
	if KCode = KMC_SouthWest then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 3 ) ] , PC_Should_Run );
		GotMove := True;
	end else if KCode = KMC_South then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 2 ) ] , PC_Should_Run );
		GotMove := True;
	end else if KCode = KMC_SouthEast then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 1 ) ] , PC_Should_Run );
		GotMove := True;
	end else if KCode = KMC_West then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 4 ) ] , PC_Should_Run );
		GotMove := True;
	end else if KCode = KMC_East then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 0 ) ] , PC_Should_Run );
		GotMove := True;
	end else if KCode = KMC_NorthWest then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 5 ) ] , PC_Should_Run );
		GotMove := True;
	end else if KCode = KMC_North then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 6 ) ] , PC_Should_Run );
		GotMove := True;
	end else if KCode = KMC_NorthEast then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ KeyboardDirToMapDir( 7 ) ] , PC_Should_Run );
		GotMove := True;
{$ENDIF}

	end else if KCode = KMC_NormSpeed then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ NAttValue( Mek^.NA , NAG_Location , NAS_D ) ] , False );
		GotMove := True;
	end else if KCode = KMC_TurnLeft then begin
		PrepAction( Camp^.GB , Mek , NAV_TurnLeft );
	end else if KCode = KMC_TurnRight then begin
		PrepAction( Camp^.GB , Mek , NAV_TurnRight );
	end else if KCode = KMC_FullSpeed then begin
		RLWalker( Camp^.GB , Mek , Reverse_RL_D[ NAttValue( Mek^.NA , NAG_Location , NAS_D ) ] , True );
		GotMove := True;
	end else if ( KCode = KMC_Reverse ) and MoveLegal( Camp^.GB^.Scene , Mek , NAV_Reverse , Camp^.GB^.ComTime ) then begin
		PrepAction( Camp^.GB , Mek , NAV_Reverse );
	end else if KCode = KMC_Stop then begin
		PrepAction( Camp^.GB , Mek , NAV_Stop );

	end else if KCode = KMC_ShiftGears then begin
		ShiftGears( Camp^.GB , Mek , TRUE );
	end else if KCode = KMC_ExamineMap then begin
		LookAround( Camp^.GB , Mek );
	end else if KCode = KMC_AttackMenu then begin
		DoPlayerAttack( Mek , Camp^.GB );
	end else if KCode = KMC_Attack then begin
		RLQuickAttack( Camp^.GB , Mek );
	end else if KCode = KMC_QuitGame then begin
		if DoAutoSave then PCSaveCampaign( Camp , Mek , True );
		Camp^.GB^.QuitTheGame := True;

	end else if KCode = KMC_Talk then begin
		PCTalk( Camp^.GB , Mek );

	end else if KCode = KMC_Telephone then begin
		PCTelephone( Camp^.GB , Mek );

	end else if KCode = KMC_Help then begin
		PCRLHelp( Camp^.GB );

	end else if KCode = KMC_Get then begin
		PCGetItem( Camp^.GB , Mek );

	end else if KCode = KMC_Inventory then begin
		PCBackpackMenu( Camp^.GB , Mek , True );
	end else if KCode = KMC_Equipment then begin
		PCBackpackMenu( Camp^.GB , Mek , False );

	end else if ( KCode = KMC_Enter ) or ( KCode = KMC_Enter2 ) then begin
		PCEnter( Camp^.GB , Mek );

	end else if KCode = KMC_PartBrowser then begin
		MechaPartBrowser( Mek , @PCActionRedraw );

	end else if KCode = KMC_LearnSkills then begin
		PCACTIONRD_GB := Camp^.GB;
		DoTraining( Camp^.GB , Mek , @PCActionRedraw );

	end else if KCode = KMC_SelectMecha then begin
		DoSelectPCMek( Camp^.GB , Mek );

	end else if KCode = KMC_SaveGame then begin
		PCSaveCampaign( Camp , Mek , True );

	end else if KCode = KMC_CharInfo then begin
		PCViewChar( Camp^.GB , Mek );

	end else if KCode = KMC_ApplySkill then begin
		PCActivateSkill( Camp^.GB , Mek );

	end else if KCode = KMC_Eject then begin
		DoEjection( Camp^.GB , Mek );

	end else if KCode = KMC_Rest then begin
		DoRest( Camp^.GB , Mek );

	end else if KCode = KMC_History then begin
		DisplayConsoleHistory( Camp^.GB );

	end else if KCode = KMC_FieldHQ then begin
		PCFieldHQ( Camp^.GB , Mek );

	end else if KCode = KMC_ViewMemo then begin
		MemoBrowser( Camp^.GB , Mek );

	end else if KCode = KMC_UseProp then begin
		PCUseProp( Camp^.GB , Mek );

	end else if KCode = KMC_Search then begin
		PCSearch( Camp^.GB , Mek );

	end else if KCode = KMC_RunToggle then begin
		PCRunToggle;

	end else if KCode = KMC_QuickFire then begin
		DoQuickFire( Camp^.GB, Mek );

	end else if KCode = KMC_RollHistory then begin
        {$IFDEF ASCII}
		MoreText( Skill_Roll_History , MoreHighFirstLine( Skill_Roll_History ) );
        {$ELSE}
        PCACTIONRD_GB := Camp^.GB;
		MoreText( Skill_Roll_History , MoreHighFirstLine( Skill_Roll_History ) , @PCActionRedraw );
        {$ENDIF}
	end else if KCode = KMC_PartyMode then begin
		SwitchPartyMode( Camp^.GB );
		GotMove := True;

	end else if KCode = KMC_UseSystem then begin
		UsableGearMenu( Camp^.GB , Mek );

{$IFNDEF ASCII}
	end else if KCode = KMC_WallToggle then begin
		Use_Tall_Walls := not Use_Tall_Walls;
{$ENDIF}

	end;
	PCA_CommandProcessor := GotMove;
end;

Procedure MenuPlayerInput( Mek: GearPtr; GB: GameBoardPtr );
	{ This mek belongs to the player. Get input. }
var
	MoveMode, T , S: Integer;
	RPM: RPGMenuPtr;
begin
	{ Create the action menu. }
	RPM := CreateRPGMenu( PlayerBlue , StdWhite , ZONE_Menu );

	{ Add movement options - Cruise, Full, Turn-L, Turn-R }
	{ - if it's appropriate to do so. Check to make sure }
	{ that the mek is capable of moving first. }
	MoveMode := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	if CPHMoveRate( GB^.Scene , Mek , gb^.Scale ) > 0 then begin
		if MoveMode = MM_Walk then begin
			AddRPGMenuItem( RPM , 'Walk' , NAV_NormSpeed );
			AddRPGMenuItem( RPM , 'Run' , NAV_FullSpeed );
		end else begin
			AddRPGMenuItem( RPM , 'Cruise Speed' , NAV_NormSpeed );
			if MoveLegal( GB^.Scene , Mek , NAV_FullSpeed , GB^.ComTime ) then AddRPGMenuItem( RPM , 'Full Speed' , NAV_FullSpeed );
		end;
		if MoveLegal( GB^.Scene , Mek , NAV_TurnLeft , GB^.ComTime ) then AddRPGMenuItem( RPM , '<<< Turn Left', NAV_TurnLeft );
		if MoveLegal( GB^.Scene , Mek , NAV_TurnRight , GB^.ComTime ) then AddRPGMenuItem( RPM , '    Turn Right >>>', NAV_TurnRight);
		if MoveLegal( GB^.Scene , Mek , NAV_Reverse , GB^.ComTime ) then AddRPGMenuItem( RPM , '    Reverse', NAV_Reverse);
	end;

	{ Add movemode switching options, if applicable. }
	{ Check to see what movemodes the mek has }
	{ available. }
	for t := NumMoveMode downto 1 do begin
		{ We won't add a switch option for the move mode currently }
		{ being used. }
		if T <> MoveMode then begin
			if ( BaseMoveRate( GB^.Scene , Mek , T ) > 0 ) and MoveLegal( GB^.Scene , Mek , T , NAV_NormSpeed , GB^.ComTime ) then begin
				if T = MM_Fly then begin
					if JumpTime( GB^.Scene , Mek ) > 0 then begin
						AddRPGMenuItem( RPM , 'Jump' , 100+T );
					end else begin
						AddRPGMenuItem( RPM , MsgString( 'MoveModeName_' + BStr(T) ) , 100+T );
					end;
				end else begin
					AddRPGMenuItem( RPM , MsgString( 'MoveModeName_' + BStr(T) ) , 100+T );
				end;
			end;
		end;
	end;

	{ Add the Stop/Wait option. For meks which have }
	{ had their movement systems disabled, this will }
	{ be the only option. }
	if NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction ) = NAV_Stop then begin
		AddRPGMenuItem( RPM , 'Wait', -1 );
	end else begin
		AddRPGMenuItem( RPM , 'Stop', -1 );
	end;

	AddRPGMenuItem( RPM , 'Weapons Menu', -3 );
	AddRPGMenuItem( RPM , 'Info Menu', -2 );
	AddRPGMenuItem( RPM , 'Options Menu', -5 );
	AddRPGMenuItem( RPM , 'Search' , -6 );

	{ Set the SelectItem field of the menu to the }
	{ item which matches the mek's last menu action. }
	SetItemByValue( RPM , NAttValue( Mek^.NA , NAG_Location , NAS_LastMenuItem ) );

	RPM^.Mode := RPMNoCleanup;

	{ Keep processing input from the mek until we get }
	{ an input which changes the CallTime. }
	while (NAttValue( Mek^.NA , NAG_Action , NAS_CallTime) <= GB^.ComTime ) and (not GB^.QuitTheGame) and GearActive( Mek ) do begin
		{ Indicate the mek to get the action for, }
		{ and prepare the display. }

		{ Input the action. }
		S := SelectMenu( RPM , @PCMenuRedraw );


		{ Set ETA, movement stats, whatever. }
		if ( S > -1 ) and ( S < 100 ) then begin
			{ Some basic movement command. }
			PrepAction( GB , Mek , S );

		end else if ( S div 100 ) = 1 then begin
			{ A movemode switch has been selected. }
			SetMoveMode( GB , Mek , S mod 100 );

		end else if S = -1 then begin
			{ WAIT or STOP, depending... }
			PrepAction( GB , Mek , NAV_Stop );

		end else if S = -2 then begin
			InfoMenu( Mek , GB );
		end else if S = -3 then begin
			DoPlayerAttack( Mek , GB );
		end else if S = -5 then begin
			GameOptionMenu( Mek , GB );
		end else if S = -6 then begin
			PCSearch( GB , Mek );
		end; {if}

	end; {While}

	{ Record the last used menu action. }
	SetNAtt( Mek^.NA , NAG_Location , NAS_LastMenuItem , S );

	{ De-allocate the menu. }
	DisposeRPGMenu( RPM );

end;


Function KeyToKeyCode( KP: Char ): Integer;
	{ Return the key code represented by this key press. }
var
	t,kcode: Integer;
begin
	kcode := 0;
	for t := 1 to NumMappedKeys do begin
		if KeyMap[t].IsACommand and ( KeyMap[t].kcode = KP ) then begin
			kcode := t;
			Break;
		end;
	end;
	KeyToKeyCode := kcode;
end;

{$IFNDEF ASCII}
Procedure GraphicsTest( GB: GameBoardPtr );

var
	Time0: QWord;
	T: Integer;
begin
	Time0 := SDL_GetTicks;
	DialogMsg( '*** Graphics Test ***' );

	for t := 1 to 100 do begin
		CombatDisplay( GB );
		DoFlip;
	end;

	DialogMsg( 'Time: ' + BStr( SDL_GetTicks - Time0 ) );
end;
{$ENDIF}

Procedure GodMode( GB: GameBoardPtr; PC: GearPtr );
	{ CHEAT COMMAND! Make PC ready for instant adventuring from beginning }
	{ to ending. }
var
	T: Integer;
	Item: GearPtr;
begin
	DialogMsg( '*** GOD MODE ACTIVATED ***' );

	for t := 1 to NumSkill do begin
		if NAttValue( PC^.NA , NAG_Skill , T ) > 0 then SetNAtt( PC^.NA , NAG_Skill , T , 20 );
	end;
	SetNAtt( PC^.NA , NAG_Skill , NAS_Vitality , 30 );
	SetNAtt( PC^.NA , NAG_Skill , NAS_Awareness , 30 );
	SetNAtt( PC^.NA , NAG_Experience , NAS_Credits , 10000000 );
	AddSAtt( FindRoot( GB^.Scene )^.SA , 'HISTORY' , 'God mode was activated.' );
	SelectEquipmentForNPC( GB, PC, 120 );
	Item := LoadNewItem( 'Network Phone' );
	if Item <> Nil then InsertInvCom( PC , Item );
end;

Procedure CheckMissionGivers( GB: GameBoardPtr );
	{ Examine the mission givers per city. }
var
	Num_Factions: Integer;
	Mission_Givers: Array of Integer;
	Faction_Desig: Array of String;
	Results: SAttPtr;
	Procedure RecordFactionDesigs;
		{ Record the designations for these factions. }
	var
		T: Integer;
		Fac: GearPtr;
	begin
		for t := 0 to Num_Factions do begin
			Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , T );
			if Fac = Nil then begin
				Faction_Desig[ t ] := 'NOFAC';
			end else begin
				Faction_Desig[ t ] := SAttValue( Fac^.SA , 'DESIG' );
			end;
		end;
	end;
	Procedure ClearTheArray;
		{ Clear the Mission_Givers array. }
	var
		T: Integer;
	begin
		for t := 0 to Num_Factions do Mission_Givers[ t ] := 0;
	end;
	Procedure OutputString( msg: String );
		{ Output this string. }
	begin
		DialogMsg( msg );
		StoreSAtt( Results, msg );
	end;
	Procedure OutputTheResults;
		{ We've counted up all the mission-givers in this city. }
		{ Better output the results. }
	var
		T: Integer;
	begin
		for t := 0 to Num_Factions do begin
			if Mission_Givers[ t ] > 0 then begin
				OutputString( '  ' + Faction_Desig[ t ] + ': ' + BStr( Mission_Givers[ t ] ) );
			end;
		end;
	end;
	Procedure CheckAlongPath( LList: GearPtr );
		{ Check along this list, recording any mission-givers discovered. }
	var
		FID: Integer;
	begin
		while LList <> Nil do begin
			if ( LList^.G = GG_Character ) and ( NAttValue( LList^.NA , NAG_CharDescription , NAS_NonMissionGiver ) = 0 ) then begin
				FID := GetFactionID( LList );
				if ( FID > 0 ) and ( FID <= Num_Factions ) then Inc( Mission_Givers[ FID ] );
			end;
			CheckAlongPath( LList^.SubCom );
			CheckAlongPath( LList^.InvCom );
			LList := LList^.Next;
		end;
	end;
	Procedure CheckThisCity( City: GearPtr );
		{ Examine this city, searching for mission-giving NPCs. }
		{ Output the results. }
	begin
		{ Start by clearing the array. }
		ClearTheArray;

		{ Output the name of the city. }
		OutputString( FullGearName( City ) );

		{ Start counting the mission-givers. }
		CheckAlongPath( City^.SubCom );
		CheckAlongPath( City^.InvCom );

		{ Output the results. }
		OutputTheResults;
		StoreSAtt( Results , ' ' );
	end;
var
	World,LList: GearPtr;
begin
	{ Step One: Determine how many factions there are, and dimension }
	{ the array. }
	Num_Factions := NumSiblingGears( Factions_List );
	SetLength( Mission_Givers , Num_Factions + 1 );
	SetLength( Faction_Desig , Num_Factions + 1 );
	RecordFactionDesigs;

	{ Init the results list. }
	Results := Nil;

	{ Find the current world. }
	World := FindWorld( GB , GB^.Scene );
	if World <> Nil then begin
		LList := World^.SubCom;
		while LList <> Nil do begin
			if LList^.G = GG_Scene then begin
				CheckThisCity( LList );
			end;
			LList := LList^.Next;
		end;
	end;

	{ Write the results to file, and dispose of the list. }
	SaveStringList( 'out_mgtest.txt' , Results );
	DisposeSAtt( Results );
end;


Procedure RLPlayerInput( Mek: GearPtr; Camp: CampaignPtr );
	{ Allow the PC to control the action as per normal in a RL }
	{ game- move using the arrow keys, use other keys for everything }
	{ else. }
var
	KP: Char;	{ Key Pressed }
	KCode: Integer;
	GotMove: Boolean;
	Mobile: Boolean;
begin
	{ Record where the mek currently is. }
	Mobile := CurrentMoveRate( Camp^.GB^.Scene , Mek ) > 0;

	FocusOn( Mek );

	if ( NAttValue( Mek^.NA , NAG_Location , NAS_SmartAction ) <> 0 ) and Mobile then begin
		{ The player is smartbumping. Call the appropriate procedure. }
		RLSmartAction( Camp^.GB , Mek );

	end else begin
		GotMove := False;

		{ Start the input loop. }
		while (NAttValue( Mek^.NA , NAG_Action , NAS_CallTime) <= Camp^.GB^.ComTime) and (not GotMove) and (not Camp^.GB^.QuitTheGame) and GearActive( Mek ) do begin
			CombatDisplay( Camp^.GB );
			DoFlip;

			{ Input the action. }
			KP := RPGKey;

			KCode := KeyToKeyCode( KP );

			if KCode > 0 then begin
				{ We got a command. Process it. }
				GotMove := PCA_CommandProcessor( Mek, Camp, KCode, True );

{$IFNDEF ASCII}
			end else if ( KP = RPK_RightButton ) and Mouse_Active then begin
				GameOptionMenu( Mek , Camp^.GB );
{$ENDIF}
			end else if KP = '}' then begin
				ForcePlot( Camp^.GB , Mek , Camp^.GB^.Scene );
			end else if ( KP = '!' ) and ( Camp^.GB^.Scene <> Nil ) then begin
				BrowseDesignFile( FindRoot( Camp^.GB^.Scene )^.InvCom , @PCActionRedraw );
			end else if ( KP = '$' ) and ( Camp^.GB^.Scene <> Nil ) then begin
				BrowseDesignFile( FindRoot( Camp^.GB^.Scene )^.SubCom , @PCActionRedraw );
			end else if ( KP = '^' ) and ( Camp^.GB^.Scene <> Nil ) then begin
				SpitContents( Camp^.GB^.meks );

			end else if KP = '*' then begin
				BrowseDesignFile( Camp^.GB^.Meks , @PCActionRedraw );

			end else if KP = '@' then begin
				ShowRep( Mek );

			end else if KP = '~' then begin
				ShowSkillXP( Mek );

			end else if KP = '#' then begin
				DirectScript( Camp^.GB );

{$IFNDEF ASCII}
			end else if KP = '"' then begin
				GraphicsTest( Camp^.GB );
{$ENDIF}
			end else if xxran_debug and ( KP = '|' ) then begin
				GodMode( Camp^.GB , LocatePilot( Mek ) );
			end else if xxran_debug and ( KP = '`' ) then begin
				CheckMissionGivers( Camp^.GB );

			end; {if}

		end; {While}
	end; {IF}
end;

Function PCisMarooned( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
	{ Check the PC's available move modes, return TRUE if the PC is SOL. }
var
	P: Point;
	Terr,MM: Integer;
	IsMarooned: Boolean;
begin
	{ Assume TRUE unless shown otherwise. }
	IsMarooned := True;

	{ Determine the terrain of the tile the mek is standing in. The shifted movemode }
	{ must be legal there. }
	P := GearCurrentLocation( Mek );
	Terr := TileTerrain( GB , P.X , P.Y );

	{ Check all the movemodes in turn. }
	for MM := 1 to NumMoveMode do begin
		{ If the PC has this movemode, see if it can be used here. }
		if BaseMoveRate( GB^.Scene , Mek , MM ) > 0 then begin
			if not IsBlockingTerrainForMM( GB , Mek , Terr , MM ) then IsMarooned := False;
		end;
	end;

	PCisMarooned := IsMarooned;
end;

Procedure GetPlayerInput( Mek: GearPtr; Camp: CampaignPtr );
	{ Branch to either the MENU based input routine or the RL one. }
var
	IT: Integer;
	TL: LongInt;
begin
	PCACTIONRD_PC := Mek;
	PCACTIONRD_GB := Camp^.GB;

	{ Check the player for jumping. }
	TL := NAttValue( Mek^.NA , NAG_Action , NAS_TimeLimit );
	if ( TL > 0 ) then begin
		DialogMsg( BStr( Abs( TL - Camp^.GB^.ComTime ) ) + ' seconds jump time left.' );
	end;

	{ Check the player for valid movemode. This is needed }
	{ for jumping mecha. I think that the way jumping is }
	{ currently handled in the game is a bit messy- lots of }
	{ bits here and there trying to make it look right. }
	{ Someday I'll try to clean up action.pp and make everything }
	{ more elegant, but for right now as long as everything works }
	{ and is vaguely understandable I can't complain. }
	if not MoveLegal( Camp^.GB^.Scene , Mek , NAV_NormSpeed , Camp^.GB^.ComTime ) then begin
		GearUp( Mek );
	end;

	{ Check to see if the PC is marooned. If so, load a recovery scenario. }
	{ The PC only counts as marooned if outside of a mecha; if inside a mecha, }
	{ he'll have to eject. Recovery can also only take place in a safe scene. }
	if ( Mek^.G = GG_Character ) and IsSafeArea( Camp^.GB ) then begin
		{ See if the Mek can move in the terrain currently being stood upon. }
		if PCisMarooned( Camp^.GB , Mek ) then begin
			{ Looks like the PC is marooned. Load a rescue scenario. }
			StartRescueScenario( Camp^.GB , Mek , '*PICKUP' );
		end;
	end;

	{ Find out what kind of interface to use. }
	IT := InterfaceType( Camp^.GB , Mek );

	if IT = MenuBasedInput then begin
		MenuPlayerInput( Mek , Camp^.GB );
	end else begin
		RLPlayerInput( Mek , Camp );
	end;

	{ At the end of any action, do a search for metaterrain. }
	if GearActive( Mek ) then CheckHiddenMetaterrain( Camp^.GB , Mek );
end;



Procedure SetPartyWorldPos( GB: GameBoardPtr; X , Y: Integer );
	{ Set the position of the party on the world map. }
	{ All PC and Lancemate gears should have their location set to X,Y. }
var
	M: GearPtr;
	T: Integer;
begin
	M := GB^.Meks;
	while M <> Nil do begin
		T := NAttValue( M^.NA , NAG_Location , NAS_Team );
		if ( T = NAV_DefPlayerTeam ) or ( T = NAV_LancemateTeam ) then begin
			SetNAtt( M^.NA , NAG_Location , NAS_X , X );
			SetNAtt( M^.NA , NAG_Location , NAS_Y , Y );
		end;
		M := M^.Next;
	end;
end;

Function MoveOnWorld( GB: GameBoardPtr; Mek: GearPtr; var X,Y: Integer; D: Integer ): Integer;
	{ Attempt to move on the world map. This function returns the travel time, }
	{ or 0 if travel is impossible. }
	Function WorldMapMoveRate( Mek: GearPtr; MM: Integer ): Integer;
		{ Return a scaled rate for moving on the world map. }
	var
		it,T: Integer;
	begin
		it := BaseMoveRate( GB^.Scene , Mek , MM );
		if it > 0 then begin
			for t := 1 to Mek^.Scale do it := it * 2;
			it := GB^.Scale * 3600 div it;
			if it < 1 then it := 1;
		end else begin
			it := 0;
		end;
		WorldMapMoveRate := it;
	end;
var
	X2,Y2,TopSpeed,terr,T,spd: Integer;
begin
	{ Locate the new position. }
	X2 := X + AngDir[ D , 1 ];
	Y2 := Y + AngDir[ D , 2 ];
	FixWorldCoords( GB^.Scene , X2 , Y2 );

	{ If this new position is on the map, maybe the PC can move there. }
	if OnTheMap( GB , X2 , Y2 ) then begin
		terr := TileTerrain( GB , X2 , Y2 );
		if Mek <> Nil then begin
			{ Determine the top speed at which the PC can cross this terrain. }
			TopSpeed := 0;
			for t := 1 to NumMoveMode do begin
				if TerrMan[ terr ].MMPass[ T ] then begin
					spd := WorldMapMoveRate( Mek , T );
					if spd > TopSpeed then TopSpeed := spd;
				end;
			end;
			if TopSpeed > 0 then begin
				X := X2;
				Y := Y2;
				SetPartyWorldPos( GB , X , Y );
				MoveOnWorld := TopSpeed;
			end else begin
				MoveOnWorld := 0;
			end;
		end else begin
			{ No PC... Better set the Quit flag. }
			GB^.QuitTheGame := True;
			MoveOnWorld := 0;
		end;
	end else begin
		MoveOnWorld := 0;
	end;
end;

Function WorldMapMain( Camp: CampaignPtr ): Integer;
	{ Explore the world map. Maybe enter a location. }
var
	TravelTime,T: Integer;
	A: Char;
	PCX,PCY: Integer;	{ The party's location on the map. }
	PC: GearPtr;
	update_trigger: String;
begin
	{ Set the gameboard's pointer to the campaign. }
	Camp^.GB^.Camp := Camp;

	PC := GG_LocatePC( Camp^.GB );
	PCACTIONRD_PC := PC;
	PCACTIONRD_GB := Camp^.GB;
	if PC <> Nil then begin
		PCX := NAttValue( PC^.NA , NAG_Location , NAS_X );
		PCY := NAttValue( PC^.NA , NAG_Location , NAS_Y );
	end else begin
		PCX := Random( Camp^.GB^.Map_Width ) + 1;
		PCY := Random( Camp^.GB^.Map_Height ) + 1;
	end;

	SetPartyWorldPos( Camp^.GB , PCX , PCY );

	{ Set the STARTGAME trigger, and update all props. }
	SetTrigger( Camp^.GB , TRIGGER_StartGame );
	update_trigger := 'UPDATE';
	CheckTriggerAlongPath( update_trigger , Camp^.GB , Camp^.GB^.Meks , True );

	{ Start world map exploration loop here. }
	{ Basically, the PC will have the chance to move around. }
	while KeepPlayingSC( Camp^.GB ) do begin
		CombatDisplay( Camp^.GB );
		DoFlip;

		{ Player input loop. }
		TravelTime := 0;
		repeat
			A := RPGKey;

			if A = KeyMap[ KMC_North ].KCode then begin
				TravelTime := MoveOnWorld( Camp^.GB , PC , PCX , PCY , 6 );
			end else if A = KeyMap[ KMC_South ].KCode then begin
				TravelTime := MoveOnWorld( Camp^.GB , PC , PCX , PCY , 2 );
			end else if A = KeyMap[ KMC_West ].KCode then begin
				TravelTime := MoveOnWorld( Camp^.GB , PC , PCX , PCY , 4 );
			end else if A = KeyMap[ KMC_East ].KCode then begin
				TravelTime := MoveOnWorld( Camp^.GB , PC , PCX , PCY , 0 );
			end else if A = KeyMap[ KMC_QuitGame ].KCode then begin
                if DoAutoSave then PCSaveCampaign( Camp , PC , True );
				Camp^.GB^.QuitTheGame := True;

			end else if A = KeyMap[ KMC_Help ].KCode then begin
				PCRLHelp( Camp^.GB );
			end else if A = KeyMap[ KMC_Inventory ].KCode then begin
				PCBackpackMenu( Camp^.GB , PC , True );
			end else if A = KeyMap[ KMC_Equipment ].KCode then begin
				PCBackpackMenu( Camp^.GB , PC , False );

			end else if ( A = KeyMap[ KMC_Enter ].KCode ) or ( A = KeyMap[ KMC_Enter2 ].KCode ) then begin
				PCEnter( Camp^.GB , PC );

			end else if A = KeyMap[ KMC_PartBrowser ].KCode then begin
				MechaPartBrowser( PC , @PCActionRedraw );

			end else if A = KeyMap[ KMC_LearnSkills ].KCode then begin
				PCACTIONRD_GB := Camp^.GB;
				DoTraining( Camp^.GB , PC , @PCActionRedraw );

			end else if A = KeyMap[ KMC_SelectMecha ].KCode then begin
				DoSelectPCMek( Camp^.GB , PC );

			end else if A = KeyMap[ KMC_SaveGame ].KCode then begin
				PCSaveCampaign( Camp , PC , True );

			end else if A = KeyMap[ KMC_CharInfo ].KCode then begin
				PCViewChar( Camp^.GB , PC );

			end else if A = KeyMap[ KMC_ApplySkill ].KCode then begin
				PCActivateSkill( Camp^.GB , PC );

			end else if A = KeyMap[ KMC_History ].KCode then begin
				DisplayConsoleHistory( Camp^.GB );

			end else if A = KeyMap[ KMC_FieldHQ ].KCode then begin
				PCFieldHQ( Camp^.GB , PC );

			end else if A = KeyMap[ KMC_ViewMemo ].KCode then begin
				MemoBrowser( Camp^.GB , PC );

			end else if A = KeyMap[ KMC_UseProp ].KCode then begin
				PCUseProp( Camp^.GB , PC );

			end else if A = KeyMap[ KMC_Search ].KCode then begin
				PCSearch( Camp^.GB , PC );

			end else if A = '#' then begin
				DirectScript( Camp^.GB );

			end else if A = '$' then begin
                {$IFDEF ASCII}
		        MoreText( Skill_Roll_History , MoreHighFirstLine( Skill_Roll_History ) );
                {$ELSE}
                PCACTIONRD_GB := Camp^.GB;
		        MoreText( Skill_Roll_History , MoreHighFirstLine( Skill_Roll_History ) , @PCActionRedraw );
                {$ENDIF}

			end;

			CombatDisplay( Camp^.GB );
			DoFlip;
		until ( travelTime > 0 ) or not KeepPlayingSC( Camp^.GB );

		{ Advance the game clock. }
		for t := 1 to TravelTime do AdvanceGameClock( Camp^.GB , True , True );

		HandleTriggers( Camp^.GB );

	{end world map exploration loop.}
	end;

	{ Handle the last pending triggers. }
	SetTrigger( Camp^.GB , TRIGGER_EndGame );
	HandleTriggers( Camp^.GB );

	{ Return the outcome code. }
	WorldMapMain := ( Camp^.GB^.ReturnCode );
end;


end.
