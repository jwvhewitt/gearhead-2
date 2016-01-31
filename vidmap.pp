unit vidmap;
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

var
	Origin_X,Origin_Y: Integer;
	Focused_On_Mek: GearPtr;

Function ScreenDirToMapDir( D: Integer ): Integer;
Function KeyboardDirToMapDir( D: Integer ): Integer;

Procedure RenderMap( GB: GameBoardPtr );
Procedure FocusOn( Mek: GearPtr );

Procedure IndicateTile( GB: GameBoardPtr; X , Y , Z: Integer );

Procedure ClearOverlays;
Function ProcessShotAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;
Function ProcessPointAnimation( GB: GameBoardPtr; var AnimList,AnimOb: GearPtr ): Boolean;

Procedure RenderWorldMap( GB: GameBoardPtr; PC: GearPtr; X0,Y0: Integer );


implementation

uses ui4gh,vidgfx,video,ability,ghprop,gearutil,effects;

const
	TerrGfx: Array [1..NumTerr] of Char = (
		'.', '=', '#', '=', '%',
		'.', '.', '^', '^', '^',
		'.', '#', '#', '.', '+',
		'.', '=', '-', '.', '#',
		'.', '%', '-', '&', '&',
		'#', '&'
	);
	TerrColor: Array [0..NumTileSet,1..NumTerr] of Byte = (
	{ Default Tileset }
	(	Green, LightGreen, LightGreen, LightBlue, DarkGray,
		LightGray, Cyan, DarkGray, LightGray, White,
		DarkGray, LightGray, White, DarkGray, DarkGray,
		Blue, Blue, Blue, Brown, Yellow,
		Blue, Brown,DarkGray,LightGray,LightGray,
		LightCyan,LightGray
		),

	{ Rocky Tileset }
	(	DarkGray, LightGreen, LightGreen, LightBlue, DarkGray,
		LightGray, Cyan, DarkGray, LightGray, White,
		DarkGray, LightGray, DarkGray, DarkGray, DarkGray,
		Blue, Blue, Blue, Brown, Yellow,
		Blue, Brown,DarkGray,LightGray,LightGray,
		LightCyan,LightGray
		),

	{ Palace Park Tileset }
	(	Green, LightGreen, LightGreen, LightBlue, DarkGray,
		LightGray, Cyan, DarkGray, LightGray, White,
		DarkGray, LightGray, White, DarkGray, DarkGray,
		Blue, Blue, Blue, Brown, Yellow,
		Blue, Brown,DarkGray,LightGray,LightGray,
		LightCyan,LightGray
		),

	{ Industrial Tileset }
	(	Green, LightGreen, LightGreen, LightBlue, DarkGray,
		LightGray, Cyan, DarkGray, LightGray, White,
		DarkGray, LightGray, White, DarkGray, DarkGray,
		Blue, Blue, Blue, Brown, Yellow,
		Blue, Brown,DarkGray,LightGray,LightGray,
		LightCyan,LightGray
		),

	{ Organic Tileset }
	(	Red, LightGreen, LightGreen, LightBlue, DarkGray,
		LightGray, Magenta, DarkGray, LightGray, White,
		DarkGray, LightGray, LightMagenta, Magenta, DarkGray,
		Blue, Blue, Blue, Brown, Yellow,
		Blue, Brown,DarkGray,LightGray,LightGray,
		Yellow,LightGray
		)

	);

Type
	OverlayCell = Record
		gfx: 	Char;
		c: 	Byte;	{ If the color of an overlay cell is black, it's "off" }
	end;

var
	Overlays: Array [1..MaxMapWidth,1..MaxMapWidth] of OverlayCell;
	Indicate_X,Indicate_Y: Integer;


Function ScreenDirToMapDir( D: Integer ): Integer;
	{ Convert the requested screen direction to a map direction. }
	{ For ASCII mode, this is trivially easy. }
begin
	ScreenDirToMapDir := D;
end;

Function KeyboardDirToMapDir( D: Integer ): Integer;
	{ Given the press of a key on the keyboard, return the map direction it }
	{ corresponds to. }
begin
	KeyboardDirToMapDir := ScreenDirToMapDir( D );
end;

Function TeamColor( GB: GameBoardPtr; G: GearPtr ): Byte;
	{ Select a good color based upon the team this }
	{ gear belongs to. }
var
	T,color: LongInt;
begin
	if ( G = Nil ) or ( GB = Nil ) then begin
		{ No gear provided - Neutral Gray. }
		color := NeutralGrey;

	end else if not GearOperational( G ) then begin
		{ Nonfunctioning gear. Color = DarkGrey. }
		color := DarkGray;

	end else begin
		T := NAttValue( G^.NA , NAG_Location , NAS_Team );

		if T = NAV_DefPlayerTeam then begin
			{ Player team. Color = Blue. }
			color := PlayerBlue;

		end else if AreEnemies( GB , NAV_DefPlayerTeam , T ) then begin
			{ Enemy team. Color = Red. }
			color := LightMagenta;

		end else if AreAllies( GB , NAV_DefPlayerTeam , T ) then begin
			{ Ally team. Color = Purple. }
			color := LightCyan;

		end else begin
			{ Neutral team. Color = Brown. }
			if G^.G = GG_Prop then begin
				color := LightGray;
			end else begin
				color := NeutralBrown;
			end;
		end;
	end;
	TeamColor := Color;
end;

Function ModelColor( GB: GameBoardPtr; G: GearPtr ): Byte;
	{ Return a color for this model. }
var
	C: Byte;
begin
	if Destroyed( G ) then begin
		C := DarkGray;

	end else if G^.G = GG_MetaTerrain then begin
		case G^.S of
			GS_MetaCloud:	if SAttValue( G^.SA , 'EFFECT' ) = '' then C := LightGray
					else C := LightGreen;
			GS_MetaFire:	Case Random( 3 ) of
						0,1:	C := LightRed;
						2:	C := Yellow;
					end;
			GS_MetaEncounter:	Case G^.Stat[ STAT_EncounterType ] of
							ENCOUNTER_Defense:	C := LightMagenta;
							ENCOUNTER_NonCombat:	C := LightCyan;
						else C := LightRed;
						end;
		else C := Yellow;
		end;
	end else if ( G = Focused_On_Mek ) then begin
		C := White;
	end else if IsMasterGear( G ) then begin
		C := TeamColor( GB , G );
	end else begin
		C := LightGray;
	end;
	ModelColor := C;
end;

Function ModelGfx( G: GearPtr ): Char;
	{ Return a character to represent this model on the display. }
var
	gfx: Char;
	roguechar: String;
begin
	gfx := ' ';
	if Destroyed( G ) then begin
		gfx := '%';
	end else begin
		roguechar := SAttValue( G^.SA , 'ROGUECHAR' );
		if roguechar <> '' then begin
			gfx := roguechar[1];
		end else if ( NAttValue( G^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and IsMasterGear( G ) then begin
			gfx := '@';
		end else if IsMasterGear( G ) then begin
			gfx := GearName( G )[1];
		end else begin
			Case G^.G of
				GG_Weapon:	gfx := '/';
				GG_ExArmor:	gfx := ']';
				GG_Shield:	gfx := ')';
			else gfx := '-';
			end;
		end;
	end;
	ModelGfx := Gfx;
end;

Procedure DrawMapGlyph( img: Char; X,Y,FG,MX,MY: Byte );
	{ Draw a glyph on the map. If this map tile (MX,MY) is indicated, draw the }
	{ tile in reverse. }
begin
	if ( MX = Indicate_X ) and ( MY = Indicate_Y ) then begin
		if FG = White then FG := LightGray
		else if ( FG = Black ) or ( img = ' ' ) then FG := Blue;
		DrawGlyph( img , X , Y , White , FG );
	end else begin
		DrawGlyph( img , X , Y , FG , Black );
	end;
end;

Procedure RenderMap( GB: GameBoardPtr );
	{ The map fills the entire area from row 4 to row (ScreenHeight - 5). }
	{ Origin_X,Origin_Y represents the center of the map rather than the }
	{ edge. }
	Function ModelWeight( M: GearPtr ): Byte;
		{ Return the Image Weight for this model. }
	begin
		if IsMasterGear( M ) and NotDestroyed( M ) then begin
			ModelWeight := 5;
		end else if M^.G = GG_MetaTerrain then begin
			ModelWeight := 3;
		end else begin
			ModelWeight := 1;
		end;
	end;
var
	Map_Zone: VGFX_Rect;
	TX,TY,MX,MY,Terr: Integer;
	M: GearPtr;
	ImageWeight: Array [1..MaxMapWidth,1..MaxMapWidth] of Byte;
		{ This array is used to stop models from being drawn if there's }
		{ already been something more important drawn in their tile. }
	TileSet: Integer;
begin
	Map_Zone.X := 1;
	Map_Zone.Y := 1;
	Map_Zone.W := ScreenColumns - RightColumnWidth;
	Map_Zone.H := ScreenRows - 5;
	ClipZone( Map_Zone );

	if ( GB^.Scene <> Nil ) then TileSet := NAttValue( GB^.Scene^.NA , NAG_SceneData , NAS_TileSet )
	else TileSet := NAV_DefaultTiles;

	{ Start by displaying the terrain. }
	for TX := 1 to Map_Zone.W do begin
		for TY := 1 to Map_Zone.H do begin
			MX := TX + Origin_X - Map_Zone.W div 2;
			MY := TY + Origin_Y - Map_Zone.H div 2;
			if OnTheMap( GB , MX , MY ) then begin
				{ Initialize the ImageWeight. }
				ImageWeight[ MX , MY ] := 0;
				if Overlays[ MX , MY ].C <> Black then begin
					DrawGlyph( Overlays[ MX , MY ].Gfx , TX , TY , Overlays[ MX , MY ].C , Black );
					{ An overlay goes over everything else. Duh. }
					{ So, set the ImageWeight to its maximum value. }
					ImageWeight[ MX , MY ] := 255;
				end else if TileVisible( GB , MX , MY ) then begin
					Terr := TileTerrain( GB , MX , MY );
					DrawMapGlyph( TerrGfx[ Terr ] , TX , TY , TerrColor[ TileSet , Terr ] , MX , MY );
				end else begin
					DrawMapGlyph( ' ' , TX , TY , Black , MX , MY );
				end;
			end;
		end;	{ For TY }
	end;	{ For TX }

	{ Next draw the map content on top of it. Thanks to the FPC video unit which }
	{ is nice and lovely and almost pornographic, I don't have to worry about flicker }
	{ from drawing the map first and the contents second, since nothing goes to the }
	{ screen until I issue a flip. Bwa-ha-ha-ha! }
	M := GB^.Meks;
	while M <> Nil do begin
		{ Depending on what M is, decide what to draw. }
		if OnTheMap( GB , M ) and MekVisible( GB , M ) then begin
			{ MX,MY give the map coordinates of this gear. }
			{ TX,TY give the screen coordinates. }
			MX := NAttValue( M^.NA , NAG_Location , NAS_X );
			MY := NAttValue( M^.NA , NAG_Location , NAS_Y );
			if ImageWeight[ MX , MY ] < ModelWeight( M ) then begin
				TX := MX - Origin_X + Map_Zone.W div 2;
				TY := MY - Origin_Y + Map_Zone.H div 2;
				if ( TX > 0 ) and ( TY > 0 ) and ( TX < 255 ) and ( TY < 255 ) then begin
					DrawMapGlyph( ModelGfx( M ) , TX , TY , ModelColor( GB , M ) , MX , MY );
				end;
				ImageWeight[ MX , MY ] := ModelWeight( M );
			end;
		end;

		M := M^.Next;
	end;	{ While M <> Nil do ... }

	{ Restore the clip zone. }
	MaxClipZone;
end;

Procedure FocusOn( Mek: GearPtr );
	{ Focus on the provided mecha. }
begin
	if Mek <> Nil then begin
		origin_x := NAttValue( Mek^.NA , NAG_Location , NAS_X ) - 1;
		origin_y := NAttValue( Mek^.NA , NAG_Location , NAS_Y ) - 1;
	end;
	Focused_On_Mek := Mek;
end;

Procedure IndicateTile( GB: GameBoardPtr; X , Y , Z: Integer );
	{ Set the indication point to the requested tile. In ASCII mode the }
	{ Z parameter is useless, but I leave it in to avoid changing the }
	{ interface between ASCII and OpenGL. }
begin
	Indicate_X := X;
	Indicate_Y := Y;
	origin_X := X - 1;
	origin_y := Y - 1;
end;

Procedure ClearOverlays;
	{ Erase all overlays currently on the screen. }
	{ Also, reset the indicated tile(s). }
var
	X,Y: Integer;
begin
	for X := 1 to MaxMapWidth do begin
		for y := 1 to MaxMapWidth do begin
			Overlays[ X , Y ].C := Black;
		end;
	end;
	Indicate_X := -1;
	Indicate_Y := -1;
end;

Procedure AddOverlay( GB: GameBoardPtr; X , Y: Integer; gfx: Char; C: Byte );
	{ Add an overlay to the display. This may be a shot, and explosion, or whatever }
	{ else. }
begin
	if OnTheMap( GB , X , Y ) then begin
		Overlays[ X , Y ].Gfx := gfx;
		Overlays[ X , Y ].C := C;
	end;
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
	P := SolveLine( AnimOb^.Stat[ X1 ] , AnimOb^.Stat[ Y1 ] , AnimOb^.Stat[ X2 ] , AnimOb^.Stat[ Y2 ] , AnimOb^.V );

	{ If this is the destination point, then we're done. }
	if ( P.X = AnimOb^.Stat[ X2 ] ) and ( P.Y = AnimOb^.Stat[ Y2 ] ) then begin
		RemoveGear( AnimList , ANimOb );
		P.X := 0;

	{ If this is not the destination point, draw the missile. }
	end else begin
		{Display bullet...}
		AddOverlay( GB , P.X , P.Y , '+' , LightRed );
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
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , '*' , LightRed );

				end;
		GS_ArmorDefHit: begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , '*' , DarkGray );

				end;

		GS_Parry:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , '!' , DarkGray );
				end;

		GS_Dodge:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , '-' , DarkGray );
				end;

		GS_Backlash:	begin
				AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , '*' , Yellow );

				end;
		GS_AreaAttack:	Case Random( 3 ) of
					0,1: AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , '*' , LightRed );
					2: AddOverlay( GB , AnimOb^.Stat[ X ] , AnimOb^.Stat[ Y ] , '*' , Yellow );
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
	DX,DY,X,Y,TX,TY,Terr,TileSet: Integer;
	MyDest: VGFX_Rect;
	M: GearPtr;
begin
	MyDest := ZoneToRect( ZONE_WorldMap );
	ClrZone( MyDest );
	InfoBox( MyDest );

	if ( GB^.Scene <> Nil ) then TileSet := NAttValue( GB^.Scene^.NA , NAG_SceneData , NAS_TileSet )
	else TileSet := NAV_DefaultTiles;

	{ First, render the terrain. }
	for DX := -2 to 2 do begin
		for DY := -2 to 2 do begin
			X := X0 + DX;
			Y := Y0 + DY;
			FixWorldCoords( GB^.Scene , X , Y );

			if OnTheMap( GB , X , Y ) then begin
				Terr := TileTerrain( GB , X , Y );
				for tx := ( ( DX + 2 ) * 5 + MyDest.X ) to ( ( DX + 3 ) * 5 + MyDest.X - 1 ) do begin
					for tY := ( ( DY + 2 ) * 3 + MyDest.Y ) to ( ( DY + 3 ) * 3 + MyDest.Y - 1 ) do begin
						DrawMapGlyph( TerrGfx[ Terr ] , TX , TY , TerrColor[ TileSet , Terr ] , X , Y );
					end;
				end;
			end;
		end;
	end;

	{ Next, draw any metaterrain that may be on the map. }
	M := GB^.Meks;
	while M <> Nil do begin
		if ( M^.G = GG_MetaTerrain ) and ( M^.Stat[ STAT_MetaVisibility ] = 0 ) and OnTheMap( GB , M ) then begin
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );

			DX := X - X0;
			if WorldWrapsX( GB^.Scene ) and ( DX < -2 ) then DX := DX + GB^.Map_Width;
			DY := Y - Y0;
			if WorldWrapsY( GB^.Scene ) and ( DY < -2 ) then DY := DY + GB^.Map_Height;

			if ( DX >= -2 ) and ( DX <= 2 ) and ( DY >= -2 ) and ( DY <= 2 ) then begin
				TX := MyDest.X + ( DX + 2 ) * 5 + 1;
				TY := MyDest.Y + ( DY + 2 ) * 3;
				DrawMapGlyph( ModelGfx( M ) , TX , TY , Yellow , X , Y );
			end;
		end;
		M := M^.Next;
	end;

	{ At the very end, draw the little crosshair in the middle to indicate the party poistion. }
	if PC <> Nil then begin
		DrawMapGlyph( '@' , MyDest.X + MyDest.W div 2 , MyDest.Y + MyDest.H div 2 , StdWhite , X , Y );
	end;
end;


initialization
	Focused_On_Mek := Nil;
	ClearOverlays;

end.
