unit spaceships;
	{ This unit handles spaceships. }
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

Function NewSpaceship( GB: GameBoardPtr; const Desig: String );

implementation

uses gearparser,gearutil;

var
	Spaceship_Prototype_List: GearPtr;

Function NewSpaceship( GB: GameBoardPtr; const Desig: String );
	{ Create a new spaceship of type DESIG. Give it a unique name and scene IDs. }
var
	Ship: GearPtr;
begin

end;

initialization
	Spaceship_Prototype_List := AggregatePattern( 'SHIP_*.txt' , Series_Directory );


finalization
	DisposeGear( Spaceship_Prototype_List );

end.
