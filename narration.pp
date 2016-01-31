unit narration;
	{ This unit holds utilities for dealing with RPG campaigns and random plots. }
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

	{ PLOT DEFINITION }
	{   G = GG_Plot               }
	{   S = Quest Prototype Index }
	{   V = Dramatic Choice ID    }

	{ MEME DEFINITION      }
	{   G = GG_Meme        }
	{   S = ID Number      }
	{   V = Undefined      }
	{ A Meme is only active when it's a subcom of a root scene. There is an ASL command }
	{ for activating a meme. }

	{ CITYMOOD DEFINITION }
	{  G = GG_CityMood     }
	{  S = Major/Minor     }
	{  V = Number of attached plots }
	{ A mood may also have TYPE and a PLOT_TYPE string attributes. The first modifies the }
	{ type of the city to which the mood is attached. The second determines what sort of plot }
	{ will be loaded by this mood; the default value is *GENERAL. }
	{ The ControllerID for a mood is assigned automatically. }


Const
	GS_MajorMood = 0;
	GS_MinorMood = 1;

	NAG_XXRan = -7;		{ Extra-Extra-Random Plot Generator Data }
	NAS_LoadNextComponent = 0;	{ if =0, load next component. }

	NAS_ComponentID = 5;	{ Each component is assigned an ID number. }
				{ This number is only unique within the scope of the story. }
	NAS_EpisodeNumber = 6;	{ How many episodes have been completed? }
	NAS_LastEpisodeNoted = 7;	{ What was the last episode to get a history note? }

	NAS_DramaticChoice = 8;	{ What choice has the PC made for this episode? }
	NAS_IsDramaticChoicePlot = 9;	{ If nonzero, this plot is part of our DC menu. }
	NAS_DCRSeed = 10;	{ Random value for determining which dramatic choice }
				{ reward to load for the upcoming episode. }
	NAS_DebriefingMsg = 11;

	NAS_XXChar_Motivation = 101;
	NAS_XXChar_Attitude = 102;
	NAS_XXFac_Plan = 103;

	NAG_Completed_DC = -25;	{ Lists the dramatic choices which have been completed. }
		{ S = The dramatic choice being referred to }
		{ V = The result; 1 = Success, -1 = Cancelled + may not be attempted again }

	NAG_ElementID = -9;	{ Used to store ID numbers for plot/story elements. }

	Num_Plot_Elements = 50;	{ Maximum number of plot elements }


	NAG_SubPlotLayerID = -19;	{ Most of the megaplot info is filed under }
	NAG_SubPlotPlotID = -21;	{ "Narrative" in gears.pp, but I figured I'd }
				{ place this here since it's thematically identical }
					{ to the SubQuestLID above. }
	NAG_MasterPlotElementIndex = -20;	{ When combining two plots, this NAtt stores }
					{ the index number of element [S] in the master plot. }
	NAG_PlotStatus = -22;	{ S = Layer ID, V = State for this layer. Just like QuestStatus, below. }

	NAG_MemeData = -17;	{ Used to record certain things about memes. }
		NAS_MemeTimeLimit = 1;	{ Holds the time at which this meme should be deleted. }
					{ If zero, this meme has no time limit. }
		NAS_NumViews = 0;	{ How many times the PC has seen this meme. }
		NAS_MaxMemeViews = 2;	{ How many times should this meme be viewed? Due to the peculiarities of }
					{ the system, the default score (0) is equivalent to 1. }

	NAG_MoodData = -23;	{ Used to record certain things about moods. }
		NAS_MoodTimeLimit = 1;	{ The time at which this mood will be deleted. }


	{ PLOT ELEMENTS }
	{ A plot or a story can have up to 8 elements associated with it. The type of }
	{ element is defined in the string attributes Element1..Element8, and the ID }
	{ number of the element is held in the stats of the source gear. }

	{ Only the first character in the Element# string attribute is needed to tell }
	{ what kind of an element this is. The legal values are: }
	{ "C" = Character, ID number is CID }
	{ "S" = Scene, ID number is scene number }
	{ "F" = Faction, ID number is faction number }
	{ "I" = Item, ID number is NID }
	{       All gears other than characters, scenes, metascenes, and factions are }
	{       treated as items. }

	{ Some additional types are defined for the purposes of element search. }
	{ "M" = Metascene, ID number is metascene ID }
	{       Once an entry point is selected the "M" tag is changed to "S". }
	{ "P" = Prefab; element is defined within the plot/story. }
	{       Once the plot is initialized an appropriate descriptive tag is added. }
	{ "G" = Grab; element ID is taken from source story. }
	{       The grabbed element gains the same descriptive tag as the original. }


	{ These constants describe the standard palette entries for xxran stories. }
	XRP_EnemyChar = 1;		{ E: }
	XRP_EnemyFac = 2;		{ F: }
	XRP_AllyFac = 3;		{ P: }
	XRP_EpisodeScene = 7;		{ L: }
	XRP_TargetItem = 8;		{ I: }

	TRIGGER_StartGame = 'Start';
	TRIGGER_EndGame = 'END';

	{ ArenaHQ Data. Not really narrative, but this is a good place }
	{ to stick it. }
	NAG_AHQData = 27;
		NAS_RewardMissionTimer = 1;	{ Used for spacing out reward missions. }
		NAS_CoreMissionTimer = 2;	{ Used for spacing out core missions. }
		NAS_CoreMissionStep = 3;	{ Records the number of core missions completed. }
		NAS_CoreMissionEnemy = 4;	{ Enemy for the core story. }

	{ The Attitude and Motivation constants, made public so the BeanCounter }
	{ can examine them. }
	Num_XXR_Motivations = 8;
	Num_XXR_Attitudes = 14;
	XXR_Motivation: Array [0..Num_XXR_Motivations] of String[3] = (
		'---',
		'mer', 'pro', 'ggd', 'see', 'rev', 'cha', 'com', 'nih'
	);
	XXR_Attitude: Array [0..Num_XXR_Attitudes] of String[3] = (
		'---',
		'jr_', 'sr_', 'sec', 'equ', 'env',   'pch', 'hat', 'mut', 'obs', 'tha',
		'nme', 'ant', 'adm', 'dis'
	);

	Num_XXR_Plans = 9;
	XXR_Plan: Array [0..Num_XXR_Plans] of String[3] = (
		'---',
		'sub','cat','pil','pat','art',	'gat','wep','war','ina'
	);

Procedure AddXXFactionContext( Fac: GearPtr; var Context: String; palette_entry_code: Char );

Function LancemateCanDevelop( NPC: GearPtr ): Boolean;
Procedure AddXXCharContext( NPC: GearPtr; var Context: String; palette_entry_code: Char );
Function XNPCDesc( GB: GameBoardPtr; Adv,NPC: GearPtr ): String;

Function FindSceneID( Part: GearPtr; GB: GameBoardPtr ): Integer;

Function SeekFaction( Scene: GearPtr; ID: Integer ): GearPtr;
Function GetFactionID( Part: GearPtr ): Integer;
Function FactionIsInactive( Fac: GearPtr ): Boolean;

Function ElementID( Plot: GearPtr; N: Integer ): LongInt;
Function PlotElementID( Plot: GearPtr; Code: Char; ID: LongInt ): Integer;
Function FindMetaPersona( Source: GearPtr; N: Integer ): GearPtr;

Function FindPersonaPlot( Adventure: GearPtr; CID: Integer ): GearPtr;
Function FindPersonaStory( Adventure: GearPtr; CID: Integer ): GearPtr;

Function PersonaInUse( Adventure: GearPtr;  ID: LongInt ): Boolean;
Function PersonaUsedByQuest( Adv, Persona: GearPtr ): Boolean;

Function SeekGearByElementDesc( Adventure: GearPtr; E_Desc: Char; E_ID: Integer; GB: GameBoardPtr ): GearPtr;
Function SeekPlotElement( Adventure , Plot: GearPtr; N: Integer; GB: GameBoardPtr ): GearPtr;
Function PlotUsedHere( Plot: GearPtr; GB: GameBoardPtr ): Boolean;

Function SeekPersona( Scene: GearPtr; CID: LongInt ): GearPtr;
Function SeekPersona( GB: GameBoardPtr; CID: LongInt ): GearPtr;
function SeekGearByCID( LList: GearPtr; CID: LongInt ): GearPtr;

Function FindItemPlot( Adventure: GearPtr; NID: LongInt ): GearPtr;
Function FindItemQuest( City: GearPtr; NID: LongInt ): GearPtr;
Function FindItemStory( Adventure: GearPtr; NID: LongInt ): GearPtr;

Function FindMetascenePlot( Adventure: GearPtr; MSID: LongInt ): GearPtr;
Function FindMetasceneStory( Adventure: GearPtr; MSID: LongInt ): GearPtr;
Function MetaSceneNotInUse( Adventure: GearPtr; MSID: LongInt ): Boolean;
Function FindMetascene( Adventure: GearPtr; MSID: LongInt ): GearPtr;
Function FindSceneEntrance( Adventure: GearPtr; GB: GameBoardPtr; MSID: LongInt ): GearPtr;

Function NewCID( Adventure: GearPtr ): LongInt;
Function NewNID( Adventure: GearPtr ): LongInt;
Function NewMetaSceneID( Adventure: GearPtr ): LongInt;
Function NewSceneID( Adv: GearPtr ): Integer;

Function ElementLocation( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
Function ElementFaction( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
Function ElementName( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): String;

Procedure WriteCampaign( Camp: CampaignPtr; var F: Text );
Function ReadCampaign( var F: Text ): CampaignPtr;

Function TeamDescription( Scene,Team: GearPtr ): String;
Function CreateTeam( Scene: GearPtr; TDesc: String ): GearPtr;
Procedure ChooseTeam( NPC , Scene: GearPtr );
Procedure PutAwayGlobal( GB: GameBoardPtr; var Item: GearPtr );

Function RealSceneID( Scene: GearPtr ): Integer;
Function FindActualScene( Scene: GearPtr; SID: Integer ): GearPtr;
Function FindActualScene( GB: GameBoardPtr; SID: Integer ): GearPtr;
Function IsAScene( S: GearPtr ): Boolean;
Function SceneIsTemp( S: GearPtr ): Boolean;
Function FindRootScene( S: GearPtr ): GearPtr;
Function FindWorld( GB: GameBoardPtr; S: GearPtr ): GearPtr;

Procedure DelinkGearForMovement( GB: GameBoardPtr; GearToBeMoved: GearPtr );

Function KeepPlayingSC( GB: GameBoardPtr ): Boolean;

Procedure RecordFatality( Camp: CampaignPtr; NPC: GearPtr );

Function HasMeritBadge( Adv: GearPtr; Badge: Integer ): Boolean;

implementation

uses texutil,rpgdice,ghchars,gearutil,ability,menugear,ghprop,ghweapon,interact,
{$IFDEF ASCII}
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}

const
	FROZEN_MAP_CONTINUE = 1;
	FROZEN_MAP_SENTINEL = -1;

Procedure AddXXFactionContext( Fac: GearPtr; var Context: String; palette_entry_code: Char );
	{ Add context descriptor for the master plan of this faction. }
var
	T: Integer;
begin
	T := NAttValue( Fac^.NA , NAG_XXRan , NAS_XXFac_Plan );
	if ( T > 0 ) and ( T <= Num_XXR_Plans ) then Context := Context + ' ' + palette_entry_code + ':P.' + XXR_Plan[ t ]
	else Context := Context + ' ' + palette_entry_code + ':P.---';
end;


Function LancemateCanDevelop( NPC: GearPtr ): Boolean;
	{ If this lancemate can learn new skills via the TrainNPC function, }
	{ return TRUE. This is determined by the NAS_LancemateTraining_Total and }
	{ NAS_LancemateTraining_Spent attributes. }
const
	Points_Per_TrainNPC = 11;
begin
	NPC := LocatePilot( NPC );
	if NPC = Nil then Exit( False );
	LancemateCanDevelop := ( ( NAttValue( NPC^.NA , NAG_Narrative , NAS_LancemateTraining_Spent ) + 1 ) * Points_Per_TrainNPC ) < NAttValue( NPC^.NA , NAG_Narrative , NAS_LancemateTraining_Total );
end;

Procedure AddXXCharContext( NPC: GearPtr; var Context: String; palette_entry_code: Char );
	{ Add context descriptors for the attitude and motivation of this NPC. }
var
	T: Integer;
begin
	T := NAttValue( NPC^.NA , NAG_XXRan , NAS_XXChar_Motivation );
	if ( T > 0 ) and ( T <= Num_XXR_Motivations ) then Context := Context + ' ' + palette_entry_code + ':M.' + XXR_Motivation[ t ]
	else Context := Context + ' ' + palette_entry_code + ':M.---';

	T := NAttValue( NPC^.NA , NAG_XXRan , NAS_XXChar_Attitude );
	if ( T > 0 ) and ( T <= Num_XXR_Attitudes ) then Context := Context + ' ' + palette_entry_code + ':A.' + XXR_Attitude[ t ]
	else Context := Context + ' ' + palette_entry_code + ':A.---';

	{ Lancemates may also get a TRAIN tag, if appropriate. }
	if ( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and LancemateCanDevelop( NPC ) then begin
		Context := Context + ' ' + palette_entry_code + ':TRAIN';
	end;
end;

Function XNPCDesc( GB: GameBoardPtr; Adv,NPC: GearPtr ): String;
	{ Extended NPC description. }
	{ If GB = Nil, information about the NPC's plot recharge will not be included. }
var
	it: String;
	Fac,Persona: GearPtr;
	CID,FID: LongInt;
begin
	{ Error check- make sure the adventure really is the adventure. }
	Adv := FindRoot( Adv );

	it := NPCTraitDesc( NPC );
	it := it + ' ' + SAttValue( NPC^.SA , 'JOB_DESIG' );

	AddXXCharContext( NPC , it , '@' );

	Case NAttValue( NPC^.NA , NAG_Relationship , 0 ) of
		NAV_ArchEnemy: it := it + ' NEMESIS';
		NAV_Lover: it := it + ' LOVER';
		NAV_Family: it := it + ' FAMILY';
		NAV_Friend: it := it + ' FRIEND';
		NAV_ArchAlly: it := it + ' LANCEMATE';
	end;
	if IsArchEnemy( Adv, NPC ) then it := it + ' ARCHENEMY';
	if IsArchAlly( Adv, NPC ) then it := it + ' ARCHALLY';

	{ If this NPC is a mission-giver, note that here. }
	if NAttValue( NPC^.NA , NAG_CharDescription , NAS_NonMissionGiver ) = 0 then it := it + ' MISSION';

	CID := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
	Persona := SeekPersona( Adv , CID );
	if ( Persona <> Nil ) and AStringHasBString( SAttValue( Persona^.SA , 'SPECIAL' ) , 'NOPLOTS' ) then it := it + ' INUSE'
	else if PersonaUsedByQuest( Adv , Persona ) then it := it + ' INUSE'
	else if PersonaInUse( Adv , CID ) then it := it + ' INUSE'
	else it := it + ' NOTUSED';

	FID := NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID );
	Fac := SeekFaction( Adv , FID );
	if Fac <> Nil then it := it + ' ' + SATtValue( Fac^.SA , 'DESIG' ) + ' ' + SATtValue( Fac^.SA , 'CONTEXT' )
	else it := it + ' NOFAC';
	if ( FID <> 0 ) and ( FID = NAttValue( Adv^.NA , NAG_Personal , NAS_FactionID ) ) then it := it + ' PCFAC';

	if GB <> Nil then begin
		if GB^.ComTime >= NAttValue( NPC^.NA , NAG_Personal , NAS_PlotRecharge ) then begin
			it := it + ' RECHARGED';
		end;
	end;

	it := QuoteString( it );

	XNPCDesc := it;
end;


Function FindSceneID( Part: GearPtr; GB: GameBoardPtr ): Integer;
	{ Find the scene number of this gear. Return 0 if no scene }
	{ can be found which contains it. Return the metascene ID }
	{ if the scene is a metascene. }
var
	it: Integer;
	Scene: GearPtr;
begin
	it := 0;

	if Part <> Nil then begin
		{ Move upwards through the tree until either we }
		{ find a scene gear or root level. }
		Scene := Part;
		while ( Scene <> Nil ) and not IsAScene( Scene ) do begin
			Scene := Scene^.Parent;
		end;

		{ If we didn't find the scene, maybe this gear is on the gameboard. }
		if Scene = Nil then begin
			if IsFoundAlongTrack( GB^.Meks , FindRoot( Part ) ) then Scene := GB^.Scene;
		end;

		if Scene <> Nil then begin
			it := RealSceneID( Scene );
		end;
	end;

	FindSceneID := it;
end;

Function SeekFaction( Scene: GearPtr; ID: Integer ): GearPtr;
	{ Look for a faction corresponding to the provided ID number. }
	{ Return NIL if no such faction is found. }
var
	F: GearPtr;
begin
	{ Error check. }
	if ( Scene = Nil ) or ( ID = 0 ) then Exit( Nil );

	{ Find the root of SCENE, which should be the ADVENTURE. }
	{ The faction should be located along the invcoms. }
	F := FindRoot( Scene )^.InvCom;
	while ( F <> Nil ) and (( F^.G <> GG_Faction ) or ( F^.S <> ID )) do F := F^.Next;

	{ If the faction was not in the normal place, call the }
	{ heavy-duty and cycle-wasteful search routine. }
	if F = Nil then F := SeekGear( FindRoot( Scene ) , GG_Faction , ID );
	SeekFaction := F;
end;

Function GetFactionID( Part: GearPtr ): Integer;
	{ This function will return the Faction ID associated with }
	{ any given part, if appropriate. }
	{ FOr a faction this will be it's "S" descriptor. }
	{ For anything else, faction affiliation is stored as a NAtt. }
begin
	if Part = Nil then begin
		GetFactionID := 0;
	end else if Part^.G = GG_Faction then begin
		GetFactionID := Part^.S;
	end else begin
		GetFactionID := NAttValue( Part^.NA , NAG_Personal , NAS_FactionID );
	end;
end;

Function FactionIsInactive( Fac: GearPtr ): Boolean;
	{ Return TRUE if this faction has an INACTIVE tag in its }
	{ TYPE string attribute, or FALSE otherwise. }
begin
	FactionIsInactive := AStringHasBString( SATtValue( Fac^.SA , 'TYPE' ) , 'INACTIVE' );
end;

Function ElementID( Plot: GearPtr; N: Integer ): LongInt;
	{ Return the stored ID number for the requested plot element. }
begin
	ElementID := NAttValue( Plot^.NA , NAG_ElementID , N );
end;

Function PlotElementID( Plot: GearPtr; Code: Char; ID: LongInt ): Integer;
	{ Determine which plot element is referred to by the supplied data. }
	{ CODE indicates what kind of gear we're looking for, while ID }
	{ is the identification number that should be listed in the Plot's }
	{ stats. }
	{ If the supplied ID number cannot be found within this plot, }
	{ return 0. }
var
	t,N: Integer;
	EDesc: String;
begin
	N := 0;
	Code := UpCase( Code );

	for t := 1 to Num_Plot_Elements do begin
		if ElementID( Plot , T ) = ID then begin
			EDesc := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			DeleteWhiteSpace( EDesc );

			if ( EDesc <> '' ) and ( UpCase( EDesc[1] ) = Code ) then begin
				N := T;
			end;
		end;
	end;

	PlotElementID := N;
end;

Function FindMetaPersona( Source: GearPtr; N: Integer ): GearPtr;
	{ Locate the replacement persona from this PLOT or STORY. }
begin
	FindMetaPersona := SeekCurrentLevelGear( Source^.SubCom , GG_Persona , N );
end;

Function SeekPlotAlongPath( Part: GearPtr;  Code: Char; ID: LongInt; SeekType: Integer; NeedsPersona: Boolean ): GearPtr;
	{ Seek a gear which uses the specified element along the given }
	{ path. If no such plot is found return Nil. Recursively search }
	{ all active subcomponents. }
var
	it: GearPtr;
begin
	it := Nil;
	while ( Part <> Nil ) and ( it = Nil ) do begin
		if ( Part^.G = SeekType ) and ( PlotElementID( Part , Code , ID ) <> 0 ) then begin
			if NeedsPersona then begin
				if FindMetaPersona( Part , PlotElementID( Part , Code , ID ) ) <> Nil then begin
					it := Part;
				end;
			end else begin
				it := Part;
			end;
		end else if ( Part^.G = GG_Story ) or ( Part^.G = GG_Faction ) then begin
			it := SeekPlotALongPath( Part^.InvCom , Code , ID , SeekType , NeedsPersona );
		end;

		Part := Part^.Next;
	end;
	SeekPlotAlongPath := it;
end;

Function FindPersonaPlot( Adventure: GearPtr; CID: Integer ): GearPtr;
	{ Search all through ADVENTURE looking for a plot which }
	{ involves PERSONA. If no such plot is found, return NIL. }
begin
	{ Plots should be located along Adventure/InvCom. Plots which }
	{ are not located there are probably sub-plots, so they probably }
	{ don't yet have actors assigned. }
	Adventure := FindRoot( Adventure );
	if ( Adventure = Nil ) or ( Adventure^.G <> GG_Adventure ) then begin
		FindPersonaPlot := Nil;
	end else begin
		FindPersonaPlot := SeekPlotAlongPath( Adventure^.InvCom , 'C' , CID , GG_Plot , False );
	end;
end;

Function FindPersonaStory( Adventure: GearPtr; CID: Integer ): GearPtr;
	{ Search all through ADVENTURE looking for a story which }
	{ involves PERSONA. If no such story is found, return NIL. }
begin
	Adventure := FindRoot( Adventure );
	if ( Adventure = Nil ) or ( Adventure^.G <> GG_Adventure ) then begin
		FindPersonaStory := Nil;
	end else begin
		FindPersonaStory := SeekPlotAlongPath( Adventure^.InvCom , 'C' , CID , GG_Story , True );
	end;
end;

Function PersonaInUse( Adventure: GearPtr;  ID: LongInt ): Boolean;
	{ Seek a plot, story, or remnant which uses this Character ID. }
	{ Quests aren't checked, making the title of this particular function misleading. }
	{ I should change that sometime. }
var
	it: Boolean;
begin
	{ Assume FALSE until we find this persona in use. }
	it := False;
	while ( Adventure <> Nil ) and ( not It ) do begin
		if (( Adventure^.G = GG_Plot ) or ( Adventure^.G = GG_Story )) and ( PlotElementID( Adventure , 'C' , ID ) <> 0 ) then begin
			it := True;
		end else if ( Adventure^.G = GG_Story ) or ( Adventure^.G = GG_Faction ) or ( Adventure^.G = GG_Adventure ) then begin
			it := PersonaInUse( Adventure^.InvCom , ID );
		end;

		Adventure := Adventure^.Next;
	end;
	PersonaInUse := it;
end;

Function PersonaUsedByQuest( Adv, Persona: GearPtr ): Boolean;
	{ Return TRUE if PERSONA is being used by a quest, and is still in use by }
	{ that quest. }
begin
	PersonaUsedByQuest := ( Adv <> Nil ) and ( Persona <> Nil ) and ( NAttValue( Persona^.NA , NAG_Narrative , NAS_PlotID ) < 0 ) and ( NAttValue( FindROot( Adv )^.NA , NAG_PlotStatus , NAttValue( Persona^.NA , NAG_Narrative , NAS_PlotID ) ) >= 0 );
end;


Function FindItemPlot( Adventure: GearPtr; NID: LongInt ): GearPtr;
	{ Locate the plot that uses this metascene. }
begin
	FindItemPlot := SeekPlotAlongPath( Adventure^.InvCom , 'I' , NID , GG_Plot , False );
end;

Function FindItemQuest( City: GearPtr; NID: LongInt ): GearPtr;
	{ Locate the plot that uses this metascene. }
begin
	FindItemQuest := SeekPlotAlongPath( City^.SubCom , 'I' , NID , GG_Plot , False );
end;

Function FindItemStory( Adventure: GearPtr; NID: LongInt ): GearPtr;
	{ Locate the story that uses this metascene. }
begin
	FindItemStory := SeekPlotAlongPath( Adventure^.InvCom , 'I' , NID , GG_Story , False );
end;

Function FindMetascenePlot( Adventure: GearPtr; MSID: LongInt ): GearPtr;
	{ Locate the plot that uses this metascene. }
begin
	FindMetascenePlot := SeekPlotAlongPath( Adventure^.InvCom , 'S' , MSID , GG_Plot , False );
end;

Function FindMetasceneStory( Adventure: GearPtr; MSID: LongInt ): GearPtr;
	{ Locate the story that uses this metascene. }
begin
	FindMetasceneStory := SeekPlotAlongPath( Adventure^.InvCom , 'S' , MSID , GG_Story , False );
end;

Function MetaSceneNotInUse( Adventure: GearPtr; MSID: LongInt ): Boolean;
	{ Return TRUE if this metascene is not in use, or FALSE otherwise. }
begin
	MetaSceneNotInUse := ( FindMetascenePlot( Adventure , MSID ) = Nil ) and ( FindMetasceneStory( Adventure , MSID ) = Nil );
end;

Function FindMetascene( Adventure: GearPtr; MSID: LongInt ): GearPtr;
	{ Attempt to locate the metascene referenced by MSID. If no such metascene is }
	{ defined, return NIL, even if the metascene ID is currently assigned to a }
	{ story or plot. }
var
	Plot,MS,T: GearPtr;
	N: Integer;
begin
	MS := Nil;

	{ Find the plot that's using this meta-location ID. }
	Plot := SeekPlotAlongPath( Adventure^.InvCom , 'S' , MSID , GG_Plot , False );

	{ If we found a plot, search it for a MetaScene gear. }
	if Plot <> Nil then begin
		{ This character is featured in a plot. The plot may }
		{ well contain a persona for this character to use }
		{ while the plot is in effect. }
		N := PlotElementID( Plot , 'S' , MSID );

		T := Plot^.SubCom;
		while T <> Nil do begin
			if ( T^.G = GG_MetaScene ) and ( T^.S = N ) then MS := T;	
			T := T^.Next;
		end;
	end;

	FindMetascene := MS;
end;

Function FindQuestscene( LList: GearPtr; QSID: LongInt ): GearPtr;
	{ Attempt to locate the questscene referenced by MSID. Check LList and }
	{ all of its subcoms. }
var
	MS,T: GearPtr;
	N: Integer;
begin
	MS := Nil;

	while ( LList <> Nil ) and ( MS = Nil ) do begin
		if LList^.G = GG_Plot then begin
			N := PlotElementID( LList , 'Q' , QSID );
			if N > 0 then begin
				T := LList^.SubCom;
				while T <> Nil do begin
					if ( T^.G = GG_MetaScene ) and ( T^.S = N ) then MS := T;	
					T := T^.Next;
				end;
			end;
		end;

		if MS = Nil then MS := FindQuestScene( LList^.SubCom , QSID );
		if MS = Nil then MS := FindQuestScene( LList^.InvCom , QSID );

		LList := LList^.Next;
	end;

	FindQuestscene := MS;
end;

Function FindSceneEntrance( Adventure: GearPtr; GB: GameBoardPtr; MSID: LongInt ): GearPtr;
	{ Attempt to find an entrance for this metascene. }
	Function CheckAlongPath( P: GearPtr ): GearPtr;
	var
		it: GearPtr;
	begin
		it := Nil;
		while ( P <> Nil ) and ( it = Nil ) do begin
			if ( P^.G = GG_MetaTerrain ) and ( P^.Stat[ STAT_Destination ] = MSID ) then begin
				it := P;
			end;
			if it = Nil then it := CheckAlongPath( P^.SubCom );
			if it = Nil then it := CheckAlongPath( P^.InvCom );
			P := P^.Next;
		end;
		CheckAlongPath := it;
	end;
var
	it: GearPtr;
begin
	it := CheckAlongPath( Adventure );
	if it = Nil then it := CheckAlongPath( GB^.Meks );
	FindSceneEntrance := it;
end;

Function SeekGearByElementDesc( Adventure: GearPtr; E_Desc: Char; E_ID: Integer; GB: GameBoardPtr ): GearPtr;
	{ Given the element description code and the element ID, locate the gear }
	{ being referenced. }
var
	Part: GearPtr;
begin
	Adventure := FindRoot( Adventure );
	if E_Desc = 'C' then begin
		{ Find a character. }
		Part := SeekGearByCID( Adventure , E_ID );
		if ( Part = Nil ) and ( GB <> Nil ) then Part := SeekGearByCID( GB^.Meks , E_ID );
	end else if E_Desc = 'S' then begin
		{ Find a scene. }
		if GB <> Nil then begin
			Part := FindActualScene( GB , E_ID );
		end else begin
			Part := SeekGear( Adventure , GG_Scene , E_ID );
		end;

	end else if E_Desc = 'Q' then begin
		{ Find a quest scene- this scene probably hasn't been deployed yet. }
		Part := FindQuestScene( FindRoot( Adventure ) , E_ID );

	end else if E_Desc = 'F' then begin
		{ Find a faction. }
		Part := SeekGear( Adventure , GG_Faction , E_ID );

	end else if ( E_Desc = 'I' ) and ( E_ID <> 0 ) then begin
		{ Find an item. }
		Part := SeekGearByIDTag( Adventure , NAG_Narrative , NAS_NID , E_ID );
		if ( Part = Nil ) and ( GB <> Nil ) then Part := SeekGearByIDTag( GB^.Meks , NAG_Narrative , NAS_NID , E_ID );

	end else begin
		Part := Nil;
	end;

	SeekGearByElementDesc := Part;
end;

Function SeekPlotElement( Adventure , Plot: GearPtr; N: Integer; GB: GameBoardPtr ): GearPtr;
	{ Find the gear referred to in the N'th element of PLOT. }
	{ If no such element may be found return Nil. }
var
	Desc: String;
	Part: GearPtr;
begin
	{ Start by locating the element description string. }
	Desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) );

	{ Look for the element in the sensible place, given the }
	{ nature of the string. }
	if Desc = '' then begin
		Part := Nil;
	end else begin
		Part := SeekGearByElementDesc( Adventure , Desc[1] , ElementID( Plot , N ) , GB );
	end;

	{ Return the part that was found. }
	SeekPlotElement := Part;
end;

Function PlotUsedHere( Plot: GearPtr; GB: GameBoardPtr ): Boolean;
	{ See whether or not any of the elements of PLOT are in use on }
	{ this game board or in its associated scene. }
var
	PUH,EH: Boolean;
	T: Integer;
	Desc: String;
begin
	{ Error check - Make sure both the plot and the game board are }
	{ defined. }
	if ( Plot = Nil ) or ( GB = Nil ) then begin
		PlotUsedHere := False;
	end else begin
		{ Assume FALSE, then look for any element that's being used }
		{ on the game board. }
		PUH := False;

		{ Search through all the elements. }
		for t := 1 to NumGearStats do begin
			{ Start by locating the element description string. }
			Desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) ) );

			{ Look for the element in the sensible place, given the }
			{ nature of the string. }
			if Desc = '' then begin
				EH := False;
			end else if Desc[1] = 'C' then begin
				{ Find a character. }
				EH := SeekGearByCID( GB^.Meks , ElementID( Plot , T ) ) <> Nil;
			end else if Desc[1] = 'S' then begin
				{ Find a scene. }
				if GB^.Scene <> Nil then EH := ElementID( Plot , T ) = GB^.Scene^.S
				else EH := False;
			end else if Desc[1] = 'I' then begin
				{ Find an item. }
				EH := SeekGearByIDTag( GB^.Meks , NAG_Narrative , NAS_NID , ElementID( Plot , T ) ) <> Nil;
			end;

			PUH := PUH or EH;
		end;

		{ Return whatever result was found. }
		PlotUsedHere := PUH;
	end;
end;

Function SeekPersona( Scene: GearPtr; CID: LongInt ): GearPtr;
	{ Seek the closest persona gear with the provided Character ID. }
	{ If this NPC is involved in a plot, use the persona gear from }
	{ the plot if one is provided. Otherwise, seek the PERSONA }
	{ in the GB/Scene gear. }
var
	Plot,Persona: GearPtr;
	N: Integer;
begin
	Persona := Nil;

	{ Use the persona located in the character's PLOT, if appropriate. }
	Plot := FindPersonaPlot( FindRoot( Scene ) , CID );
	if Plot <> Nil then begin
		{ This character is featured in a plot. The plot may }
		{ well contain a persona for this character to use }
		{ while the plot is in effect. }
		N := PlotElementID( Plot , 'C' , CID );
		Persona := FindMetaPersona( Plot , N );
	end;

	{ Use the persona from the character's STORY next. }
	if Persona = Nil then begin
		Plot := FindPersonaStory( FindRoot( Scene ) , CID );
		if Plot <> Nil then begin
			N := PlotElementID( Plot , 'C' , CID );
			Persona := FindMetaPersona( Plot , N );
		end;
	end;

	{ Next two places to look - The current scene, and the }
	{ adventure itself. }
	if Persona = Nil then Persona := SeekGear( Scene , GG_Persona , CID );
	if ( Persona = Nil ) and ( CID > Num_Plot_Elements ) then begin
		Scene := FindRootScene( Scene );
		if Scene <> Nil then Persona := SeekGear( Scene , GG_Persona , CID , False );
	end;


	SeekPersona := Persona;
end;

Function SeekPersona( GB: GameBoardPtr; CID: LongInt ): GearPtr;
	{ Call the above procedure with the scene. }
begin
	SeekPersona := SeekPersona( GB^.Scene , CID );
end;

function SeekGearByCID( LList: GearPtr; CID: LongInt ): GearPtr;
	{ Seek a gear with the provided ID. If no such gear is }
	{ found, return NIL. }
begin
	if CID = 0 then Exit( Nil );
	SeekGearByCID := SeekGearByIDTag( LList , NAG_Personal , NAS_CID , CID );
end;

Function NewCID( Adventure: GearPtr ): LongInt;
	{ Determine a new, unique CID for a character being added to the }
	{ campaign. In GH2, all CIDs come from this function, so we don't }
	{ have to worry about searching for any pre-existing CIDs. }
var
	it: LongInt;
begin
	{ Make sure the Adventure really is the Adventure. }
	Adventure := FindRoot( Adventure );

	{ To start with, find the highest ID being used by a character. }
	it := NAttValue( Adventure^.NA , NAG_Narrative , NAS_MaxCID );
	if it = 0 then it := Num_Plot_Elements;

	{ Return the highest value found, +1. }
	SetNAtt( Adventure^.NA , NAG_Narrative , NAS_MaxCID , it + 1 );
	NewCID := it + 1;
end;

Function NewNID( Adventure: GearPtr ): LongInt;
	{ Determine a new, unique NID for an item being added to the }
	{ campaign. Again, all IDs come from this procedure, so don't }
	{ worry about pre-existing values. }
var
	it: LongInt;
begin
	Adventure := FindRoot( Adventure );

	it := NAttValue( Adventure^.NA , NAG_Narrative , NAS_MaxNID );

	{ Return the highest value found, +1. }
	SetNAtt( Adventure^.NA , NAG_Narrative , NAS_MaxNID , it + 1 );
	NewNID := it + 1;
end;

Function NewMetaSceneID( Adventure: GearPtr ): LongInt;
	{ Determine a new, unique ID for a metascene entrance point. }
var
	it: LongInt;
begin
	Adventure := FindRoot( Adventure );
	it := NAttValue( Adventure^.NA , NAG_Narrative , NAS_MinMSID ) - 1;
	if it > -100 then it := -100;
	SetNAtt( Adventure^.NA , NAG_Narrative , NAS_MinMSID , it );
	NewMetaSceneID := it;
end;

Function NewSceneID( Adv: GearPtr ): Integer;
	{ The campaign initialization should have set the maximum scene ID currently }
	{ in use. We'll use that to get a new ID. }
begin
	Adv := FindRoot( Adv );
	AddNAtt( Adv^.NA , NAG_Narrative , NAS_MaxSceneID , 1 );
	NewSceneID := NAttValue( Adv^.NA , NAG_Narrative , NAS_MaxSceneID );
end;


Function ElementLocation( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
	{ Find the scene number where this element resides. If no such }
	{ scene can be found, return 0. }
var
	E: GearPtr;
begin
	E := SeekPlotElement( Adv, Plot, N , GB );
	ElementLocation := FindSceneID( E , GB );
end;

Function ElementFaction( Adv,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): Integer;
	{ Find the scene number where this element resides. If no such }
	{ scene can be found, return 0. }
var
	E: GearPtr;
begin
	E := SeekPlotElement( Adv, Plot, N , GB );

	ElementFaction := GetFactionID( E );
end;

Function ElementName( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr ): String;
	{ Find the name of element N. Return an empty string if no such }
	{ element can be found. }
var
	Desc: String;
	Part: GearPtr;
begin
	Desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) );

	if Desc <> '' then begin
		if ( UpCase( Desc[1] ) = 'S' ) and ( ElementID( Plot , N ) < 0 ) then begin
			Part := FindSceneEntrance( Adventure , GB , ElementID( Plot , N ) );
		end else begin
			Part := SeekPlotElement( Adventure, Plot, N , GB );
		end;

		if Part <> Nil then begin
			{ If this is a metascene, we don't really want the name of the scene }
			{ itself since that's meaningless. Instead, what we really want is the }
			{ name of the entrance to the scene. }
			ElementName := GearName( Part );
		end else begin
			ElementName := '***ERROR***';
		end;
	end else begin
		ElementName := '***NOT DEFINED***';
	end;
end;

Procedure WriteCampaign( Camp: CampaignPtr; var F: Text );
	{ Output the supplied campaign and all appropriate data to disk. }
var
	Frz: FrozenLocationPtr;
begin
	{ Output GameBoard. }
	if Camp^.GB <> Nil then begin
		writeln( F , Camp^.GB^.MAP_Width );
		writeln( F , Camp^.GB^.MAP_Height );
		writeln( F , Camp^.GB^.ComTime );
		writeln( F , Camp^.GB^.Scale );
		WriteMap( Camp^.GB^.Map , F );

		{ Can't output the scene gear directly, since it'll be outputted }
		{ with the rest of SOURCE later on. Output its reference number. }
		writeln( F , FindGearIndex( Camp^.Source , Camp^.GB^.Scene ) );

		{ Output map contents. }
		WriteCGears( F , Camp^.GB^.Meks );
	end else begin
		{ To indicate that there's no gameboard, i.e. that this is }
		{ an arena campaign saved at the HQ, output a 0. Since there's }
		{ no such thing as a map with 0 width, this value will let the }
		{ loader know that there's no gameboard. Also, by working things }
		{ this way, I ensure that save files from previous versions of GH2 }
		{ are still compatable. Am I brilliant or what? }
		writeln( F , '0' );
	end;

	{ Output frozen maps. }
	Frz := Camp^.Maps;
	while Frz <> Nil do begin
		writeln( F , FROZEN_MAP_CONTINUE );
		writeln( F , Frz^.Name );
		writeln( F , Frz^.MAP_Width );
		writeln( F , Frz^.MAP_Height );
		WriteMap( Frz^.Map , F );
		Frz := Frz^.Next;
	end;

	{ Output frozen map sentinel marker. }
	writeln( F , FROZEN_MAP_SENTINEL );

	{ Output SOURCE. }
	WriteCGears( F , Camp^.Source );
end;

Function ReadCampaign( var F: Text ): CampaignPtr;
	{ Input the campaign and all appropriate data from disk. }
var
	Camp: CampaignPtr;
	SceneIndex: LongInt;
	N: Integer;
	Frz: FrozenLocationPtr;
	W,H: Integer;
begin
	{ Allocate the campaign and the gameboard. }
	Camp := NewCampaign;
	readln( F , W );
	if W > 0 then begin
		readln( F , H );
		Camp^.GB := NewMap( W , H );

		Camp^.GB^.MAP_Width := W;
		Camp^.GB^.MAP_Height := H;

		readln( F , Camp^.GB^.ComTime );
		Camp^.ComTime := Camp^.GB^.ComTime;
		readln( F , Camp^.GB^.Scale );
		Camp^.GB^.Map := ReadMap( F , Camp^.GB^.MAP_Width , Camp^.GB^.MAP_Height );

		{ Read the index of this game board's SCENE gear, and }
		{ remember to set it in the GB structure after SOURCE is loaded. }
		readln( F , SceneIndex );

		{ Read the list of map contents. }
		Camp^.GB^.Meks := ReadCGears( F );

	end else begin
		{ If W=0, this implies that we don't actually have a gameboard. }
		{ Load the rest of the file anyways. }
		Camp^.GB := Nil;
		Camp^.ComTime := 0;
	end;

	{ Read the frozen maps. }
	repeat
		ReadLn( F , N );

		if N = FROZEN_MAP_CONTINUE then begin
			Frz := CreateFrozenLocation( Camp^.Maps );
			ReadLn( F , Frz^.Name );
			ReadLn( F , Frz^.MAP_Width );
			ReadLn( F , Frz^.MAP_Height );
			Frz^.Map := ReadMap( F , Frz^.MAP_Width , Frz^.MAP_Height );
		end;
	until N = FROZEN_MAP_SENTINEL;

	{ Read the source, and set the gameboard's scene. }
	Camp^.Source := ReadCGears( F );
	{ Only set the scene if we have a gameboard. It's possible that we don't. }
	if Camp^.GB <> Nil then Camp^.GB^.Scene := LocateGearByNumber( Camp^.Source , SceneIndex );

	{ Return the restored campaign structure. }
	ReadCampaign := Camp;
end;

Function TeamDescription( Scene,Team: GearPtr ): String;
	{ Create a description for this team. This is to be used }
	{ by the team location routines. }
var
	it: String;
begin
	{ Start with an empty string. }
	it := '';

	if Team <> Nil then begin
		if AreEnemies( Scene, Team^.S , NAV_DefPlayerTeam ) then begin
			it := it + ' enemy';
		end else if AreAllies( Scene , Team^.S , NAV_DefPlayerTeam ) then begin
			it := it + ' ally';
		end;

		it := it + ' ' + AI_Type_Label[ Team^.Stat[ STAT_TeamOrders ] ];

		if Team^.Stat[ STAT_WanderMon ] > 0 then it := it + ' wmon';
	end;

	TeamDescription := it;
end;

Function CreateTeam( Scene: GearPtr; TDesc: String ): GearPtr;
	{ Make a new team corresponding to the description provided. }
var
	Team: GearPtr;
	CMD: String;
	T: Integer;
begin
	Team := NewGear( Nil );
	Team^.G := GG_Team;
	Team^.S := NewTeamID( Scene );
	InsertSubCom( Scene , Team );

	{ Set the new team's attributes based upon the remainder of }
	{ the PLACE string. }
	TDesc := UpCase( TDesc );
	while TDesc <> '' do begin
		cmd := ExtractWord( TDesc );

		if cmd = 'ENEMY' then begin
			SetNAtt( Team^.NA , NAG_SideReaction , NAV_DefPlayerTeam , NAV_AreEnemies );
		end else if cmd = 'ALLY' then begin
			SetNAtt( Team^.NA , NAG_SideReaction , NAV_DefPlayerTeam , NAV_AreAllies );

		end else begin
			{ This command may be an AIType. }
			for t := 0 to NumAITypes do begin
				if cmd = AI_Type_Label[ t ] then Team^.Stat[ STAT_TeamOrders ] := t;
			end;
		end;
	end;

	CreateTeam := Team;
end;

Function FindMatchingTeam( Scene: GearPtr; TDesc: String ): GearPtr;
	{ Locate a team which matches the provided description. }
	{ If no such team can be found, return Nil. If more than }
	{ one team is found, return one of them, although there's }
	{ no guarantee which one. }
var
	T,it: GearPtr;
begin
	{ Teams are located as root subcomponents of the scene, }
	{ so look there. }
	T := Scene^.SubCom;

	{ Initialize our search bit to NIL. }
	it := Nil;

	while ( T <> Nil ) and ( it = Nil ) do begin
		if ( T^.G = GG_Team ) and ( T^.S <> NAV_DefPlayerTeam ) and PartMatchesCriteria( TeamDescription( Scene , T ) , TDesc ) then begin
			it := T;
		end;

		T := T^.Next;
	end;

	FindMatchingTeam := it;
end;

Procedure ChooseTeam( NPC , Scene: GearPtr );
	{ Find a team which matches the NPC's needs. }
var
	TeamData: String;
	Team: GearPtr;
begin
	TeamData := SAttValue( NPC^.SA , 'TEAMDATA' );

	{ If we have no teamdata, and the NPC is a prop, just set it to }
	{ team zero. }
	if ( TeamData = '' ) and ( NPC^.G = GG_Prop ) then begin
		SetNAtt( NPC^.NA , NAG_Location , NAS_Team , 0 );

	end else begin
		Team := FindMatchingTeam( Scene , TeamData );

		{ If no matching team was found, create a new team. }
		if Team = Nil then begin
			Team := CreateTeam( Scene , TeamData );
		end;

		{ Store the correct team number in the NPC. }
		SetNAtt( NPC^.NA , NAG_Location , NAS_Team , Team^.S );
	end;
end;


Procedure PutAwayGlobal( GB: GameBoardPtr; var Item: GearPtr );
	{ ITEM is a global gear. It belongs somewhere other than it is. }
	{ IMPORTANT: GB, GB^.SCene, and Item are all defined. }
var
	SID: Integer;
	Scene: GearPtr;
begin
	{ Find this gear's original home scene. }
	SID := NAttValue( Item^.NA , NAG_ParaLocation , NAS_OriginalHome );

	{ Erase the original home data, since we're sending it home now. }
	{ If the gear gets moved again its original home data should be }
	{ reset. }
	SetNAtt( Item^.NA , NAG_ParaLocation , NAS_OriginalHome , 0 );

	{ Put it away there. }
	if SID > 0 then begin
		Scene := FindActualScene( GB , SID );
	end else begin
		Scene := Nil;
	end;

	if Scene <> Nil then begin
		InsertInvCom( Scene , Item );

		{ If inserting a character, better choose a team. }
		if IsMasterGear( Item ) then begin
			ChooseTeam( Item , Scene );
		end;

	end else if GB^.SCene <> Nil then begin
		InsertInvCom( FindRoot( GB^.Scene ) , Item );

	end else begin
		DisposeGear( Item );

	end;
end;

Function RealSceneID( Scene: GearPtr ): Integer;
	{ Given SCENE, return its actual ID value. If this is a MetaScene, }
	{ we have to check its plot. }
var
	it: Integer;
begin
	if ( Scene^.G = GG_MetaScene ) and ( Scene^.Parent <> Nil ) and ( Scene^.Parent^.G = GG_Plot ) and IsSubCom( Scene ) and ( Scene^.S >= 1 ) and ( Scene^.S <= Num_Plot_Elements ) then begin
		it := ElementID( Scene^.Parent , Scene^.S );
	end else if ( Scene^.G = GG_MetaScene ) or IsSubCom( Scene ) then begin
		it := Scene^.S;
	end else begin
		it := 0;
	end;
	RealSceneID := it;
end;

Function FindActualScene( Scene: GearPtr; SID: Integer ): GearPtr;
	{ Find the ACTUAL scene with the specified ID, as opposed to any }
	{ temporary scenes which may have the same value. }
	function LookForScene( S: GearPtr ): GearPtr;
		{ Look for the requested scene along this path, }
		{ checking subcoms as well. }
	var
		it: GearPtr;
	begin
		it := Nil;
		while ( S <> Nil ) and ( it = Nil ) do begin
			if ( ( S^.G = GG_Scene ) or ( S^.G = GG_World ) ) and ( S^.S = SID ) then it := S;
			if it = Nil then it := LookForScene( S^.SubCom );
			S := S^.Next;
		end;
		LookForScene := it;
	end;
var
	Part: GearPtr;
begin
	if Scene = Nil then Exit( Nil );
	Scene := FindRoot( Scene );
	Part := Nil;
	if SID > 0 then begin
		Part := LookForScene( Scene );
	end else if SID < 0 then begin
		Part := FindMetascene( Scene , SID );
	end;
	FindActualScene := Part;
end;

Function FindActualScene( GB: GameBoardPtr; SID: Integer ): GearPtr;
	{ Find the ACTUAL scene with the specified ID, as opposed to any }
	{ temporary scenes which may have the same value. }
begin
	FindActualScene := FindActualScene( GB^.Scene , SID );
end;

Function IsAScene( S: GearPtr ): Boolean;
	{ Return TRUE if S is a scene or metascene, or FALSE otherwise. }
begin
	IsAScene := ( S <> Nil ) and ( ( S^.G = GG_Scene ) or ( S^.G = GG_MetaScene ) );
end;

Function SceneIsTemp( S: GearPtr ): Boolean;
	{ Return TRUE if S is a temporary scene. These include: }
	{ - Metascenes }
	{ - Dynamic Scenes }
begin
	SceneIsTemp := ( S = Nil ) or ( S^.G = GG_MetaScene ) or IsInvCom( S );
end;

Function FindRootScene( S: GearPtr ): GearPtr;
	{ Return the root scene of S. If no root is found, return Nil. }
	{ S should be a scene or metascene connected to the adventure; otherwise, }
	{ expect an error. }
begin
	if S = Nil then Exit( Nil );
	if ( S^.G = GG_MetaScene ) and ( NAttValue( S^.NA , NAG_Narrative , NAS_EntranceScene ) <> 0 ) then S := FindActualScene( FindRoot( S ) , NAttValue( S^.NA , NAG_Narrative , NAS_EntranceScene ) )
	else if IsInvCom( S ) then S := FindActualScene( FindRoot( S ) , S^.S );
	while ( S <> Nil ) and not ( ( S^.Parent <> Nil ) and ( S^.Parent^.G <> GG_Scene ) ) do begin
		S := S^.Parent;
	end;
	FindRootScene := S;
end;

Function FindWorld( GB: GameBoardPtr; S: GearPtr ): GearPtr;
	{ Find the world this scene belongs to. }
	{ If no world can be found, return Nil. }
begin
	{ First, find the city this scene belongs to. That should make things easier. }
	S := FindRootScene( S );
	while ( S <> Nil ) and ( S^.G <> GG_World ) do begin
		S := S^.Parent;
	end;
	FindWorld := S;
end;

Procedure DelinkGearForMovement( GB: GameBoardPtr; GearToBeMoved: GearPtr );
	{ Delink the provided gear in preparation for movement to somewhere else. }
var
	Scene,Master: GearPtr;
	SceneID,TID: Integer;
begin
	if NAttValue( GearToBeMoved^.NA , NAG_ParaLocation , NAS_OriginalHome ) = 0 then begin
		SceneID := FindSceneID( GearToBeMoved , GB );
		Scene := FindActualScene( GB , SceneID );
		TID := NAttValue( GearToBeMoved^.NA , NAG_Location , NAS_Team );

		if ( SceneID > 0 ) and ( SCene <> Nil ) then begin
			{ Record team description. }
			SetSATt( GearToBeMoved^.SA , 'TEAMDATA <' + TeamDescription( Scene, LocateTeam( Scene , TID ) ) + '>' );

			{ Record the item's orginal home, if not already done. }
			SetNAtt( GearToBeMoved^.NA , NAG_ParaLocation , NAS_OriginalHome , Scene^.S );
		end else begin
			SetNAtt( GearToBeMoved^.NA , NAG_ParaLocation , NAS_OriginalHome , -1 );
		end;
	end;

	{ Locate the root, if possible. }
	Master := FindRoot( GearToBeMoved );

	{ Delink the gear, if it can be found. }
	if IsSubCom( GearToBeMoved ) then begin
		DelinkGear( GearToBeMoved^.Parent^.SubCom , GearToBeMoved );
	end else if IsInvCom( GearToBeMoved ) then begin
		DelinkGear( GearToBeMoved^.Parent^.InvCom , GearToBeMoved );
	end else if IsFoundAlongTrack( GB^.Meks , GearToBeMoved) then begin
		DelinkGear( GB^.Meks , GearToBeMoved );
	end;

	{ If the root of the gear is on the map, is a mecha, and is temporary, }
	{ get rid of that now. }
	if ( Master <> GearToBeMoved ) and ( GB <> Nil ) and IsFoundAlongTrack( GB^.Meks , Master ) and ( NAttValue( Master^.NA , NAG_EpisodeData , NAS_Temporary ) <> 0 ) then begin
		RemoveGear( GB^.Meks , Master );
	end;

	{ Remove attributes of the current area. }
	StripNAtt( GearToBeMoved , NAG_Location );
	StripNAtt( GearToBeMoved , NAG_Damage );
	StripNAtt( GearToBeMoved , NAG_WeaponModifier );
	StripNAtt( GearToBeMoved , NAG_Condition );
	StripNAtt( GearToBeMoved , NAG_StatusEffect );
end;

Function KeepPlayingSC( GB: GameBoardPtr ): Boolean;
	{ Check out this scenario and decide whether or not to keep }
	{ playing. Right now, combat will continue as long as there }
	{ is at least one active mek on each team. }
var
	PTeam,ETeam: Integer;		{ Player Team , Enemy Team }
begin
	{ If this scenario is being controlled by a SCENE gear, }
	{ control of when to quit will be handled by the event strings. }
	{ Also, if we have received a QUIT order, stop playing. }

	if gb^.Scene <> Nil then KeepPlayingSC := Not gb^.QuitTheGame
	else if gb^.QuitTheGame then KeepPlayingSC := False
	else begin

		{ Determine the number of player mecha and enemy mecha. }
		PTeam := NumActiveMasters( GB , NAV_DefPlayerTeam );
		ETeam := NumActiveMasters( GB , NAV_DefEnemyTeam );

		KeepPlayingSC := ( PTeam > 0 ) and ( ETeam > 0 );
	end;
end;

Procedure RecordFatality( Camp: CampaignPtr; NPC: GearPtr );
	{ This character has died, and is about to be removed from the campaign. }
	{ Record the death, and also record any special things about this NPC. }
var
	Relationship: Integer;
begin
	AddNAtt( Camp^.Source^.NA , NAG_Narrative , NAS_TotalFatalities , 1 );
	Relationship := NAttValue( NPC^.NA , NAG_Relationship , 0 );
	case Relationship of
		NAV_Family: 	AddNAtt( Camp^.Source^.NA , NAG_Narrative , NAS_FamilyFatalities , 1 );
		NAV_Lover: 	AddNAtt( Camp^.Source^.NA , NAG_Narrative , NAS_LoverFatalities , 1 );
		NAV_Friend:	AddNAtt( Camp^.Source^.NA , NAG_Narrative , NAS_FriendFatalities , 1 );
	end;
	Relationship := NAttValue( NPC^.NA , NAG_Location , NAS_Team );
	if ( Relationship = NAV_DefPlayerTeam ) or ( Relationship = NAV_LancemateTeam ) then begin
		AddNAtt( Camp^.Source^.NA , NAG_Narrative , NAS_LancemateFatalities , 1 );
	end;
end;

Function HasMeritBadge( Adv: GearPtr; Badge: Integer ): Boolean;
	{ Return TRUE if the current PC has the requested merit badge or its }
	{ equivalent ability, FALSE if not. }
begin
	Adv := FindRoot( Adv );
	HasMeritBadge := NAttValue( Adv^.NA , NAG_MeritBadge , Badge ) <> 0;
end;

end.
