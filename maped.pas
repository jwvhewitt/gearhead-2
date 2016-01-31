Program maped;
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

{	This is the map editor for GH2. Note that this program must be compiled
	in ASCII mode.
}


uses gears,locale,vidgfx,randmaps,video,ui4gh,texutil,vidmenus;

const
	METerrGfx: Array [1..NumTerr] of Char = (
		'.', '=', '#', '=', '%',
		'.', '.', '^', '^', '^',
		'.', '#', '#', '.', '+',
		'.', '=', '-', '.', '#',
		'.', '%', '-', '&', '&',
		'#', '&'
	);
	METerrColor: Array [1..NumTerr] of Byte = (
		LightGreen, LightGreen, LightGreen, LightBlue, DarkGray,
		LightGray, LightCyan, DarkGray, LightGray, White,
		DarkGray, LightGray, White, DarkGray, DarkGray,
		LightBlue, LightBlue, LightBlue, Brown, Yellow,
		LightBlue, Brown,DarkGray,LightGray,LightGray,
		LightCyan,LightGray
	);

Function CellOnTile( GB: GameBoardPtr; X,Y: Integer ): GearPtr;
	{ Look at tile X,Y and return the cell associated with it. }
var
	M,C: GearPtr;
	MX,MY: Integer;
begin
	M := GB^.Meks;
	C := Nil;
	while ( M <> Nil ) and ( C = Nil ) do begin
		MX := M^.Stat[ STAT_PDMC_X ];
		MY := M^.Stat[ STAT_PDMC_Y ];
		if ( MX <= X ) and (( MX + M^.Stat[ STAT_PDMC_W ]) > X ) and ( MY <= Y ) and (( MY + M^.Stat[ STAT_PDMC_H ]) > Y ) then begin
			C := M;
		end;
		M := M^.Next;
	end;
	CellOnTile := C;
end;

Procedure MEDisplayMap( GB: GameBoardPtr; Pen_X,Pen_Y: Integer );
	{ Display the map. Display all tiles and the locations of map cells. }
	{ The Pen_X , Pen_Y position should be centered on the screen. }
const
	{ These arrays tell where to put the direction indicator for a }
	{ map cell. Note that the bright spot points in the direction that }
	{ would be south in the minimap; this is the direction that's used }
	{ as the front of a store tile. }
	Sweet_X: Array [0..3] of byte = ( 2 , 0 , 2 , 4 );
	Sweet_Y: Array [0..3] of byte = ( 4 , 2 , 0 , 2 );
var
	Map_Zone: VGFX_Rect;
	TX,TY,MX,MY,T: Integer;
	M: GearPtr;
	BGColor: Byte;
begin
	ClrScreen;
	Map_Zone.X := 1;
	Map_Zone.Y := 1;
	Map_Zone.W := ScreenColumns - RightColumnWidth;
	Map_Zone.H := ScreenRows - 5;
	ClipZone( Map_Zone );

	for TX := 1 to Map_Zone.W do begin
		for TY := 1 to Map_Zone.H do begin
			MX := TX + Pen_X - Map_Zone.W div 2;
			MY := TY + Pen_Y - Map_Zone.H div 2;
			if OnTheMap( GB , MX , MY ) then begin
				M := CellOnTile( GB , MX , MY );
				if ( MX = Pen_X ) and ( MY = Pen_Y ) then begin
					BGColor := Green;
				end else if M <> Nil then begin
					{ Depending on the direction of this cell, }
					{ color this tile either blue or cyan. }
					if (( MX - M^.Stat[ STAT_PDMC_X ] ) = Sweet_X[ M^.Stat[ STAT_PDMC_D ] ] ) and (( MY - M^.Stat[ STAT_PDMC_Y ] ) = Sweet_Y[ M^.Stat[ STAT_PDMC_D ] ] ) then begin
						BGColor := Cyan;
					end else begin
						BGColor := Blue;
					end;
				end else begin
					BGColor := Black;
				end;
				T := TileTerrain( GB , MX , MY );
				DrawGlyph( METerrGfx[ T ] , TX , TY , METerrColor[T] , BGColor );
			end;
		end;	{ For TY }
	end;	{ For TX }

	{ Restore the clip zone. }
	MaxClipZone;
end;

Procedure MapEditInfo( Pen , X , Y: Integer );
	{ Display some info about the pen, and print out some instructions while you're }
	{ at it. }
const
	Instructions = ' [ ] Change Pen' + #13 + ' S Save Map' + #13 + ' C Clear Map' + #13 + ' c Add/Rotate Cell' + #13 + ' d Delete Cell'  + #13 + ' Q Quit Editor';
begin
	GameMsg( METerrGfx[ Pen ] + ' ' + MsgString( 'TerrNAME_' + BStr( Pen ) ) , ZONE_Info , METerrColor[ Pen ] );
	GameMsg( BStr( X ) + ' , ' + BStr( Y ) + #13 + Instructions , ZONE_Menu , StdWhite );
	RedrawConsole;
end;


Procedure ClearMap( GB: GameBoardPtr; Pen: Integer );
	{ Clear the map using the requested pen terrain. }
var
	X,Y: Integer;
begin
	for X := 1 to GB^.Map_Width do begin
		for Y := 1 to GB^.Map_Height do begin
			SetTerrain( GB , X , Y , Pen );
		end;
	end;
end;

Procedure EditCell( GB: GameBoardPtr; X , Y: Integer );
	{ if there's no cell in this tile, add one. If there is a cell }
	{ in this tile, rotate it. }
var
	Cell: GearPtr;
begin
	Cell := CellOnTile( GB , X , Y );
	if Cell = Nil then begin
		{ No cell. Add one. }
		{ At the moment, no check is made to make sure that cells don't }
		{ overlap. This could result in some massive uglification. }
		Cell := NewGear( Nil );
		AppendGear( GB^.Meks , Cell );
		Cell^.Stat[ STAT_PDMC_X ] := X;
		Cell^.Stat[ STAT_PDMC_Y ] := Y;
		Cell^.Stat[ STAT_PDMC_W ] := 5;
		Cell^.Stat[ STAT_PDMC_H ] := 5;
		Cell^.Stat[ STAT_PDMC_D ] := 0;
	end else begin
		Cell^.Stat[ STAT_PDMC_D ] := ( Cell^.Stat[ STAT_PDMC_D ] + 1 ) mod 4;
	end;
end;

Procedure DeleteCell( GB: GameBoardPtr; X , Y: Integer );
	{ if there's a cell in this tile, delete it. }
var
	Cell: GearPtr;
begin
	Cell := CellOnTile( GB , X , Y );
	if Cell <> Nil then begin
		RemoveGear( GB^.Meks , Cell );
	end;
end;


Procedure EditMap( GB: GameBoardPtr; const FName: String );
	{ Edit the given map. Save it to disk if need be. }
var
	A: CHar;
	Pen,X,Y: Integer;
	Procedure RepositionCursor( D: Integer );
	begin
		if OnTheMap( GB , X + AngDir[ D , 1 ] , Y + AngDir[ D , 2 ] ) then begin
			X := X + AngDir[ D , 1 ];
			Y := Y + AngDir[ D , 2 ];
		end;
	end;
begin
	{ Initialize our tools. }
	Pen := 1;
	X := 1;
	Y := 1;
	DialogMsg( 'Editing ' + fname + '.' );

	repeat
		MEDisplayMap( GB , X , Y );
		MapEditInfo( Pen , X , Y );
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

		end else if A = ']' then begin
			Pen := Pen + 1;
			if Pen > NumTerr then pen := 1;

		end else if A = '[' then begin
			Pen := Pen - 1;
			if Pen < 1 then pen := NumTerr;

		end else if A = ' ' then begin
			SetTerrain( GB , X , Y , Pen );

		end else if A = 'c' then begin
			EditCell( GB , X , Y );

		end else if A = 'd' then begin
			DeleteCell( GB , X , Y );

		end else if A = 'S' then begin
			DialogMsg( 'Saving...' );
			SavePredrawnMap( GB , FName );
			DialogMsg( 'Saved map ' + fname + '.' );


		end else if A = 'C' then begin
			ClearMap( GB , Pen );

		end;

	until A = 'Q';

	{ Get rid of the map. }
	DisposeMap( GB );
end;

Procedure RedrawOpening;
	{ The opening menu redraw procedure. }
begin
	ClrScreen;
	InfoBox( ZONE_Menu );
	RedrawConsole;
end;

Procedure CreateNewMap;
	{ Create a brand new map and pass it to the editor. }
var
	fname: String;
	RPM: RPGMenuPtr;
	W,H,T: Integer;
	GB: GameBoardPtr;
begin
	fname := GetStringFromUser( 'Enter filename for this map.' , @RedrawOpening );
	if fname <> '' then begin
		RPM := 	CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
		for t := 1 to 20 do AddRPGMenuItem( RPM , BSTr( t * 5 ) + ' tiles' , T * 5 );
		DialogMsg( 'Enter width' );
		W := SelectMenu( RPM , @RedrawOpening );
		if W <> -1 then begin
			DialogMsg( 'Enter height' );
			H := SelectMenu( RPM , @RedrawOpening );
			if H <> -1 then begin
				GB := NewMap( W , H );
				EditMap( GB , fname );
			end;
		end;
		DisposeRPGMenu( RPM );
	end;
end;

Procedure EditOldMap;
	{ Load an old map from disk and pass it to the editor. }
var
	fname: String;
	RPM: RPGMenuPtr;
	GB: GameBoardPtr;
begin
	RPM := 	CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	BuildFileMenu( RPM , Series_Directory + 'MAP_*.txt' );
	if RPM^.NumItem > 0 then begin
		fname := SelectFile( RPM , @RedrawOpening );
		if fname <> '' then begin
			GB := LoadPredrawnMap( fname );
			EditMap( GB , fname );
		end;
	end;
	DisposeRPGMenu( RPM );
end;

var
	RPM: RPGMenuPtr;
	N: Integer;

begin
	RPM := 	CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu );
	AddRPGMenuItem( RPM , 'Create New Map' , 1 );
	AddRPGMenuItem( RPM , 'Load Existing Map' , 2 );
	AddRPGMenuItem( RPM , 'Exit MapEd' , -1 );

	repeat
		N := SelectMenu( RPM , @RedrawOpening );
		Case N of
			1:	CreateNewMap;
			2:	EditOldMap;
		end;
	until N = -1;

	DisposeRPGMenu( RPM );
end.
