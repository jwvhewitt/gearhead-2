unit infodisplay;
	{ This unit holds the information browser. }
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

uses gears,locale,gearutil;

Procedure View_Personadex( GB: GameBoardPtr );

implementation

uses ui4gh,narration,interact,arenacfe,
{$IFDEF ASCII}
	vidgfx,vidinfo,vidmenus;
{$ELSE}
	sdlgfx,sdlmap,sdlinfo,sdlmenus;
{$ENDIF}

type
	Personadex_Entry = Record
		NPC,Scene: GearPtr;
	end;

var
	Dex_List: Array of Personadex_Entry;
	Dex_Menu: RPGMenuPtr;
	Info_GB: GameBoardPtr;

Procedure PersonadexRedraw;
	{ A specific item was selected, and its location stored in BP_Source. }
var
	n: Integer;
begin
	CombatDisplay( Info_GB );
	SetupFHQDisplay;
	if ( Dex_Menu <> Nil ) then begin
		n := CurrentMenuItemValue( Dex_Menu );
		if n >= 0 then PersonadexInfo( Dex_List[n].NPC , Dex_List[n].Scene , ZONE_ItemsInfo );
	end;
end;

Procedure View_Personadex( GB: GameBoardPtr );
	{ The PersonaDex allows the PC to view all of his/her relationships }
	{ with NPCs, and some info about the NPCs such as location, motivation, }
	{ and attitude. }
	Procedure SeekAlongTrack( LList: GearPtr; var N: LongInt );
		{ Seek NPCs along this track. Store pointers to the NPCs you find. }
	begin
		while LList <> Nil do begin
			if ( LList^.G = GG_Character ) and ( ( NAttValue( LList^.NA , NAG_XXRan , NAS_XXChar_Attitude ) <> 0 ) or ( NAttValue( LList^.NA , NAG_Relationship , 0 ) <> 0 ) ) then begin
				Dex_List[ N ].NPC := LList;
				Dex_List[ N ].Scene := FindRootScene( FindActualScene( GB , FindGearScene( LList , GB ) ) );
				Inc( N );
			end;
			SeekAlongTrack( LList^.SubCom , N );
			SeekAlongTrack( LList^.InvCom , N );
			LList := LList^.Next;
		end;
	end;

var
	Adv: GearPtr;
	NumMatches,T: LongInt;
begin
	{ Locate the adventure, and determine how many NPCs there are. }
	Adv := FindRoot( GB^.Scene );
	Info_GB := GB;

	NumMatches := NAttValue( Adv^.NA , NAG_Narrative , NAS_MaxCID );
	if NumMatches = 0 then begin
		DialogMsg( 'ERROR: No CIDs recorded in ' + GearName( Adv ) + '.' );
		Exit;
	end;

	{ Set the length of the NPC_List array. }
	SetLength( Dex_List , NumMatches );

	{ Fill the array with NPCs. }
	NumMatches := 0;
	SeekAlongTrack( Adv , NumMatches );
	SeekAlongTrack( GB^.meks , NumMatches );

	{ Create the menu. }
	Dex_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
	if NumMatches > 0 then begin
		for t := 0 to ( NumMatches - 1 ) do begin
			AddRPGMenuItem( Dex_Menu , GearName( Dex_List[ t ].NPC ) , t );
		end;
	end else begin
		AddRPGMenuItem( Dex_Menu , MsgString( 'MEMO_CALL_NoPeople' ) , -1 );
	end;
	RPMSortAlpha( Dex_Menu );

	{ Browse the menu. }
	T := SelectMenu( Dex_Menu , @PersonadexRedraw );

	{ Clear the menu and dynamic array. }
	DisposeRPGMenu( Dex_Menu );
	SetLength( Dex_List , 0 );
end;

end.
