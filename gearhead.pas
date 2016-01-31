program gearhead;
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

{$IFNDEF DEBUG}
{$IFNDEF ASCII}
{$IFNDEF LINUX}
{$APPTYPE GUI}
{$ENDIF}
{$ENDIF}
{$ENDIF}

uses 	gears,navigate,randmaps,locale,arenaplay,ghchars,gearutil,gearparser,
	ability,chargen,backpack,ui4gh,gh2arena,menugear,
{$IFDEF ASCII}
	vidgfx,vidmap,vidmenus;
{$ELSE}
	sdlgfx,sdlmap,sdlmenus;
{$ENDIF}

const
	Version = '0.628';

Procedure RedrawOpening;
	{ The opening menu redraw procedure. }
begin
	SetupTitleScreenDisplay;
	CMessage( Version , ZONE_Title_Screen_Version , StdWhite );
	if Console_History <> Nil then begin
		RedrawConsole;
	end;
end;


Procedure GenerateNewPC;
	{ Call the character creator, and save the resultant }
	{ character to disk. }
var
	PC: GearPtr;
begin
	PC := CharacterCreator( 0 );
	if PC <> Nil then begin
		{ Write this character to disk. }
		SaveEgg( PC );

		{ Get rid of the PC gear. }
		DisposeGear( PC );
	end;
end;

Procedure StartRPGCampaign;
	{ Load & run the adventure. }
var
	RPM: RPGMenuPtr;
	uname: String;
	PC: GearPtr;
	F: Text;
begin
	PC := Nil;

	{ Create a menu listing all the characters in the SaveGame directory. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Title_Screen_Menu );
	BuildFileMenu( RPM , Save_Egg_Base + Default_Search_Pattern );

	if RPM^.NumItem > 0 then begin
		RPMSortAlpha( RPM );
		AddRPGMenuItem( RPM , MsgString( 'STARTRPG_NewChar' ) , -2 );
		DialogMSG('Select character file.');

		uname := SelectFile( RPM , @RedrawOpening );

		if uname = MsgString( 'STARTRPG_NewChar' ) then begin
			PC := CharacterCreator( 0 );

		end else if uname <> '' then begin
			Assign(F, Save_Game_Directory + uname );
			reset(F);
			PC := ReadCGears(F);
			Close(F);
		end;

	end else begin
		{ The menu was empty... make a new PC! }
		PC := CharacterCreator( 0 );

	end;

	if PC <> Nil then begin
		StartCampaign( PC );
	end;

	DisposeRPGMenu( RPM );
end;

Procedure DesignDirBrowser;
	{ Browse the mecha files on disk. }
	{ NOTE: This procedure must be called from the Arena opening menu, so that }
	{ the RedrawOpening procedure is properly initialized. }
var
	MekMenu: RPGMenuPtr;
	fname: String;
	part: GearPtr;
begin
	MekMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Title_Screen_Menu );
	BuildFileMenu( MekMenu , Design_Directory + Default_Search_Pattern );
	RPMSortAlpha( MekMenu );
	AddRPGMenuItem( MekMenu , '  Exit' , -1 );

	repeat
		fname := SelectFile( MekMenu , @RedrawOpening );

		if fname <> '' then begin
			part := LoadFile( fname , Design_Directory );
			if Part <> Nil then begin
				if Part^.Next = Nil then begin
					{ Only one mecha in this file. Just view it. }
					MechaPartBrowser( Part , @RedrawOpening );
				end else begin
					{ Multiple mecha in this file. Better write another }
					{ procedure... }
					BrowseDesignFile( Part , @RedrawOpening );
				end;
				DisposeGear( Part );
			end;
		end;
	until fname = '';
	DisposeRPGMenu( MekMenu );
end;


Procedure SeriesDirBrowser;
	{ Browse the series files on disk. }
	{ NOTE: This procedure must be called from the Arena opening menu, so that }
	{ the RedrawOpening procedure is properly initialized. }
var
	MekMenu: RPGMenuPtr;
	fname: String;
	part: GearPtr;
begin
	MekMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Title_Screen_Menu );
	BuildFileMenu( MekMenu , Series_Directory + Default_Search_Pattern );
	RPMSortAlpha( MekMenu );
	AddRPGMenuItem( MekMenu , '  Exit' , -1 );

	repeat
		fname := SelectFile( MekMenu , @RedrawOpening );

		if fname <> '' then begin
			part := LoadFile( fname , Series_Directory );
			if Part <> Nil then begin
				if Part^.Next = Nil then begin
					{ Only one mecha in this file. Just view it. }
					MechaPartBrowser( Part , @RedrawOpening );
				end else begin
					{ Multiple mecha in this file. Better write another }
					{ procedure... }
					BrowseDesignFile( Part , @RedrawOpening );
				end;
				DisposeGear( Part );
			end;
		end;
	until fname = '';
	DisposeRPGMenu( MekMenu );
end;


var
	RPM: RPGMenuPtr;
	N: Integer;

begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Title_Screen_Menu );
	AddRPGMenuItem( RPM , 'Create Character' , 1 );
	AddRPGMenuItem( RPM , 'Load RPG Campaign' , 2 );
	AddRPGMenuItem( RPM , 'Start RPG Campaign' , 3 );

	AddRPGMenuItem( RPM , 'Load Arena Campaign' , 6 );
	AddRPGMenuItem( RPM , 'Start Arena Campaign' , 7 );

	AddRPGMenuItem( RPM , 'View Design Files' , 4 );

	if XXRan_Debug then begin
		AddRPGMenuItem( RPM , 'View Series Files' , 5 );
	end;

	AddRPGMenuItem( RPM , 'Quit Game' , -1 );

	repeat
		if not STARTUP_OK then DialogMsg( 'ERROR: Main game directories not found. Please check installation of the game.' );

		N := SelectMenu( RPM , @RedrawOpening );

		case N of
			1:	GenerateNewPC;
			2:	RestoreCampaign( @RedrawOpening );
			3:	StartRPGCampaign;
			4:	DesignDirBrowser;
			5:	SeriesDirBrowser;
			6:	RestoreArenaCampaign( @RedrawOpening );
			7:	StartArenaCampaign;
		end;

		{ Get rid of the console history from previous games. }
		DisposeSAtt( Console_History );
		DisposeSAtt( Skill_Roll_History );
	until N = -1;

	{deallocate all dynamic resources.}
	DisposeRPGMenu( RPM );
end.
