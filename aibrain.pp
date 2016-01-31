unit aibrain;
	{ This unit handles behavior for the various enemy units in }
	{ Gearhead Arena. }
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

uses gears,locale;

procedure ShiftGears( GB: GameBoardPtr; Mek: GearPtr; DoOutput: Boolean );
Function CanSpeakWithTarget( GB: GameBoardPtr; PC,NPC: GearPtr ): Boolean;

Procedure ClearHotMaps;

Function SelectBestWeapon( GB: GameBoardPtr; Mek,Target: GearPtr ): GearPtr;

Procedure GetAIInput( Mek: GearPtr; GB: GameBoardPtr );
Procedure ConfusedInput( Mek: GearPtr; GB: GameBoardPtr );

Procedure BrownianMotion( GB: GameBoardPtr );
Procedure HandleEncounters( GB: GameBoardPtr );

Procedure LancemateUsefulAction( Mek: GearPtr; GB: GameBoardPtr );

Function MOVE_MODEL_TOWARDS_SPOT( Mek: GearPtr; GB: GameBoardPtr; GX,GY: Integer ): Boolean;

implementation

uses ability,action,arenacfe,effects,movement,gearutil,specialsys,ghswag,
     ghchars,ghmodule,ghweapon,gearparser,ghprop,interact,rpgdice,skilluse,
     texutil,ui4gh,grabgear,arenascript,menugear,ghsupport,backpack,
{$IFDEF ASCII}
	vidgfx,vidmap;
{$ELSE}
	sdlmap,sdlgfx;
{$ENDIF}

const
	HMMM_EncounterGround = -1;

	Hot_Terr: Array [-1..NumMoveMode,1..NumTerr] of SmallInt = (
	( 2, 2, 2, 2, 2,  2, 2, 2, 2, 2,  { ENCOUNTER: GROUND }
	  2, 2,-1,  2, 2, 2,
	  2, 2,  2,-1, 2,
	 2,
	  2, 2, 2, -1, 2	),
	( 2, 3, 4,-1, 2,  2, 3, 3, 4, 5,  { CHARA WALK }
	  3,-1,-1,  2, 2, 2,
	 -1,-1,  2,-1, 2,
	 4,
	  -1,-1,-1, -1,-1	),
	( 2, 3, 4, 5, 2,  2, 3, 3, 4, 5,  { MECHA WALK }
	  3,-1,-1,  2, 2, 2,
	  5, 5,  2,-1, 2,
	 4,
	  -1,-1,-1, -1,-1	),
	( 2,-1,-1,-1, 3,  1, 4, 3, 4, 5,  { ROLL }
	  4,-1,-1,  2, 2, 2,
	  5, 5,  2,-1, 2,
	 -1,
	  -1,-1,-1, -1,-1	),
	( 2, 3, 4, 2, 2,  2, 3, 3, 4, 5,  { SKIM }
	  2,-1,-1,  2, 2, 2,
	  2, 2,  2,-1, 2,
	 4,
	  -1,-1,-1, -1,-1	),
	( 2, 2, 2, 2, 2,  2, 2, 2, 2, 2,  { FLY }
	  2, 2,-1,  2, 2, 2,
	  2, 2,  2,-1, 2,
	 2,
	  -1, 2, 2, -1, 2	),
	(-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,  { SPACE FLIGHT }
	 -1,-1,-1, -1,-1,-1,
	 -1,-1, -1,-1,-1,
	 -1,
	 2,-1,-1, -1,-1	)
	);

	NumFFMap = 10;

	ORD_SeekAnyEdge = -1;
	ORD_SeekEnemy = 0;
	ORD_SeekSingleModel = 1;
	ORD_SeekSpot = 2;
	ORD_SeekEdge = 3;
	ORD_SeekTeam = 4;

	Hot_Map_Validity = 10;

	CORD_Flirt = 1;
	CORD_Chat = 2;

var
	{ The HOTMAP is used for pathfinding and general tactical }
	{ decision-making. }
	{ HOTMAP shows what squares the NPC will want to move into. }
	{ COLDMAP shows what squares the NPC won't want to move into. }
	MapUpdate: Array [1..NumFFMap] of LongInt;
	MapTeam: Array [1..NumFFMap] of Integer;
	MapOrder: Array [1..NumFFMap] of Integer;
	MapMoveMode: Array [1..NumFFMap] of Integer;
	HotMap: Array [1..NumFFMap , 1..MaxMapWidth , 1..MaxMapWidth ] of Integer;
	ColdMap: Array [1..NumFFMap , 1..MaxMapWidth , 1..MaxMapWidth ] of Integer;

procedure ShiftGears( GB: GameBoardPtr; Mek: GearPtr; DoOutput: Boolean );
	{ Set the mek's MoveMode attribute to the next }
	{ active movemode that this mek has. }
var
	P: Point;
	Terr,MM,CMM: Integer;
begin
	{ Initialize values. }
	CMM := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	MM := CMM mod NumMoveMode + 1;

	{ Determine the terrain of the tile the mek is pointing at. The shifted movemode }
	{ must be legal there. }
	P := GearCurrentLocation( Mek );
	P.X := P.X + AngDir[ NAttValue( Mek^.NA , NAG_Location , NAS_D ) ,1];
	P.Y := P.Y + AngDir[ NAttValue( Mek^.NA , NAG_Location , NAS_D ) ,2];

	{ If it turns out that the model's facing the edge of the map, use the current tile }
	{ instead. }
	if not OnTheMap( GB , P.X , P.Y ) then P := GearCurrentLocation( Mek );
	Terr := TileTerrain( GB , P.X , P.Y );

	{ Check each movemode in turn until we find one the mek is capable of that is also }
	{ legal for the tile in front. }
	while ( MM <> CMM ) and ( ( BaseMoveRate( GB^.Scene , Mek , MM ) <= 0 ) or IsBlockingTerrainForMM( GB , Mek , Terr , MM ) ) do begin
		MM := MM mod NumMoveMode + 1;
	end;

	{ If a legal move mode was found, switch to that. }
	if ( MM <> 0 ) and ( MM <> CMM ) then begin
		SetMoveMode( GB , Mek , MM );
		if DoOutput then DialogMsg( ReplaceHash( MsgString( 'ShiftGears' ) , MsgString( 'MOVEMODENAME_' + BStr( MM ) ) ) );
	end else begin
		if DoOutput then DialogMsg( MsgString( 'SHIFTGEARS_FAIL' ) );
	end;
end;


Function CanSpeakWithTarget( GB: GameBoardPtr; PC,NPC: GearPtr ): Boolean;
	{ Return TRUE if the PC can speak with the target without breaking out the }
	{ telephone, or FALSE otherwise. }
begin
	CanSpeakWithTarget := ( Range( GB , FindRoot( PC ) , FindRoot( NPC ) ) < 6 );
end;

Function HotTileBlocksLOS( GB: GameBoardPtr; X , Y , MM: Integer ): Boolean;
	{ Return TRUE if the given tile should block AI movement. }
	{ BUGS: X,Y must lie on the map; MM must be in range 0..NumMoveMode. }
begin
	HotTileBlocksLOS := TileBlocksLOS( GB , X , Y , 5 ) or ( Hot_Terr[ MM , TileTerrain( GB , X , Y ) ] < 0 );
end;

Procedure HotMapFloodFill( GB: GameBoardPtr; N,MM: Integer );
	{ Given a map that's had the hot spots filled in, use the }
	{ flood fill algorithm to determine paths etc. }
var
	X,Y: Integer;
	Flag: Boolean;
	DV,DH,DD,DP: Integer;	{ Distance Vertical, Horizontal, and Diagnol. }
begin
	flag := True;
	while flag do begin
		flag := False;
		for y := 2 to (GB^.MAP_Height-1) do begin
			for x := 2 to (GB^.Map_Width-1) do begin
				if not HotTileBlocksLOS( GB , X , Y , MM ) then begin
					dH := Hot_Terr[ MM , TileTerrain( GB,X,Y) ] + HotMap[ N , X - 1 , Y ];
					dV := Hot_Terr[ MM , TileTerrain( GB,X,Y) ] + HotMap[ N , X , Y - 1 ];
					if DV < DH then DH := DV;
					DD := Hot_Terr[ MM , TileTerrain( GB,X,Y) ] + 1 + HotMap[ N , X - 1 , Y - 1];
					if DD < DH then DH := DD;
					DP := Hot_Terr[ MM , TileTerrain( GB,X,Y) ] + 1 + HotMap[ N , X + 1 , Y - 1];
					if DP < DH then DH := DP;

					if DH < HotMap[ N , X , Y ] then begin
						HotMap[ N , X , Y ] := DH;
						flag := True;
					end;
				end;
			end;
		end;


		for y := ( GB^.Map_Height - 1 ) downto 2 do begin
			for x := ( GB^.Map_Width - 1 ) downto 2 do begin
				if not HotTileBlocksLOS( GB , X , Y , MM ) then begin
					dH := Hot_Terr[ MM , TileTerrain( GB,X,Y) ] + HotMap[ N , X + 1 , Y ];
					dV := Hot_Terr[ MM , TileTerrain( GB,X,Y) ] + HotMap[ N , X , Y + 1 ];
					if DV < DH then DH := DV;
					DD := Hot_Terr[ MM , TileTerrain( GB,X,Y) ] + 1 + HotMap[ N , X + 1 , Y + 1];
					if DD < DH then DH := DD;
					DP := Hot_Terr[ MM , TileTerrain( GB,X,Y) ] + 1 + HotMap[ N , X - 1 , Y + 1];
					if DP < DH then DH := DP;

					if DH < HotMap[ N , X , Y ] then begin
						HotMap[ N , X , Y ] := DH;
						flag := True;
					end;
				end;
			end;
		end;

	end;
end;

Procedure Calc_FollowMap( GB: GameBoardPtr; N,UID,MM: Integer );
	{ Unlike the SEEK AND DESTROY map, this map should have only }
	{ one hot spot. }
var
	M: GearPtr;
	P: Point;
begin
	M := GB^.Meks;
	while M <> Nil do begin
		P := GearCurrentLocation( M );
		if IsMasterGear( M ) and OnTheMap( GB , P.X , P.Y ) and GearOperational( M ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
		end else if ( M^.G = GG_MetaTerrain ) and ( M^.Stat[ STAT_Pass ] <= -100 ) and NotDestroyed( M ) and OnTheMap( GB , P.X , P.Y ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
		end;
		if NAttValue( M^.NA , NAG_EpisodeData , NAS_UID ) = UID then begin
			P := GearCurrentLocation( M );
			if OnTheMap( GB , P.X , P.Y ) then begin
				HotMap[ N , P.X , P.Y ] := 0;
				HotMapFloodFill( GB , N , MM );
			end;
		end;
		M := M^.Next;
	end;
end;

Procedure Calc_SpotMap( GB: GameBoardPtr; N,PDat,MM: Integer );
	{ Calculate a map seeking the described point. }
var
	M: GearPtr;
	P: Point;
begin
	{ Set the position for all blocking gears on the coldmap. }
	M := GB^.Meks;
	while M <> Nil do begin
		P := GearCurrentLocation( M );
		if IsMasterGear( M ) and OnTheMap( GB , P.X , P.Y ) and GearOperational( M ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
		end else if ( M^.G = GG_MetaTerrain ) and ( M^.Stat[ STAT_Pass ] <= -100 ) and NotDestroyed( M ) and OnTheMap( GB , P.X , P.Y ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
		end;
		M := M^.Next;
	end;

	{ Set the hot spot. }
	P.X := PDat mod ( GB^.Map_Width + 1 );
	P.Y := PDat div ( GB^.Map_Width + 1 );
	if OnTheMap( GB , P.X , P.Y ) then HotMap[ N , P.X , P.Y ] := 0;

	{ Increase the timer for this map, since we're dealing with a }
	{ stationary position, so the data should remain good for a }
	{ nice long time. }
	MapUpdate[ N ] := GB^.ComTime + 100;

	HotMapFloodFill( GB , N , MM );
end;

Procedure Calc_EdgeMap( GB: GameBoardPtr; N,PDat,MM: Integer );
	{ Calculate a map seeking the described edges. }
var
	M: GearPtr;
	P: Point;
	X,Y: Integer;
begin
	{ Set the position for all blocking gears on the coldmap. }
	M := GB^.Meks;
	while M <> Nil do begin
		P := GearCurrentLocation( M );
		if IsMasterGear( M ) and OnTheMap( GB , P.X , P.Y ) and GearOperational( M ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
		end else if ( M^.G = GG_MetaTerrain ) and ( M^.Stat[ STAT_Pass ] <= -100 ) and NotDestroyed( M ) and OnTheMap( GB , P.X , P.Y ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
		end;
		M := M^.Next;
	end;

	{ Set the hot spots. }
	for X := 1 to GB^.MAP_Width do begin
		if AngDir[ PDat , 2 ] = -1 then HotMap[ N , X , 1 ] := 0
		else if AngDir[ PDat , 2 ] = 1 then HotMap[ N , X , GB^.MAP_Height ] := 0;
	end;
	for Y := 1 to GB^.MAP_Height do begin
		if AngDir[ PDat , 1 ] = -1 then HotMap[ N , 1, Y ] := 0
		else if AngDir[ PDat , 1 ] = 1 then HotMap[ N , GB^.MAP_Width , Y ] := 0;
	end;

	{ Increase the timer for this map, since we're dealing with a }
	{ stationary position, so the data should remain good for a }
	{ nice long time. }
	MapUpdate[ N ] := GB^.ComTime + 100;

	HotMapFloodFill( GB , N , MM );
end;

Procedure Calc_RetreatMap( GB: GameBoardPtr; N,PDat,MM: Integer );
	{ Calculate a map seeking the edges. }
var
	M: GearPtr;
	P: Point;
	X,Y: Integer;
begin
	{ Set the position for all blocking gears on the coldmap. }
	M := GB^.Meks;
	while M <> Nil do begin
		P := GearCurrentLocation( M );
		if IsMasterGear( M ) and OnTheMap( GB , P.X , P.Y ) and GearOperational( M ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
		end else if ( M^.G = GG_MetaTerrain ) and ( M^.Stat[ STAT_Pass ] <= -100 ) and NotDestroyed( M ) and OnTheMap( GB , P.X , P.Y ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
		end;
		M := M^.Next;
	end;

	{ Set the hot spots. }
	for X := 1 to GB^.MAP_Width do begin
		HotMap[ N , X , 1 ] := 0;
		HotMap[ N , X , GB^.MAP_Height ] := 0;
	end;
	for Y := 1 to GB^.MAP_Height do begin
		HotMap[ N , 1, Y ] := 0;
		HotMap[ N , GB^.MAP_Width , Y ] := 0;
	end;

	{ Increase the timer for this map, since we're dealing with a }
	{ stationary position, so the data should remain good for a }
	{ nice long time. }
	MapUpdate[ N ] := GB^.ComTime + 100;

	HotMapFloodFill( GB , N , MM );
end;


Procedure Calc_SDMap( GB: GameBoardPtr; N,Team,MM: Integer );
	{ Calculate a SEEK AND DESTROY hotmap for a member of TEAM using }
	{ movement mode MM. }
var
	M: GearPtr;
	Flag: Boolean;
	P: Point;
begin
	{ Set the position for all enemies of the listed team to 0 on hotmap. }
	{ Set the position for all blocking gears on the coldmap. }
	M := GB^.Meks;
	flag := True;
	while M <> Nil do begin
		P := GearCurrentLocation( M );
		if IsMasterGear( M ) and OnTheMap( GB , P.X , P.Y ) and GearOperational( M ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
			if TeamCanSeeTarget( GB , Team , M ) and AreEnemies( GB , Team , NAttValue( M^.NA , NAG_Location , NAS_Team ) ) then begin
				HotMap[ N , P.X , P.Y ] := 0;
				Flag := False;
			end;
		end else if ( M^.G = GG_MetaTerrain ) and ( M^.Stat[ STAT_Pass ] <= -100 ) and NotDestroyed( M ) and OnTheMap( GB , P.X , P.Y ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
		end;
		M := M^.Next;
	end;

	{ If no visible enemies found, no point in continuing with the }
	{ algorithm. }
	if Flag then Exit;

	HotMapFloodFill( GB , N , MM );
end;

Procedure Calc_TeamMap( GB: GameBoardPtr; N,Team,MM: Integer );
	{ Calculate a FOLLOW TEAM hotmap for a member of TEAM using }
	{ movement mode MM. }
var
	M: GearPtr;
	Flag: Boolean;
	P: Point;
begin
	{ Set the position for all enemies of the listed team to 0 on hotmap. }
	{ Set the position for all blocking gears on the coldmap. }
	M := GB^.Meks;
	flag := True;
	while M <> Nil do begin
		P := GearCurrentLocation( M );
		if IsMasterGear( M ) and OnTheMap( GB , P.X , P.Y ) and GearOperational( M ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
			if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = Team ) then begin
				HotMap[ N , P.X , P.Y ] := 0;
				Flag := False;
			end;
		end else if ( M^.G = GG_MetaTerrain ) and ( M^.Stat[ STAT_Pass ] <= -100 ) and NotDestroyed( M ) and OnTheMap( GB , P.X , P.Y ) then begin
			Inc( ColdMap[ N , P.X , P.Y ] );
		end;
		M := M^.Next;
	end;

	{ If no visible enemies found, no point in continuing with the }
	{ algorithm. }
	if Flag then Exit;

	HotMapFloodFill( GB , N , MM );
end;

Procedure CalculateHotMap( GB: GameBoardPtr; N,Team,MM,O: Integer );
	{ Calculate a hot map, choosing type based on the ORDER given. }
var
	X,Y: Integer;
begin
	MapUpdate[n] := GB^.ComTime + Hot_Map_Validity;
	MapTeam[n] := Team;
	MapMoveMode[n] := MM;
	MapOrder[n] := O;

	{ Clear out the entire map, first. }
	For X := 1 to MaxMapWidth do begin
		For Y := 1 to MaxMapWidth do begin
			HotMap[ N , X , Y ] := 9999;
			ColdMap[ N , X , Y ] := 0;
		end;
	end;
	UpdateShadowMap( GB );

	if O = ORD_SeekSingleModel then begin
		Calc_FollowMap( GB , N , Team , MM );
	end else if O = ORD_SeekSpot then begin
		Calc_SpotMap( GB , N , Team , MM );
	end else if O = ORD_SeekEdge then begin
		Calc_EdgeMap( GB , N , Team , MM );
	end else if O = ORD_SeekTeam then begin
		Calc_TeamMap( GB , N , Team , MM );
	end else if O = ORD_SeekAnyEdge then begin
		Calc_RetreatMap( GB , N , Team , MM );
	end else begin
		Calc_SDMap( GB , N , Team , MM );
	end;
end;

Procedure ClearHotMaps;
	{ Clear all the currently processed floodfill maps. }
var
	t: Integer;
begin
	for t := 1 to NumFFMap do MapUpdate[ T ] := -1;
end;

Function GetHotMap( GB: GameBoardPtr; Team,MM,O: Integer ): Integer;
	{ Locate an appropriate HotMap for the data provided. }
var
	RepMap,GoodMap,T: Integer;
begin
	RepMap := 1;
	GoodMap := 0;
	for T := 1 to NumFFMap do begin
		if ( MapUpdate[ t ] >= GB^.ComTime ) and ( MapTeam[ t ] = Team ) and ( MapMoveMode[ t ] = MM ) and ( MapOrder[ t ] = O ) then begin
			GoodMap := T;
		end;
		if MapUpdate[ t ] < MapUpdate[ RepMap ] then RepMap := T;
	end;

	if GoodMap <> 0 then begin
		GetHotMap := GoodMap;
	end else begin
		CalculateHotMap( GB , RepMap , Team , MM , O );
		GetHotMap := RepMap;
	end;
end;

procedure AIAttacker( GB: GameBoardPtr; Mek,Weapon,Target: GearPtr );
	{ MEK wants to fire WEP at TAR. }
var
	AttSkillVal, DefSkillVal: Integer;	{ Used to calculate the chances of hitting. }
					{ Thanks to Peter Cordes }
	AtOp: Integer;
	T2,T3: GearPtr;
begin
	{ Calculate AttSkillVal, DefSkillVal, and set AtOp to 0. }
	DefSkillVal := BasicDefenseValue( FindRoot( Target ) );
	AttSkillVal := SkillValue( Mek , AttackSkillNeeded( Weapon ), AttackStatNeeded( Weapon ) ) + CalcTotalModifiers( gb , Weapon , Target , 0 , WeaponAttackAttributes( Weapon ) );
	AtOp := 0;

	{ If the odds of hitting are good enough, the attacker may try }
	{ to make a called shot. }
	if not NoCalledShots(WeaponAttackAttributes(Weapon),0) and (AttSkillVal-DefSkillVal > 4+Random(10))  and (Random(3) <> 1) and ((Weapon^.S <> GS_Ballistic) or (Weapon^.S <> GS_BeamGun) or (Random(6)+Random(6) > Weapon^.Stat[STAT_BurstValue])) then begin
		T2 := Target^.SubCom;

		if WeaponDC( Weapon ) > 10 then begin
			{ If using a powerful weapon, do aimed shot at the torso. }
			while ( T2 <> Nil ) and (( T2^.G <> GG_Module ) or ( T2^.S <> GS_Body )) do T2 := T2^.Next;

		end else if T2 <> Nil then begin
			{ If using a less powerful weapon, do aimed shot at the part with the lowest armor. }
			T3 := Nil;
			while T2 <> Nil do begin
				if T3 = Nil then T3 := T2
				else if GearCurrentArmor( T2 ) < GearCurrentArmor( T3 ) then T3 := T2;
				T2 := T2^.Next;
			end;
			T2 := T3;
		end;

		if T2 <> Nil then Target := T2;

	end else if ( Weapon^.G = GG_Weapon ) then begin
		{ If not making a called shot, the attacker will take }
		{ advantage of rapid fire if possible. }
		if ( Weapon^.S = GS_Ballistic ) and ( Weapon^.Stat[ STAT_BurstValue ] > 0 ) then begin
			AtOp := Weapon^.Stat[ STAT_BurstValue ];
		end else if ( Weapon^.S = GS_BeamGun ) and ( Weapon^.Stat[ STAT_BurstValue ] > 0 ) then begin
			AtOp := Weapon^.Stat[ STAT_BurstValue ];
		end else if Weapon^.S = GS_Missile then begin
			AtOp := Random( 10 );
		end;
	end;

	AttackerFrontEnd( GB , Mek , Weapon , Target , AtOp );

	{ Set the initiative recharge counter. }
	SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_InitRecharge , GB^.ComTime + ReactionTime( Mek ) );
end;

procedure SelectMoveMode( Mek: GearPtr; GB: GameBoardPtr );
	{ Set the mek's MoveMode attribute to the highest }
	{ active movemode that this mek has. }
var
	T,MM,MaxSpeed: Integer;
	P: Point;
begin
	MM := 0;
	MaxSpeed := 0;
	P := GearCurrentLocation( Mek );
	for T := 1 to NumMoveMode do begin
		if ( BaseMoveRate( GB^.Scene , Mek , T ) > MaxSpeed ) and MoveLegal( GB^.Scene , Mek , T , NAV_NormSpeed , GB^.Comtime ) and TerrMan[ TileTerrain( GB , P.X , P.Y ) ].MMPass[t] then begin
			if not ( ( GB <> Nil ) and ( GB^.Scale > Mek^.Scale ) and ( T = MM_Fly ) and ( JumpTime( GB^.Scene , Mek ) > 0 ) ) then begin
				MM := T;
				MaxSpeed := BaseMoveRate( GB^.Scene , Mek , T );
			end;
		end;
	end;
	if MM <> 0 then SetMoveMode( GB , Mek , MM);
end;

Function SelectBestWeapon( GB: GameBoardPtr; Mek,Target: GearPtr ): GearPtr;
	{ Select the best weapon for attacking TARGET with. }
var
	weapon: GearPtr;
	BestWeight: LongInt;
	function SafeToFire( Part: GearPtr ): Boolean;
		{ Return TRUE if firing this weapon won't cause a huge problem, }
		{ or FALSE otherwise. }
	var
		Found: Boolean;
		R: Integer;
		P: Point;
		M2: GearPtr;
	begin
		{ First off, dumb things won't care if it's safe to fire or not. }
		if ( Mek^.G = GG_Character ) and ( Mek^.Stat[ STAT_Knowledge ] < RollStep( 5 ) ) then begin
			Exit( True );
		end;

		{ Check to see if this is a blast weapon. }
		if HasAttackAttribute( WeaponAttackAttributes( Part ) , AA_BlastAttack ) then begin
			{ If there's an ally within the blast radius, this weapon isn't safe. }
			P := GearCurrentLocation( Target );
			M2 := GB^.Meks;
			R := BlastRadius( GB , Part , WeaponAttackAttributes( Part ) );
			Found := False;
			while M2 <> Nil do begin
				if AreAllies( GB , Mek , M2 ) and ( Range( M2 , P.X , P.Y ) < R ) then Found := True;
				M2 := M2^.Next;
			end;
			SafeToFire := Not Found;
		end else begin
			{ The blastattack check is the only one I'm doing yet. }
			SafeToFire := True;
		end;
	end;

	function WGoodness( Part, Target: GearPtr ): Integer;
		{ This is the heuristic SeekBigWeapon uses }
	var
		WG,AS,AM,BV,AAV		 : Integer;
		AttSkillVal, DefSkillVal : Integer;
		AtAt: String;
	begin
		{ Can your lancemates size up the abilities of a defender in a }
		{ mecha, very far away, in heavy cover?  Sure they can! }
		{ Just look at Piloting or Dodge, not talents, parrying, ... }
		DefSkillVal := BasicDefenseValue( FindRoot( Target ) );

		{ NOTE: the actual attack code does RollStep(SkillValue) + }
		{ modifiers, so this is an approximation }
		{ Missiles will have BustValue = 0.  Don't fire }
		{ until you can see the whites of their eyes. }
		AS := SkillValue( FindRoot(Part) , AttackSkillNeeded( Part ) , AttackStatNeeded( Part ) );
		AM := CalcTotalModifiers( gb , Part , Target , Part^.Stat[ STAT_BurstValue ] , WeaponAttackAttributes( Part ) );
		AttSkillVal := AS + AM + 5 - DefSkillVal;
		if AttSkillVal < 0 then AttSkillVal := 0;

		if ( Part^.G = GG_Weapon ) and (( Part^.S = GS_Ballistic ) or ( Part^.S = GS_BeamGun )) then begin
			BV := 1 + Part^.Stat[ STAT_BurstValue ];
		end else if ( Part^.G = GG_Weapon ) and ( Part^.S = GS_Missile ) then begin
			BV := 2;
		end else begin
			BV := 3;
		end;

		{ Apply special modifiers to BV. }
		AtAt := WeaponAttackAttributes( Part );
		AAV := AttackAttributeValue( AtAt ) - 10;
		if AAV < 0 then AAV := 0;

		WG := WeaponDC( Part ) * BV + AAV + 2 * AttSkillVal;
		for AS := 1 to Part^.Scale do WG := WG * 3;

		{ Debugging message
		DialogMsg( PilotName( Mek ) + '/' + GearName( Part ) + ': ' + BStr( WG ) );
		DialogMsg( '- -  DC: ' + BStr( WeaponDC( Part ) ) + ', BV:' + BStr( BV ) + ', AtAt:' + BStr( AAV ) + ', AtSkill:' + BStr( AttSkillVal ) );
		}
		WGoodness := WG;
	end;

	procedure SeekBigWeapon( Part: GearPtr );
		{ Seek a weapon which is capable of hitting target. }
		{ Select the best weapon, weighted by accuracy and damage }
		{ Things we don't do: }
		{   * scale factors }
		{   * avoid wasting ammo/recharge time on easy-to-kill targets }
		{	(it would be worth working on the target selection }
		{	algorithm if you were going to do anything about this. }
		{	Maybe find your best weapon and look for targets to }
		{	fire it at.  This could help a lot with LINE weapons. }
		{	Or even find a weight for every weapon/target pair...) }
	var
		Weight : Integer;
	begin
		while ( Part <> Nil ) do begin
			if ( Part^.G = GG_Module ) or ( Part^.G = GG_Weapon ) then begin
				if ReadyToFire( GB , Mek , Part ) and RangeArcCheck( GB , Mek , Part , Target ) and SafeToFire( Part ) then begin
					if Weapon = Nil then begin
						Weapon := Part;
						BestWeight := WGoodness(Part, Target);
					end else begin
						Weight := WGoodness(Part, Target);
						{  BestWeight is a variable in the parent procedure.  I don't know how else to do this in Pascal... }
						if Weight > BestWeight then begin
							Weapon := Part;
							BestWeight := Weight;
						end;
					end;				end;
			end;
			if ( Part^.SubCom <> Nil ) then SeekBigWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekBigWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;

begin
	Weapon := Nil;
	BestWeight := -10000;
	SeekBigWeapon( Mek^.SubCom );
	SeekBigWeapon( Mek^.InvCom );
	SelectBestWeapon := Weapon;
end;

Function SelectRandomUsable( Mek: GearPtr ): GearPtr;
	{ Select a random usable gear from this mecha. }
var
	ShoppingList: NAttPtr;
	N: Integer;
	Procedure CheckAlongPath( LList: GearPtr );
		{ Check along this path for usable gears. Don't check the inventory }
		{ or along paths which have been destroyed. }
	begin
		while LList <> Nil do begin
			if NotDestroyed( LList ) then begin
				if LList^.G = GG_Usable then begin
					Inc( N );
					SetNAtt( ShoppingList , N , 0 , FindGearIndex( Mek , LList ) );
				end;
				CheckAlongPath( LList^.SubCom );
			end;
			LList := LList^.Next;
		end;
	end;
var
	Part: GearPtr;
begin
	ShoppingList := Nil;
	N := 0;
	CheckAlongPath( Mek^.SubCom );
	Part := Nil;

	if N > 0 then begin
		N := NAttValue( ShoppingList , Random( N ) + 1 , 0 );
		Part := LocateGearByNumber( Mek , N );
	end;

	DisposeNAtt( ShoppingList );
	SelectRandomUsable := Part;
end;

Procedure AttemptSpecialAction( GB: GameBoardPtr; Mek: GearPtr );
	{ The enemy can't attack just now. See if there's anything else }
	{ worth doing. }
var
	Part: GearPtr;
begin
	if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_SpecialActionRecharge ) > GB^.ComTime then Exit;

	{ Select one of this mecha's special systems at random. }
	Part := SelectRandomUsable( Mek );
	if Part <> Nil then begin
		if Part^.S = GS_Transformation then begin
			if AIShouldTransform( GB , Mek , Part ) then begin
				DoTransformation( GB , Mek , Part , True );
				SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_SpecialActionRecharge , GB^.ComTime + 150 + Random( 50 ) );
			end;
		end else if Part^.S = GS_LongRangeScanner then begin
			if AIShouldLRScan( GB , Mek , Part ) then begin
				DoLongRangeScan( GB , Mek , Part );
				SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_SpecialActionRecharge , GB^.ComTime + 150 + Random( 50 ) );
			end;
		end;
	end;
end;

Procedure AttackTargetOfOppurtunity( GB: GameBoardPtr; Mek: GearPtr );
	{ Look for the most oppurtune target to attack. }
var
	weapon: GearPtr;
	TL,Target: GearPtr;
	CouldAttack: Boolean;
{ *** PROCEDURES BLOCK *** }
	procedure SeekFarWeapon( Part: GearPtr );
		{ Find the weapon with the longest current range. }
	begin
		while ( Part <> Nil ) do begin
			if ( Part^.G = GG_Module ) or ( Part^.G = GG_Weapon ) then begin
				if ReadyToFire( GB , Mek , Part ) then begin
					if Weapon = Nil then Weapon := Part
					else if WeaponRange( GB , Part , RANGE_Long ) > WeaponRange( GB , Weapon , RANGE_Long ) then Weapon := Part;
				end;
			end;
			if ( Part^.SubCom <> Nil ) then SeekFarWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekFarWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;

begin
	{ First, check to make sure that the mecha hasn't attacked }
	{ too recently. }
	if NAttValue( Mek^.NA , NAG_EpisodeData , NAS_InitRecharge ) > GB^.ComTime then Exit;

	{ Assume FALSE unless proven TRUE. }
	CouldAttack := False;

	{ Start by finding a good weapon to fire with. }
	{ Preference will be given to the weapon with the longest range. }
	Weapon := Nil;
	SeekFarWeapon( Mek^.SubCom );
	SeekFarWeapon( Mek^.InvCom );

	if Weapon <> Nil then begin
		{ Next, see if we have an appropriate target. }
		Target := Nil;
		TL := gb^.meks;

		while TL <> Nil do begin
			if AreEnemies( GB , Mek , TL ) and OnTheMap( GB , TL ) and RangeArcCheck( GB , Mek , Weapon , TL ) and GearActive( TL ) and MekCanSeeTarget( GB , Mek , TL ) then begin
				if Target = Nil then Target := TL
				else if Range( gb , Target , Mek ) > Range( gb , TL , Mek ) then Target := TL;
			end;
			TL := TL^.Next;
		end;

		{ If a target was found, fire at that target with the }
		{ biggest weapon in the arsenal. }
		if Target <> Nil then begin
			Weapon := SelectBestWeapon( GB , Mek , Target );
			if Weapon <> Nil then begin
				AIAttacker( GB , Mek , Weapon , Target );
				CouldAttack := True;
			end;
		end;
	end;

	{ If we couldn't attack, attempt some other combat action, maybe. }
	if not CouldAttack then AttemptSpecialAction( GB , Mek );
end;

Procedure Wander( Mek: GearPtr; GB: GameBoardPtr );
	{ Just wander about. This procedure is often called when }
	{ conventional pathfinding methods have failed. It is also }
	{ used as the "SEEK" part of "SEEK AND DESTROY". }
var
	P: Point;
	CD: Integer;
begin
	{ Determine current facing and position. }
	P := GearCurrentLocation( Mek );
	CD := NAttValue( Mek^.NA , NAG_Location , NAS_D );

	{ If the current direction of travel doesn't lead off the map, }
	{ and isn't blocked, just move foreword. }
	if OnTheMap( GB , P.X + AngDir[ CD , 1 ] , P.Y + AngDir[ CD , 2 ] ) and ( Random( 5 ) <> 1 ) and not MoveBlocked( Mek , GB ) then begin
		if Mek^.G = GG_Mecha then begin
			PrepAction( GB , Mek , NAV_FullSpeed );
		end else begin
			PrepAction( GB , Mek , NAV_NormSpeed );
		end;
	end else begin
		if Random( 2 ) = 1 then begin
			PrepAction( GB , Mek , NAV_TurnRight );
		end else begin
			PrepAction( GB , Mek , NAV_TurnLeft );
		end;
	end;
end;

Function XMoveTowardsGoal( GB: GameBoardPtr; Mek: GearPtr; HM,OptMax,OptMin: Integer ): Boolean;
	{ Using hotmap N as a guide, attempt to move towards the goal. }
	{ OPTMAX and OPTMIN describe the maximum and minumum hotmap values the mek will }
	{ try to reach. If its current location has a hot value lower than OptMax, it }
	{ will stay in that spot. If its current location is lower than OptMin, it will }
	{ attempt to move to a location with a higher hot value. }
	Function ThisMoveIsOkay( MAct,X,Y: Integer; P: Point ): Boolean;
		{ This function combines two checks: Whether or not the target tile is }
		{ unblocked, and whether or not the specified moveaction is legal. }
	begin
		ThisMoveIsOkay := MoveLegal( GB^.Scene , Mek , MAct , GB^.ComTime ) and not MovementBlocked( Mek , GB , P.X , P.Y , X , Y );
	end;
var
	P,P2: Point;
	T,D,Best,CD: Integer;
begin
	P := GearCurrentLocation( Mek );

	{ If our current direction of travel is bringing us closer to the }
	{ target, keep moving in that direction, even if it isn't the }
	{ optimal path. }
	CD := NAttValue( Mek^.NA , NAG_Location , NAS_D );
	if HotMap[ HM , P.X ,P.Y ] < OptMin then begin
		{ Too close to the target- move farther away. }
		P2.X := P.X + AngDir[ ( CD + 4 ) mod 8 , 1 ];
		P2.Y := P.Y + AngDir[ ( CD + 4 ) mod 8 , 2 ];
		if OnTheMap( GB , P2.X , P2.Y ) and ( HotMap[ HM , P2.X , P2.Y ] > HotMap[ HM , P.X , P.Y ] ) and ThisMoveIsOkay( NAV_Reverse , P2.X , P2.Y , P ) then begin
			PrepAction( GB , Mek , NAV_Reverse );
			XMoveTowardsGoal := True;

		end else if OnTheMap( GB , P.X + AngDir[ CD , 1 ] , P.Y + AngDir[ CD , 2 ] ) and ( HotMap[ HM , P.X + AngDir[ CD , 1 ] , P.Y + AngDir[ CD , 2 ] ] > HotMap[ HM , P.X , P.Y ] ) and ThisMoveIsOkay( NAV_NormSpeed , P.X + AngDir[ CD , 1 ] , P.Y + AngDir[ CD , 2 ] , P ) then begin
			if Mek^.G = GG_Character then begin
				PrepAction( GB , Mek , NAV_NormSpeed );
			end else begin
				PrepAction( GB , Mek , NAV_FullSpeed );
			end;
			XMoveTowardsGoal := True;

		end else begin
			D := -1;
			Best := HotMap[ HM , P.X , P.Y ];
			for t := 0 to 7 do begin
				if OnTheMap( GB , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ) then begin
					if ( HotMap[ HM , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ] > Best ) and ( ColdMap[ HM , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ] < 1 ) and not MovementBlocked( Mek , GB , P.X , P.Y , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ) then begin
						Best := HotMap[ HM , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ];
						D := T;
					end;
				end;
			end;

			if D <> -1 then begin
				if CD <> D then begin
					Best := NAV_TurnRight;
					for t := 1 to 4 do begin
						if (( CD + T ) mod 8 ) = D then Best := NAV_TurnRight
						else if (( CD + 8 - T ) mod 8 ) = D then Best := NAV_TurnLeft;
					end;
					PrepAction( GB , Mek , Best );

				end else begin
					PrepAction( GB , Mek , NAV_FullSpeed );
				end;
				XMoveTowardsGoal := True;

			end else begin
				{ If we don't have a good place to go, }
				{ try changing move modes to the lowest. }
				if Random( 2 ) = 1 then begin
					ShiftGears( GB , Mek , False );
				end;
				XMoveTowardsGoal := False;
			end;
		end;

	end else if ( HotMap[ HM , P.X ,P.Y ] < OptMax ) and ( ( Random( 15 ) < HotMap[ HM , P.X ,P.Y ] ) or IsInCover( GB , Mek ) ) then begin
		{ Within optimal range. Turn to hopefully face a target. }
		D := -1;
		Best := HotMap[ HM , P.X , P.Y ];
		for t := 0 to 7 do begin
			if OnTheMap( GB , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ) then begin
				if ( HotMap[ HM , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ] < Best ) then begin
					Best := HotMap[ HM , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ];
					D := T;
				end;
			end;
		end;

		{ If a good direction was found, turn to face it. }
		{ Otherwise assume that we're already facing a good direction. }
		if D <> -1 then begin
			if CD <> D then begin
				Best := NAV_TurnRight;
				for t := 1 to 4 do begin
					if (( CD + T ) mod 8 ) = D then Best := NAV_TurnRight
					else if (( CD + 8 - T ) mod 8 ) = D then Best := NAV_TurnLeft;
				end;
				PrepAction( GB , Mek , Best );
			end else begin
				WaitAMinute( GB , Mek , ReactionTime( Mek ) );
			end;
		end else begin
			{ If we don't have a good place to go, }
			{ try changing move modes to the lowest. }
			if Random( 2 ) = 1 then begin
				ShiftGears( GB , Mek , False );
			end;
			WaitAMinute( GB , Mek , ReactionTime( Mek ) );
		end;
		XMoveTowardsGoal := True;


	end else if OnTheMap( GB , P.X + AngDir[ CD , 1 ] , P.Y + AngDir[ CD , 2 ] ) and ( HotMap[ HM , P.X + AngDir[ CD , 1 ] , P.Y + AngDir[ CD , 2 ] ] < HotMap[ HM , P.X , P.Y ] ) and ( HotMap[ HM , P.X , P.Y ] < Random( 4 ) ) and not MoveBlocked( Mek , GB ) then begin
		if (( Mek^.G = GG_Mecha ) or ( CurrentStamina( Mek ) > 10 ) ) and MoveLegal( GB^.Scene , Mek , NAV_FullSpeed , GB^.ComTime ) then begin
			PrepAction( GB , Mek , NAV_FullSpeed );
		end else if MoveLegal( GB^.Scene , Mek , NAV_NormSpeed , GB^.ComTime ) then begin
			PrepAction( GB , Mek , NAV_NormSpeed );
		end else begin
			Exit( False );
		end;
		XMoveTowardsGoal := True;

	end else begin
		{ Check to see if there's a better direction we can be moving in. }
		D := -1;
		Best := HotMap[ HM , P.X , P.Y ];
		for t := 0 to 7 do begin
			if OnTheMap( GB , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ) then begin
				if ( HotMap[ HM , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ] < Best ) and ( ColdMap[ HM , P.X + AngDir[T,1] , P.Y + AngDir[T,2] ] < 1 ) and not MovementBlocked( Mek,GB,P.X,P.Y,P.X + AngDir[T,1] , P.Y + AngDir[T,2]) then begin
					Best := HotMap[ HM , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ];
					D := T;
				end;
			end;
		end;

		if D <> -1 then begin
			if CD <> D then begin
				Best := NAV_TurnRight;
				for t := 1 to 4 do begin
					if (( CD + T ) mod 8 ) = D then Best := NAV_TurnRight
					else if (( CD + 8 - T ) mod 8 ) = D then Best := NAV_TurnLeft;
				end;
				PrepAction( GB , Mek , Best );

			end else begin
				if MoveBlocked( Mek , GB ) then begin
					Exit( False );
				end else if ( HotMap[ HM , P.X ,P.Y ] > ( OptMax * 3 div 2 ) ) and (( Mek^.G = GG_Mecha ) or ( CurrentStamina( Mek ) > 10 ) ) and MoveLegal( GB^.Scene , Mek , NAV_FullSpeed, GB^.ComTime ) then begin
					PrepAction( GB , Mek , NAV_FullSpeed );
				end else if MoveLegal( GB^.Scene , Mek , NAV_NormSpeed, GB^.ComTime ) then begin
					PrepAction( GB , Mek , NAV_NormSpeed );
				end else begin
					Exit( False );
				end;
			end;
			XMoveTowardsGoal := True;

		end else begin
			{ If we don't have a good place to go, }
			{ try changing move modes to the lowest. }
			if Random( 2 ) = 1 then begin
				ShiftGears( GB , Mek , False );
			end;
			XMoveTowardsGoal := False;
		end;
	end;
end;

Procedure MoveTowardsGoal( GB: GameBoardPtr; Mek: GearPtr; HM: Integer );
	{ Front-end for the Extended Move Towards Goal. }
begin
	if not XMoveTowardsGoal( GB , Mek , HM , 0 , 0 ) then Wander( Mek , GB );
end;


Function DoorPresent( GB: GameBoardPtr; X,Y: Integer ): Boolean;
	{ Return TRUE if there's a door here which a passive NPC shouldn't pass. }
begin
	if not OnTheMap( GB , X , Y ) then begin
		DoorPresent := False;
	end else begin
		DoorPresent := TileTerrain( GB , X , Y ) = TERRAIN_Threshold;
	end;
end;

Procedure MillAround( GB: GameBoardPtr; Mek: GearPtr );
	{ Stay in roughly the same position, wander around a little bit. }
var
	P,P0: Point;
	D: Integer;
begin
	{ No reason to panic. Just stand around; }
	{ maybe move if it's okay. }
	if Random( 3 ) = 1 then begin
		PrepAction( GB , Mek , NAV_Stop );
	end else if Random( 3 ) = 1 then begin
		{ The passive character may walk sometimes. }
		P0 := GearCurrentLocation( Mek );
		D := NAttValue( Mek^.NA , NAG_Location , NAS_D );
		P.X := P0.X + AngDir[ D , 1 ];
		P.Y := P0.Y + AngDir[ D , 2 ];
		if OnTheMap( GB , P.X , P.Y ) then begin
			{ Don't move foreword if the move is blocked }
			{ or if the move would take the character over }
			{ the threshold of a door. }
			if MovementBlocked( Mek , GB , P0.X , P0.Y , P.X , P.Y ) or DoorPresent( GB , P.X , P.Y ) then begin
				PrepAction( GB , Mek , NAV_Stop );
			end else begin
				PrepAction( GB , Mek , NAV_NormSpeed );
			end;
		end;
	end else begin
		if Random( 2 ) = 1 then begin
			PrepAction( GB , Mek , NAV_TurnRight );
		end else begin
			PrepAction( GB , Mek , NAV_TurnLeft );
		end;
	end;
end;

Procedure FleeFromGoal( GB: GameBoardPtr; Mek: GearPtr; HM: Integer );
	{ Using hotmap N as a guide, attempt to move away from the goal. }
var
	P: Point;
	T,D,Best,CD: Integer;
begin
	P := GearCurrentLocation( Mek );

	{ If our current direction of travel is bringing us closer to the }
	{ target, keep moving in that direction, even if it isn't the }
	{ optimal path. }
	CD := NAttValue( Mek^.NA , NAG_Location , NAS_D );
	if OnTheMap( GB , P.X + AngDir[ CD , 1 ] , P.Y + AngDir[ CD , 2 ] ) and ( HotMap[ HM , P.X + AngDir[ CD , 1 ] , P.Y + AngDir[ CD , 2 ] ] > HotMap[ HM , P.X , P.Y ] ) and ( HotMap[ HM , P.X , P.Y ] > Random( 8 ) ) and not MoveBlocked( Mek , GB ) then begin
		PrepAction( GB , Mek , NAV_NormSpeed );

	end else begin
		D := -1;
		Best := HotMap[ HM , P.X , P.Y ];
		for t := 0 to 7 do begin
			if OnTheMap( GB , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ) then begin
				if ( HotMap[ HM , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ] > Best ) and ( ColdMap[ HM , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ] < 1 ) then begin
					Best := HotMap[ HM , P.X + AngDir[ T , 1 ] , P.Y + AngDir[ T , 2 ] ];
					D := T;
				end;
			end;
		end;



		if D <> -1 then begin
			if CD <> D then begin
				Best := NAV_TurnRight;
				for t := 1 to 4 do begin
					if (( CD + T ) mod 8 ) = D then Best := NAV_TurnRight
					else if (( CD + 8 - T ) mod 8 ) = D then Best := NAV_TurnLeft;
				end;
				PrepAction( GB , Mek , Best );

			end else begin
				PrepAction( GB , Mek , NAV_NormSpeed );
			end;
		end else begin
			MillAround( GB , Mek );
		end;
	end;

end;

Function HotMoveMode( Mek: GearPtr ): Integer;
	{ Return the current move mode of this mecha, adjusted for }
	{ characters who are walking. }
var
	T: Integer;
begin
	T := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	if ( T = MM_Walk ) and ( Mek^.G = GG_Character ) then T := 0;
	HotMoveMode := T;
end;

Procedure AIRepair( GB: GameBoardPtr; NPC,Target: GearPtr; Skill: Integer );
	{ This procedure acts as a frontend for the repair skill bits. }
begin
	if not DoFieldRepair( GB , NPC , Target , Skill ) then begin
		SetNAtt( NPC^.NA , NAG_EpisodeData , NAS_ContinuousOrders , 0 );
	end;
end;

Function SelectRepairTarget( GB: GameBoardPtr; Mek: GearPtr; Skill: Integer ): GearPtr;
	{ Locate a target that needs repairs. }
var
	T,BTar: GearPtr;
	Best,Dmg: Integer;
begin
	T := GB^.Meks;
	BTar := Nil;
	Best := 0;

	while T <> Nil do begin
		if AreAllies( GB , Mek , T ) and ( ( T^.G = GG_Character ) or ( SAttValue( T^.SA , 'pilot' ) <> '' ) ) then begin
			Dmg := RepairNeededBySkill( T , Skill );
			if ( Dmg > Best ) and CanRepairUsingSKill( Mek , T , Skill ) then begin
				BTar := T;
				Best := Dmg;
			end;
		end;
		T := T^.Next;
	end;

	SelectRepairTarget := BTar;
end;

Function SelectSocialTarget( GB: GameBoardPtr; NPC: GearPtr; MustBeSexy: Boolean ): GearPtr;
	{ Select a character for NPC to interact with. }
var
	M,Target: GearPtr;
	N,Team: Integer;
	Function IsGoodSocTarget: Boolean;
		{ Return TRUE if M is a good target, or FALSE otherwise. }
	begin
		if ( NAttValue( M^.NA , NAG_Personal , NAS_CID ) = 0 ) or ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = Team ) or ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then begin
			IsGoodSocTarget := False;
		end else if not NotAnAnimal( M ) then begin
			IsGoodSocTarget := False;
		end else if MustBeSexy then begin
			IsGoodSocTarget := GearActive( M ) and ( not AreEnemies( GB , NPC , M ) ) and IsSexy( NPC , M );
		end else begin
			IsGoodSocTarget := GearActive( M ) and ( not AreEnemies( GB , NPC , M ) );
		end;
	end;
begin
	{ Make two passes. On the first pass, just count the number of candidates. }
	{ On the second pass actually select one. }
	N := 0;
	Target := Nil;
	M := GB^.Meks;
	Team := NAttValue( NPC^.NA , NAG_Location , NAS_Team );
	while M <> Nil do begin
		if IsGoodSocTarget then Inc( N );
		M := M^.Next;
	end;

	{ If any potential targets were found, pick one of them at random. }
	if N > 0 then begin
		M := GB^.Meks;
		N := Random( N );
		while M <> Nil do begin
			if IsGoodSocTarget then begin
				Dec( N );
				if N = -1 then Target := M;
			end;
			M := M^.Next;
		end;
	end;

	SelectSocialTarget := Target;
end;

{Procedure NPC_Flirtation( GB: GameBoardPtr; NPC , Target: GearPtr );
	{ NPC will flirt with TARGET. If successful, this will cause the PC to gain }
	{ a reaction bonus from TARGET. }
var
	skRoll: Integer;
	CID: LongInt;
	msg: String;
	M,PC: GearPtr;
begin
	SkRoll := RollStep( SkillValue( NPC , 27 ) );
	if SkRoll > 15 then begin
		{ Report the success. }
		msg := MsgString( 'NPCFLIRT_Good' );
		msg := ReplaceHash( msg , PilotName( NPC ) );
		msg := ReplaceHash( msg , PilotName( TARGET ) );
		DialogMsg( msg );

		{ Success! Improve the reaction score. }
		CID := NAttValue( Target^.NA , NAG_Personal , NAS_CID );
		M := GB^.Meks;
		while M <> Nil do begin
			if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and GearActive( M ) then begin
				PC := LocatePilot( M );
				if PC <> Nil then AddNAtt( PC^.NA , NAG_ReactionScore , CID , 1 + Random( 3 ) );
			end;
			M := M^.Next;
		end;
	end else if SkRoll > 5 then begin
		{ Okay... neither good nor bad. }
		msg := MsgString( 'NPCFLIRT_Okay' );
		msg := ReplaceHash( msg , PilotName( NPC ) );
		msg := ReplaceHash( msg , PilotName( TARGET ) );
		DialogMsg( msg );
	end else begin
		{ Bad. This is just bad. }
		AddMoraleDmg( NPC , 15 );
		msg := MsgString( 'NPCFLIRT_Bad' );
		msg := ReplaceHash( msg , PilotName( TARGET ) );
		msg := ReplaceHash( msg , PilotName( NPC ) );
		DialogMsg( msg );
	end;
end;}

{Procedure NPC_Chatting( GB: GameBoardPtr; NPC , Target: GearPtr );
	{ NPC will chat with TARGET. This may reveal a rumor. }
var
	skRoll: Integer;
	msg: String;
	Rumors: SAttPtr;
begin
	SkRoll := SkillRoll( GB , NPC , NAS_Conversation , STAT_Charm , 10 , 0 , False, True );
	if SkRoll > 10 then begin
		{ A rumor has been gained. }
		rumors := CreateRumorList( GB , Nil , Target );

		if rumors <> Nil then begin
			msg := MsgString( 'NPCCHAT_Good' );
			msg := ReplaceHash( msg , PilotName( NPC ) );
			msg := msg + ' ' + SelectRandomSAtt( Rumors )^.info;
			DisposeSAtt( Rumors );
		end else begin
			msg := MsgString( 'NPCCHAT_Okay' );
			msg := ReplaceHash( msg , PilotName( NPC ) );
			msg := ReplaceHash( msg , PilotName( TARGET ) );
		end;

		DialogMsg( msg );
	end else begin
		{ Okay... neither good nor bad. }
		msg := MsgString( 'NPCCHAT_Okay' );
		msg := ReplaceHash( msg , PilotName( NPC ) );
		msg := ReplaceHash( msg , PilotName( TARGET ) );
		DialogMsg( msg );
	end;
end;}

Procedure LancemateUsefulAction( Mek: GearPtr; GB: GameBoardPtr );
	{ Do something useful! There are no enemies to be found... }
const
	Num_AI_Repair = 2;
	AI_Repair_List: Array [1..Num_AI_Repair] of Byte = (
		NAS_Medicine, NAS_Repair
	);
var
	HM,Target,T: Integer;
	NPC,TGear,Tool: GearPtr;
	CORD: Integer;	{ Continuous Orders }
begin
	{ See if there are any pending actions. }
	CORD := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders );

	{ If CORD < 0 , use a repair skill. }
	if CORD < 0 then begin
		Target := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_ATarget );
		TGear := LocateMekByUID( GB , Target );

		{ If this gear no longer needs repairs, quit. }
		if ( TGear = Nil ) or ( not CanRepairUsingSkill( Mek , TGear , Abs( CORD ) ) ) or ( CurrentMental( Mek ) < 1 ) then begin
			{ Clear the continuous action. }
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders , 0 );

		end else if OnTheMap( GB , TGear ) then begin
			{ If on the map, NPC must move towards TARGET. }
			if Range( GB , Mek , TGear ) > 3 then begin
				HM := GetHotMap( GB , Target , HotMoveMode( Mek ) , ORD_SeekSingleModel );
				MoveTowardsGoal( GB , Mek , HM );
			end else begin
				AIRepair( GB , Mek , TGear , Abs( CORD ) );
			end;

		end else begin
			{ If off the map, NPC can just autorepair it. }
			AIRepair( GB , Mek , TGear , Abs( CORD ) );
		end;

{	end else if CORD = CORD_Flirt then begin
		Target := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_ATarget );
		TGear := LocateMekByUID( GB , Target );

		{ If this gear no longer qualifies, quit. }
		if ( TGear = Nil ) or AreEnemies( GB , Mek , TGear ) or ( Destroyed( TGear ) ) then begin
			{ Clear the continuous action. }
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders , 0 );

		end else if OnTheMap( GB , TGear ) then begin
			{ If on the map, NPC must move towards TARGET. }
			if Range( GB , Mek , TGear ) > 3 then begin
				{ If the move cannot proceed, cancel the action. }
				HM := GetHotMap( GB , Target , HotMoveMode( Mek ) , ORD_SeekSingleModel );
				if not XMoveTowardsGoal( GB , Mek , HM , 0 , 0 ) then SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders , 0 );
			end else begin
				{ Close enough to flirt. Yay! }
				NPC_Flirtation( GB, Mek , TGEar );
				WaitAMinute( GB , Mek , ReactionTime( Mek ) * 5 );
				SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders , 0 );
			end;

		end else begin
			{ If off the map, cancel the action. }
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders , 0 );
		end;

	end else if CORD = CORD_Chat then begin
		Target := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_ATarget );
		TGear := LocateMekByUID( GB , Target );

		{ If this gear no longer qualifies, quit. }
		if ( TGear = Nil ) or AreEnemies( GB , Mek , TGear ) or ( Destroyed( TGear ) ) then begin
			{ Clear the continuous action. }
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders , 0 );

		end else if OnTheMap( GB , TGear ) then begin
			{ If on the map, NPC must move towards TARGET. }
			if Range( GB , Mek , TGear ) > 3 then begin
				{ If the move cannot proceed, cancel the action. }
				HM := GetHotMap( GB , Target , HotMoveMode( Mek ) , ORD_SeekSingleModel );
				if not XMoveTowardsGoal( GB , Mek , HM , 0 , 0 ) then SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders , 0 );
			end else begin
				{ Close enough to flirt. Yay! }
				NPC_Chatting( GB, Mek , TGEar );
				WaitAMinute( GB , Mek , ReactionTime( Mek ) * 5 );
				SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders , 0 );
			end;

		end else begin
			{ If off the map, cancel the action. }
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders , 0 );
		end;
}
	end else begin
		{ Attempt to find a useful thing to do. }
		{ Locate the NPC proper. }
		NPC := LocatePilot( Mek );

		{ Check to see whether or not this NPC has any repair skills }
		{ to use. }
		t := 1;
		Target := 0;
		CORD := 0;
		if CurrentMental( Mek ) > 0 then begin
			while ( t <= Num_AI_Repair ) and ( Target = 0 ) do begin
				if ( NAttValue( NPC^.NA , NAG_Skill , AI_Repair_List[ t ] ) > 0 ) then begin
					TGear := SelectRepairTarget( GB , Mek , AI_Repair_List[ t ] );
					if TGear <> Nil then begin
						Target := NAttValue( TGear^.NA , NAG_EpisodeData , NAS_UID );
						CORD := -AI_Repair_List[ t ];
					end;
				end;
				Inc( T );
			end;
		end;

		{ If no repair skills, try flirtation or conversation. }
{		if ( CORD = 0 ) and ( NAttValue( NPC^.NA , NAG_Skill , 27 ) > Random( 10 ) ) and ( Random( 3 ) = 1 ) and IsSafeArea( GB ) then begin
			TGEar := SelectSocialTarget( GB , NPC , True );
			if TGear <> Nil then begin
				Target := NAttValue( TGear^.NA , NAG_EpisodeData , NAS_UID );
				CORD := CORD_Flirt;
			end;
		end;}
		if ( CORD = 0 ) and ( NAttValue( NPC^.NA , NAG_Skill , NAS_Conversation ) > Random( 10 ) ) and ( Random( 3 ) = 1 ) and IsSafeArea( GB ) then begin
			TGEar := SelectSocialTarget( GB , NPC , False );
			if TGear <> Nil then begin
				Target := NAttValue( TGear^.NA , NAG_EpisodeData , NAS_UID );
				CORD := CORD_Chat;
			end;
		end;

		if CORD <> 0 then begin
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ContinuousOrders , CORD );
			SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_ATarget , Target );
		end else begin
			HM := GetHotMap( GB , NAV_DefPlayerTeam , HotMoveMode( Mek ) , ORD_SeekTeam );
			if not XMoveTowardsGoal( GB , Mek , HM , 5 , 10 ) then Wander( Mek , GB );
		end;
	end;
end;

Procedure Seek_And_Destroy( Mek: GearPtr; GB: GameBoardPtr );
	{ Seek an enemy, destroy it if possible. }
var
	HM: Integer;
	N1,D1,N2,D2: LongInt;	{ Numerator 1 , Numerator 2 , Denominator 1 , Denominator 2 }
				{ Used for the OptMax, OptMin calculations. }
	Procedure CheckOptimumRange( Part: GearPtr );
		{ Check the weapons along this track to find out the optimum fighting }
		{ ranges for MEK. }
		{ This is done with a strange fraction calculation- find the average range }
		{ of all weapons, weighted by the DC they do. }
	var
		Dmg,Rng: Integer;
	begin
		while Part <> Nil do begin
			{ If PART is a weapon, it will affect our calculations. }
			if ReadyToFire( GB , Mek , Part ) then begin
				if Part^.G = GG_Module then begin
					Dmg := WeaponDC( Part );
					D1 := D1 + Dmg div 2;
				end else if Part^.G = GG_Weapon then begin
					{ Find the DMG and RNG of this weapon. }
					Dmg := WeaponDC( Part );
					Rng := WeaponRange( GB , Part , RANGE_Long );
					if Rng < 2 then begin
						D1 := D1 + Dmg div 2;
						D2 := D2 + Dmg * 6;
					end else if Rng < 18 then begin
						N1 := N1 + ( Rng * 2 * Dmg );
						N2 := N2 + ( Rng * Dmg div 3 );
						D1 := D1 + Dmg;
						D2 := D2 + Dmg;
					end else begin
						N1 := N1 + ( Rng * 2 * Dmg );
						D1 := D1 + Dmg;
						N2 := N2 + ( Rng * Dmg );
						D2 := D2 + Dmg;
					end;
				end;
			end;
			CheckOptimumRange( Part^.SubCom );
			CheckOptimumRange( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;
	Procedure GetOptimumRange;
		{ Determine the optimum range for this mecha. }
	var
		NPC: GearPtr;
	begin
		NPC := LocatePilot( Mek );

		if ( NPC <> Nil ) and ( NAttValue( NPC^.NA , NAG_Personal , NAS_OptMax ) <> 0 ) then begin
			N1 := NAttValue( NPC^.NA , NAG_Personal , NAS_OptMax );
			N2 := NAttValue( NPC^.NA , NAG_Personal , NAS_OptMin );
		end else begin
			CheckOptimumRange( Mek^.SubCom );
		end;
	end;
begin
	{ First, move towards the enemy, if necessary. }
	if Random( 3 ) = 1 then begin
		SelectMoveMode( Mek , GB );
	end;
	HM := GetHotMap( GB , NAttValue( Mek^.NA , NAG_LOcation , NAS_Team ) , HotMoveMode( Mek ) , ORD_SeekEnemy );

	{ Determine optimum ranges. }
	N1 := 0;
	N2 := 0;
	D1 := 1;
	D2 := 1;
	GetOptimumRange;
	if not XMoveTowardsGoal( GB , Mek , HM , N1 div D1 , N2 div D2 ) then begin
		if NAttValue( Mek^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam then begin
			LancemateUsefulAction( Mek , GB );
		end else begin
			Wander( Mek , GB );
		end;
	end else begin
		{ Not doing anything special... Might as well launch a verbal attack. }
		if ( GB^.ComTime > NAttValue( Mek^.NA , NAG_EpisodeData , NAS_ChatterRecharge ) ) then begin
			if Random( 50 ) = 1 then SayCombatTaunt( GB , Mek , 'CHAT_ATTACK' );
		end;
	end;

	{ Secondly, attack anyone within reach. }
	AttackTargetOfOppurtunity( GB , Mek );
end;


Procedure SetNewOrders( GB: GameBoardPtr; Mek: GearPtr );
	{ MEK has apparently either completed what it set out to do, }
	{ or the standing orders have become impossible. }
var
	TN: Integer;
	TG: GearPtr;
begin
	TN := NAttValue( Mek^.NA , NAG_Location , NAS_Team );
	TG := LocateTeam( GB , TN );

	if TG <> Nil then begin
		{ Set the default orders listed in the TEAM gear. }
		SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Orders , TG^.Stat[ STAT_TeamOrders ] );

	end else begin
		{ If no team gear has been defined, use default orders }
		{ SEARCH AND DESTROY. }
		SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Orders , NAV_SeekAndDestroy );
	end;
end;

Procedure GOTO_SPOT( Mek: GearPtr; GB: GameBoardPtr );
	{ The outline for this behavior is as follows: }
	{ - If not moving, set move towards target. }
	{ - Fire at targets of oppurtunity. }
	{ - Once target is reached, seek new orders. }
var
	HM,X,Y,GX,GY: Integer;
begin
	{ Locate all the values we're gonna need. }
	X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );
	GX := NAttValue( Mek^.NA , NAG_Location , NAS_GX );
	GY := NAttValue( Mek^.NA , NAG_Location , NAS_GY );

	if Random( 3 ) = 1 then begin
		SelectMoveMode( Mek , GB );
	end;

	{ If we have reached the spot where we want to go, }
	{ its time to seek new orders. }
	if ( GX = X ) and ( GY = Y ) then begin
		SetNewOrders( GB , Mek );

	end else begin
		HM := GetHotMap( GB , GX + ( GY * ( GB^.MAP_Width + 1 ) ) , HotMoveMode( Mek ) , ORD_SeekSpot );
		MoveTowardsGoal( GB , Mek , HM );

		{ Secondly, attack an enemy within reach. }
		AttackTargetOfOppurtunity( GB , Mek );
	end;
end;

Procedure GOTO_EDGE( Mek: GearPtr; GB: GameBoardPtr );
	{ The outline for this behavior is as follows: }
	{ - If not moving, set move towards target. }
	{ - Fire at targets of oppurtunity. }
var
	HM,Edge: Integer;
begin
	{ Locate all the values we're gonna need. }
	Edge := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_ATarget );

	if Random( 2 ) = 1 then begin
		SelectMoveMode( Mek , GB );
	end;

	HM := GetHotMap( GB , Edge , HotMoveMode( Mek ) , ORD_SeekEdge );
	MoveTowardsGoal( GB , Mek , HM );

	{ Secondly, attack an enemy within reach. }
	AttackTargetOfOppurtunity( GB , Mek );
end;

Procedure PASSIVE( Mek: GearPtr; GB: GameBoardPtr );
	{ This particular gear is going to act passively. It will not }
	{ move around much, just stand there mostly. If it spots a }
	{ hostile model it will run about randomly. }
	{ This AI type is to be used for townsfolk and other unfortunates. }
var
	HM: Integer;
begin
	{ First, move away from the enemy, if necessary. }
	HM := GetHotMap( GB , NAttValue( Mek^.NA , NAG_LOcation , NAS_Team ) , HotMoveMode( Mek ) , ORD_SeekEnemy );
	FleeFromGoal( GB , Mek , HM );
end;

Procedure RUNAWAY( Mek: GearPtr; GB: GameBoardPtr );
	{ This AI type is for models wishing to exit the board. }
begin
	{ This mode will likely run the NPC off the map. }
	if MoveBlocked( Mek , GB ) then begin
		SelectMoveMode( Mek , GB );
		if Random( 2 ) = 1 then begin
			PrepAction( GB , Mek , NAV_TurnRight );
		end else begin
			PrepAction( GB , Mek , NAV_TurnLeft );
		end;
	end else begin
		PrepAction( GB , Mek , NAV_FullSpeed );
	end;
end;

Procedure FOLLOW( Mek: GearPtr; GB: GameBoardPtr );
	{ Attempt to follow the target. }
	{ Note that this is a "MAGIC" AI type, since the NPC will }
	{ follow its target even if the target cannot be seen. }
var
	UID,HM: Integer;
begin
	{ First, attempt to move closer to target. }
	UID := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_ATarget );
	HM := GetHotMap( GB , UID , HotMoveMode( Mek ) , ORD_SeekSingleModel );
	MoveTowardsGoal( GB , Mek , HM );

	{ Secondly, attack an enemy within reach. }
	AttackTargetOfOppurtunity( GB , Mek );
end;

Procedure GetPropInput( GB: GameBoardPtr; Mek: GearPtr );
	{ Props just kind of sit there. Usually. }
begin
	if Mek^.S = GS_CombatProp then begin
		AttackTargetOfOppurtunity( GB , Mek );
		SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ReactionTime( Mek ) );
	end else begin
		PrepAction( GB , Mek , NAV_Stop );
		SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ClicksPerRound );
	end;
end;

Function AIUseInventory( NPC: GearPtr; GB: GameBoardPtr ): Boolean;
	{ It's possible that this NPC has a status condition. Check to see }
	{ whether or not they have any medicine to deal with it. }
var
	Item,I2: GearPtr;
	UsedSomething: Boolean;
begin
	{ Assume FALSE until something gets used. }
	UsedSomething := FALSE;

	{ Animals never do this. }
	if NotAnAnimal( NPC ) then begin
		NPC := LocatePilot( NPC );

		Item := NPC^.InvCom;
		while ( Item <> Nil ) and not UsedSomething do begin
			I2 := Item^.Next;

			if ( Item^.G = GG_Consumable ) and ( Item^.Stat[ STAT_FoodEffectType ] <> 0 ) then begin
				if ( Item^.Stat[ STAT_FoodEffectType ] = FET_CureStatus ) and HasStatus( NPC , Item^.Stat[ STAT_FoodEffectMod ] ) then begin
					EatItem( GB , NPC , Item );
					UsedSomething := True;
				end else if ( ( Item^.Stat[ STAT_FoodEffectType ] = FET_Healing ) or ( Item^.Stat[ STAT_FoodEffectType ] = FET_Regeneration ) ) and ( PercentDamaged( NPC ) < 90 ) then begin
					EatItem( GB , NPC , Item );
					UsedSomething := True;
				end;
			end;

			Item := I2;
		end;
	end;

	AIUseInventory := UsedSomething;
end;

Procedure GetAIInput( Mek: GearPtr; GB: GameBoardPtr );
	{ MEK belongs to the computer team. Decide upon }
	{ a course of action for it here. }
var
	O: LongInt;
begin
	{ Before processing orders, check jump time, since the AI is }
	{ stupid and will crash as often as possible. }
	O := NAttValue( Mek^.NA , NAG_Action , NAS_TimeLimit );
	if ( O > 0 ) and (( O + CalcMoveTime( Mek , GB ) ) >= GB^.ComTime ) then begin
		{ This is as far as this jump can go. Better land now. }
		PrepAction( GB , Mek , NAV_Stop );

		{ Switch to another movemode, since jumping will }
		{ require some time to recharge. }
		ShiftGears( GB , Mek , False );
	end;

	if Mek^.G = GG_Prop then begin
		GetPropInput( GB , Mek );

	end else if not IsMasterGear( Mek ) then begin
		{ If this is not a master gear, just wait. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ClicksPerRound );

	end else if not AIUseInventory( mek , GB ) then begin

		{ Otherwise, check the orders of the NPC unit, and branch accordingly. }
		O := NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Orders );

		case O of
			NAV_GotoSpot:		GOTO_SPOT( Mek , GB );
			NAV_SeekEdge:		GOTO_EDGE( Mek , GB );
			NAV_Passive:		PASSIVE( Mek , GB );
			NAV_RunAway:		RUNAWAY( Mek , GB );
			NAV_Follow:		FOLLOW( Mek , GB );
			else Seek_And_Destroy( Mek , GB );
		end;

		if ( GB^.ComTime > NAttValue( Mek^.NA , NAG_EpisodeData , NAS_ChatterRecharge ) ) and ( Random( 80 ) = 1 ) and IsSafeArea( GB ) then begin
			SayCombatTaunt( GB , Mek , 'CHAT_SAFE' );
		end;
	end;
end;

Procedure ConfusedInput( Mek: GearPtr; GB: GameBoardPtr );
	{ The mek is not in full control of its faculties. Move randomly. }
var
	P: Point;
	CD: Integer;
begin
	{ Confused props just sit there and do nothing... much like regular props. }
	if Mek^.G = GG_Prop then Exit;

	{ Determine current facing and position. }
	P := GearCurrentLocation( Mek );
	CD := NAttValue( Mek^.NA , NAG_Location , NAS_D );

	{ If the current direction of travel doesn't lead off the map, }
	{ and isn't blocked, just move foreword. }
	if OnTheMap( GB , P.X + AngDir[ CD , 1 ] , P.Y + AngDir[ CD , 2 ] ) and ( Random( 3 ) <> 1 ) and not MoveBlocked( Mek , GB ) then begin
		if Random( 2 ) = 1 then begin
			PrepAction( GB , Mek , NAV_FullSpeed );
		end else begin
			PrepAction( GB , Mek , NAV_NormSpeed );
		end;
	end else begin
		if Random( 2 ) = 1 then begin
			PrepAction( GB , Mek , NAV_TurnRight );
		end else begin
			PrepAction( GB , Mek , NAV_TurnLeft );
		end;
	end;
end;

Procedure BrownianMotion( GB: GameBoardPtr );
	{ Go through all the clouds and flames on the map, and update }
	{ them. A few rules... }
	{  1. No more than one cloud and one flame per tile. }
	{  2. Clouds will move if there's a free square. }
	{  3. Fires will burn terrain and ay reproduce to free squares. }
	{  4. Both fires and clouds will do EFFECT if that SAtt is defined. }

	Procedure MetaEffect( MT: GearPtr; X,Y: Integer );
		{ This metaterrain has some effect. Better handle that }
		{ here. }
	var
		fx,desc: String;
		N,T: Integer;
		Target: GearPtr;
	begin
		fx := SAttValue( MT^.SA , 'EFFECT' );
		desc := SAttValue( MT^.SA , 'FX_DESC' );
		N := NumGearsXY( GB , X , Y );
		for t := 1 to N do begin
			target := FindGearXY( GB , X , Y , T );
			if ( Target <> MT ) and NotDestroyed( Target ) then EffectFrontEnd( GB , Target , fx , desc );
		end;
	end;
var
	CloudMap: Array [1..MaxMapWidth,1..MaxMapWidth] of GearPtr;
	FireMap: Array [1..MaxMapWidth,1..MaxMapWidth] of GearPtr;
	ElseMap: Array [1..MaxMapWidth,1..MaxMapWidth] of Boolean;
	M,M2: GearPtr;
	P: Point;
	X,Y,T: Integer;
begin
	{ Start by filling out the cloudmap and the firemap. }
	for x := 1 to MaxMapWidth do begin
		for y := 1 to MaxMapWidth do begin
			CloudMap[ X , Y ] := Nil;
			FireMap[ X , Y ] := Nil;
			ElseMap[ X , Y ] := False;
		end;
	end;

	{ Look for clouds and flames and store them in the map. }
	M := GB^.Meks;
	while M <> Nil do begin
		M2 := M^.Next;

		P := GearCurrentLocation( M );
		if OnTheMap( GB , P.X , P.Y ) then begin
			if ( M^.G = GG_Metaterrain ) and ( M^.S = GS_MetaCloud ) then begin
				{ If two clouds exist on the same tile, }
				{ the one with the greatest duration wins. }
				{ Remember that a negative duration really }
				{ means infinite duration. }
				if CloudMap[ P.X , P.Y ] = Nil then begin
					CloudMap[ P.X , P.Y ] := M;
				end else if M^.Stat[ STAT_CloudDuration ] < 0 then begin
					RemoveGear( GB^.Meks , CloudMap[ P.X , P.Y ] );
					CloudMap[ P.X , P.Y ] := M;
				end else if ( M^.Stat[ STAT_CloudDuration ] > CloudMap[ P.X , P.Y ]^.Stat[ STAT_CloudDuration ] ) and ( CloudMap[ P.X , P.Y ]^.Stat[ STAT_CloudDuration ] > 0 ) then begin
					RemoveGear( GB^.Meks , CloudMap[ P.X , P.Y ] );
					CloudMap[ P.X , P.Y ] := M;
				end else begin
					RemoveGear( GB^.Meks , M );
				end;
			end else if ( M^.G = GG_Metaterrain ) and ( M^.S = GS_MetaFire ) then begin
				{ Fires are simpler than clouds. Just one }
				{ fire per map square, no exceptions. }
				if FireMap[ P.X , P.Y ] = Nil then begin
					FireMap[ P.X , P.Y ] := M;
				end else begin
					RemoveGear( GB^.Meks , M );
				end;

			end else begin
				ElseMap[ P.X , P.Y ] := True;
			end;
		end;

		M := M2;
	end;

	{ Finally, go through each cloud/flame one more time and update }
	{ them. }
	for X := 1 to MaxMapWidth do begin
		for Y := 1 to MaxMapWidth do begin
			{ If there's a cloud here, deal with it. }
			if CloudMap[ X , Y ] <> Nil then begin
				{ If the cloud has an effect, apply that }
				{ effect to all models in the same tile. }
				if ( SAttValue( CloudMap[ X , Y ]^.SA , 'EFFECT' ) <> '' ) and ElseMap[ X , Y ] then begin
					MetaEffect( CloudMap[ X , Y ] , X , Y );
				end;

				{ If the cloud has a duration, deal with it. }
				if CloudMap[ X , Y ]^.Stat[ STAT_CloudDuration ] > 0 then Dec( CloudMap[ X , Y ]^.Stat[ STAT_CloudDuration ] );
				if CloudMap[ X , Y ]^.Stat[ STAT_CloudDuration ] = 0 then begin
					RemoveGear( GB^.Meks , CloudMap[ X , Y ] );
					Screen_Needs_Redraw := True;


				{ If the cloud's time isn't finished, }
				{ try moving it around. }
				end else begin
					{ Pick a random spot next to the cloud. }
					{ If it's empty and non-blocking, move }
					{ the cloud there. }
					P.X := X + Random( 2 ) - Random( 2 );
					P.Y := Y + Random( 2 ) - Random( 2 );
					if OnTheMap( GB , P.X , P.Y ) and ( CloudMap[ P.X , P.Y ] = Nil ) and not TileBlocksLOS( GB , P.X , P.Y , 5 ) then begin
						CloudMap[ P.X , P.Y ] := CloudMap[ X , Y ];
						CloudMap[ X , Y ] := Nil;
						SetNAtt( CloudMap[ P.X , P.Y ]^.NA , NAG_Location , NAS_X , P.X );
						SetNAtt( CloudMap[ P.X , P.Y ]^.NA , NAG_Location , NAS_Y , P.Y );
						Screen_Needs_Redraw := True;

					end;
				end;
			end; { if CloudMap... }

			if FireMap[ X , Y ] <> Nil then begin
				{ Handle the effects of fire here. }
				if ( SAttValue( FireMap[ X , Y ]^.SA , 'EFFECT' ) <> '' ) and ElseMap[ X , Y ] then begin
					MetaEffect( FireMap[ X , Y ] , X , Y );
				end;

				{ Fire needs smoke. If there's no smoke, }
				{ probably add some. }
				if ( Random( 3 ) <> 1 ) and ( CloudMap[ X , Y ] = Nil ) then begin
					M := LoadNewSTC( 'SMOKE-1' );
					if M <> Nil then begin
						M^.Scale := GB^.Scale;
						AppendGear( GB^.Meks , M );
						M^.Stat[ STAT_CloudDuration ] := RollStep( 2 );
						SetNAtt( M^.NA , NAG_Location , NAS_X , X );
						SetNAtt( M^.NA , NAG_Location , NAS_Y , Y );
					end;
				end;

				{ Check to see if the fire will spread. }
				for t := 0 to 7 do begin
					P.X := X + AngDir[ t , 1 ];
					P.Y := Y + AngDir[ t , 2 ];

					if OnTheMap( GB , P.X , P.Y ) and TerrMan[ TileTerrain( GB, P.X , P.Y ) ].Flammable and ( FireMap[ P.X , P.Y ] = Nil ) and ( Random( 15 ) = 1 ) then begin
						M := LoadNewSTC( 'FIRE-1' );
						if M <> Nil then begin
							AppendGear( GB^.Meks , M );
							M^.Scale := GB^.Scale;
							SetNAtt( M^.NA , NAG_Location , NAS_X , P.X );
							SetNAtt( M^.NA , NAG_Location , NAS_Y , P.Y );
							Screen_Needs_Redraw := True;
						end;
					end;
				end;

				{ Check to see if the fire will go out. }
				if ( Random( 20 ) = 1 ) or not TerrMan[ TileTerrain( GB , X , Y ) ].Flammable then begin
					RemoveGear( GB^.Meks , FireMap[ X , Y ] );
					Screen_Needs_Redraw := True;

				end else if Random( TerrMan[ TileTerrain( GB , X , Y ) ].DMG + 2 ) = 1 then begin
					DestroyTerrain( GB , X , Y );
					if ( Random( 10 ) = 1 ) then RemoveGear( GB^.Meks , FireMap[ X , Y ] );
					Screen_Needs_Redraw := True;
				end;
			end; { if FireMap... }

		end; {for Y}
	end; {for X}
end;

Procedure HandleEncounters( GB: GameBoardPtr );
	{ It's time to move encounters. }
var
	M,PC: GearPtr;
	PC_Pos,Enc_Pos: Point;
	trigger: String;
	Ord,GX,GY,HM,MM,Best,FinalD,D: Integer;
begin
	M := GB^.Meks;
	PC := GG_LocatePC( GB );
	PC_Pos := GearCurrentLocation( PC );
	HM := 0;

	while M <> Nil do begin
		if ( M^.G = GG_MetaTerrain ) and ( M^.S = GS_MetaEncounter ) and ( M^.STAT[ STAT_MetaVisibility ] >= 0 ) then begin
			{ Move the encounter as appropriate. }
			Enc_Pos := GearCurrentLocation( M );

			Ord := NAttValue( M^.NA , NAG_EpisodeData , NAS_Orders );
			if M^.Stat[ STAT_Altitude ] <= 0 then begin
				MM := HMMM_EncounterGround;
			end else begin
				MM := MM_Fly;
			end;
			SetNAtt( M^.NA , NAG_Action , NAS_MoveMode , MM );

			if Random( 100 ) < M^.Stat[ STAT_EncounterMove ] then begin
				if ( Ord <> NAV_Passive ) then begin
					if Ord = NAV_GotoSpot then begin
						GX := NAttValue( M^.NA , NAG_Location , NAS_GX );
						GY := NAttValue( M^.NA , NAG_Location , NAS_GY );
						HM := GetHotMap( GB , GX + ( GY * ( GB^.MAP_Width + 1 ) ) , MM , ORD_SeekSpot );

					end else if Ord = NAV_SeekEdge then begin
						GX := NAttValue( M^.NA , NAG_EpisodeData , NAS_ATarget );
						HM := GetHotMap( GB , GX , MM , ORD_SeekEdge );

					end else if Ord = NAV_RunAway then begin
						HM := GetHotMap( GB , 0 , MM , ORD_SeekAnyEdge );

					end else if Ord = NAV_Follow then begin
						GX := NAttValue( M^.NA , NAG_EpisodeData , NAS_ATarget );
						HM := GetHotMap( GB , GX , MM , ORD_SeekSingleModel );

					end else begin
						HM := GetHotMap( GB , PC_Pos.X + ( PC_Pos.Y * ( GB^.MAP_Width + 1 ) ) , MM , ORD_SeekSpot );

					end;

					{ We have a hot map. Move in the most advantageous direction. }
					Best := HotMap[ HM , Enc_pos.X , Enc_Pos.Y ];
					FinalD := -1;
					for D := 0 to 7 do begin
						GX := Enc_Pos.X + AngDir[ D , 1 ];
						GY := Enc_Pos.Y + AngDir[ D , 2 ];
						if OnTheMap( GB , GX , GY ) and ( HotMap[ HM , GX , GY ] < Best ) then begin
							Best := HotMap[ HM , GX , GY ];
							FinalD := D;
						end;
					end;

					if FinalD <> -1 then begin
						Enc_Pos.X := Enc_Pos.X + AngDir[ FinalD , 1 ];
						Enc_Pos.Y := Enc_Pos.Y + AngDir[ FinalD , 2 ];
						SetNAtt( M^.NA , NAG_Location , NAS_X , Enc_Pos.X );
						SetNAtt( M^.NA , NAG_Location , NAS_Y , Enc_Pos.Y );
					end;
				end else begin { if not Passive... }
					GX := Enc_Pos.X + Random( 2 ) - Random( 2 );
					GY := Enc_Pos.Y + Random( 2 ) - Random( 2 );
					if OnTheMap( GB , GX , GY ) and not MovementBlocked( M , GB , Enc_Pos.X , Enc_Pos.Y , GX , GY ) then begin
						Enc_Pos.X := GX;
						Enc_Pos.Y := GY;
						SetNAtt( M^.NA , NAG_Location , NAS_X , Enc_Pos.X );
						SetNAtt( M^.NA , NAG_Location , NAS_Y , Enc_Pos.Y );
					end;
				end;

			end; { if random(100) < EncounterMove }

			{ Perform a vision check to see if this encounter will be spotted }
			{ by the player. }
			VisionCheck( GB , M );

			{ If the PC and an encounter share the same space, the ATTACK script }
			{ is triggered. }
			if ( Abs( Enc_Pos.X - PC_Pos.X ) <= 1 ) and ( Abs( Enc_Pos.Y - PC_Pos.Y ) <= 1 ) and ( ( NAttValue( M^.NA , NAG_Narrative , NAS_ScriptActivatedTimer ) + 5 ) < GB^.ComTime ) and (( GB^.Scene = Nil ) or ( NAttValue( GB^.Scene^.NA , NAG_SceneData , NAS_EncounterRecharge ) < GB^.ComTime )) then begin
				trigger := 'ATTACK';
				TriggerGearScript( GB , M , trigger );
				if GB^.Scene <> Nil then SetNAtt( GB^.Scene^.NA , NAG_SceneData , NAS_EncounterRecharge , GB^.ComTime + Standard_Encounter_Recharge );
				{ Only one encounter script can be triggered per iteration. }
				break;
			end else if ( HM > 0 ) and ( HotMap[ HM , Enc_Pos.X , Enc_Pos.Y ] = 0 ) then begin
				SetTrigger( GB , 'ENCGOAL' + BStr( M^.Stat[ STAT_Destination ] ) );
			end;
		end;

		M := M^.Next;
	end;
end;

Function MOVE_MODEL_TOWARDS_SPOT( Mek: GearPtr; GB: GameBoardPtr; GX,GY: Integer ): Boolean;
	{ A new life for an old procedure. }
var
	HM,X,Y: Integer;
begin
	{ Locate all the values we're gonna need. }
	X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );

	if Random( 3 ) = 1 then begin
		SelectMoveMode( Mek , GB );
	end;

	{ If we have reached the spot where we want to go, }
	{ its time to seek new orders. }
	if ( GX = X ) and ( GY = Y ) then begin
		MOVE_MODEL_TOWARDS_SPOT := False;

	{ If we're right next to the target but it's blocked, exit false. }
	end else if ( Abs( GX - X ) <= 1 ) and ( Abs( GY - Y ) <= 1 ) and MovementBlocked( Mek , GB , X , Y , GX , GY ) then begin
		MOVE_MODEL_TOWARDS_SPOT := False;

	end else begin
		HM := GetHotMap( GB , GX + ( GY * ( GB^.MAP_Width + 1 ) ) , HotMoveMode( Mek ) , ORD_SeekSpot );

		{ If there's no way from here to the desired location, exit FALSE. }
		if HotMap[ HM , X , Y ] > 1000 then Exit( False );

		{ Otherwise attempt to move. }
		MOVE_MODEL_TOWARDS_SPOT := XMoveTowardsGoal( GB , Mek , HM , 0 , 0 );
	end;
end;


end.
