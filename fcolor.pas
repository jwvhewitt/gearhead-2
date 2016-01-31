Program fcolor;
	{ Show mecha in the colors for all factions. }
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

{$APPTYPE GUI}
uses gears,gearparser,sdl,glgfx;

const
	ZONE_All: TSDL_Rect = (x: 5 ; y:5; w:ScreenWidth - 10; h:ScreenHeight - 10 );

	X_Size = 150;
	Y_Size = 80;

	Text_Offset = 64;

var
	MyDest,TextDest: TSDL_Rect;
	F: GearPtr;
	S: SensibleSpritePtr;

begin
	ClrScreen;
	InfoBox( ZONE_All );
	MyDest.X := ZONE_All.X;
	MyDest.Y := ZONE_All.Y;
	TextDest.X := ZONE_All.X;
	TextDest.Y := ZONE_All.Y + Text_Offset;
	F := Factions_List;
	while F <> Nil do begin
		S := LocateSprite( 'btr_buruburu.png' , SAttValue( F^.SA , 'mecha_colors' ) , 64 , 64 );
		DrawSprite( S , MyDest , 1 );
		QuickText( SAttValue( F^.SA , 'name' ) , TextDest , StdWhite , Small_Font );

		MyDest.X := MyDest.X + X_Size;
		if ( MyDest.X + X_Size ) > ( ZONE_All.X + ZONE_All.W ) then begin
			MyDest.X := ZONE_All.X;
			MyDest.Y := MyDest.Y + Y_Size;
		end;
		TextDest.Y := MyDest.Y + Text_Offset;
		TextDest.X := MyDest.X;
		F := F^.Next;
	end;

	DoFlip;
	MoreKey;
end.
