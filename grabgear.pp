unit grabgear;
	{ This unit has one purpose: To seek gears and stick them in }
	{ ArenaScript's grabbed_gear global variable. }
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

Function GG_LocatePC( GB: GameBoardPtr ): GearPtr;
Function GG_LocateNPC( CID: LongInt; GB: GameBoardPtr; Source: GearPtr ): GearPtr;
Function GG_LocateItem( NID: LongInt; GB: GameBoardPtr; Source: GearPtr ): GearPtr;
Function GG_LocateFaction( FID: Integer; GB: GameBoardPtr; Scene: GearPtr ): GearPtr;
Function GG_LocateAdventure( GB: GameBoardPtr; Source: GearPtr ): GearPtr;
Function GG_GrabDesig( GB: GameBoardPtr; desig: String ): GearPtr;

Function PlotMaster( GB: GameBoardPtr; Source: GearPtr ): GearPtr;
Function StoryMaster( GB: GameBoardPtr; Source: GearPtr ): GearPtr;

Function Attempt_Gear_Grab( const Cmd: String;var Event: String; GB: GameBoardPtr; Source: GearPtr ): Boolean;

implementation

uses ability,arenascript,gearutil,interact,narration,texutil,ghprop,ghchars;

Function GG_LocatePC( GB: GameBoardPtr ): GearPtr;
	{ Attempt to find the player character. If there's more than one }
	{ master on Team 1, return one of them. }
var
	Bits,PC,Pilot: GearPtr;
	XPScore,HiXP: LongInt;
begin
	{ Begin the search... }
	PC := Nil;

	{ We are going to cheat a little bit. }
	{ If the interaction menu has been defined, we already know the }
	{ location of the PC since it's stored in I_PC. }
	if ( IntMenu <> Nil ) and ( I_PC <> Nil ) then begin
		PC := I_PC;
	end else if GB <> Nil then begin
		Bits := GB^.Meks;
		while ( Bits <> Nil ) do begin
			if ( NAttValue( Bits^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and IsMasterGear( Bits ) and OnTheMap( GB , Bits ) and GearOperational( Bits ) then begin
				Pilot := LocatePilot( Bits );
				if ( PC = Nil ) and ( Pilot <> Nil ) then begin
					PC := Bits;
					HiXP := NattValue( Pilot^.NA , NAG_Experience , NAS_TotalXP );
				end else if Pilot <> Nil then begin
					XPScore := NattValue( Pilot^.NA , NAG_Experience , NAS_TotalXP );
					if XPScore > HiXP then begin
						PC := Bits;
						HiXP := XPScore;
					end;
				end;
			end;
			Bits := Bits^.Next;
		end;
	end;

	{ If the PC can't be found on the map, search again... }
	{ This time take any Team1 master that has a pilot. }
	if PC = Nil then begin
		Bits := GB^.Meks;
		while ( Bits <> Nil ) and ( PC = Nil ) do begin
			if ( NAttValue( Bits^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and IsMasterGear( Bits ) and ( LocatePilot( Bits ) <> Nil ) then begin
				PC := Bits;
			end;
			Bits := Bits^.Next;
		end;
	end;

	GG_LocatePC := PC;
end;

Function GG_LocateNPC( CID: LongInt; GB: GameBoardPtr; Source: GearPtr ): GearPtr;
	{ ATtempt to find a NPC in either the mecha list or in the }
	{ adventure. Return NIL if no such NPC can be found. }
var
	NPC: GearPtr;
begin
	{ Error check - no undefined searches!!! }
	if CID = 0 then Exit( Nil );

	NPC := Nil;
	if ( GB <> Nil ) then NPC := SeekGearByCID( GB^.Meks , CID );
	if ( NPC = Nil ) and ( GB^.Scene <> Nil ) then NPC := SeekGearByCID( FindRoot( GB^.Scene ) , CID );
	if NPC = Nil then NPC := SeekGearByCID( FindRoot( Source ) , CID );
	if ( NPC = Nil ) and ( SCRIPT_DynamicEncounter <> Nil ) then NPC := SeekGearByCID( SCRIPT_DynamicEncounter , CID );
	GG_LocateNPC := NPC;
end;

Function GG_LocateItem( NID: LongInt; GB: GameBoardPtr; Source: GearPtr ): GearPtr;
	{ ATtempt to find a item in either the mecha list or in the }
	{ adventure. Return NIL if no such item can be found. }
var
	Item: GearPtr;
begin
	{ Error check - no undefined searches!!! }
	if NID = 0 then Exit( Nil );

	if GB <> Nil then begin
		Item := SeekGearByIDTag( GB^.Meks , NAG_Narrative , NAS_NID , NID );
		if Item = Nil then Item := SeekGearByIDTag( FindRoot( GB^.Scene ) , NAG_Narrative , NAS_NID , NID );
	end else begin
		Item := SeekGearByIDTag( FindRoot( Source ) , NAG_Narrative , NAS_NID , NID );
	end;
	GG_LocateItem := Item;
end;

Function GG_LocateController( ConID: LongInt; GB: GameBoardPtr; Source: GearPtr ): GearPtr;
	{ Attempt to find a plot controller. }
	{ Return NIL if no such item can be found. }
var
	Item: GearPtr;
begin
	{ Error check - no undefined searches!!! }
	if ConID = 0 then Exit( Nil );

	if GB <> Nil then begin
		Item := SeekGearByIDTag( GB^.Meks , NAG_Narrative , NAS_ControllerID , ConID );
		if Item = Nil then Item := SeekGearByIDTag( FindRoot( GB^.Scene ) , NAG_Narrative , NAS_ControllerID , ConID );
	end else begin
		Item := SeekGearByIDTag( FindRoot( Source ) , NAG_Narrative , NAS_ControllerID , ConID );
	end;
	GG_LocateController := Item;
end;

Function GG_LocateFaction( FID: Integer; GB: GameBoardPtr; Scene: GearPtr ): GearPtr;
	{ Find a faction gear, given its ID number and all the regular }
	{ information passed around by ArenaScript procedures. }
begin
	{ Seek the faction. }
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		GG_LocateFaction := SeekFaction( GB^.Scene , FID );

	end else if Scene <> Nil then begin
		GG_LocateFaction := SeekFaction( Scene , FID );

	end else begin
		GG_LocateFaction := Nil;

	end;
end;

Function GG_LocateAdventure( GB: GameBoardPtr; Source: GearPtr ): GearPtr;
	{ Find the adventure. }
begin
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		GG_LocateAdventure := FindRoot( GB^.Scene );
	end else begin
		GG_LocateAdventure := FindRoot( Source );
	end;
end;

Function GG_GrabDesig( GB: GameBoardPtr; desig: String ): GearPtr;
	{ Seek a gear based on its designation. Since designations are the only }
	{ way I can reliably identify gears in the ATLAS, this grabber will be }
	{ used to grab those gears. }
var
	it: GearPtr;
begin
	{ First, search the game board. }
	it := SeekGearByDesig( GB^.Meks , desig );

	{ If it wasn't on the game board, search the adventure. }
	if it = Nil then it := SeekGearByDesig( FindRoot( GB^.Scene ) , desig );

	{ Return whatever we found. }
	GG_GrabDesig := it;
end;

Function PlotMaster( GB: GameBoardPtr; Source: GearPtr ): GearPtr;
	{ Given a scene gear, find the PLOT that it is based off of, }
	{ returning NIL if no such plot exists. Assuming that SCENE is }
	{ based on a plot in the first place, it must be either the }
	{ plot itself, or a descendant of the plot. }
var
	Plot: GearPtr;
begin
	{ Note that the master plot may have a G of GG_AbsolutelyNothing, }
	{ if a previous command in the script has set this plot to be }
	{ advanced. }
	{ GH2v0.231: It may also be a plot remnant. }
	Plot := Source;
	while ( Plot <> Nil ) and (Plot^.G <> GG_Plot ) and ( Plot^.G <> GG_AbsolutelyNothing ) do Plot := Plot^.Parent;
	if ( Plot = Nil ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Plot := GB^.Scene;
		while ( Plot <> Nil ) and (Plot^.G <> GG_Plot ) and ( Plot^.G <> GG_AbsolutelyNothing ) do Plot := Plot^.Parent;
	end;
	if ( Plot = Nil ) and ( Source^.G = GG_MetaTerrain ) and ( Source^.Stat[ STAT_Destination ] < 0 ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Plot := FindMetascenePlot( FindRoot( GB^.Scene ) , Source^.Stat[ STAT_Destination ] );
	end;
	if ( Plot = Nil ) and ( NAttValue( Source^.NA , NAG_Narrative , NAS_NID ) <> 0 ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Plot := FindItemPlot( FindRoot( GB^.Scene ) , NAttValue( Source^.NA , NAG_Narrative , NAS_NID ) );

		{ Maybe it's a quest. Find out. }
		if Plot = Nil then Plot := FindItemQuest( FindRootScene( GB^.Scene ) , NAttValue( Source^.NA , NAG_Narrative , NAS_NID ) );
	end;

	{ This plot could be a quest. Look that up now. }
	if ( Plot = Nil ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		if NAttValue( Source^.NA , NAG_Narrative , NAS_PlotID ) <> 0 then begin
			Plot := SeekGearByIDTag( FindRoot( GB^.Scene ) , NAG_PlotStatus , NAttValue( Source^.NA , NAG_Narrative , NAS_PlotID ) , 1 );
		end else if NAttValue( GB^.Scene^.NA , NAG_Narrative , NAS_PlotID ) <> 0 then begin
			Plot := SeekGearByIDTag( FindRoot( GB^.Scene ) , NAG_PlotStatus , NAttValue( GB^.Scene^.NA , NAG_Narrative , NAS_PlotID ) , 1 );
		end;
	end;

	PlotMaster := Plot;
end;

Function StoryMaster( GB: GameBoardPtr; Source: GearPtr ): GearPtr;
	{ Given a source gear, find the STORY that it is based off of, }
	{ returning NIL if no such story exists. }
var
	Scene: GearPtr;
begin
	{ Note that the master plot may have a G of GG_AbsolutelyNothing, }
	{ if a previous command in the script has set this plot to be }
	{ advanced. }
	Scene := Source;
	while ( Scene <> Nil ) and (Scene^.G <> GG_Story ) and ( Scene^.G <> GG_AbsolutelyNothing ) do Scene := Scene^.Parent;
	if ( Scene = Nil ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Scene := GB^.Scene;
		while ( Scene <> Nil ) and (Scene^.G <> GG_Story ) and ( Scene^.G <> GG_AbsolutelyNothing ) do Scene := Scene^.Parent;
	end;
	{ It's possible that if we found an AbsolutelyNothing gear, it's really a plot that }
	{ has just been marked for deletion and is not the story we want. Check for that }
	{ possibility here. }
	if ( Scene <> Nil ) and ( Scene^.G = GG_AbsolutelyNothing ) and ( Scene^.Parent <> Nil ) and ( Scene^.Parent^.G = GG_Story ) then Scene := Scene^.Parent;
	if ( Scene = Nil ) and ( Source^.G = GG_MetaTerrain ) and ( Source^.Stat[ STAT_Destination ] < 0 ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Scene := FindMetasceneStory( FindRoot( GB^.Scene ) , Source^.Stat[ STAT_Destination ] );
		if Scene = Nil then begin
			Scene := FindMetascenePlot( FindRoot( GB^.Scene ) , Source^.Stat[ STAT_Destination ] );
			while ( Scene <> Nil ) and (Scene^.G <> GG_Story ) and ( Scene^.G <> GG_AbsolutelyNothing ) do Scene := Scene^.Parent;
		end;
	end;
	if ( Scene = Nil ) and ( NAttValue( Source^.NA , NAG_Narrative , NAS_NID ) <> 0 ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Scene := FindItemStory( FindRoot( GB^.Scene ) , NAttValue( Source^.NA , NAG_Narrative , NAS_NID ) );
		if Scene = Nil then begin
			Scene := FindItemPlot( FindRoot( GB^.Scene ) , NAttValue( Source^.NA , NAG_Narrative , NAS_NID ) );
			while ( Scene <> Nil ) and (Scene^.G <> GG_Story ) and ( Scene^.G <> GG_AbsolutelyNothing ) do Scene := Scene^.Parent;
		end;
	end;
	StoryMaster := Scene;
end;

Function GG_FindSubScene( Scene: GearPtr; N: Integer ): GearPtr;
	{ Return the N'th subscene of the provided scene. }
begin
	Scene := Scene^.SubCom;
	while ( Scene <> Nil ) and ( N > 0 ) do begin
		if Scene^.G = GG_Scene then Dec( N );
		if N > 0 then Scene := Scene^.next;
	end;
	GG_FindSubScene := Scene;
end;

Function Attempt_Gear_Grab( const Cmd : String; var Event: String; GB: GameBoardPtr; Source: GearPtr ): Boolean;
	{ See whether or not CMD refers to a valid Gear-Grabbing command. }
	{ CMD is assumed to be already uppercase. }
	{ If CMD is not a gear-grabbing command, no changes are made. }
	{ Return TRUE if a gear was grabbed, FALSE otherwise. }
var
	it: Boolean;
	X: LongInt;
	name: String;
begin
	{ Assume this is a gear-grabbing command, for now. }
	it := True;

	if CMD = 'GRABSOURCE' then begin
		Grabbed_Gear := Source;

	end else if CMD = 'GRABADVENTURE' then begin
		Grabbed_Gear := GG_LocateAdventure( GB , Source );

	end else if CMD = 'GRABDYNAMIC' then begin
		{ Grab the dynamic scene currently under construction. }
		Grabbed_Gear := SCRIPT_DynamicEncounter;

	end else if ( CMD = 'GRABCURRENTSCENE' ) and ( GB <> Nil ) then begin
		Grabbed_Gear := GB^.Scene;

	end else if CMD = 'GRABFACTION' then begin
		X := ScriptValue( Event , GB , Source );
		Grabbed_Gear := GG_LocateFaction( X , GB , Source );

	end else if ( CMD = 'GRABSCENE' ) and ( GB <> Nil ) then begin
		X := ScriptValue( Event , GB , Source );
		Grabbed_Gear := FindActualScene( GB , X );

	end else if CMD = 'GRABNPC' then begin
		X := ScriptValue( Event , GB , Source );
		Grabbed_Gear := GG_LocateNPC( X , GB , Source );

	end else if CMD = 'GRABLOCAL' then begin
		X := ScriptValue( Event , GB , Source );
		Grabbed_Gear :=  LocateMekByUID( gb , X );

	end else if CMD = 'GRABTEAM' then begin
		X := ScriptValue( Event , GB , Source );
		Grabbed_Gear :=  LocateTeam( gb , X );

	end else if CMD = 'GRABITEM' then begin
		X := ScriptValue( Event , GB , Source );
		Grabbed_Gear := GG_LocateItem( X , GB , Source );

	end else if CMD = 'GRABCONTROLLER' then begin
		X := ScriptValue( Event , GB , Source );
		Grabbed_Gear := GG_LocateController( X , GB , Source );

	end else if ( CMD = 'GRABCHATNPC' ) then begin
		Grabbed_Gear := I_NPC;

	end else if ( CMD = 'GRABPC' ) and ( GB <> Nil ) then begin
		Grabbed_Gear := GG_LocatePC( GB );

	end else if ( CMD = 'GRABPCPILOT' ) and ( GB <> Nil ) then begin
		Grabbed_Gear := LocatePilot( GG_LocatePC( GB ) );

	end else if ( CMD = 'GRABPLOT' ) and ( Source <> Nil ) then begin
		Grabbed_Gear := PlotMaster( GB , Source );

	end else if ( CMD = 'GRABSTORY' ) and ( Source <> Nil ) then begin
		Grabbed_Gear := StoryMaster( GB , Source );

	end else if ( CMD = 'GRABENTRANCE' ) and ( GB <> Nil ) and ( GB^.Camp <> Nil ) then begin
		X := ScriptValue( Event , GB , Source );
		Grabbed_Gear := FindSceneEntrance( GB^.Camp^.Source , GB , X );

	end else if ( CMD = 'GRABSUBSCENE' ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		X := ScriptValue( Event , GB , Source );
		Grabbed_Gear := GG_FindSubScene( GB^.Scene , X );

	end else if CMD = 'GRABROOT' then begin
		Grabbed_Gear := FindRoot( Grabbed_Gear );

	end else if CMD = 'GRABROOTSCENE' then begin
		Grabbed_Gear := FindRootScene( Grabbed_Gear );

	end else if CMD = 'GRABTEAMNAME' then begin
		name := ExtractWord( Event );
		Grabbed_Gear := SeekChildByName( GB^.SCENE , name );
		if Grabbed_Gear^.G <> GG_Team then Grabbed_Gear := Nil;

	end else if CMD = 'GRABDESIG' then begin
		name := ExtractWord( Event );
		Grabbed_Gear := GG_GrabDesig( GB , name );

	end else if ( CMD = 'GRABPARENT' ) and ( Grabbed_Gear <> Nil ) then begin
		Grabbed_Gear := Grabbed_Gear^.Parent;

	end else begin
		{ No command was found matching CMD... return False. }
		it := False;
	end;

	Attempt_Gear_Grab := it;
end;

end.
