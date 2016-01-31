unit ghprop;
	{ What do props do? Well, not much by themselves... But they }
	{ can be used to make buildings, safes, machinery, or whatever }
	{ else you can think to do with them. }

	{ Metaterrain acts basically like terrain- it can hinder movement or block line }
	{ of sight. As a gear, it can have scripts associated with it. }
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

uses texutil,gears,ui4gh;

	{ PROP DEFINITION }
	{ G => GG_Prop }
	{ S => Prop Behavior }
	{ V => Prop Size; translates to mass and damage. }

	{ METATERRAIN DEFINITION }
	{ G => GG_MetaTerrain }
	{ S => Specific Type, 0 = Generic }
	{ V => Terrain Size; translates to armor and damage. }
	{         if MetaTerrain V = 0, cannot be destroyed. }


const
	{ Please note that a metaterrain gear does not need to have }
	{ its "S" value within the 1..NumBasicMetaTerrain range, }
	{ but those which do lie within this range will be initialized }
	{ with the default scripts. }
	NumBasicMetaTerrain = 11;
	GS_MetaDoor = 1;
	GS_MetaCloud = 2;
	GS_MetaStairsUp = 3;
	GS_MetaStairsDown = 4;
	GS_MetaElevator = 5;
	GS_MetaTrapDoor = 6;
	GS_MetaRubble = 7;
	GS_MetaSign = 8;
	GS_MetaFire = 9;
	GS_MetaBuilding = 10;
	GS_MetaEncounter = 11;

	STAT_Altitude = 1;
	STAT_Obscurement = 2;
	STAT_Pass = 3;
	STAT_Destination = 4;
	STAT_MetaVisibility = 5;	{ If nonzero, this terrain can't be seen. }
	STAT_Lock = 6;
	STAT_CloudDuration = 7;		{ Used only by METACLOUD gears. }
	STAT_EncounterMove = 7;		{ Used only be ENCOUNTER gears; % chance it will move. }
	STAT_EncounterType = 8;		{ Determines the color of the encounter blip. }
		ENCOUNTER_Hostile = 0;
		ENCOUNTER_Defense = 1;
		ENCOUNTER_NonCombat = 2;

	{ Prop Stats }
	STAT_PropMesh = 5;		{ Does this prop use a custom mesh? }
	{ STAT_Lock is the same as above- used by treasure chests. }
		MESH_Bunker = 1;
		MESH_Pillbox = 2;
		MESH_VideoGame = 3;
		MESH_BigBox = 4;
		MESH_ShipBody = 5;
		MESH_ShipWedge = 6;
		MESH_ShipCurve = 7;
		MESH_ShipTower = 8;
		MESH_ShipEngine = 9;
		MESH_ShopShelf = 10;
		MESH_Crate = 11;
		MESH_EndTable = 12;
		MESH_Bed = 13;


	NAG_MTAppearance = 19;		{ Holds some appearance info for metaterrain }
		NAS_BuildingMesh = 1;	{ What mesh to use for building? }
			NAV_Default = 0;	{ Default building mesh. }
			NAV_Spaceport = 9;	{ Spaceport mesh }

	GS_BasicProp = 0;	{ Doesn't do anything. }
	GS_CombatProp = 1;	{ Will fire weapons at enemies, as appropriate. }

	{ *** MAP FEATURE DEFINITION *** }
	{ G = GG_MapFeature              }
	{ S = Feature Type               }
	{ V = Feature Value              }
	GS_Building = -1;

	STAT_XPos = 1;
	STAT_YPos = 2;
	STAT_MFWidth = 3;
	STAT_MFHeight = 4;
	STAT_MFFloor = 5;
	STAT_MFMarble = 6;
	STAT_MFBorder = 7;
	STAT_MFSpecial = 8;

	MapFeatureMaxWidth = 25;
	MapFeatureMaxHeight = 15;
	MapFeatureMinDimension = 5;


var
	{ This array holds the scripts. }
	Meta_Terrain_Scripts: Array [1..NumBasicMetaTerrain] of SAttPtr;


Procedure CheckPropRange( Part: GearPtr );

Procedure InitMetaTerrain( Part: GearPtr );
Procedure InitMapFeature( Part: GearPtr );

Function RandomBuildingName( B: GearPtr ): String;

implementation



Procedure CheckPropRange( Part: GearPtr );
	{ Examine the various bits of this gear to make sure everything }
	{ is all nice and legal. }
begin
	{ Check V - Size Category }
	if Part^.V < 1 then Part^.V := 1
	else if Part^.V > 100 then Part^.V := 100;


end;

Procedure InitMetaTerrain( Part: GearPtr );
	{ Initialize this metaterrain gear for a nice default example of }
	{ the terrain type it's supposed to represent. }
begin
	{ If this is a part for which we have a standard script, }
	{ install that script now. }
	if ( Part^.S >= 1 ) and ( Part^.S <= NumBasicMetaTerrain ) then begin
		SetSAtt( Part^.SA , 'ROGUECHAR <' + SAttValue( Meta_Terrain_Scripts[ Part^.S ] , 'roguechar' ) + '>' );
		SetSAtt( Part^.SA , 'NAME <' + SAttValue( Meta_Terrain_Scripts[ Part^.S ] , 'NAME' ) + '>' );
	end;

	{ Do part-specific initializations here. }
	if Part^.S = GS_MetaDoor then begin
		{ Begin with the stats for a closed door. }
		Part^.Stat[ STAT_Pass ] := -100;
		Part^.Stat[ STAT_Altitude ] := 6;
	end else if Part^.S = GS_MetaStairsUp then begin
		Part^.Stat[ STAT_Pass ] := -100;
		Part^.Stat[ STAT_Altitude ] := 1;
		Part^.Stat[ STAT_Obscurement ] := 1;
	end else if Part^.S = GS_MetaElevator then begin
		Part^.Stat[ STAT_Pass ] := -100;
		Part^.Stat[ STAT_Altitude ] := 6;
	end else if Part^.S = GS_MetaBuilding then begin
		Part^.Stat[ STAT_Pass ] := -100;
	end else if ( Part^.S = GS_MetaRubble ) or ( Part^.S = GS_MetaSign ) then begin
		Part^.Stat[ STAT_Pass ] := -100;
		Part^.Stat[ STAT_Altitude ] := 1;
		Part^.Stat[ STAT_Obscurement ] := 1;
	end;
end;

Procedure InitMapFeature( Part: GearPtr );
	{ This procedure does only one thing- if the part has a minimap defined, }
	{ make sure it's at least a 5x5 area. }
begin
	if ( part <> Nil ) and ( SAttValue( Part^.SA , 'MINIMAP' ) <> '' ) then begin
		if Part^.Stat[ STAT_MFWidth ] < 5 then Part^.Stat[ STAT_MFWidth ] := 5;
		if Part^.Stat[ STAT_MFHeight ] < 5 then Part^.Stat[ STAT_MFHeight ] := 5;
	end;
end;

Procedure LoadMetaScripts;
	{ Load the metascripts from disk. }
var
	T: Integer;
begin
	for t := 1 to NumBasicMetaTerrain do begin
		Meta_Terrain_Scripts[ t ] := LoadStringList( MetaTerrain_File_Base + BStr( T ) + Default_File_Ending );
	end;
end;

Procedure ClearMetaScripts;
	{ Free the metascripts from memory. }
var
	T: Integer;
begin
	for t := 1 to NumBasicMetaTerrain do begin
		DisposeSAtt( Meta_Terrain_Scripts[ t ] );
	end;
end;

Function RandomBuildingName( B: GearPtr ): String;
	{ Create a random name for the provided building. }
	{ Replace %b with the basic building name. }
	{ Replace %a with an adjective. }
	{ Replace %n with an ordinal number. }
const
	NumNameForms = 3;
	NumAdjectives = 5;
	NumOridinals = 5;
var
	it: String;
begin
	it := MSgString( 'GHPROP_RBN_FORM_' + BStr( Random( NumNameForms ) + 1 ) );
	if B = Nil then begin
		ReplacePat( it , '%b' , 'NoBuildingError' );
	end else begin
		ReplacePat( it , '%b' , SAttValue( B^.SA , 'NAME' ) );
	end;
	ReplacePat( it , '%a' , MSgString( 'GHPROP_RBN_Adjective_' + BStr( Random( NumAdjectives ) + 1 ) ) );
	ReplacePat( it , '%n' , MSgString( 'GHPROP_RBN_Ordinal_' + BStr( Random( NumOridinals ) + 1 ) ) );
	RandomBuildingName := it;
end;


initialization
	LoadMetaScripts;

finalization
	ClearMetaScripts;

end.
