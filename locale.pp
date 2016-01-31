unit locale;
	{ This unit handles maps & terrain. It doesn't handle }
	{ the screen output of said maps. }

	{ Also, it handles definitions for SCENE and TEAM gears. }
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

uses RPGDice,Gears,Gearutil,Movement,Ability;

Type
	TerrDesc = Record
		Pass: Integer;
		MMPass: Array [1..NumMoveMode ] of Boolean;
		Obscurement: Byte;
		Altitude: SmallInt;
		DMG: Byte;	{ How much damage required to destroy this terrain. 0 = Cannot be damaged further. }
		Destroyed: Integer;	{ When the terrain is destroyed, what terrain it becomes. }
		Flammable: Boolean;	{ Will it burn? }
	end;

Const
	All_Terrain_Designations = 'GROUND SPACE';	{ Also alter TERR_SPEC_FOUND in gearparser }
							{ if adding new terrain designations. }

	NAG_ParaLocation = -6;
	NAS_OriginalHome = 255;	{ The constant is high to avoid conflicts with LOCATION vars copied by PARALOCATION. }
		{ This variable holds the scene number from which the }
		{ gear in question was originally taken, and to which }
		{ it will be returned once the current scene is over. }


	NAG_Location = -1;	{ Numeric Attribute : Map Location }
	NAS_X = 0;
	NAS_Y = 1;
	NAS_D = 2;
	NAS_Team = 4;
		NAV_DefNeutralTeam = 0;
		NAV_DefPlayerTeam = 1;
		NAV_LancemateTeam = -3;
		NAV_DefEnemyTeam = 2;
	NAS_LastMenuItem = 5;	{Is the theme dead yet?}
	NAS_GX = 6;		{ Waypoint Destination X - the G means "Go". }
	NAS_GY = 7;		{ Waypoint Destination Y }
	NAS_SmartAction = 8;	{ Indicates a continuous action (pcaction.pp) }
	NAS_SmartWeapon = 9;	{ Weapon to be used by smartbump smartattack (pcaction.pp) }
	NAS_SmartCount = 10;	{ Counter for continuous actions }
	NAS_SmartX = 11;	{ X,Y coordinates for SmartAction, }
	NAS_SmartY = 12;	{  used as appropriate. }
	NAS_SmartTarget = 13;
	NAS_SmartSpeed = 14;	{ Use NormSpeed or FullSpeed for smartwalking? }
	NAS_SmartSkill = 15;	{ What skill to use for continued skill use. }

	NAV_SmartAttack = 10;
	NAV_UseSkill = 11;
	NAV_SmartGo = 12;
	NAV_SmartTalk = 13;

	NAG_Visibility = -5;	{ NAS is the team ID which spotted this gear }
	NAV_Spotted = 1;
	NAV_Hidden = 0;

	NAG_SideReaction = -24;
	NAV_AreEnemies = -1;
	NAV_AreNeutral = 0;
	NAV_AreAllies = 1;

	NAG_EntryDirections = -15;	{ When entering from a certain location, }
				{ this tells what direction you should be facing. }
	{ NAS = the scene being entered from. }
	{ NAV = the direction to face +1. }



	NAG_SceneData = 21;
	{ SceneData holds various miscellaneous values associated with scenes. }
	NAS_TacticsTurnStart = 1;
	NAS_Tileset = 2;
		NumTileSet = 4;
		NAV_DefaultTiles = 0;
		NAV_RockyTiles = 1;
		NAV_PalaceParkTiles = 2;
		NAV_IndustrialTiles = 3;
		NAV_OrganicTiles = 4;
	NAS_Backdrop = 3;	{ The image used in the background. Left as 0, it means no backdrop. }
		NumBackdrop = 1;
		NAV_Starfield = 1;

	NAS_DynaRenown = 4;	{ These two attributes record the enemy force renown/strength }
	NAS_DynaStrength = 5;	{ for a dynamic scene. }

	NAS_EncounterRecharge = 6;	{ Holds a time limit by which encounters can attack the PC. }
		Standard_Encounter_Recharge = 90;

	NAS_PartyControlMethod = 7;	{ What control method is currently being used- tactics or clock? }
		NAV_ClockMode = 1;	{ This gets set when a scene is entered and cleared when the scene }
		NAV_TacticsMode = 2;	{ is exited. }

	NAG_MissionReport = 23;		{ Holds data that will be erased the next time this mecha is deployed. }
		NAS_WasSalvaged = 1;	{ If nonzero, this gear was salvaged. }


	SA_MapEdgeObstacle = 'NOEXIT';

	RANGE_Minimum = 0;
	RANGE_Short = 1;
	RANGE_Medium = 2;
	RANGE_Long = 3;

	DefaultScale = 2; {The default map scale. 2 = Mecha Scale}

	NumTerr = 27;
	TerrMan: Array [1..NumTerr] of TerrDesc = (
	(	{Open Ground}
		Pass: 0;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 0;
		DMG: 20; Destroyed: 11;
		Flammable: True;
		),
	(	{ Light Forest}
		Pass: 50;
		MMPass: ( True , False , True , True , False );
		Obscurement: 2;
		Altitude: 0;
		DMG: 5; Destroyed: 11;
		Flammable: True;
		),
	(	{ Heavy Forest}
		Pass: 100;
		MMPass: ( True , False , True , True , False );
		Obscurement: 3;
		Altitude: 0;
		DMG: 10; Destroyed: 2;
		Flammable: True;
		),
	(	{Water L1}
		Pass: 300;
		MMPass: ( True , False , True , True , False );
		Obscurement: 2;
		Altitude: -1;
		DMG: 0; Destroyed: 0;
		Flammable: False;
		),
	(	{Rubble}
		Pass: 25;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 0;
		DMG: 0; Destroyed: 0;
		Flammable: False;
		),

	{ 6 - 10 }
	(	{Pavement}
		Pass: -5;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 0;
		DMG: 10; Destroyed: 11;
		Flammable: False;
		),
	(	{Swamp}
		Pass: 50;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 0;
		DMG: 0; Destroyed: 0;
		Flammable: False;
		),
	(	{Hill L1}
		Pass: 0;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 1;
		DMG: 32; Destroyed: 11;
		Flammable: False;
		),
	(	{Hill L2}
		Pass: 0;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 2;
		DMG: 35; Destroyed: 9;
		Flammable: False;
		),
	(	{Hill L3}
		Pass: 0;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 3;
		DMG: 39; Destroyed: 10;
		Flammable: False;
		),

	{ 11 - 15 }
	(	{Rough Ground}
		Pass: 50;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 0;
		DMG: 19; Destroyed: 5;
		Flammable: False;
		),
	(	{Low Wall}
		Pass: -100;
		MMPass: ( True , True , True , True , False );
		Obscurement: 1;
		Altitude: 1;
		DMG: 18; Destroyed: 22;
		Flammable: True;
		),
	(	{Wall}
		Pass: -100;
		MMPass: ( True , True , True , True , False );
		Obscurement: 1;
		Altitude: 6;
		DMG: 26; Destroyed: 22;
		Flammable: True;
		),
	(	{Floor}
		Pass: 0;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 0;
		DMG: 20; Destroyed: 11;
		Flammable: True;
		),
	(	{Threshold}
		Pass: 0;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 0;
		DMG: 15; Destroyed: 5;
		Flammable: True;
		),

	{ 16 - 20 }
	(	{Carpet}
		Pass: -3;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 0;
		DMG: 7; Destroyed: 1;
		Flammable: True;
		),
	(	{Deep Water}
		Pass: 300;
		MMPass: ( True , False , True , True , False );
		Obscurement: 2;
		Altitude: -2;
		DMG: 0; Destroyed: 0;
		Flammable: False;
		),
	(	{Very Deep Water}
		Pass: 300;
		MMPass: ( True , False , True , True , False );
		Obscurement: 2;
		Altitude: -3;
		DMG: 0; Destroyed: 0;
		Flammable: False;
		),
	(	{Wooden Floor}
		Pass: -5;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 0;
		DMG: 7; Destroyed: 11;
		Flammable: True;
		),
	(	{Wooden Wall}
		Pass: -100;
		MMPass: ( True , True , True , True , False );
		Obscurement: 1;
		Altitude: 6;
		DMG: 20; Destroyed: 11;
		Flammable: True;
		),

	{ 21 - 25 }
	(	{Tile Floor}
		Pass: -5;
		MMPass: ( True , True , True , True , False );
		Obscurement: 0;
		Altitude: 0;
		DMG: 9; Destroyed: 11;
		Flammable: False;
		),
	(	{Wreckage}
		Pass: 100;
		MMPass: ( True , False , True , True , False );
		Obscurement: 3;
		Altitude: 0;
		DMG: 14; Destroyed: 5;
		Flammable: True;
		),
	(	{Empty Space}
		Pass: 0;
		MMPass: ( False , False , FaLse , False , True );
		Obscurement: 0;
		Altitude: 0;
		DMG: 0; Destroyed: 0;
		Flammable: False;
		),
	(	{Low Building}
		Pass: -100;
		MMPass: ( True , True , True , True , False );
		Obscurement: 1;
		Altitude: 2;
		DMG: 12; Destroyed: 22;
		Flammable: True;
		),
	(	{Medium Building}
		Pass: -100;
		MMPass: ( True , True , True , True , False );
		Obscurement: 1;
		Altitude: 3;
		DMG: 16; Destroyed: 22;
		Flammable: True;
		),

	{ 26 - 30 }
	(	{Glass Wall}
		Pass: -100;
		MMPass: ( True , True , True , True , False );
		Obscurement: 1;
		Altitude: 6;
		DMG: 7; Destroyed: 22;
		Flammable: False;
		),
	(	{Very Low Building}
		Pass: -100;
		MMPass: ( True , True , True , True , False );
		Obscurement: 1;
		Altitude: 1;
		DMG: 10; Destroyed: 22;
		Flammable: True;
		)

	{ 31 - 35 }

	{ 36 - 40 }

	{ 41 - 45 }

	{ 46 - 50 }

	);


	{ This array holds the movement vectors for the 8 possible }
	{ directions of travel. Dir 0 is at three o'clock, for no }
	{ better reason than it's the same convention I've used in }
	{ other games. }
	AngDir: Array [0..7 , 1..2] of SmallInt = (
		(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1),(0,-1),(1,-1)
	);

	LOCALE_CollectTriggers: Boolean = True;

	TERRAIN_OpenGround = 1;
	TERRAIN_LightFOrest = 2;
	TERRAIN_HeavyForest = 3;
	TERRAIN_L1_Water = 4;
	TERRAIN_Rubble = 5;

	TERRAIN_Pavement = 6;
	TERRAIN_Swamp = 7;
	TERRAIN_L1_Hill = 8;
	TERRAIN_L2_Hill = 9;
	TERRAIN_L3_Hill = 10;

	TERRAIN_RoughGround = 11;
	TERRAIN_LowWall = 12;
	TERRAIN_Wall = 13;
	TERRAIN_Floor = 14;
	TERRAIN_Threshold = 15;

	TERRAIN_Carpet = 16;
	TERRAIN_L2_Water = 17;
	TERRAIN_L3_Water = 18;
	TERRAIN_WoodenFloor = 19;
	TERRAIN_WoodenWall = 20;

	TERRAIN_TileFloor = 21;
	TERRAIN_Wreckage = 22;
	TERRAIN_Space = 23;
	TERRAIN_MediumBuilding = 24;
	TERRAIN_HighBuilding = 25;

	TERRAIN_GlassWall = 26;
	TERRAIN_LowBuilding = 27;

	{ ******************************** }
	{ ***  SCENE & TEAM CONSTANTS  *** }
	{ ******************************** }

	{ ADVENTURE DEFINITION }
	{   G = GG_Adventure   }
	{   S = Exit Lock      }
	{   V = Undefined      }
	GS_RPGCampaign = 0;
	GS_ArenaCampaign = 1;

	{ SCENE DEFINITION }
	{   G = GG_Scene   }
	{   S = Scene ID   }
	{   V = Map Scale  }
	{ STAT[ 1 ] = Map Generation Type }

	STAT_MapGenerator = 1;
	STAT_MapWidth = 2;
	STAT_MapHeight = 3;
	STAT_SpaceMap = 4;	{ If SpaceMap is nonzero, map will scroll. }

	{ WORLD DEFINITION }
	{   G = GG_World   }
	{   S = Scene ID   }
	{   V = Map Scale, not exactly the same as normal scene scale  }
	{   Stats are the same as a scene, so that the map generator can be used. }
	STAT_Wrap = 4;		{ Does the map wrap? }
				{ ..0001 = Wrap X }
				{ ..0010 = Wrap Y }


	{ TEAM DEFINITION  }
	{   G = GG_Team    }
	{   S = Team ID    }
	{   V = UNDEFINED  }
	{ STAT[ 1 ] = Default Team Orders }
	{ STAT[ 2 ] = Wandering Monster Value }

	STAT_TeamOrders = 1;
	STAT_WanderMon = 2;

	{ *** SUPERPROP DEFINITION *** }
	{ Stats 3 and 4 are width and height as with map features. }
	STAT_TeamA = 5;
	STAT_TeamB = 6;
	STAT_TeamC = 7;
	STAT_TeamD = 8;

	{ TIME CONSTANTS }
	AP_Minute = 60;
	AP_3Minutes = 180;
	AP_5Minutes = 300;
	AP_10Minutes = 600;
	AP_HalfHour = 1800;
	AP_Hour = 3600;
	AP_Quarter = 21600;
	AP_Day = 86400;

	TRIGGER_FiveMinutes = '5MIN';
	TRIGGER_Hour = 'HOUR';
	TRIGGER_HalfHour = 'HALFHOUR';
	TRIGGER_Quarter = 'QUARTER';

	{ This constant is used by stairs and other portals. If a value }
	{ is addigned to it, the player character should appear on that }
	{ terrain after leaving the current level. }
	SCRIPT_Terrain_To_Seek: Integer = 0;
	SCRIPT_Gate_To_Seek: Integer = 0;

	PC_Team_X: Integer = 0;
	PC_Team_Y: Integer = 0;

	MaxMapWidth = 100;

	SPECIAL_StartHere = 'STARTHERE';


	Screen_Needs_Redraw: Boolean = True;


type
	Point = Record
		x,y,z: Integer;
	end;

	Tile = Record
		Terr: Integer;
		Visible: Boolean;
	end;

	Location = Array of Tile;

	CampaignPtr = ^Campaign;

	gameboard = Record
		ComTime: LongInt;	{ Current game time. }
		Scale: SmallInt;	{ The scale of the map. }
		QuitTheGame: Boolean;	{ Whether or not a QUIT msg was caught. }
		ReturnCode: Integer;	{ Value to return when the game is over. }
		map: Location;
		map_width,map_height: Byte;	{ Width and height of the map. }
		Scene: GearPtr; { A gear describing the scenario. }
		Trig: SAttPtr; { A list of triggers which have occured - should be routinely checked by the main combat procedure. }
			{ See the scripting unit for this implementation for more information, or set LOCALE_CollectTriggers to FALSE to disable scripts. }
		meks: GearPtr; {A list of all associated mecha.}
		camp: CampaignPtr;	{ A backwards-pointer to the campaign in which this gameboard is set. }
					{ This pointer is initialized to NIL, then set to the proper }
					{ value by the ScenePlayer procedure in ArenaPlay. }
	end;
	gameboardptr = ^gameboard;

	FrozenLocation = Record
		Name: String;
		map: Location;
		map_width,map_height: Byte;	{ Width and height of the map. }
		Next: Pointer;
	end;
	FrozenLocationPtr = ^FrozenLocation;

	{ This record holds the data needed for an entire campaign. }
	Campaign = Record
		ComTime: LongInt;
		GB: GameBoardPtr;
		Maps: FrozenLocationPtr;
		Source: GearPtr;
	end;


Function TileTerrain( GB: GameBoardPtr; X,Y: Integer ): Integer;
Function TileVisible( GB: GameBoardPtr; X,Y: Integer ): Boolean;
Procedure SetTerrain( GB: GameBoardPtr; X,Y,T: Integer );
Procedure SetVisibility( GB: GameBoardPtr; X,Y: Integer; V: Boolean );

Function CreateFrozenLocation(var LList: FrozenLocationPtr): FrozenLocationPtr;

Function SolveLine(X1,Y1,X2,Y2,N: Integer): Point;
Function SolveLine(X1,Y1,Z1,X2,Y2,Z2,N: Integer): Point;

function NewMap( XMax,YMax: Byte ): GameBoardPtr;
function NewCampaign: CampaignPtr;
procedure DisposeMap(var gb: GameBoardPtr);
procedure DisposeCampaign(var Camp: CampaignPtr);

function GearCurrentLocation( Mek: GearPtr ): Point;

Function LocateTeam( Scene: GearPtr; Team: Integer ): GearPtr;
Function LocateTeam( GB: GameBoardPtr; Team: Integer ): GearPtr;
Function AreEnemies( Scene: GearPtr; T1,T2: Integer ): Boolean;
Function AreEnemies( GB: GameBoardPtr; T1,T2: Integer ): Boolean;
Function AreEnemies( GB: GameBoardPtr; M1 , M2: GearPtr ): Boolean;
Function AreAllies( Scene: GearPtr; T1,T2: Integer ): Boolean;
Function AreAllies( GB: GameBoardPtr; T1,T2: Integer ): Boolean;
Function AreAllies( GB: GameBoardPtr; M1 , M2: GearPtr ): Boolean;

Procedure DeleteObsoleteTeams( GB: GameBoardPtr );
Function IsSafeArea( GB: GameBoardPtr ): Boolean;

Function TeamSkill( GB: GameBoardPtr; Team,Skill,Stat: Integer): Integer;
Function TeamHasSkill( GB: GameBoardPtr; Team,Skill: Integer): Boolean;
Function TeamHasTalent( GB: GameBoardPtr; Team,Talent: Integer): Boolean;

Function TeamCanSeeTarget( GB: GameBoardPtr; Team: Integer; Target: GearPtr ): Boolean;
Function MekCanSeeTarget( GB: GameBoardPtr; Mek , Target: GearPtr ): Boolean;

Function OnTheMap( GB: GameBoardPtr; X,Y: Integer ): Boolean;
Function OnTheMap( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
function MekVisible( gb: GameBoardPtr; Mek: GearPtr ): Boolean;
function MekAltitude( gb: GameBoardPtr; Mek: GearPtr ): Integer;

Function NumGearsXY( GB: GameBoardPtr; X,Y: Integer ): Integer;
Function FindGearXY( GB: GameBoardPtr; X,Y,N: Integer): GearPtr;
Function NumVisibleGears( GB: GameBoardPtr; X,Y: Integer ): Integer;
Function FindVisibleGear( GB: GameBoardPtr; X,Y,N: Integer): GearPtr;
Function FindBlockerXYZ( GB: GameBoardPtr; X,Y,Z: Integer ): GearPtr;

Function NumVisibleItemsAtSpot( GB: GameBoardPtr; X,Y: Integer ): Integer;
Function GetVisibleItemAtSpot( GB: GameBoardPtr; X,Y,N: Integer ): GearPtr;
Function FindVisibleItemAtSpot( GB: GameBoardPtr; X,Y: Integer ): GearPtr;

Function NumVisibleUsableGearsXY( GB: GameBoardPtr; X,Y: Integer; const Trigger: String ): Integer;
Function FindVisibleUsableGearXY( GB: GameBoardPtr; X,Y,N: Integer; const Trigger: String): GearPtr;
Function FindVisibleBlockerAtSpot( GB: GameBoardPtr; X,Y: Integer ): GearPtr;

Procedure UpdateShadowMap( GB: GameBoardPtr );
Function TileBlocksLOS( GB: GameBoardPtr; X,Y,Z: Integer ): Boolean;
Function CalcObscurement(X1,Y1,Z1,X2,Y2,Z2: Integer; gb: GameBoardPtr): Integer;
Function CalcObscurement(X1,Y1,X2,Y2: Integer; gb: GameBoardPtr): Integer;
Function CalcObscurement( M1: GearPtr; X2,Y2: Integer; gb: GameBoardPtr ): Integer;
Function CalcObscurement( M1 , M2: GearPtr; gb: GameBoardPtr ): Integer;

Function CheckArc( OX , OY , TX , TY , A: Integer ): Boolean;
Function CheckArc( M1: GearPtr; X2,Y2,A: Integer ): Boolean;
Function CheckArc( M1,M2: GearPtr; A: Integer ): Boolean;

Function Range( X1 , Y1 , X2 , Y2: Integer ): Integer;
Function Range( M1: GearPtr; X2,Y2: Integer ): Integer;
Function Range( gb: GameBoardPtr; M1 , M2: GearPtr ): Integer;

function WeaponRange( GB: GameBoardPtr; Weapon: GearPtr; Band: Integer ): Integer;
function ThrowingRange( GB: GameBoardPtr; User,Weapon: GearPtr ): Integer;

Function GearDestination( Mek: GearPtr ): Point;

Function IsBlockingTerrainForMM( GB: GameBoardPtr; Mek: GearPtr; Terrain,MM: Integer ): Boolean;
Function IsBlockingTerrain( GB: GameBoardPtr; Mek: GearPtr; Terrain: Integer ): Boolean;

Function MovementBlocked( Mek: GearPtr; GB: GameBoardPtr; OX,OY,DX,DY: Integer ): Boolean;
Function FrontBlocked( Mek: GearPtr; GB: GameBoardPtr; D: Integer ): Boolean;
Function MoveBlocked( Mek: GearPtr; GB: GameBoardPtr ): Boolean;
Function CalcMoveTime( Mek: GearPtr; GB: GameBoardPtr ): Integer;
Function CalcRelativeSpeed( Mek: GearPtr; GB: GameBoardPtr ): Integer;

Function IsInCover( GB: GameBoardPtr; Master: GearPtr ): Boolean;

Function NumActiveMasters( GB: GameBoardPtr; Team: Integer ): Integer;
Function NumOperationalMasters( GB: GameBoardPtr; Team: Integer ): Integer;

Procedure SetTrigger( GB: GameBoardPtr; const msg: String );
Function SeekTarget( GB: GameBoardPtr; Mek: GearPtr ): GearPtr;

Procedure FreezeLocation( const Name: String; GB: GameBoardPtr; var FList: FrozenLocationPtr );
Function UnfreezeLocation( const Name: String; var FList: FrozenLocationPtr ): GameBoardPtr;
Procedure DeleteFrozenLocation( const Name: String; var FList: FrozenLocationPtr );

function FindThisTerrain( GB: GameBoardPtr; TTS: Integer ): Point;
Function NewTeamID( Scene: GearPtr ): LongInt;
Procedure SetTeamReputation( GB: GameBoardPtr; T,R,V: Integer );
Procedure DeclarationOfHostilities( GB: GameBoardPtr; ATeam,DTeam: Integer );

Function BoardMecha( Mek,Pilot: GearPtr ): Boolean;
Function ExtractPilot( Mek: GearPtr ): GearPtr;
Function FindPilotsMecha( LList,PC: GearPtr ): GearPtr;
Procedure AssociatePilotMek( LList , Pilot , Mek: GearPtr );

Function FindGearScene( Part: GearPtr; GB: GameBoardPtr ): Integer;

Procedure WriteMap(Map: Location; var F: Text );
Function ReadMap(var F: Text; W,H: Integer ): Location;

Procedure GearDownToLowestMM( Mek: GearPtr; GB: GameBoardPtr; X,Y: Integer );

Function FindDeploymentSpot( GB: GameBoardPtr; Mek: GearPtr ): Point;

Procedure RevealMek( GB: GameBoardPtr; Mek,Spotter: GearPtr );
Procedure CheckVisibleArea( GB: GameBoardPtr; Mek: GearPtr );

Function LocateMekByUID( GB: GameBoardPtr; UID: Integer ): GearPtr;
Procedure DeployGear( GB: GameBoardPtr; Mek: GearPtr; PutOnMap: Boolean );

Function WorldWrapsX( World: GearPtr ): Boolean;
Function WorldWrapsY( World: GearPtr ): Boolean;
Procedure FixWorldCoords( Scene: GearPtr; var X,Y: Integer );

Function ArcCheck( X0,Y0,D0,X1,Y1,A: Integer ): Boolean;
Function IsHidden( Mek: GearPtr ): Boolean;


implementation

{ Include specific GH*.pp units here. }
uses ghweapon,ghprop,ghchars,texutil,ghmovers;

Type
	LPattern = Record	{ Location Pattern }
		X,Y,Z: Integer;		{ Tile to search }
		{ Set Z outside normal range -5...+5 to exclude it as a search parameter }
		Trigger: String;	{ USed when searching for triggerable props. }
		Only_Visibles: Boolean;	{ Only search for visible gears? }
		Only_Masters: Integer;	{ Only search for master gears? }
	end;

Const
	LP_MustBeBlocker = 2;
	LP_MustBeMaster = 1;
	LP_MustNotBeMaster = -1;
	LP_MustBeUsable = -2;

	LowShadow = -3;
	HiShadow = 5;


var
	Shadow_Map: Array [1..MaxMapWidth,1..MaxMapWidth,LowShadow..HiShadow] of SmallInt;
	Shadow_Map_Update: LongInt;	{ ComTime when map last updated. }

Function TileIndex( GB: GameBoardPtr; X,Y: Integer ): LongInt;
	{ Given tile X,Y on GB, tell what array index position the tile will be at. }
begin
	TileIndex := X + ( Y - 1 ) * GB^.Map_Width - 1;
end;

Function TileTerrain( GB: GameBoardPtr; X,Y: Integer ): Integer;
	{ Return the terrain type of the requested tile. }
var
	T: Integer;
begin
	if ( X >= 1 ) and ( X <= GB^.Map_Width ) and ( Y >= 1 ) and ( Y <= GB^.Map_Height ) then begin
		T := GB^.Map[ TileIndex( GB , X , Y ) ].terr;
		if ( T < 1 ) or ( T > NumTerr) then T := 1;
		TileTerrain := T;
	end else begin
		TileTerrain := 0;
	end;
end;

Function TileVisible( GB: GameBoardPtr; X,Y: Integer ): Boolean;
	{ Return the visibility flag of the requested tile. }
begin
	if ( X >= 1 ) and ( X <= GB^.Map_Width ) and ( Y >= 1 ) and ( Y <= GB^.Map_Height ) then begin
		TileVisible := GB^.Map[ TileIndex( GB , X , Y ) ].visible;
	end else begin
		TileVisible := False;
	end;
end;

Procedure SetTerrain( GB: GameBoardPtr; X,Y,T: Integer );
	{ Set the terrain for the requested map tile, if it lies within the bounds of the map. }
begin
	if ( X >= 1 ) and ( X <= GB^.Map_Width ) and ( Y >= 1 ) and ( Y <= GB^.Map_Height ) then begin
		GB^.Map[ TileIndex( GB , X , Y ) ].terr := T;
	end;
end;

Procedure SetVisibility( GB: GameBoardPtr; X,Y: Integer; V: Boolean );
	{ Set the visibility for the requested map tile, if it lies within the bounds of the map. }
begin
	if ( X >= 1 ) and ( X <= GB^.Map_Width ) and ( Y >= 1 ) and ( Y <= GB^.Map_Height ) then begin
		GB^.Map[ TileIndex( GB , X , Y ) ].Visible := V;
	end;
end;


Function CreateFrozenLocation(var LList: FrozenLocationPtr): FrozenLocationPtr;
	{Add a new element to the head of LList.}
var
	it: FrozenLocationPtr;
begin
	{Allocate memory for our new element.}
	New(it);
	if it = Nil then exit;

	{Attach IT to the list.}
	it^.Next := LList;
	LList := it;

	{Return a pointer to the new element.}
	CreateFrozenLocation := it;
end;

Procedure DisposeFrozenLocation(var LList: FrozenLocationPtr);
	{Dispose of the list, freeing all associated system resources.}
var
	LTemp: FrozenLocationPtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;
		Dispose(LList);
		LList := LTemp;
	end;
end;

Procedure RemoveFrozenLocation(var LList,LMember: FrozenLocationPtr);
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: FrozenLocationPtr;
begin
	{Initialize A and B}
	B := LList;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		writeln('ERROR- RemoveFrozenLocation asked to remove a link that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		LList := B^.Next;
		Dispose(B);
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		Dispose(B);
	end;
end;

Function FindFrozenLocation( const Name_In: String; FList: FrozenLocationPtr ): FrozenLocationPtr;
	{ Locate a frozen location by looking for its name. }
	{ If the specified location cannot be found, return Nil. }
var
	Name: String;
begin
	{ Make sure name is upper-case. }
	Name := UpCase( Name_In );

	while ( FList <> Nil ) and ( UpCase( FList^.Name ) <> Name ) do FList := FList^.Next;

	FindFrozenLocation := FList;
end;

Function SolveLine(X1,Y1,X2,Y2,N: Integer): Point;
	{Find the N'th point along a line starting at X1,Y1 and ending}
	{at X2,Y2. Return its location.}
var
	tmp: point;
	VX1,VY1,VX,VY: Integer;
	Rise,Run: Integer; {Rise and Run}
begin
	{ERROR CHECK- Solve the trivial case.}
	if (X1=X2) and (Y1=Y2) then begin
		tmp.x := X1;
		tmp.y := Y1;
		Exit(tmp);
	end;

	{For line determinations, we'll use a virtual grid where each game}
	{tile is a square 10 units across. Calculations are done from the}
	{center of each square.}
	VX1 := X1*10 + 5;
	VY1 := Y1*10 + 5;

	{Do the slope calculations.}
	Rise := Y2 - Y1;
	Run := X2 - X1;

	if Abs(X2 - X1)> Abs(Y2 - Y1) then begin
		{The X direction is longer than the Y axis.}
		{Therefore, we can infer X pretty easily, then}
		{solve the equation for Y.}
		{Determine our X value.}
		if Run > 0 then VX := (n*10) + VX1
		else VX := VX1 - n*10;

		VY := n*10*Rise div Abs(Run) + VY1;

		end
	else begin
		{The Y axis is longer.}
		if Rise > 0 then VY := (n*10) + VY1
		else VY := VY1 - n*10;

		VX := (n*10*Run div Abs(Rise)) + VX1;

	end;

	{Error check- DIV doesn't deal with negative numbers as I would}
	{want it to. I'd always like a positive remainder- so, let's modify}
	{the values.}
	if VX<0 then VX := VX - 10;
	if VY<0 then VY := VY - 10;

	tmp.x := VX div 10;
	tmp.y := VY div 10;
	SolveLine := tmp;
end;

Function SolveLine(X1,Y1,Z1,X2,Y2,Z2,N: Integer): Point;
	{ Solve the three-dimensional line. }
var
	PA,PB: Point;
	W: Integer;
begin
	if Abs(X2 - X1) > Abs(Y2 - Y1) then
		W := Abs(X2-X1)
	else
		W := Abs(Y2-Y1);

	PA := SolveLine( X1 , Y1 , X2 , Y2 , N );
	PB := SolveLine( 0 , Z1 , W , Z2 , N );
	PA.Z := PB.Y;
	SolveLine := PA;
end;

function NewMap( XMax,YMax: Byte ): GameBoardPtr;
	{Allocate and initialize a new GameBoard structure.}
var
	it: GameBoardPtr;
	X: Integer;
begin
	{Allocate the needed memory space.}
	New(it);

	if it <> Nil then begin
		it^.Scale := DefaultScale;
		it^.meks := Nil;
		it^.Scene := Nil;
		it^.Trig := Nil;
		it^.ComTime := 0;
		it^.QuitTheGame := False;
		it^.ReturnCode := 0;
		it^.Camp := Nil;
		it^.MAP_Width := XMax;
		it^.MAP_Height := YMax;

		SetLength( it^.map , XMax * YMax );
		for X := 0 to ( Length( it^.Map ) - 1 ) do begin
			it^.map[X].terr := 1;
			it^.map[X].visible := False;
		end;
	end;
	NewMap := it;
end;

function NewCampaign: CampaignPtr;
	{Allocate and initialize a new Campaign structure.}
var
	it: CampaignPtr;
begin
	{Allocate the needed memory space.}
	New(it);

	if it <> Nil then begin
		it^.ComTime := 0;
		it^.GB := Nil;
		it^.maps := Nil;
		it^.Source := Nil;
	end;
	NewCampaign := it;
end;

procedure DisposeMap(var gb: GameBoardPtr);
	{Get rid of the GameBoard.}
	{ NOTE: Any gears, triggers, or scenes still attached will be }
	{ lost as well!!! }
begin
	{ Error check }
	if GB = Nil then Exit;

	DisposeGear( gb^.Meks );
	DisposeGear( gb^.Scene );
	DisposeSAtt( gb^.Trig );
	Dispose(gb);
	GB := Nil;
end;

procedure DisposeCampaign(var Camp: CampaignPtr);
	{Get rid of the campaign.}
begin
	DisposeGear( Camp^.Source );
	DisposeMap( Camp^.GB );
	DisposeFrozenLocation( Camp^.Maps );
	Dispose(Camp);
	Camp := Nil;
end;


function GearCurrentLocation( Mek: GearPtr ): Point;
	{ Locate the coordinates of MEK. }
	{ BUGS: If Mek is Nil or undefined, this function will cause }
	{  a runtime error. }
var
	P: Point;
begin
	{ Make sure first that we're dealing with a root-level gear. }
	Mek := FindRoot( Mek );

	{ Locate its X and Y coordinates. }
	P.X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
	P.Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );

	GearCurrentLocation := P;
end;

Function LocateTeam( Scene: GearPtr; Team: Integer ): GearPtr;
	{ Given a SCENE gear, locate the requested team. }
var
	TG,SE: GearPtr;
begin
	TG := Nil;
	if Scene <> Nil then begin
		SE := Scene^.SubCom;
		while SE <> Nil do begin
			if (SE^.G = GG_Team) and (SE^.S = TEAM) then TG := SE;
			SE := SE^.Next;
		end;
	end;
	LocateTeam := TG;
end;

Function LocateTeam( GB: GameBoardPtr; Team: Integer ): GearPtr;
	{ Search through the SCENE gear attached to the game board, }
	{ trying to find the team gear corresponding to the provided }
	{ TEAM number. If no such team is found, or if no scene is }
	{ defined, return NIL. }
var
	TG: GearPtr;		{ Scene Element, Team Gear }
begin
	TG := Nil;
	if GB^.Scene <> Nil then begin
		TG := LocateTeam( GB^.Scene , Team );
	end;
	LocateTeam := TG;
end;

Function AreEnemies( Scene: GearPtr; T1,T2: Integer ): Boolean;
	{ Locate the TEAM descriptions for the two teams indicated, }
	{ then return TRUE if they are enemies, FALSE if they are not. }
	{ If no TEAM gears have been defined, even teams are enemies }
	{ with odd teams, except team 0 which is perfectly neutral. }
	{ Note that this check is performed from the perspective of }
	{ team one. }
var
	TG1: GearPtr;
	SR: Integer;
	it: Boolean;
begin
	{ First, substitute out the Lancemate team for the PC team. }
	if T1 = NAV_LancemateTeam then T1 := NAV_DefPlayerTeam;
	if T2 = NAV_LancemateTeam then T2 := NAV_DefPlayerTeam;

	TG1 := LocateTeam( Scene , T1 );
	it := False;

	{ A team is never enemies with itself. }
	if T1 = T2 then begin
		it := False;

	end else if TG1 = Nil then begin
		{ If either of the teams can't be found, use default. }
		if ( T1 = 0 ) or ( T2 = 0 ) then begin
			it := False;
		end else if ( Abs( T1 ) mod 2 ) <> ( Abs( T2 ) mod 2 ) then begin
			it := True;
		end else begin
			it := False;
		end;
	end else begin
		SR := NAttValue( TG1^.NA , NAG_SideReaction , T2 );
		if SR = NAV_AreEnemies then it := True
		else it := False;
	end;

	AreEnemies := it;
end;

Function AreEnemies( GB: GameBoardPtr; T1,T2: Integer ): Boolean;
	{ Return TRUE if M1 and M2 are enemies, FALSE otherwise. }
begin
	AreEnemies := AreEnemies( GB^.Scene , T1 , T2 );
end;

Function AreEnemies( GB: GameBoardPtr; M1 , M2: GearPtr ): Boolean;
	{ Return TRUE if M1 and M2 are enemies, FALSE otherwise. }
var
	Team1,Team2: Integer;
begin
	Team1 := NAttValue( M1^.NA , NAG_Location , NAS_Team );
	Team2 := NAttValue( M2^.NA , NAG_Location , NAS_Team );
	AreEnemies := AreEnemies( GB , Team1 , Team2 );
end;

Function AreAllies( Scene: GearPtr; T1,T2: Integer ): Boolean;
	{ Locate the TEAM descriptions for the two teams indicated, }
	{ then return TRUE if they are alliess, FALSE if they are not. }
	{ If no TEAM gears have been defined, even teams are enemies }
	{ with odd teams, except team 0 which is perfectly neutral. }
	{ Note that this check is performed from the perspective of }
	{ team one. }
var
	TG1: GearPtr;
	SR: Integer;
	it: Boolean;
begin
	{ First, substitute out the Lancemate team for the PC team. }
	if T1 = NAV_LancemateTeam then T1 := NAV_DefPlayerTeam;
	if T2 = NAV_LancemateTeam then T2 := NAV_DefPlayerTeam;

	TG1 := LocateTeam( Scene , T1 );
	it := False;

	{ A team is always allied with itself. }
	if T1 = T2 then begin
		it := True;
	end else if ( T1 = 0 ) or ( T2 = 0 ) then begin
		it := False;
	end else if ( TG1 = Nil ) then begin
		{ If the team can't be found, use default. }
		if ( Abs( T1 ) mod 2 ) = ( Abs( T2 ) mod 2 ) then begin
			it := True;
		end else begin
			it := False;
		end;
	end else begin
		SR := NAttValue( TG1^.NA , NAG_SideReaction , T2 );
		if SR = NAV_AreAllies then it := True
		else it := False;
	end;

	AreAllies := it;
end;

Function AreAllies( GB: GameBoardPtr; T1,T2: Integer ): Boolean;
	{ Return TRUE if M1 and M2 are allies, FALSE otherwise. }
begin
	AreAllies := AreAllies( GB^.Scene , T1 , T2 );
end;

Function AreAllies( GB: GameBoardPtr; M1 , M2: GearPtr ): Boolean;
	{ Return TRUE if M1 and M2 are allies, FALSE otherwise. }
var
	Team1,Team2: Integer;
begin
	Team1 := NAttValue( M1^.NA , NAG_Location , NAS_Team );
	Team2 := NAttValue( M2^.NA , NAG_Location , NAS_Team );
	AreAllies := AreAllies( GB , Team1 , Team2 );
end;

Procedure ForgetTeam( Scene: GearPtr; Team: Integer );
	{ Clear all reactions to the team which is to be forgotten. }
var
	Part: GearPtr;
begin
	Part := Scene^.SubCOm;

	while Part <> Nil do begin
		if Part^.G = GG_Team then SetNAtt( Part^.NA , NAG_SideReaction , Team , 0 );
		Part := Part^.Next;
	end;
end;

Procedure DeleteObsoleteTeams( GB: GameBoardPtr );
	{ Check for teams which have no members and no name. Delete them. }
var
	Mek,Team: GearPtr;
begin
	if GB^.Scene <> Nil then begin
		Team := GB^.Scene^.SubCom;
		while Team <> Nil do begin
			Mek := Team^.Next;
			if Team^.G = GG_Team then begin
				if ( NumACtiveMasters( GB , Team^.S ) < 1 ) and ( Team^.S <> NAV_DefPlayerTeam ) and ( Team^.Stat[ STAT_WanderMon ] = 0 ) and ( GearName( Team ) = '' ) then begin
					{ This team has no active masters, }
					{ isn't the player team, and has no wandering monsters. }
					ForgetTeam( GB^.Scene , Team^.S );
					RemoveGear( GB^.Scene^.SubCom , Team );
				end;
			end;
			Team := Mek;
		end;
	end;
end;

Function IsSafeArea( GB: GameBoardPtr ): Boolean;
	{ Return TRUE if this map is a safe area for the PC, or }
	{ FALSE if it isn't. An area is safe it: }
	{ 1) No teams have WMon values set }
	{ 2) No master gears which are enemies of Team 1 are present. }
var
	it: Boolean;
	M: GearPtr;
	T: Integer;
begin
	{ Assume the area is safe, until we find a dangerous thing. }
	it := True;

	{ First, get rid of any obsolete teams. }
	DeleteObsoleteTeams( GB );

	{ Check teams for wandering monsters. }
	if GB^.SCene <> Nil then begin
		if AStringHasBString( SAttValue( GB^.Scene^.SA , 'SPECIAL' ) , 'UNSAFE' ) then it := False;

		M := GB^.Scene^.SubCom;
		while M <> Nil do begin
			if ( M^.G = GG_Team ) and ( M^.Stat[ STAT_WanderMon ] > 0 ) then it := False;
			M := M^.Next;
		end;
	end;

	{ Check map contents for hostile masters. }
	if it then begin
		M := GB^.Meks;
		while M <> Nil do begin
			if IsMasterGear( M ) and GearOperational( M ) and OnTheMap( GB , M ) then begin
				T := NAttValue( M^.NA , NAG_Location , NAS_TEam );
				if AreEnemies( GB , T , NAV_DefPlayerTeam ) then it := False;
			end;

			M := M^.Next;
		end;
	end;

	{ Return the result of our search. }
	IsSafeArea := it;
end;

Function TeamSkill( GB: GameBoardPtr; Team,Skill,Stat: Integer): Integer;
	{ Return the maximum skill value from the team. }
var
	M: GearPtr;
	MSkill,BigSkill,TSkill,T2: Integer;
begin
	{ Check through every mek on the board. }
	M := GB^.Meks;
	BigSkill := 0;
	TSkill := 0;
	while m <> Nil do begin
		{ Lancemates count as part of the PC team for skill purposes. }
		T2 := NAttValue( M^.NA , NAG_Location , NAS_Team );
		if T2 = NAV_LancemateTeam then T2 := NAV_DefPlayerTeam;
		if T2 = Team then begin
			if IsMasterGear( M ) then begin
				MSkill := SkillValue( M , Skill , Stat );
				if MSkill > BigSkill then BigSkill := MSkill;
				if MSkill >= 5 then TSkill := TSkill + ( MSkill div 5 );
			end;
		end;
		m := m^.Next;
	end;
	TeamSkill := BigSkill + TSkill - ( BigSkill div 5 );
end;

Function TeamHasSkill( GB: GameBoardPtr; Team,Skill: Integer): Boolean;
	{ Return TRUE if at least one member of the team has the requested skill. }
var
	M,P: GearPtr;
	Found: Boolean;
	T2: Integer;
begin
	{ Check through every mek on the board. }
	M := GB^.Meks;
	Found := False;
	while m <> Nil do begin
		{ Lancemates count as part of the PC team for skill purposes. }
		T2 := NAttValue( M^.NA , NAG_Location , NAS_Team );
		if T2 = NAV_LancemateTeam then T2 := NAV_DefPlayerTeam;
		if T2 = Team then begin
			if IsMasterGear( M ) and GearActive( M ) then begin
				if HasSkill( LocatePilot( M ) , Skill ) then Found := True;
			end;
		end;
		m := m^.Next;
	end;
	TeamHasSkill := Found;
end;

Function TeamHasTalent( GB: GameBoardPtr; Team,Talent: Integer): Boolean;
	{ Return TRUE if at least one member of the team has the requested skill. }
var
	M: GearPtr;
	Found: Boolean;
	T2: Integer;
begin
	{ Check through every mek on the board. }
	M := GB^.Meks;
	Found := False;
	while m <> Nil do begin
		{ Lancemates count as part of the PC team for skill purposes. }
		T2 := NAttValue( M^.NA , NAG_Location , NAS_Team );
		if T2 = NAV_LancemateTeam then T2 := NAV_DefPlayerTeam;
		if T2 = Team then begin
			if IsMasterGear( M ) and GearActive( M ) then begin
				if HasTalent( LocatePilot( M ) , Talent ) then Found := True;
			end;
		end;
		m := m^.Next;
	end;
	TeamHasTalent := Found;
end;

Function TeamCanSeeTarget( GB: GameBoardPtr; Team: Integer; Target: GearPtr ): Boolean;
	{ Check to see whether or not TARGET is visible to the listed }
	{ team. It is visible if it has a visibility marker from the }
	{ listed team, or if it has a visibility marker from any of TEAM's }
	{ allies. }
var
	it: Boolean;
	T2: Integer;
	Vis: NAttPtr;
	P: Point;
begin
	it := False;

	T2 := NAttValue( Target^.NA , NAG_Location , NAS_Team );
	if T2 = Team then begin
		It := True;
	end else if AreAllies( GB , Team , T2 ) and ( T2 <> NAV_DefPlayerTeam ) then begin
		It := True;
	end else if ( Team = NAV_DefPlayerTeam ) and ( Target^.G = GG_MetaTerrain ) and ( Target^.S = GS_MetaEncounter ) then begin
		it := NAttValue( Target^.NA , NAG_EpisodeData , NAS_EncounterVisibility ) >= GB^.ComTime;
	end else if IsMasterGear( Target ) then begin
		{ Check through all the target's NAtts, looking for }
		{ visibility information. }
		Vis := Target^.NA;
		while Vis <> Nil do begin
			if ( Vis^.G = NAG_Visibility ) and ( Vis^.V = NAV_Spotted ) then begin
				if AreAllies( gb , Team , Vis^.S ) and ( Vis^.S <> T2 ) then it := True;
			end;
			Vis := Vis^.Next;
		end;
	end else begin
		P := GearCurrentLocation( Target );
		if OnTheMap( GB , P.X , P.Y ) then begin
			it := TileVisible( GB , P.X , P.Y );
		end;
	end;
	TeamCanSeeTarget := it;
end;

Function MekCanSeeTarget( GB: GameBoardPtr; Mek , Target: GearPtr ): Boolean;
	{ Check to see whether or not TARGET is currently visible to }
	{ MEK. }
var
	Team: Integer;
begin
	Team := NAttValue( Mek^.NA , NAG_Location , NAS_Team );
	MekCanSeeTarget := TeamCanSeeTarget( gb , Team , Target );
end;

Function OnTheMap( GB: GameBoardPtr; X,Y: Integer ): Boolean;
	{ Check to see whether or not location X,Y is on the map.}
begin
	OnTheMap := ( X >= 1 ) and ( X <= GB^.Map_Width ) and ( Y >= 1 ) and ( Y <= GB^.Map_Height );
end;

Function OnTheMap( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
	{ Determine whether or not this mech is on the map. }
var
	X,Y: Integer;
begin 
	{ Error check - MEK must be defined in order for this to work. }
	if Mek = Nil then Exit( False );

	{ The location info is stored at root level... so if this gear }
	{ isn't root level, find one that is. }
	if Mek^.Parent <> Nil then Mek := FindRoot( Mek );

	X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );
	OnTheMap := OnTheMap( GB , X , Y );
end;

function MekVisible( GB: GameBoardPtr; Mek: GearPtr ): Boolean;
	{ Determine whether or not the graphic for MEK should be drawn }
	{ on the screen. }
var
	P: Point;
begin
	if Mek^.G = GG_MetaTerrain then begin
		P := GearCurrentLocation( Mek );
		if Mek^.S = GS_MetaEncounter then begin
			MekVisible := TeamCanSeeTarget( gb , NAV_DefPlayerTeam , Mek ) and TileVisible( GB , P.X , P.Y ) and ( Mek^.Stat[ STAT_MetaVisibility ] = 0 );
		end else if OnTheMap( GB , P.X , P.Y ) then begin
			MekVisible := TileVisible( GB , P.X , P.Y ) and ( Mek^.Stat[ STAT_MetaVisibility ] = 0 );
		end else begin
			MekVisible := TeamCanSeeTarget( gb , NAV_DefPlayerTeam , Mek );
		end;
	end else begin
		MekVisible := TeamCanSeeTarget( gb , NAV_DefPlayerTeam , Mek );
	end;
end;

function MekAltitude( gb: GameBoardPtr; Mek: GearPtr ): Integer;
	{ Determine the current altitude of MEK. This could be affected by }
	{ a number of things. The basic value is the same as the tile the mek }
	{ is standing on; if the mek is hovering or flying its altitude may }
	{ be different. }
var
	X,Y,Z: Integer;
begin
	{ Find the location of the mek. }
	X := NAttValue( Mek^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Mek^.NA , NAG_Location , NAS_Y );

	{ Error Check - make sure the mek is on the map. }
	if not OnTheMap( GB , X , Y ) then Exit( 0 );

	{ Z will be used to represent the vertical coordinate }
	Z := TerrMan[ TileTerrain( gb , X , Y ) ].Altitude;

	{ Depending upon the mek's move mode, this altitude may be changed. }
	X := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	if ( X = MM_Skim ) and ( BaseMoveRate(GB^.Scene,Mek,X) > 0 ) then begin
		{ A hovering mek will not go underwater. Min. Z = 0 }
		if Z < 0 then Z := 0;
	end else if ( X = MM_Fly ) and ( BaseMoveRate(GB^.Scene,Mek,X) > 0 ) and GearOperational( Mek ) and ( NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction ) <> NAV_Stop ) then begin
		Z := 5;
	end;

	MekAltitude := Z;
end;

Function IsBlocker( Mek: GearPtr ): Boolean;
	{ Return TRUE if MEK is a blocker, FALSE otherwise. }
begin
	if IsMasterGear( mek ) then begin
		IsBlocker := True;
	end else if Mek^.G = GG_MetaTerrain then begin
		IsBlocker := ( Mek^.Stat[ STAT_Pass ] <= -100 ) and NotDestroyed( Mek );
	end else begin
		IsBlocker := False;
	end;
end;

Function GearMatchesLPattern( GB: GameBoardPtr; Mek: GearPtr; var Match: LPattern ): Boolean;
	{ Return TRUE if the specified gear matches the search criteria, }
	{ or FALSE if it doesn't. }
var
	it: Boolean;
	P: Point;
begin
	if Mek = Nil then begin
		{ An undefined mek can't be a match. }
		it := False;

	end else begin
		{ See whether or not the gear is in our search tile. }
		P := GearCurrentLocation( Mek );
		if ( P.X = Match.X ) and ( P.Y = Match.Y ) then begin
			{ It's in the search tile. Assume TRUE, then apply the }
			{ other checks. }
			it := True;

			{ If a defined altitude is provided, check to see }
			{ whether or not the provided mek is at this alt. }
			if ( Match.Z >= -5 ) and ( Match.Z <= 5 ) then begin
				if Mek^.G = GG_MetaTerrain then begin
					it := Mek^.Stat[ STAT_Altitude ] >= Match.Z;
				end else begin
					it := MekAltitude( gb , Mek ) = Match.Z;
				end;
			end;

			{ If we're only looking for masters, or only }
			{ looking for non-masters, check that now. }
			if Match.Only_Masters = LP_MustBeMaster then begin
				it := it AND IsMasterGear( Mek );
			end else if Match.Only_Masters = LP_MustBeBlocker then begin
				it := it and IsBlocker( Mek );
			end else if Match.Only_Masters = LP_MustNotBeMaster then begin
				it := it AND NOT IsMasterGear( Mek );
			end else if Match.Only_Masters = LP_MustBeUsable then begin
				it := it AND (( Mek^.G = GG_MetaTerrain ) or ( SAttValue( Mek^.SA , Match.Trigger ) <> '' ));
			end;

			{ If we're only looking for visible gears, }
			{ check that now. }
			if Match.Only_Visibles then it := it AND MekVisible( GB , Mek );

		end else begin
			{ This gear isn't in the proper map tile, so of course }
			{ it doesn't fit the search criteria. }
			it := False;
		end;
	end;

	GearMatchesLPattern := it;
end;

Function NumMatchesPresent( GB: GameBoardPtr; var Match: LPattern ): Integer;
	{ Find the number of gears on the map which match the provided }
	{ search criteria. }
var
	M: GearPtr;	{ Mek Pointer }
	C: Integer;	{ Mek Count }
begin
	{ Initialize values }
	M := GB^.Meks;
	C := 0;

	while M <> Nil do begin
		if GearMatchesLPattern( GB , M , Match ) then Inc(C);
		M := M^.Next;
	end;

	NumMatchesPresent := C;
end;

Function FindMatchNumber( GB: GameBoardPtr; var Match: LPattern; N: Integer): GearPtr;
	{ Find gear number N at map tile X,Y. }
	{ If no appropriate gear is found, return the closest match. }
	{ If there's no gear at all in this tile, return Nil. }
var
	M,SM: GearPtr; { Mek counter, and Spot Mecha. }
	Count: Integer;
begin
	{ Initialize all the variables. }
	M := GB^.Meks;
	SM := Nil;
	Count := 0;

	{ Make sure that N is equal to at least one. }
	if N < 1 then N := 1;

	while ( M <> Nil ) and ( Count <> N ) do begin
		if GearMatchesLPattern( GB , M , Match ) then begin
			Inc(Count);
			SM := M;
		end;

		M := M^.Next;
	end;

	FindMatchNumber := SM;
end;

Function FindBestMatch( GB: GameBoardPtr; var Match: LPattern ): GearPtr;
	{ Locate the best match for the specified search criteria. }
	{ If more than one match is found, the mek to be returned will }
	{ be decided by the following criteria, in order of importance: }
	{  - Altitude (highest mek selected) }
	{  - Operationality (okay gear selected over destroyed gear) }
	{  - Scale (large gear selected over small gear) }
var
	Mek,BestMek: GearPtr;
begin
	Mek := GB^.Meks;
	BestMek := Nil;

	{ Loop through all of the meks on the map. }
	while Mek <> Nil do begin
		{ If this mek matches the description we've been given, }
		{ decide what to do with it next. }
		if GearMatchesLPattern( GB , Mek , Match ) then begin
			if BestMek = Nil then begin
				BestMek := Mek;
			end else if MekAltitude( GB , Mek ) > MekAltitude( GB , BestMek ) then begin
				BestMek := Mek;
			end else if MekAltitude( GB , Mek ) = MekAltitude( GB , BestMek ) then begin
				if GearOperational( Mek ) and not GearOperational( BestMek ) then begin
					BestMek := Mek;
				end else if GearOperational( Mek ) and ( Mek^.Scale > BestMek^.Scale ) then begin
					BestMek := Mek;
				end;
			end;
		end;

		Mek := Mek^.Next;
	end;

	{ Return whatever gear we've found. }
	FindBestMatch := BestMek;
end;

Function NumGearsXY( GB: GameBoardPtr; X,Y: Integer ): Integer;
	{ Determine how many VISIBLE meks there are in tile X,Y. }
var
	NVG_Search: LPattern;
begin
	NVG_Search.X := X;
	NVG_Search.Y := Y;
	NVG_Search.Z := -10;
	NVG_Search.Only_Visibles := False;
	NVG_Search.Only_Masters := 0;
	NumGearsXY := NumMatchesPresent( GB , NVG_Search );
end;

Function FindGearXY( GB: GameBoardPtr; X,Y,N: Integer): GearPtr;
	{ Find the VISIBLE gear number N at map tile X,Y. }
	{ If no appropriate gear is found, return the closest match. }
	{ If there's no gear at all in this tile, return Nil. }
var
	FVG_Search: LPattern;
begin
	FVG_Search.X := X;
	FVG_Search.Y := Y;
	FVG_Search.Z := -10;
	FVG_Search.Only_Visibles := False;
	FVG_Search.Only_Masters := 0;
	FindGearXY := FindMatchNumber( GB , FVG_Search , N );
end;

Function NumVisibleGears( GB: GameBoardPtr; X,Y: Integer ): Integer;
	{ Determine how many VISIBLE meks there are in tile X,Y. }
var
	NVG_Search: LPattern;
begin
	NVG_Search.X := X;
	NVG_Search.Y := Y;
	NVG_Search.Z := -10;
	NVG_Search.Only_Visibles := True;
	NVG_Search.Only_Masters := 0;
	NumVisibleGears := NumMatchesPresent( GB , NVG_Search );
end;

Function FindVisibleGear( GB: GameBoardPtr; X,Y,N: Integer): GearPtr;
	{ Find the VISIBLE gear number N at map tile X,Y. }
	{ If no appropriate gear is found, return the closest match. }
	{ If there's no gear at all in this tile, return Nil. }
var
	FVG_Search: LPattern;
begin
	FVG_Search.X := X;
	FVG_Search.Y := Y;
	FVG_Search.Z := -10;
	FVG_Search.Only_Visibles := True;
	FVG_Search.Only_Masters := 0;
	FindVisibleGear := FindMatchNumber( GB , FVG_Search , N );
end;

Function FindBlockerXYZ( GB: GameBoardPtr; X,Y,Z: Integer ): GearPtr;
	{ Locate a master gear at coordinates X,Y,Z. }
	{ Return Nil if no master gear is located at these coordinates. }
var
	Match: LPattern;
begin
	Match.X := X;
	Match.Y := Y;
	Match.Z := Z;
	Match.Only_Visibles := False;
	Match.Only_Masters := LP_MustBeBlocker;
	FindBlockerXYZ := FindBestMatch( GB , Match );
end;

Function NumVisibleItemsAtSpot( GB: GameBoardPtr; X,Y: Integer ): Integer;
	{ Locate a visible item at the specified coordinates. }
var
	Match: LPattern;
begin
	Match.X := X;
	Match.Y := Y;
	Match.Z := -10;
	Match.Only_Visibles := True;
	Match.Only_Masters := LP_MustNotBeMaster;
	NumVisibleItemsAtSpot :=  NumMatchesPresent( GB , Match );
end;

Function GetVisibleItemAtSpot( GB: GameBoardPtr; X,Y,N: Integer ): GearPtr;
	{ Locate a visible item at the specified coordinates. }
var
	Match: LPattern;
begin
	Match.X := X;
	Match.Y := Y;
	Match.Z := -10;
	Match.Only_Visibles := True;
	Match.Only_Masters := LP_MustNotBeMaster;
	GetVisibleItemAtSpot :=  FindMatchNumber( GB , Match , N );
end;

Function FindVisibleItemAtSpot( GB: GameBoardPtr; X,Y: Integer ): GearPtr;
	{ Locate a visible item at the specified coordinates. }
var
	Match: LPattern;
begin
	Match.X := X;
	Match.Y := Y;
	Match.Z := -10;
	Match.Only_Visibles := True;
	Match.Only_Masters := LP_MustNotBeMaster;
	FindVisibleItemAtSpot := FindBestMatch( GB , Match );
end;

Function NumVisibleUsableGearsXY( GB: GameBoardPtr; X,Y: Integer; const Trigger: String ): Integer;
	{ Count the visible, usable items at the specified coordinates. }
var
	NVUG_Search: LPattern;
begin
	NVUG_Search.X := X;
	NVUG_Search.Y := Y;
	NVUG_Search.Z := -10;
	NVUG_Search.Only_Visibles := True;
	NVUG_Search.Only_Masters := LP_MustBeUsable;
	NVUG_Search.Trigger := Trigger;
	NumVisibleUsableGearsXY := NumMatchesPresent( GB , NVUG_Search );
end;

Function FindVisibleUsableGearXY( GB: GameBoardPtr; X,Y,N: Integer; const Trigger: String): GearPtr;
	{ Find the Nth visible, usable item at the specified coordinates. }
var
	FVUG_Search: LPattern;
begin
	FVUG_Search.X := X;
	FVUG_Search.Y := Y;
	FVUG_Search.Z := -10;
	FVUG_Search.Only_Visibles := True;
	FVUG_Search.Only_Masters := LP_MustBeUsable;
	FVUG_Search.Trigger := Trigger;
	FindVisibleUsableGearXY := FindMatchNumber( GB , FVUG_Search , N );
end;


Function FindVisibleBlockerAtSpot( GB: GameBoardPtr; X,Y: Integer ): GearPtr;
	{ Locate a blocker gear at spot X,Y. Return Nil if no such }
	{ gear is found. Return the gear at highest altitude with the }
	{ largest scale. }
var
	Match: LPattern;
begin
	Match.X := X;
	Match.Y := Y;
	Match.Z := -10;
	Match.Only_Visibles := True;
	Match.Only_Masters := LP_MustBeBlocker;
	FindVisibleBlockerAtSpot := FindBestMatch( GB , Match );
end;

Procedure UpdateShadowMap( GB: GameBoardPtr );
	{ Update the list of shadows which holds information on gears which }
	{ either block or affect LOS. }
	{ When we are finished, the shadow map will hold a positive number for }
	{ tiles which have an obscurement score, and a negative number for tiles }
	{ which block LOS altogether. }
	{ We keep the shadow map so that we won't have to scan through every single }
	{ gear in the list for every single tile checked when calculating obscurement, }
	{ area effects, et cetera. }
var
	X,Y,Z: Integer;
	M: GearPtr;
begin
	{ To start with, clear the previous map. }
	for X := 1 to MaxMapWidth do begin
		for Y := 1 to MaxMapWidth do begin
			for Z := LowShadow to HiShadow do begin
				Shadow_Map[ X , Y , Z ] := 0;
			end;
		end;
	end;

	{ Loop through all gears on the map, looking for metaterrain. }
	M := GB^.Meks;
	while M <> Nil do begin
		if ( M^.G = GG_MetaTerrain ) and NotDestroyed( M ) then begin
			X := NAttValue( M^.NA , NAG_Location , NAS_X );
			Y := NAttValue( M^.NA , NAG_Location , NAS_Y );
			if OnTheMap( GB , X , Y ) then begin
				for Z := LowShadow to HiShadow do begin
					if Z <= M^.Stat[ Stat_Altitude ] then begin
						{ If the tile causes obscurement, add that now. }
						{ If the tile blocks LOS altogether, do that as well. }
						if M^.Stat[ STAT_Pass ] <= -100 then begin
							Shadow_Map[ X , Y , Z ] := -1;
						end else if Shadow_Map[ X , Y , Z ] >= 0 then begin
							Shadow_Map[ X , Y , Z ] := Shadow_Map[ X , Y , Z ] + M^.Stat[ STAT_Obscurement ];
						end;
					end;
				end;
			end;
		end;

		M := M^.Next;
	end;

	{ Store the current combat time, so that the shadow map doesn't have to be }
	{ generated over again all the time. }
	Shadow_Map_Update := GB^.ComTime;
end;

Function TileBlocksLOS( GB: GameBoardPtr; X,Y,Z: Integer ): Boolean;
	{ Return TRUE if this tile blocks LOS, or FALSE otherwise. }
	{ IMPORTANT: Assumes that X,Y is located on the map. }
	{ ALSO IMPORTANT: Assumes that the shadow map is up to date. }
begin
	{ Error check - make sure Z is within range. We already }
	{ know that X and Y are by the condition that X,Y be on the map. }
	if Z > HiShadow then Z := HiShadow
	else if Z < LowShadow then Z := LowShadow;
	if Shadow_Map[ X , Y , Z ] < 0 then begin
		TileBlocksLOS := True;
	end else begin
		TileBlocksLOS := TerrMan[ TileTerrain( GB , X , Y ) ].Altitude > Z;
	end;
end;

Function CalcObscurement(X1,Y1,Z1,X2,Y2,Z2: Integer; gb: GameBoardPtr): Integer;
	{Check the space between X1,Y1 and X2,Y2. Calculate the total}
	{obscurement value of the terrain there. Return 0 for a}
	{clear LOS, a positive number for an obscured LOS, and -1}
	{for a completely blocked LOS.}
var
	N: Integer;		{The number of points on the line.}
	t,terr: Integer;	{A counter, and a terrain type.}
	Wall: Boolean;	{Have we hit a wall yet?}
	p: Point;
	O: Integer;	{The obscurement count.}
begin
	{ Start by updating the shadow map. }
	if Shadow_Map_Update < GB^.Comtime then UpdateShadowMap( GB );
	if not ( OnTheMap( GB , X1 , Y1 ) and OnTheMap( GB , X2 , Y2 ) ) then Exit( -1 );

	if Abs(X2 - X1) > Abs(Y2 - Y1) then
		N := Abs(X2-X1)
	else
		N := Abs(Y2-Y1);

	{The obscurement count starts out with a value of 0.}
	O := 0;

	{The variable WALL represents a boundary that cannot be seen through.}
	Wall := false;

	for t := 1 to N do begin
		{Locate the next point on the line.}
		p := SolveLine(X1,Y1,Z1,X2,Y2,Z2,t);

		{Determine the terrain of this tile.}
		if OnTheMap( GB , p.X , P.y ) then begin
			terr := TileTerrain( gb , p.X , p.Y );
		end else begin
			terr := 1;
		end;

		{ Determine whether this terrain is at the correct height }
		{ to affect obscurement. }
		if TerrMan[ Terr ].Altitude = P.Z then begin
			{Update the Obscurement count.}
			O := O + TerrMan[Terr].Obscurement;
			if ( P.Z >= LowShadow ) and ( P.Z <= HiShadow ) and ( Shadow_Map[ P.X , P.Y , P.Z ] > 0 ) then O := O + Shadow_Map[ P.X , P.Y , P.Z ];
		end;
		if TileBlocksLOS( GB , P.X , P.Y , P.Z ) then begin
			{ If the wall is the terminus of the LOS calculation, }
			{ it won't block LOS. Why? Because the PC should }
			{ be able to see a wall, even though the wall tile }
			{ itself if blocking terrain. }
			Wall := T <> N;
		end;
	end;

	{If there's a wall in the way, Obscurement := -1}
	if Wall then
		O := -1;

	CalcObscurement := O;
end;

Function CalcObscurement(X1,Y1,X2,Y2: Integer; gb: GameBoardPtr): Integer;
	{ Same as above, but calculate Z values here. }
begin
	if not ( OnTheMap( GB , X1 , Y1 ) and OnTheMap( GB , X2 , Y2 ) ) then Exit( -1 );
	CalcObscurement := CalcObscurement( X1 , Y1 , TerrMan[ TileTerrain( gb , X1 , Y1 ) ].Altitude , X2 , Y2 , TerrMan[ TileTerrain( gb , X2 , Y2 ) ].Altitude , gb );
end;

Function CalcObscurement( M1: GearPtr; X2,Y2: Integer; gb: GameBoardPtr ): Integer;
	{ Calculate the obscurement between M1 and M2. }
var
	X1,Y1: Integer;
begin
	if M1^.Parent <> Nil then M1 := FindRoot( M1 );

	if OnTheMap( GB , M1 ) and OnTheMap( GB , X2 , Y2 ) then begin
		X1 := NAttValue( M1^.NA , NAG_Location , NAS_X );
		Y1 := NAttValue( M1^.NA , NAG_Location , NAS_Y );
		CalcObscurement := CalcObscurement( X1 , Y1 , MekAltitude(gb,M1) , X2 , Y2 , TerrMan[ TileTerrain( gb , X2 , Y2 ) ].Altitude , gb );
	end else begin
		CalcObscurement := -1;
	end;
end;

Function CalcObscurement( M1 , M2: GearPtr; gb: GameBoardPtr ): Integer;
	{ Calculate the obscurement between M1 and M2. }
var
	X1,Y1,X2,Y2: Integer;
begin
	if M1^.Parent <> Nil then M1 := FindRoot( M1 );
	if M2^.Parent <> Nil then M2 := FindRoot( M2 );

	if OnTheMap( GB , M1 ) and OnTheMap( GB, M2 ) then begin
		X1 := NAttValue( M1^.NA , NAG_Location , NAS_X );
		Y1 := NAttValue( M1^.NA , NAG_Location , NAS_Y );
		X2 := NAttValue( M2^.NA , NAG_Location , NAS_X );
		Y2 := NAttValue( M2^.NA , NAG_Location , NAS_Y );
		CalcObscurement := CalcObscurement( X1 , Y1 , MekAltitude(gb,M1) , X2 , Y2 , MekAltitude(gb,M2) , gb );
	end else begin
		CalcObscurement := -1;
	end;
end;

Function CheckArc( OX , OY , TX , TY , A: Integer ): Boolean;
	{ Examine target point TX,TY as it relates to origin point OX,OY. }
	{ Return TRUE if it falls within arc A, FALSE otherwise. }
var
	DX,DY: Integer;
	it: Boolean;
begin
	{ Find relative coordinates of the target square. }
	DX := TX - OX;
	DY := TY - OY;

	{ *** ARC CHART *** }
	{     \ 5 | 6 /     }
	{      \  |  /      }
	{    4  \ | / 7     }
	{        \|/        }
	{    -----@-----    }
	{        /|\  0     }
	{    3  / | \       }
	{      /  |  \      }
	{     / 2 | 1 \     }

	it := False;
	if A = 0 then begin
		{ DX >= 0 }
		{ 0 <= DY <= Abs(DX) }
		if ( DX >= 0 ) and ( 0 <= DY ) and ( DY <= DX ) then it := true;
	end else if A = 1 then begin
		{ DY >= 0 }
		{ 0 <= DX <= Abs(DY) }
		if ( DY >= 0 ) and ( 0 <= DX ) and ( DX <= DY ) then it := true;
	end else if A = 2 then begin
		{ DY >= 0 }
		{ 0 >= DX >= -Abs(DY) }
		if ( DY >= 0 ) and ( 0 >= DX ) and ( DX >= -Abs(DY) ) then it := true;
	end else if A = 3 then begin
		{ DX <= 0 }
		{ 0 <= DY <= Abs(DX) }
		if ( DX <= 0 ) and ( 0 <= DY ) and ( DY <= Abs(DX) ) then it := true;
	end else if A = 4 then begin
		{ DX <= 0 }
		{ 0 >= DY >= -Abs(DX) }
		if ( DX <= 0 ) and ( 0 >= DY ) and ( DY >= DX ) then it := true;
	end else if A = 5 then begin
		{ DY <= 0 }
		{ 0 >= DX >= -Abs(DY) }
		if ( DY <= 0 ) and ( 0 >= DX ) and ( DX >= DY ) then it := true;
	end else if A = 6 then begin
		{ DY <= 0 }
		{ 0 <= DX <= Abs(DY) }
		if ( DY <= 0 ) and ( 0 <= DX ) and ( DX <= Abs(DY) ) then it := true;
	end else if A = 7 then begin
		{ DX >= 0 }
		{ 0 >= DY >= -Abs(DX) }
		if ( DX >= 0 ) and ( 0 >= DY ) and ( DY >= -DX ) then it := true;
	end;

	CheckArc := it;
end;

Function CheckArc( M1: GearPtr; X2,Y2,A: Integer ): Boolean;
	{ See comments above. This function just calls the above one. }
	{ Checks arc A to see if point X2,Y2 falls inside it. }
var
	X1,Y1: Integer;
begin
	X1 := NAttValue( M1^.NA , NAG_Location , NAS_X );
	Y1 := NAttValue( M1^.NA , NAG_Location , NAS_Y );
	CheckArc := CheckArc( X1 , Y1 , X2 , Y2 , A );
end;

Function CheckArc( M1,M2: GearPtr; A: Integer ): Boolean;
	{ See comments above. This function just calls the above one. }
	{ Checks arc A to see if point X2,Y2 falls inside it. }
var
	X2,Y2,X1,Y1: Integer;
begin
	X1 := NAttValue( M1^.NA , NAG_Location , NAS_X );
	Y1 := NAttValue( M1^.NA , NAG_Location , NAS_Y );
	X2 := NAttValue( M2^.NA , NAG_Location , NAS_X );
	Y2 := NAttValue( M2^.NA , NAG_Location , NAS_Y );
	CheckArc := CheckArc( X1 , Y1 , X2 , Y2 , A );
end;


Function Range( X1 , Y1 , X2 , Y2: Integer ): Integer;
	{Calculate the range between X1,Y1 and X2,Y2.}
begin
	{Pythagorean theorem.}
	Range := Round(Sqrt(Sqr(X2 - X1) + Sqr(Y2 - Y1)));
end;

Function Range( M1: GearPtr; X2,Y2: Integer ): Integer;
	{ Calculate the distance between M1 and M2. }
var
	X1,Y1: Integer;
begin
	X1 := NAttValue( M1^.NA , NAG_Location , NAS_X );
	Y1 := NAttValue( M1^.NA , NAG_Location , NAS_Y );
	Range := Range( X1 , Y1 , X2 , Y2 );
end;

Function Range( gb: GameBoardPtr; M1 , M2: GearPtr ): Integer;
	{ Calculate the distance between M1 and M2. }
var
	X1,Y1,Z1,X2,Y2,Z2: Integer;
begin
	X1 := NAttValue( M1^.NA , NAG_Location , NAS_X );
	Y1 := NAttValue( M1^.NA , NAG_Location , NAS_Y );
	Z1 := MekAltitude( gb , M1 );
	X2 := NAttValue( M2^.NA , NAG_Location , NAS_X );
	Y2 := NAttValue( M2^.NA , NAG_Location , NAS_Y );
	Z2 := MekAltitude( gb , M2 );
	Range := Round( Sqrt(Sqr(X2 - X1) + Sqr(Y2 - Y1) + Sqr(Z2 - Z1)) );
end;

function WeaponRange( GB: GameBoardPtr; Weapon: GearPtr; Band: Integer ): Integer;
	{ Calculate the range of this weapon, adjusting the value for map scale. }
	{ If GB=Nil, return the unscaled value. }
	{ Normally, medium range is 2x short and long range is 3x short. Some }
	{ weapons are special cases. }
const
	Missile_Launcher_Bonus = 4;
var
	BaseRange,rng,t: Integer;
	WAO,AMmo: GearPtr;
	AtAt: String;
	IsMissileWeapon: Boolean;
begin
	if Weapon = Nil then Exit( 0 );

	{ Calculate the attack attributes. We'll need those later. }
	AtAt := WeaponAttackAttributes( Weapon );
	IsMissileWeapon := False;

	if Weapon^.G = GG_Weapon then begin
		if ( Weapon^.S = GS_Ballistic ) or ( Weapon^.S = GS_BeamGun ) or ( Weapon^.S = GS_Missile ) then begin
			IsMissileWeapon := True;
			if Weapon^.S = GS_Missile then begin
				Ammo := LocateGoodAmmo( Weapon );
				if Ammo <> Nil then BaseRange := Ammo^.Stat[ STAT_Range ]
				else begin
					Ammo := LocateAnyAmmo( Weapon );
					if Ammo <> Nil then BaseRange := Ammo^.Stat[ STAT_Range ]
					else BaseRange := 0;
				end;
			end else begin
				BaseRange := Weapon^.Stat[ STAT_Range ];
			end;

			{ Add the bonus from any weapon add-ons. }
			WAO := Weapon^.InvCom;
			while WAO <> Nil do begin
				if ( WAO^.G = GG_WeaponAddOn ) and NotDestroyed( WAO ) then begin
					BaseRange := BaseRange + WAO^.Stat[ STAT_Range ]
				end;
				WAO := WAO^.Next;
			end;

		end else begin
			BaseRange := 1;
			if HasAttackAttribute( AtAt , AA_Extended ) then begin
				BaseRange := 2;
			end;
		end;
	end else BaseRange := 1;

	{ Given the base range, calculate the requested range band. }
	if IsMissileWeapon then begin
		if Band = RANGE_Medium then begin
			rng := BaseRange * 2;
		end else if Band = RANGE_Long then begin
			if HasAttackAttribute( AtAt , AA_LineAttack ) then begin
				rng := BaseRange * 2;
			end else begin
				rng := BaseRange * 3;
			end;
		end else begin
			rng := BaseRange;
		end;

		{ Missile launchers get extended range. }
		if Weapon^.S = GS_Missile then begin
			rng := rng + Missile_Launcher_Bonus;
		end;
	end else rng := BaseRange;

	if ( GB <> Nil ) and ( rng > 1 ) and ( Weapon^.Scale <> GB^.Scale ) then begin
		if Weapon^.Scale > GB^.Scale then begin
			for t := 1 to ( Weapon^.Scale - GB^.Scale ) do rng := rng * 2;
		end else begin
			{ The weapon scale must be smaller then the }
			{ game board scale. }
			for t := 1 to ( GB^.Scale - Weapon^.Scale ) do rng := rng div 2;
			if rng < 1 then rng := 1;
		end;
	end;

	WeaponRange := rng;
end;

function ThrowingRange( GB: GameBoardPtr; User,Weapon: GearPtr ): Integer;
	{ Calculate the maximum thrown range of this weapon, }
	{ adjusting the value for map scale. }
	{ If GB=Nil, return the unscaled value. }
var
	rng,t: Integer;
	HeavyActuator: Integer;
begin
	rng := 0;
	if ( Weapon <> Nil ) and ( Weapon^.G = GG_Weapon ) then begin
		if HasAttackAttribute( WeaponATtackAttributes( Weapon ) , AA_THrown ) then begin
			rng := MasterSize( User ) + 2;

			{ EXTEND weapons get a longer throwing range. }
			if HasAttackAttribute( WeaponAttackAttributes( Weapon ) , AA_Extended ) then begin
				rng := rng + 3;
			end;

			{ Throwing range may get a bonus from heavy actuators. }
			HeavyActuator := CountActivePoints( User , GG_MoveSys , GS_HeavyActuator );
			if HeavyActuator > 0 then begin
				rng := rng + ( HeavyActuator div 10 );
			end;
		end;

	end else if ( Weapon <> Nil ) and ( Weapon^.G = GG_Ammo ) and ( Weapon^.S = GS_Grenade ) then begin
		rng := MasterSize( User ) * 2 + 1;
	end;

	if ( Weapon <> Nil ) and ( GB <> Nil ) and ( rng > 1 ) and ( Weapon^.Scale <> GB^.Scale ) then begin
		if Weapon^.Scale > GB^.Scale then begin
			for t := 1 to ( Weapon^.Scale - GB^.Scale ) do rng := rng * 2;
		end else begin
			{ The weapon scale must be smaller then the }
			{ game board scale. }
			for t := 1 to ( GB^.Scale - Weapon^.Scale ) do rng := rng div 2;
			if rng < 1 then rng := 1;
		end;
	end;

	ThrowingRange := rng;
end;

Function GearDestination( Mek: GearPtr ): Point;
	{ Determine MEK's destination, given its current position }
	{ and movement action. }
var
	P: Point;
	Action , D: Integer;
begin
	P := GearCurrentLocation( Mek );
	Action := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );
	D := NAttValue( Mek^.NA , NAG_Location , NAS_D );

	if ( Action = NAV_NormSpeed ) or ( Action = NAV_FullSpeed ) then begin
		P.X := P.X + AngDir[D,1];
		P.Y := P.Y + AngDir[D,2];
	end else if Action = NAV_Reverse then begin
		P.X := P.X - AngDir[D,1];
		P.Y := P.Y - AngDir[D,2];
	end;

	GearDestination := P;
end;

Function IsBlockingTerrainForMM( GB: GameBoardPtr; Mek: GearPtr; Terrain,MM: Integer ): Boolean;
	{ Check the terrain type in question, and return TRUE if the mek }
	{ can move through it or FALSE if it cannot. }
var
	MekAlt: Integer;
	it: Boolean;
begin
	{ Primary Criterion - if terrain is defined as an obstacle, and }
	{ is of the same or lower elevation as the master gear under }
	{ consideration, it's an obstacle. }
	MekAlt := MekAltitude( GB , Mek );
	if TerrMan[ Terrain ].Pass <= -100 then begin
		it := TerrMan[ Terrain ].Altitude >= MekALt;
	end else if MM <> MM_Fly then begin
		{ If the terrain isn't an obstacle, but is two elevations }
		{ too tall, then it counts as an obstacle. }
		it := TerrMan[ Terrain ].Altitude > ( MekALt + 1 );
	end else begin
		it := False;
	end;

	{ Check the movement mode of the mek, to make sure that the }
	{ terrain being entered is legal for the given mode. }
	{ CAUTION: The mek might not have geared up yet, so its }
	{  movement mode might be illegal. }
	if ( MM >= 1 ) and ( MM <= NumMoveMode ) then begin
		it := it or not TerrMan[ Terrain ].MMPass[ MM ];

	{ Don't put items in water. }
	end else if not IsMasterGear( Mek ) then begin
		if TerrMan[ Terrain ].Altitude < 0 then it := True;
	end;

	{ Character type gears using the WALK move mode can't move }
	{ through water. Mecha which are smaller than the map size }
	{ can't walk through water either. }
	{ This is a special case, and as such I don't like it. However, }
	{ I have no better ideas as to how to deal with the issue. }
	if ( ( Mek^.G = GG_Character ) or ( Mek^.Scale < GB^.Scale ) ) and ( NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) = MM_Walk ) then begin
		if TerrMan[ Terrain ].Altitude < 0 then it := True;
	end;

	IsBlockingTerrainForMM := it;
end;

Function IsBlockingTerrain( GB: GameBoardPtr; Mek: GearPtr; Terrain: Integer ): Boolean;
	{ Call the above function with the mek's current move mode. }
begin
	IsBlockingTerrain := IsBlockingTerrainForMM( GB , Mek , Terrain , NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) );
end;

Function MovementBlocked( Mek: GearPtr; GB: GameBoardPtr; OX,OY,DX,DY: Integer ): Boolean;
	{ Return TRUE if tile X,Y is unsuitable for MEK to enter, FALSE }
	{ if it isn't. }
var
	Special: String;
	it: Boolean;
	M: GearPtr;
begin
	{ Locate the SPECIAL string for this scene, if one exists. }
	if GB^.Scene <> Nil then begin
		Special := UpCase( SAttValue( GB^.Scene^.SA , 'SPECIAL' ) );
	end else begin
		Special := '';
	end;

	if not OnTheMap( GB , DX , DY ) then begin
		{ If the specified location is not on the map, }
		{ the move probably isn't blocked. }
		{ Check the SPECIAL string to find out. }
		it := Pos( SA_MapEdgeObstacle , Special ) > 0;

	end else if ( OX = DX ) and ( OY = DY ) then begin
		it := False;

	end else if IsBlockingTerrain( GB , Mek , TileTerrain( GB , DX , DY ) ) then begin
		it := True;
	end else begin
		{ Masters and Encounters will search for blockers. }
		if IsMasterGear( Mek ) or (( Mek^.G = GG_MetaTerrain ) and ( Mek^.S = GS_MetaEncounter )) then begin
			M := FindBlockerXYZ( GB , DX , DY , MekAltitude( GB , Mek ) );

            		if ( M <> Nil ) and ( M^.Scale >= GB^.Scale ) and GearOperational( M ) then begin
				it := True;
			end else begin
				it := False;
			end;
		end else begin
			{ If this gear is at a smaller scale than the map, }
			{ it can stack without penalty. IsBlocked = False. }
			it := False;
		end;

	end;

	MovementBlocked := it;
end;

Function FrontBlocked( Mek: GearPtr; GB: GameBoardPtr; D: Integer ): Boolean;
	{ Return TRUE if the mek would be blocked if traveling in direction D, }
	{ FALSE if it wouldn't be. }
var
	P1,P2: Point;
begin
	{ Determine the destination square. }
	P1 := GearCurrentLocation( Mek );
	P2.X := P1.X + AngDir[ D , 1 ];
	P2.Y := P1.Y + AngDir[ D , 2 ];

	FrontBlocked := MovementBlocked( Mek , GB , P1.X , P1.Y , P2.X , P2.Y );
end;

Function MoveBlocked( Mek: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Check Mek's current movemode and action. Return TRUE if Mek }
	{ can complete this move, FALSE otherwise. }
var
	P1,P2: Point;	{ Destination point. }
begin
	{ Determine the destination square. }
	P1 := GearCurrentLocation( Mek );
	P2 := GearDestination( Mek );

	MoveBlocked := MovementBlocked( Mek , GB , P1.X , P1.Y , P2.X , P2.Y );
end;

Function CalcTerrainMod( Mek: GearPtr; GB: GameBoardPtr ): Integer;
	{ Calculate the terrain modifier for the terrain the model is facing. }
var
	P1,P2: Point;
	Terrain: Integer;
	TerrMod,MM: Integer;
	MTerr: GearPtr;
begin
	P1 := GearCurrentLocation( Mek );
	P2 := GearDestination( Mek );
	TerrMod := 0;

	if OnTheMap( GB, P2.X , P2.Y ) then begin
		{ Modify the movement rate by the terrain mod of the destination hex. }
		Terrain := TileTerrain( GB , P2.X , P2.Y );
		TerrMod := TerrMan[ Terrain ].Pass;

		{ Modify for meta-terrain. }
		MTerr := GB^.Meks;
		while MTerr <> Nil do begin
			if ( MTerr^.G = GG_MetaTerrain ) and ( NAttValue( MTerr^.NA , NAG_Location , NAS_X ) = P2.X ) and ( NAttValue( MTerr^.NA , NAG_Location , NAS_X ) = P2.Y ) then begin
				TerrMod := TerrMod + MTerr^.Stat[ STAT_Pass ];
			end;
			MTerr := MTerr^.Next;
		end;

		if IsBlockingTerrain( GB , Mek , Terrain ) then begin
			{ It takes a normal movement action to bump into }
			{ an obstacle. }
			TerrMod := -50;

		end else begin
			MM := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );

			{ Adjust for elevation change. }
			if TerrMan[ Terrain ].Altitude < TerrMan[ TileTerrain( GB , P1.X , P1.Y ) ].Altitude then begin
				TerrMod := TerrMod - 5;
			end else if TerrMan[ Terrain ].Altitude > TerrMan[ TileTerrain( GB , P1.X , P1.Y ) ].Altitude then begin
				TerrMod := TerrMod + 25 * ( TerrMan[ Terrain ].Altitude - TerrMan[ TileTerrain( GB , P1.X , P1.Y ) ].Altitude );
			end;

			{ Adjust for move mode characteristics. }
			if MM = MM_Roll then begin
				{ Ground vehicles suffer 4x the movement penalty of other types. }
				TerrMod := TerrMod * 4;

			end else if MM = MM_Skim then begin
				{ Hovering units can skim right over low obstacles. So, if the }
				{ terrain in question doesn't cause obscurement, it doesn't slow }
				{ down a hovering mecha either. }
				if ( TerrMan[ Terrain ].Obscurement = 0 ) or ( TerrMan[Terrain].Altitude < 0 ) then TerrMod := 0;

			end else if MM = MM_Fly then begin
				TerrMod := 0;

			end;
		end;

		{ Make sure the terrain modifier doesn't drop below a certain standard. }
		if TerrMod < -50 then TerrMod := -50;
	end else begin
		{ Attempting to move off the map }
		{ takes 2x as long as normal movement. }
		TerrMod := 200;

	end;
	CalcTerrainMod := TerrMod;
end;

Function CalcMoveTime( Mek: GearPtr; GB: GameBoardPtr ): Integer;
	{ This procedure calls the movement.pp speed calculator, }
	{ then adjusts the value obtained for terrain and elevation. }
	{ As with the movement.pp functions, CalcMoveTime returns }
	{ zero if the mecha isn't capable of moving. }
const
	MinMoveTime = 3;
var
	it: Integer;
	Action: Integer;
	TerrMod, D: Integer;
begin
	it := CPHMoveRate( GB^.Scene , Mek , GB^.Scale );
	Action := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );
	TerrMod := 0;

	{ Find the direction of travel, and also the }
	{ destination square. }
	D := NAttValue( Mek^.NA , NAG_Location , NAS_D );

	{ Adjust for terrain if the mecha is walking or running. }
	if ( Action = NAV_NormSpeed ) or ( Action = NAV_FullSpeed ) or ( Action = NAV_Reverse ) then begin
		{ Modify the movement rate by the terrain mod of the destination hex. }
		TerrMod := CalcTerrainMod( Mek , GB );
		it := ( it * ( 100 + TerrMod ) ) div 100;

		{ Adjust for diagnol movement. }
		if (D mod 2) = 1 then it := (it * 141) div 100;
	end;

	if it < MinMoveTime then it := MinMoveTime;

	CalcMoveTime := it;
end;

Function CalcRelativeSpeed( Mek: GearPtr; GB: GameBoardPtr ): Integer;
	{ Calculate the relative speed of this mecha. }
	{ This is used for calculating hit rolls and maybe some other things. }
	{ This speed is modified for terrain but not for map scale. It is measured }
	{ in decihexes per round. }
var
	MoveMode,Action,Spd,Drift: Integer;
begin
	MoveMode := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	Action := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );
	Drift := NAttValue( Mek^.NA , NAG_Action , NAS_DriftSpeed );

	{ If the mecha's action is to stand still, it will have a relative speed of 0. }
	if ( Action = NAV_Hover ) or ( Action = NAV_Stop ) then begin
		Spd := 0;

	end else begin
		Spd := AdjustedMoveRate( GB^.Scene , Mek , MoveMode , Action );

		if Spd > 0 then begin
			{ If using full speed, normal speed, or reverse, modify the }
			{ speed for terrain. }
			if ( Action = NAV_NormSpeed ) or ( Action = NAV_FullSpeed ) or ( Action = NAV_Reverse ) then begin
				Spd := ( Spd * 100 ) div ( 100 + CalcTerrainMod( Mek , GB ) );
			end;
		end;
	end;

	{ As long as the mecha is mobile in space, it can treat its drift speed }
	{ as its defensive speed. }
	if ( BaseMoveRate( GB^.Scene , Mek , MM_Space ) > 0 ) and ( Drift > Spd ) then Spd := Drift;

	CalcRelativeSpeed := Spd;
end;

Function IsInCover( GB: GameBoardPtr; Master: GearPtr ): Boolean;
	{ Return TRUE if MASTER is in cover, FALSE otherwise. }
var
	X,Y,Z: Integer;
begin
	if Shadow_Map_Update < GB^.ComTime then UpdateShadowMap( GB );

	if Master <> Nil then begin
		{ Movement information is stored at root level. }
		if Master^.Parent <> Nil then Master := FindRoot( Master );

		X := NAttValue( Master^.NA , NAG_Location , NAS_X );
		Y := NAttValue( Master^.NA , NAG_Location , NAS_Y );
		Z := MekAltitude( GB , Master );

		if Z < 0 then begin
			{ Meks underwater are automatically in cover. }
			IsInCover := True;
		end else if TerrMan[TileTerrain( GB , X , Y ) ].Altitude < Z then begin
			{ Meks flying above the terrain are automatically not in cover. }
			IsInCover := False;
		end else begin
			{ Meks standing in the terrain may or may not be in cover. }
			{ It depends on whether or not the terrain they're standing in }
			{ provides obscurement. }
			IsInCover := ( TerrMan[TileTerrain( GB , X , Y )].Obscurement > 0 ) or ( Shadow_Map[ X , Y , Z ] > 0 );
		end;
	end else IsInCover := False;
end;

Function NumActiveMasters( GB: GameBoardPtr; Team: Integer ): Integer;
	{ Count up the number of members of this team who are operational }
	{ and on the map. }
var
	mek: GearPtr;
	mem,T: Integer;
begin
	mek := GB^.Meks;
	mem := 0;

	{ Loop through all the meks on the board. }
	while mek <> nil do begin
		if GearActive( Mek ) and OnTheMap( GB , Mek ) then begin
			T := NAttValue( mek^.NA , NAG_Location , NAS_Team );
			if T = Team then Inc( mem );
		end;
		mek := mek^.next;
	end;

	NumActiveMasters := Mem;
end;

Function NumOperationalMasters( GB: GameBoardPtr; Team: Integer ): Integer;
	{ Count up the number of members of this team who are operational }
	{ and on the map. }
var
	mek: GearPtr;
	mem,T: Integer;
begin
	mek := GB^.Meks;
	mem := 0;

	{ Loop through all the meks on the board. }
	while mek <> nil do begin
		if GearOperational( Mek ) and OnTheMap( GB , Mek ) then begin
			T := NAttValue( mek^.NA , NAG_Location , NAS_Team );
			if T = Team then Inc( mem );
		end;
		mek := mek^.next;
	end;

	NumOperationalMasters := Mem;
end;

Procedure SetTrigger( GB: GameBoardPtr; const msg: String );
	{ Store the trigger. }
begin
	{ Only store it if collection has been set to TRUE. }
	if LOCALE_CollectTriggers then begin
		StoreSAtt( GB^.Trig , msg );
	end;
end;

Function SeekTarget( GB: GameBoardPtr; Mek: GearPtr ): GearPtr;
	{ Try to find the best target for Mek to fire at. }
var
	TTemp,TBest: GearPtr;
	BestScore,Score: Integer;
begin
	TTemp := GB^.Meks;
	TBest := Nil;
	BestScore := 9999;

	while TTemp <> Nil do begin
		{ If this mek is an enemy of the spotter, and is visible, }
		{ and is still functional, }
		{ then it's a candidate to be the target picked. }
		if OnTheMap( GB , Mek ) and AreEnemies( GB , Mek , TTemp ) and MekCanSeeTarget( GB , Mek , TTemp ) and GearActive( TTemp ) then begin
			{ Calculate this mek's vunerability score. }
			Score := Range( GB , Mek , TTemp ) + CalcObscurement( Mek , TTemp , GB );

			{ If not in the front arc, impose penalty. }
			if not CheckArc( Mek , TTemp , ARC_F180 ) then Score := Score + 15
			else if not CheckArc( Mek , TTemp , ARC_F90 ) then Score := Score + 5;

			if ( Score < BestScore ) or ( TBest = Nil ) then begin
				BestScore := Score;
				TBest := TTemp;
			end;
		end;
		TTemp := TTemp^.Next;
	end;

	SeekTarget := TBest;
end;


Procedure FreezeLocation( const Name: String; GB: GameBoardPtr; var FList: FrozenLocationPtr );
	{ Store the provided location in FList for later use. }
var
	it: FrozenLocationPtr;
begin
	{ Error check - make sure that there's no level currently in the }
	{ list with this name. }
	it := FindFrozenLocation( Name , FList );
	if it <> Nil then RemoveFrozenLocation( FList , it );

	{ Create a new level, and store the stuff. }
	it := CreateFrozenLocation( FList );
	it^.Name := Name;
	it^.Map := GB^.Map;
	it^.Map_Width := GB^.Map_Width;
	it^.Map_Height := GB^.Map_Height;
end;

Function UnfreezeLocation( const Name: String; var FList: FrozenLocationPtr ): GameBoardPtr;
	{ Attempt to unfreeze the specified level. If the level was found, }
	{ return TRUE. If the unfreezing failed, return FALSE. }
	{ Once the level is unfrozen the frozen record should be removed. }
var
	it: FrozenLocationPtr;
	gb: GameBoardPtr;
begin
	it := FindFrozenLocation( Name , FList );

	if it = Nil then begin
		{ This map wasn't found in the list, so return NIL. }
		UnfreezeLocation := Nil;
	end else begin
		{ We have the map level. Copy the map into a new }
		{ gameboard structure, then pass that back. }
		gb := NewMap( it^.Map_Width , it^.Map_Height );
		gb^.Map := it^.Map;
		gb^.Map_Width := it^.Map_Width;
		gb^.Map_Height := it^.Map_Height;
		RemoveFrozenLocation( FList , it );
		UnfreezeLocation := GB;
	end;
end;

Procedure DeleteFrozenLocation( const Name: String; var FList: FrozenLocationPtr );
	{ Delete this frozen location. }
var
	it: FrozenLocationPtr;
begin
	it := FindFrozenLocation( Name , FList );
	if it <> Nil then begin
		RemoveFrozenLocation( FList , it );
	end;
end;

function FindThisTerrain( GB: GameBoardPtr; TTS: Integer ): Point;
	{ Attempt to find the terrain in question. }
	{ If the terrain can't be found, return point 0,0. }
var
	P: Point;
	X,Y: Integer;
begin
	P.X := 0;
	P.Y := 0;
	for X := 1 to GB^.Map_Width do begin
		for Y := 1 to GB^.Map_Height do begin
			if TileTerrain( GB , X , Y ) = TTS then begin
				P.X := X;
				P.Y := Y;
			end;
		end;
	end;
	FindThisTerrain := P;
end;

Function NewTeamID( Scene: GearPtr ): LongInt;
	{ Create a new unique team ID. Do this by seeking out the currently highest }
	{ team ID in use, then going one higher. }
var
	it: LongInt;
	T: GearPtr;
begin
	{ Check the models on the map... }
	it := MaxIDTag( Scene^.InvCom , NAG_Location , NAS_Team );

	{ Check the team definitions themselves... }
	T := Scene^.SubCOm;
	while T <> Nil do begin
		if ( T^.G = GG_Team ) and ( T^.S > it ) then it := T^.S;
		T := T^.Next;
	end;

	NewTeamID := it + 1;
end;

Procedure SetTeamReputation( GB: GameBoardPtr; T,R,V: Integer );
	{ Set a reputation for each member of team T. }
var
	Part: GearPtr;
begin
	Part := GB^.Meks;
	while Part <> Nil do begin
		if ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = T ) and IsMasterGear( Part ) then begin
			AddReputation( Part , R , V );
		end;
		Part := Part^.Next;
	end;
end;

Procedure DeclarationOfHostilities( GB: GameBoardPtr; ATeam,DTeam: Integer );
	{ Attacker Team has just attacked Defender Team. Update all the }
	{ team gears in GB/Scene as a result. }
var
	Team: GearPtr;
begin
	{ Error check - better not be talking about the NoTeam team... }
	if ( Ateam = 0 ) or ( DTeam = 0 ) or ( ATeam = DTeam ) then Exit;

	{ If it's the lancemate team attacking, this counts as a PC attack. }
	if ATeam = NAV_LancemateTeam then ATeam := NAV_DefPlayerTeam;

	{ If the Attacking team hasn't started as the enemy of the other team, set reputation to Chaotic. }
	{ If the Defending team isn't out to get the attacking team, set reputation to Villainous. }
	if ( ATeam > 0 ) and ( DTeam > 0 ) and not AreEnemies( GB , ATeam , DTeam ) then begin
		SetTeamReputation( GB , ATeam , 2 , -5 );
		if not AreEnemies( GB , DTeam , ATeam ) then begin
			SetTeamReputation( GB , ATeam , 1 , -25 );
			if ATeam = NAV_DefPlayerTeam then SetTrigger( GB, 'PLAYERVILLAIN' );
		end;
	end;

	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		{ Go through all the teams in the SCENE record. }
		Team := GB^.Scene^.SubCom;

		while Team <> Nil do begin
			{ If this is a team, we might need to update }
			{ its alleigances. }
			if Team^.G = GG_Team then begin
				if Team^.S = ATeam then begin
					SetNAtt( Team^.NA , NAG_SideReaction , DTeam , NAV_AreEnemies );
				end else if Team^.S = DTEam then begin
					SetNAtt( Team^.NA , NAG_SideReaction , ATeam , NAV_AreEnemies );
				end else begin
					if AreAllies( GB , Team^.S , DTeam ) then SetNAtt( Team^.NA , NAG_SideReaction , ATeam , NAV_AreEnemies );
				end;
			end;

			Team := Team^.Next;
		end;
	end;
end;

Function BoardMecha( Mek,Pilot: GearPtr ): Boolean;
	{ Attempt to load PILOT into MEK. Return TRUE if this could }
	{ be done, or FALSE if it couldn't. }
var
	CP: GearPtr;
begin
	if ( Mek = Nil ) or ( Pilot = Nil ) then begin
		{ If either mecha or pilot are undefined, this }
		{ attempt will of course fail. }
		BoardMecha := False;

	end else begin
		{ Attempt to find the cockpit. }
		CP := SeekGear(mek,GG_CockPit,0);
		if CP <> Nil then begin
			{ Cockpit has been located. Insert pilot. }
			if IsLegalSubcom( CP , Pilot ) then begin
				InsertSubCom( CP , Pilot );
				BoardMecha := True;

			end else begin
				{ For whatever reason, the pilot can't be inserted into }
				{ the cockpit. }
				BoardMecha := False;

			end;

		end else begin
			{ Cockpit has not been located. This attempt has failed. }
			BoardMecha := False;

		end;

	end;
end;

Function ExtractPilot( Mek: GearPtr ): GearPtr;
	{ Remove the pilot from the specified mek. If no pilot is found, }
	{ return Nil. }
var
	Pilot: GearPtr;
begin
	if ( Mek = Nil ) or ( Mek^.G = GG_Character ) then begin
		{ Can't extract a pilot from a character or an undefined gear. }
		ExtractPilot := Nil;

	end else begin
		Pilot := SeekGearByG( Mek^.SubCom , GG_Character );
		if Pilot <> Nil then begin
			DelinkGear( Pilot^.Parent^.SubCom , Pilot );
		end;
		ExtractPilot := Pilot;
	end;

end;

Function FindPilotsMecha( LList,PC: GearPtr ): GearPtr;
	{ Attempt to find the mecha belonging to PC from the list. }
	{ If no such mecha may be found, return Nil. }
var
	mek,pmek: GearPtr;
	name: String;
begin
	{ Begin by finding the PC's name. }
	name := PilotName( PC );

	{ Stupid error check - A truly nameless PC might cause an }
	{ endless loop. }
	if name = '' then Exit( Nil );

	{ Search through the list looking for a mecha which }
	{ has been assigned to this pilot. }
	mek := LList;
	pmek := Nil;
	while ( mek <> Nil ) and ( pmek = Nil ) do begin
		if mek^.G = GG_Mecha then begin
			if SAttValue( mek^.SA , 'pilot' ) = name then PMek := Mek;
		end;
		mek := mek^.Next;
	end;

	FindPilotsMecha := pmek;
end;

Procedure AssociatePilotMek( LList , Pilot , Mek: GearPtr );
	{ From this point on, MEK is PILOT's mecha. }
	{ Set MEK's pilot attribute and make sure there are no }
	{ duplications on the go. }
var
	dup: GearPtr;	{ Duplication checker. }
begin
	{ If the pilot already has a mek assigned, negate that association. }
	repeat
		dup := FindPilotsMecha( LList , Pilot );
		if dup <> Nil then SetSAtt( dup^.SA , 'pilot <>' );
	until dup = Nil;

	{ If the mek already has a different pilot, so what. It has a }
	{ new one now. Just set the new pilot attribute. }
	SetSAtt( Mek^.SA , 'pilot <'+PilotName(Pilot)+'>' );
end;


Function FindGearScene( Part: GearPtr; GB: GameBoardPtr ): Integer;
	{ Find the scene number of this gear. Return 0 if no scene }
	{ can be found which contains it. }
	{ Note that this function will ignore metascenes. }
var
	it: Integer;
	P2: GearPtr;
begin
	it := 0;

	if Part <> Nil then begin
		{ Move upwards through the tree until either we }
		{ find a scene gear or root level. }
		while ( Part^.Parent <> Nil ) and ( Part^.G <> GG_Scene ) do begin
			Part := Part^.Parent;
		end;

		if Part^.G = GG_Scene then begin
			{ We found the scene, record the ID. }
			it := Part^.S;
		end else if ( GB <> Nil ) and ( GB^.Scene <> Nil ) and ( GB^.Scene^.G = GG_Scene ) then begin
			{ We didn't find a scene, see if the gear }
			{ is on the gameboard. }
			P2 := GB^.Meks;
			it := 0;
			while P2 <> Nil do begin
				if P2 = Part then it := GB^.Scene^.S;
				P2 := P2^.Next;
			end;
		end;
	end;

	FindGearScene := it;
end;


Procedure WriteMap(Map: Location; var F: Text);
	{Write all of the important info in MAP to the file F.}
	{ This procedure is taken more or less verbatim from DeadCold. }
var
	T,C,X: Longint;
	Vis: Boolean;
begin
	{First, a descriptive message.}
	writeln(F,'*** GearHead Location Record ***');

	{Output the terrain of the map, compressed using}
	{run length encoding.}
	T := Map[0].terr;
	C := 0;
	X := 0;
	while X < Length( Map ) do begin
		if Map[ X ].terr = t then begin
			Inc(C);
		end else begin
			writeln(F,C);
			writeln(F,T);
			T := Map[ X ].terr;
			C := 1;
		end;
		Inc( X );
	end;
	{Output the last terrain stretch}
	writeln(F,C);
	writeln(F,T);

	writeln(F,'***');

	{Output the Visibility of the map, again using run}
	{length encoding. Since there are only two possible}
	{values, just flop between them.}
	Vis := False;
	C := 0;
	X := 0;
	while X < Length( Map ) do begin
		if map[ X ].visible = Vis then begin
			Inc(C);
		end else begin
			writeln(F,C);
			Vis := not Vis;
			C := 1;
		end;
		Inc( X );
	end;
	{Output the last terrain stretch}
	writeln(F,C);

end;

Function ReadMap(var F: Text; W,H: Integer ): Location;
	{We're reading the gameboard from disk.}
	{ This procedure is taken more or less verbatim from DeadCold. }
var
	Map: Location;
	MapLength,C,T,X,I: Longint;
	A: String;
	Vis: Boolean;
begin
	{First, get rid of the descriptive message.}
	readln(F,A);

	MapLength := W * H;
	SetLength( Map , MapLength );

	I := 0;
	while I < MapLength do begin
		readln(F,C);	{Read Count}
		readln(F,T);	{Read Terrain}

		{Fill the map with this terrain up to Count.}
		for X := I to ( I + C - 1 ) do begin
			map[ X ].terr := t;
			Inc( I );
		end;
	end;

	{Read the second descriptive label.}
	readln(F,A);

	{Read the visibility data.}
	Vis := False;
	I := 0;
	while I < MapLength do begin
		readln(F,C);	{Read Count}

		{Fill the map with this terrain up to Count.}
		for X := I to ( C + I - 1 ) do begin
			Map[ X ].visible := Vis;
			Inc( I );
		end;

		Vis := not Vis;
	end;

	ReadMap := Map;
end;

Function IsGoodDeploymentSpot( GB: GameBoardPtr; Mek: GearPtr; X,Y: Integer; CheckNoGo: Boolean ): Boolean;
	{ Return TRUE if this is a good spot for MEK, or }
	{ FALSE otherwise. }
var
	it: Boolean;
	T: Integer;
	MF: GearPtr;
begin
	{ First check that the spot is on the map. }
	it := OnTheMap( GB , X , Y );

	{ Next, check to see if the mecha's movement is blocked in this tile. }
	if it and MovementBlocked( Mek , GB , 0 , 0 , X , Y ) then begin
		{ If the tile is blocked, this might just be }
		{ because of Mek's movemode. Try all available }
		{ movement modes for a good one. }
		for T := 1 to NumMoveMode do begin
			if TerrMan[ TileTerrain( GB , X , Y ) ].MMPass[ T ] and ( BaseMoveRate( GB^.Scene , Mek , T ) > 0 ) then begin
				SetNAtt( Mek^.NA , NAG_Action , NAS_MoveMode , T );
				if not MovementBlocked( Mek , GB , 0 , 0 , X , Y ) then Break;
			end;
		end;
		it := not MovementBlocked( Mek , GB , 0 , 0 , X , Y );
	end;

	{ Next, make sure we're not deploying the model on a threshold }
	if it and ( ( Mek^.G <> GG_MetaTerrain ) or ( Mek^.S <> GS_MetaDoor ) ) then begin
		it := TileTerrain( GB , X , Y ) <> TERRAIN_Threshold;
	end;

	{ Finally, check to make sure this isn't a NoGo zone. }
	if it and ( GB^.Scene <> Nil ) and CheckNoGo then begin
		MF := GB^.Scene^.SubCom;
		while MF <> Nil do begin
			if MF^.G = GG_MapFeature then begin
				if ( X >= MF^.Stat[ STAT_XPos ] ) and ( Y >= MF^.Stat[ STAT_YPos ] ) and ( X <= ( MF^.Stat[ STAT_XPos ] + MF^.Stat[ STAT_MFWidth ] ) ) and ( Y <= ( MF^.Stat[ STAT_YPos ] + MF^.Stat[ STAT_MFHeight ] ) ) then begin
					if AStringHasBString( SAttValue( MF^.SA , 'SPECIAL' ) , 'NoGo' ) and ( UpCase( SAttValue( Mek^.SA , 'HOME' ) ) <> UpCase( GearName( MF ) ) )then it := False;
				end;
			end;
			MF := MF^.Next;
		end;
	end;

	IsGoodDeploymentSpot := it;
end;

Procedure GearDownToLowestMM( Mek: GearPtr; GB: GameBoardPtr; X,Y: Integer );
	{ Use the lowest movement mode legal for this terrain. }
var
	T: Integer;
begin
	for T := 1 to NumMoveMode do begin
		if ( BaseMoveRate( Nil , Mek , T ) > 0 ) then begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveMode , T );
			if not IsBlockingTerrainForMM( GB, Mek, TileTerrain( GB , NAttValue( Mek^.NA , NAG_Location , NAS_X ) , NAttValue( Mek^.NA , NAG_Location , NAS_Y ) ), T ) then break;
		end;
	end;
end;

Function FindSpotNearGate( GB: GameBoardPtr; Mek: GearPtr; GNum: Integer ): Point;
	{ First, find the gate whose number we have been given. }
	{ Second, find an empty spot adjacent to the gate. }
	function FindGateAlongPath( Part: GearPtr ): GearPtr;
		{ This is a nice simple non-recursive list search, }
		{ since the gate should be at root level. }
	var
		TheGate: GearPtr;
	begin
		TheGate := Nil;
		while ( Part <> Nil ) and ( TheGate = Nil ) do begin
			if ( Part^.G = GG_MetaTerrain ) and ( Part^.Stat[ STAT_Destination ] = GNum ) then begin
				TheGate := Part;
			end;
			Part := Part^.Next;
		end;
		FindGateAlongPath := TheGate;
	end;
var
	Gate: GearPtr;
	P: Point;
	D,T: Integer;
begin
	{ Search for an appropriate gate. As of GH2, metaterrain is placed }
	{ on the map before anything else, so we should be able to find it if }
	{ it exists. }
	Gate := FindGateAlongPath( GB^.Meks );

	if Gate <> Nil then begin
		{ The gate should have a location defined, since the }
		{ random map generator does that. }
		P.X := NAttValue( Gate^.NA , NAG_Location , NAS_X );
		P.Y := NAttValue( Gate^.NA , NAG_Location , NAS_Y );

		{ Attempt to find an adjacent, nonblocked spot. }
		if Gate^.Stat[ STAT_Pass ] <= -100 then begin
			D := Random( 8 );
			T := 8;
			while ( T > 0 ) and not IsGoodDeploymentSpot( GB , Mek , P.X + AngDir[ D , 1 ] , P.Y + AngDir[ D , 2 ] , False ) do begin
				D := ( D + 1 ) mod 8;
				Dec( T );
			end;
			if ( T > 0 ) and OnTheMap( GB , P.X + AngDir[ D , 1 ] , P.Y + AngDir[ D , 2 ] ) then begin
				P.X := P.X + AngDir[ D , 1 ];
				P.Y := P.Y + AngDir[ D , 2 ];
			end;
		end;
	end else begin
		{ No gate was found. Return a point not on the map. }
		P.X := 0;
		P.Y := 0;
	end;

	FindSpotNearGate := P;
end;

Function FindSpotNearSpot( GB: GameBoardPtr; Mek: GearPtr; X,Y: Integer ): Point;
	{ Find an empty spot adjacent to the point given. }
var
	P: Point;
	T: Integer;
begin
	T := 0;
	repeat
		if T > 100 then begin
			P.X := X + Random( 7 ) - Random( 7 );
			P.Y := Y + Random( 7 ) - Random( 7 );
		end else if T > 50 then begin
			P.X := X + Random( 4 ) - Random( 4 );
			P.Y := Y + Random( 4 ) - Random( 4 );
		end else begin
			P.X := X + Random( 3 ) - Random( 3 );
			P.Y := Y + Random( 3 ) - Random( 3 );
		end;
		inc( T );
	until ( T > 200 ) or IsGoodDeploymentSpot( GB , Mek , P.X , P.Y , True );

	FindSpotNearSpot := P;
end;

Function FindDeploymentSpot( GB: GameBoardPtr; Mek: GearPtr ): Point;
	{ Determine a good starting point for this model. }
	{ A good starting point is one which falls within the model's team's }
	{ deployment zone and which is not blocked to travel by the model. }
	Function FindBuildingSpot( var P: Point ): Boolean;
		{ If placing a building on the map, we'll use a special procedure. }
		{ Try to locate a building-type terrain... right now that's either 44 or 45. }
		{ Replace that with an OpenGround terrain, and set the building there. }
	var
		X,Y,N,T: Integer;
	begin
		{ First count the number of buildings on the map. }
		N := 0;
		for X := 1 to GB^.Map_Width do begin
			for Y := 1 to GB^.Map_Height do begin
				T := TileTerrain( GB , X , Y );
				if ( T = TERRAIN_LowBuilding ) or ( T = TERRAIN_MediumBuilding ) or ( T = TERRAIN_HighBuilding ) then Inc( N );
			end;
		end;

		{ Next, select one at random and place the building we've been given there. }
		if N > 0 then begin
			N := Random( N );
			for X := 1 to GB^.Map_Width do begin
				for Y := 1 to GB^.Map_Height do begin
					T := TileTerrain( GB , X , Y );
					if ( T = TERRAIN_LowBuilding ) or ( T = TERRAIN_MediumBuilding ) or ( T = TERRAIN_HighBuilding ) then begin
						Dec( N );
						if N = -1 then begin
							SetTerrain( GB , X , Y , TERRAIN_OpenGround );
							P.X := X;
							P.Y := Y;
						end;
					end;
				end;
			end;

			FindBuildingSpot := True;
		end else begin
			FindBuildingSpot := False;
		end;
	end;
	Function SeekStartHerePoint( LList: GearPtr ): GearPtr;
		{ Look for a map feature with the SPECIAL type "StartHere". }
	var
		it: GearPtr;
	begin
		it := Nil;
		while ( LList <> Nil ) and ( it = Nil ) do begin
			if ( LList^.G = GG_MapFeature ) and AStringHasBString( SATtValue( LList^.SA , 'SPECIAL' ) , SPECIAL_StartHere ) then it := LList;
			if it = Nil then it := SeekStartHerePoint( LList^.SubCom );
			LList := LList^.Next;
		end;

		SeekStartHerePoint := it;
	end;
var
	Team,Home,THome: GearPtr;
	TeamNum,Tries: Integer;
	P,TP: Point;
	CheckNoGo: Boolean;	{ Model shouldn't be placed in a NoGo zone. }
begin
	{ If this is a building, use the special building placer then exit. }
	if ( Mek^.G = GG_MetaTerrain ) and ( Mek^.S = GS_MetaBuilding ) and FindBuildingSpot( P ) then Exit( P );

	{ Find the team for this model. }
	TeamNum := NAttValue( Mek^.NA , NAG_Location , NAS_Team );

	{ LanceMates count as members of the player team. }
	if TeamNum = NAV_LancemateTeam then TeamNum := NAV_DefPlayerTeam
	else TeamNum := Abs( TeamNum );

	Team := LocateTeam( GB , TeamNum );
	if Team <> Nil then begin
		TP.X := NAttValue( Team^.NA , NAG_ParaLocation , NAS_X );
		TP.Y := NAttValue( Team^.NA , NAG_ParaLocation , NAS_Y );
	end;

	{ Find the home of this model, if appropriate. }
	if ( SAttValue( Mek^.SA , 'HOME' ) <> '' ) and ( GB^.Scene <> Nil ) then begin
		Home := SeekChildByName( GB^.Scene , SAttValue( Mek^.SA , 'HOME' ) );
		{ If no home can be found, erase the home to prevent "wandering items". }
		if Home = Nil then SetSAtt( Mek^.SA , 'HOME <>' );
	{ If we're dealing with the player team, see if there's a STARTHERE map feature. }
	end else if ( TeamNum = NAV_DefPlayerTeam ) and ( GB^.Scene <> Nil ) then begin
		Home := SeekStartHerePoint( GB^.Scene^.SubCom );
	end else begin
		Home := Nil;
	end;

	{ Find the home of this team, if appropriate. }
	if ( Team <> Nil ) and ( SAttValue( Team^.SA , 'HOME' ) <> '' ) and ( GB^.Scene <> Nil ) then begin
		THome := SeekChildByName( GB^.Scene , SAttValue( Team^.SA , 'HOME' ) );
	end else begin
		THome := Nil;
	end;

	{ Attempt to find a good spot in which to deploy this model. }
	{ Just in case the task turns out to be impossible, this procedure }
	{ will give up after 1000 tries. }
	Tries := 1000;
	repeat
		{ Always check the NoGo zones, unless directed otherwise. }
		CheckNoGo := True;

		if ( TeamNum = NAV_DefPlayerTeam ) and OnTheMap( GB , PC_Team_X , PC_Team_Y ) then begin
			P := FindSpotNearSpot( GB , Mek , PC_Team_X , PC_Team_Y );

		end else if ( TeamNum = NAV_DefPlayerTeam ) and ( SCRIPT_Gate_To_Seek <> 0 ) then begin
			P := FindSpotNearGate( GB , Mek , SCRIPT_Gate_To_Seek );
			SCRIPT_Gate_To_Seek := 0;
			CheckNoGo := False;

		end else if ( TeamNum = NAV_DefPlayerTeam ) and ( SCRIPT_Terrain_To_Seek <> 0 ) then begin
			P := FindThisTerrain( GB , SCRIPT_Terrain_To_Seek );
			SCRIPT_Terrain_To_Seek := 0;
			{ If the requested terrain couldn't be found, set X,Y }
			{ to a random location. }
			if P.X = 0 then begin
				P.X := Random( GB^.Map_Width ) + 1;
				P.Y := Random( GB^.Map_Height ) + 1;
			end;

		end else if ( TeamNum = NAV_DefPlayerTeam ) and ( GB^.Scene <> Nil ) and ( NAttValue( GB^.Scene^.NA , NAG_ParaLocation , NAS_X ) <> 0 ) then begin
			P.X := NAttValue( GB^.Scene^.NA , NAG_ParaLocation , NAS_X );
			P.Y := NAttValue( GB^.Scene^.NA , NAG_ParaLocation , NAS_Y );
			SetNAtt( GB^.Scene^.NA , NAG_ParaLocation , NAS_X , 0 );
			SetNAtt( GB^.Scene^.NA , NAG_ParaLocation , NAS_Y , 0 );
			CheckNoGo := False;

		end else if ( NAttValue( Mek^.NA , NAG_ParaLocation , NAS_X ) <> 0 ) and ( Tries > 500 ) then begin
			P.X := NAttValue( Mek^.NA , NAG_ParaLocation , NAS_X ) + Random( 6 ) - Random( 6 );
			P.Y := NAttValue( Mek^.NA , NAG_ParaLocation , NAS_Y ) + Random( 6 ) - Random( 6 );

		end else if ( Home <> Nil ) and ( Tries > 250 ) then begin
			P.X := Random( Home^.Stat[ Stat_MFWidth ] - 2 ) + Home^.Stat[ STAT_XPos ] + 1;
			P.Y := Random( Home^.Stat[ Stat_MFHeight ] - 2 ) + Home^.Stat[ STAT_YPos ] + 1;
			CheckNoGo := False;

		end else if ( THome <> Nil ) and ( Tries > 250 ) then begin
			P.X := Random( THome^.Stat[ Stat_MFWidth ] - 2 ) + THome^.Stat[ STAT_XPos ] + 1;
			P.Y := Random( THome^.Stat[ Stat_MFHeight ] - 2 ) + THome^.Stat[ STAT_YPos ] + 1;
			CheckNoGo := False;

		end else if ( Team <> Nil ) and OnTheMap( GB , TP.X , TP.Y ) and ( Tries > 250 ) then begin
			{ Place somewhere near the deployment area. }
			P.X := TP.X + Random( 5 ) - Random( 5 );
			if P.X < 1 then P.X := 1
			else if P.X > GB^.Map_Width then P.X := GB^.Map_Width;
			P.Y := TP.Y + Random( 5 ) - Random( 5 );
			if P.Y < 1 then P.Y := 1
			else if P.Y > GB^.Map_Height then P.Y := GB^.Map_Height;

		end else if ( TeamNum = 0 ) or ( Team <> NIl ) then begin
			{ Place anywhere randomly on the map. }
			P.X := Random( GB^.Map_Width ) + 1;
			P.Y := Random( GB^.Map_Height ) + 1;

		end else begin
			{ Place in a quadrant depending on team number. }
			TeamNum := Abs( TeamNum );
			if (( TeamNum mod 4 ) mod 2 ) = 1 then begin
				P.X := 1 + Random( GB^.Map_Width div 2 );
			end else begin
				P.X := GB^.Map_Width - Random( GB^.Map_Width div 2 );
			end;
			if (( TeamNum mod 4 ) div 2 ) = 1 then begin
				P.Y := 1 + Random( GB^.Map_Height div 2 );
			end else begin
				P.Y := GB^.Map_Height - Random( GB^.Map_Height div 2 );
			end;
		end;

		dec( Tries );
	until ( Tries < 1 ) or ( OnTheMap( GB , P.X , P.Y ) and IsGoodDeploymentSpot( GB , Mek , P.X , P.Y , CheckNoGo ) );

	SetNAtt( Mek^.NA , NAG_ParaLocation , NAS_X , 0 );
	SetNAtt( Mek^.NA , NAG_ParaLocation , NAS_Y , 0 );

	if ( TeamNum = NAV_DefPlayerTeam ) and ( PC_Team_X = 0 ) and OnTheMap( GB , P.X , P.Y ) then begin
		PC_Team_X := P.X;
		PC_Team_Y := P.Y;
	end;

	FindDeploymentSpot := P;
end;

Procedure RevealMek( GB: GameBoardPtr; Mek,Spotter: GearPtr );
	{ This mek has been spotted. Light it up. }
var
	team: Integer;
begin
	team := NAttValue( Spotter^.NA , NAG_Location , NAS_Team );
	SetNAtt( Mek^.NA , NAG_Visibility , Team , NAV_Spotted );
	if ( Mek^.G = GG_MetaTerrain ) and ( Mek^.S = GS_MetaEncounter ) and ( Team = NAV_DefPlayerTeam ) then begin
		SetNAtt( Mek^.NA ,NAG_EpisodeData , NAS_EncounterVisibility , GB^.ComTime + 301 );
	end;
	Screen_Needs_Redraw := True;
end;

Procedure CheckVisibleArea( GB: GameBoardPtr; Mek: GearPtr );
	{ Expand the visual area around this model. }
var
	P: Point;
	X,Y,MZ,R,Obs: Integer;
begin
	P := GearCurrentLocation( Mek );
	R := MappingRange( Mek , GB^.Scale );
	MZ := MekAltitude( GB , Mek );

	{ Look through every tile within range. If it's on the map and }
	{ not yet revealed, do a check to see if it should be. }
	for X := ( P.X - R ) to ( P.X + R ) do begin
		for Y := ( P.Y - R ) to ( P.Y + R ) do begin
			if OnTheMap( GB , X , Y ) and not TileVisible( GB,X,Y ) then begin
				{ This tile will be revealed if Range + Obscurement }
				{ is less than or equal to the mapping radius. }
				Obs := CalcObscurement( X , Y , TerrMan[ TileTerrain( GB, X , Y ) ].Altitude , P.X , P.Y , MZ , GB );
				if (( Range( P.X , P.Y , X , Y ) + Obs ) <= R ) and ( Obs <> -1 ) then begin
					SetVisibility( GB,X,Y,True );
					Screen_Needs_Redraw := True;
				end;
			end;
		end;
	end;
end;

Function LocateMekByUID( GB: GameBoardPtr; UID: Integer ): GearPtr;
	{ Search through the list of mecha associated with this scenario, and }
	{ return the mecha with the given Unique ID. Return Nil if it can't }
	{ be found. }
begin
	{ Error check - UID 0 is impossible. }
	if UID = 0 then Exit( Nil );

	{ Return whatever we found. }
	LocateMekByUID := SeekGearByIDTag( GB^.Meks , NAG_EpisodeData , NAS_UID , UID );
end;

Procedure DeployGear( GB: GameBoardPtr; Mek: GearPtr; PutOnMap: Boolean );
	{ Stick the provided MEK onto the game board. Assign a UID, }
	{ and set the default orders for MEK's team. }
	{ PRECONDITION: Mek must be unlinked. }
	Procedure SetDirection;
		{ Set a direction for certain things. }
	var
		D: Integer;
	begin
		if ( NAttValue( mek^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) and ( SCRIPT_Gate_to_Seek <> 0 ) then begin
			D := NAttValue( GB^.Scene^.NA , NAG_EntryDirections , SCRIPT_Gate_to_Seek );
			if ( D > 0 ) and ( D <= 8 ) then begin
				SetNAtt( mek^.NA , NAG_Location , NAS_D , D - 1 );
			end else begin
				SetNAtt( mek^.NA , NAG_Location , NAS_D , Random( 8 ) );
			end;
		end else begin
			SetNAtt( mek^.NA , NAG_Location , NAS_D , Random( 8 ) );
		end;
	end;
var
	Team,Pilot: GearPtr;
	P: Point;
begin
	if ( GB = Nil ) or ( Mek = Nil ) then Exit;

	{ Erase any MissionReport attributes still attached to this mek. }
	StripNAtt( Mek , NAG_MissionReport );

	{ We set the direction first. This has to be done before }
	{ FindDeploymentSpot screws up our values. }
	if ( Mek^.G = GG_Character ) or ( Mek^.G = GG_Mecha ) then SetDirection;

	{ Find the team for this model. }
	Team := LocateTeam( GB , NAttValue( Mek^.NA , NAG_Location , NAS_Team ) );

	{ Gear up the mek. }
	if PutOnMap then GearUp( Mek );

	{ Determine the X and Y values for everything. }
	{ If, according to the PutOnMap parameter, we aren't supposed to put }
	{ this model on the map, set X and Y to 0. }
	{ If the model has X and Y already defined within the map boundaries, }
	{ place it on the map at its specified location. }
	{ Otherwise, determine a good spot to place this mek based upon its }
	{ assigned team. }
	if not PutOnMap then begin
		SetNAtt( mek^.NA , NAG_Location , NAS_X , 0 );
		SetNAtt( mek^.NA , NAG_Location , NAS_Y , 0 );

	end else if not( ( SAttValue( Mek^.SA , 'HOME' ) = '' ) and OnTheMap( GB , Mek ) ) then begin
		P := FindDeploymentSpot( GB , Mek );
		SetNAtt( mek^.NA , NAG_Location , NAS_X , P.X );
		SetNAtt( mek^.NA , NAG_Location , NAS_Y , P.Y );

		{ Gear down to the lowest legal movemode. }
		GearDownToLowestMM( Mek , GB , P.X , P.Y );
	end;


	{ Assign a unique ID for this model. }
	SetNAtt( mek^.NA , NAG_EpisodeData, NAS_UID, MaxIdTag( GB^.Meks , NAG_EpisodeData, NAS_UID ) + 1 );
	if mek^.G = GG_Mecha then begin
		{ The pilot also needs a UID. }
		Pilot := LocatePilot( mek );
		if Pilot <> Nil then SetNAtt( pilot^.NA , NAG_EpisodeData, NAS_UID, NAttValue( mek^.NA , NAG_EpisodeData , NAS_UID ) + 1 );
	end;

	{ Stick mek on board. }
	Mek^.Next := gb^.Meks;
	gb^.Meks := Mek;


	{ Set default orders. }
	if Team <> Nil then begin
		SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Orders , Team^.Stat[ STAT_TeamOrders ] );
	end;
end;

Function WorldWrapsX( World: GearPtr ): Boolean;
	{ Return TRUE if this world wraps along the X axis, FALSE if it doesn't. }
begin
	WorldWrapsX := ( ( World^.Stat[ STAT_Wrap ] mod 2 ) = 1 ) and ( World^.Stat[ STAT_MapWidth ] > 0 );
end;

Function WorldWrapsY( World: GearPtr ): Boolean;
	{ Return TRUE if this world wraps along the Y axis, FALSE if it doesn't. }
begin
	WorldWrapsY := ( ( World^.Stat[ STAT_Wrap ] div 2 mod 2 ) = 1 ) and ( World^.Stat[ STAT_MapHeight ] > 0 );
end;

Procedure FixWorldCoords( Scene: GearPtr; var X,Y: Integer );
	{ It's possible for a world map to wrap along the X axis, the Y axis, or both. }
	{ This procedure will make sure that if X,Y is supposed to be on the map, it }
	{ will be. }
begin
	if WorldWrapsX( Scene ) then begin
		if X < 1 then begin
			while X < 1 do X := X + Scene^.Stat[ STAT_MapWidth ];
		end else if X > Scene^.Stat[ STAT_MapWidth ] then begin
			while X > Scene^.Stat[ STAT_MapWidth ] do X := X - Scene^.Stat[ STAT_MapWidth ];
		end;
	end;
	if WorldWrapsY( Scene ) then begin
		if Y < 1 then begin
			while Y < 1 do Y := Y + Scene^.Stat[ STAT_MapHeight ];
		end else if Y > Scene^.Stat[ STAT_MapHeight ] then begin
			while Y > Scene^.Stat[ STAT_MapHeight ] do Y := Y - Scene^.Stat[ STAT_MapHeight ];
		end;
	end;
end;

Function ArcCheck( X0,Y0,D0,X1,Y1,A: Integer ): Boolean;
	{ CHeck that point X1,Y1 falls within Arc A as relative to }
	{ point X0,Y0 with direction D0. }
	{ A is one of the named ARC_* variables: ARC_F90, ARC_F180, or ARC_360. }
var
	OK: Boolean;
begin
	if A = ARC_360 then OK := True
	else if A = ARC_F90 then begin
		if CheckArc( X0 , Y0 , X1 , Y1 , D0 ) or CheckArc( X0 , Y0 , X1 , Y1 , ( D0 + 7 ) mod 8 ) then OK := True
		else OK := False;
	end else begin
		{ ASSERT -> A is ARC_F180 }
		if CheckArc( X0 , Y0 , X1 , Y1 , D0 ) or CheckArc( X0 , Y0 , X1 , Y1 , ( D0 + 7 ) mod 8 ) or CheckArc( X0 , Y0 , X1 , Y1 , ( D0 + 1 ) mod 8 ) or CheckArc( X0 , Y0 , X1 , Y1 , ( D0 + 6 ) mod 8 ) then OK := True
		else OK := False;
	end;

	ArcCheck := OK;
end;

Function IsHidden( Mek: GearPtr ): Boolean;
	{ Return TRUE if Mek has no visibility markers, or FALSE otherwise. }
var
	IH: Boolean;
	Mark: NAttPtr;
begin
	{ Assume TRUE until shown otherwise. }
	IH := True;
	Mark := Mek^.NA;
	while ( Mark <> Nil ) and IH do begin
		if Mark^.G = NAG_Visibility then IH := False;
		Mark := Mark^.Next;
	end;
	IsHidden := IH;
end;

initialization
	Shadow_Map_Update := -1;


end.
