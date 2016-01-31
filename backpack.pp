unit backpack;
	{ This unit handles both the inventory display and the }
	{ FieldHQ interface, which uses many of the same things. }
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

uses gears,locale,ghchars,
{$IFDEF ASCII}
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}

const
	TRIGGER_GetItem = 'GET';

	Skill_Use_Trigger: Array [1..NumSkill] of String = (
		'USE', 'USE', 'USE', 'USE', 'USE',
		'USE', 'USE', 'USE', 'USE', 'USE',
		'USE', 'CLUE_SURVIVAL', 'CLUE_REPAIR', 'CLUE_MEDICINE', 'USE',
		'USE', 'USE', 'USE', 'USE', 'USE',
		'CLUE_SCIENCE', 'USE', 'CLUE_CODEBREAKING', 'CLUE_MYSTICISM', 'USE',
		'USE', 'CLUE_INSIGHT', 'USE'
	);


Function DefaultAtOp( Weapon: GearPtr ): Integer;

Procedure GatherFieldHQ( GB: GameBoardPtr );
Procedure GivePartToPC( var LList: GearPtr; Part, PC: GearPtr );
Procedure GivePartToPC( GB: GameBoardPtr; Part, PC: GearPtr );

{$IFNDEF ASCII}
Procedure SelectColors( M: GearPtr; Redrawer: RedrawProcedureType );
Procedure SelectSprite( M: GearPtr; Redrawer: RedrawProcedureType );
{$ENDIF}

Function DoFieldRepair( GB: GameBoardPtr; PC , Item: GearPtr; Skill: Integer ): Boolean;

Function Handless( Mek: GearPtr ): Boolean;
Function CanBeExtracted( Item: GearPtr ): Boolean;
Procedure ExtractMechaPart( var LList,Item: GearPtr );

Function ShakeDown( GB: GameBoardPtr; Part: GearPtr; X,Y: Integer ): LongInt;
Procedure PCGetItem( GB: GameBoardPtr; PC: GearPtr );
Procedure PCTradeItems( GB: GameBoardPtr; PC,Target: GearPtr );
Procedure EatItem( GB: GameBoardPtr; TruePC , Item: GearPtr );

Procedure FHQ_SelectMechaForPilot( GB: GameBoardPtr; NPC: GearPtr );
Procedure ArenaHQBackpack( Source,BPPC: GearPtr; BasicRedraw: RedrawProcedureType );
Procedure LancemateBackpack( GB: GameBoardPtr; PC,NPC: GearPtr; BasicRedraw: RedrawProcedureType );
Procedure BackpackMenu( GB: GameBoardPtr; PC: GearPtr; StartWithInv: Boolean; BasicRedraw: RedrawProcedureType );
Procedure MechaPartEditor( GB: GameBoardPtr; var LList: GearPtr; PC,Mek: GearPtr; BasicRedraw: RedrawProcedureType  );

Procedure MechaPartBrowser( Mek: GearPtr; RDP: RedrawProcedureType );
Procedure MysteryPartBrowser( Mek: GearPtr; RDP: RedrawProcedureType );
Procedure BrowseDesignFile( List: GearPtr; RDP: RedrawProcedureType );

Procedure FHQ_ThisWargearWasSelected( GB: GameBoardPtr; var LList: GearPtr; PC,M: GearPtr; BasicRedrawer: RedrawProcedureType );

Procedure PCDoPerformance( GB: GameBoardPtr; PC: GearPtr );
Procedure StartPerforming( GB: GameBoardPtr; PC: GearPtr );

Procedure UsableGearMenu( GB: GameBoardPtr; PC: GearPtr );


implementation

uses ability,action,arenacfe,arenascript,gearutil,ghholder,
     ghmodule,ghprop,ghswag,interact,menugear,rpgdice,skilluse,texutil,
     description,ghweapon,ui4gh,narration,specialsys,ghsupport,
     ghintrinsic,effects,targetui,ghsensor,customization,
{$IFDEF ASCII}
	vidmap,vidmenus,vidinfo;
{$ELSE}
	colormenu,sdlmap,sdlmenus,sdlinfo;
{$ENDIF}

var
	ForceQuit: Boolean;
	EqpRPM,InvRPM: RPGMenuPtr;
	MenuA,MenuB: RPGMenuPtr;

	BP_Source: GearPtr;	{ Gear to appear in the INFO menu. }
	BP_SeekSibs: Boolean;	{ TRUE if the menu lists sibling gears; FALSE if it lists child gears. }
	BP_ActiveMenu: RPGMenuPtr;	{ The active menu. Used to determine the gear to show info about. }
	BP_GB: GameBoardPtr;
	BP_Redraw: RedrawProcedureType;
	MPB_Redraw: RedrawProcedureType;	{ Mecha Part Browser redraw procedure. }
						{ Since the mecha part browser may be called }
						{ from the main menu, the mecha editor, or }
						{ a dozen other places it needs to specify }
						{ a redrawer. }

Function DefaultAtOp( Weapon: GearPtr ): Integer;
	{ Return the default Attack Options value for the weapon selected. }
var
	atop,PVal: Integer;
	Ammo: GearPtr;
begin
	AtOp := 0;
	PVal := WeaponBVSetting( Weapon );

	if ( Weapon^.G = GG_Weapon ) then begin
		if ( ( Weapon^.S = GS_Ballistic ) or ( Weapon^.S = GS_BeamGun ) ) and ( Weapon^.Stat[ STAT_BurstValue ] > 0 ) then begin
			if PVal = BV_Max then begin
				AtOp := Weapon^.Stat[ STAT_BurstValue ];
			end else if PVal = BV_Half then begin
				AtOp := Weapon^.Stat[ STAT_BurstValue ] div 2;
				if AtOp < 1 then AtOp := 1;
			end else if PVal = BV_Quarter then begin
				AtOp := Weapon^.Stat[ STAT_BurstValue ] div 4;
				if AtOp < 1 then AtOp := 1;
			end;
		end else if Weapon^.S = GS_Missile then begin
			Ammo := LocateGoodAmmo( Weapon );
			if Ammo = Nil then begin
				AtOp := 0;
			end else if PVal = BV_Max then begin
				AtOp := Ammo^.Stat[ STAT_AmmoPresent ] - 1;
				if AtOp < 0 then AtOp := 0;
			end else if PVal = BV_Half then begin
				AtOp := ( Ammo^.Stat[ STAT_AmmoPresent ] div 2 ) - 1;
				if AtOp < 0 then AtOp := 0;
			end else if PVal = BV_Quarter then begin
				AtOp := ( Ammo^.Stat[ STAT_AmmoPresent ] div 4 ) - 1;
				if AtOp < 0 then AtOp := 0;
			end;

		end;
	end;
	DefaultAtOp := atop;
end;


Procedure PlainRedraw;
	{ Miscellaneous menu redraw procedure. }
begin
	if BP_GB <> Nil then CombatDisplay( BP_GB );
end;

Procedure MiscProcRedraw;
	{ Miscellaneous menu redraw procedure. The Eqp display will be shown; }
	{ the INV display won't be. }
var
	N: Integer;
	Part: GearPtr;
begin
	BP_Redraw;
	DrawBPBorder;
	GameMsg( MsgString( 'BACKPACK_Directions' ) , ZONE_BackpackInstructions , InfoHilight );
	if ( BP_ActiveMenu <> Nil ) and ( BP_Source <> Nil ) then begin
		N := CurrentMenuItemValue( BP_ActiveMenu );
		if N > 0 then begin
			if BP_SeekSibs then Part := RetrieveGearSib( BP_Source , N )
			else Part := LocateGearByNumber( BP_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( BP_GB , Part , ZONE_ItemsInfo );
			end;
		end;
	end;
	if EqpRPM <> Nil then begin
		DisplayMenu( EqpRPM , Nil );
	end;
end;

Procedure InstallRedraw;
	{ Redrawer for installing a part into a mecha. }
begin
	BP_Redraw;
	DrawBPBorder;
	BrowserInterfaceInfo( BP_GB , BP_Source , ZONE_ItemsInfo );
	if EqpRPM <> Nil then begin
		DisplayMenu( EqpRPM , Nil );
	end;
end;

Procedure EqpRedraw;
	{ Show Inventory, select Equipment. }
var
	N: Integer;
	Part: GearPtr;
begin
	BP_Redraw;
	DrawBPBorder;
	DisplayMenu( InvRPM , Nil );
	GameMsg( MsgString( 'BACKPACK_Directions' ) , ZONE_BackpackInstructions , InfoHilight );
	if ( BP_ActiveMenu <> Nil ) and ( BP_Source <> Nil ) then begin
		N := CurrentMenuItemValue( BP_ActiveMenu );
		if N > 0 then begin
			if BP_SeekSibs then Part := RetrieveGearSib( BP_Source , N )
			else Part := LocateGearByNumber( BP_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( BP_GB , Part , ZONE_ItemsInfo );
			end;
		end;
	end;
end;

Procedure ThisItemRedraw;
	{ A specific item was selected, and its location stored in BP_Source. }
begin
	BP_Redraw;
	DrawBPBorder;
	GameMsg( MsgString( 'BACKPACK_Directions' ) , ZONE_BackpackInstructions , InfoHilight );
	if BP_Source <> Nil then BrowserInterfaceInfo( BP_GB , BP_Source , ZONE_ItemsInfo );

	if EqpRPM <> Nil then begin
		DisplayMenu( EqpRPM , Nil );
	end;
end;

Procedure GetItemRedraw;
begin
	CombatDisplay( BP_GB );
	DrawGetItemBorder;
end;


Procedure ThisWargearRedraw;
	{ A specific item was selected, and its location stored in BP_Source. }
begin
	BP_Redraw;
	SetupFHQDisplay;
	if BP_Source <> Nil then BrowserInterfaceInfo( BP_GB , BP_Source , ZONE_ItemsInfo );
end;

Procedure MechaPartEditorRedraw;
	{ Show Inventory, select Equipment. }
var
	Part: GearPtr;
begin
	BP_Redraw;
	SetupFHQDisplay;
	if ( BP_ActiveMenu <> Nil ) and ( BP_Source <> Nil ) then begin
		if BP_SeekSibs then Part := RetrieveGearSib( BP_Source , CurrentMenuItemValue( BP_ActiveMenu ) )
		else Part := LocateGearByNumber( BP_Source , CurrentMenuItemValue( BP_ActiveMenu ) );
		if Part <> Nil then begin
			BrowserInterfaceInfo( BP_GB , Part , ZONE_ItemsInfo );
		end;
	end;
end;

Procedure PartBrowserRedraw;
	{ Redraw the screen for the part browser. }
var
	Part: GearPtr;
begin
	if MPB_Redraw <> Nil then MPB_Redraw;
	SetupFHQDisplay;
	if ( BP_ActiveMenu <> Nil ) and ( BP_Source <> Nil ) then begin
		if BP_SeekSibs then Part := RetrieveGearSib( BP_Source , CurrentMenuItemValue( BP_ActiveMenu ) )
		else Part := LocateGearByNumber( BP_Source , CurrentMenuItemValue( BP_ActiveMenu ) );
		if Part <> Nil then begin
			BrowserInterfaceInfo( BP_GB , Part , ZONE_ItemsInfo );
		end;
	end;
end;

Procedure MysteryBrowserRedraw;
	{ Redraw the screen for the mystery display. }
	{ This is the screen that shows no real information when the PC doesn't have }
	{ the correct software to view a target. }
begin
	if MPB_Redraw <> Nil then MPB_Redraw;
	SetupFHQDisplay;
	if ( BP_Source <> Nil ) then begin
		BrowserInterfaceMystery( BP_Source , ZONE_ItemsInfo );
	end;
end;

Procedure TradeItemsRedraw;
	{ Trade Items menu redraw procedure. The MenuA and MenuB will both be shown. }
var
	N: Integer;
	Part: GearPtr;
begin
	CombatDisplay( BP_GB );
	DrawBPBorder;
	GameMsg( MsgString( 'BACKPACK_Directions' ) , ZONE_BackpackInstructions , InfoHilight );
	DisplayMenu( MenuA , Nil );
	DisplayMenu( MenuB , Nil );

	if ( BP_ActiveMenu <> Nil ) and ( BP_Source <> Nil ) then begin
		N := CurrentMenuItemValue( BP_ActiveMenu );
		if N > 0 then begin
			Part := RetrieveGearSib( BP_Source^.InvCom , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( BP_GB , Part , ZONE_ItemsInfo );
			end;
		end;
	end;
end;


Procedure GatherFieldHQ( GB: GameBoardPtr );
	{ The PC wants to open his FieldHQ. Look through the current city and gather }
	{ up everything belonging to the PC team. Deposit these gears on the gameboard. }
	Procedure GatherFromScene( S: GearPtr );
		{ Gather any gears belonging to the PC from this scene. }
		{ Move them to the gameboard. }
	var
		M,M2: GearPtr;
	begin
		M := S^.InvCom;
		while M <> Nil do begin
			M2 := M^.Next;

			if ( M^.G >= 0 ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then begin
				DelinkGear( S^.InvCom , M );
				DeployGear( GB , M , False );
			end;

			M := M2;
		end;
	end;
	Procedure SearchAlongPath( SList: GearPtr );
		{ Search along this path for scenes. }
	begin
		while SList <> Nil do begin
			if SList^.G = GG_Scene then begin
				GatherFromScene( SList );
				SearchAlongPath( SList^.SubCom );
			end;
			SList := SList^.Next;
		end;
	end;
var
	City: GearPtr;
begin
	City := FindRootScene( GB^.Scene );
	if City <> Nil then begin
		GatherFromScene( City );
		SearchAlongPath( City^.SubCom );
	end;
end;

Procedure GivePartToPC( var LList: GearPtr; Part, PC: GearPtr );
	{ Give the specified part to the PC. If the part cannot be }
	{ held by the PC, store it so that it can be recovered using }
	{ the FieldHQ Wargear Explorer. }
	{ The part should be delinked already. }
var
	P2,Pilot: GearPtr;
begin
	if PC^.G = GG_Mecha then Pilot := LocatePilot( PC )
	else Pilot := Nil;
	if ( Part^.G = GG_Set ) then begin
		while Part^.SubCom <> Nil do begin
			P2 := Part^.SubCom;
			DelinkGear( Part^.SubCom , P2 );
			GivePartToPC( LList , P2 , PC );
		end;
		while Part^.InvCom <> Nil do begin
			P2 := Part^.InvCom;
			DelinkGear( Part^.InvCom , P2 );
			GivePartToPC( LList , P2 , PC );
		end;
	end else if ( Pilot <> Nil ) and IsLegalInvCom( Pilot , Part ) then begin
		StripNAtt( Part , NAG_Location );
		StripNAtt( Part , NAG_EpisodeData );
		InsertInvCom( Pilot , Part );
	end else if ( PC <> Nil ) and IsLegalInvCom( PC , Part ) then begin
		StripNAtt( Part , NAG_Location );
		StripNAtt( Part , NAG_EpisodeData );
		InsertInvCom( PC , Part );
	end else begin
		{ If the PC can't carry this equipment, }
		{ stick it off the map. }
		SetNAtt( Part^.NA , NAG_Location , NAS_Team , 1 );
		SetNAtt( Part^.NA , NAG_Location , NAS_X , 0 );
		SetNAtt( Part^.NA , NAG_Location , NAS_Y , 0 );
		AppendGear( LList , Part );
	end;
end;

Procedure GivePartToPC( GB: GameBoardPtr; Part, PC: GearPtr );
	{ Call the above procedure, with GB^.Meks as the LList. }
begin
	GivePartToPC( GB^.Meks , Part , PC );
end;

{$IFNDEF ASCII}
Procedure SelectColors( M: GearPtr; Redrawer: RedrawProcedureType );
	{ The player wants to change the colors for this part. Make it so. }
	{ The menu will be placed in the Menu area; assume the redrawer will }
	{ show whatever changes are made here. }
var
	portraitname,oldcolor,newcolor: String;
begin
	portraitname := InfoImageName( M );
	oldcolor := SAttValue( M^.SA , 'SDL_Colors' );

	if M^.G = GG_Character then begin
		newcolor := SelectColorPalette( colormenu_mode_character , portraitname , oldcolor , 100 , 150 , Redrawer );
	end else if M^.G = GG_Mecha then begin
		newcolor := SelectColorPalette( colormenu_mode_mecha , portraitname , oldcolor , 100 , 150 , Redrawer );
	end else begin
		newcolor := SelectColorPalette( colormenu_mode_allcolors , portraitname , oldcolor , 100 , 150 , Redrawer );
	end;

	SetSAtt( M^.SA , 'SDL_Colors <' + newcolor + '>' );
end;

Procedure SelectSprite( M: GearPtr; Redrawer: RedrawProcedureType );
	{ The player wants to change the colors for sprite for this character. }
	{ The menu will be placed in the Menu area; assume the redrawer will }
	{ show whatever changes are made here. }
var
	RPM: RPGMenuPtr;
	fname: String;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	if NAttValue( M^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Female then begin
		BuildFileMenu( RPM , Graphics_Directory + 'cha_f_*.*' );
	end else begin
		BuildFileMenu( RPM , Graphics_Directory + 'cha_m_*.*' );
	end;
	AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

	fname := SelectFile( RPM , Redrawer );

	if fname <> '' then begin
		SetSAtt( M^.SA , 'SDL_SPRITE <' + fname + '>' );
	end;

	DisposeRPGMenu( RPM );
end;
{$ENDIF}

Procedure AddRepairOptions( RPM: RPGMenuPtr; PC,Item: GearPtr );
	{ Check the object in question, then add options to the }
	{ provided menu if the item is in need of repairs which the }
	{ PC can provide. Repair items will be numbered 100 + RSN }
var
	N: Integer;
begin
	PC := LocatePilot( PC );
	if PC <> Nil then begin
		for N := 1 to NumSkill do begin
			{ The repair option will only be added to the menu if: }
			{ - The PC has the required skill. }
			{ - The item is in need of repair (using this skill). }
			if ( SkillMan[N].Usage = USAGE_Repair ) and ( NAttValue( PC^.NA , NAG_Skill , N ) > 0 ) and ( RepairNeededBySkill( Item , N ) > 0 ) then begin
				AddRPGMenuItem( RPM , MsgString( 'BACKPACK_Repair' ) + MSgString( 'SKILLNAME_' + BStr( N ) ) , 100 + N );
			end;
		end;
	end;
end;

Function DoFieldRepair( GB: GameBoardPtr; PC , Item: GearPtr; Skill: Integer ): Boolean;
	{ The PC is going to use one of the repair skills. Call the }
	{ standard procedure, then print output. }
	{ Return TRUE if repair fuel found, or FALSE otherwise. }
var
	msg: String;
	Dmg0,DDmg,T: LongInt;
	SFX_Check: Array [1..Num_Status_FX] of Boolean;
	RepairFuelFound,NoStatusCured: Boolean;
begin
	{ Record the initial state of the repair target. }
	Dmg0 := AmountOfDamage( Item , True );
	for t := 1 to Num_Status_FX do SFX_Check[ t ] := HasStatus( Item , T );

	RepairFuelFound := UseRepairSkill( GB , PC , Item , Skill );
	if NAttValue( PC^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
		msg := ReplaceHash( MsgString( 'PCREPAIR_UseSkill' ) , MsgString( 'SkillName_' + BStr( Skill ) ) );
	end else begin
		msg := ReplaceHash( MsgString( 'NPCREPAIR_UseSkill' ) , PilotName( PC ) );
		msg := ReplaceHash( msg , MsgString( 'SkillName_' + BStr( Skill ) ) );
	end;
	msg := ReplaceHash( msg , GearName( Item ) );

	{ Report the final state of the repair target. }
	DDmg := Dmg0 - AmountOfDamage( Item , True );

	{ Inform the user of the success. }
	if ( Item^.G = GG_Character ) and Destroyed( Item ) then begin
		msg := msg + ' ' + ReplaceHash( MsgString( 'PCREPAIR_DEAD' ) , GearName( Item ) );
	end else if not RepairFuelFound then begin
		msg := msg + ' ' + MsgString( 'PCREPAIR_NoRepairFuel' );
	end else if DDmg > 0 then begin
		msg := msg + ' ' + ReplaceHash( MsgString( 'PCREPAIR_Success' ) , BStr( DDmg ) );
	end;

	{ Assume TRUE unless proven FALSE. }
	NoStatusCured := True;
	for t := 1 to Num_Status_FX do begin
		if SFX_Check[ t ] and not HasStatus( Item , T ) then begin
			{ This status effect was cured. Add it to the list. }
			NoStatusCured := FALSE;
		end;
	end;

	{ If no damage was healed and no status was cured, this was a big waste of time. }
	if ( DDMg = 0 ) and NoStatusCured then msg := msg + ' ' + MsgString( 'PCREPAIR_Failure' )
	else if NotDestroyed( Item ) and not NoStatusCured then msg := msg + ' ' + ReplaceHash( MsgString( 'STATUS_Remove' ) , GearName( Item ) );

	DialogMsg( msg );

	DoFieldRepair := RepairFuelFound;
end;

Function ShakeDown( GB: GameBoardPtr; Part: GearPtr; X,Y: Integer ): LongInt;
	{ This is the workhorse for this function. It does the }
	{ dirty work of separating inventory from (former) owner. }
var
	cash: LongInt;
	SPart: GearPtr;		{ Sub-Part }
begin
	{ Start by removing the cash from this part. }
	cash := NAttValue( Part^.NA , NAG_Experience , NAS_Credits );
	SetNAtt( Part^.NA , NAG_Experience , NAS_Credits , 0 );
	SetNAtt( Part^.NA , NAG_EpisodeData , NAS_Ransacked , 1 );

	{ Remove all InvComs, and place them on the map. }
	While Part^.InvCom <> Nil do begin
		SPart := Part^.InvCom;
		DelinkGear( Part^.InvCom , SPart );
		{ If this invcom isn't destroyed, put it on the }
		{ ground for the PC to pick up. Otherwise delete it. }
		if NotDestroyed( SPart ) then begin
			SetNAtt( SPart^.NA , NAG_Location , NAS_X , X );
			SetNAtt( SPart^.NA , NAG_Location , NAS_Y , Y );
			SPart^.Next := GB^.Meks;
			GB^.Meks := SPart;
		end else begin
			DisposeGear( SPart );
		end;
	end;

	{ Shake down this gear's subcoms. }
	SPart := Part^.SubCOm;
	while SPart <> Nil do begin
		if SPart^.G <> GG_Cockpit then cash := cash + ShakeDown( GB , SPart , X , Y );
		SPart := SPart^.Next;
	end;

	ShakeDown := Cash;
end;


Function Ransack( GB: GameBoardPtr; X,Y: Integer ): LongInt;
	{ Yay! Loot and pillage! This function has two purposes: }
	{ first, it separates all Inventory gears from any non-operational }
	{ masters standing in this tile. Secondly, it collects the }
	{ money from all those non-operational masters and returns the }
	{ total amount as the function result. }
var
	it: LongInt;
	Mek: GearPtr;
begin
	it := 0;

	Mek := GB^.Meks;

	while Mek <> Nil do begin
		{ If this is a broken-down master, check to see if it's }
		{ one we want to pillage. }
		if IsMasterGear( Mek ) and not GearOperational( Mek ) then begin
			{ We will ransack this gear if it's in the correct location. }
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_X ) = X ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Y ) = Y ) then begin
				it := it + ShakeDown( GB , Mek , X , Y );
			end;
		end else if ( Mek^.G = GG_MetaTerrain ) and ( ( Mek^.Stat[ STAT_Lock ] = 0 ) or Destroyed( Mek ) ) then begin
			{ Metaterrain gets ransacked if it's unlocked, }
			{ or wrecked. }
			if ( NAttValue( Mek^.NA , NAG_Location , NAS_X ) = X ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Y ) = Y ) then begin
				it := it + ShakeDown( GB , Mek , X , Y );
			end;
		end;
		Mek := Mek^.Next;
	end;

	Ransack := it;
end;

Function Handless( Mek: GearPtr ): Boolean;
	{ Return TRUE if Mek either has no hands or can't use its hands }
	{ at the moment (say, because it's transformed into tank mode). }
	{ Return TRUE if Mek has hands and they are in perfect working order. }
var
	Hand: GearPtr;
begin
	Hand := SeekActiveIntrinsic( Mek , GG_Holder , GS_Hand );
	if Hand = Nil then Handless := True
	else Handless := not InGoodModule( Hand );
end;

Function SelectVisibleItem( GB: GameBoardPtr; PC: GearPtr; X,Y: Integer ): GearPtr;
	{ Attempt to select a visible item from gameboard tile X,Y. }
	{ If more than one item is present, prompt the user for which one }
	{ to pick up. }
var
	N,T: Integer;
	RPM: RPGMenuPtr;
begin
	{ First count the number of items in this spot. }
	N := NumVisibleItemsAtSpot( GB , X , Y );

	{ If it's just 0 or 1, then our job is simple... }
	if N = 0 then begin
		SelectVisibleItem := Nil;
	end else if N = 1 then begin
		SelectVisibleItem := FindVisibleItemAtSpot( GB , X , Y );

	{ If it's more than one, better create a menu and let the user }
	{ pick one. }
	end else if N > 1 then begin
		DialogMsg( MsgString( 'GET_WHICH_ITEM?' ) );
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_GetItemMenu );
		for t := 1 to N do begin
			AddRPGMenuItem( RPM , GearName( GetVisibleItemAtSpot( GB , X , Y , T ) ) , T );
		end;

		BP_GB := GB;
		N := SelectMenu( RPM , @GetItemRedraw );

		DisposeRPGMenu( RPM );
		if N > -1 then begin
			SelectVisibleItem := GetVisibleItemAtSpot( GB , X , Y , N );
		end else begin
			SelectVisibleItem := Nil;
		end;
	end;
end;

Procedure PCGetItem( GB: GameBoardPtr; PC: GearPtr );
	{ The PC will attempt to pick up something lying on the ground. }
var
	Cash,NID: LongInt;
	P: Point;
	item: GearPtr;
	IsHandless: Boolean;
begin
	IsHandless := Handless( PC );
	if IsHandless and not IsSafeArea( GB ) then begin
		{ Start by checking something that other RPGs would }
		{ just assume- does the PC have any hands? }
		DialogMsg( MsgString( 'HANDLESS_PICKUP' ) );

	end else begin
		P := GearCurrentLocation( PC );

		{ Before attempting to get an item, ransack whatever }
		{ fallen enemies lie in this spot. }
		Cash := Ransack( GB , P.X , P.Y );

		{ Perform an immediate vision check- without it, items }
		{ freed by the Ransack procedure above will remain unseen. }
		VisionCheck( GB , PC );

		Item := SelectVisibleItem( GB , PC , P.X , P.Y );

		if Item <> Nil then begin
			if IsLegalInvCom( PC , Item ) then begin
				DelinkGear( GB^.Meks , Item );

				{ Clear the item's location values. }
				StripNAtt( Item , NAG_Location );

				InsertInvCom( PC , Item );
				{ Clear the home, to prevent wandering items. }
				SetSAtt( Item^.SA , 'HOME <>' );

				if ( PC^.G = GG_Mecha ) and IsHandless then begin
					DialogMsg( ReplaceHash( MsgString( 'YOU_STRAP_?' ) , GearName( Item ) ) );
				end else begin
					DialogMsg( ReplaceHash( MsgString( 'YOU_GET_?' ) , GearName( Item ) ) );
				end;

				NID := NAttValue( Item^.NA , NAG_Narrative , NAS_NID );
				if NID <> 0 then SetTrigger( GB , TRIGGER_GetItem + BStr( NID ) );
			end else if Cash = 0 then begin
				DialogMsg( ReplaceHash( MsgString( 'CANT_GET_?' ) , GearName( Item ) ) );
			end;
		end else if Cash = 0 then begin
			DialogMSG( 'No item found.' );
		end;

		if Cash > 0 then begin
			DialogMsg( ReplaceHash( MsgString( 'YouFind$' ) , BStr( Cash ) ) );
			AddNAtt( LocatePilot( PC )^.NA , NAG_Experience , NAS_Credits , Cash );
		end;

		{ Picking up an item takes time. }
		{ More time if you're doing it without hands. }
		if IsHandless then begin
			WaitAMinute( GB , PC , ReactionTime( PC ) * 3 );
		end else begin
			WaitAMinute( GB , PC , ReactionTime( PC ) );
		end;
	end;
end;

Procedure PCTradeItems( GB: GameBoardPtr; PC,Target: GearPtr );
	{ The PC will attempt to trade items with TARGET. }
	Procedure SetupMenu( RPM: RPGMenuPtr; M: GearPtr );
		{ The setup procedure for both menus is the same, so here }
		{ it is. }
	begin
		BuildSiblingMenu( RPM , M^.InvCom );
		RPMSortAlpha( RPM );

		{ If the menu is empty, add a message saying so. }
		If RPM^.NumItem < 1 then AddRPGMenuItem( RPM , '[no inventory items]' , -1 )
		else AlphaKeyMenu( RPM );

		{ Add the menu keys. }
		AddRPGMenuKey(RPM,'/',-2);
	end;
	Procedure TransferItem( Source , Item , Destination: GearPtr );
		{ If possible, move ITEM from SOURCE to DESTINATION. }
	var
		NID: LongInt;
	begin
		if IsLegalInvCom( Destination , Item ) then begin
			{ Clear the item's location values. }
			StripNAtt( Item , NAG_Location );

			DelinkGear( Source^.InvCom , Item );
			InsertInvCom( Destination , Item );

			{ Clear the home, to prevent wandering items. }
			SetSAtt( Item^.SA , 'HOME <>' );
			if Destination = PC then begin
				DialogMsg( ReplaceHash( MsgString( 'YOU_GET_?' ) , GearName( Item ) ) );
			end else begin
				DialogMsg( ReplaceHash( MsgString( 'YOU_PUT_?' ) , GearName( Item ) ) );
			end;

			NID := NAttValue( Item^.NA , NAG_Narrative , NAS_NID );
			if NID <> 0 then SetTrigger( GB , TRIGGER_GetItem + BStr( NID ) );

			if GB <> Nil then WaitAMinute( GB , PC , ReactionTime( PC ) );

		end else begin
			DialogMsg( ReplaceHash( MsgString( 'CANT_GET_?' ) , GearName( Item ) ) );
		end;
	end;
var
	item: GearPtr;
	PCMenu,TarMenu: RPGMenuPtr;
	EscMenu,UseTarInv: Boolean;
	N: Integer;
begin
	{ Error check. }
	{ PC and Target must be non-nil; they must also be separate entities, or else }
	{ weird things will result. }
	if ( PC = Nil ) or ( Target = Nil ) or ( FindRoot( PC ) = FindRoot( Target ) ) then Exit;

	{ Initialize variables. }
	BP_GB := GB;
	UseTarInv := True;

	{ Keep going back and forth between the PC and the target until }
	{ the player hits ESCape. }
	EscMenu := False;
	repeat
		{ Create the two menus. }
		PCMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_EqpMenu );
		MenuA := PCMenu;
		SetupMenu( PCMenu , PC );

		TarMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
		MenuB := TarMenu;
		SetupMenu( TarMenu , Target );

		{ Determine which of the two menus is going to be our active one, }
		{ based on the UseTarInv variable. }
		if UseTarInv then begin
			BP_ActiveMenu := TarMenu;
			BP_Source := Target;
		end else begin
			BP_ActiveMenu := PCMenu;
			BP_Source := PC;
		end;

		N := SelectMenu( BP_ActiveMenu , @TradeItemsRedraw );

		if N > 0 then begin
			{ An item has been selected. Find it, then attempt to swap from }
			{ target to PC or vice versa. }
			if UseTarInv then begin
				Item := RetrieveGearSib( Target^.InvCom , N );
				TransferItem( Target , Item , PC );
			end else begin
				Item := RetrieveGearSib( PC^.InvCom , N );
				TransferItem( PC , Item , Target );
			end;

		end else if N = -1 then begin
			{ An Escape has been recieved. Quit this procedure. }
			EscMenu := True;
		end else if N = -2 then begin
			{ A menu swap has been requested. Change the active menu. }
			UseTarInv := Not UseTarInv;
		end;

		{ Dispose the two menus. }
		DisposeRPGMenu( PCMenu );
		DisposeRPGMenu( TarMenu );
	until EscMenu;
end;

Procedure CreateInvMenu( PC: GearPtr );
	{ Allocate the Inventory menu and fill it up with the PC's inventory. }
begin
	if InvRPM <> Nil then DisposeRPGMenu( InvRPM );
	InvRPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	InvRPM^.Mode := RPMNoCleanup;
	BuildInventoryMenu( InvRPM , PC , False );
	RPMSortAlpha( InvRPM );

	{ If the menu is empty, add a message saying so. }
	If InvRPM^.NumItem < 1 then AddRPGMenuItem( InvRPM , '[no inventory items]' , -1 )
	else AlphaKeyMenu( InvRPM );

	{ Add the menu keys. }
	AddRPGMenuKey(InvRPM,'/',-2);
end;

Procedure CreateEqpMenu( PC: GearPtr );
	{ Allocate the equipment menu and fill it up with the PC's gear. }
begin
	if EqpRPM <> Nil then DisposeRPGMenu( EqpRPM );
	EqpRPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_EqpMenu );
	EqpRPM^.Mode := RPMNoCleanup;
	BuildEquipmentMenu( EqpRPM , PC );

	{ If the menu is empty, add a message saying so. }
	If EqpRPM^.NumItem < 1 then AddRPGMenuItem( EqpRPM , '[no equipped items]' , -1 );

	{ Add the menu keys. }
	AddRPGMenuKey(EqpRPM,'/',-2);
end;

Procedure UpdateBackpack( PC: GearPtr );
	{ Redo all the menus, and display them on the screen. }
begin
	CreateInvMenu( PC );
	CreateEqpMenu( PC );
end;

Procedure UnequipItem( GB: GameBoardPtr; var LList: GearPtr; PC , Item: GearPtr );
	{ Delink ITEM from its parent, and stick it in the general inventory. }
begin
	{ First, delink Item from its parent. }
	DelinkGear( Item^.Parent^.InvCom , Item );
	{ HOW'D YA LIKE THEM CARROT DOTS, EH!?!? }

	{ Next, link ITEM into the general inventory, if possible. }
	GivePartToPC( LList , Item , PC );

	{ Unequipping takes time. }
	if GB <> Nil then WaitAMinute( GB , PC , ReactionTime( PC ) );
end;

Procedure UnequipFrontend( GB: GameBoardPtr; var LList: GearPtr; PC , Item: GearPtr );
	{ Simply unequip the provided item. }
	{ PRECOND: PC and ITEM had better be correct, dagnabbit... }
begin
	DialogMsg( ReplaceHash( MsgString( 'BACKPACK_Do_Unequip' ) , GearName( Item ) ) );
	UnequipItem( GB , LList , PC , Item );
end;

Procedure EjectAmmo( GB: GameBoardPtr; var LList: GearPtr; PC , Item: GearPtr );
	{ Remove all ammo from this item. }
	Procedure RemoveThisAmmo( Ammo: GearPtr );
		{ Remove ammo from wherever it is, then give it to the PC. }
		{ Ammo must be a subcom!!! }
	begin
		{ First, delink Ammo from its parent. }
		DelinkGear( Ammo^.Parent^.SubCom , Ammo );

		{ Next, link Ammo into the general inventory, if possible. }
		GivePartToPC( LList , Ammo , PC );

		DialogMsg( ReplaceHash( MsgString( 'BACKPACK_Do_EjectAmmo' ) , GearName( Ammo ) ) );
	end;
	Procedure CheckForAmmoToEject( IList: GearPtr );
		{ Check this list for ammo to eject, and also all subcoms. }
	var
		I2: GearPtr;
	begin
		while IList <> Nil do begin
			I2 := IList^.Next;

			if IList^.G = GG_Ammo then begin
				RemoveThisAmmo( IList );
			end else begin
				CheckForAmmoToEject( IList^.SubCom );
			end;

			IList := I2;
		end;
	end;
begin
	{ Start the search going. }
	CheckForAmmoToEject( Item^.SubCom );

	{ Unequipping takes time. }
	if GB <> Nil then WaitAMinute( GB , PC , ReactionTime( PC ) );
end;

Procedure EjectSoftware( GB: GameBoardPtr; var LList: GearPtr; PC , Item: GearPtr );
	{ Remove all software from this item. }
	Procedure RemoveThisSoftware( Soft: GearPtr );
		{ Remove Soft from wherever it is, then give it to the PC. }
		{ Soft must be a subcom!!! }
	begin
		{ First, delink Soft from its parent. }
		DelinkGear( Soft^.Parent^.SubCom , Soft );

		{ Next, link Ammo into the general inventory, if possible. }
		GivePartToPC( LList , Soft , PC );

		DialogMsg( ReplaceHash( MsgString( 'BACKPACK_Do_EjectSoftware' ) , GearName( Soft ) ) );
	end;
	Procedure CheckForSoftwareToEject( IList: GearPtr );
		{ Check this list for software to eject, and also all subcoms. }
	var
		I2: GearPtr;
	begin
		while IList <> Nil do begin
			I2 := IList^.Next;

			if IList^.G = GG_Software then begin
				RemoveThisSoftware( IList );
			end else begin
				CheckForSoftwareToEject( IList^.SubCom );
			end;

			IList := I2;
		end;
	end;
begin
	{ Start the search going. }
	CheckForSoftwareToEject( Item^.SubCom );

	{ Unequipping takes time. }
	if GB <> Nil then WaitAMinute( GB , PC , ReactionTime( PC ) );
end;


Function CanBeExtracted( Item: GearPtr ): Boolean;
	{ Return TRUE if the listed part can be extracted from a mecha, }
	{ or FALSE if it cannot normally be extracted. }
begin
	if ( Item^.G = GG_Support ) or ( Item^.G = GG_Cockpit ) or IsMasterGear( Item ) or ( Item^.Parent = Nil ) or ( Item^.Parent^.Scale = 0 ) or ( Item^.G = GG_Modifier ) then begin
		CanBeExtracted := False;
	end else if ( Item^.G = GG_Module ) and ( Item^.S = GS_Body ) then begin
		CanBeExtracted := False;
	end else if Item^.G = GG_SOftware then begin
		{ Software can't be extracted; it must be uninstalled. }
		CanBeExtracted := False;
	end else if SeekGear( Item , GG_Cockpit , 0 , False ) <> Nil then begin
		{ If the item contains the cockpit, it can't be extracted. }
		CanBeExtracted := False;
	end else begin
		CanBeExtracted := Not PartHasIntrinsic( Item , NAS_Integral );
	end;
end;

Function CanBeInstalled( Item: GearPtr ): Boolean;
	{ Return TRUE if the listed part can maybe be installed in a mecha }
	{ with the Mecha Engineering skill, or FALSE if it definitely can't. }
begin
	if ( Item = Nil ) or ( Item^.G = GG_Ammo ) or ( Item^.G = GG_Shield ) or ( Item^.G = GG_ExArmor ) or ( Item^.G = GG_Tool ) or ( Item^.G = GG_RepairFuel ) or ( Item^.G = GG_Consumable )
	or ( Item^.G = GG_WeaponAddOn ) or ( Item^.G = GG_Software ) then begin
		CanBeInstalled := False;
	end else begin
		CanBeInstalled := True;
	end;
end;

Procedure ExtractMechaPart( var LList,Item: GearPtr );
	{ Remove this part from the mecha. }
begin
	DelinkGear( LList , Item );

	{ If this is a variable form module, assume the primary form. }
	if ( Item^.G = GG_Module ) and ( Item^.Stat[ STAT_VariableModuleForm ] <> 0 ) then begin
		Item^.S := Item^.Stat[ STAT_PrimaryModuleForm ];
	end;
end;

Function ExtractItem( GB: GameBoardPtr; TruePC , PC: GearPtr; var Item: GearPtr ): Boolean;
	{ As of GH2 all attempts to extract an item will be successful. }
	{ The only question is whether the part will be destroyed in the process, }
	{ or whether some other bad effect will take place. }
	{ Note that pulling a gear out of its mecha may well wreck it }
	{ beyond any repair! Therefore, after this call, ITEM might no }
	{ longer exist... i.e. it may equal NIL. }
	{ This function returns TRUE if the item is okay, or FALSE if it was destroyed. }
var
	it: Boolean;
	SkRoll,WreckTarget: Integer;
	Slot: GearPtr;
begin
	Slot := Item^.Parent;

	{ First, calculate the skill target. }
	if Item^.G = GG_Module then begin
		WreckTarget := 6;
		if Slot^.G = GG_Mecha then WreckTarget := WreckTarget + Slot^.V - Item^.V;
	end else begin
		WreckTarget := ComponentComplexity( Item ) + 10 - UnscaledMaxDamage( Item );
		WreckTarget := WreckTarget + SubComComplexity( Slot ) - ComponentComplexity( Slot );
	end;
	if WreckTarget < 5 then WreckTarget := 5;

	SkRoll := SkillRoll( GB , TruePC , NAS_MechaEngineering , STAT_Knowledge , WreckTarget , 0 , True , True );

	if GB <> Nil then begin
		AddMentalDown( TruePC , 1 );
		WaitAMinute( GB , TruePC , ReactionTime( TruePC ) * 5 );
	end;

	{ Decide whether to extract the part and keep it, or just wreck it trying }
	{ to get it out. }
	if SkRoll > WreckTarget then begin
		{ First, delink Item from its parent. }
		ExtractMechaPart( Item^.Parent^.SubCom , Item );

		{ Try to stick as invcom of parent. }
		GivePartToPC( GB , Item , PC );

		it := True;
	end else begin
		RemoveGear( Item^.Parent^.SubCom , Item );
		Item := Nil;
		it := False;
	end;

	ExtractItem := it;
end;

Procedure ExtractFrontend( GB: GameBoardPtr; TruePC , PC , Item: GearPtr );
	{ Simply remove the provided item. }
	{ PRECOND: PC and ITEM had better be correct, dagnabbit... }
var
	name: String;
begin
	name := GearName( Item );
	if GearActive( PC ) then begin
		DialogMsg( MsgString( 'EXTRACT_NOTACTIVE' ) );
	end else begin 
		if ExtractItem( GB , TruePC , PC , Item ) then begin
			DialogMsg( ReplaceHash( MsgString( 'EXTRACT_OK' ) , name ) );
		end else begin
			DialogMsg( ReplaceHash( MsgString( 'EXTRACT_WRECK' ) , name ) );
		end;
	end;
end;


Procedure EquipItem( GB: GameBoardPtr; var LList: GearPtr; PC , Slot , Item: GearPtr );
	{ This is the real equipping procedure. Stuff ITEM into SLOT. }
	{ As noted in TheRules.txt, any nonmaster gear can only have one }
	{ item of any particular "G" type equipped at a time. So, if }
	{ SLOT already has equipment of type ITEM^.G, unequip that and }
	{ stuff it into PC's general inventory. }
var
	I2,I3: GearPtr;
begin
	{ First, check for already equipped items. }
	I2 := Slot^.InvCom;
	while I2 <> Nil do begin
		I3 := I2^.Next;		{ This next step might delink I2, so... }
		if ( I2^.G = Item^.G ) or ( Slot^.G = GG_Holder ) then begin
			UnequipItem( GB , LList , PC , I2 );
		end;
		I2 := I3;
	end;

	{ Next, delink Item from PC. }
	DelinkGear( PC^.InvCom , Item );

	{ Next, link ITEM into SLOT. }
	InsertInvCom( Slot , Item );

	{ Equipping an item takes time. }
	if GB <> Nil then WaitAMinute( GB , PC , ReactionTime( PC ) );
end;

Procedure EquipItemFrontend( GB: GameBoardPtr; var LList: GearPtr; PC , Item: GearPtr );
	{ Assign ITEM to a legal equipment slot. Move it from the }
	{ general inventory into its new home. }
var
	EI_Menu: RPGMenuPtr;
	N: Integer;
	W,L: Integer;
begin
	{ Build the slot selection menu. }
	EI_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	BuildSlotMenu( EI_Menu , PC , Item );
	AlphaKeyMenu( EI_Menu );
	if EI_Menu^.NumItem < 1 then AddRPGMenuItem( EI_Menu , ReplaceHash( MsgString( 'BACKPACK_CantEquip' ) , GearName( Item ) ) , -1 );

	{ Select a slot for the item to go into. }
	BP_Source := Item;
	N := SelectMenu( EI_Menu , @ThisItemRedraw);

	DisposeRPGMenu( EI_Menu );

	{ If a slot was selected, pass that info on to the workhorse. }
	if N <> -1 then begin
		DialogMsg( ReplaceHash( MsgString( 'BACKPACK_Do_Equip' ) , GearName( Item ) ) );
		EquipItem( GB , LList , PC , LocateGearByNumber( PC , N ) , Item );
		if Item^.G = GG_Weapon then begin
			W := Firing_Weight( Item , DefaultAtOp( Item ) );
			L := Firing_Weight_Limit( PC );
			if W > ( L * 3 ) then begin
				DialogMsg( MsgString( 'BACKPACK_Weapon_TooHeavy' ) );
			end else if W > L then begin
				DialogMsg( MsgString( 'BACKPACK_Weapon_Need2Hands' ) );
			end;
		end;
	end;
end;

Function InstallItem( GB: GameBoardPtr; TruePC , Slot: GearPtr; var Item: GearPtr ): Boolean;
	{ Attempt the skill rolls needed to install ITEM into the }
	{ requested slot. }
	{ ITEM should be linked as an inventory gear, and may be deleted by this function. }
	{ Return TRUE if the install was successful, or FALSE otherwise. }
	Procedure ResortInventory( Part: GearPtr );
		{ Take all the inventory from PART and move it to FindMaster(Slot) }
	var
		M,I: GearPtr;
	begin
		M := FindMaster( Slot );
		if M <> Nil then begin
			while Part^.InvCom <> Nil do begin
				I := Part^.InvCom;
				DelinkGear( Part^.InvCom , I );
				InsertInvCom( M , I );
			end;
		end else begin
			DisposeGear( Part^.InvCom );
		end;
	end;
	Procedure ShakeDownItem( LList: GearPtr );
		{ Remove all InvComs from this list, and for all children as well. }
	begin
		while LList <> Nil do begin
			if LList^.InvCom <> Nil then ResortInventory( LList );
			ShakeDownItem( LList^.SubCom );
			LList := LList^.Next;
		end;
	end;
var
	SlotCom,ItemCom,UsedCom,HardLimit: Integer;
	WreckTarget,SkRoll: Integer;
begin
	{ Error Check - no circular references! }
	if ( FindGearIndex( Item , Slot ) <> -1 ) then begin
		DialogMsg( ReplaceHash( MsgString( 'INSTALL_FAIL' ) , GearName( Item ) ) );
		Exit( False );
	end;

	{ Also, can't engineer things when you're exhausted. }
	if IsMasterGear( TruePC ) and ( CurrentMental( TruePC ) < 1 ) then begin
		DialogMsg( ReplaceHash( MsgString( 'INSTALL_FAIL' ) , GearName( Item ) ) );
		Exit( False );
	end;

	{ Can't install into a personal-scale slot. }
	if Slot^.Scale = 0 then begin
		DialogMsg( ReplaceHash( MsgString( 'INSTALL_FAIL' ) , GearName( Item ) ) );
		Exit( False );
	end;

	SlotCom := ComponentComplexity( Slot );
	HardLimit := SlotCom;
	ItemCom := ComponentComplexity( Item );
	UsedCom := SubComComplexity( Slot );
	{ If the INNOVATION talent is known, increase the HardLimit. }
	if GB <> Nil then begin
		if TeamHasTalent( GB , NAV_DefPlayerTeam , NAS_Innovation ) then HardLimit := HardLimit + 5;
	end else begin
		if HasTalent( TruePC , NAS_Innovation ) then HardLimit := HardLimit + 5;
	end;

	if (( UsedCom + ItemCom ) > HardLimit ) and not IsMasterGear( Slot ) then begin
		DialogMsg( MSgString( 'INSTALL_NoRoom' ) );
		Exit( False );
	end;

	{ The WreckTarget is the target number that must be beat }
	{ in order to avoid accidentally destroying the part... }
	if ( Item^.G = GG_Module ) then begin
		WreckTarget := 3 + NumSiblingGears( Slot^.SubCom ) - Item^.V;
	end else if Item^.G = GG_MoveSys then begin
		WreckTarget := 5 + ItemCom;
	end else if ( Item^.G = GG_Modifier ) then begin
		WreckTarget := 10 + ItemCom;
	end else if ( UnscaledMaxDamage( Item ) < 1 ) or ( Item^.Scale < Slot^.Scale ) then begin
		WreckTarget := 10;
	end else begin
		WreckTarget := 10 - UnscaledMaxDamage( Item );
	end;
	{ The insertion target is easier for heavy items, harder for lightened ones. }
	WreckTarget := WreckTarget - NAttValue( Item^.NA , NAG_GearOps , NAS_MassAdjust );
	if WreckTarget < 3 then WreckTarget := 3;

	{ If the SLOT is going to be overstuffed, better raise the }
	{ number of successes and the target number drastically. }
	if ( ( ItemCom + UsedCom ) > SlotCom ) and ( Not IsMasterGear( Slot ) ) then begin
		WreckTarget := WreckTarget + 2 + UsedCom + ItemCom - SlotCom + ItemCom * 5 div SlotCom;
	end;

	if GB <> Nil then WaitAMinute( GB , TruePC , ReactionTime( TruePC ) * 5 );

	SkRoll := SkillRoll( GB , TruePC , NAS_MechaEngineering , STAT_Knowledge , WreckTarget , 0 , True , True );
	if SkRoll >= WreckTarget then begin
		DialogMsg( ReplaceHash( MsgString( 'INSTALL_OK' ) , GearName( Item ) ) );
		{ Install the item. }
		ResortInventory( Item );
		ShakeDownItem( Item^.SubCom );
		DelinkGear( Item^.Parent^.InvCom , Item );
		InsertSubCom( Slot , Item );
	end else begin
		DialogMsg( ReplaceHash( MsgString( 'INSTALL_WRECK' ) , GearName( Item ) ) );
		RemoveGear( Item^.Parent^.InvCom , Item );
		Item := Nil;
	end;

	if ( GB <> Nil ) and IsMasterGear( TruePC ) then begin
		AddMentalDown( TruePC , 1 );
	end;

	InstallItem := SkRoll >= WreckTarget;
end;

Procedure InstallFrontend( GB: GameBoardPtr; TruePC , PC , Item: GearPtr );
	{ Assign ITEM to a legal equipment slot. Move it from the }
	{ general inventory into its new home. }
var
	EI_Menu: RPGMenuPtr;
	N: Integer;
begin
	{ Error check- can't install into an active master. }
	if GearActive( PC ) then begin
		DialogMsg( MsgString( 'INSTALL_NOTACTIVE' ) );
		Exit;
	end;

	{ Build the slot selection menu. }
	EI_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	BuildSubMenu( EI_Menu , PC , Item , True );
	if EI_Menu^.NumItem < 1 then AddRPGMenuItem( EI_Menu , '[cannot install ' + GearName( Item ) + ']' , -1 );

	{ Select a slot for the item to go into. }
	DialogMsg( ReplaceHash( MsgSTring( 'BACKPACK_InstallInfo' ) , GearName( Item ) ) );
	BP_Source := Item;
	N := SelectMenu( EI_Menu , @InstallRedraw);

	DisposeRPGMenu( EI_Menu );

	{ If a slot was selected, pass that info on to the workhorse. }
	if N <> -1 then begin
		{ Store the name here, since the item might get destroyed }
		{ during the installation process. }
		InstallItem( GB , TruePC , LocateGearByNumber( PC , N ) , Item );
	end;
end;

Procedure InstallAmmo( GB: GameBoardPtr; PC , Gun , Ammo: GearPtr );
	{ Place the ammunition gear into the gun. }
var
	A,A2: GearPtr;
begin
	{ To start with, unload any ammo currently in the gun. }
	A := Gun^.SubCom;
	while A <> Nil do begin
		A2 := A^.Next;

		if A^.G = GG_Ammo then begin
			DelinkGear( Gun^.SubCom , A );
			InsertInvCom( PC , A );
		end;

		A := A2;
	end;

	{ Delink the magazine from wherever it currently resides. }
	if IsInvCom( Ammo ) then begin
		DelinkGear( Ammo^.Parent^.InvCom , Ammo );
	end else if IsSubCom( Ammo ) then begin
		DelinkGear( Ammo^.Parent^.SubCom , Ammo );
	end;

	{ Stick the new magazine into the gun. }
	InsertSubCom( Gun , Ammo );

	{ Loading a gun takes time. }
	if GB <> Nil then WaitAMinute( GB , PC , ReactionTime( PC ) );
end;

Procedure InstallAmmoFrontend( GB: GameBoardPtr; PC , Item: GearPtr );
	{ Assign ITEM to a legal projectile weapon. Move it from the }
	{ general inventory into its new home. }
var
	IA_Menu: RPGMenuPtr;
	Gun: GearPtr;
	N: Integer;
begin
	{ Build the slot selection menu. }
	IA_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	BuildSubMenu( IA_Menu , PC , Item , False );
	if IA_Menu^.NumItem < 1 then AddRPGMenuItem( IA_Menu , '[no weapon for ' + GearName( Item ) + ']' , -1 );

	{ Select a slot for the item to go into. }
	N := SelectMenu( IA_Menu , @MiscProcRedraw);

	DisposeRPGMenu( IA_Menu );

	{ If a slot was selected, pass that info on to the workhorse. }
	if N <> -1 then begin
		Gun := LocateGearByNumber( PC , N );
		DialogMsg( 'You load ' + GearName( Item ) + ' into ' + GearName( Gun ) + '.' );
		InstallAmmo( GB , PC , Gun , Item );
	end;
end;


Procedure DropFrontEnd( GB: GameBoardPtr; var LList: GearPtr; PC , Item: GearPtr );
	{ How to drop an item: Make sure PC is a root-level gear. }
	{ Delink ITEM from its current location. }
	{ Copy PC's location variables to ITEM. }
	{ Install ITEM as the next sibling of PC. }
begin
	{ Make sure PC is at root level... }
	PC := FindRoot( PC );

	{ Delink ITEM from its parent... }
	DelinkGear( Item^.Parent^.InvCom , Item );

	{ Copy the location variables to ITEM... }
	SetNAtt( Item^.NA , NAG_Location , NAS_X , NAttValue( PC^.NA , NAG_Location , NAS_X ) );
	SetNAtt( Item^.NA , NAG_Location , NAS_Y , NAttValue( PC^.NA , NAG_Location , NAS_Y ) );
	if ( GB <> Nil ) and not OnTheMap( GB , PC ) then SetNAtt( Item^.NA , NAG_Location , NAS_Team , NAV_DefPlayerTeam );

	{ Install ITEM into LList... }
	AppendGear( LList , Item );

	{ Do display stuff. }
	DialogMsg( ReplaceHash( MsgString( 'BACKPACK_Do_Drop' ) , GearName( Item ) ) );
end;

Procedure TradeFrontend( GB: GameBoardPtr; PC , Item, LList: GearPtr );
	{ Assign ITEM to a different master. Move it from the }
	{ general inventory of PC into its new home. }
var
	TI_Menu: RPGMenuPtr;
	M: GearPtr;
	Team,N: Integer;
begin
	if ( GB <> Nil ) and not IsSafeArea( GB ) then begin
		DialogMsg( MsgSTring( 'TRANSFER_NOTHERE' ) );
		Exit;
	end;

	{ Build the slot selection menu. }
	TI_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	N := 1;
	M := LList;
	Team := NAttValue( PC^.NA , NAG_Location , NAS_Team );

	{ This menu should contain all the masters from LList which }
	{ belong to Team 1. }
	while M <> Nil do begin
		if ( GB = Nil ) and IsMasterGear( M ) and ( M <> PC ) then begin
			AddRPGMenuItem( TI_Menu , TeamMateName( M ) , N );
		end else if ( Team = NAV_DefPlayerTeam ) or ( Team = NAV_LancemateTeam ) then begin
			if IsMasterGear( M ) and ( ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) or ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NaV_LancemateTeam ) ) and ( M <> PC ) then begin
				AddRPGMenuItem( TI_Menu , TeamMateName( M ) , N );
			end;
		end else begin
			if IsMasterGear( M ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = Team ) and ( M <> PC ) then begin
				AddRPGMenuItem( TI_Menu , TeamMateName( M ) , N );
			end;
		end;
		M := M^.Next;
		Inc( N );
	end;
	RPMSortAlpha( TI_Menu );
	AlphaKeyMenu( TI_Menu );

	if TI_Menu^.NumItem < 1 then AddRPGMenuItem( TI_Menu , MsgString( 'CANCEL' ) , -1 );

	{ Select a slot for the item to go into. }
	N := SelectMenu( TI_Menu , @MiscProcRedraw);

	DisposeRPGMenu( TI_Menu );

	{ If a slot was selected, pass that info on to the workhorse. }
	if N <> -1 then begin
		M := RetrieveGearSib( LList , N );
		if IsLegalInvCom( M , Item ) then begin
			DelinkGear( Item^.Parent^.InvCom , Item );
			InsertInvCom( M , Item );
			DialogMsg( MsgString( 'BACKPACK_ItemTraded' ) );
		end else begin
			DialogMsg( MsgString( 'BACKPACK_NotTraded' ) );
		end;
	end;
end;

Procedure FHQ_AssociatePilotMek( PC , M , LList: GearPtr );
	{ Associate the mecha with the pilot. }
begin
	AssociatePilotMek( LList , PC , M );
	DialogMsg( ReplaceHash( MsgString( 'FHQ_AssociatePM' ) , GearName( PC ) ) );
end;

Procedure FHQ_AssociateRedraw;
	{ Do a redraw for the Field HQ. }
var
	Part: GearPtr;
begin
	CombatDisplay( BP_GB );
	SetupFHQDisplay;
	if ( BP_ActiveMenu <> Nil ) and ( BP_Source <> Nil ) then begin
		Part := RetrieveGearSib( BP_Source , CurrentMenuItemValue( BP_ActiveMenu ) );
		if Part <> Nil then begin
			BrowserInterfaceInfo( BP_GB , Part , ZONE_ItemsInfo );
		end;
	end;
end;

Procedure FHQ_SelectPilotForMecha( GB: GameBoardPtr; Mek: GearPtr );
	{ Select a pilot for the mecha in question. }
	{ Pilots must be characters- they must either belong to the default }
	{ player team or, if they're lancemates, they must have a CID. }
	{ This is to prevent the PC from dominating some sewer rats and }
	{ training them to be pilots. }
var
	RPM: RPGMenuPtr;
	N: Integer;
	M: GearPtr;
begin
	BP_GB := GB;
	BP_Source := GB^.Meks;
	DialogMsg( ReplaceHash( MsgString( 'FHQ_SP4M_Prompt' ) , FullGearName( Mek ) ) );

	{ Create the menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
	BP_ActiveMenu := RPM;
	M := GB^.Meks;
	N := 1;
	while M <> Nil do begin
		if M^.G = GG_Character then begin
			if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and ( NAttValue( M^.NA , NAG_Personal , NAS_CID ) <> 0 ) then begin
				AddRPGMenuItem( RPM , GearName( M ) , N );
			end else if NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then begin
				AddRPGMenuItem( RPM , GearName( M ) , N );
			end;
		end;
		M := M^.Next;
		Inc( N );
	end;
	RPMSortAlpha( RPM );
	AddRPGMenuItem( RPM , MSgString( 'EXIT' ) , -1 );

	{ Get a selection from the menu. }
	n := SelectMenu( RPM , @FHQ_AssociateRedraw );

	DisposeRPGMenu( RPM );

	if N > 0 then begin
		M := RetrieveGearSib( GB^.Meks , N );
		FHQ_AssociatePilotMek( M , Mek , GB^.Meks );
	end;
end;

Procedure FHQ_SelectMechaForPilot( GB: GameBoardPtr; NPC: GearPtr );
	{ Select a pilot for the mecha in question. }
	{ Pilots must be characters- they must either belong to the default }
	{ player team or, if they're lancemates, they must have a CID. }
	{ This is to prevent the PC from dominating some sewer rats and }
	{ training them to be pilots. }
var
	RPM: RPGMenuPtr;
	N: Integer;
	M: GearPtr;
begin
	BP_GB := GB;
	BP_Source := GB^.Meks;
	DialogMsg( ReplaceHash( MsgString( 'FHQ_SM4P_Prompt' ) , GearName( NPC ) ) );

	{ Error check- only characters can pilot mecha! Pets can't. }
	if ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) = 0 ) and ( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) <> NAV_DefPlayerTeam ) then begin
		DialogMsg( ReplaceHash( MsgString( 'FHQ_SMFP_NoPets' ) , GearName( NPC ) ) );
		Exit;
	end;

	{ Create the menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
	BP_ActiveMenu := RPM;
	M := GB^.Meks;
	N := 1;
	while M <> Nil do begin
		if ( M^.G = GG_Mecha ) and ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then begin
			AddRPGMenuItem( RPM , GearName( M ) , N );
		end;
		M := M^.Next;
		Inc( N );
	end;
	RPMSortAlpha( RPM );
	AddRPGMenuItem( RPM , MSgString( 'EXIT' ) , -1 );

	{ Get a selection from the menu. }
	n := SelectMenu( RPM , @FHQ_AssociateRedraw );

	DisposeRPGMenu( RPM );

	if N > 0 then begin
		M := RetrieveGearSib( GB^.Meks , N );
		FHQ_AssociatePilotMek( NPC , M , GB^.Meks );
	end;
end;

Procedure UseScriptItem( GB: GameBoardPtr; TruePC, Item: GearPtr; T: String );
	{ This item has a script effect. Exit the backpack and use it. }
begin
	if SAttValue( Item^.SA , T ) <> '' then begin
		{ Announce the intention. }
		DialogMsg( ReplaceHash( MsgString( 'BACKPACK_Script_' + T ) , GearName( Item ) ) );

		{ Using items takes time... }
		WaitAMinute( GB , TruePC , ReactionTime( TruePC ) );

		{ ...and also exits the backpack. }
		ForceQuit := True;
		CombatDisplay( GB );

		{ Finally, trigger the script. }
		TriggerGearScript( GB , Item , T );
	end else begin
		{ Announce the lack of a valid script. }
		DialogMsg( ReplaceHash( MsgString( 'BACKPACK_CannotUseScript' ) , GearName( Item ) ) );
	end;
end;

Procedure UseSkillOnItem( GB: GameBoardPtr; TruePC, Item: GearPtr );
	{ The PC will have the option to use a CLUE-type skill on this }
	{ item, maybe to gain some new information, activate an effect, }
	{ or whatever else. }
var
	SkMenu: RPGMenuPtr;
	T: Integer;
	msg: String;
begin
	SkMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );

	{ Add the usable skills. }
	for t := 1 to NumSkill do begin
		{ In order to be usable, it must be a CLUE type skill, }
		{ and the PC must have ranks in it. }
		if ( SkillMan[ T ].Usage = USAGE_Clue ) and ( TeamHasSkill( GB , NAV_DefPlayerTeam , T ) or TeamHasTalent( GB , NAV_DefPlayerTeam , NAS_JackOfAll ) ) then begin
			msg := ReplaceHash( MsgString( 'BACKPACK_ClueSkillPrompt' ) , MsgString( 'SKILLNAME_' + BStr( T ) ) );
			msg := ReplaceHash( msg , GearName( Item ) );
			AddRPGMenuItem( SkMenu , msg , T );
		end;
	end;
	RPMSortAlpha( SkMenu );
	AddRPGMenuItem( SkMenu , MsgSTring( 'BACKPACK_CancelSkillUse' ) , -1 );

	BP_GB := GB;
	BP_Source := Item;
	T := SelectMenu( SkMenu , @ThisItemRedraw);

	DisposeRPGMenu( SkMenu );

	if T <> -1 then begin
		UseScriptItem( GB , TruePC , Item , Skill_Use_Trigger[ T ] );
	end;
end;

Procedure EatItem( GB: GameBoardPtr; TruePC , Item: GearPtr );
	{ The PC wants to eat this item. Give it a try. }
var
	effect: String;
begin
	TruePC := LocatePilot( TruePC );

	if TruePC = Nil then begin
		DialogMsg( ReplaceHash( MsgString( 'BACKPACK_CantBeEaten' ) , GearName( Item ) ) );

	end else if ( NAttValue( TruePC^.NA , NAG_Condition , NAS_Hunger ) > ( Item^.V div 2 ) ) or ( Item^.V = 0 ) then begin
		{ Show a message. }
		DialogMsg( ReplaceHash( ReplaceHash( MsgString( 'BACKPACK_YouAreEating' ) , GearName( TruePC ) ) , GearName( Item ) ) );

		{ Eating takes time... }
		WaitAMinute( GB , TruePC , ReactionTime( TruePC ) * GearMass( Item ) + 1 );

		{ ...and also exits the backpack. }
		ForceQuit := True;

		{ Locate the PC's Character record, then adjust hunger values. }
		AddNAtt( TruePC^.NA , NAG_Condition , NAS_Hunger , -Item^.V );
		AddMoraleDmg( TruePC , -( Item^.Stat[ STAT_MoraleBoost ] * FOOD_MORALE_FACTOR ) );

		{ Invoke the item's effect, if any. }
		if Item^.Stat[ STAT_FoodEffectType ] <> 0 then begin
			effect := ReplaceHash( Food_Effect_String[ Item^.Stat[ STAT_FoodEffectType ] ] , BStr( Item^.Stat[ STAT_FoodEffectMod ] ) );
			EffectFrontEnd( GB , TruePC , effect , '' );
		end;

		{ Apply the item's SkillXP, if any. }
		if Item^.Stat[ STAT_FoodSkillXP ] <> 0 then begin
			if DoleSkillExperience( TruePC , Item^.Stat[ STAT_FoodSkillXP ] , Item^.Stat[ STAT_FoodSkillXPAmount ] ) then begin
				DialogMsg( ReplaceHash( MsgString( 'BACKPACK_FoodSkillBoost' ) , GearName( Item ) ) );
			end;
		end;

		{ Destroy the item, if appropriate. }
		if IsInvCom( Item ) then begin
			RemoveGEar( Item^.Parent^.InvCom , Item );
		end else if IsSubCom( Item ) then begin
			RemoveGEar( Item^.Parent^.SubCom , Item );
		end;
	end else begin
		DialogMsg( MsgString( 'BACKPACK_NotHungry' ) );
	end;
end;

Procedure SwitchQuickFire( Item: GearPtr );
	{ Swap the quickfire prefs for this item. }
var
	QFP: Integer;	{ Quick Fire Priority }
begin
	QFP := ( NAttValue( Item^.NA, NAG_WeaponModifier, NAS_QuickFire ) + 3 ) mod 4;
	SetNAtt( Item^.NA, NAG_WeaponModifier, NAS_QuickFire , QFP );
end;

Procedure InstallSoftware( GB: GameBoardPtr; PC , SW: GearPtr );
	{ Attempt to install some software into a computer. This is how it's }
	{ going to work: First pick a computer to install into. If a computer }
	{ was selected, see if it has enough free space for the requested }
	{ software. If it doesn't, prompt to uninstall some programs. If after }
	{ the purge there's enough room for the requested program install it. }
	Function SelectComputer: GearPtr;
		{ Attempt to select a computer. }
	var
		RPM: RPGMenuPtr;
		N: Integer;
	begin
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
		BuildGearMenu( RPM , PC , GG_Computer );
		BP_Source := PC;
		BP_SeekSibs := False;
		BP_ActiveMenu := RPM;

		if RPM^.NumItem < 1 then AddRPGMenuItem( RPM , '[no computer for ' + GearName( SW ) + ']' , -1 );

		{ Select a computer, and get rid of the menu. }
		N := SelectMenu( RPM , @MiscProcRedraw);
		DisposeRPGMenu( RPM );

		if N > 0 then begin
			SelectComputer := LocateGearByNumber( PC , N );
		end else begin
			SelectComputer := Nil;
		end;
	end;
	Procedure FreeSoftwareSpace( Compy: GearPtr );
		{ Unload programs from this computer until SW can be installed, }
		{ or the user cancels. }
	var
		RPM: RPGMenuPtr;
		S: GearPtr;
		N: Integer;
	begin
		DialogMsg( ReplaceHash( MsgString( 'BACKPACK_FreeSoftwareSpace' ) , GearName( SW ) ) );
		repeat
			RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
			BP_Source := Compy^.SubCom;
			BP_SeekSibs := True;
			BP_ActiveMenu := RPM;

			{ Add the software to the menu. }
			N := 1;
			S := Compy^.SubCom;
			while S <> nil do begin
				AddRPGMenuItem( RPM , GearName( S ) , N );
				Inc( N );
				S := S^.Next;
			end;

			{ Select from the menu. }
			N := SelectMenu( RPM , @MiscProcRedraw);
			DisposeRPGMenu( RPM );

			{ If a software program was selected, uninstall it and place }
			{ it in the inventory. }
			if N > -1 then begin
				S := RetrieveGearSib( Compy^.SubCom , N );
				DelinkGear( Compy^.SubCom , S );
				InsertInvCom( PC , S );
			end;
		until ( N = -1 ) or IsLegalSubCom( Compy , SW );
	end;
var
	Compy: GearPtr;
begin
	BP_GB := GB;
	Compy := SelectComputer;
	if ( Compy <> Nil ) then begin
		if ( ZetaGigs( Compy ) >= ZetaGigs( SW ) ) then begin
			if not IsLegalSubCom( Compy , SW ) then FreeSoftwareSpace( Compy );
			if IsLegalSubCom( Compy , SW ) then begin
				DelinkGear( SW^.Parent^.InvCom , SW );
				InsertSubCom( Compy , SW );
				DialogMsg( ReplaceHash( MsgString( 'BACKPACK_InstallSoftware' ) , GearName( SW ) ) );
				if GB <> Nil then WaitAMinute( GB , PC , ReactionTime( PC ) );
			end else begin
				DialogMsg( ReplaceHash( MsgString( 'BACKPACK_ComputerTooFull' ) , GearName( SW ) ) );
			end;
		end else begin
			{ This computer is too small to install this program. }
			DialogMsg( ReplaceHash( MsgString( 'BACKPACK_ComputerTooSmall' ) , GearName( SW ) ) );
		end;
	end;
end;

Procedure PCDoPerformance( GB: GameBoardPtr; PC: GearPtr );
	{ The PC is playing an instrument. Whee! Check how many positive }
	{ reactions the PC scores. The PC might also earn money, if the }
	{ public response is positive enough. }
var
	Target: GearPtr;
	Success: LongInt;
	msg: String;
begin
	{ Select a target for this performance. }
	Target := SelectPerformanceTarget( GB , PC );
	msg := ReplaceHash( MsgString( 'PERFORMANCE_Base' ) , GearName( PC ) );

	{ If we have a target, then perform. }
	if Target <> Nil then begin
		{ Call the performance procedure to find out how well the }
		{ player has done. }
		Success := UsePerformance( GB , PC , Target );

		{ Print an appropriate message. }
		if Success > 0 then begin
			{ Good show! The PC made some money as a busker. }
			msg := msg + ' ' + ReplaceHash( MsgString( 'PERFORMANCE_DidWell' + BStr( Random( 3 ) ) ) , BStr( Success ) );
		end else if Success < 0 then begin
			{ The PC flopped. No money made, and possibly damage }
			{ to his reputation. }
			msg := msg + ' ' + MsgString( 'PERFORMANCE_Horrible' + BStr( Random( 3 ) ) );
		end;
	end else begin
		msg := msg + ' ' + MsgString( 'PERFORMANCE_NoAudience' );
		SetNAtt( PC^.NA , NAG_Location , NAS_SmartAction , 0 );
	end;

	DialogMsg( msg );
end;

Procedure StartPerforming( GB: GameBoardPtr; PC: GearPtr );
	{ Start performing on a musical instrument. This procedure will set }
	{ up the continuous action. }
begin
	if ( PC = Nil ) or ( PC^.G <> GG_Character ) then Exit;


	SetNAtt( PC^.NA , NAG_Location , NAS_SmartCount , 4 );
	SetNAtt( PC^.NA , NAG_Location , NAS_SmartAction , NAV_UseSkill );
	SetNAtt( PC^.NA , NAG_Location , NAS_SmartSkill , NAS_Performance );

	{ ...and also exit the backpack. }
	ForceQuit := True;

	PCDoPerformance( GB , PC );
	WaitAMinute( GB , PC , ReactionTime( PC ) );
end;

Procedure ThisItemWasSelected( GB: GameBoardPtr; var LList: GearPtr; TruePC , PC , Item: GearPtr );
	{ TruePC is the primary character, who may be doing repairs }
	{  and stuff. }
	{ PC is the current master being examined, which may well be }
	{  a mecha belonging to the TruePC rather than the TruePC itself. }
	{ LList is a list of mecha and other things which may or may not }
	{  belong to the same team as TruePC et al. }
	{ Item is the piece of wargear currently being examined. }
	{ BP_Redraw must have been set some time before this procedure was called. }
var
	TIWS_Menu: RPGMenuPtr;
	N: Integer;
begin
	N := 0;
	repeat
		TIWS_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );

		if ( Item^.G = GG_Tool ) and ( Item^.S = NAS_Performance ) and ( GB <> Nil ) then AddRPGMenuItem( TIWS_Menu , ReplaceHash( MsgString( 'BACKPACK_UseInstrument' ) , GearName( Item ) ) , -9 );
		if ( Item^.G = GG_Consumable ) and ( GB <> Nil ) then AddRPGMenuItem( TIWS_Menu , ReplaceHash( MsgString( 'BACKPACK_EatItem' ) , GearName( Item ) ) , -10 );
		if ( Item^.G = GG_Software ) and IsInvCom( Item ) then AddRPGMenuItem( TIWS_Menu , ReplaceHash( MsgString( 'BACKPACK_TIWS_InstallSoftware' ) , GearName( Item ) ) , -12 );

		if ( GB <> Nil ) and ( SATtValue( Item^.SA , 'USE' ) <> '' ) then AddRPGMenuItem( TIWS_Menu , ReplaceHash( MsgString( 'BACKPACK_UseItemScript' ) , GearName( Item ) ) , -11 );

		if ( Item^.G = GG_Ammo ) and IsInvCom( Item ) then AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_LoadAmmo' ) , -5 );

		if IsInvCom( Item ) then begin
			if Item^.Parent = PC then begin
				AddRPGMenuItem( TIWS_Menu , ReplaceHash( MsgString( 'BACKPACK_EquipItem' ) , GearName( Item ) ) , -2 );
				if ( FindMaster( Item ) <> Nil ) and ( FindMaster( Item )^.G = GG_Mecha ) and CanBeInstalled( Item ) then begin
					AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_Install' ) + GearName( Item ) , -8 );
				end;
			end else begin
				AddRPGMenuItem( TIWS_Menu , ReplaceHash( MsgString( 'BACKPACK_UnequipItem' ) , GearName( Item ) ) , -3 );
			end;
			if ( LList <> Nil ) and (( GB = Nil ) or IsSafeArea( GB )) then AddRPGMenuItem ( TIWS_Menu , MsgString( 'BACKPACK_TradeItem' ) , -6 );
			AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_DropItem' ) , -4 );
		end else if ( FindMaster( Item ) <> Nil ) and ( FindMaster( Item )^.G = GG_Mecha ) and CanBeExtracted( Item ) then begin
			AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_Remove' ) + GearName( Item ) , -7 );
		end;

		if ( SeekSubsByG( Item^.SubCom , GG_Ammo ) <> Nil ) and not IsMasterGear( Item ) then AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_EjectAmmo' ) , 4 );
		if ( SeekSubsByG( Item^.SubCom , GG_Software ) <> Nil ) and not IsMasterGear( Item ) then AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_EjectSoftware' ) , 5 );

		if GB <> Nil then AddRepairOptions( TIWS_Menu , TruePC , Item );
		if ( Item^.G = GG_Weapon ) or ( ( Item^.G = GG_Ammo ) and ( Item^.S = GS_Grenade ) ) then begin
			AddRPGMenuItem( TIWS_Menu, ReplaceHash( MsgString( 'BACKPACK_QF' + BStr( NAttValue( Item^.NA, NAG_WeaponModifier, NAS_QuickFire ) ) ), GearName( Item ) ), 2 );

			if NAttValue( Item^.NA , NAG_WeaponModifier , NAS_SafetySwitch ) = 0 then begin
				AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_EngageSafety' ) , 3 );
			end else begin
				AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_DisengageSafety' ) , 3 );
			end;
		end;
		if GB <> Nil then AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_UseSkillOnItem' ) , 1 );
		AddRPGMenuItem( TIWS_Menu , MsgString( 'BACKPACK_ExitTIWS' ) , -1 );

		{ Restore the menu item in case this isn't the first iteration. }
		SetItemByValue( TIWS_Menu , N );

		BP_GB := GB;
		BP_Source := Item;
		N := SelectMenu( TIWS_Menu , @ThisItemRedraw );
		DisposeRPGMenu( TIWS_Menu );

		if N > 100 then begin
			DoFieldRepair( GB , TruePC , Item , N-100 );
		end else begin
			case N of
				5: EjectSoftware( GB , LList , PC , Item );
				4: EjectAmmo( GB , LList , PC , Item );
				3: SetNAtt( Item^.NA , NAG_WeaponModifier , NAS_SafetySwitch , 1 - NAttValue( Item^.NA , NAG_WeaponModifier , NAS_SafetySwitch ) );
				2: SwitchQuickFire( Item );
				1: UseSkillOnItem( GB , TruePC , Item );
				-2: EquipItemFrontend( GB , LList , PC , Item );
				-3: UnequipFrontEnd( GB , LList , PC , Item );
				-4: DropFrontEnd( GB , LList , PC , Item );
				-5: InstallAmmoFrontEnd( GB , PC , Item );
				-6: TradeFrontEnd( GB , PC, Item , LList );
				-7: ExtractFrontEnd( GB , TruePC , PC , Item );
				-8: InstallFrontEnd( GB , TruePC , PC , Item );
				-9: StartPerforming( GB , PC );
				-10: EatItem( GB , PC , Item );
				-11: UseScriptItem( GB , TruePC , Item , 'USE' );
				-12: InstallSoftware( GB , PC , Item );	{ Install Software }
			end;
		end;
	until ( N < 0 ) or ForceQuit;
end;

Function DoInvMenu( GB: GameBoardPtr; var LList: GearPtr; PC,M: GearPtr ): Boolean;
	{ Return TRUE if the user selected Quit. }
	{ M is the MASTER whose inventory we're examining. In a normal case, when }
	{ the PC is examining his own stuff, then M = PC. }
var
	N: Integer;
begin
	Repeat
		BP_GB := GB;
		BP_Source := M;
		BP_SeekSibs := False;
		BP_ActiveMenu:= InvRPM;

		N := SelectMenu( INVRPM , @MiscProcRedraw);

		{ If an item was selected, pass it along to the appropriate }
		{ procedure. }
		if N > 0 then begin
			ThisItemWasSelected( GB , LList , PC , M , LocateGearByNumber( M , N ) );
			{ Restore the display. }
			UpdateBackpack( M );
		end;
	until ( N < 0 ) or ForceQuit;

	DoInvMenu := N=-1;
end;

Function DoEqpMenu( GB: GameBoardPtr; var LList: GearPtr; PC,M: GearPtr ): Boolean;
	{ Return TRUE if the user selected Quit. }
	{ M is the MASTER whose inventory we're examining. In a normal case, when }
	{ the PC is examining his own stuff, then M = PC. }
var
	N: Integer;
begin
	Repeat
		BP_GB := GB;

		BP_Source := M;
		BP_SeekSibs := False;
		BP_ActiveMenu:= EqpRPM;

		N := SelectMenu( EqpRPM , @EqpRedraw);

		{ If an item was selected, pass it along to the appropriate }
		{ procedure. }
		if N > 0 then begin
			ThisItemWasSelected( GB , LList , PC , M , LocateGearByNumber( M , N ) );
			{ Restore the display. }
			UpdateBackpack( M );
		end;
	until ( N < 0 ) or ForceQuit;

	DoEqpMenu := N=-1;
end;


Procedure RealBackpack( GB: GameBoardPtr; var LList: GearPtr; PC,M: GearPtr; StartWithInv: Boolean; BasicRedraw: RedrawProcedureType );
	{ This is the backpack routine which should allow the player to go }
	{ through all the stuff in his/her inventory, equip items, drop them, }
	{ reload weapons, and whatnot. It is based roughly upon the procedures }
	{ from DeadCold. }
	{ GB = The gameboard; may be nil. }
	{ LList = The list of stuff surrounding M; where things go when dropped. }
	{ PC = The controller of the party; the primary PC. }
	{ M = The model whose backpack we're dealing with. }
var
	QuitBP: Boolean;
begin
	{ Set up the display. }
	ForceQuit := False;

	BP_Redraw := BasicRedraw;

	{ Initialize menus to NIL, then create them. }
	InvRPM := Nil;
	EqpRPM := Nil;
	UpdateBackpack( M );

	repeat
		if StartWithInv then begin
			QuitBP := DoInvMenu( GB , LList , PC , M );
		end else begin
			QuitBP := DoEqpMenu( GB , LList , PC , M );
		end;

		{ If we have not been ordered to exit the loop, we must }
		{ have been ordered to switch menus. }
		StartWithInv := Not StartWithInv;
	until QuitBP or ForceQuit;

	DisposeRPGMenu( InvRPM );
	DisposeRPGMenu( EqpRPM );
end;

Procedure ArenaHQBackpack( Source,BPPC: GearPtr; BasicRedraw: RedrawProcedureType );
	{ Open the backpack menu for a member of this arena unit. }
begin
	RealBackpack( Nil , Source^.SubCom , Source , BPPC , True , BasicRedraw );
end;

Procedure LancemateBackpack( GB: GameBoardPtr; PC,NPC: GearPtr; BasicRedraw: RedrawProcedureType );
	{ This is a header for the REALBACKPACK function. }
begin
	RealBackPack( GB , GB^.Meks , PC , NPC , True , BasicRedraw );
end;

Procedure BackpackMenu( GB: GameBoardPtr; PC: GearPtr; StartWithInv: Boolean; BasicRedraw: RedrawProcedureType );
	{ This is a header for the REALBACKPACK function. }
begin
	RealBackPack( GB , GB^.Meks , PC , PC , StartWithInv , BasicRedraw );
end;

Procedure MechaPartEditor( GB: GameBoardPtr; var LList: GearPtr; PC,Mek: GearPtr; BasicRedraw: RedrawProcedureType  );
	{ This procedure may be used to browse through all the various }
	{ bits of a mecha and examine each one individually. }
	{ LList is the list of mecha of which MEK is a sibling. If any item gets removed }
	{ from Mek but can't be placed in the general inventory, it will be put there. }
var
	RPM: RPGMenuPtr;
	N,I: Integer;
begin
	{ Set up the display. }
	DrawBPBorder;
	I := 0;

	Repeat
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
		BP_ActiveMenu := RPM;
		BuildGearMenu( RPM , Mek );
		if I > 0 then SetItemByPosition( RPM , I );
		AddRPGMenuItem( RPM , 'Exit Editor' , -1 );

		BP_Redraw := BasicRedraw;
		BP_GB := GB;
		BP_Source := Mek;
		BP_SeekSibs := False;
		N := SelectMenu( RPM , @MechaPartEditorRedraw);

		I := RPM^.SelectItem;
		DisposeRPGMenu( RPM );

		if N > -1 then begin
			ThisItemWasSelected( GB , LList , PC , Mek , LocateGearByNumber( Mek , N ) );
		end;
	until N = -1;
end;


Procedure MechaPartBrowser( Mek: GearPtr; RDP: RedrawProcedureType );
	{ This procedure may be used to browse through all the various }
	{ bits of a mecha and examine each one individually. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	MPB_Redraw := RDP;

	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
	BuildGearMenu( RPM , Mek );
	AddRPGMenuItem( RPM , 'Exit Browser' , -1 );

	Repeat
		BP_Source := Mek;
		BP_SeekSibs := False;
		BP_ActiveMenu := RPM;
		N := SelectMenu( RPM , @PartBrowserRedraw );
	until N = -1;
	DisposeRPGMenu( RPM );
end;

Procedure MysteryPartBrowser( Mek: GearPtr; RDP: RedrawProcedureType );
	{ Like the above procedure, but provide no actual info. }
	{ This procedure is used when the PC attempts to inspect a target, }
	{ but lacks the proper identification software. }
var
	RPM: RPGMenuPtr;
begin
	MPB_Redraw := RDP;
	BP_Source := Mek;
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
	AddRPGMenuItem( RPM , '????' , -1 );
	SelectMenu( RPM , @MysteryBrowserRedraw );
	DisposeRPGMenu( RPM );
end;

Procedure BrowseDesignFile( List: GearPtr; RDP: RedrawProcedureType );
	{ Choose one of the sibling gears from LIST and display its properties. }
var
	BrowseMenu: RPGMenuPtr;
	Part: GearPtr;
	N: Integer;
begin
	{ Create the menu. }
	BrowseMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );

	{ Add each of the gears to the menu. }
	BuildSiblingMenu( BrowseMenu , List );
	RPMSortAlpha( BrowseMenu );
	AddRPGMenuItem( BrowseMenu , '  Cancel' , -1 );

	repeat
		MPB_Redraw := RDP;
		BP_Source := List;
		BP_SeekSibs := True;
		BP_ActiveMenu := BrowseMenu;

		{ Select a gear. }
		N := SelectMenu( BrowseMenu, @PartBrowserRedraw );

		if N > -1 then begin
			Part := RetrieveGearSib( List , N );
			MechaPartBrowser( Part , RDP );
			if Part^.G = GG_Theme then CheckTheme( Part );
		end;
	until N = -1;

	DisposeRPGMenu( BrowseMenu );
end;


Procedure FHQ_Transfer( var LList: GearPtr; PC,Item: GearPtr );
	{ An item has been selected. Allow it to be transferred to }
	{ one of the team's master gears. }
var
	RPM: RPGMenuPtr;
	M: GearPtr;
	N,Team: Integer;
begin
	{ Create the menu. }
	RPM := CreateRPGMenu( MenuItem, MenuSelect, ZONE_FieldHQMenu );
	M := LList;
	N := 1;
	Team := NAttValue( PC^.NA , NAG_LOcation , NAS_Team );
	while M <> Nil do begin
		if ( ( NAttValue( M^.NA , NAG_LOcation , NAS_Team ) = Team ) or ( NAttValue( M^.NA , NAG_LOcation , NAS_Team ) = NAV_LancemateTeam ) ) and IsMasterGear( M ) and IsLegalInvcom( M , Item ) then begin
			AddRPGMenuItem( RPM , TeamMateName( M ) , N );
		end;

		M := M^.Next;
		Inc( N );
	end;

	{ Sort the menu, then add an exit option. }
	RPMSortAlpha( RPM );
	AlphaKeyMenu( RPM );
	AddRPGMenuItem( RPM , MsgString( 'FHQ_ReturnToMain' ) , -1 );

	{ Get a menu selection, then exit the menu. }
	BP_Source := Item;
	DialogMSG( MsgString( 'FHQ_SelectDestination' ) );
	N := SelectMenu( RPM , @ThisWargearRedraw );

	DisposeRPGMenu( RPM );

	if N > -1 then begin
		M := RetrieveGearSib( LList , N );
		DelinkGear( LList , Item );
		InsertInvCom( M , Item );
		DialogMSG( MsgString( 'FHQ_ItemMoved' ) );
	end else begin
		DialogMSG( MsgString( 'Cancelled' ) );
	end;
end;

Procedure Rename_Mecha( GB: GameBoardPtr; NPC: GearPtr );
	{ Enter a new name for NPC. }
var
	name: String;
begin
	name := GetStringFromUser( ReplaceHash( MsgString( 'FHQ_Rename_Prompt' ) , GearName( NPC ) ) , @PlainRedraw );

	if name <> '' then SetSAtt( NPC^.SA , 'name <' + name + '>' );
end;

Procedure FHQ_ThisWargearWasSelected( GB: GameBoardPtr; var LList: GearPtr; PC,M: GearPtr; BasicRedrawer: RedrawProcedureType );
	{ A mecha has been selected by the PC from the FHQ main menu. }
	{ Offer up all the different choices of things the PC can }
	{ do with mecha - select pilot, repair, check inventory, etc. }
var
	RPM: RPGMenuPtr;
	N: Integer;
begin
	repeat
		{ Create the FHQ menu. }
		RPM := CreateRPGMenu( MenuItem, MenuSelect, ZONE_FieldHQMenu );
		RPM^.Mode := RPMNoCleanup;

		if IsMasterGear( M ) then begin
			if IsSafeArea( GB ) or OnTheMap( GB , M ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_GoBackpack' ) , 1 );
		end else if IsSafeArea( GB ) then begin
			AddRPGMenuItem( RPM , MsgString( 'FHQ_Transfer' ) , -3 );
		end;

		if IsSafeArea( GB ) then AddRepairOptions( RPM , PC , M );

		if M^.G = GG_Mecha then begin
			AddRPGMenuItem( RPM , MsgString( 'FHQ_SelectMecha' ) , 2 );
			AddRPGMenuItem( RPM , MsgString( 'FHQ_Rename' ) , 6 );
		end;
		if IsSafeArea( GB ) then AddRPGMenuItem( RPM , MsgString( 'FHQ_PartEditor' ) , 4 );


		if M^.G = GG_Mecha then AddRPGMenuItem( RPM , MsgString( 'FHQ_EditColor' ) , 5 );


		AddRPGMenuItem( RPM , MsgString( 'FHQ_ReturnToMain' ) , -1 );

		{ Get a selection from the menu, then dispose of it. }
		BP_GB := GB;
		BP_Source := M;
		BP_Redraw := BasicRedrawer;
		N := SelectMenu( RPM , @ThisWargearRedraw );

		DisposeRPGMenu( RPM );

		if N > 100 then begin
			{ A repair option must have been selected. }
			DoFieldRepair( GB , PC , M , N-100 );

		end else begin
			case N of
				1: RealBackpack( GB , LList , PC , M , False , BasicRedrawer );
				2: FHQ_SelectPilotForMecha( GB , M );
				-3: FHQ_Transfer( LList , PC , M );
				4: MechaPartEditor( GB , LList , PC , M , @PlainRedraw );
{$IFNDEF ASCII}
				5: SelectColors( M , BasicRedrawer );
{$ENDIF}
				6: Rename_Mecha( GB , M );
			end;

		end;

	until N < 0;
{$IFNDEF ASCII}
	CleanSpriteList;
{$ENDIF}
end;

Procedure UsableGearMenu( GB: GameBoardPtr; PC: GearPtr );
	{ The PC is about to invoke a usable gear. Take a look and see }
	{ which effects are available, then invoke one of them. }
var
	RPM: RPGMenuPtr;
	N: Integer;
	Part: GearPtr;
begin
	BP_GB := GB;
	BP_Source := PC;
	BP_Redraw := @PlainRedraw;
	BP_SeekSibs := False;

	RPM := CreateRPGMenu( MenuItem, MenuSelect, ZONE_FieldHQMenu );
	BuildGearMenu( RPM , PC , GG_Usable );

	AlphaKeyMenu( RPM );
	RPMSortAlpha( RPM );

	AddRPGMenuItem( RPM , MsgString( 'Cancel' ) , -1 );

	BP_ActiveMenu := RPM;

	N := SelectMenu( RPM , @MechaPartEditorRedraw );
	DisposeRPGMenu( RPM );

	Part := LocateGearByNumber( PC , N );
	if Part <> Nil then begin
		if Part^.S = GS_Transformation then begin
			if CanDoTransformation( GB , PC , Part ) then begin
				DoTransformation( GB , PC , Part , True );
			end else begin
				DialogMsg( MsgString( 'TRANSFORM_NotNow' ) );
			end;
		end else if Part^.S = GS_LongRangeScanner then begin
			if LongRangeScanEPCost( GB, Part ) > EnergyPoints( FindRoot( Part ) ) then begin
				DialogMsg( MsgString( 'LONGRANGESCAN_NoPower' ) );
			end else if CanLRScanHere( GB, Part ) then begin
				DoLongRangeScan( GB , PC , Part );
			end else begin
				DialogMsg( MsgString( 'LONGRANGESCAN_NotNow' ) );
			end;
		end;
	end;
end;




end.
