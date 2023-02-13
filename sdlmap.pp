unit sdlmap;
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

uses locale,sdl,math,gears,texutil,sdlgfx;

const
	LoAlt = -3;
	HiAlt = 5;

	Num_Prop_Meshes = 13;

var
	tile_x,tile_y,tile_z: LongInt;	{ Tile where the mouse pointer is pointing. }
	origin_x,origin_y: Integer;	{ Tile which the camera is pointing at. }
	origin_d: Integer;		{ The camera angle; one of four. }


	Overlays,Underlays: Array [1..MaxMapWidth,1..MaxMapWidth,LoAlt..HiAlt] of Integer;

	Model_Map: Array [1..MaxMapWidth,1..MaxMapWidth,LoAlt..( HiAlt + 1 )] of GearPtr;

	Strong_Hit_Sprite,Weak_Hit_Sprite,Parry_Sprite,Miss_Sprite,Encounter_Sprite: SensibleSpritePtr;
	Terrain_Sprite,Extras_Sprite,Shadow_Sprite,Building_Sprite,Current_Backdrop: SensibleSpritePtr;
	Off_Map_Model_Sprite: SensibleSpritePtr;

	Focused_On_Mek: GearPtr;


Function ScreenDirToMapDir( D: Integer ): Integer;
Function KeyboardDirToMapDir( D: Integer ): Integer;

Function SpriteColor( GB: GameBoardPtr; M: GearPtr ): String;
Function SpriteName( GB: GameBoardPtr; M: GearPtr ): String;

Procedure Render_Off_Map_Models;

Procedure RenderMap( GB: GameBoardPtr );
Procedure FocusOn( Mek: GearPtr );

Procedure DisplayMiniMap( GB: GameBoardPtr );
Procedure IndicateTile( GB: GameBoardPtr; X , Y , Z: Integer );

Procedure ScrollMap( GB: GameBoardPtr );

Procedure ClearOverlays;
Function ProcessShotAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;
Function ProcessPointAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;

Procedure RenderWorldMap( GB: GameBoardPtr; PC: GearPtr; X0,Y0: Integer );

Procedure InitGraphicsForScene( GB: GameBoardPtr );


implementation

uses ghmecha,ghchars,gearutil,ability,ghprop,effects,narration,ui4gh,colormenu;

type
	Cute_Map_Cel_Description = Record
		Sprite: SensibleSpritePtr;
		F: Integer;	{ The frame to be displayed. }
	end;

	Cute_Map_Cel_Toggle = Array [ 1..MaxMapWidth, 1..MaxMapWidth, LoAlt..HiAlt ] of Boolean;

const
	Strong_Hit_Sprite_Name = 'blast64.png';
	Weak_Hit_Sprite_Name = 'nodamage64.png';
	Parry_Sprite_Name = 'misc_parry.png';
	Miss_Sprite_Name = 'misc_miss.png';

	Default_Prop_Sprite_Name = 'c_cha_m_citizen.png';
	Items_Sprite_Name = 'c_default_items.png';
	Default_Wreckage = 1;
	Default_Dead_Thing = 2;

	WallBrown: TSDL_Color = ( R: 76; G: 64; B: 51 );
	DoorBlue: TSDL_Color = ( R: 0; G: 128; B: 128 );
	WallGray: TSDL_Color = ( R: 70; G: 70; B: 55 );		{ For the low wall. }
	SmokeGray: TSDL_Color = ( R: 155; G: 150; B: 150 );
	ToxicGreen: TSDL_Color = ( R: 50; G: 170; B: 15 );

	TT_OpenGround = 1;
	TT_Tree = 2;
	TT_Mountain = 3;
	TT_ForestFloor = 4;
	TT_Swamp = 5;
	TT_Pavement = 6;
	TT_Rubble = 7;
	TT_RoughGround = 8;
	TT_GenericWall = 9;
	TT_GenericFloor = 10;
	TT_Threshold = 11;
	TT_Carpet = 12;
	TT_WoodenFloor = 13;
	TT_WoodenWall = 14;
	TT_TileFloor = 15;
	TT_WreckageWall = 16;
	TT_GlassWall = 17;
	TT_Elevator = 18;
	TT_StairsDown = 19;
	TT_TrapDoor = 20;
	TT_Door = 21;
	{ Terrain texture 22 is open for expansion }
	TT_Water = 23;

	NumCMCelLayers = 9;		{ Total number of cel layers. }
	NumBasicCelLayers = 8;		{ Number of cel layers set by RenderMap. }

	CMC_Terrain = 1;
	CMC_Shadow = 2;
	CMC_MetaTerrain = 3;
	CMC_MShadow = 4;
	CMC_Destroyed = 5;
	CMC_Items = 6;
	CMC_Master = 7;
	CMC_Toupee = 8;
	CMC_Effects = 9;

	Num_Rotation_Angles = 4;

	Backdrop_Size = 512;	{ Width/Height in pixels of the backdrop image. }

	SI_Ally = 3;
	SI_Neutral = 2;
	SI_Enemy = 1;

	NumOMM = 32;
	OM_North = 1;
	OM_East = 2;
	OM_South = 4;
	OM_West = 3;


var
	Mini_Map_Sprite,World_Terrain,Items_Sprite: SensibleSpritePtr;
	Compass_Sprite: SensibleSpritePtr;

	CM_Cels: Array [ 1..MaxMapWidth, 1..MaxMapWidth, LoAlt..HiAlt, 0..NumCMCelLayers ] of Cute_Map_Cel_Description;
	CM_Cel_IsOn: Array [0..NumCMCelLayers] of Cute_Map_Cel_Toggle;
	CM_Cel_OMIcon: Array [ 1..MaxMapWidth, 1..MaxMapWidth ] of Byte;
	CM_ModelNames: Array [ 1..MaxMapWidth, 1..MaxMapWidth, LoAlt..HiAlt ] of String;

	OFF_MAP_MODELS: Array [1..4,0..NumOMM] of Integer;


Function ScreenDirToMapDir( D: Integer ): Integer;
	{ Convert the requested screen direction to a map direction. }
begin
	ScreenDirToMapDir := ( D + Origin_D * 2 + 7 ) mod 8;
end;

Function KeyboardDirToMapDir( D: Integer ): Integer;
	{ Given the press of a key on the keyboard, return the map direction it }
	{ corresponds to. Normally this will be the same as the screen dir, }
	{ unless using isometric mode and ISO_DIR_OFFSET is nonzero. }
var
	it: Integer;
begin
	it := ScreenDirToMapDir( D );

	it := ( it + Iso_Dir_Offset ) mod 8;

	KeyboardDirToMapDir := it;
end;

Procedure ClearCMCelLayer( L: Integer );
	{ Clear sprite descriptions from the provided overlay layer. }
var
	X,Y,Z: Integer;
begin
	FillChar( CM_Cel_IsOn[ L ] , SizeOf( CM_Cel_IsOn[ L ] ) , False );
end;

Procedure AddCMCel( GB: GameBoardPtr; X,Y,Z,L: Integer; SS: SensibleSpritePtr; Frame: Integer );
	{ Add an overlay image safely to the display. }
begin
	if not OnTheMap( GB , X , Y ) then Exit;
	if ( Z < LoAlt ) or ( Z > HiAlt ) then Exit;
	if ( L < 0 ) or ( L > NumCMCelLayers ) then Exit;
	CM_Cels[ X , Y , Z , L ].Sprite := SS;
	CM_Cels[ X , Y , Z , L ].F := Frame;
	CM_Cel_IsOn[ L ][ X , Y , Z ] := SS <> Nil;
end;

Procedure ClearCMCel( GB: GameBoardPtr; X,Y,Z,L: Integer );
	{ Remove the overlay image from this tile. }
begin
	if not OnTheMap( GB , X , Y ) then Exit;
	if ( Z < LoAlt ) or ( Z > HiAlt ) then Exit;
	if ( L < 0 ) or ( L > NumCMCelLayers ) then Exit;
	CM_Cel_IsOn[ L ][ X , Y , Z ] := False;
end;


Function SpriteName( GB: GameBoardPtr; M: GearPtr ): String;
	{ Locate the sprite name for this gear. If no sprite name is defined, }
	{ set the default sprite name for the gear type & store it as a string }
	{ attribute so we won't need to do this calculation later. }
const
	FORM_DEFAULT: Array [1..NumForm] of String = (
	'btr_buruburu.png','zoa_scylla.png','ghu_ultari.png',
	'ara_kojedo.png', 'aer_wraith.png', 'orn_wasp.png',
	'ger_harpy.png', 'aer_bluebird.png', 'gca_rover.png'
	);
	DefaultMaleSpriteName = 'cha_m_citizen.png';
	DefaultFemaleSpriteName = 'cha_f_citizen.png';
	DefaultMaleSpriteHead = 'cha_m_';
	DefaultFemaleSpriteHead = 'cha_f_';
	DefaultNonbinarySpriteHead = 'cha_*_';
	mini_sprite = 'cha_pilot.png';
	Unknown_Sprite = 'prop_unknown.png';
var
	it,fname: String;
	FList: SAttPtr;
    gen: Integer;
begin
	{ If this model is an out-of-scale character, return the mini-sprite. }
	if ( M^.G = GG_Character ) and ( GB <> Nil ) and ( M^.Scale < GB^.Scale ) then Exit( mini_sprite );

	it := SAttValue( M^.SA , 'SDL_SPRITE' );
	if it = '' then begin
		if M^.G = GG_Character then begin
            gen := NAttValue( M^.NA , NAG_CharDescription , NAS_Gender );
			if gen = NAV_Male then begin
				it := DefaultMaleSpriteHead;
			end else if gen = NAV_Female then begin
				it := DefaultFemaleSpriteHead;
            end else begin
                it := DefaultNonbinarySpriteHead;
			end;
			fname := it + LowerCase( SAttValue( M^.SA , 'JOB' ) ) + '.*';
			FList := CreateFileList( Graphics_Directory + fname );
			if FList <> Nil then begin
				it := SelectRandomSAtt( FList )^.Info;
				DisposeSAtt( FList );
			end else begin
				fname := it + LowerCase( SAttValue( M^.SA , 'JOB_DESIG' ) ) + '.*';

				FList := CreateFileList( Graphics_Directory + fname );
				if FList <> Nil then begin
					it := SelectRandomSAtt( FList )^.Info;
					DisposeSAtt( FList );
				end else begin
				    if gen = NAV_Male then begin
					    it := DefaultMaleSpriteName;
				    end else if gen = NAV_Female then begin
					    it := DefaultFemaleSpriteName;
                    end else if random(2) = 1 then it := DefaultMaleSpriteName
				    else it := DefaultFemaleSpriteName;
				end;
			end;
		end else if ( M^.G = GG_Mecha ) and ( M^.S >= 0 ) and ( M^.S < NumForm ) then begin
			it := FORM_DEFAULT[ M^.S + 1 ];
		end else begin
			it := Unknown_Sprite;
		end;
		SetSAtt( M^.SA , 'SDL_SPRITE <' + it + '>' );
	end;
	SpriteName := it;
end;

Function SpriteColor( GB: GameBoardPtr; M: GearPtr ): String;
	{ Determine the color string for this model. }
const
	neutral_clothing_color = '140 130 120';
var
	it: String;
	T: Integer;
	Team,Faction: GearPtr;
begin
	it := SAttValue( M^.SA , 'SDL_COLORS' );
	{ Props usually but not always have their own palette, so if no }
	{ color has been stored in SDL_COLORS assume no color is needed. }
	if ( it = '' ) and ( M^.G <> GG_Prop ) and ( M^.G <> GG_MetaTerrain ) and ( GB = Nil ) then begin
		if M^.G = GG_Character then begin
			it := neutral_clothing_color;
			it := it + ' ' + RandomColorString( CS_Skin ) + ' ' + RandomColorString( CS_Hair );
		end else begin
			it := '175 175 171 100 100 120 0 200 200';
		end;
		SetSAtt( M^.SA , 'SDL_COLORS <' + it + '>' );

	end else if ( it = '' ) and ( M^.G <> GG_Prop ) and ( M^.G <> GG_MetaTerrain ) then begin
		T := NAttValue( M^.NA , NAG_Location , NAS_Team );
		Team := LocateTeam( GB , T );
		if Team <> Nil then it := SAttValue( Team^.SA , 'SDL_COLORS' );

		if it = '' then begin
			if Team <> Nil then Faction := SeekFaction( GB^.Scene , NAttValue( Team^.NA , NAG_Personal , NAS_FactionID ) )
			else Faction := Nil;
			if Faction = Nil then Faction := SeekFaction( GB^.Scene , NAttValue( M^.NA , NAG_Personal , NAS_FactionID ) );
			if M^.G = GG_Character then begin
				if Faction <> Nil then it := SAttValue( Faction^.SA , 'chara_colors' );
				if it = '' then begin
					if T = NAV_DefPlayerTeam then begin
						it := '66 121 179';
					end else if AreEnemies( GB , T , NAV_DefPlayerTeam ) then begin
						it := '180 10 120';
					end else if AreAllies( GB , T , NAV_DefPlayerTeam ) then begin
						it := '150 150 150';
					end else begin
						it := neutral_clothing_color;
					end;
				end;
				it := it + ' ' + RandomColorString( CS_Skin ) + ' ' + RandomColorString( CS_Hair );
			end else begin
				if Faction <> Nil then it := SAttValue( Faction^.SA , 'mecha_colors' );
				if it = '' then begin
					if T = NAV_DefPlayerTeam then begin
						it := '66 121 179 210 215 80 205 25 0';
					end else if AreEnemies( GB , T , NAV_DefPlayerTeam ) then begin
						it := '103 3 45 166 47 32 244 216 28';
					end else if AreAllies( GB , T , NAV_DefPlayerTeam ) then begin
						it := '66 121 119 190 190 190 0 205 0';
					end else begin
						it := '175 175 171 100 100 120 0 200 200';
					end;
				end;
			end;
		end;
		SetSAtt( M^.SA , 'SDL_COLORS <' + it + '>' );
	end;
	SpriteColor := it;
end;

Function AlmostSeen( GB: GameBoardPtr; X1 , Y1: Integer ): Boolean;
	{ Tell whether or not to show the edge of visibility symbol here. We'll }
	{ show it if this tile is unseen, and is adjacent to a seen tile that's not a wall. }
var
	IsAlmostSeen: Boolean;
	D,X2,Y2: Integer;
begin
	IsAlmostSeen := False;
	For D := 0 to 7 do begin
		X2 := X1 + AngDir[ D , 1 ];
		Y2 := Y1 + AngDir[ D , 2 ];
		if OnTheMap( GB , X2 , Y2 ) and TileVisible( GB , X2 , Y2 ) and ( TerrMan[ TileTerrain( GB , X2 , Y2 ) ].Altitude < 6 ) then begin
			IsAlmostSeen := True;
			Break;
		end;
	end;
	AlmostSeen := IsAlmostSeen;
end;

Procedure DrawBackdrop;
	{ If Current_Backdrop exists, fill the screen with it. }
var
	X,Y: Integer;
	MyDest: TSDL_Rect;
begin
	if Current_Backdrop <> Nil then begin
		for x := 0 to ( Game_Screen^.W div Backdrop_Size ) do begin
			for y := 0 to ( Game_Screen^.H div Backdrop_Size ) do begin
				MyDest.X := x * Backdrop_Size;
				MyDest.Y := y * Backdrop_Size;
				DrawSprite( Current_Backdrop , MyDest , 0 );
			end;
		end;
	end;
end;

Procedure Render_Off_Map_Models;
	{ Draw the off-map models, as stored in the Off_Map_Models array. }
	Procedure DrawOffMap( Quad,N: Integer );
		{ Draw an off-map model as indicated by the OFF_MAP_MODEL array. }
	var
		MyDest: TSDL_Rect;
	begin
		if Quad = OM_East then begin
			MyDest.Y := ( Game_Screen^.H * ( N + 1 ) ) div ( NumOMM + 2 );
			MyDest.X := Game_Screen^.W - 16;
		end else if Quad = OM_West then begin
			MyDest.Y := ( Game_Screen^.H * ( N + 1 ) ) div ( NumOMM + 2 );
			MyDest.X := 1;
		end else if Quad = OM_South then begin
			MyDest.X := ( ( Game_Screen^.W * ( N + 1 ) ) div ( NumOMM + 2 ) );
			MyDest.Y := 1;
		end else begin
			MyDest.X := ( ( Game_Screen^.W * ( N + 1 ) ) div ( NumOMM + 2 ) );
			MyDest.Y := Game_Screen^.H - 12;
		end;
		DrawSprite( Off_Map_Model_Sprite , MyDest , OFF_MAP_MODELS[ Quad , N ] - 1 + ( Animation_Phase div 5 mod 2 ) * 3 );
	end;
var
	T: Integer;
begin
	{ Once everything else has been rendered, draw the off-map icons. }
	for t := 0 to NumOMM do begin
		if Off_Map_Models[ OM_North , T ] > 0 then DrawOffMap( OM_North , T );
		if Off_Map_Models[ OM_South , T ] > 0 then DrawOffMap( OM_South , T );
		if Off_Map_Models[ OM_West , T ] > 0 then DrawOffMap( OM_West , T );
		if Off_Map_Models[ OM_East , T ] > 0 then DrawOffMap( OM_East , T );
	end;
end;


Procedure Render_Isometric( GB: GameBoardPtr );
	{ Render the isometric 2D map. }
const
	Altitude_Height = 20; { Pixel height of each altitude layer. }
	HalfTileWidth = 32;
	HalfTileHeight = 16;

	{ Terrain cel constants. }
	TCEL_OpenGround = 0;
	TCEL_Void = 1;
	TCEL_Pavement = 2;
	TCEL_DarkGround = 3;
	TCEL_RoughGround = 4;

	TCEL_Wall = 5;
	TCEL_Carpet = 6;
	TCEL_WoodenFloor = 7;
	TCEL_WoodenWall = 8;
	TCEL_GlassWall = 9;

	TCEL_Floor = 10;
	TCEL_LightForest_A = 11;
	TCEL_HeavyForest_A = 12;
	TCEL_LightForest_B = 13;
	TCEL_HeavyForest_B = 14;

	TCEL_ShortWall = 15;
	TCEL_Door = 16;
	TCEL_Threshold = 17;
	TCEL_Elevator = 18;
	TCEL_ShortDoor = 19;

	TCEL_LowHill = 20;
	TCEL_MediumHill = 21;
	TCEL_HighHill = 22;

	{ Extras cel constants. }
	ECEL_Unknown = 0;
	ECEL_Trapdoor = 1;
	ECEL_Indicator = 2;
	ECEL_Item = 3;
	ECEL_Dead_Thing = 4;

	ECEL_Wreckage = 5;
	ECEL_StairsUp = 6;
	ECEL_StairsDown = 7;

	ECEL_Fire = 20;
	ECEL_Smoke = 21;

	function MapDirToScreenDir( D: Integer ): Integer;
		{ Given an in-game map dir, convert this to a screen dir which }
		{ can be used to render sprites. }
	begin
		MapDirToScreenDir := ( D + 9 - Origin_D * 2 ) mod 8;
	end;

	Procedure AddShadow( X,Y,Z: Integer );
		{ For this shadow, we're only concerned about three blocks- the one directly to the left (which }
		{ I'll label #1), the one to the left and above (#2), and the one directly above (#3). You can }
		{ find the right shadow frame by adding +1 if #1 is a wall, +2 if #2 is a wall, and +4 if #3 is }
		{ a wall. The case where #1 and #3 are occupied is the same as if all three tiles were occupied. }
		{ Here's a picture: }
		{    2 3 }
		{    1 x <-- X is the target tile. }

		Function IsHigher( X2,Y2: Integer ): Boolean;
		var
			Terr,H2: Integer;
		begin
			if OnTheMap( GB , X2 , Y2 ) then begin
				terr := TileTerrain( GB , X2 , Y2 );
				if ( terr <> TERRAIN_LowBuilding ) and ( terr <> TERRAIN_MediumBuilding ) and ( terr <> TERRAIN_HighBuilding ) then begin
					H2 := TerrMan[ terr ].Altitude;
					IsHigher := H2 > Z;
				end else begin
					IsHigher := False;
				end;
			end else begin
				IsHigher := False;
			end;
		end;
	var
		Total: Integer;
	begin
		Total := 0;
		if IsHigher( X + AngDir[ ScreenDirToMapDir( 3 ) , 1 ] , Y + AngDir[ ScreenDirToMapDir( 3 ) , 2 ] ) then Total := Total + 1;
		if IsHigher( X + AngDir[ ScreenDirToMapDir( 4 ) , 1 ] , Y + AngDir[ ScreenDirToMapDir( 4 ) , 2 ] ) then Total := Total + 2;
		if IsHigher( X + AngDir[ ScreenDirToMapDir( 5 ) , 1 ] , Y + AngDir[ ScreenDirToMapDir( 5 ) , 2 ] ) then Total := Total + 4;
		if Total = 7 then Total := 5;
		if Total > 0 then AddCMCel( GB , X , Y , Z , CMC_Shadow , Shadow_Sprite , Total - 1 );
	end;
	Procedure AddBasicFloorCel( X,Y,F: Integer );
		{ Add a basic terrain cel plus a shadow. }
	begin
		AddCMCel( GB , X , Y ,  0 , CMC_Terrain , terrain_sprite ,  F );
		AddShadow( X,Y,0 );
	end;
	Procedure AddBasicTerrainCel( X,Y,F: Integer );
		{ Add a basic terrain cel without a shadow. }
	begin
		AddCMCel( GB , X , Y ,  0 , CMC_Terrain , terrain_sprite ,  F );
	end;
	Procedure AddBuilding( X,Y,F: Integer );
		{ Add a basic terrain cel. }
	begin
		AddCMCel( GB , X , Y ,  0 , CMC_Terrain , terrain_sprite ,  TCEL_OpenGround );
		AddCMCel( GB , X , Y ,  0 , CMC_MetaTerrain , building_sprite ,  F );
	end;
	Procedure AddBasicWallCel( X,Y,F: Integer );
		{ Add a basic wall cel using F. }
	begin
		if Use_Tall_Walls then begin
			AddCMCel( GB , X , Y ,  0 , CMC_Terrain , terrain_sprite ,  F );
		end else begin
			AddCMCel( GB , X , Y ,  0 , CMC_Terrain , terrain_sprite ,  TCEL_ShortWall );
		end;
	end;
	Procedure AddBasicDoorCel( X,Y,F: Integer );
		{ Add a door or elevator cel using F. }
	begin
		if Use_Tall_Walls then begin
			AddCMCel( GB , X , Y ,  0 , CMC_Terrain , terrain_sprite ,  F );
		end else begin
			AddCMCel( GB , X , Y ,  0 , CMC_Terrain , terrain_sprite ,  TCEL_ShortDoor );
		end;
		ClearCMCel( GB , X , Y , 0 , CMC_Shadow );
	end;
	Function DoorSprite( X,Y: Integer ): Integer;
		{ Return the appropriate door sprite for this tile: use either the vertical }
		{ door or the horizontal door. }
	begin
		{ Calculate the location of the tile directly above this one. }
		X := X + AngDir[ ScreenDirToMapDir( 6 ) , 1 ];
		Y := Y + AngDir[ ScreenDirToMapDir( 6 ) , 2 ];
		if OnTheMap( GB , X , Y ) and ( TerrMan[ TileTerrain( GB , X , Y ) ].Altitude > 5 ) then DoorSprite := 16
		else DoorSprite := 14;
	end;

	Function MapX( VX,VY: Integer ): Integer;
		{ Given virtual point VX,VY return which actual map tile we're }
		{ talking about. }
	begin
		if origin_d = 0 then MapX := VX
		else if origin_d = 1 then MapX := ( GB^.Map_Width - VY + 1 )
		else if origin_d = 2 then MapX := ( GB^.Map_Width - VX + 1 )
		else MapX := VY;
	end;
	Function MapY( VX,VY: Integer ): Integer;
		{ Given virtual point VX,VY return which actual map tile we're }
		{ talking about. }
	begin
		if origin_d = 0 then MapY := VY
		else if origin_d = 1 then MapY := VX
		else if origin_d = 2 then MapY := ( GB^.Map_Height - VY + 1 )
		else MapY := ( GB^.Map_Height - VX + 1 );
	end;

	Function VirtX( MX,MY: Integer ): Integer;
		{ Given map point MX,MY return the virtual screen tile to which }
		{ it will be rendered. }
	begin
		if origin_d = 0 then VirtX := MX
		else if origin_d = 1 then VirtX := MY
		else if origin_d = 2 then VirtX := ( GB^.Map_Width - MX + 1 )
		else VirtX := ( GB^.Map_Height - MY + 1 );
	end;

	Function VirtY( MX,MY: Integer ): Integer;
		{ Given map point MX,MY return the virtual screen tile to which }
		{ it will be rendered. }
	begin
		if origin_d = 0 then VirtY := MY
		else if origin_d = 1 then VirtY := ( GB^.Map_Width - MX + 1 )
		else if origin_d = 2 then VirtY := ( GB^.Map_Height - MY + 1 )
		else VirtY := MX;
	end;


	Function RelativeX( X,Y: Integer ): LongInt;
		{ Return the relative position of tile X,Y. The UpLeft corner }
		{ of tile [1,1] is the origin of our display. }
	begin
		RelativeX := ( (X-1) * HalfTileWidth ) - ( (Y-1) * HalfTileWidth );
	end;

	Function RelativeY( X,Y: Integer ): LongInt;
		{ Return the relative position of tile X,Y. The UpLeft corner }
		{ of tile [1,1] is the origin of our display. }
	begin
		RelativeY := ( (Y-1) * HalfTileHeight ) + ( (X-1) * HalfTileHeight );
	end;

	Function ScreenX( X,Y: Integer ): LongInt;
		{ Return the screen coordinates of map column X. }
	begin
		ScreenX := RelativeX( X - VirtX( Origin_X , Origin_Y ) , Y - VirtY( Origin_X , Origin_Y ) ) + ( Game_Screen^.W div 2 );
	end;
	Function ScreenY( X,Y: Integer ): Integer;
		{ Return the screen coordinates of map row Y. }
	begin
		ScreenY := RelativeY( X - VirtX( Origin_X , Origin_Y ) , Y - VirtY( Origin_X , Origin_Y ) ) + ( Game_Screen^.H div 2 );
	end;
	Function OnTheScreen( X , Y: Integer ): Boolean;
		{ This function returns TRUE if the specified point is visible }
		{ on screen, FALSE if it isn't. }
	var
		SX,SY: LongInt;		{ Find Screen X and Screen Y and see if it's in the map area. }
	begin
		SX := ScreenX( X , Y );
		SY := ScreenY( X , Y );
		if ( SX >= ( -64 ) ) and ( SX <= ( Game_Screen^.W ) ) and ( SY >= -64 ) and ( SY <= ( Game_Screen^.H ) ) then begin
			OnTheScreen := True;
		end else begin
			OnTheScreen := False;
		end;
	end;
var
	VX,VY,VX_Max,VY_Max,X,Y,Z,T,Row,Column,Terr,Quad: Integer;
	M: GearPtr;
	MyDest,TexDest: TSDL_Rect;
	Spr: SensibleSpritePtr;
begin
	{ Clear the OFF_MAP_MODELS. }
	{ NOTE: X and Y do not refer to X and Y!!! Coordinates, that is... }
	{  here they're being used as the map border and the icon position. }
	for X := 1 to 4 do begin
		for Y := 0 to NumOMM do begin
			OFF_MAP_MODELS[ X , Y ] := 0;
		end;
	end;

	{ Fill out the basic terrain cels, and while we're here clear the model map. }
	for X := 1 to GB^.Map_Width do begin
		for Y := 1 to GB^.Map_Height do begin
			if TileVisible( GB , X , Y ) then begin
				Terr := TileTerrain( GB , X , Y );
				case Terr of
				TERRAIN_OpenGround: 	AddBasicFloorCel( X , Y , TCEL_OpenGround );
				TERRAIN_LightForest:	begin
							AddBasicTerrainCel( X , Y , TCEL_LightForest_A );
							AddCMCel( GB , X , Y , 0 , CMC_Toupee , Terrain_Sprite , TCEL_LightForest_B );
							end;
				TERRAIN_HeavyForest:	begin
							AddBasicTerrainCel( X , Y , TCEL_HeavyForest_A );
							AddCMCel( GB , X , Y , 0 , CMC_Toupee , Terrain_Sprite , TCEL_HeavyForest_B );
							end;

				TERRAIN_Rubble:		AddBasicFloorCel( X , Y , TCEL_RoughGround );

				TERRAIN_Pavement: 	AddBasicFloorCel( X , Y , TCEL_Pavement );
				TERRAIN_Swamp: 		AddBasicTerrainCel( X , Y , TCEL_DarkGround );
				TERRAIN_L1_Hill:	AddBasicTerrainCel( X , Y , TCEL_LowHill );
				TERRAIN_L2_Hill:	AddBasicTerrainCel( X , Y , TCEL_MediumHill );
				TERRAIN_L3_Hill:	AddBasicTerrainCel( X , Y , TCEL_HighHill );
				TERRAIN_RoughGround:	AddBasicTerrainCel( X , Y , TCEL_RoughGround );
				TERRAIN_LowWall:	AddBasicWallCel( X , Y , TCEL_Wall );
				TERRAIN_Wall:		AddBasicWallCel( X , Y , TCEL_Wall );
				TERRAIN_Floor:		AddBasicFloorCel( X , Y , TCEL_Floor );
				TERRAIN_Threshold:	AddBasicFloorCel( X , Y , TCEL_Threshold );
				TERRAIN_Carpet:		AddBasicFloorCel( X , Y , TCEL_Carpet );

				TERRAIN_WoodenFloor:	AddBasicFloorCel( X , Y , TCEL_WoodenFloor );
				TERRAIN_WoodenWall:	AddBasicWallCel( X , Y , TCEL_WoodenWall );

				TERRAIN_TileFloor:	AddBasicFloorCel( X , Y , TCEL_Floor );

				TERRAIN_Space:		AddCMCel( GB , X , Y ,  0 , CMC_Terrain , Terrain_Sprite , TCEL_Void );
				TERRAIN_MediumBuilding:	AddBuilding( X , Y , ( ( X * 17 ) + ( Y * 71 ) ) mod 4 + 1 );
				TERRAIN_HighBuilding:	AddBuilding( X , Y , ( ( X * 17 ) + ( Y * 71 ) ) mod 4 + 5 );

				TERRAIN_GlassWall:	AddBasicWallCel( X , Y , TCEL_GlassWall );
				TERRAIN_LowBuilding:	AddBuilding( X , Y , ( ( X * 17 ) + ( Y * 71 ) ) mod 4 + 15 );

				else AddBasicTerrainCel( X , Y , TCEL_Void );
				end;
			end else begin
				if AlmostSeen( GB , X , Y ) then AddCMCel( GB , X , Y , 0 , CMC_Terrain , Extras_Sprite , ECEL_Unknown );
			end;

			{ Clear the model map here. }
			for z := LoAlt to ( HiAlt + 1 ) do begin
				model_map[ X , Y , z ] := Nil;
				if Names_Above_Heads then CM_ModelNames[ X , Y , Z ] := '';
			end;

			{ And the off-map icon. }
			CM_Cel_OMIcon[ X , Y ] := 0;
		end;
	end;

	{ Next add the characters, mecha, and items to the list. }
	M := GB^.Meks;
	while M <> Nil do begin
		if OnTheMap( GB , M ) and MekVisible( GB , M ) then begin
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			Z := MekAltitude( GB , M );

			if Destroyed( M ) then begin
				{ Insert wreckage-drawing code here. }
				if M^.G = GG_Character then begin
					AddCMCel( GB , X , Y , Z , CMC_Destroyed , Extras_Sprite , ECEL_Dead_Thing );
				end else begin
					AddCMCel( GB , X , Y , Z , CMC_Destroyed , Extras_Sprite , ECEL_Wreckage );
				end;

			end else if IsMasterGear( M ) then begin
				{ Insert sprite-drawing code here. }
				AddCMCel( 	GB , X , Y , Z , CMC_Master ,
						LocateSprite( SpriteName( GB , M ) , SpriteColor( GB , M ) , 64 , 64 ),
						MapDirToScreenDir( NAttValue( M^.NA , NAG_Location , NAS_D ) )
				);

				{ Also add a shadow. }
				AddCMCel( 	GB , X , Y , TerrMan[ TileTerrain( gb , X , Y ) ].Altitude , CMC_MShadow , Shadow_Sprite , 6 );

				{ If appropriate, save the model map and model name. }
				if OnTheMap( GB , X , Y ) and ( Z >= LoAlt ) and ( Z <= HiAlt ) then begin
					model_map[ X , Y , Z ] := M;
					if Names_Above_Heads and ( M^.G <> GG_Prop ) then CM_ModelNames[ X , Y , Z ] := PilotName( M );

					{ Also record the off-map icon. }
					if AreAllies( GB , NAV_DefPlayerTeam , NAttValue( M^.NA , NAG_Location , NAS_Team ) ) then begin
						cm_cel_OMIcon[ X , Y ] := SI_Ally;
	{					Mini_Map[ X , Y ] := 5;}
					end else if AreEnemies( GB , NAV_DefPlayerTeam , NAttValue( M^.NA , NAG_Location , NAS_Team ) ) then begin
						cm_cel_OMIcon[ X , Y ] := SI_Enemy;
	{					Mini_Map[ X , Y ] := 1;}
					end else begin
						cm_cel_OMIcon[ X , Y ] := SI_Neutral;
	{					Mini_Map[ X , Y ] := 3;}
					end;
				end;

			end else if M^.G = GG_MetaTerrain then begin
				{ Insert MetaTerrain-drawing code here. }

				case M^.S of
				GS_MetaDoor:		if M^.Stat[ STAT_Pass ] = -100 then AddBasicDoorCel( X , Y , TCEL_Door );
				GS_MetaStairsUp:	AddCMCel( GB , X , Y ,  0 , CMC_MetaTerrain , Extras_Sprite , ECEL_StairsUp );
				GS_MetaStairsDown:	AddCMCel( GB , X , Y ,  0 , CMC_MetaTerrain , Extras_Sprite , ECEL_StairsDown );
				GS_MetaTrapdoor:	AddCMCel( GB , X , Y ,  0 , CMC_MetaTerrain , Extras_Sprite , ECEL_Trapdoor );
				GS_MetaElevator:	AddBasicDoorCel( X , Y , TCEL_Elevator );
				GS_MetaBuilding:	begin
								AddBuilding( X , Y , NAttValue( M^.NA , NAG_MTAppearance , NAS_BuildingMesh ) );
								if OnTheMap( GB , X , Y ) and Names_Above_Heads then CM_ModelNames[ X , Y , 1 ] := GearName( M );
							end;
				GS_MetaEncounter:	begin
								AddCMCel( GB , X , Y ,  0 , CMC_MetaTerrain , Encounter_Sprite , ( M^.Stat[ STAT_EncounterType ] mod 3 ) * 3 + ( ( Animation_Phase div 5 ) mod 2 ) );
								if OnTheMap( GB , X , Y ) and Names_Above_Heads then CM_ModelNames[ X , Y , 0 ] := GearName( M );
							end;

				GS_MetaCloud:		AddCMCel( GB , X , Y ,  0 , CMC_MetaTerrain , Extras_Sprite , ECEL_Smoke );
				GS_MetaFire:		AddCMCel( GB , X , Y ,  0 , CMC_MetaTerrain , Extras_Sprite , ECEL_Fire );
				else AddCMCel( 	GB , X , Y , Z , CMC_MetaTerrain , LocateSprite( SpriteName( GB , M ) , SpriteColor( GB , M ) , 64 , 64 ) , MapDirToScreenDir( NAttValue( M^.NA , NAG_Location , NAS_D ) ) );
				end;

			end else begin
				{ Draw the yellow-striped box. }
				AddCMCel( GB , X , Y , Z , CMC_Items , Extras_Sprite , ECEL_Item );
			end;
		end;

		M := M^.Next;
	end;

	{ Go through each tile on the map, displaying terrain and }
	{ other contents. }
	DrawBackdrop;
	TexDest.W := 64;
	TexDest.H := 15;

	{ We need to calculate the virtual X and Y maximums. }
	{ If origin_d is even it's the X axis running down the right from the }
	{ top tile and the Y axis runs to the left. If origin_d is odd, then }
	{ the opposite is true. }
	if ( ( origin_d mod 2 ) = 0 ) then begin
		VX_Max := GB^.Map_Width;
		VY_Max := GB^.Map_Height;
	end else begin
		VX_Max := GB^.Map_Height;
		VY_Max := GB^.Map_Width;
	end;

	for VX := 1 to VX_Max do begin
		for VY := 1 to VY_Max do begin
			{ Determine the map X,Y coordinates that this virtual }
			{ point is pointing to. }
			X := MapX( VX , VY );
			Y := MapY( VX , VY );

			if OnTheScreen( VX , VY ) then begin
				for Z := LoAlt to HiAlt do begin
					for t := 0 to NumCMCelLayers do begin
						if CM_Cel_IsOn[ T ][ X , Y , Z ] then begin
							MyDest.X := ScreenX( VX , VY );
							MyDest.Y := ScreenY( VX , VY ) - Altitude_Height * Z;
							if CM_Cels[ X ,Y , Z , T ].Sprite^.H > 64 then MyDest.Y := MyDest.Y - 32;
							DrawSprite( CM_Cels[ X ,Y , Z , T ].Sprite , MyDest , CM_Cels[ X ,Y , Z , T ].F );
						end;
					end;

					if Names_Above_Heads and ( CM_ModelNames[ X , Y , Z ] <> '' ) then begin
						TexDest.X := ScreenX( VX , VY );
						TexDest.Y := ScreenY( VX , VY ) - Altitude_Height * Z;
						QuickTextC( CM_ModelNames[ X , Y , Z ] , TexDest , StdWhite , Small_Font );
					end;
				end; { For Z... }
			end else if OnTheMap( GB , X , Y ) and ( CM_Cel_OMIcon[ X , Y ] >= 1 ) and ( CM_Cel_OMIcon[ X , Y ] <= 3 ) then begin
				{ This image is off the map, but has a substitute image }
				{ so it should be indicated on the edge. }
				{ Add a note to the OFF_MAP_MODELS array. }
				{ Figure out its relative coordinates, with the center of the map }
				{ as the origin. }
				{ ***NOTE*** Lifted directly from GH1, don't fully understand }
				{  everything going on here, let's hope it works. }
				MyDest.X := ScreenX( VX , VY ) - ( Game_Screen^.W div 2 );
				MyDest.Y := ScreenY( VX , VY ) - ( Game_Screen^.H div 2 );

				{ Use W to save the segment total length, and H to store the }
				{ relative length. }
				Quad := 1;
				if MyDest.Y <= MyDest.X then Quad := Quad + 1;
				if MyDest.Y <= -MyDest.X then Quad := Quad + 2;

				if ( Quad = 1 ) or ( Quad = 4 ) then begin
					MyDest.W := Abs( MyDest.Y ) * 2;
					MyDest.H := MyDest.X + Abs( MyDest.Y );
				end else begin
					MyDest.W := Abs( MyDest.X ) * 2;
					MyDest.H := MyDest.Y + Abs( MyDest.X );
				end;

				OFF_MAP_MODELS[ Quad , ( MyDest.H * NumOMM ) div MyDest.W ] := CM_Cel_OMIcon[ X , Y ];

			end; { if OnTheScreen... }
		end;
	end;

	{ We don't draw the off-map models yet, because they're getting stuck on top of }
	{ everything else later on. }
end;

Procedure RenderMap( GB: GameBoardPtr );
	{ Render the location stored in G_Map, along with all items and characters on it. }
	{ Also save the position of the mouse pointer, in world coordinates. }

	{ I'm going to use the GH1 method for doing this- create a list of cels first containing all the }
	{ terrain, mecha, and effects to be displayed. Then, render them. There's something I don't like }
	{ about this method but I don't remember what, and it seems to be more efficient than searching }
	{ through the list of models once per tile once per elevation level. }
var
	X,Y,Z: Integer;
	M: GearPtr;
begin
	{ How to find out the proper mouse location- while drawing each sprite, do a check with the }
	{ map coordinates. If we get a second match later on, that supercedes the previous match obviously, }
	{ since we're overwriting something anyways. Brilliance! }

	ClrScreen;

	{ Clear the basic cels- the ones that the map renderer has access to. There will be additional }
	{ layers which the map renderer shouldn't touch. }
	for X := 1 to NumBasicCelLayers do ClearCMCelLayer( X );

	Render_Isometric( GB );
end;


Procedure FocusOn( Mek: GearPtr );
	{ Focus on the provided mecha. }
begin
	if Mek <> Nil then begin
		ClearCMCelLayer( CMC_Effects );
		origin_x := NAttValue( Mek^.NA , NAG_Location , NAS_X );
		origin_y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );
	end;
	Focused_On_Mek := Mek;
end;

Procedure IndicateTile( GB: GameBoardPtr; X , Y , Z: Integer );
	{ Indicate the requested tile. }
begin
	ClearCMCelLayer( CMC_Effects );
	if OnTheMap( GB , X , Y ) then begin
		origin_x := x;
		origin_y := y;
		if ( Z >= LoAlt ) and ( Z <= HiAlt ) then AddCMCel( GB , X , Y , Z , CMC_Effects , Extras_Sprite , 2 );
	end;
end;

Procedure DisplayMiniMap( GB: GameBoardPtr );
	{ Draw the mini-map. }
const
	ZONE_MiniMap: TSDL_Rect = ( X:15; Y: 15; W: 300; H: 300 );
var
	MyDest: TSDL_Rect;
	X,Y: Integer;
	M: GearPtr;
begin
	ZONE_MiniMap.W := GB^.MAP_Width * 3;
	ZONE_MiniMap.H := GB^.MAP_Height * 3;
	SDL_FillRect( game_screen , @ZONE_MiniMap , SDL_MapRGBA( Game_Screen^.Format , 0 , 0 , 255 , 150 ) );

	for x := 1 to GB^.MAP_Width do begin
		for y := 1 to GB^.MAP_Height do begin
			MyDest.X := ZONE_MiniMap.X - 3 + X*3;
			MyDest.Y := ZONE_MiniMap.Y - 3 + Y*3;
			DrawSprite( Mini_Map_Sprite , MyDest , TileTerrain( GB , X , Y ) + 10 );
		end;
	end;

	M := GB^.Meks;
	while M <> Nil do begin
		if IsMasterGear( M ) and MekVisible( GB , M ) and GearActive( M ) then begin
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			MyDest.X := ZONE_MiniMap.X - 3 + X*3;
			MyDest.Y := ZONE_MiniMap.Y - 3 + Y*3;

			if AreAllies( GB , NAV_DefPlayerTeam , NAttValue( M^.NA , NAG_Location , NAS_Team ) ) then begin
				DrawSprite( Mini_Map_Sprite , MyDest , 5 + ( Animation_Phase div 5 mod 2 ) );
			end else if AreEnemies( GB , NAV_DefPlayerTeam , NAttValue( M^.NA , NAG_Location , NAS_Team ) ) then begin
				DrawSprite( Mini_Map_Sprite , MyDest , 1 + ( Animation_Phase div 5 mod 2 ) );
			end else begin
				DrawSprite( Mini_Map_Sprite , MyDest , 3 + ( Animation_Phase div 5 mod 2 ) );
			end;

			DrawSprite( Mini_Map_Sprite , MyDest , 1 + ( Animation_Phase div 5 mod 2 ) );
		end;
		M := M^.Next;
	end;
end;

Procedure ScrollMap( GB: GameBoardPtr );
	{ Asjust the position of the map origin. }
begin
	if ( RK_KeyState[ SDLK_Delete ] = 1 ) then begin
		origin_d := ( origin_d + 1 ) mod Num_Rotation_Angles;
	end else if ( RK_KeyState[ SDLK_Insert ] = 1 ) then begin
		origin_d := ( origin_d + Num_Rotation_Angles - 1 ) mod Num_Rotation_Angles;
	end;
end;


Procedure ClearOverlays;
	{ Erase all overlays currently on the screen. }
begin
	ClearCMCelLayer( CMC_Effects );
end;

Procedure AddOverlay( GB: GameBoardPtr; OL_Sprite: SensibleSpritePtr; X , Y , Z, F: Integer );
	{ Add an overlay to the screen. }
begin
	AddCMCel( GB , X , Y , Z , CMC_Effects , OL_Sprite , F );
end;

Function ProcessShotAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;
	{ Process this shot. Return TRUE if the missile }
	{ is visible on the screen, FALSE otherwise. }
	{ V = Timer }
	{ Stat 1 , 2 , 3 -> X1 , Y1 , Z1 }
	{ Stat 4 , 5 , 6 -> X2 , Y2 , Z2 }
const
	X1 = 1;
	Y1 = 2;
	Z1 = 3;
	X2 = 4;
	Y2 = 5;
	Z2 = 6;
var
	P: Point;
begin
	{ Increase the counter, and find the next spot. }
	Inc( AnimOb^.V );
	P := SolveLine( AnimOb^.Stat[ X1 ] , AnimOb^.Stat[ Y1 ] , AnimOb^.Stat[ Z1 ] , AnimOb^.Stat[ X2 ] , AnimOb^.Stat[ Y2 ] , AnimOb^.Stat[ Z2 ] , AnimOb^.V );

	{ If this is the destination point, then we're done. }
	if ( P.X = AnimOb^.Stat[ X2 ] ) and ( P.Y = AnimOb^.Stat[ Y2 ] ) then begin
		RemoveGear( AnimList , ANimOb );
		P.X := 0;

	{ If this is not the destination point, draw the missile. }
	end else begin
		{Display bullet...}
		AddOverlay( GB , Strong_Hit_Sprite , P.X , P.Y , P.Z , 0 );
	end;

	ProcessShotAnimation := True;
end;

Function ProcessPointAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;
	{ Process this effect. Return TRUE if the blast }
	{ is visible on the screen, FALSE otherwise. }
	{ V = Timer }
	{ Stat 1 , 2 , 3 -> X , Y , Z }
const
	X = 1;
	Y = 2;
	Z = 3;
var
	it: Boolean;
begin
	if AnimOb^.V < 10 then begin
		case AnimOb^.S of
		GS_DamagingHit: begin
				AddOverlay( GB , Strong_Hit_Sprite , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , AnimOb^.V );

				end;
		GS_ArmorDefHit: begin
				AddOverlay( GB , Weak_Hit_Sprite , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] ,  AnimOb^.V );

				end;

		GS_Parry,GS_Block,GS_Intercept,GS_Resist:	begin
				AddOverlay( GB , Parry_Sprite , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] ,  AnimOb^.V );
				Inc( AnimOb^.V );
				end;

		GS_Dodge,GS_ECMDef:	begin
				AddOverlay( GB , Miss_Sprite , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , AnimOb^.V );
				Inc( AnimOb^.V );
				end;

		GS_Backlash:	begin
				AddOverlay( GB , Strong_Hit_Sprite , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , AnimOb^.V );

				end;
		GS_AreaAttack:	begin
				AddOverlay( GB , Strong_Hit_Sprite , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , AnimOb^.Stat[ Z ] , AnimOb^.V );

				end;
		end;


		{ Increment the counter. }
		Inc( AnimOb^.V );

		it := True;
	end else begin

		RemoveGear( AnimList , AnimOb );
		it := False;
	end;

	ProcessPointAnimation := it;
end;

Procedure RenderWorldMap( GB: GameBoardPtr; PC: GearPtr; X0,Y0: Integer );
	{ Render the world map. X0,Y0 is the center tile. }
var
	DX,DY,X,Y: Integer;
	MyDest: TSDL_Rect;
	MySprite: SensibleSpritePtr;
	M: GearPtr;
begin
	ClrZone( ZONE_WorldMap );
	MyDest.W := 64;
	MyDest.H := 64;
	{ First, render the terrain. }
	for DX := -2 to 2 do begin
		for DY := -2 to 2 do begin
			X := X0 + DX;
			Y := Y0 + DY;
			FixWorldCoords( GB^.Scene , X , Y );
			MyDest.X := ZONE_WorldMap.X + ( DX + 2 ) * 64;
			MyDest.Y := ZONE_WorldMap.Y + ( DY + 2 ) * 64;
			if OnTheMap( GB , X , Y ) then begin
				DrawSprite( World_Terrain , MyDest , TileTerrain( GB , X , Y ) - 1 );
			end;
		end;
	end;

	{ Next, draw any metaterrain that may be on the map. }
	M := GB^.Meks;
	while M <> Nil do begin
		if ( M^.G = GG_MetaTerrain ) and ( M^.Stat[ STAT_MetaVisibility ] = 0 ) and OnTheMap( GB , M ) then begin
			DX := NAttValue( M^.NA , NAG_Location , NAS_X ) - X0;
			if WorldWrapsX( GB^.Scene ) and ( DX < -2 ) then DX := DX + GB^.Map_Width;
			DY := NAttValue( M^.NA , NAG_Location , NAS_Y ) - Y0;
			if WorldWrapsY( GB^.Scene ) and ( DY < -2 ) then DY := DY + GB^.Map_Height;
			if ( DX >= -2 ) and ( DX <= 2 ) and ( DY >= -2 ) and ( DY <= 2 ) then begin
				MyDest.X := ZONE_WorldMap.X + ( DX + 2 ) * 64;
				MyDest.Y := ZONE_WorldMap.Y + ( DY + 2 ) * 64;
				MySprite := LocateSprite( SpriteName( Nil , M ) , SpriteColor( GB , M ) , 64 , 64 );
				DrawSprite( MySprite , MyDest , NAttValue( M^.NA , NAG_Display , NAS_PrimaryFrame ) );
			end;
		end;
		M := M^.Next;
	end;

	{ Finally, draw the little crosshair in the middle to indicate the party poistion. }
	if PC <> Nil then begin
		MyDest.X := ZONE_WorldMap.X + 128;
		MyDest.Y := ZONE_WorldMap.Y + 128;
		MySprite := LocateSprite( SpriteName( Nil , PC ) , SpriteColor( GB , PC ) , 64 , 64 );
		DrawSprite( MySprite , MyDest , 1 );
	end;
end;

Procedure InitGraphicsForScene( GB: GameBoardPtr );
	{ Initialize the graphics for this scene. Make sure the correct tilesets are loaded. }
const
	NumBackdrops = 1;
	Backdrop_FName: Array [1..NumBackdrops] of String = (
		'bg_space.png'
	);
	iso_tileset_fname: Array [0..NumTileSet] of String = (
		'iso_terrain_default.png',
		'iso_terrain_rocky.png','iso_terrain_default.png','iso_terrain_industrial.png','iso_terrain_default.png'
	);
var
	TileSet,BDNum: Integer;
begin
	if Terrain_Sprite <> Nil then RemoveSprite( Terrain_Sprite );
	if Shadow_Sprite <> Nil then RemoveSprite( Shadow_Sprite );
	if Building_Sprite <> Nil then RemoveSprite( Building_Sprite );
	if Extras_Sprite <> Nil then RemoveSprite( Extras_Sprite );

	if GB^.Scene <> Nil then TileSet := NAttValue( GB^.Scene^.NA , NAG_SceneData , NAS_TileSet )
	else TileSet := NAV_DefaultTiles;
	if ( TileSet > NumTileSet ) or ( TileSet < 0 ) then TileSet := NAV_DefaultTiles;
	Terrain_Sprite := LocateSprite( iso_tileset_fname[ TileSet ] , 64 , 96 );
	Shadow_Sprite := LocateSprite( 'iso_shadows_noalpha.png' , 64 , 96 );
	Building_Sprite := LocateSprite( 'iso_buildings.png' , 64, 96 );
	Extras_Sprite := LocateSprite( 'iso_extras.png' , 64, 96 );

	{ Also set the backdrop. }
	if Current_Backdrop <> Nil then RemoveSprite( Current_Backdrop );
	if GB^.Scene <> Nil then begin
		BDNum := NAttValue( GB^.Scene^.NA , NAG_SceneData , NAS_Backdrop );
		if ( BDNum > 0 ) and ( BDNum <= NumBackdrops ) then begin
			Current_Backdrop := LocateSprite( Backdrop_FName[ BDNum ] , Backdrop_Size , Backdrop_Size );
		end;
	end;

	{ Also clear the cel layers, to prevent crashage. }
	For BDNum := 1 to NumCMCelLayers do ClearCMCelLayer( BDNum );
end;

initialization
	RPGKey;

	SDL_PumpEvents;
	SDL_GetMouseState( Mouse_X , Mouse_Y );


	tile_x := 0;
	tile_y := 0;
    tile_z := 0;

	origin_d := 0;

	Mini_Map_Sprite := LocateSprite( 'minimap.png' , 3 , 3 );
	World_Terrain := LocateSprite( 'world_terrain.png' , 64 , 64 );

	Terrain_Sprite := Nil;
	Shadow_Sprite := Nil;
	Building_Sprite := Nil;
	Current_Backdrop := Nil;
	Extras_Sprite := Nil;

	Items_Sprite := LocateSprite( Items_Sprite_Name , 50 , 120 );
	Off_Map_Model_Sprite := LocateSprite( 'off_map.png' , 16 , 16 );

	Strong_Hit_Sprite := LocateSprite( Strong_Hit_Sprite_Name , 64, 64 );
	Weak_Hit_Sprite := LocateSprite( Weak_Hit_Sprite_Name , 64, 64 );
	Parry_Sprite := LocateSprite( Parry_Sprite_Name , 64, 64 );
	Miss_Sprite := LocateSprite( Miss_Sprite_Name , 64, 64 );

	Encounter_Sprite := LocateSprite( 'encounter_64.png' , 64, 64 );

	Compass_Sprite := LocateSprite( 'iso_compass.png' , 64, 64 );

	ClearOverlays;
	Focused_On_Mek := Nil;


end.
