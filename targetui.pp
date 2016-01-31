unit targetui;
	{ Targeting User Interface. }
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
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}


const
	LOOKER_AutoSelect: Boolean = True;	{ Auto select new target if no current target. }

var
	LOOKER_X,LOOKER_Y: Integer;	{ Last X , Y position accessed. }
	LOOKER_Gear: GearPtr;		{ Last mecha accessed. }
	LOOKER_LastGearSelected: GearPtr;	{ Last enemy selected with select next enemy key. }

Function WeaponBVSetting( Weapon: GearPtr ): Integer;

Function LookAround( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
Function SelectTarget( GB: GameBoardPtr; Mek: GearPtr; var Wpn: GearPtr; var CallShot: boolean; var RapidFire: Integer ): Boolean;

Function DirKey( ReDrawer: RedrawProcedureType ): Integer;


implementation

uses ability,gearutil,ghweapon,menugear,texutil,ui4gh,ghsensor,
     arenacfe,description,backpack,
{$IFDEF ASCII}
	vidmap,vidmenus,vidinfo;
{$ELSE}
	sdlmap,sdlmenus,sdlinfo;
{$ENDIF}

var
	LOOKER_Origin,LOOKER_Weapon: GearPtr;
	LOOKER_CallShot: Boolean;
	LOOKER_RapidFire: Integer;
	LOOKER_GB: GameBoardPtr;
	LOOKER_Desc: String;

Function WeaponBVSetting( Weapon: GearPtr ): Integer;
	{ Return the BV Setting used by this weapon. It should be }
	{ one of either Off, 1/2, 1/4, or Max. }
var
	BV: Integer;
begin
	if Weapon = Nil then Exit( BV_Off );

	BV := NAttValue( Weapon^.NA , NAG_Prefrences , NAS_DefAtOp );
	if BV = 0 then begin
		if Weapon^.G <> GG_Weapon then begin
			BV := BV_Off;
		end else if ( Weapon^.S = GS_Ballistic ) then begin
			BV := DefBallisticBV;
		end else if Weapon^.S = GS_BeamGun then begin
			BV := DefBeamGunBV;
		end else if Weapon^.S = GS_Missile then begin
			BV := DefMissileBV;
		end else begin
			BV := BV_Off;
		end;
	end;

	WeaponBVSetting := BV;
end;

Procedure DoSwitchBV;
	{ Switch the burst value used for LOOKER_Weapon, then store the }
	{ new burst value as the weapon's default. }
var
	BV: Integer;
begin
	if LOOKER_Weapon = Nil then Exit;

	{ Determine the current BV; this will tell us what to do next. }
	BV := WeaponBVSetting( LOOKER_Weapon );
	if LOOKER_Weapon^.G = GG_Weapon then begin
		if LOOKER_Weapon^.S = GS_Missile then begin
			BV := BV + 1;
			if BV > 4 then BV := 1;
			SetNAtt( LOOKER_Weapon^.NA , NAG_Prefrences , NAS_DefAtOp , BV );
		end else if ( LOOKER_Weapon^.S = GS_Ballistic ) or ( LOOKER_Weapon^.S = GS_BeamGun ) then begin
			BV := 5 - BV;
			SetNAtt( LOOKER_Weapon^.NA , NAG_Prefrences , NAS_DefAtOp , BV );
		end;
	end;
end;

Procedure WeaponDisplay;
	{ Show the weapon display, and the instructions/options. }
var
	msg: String;
begin
	{ Generate instructions. }
	msg := '[' + KeyMap[ KMC_SwitchWeapon ].KCode + '] Change Weapon' + #13;
	msg := msg + ' [' + KeyMap[ KMC_CalledShot ].KCode + '] Called Shot: ';
	if LOOKER_CallShot then msg := msg + 'On'
	else msg := msg + 'Off';
	msg := msg + #13 + ' [' + KeyMap[ KMC_SwitchBV ].KCode + '] Burst Value: ';
	msg := msg + BVTypeName[ WeaponBVSetting( LOOKER_Weapon ) ];
	msg := msg + #13 + ' [' + KeyMap[ KMC_SwitchTarget ].KCode + '] Switch Target';
	msg := msg + #13 + ' [' + KeyMap[ KMC_ExamineTarget ].KCode + '] Examine Target';

	{ Print instructions. }
	InfoBox( ZONE_RightInfo );
	GameMSG( msg , ZONE_RightInfo , InfoGreen );

	InfoBox( ZONE_LeftInfo );
	GameMsg( GearName( Looker_Weapon ) + ' ' + WeaponDescription( LOOKER_GB , LOOKER_Weapon ) , ZONE_LeftInfo , InfoGreen );
end;

Function CreateTileMechaMenu( GB: GameBoardPtr; X,Y: Integer; ShowAll: Boolean ): RPGMenuPtr;
	{ Make a menu listing each of the mecha at spot X , Y. }
	Function ShouldInclude( Mek: GearPtr ): Boolean;
		{ Return TRUE if MEK should be included in a targeting menu, }
		{ or FALSE otherwise. }
	begin
		if IsMasterGear( Mek ) then begin
			ShouldInclude := GearOperational( Mek );
		end else begin
			ShouldInclude := NotDestroyed( Mek ) and ( GearMaxDamage( Mek ) > 0 );
		end;
	end;
var
	TMM: RPGMenuPtr;
	N,T: Integer;
	Mek: GearPtr;
	msg: String;
begin
	TMM := CreateRPGMenu( InfoGreen , InfoHilight , ZONE_Caption );

	N := NumVisibleGears( GB , X , Y );

	for t := 1 to N do begin
		{ We need to list both the name of the mecha and the name of }
		{ the pilot. }
		Mek := FindVisibleGear( GB , X , Y , T );
		msg := MechaPilotName( Mek );
		if not GearOperational( Mek ) then begin

		    if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Gutted) = 1
		    then begin
			if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Flayed) = 1
			then
			    msg := msg + ' (stripped'
			else
			    msg := msg + ' (gutted';
			end
		    else begin
			if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Flayed) = 1
			then
			    msg := msg + ' (flayed'
			else
			    msg := msg + ' (X';
			end;
			
		    if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Ransacked) = 1
		    then
			msg := msg + ', looted)'
		    else
			msg := msg + ')';
		end;
		if ShowAll or ShouldInclude( Mek ) then begin
			AddRPGMenuItem( TMM , msg , T );
		end;
	end;

	if not ShowAll then AlphaKeyMenu( TMM );

	CreateTileMechaMenu := TMM;
end;

Procedure DisplayTileInfo( GB: GameBoardPtr; X,Y: Integer);
	{ Display info on the contents of location X,Y. }
	{ If the tile is empty, give a description of the terrain. }
	{ Otherwise provide a sumamry for whatever gears are there. }
var
	N: Integer;	{ The number of gears present in the tile. }
	Mek: GearPtr;
	TMM: RPGMenuPtr;
	msg: String;
begin
	{ Display info for target square. }
	N := NumVisibleGears( GB , X , Y );
	if not OnTheMap( GB , X , Y ) then begin
		GameMSG( 'Off The Map' , ZONE_Caption , InfoGreen );
		LOOKER_Gear := Nil;

	end else if N = 0 then begin
		if TileVisible( GB , X , Y ) then begin
			msg := '';
			if msg = '' then msg := MsgString( 'TerrNAME_' + BStr( TileTerrain( GB,X,Y) ) );
			GameMsg( msg , ZONE_Caption , InfoGreen );

		end else begin
			GameMsg( 'UNKNOWN' , ZONE_Caption , InfoGreen );
		end;

		LOOKER_Gear := Nil;

	end else if N = 1 then begin
		Mek := FindVisibleGear( GB , X , Y , 1 );
		DisplayModelStatus( GB , mek , ZONE_Caption );
		LOOKER_Gear := Mek;

	end else if N > 1 then begin
		TMM := CreateTileMechaMenu( GB , X , Y , True );
		DisplayMenu( TMM , Nil );

		DisposeRPGMenu( TMM );
		LOOKER_Gear := Nil;

	end;

end;

Procedure GFLRedraw;
	{ menu redrawer for this unit. }
begin
	if LOOKER_GB <> Nil then CombatDisplay( LOOKER_GB );
	if LOOKER_Weapon <> Nil then WeaponDisplay;
{$IFNDEF ASCII}
	InfoBox( ZONE_SubCaption );
{$ELSE}
	ClockBorder;
{$ENDIF}
	CMessage( LOOKER_Desc , ZONE_SubCaption , InfoHilight );
	InfoBox( ZONE_Caption );
	DisplayTileInfo( LOOKER_GB , LOOKER_X , LOOKER_Y );
end;

Procedure ExamineTargetRedraw;
	{ menu redrawer for this unit. }
begin
	if LOOKER_GB <> Nil then CombatDisplay( LOOKER_GB );
end;

Procedure SelectOneTargetFromListRedraw;
	{ menu redrawer for this unit. }
begin
	if LOOKER_GB <> Nil then CombatDisplay( LOOKER_GB );
	if LOOKER_Weapon <> Nil then WeaponDisplay;
{$IFNDEF ASCII}
	InfoBox( ZONE_SubCaption );
{$ELSE}
	ClockBorder;
{$ENDIF}
	CMessage( LOOKER_Desc , ZONE_SubCaption , InfoHilight );
	InfoBox( ZONE_Caption );
end;

Function CoverDesc( C: Integer ): String;
	{ Return a string telling how much cover the target has. }
begin
	if C < 0 then begin
		CoverDesc := 'X';
	end else begin
		CoverDesc := BStr( C );
	end;
end;

Function FindNextTarget( GB: GameBoardPtr; Origin: GearPtr; MustBeEnemy: Boolean ): GearPtr;
	{ ORIGIN is looking for a new target. Return the next visible enemy found. }
	Function TargetIsValid( M: GearPtr ): Boolean;
		{ Return TRUE if this model is of a type that we're looking for. }
	begin
		if MustBeEnemy then begin
			TargetIsValid := AreEnemies( GB , Origin , M );
		end else begin
			TargetIsValid := IsMasterGear( M );
		end;
	end;
var
	M,NextTarget,FirstTarget: GearPtr;
	PickNext: Boolean;
begin
	{ If we've already selected an enemy, find the next one from that point. }
	if ( LOOKER_LastGearSelected = Nil ) and ( LOOKER_Gear <> Nil ) then LOOKER_LastGearSelected := LOOKER_Gear;

	{ Cycle through all the models on the map looking for a visible, operational enemy. }
	M := GB^.Meks;
	NextTarget := Nil;
	PickNext := False;
	FirstTarget := Nil;
	while M <> Nil do begin
		{ If M fits our target criteria, check it to see what's going on. }
		if OnTheMap( GB , M ) and TargetIsValid( M ) and GearOperational( M ) and MekCanSeeTarget( GB , Origin , M ) and ( NAttValue( M^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) <> NAV_NowSurrendered ) then begin
			{ If M is the target we started with, set the flag to pick the next }
			{ target encountered. }
			if M = LOOKER_LastGearSelected then begin
				PickNext := True;
			end else if PickNext then begin
				NextTarget := M;
				PickNext := False;
			end;
			if FirstTarget = Nil then FirstTarget := M;
		end;

		M := M^.Next;
	end;
	{ If NextTarget = Nil, either we started with no target or the target we had }
	{ was the last target in the list. So, go with the first target found. }
	if NextTarget = Nil then NextTarget := FirstTarget;
	LOOKER_LastGearSelected := NextTarget;
	FindNextTarget := NextTarget;
end;

Function GetTargetFromTile( GB: GameBoardPtr; X,Y: Integer ): GearPtr;
	{ Get a target from this map position. }
var
	N,MekNum: Integer;
	Target: GearPtr;
	TMM: RPGMenuPtr;
begin
	N := NumVisibleGears( GB , X , Y );
	if N = 1 then begin
		Target := FindVisibleGear( GB , X , Y , 1 );

	end else if N > 1 then begin
		TMM := CreateTileMechaMenu( GB , X , Y , Looker_Weapon = Nil );
		if TMM^.NumItem > 1 then begin
			MekNum := SelectMenu( TMM , @SelectOneTargetFromListRedraw );

		end else if TMM^.NumItem > 0 then begin
			MekNum := TMM^.FirstItem^.Value;
		end else begin
			MekNum := -1;
		end;
		DisposeRPGMenu( TMM );

		if MekNum <> -1 then Target := FindVisibleGear( GB , X , Y , MekNum )
		else Target := Nil;

	end else begin
		Target := Nil;
	end;
	GetTargetFromTile := Target;
end;

Procedure ExamineTarget( GB: GameBoardPtr; PC: GearPtr; X , Y: Integer );
	{ The PC wants to examine this tile. Whether or not he can do so will depend }
	{ on what kind of software he has loaded. }
var
	Target: GearPtr;
	Function HasInformation( I: Integer ): Boolean;
		{ Return TRUE if the PC has the requested information software, }
		{ or FALSE otherwise. }
	begin
		HasInformation := SeekSoftware( PC , S_Information , I , True ) <> Nil;
	end;
	Function CanExamineTarget: Boolean;
		{ Depending on TARGET's type, and PC's loaded software, }
		{ the PC may or may not be able to examine this target. }
	begin
		if Target^.G = GG_Character then begin
			if NotAnAnimal( Target ) then begin
				CanExamineTarget := True;
			end else begin
				case NAttValue( Target^.NA , NAG_GearOps , NAS_Material ) of
					NAV_Meat:	CanExamineTarget := HasInformation( SInfo_CreatureDex );
					NAV_Metal:	CanExamineTarget := HasInformation( SInfo_RobotDex );
					NAV_Biotech:	CanExamineTarget := HasInformation( SInfo_SynthDex );
				else CanExamineTarget := True;
				end;				
			end;
		end else if Target^.G = GG_Mecha then begin
			CanExamineTarget := HasInformation( SInfo_MechaDex );
		end else CanExamineTarget := True;
	end;
begin
	Target := GetTargetFromTile( GB , X , Y );
	if Target <> Nil then begin
		if CanExamineTarget then begin
			MechaPartBrowser( Target , @ExamineTargetRedraw );
		end else begin
			MysteryPartBrowser( Target , @ExamineTargetRedraw );
		end;
	end;
end;

Function TrueLooker( GB: GameBoardPtr; X , Y: Integer ): Boolean;
	{ Scan the map, starting at location X,Y. }
	{ Return TRUE if this procedure is exited with the space bar, }
	{ FALSE if it is exited with the ESC key. }
	{ If Mek <> Nil, do range calculations from that spot. }
	{ If WPN <> Nil, allow weapon selection. }
var
	A: Char;
	Procedure RepositionCursor( D: Integer );
	begin
		{ Convert the screen direction to a map direction. }
		D := KeyboardDirToMapDir( D );

		if OnTheMap( GB , X + AngDir[ D , 1 ] , Y + AngDir[ D , 2 ] ) then begin
			X := X + AngDir[ D , 1 ];
			Y := Y + AngDir[ D , 2 ];
		end;
	end;
begin
	{ Error check- make sure the start point is on the screen. }
	if not OnTheMap( GB , X , Y ) then begin
		X := 1;
		Y := 1;
	end;

	LOOKER_LastGearSelected := Nil;

	{ Start going here. }
	repeat
		LOOKER_GB := GB;
		LOOKER_X := X;
		LOOKER_Y := Y;
		if ( LOOKER_Origin <> Nil ) and OnTheMap( GB , LOOKER_Origin ) then begin
			if LOOKER_Gear = Nil then begin
				LOOKER_Desc := 'Range: ' + BStr( ScaleRange( Range(LOOKER_Origin,X,Y) , GB^.Scale ) ) + '   Cover: '+CoverDesc( CalcObscurement( LOOKER_Origin , X , Y , gb ));
			end else begin
				Looker_Desc := 'Range: ' + BStr( ScaleRange( Range(gb,LOOKER_Origin,LOOKER_Gear) , GB^.Scale )) + '   Cover: '+CoverDesc( CalcObscurement( LOOKER_Origin , LOOKER_Gear , gb ));
			end;
		end else begin
			LOOKER_Desc := '';
		end;

		{ Indicate target square. }
		IndicateTile( GB , X , Y , TerrMan[ TileTerrain( GB , X , Y ) ].Altitude );

		GFLRedraw;
		DoFlip;

		A := RPGKey;

		if A = KeyMap[ KMC_North ].KCode then begin
			RepositionCursor( 6 );

		end else if A = KeyMap[ KMC_South ].KCode then begin
			RepositionCursor( 2 );

		end else if A = KeyMap[ KMC_West ].KCode then begin
			RepositionCursor( 4 );

		end else if A = KeyMap[ KMC_East ].KCode then begin
			RepositionCursor( 0 );

		end else if A = KeyMap[ KMC_NorthEast ].KCode then begin
			RepositionCursor( 7 );

		end else if A = KeyMap[ KMC_SouthWest ].KCode then begin
			RepositionCursor( 3 );

		end else if A = KeyMap[ KMC_NorthWest ].KCode then begin
			RepositionCursor( 5 );

		end else if A = KeyMap[ KMC_SouthEast ].KCode then begin
			RepositionCursor( 1 );

		end else if ( A = KeyMap[ KMC_SwitchWeapon ].KCode ) and ( LOOKER_Weapon <> Nil ) and ( LOOKER_Origin <> Nil ) then begin
			if Cycle_All_Weapons then begin
				LOOKER_Weapon := FindNextWeapon( GB , LOOKER_Origin , LOOKER_Weapon , 0 );
			end else begin
				LOOKER_Weapon := FindNextWeapon( GB , LOOKER_Origin , LOOKER_Weapon , Range( LOOKER_Origin , X , Y ) );
			end;

		end else if ( A = KeyMap[ KMC_SwitchTarget ].KCode ) and ( LOOKER_Origin <> Nil ) then begin
			LOOKER_Gear := FindNextTarget( GB , LOOKER_Origin , LOOKER_Weapon <> Nil );
			if LOOKER_Gear <> Nil then begin
				X := NATtValue( LOOKER_Gear^.NA , NAG_Location , NAS_X );
				Y := NATtValue( LOOKER_Gear^.NA , NAG_Location , NAS_Y );
			end;

		end else if ( A = KeyMap[ KMC_ExamineTarget ].KCode ) and ( LOOKER_Origin <> Nil ) then begin
			ExamineTarget( GB , LOOKER_Origin , X , Y );

		end else if ( A = KeyMap[ KMC_SwitchBV ].KCode ) and ( LOOKER_Weapon <> Nil ) and ( LOOKER_Origin <> Nil ) then begin
			DoSwitchBV;

		end else if ( A = KeyMap[ KMC_CalledShot ].KCode ) and ( LOOKER_Weapon <> Nil ) and ( LOOKER_Origin <> Nil ) then begin
			LOOKER_CallShot := not LOOKER_CallShot;

		end else if A = KeyMap[ KMC_ExamineMap ].KCode then begin
			A := #27;

{$IFNDEF ASCII}
		end else if ( A = RPK_MouseButton ) and OnTheMap( GB , Tile_X , Tile_Y ) then begin
			if ( X = Tile_X ) and ( Y = Tile_Y ) then begin
				A := ' ';
			end else begin
				X := Tile_X;
				Y := Tile_Y;
			end;
{$ENDIF}

		end else if A = KeyMap[ KMC_Attack ].KCode then begin
			A := ' ';

		end else if A = #8 then begin
			A := #27;

		end;

	until (A = ' ') or (A = #27) or (A = #10);

	{ Restore the display. }
	ClearOverlays;
	CombatDisplay( GB );

	{ Store the values in the global variables. }
	LOOKER_X := X;
	LOOKER_Y := Y;
	LOOKER_Gear := GetTargetFromTile( GB , X , Y );

	{ Return TRUE if a space was pressed, FALSE otherwise. }
	TrueLooker := ( A = ' ' ) or ( A = #10 );
end;

Function LookAround( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
	{ This function just calls the above one with the location of }
	{ the specified mek. }
var
	X,Y: Integer;
begin
	LOOKER_Origin := Mek;
	LOOKER_Weapon := Nil;
	LOOKER_Gear := Nil;

	if Mek <> Nil then begin
		X := NAttValue( Mek^.NA , NAG_Location, NAS_X );
		Y := NAttValue( Mek^.NA , NAG_Location, NAS_Y );
	end else begin
		X := 1;
		Y := 1;
	end;

	LookAround := TrueLooker( GB , X , Y );
end;

Function SelectTarget( GB: GameBoardPtr; Mek: GearPtr; var Wpn: GearPtr; var CallShot: boolean; var RapidFire: Integer ): Boolean;
	{ This function just calls LookAround with the location of }
	{ the specified mek and its current target. }
	{ Record the target selected as this mecha's target. }
var
	T: GearPtr;		{ The Target }
	X,Y: Integer;
	FunResult: Boolean;	{ Function Result }
begin
	LOOKER_Origin := Mek;
	LOOKER_Weapon := Wpn;
	LOOKER_CallShot := CallShot;
	LOOKER_RapidFire := RapidFire;
	LOOKER_Gear := Nil;

	{ Get the default values from this mek. }
	T := LocateMekByUID( GB , NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Target ) );

	{ If this mek has a target, start out the targeting cursor in the }
	{ target's square. If it has no target, start the targeting cursor }
	{ in the mek's own square. }
	if ( T <> Nil ) and MekCanSeeTarget( gb , Mek , T ) and OnTheMap( GB , T ) and GearOperational( T ) and ( NAttValue( T^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) <> NAV_NowSurrendered ) then begin
		X := NAttValue( T^.NA , NAG_Location, NAS_X );
		Y := NAttValue( T^.NA , NAG_Location, NAS_Y );
	end else if LOOKER_AutoSelect then begin
		T := SeekTarget( GB , Mek );
		if T <> Nil then begin
			X := NAttValue( T^.NA , NAG_Location, NAS_X );
			Y := NAttValue( T^.NA , NAG_Location, NAS_Y );
		end else begin
			X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
			Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );
		end;
	end else begin
		X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
		Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );
	end;

	{ Call the look around procedure. }
	FunResult := TrueLooker( GB , X , Y );

	{ If the targeting wasn't cancelled, record the target. }
	if FunResult and ( LOOKER_Gear <> Nil ) and ( FindRoot( LOOKER_Gear ) <> Mek ) then begin
		SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Target , NAttValue( LOOKER_Gear^.NA , NAG_EpisodeData , NAS_UID ) );
	end;

	{ Set the values of the VAR parameters. }
	Wpn := LOOKER_Weapon;
	CallShot := LOOKER_CallShot;
	RapidFire := LOOKER_RapidFire;

	{ Return the value. }
	SelectTarget := FunResult;
end;


Function DirKey( ReDrawer: RedrawProcedureType ): Integer;
	{ Get a direction selection from the user. If a standard direction }
	{ key was selected, return its direction (0 is East, increase }
	{ clockwise). See Locale.pp for details. }
	{ Return -1 if no good direction was chosen. }
var
	D: Integer;
	K: Char;
begin
	ReDrawer;
	DoFlip;

	D := -2;
	repeat
		K := RPGKey;
		if K = KeyMap[ KMC_East ].KCode then begin
			D := 0;
		end else if K = KeyMap[ KMC_SouthEast ].KCode then begin
			D := 1;
		end else if K = KeyMap[ KMC_South ].KCode then begin
			D := 2;
		end else if K = KeyMap[ KMC_SouthWest ].KCode then begin
			D := 3;
		end else if K = KeyMap[ KMC_West ].KCode then begin
			D := 4;
		end else if K = KeyMap[ KMC_NorthWest ].KCode then begin
			D := 5;
		end else if K = KeyMap[ KMC_North ].KCode then begin
			D := 6;
		end else if K = KeyMap[ KMC_NorthEast ].KCode then begin
			D := 7;
{$IFNDEF ASCII}
		end else if K = RPK_TimeEvent then begin
			ReDrawer;
			DoFlip;
			D := -2;
{$ENDIF}
		end else begin
			D := -1;
		end;
	until D <> -2;

	if D <> -1 then D := KeyboardDirToMapDir( D );

	DirKey := D;
end;


end.
