unit RandMaps;
	{ ******************************* }
	{ ***   NEW  SPECIFICATIONS   *** }
	{ ******************************* }

	{ Every feature, both the SCENE gear and the MAP FEATURES, }
	{ needs three SAtts defined: PARAM describes the rendering }
	{ parameters to be sent to the actual drawing routine, while }
	{ SELECTOR holds the parameters to be sent to the sub-area }
	{ selection routine. GAPFILL describes how to plug empty spaces. }

	{ If these strings are not defined in the scene/feature gear, }
	{ a default value is obtained from the GameData/randmaps.txt file }
	{ based upon the scene/feature's listed style. }

	{ All map features are to be recursive. Bottom level features }
	{ fit into the SCENE gear. }
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

uses gears,locale,playwright;

const
	DEFAULT_FLOOR_TYPE = 20;
	DEFAULT_WALL_TYPE = 23;

	SPECIAL_ShowAll = 'SHOWALL';
	SPECIAL_ConvertDoors = 'CELL';
	SPECIAL_Unchartable = 'UNCHARTABLE';


	DW_Horizontal = 1;
	DW_Vertical = 2;

	{ NAtts for components.  }
	NAG_ComponentDesc = -8;
	NAS_CompUID = 1;
	NAS_ELementID = 2;	{ Used by the minimap to identify components. }

	{ CELL FORMAT: X Y W H D }
	{ Direction 0 means that the minimap will have the same orientation as }
	{ when drawn out in a design file; dirs 1 through 3 rotate 90 degrees clockwise. }

	{ Predrawn maps come with gears that describe their cells. }
	STAT_PDMC_X = 1;
	STAT_PDMC_Y = 2;
	STAT_PDMC_W = 3;
	STAT_PDMC_H = 4;
	STAT_PDMC_D = 5;

var
	High_Component_ID: Integer;

Function LoadPredrawnMap( const FName: String ): GameBoardPtr;
Procedure SavePredrawnMap( GB: GameBoardPtr; const FName: String );

Function NewSubZone( MF: GearPtr ): GearPtr;

Procedure DrawMiniMap( GB: GameBoardPtr; MF: GearPtr; MapDesc: String; D: Integer );

{ WARNING: AddContent is for internal use only!!! }
Function AddContent( CType: String; GB: GameboardPtr; Source,Zone: GearPtr; P: String; var Cells: SAttPtr; SCheck,STerr: Integer ): Boolean;

function RandomMap( Scene: GearPtr ): GameBoardPtr;


implementation

uses gearutil,ghprop,rpgdice,texutil,gearparser,narration,ui4gh,arenascript,ghchars,sysutils,ability,
{$IFDEF ASCII}
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}

var
	Standard_Param_List: SAttPtr;
	random_scene_content,super_prop_list: GearPtr;
	UniqueZoneNum: Integer;

Function LoadPredrawnMap( const FName: String ): GameBoardPtr;
	{ Load the requested map feature from disk. If no such map can be found, }
	{ return a blank map instead. }
var
	F: Text;
	W,H: Integer;
	it: GameBoardPtr;
begin
	if FileExists( Series_Directory + FName ) then begin
		Assign( F , Series_Directory + FName );
		Reset( F );

		ReadLn( F , W );
		ReadLn( F , H );
		it := NewMap( W , H );

		it^.Map := ReadMap( F , W , H );

		it^.Meks := ReadCGears( F );

		Close( F );
	end else begin
		it := NewMap( 50 , 50 );
	end;
	LoadPredrawnMap := it;
end;

Procedure SavePredrawnMap( GB: GameBoardPtr; const FName: String );
	{ Save this map to disk using the provided filename. }
var
	F: Text;
begin
	Assign( F , Series_Directory + FName );
	Rewrite( F );

	{ Width and height get written first. }
	writeln( F , GB^.Map_Width );
	writeln( F , GB^.Map_Height );

	{ Write the map data. This part should be easy. }
	WriteMap( GB^.Map , F );

	{ Write the cell data. This part may take a bit more work. }
	WriteCGears( F , GB^.Meks );

	Close( F );
end;


Function IsLegalTerrain( T: Integer ): Boolean;
	{ Return TRUE if T is a legal terrain type, or FALSE otherwise. }
begin
	IsLegalTerrain := ( T >= 1 ) and ( T <= NumTerr );
end;

Function GetSpecial( MF: GearPtr ): String;
	{ Retrieve the special string for this map feature, }
	{ convert it to uppercase and return it. }
begin
	GetSpecial := UpCase( SAttValue( MF^.SA , 'SPECIAL' ) );
end;

Function RectPointOverlap( X1,Y1,X2,Y2,PX,PY: Integer ): Boolean;
	{ Return TRUE if point PX,PY is located inside the provided }
	{ rectangle, FALSE if it isn't. }
begin
	RectPointOverlap := ( PX >= X1 ) and ( PX <= X2 ) and ( PY >= Y1 ) and ( PY <= Y2 );
end;

Function RectRectOverlap( X1,Y1,W1,H1,X2,Y2,W2,H2: Integer ): Boolean;
	{ Return TRUE if the two rectangles described by X,Y,Width,Height }
	{ overlap, FALSE if they don't. }
var
	OL: Boolean;
	XB,YB: Integer;
begin
	OL := False;

	{ Check all points of the first rectangle against the second. }
	for XB := X1 to (X1 + W1 - 1 ) do begin
		for YB := Y1 to (Y1 + H1 - 1 ) do begin
			Ol := OL or RectPointOverlap( X2 , Y2 , X2 + W2 - 1 , Y2 + H2 - 1 , XB , YB );
		end;
	end;

	RectRectOverlap := OL;
end;

Function RegionClear( GB: GameBoardPtr; SCheck,STerr,X,Y,W,H: Integer ): Boolean;
	{ Return TRUE if the specified region counts as clear for the purpose }
	{ of sticking a map feature there, FALSE if it doesn't. }
	Function InclusiveRegionClear: Boolean;
		{ Return TRUE if this region contains at least one }
		{ tile of STERR, false otherwise. }
	var
		IsClear: Boolean;
		TX,TY: Integer;
	begin
		IsClear := False;
		for TX := ( X - 1 ) to ( X + W ) do begin
			for TY := ( Y - 1 ) to ( Y + H ) do begin
				if OnTheMap( GB , TX , TY ) then begin
					if TileTerrain( GB , TX , TY ) = STerr then begin
						IsClear := True;
					end;
				end;
			end;
		end;
		InclusiveRegionClear := IsClear;
	end;

	Function ExclusiveRegionClear: Boolean;
		{ Return TRUE if this region is free from tiles }
		{ of type STERR, false otherwise. }
	var
		IsClear: Boolean;
		TX,TY: Integer;
	begin
		IsClear := True;
		for TX := ( X - 1 ) to ( X + W ) do begin
			for TY := ( Y - 1 ) to ( Y + H ) do begin
				if OnTheMap( GB , TX , TY ) then begin
					if TileTerrain( GB , TX,TY ) = STerr then begin
						IsClear := False;
					end;
				end;
			end;
		end;
		ExclusiveRegionClear := IsClear;
	end;

begin
	{ Call the appropriate checking routine based upon what kind of }
	{ map generator we're dealing with. }
	if SCheck > 0 then begin
		RegionClear := InclusiveRegionClear;
	end else if SCheck < 0 then begin
		RegionClear := ExclusiveRegionClear;
	end else begin
		RegionClear := True;
	end;
end;

Function RandomPointWithinBounds( Container: GearPtr; W,H: Integer ): Point;
	{ Select a placement point within the bounds of this container. }
var
	P: Point;
begin
	if ( Container = Nil ) or IsAScene( Container ) then begin
		P.X := Random( Container^.STAT[ STAT_MAPWIDTH ] - 3 - W ) + 3;
		P.Y := Random( Container^.STAT[ STAT_MAPHEIGHT ] - 3 - H ) + 3;
	end else begin
		P.X := Container^.Stat[ STAT_XPos ] + 1;
		if W < ( Container^.Stat[ STAT_MFWidth ] - 3 ) then P.X := P.X + Random( Container^.Stat[ STAT_MFWidth ] - W - 4 );
		P.Y := Container^.Stat[ STAT_YPos ] + 1;
		if H < ( Container^.Stat[ STAT_MFHeight ] - 3 ) then P.Y := P.Y + Random( Container^.Stat[ STAT_MFHeight ] - H - 4 );
	end;
	RandomPointWithinBounds := P;
end;

Function PlacementPointIsGood( GB: GameBoardPtr; Container: GearPtr; SCheck,STerr,X0,Y0,W,H: Integer ): Boolean;
	{ Return TRUE if the specified area is free for adding a new }
	{ map feature, or FALSE otherwise. }
var
	BadPosition: Boolean;
	MF2: GearPtr;
begin
	{ Assume it isn't a bad position until shown otherwise. }
	BadPosition := False;


	{ Check One - see if this position intersects with any }
	{ other map feature at this same depth. }
	{ Only those map features which have }
	{ already been placed need be checked. }
	if Container <> Nil then begin
		MF2 := Container^.SubCom;
		while MF2 <> Nil do begin
			if ( MF2^.G = GG_MapFeature ) and OnTheMap( GB , MF2^.Stat[ STAT_XPos ] , MF2^.Stat[ STAT_YPos ] ) then begin
				BadPosition := BadPosition or RectRectOverlap( X0 - 1 , Y0 - 1 , W + 2 , H + 2 , MF2^.Stat[ STAT_XPos ] , MF2^.Stat[ STAT_YPos ] , MF2^.Stat[ STAT_MFWidth ] , MF2^.Stat[ STAT_MFHeight ] );
			end;
			MF2 := MF2^.Next;
		end;
	end;

	{ Check Two - see if this position is in a "clear" area }
	{ of the map. }
	if not BadPosition then BadPosition := not RegionClear( GB , SCheck , STerr , X0 , Y0 , W , H );

	{ So, the placement point is good if X,Y isn't a bad position. }
	PlacementPointIsGood := not BadPosition;
end;

Function SelectPlacementPoint( GB: GameBoardPtr; Container,MF: GearPtr; var Cells: SAttPtr; SCheck,STerr: Integer ): Boolean;
	{ Attempt to find a decent place to put map feature MF. }
	{ - It should not intersect with any other map feature               }
	{   currently placed.                                                }
	{ - It should be at least one tile from the edge of the container    }
	{   on all sides.                                                    }
	{ - It should be placed in an area that is considered "clear",       }
	{   depending upon the SCheck, STerr values.                         }
const
	MaxTries = 10000;
var
	Tries: Integer;
	P: Point;
	TheCell: SAttPtr;
begin
	{ If we have been provided with a list of cells, then in theory }
	{ or work here has already been done for us. Pick one of the cells }
	{ at random and return that. On the other hand, if we have no }
	{ cells, we'll need to search for a free spot ourselves. }
	if not OnTheMap( GB , MF^.Stat[ STAT_XPos ] , MF^.Stat[ STAT_YPos ] ) then begin
		if Cells <> Nil then begin
			{ Select a cell at random. }
			TheCell := SelectRandomSAtt( Cells );

			{ Extract the needed info from this cell. }
			MF^.Stat[ STAT_XPos ] := ExtractValue( TheCell^.Info );
			MF^.Stat[ STAT_YPos ] := ExtractValue( TheCell^.Info );
			MF^.Stat[ STAT_MFWidth ] := ExtractValue( TheCell^.Info );
			MF^.Stat[ STAT_MFHeight ] := ExtractValue( TheCell^.Info );
			SetNAtt( MF^.NA , NAG_Location , NAS_D , ExtractValue( TheCell^.Info ) );

			{ Delete this cell, to prevent it from being chosen again. }
			RemoveSAtt( Cells , TheCell );

			SelectPlacementPoint := True;
		end else begin
			Tries := 0;
			repeat
				P := RandomPointWithinBounds( Container , MF^.Stat[ STAT_MFWidth ] , MF^.Stat[ STAT_MFHeight ] );
				Inc( Tries );

				{ If we've been trying and trying with no success, }
				{ get rid of the terrain check condition and just go }
				{ on nonintersection. }
				if Tries > 9000 then SCheck := 0;
			until ( Tries > MaxTries ) or PlacementPointIsGood( GB , Container , SCheck , STerr , P.X , P.Y , MF^.Stat[ STAT_MFWidth ] , MF^.Stat[ STAT_MFHeight ] );

			MF^.Stat[ STAT_XPos ] := P.X;
			MF^.Stat[ STAT_YPos ] := P.Y;

			SelectPlacementPoint := Tries <= MaxTries;
		end;
	end;
end;

Function DecideTerrainType( MF: GearPtr; var Cmd: String; D: Integer ): Integer;
	{ Given the default provided by the instruction string and the }
	{ value stored in the map feature gear, decide what terrain type }
	{ to use for the current operation. }
var
	it: Integer;
begin
	it := ExtractValue( CMD );
	if ( MF <> Nil ) and ( D >= 5 ) and ( D <= NumGearStats ) and IsLegalTerrain( MF^.Stat[ D ] ) then begin
		it := MF^.Stat[ D ];
	end;
	DecideTerrainType := it;
end;

Procedure DrawTerrain( GB: GameBoardPtr; X,Y,T1,T2: Integer );
	{ Draw a terrain type into the designated tile. If two terrain }
	{ types have been provided, pick one of them randomly. }
begin
	if OnTheMap( GB , X , Y ) then begin
		if ( Random( 3 ) = 1 ) and ( T2 <> 0 ) then SetTerrain( GB , X,Y , T2 )
		else SetTerrain( GB , X,Y , T1 );
	end;
end;

Procedure RectFill( GB: GameBoardPtr; T1,T2,X0,Y0,W,H: Integer );
	{ Fill a rectangular area with the specified terrain. }
	{ This is needed by several of the commands, so here it is }
	{ as a separate procedure. }
var
	X,Y: Integer;
begin
	for X := X0 to ( X0 + W - 1 ) do begin
		for Y := Y0 to ( Y0 + H - 1 ) do begin
			if OnTheMap( GB , X , Y ) then begin
				DrawTerrain( GB , X , Y , T1 , T2 );
			end;
		end;
	end;
end;

Procedure ProcessFill( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer );
	{ Just fill this region with a terrain type. }
var
	T1,T2: Integer;
begin
	T1 := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	T2 := DecideTerrainType( MF , Cmd , STAT_MFMarble );

	{ Fill in the building area with the floor terrain. }
	RectFill( GB , T1 , T2 , X0 , Y0 , W , H );
end;

Procedure InstallDoor( GB: GameBoardPtr; MF: GearPtr; X,Y,LockVal,HideVal: Integer );
	{ Add a standard door to the map at the specified location with the specified options. }
	function LocalWall: Integer;
		{ Take a look at the four neighboring squares to locate }
		{ a wall. }
	var
		D,T: Integer;
	begin
		D := 0;
		while D <= 8 do begin
			T := TileTerrain( GB , X + AngDir[ D , 1 ] , Y + AngDir[ D , 2 ] );
			D := D + 2;
			if TerrMan[ T ].Pass < -99 then D := 10;
		end;
		LocalWall := T;
	end;
var
	NewDoor,DoorPrototype: GearPtr;
begin
	if MF <> Nil then DoorPrototype := SeekCurrentLevelGear( MF^.SubCom , GG_MetaTerrain , GS_MetaDoor )
	else DoorPrototype := Nil;
	if DoorPrototype <> Nil then begin
		NewDoor := CloneGear( DoorPrototype );
	end else begin
		NewDoor := NewGear( Nil );
		NewDoor^.G := GG_MetaTerrain;
		NewDoor^.S := GS_MetaDoor;
		NewDoor^.V := 5;
		InitGear( NewDoor );
	end;

	SetNAtt( NewDoor^.NA , NAG_Location , NAS_X , X );
	SetNAtt( NewDoor^.NA , NAG_Location , NAS_Y , Y );

{	if MF <> Nil then begin
		Name := SAttValue( MF^.SA , 'NAME' );
		if Name <> '' then begin
			SetSAtt( NewDoor^.SA , 'NAME <' + MsgString( 'RANDMAPS_DoorSign' ) + Name + '>' );
		end;
	end;}

	NewDoor^.Stat[ STAT_Lock ] := LockVal;

	if HideVal > 0 then begin
		DrawTerrain( GB , X , Y , LocalWall , 0 );
		NewDoor^.Stat[ STAT_MetaVisibility ] := HideVal;
	end;

	InsertInvCom( GB^.Scene , NewDoor );
end;


Procedure AddDoor( GB: GameBoardPtr; MF: GearPtr; X,Y: Integer );
	{ Add a standard door to the map at the specified location. }
var
	Roll,Chance,LockVal,HideVal: Integer;
begin
	LockVal := 0;
	HideVal := 0;
	if MF <> Nil then begin
		{ Possibly make the door either LOCKED or SECRET, }
		{ depending on the random chances stored in the MF. }
		Chance := NAttValue( MF^.NA , NAG_Narrative , NAS_LockedDoorChance );
		if Chance > 0 then begin
			Roll := Random( 100 );
			if Roll < Chance then begin
				LockVal := ( Roll div 10 ) + 3;
			end;
		end;
		Chance := NAttValue( MF^.NA , NAG_Narrative , NAS_SecretDoorChance );
		if Chance > 0 then begin
			Roll := Random( 100 );
			if Roll < Chance then begin
				HideVal := ( Roll div 8 ) + 2;
			end;
		end;
	end;

	InstallDoor( GB , MF , X , Y , LockVal , HideVal );
end;

Procedure AddHiddenEntrance( GB: GameBoardPtr; X,Y,D: Integer );
	{ Add a hidden entrance back to the parent map. This is used generally }
	{ to control where the PC will enter a scene. }
var
	Entry,OS: GearPtr;	{ Entrance, and Originating SCene }
begin
	Entry := LoadNewSTC( 'HIDDEN_ENTRANCE' );
	{ The destination in the hidden entrance should have the same value as the }
	{ scene being entered from. However, if this is a metascene or dynamic scene, }
	{ it's gonna take some work to find out what that is. }
	if GB^.Scene^.G = GG_MetaScene then begin
		OS := FindSceneEntrance( FindRoot( GB^.Scene ) , GB , RealSceneID( GB^.Scene ) );
		if OS <> Nil then Entry^.Stat[ STAT_Destination ] := FindSceneID( OS , GB );
	end else if IsInvCom( GB^.Scene ) then begin
		Entry^.Stat[ STAT_Destination ] := GB^.Scene^.S;
	end else begin
		Entry^.Stat[ STAT_Destination ] := GB^.Scene^.Parent^.S;

	end;
	SetNAtt( Entry^.NA , NAG_Location , NAS_X , X );
	SetNAtt( Entry^.NA , NAG_Location , NAS_Y , Y );

	{ Store the entry direction for this entrance. }
	SetNAtt( GB^.Scene^.NA , NAG_EntryDirections , Entry^.Stat[ STAT_Destination ] , D + 1 );

	InsertInvCom( GB^.Scene , Entry );
end;


Procedure ConvertDoors( GB: GameBoardPtr; DoorPrototype: GearPtr; X0,Y0,W,H: Integer );
	{ Convert any doors within the specified range to the door }
	{ prototype requested. }
var
	map: Array[ 1..MaxMapWidth , 1..MaxMapWidth ] of Boolean;
	M,M2,D2: GearPtr;
	X,Y: Integer;
begin
	{ For this procedure to work, we must have the scene and }
	{ a prototype door. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) or ( DoorPrototype = Nil ) then Exit;

	{ Clear our replacement map. }
	{ Set each tile to TRUE; change to FALSE once the door at this }
	{ spot has been replaced. This should keep us from repeatedly }
	{ replacing the same door over and over in an endless loop. }
	for x := 1 to MaxMapWidth do begin
		for y := 1 to MaxMapWidth do begin
			map[ X,Y] := True;
		end;
	end;

	M := GB^.Scene^.InvCom;
	while M <> Nil do begin
		M2 := M^.Next;

		if ( M^.G = GG_MetaTerrain ) and ( M^.S = GS_MetaDoor ) then begin
			{ This is a door. Check it out. }
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			if OnTheMap( GB , X , Y ) and Map[ X , Y ] and RectPointOverlap( X0 - 1 , Y0 - 1 , X0 + W , Y0 + H , X , Y ) then begin
				D2 := CloneGear( DoorPrototype );
				RemoveGear( GB^.Scene^.InvCom , M );
				SetNAtt( D2^.NA , NAG_Location , NAS_X , X );
				SetNAtt( D2^.NA , NAG_Location , NAS_Y , Y );
				InsertInvCom( GB^.Scene , D2 );
				Map[ X , Y ] := False;
			end;
		end;

		M := M2;
	end;
end;

Procedure DrawWall( GB: GameBoardPtr; MF: GearPtr; Terrain,X0,Y0,W,H: Integer; AddGaps,AddDoors: Boolean );
	{ Do the grunt work of drawing the wall. }
var
	DX,DY: Integer;	{ Door Position }
	X,Y: Integer;
	Procedure DrawWallNow;
	begin
		if OnTheMap( GB , X , Y ) then begin
			{ If this is the door position, deal with that. }
			if AddGaps and ( MF <> Nil ) and ( X = DX ) and ( Y = DY ) then begin
				if AddDoors then begin
					SetTerrain( GB , X , Y , TERRAIN_Threshold );
					AddDoor( GB , MF , X , Y );
				end else begin
					SetTerrain( GB , X , Y , TERRAIN_OpenGround );
				end;

			{ If this isn't the door position, draw a wall. }
			end else begin
				SetTerrain( GB , X , Y , Terrain );
			end;
		end;
	end;
begin
	{ Top wall. }
	DX := Random( W - 2 ) + X0 + 1;
	Y := Y0;
	DY := Y0;
	for X := X0 to ( X0 + W - 1 ) do begin
		DrawWallNow;
	end;

	{ Bottom wall. }
	DX := Random( W - 2 ) + X0 + 1;
	Y := Y0 + H - 1;
	DY := Y;
	for X := X0 to ( X0 + W - 1 ) do begin
		DrawWallNow;
	end;

	{ Right wall. }
	DY := Random( H - 2 ) + Y0 + 1;
	X := X0 + W - 1;
	DX := X;
	for Y := Y0 to ( Y0 + H - 1 ) do begin
		DrawWallNow;
	end;

	{ Left wall. }
	DY := Random( H - 2 ) + Y0 + 1;
	X := X0;
	DX := X;
	for Y := Y0 to ( Y0 + H - 1 ) do begin
		DrawWallNow;
	end;
end;

Procedure ProcessWall( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer; AddGaps,AddDoors: Boolean );
	{ Draw a wall around this map feature. Use the MFBORDER terrain, if }
	{ appropriate. }
var
	terrain: Integer;
begin
	{ Decide on what terrain to use for the walls. }
	Terrain := DecideTerrainType( MF , Cmd ,  STAT_MFBorder );

	{ Call  the wall-drawer. }
	DrawWall( GB, MF, Terrain,X0,Y0,W,H, AddGaps,AddDoors );

	{ Maybe add the exit, if one was requested. }
	if ASTringHasBString( GetSpecial( MF ) , 'ADDEXIT' ) then begin
		if ( MF^.G = GG_Scene ) or ( MF^.G = GG_MetaScene ) then begin
			Terrain := MF^.Stat[ STAT_MFFloor ];
			if ( Terrain < 1 ) or ( Terrain > NumTerr ) then Terrain := TERRAIN_Floor;
			SetTerrain( GB , X0 , Y0 + H div 2 + 1 , TERRAIN );
			SetTerrain( GB , X0 , Y0 + H div 2 , TERRAIN );
			SetTerrain( GB , X0 , Y0 + H div 2 - 1 , TERRAIN );
			AddHiddenEntrance( GB , X0 , Y0 + H div 2 , 0 );

		end else begin
			DrawTerrain( GB , X0 , Y0 + H div 2 , TERRAIN_Threshold , 0 );
			AddDoor( GB , MF , X0 , Y0 + H div 2 );
		end;
	end;
end;

Function WallCoverage( GB: GameBoardPtr; X0,Y0,W,H,WallType: Integer ): Integer;
	{ Return the percentage of the map covered in walls. }
var
	X,Y,Walls,Tiles: Integer;
begin
	Walls := 0;
	Tiles := 0;

	for X := X0 to ( X0 + W - 1 ) do begin
		for Y := Y0 to ( Y0 + H - 1 ) do begin
			if TileTerrain( GB,X,Y ) = WallType then Inc( Walls );
			Inc( Tiles );
		end;
	end;
	WallCoverage := ( Walls * 100 ) div Tiles;
end;

Procedure DrawTerrainWithWobblyPen( GB: GameBoardPtr; X,Y,Floor1,Floor2: Integer );
	{ Draw terrain in this spot, and possibly also in the four adjacent spots. }
const
	cardinal_dir: Array [0..3,1..2] of SmallInt = (
	(1,0),(0,1),(-1,0),(0,-1)
	);
var
	t: Integer;
begin
	DrawTerrain( GB , X , Y , Floor1 , Floor2 );
	for t := 0 to 3 do begin
		if ( Random( 3 ) <> 1 ) then begin
			DrawTerrain( GB , X + cardinal_dir[ t , 1 ] , Y + cardinal_dir[ t , 2 ] , Floor1 , Floor2 );
		end;
	end;
end;

Function ProcessCavern( GB: GameBoardPtr;  MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer ): SAttPtr;
	{ Construct a cavern with several chambers. }
begin
	{ Step One: Place the chambers. }

	{ Step Two: Connect the rooms in order. }

end;

Procedure DebugMap( GB: GameBoardPtr; X0,Y0,Wall,Floor1,Floor2: Integer );
	{ Spit out a debugging map of the gameboard. }
var
	X,Y,Terr: Integer;
	msg: String;
	F: Text;
begin
	Assign( F , 'debugmap.txt' );
	Rewrite( F );

	for Y := 1 to GB^.Map_Height do begin
		msg := '';
		for X := 1 to GB^.Map_Width do begin
			if ( X = X0 ) and ( Y = Y0 ) then begin
				msg := msg + '@';
			end else begin
				Terr := TileTerrain( GB , X , Y );
				if Terr = Wall then msg := msg + '#'
				else if Terr = Floor1 then msg := msg + '.'
				else if Terr = Floor2 then msg := msg + ','
				else msg := msg + '?';
			end;
		end;
		writeln( F , msg );
	end;

	Close( F );
end;

Procedure ProcessCarve( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer );
	{ This should draw a cave using the 'L' method. }
var
	Floor1,Floor2,Wall: Integer;
	P: Point;

	Procedure DrawAnL( X , Y: Integer );
	var
		X1,X2,Y1,Y2,XT,YT: Integer;
	begin
		{ Determine X0,X1,Y0,Y1 points. }
		if Random( 2 ) = 1 then begin
			X1 := X - 5 - Random( 16 );
			X2 := X;
		end else begin
			X1 := X;
			X2 := X + 5 + Random( 16 );
		end;
		if Random( 2 ) = 1 then begin
			Y1 := Y - 5 - Random( 16 );
			Y2 := Y;
		end else begin
			Y1 := Y;
			Y2 := Y + 5 + Random( 16 );
		end;
		for XT := X1 to X2 do begin
			DrawTerrainWithWobblyPen( GB , XT , Y , Floor1 , Floor2 );
		end;
		for YT := Y1 to Y2 do begin
			DrawTerrainWithWobblyPen( GB , X , YT , Floor1 , Floor2 );
		end;
	end;

	Procedure AddWayOut;
		{ Far out! Add an exit to this map feature. }
		{ If MF is a scene, add a hidden gate to the parent map. }
		{ Otherwise add a door. }
		Function IsGoodEntrance( X, Y, D: Integer; var P: Point ): Boolean;
			{ Check this point and direction to make sure }
			{ that it links up to a part of the maze. }
		var
			XYFTerr: Integer;
			FoundFloor: Boolean;
			MiniMap: String;
		begin
			{ The entrance must start at a wall; I don't want }
			{ any double doors on the same tile. }
			if TileTerrain( GB , X , Y ) <> Wall then Exit( False );

			{ If we're starting at a wall, check to make sure }
			{ this entrance will connect to the maze. }
			FoundFloor := False;
			{ Keep searching until we find a floor tile or exit }
			{ the bounding box. }
			repeat
				X := X + AngDir[ D , 1 ];
				Y := Y + AngDir[ D , 2 ];
				XYFTerr := TileTerrain( GB , X , Y );
				FoundFloor := ( XYFTerr = Floor1 ) or ( XYFTerr = Floor2 );
			until FoundFloor or not RectPointOverlap( X0 , Y0 , X0 + W - 1 , Y0 + H - 1 , X , Y );
			if FoundFloor then begin
				P.X := X;
				P.Y := Y;
			end;
			IsGoodEntrance := FoundFloor;
		end;
		Procedure DrawBlock( X1,Y1: Integer );
			{ Draw a 3x3 block centered on X,Y. }
		var
			X,Y: Integer;
		begin
			for X := ( X1 - 1 ) to ( X1 + 1 ) do begin
				for Y := ( Y1 - 1 ) to ( Y1 + 1 ) do begin
					DrawTerrain( GB , X , Y , Floor1 , Floor2 );
				end;
			end;
		end;
		Procedure RenderEntrance( E_X0 , E_Y0 , D: Integer; EndPoint: Point );
			{ Render the entrance passageway. }
		var
			X,Y: Integer;
		begin
			{ Add the hallway. }
			X := E_X0;
			Y := E_Y0;
			repeat
				X := X + AngDir[ D , 1 ];
				Y := Y + AngDir[ D , 2 ];
				DrawBlock( X , Y );
			until (( X = EndPoint.X ) and ( Y = EndPoint.Y )) or not RectPointOverlap( X0 , Y0 , X0 + W - 1 , Y0 + H - 1 , X , Y );

			{ Add the door. }
			if ( MF^.G = GG_Scene ) or ( MF^.G = GG_MetaScene ) then begin
				AddHiddenEntrance( GB , E_X0 , E_Y0 , 0 );
			end else begin
				DrawTerrain( GB , E_X0 , E_Y0 , TERRAIN_Threshold , 0 );
				if ( D mod 4 ) = 0 then begin
					DrawTerrain( GB , E_X0 , E_Y0 + 1 , Wall , 0 );
					DrawTerrain( GB , E_X0 , E_Y0 - 1 , Wall , 0 );
				end else begin
					DrawTerrain( GB , E_X0 + 1 , E_Y0 , Wall , 0 );
					DrawTerrain( GB , E_X0 - 1 , E_Y0 , Wall , 0 );
				end;
				AddDoor( GB , MF , E_X0 , E_Y0 );
			end;
		end;
	var
		Tries,DX,DY: Integer;
		P: Point;
	begin
		{ This may take several attempts to get a good entrance... }
		Tries := 50;
		while Tries > 0 do begin
			{ Decide on a random direction and entry point. }
			Case Random( 4 ) of
			0:	begin
					DX := X0 + Random( W - 6 ) + 3;
					DY := Y0;
					if IsGoodEntrance( DX , DY , 2 , P ) then begin
						RenderEntrance( DX , DY , 2 , P );
						Tries := -1;
					end;
				end;
			1:	begin
					DX := X0 + Random( W - 6 ) + 3;
					DY := Y0 + H - 1;
					if IsGoodEntrance( DX , DY , 6 , P ) then begin
						RenderEntrance( DX , DY , 6 , P );
						Tries := -1;
					end;
				end;
			2:	begin
					DX := X0;
					DY := Y0 + Random( H - 6 ) + 3;
					if IsGoodEntrance( DX , DY , 0 , P ) then begin
						RenderEntrance( DX , DY , 0 , P );
						Tries := -1;
					end;
				end;
			else begin
					DX := X0 + W - 1;
					DY := Y0 + Random( H - 6 ) + 3;
					if IsGoodEntrance( DX , DY , 4 , P ) then begin
						RenderEntrance( DX , DY , 4 , P );
						Tries := -1;
					end;
				end;
			end;
			Dec( Tries );
		end;
	end;

begin
	Floor1 := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	Floor2 := DecideTerrainType( MF , Cmd , STAT_MFMarble );
	Wall := DecideTerrainType( MF , Cmd , STAT_MFBorder );

	{ Fill in entire area with rocks. }
	RectFill( GB , Wall , 0 , X0 , Y0 , W , H );

	{ Draw L's until the map is sufficiently perforated. }
	DrawAnL( X0 + ( W div 2 ) , Y0 + ( H div 2 ) );
	while WallCoverage( GB , X0 , Y0 , W , H , Wall ) > 50 do begin
		P.X := X0 + Random( W - 2 ) + 1;
		P.Y := Y0 + Random( H - 2 ) + 1;
		if OnTheMap( GB , P.X , P.Y ) and ( TileTerrain( GB,P.X,P.Y ) <> Wall ) then DrawAnL( P.X , P.Y );
	end;

	{ Seal off the edges. }
	DrawWall( GB, MF, Wall, X0, Y0, W, H, False, False );

	{ At the end, if a way out was requested, draw it. }
	if AStringHasBSTring( GetSpecial( MF ) , 'ADDEXIT' ) then AddWayOut;
end;

Procedure ProcessScatter( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer );
	{ Do a scattering of terrain. Useful for forests, hills, etc. }
var
	T1,T2,T3: Integer;
	N,T: LongInt;
	X,Y: Integer;
begin
	{ Begin by reading the terrain definitions. }
	T1 := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	T2 := DecideTerrainType( MF , Cmd , STAT_MFMarble );
	T3 := DecideTerrainType( MF , Cmd , STAT_MFSpecial );

	{ Calculate how many iterations to do. }
	N := W * H div 2;
	for t := 1 to N do begin
		{ Pick a random point within the bounds. }
		X := X0 + ( W div 2 ) + Random( ( W + 1 ) div 2 ) - Random( ( W + 1 ) div 2 );
		Y := Y0 + ( H div 2 ) + Random( ( H + 1 ) div 2 ) - Random( ( H + 1 ) div 2 );
		if OnTheMap( GB , X , Y ) then begin
			{ Check the terrain at this spot, then move up to the next terrain. }
			if ( TileTerrain( GB , X , Y ) = T1 ) and IsLegalTerrain( T2 ) then begin
				SetTerrain( GB , X , Y , T2 )
			end else if ( TileTerrain( GB , X , Y ) = T2 ) and IsLegalTerrain( T3 ) then begin
				SetTerrain( GB , X , Y , T3 )
			end else if (  TileTerrain( GB , X , Y ) <> T3 ) and IsLegalTerrain( T1 ) then begin
				SetTerrain( GB , X , Y , T1 )
			end;
		end;
	end;
end;

Procedure ProcessEllipse( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer );
	{ Do a vaguely ellipsoid area of terrain. }
var
	T1,T2,T3: Integer;
	X,Y,MX,MY,SX,SY,SR: Integer;
begin
	{ Begin by reading the terrain definitions. }
	T1 := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	T2 := DecideTerrainType( MF , Cmd , STAT_MFMarble );
	T3 := DecideTerrainType( MF , Cmd , STAT_MFSpecial );

	MX := X0 + ( ( W - 1 ) div 2 );
	MY := Y0 + ( ( H - 1 ) div 2 );
	for X := X0 to ( X0 + W - 1 ) do begin
		for Y := Y0 to ( Y0 + H - 1 ) do begin
			if OnTheMap( GB , X , Y ) then  begin
				{ Calculate scaled X and Y values. }
				{ Scale things for a circle of radius 100. }
				SX := Abs( X - MX ) * 100 div W;
				SY := Abs( Y - MY ) * 100 div H;

				{ Calculate the radius to this spot. }
				SR := Range( 0 , 0 , SX , SY );
				if ( SR <= 17 ) and IsLegalTerrain( T3 ) then begin
					SetTerrain( GB , X , Y , T3 );
				end else if ( SR <= 33 ) and IsLegalTerrain( T2 ) then begin
					SetTerrain( GB , X , Y , T2 );
				end else if ( SR <= 50 ) and IsLegalTerrain( T1 ) then begin
					SetTerrain( GB , X , Y , T1 );
				end;
			end;
		end;
	end;
end;

Function SeekRoom( MF: GearPtr; Desig: String ): GearPtr;
	{ Seek a sub-mapfeature with the provided deignation. }
	{ Return NIL if no such map feature could be found. }
begin
	Desig := UpCase( Desig );
	MF := MF^.SubCom;
	while ( MF <> Nil ) and ( UpCase( SAttValue( MF^.SA , 'DESIG' ) ) <> Desig ) do MF := MF^.Next;
	SeekRoom := MF;
end;

Function ProcessLattice( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer ): SAttPtr;
	{ Draw a grid of lines on the map. }
	{ GH2- The lattice will be of 5x5 cells separated by corridors of width 3. }
var
	LineTerr,FieldTerr,MarbleTerr,X,Y,CX,CY,L_W,L_H,X_Offset,Y_Offset: Integer;
	CornerCell: GearPtr;
	Cells: SAttPtr;
begin
	FieldTerr := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	MarbleTerr := DecideTerrainType( MF , Cmd , STAT_MFMarble );
	LineTerr := DecideTerrainType( MF , Cmd , STAT_MFSpecial );
	Cells := Nil;

	{ Fill in entire area with the corridor terrain type. }
	RectFill( GB , LineTerr , 0 , X0 , Y0 , W , H );

	{ Start drawing boxes. }
	{ The first cell needs 7 tiles, plus 8 tiles for each additional cell. }
	L_W := ( W + 1 ) div 8;
	L_H := ( H + 1 ) div 8;

	{ There should be at least one tile's worth of corridor surrounding the cells, and depending }
	{ on the map size there may be as many as 4. Determine the offset to the first cell. }
	X_Offset := ( W - ( L_W * 8 - 3 ) ) div 2 + X0;
	Y_Offset := ( H - ( L_H * 8 - 3 ) ) div 2 + Y0;

	{ I think we're ready to start generating. }
	for CX := 1 to L_W do begin
		for CY := 1 to L_H do begin
			{ Calculate the coordinates of our next cell. }
			X := ( CX - 1 ) * 8 + X_Offset;
			Y := ( CY - 1 ) * 8 + Y_Offset;

			{ If this is one of the four corners, seek the corner cell. }
			if ( CX = 1 ) and ( CY = 1 ) then begin
				CornerCell := SeekRoom( MF , 'NW' );
			end else if ( CX = L_W ) and ( CY = 1 ) then begin
				CornerCell := SeekRoom( MF , 'NE' );
			end else if ( CX = 1 ) and ( CY = L_H ) then begin
				CornerCell := SeekRoom( MF , 'SW' );
			end else if ( CX = L_W ) and ( CY = L_H ) then begin
				CornerCell := SeekRoom( MF , 'SE' );
			end else CornerCell := Nil;

			{ Draw the basic terrain. }
			RectFill( GB , FieldTerr , MarbleTerr , X , Y , 5 , 5 );

			{ Record the cell position. }
			if CornerCell <> Nil then begin
				{ We have a cell that wants to belong here. Store the info. }
				CornerCell^.Stat[ STAT_XPos ] := X;
				CornerCell^.Stat[ STAT_YPos ] := Y;
				CornerCell^.Stat[ STAT_MFWidth ] := 5;
				CornerCell^.Stat[ STAT_MFHeight ] := 5;
			end else begin
				{ Record a new cell. }
				StoreSAtt( Cells , BStr( X ) + ' ' + BStr( Y ) + ' 5 5 ' + BStr( Random( 4 ) ) );
			end;
		end;
	end;

	{ Return the list of cells. }
	ProcessLattice := Cells;
end;

Procedure ProcessCity( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer );
	{ Draw a grid of lines on the map. }
	{ PARAM1: Field Terrain }
	{ PARAM2: Street Terrain }
	{ PARAM3,4,5: Percent chance of small, medium, large buildings }
var
	LineTerr,FieldTerr,X,Y,AChance,BChance,CChance,Roll: Integer;
	P: Point;
	WideX: Boolean;
begin
	FieldTerr := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	LineTerr := DecideTerrainType( MF , Cmd , STAT_MFSpecial );
	AChance := ExtractValue( Cmd );
	BChance := ExtractValue( Cmd );
	CChance := ExtractValue( Cmd );
	WideX := Random( 2 ) = 1;

	{ Fill in entire area with the field terrain type. }
	RectFill( GB , FieldTerr , 0 , X0 , Y0 , W , H );

	{ Draw the vertical lines. }
	P.X := X0 + 1;
	while P.X <= ( X0 + W ) do begin
		for x := P.X to ( P.X + 1 ) do begin
			if X < ( X0 + W ) then begin
				for Y := Y0 to ( Y0 + H - 1 ) do begin
					SetTerrain( GB , X , Y , LineTerr );
				end;
			end;
		end;
		if WideX then begin
			P.X := P.X + 4 + Random( 5 );
		end else begin
			P.X := P.X + 4;
		end;
	end;

	{ Draw the horizontal lines. }
	P.Y := Y0 + 1;
	while P.Y <= ( Y0 + H + 1 ) do begin
		for Y := P.Y to ( P.Y + 1 ) do begin
			if Y < ( Y0 + H ) then begin
				for X := X0 to ( X0 + W - 1 ) do begin
					SetTerrain( GB , X , Y , LineTerr );
				end;
			end;
		end;
		if WideX then begin
			P.Y := P.Y + 4;
		end else begin
			P.Y := P.Y + 4 + Random( 5 );
		end;
	end;

	{ The far line must be composed of LineTerr, otherwise there might be }
	{ some buildings which are inaccessible. }
	if WideX then begin
		For X := X0 to ( X0 + W - 1 ) do begin
			SetTerrain( GB , X , Y0 + H - 1 , LineTerr );
		end;
	end else begin
		For Y := Y0 to ( Y0 + H - 1 ) do begin
			SetTerrain( GB , X0 + W - 1 , Y , LineTerr );
		end;
	end;

	{ Add buildings. }
	for X := X0 to ( X0 + W - 1 ) do begin
		for Y := Y0 to ( Y0 + H - 1 ) do begin
			if TileTerrain( GB , X , Y ) = FieldTerr then begin
				Roll := Random( 100 ) - AChance;
				if Roll < 0 then begin
					SetTerrain( GB , X , Y , TERRAIN_LowBuilding );
				end else if ( Roll - BChance ) < 0 then begin
					SetTerrain( GB , X , Y , TERRAIN_MediumBuilding );
				end else if ( Roll - ( BChance + CChance ) ) < 0 then begin
					SetTerrain( GB , X , Y , TERRAIN_HighBuilding );
				end;
			end;
		end;
	end;
end;

Procedure DrawWall( GB: GameBoardPtr; MF: GearPtr; X, Y, L, Style, WallType: Integer );
	{ Draw a wall starting at X0,Y0 and continuing for L tiles in }
	{ the direction indicated by Style. Use WallType as the wall }
	{ terrain, and DoorPrototype for the door. } 
var
	DL: Integer;	{ Door longitude. The tile at which to add the door. }
	T: Integer;
begin
	{ Select the door point now. }
	DL := Random( L - 2 ) + 2;
	for t := 1 to L do begin
		{ If our point is on the map, do drawing here. }
		if OnTheMap( GB , X , Y ) then begin
			{ If this is our door point, do that now. }
			if T = DL then begin
				SetTerrain( GB , X , Y  , TERRAIN_Threshold );
				AddDoor( GB , MF , X , Y );

			{ Otherwise draw the wall terrain. }
			end else begin
				SetTerrain( GB , X , Y , WallType );

			end;

			if Style = DW_Horizontal then begin
				Inc( X );
			end else begin
				Inc( Y );
			end;
		end;
	end;
end;

Function ProcessMitose( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer ): SAttPtr;
	{ The requested area will split in two. A wall will be drawn }
	{ between the two halves, and a door placed in the wall. }
	{ This division will continue until we have a bunch of little }
	{ rooms. }
var
	Cells: SAttPtr;
	FloorType,WallType: Integer;

	Function IsGoodWallAnchor( AX,AY: Integer ): Boolean;
		{ This spot is a good anchor point for a wall as long as }
		{ there isn't a door. }
	begin
		IsGoodWallAnchor := OnTheMap( GB , AX , AY ) and ( TileTerrain( GB , AX , AY ) <> TERRAIN_Threshold ) and ( TileTerrain( GB , AX , AY ) <> FloorType );
	end;

	Procedure DivideArea( CX0 , CY0 , CW , CH: Integer );
		{ If this area is large enough, divide it into two }
		{ smaller areas, then recurse for each of the }
		{ sub-areas. If it is not large enough, then just }
		{ add its coordinates to the CELLS list. }
		Procedure VerticalDivison;
			{ Attempt to divide this area with a horizontal wall. }
		var
			MaybeD,D,Tries: Integer;
		begin
			tries := 0;
			D := 0;
			repeat
				MaybeD := Random( CH - 10 ) + 5;
				if IsGoodWallAnchor( CX0 - 1 , CY0 + MaybeD ) and IsGoodWallAnchor( CX0 + CW , CY0 + MaybeD ) then D := MaybeD;
				Inc( Tries );
			until ( D <> 0 ) or ( Tries > 15 );

			{ Check to make sure it's a good place. }
			if D <> 0 then begin
				{ Draw the wall. }
				DrawWall( GB, MF , CX0, CY0 + D , CW, DW_Horizontal, WallType );

				{ Recurse to the two sub-areas. }
				DivideArea( CX0 , CY0 , CW , D );
				DivideArea( CX0 , CY0 + D + 1 , CW , CH - D - 1 );

			end else begin
				{ No room for further divisions. Just store this cell. }
				StoreSAtt( Cells , BStr( CX0 ) + ' ' + BStr( CY0 ) + ' ' + BStr( CW ) + ' ' + BStr( CH )  + ' ' + BStr( Random( 4 ) ));
			end;
		end;

		Procedure HorizontalDivison;
			{ Attempt to divide this area with a vertical wall. }
		var
			MaybeD,D,Tries: Integer;
		begin
			tries := 0;
			D := 0;
			repeat
				MaybeD := Random( CW - 10 ) + 5;
				if IsGoodWallAnchor( CX0 + MaybeD , CY0 - 1 ) and IsGoodWallAnchor( CX0 + MaybeD , CY0 + CH ) then D := MaybeD;
				Inc( Tries );
			until ( D <> 0 ) or ( Tries > 15 );

			{ Check to make sure it's a good place. }
			if D <> 0 then begin
				{ Draw the wall. }
				DrawWall( GB, MF , CX0 + D , CY0 , CH, DW_Vertical, WallType );

				{ Recurse to the two sub-areas. }
				DivideArea( CX0 , CY0 , D , CH );
				DivideArea( CX0 + D + 1 , CY0 , CW - D - 1 , CH );

			end else begin
				{ No room for further divisions. Just store this cell. }
				StoreSAtt( Cells , BStr( CX0 ) + ' ' + BStr( CY0 ) + ' ' + BStr( CW ) + ' ' + BStr( CH )  + ' ' + BStr( Random( 4 ) ) );
			end;
		end;
	begin
		if ( CW > 12 ) and ( CH > 5 ) and ( Random( 2 ) = 1 ) then begin
			HorizontalDivison;
		end else if ( CH > 12 ) and ( CW > 5 ) and ( Random( 2 ) = 1 ) then begin
			VerticalDivison;
		end else if ( CW > CH ) and ( CW > 12 ) and ( CH > 4 ) then begin
			HorizontalDivison;
		end else if ( CH > 12 ) and ( CW > 4 ) then begin
			VerticalDivison;
		end else begin
			{ No room for further divisions. Just store this cell. }
			StoreSAtt( Cells , BStr( CX0 ) + ' ' + BStr( CY0 ) + ' ' + BStr( CW ) + ' ' + BStr( CH )  + ' ' + BStr( Random( 4 ) ) );
		end;
	end;
begin
	{ Initialize values. }
	Cells := Nil;
	FloorType := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	WallType  := DecideTerrainType( MF , Cmd , STAT_MFBorder );

	RectFill( GB , FloorType , 0 , X0 + 1 , Y0 + 1 , W - 2 , H - 2 );
	DivideArea( X0 + 1 , Y0 + 1 , W - 2 , H - 2 );
	ProcessMitose := Cells;
end;

Function ProcessMall( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer ): SAttPtr;
	{ Create a bunch of 5x5 rooms. }
var
	Cells: SAttPtr;
	FloorType,WallType: Integer;
	EntranceGrid: GearPtr;
	Extra,CY,DY,Phase,NumColumns,NumRows,RowWidth,T,tt: Integer;
begin
	{ Initialize values. }
	Cells := Nil;
	FloorType := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	WallType  := DecideTerrainType( MF , Cmd , STAT_MFBorder );
	EntranceGrid := SeekRoom( MF , 'EntranceGrid' );

	{ Start with a box. }
	RectFill( GB , WallType , 0 , X0 , Y0 , W , H );
	RectFill( GB , FloorType , 0 , X0 + 1 , Y0 + 1 , W - 2 , H - 2 );
	{ Maybe add the exit, if one was requested. }
	if ASTringHasBString( GetSpecial( MF ) , 'ADDEXIT' ) then begin
		if ( MF^.G = GG_Scene ) or ( MF^.G = GG_MetaScene ) then begin
			SetTerrain( GB , X0 , Y0 + H div 2 + 1 , FloorType );
			SetTerrain( GB , X0 , Y0 + H div 2 , FloorType );
			SetTerrain( GB , X0 , Y0 + H div 2 - 1 , FloorType );
			AddHiddenEntrance( GB , X0 , Y0 + H div 2 , 0 );

		end else begin
			DrawTerrain( GB , X0 , Y0 + H div 2 , TERRAIN_Threshold , 0 );
			AddDoor( GB , MF , X0 , Y0 + H div 2 );
		end;
	end;

	NumColumns := ( W - 1 ) div 6;
	if NumColumns > 1 then Dec( NumColumns );
	NumRows := ( H - 1 ) div 7;
	RowWidth := NumColumns * 6 + 1;
	Phase := 0;
	CY := Y0;
	DY := 8 + ( H - NumRows * 7 ) div ( ( NumRows + 1 ) div 2 );
	Extra := ( H - NumRows * 7 + 1 ) mod ( ( NumRows + 1 ) div 2 );

	for t := 0 to ( NumRows - 1 ) do begin
		RectFill( GB , WallType , 0 , X0 + W - RowWidth , CY , RowWidth , 6 );
		for tt := 0 to ( NumColumns - 1 ) do begin
			StoreSAtt( Cells , BStr( X0 + W - RowWidth + tt * 6 + 1 ) + ' ' + BStr( CY + 1 - Phase ) + ' 5 5 ' + BStr( Phase * 2 ) );
		end;
		if Phase = 0 then begin
			CY := CY + DY;
			if Extra > 0 then begin
				Inc( CY );
				Dec( Extra );
			end;
		end else CY := CY + 5;
		Phase := 1 - Phase;
	end;

	if EntranceGrid <> Nil then begin
		EntranceGrid^.Stat[ STAT_XPos ] := 2;
		EntranceGrid^.Stat[ STAT_YPos ] := 2;
		EntranceGrid^.Stat[ STAT_MFWidth ] := W - RowWidth - 1;
		EntranceGrid^.Stat[ STAT_MFHeight ] := H - 2;
	end;

	ProcessMall := Cells;
end;

Function ProcessCellbox( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer ): SattPtr;
	{ Fill this region with a terrain type, then fill the interior with 5x5 cells. }
var
	T1,T2,X,Y: Integer;
	Cells: SAttPtr;
begin
	T1 := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	T2 := DecideTerrainType( MF , Cmd , STAT_MFMarble );

	{ Fill in the building area with the floor terrain. }
	RectFill( GB , T1 , T2 , X0 , Y0 , W , H );

	{ Next, calculate the locations of all cells. }
	Cells := Nil;
	for X := 1 to (( W - 2 ) div 5 ) do begin
		for Y := 1 to (( H - 2 ) div 5 ) do begin
			StoreSAtt( Cells , BStr( X0 + ( X - 1 ) * 5 + 1 ) + ' ' + BStr( Y0 + ( Y - 1 ) * 5 + 1 ) + ' 5 5 ' + BStr( Random( 4 ) ) );
		end;
	end;

	ProcessCellbox := Cells;
end;

Function ProcessClub( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer ): SAttPtr;
	{ Make a dance club, coffee house, or whatever other kind of sociable meeting place }
	{ might exist in the GearHead universe. This is pretty much like the mall above but }
	{ should feature a whole lot more empty space, with some cells to act as private booths. }
var
	Cells: SAttPtr;
	FloorType,WallType: Integer;
	EntranceGrid: GearPtr;
	T,tt,ExitD: Integer;
	CellWalls: Array [0..3] of Boolean;
	egx,egy,egw,egh: Integer;	{ The width, height, and position of the entrance grid. }
			{ On a club map, the entrance grid serves as the dance floor. }
begin
	{ Initialize values. }
	Cells := Nil;
	FloorType := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	WallType  := DecideTerrainType( MF , Cmd , STAT_MFBorder );
	EntranceGrid := SeekRoom( MF , 'EntranceGrid' );
	for t := 0 to 3 do CellWalls[t] := False;
	egx := 2;
	egy := 2;
	egw := W - 2;
	egh := H - 2;
	ExitD := -1;

	{ Start with a box. }
	RectFill( GB , WallType , 0 , X0 , Y0 , W , H );
	RectFill( GB , FloorType , 0 , X0 + 1 , Y0 + 1 , W - 2 , H - 2 );
	{ Maybe add the exit, if one was requested. }
	if ASTringHasBString( GetSpecial( MF ) , 'ADDEXIT' ) then begin
		if ( MF^.G = GG_Scene ) or ( MF^.G = GG_MetaScene ) then begin
			SetTerrain( GB , X0 , Y0 + H div 2 + 1 , FloorType );
			SetTerrain( GB , X0 , Y0 + H div 2 , FloorType );
			SetTerrain( GB , X0 , Y0 + H div 2 - 1 , FloorType );
			AddHiddenEntrance( GB , X0 , Y0 + H div 2 , 0 );

		end else begin
			DrawTerrain( GB , X0 , Y0 + H div 2 , TERRAIN_Threshold , 0 );
			AddDoor( GB , MF , X0 , Y0 + H div 2 );
		end;
		ExitD := 3;
	end;

	{ Maybe add walls with private rooms, but not to the wall where the exit is. }
	for t := 0 to 3 do begin
		if T <> ExitD then begin
			{ Things will be slightly different whether we're dealing with a }
			{ horizontal edge or a vertical edge. }
			if ( t mod 2 ) = 0 then begin
				if ( egh > 12 ) then begin
					egh := egh - 6;
					if t = 0 then egy := egy + 5;
					CellWalls[t] := True;
				end;
			end else begin
				if ( egw > 12 ) then begin
					egw := egw - 6;
					if t = 3 then egx := egx + 5;
					CellWalls[t] := True;
				end;
			end;
		end;
	end;

	for t := 0 to 3 do begin
		if CellWalls[t] then begin
			{ Draw the wall, add the cells. }
			case T of
			0: 	begin
				RectFill( GB , WallType , 0 , X0 , Y0 , W , 6 );
				for tt := 1 to ( ( W - 12 ) div 6 ) do StoreSAtt( Cells , BStr( X0 + tt * 6 + 1 ) + ' ' + BStr( Y0 + 1 ) + ' 5 5 0' );
				end;
			1: 	begin
				RectFill( GB , WallType , 0 , X0 + W - 6 , Y0 , 6 , H );
				for tt := 1 to ( ( H - 12 ) div 6 ) do StoreSAtt( Cells , BStr( X0 + W - 6 ) + ' ' + BStr( Y0 + tt * 6 + 1 ) + ' 5 5 1' );
				end;
			2: 	begin
				RectFill( GB , WallType , 0 , X0 , Y0 + H - 6 , W , 6 );
				for tt := 1 to ( ( W - 12 ) div 6 ) do StoreSAtt( Cells , BStr( X0 + tt * 6 + 1 ) + ' ' + BStr( Y0 + H - 6 ) + ' 5 5 2' );
				end;
			3: 	begin
				RectFill( GB , WallType , 0 , X0 , Y0 , 6 , H );
				for tt := 1 to ( ( H - 12 ) div 6 ) do StoreSAtt( Cells , BStr( X0 + 1 ) + ' ' + BStr( Y0 + tt * 6 + 1 ) + ' 5 5 3' );
				end;
			end;
		end;

	end;

	if EntranceGrid <> Nil then begin
		EntranceGrid^.Stat[ STAT_XPos ] := egx;
		EntranceGrid^.Stat[ STAT_YPos ] := egy;
		EntranceGrid^.Stat[ STAT_MFWidth ] := egw;
		EntranceGrid^.Stat[ STAT_MFHeight ] := egh;
	end;

	ProcessClub := Cells;
end;

Function ProcessPredrawn( GB: GameBoardPtr ): SAttPtr;
	{ This is a predrawn map. There's no actual rendering to do, but the }
	{ cells to be used are currently stored as the map content. Remove them }
	{ from the map and parse them. }
var
	CellList: SAttPtr;
	Cell: GearPtr;
begin
	CellList := Nil;

	while GB^.Meks <> Nil do begin
		Cell := GB^.Meks;
		DelinkGear( GB^.Meks , Cell );

		{ This gear should be a cell description. Parse it. Parse it real good. }
		StoreSAtt( CellList , BStr( Cell^.Stat[ STAT_PDMC_X ] ) + ' ' + BStr( Cell^.Stat[ STAT_PDMC_Y ] ) + ' ' + BStr( Cell^.Stat[ STAT_PDMC_W ] ) + ' ' + BStr( Cell^.Stat[ STAT_PDMC_H ] ) + ' ' + BStr( Cell^.Stat[ STAT_PDMC_D ] ) );
		DisposeGear( Cell );
	end;

	ProcessPredrawn := CellList;
end;

Function ProcessMonkeyMaze( GB: GameBoardPtr; MF: GearPtr; var Cmd: String; X0,Y0,W,H: Integer ): SAttPtr;
	{ Draw a maze as featured in my non-hit game, Dungeon Monkey. }
	{ This procedure is lifted straight from that game's random map }
	{ generator, actually... It's about time GearHead got a new map }
	{ type, isn't it? }
	{ GHv2: MonkeyMaze altered to generate 7x7 cells instead of the traditional 5x5. }
var
	Cells: SAttPtr;
	FloorType,WallType: Integer;
	NXMax,NYMax: Integer;
const
	VecDir: Array [1..9,1..2] of Integer = (
	(-1, 1),( 0, 1),( 1, 1),
	(-1, 0),( 0, 0),( 1, 0),
	(-1,-1),( 0,-1),( 1,-1)
	);

	Function NodeX( ND: Integer ): Integer;
		{ Convert node coordinate ND to an actual map coordinate. }
	begin
		NodeX := ND * 7 - 4 + X0;
	end;
	Function NodeY( ND: Integer ): Integer;
		{ Convert node coordinate ND to an actual map coordinate. }
	begin
		NodeY := ND * 7 - 4 + Y0;
	end;
	Procedure DrawBlock( X1,Y1: Integer );
		{ Draw a 3x3 block centered on X,Y. }
	var
		X,Y: Integer;
	begin
		for X := ( X1 - 1 ) to ( X1 + 1 ) do begin
			for Y := ( Y1 - 1 ) to ( Y1 + 1 ) do begin
				DrawTerrain( GB , X , Y , FloorType , 0 );
			end;
		end;
	end;
	Function AllNodesConnected: Boolean;
		{ Return TRUE if all the nodes have been connected, or }
		{ FALSE if some of them haven't been. }
	var
		FoundAWall: Boolean;
		NX,NY: Integer;
	begin
		{ At the beginning, we haven't found any walls yet. }
		FoundAWall := False;
		for NX := 1 to NXMax do begin
			for NY := 1 to NYMax do begin
				if TileTerrain( GB , NodeX( NX ) , NodeY( NY ) ) = WallType then FoundAWall := True;
			end;
		end;
		AllNodesConnected := Not FoundAWall;
	end;
	Procedure DrawAnL( NX , NY: Integer );
		{ Draw an L-Shaped corridor on the map, centered on }
		{ node point NX, NY. }
		{ This will be the first structure in the monkeymap. }
	var
		X1,X2,Y1,Y2,XT,YT: Integer;
	begin
		{ Determine X0,X1,Y0,Y1 points. }
		if ( NX > 1 ) and ( ( Random( 2 ) = 1 ) or ( NX = NXMax ) ) then begin
			X1 := NodeX( NX ) - ( 7 * ( Random( NX - 1 ) + 1 ) );
			X2 := NodeX( NX );
		end else begin
			X1 := NodeX( NX );
			X2 := NodeX( NX ) + ( 7 * ( Random( NXMax - NX ) + 1 ) );
		end;
		if ( NY > 1 ) and ( ( Random( 2 ) = 1 ) or ( NY = NYMax ) ) then begin
			Y1 := NodeY( NY ) - ( 7 * ( Random( NY - 1 ) + 1 ) );
			Y2 := NodeY( NY );
		end else begin
			Y1 := NodeY( NY );
			Y2 := NodeY( NY ) + ( 7 * ( Random( NYMax - NY ) + 1 ) );
		end;
		for XT := X1 to X2 do begin
			DrawBlock( XT , NodeY( NY ) );
		end;
		for YT := Y1 to Y2 do begin
			DrawBlock( NodeX( NX ) , YT );
		end;
	end; {DrawAnL}
	Procedure DrawOneLine( NX , NY: Integer );
		{ Draw a regular corridor on the map, centered on }
		{ node point NX, NY. }
	var
		X1,X2,Y1,Y2,XT,YT: Integer;
	begin
		{ Determine X0,X1,Y0,Y1 points. }
		if Random( 2 ) = 1 then begin
			if ( NX > 1 ) and ( ( Random( 2 ) = 1 ) or ( NX = NXMax ) ) then begin
				X1 := NodeX( NX ) - 7;
				X2 := NodeX( NX );
			end else begin
				X1 := NodeX( NX );
				X2 := NodeX( NX ) + 7;
			end;

			for XT := X1 to X2 do begin
				DrawBlock( XT , NodeY( NY ) );
			end;

		end else begin
			if ( NY > 1 ) and ( ( Random( 2 ) = 1 ) or ( NY = NYMax ) ) then begin
				Y1 := NodeY( NY ) - 7;
				Y2 := NodeY( NY );
			end else begin
				Y1 := NodeY( NY );
				Y2 := NodeY( NY ) + 7;
			end;

			for YT := Y1 to Y2 do begin
				DrawBlock( NodeX( NX ) , YT );
			end;
		end;
	end; {DrawOneLine}

	Procedure CarveALine( NX , NY: Integer );
		{ Starting at the indicated node, attempt to carve a line from }
		{ NX,NY to another floor tile. }
	var
		D: Integer;
		X,Y,XF,YF: Integer;
	begin
		{ Select one of the four cardinal directions at random. }
		D := Random( 4 ) * 2 + 2;

		{ We'll use the VecDir array to direct the line. }
		X := NodeX( NX );
		Y := NodeY( NY );

		{ Keep traveling until we either find a floor or go off the map. }
		repeat
			X := X + VecDir[ D , 1 ];
			Y := Y + VecDir[ D , 2 ];
		until ( TileTerrain( GB , X , Y ) = FloorType ) or ( Not RectPointOverlap( X0 , Y0 , X0 + W - 1 , Y0 + H - 1 , X , Y ) );

		{ If we didn't go off the map, we must have hit a floor. Bonus! }
		{ Start carving the line in the randomly prescribed direction. }
		if RectPointOverlap( X0 , Y0 , X0 + W - 1 , Y0 + H - 1 , X , Y ) then begin
			XF := X;
			YF := Y;
			X := NodeX( NX );
			Y := NodeY( NY );
			repeat
				DrawBlock( X , Y );
				X := X + VecDir[ D , 1 ];
				Y := Y + VecDir[ D , 2 ];
			until ( ( X = XF ) and ( Y = YF ) ) or ( Not OnTheMap( GB , X , Y ) );
		end;

	end; {CarveALine}

	Procedure DrawTheMaze;
		{ First step, generate a decent maze. }
	var
		NX,NY,Tries: Integer;
	begin
		{ Start with a random point, then draw an "L" there. }
		NX := Random( NXMax - 2 ) + 2;
		NY := Random( NYMax - 2 ) + 2;
		DrawAnL( NX , NY );

		Tries := 500;

		{ Randomly expand upon this maze until all the nodes have }
		{ been connected to one another. }
		repeat
			for NX := 1 to NXMax do begin
				for NY := 1 to NYMax do begin
					if TileTerrain( GB , NodeX( NX ) , NodeY( NY ) ) = FloorType then begin
						if Random( 12 ) = 1 then begin
							DrawOneLine( NX , NY );
						end;
					end else begin
						CarveALine( NX , NY );
					end;
				end;
			end;

			Dec( Tries );
		until AllNodesConnected or ( Tries < 1 );

	end; {DrawTheMaze}

	Procedure FillDungeon;
		{ Fill the dungeon with rooms. }
	var
		NodeClear: Array [1..MaxMapWidth div 7,1..MaxMapWidth div 7] of Boolean;
			{ Lists nodes which have not yet been developed. }
		X,Y,NumRooms,TRoom: Integer;

		Function SelectClearNode: Point;
			{ Select a node which is free for development. }
		var
			P: Point;
			Tries: Integer;
		begin
			Tries := 500;
			repeat
				P.X := Random( NXMax ) + 1;
				P.Y := Random( NYMax ) + 1;
				Dec( Tries );
			until NodeClear[ P.X , P.Y ] or ( Tries < 1 );
			SelectClearNode := P;
		end;

		Procedure RoomRenderer( NX,NY,NW,NH: Integer );
			{ Render a room, adding doors at whimsy. }
			Procedure MaybeAddDoor( DX,DY: Integer; HorizontalWall: Boolean );
				{ Maybe add a door to this spot, or maybe not. }
			begin
				if Random( 4 ) <> 1 then begin
					if HorizontalWall then begin
						DrawTerrain( GB , DX - 1 , DY , WallType , 0 );
						DrawTerrain( GB , DX + 1 , DY , WallType , 0 );
					end else begin
						DrawTerrain( GB , DX , DY - 1 , WallType , 0 );
						DrawTerrain( GB , DX , DY + 1 , WallType , 0 );
					end;
					DrawTerrain( GB , DX , DY , TERRAIN_Threshold , 0 );
					AddDoor( GB , MF , DX , DY );
				end;
			end;
		var
			X1,Y1,W,H,RX,RY: Integer;
		begin
			X1 := NodeX( NX ) - 2;
			Y1 := NodeY( NY ) - 2;
			W := NW * 7 - 2;
			H := NH * 7 - 2;
			RectFill( GB , FloorType , 0 , X1 , Y1 , W , H );

			for RX := NX to ( NX + NW - 1 ) do begin
				if TileTerrain( GB , NodeX( RX ) , Y1 - 1 ) = FloorType then MaybeAddDoor( NodeX( RX ) , Y1 - 1 , True );
				if TileTerrain( GB , NodeX( RX ) , Y1 + H ) = FloorType then MaybeAddDoor( NodeX( RX ) , Y1 + H , True );
			end;
			for RY := NY to ( NY + NH - 1 ) do begin
				if TileTerrain( GB , X1 - 1 , NodeY( RY ) ) = FloorType then MaybeAddDoor( X1 - 1 , NodeY( RY ) , False );
				if TileTerrain( GB , X1 + W , NodeY( RY ) ) = FloorType then MaybeAddDoor( X1 + W , NodeY( RY ) , False );
			end;

			{ Record this cell in the list. }
			StoreSAtt( Cells , BStr( X1 ) + ' ' + BStr( Y1 ) + ' ' + BStr( W ) + ' ' + BStr( H ) + ' ' + BStr( Random( 4 ) ) );
		end;


		Procedure DrawRoom( NX , NY: Integer );
			{ Draw a small square room centered on this node. }
		var
			NW,NH,TX,TY: Integer;
		begin
			NW := 1;
			NH := 1;

			{ Maybe expand this room, if space permits. }
			if ( NX < ( NXMax - 1 ) ) and ( NY < ( NYMax - 1 ) ) and ( Random( 5 ) = 1 ) then begin
				if NodeClear[ NX + 1 , NY ] and NodeClear[ NX + 1 , NY + 1 ] and NodeClear[ NX , NY + 1 ] then begin
					NW := NW + 1;
					NH := NH + 1;
				end;
			end else if ( NX < ( NXMax - 1 ) ) and ( Random( 4 ) = 1 ) then begin
				TX := Random( 3 ) + 1;
				while ( TX > 0 ) and ( ( NX + NW ) <= NXMax ) do begin
					if NodeClear[ NX + NW , NY ] then begin
						Inc( NW );
						Dec( TX );
					end else begin
						TX := 0;
					end;
				end;
			end else if ( NX < ( NXMax - 1 ) ) and ( Random( 4 ) = 1 ) then begin
				TY := Random( 3 ) + 1;
				while ( TY > 0 ) and ( ( NY + NH ) <= NYMax ) do begin
					if NodeClear[ NX , NY + NH ] then begin
						Inc( NH );
						Dec( TY );
					end else begin
						TY := 0;
					end;
				end;
			end;


			{ Call the renderer, block out the used nodes. }
			RoomRenderer( NX , NY , NW , NH );
			for TX := NX to ( NX + NW - 1 ) do begin
				for TY := NY to ( NY + NH - 1 ) do begin
					NodeCLear[ TX , TY ] := False;
				end;
			end;
		end;
		Procedure AddRandomRoom;
			{ Add a randomly placed room to the map. }
		var
			P: Point;
		begin
			P := SelectClearNode;
			if NodeClear[ P.X , P.Y ] then DrawRoom( P.X , P.Y );
		end;

	begin
		{ First, prepare the nodemap. }
		{ Each node is ready for development if there's a floor tile there. }
		{ It's possible (though unlikely) that the maze generator didn't }
		{ fill the entire map, so check the status of each node tile to see }
		{ whether or not it's okay to build there. }
		for X := 1 to NXMax do begin
			for Y := 1 to NYMax do begin
				NodeClear[ X , Y ] := TileTerrain( GB , NodeX( X ) , NodeY( Y ) ) = FloorType;
			end;
		end;

		NumRooms := ( NXMax * NYMax ) div 3;
		if NumRooms < 1 then NumRooms := 1;
		for TRoom := 1 to NumRooms do begin
			AddRandomRoom;
		end;
	end;

	Procedure AddWayOut;
		{ Far out! Add an exit to this map feature. }
		{ If MF is a scene, add a hidden gate to the parent map. }
		{ Otherwise add a door. }
		Function IsGoodEntrance( X, Y, D: Integer; var P: Point ): Boolean;
			{ Check this point and direction to make sure }
			{ that it links up to a part of the maze. }
		var
			FoundFloor: Boolean;
		begin
			{ The entrance must start at a wall; I don't want }
			{ any double doors on the same tile. }
			if TileTerrain( GB , X , Y ) <> WallType then Exit( False );

			{ If we're starting at a wall, check to make sure }
			{ this entrance will connect to the maze. }
			FoundFloor := False;
			{ Keep searching until we find a floor tile or exit }
			{ the bounding box. }
			repeat
				X := X + AngDir[ D , 1 ];
				Y := Y + AngDir[ D , 2 ];
				FoundFloor := TileTerrain( GB , X , Y ) = FloorType;
			until FoundFloor or not RectPointOverlap( X0 , Y0 , X0 + W - 1 , Y0 + H - 1 , X , Y );
			if FoundFloor then begin
				P.X := X;
				P.Y := Y;
			end;
			IsGoodEntrance := FoundFloor;
		end;
		Procedure RenderEntrance( RE_X0 , RE_Y0 , D: Integer; EndPoint: Point );
			{ Render the maze as per above. }
		var
			X,Y: Integer;
		begin
			{ Add the hallway. }
			X := RE_X0;
			Y := RE_Y0;
			repeat
				X := X + AngDir[ D , 1 ];
				Y := Y + AngDir[ D , 2 ];
				DrawBlock( X , Y );
			until (( X = EndPoint.X ) and ( Y = EndPoint.Y )) or not RectPointOverlap( X0 , Y0 , X0 + W - 1 , Y0 + H - 1 , X , Y );

			{ Add the door. }
			if ( MF^.G = GG_Scene ) or ( MF^.G = GG_MetaScene ) then begin
				AddHiddenEntrance( GB , RE_X0 , RE_Y0 , 0 );
			end else begin
				DrawTerrain( GB , RE_X0 , RE_Y0 , TERRAIN_Threshold , 0 );
				if ( D mod 4 ) = 0 then begin
					DrawTerrain( GB , RE_X0 , RE_Y0 + 1 , WallType , 0 );
					DrawTerrain( GB , RE_X0 , RE_Y0 - 1 , WallType , 0 );
				end else begin
					DrawTerrain( GB , RE_X0 + 1 , RE_Y0 , WallType , 0 );
					DrawTerrain( GB , RE_X0 - 1 , RE_Y0 , WallType , 0 );
				end;
				AddDoor( GB , MF , RE_X0 , RE_Y0 );
			end;
		end;
	var
		Tries,DX,DY: Integer;
		P: Point;
	begin
		{ This may take several attempts to get a good entrance... }
		Tries := 50;
		while Tries > 0 do begin
			{ Decide on a random direction and entry point. }
			Case Random( 4 ) of
			0:	begin
					DX := NodeX( Random( NXMax ) + 1 );
					DY := Y0;
					if IsGoodEntrance( DX , DY , 2 , P ) then begin
						RenderEntrance( DX , DY , 2 , P );
						Tries := Tries - ( 10 + Random( 50 ) );
						if MF^.G = GG_Scene then Tries := -1;
					end;
				end;
			1:	begin
					DX := NodeX( Random( NXMax ) + 1 );
					DY := Y0 + H - 1;
					if IsGoodEntrance( DX , DY , 6 , P ) then begin
						RenderEntrance( DX , DY , 6 , P );
						Tries := Tries - ( 10 + Random( 50 ) );
						if MF^.G = GG_Scene then Tries := -1;
					end;
				end;
			2:	begin
					DX := X0;
					DY := NodeY( Random( NYMax ) + 1 );
					if IsGoodEntrance( DX , DY , 0 , P ) then begin
						RenderEntrance( DX , DY , 0 , P );
						Tries := Tries - ( 10 + Random( 50 ) );
						if MF^.G = GG_Scene then Tries := -1;
					end;
				end;
			else begin
					DX := X0 + W - 1;
					DY := NodeY( Random( NYMax ) + 1 );
					if IsGoodEntrance( DX , DY , 4 , P ) then begin
						RenderEntrance( DX , DY , 4 , P );
						Tries := Tries - ( 10 + Random( 50 ) );
						if MF^.G = GG_Scene then Tries := -1;
					end;
				end;
			end;
			Dec( Tries );
		end;
	end;
begin
	{ Initialize values. }
	Cells := Nil;
	FloorType := DecideTerrainType( MF , Cmd , STAT_MFFloor );
	WallType  := DecideTerrainType( MF , Cmd , STAT_MFBorder );
	NXMax := W div 7;
	NYMax := H div 7;

	{ The entire area starts out devoid of stuff. }
	RectFill( GB , WallType , 0 , X0 , Y0 , W , H );

	{ If we have enough space, add cells! }
	if ( NXMax > 0 ) and ( NYMax > 0 ) then begin
		DrawTheMaze;
		FillDungeon;
		if AStringHasBSTring( GetSpecial( MF ) , 'ADDEXIT' ) then AddWayOut;
	end;

	ProcessMonkeyMaze := Cells;
end;

Function ThingInSpot( GB: GameBoardPtr; X,Y: Integer ): Boolean;
	{ Return TRUE if there's a thing in the specified spot, FALSE otherwise. }
	{ The thing could be either another gear or an obstacle. }
var
	M: GearPtr;
	it: Boolean;
begin
	if not OnTheMap( GB , X , Y ) then Exit( True );

	it := TerrMan[ TileTerrain( GB , X , Y ) ].Pass = -100;
	if ( GB^.Scene <> Nil ) and not it then begin
		M := GB^.Scene^.InvCom;
		while ( M <> Nil ) and not it do begin
			it := ( NAttValue( M^.NA , NAG_Location , NAS_X ) = X ) and ( NAttValue( M^.NA , NAG_Location , NAS_Y ) = Y );
			M := M^.Next;
		end;
	end;
	ThingInSpot := it;
end;

Function SelectSpotInFeature( GB: GameBoardPtr; MF: GearPtr ): Point;
	{ Select a tile within the boundaries of this particular }
	{ map feature. }
var
	P: Point;
	T: Integer;
begin
	{ We will test random points a maximum of 100 times, after which }
	{ we'll just leave it wherever. }
	T := 100;

	repeat
		{ Select random X and Y values within the interior space of this feature. }
		if ( MF^.Stat[ Stat_MFWidth ] > 4 ) and ( MF^.Stat[ Stat_MFHeight ] > 4 ) then begin
			P.X := Random( MF^.Stat[ Stat_MFWidth ] - 4 ) + MF^.Stat[ STAT_XPos ] + 2;
			P.Y := Random( MF^.Stat[ Stat_MFHeight ] - 4 ) + MF^.Stat[ STAT_YPos ] + 2;
		end else if ( MF^.Stat[ Stat_MFWidth ] > 2 ) and ( MF^.Stat[ Stat_MFHeight ] > 2 ) and ( T = 100 ) then begin
			P.X := Random( MF^.Stat[ Stat_MFWidth ] - 2 ) + MF^.Stat[ STAT_XPos ] + 1;
			P.Y := Random( MF^.Stat[ Stat_MFHeight ] - 2 ) + MF^.Stat[ STAT_YPos ] + 1;
		end else if ( MF^.Stat[ Stat_MFWidth ] > 1 ) and ( MF^.Stat[ Stat_MFHeight ] > 1 ) then begin
			P.X := Random( MF^.Stat[ Stat_MFWidth ] ) + MF^.Stat[ STAT_XPos ];
			P.Y := Random( MF^.Stat[ Stat_MFHeight ] ) + MF^.Stat[ STAT_YPos ];
		end else begin
			P.X := MF^.Stat[ STAT_XPos ];
			P.Y := MF^.Stat[ STAT_YPos ];
			T := 0;
		end;
		Dec( T );
	until ( Not ThingInSpot( GB , P.X , P.Y ) ) or ( T < 1 );

	SelectSpotInFeature := P;
end;

Procedure ExpandSuperprop( GB: GameBoardPtr; MF,SPReq: GearPtr );
	{ Expand this SuperProp request. MF is the map feature the prop will be }
	{ placed in. SPReq is the SuperProp request we'll be dealing with. }
var
	SPType: String;
	SPTemp,P: GearPtr;
	ox,oy,x,y,team: Integer;
begin
	{ Begin by selecting the template we'll be using for this superprop. }
	SPType := SAttValue( SPReq^.SA , 'REQUIRES' ) + ' ' + SceneContext( GB , GB^.Scene );
	SPTemp := CloneGear( FindNextComponent( super_prop_list , SPType ) );
	if SPTemp = Nil then begin
		DialogMsg( 'ERROR: Superprop not found for request "' + SPType +'".' );
		Exit;
	end;

	{ Calculate the northwest corner coordinates. }
	ox := MF^.Stat[ STAT_XPos ] + ( MF^.Stat[ STAT_MFWidth ] - SPTemp^.Stat[ STAT_MFWidth ] ) div 2;
	oy := MF^.Stat[ STAT_YPos ] + ( MF^.Stat[ STAT_MFHeight ] - SPTemp^.Stat[ STAT_MFHeight ] ) div 2;

	{ Deploy all the invcoms of the superprop template. }
	P := SPTemp^.InvCom;
	while P <> Nil do begin
		{ Delink this prop from the list. }
		DelinkGear( SPTemp^.InvCom , P );

		{ Megalist over the scripts from the SPReq. }
		BuildMegalist( P , SPReq^.SA );

		{ Determine the correct position, orientation, and team }
		{ for this sub-prop. }
		X := OX + NAttValue( P^.NA , NAG_Location , NAS_X );
		Y := OY + NAttValue( P^.NA , NAG_Location , NAS_Y );
		SetNAtt( P^.NA , NAG_Location , NAS_X , X );
		SetNAtt( P^.NA , NAG_Location , NAS_Y , Y );

		team := NattValue( P^.NA , NAG_Location , NAS_Team ) + STAT_TeamA - 1;
		if ( team >= STAT_TeamA ) and ( team <= STAT_TeamD ) and ( SPReq^.Stat[ team ] <> 0 ) then begin
			SetNAtt( P^.NA , NAG_Location , NAS_Team , SPReq^.Stat[ team ] );
		end else begin
			SetNAtt( P^.NA , NAG_Location , NAS_Team , NAttValue( SPReq^.NA , NAG_Location , NAS_Team ) );
		end;

		{ Scale the prop to the map in question. }
		if GB^.Scene^.G <> GG_World then P^.Scale := GB^.Scene^.V;
		InsertInvcom( GB^.Scene , P );

		P := SPTemp^.InvCom;
	end;
	DisposeGear( SPTemp );
end;

Procedure PlaceMetaTerrain( GB: GameBoardPtr; MF: GearPtr );
	{ This map feature may contain metaterrain gears which }
	{ are meant to be placed inside of it. Do so now. }
var
	MT,MT2: GearPtr;
	P: Point;
begin
	MT := MF^.SubCom;
	while MT <> Nil do begin
		MT2 := MT^.Next;

		{ Check the InvComs for MetaTerrain, placing non-doors }
		{ on the map and deleting doors (since those will already }
		{ have been cloned and placed when the wall was drawn). }
		if ( MT^.G = GG_MetaTerrain ) then begin
			DelinkGear( MF^.SubCOm , MT );

			if MT^.S = GS_MetaDoor then begin
				{ This is a door. Delete it. }
				DisposeGear( MT );
			end else begin
				{ This is not a door. Place it somewhere }
				{ appropriate in the map feature. }
				P := SelectSpotInFeature( GB , MF );
				SetNAtt( MT^.NA , NAG_Location , NAS_X , P.X );
				SetNAtt( MT^.NA , NAG_Location , NAS_Y , P.Y );

				if GB^.Scene^.G <> GG_World then MT^.Scale := GB^.Scene^.V;

				{ Then, stick it into the scene's invcom, }
				{ so DeployJjang will place it on the map. }
				InsertInvCom( GB^.Scene , MT );
			end;

		end else if MT^.G = GG_SuperProp then begin
			ExpandSuperprop( GB , MF , MT );
			RemoveGear( MF^.SubCom , MT );
		end;

		MT := MT2;
	end;
end;

Procedure ShowArea( GB: GameBoardPtr; X0,Y0,W,H: Integer );
	{ Set the "visible" field for all tiles in the requested area to TRUE. }
Var
	X,Y: Integer;
begin
	for X := X0 to ( X0 + W - 1 ) do begin
		for Y := Y0 to ( Y0 + H - 1 ) do begin
			if OnTheMap( GB , X , Y ) then SetVisibility( GB ,X,Y , True );
		end;
	end;
end;

Function MiniMapPosToRegularPos( MX,MY,D: Integer ): Point;
	{ Convert MX,MY on the minimap to regular map coordinates. X and Y must }
	{ be in the range 0..4. D is in the range 0..3, where 0 is regular }
	{ orientation and 1..3 are ninety degree clockwise rotations. }
var
	it: Point;
begin
	if D = 0 then begin
		it.X := MX;
		it.Y := MY;
	end else if D = 1 then begin
		it.X := 4 - MY;
		it.Y := MX;
	end else if D = 2 then begin
		it.X := 4 - MX;
		it.Y := 4 - MY;
	end else begin
		it.X := MY;
		it.Y := 4 - MX;
	end;
	MiniMapPosToRegularPos := it;
end;

Procedure DrawMiniMap( GB: GameBoardPtr; MF: GearPtr; MapDesc: String; D: Integer );
	{ Draw the mini-map }
var
	X,Y,MMX,MMY,T,ED: Integer;
	GBP: Point;
	Palette: Array [5..8] of Integer;
	PlacedItems: Array [0..4,0..4] of GearPtr;
	E: GearPtr;
begin
	if Length( MapDesc ) < 25 then begin
		DialogMsg( 'ERROR: MiniMap fail for ' + GearName( MF ) +  ': "' + MapDesc + '"' );
		exit;
	end;
	{ Locate the palette. }
	for t := 5 to 8 do Palette[ t ] := MF^.Stat[ t ];
	if Palette[ STAT_MFFloor ] = 0 then Palette[ STAT_MFFloor ] := TERRAIN_Floor;
	if Palette[ STAT_MFBorder ] = 0 then Palette[ STAT_MFBorder ] := TERRAIN_Wall;
	if Palette[ STAT_MFMarble ] = 0 then Palette[ STAT_MFMarble ] := TERRAIN_OpenGround;
	if Palette[ STAT_MFSpecial ] = 0 then Palette[ STAT_MFSpecial ] := TERRAIN_GlassWall;

	{ Clear the PlacedItems array. }
	for X := 0 to 4 do for Y := 0 to 4 do PlacedItems[ X , Y ] := Nil;

	X := MF^.Stat[ STAT_XPos ];
	if MF^.Stat[ STAT_MFWidth ] > 6 then begin
		X := X + ( MF^.Stat[ STAT_MFWidth ] - 5 ) div 2;
	end;
	Y := MF^.Stat[ STAT_YPos ];
	if MF^.Stat[ STAT_MFHeight ] > 6 then begin
		Y := Y + ( MF^.Stat[ STAT_MFHeight ] - 5 ) div 2;
	end;

	{ Draw the terrain. }
	for MMX := 0 to 4 do begin
		for MMy := 0 to 4 do begin
			GBP := MiniMapPosToRegularPos( MMX , MMY , D );
			GBP.X := GBP.X + X;
			GBP.Y := GBP.Y + Y;
			case MapDesc[ MMX + MMY * 5 + 1 ] of
				'+':	begin
					SetTerrain( GB , GBP.X , GBP.Y , TERRAIN_Threshold );
					AddDoor( GB , MF , GBP.X , GBP.Y );
					end;
				'?':	begin
					SetTerrain( GB , GBP.X , GBP.Y , Palette[ STAT_MFBorder ] );
					InstallDoor( GB , MF , GBP.X , GBP.Y , 0 , 5 + Random( 11 ) );
					end;
				'=':	begin
					SetTerrain( GB , GBP.X , GBP.Y , TERRAIN_Threshold );
					InstallDoor( GB , MF , GBP.X , GBP.Y , 5 + Random( 11 ) , 0 );
					end;
				'#':	SetTerrain( GB , GBP.X , GBP.Y , Palette[ STAT_MFBorder ] );
				',':	SetTerrain( GB , GBP.X , GBP.Y , Palette[ STAT_MFMarble ] );
				'&':	SetTerrain( GB , GBP.X , GBP.Y , Palette[ STAT_MFSpecial ] );
				'^':	SetTerrain( GB , GBP.X , GBP.Y , TERRAIN_Wreckage );
				'%':	SetTerrain( GB , GBP.X , GBP.Y , TERRAIN_Rubble );
				'-':	SetTerrain( GB , GBP.X , GBP.Y , TERRAIN_Threshold );
				' ':	{Do Nothing};

			else SetTerrain( GB , GBP.X , GBP.Y , Palette[ STAT_MFFloor ] );
			end;
		end;
	end;

	{ Place the invcoms. }
	while MF^.InvCom <> Nil do begin
		E := MF^.InvCom;
		DelinkGear( MF^.InvCom , E );
		InsertInvCom( GB^.Scene , E );
		T := NAttValue( E^.NA , NAG_ComponentDesc , NAS_ELementID );
		MMX := Pos( BStr( T ) , MapDesc ) - 1;
		if ( MMX < 0 ) or ( MMX > 24 ) then begin
			DialogMsg( 'ERROR: ' + GearName( E ) + ' ' + BStr( T ) + '/' + BStr( MMX ) + ' ' + MapDesc );
		end else begin
			GBP := MiniMapPosToRegularPos( MMX mod 5 , MMX div 5 , D );
			PlacedItems[ GBP.X , GBP.Y ] := E;
			GBP.X := GBP.X + X;
			GBP.Y := GBP.Y + Y;
			ED := ( NAttValue( E^.NA , NAG_ParaLocation , NAS_D ) + D * 2 ) mod 8;
			SetNAtt( E^.NA , NAG_Location , NAS_X , GBP.X );
			SetNAtt( E^.NA , NAG_Location , NAS_Y , GBP.Y );
			SetNAtt( E^.NA , NAG_Location , NAS_D , ED );
		end;
	end;

	{ Finally, render the SECRET MESSAGE, just like Groo the Wanderer but way more obvious. }
	{ If a message is tagged onto the end of the minimap, render this using the various }
	{ placed item's ROGUECHAR attributes. This way, in ASCII mode, the shops should spell }
	{ out what they sell. }
	if Length( MapDesc ) >= 30 then begin
		{ The message appears in the top line of the minimap. This is going to change based on }
		{ the direction of rendering. }
		if ( D = 0 ) or ( D = 2 ) then begin
			if D = 0 then Y := 0
			else Y := 4;
			for X := 0 to 4 do begin
				if PlacedItems[ X , Y ] <> Nil then begin
					SetSAtt( PlacedItems[ X , Y ]^.SA , 'roguechar <' + MapDesc[ 26 + X ] + '>' );
				end;
			end;
		end else begin
			if D = 3 then X := 0
			else X := 4;
			for Y := 0 to 4 do begin
				if PlacedItems[ X , Y ] <> Nil then begin
					SetSAtt( PlacedItems[ X , Y ]^.SA , 'roguechar <' + MapDesc[ 26 + Y ] + '>' );
				end;
			end;
		end;
	end;
end;

Function TheRenderer( GB: GameBoardPtr; MF: GearPtr; X , Y , W , H , Style: Integer ): SAttPtr;
	{ Do some damage to the game board in the shape of this feature. }
	{ This function returns the STYLE of the part; }
	{ it describes what kind of feature we should be drawing. }
var
	Command_String,Cmd,Special: String;
	Cells: SAttPtr;
begin
	{ Determine the command string to use for this feature. }
	Command_String := '';
	if MF <> Nil then Command_String := SAttValue( MF^.SA , 'PARAM' );
	if Command_String = '' then Command_String := SAttValue( Standard_Param_List , 'PARAM' + BStr( Style ) );
	if Command_String = '' then Command_String := SAttValue( Standard_Param_List , 'PARAMDEFAULT' );

	Cells := Nil;

	while Command_String <> '' do begin
		cmd := UpCase( ExtractWord( Command_String ) );

		if cmd = 'FILL' then begin
			ProcessFill( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'WALL' then begin
			ProcessWall( GB , MF , Command_String , X , Y , W , H , False , False );

		end else if cmd = 'OWALL' then begin
			ProcessWall( GB , MF , Command_String , X , Y , W , H , True , False );

		end else if cmd = 'DWALL' then begin
			ProcessWall( GB , MF , Command_String , X , Y , W , H , True , True );

		end else if cmd = 'CARVE' then begin
			ProcessCarve( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'SCATTER' then begin
			ProcessScatter( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'ELLIPSE' then begin
			ProcessEllipse( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'LATTICE' then begin
			if Cells <> Nil then DisposeSAtt( Cells );
			Cells := ProcessLattice( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'MITOSE' then begin
			if Cells <> Nil then DisposeSAtt( Cells );
			Cells := ProcessMitose( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'MALL' then begin
			if Cells <> Nil then DisposeSAtt( Cells );
			Cells := ProcessMall( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'CLUB' then begin
			if Cells <> Nil then DisposeSAtt( Cells );
			Cells := ProcessClub( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'MONKEYMAZE' then begin
			if Cells <> Nil then DisposeSAtt( Cells );
			Cells := ProcessMonkeyMaze( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'CITY' then begin
			ProcessCity( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'CELLBOX' then begin
			if Cells <> Nil then DisposeSAtt( Cells );
			Cells := ProcessCellbox( GB , MF , Command_String , X , Y , W , H );

		end else if cmd = 'PREDRAWN' then begin
			{ This is a predrawn map- the only thing the renderer needs to do }
			{ is parse the cells. }
			if Cells <> Nil then DisposeSAtt( Cells );
			Cells := ProcessPredrawn( GB );

		end;
	end;

	{ If this map feature has a minimap stamp, apply that now. }
	if ( MF <> Nil ) and ( SAttValue( MF^.SA , 'MINIMAP' ) <> '' ) then begin
		DrawMiniMap( GB , MF , SAttValue( MF^.SA , 'MINIMAP' ) , NAttValue( MF^.NA , NAG_Location , NAS_D ) );
	end;

	if ( GearName( GB^.Scene ) = 'DEBUG' ) and HeadMatchesString( 'ZONE_' , GearName( MF ) ) then begin
		DialogMsg( 'Rendering ' + GearName( MF ) + ': ' + SAttValue( MF^.SA , 'MINIMAP' ) );
	end;

	{ Handle any SPECIAL commands associated with this map feature. }
	if ( MF <> Nil ) then begin
		Special := GetSpecial( MF );

		{ If this feature is indicated as the starting point for this scene }
		{ set the ParaX , ParaY attributes now. }
		if AStringHasBString( Special , SPECIAL_ShowAll ) then begin
			ShowArea( GB , X , Y , W , H );
		end else if IsAScene( MF ) and ( MF^.Stat[ STAT_SpaceMap ] <> 0 ) then begin
			{ Scrolling space maps also start out all revealed. }
			ShowArea( GB , X , Y , W , H );
		end;
		if AStringHasBString( Special , SPECIAL_ConvertDoors ) then begin
			ConvertDoors( GB , SeekCurrentLevelGear( MF^.SubCom , GG_MetaTerrain , GS_MetaDoor ) , MF^.Stat[ STAT_XPos ] , MF^.Stat[ STAT_YPos ] , MF^.Stat[ STAT_MFWidth ] , MF^.Stat[ STAT_MFHeight ] );
		end;
	end;

	{ Place any metaterrain associated with this feature. }
	if MF <> Nil then PlaceMetaTerrain( GB , MF );

	TheRenderer := Cells;
end;

Procedure DoGapFilling( GB: GameBoardPtr; Container: GearPtr; C_X,C_Y,C_W,C_H,SCheck,STerr: Integer; Gapfill_String: String; var Cells: SAttPtr );
	{ Search the container for empty regions, filling them with junk }
	{ as appropriate. }
	{ GH2- if any cells remain unfilled, fill them now. }
const
	MaxGFStyle = 7;
var
	GFStyle: Array [0..MaxGFStyle] of Integer;
	NumStyle: Integer;
	Procedure AddGFMF( X , Y , W , H: Integer );
		{ Add a new map feature in the specified location. }
	var
		Style: Integer;
		NewMF: GearPtr;
	begin
		Style := GFStyle[ Random( NumStyle ) ];
		if Container <> Nil then begin
			{ Create a new gear for this gap filler. }
			NewMF := NewGear( Nil );
			InsertSubCom( Container , NewMF );
			NewMF^.G := GG_MapFeature;
			NewMF^.S := Style;
			InitGear( NewMF );
			NewMF^.Stat[ STAT_XPos ] := X;
			NewMF^.Stat[ STAT_YPos ] := Y;
			NewMF^.Stat[ STAT_MFHeight ] := H;
			NewMF^.Stat[ STAT_MFWidth ] := W;
		end else begin
			NewMF := Nil;
		end;

		{ Mark this map feature as temporary. }
		SetNAtt( NewMF^.NA , NAG_EpisodeData , NAS_Temporary , 1 );

		{ Render it on the map. }
		TheRenderer( GB , NewMF , X , Y , W , H , Style );
	end;
var
	P: Point;
	T,W,H: Integer;
	C: SAttPtr;
begin
	{ Extract the GF styles. }
	NumStyle := 0;
	for t := 0 to MaxGFStyle do begin
		GFStyle[ T ] := ExtractValue( Gapfill_String );
		if GFStyle[ t ] <> 0 then Inc( NumStyle );
	end;
	if NumStyle = 0 then begin
		DisposeSAtt( Cells );
		Exit;
	end;

	{ Use up any remaining cells. }
	C := Cells;
	while C <> Nil do begin
		P.X := ExtractValue( C^.Info );
		P.Y := ExtractValue( C^.Info );
		W := ExtractValue( C^.Info );
		H := ExtractValue( C^.Info );
		AddGFMF( P.X , P.Y , W , H );
		C := C^.Next;
	end;
	DisposeSAtt( Cells );

	{ If the container area meets our minimum size, add more stuff. }
	if ( C_W > 12 ) and ( C_H > 12 ) then begin
		{ Try to place an item on the map 100 times. }
		for t := 1 to 15000 do begin
			{ Choose a random width, height, and placement point in container. }
			W := Random( 15 ) + 3;
			H := Random( 15 ) + 3;
			P := RandomPointWithinBounds( Container , W , H );

			{ if this placement point is good, i.e. empty, then }
			{ fill it with one of the style types taken from the }
			{ GapFiller parameter string. }
			if PlacementPointIsGood( GB , Container , SCheck , STerr , P.X , P.Y , W , H  ) then begin
				AddGFMF( P.X , P.Y , W , H );
			end;
		end; { for t = 1 to 100 }
	end;
end;

Function SubZoneType( MF: GearPtr ): Integer;
	{ Return the map generator type to be used for a sub-zone of this map feature. }
var
	SZT: String;
begin
	SZT := SAttValue( MF^.SA , 'SUBZONE' );
	if SZT = '' then begin
		if IsAScene( MF ) then begin
			SZT := SAttValue( Standard_Param_List , 'SUBZONE' + BStr( MF^.STAT[ STAT_MapGenerator ] ) );
		end else if MF^.G = GG_MapFeature then begin
			SZT := SAttValue( Standard_Param_List , 'SUBZONE' + BStr( MF^.S ) );
		end;
	end;
	SubZoneType := ExtractValue( SZT );
end;

Function NewSubZone( MF: GearPtr ): GearPtr;
	{ Return a new map feature that's a subcomponent of the current one, }
	{ complete with its parent's palette and chosen child type. }
var
	it: GearPtr;
begin
	it := NewGear( Nil );
	it^.G := GG_MapFeature;
	it^.S := SubZoneType( MF );
	InitGear( it );
	it^.Stat[ STAT_MFHeight ] := 3;
	it^.Stat[ STAT_MFWidth ] := 3;
	if MF^.G = GG_MapFeature then begin
		it^.Stat[ STAT_MFFloor ] := MF^.Stat[ STAT_MFFloor ];
		it^.Stat[ STAT_MFMarble ] := MF^.Stat[ STAT_MFMarble ];
		it^.Stat[ STAT_MFBorder ] := MF^.Stat[ STAT_MFBorder ];
		it^.Stat[ STAT_MFSpecial ] := MF^.Stat[ STAT_MFSpecial ];
	end;
	InsertSubCom( MF , it );
	NewSubZone := it;
end;

Function FindFreeZone( GB: GameBoardPtr; MF: GearPtr; var Cells: SAttPtr; SCheck,STerr: Integer ): GearPtr;
	{ Attempt to locate a free space in which to add some new content. }
var
	it: GearPtr;
	T: Integer;
begin
	it := NewSubZone( MF );
	{ Because we're gonna place some content here, make the zone bigger than the default 3x3 }
	it^.Stat[ STAT_MFHeight ] := 5;
	it^.Stat[ STAT_MFWidth ] := 5;
	for t := 5 to 8 do it^.Stat[t] := MF^.Stat[t];
	SetSAtt( it^.SA , 'name <ZONE_' + BStr( High_Component_ID ) + '>' );

	if not SelectPlacementPoint( GB , MF , it , Cells , SCheck , STerr ) then begin
		RemoveGear( MF^.SubCom , it );
		FindFreeZone := Nil;
	end else begin
		FindFreeZone := it;
	end;
end;

Procedure FormatContentStrings( C: GearPtr; ID: Integer; P: String );
	{ Format this random content. }
	Procedure FormatThisPart( Part: GearPtr );
	var
		S: SATtPtr;
		T: Integer;
	begin
		S := Part^.SA;
		while S <> Nil do begin
			ReplacePat( S^.Info , '%id%' , BStr( ID ) );
			ReplacePat( S^.Info , '%param%' , P );
			for t := 1 to Num_Plot_Elements do begin
				ReplacePat( S^.Info , '%name' + BStr( T ) + '%' , SAttValue( C^.SA , 'NAME_' + BStr( T ) ) );
				ReplacePat( S^.Info , '%' + BStr( T ) + '%' , BStr( ElementID( C , T ) ) );
			end;
			S := S^.Next;
		end;
	end;
	Procedure FormatAlongPath( Part: GearPtr );
	begin
		while Part <> Nil do begin
			FormatThisPart( Part );
			FormatAlongPath( Part^.InvCom );
			FormatALongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
begin
	FormatThisPart( C );
	FormatAlongPath( C^.SubCom );
	FormatAlongPath( C^.InvCom );
end;


Function ContentInitOkay( C,Zone,Source: GearPtr; P: String; GB: GameBoardPtr; var Cells: SAttPtr; SCheck,STerr: Integer ): Boolean;
	{ Return TRUE if this component is initialized okay, or FALSE otherwise. }
	{ If initialization fails, delete the content C. }
	{ ZONE refers to the map feature where this content is located. }
	{   It must be a subcom of the "container". }
	{ P is the parameter passed by the calling procedure. }
	{ GB is the gameboard pointer. Duh. }
var
	throw,cmd,ThrowType: String;
	AllOK,Optional,NewMF: Boolean;
	ThrowParam: String;
	SA: SAttPtr;
	TZone,I: GearPtr;
begin
	{ Initialize the values. }
	Inc( High_Component_ID );
	SetNAtt( C^.NA , NAG_ComponentDesc , NAS_CompUID , High_Component_ID );
	SetSAtt( C^.SA , 'HOME <' + GearName( ZONE ) + '>' );

	{ Initialize the InvComs. }
	I := C^.InvCom;
	while I <> Nil do begin
		{ Character gears have to be individualized. }
		if ( I^.G = GG_Character ) and NotAnAnimal( I ) and ( NAttValue( C^.NA , NAG_Narrative , NAS_ContentID ) = 0 ) then begin
			IndividualizeNPC( I );
		end;
		I := I^.Next;
	end;

	{ Attempt to add this component to the adventure, selecting components and so forth. }
	{ If this check fails, then the content C will be deleted. }
	AllOK := InsertRSC( Source , C , GB );
	if not AllOk then Exit( False );

	{ Format all of the strings in this component. }
	FormatContentStrings( C , High_Component_ID , P );

	NewMF := False;

	{ Recursively add any further components that are needed. }
	SA := C^.SA;
	while ( SA <> Nil ) and AllOK do begin
		if HeadMatchesString( 'CONTENT' , SA^.Info ) then begin
			throw := RetrieveAString( SA^.Info );

			{ It's time to throw a request for a new component. }
			{ PARAM 1: OPTIONAL or REQUIRED }
			cmd := ExtractWord( throw );
			Optional := AStringHasBString( cmd , 'O' );

			{ PARAM 2: COMPONENT TYPE }
			ThrowType := ExtraCTWord( throw );

			{ PARAM 3: The component parameter. }
			ThrowParam := ExtractWord( throw );

			{ PARAM 4: COMPONENT DESTINATION }
			cmd := ExtractWord( throw );
			if UpCase( cmd[1]) = 'L' then begin
				TZone := Zone;
				NewMF := False;
			end else begin
				TZone := FindFreeZone( GB , Zone^.Parent , Cells,SCheck,STerr );
				NewMF := True;
			end;

			{ If the scene request has resulted in an acceptable range, }
			{ attempt to load the new parameter here. }
			if TZone <> Nil then begin
				if Not Optional then begin
					AllOK := AddContent( ThrowType , GB , Source , TZone , ThrowParam , Cells , SCheck , STerr );
					if NewMF and not AllOk then RemoveGear( TZone^.Parent^.SubCom , TZone );
				end else if Random( 2 ) = 1 then begin
					if not AddContent( ThrowType , GB , Source , TZone , ThrowParam , Cells , SCheck , STerr ) then begin
						if NewMF then RemoveGear( TZone^.Parent^.SubCom , TZone );
					end;
				end else if NewMF then begin
					RemoveGear( TZone^.Parent^.SubCom , TZone );
				end;
			end else AllOK := Optional;
		end;
		SA := SA^.Next;
	end;

	{ If there was a problem, delete C. }
	{ ASSERT: C will be located as a invcom of Source, having been placed there }
	{  by the InsertStoryArc procedure. }
	if not AllOk then begin
		RemoveGear( Source^.InvCom , C );
	end;

	ContentInitOkay := AllOk;
end;

Procedure InsertContentFragment( GB: GameBoardPtr; Adv,C: GearPtr );
	{ A plot has been loaded which is actually a content fragment. This is what we need }
	{ to do: }
	{ - Copy the plot scripts to the scene gear in megalist fashion. }
	{ - Copy the personas needed to the scene and set their correct CIDs. }
	{ - Move the requested gears to the scene, assign teams and homes. }
	{   Don't move gears which have a PLACE string assigned; these have already been moved. }
var
	ZONE,E,P,P2,Team,Door: GearPtr;
	T: Integer;
	Loc: Point;
	MiniMap,Z_Special,TeamData: String;
begin
	{ Copy the scripts to the local megalist. }
	BuildMegalist( GB^.Scene , C^.SA );

	{ Locate the zone assigned to this content. }
	Zone := SeekChildByName( GB^.Scene , SAttValue( C^.SA , 'HOME' ) );
	MiniMap := SAttValue( C^.SA , 'MINIMAP' );
	if ( MiniMap <> '' ) and ( Zone <> Nil ) then SetSAtt( Zone^.SA , 'MINIMAP <' + MINIMAP + '>' );
	if Zone <> Nil then begin
		Z_Special := SAttValue( ZONE^.SA , 'SPECIAL' ) + ' ' + SAttValue( C^.SA , 'ZONE_SPECIAL' );
		SetSAtt( Zone^.SA , 'SPECIAL <' + Z_Special + '>' );
	end;

	{ Copy over the door prototype, if present. }
	Door := SeekCurrentLevelGear( C^.SubCom , GG_MetaTerrain , GS_MetaDoor );
	if Door <> Nil then begin
		DelinkGear( C^.SubCom , Door );
		InsertSubCom( Zone , Door );
	end;

	if GearName( GB^.Scene ) = 'DEBUG' then begin
		DialogMsg( '"' + SAttValue( C^.SA , 'requires' ) + '" inserted in ' + SAttValue( C^.SA , 'HOME' ) + ':' + MiniMap );
		if ( Zone = Nil ) then DialogMsg( 'ERROR: ' + SAttValue( C^.SA , 'HOME' ) + ' not found.' );
	end;


	for t := 1 to Num_Plot_Elements do begin
		{ See if there's an element in this slot. }
		E := SeekPlotElement( Adv , C , T , GB );

		{ If there is an element, we have to deal with it. }
		if ( E <> Nil ) and ( E^.G >= 0 ) and ( SATtValue( C^.SA , 'PLACE' + BStr( T ) ) = '' ) then begin
			DelinkGearForMovement( GB , E );

			{ If E is prefab, don't store an original home, but do save the PlotID. }
			if AStringHasBString( SAttValue( C^.SA , 'ELEMENT' + BStr( T ) ) , 'PREFAB' ) then begin
				SetNAtt( E^.NA , NAG_ParaLocation , NAS_OriginalHome , 0 );
				SetNAtt( E^.NA , NAG_Narrative , NAS_PlotID , NAttValue( GB^.Scene^.NA , NAG_Narrative , NAS_PlotID ) );
			end;

			if ( MiniMap <> '' ) and ( Pos( BStr( T ) , MiniMap ) > 0 ) then begin
				{ Since we have a minimap, store the element temporarily in the map feature. }
				{ It will be deployed by the renderer. }
				InsertInvCom( Zone , E );
				SetNAtt( E^.NA , NAG_ComponentDesc , NAS_ELementID , T );
			end else begin
				InsertInvCom( GB^.Scene , E );
				Loc := SelectSpotInFeature( GB , Zone );
				if OnTheMap( GB , Loc.X , Loc.Y ) and not ThingInSpot( GB , Loc.X , Loc.Y ) then begin
					SetNAtt( E^.NA , NAG_Location , NAS_X , Loc.X );
					SetNAtt( E^.NA , NAG_Location , NAS_Y , Loc.Y );
				end else begin
					SetSATt( E^.SA , 'HOME <' + GEarName( Zone ) + '>' );
				end;
			end;

			if IsMasterGear( E ) then begin
				Team := SeekChildByName( GB^.SCENE , SAttValue( C^.SA , 'TEAM' + BStr( T ) ) );
				if Team <> Nil then begin
					SetNAtt( E^.NA , NAG_Location , NAS_Team , Team^.S );
				end else begin
					TeamData := SAttValue( C^.SA , 'TEAMDATA' + BStr( T ) );
					if ( TeamData <> '' ) or ( E^.G <> GG_Prop ) then begin
						SetSAtt( E^.SA , 'TEAMDATA <' + TeamData + '>' );
						ChooseTeam( E , GB^.Scene );
					end;
				end;
			end;
		end;
	end;

	{ Copy the personas from this component. }
	P := C^.SubCom;
	while P <> Nil do begin
		P2 := P^.Next;

		if P^.G = GG_Persona then begin
			{ Delink it from the plot. }
			DelinkGear( C^.SubCom , P );
			{ Set the correct CID code for this persona. }
			P^.S := ElementID( C , P^.S );

			{ Also record the Plot ID. }
			SetNAtt( P^.NA , NAG_Narrative , NAS_PlotID , NAttValue( GB^.Scene^.NA , NAG_Narrative , NAS_PlotID ) );

			{ Stick it where it needs to go. }
			InsertSubCom( GB^.Scene , P );
		end;

		P := P2;
	end;
end;

Procedure InsertFinishedContent( GB: GameBoardPtr; Adv,Source: GearPtr );
	{ Here's what this procedure has to do: Search through the invcoms of SOurce }
	{ for random scene content. When some has been found, call the insertion procedure }
	{ to move it to the gameboard. Then, delete this plot and move on to the next }
	{ one. }
var
	C,C2: GearPtr;
begin
	C := Source^.InvCom;

	while C <> Nil do begin
		C2 := C^.Next;

		if ( C^.G = GG_Plot ) and ( NAttValue( C^.NA , NAG_ComponentDesc , NAS_CompUID ) > 0 ) then begin
			{ Insert the content, then delete from the adventure. }
			InsertContentFragment( GB , Adv , C );
			RemoveGear( Source^.InvCom , C );
		end;

		C := C2;
	end;

end;

Function CreateContentList( Scene: GearPtr; const Context: String ): NAttPtr;
	{ Create a list holding all content that might be chosen for the specified context. }
	{ This list is in the regular format of component lists- the G and S values both }
	{ indicate a component index, and V indicates the component match weight. In this case }
	{ a positive index indicates regular random scene content, while a negative index }
	{ indicates unique scene content. }
const
	standard_content_multiplier = 5; { Standard, non-unique content is more likely to show up }
					{ than the unique stuff. This multiplier tells by how much. }
var
	it: NAttPtr;	{ The list we're generating. }
	C: GearPtr;
	N,MW: Integer;	{ A counter, and the current match weight. }
begin
	{ First, harvest the content from the standard list. }
	it := Nil;
	C := random_scene_content;
	N := 1;
	while C <> nil do begin
		MW := StringMatchWeight( Context , SAttValue( C^.SA , 'REQUIRES' ) );
		if MW > 0 then begin
			{ Regular scene content gets a multiplier to match weight. }
			SetNAtt( it , N , N , MW * standard_content_multiplier );
		end;
		Inc( N );
		C := C^.Next;
	end;

	{ Next, maybe add some unique content possibilities. }
	if Scene <> Nil then begin
		C := SeekCurrentLevelGear( FindRoot( Scene )^.InvCom , GG_ContentSet , 0 );
		if C <> Nil then begin
			C := C^.InvCom;
			N := -1;
			while C <> nil do begin
				MW := StringMatchWeight( Context , SAttValue( C^.SA , 'REQUIRES' ) );
				if MW > 0 then begin
					SetNAtt( it , N , N , MW );
				end;
				Dec( N );
				C := C^.Next;
			end;
		end;
	end;
	CreateContentList := it;
end;

Function ChooseSceneContent( Scene: GearPtr; var ShoppingList: NAttPtr; const Context: String ): GearPtr;
	{ Given this shopping list, select a component for inclusion in SCENE. }
	{ Positive indicies indicate regular scene content while negative indicies indicate }
	{ unique content. }
	{ Return a clone of the selected content, marked with the supplied context. }
var
	it: NAttPtr;
	N: Integer;
	C,UniCon: GearPtr;
begin
	if ShoppingList = Nil then Exit( Nil );

	{ Step one- select one of the shopping list entries. }
	it := RandomComponentListEntry( ShoppingList );

	{ If this list entry is positive, select the component from random_scene_content. }
	{ Otherwise, select the component from the unique scene content collection. }
	N := it^.S;
	RemoveNAtt( ShoppingList , it );
	if N > 0 then begin
		C := RetrieveGearSib( random_scene_content , N );
	end else if N < 0 then begin
		if Scene <> Nil then begin
			UniCon := SeekCurrentLevelGear( FindRoot( Scene )^.InvCom , GG_ContentSet , 0 );
			if UniCon <> Nil then begin
				C := RetrieveGearSib( UniCon^.InvCom , Abs( N ) );
			end else begin
				DialogMsg( 'ERROR: Unique Content not found in ChooseSceneContent.' );
				C := Nil;
			end;
		end else begin
			DialogMsg( 'ERROR: Scene not found in ChooseSceneContent.' );
			C := Nil;
		end;
	end else begin
		{ Error- we shouldn't get a zero here. }
		DialogMsg( 'ERROR: Zero generated in ChooseSceneContent.' );
		C := Nil;
	end;

	{ We now have a pointer to the prototype for this content. Clone it, set its }
	{ context attribute, and return it. }
	if C <> Nil then begin
		C := CloneGear( C );
		SetSAtt( C^.SA , 'CONTEXT <' + Context + '>' );
	end;
	ChooseSceneContent := C;
end;

Function AddContent( CType: String; GB: GameboardPtr; Source,Zone: GearPtr; P: String; var Cells: SAttPtr; SCheck,STerr: Integer ): Boolean;
	{ Add some random content to this map feature. }
	{ A content type has been requested. Add it. If additional content(s) }
	{ are requested, add those as well. If the installation fails }
	{ delete the content currently added (upper level content has already been }
	{ deleted by recursive calls to this function, and lower level content will }
	{ be deleted if nessecary when the function exits). }
	{ CType describes the context by which the new content should be chosen. }
	{    It should include a type label preceded by "*". }
	{ Source is the place where the components will be temporarily installed- }
	{    it is either a story or the adventure itself. }
	{ Zone is the specific map feature where the content will be placed. }
	{    it is a subcom of a "container" map feature. }
	{ P is the parameter passed to the new component. }
	{ Cells, SCheck, and STerr are variables needed when adding a new map feature. }
var
	AllOK: Boolean;
	CList: NAttPtr;
	C,C2: GearPtr;
	ContentID: LongInt;
begin
	{ Create the list of potential components. }
	{ Start by calculating the context type for the random map content. }
	CType := CType + ' ' + SceneContext( GB , GB^.Scene );
	CList := CreateContentList( GB^.Scene , CType );
	if CList = Nil then Exit( False );

	{ Repeat... select one component randomly. Remove it from the list. }
	{ Attempt to add it. If addition fails, try another component. Keep going }
	{ until either a component has been added or we've run out of possibilities. }
	repeat
		C := ChooseSceneContent( GB^.Scene , CList , CType );
		{ ERROR CHECK }
		if C = Nil then begin
			DialogMsg( 'ERROR: FindNextComponent returned Nil, but CList not empty.' );
			DialogMsg( 'CType:' + CType );
			break;
		end;

		AllOK := ContentInitOkay( C , Zone , Source , P , GB , Cells , SCheck , STerr );

		{ If not everything could be loaded okay, C will already }
		{ have been deleted. }
	until ( CList = Nil ) or AllOK;

	{ We don't want to repeat unique content. So, if a piece of unique content has }
	{ been added, delete it now. }
	if AllOK and ( GB^.Scene <> Nil ) then begin
		{ Record the content ID. }
		ContentID := NAttValue( C^.NA , NAG_Narrative , NAS_ContentID );

		{ If the content has a unique ID, delete the prototype from the }
		{ adventure. }
		if ContentID <> 0 then begin
			SetNAtt( C^.NA , NAG_Narrative , NAS_ContentID , 0 );
			C2 := SeekGearByIDTag( FindRoot( GB^.Scene ) , NAG_Narrative , NAS_ContentID , ContentID );
			if C2 <> Nil then RemoveGear( C2^.Parent^.InvCom , C2 );
		end;
	end;

	{ Get rid of any remaining components. }
	DisposeNAtt( CList );

	AddContent := AllOK;
end;

Procedure AddUniqueContentSequence( CType: String; GB: GameboardPtr; Source,MF: GearPtr; P: String; var Cells: SAttPtr; SCheck,STerr: Integer; NumCon: Integer; DoSub: Boolean );
	{ This works kind of the same as the above procedure, but it will create a list }
	{ of content and not add anything more than once. }
var
	AllOK: Boolean;
	CList: NAttPtr;
	Zone,C,C2: GearPtr;
	ContentID: LongInt;
	T: Integer;
	UCon,U: NAttPtr;
begin
	{ Create the list of potential components. }
	{ Start by calculating the context type for the random map content. }
	CType := CType + ' ' + SceneContext( GB , GB^.Scene );
	CList := CreateContentList( GB^.Scene , CType );
	if CList = Nil then Exit;

	{ Initialize the list of unique content to be deleted. }
	UCon := Nil;

	for t := 1 to NumCon do begin
		{ If CList = Nil, we've run out of content. Better break the loop. }
		if CList = Nil then Break;

		{ Get a zone for the next piece of content. }
		if DoSub then begin
			Zone := FindFreeZone( GB , MF , Cells,SCheck,STerr );
		end else begin
			Zone := MF;
		end;

		{ Repeat... select one component randomly. Remove it from the list. }
		{ Attempt to add it. If addition fails, try another component. Keep going }
		{ until either a component has been added or we've run out of possibilities. }
		repeat
			C := ChooseSceneContent( GB^.Scene , CList , CType );

			AllOK := ContentInitOkay( C , Zone , Source , P , GB , Cells , SCheck , STerr );

			{ If not everything could be loaded okay, C will already }
			{ have been deleted. }
		until ( CList = Nil ) or AllOK;

		{ We don't want to repeat unique content. So, if a piece of unique content has }
		{ been added, delete it now. }
		if AllOK and ( GB^.Scene <> Nil ) then begin
			{ Record the content ID. }
			ContentID := NAttValue( C^.NA , NAG_Narrative , NAS_ContentID );

			{ If the content has a unique ID, store it so we can delete it later. }
			if ContentID <> 0 then begin
				SetNAtt( C^.NA , NAG_Narrative , NAS_ContentID , 0 );
				SetNAtt( UCon , ContentID , ContentID , ContentID );
			end;
		end;

	end; { for t... }

	{ Finally, delete any unique content which got used here. }
	if UCon <> Nil then begin
		U := UCon;
		while U <> Nil do begin
			C2 := SeekGearByIDTag( FindRoot( GB^.Scene ) , NAG_Narrative , NAS_ContentID , U^.G );
			if C2 <> Nil then RemoveGear( C2^.Parent^.InvCom , C2 );
			U := U^.Next;
		end;
		DisposeNAtt( UCon );
	end;

	{ Get rid of any remaining components. }
	DisposeNAtt( CList );
end;

Procedure AddFeatureContent( GB: GameBoardPtr; MF: GearPtr;  var Cells: SAttPtr; SCheck,STerr: Integer );
	{ Attempt to add content for this map feature. }
const
	MODE_Fill = 1;
	MODE_Some = 2;
	MODE_Variety = 3;
var
	Source,Zone: GearPtr;	{ Either the adventure itself or this scene's governing story. }
	SA: SAttPtr;
	throw,cmd,Content_Type,Content_Parameter: String;
	DoSub: Boolean;
	FCMode,Content_Num,Content_Chance: Integer;
begin
	{ Error check- we need the GB and the Scene. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;

	{ Locate the source. }
	{ This will either be the adventure or, in the case of a story-linked metascene, a story. }
	Source := GB^.Scene;
	while ( Source <> Nil ) and ( Source^.G <> GG_Adventure ) and ( Source^.G <> GG_Story ) do Source := Source^.Parent;
	if Source = Nil then Exit;

	{ If this map feature doesn't have a unique name, better give it one. This will be }
	{ important for the map generator. }
	if ( SAttValue( MF^.SA , 'NAME' ) = '' ) and ( MF^.G = GG_MapFeature ) then begin
		SetSAtt( MF^.SA , 'name <UZONE_' + BStr( UniqueZoneNum ) + '>' );
		Inc( UniqueZoneNum );
	end;

	{ Look through the map feature for content requests. }
	{ If the map feature is a scene (or metascene), the content zone will be a sub-region }
	{ of the map. Otherwise, the content zone will be this map feature exactly and any }
	{ branch content will be located in map features at this same level. }
	SA := MF^.SA;
	while SA <> Nil do begin
		if HeadMatchesString( 'CONTENT' , SA^.Info ) then begin
			throw := RetrieveAString( SA^.Info );

			{ It's time to throw a request for a new component. }
			{ PARAM 1: SOME, FILL, or VARIETY }
			cmd := ExtractWord( throw );
			if UpCase( cmd[1] ) = 'S' then begin
				{ We want to add SOME content. This command should be }
				{ followed by two numbers: the first is the maximum number }
				{ of content frags to add, and the second is the percent chance }
				{ of each frag appearing. }
				FCMode := MODE_Some;
				Content_Num := ExtractValue( throw );
				Content_Chance := ExtractValue( throw );
			end else if UpCase( cmd[1] ) = 'V' then begin
				{ We want to add a VARIETY of content. This command should be }
				{ followed by two numbers as well: In this case, the first number }
				{ is the minimum number of content frags to add and the second }
				{ number is the maximum. }
				FCMode := MODE_Variety;
				Content_Num := ExtractValue( throw );
				Content_Chance := ExtractValue( throw );
			end else begin
				FCMode := MODE_Fill;
			end;

			{ PARAM 2: HERE or SUB }
			cmd := ExtractWord( throw );
			DoSub := UpCase( cmd[1] ) = 'S';

			{ PARAM 3: The content type. }
			Content_Type := ExtraCTWord( throw );

			{ PARAM 4: The content parameter. }
			Content_Parameter := ExtraCTWord( throw );
			if Content_Parameter = '' then Content_Parameter := 'na';

			{ Finally, actually add the content. }
			if FCMode = MODE_Some then begin
				while Content_Num > 0 do begin
					if Random( 100 ) < Content_Chance then begin
						if DoSub then begin
							Zone := FindFreeZone( GB , MF , Cells,SCheck,STerr );
						end else begin
							Zone := MF;
						end;
						if Zone = Nil then break;
						AddContent( Content_Type , GB , Source , Zone , Content_Parameter , Cells , SCheck , STerr );
					end;
					Dec( Content_Num );
				end;
			end else if FCMode = MODE_Fill then begin
				while Cells <> Nil do begin
					if DoSub then begin
						Zone := FindFreeZone( GB , MF , Cells,SCheck,STerr );
					end else begin
						Zone := MF;
					end;
					if Zone = Nil then break;
					AddContent( Content_Type , GB , Source , Zone , Content_Parameter , Cells , SCheck , STerr );
				end;
			end else begin
				{ Determine how many fragments to add, then send the info to the correct procedure. }
				if Content_Chance > Content_Num then Content_Num := Content_Num + Random( Content_Chance - Content_Num + 1 );
				AddUniqueContentSequence( Content_Type , GB , Source , MF , Content_Parameter , Cells , SCheck , STerr , Content_Num , DoSub);
			end;

		end;

		SA := SA^.Next;
	end;

	{ Finally, move all the content we've created into the adventure. }
	InsertFinishedContent( GB , FindRoot( GB^.Scene ) , Source );
end;

Procedure RenderFeature( GB: GameBoardPtr; MF: GearPtr );
	{ Render the provided map feature on the provided game board }
	{ in all it's glory. GB must already be initialized for this }
	{ procedure to do it work. The order in which things will be }
	{ done is as follows: }
	{ - MF itself will be rendered. }
	{ - MF's subcoms will be recursively rendered via this procedure. }
	{ - If a GAPFILL string is defined, empty spaces within the }
	{   boundaries of MF will be sought and stuffed with stuff. }
var
	Cells: SAttPtr;
	SubFeature: GearPtr;
	Placement_String,Gapfill_String,Special_String: String;
	X,Y,W,H,Style,Select_Check,Select_Terrain: Integer;
begin
	{ Initialize miscellaneous values. }
	Cells := Nil;
	if MF = Nil then begin
		{ This will be a basic-form scene. }
		Style := 0;
		X := 1;
		Y := 1;
		W := GB^.MAP_Width;
		H := GB^.MAP_Height;
	end else if IsAScene( MF ) or ( MF^.G = GG_World ) then begin
		Style := MF^.Stat[ STAT_MapGenerator ];
		if SAttValue( MF^.SA , 'TERRAIN' ) = '' then SetSAtt( MF^.SA , 'TERRAIN <' + SAttValue( Standard_Param_List , 'TERRAIN' + BStr( Style ) ) + '>' );
		X := 1;
		Y := 1;
		W := GB^.MAP_Width;
		H := GB^.MAP_Height;
	end else if MF^.G = GG_MapFeature then begin
		{ If the map feature's SPECIAL string indicates this is a SUBZONE, }
		{ better copy the subzone type from the parent map feature. }
		Special_String := SAttValue( MF^.SA , 'SPECIAL' );
		if AStringHasBString( Special_String , 'SUBZONE' ) and ( MF^.Parent <> Nil ) then begin
			MF^.S := SubZoneType( MF^.Parent );
		end;
		if AStringHasBString( Special_String , 'SHAREDPALETTE' ) and ( MF^.Parent <> Nil ) then begin
			{ Copy the palette from the parent. }
			for X := STAT_MFFloor to STAT_MFSpecial do begin
				MF^.Stat[ X ] := MF^.Parent^.Stat[ X ];
			end;
		end;
		Style := MF^.S;
		X := MF^.Stat[ STAT_XPos ];
		Y := MF^.Stat[ STAT_YPos ];
		W := MF^.Stat[ STAT_MFWidth ];
		H := MF^.Stat[ STAT_MFHeight ];
	end;

	{ Do the drawing. }
	Cells := TheRenderer( GB , MF , X , Y , W , H , Style );

	{ Now that we know the style, determine the SELECTOR parameters. }
	Placement_String := '';
	if MF <> Nil then Placement_String := SAttValue( MF^.SA , 'SELECTOR' );
	if Placement_String = '' then Placement_String := SAttValue( Standard_Param_List , 'SELECTOR' + BStr( Style ) );
	Select_Check := ExtractValue( Placement_String );
	if Select_Check <> 0 then Select_Terrain := DecideTerrainType( MF , Placement_String , ExtractValue( Placement_String ) );

	{ Also the GapFill parameters. }
	GapFill_String := '';
	if MF <> Nil then GapFill_String := SAttValue( MF^.SA , 'GAPFILL' );
	if GapFill_String = '' then GapFill_String := SAttValue( Standard_Param_List , 'GAPFILL' + BStr( Style ) );

	{ Loop through MF's subcoms here. }
	if MF <> Nil then begin
		{ First, do the placement. }
		SubFeature := MF^.SubCom;
		while SubFeature <> Nil do begin
			{ Select placement of SubFeature within boundaries of MF. }
			if SubFeature^.G = GG_MapFeature then begin
				SelectPlacementPoint( GB , MF , SubFeature , Cells , Select_Check , Select_Terrain );
			end;

			{ Move to the next sub-feature. }
			SubFeature := SubFeature^.Next;
		end;

		{ Next, add the random content. This will likely add more }
		{ map features. }
		if not AStringHasBString( SAttValue( MF^.SA , 'SPECIAL' ) , SPECIAL_Unchartable ) then AddFeatureContent( GB, MF, Cells, Select_Check,Select_Terrain );

		{ Finally, do the rendering. }
		SubFeature := MF^.SubCom;
		while SubFeature <> Nil do begin
			{ Select placement of SubFeature within boundaries of MF. }
			if SubFeature^.G = GG_MapFeature then begin
				{ Call the renderer. }
				RenderFeature( GB , SubFeature );
			end;

			{ Move to the next sub-feature. }
			SubFeature := SubFeature^.Next;
		end;
	end;


	{ If GAPFILL defined, check for empty spaces. }
	if GapFill_String <> '' then DoGapFilling( GB , MF , X , Y , W , H , Select_Check , Select_Terrain , Gapfill_String , Cells );

	{ Delete the cells, since we're finished with them. }
	if Cells <> Nil then DisposeSAtt( Cells );
end;

Procedure AdjustDimensions( Scene: GearPtr );
	{ Thanks to the new random quests, it's now possible that a scene will be }
	{ given more map content than it can hold... drat. This procedure checks }
	{ the situation and with any help will resize the map so everything fits. }
const
	MODE_MonkeyMaze = 1;
	MODE_Mall = 2;
	MODE_Club = 3;
	MODE_Cellbox = 4;
	Function NumCells( DMode: Integer ): Integer;
		{ Based on the dimensions of SCENE and the mapgenerator indicated, }
		{ return the number of cells that should be present. }
		{ Note that this will not nessecarily be exactly equal to the number of }
		{ cells the map generator produces, but it should be less than or equal to. }
	var
		X,Y,C: Integer;
	begin
		if DMode = MODE_MonkeyMaze then begin
			X := Scene^.Stat[ STAT_MapWidth ] div 7;
			Y := Scene^.Stat[ STAT_MapHeight ] div 7;
			C := ( X * Y ) div 3;
		end else if DMode = MODE_Mall then begin
			X := ( Scene^.Stat[ STAT_MapWidth ] - 1 ) div 6;
			if X > 1 then Dec( X );
			Y := ( Scene^.Stat[ STAT_MapHeight ] - 1 ) div 7;
			C := X * Y;
		end else if DMode = MODE_Cellbox then begin
			X := ( Scene^.Stat[ STAT_MapWidth ] - 2 ) div 5;
			Y := ( Scene^.Stat[ STAT_MapHeight ] - 2 ) div 5;
			C := X * Y;
		end else begin
			X := ( Scene^.Stat[ STAT_MapWidth ] - 12 ) div 6;
			if Scene^.Stat[ STAT_MapHeight ] >= 19 then X := X * 2;
			Y := ( Scene^.Stat[ STAT_MapHeight ] - 12 ) div 6;
			C := X + Y;
		end;
		NumCells := C;
	end;
var
	DMode: Integer;	{ The dimension-calculating mode. }
	MapGen: String;	{ The map generation string. }
	NeededCells: Integer;	{ The number of cells needed for this map. }
	MF: GearPtr;	{ A loop variable, for counting map features. }
begin
	{ Step one- determine the map generation script. If MONKEYMAP, CLUB or MALL are }
	{ included we may need to resize. }
	MapGen := SAttValue( Scene^.SA , 'PARAM' );
	if MapGen = '' then MapGen := SAttValue( Standard_Param_List , 'PARAM' + BStr( Scene^.Stat[ STAT_MapGenerator ] ) );

	{ Depending on which of the map generators are being used, we may not have any resizing }
	{ to do at all. Only MonkeyMaze, Mall, and Club may be resized. }
	if AStringHasBString( MapGen , 'MONKEYMAZE' ) then DMode := MODE_MOnkeyMaze
	else if AStringHasBString( MapGen , 'MALL' ) then DMode := MODE_Mall
	else if AStringHasBString( MapGen , 'CLUB' ) then DMode := MODE_Club
	else if AStringHasBString( MapGen , 'CELLBOX' ) then DMode := MODE_CellBox
	else exit;

	{ We've got a mode; firgure out how many cells are needed. }
	NeededCells := NAttValue( Scene^.NA , NAG_Narrative , NAS_NeededCells );
	MF := Scene^.SubCom;
	while MF <> Nil do begin
		{ For every map feature, minus the entrance grid, we're going to need }
		{ some more cells. }
		if ( MF^.G = GG_MapFeature ) and ( UpCase( SAttValue( MF^.SA , 'DESIG' ) ) <> 'ENTRANCEGRID' ) then Inc( NeededCells );
		MF := MF^.Next;
	end;

	{ As long as our map isn't big enough (but hasn't yet reached maximum size), }
	{ increase its dimensions. }
	while ( NumCells( DMode ) < NeededCells ) and (( Scene^.Stat[ STAT_MapWidth ] < MaxMapWidth ) or ( Scene^.Stat[ STAT_MapHeight ] < MaxMapWidth )) do begin
		if ( Random( 2 ) = 1 ) or ( Scene^.Stat[ STAT_MapWidth ] = MaxMapWidth ) then begin
			Scene^.Stat[ STAT_MapWidth ] := Scene^.Stat[ STAT_MapWidth ] + 5;
			if Scene^.Stat[ STAT_MapWidth ] > MaxMapWidth then Scene^.Stat[ STAT_MapWidth ] := MaxMapWidth;
		end else begin
			Scene^.Stat[ STAT_MapHeight ] := Scene^.Stat[ STAT_MapHeight ] + 5;
			if Scene^.Stat[ STAT_MapHeight ] > MaxMapWidth then Scene^.Stat[ STAT_MapHeight ] := MaxMapWidth;
		end;
	end;
end;

Procedure DeleteTempFeatures( var LList: GearPtr );
	{ Certain map features will have been marked as temporary. Delete those now. }
var
	MF,MF2: GearPtr;
begin
	MF := LList;
	while MF <> Nil do begin
		MF2 := MF^.Next;
		if ( MF^.G = GG_MapFeature) and ( NAttValue( MF^.NA , NAG_EpisodeData , NAS_Temporary ) <> 0 ) then begin
			RemoveGear( LList , MF );
		end else begin
			DeleteTempFeatures( MF^.SubCom );
		end;
		MF := MF2;
	end;
end;

function RandomMap( Scene: GearPtr ): GameBoardPtr;
	{Allocate a new GameBoard and stock it with random terrain.}
var
	it: GameBoardPtr;
	FName: String;
begin
	{ Initialize the UniqueZoneNum variable. }
	UniqueZoneNum := 1;

	if Scene <> Nil then begin
		FName := SAttValue( Scene^.SA , 'MAP' );
		if FName <> '' then begin
			{ This scene is supposed to use a prefabricated map. Here's }
			{ how we deal with this unpleasant situation: Create the gameboard }
			{ by loading the map from disk. This map will likely have cells }
			{ defined on it, but we won't worry about that here. Set the map }
			{ generator to he PreGen type; this action will convert the MapEd }
			{ cells to a list usable by this unit, and won't overwrite the }
			{ map as defined. }
			it := LoadPredrawnMap( FName );
			SetSAtt( Scene^.SA , 'PARAM <PREDRAWN>' );
		end else begin
			AdjustDimensions( Scene );

			if Scene^.STAT[ STAT_MAPWIDTH ] < 10 then Scene^.STAT[ STAT_MAPWIDTH ] := 10
			else if Scene^.STAT[ STAT_MAPWIDTH ] > MaxMapWidth then Scene^.STAT[ STAT_MAPWIDTH ] := MaxMapWidth;
			if Scene^.STAT[ STAT_MAPHEIGHT ] < 10 then Scene^.STAT[ STAT_MAPHEIGHT ] := 10
			else if Scene^.STAT[ STAT_MAPHEIGHT ] > MaxMapWidth then Scene^.STAT[ STAT_MAPHEIGHT ] := MaxMapWidth;

			it := NewMap( Scene^.STAT[ STAT_MAPWIDTH ] , Scene^.STAT[ STAT_MAPHEIGHT ] );
		end;
	end else begin
		it := NewMap( 50 , 50 );
	end;

	it^.Scene := Scene;

	High_Component_ID := 1;
	RenderFeature( it , Scene );

	if Scene <> Nil then DeleteTempFeatures( Scene^.SubCom );

	RandomMap := it;
end;


initialization
	Standard_Param_List := LoadStringList( RandMaps_Param_File );
	random_scene_content := LoadRandomSceneContent( 'RANCON_*.txt' , series_directory );
	super_prop_list := LoadRandomSceneContent( 'RANPROP_*.txt' , series_directory );

finalization
	DisposeSAtt( Standard_Param_List );
	DisposeGear( random_scene_content );
	DisposeGear( super_prop_list );

end.
