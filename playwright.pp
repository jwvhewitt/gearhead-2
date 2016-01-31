unit playwright;
	{ This unit handles the insertion of random plots. }
	{ It has a lot of procedures for selecting random elements from the }
	{ adventure based on criteria provided by the plot to be inserted. }
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

uses gears,locale,mpbuilder;

	{ G = GG_Plot                            }
	{ S = ID Number (not nessecarily unique) }
	{ v0.240 - Elements are stored as numeric attributes }

const
	GS_XRanStory = 1;

	NAG_ArenaMissionInfo = 20;
		NAS_PayRate = 1;	{ Determines how much money the unit will earn upon }
					{ completing the mission. }
		NAS_Pay = 2;		{ Holds the actual calculated pay value. }
		NAS_IsCoreMission = 3;	{ If nonzero, this is a core mission. }


var
	persona_fragments: GearPtr;
	Standard_Plots,Standard_Moods: GearPtr;
	Dramatic_Choices: GearPtr;


Procedure BuildMegalist( Dest: GearPtr; AddOn: SAttPtr );
Function SceneContext( GB: GameBoardPtr; Scene: GearPtr ): String;


Function SceneDesc( Scene: GearPtr ): String;

Function NumFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
Function FindFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; Num: Integer ): GearPtr;

Function SearchForScene( Adventure , Plot: GearPtr; GB: GameBoardPtr; Desc: String ): GearPtr;


Procedure AddGearXRContext( GB: GameBoardPtr; Adv,Part: GearPtr; var Context: String; palette_entry_code: Char );
Procedure AddElementContext( GB: GameBoardPtr; Story: GearPtr; var Context: String; palette_entry_code: Char; Element_Num: Integer );
Function StoryContext( GB: GameBoardPtr; Story: GearPtr ): String;

Function SeekUrbanArea( RootScene: GearPtr ): GearPtr;
Procedure InsertPFrags( Plot,Persona: GearPtr; const Context: String; ID: Integer );
Procedure PrepAllPersonas( Adventure,Plot: GearPtr; GB: GameBoardPtr; MinID: Integer );
Procedure PrepMetaScenes( Adventure,Plot: GearPtr; GB: GameBoardPtr );

Function PersonalContext( Adv,NPC: GearPtr ): String;
Function DifficulcyContext( Threat: Integer ): String;

Function InsertStory( Slot,Story: GearPtr; GB: GameBoardPtr ): Boolean;
Function InsertSubPlot( Scope,Slot,SubPlot: GearPtr; GB: GameBoardPtr ): Boolean;
Function InsertPlot( Scope,Slot,Plot: GearPtr; GB: GameBoardPtr; Threat: Integer ): Boolean;
Function InsertMood( City,Mood: GearPtr; GB: GameBoardPtr ): Boolean;

Function InsertRSC( Source,Frag: GearPtr; GB: GameBoardPtr ): Boolean;
Procedure EndPlot( GB: GameBoardPtr; Adv,Plot: GearPtr );

Function AddRandomPlot( GB: GameBoardPtr; Slot: GearPtr; Context: String; EList: ElementTable; Threat: Integer ): Boolean;

Procedure PrepareNewComponent( Story: GearPtr; GB: GameBoardPtr );

Function InsertArenaMission( Source,Mission: GearPtr; ThreatAtGeneration: Integer ): Boolean;

Procedure UpdatePlots( GB: GameBoardPtr; Renown: Integer );
Procedure UpdateMoods( GB: GameBoardPtr );

Procedure CreateChoiceList( GB: GameBoardPtr; Story: GearPtr );
Procedure ClearChoiceList( Story: GearPtr );


implementation

uses 	ui4gh,rpgdice,texutil,gearutil,interact,ability,gearparser,ghchars,narration,ghprop,
	arenascript,chargen,wmonster,
{$IFDEF ASCII}
	vidgfx,vidmenus;
{$ELSE}
	sdlgfx,sdlmenus;
{$ENDIF}

Type
	PWSearchResult = Record
		thing: GearPtr;
		match: Integer;
	end;

var
	Fast_Seek_Element: Array [0..1,1..Num_Plot_Elements] of GearPtr;

Procedure BuildMegalist( Dest: GearPtr; AddOn: SAttPtr );
	{ Combine the scripts listed in ADDON into LLIST. }
	{ If a script with the same label already exists in LLIST, the new }
	{ script from ADDON supercedes it, while the old script gets moved to }
	{ a new label. }
var
	SPop,Key,Current: String;
	SPopSA: SAttPtr;
begin
	SPop := 'na';
	while AddOn <> Nil do begin
		{ If there's currently a SAtt in the megalist with this }
		{ key, it has to be "pushed" to a new position. }
		Key := UpCase( RetrieveAPreamble( AddOn^.Info ) );
		if ( Key <> 'REQUIRES' ) and ( Key <> 'DESC' ) and ( Key <> 'DESIG' ) and ( Key <> 'SPECIAL' )
					 and not ( HeadMatchesString( 'ELEMENT' , Key ) or HeadMatchesString( 'TEAM' , Key ) or HeadMatchesString( 'CONTENT' , Key ) or HeadMatchesString( 'CONTEXT' , Key )
					 or HeadMatchesString( 'MINIMAP' , Key ) or HeadMatchesString( 'QUEST' , Key ) or HeadMatchesString( 'SCENE' , Key ) or HeadMatchesString( 'NAME' , Key )
					 or HeadMatchesString( 'PLACE' , Key ) ) then begin
			Current := AS_GetString( Dest , Key );

			if Current <> '' then begin
				SPopSA := AddSAtt( Dest^.SA , Key , Current );
				SPop := RetrieveAPreamble( SPopSA^.Info );
			end else begin
				SPop := 'na';
			end;

			ReplacePat( AddOn^.Info , '%pop%' , SPop );
			SetSAtt( Dest^.SA , AddOn^.Info );
		end;

		AddOn := AddOn^.Next;
	end;
end;

Function SeekDramaticChoice( N: Integer ): GearPtr;
	{ Return a pointer to Dramatic Choice N. }
	{ If no such choice can be found, return NIL. }
var
	C: GearPtr;
begin
	C := Dramatic_Choices;
	while ( C <> Nil ) and ( C^.V <> N ) do C := C^.Next;
	SeekDramaticChoice := C;
end;

Function SceneContext( GB: GameBoardPtr; Scene: GearPtr ): String;
	{ Return a string describing the context of this scene. }
var
	CType,TType: String;
	C: GearPtr;
begin
	CType := SAttValue( Scene^.SA , 'CONTEXT' ) + ' ' + SATtValue( Scene^.SA , 'DESIG' ) + ' ' + SAttValue( Scene^.SA , 'TYPE' );
	TType := SAttValue( Scene^.SA , 'TERRAIN' );
	if TType = '' then TType := 'GROUND';
	CType := CType + ' ' + TType;
	if ( Scene^.G = GG_Scene ) and IsSubCom( Scene ) then CType := CType + ' STATIC'
	else CType := CType + ' DYNAMIC';

	{ Add the faction context. }
	C := SeekFaction( FindRoot( Scene ) , NAttValue( Scene^.NA , NAG_Personal , NAS_FactionID ) );
	if C <> Nil then AddTraits( CType , SAttValue( C^.SA , 'DESIG' ) )
	else AddTraits( CType , 'NOFAC' );

	{ Next add the data for the city we're located in, its faction, and the }
	{ world that it's located in. }
	C := FindRootScene( Scene );
	if C <> Nil then begin
		if C <> Scene then AddTraits( CType , SAttValue( C^.SA , 'DESIG' ) );
		AddTraits( CType , SAttValue( C^.SA , 'PERSONATYPE' ) );
		C := SeekFaction( FindRoot( Scene ) , NAttValue( C^.NA , NAG_Personal , NAS_FactionID ) );
		if C <> Nil then AddTraits( CType , SAttValue( C^.SA , 'DESIG' ) );
		C := FindRootScene( Scene )^.Parent;
		if ( C <> Nil ) and ( C^.G = GG_World ) then begin
			AddTraits( CType , SAttValue( C^.SA , 'DESIG' ) );
		end;
	end;
	SceneContext := CType;
end;


Function FilterElementDescription( var IDesc: String ): String;
	{ Given this element description, break it up into the }
	{ intrinsic and relative description strings. }
	{ Note that the tag "NEVERFAIL" is edited out at this stage. }
var
	ZeroDesc,cmd,RDesc: String;
begin
	ZeroDesc := IDesc;
	RDesc := '';
	IDesc := '';

	while ZeroDesc <> '' do begin
		cmd := ExtractWord( ZeroDesc );

		if ( cmd <> '' ) and ( cmd[1] = '!' ) then begin
			RDesc := RDesc + ' ' + cmd;

			{ If this relative command requires a value, }
			{ copy that over as well. }
			{ The two that don't are !Global and !Lancemate. }
			if ( UpCase( cmd )[2] <> 'G' ) and ( UpCase( cmd )[2] <> 'L' ) then begin
				cmd := ExtractWord( ZeroDesc );
				RDesc := RDesc + ' ' + cmd;
			end;

		end else if ( cmd <> '' ) and ( UpCase( cmd ) <> 'NEVERFAIL' ) then begin
			IDesc := IDesc + ' ' + cmd;

		end;

	end;

	FilterElementDescription := RDesc;
end;

Function GetFSE( N: Integer ): GearPtr;
	{ Get the FastSeekElement requested. }
begin
	if N > 0 then begin
		GetFSE := Fast_Seek_Element[ 1 , N ]
	end else begin
		GetFSE := Fast_Seek_Element[ 0 , Abs( N ) ];
	end;
end;

Function GetFSEID( Story , Plot: GearPtr; N: Integer ): Integer;
	{ Return the ID of the FSE listed. }
begin
	if N > 0 then begin
		GetFSEID := ElementID( Plot , N );
	end else if Story <> Nil then begin
		GetFSEID := ElementID( Story , N );
	end else begin
		GetFSEID := 0;
	end;
end;

Function PWAreEnemies( Adv, Part: GearPtr; N: Integer ): Boolean;
	{ Return TRUE if the faction of element N is an enemy of the }
	{ faction of PART. }
var
	Fac: GearPtr;
	F0,F1: Integer;
begin
	F0 := GetFactionID( GetFSE( N ) );
	F1 := GetFactionID( Part );

	{ A faction is never its own enemy. }
	if F0 = F1 then Exit( False );

	Fac := SeekFaction( Adv , F1 );

	if Fac <> Nil then begin
		PWAreEnemies := NAttValue( Fac^.NA , NAG_FactionScore , F0 ) < 0;
	end else begin
		PWAreEnemies := False;
	end;
end;

Function PWAreAllies( Adv, Part: GearPtr; N: Integer ): Boolean;
	{ Return TRUE if the faction of element N is an ally of the }
	{ faction of PART. }
var
	Fac: GearPtr;
	F0,F1: Integer;
begin
	F0 := GetFactionID( GetFSE( N ) );
	F1 := GetFactionID( Part );

	{ A faction is always allied with itself. }
	if F0 = F1 then Exit( True );

	Fac := SeekFaction( Adv , F1 );

	if Fac <> Nil then begin
		PWAreAllies := NAttValue( Fac^.NA , NAG_FactionScore , F0 ) > 0;
	end else begin
		PWAreAllies := False;
	end;
end;

Function PartMatchesRelativeCriteria( Adv,Plot,Part: GearPtr; GB: GameBoardPtr; Desc: String ): Boolean;
	{ Return TRUE if the part matches the relative criteria }
	{ provided, or FALSE if it does not. }
var
	it: Boolean;
	cmd: String;
	Q: Char;
begin
	{ Assume TRUE unless shown otherwise. }
	it := True;

	{ Lancemates can only be selected if they're asked for by the plot. }
	if AStringHasBString( Desc , '!LANCEMATE' ) then it := ( Part^.G = GG_Character ) and ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam )
	else it := ( NAttValue( Part^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam );

	{ Check all the bits in the description string. }
	While ( Desc <> '' ) and it do begin
		Cmd := ExtractWord( Desc );
		if Cmd <> '' then begin
			DeleteFirstChar( cmd );
			Q := UpCase( cmd )[ 1 ];

			if ( Q = 'N' ) and ( Plot <> Nil ) then begin
				{ L1 must equal L2. }
				it := it and ( FindRootScene( FindActualScene( GB , FindSceneID( Part , GB ) ) ) = FindRootScene( FindActualScene( GB , FindSceneID( GetFSE( ExtractValue( Desc ) ) , GB ) ) ) );

			end else if ( Q = 'F' ) and ( Plot <> Nil ) then begin
				{ L1 must not equal L2. }
				it := it and ( FindRootScene( FindActualScene( GB , FindSceneID( Part , GB ) ) ) <> FindRootScene( FindActualScene( GB , FindSceneID( GetFSE( ExtractValue( Desc ) ) , GB ) ) ) );

			end else if Q = 'M' then begin
				{ MEMBER. This part must belong to the }
				{ requested faction. }
				it := it and ( GetFactionID( Part ) = ExtractValue( Desc ) );

			end else if ( Q = 'C' ) and ( Plot <> Nil ) then begin
				{ COMRADE. This part must belong to the }
				{ same faction as the requested element. }
				it := it and ( GetFactionID( GetFSE( ExtractValue( Desc ) ) ) = GetFactionID( Part ) );

			end else if ( Q = 'X' ) and ( Plot <> Nil ) then begin
				{ eXclude. This part must not be an ally }
				{ of the faction of the requested element. }
				it := it and ( not PWAreAllies( Adv, Part , ExtractValue( Desc ) ) );

			end else if ( Q = 'O' ) and ( Plot <> Nil ) then begin
				{ Okay. This part must not be an enemy }
				{ of the faction of the requested element. }
				it := it and ( not PWAreEnemies( Adv, Part , ExtractValue( Desc ) ) );

			end else if ( Q = 'A' ) and ( Plot <> Nil ) then begin
				{ Ally. This part must not be an ally }
				{ of the faction of the requested element. }
				it := it and PWAreAllies( Adv, Part , ExtractValue( Desc ) );

			end else if ( Q = 'E' ) and ( Plot <> Nil ) then begin
				{ ENEMY. The faction of the requested }
				{ element must be hated by this part's }
				{ faction. }
				it := it and PWAreEnemies( Adv, Part , ExtractValue( Desc ) );

			end;
		end;
	end;

	{ Return the result. }
	PartMatchesRelativeCriteria := it;
end;

Function NPCMatchesDesc( Adv,Plot,NPC: GearPtr; const IDesc,RDesc: String; GB: GameBoardPtr ): Boolean;
	{ Return TRUE if the supplied NPC matches this description }
	{ string, FALSE otherwise. Note that an extra check is performed }
	{ to prevent animals from being chosen for plots, which could }
	{ otherwise happen if the animal in question has a Character ID. }
	{ Thank you Fluffy the Stegosaurus. }
var
	it: Boolean;
begin
	{ DESC should contain a string list of all the stuff we want }
	{ our NPC to have. Things like gender, personality traits, }
	{ et cetera. Most of these things are intrinsic to the NPC, }
	{ but some of them are defined relative to other elements of }
	{ this plot. }

	it := PartMatchesCriteria( XNPCDesc( GB , Adv , NPC ) , IDesc );
	if it then it := PartMatchesRelativeCriteria( Adv, Plot, NPC, GB, RDesc );

	NPCMatchesDesc := it and NotAnAnimal( NPC );
end;

Function CharacterSearch( Adv, Plot: GearPtr; Desc: String; GB: GameBoardPtr ): GearPtr;
	{ Search high and low looking for a character that matches }
	{ the provided search description! }
	{ GH2- note that ADV probably isn't the adventure proper. It's the limit for our element }
	{ search, probably the city in which this plot will take place. }
var
	NPC: GearPtr;
	NumMatches: Integer;
	Results: Array of PWSearchResult;
	IDesc,RDesc: String;
	CheckGlobal,SeekLancemate: Boolean;

	Procedure CheckAlongPath( P: GearPtr );
		{ Check along this path looking for characters. If a match is found, }
		{ add it to the array. }
	var
		CID: LongInt;
	begin
		while P <> Nil do begin
			if ( P^.G = GG_Character ) and NPCMatchesDesc( Adv, Plot, P , IDesc , RDesc , GB ) then begin
				{ Next, check to make sure it has an assigned CID. }
				CID := NAttValue( P^.NA , NAG_Personal , NAS_CID );
				if ( CID <> 0 ) then begin
					Results[ NumMatches ].thing := P;
					Results[ NumMatches ].match := 1;
					Inc( NumMatches );
				end;
			end;
			{ Don't check the contents of the content set- if it hasn't yet been added to the }
			{ adventure, we don't want it. }
			{ Also, don't check the contents of metascenes- either they're already involved in }
			{ a plot or they're off-limits. }
			if ( P^.G <> GG_ContentSet ) and ( P^.G <> GG_MetaScene ) then begin
				CheckAlongPath( P^.SubCom );
				CheckAlongPath( P^.InvCom );
			end;
			P := P^.Next;
		end;
	end;
begin
	{ Step one- size the array. We have a good estimate for how many characters are in the adventure in }
	{ the MaxCID value. }
	NumMatches := NAttValue( FindRoot( Adv )^.NA , NAG_Narrative , NAS_MaxCID );
	if NumMatches = 0 then begin
		DialogMsg( 'ERROR: No CIDs recorded in ' + GearName( FindRoot( Adv ) ) + '.' );
		Exit( Nil );
	end;
	SetLength( Results , NumMatches );

	{ Determine the scope- if searching globablly, do so. }
	CheckGlobal := AStringHasBString( Desc , '!G' );
	if CheckGlobal then Adv := FindRoot( Adv );

	SeekLancemate := AStringHasBString( Desc , '!L' );

	{ Filter the relative description from the instrinsic description. }
	IDesc := Desc;
	RDesc := FilterElementDescription( IDesc );

	{ Step two- search the adventure looking for characters. }
	NumMatches := 0;
	CheckAlongPath( Adv^.SubCom );
	if Adv^.G = GG_Scene then CheckAlongPath( Adv^.InvCom );
	{ Check the gameboard as well, as long as it's not a metascene or a temporary scene. }
	{ Actually, you can go ahead and search temp scenes as long as we're looking for a lancemate. }
	if ( GB <> Nil ) and ( SeekLancemate or not SceneIsTemp( GB^.Scene ) ) then begin
		CheckAlongPath( GB^.Meks );
	end;

	{ Check the invcomponents of the adventure only if global }
	{ NPCs are allowed by the DESC string. }
	if CheckGlobal then begin
		CheckAlongPath( FindRoot( Adv )^.InvCom );
	end;

	if NumMatches > 0 then begin
		NPC := Results[ Random( NumMatches ) ].Thing;
	end else begin
		NPC := Nil;
	end;

	CharacterSearch := NPC;
end; { Character Search }


Function SceneDesc( Scene: GearPtr ): String;
	{ Create a description string for this scene. }
var
	it: String;
begin
	if ( Scene = Nil ) or not IsAScene( Scene ) then begin
		it := '';
	end else begin
		it := SAttValue( Scene^.SA , 'TYPE' ) + ' ' + SAttValue( Scene^.SA , 'CONTEXT' ) + ' SCALE' + BStr( Scene^.V );
	end;
	SceneDesc := QuoteString( it );
end;

Function XSceneDesc( Scene: GearPtr ): String;
	{ Return the regular scene description plus a few extra bits. }
var
	it: String;
	FID: LongInt;
	Adv,Fac: GearPtr;
begin
	{ Just copying the code above for now- it's not complicated, and should }
	{ save time from creating/copying two strings. If you are reading this }
	{ source code to learn how to program, DO NOT DO THIS YOURSELF!!! It's a }
	{ bad thing and will probably come back to bite me in the arse later on. }
	{ Also, feel free to use the word "arse" in your comments. }
	if ( Scene = Nil ) or not IsAScene( Scene ) then begin
		it := '';
	end else begin
		it := SAttValue( Scene^.SA , 'TYPE' ) + ' ' + SAttValue( Scene^.SA , 'CONTEXT' ) + ' SCALE' + BStr( Scene^.V );

		Adv := FindRoot( Scene );
		FID := NAttValue( Scene^.NA , NAG_Personal , NAS_FactionID );
		Fac := SeekFaction( Adv , FID );
		if Fac <> Nil then it := it + ' ' + SATtValue( Fac^.SA , 'DESIG' )
		else it := it + ' NOFAC';
		if ( FID <> 0 ) and ( FID = NAttValue( Adv^.NA , NAG_Personal , NAS_FactionID ) ) then it := it + ' PCFAC';
	end;

	XSceneDesc := QuoteString( it );
end;

Function NumFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
	{ Find out how many scenes match the provided description. }
var
	RDesc: String;
	Function CheckAlongPath( P: GearPtr ): Integer;
	var
		N: Integer;
	begin
		N := 0;
		while P <> Nil do begin
			if ( P^.G = GG_Scene ) and PartMatchesCriteria( XSceneDesc( P ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, P, GB, RDesc ) then begin
				Inc( N );
			end;
			N := N + CheckAlongPath( P^.SubCom );
			P := P^.Next;
		end;
		CheckAlongPath := N;
	end;
begin
	RDesc := FilterElementDescription( Desc );

	if ( Adventure^.G = GG_Scene ) and PartMatchesCriteria( XSceneDesc( Adventure ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Adventure, GB, RDesc ) then begin
		NumFreeScene := CheckAlongPath( Adventure^.SubCom ) + 1;
	end else begin
		NumFreeScene := CheckAlongPath( Adventure^.SubCom );
	end;
end;

Function FindFreeScene( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; Num: Integer ): GearPtr;
	{ Find the NUM'th scene that matches the provided description. }
var
	S2: GearPtr;
	RDesc: String;
{ PROCEDURES BLOCK. }
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while ( Part <> Nil ) and ( S2 = Nil ) do begin
			{ Decrement N if this gear matches our description. }
			if ( Part^.G = GG_Scene ) and PartMatchesCriteria( XSceneDesc( Part ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Part, GB, RDesc ) then begin
				Dec( Num );

				if Num = 0 then S2 := Part;
			end;

			if Num > 0 then CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
begin
	S2 := Nil;
	RDesc := FilterElementDescription( Desc );

	if ( Adventure^.G = GG_Scene ) and PartMatchesCriteria( XSceneDesc( Adventure ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Adventure, GB, RDesc ) then begin
		if Num = 1 then begin
			S2 := Adventure;
		end else begin
			Dec( Num );
			CheckAlongPath( Adventure^.SubCom );
		end;
	end else begin
		CheckAlongPath( Adventure^.SubCom );
	end;

	FindFreeScene := S2;
end;

Function SearchForScene( Adventure , Plot: GearPtr; GB: GameBoardPtr; Desc: String ): GearPtr;
	{ Try to find a scene matching the description. }
var
	NumElements: Integer;
begin
	if AStringHasBString( Desc , '!G' ) then Adventure := FindRoot( Adventure );
	NumElements := NumFreeScene( Adventure , Plot , GB , Desc );
	if NumElements > 0 then begin
		{ Pick one of the free scenes at random. }
		SearchForScene := FindFreeScene( Adventure , Plot , GB , Desc , Random( NumElements ) + 1 );
	end else begin
		SearchForScene := Nil;
	end;
end;

Function NumFreeEntryPoints( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
	{ Find out how many scenes match the provided description. }
var
	RDesc: String;
	Function CheckAlongPath( P: GearPtr ): Integer;
	var
		N: Integer;
	begin
		N := 0;
		while P <> Nil do begin
			if ( P^.G = GG_MetaTerrain ) and ( P^.S <> GS_MetaEncounter ) and ( P^.Stat[ STAT_Destination ] < 0 ) and PartMatchesCriteria( SAttValue( P^.SA , 'REQUIRES' ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, P, GB, RDesc ) then begin
				if MetaSceneNotInUse( Adventure , P^.Stat[ STAT_Destination ] ) then Inc( N );
			end;
			N := N + CheckAlongPath( P^.SubCom );
			N := N + CheckAlongPath( P^.InvCom );
			P := P^.Next;
		end;
		CheckAlongPath := N;
	end;
begin
	RDesc := FilterElementDescription( Desc );

	NumFreeEntryPoints := CheckAlongPath( Adventure^.SubCom ) + CheckAlongPath( GB^.Meks );
end;

Function FindFreeEntryPoint( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; N: Integer ): GearPtr;
	{ Find out how many scenes match the provided description. }
var
	E2: GearPtr;
	RDesc: String;
	Procedure CheckAlongPath( P: GearPtr );
	begin
		while ( P <> Nil ) and ( E2 = Nil ) do begin
			if ( P^.G = GG_MetaTerrain ) and ( P^.S <> GS_MetaEncounter ) and ( P^.Stat[ STAT_Destination ] < 0 ) and PartMatchesCriteria( SAttValue( P^.SA , 'REQUIRES' ) , Desc ) and
				PartMatchesRelativeCriteria( Adventure, Plot, P, GB, RDesc ) and MetaSceneNotInUse( Adventure , P^.Stat[ STAT_Destination ] ) then begin
					Dec( N );
					if N = 0 then E2 := P;
			end;
			if E2 = Nil then CheckAlongPath( P^.SubCom );
			if E2 = Nil then CheckAlongPath( P^.InvCom );
			P := P^.Next;
		end;
	end;
begin
	E2 := Nil;
	RDesc := FilterElementDescription( Desc );

	CheckAlongPath( Adventure^.SubCom );
	if E2 = Nil then CheckAlongPath( GB^.Meks );

	FindFreeEntryPoint := E2;
end;

Function SearchForMetasceneEntryPoint( Adventure , Plot: GearPtr; GB: GameBoardPtr; Desc: String ): GearPtr;
	{ Locate a metaterrain gear which has a negative destination number that's }
	{ currently unused. }
var
	NumElements: Integer;
begin
	NumElements := NumFreeEntryPoints( Adventure , Plot , GB , Desc );
	if NumElements > 0 then begin
		{ Pick one of the free scenes at random. }
		SearchForMetasceneEntryPoint := FindFreeEntryPoint( Adventure , Plot , GB , Desc , Random( NumElements ) + 1 );
	end else begin
		SearchForMetasceneEntryPoint := Nil;
	end;
end;

function FactionDesc( Adv,Fac: GearPtr ): String;
	{ Return a description of the provided faction. }
var
	it: String;
begin
	{ Error check- make sure the adventure really is the adventure. }
	Adv := FindRoot( Adv );

	{ Basic description is the faction's TYPE string attribute. }
	it := SATtValue( Fac^.SA , 'TYPE' ) + ' ' + SATtValue( Fac^.SA , 'CONTEXT' ) + ' ' + SATtValue( Fac^.SA , 'DESIG' );

	if IsArchEnemy( Adv, Fac ) then it := it + ' ARCHENEMY';
	if IsArchAlly( Adv, Fac ) then it := it + ' ARCHALLY';
	if Fac^.S = NAttValue( Adv^.NA , NAG_Personal , NAS_FactionID ) then it := it + ' PCFAC';

	{ Add the XXXRan Plan descriptor. }
	AddXXFactionContext( Fac , it , '@' );

	FactionDesc := it;
end;

Function NumFreeFaction( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String ): Integer;
	{ Find out how many factions match the provided description. }
var
	Fac: GearPtr;
	N: Integer;
	RDesc: String;
begin
	Fac := Adventure^.InvCom;
	N := 0;
	RDesc := FilterElementDescription( Desc );

	while Fac <> Nil do begin
		if ( Fac^.G = GG_Faction ) and PartMatchesCriteria( FactionDesc( Adventure,Fac ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Fac, GB, RDesc ) then Inc( N );
		Fac := Fac^.Next;
	end;

	NumFreeFaction := N;
end;

Function FindFreeFaction( Adventure,Plot: GearPtr; GB: GameBoardPtr; Desc: String; Num: Integer ): GearPtr;
	{ Find the NUM'th scene that matches the provided description. }
var
	Fac,F2: GearPtr;
	RDesc: String;
begin
	Fac := Adventure^.InvCom;
	F2 := Nil;
	RDesc := FilterElementDescription( Desc );

	while Fac <> Nil do begin
		if ( Fac^.G = GG_Faction ) and PartMatchesCriteria( FactionDesc( Adventure,Fac ) , Desc ) and PartMatchesRelativeCriteria( Adventure, Plot, Fac, GB, RDesc ) then begin
			Dec( Num );
			if Num = 0 then F2 := Fac;
		end;
		Fac := Fac^.Next;
	end;

	FindFreeFaction := F2;
end;

Function DeployNextPrefabElement( GB: GameBoardPtr; Adventure,Plot: GearPtr; N: Integer; MovePrefabs: Boolean ): GearPtr;
	{ Deploy the next element, give it a unique ID number if }
	{ appropriate, then return a pointer to the it. }
var
	E,Dest,Target: GearPtr;	{ Element & Destination. }
	D,P: Integer;
	Place,SubStr: String;
	ID: LongInt;
	InSceneNotElement: Boolean;
begin
	{ Find the first uninitialized entry in the list. }
	{ This is gonna be our next element. }
	E := Plot^.InvCom;
	While ( E <> Nil ) and ( SAttValue( E^.SA , 'ELEMENT' ) <> '' ) do begin
		E := E^.Next;
	end;

	if E <> Nil then begin
		{ Give our new element a unique ID, and store its ID in the Plot. }
		{ Characters who aren't animals get CIDs, encounters get scene IDs, }
		{ everything else gets NIDs. }
		if ( E^.G = GG_Character ) and NotAnAnimal( E ) then begin
			ID := NewCID( Adventure );
			SetNAtt( E^.NA , NAG_Personal , NAS_CID , ID );
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <C Prefab>' );
			SetSAtt( E^.SA , 'ELEMENT <C Prefab>' );
		end else if ( E^.G = GG_MetaTerrain ) and ( E^.S = GS_MetaEncounter ) and not AStringHasBString( SAttValue( E^.SA , 'SPECIAL' ) , 'NOMSID' ) then begin
			ID := NewMetaSceneID( Adventure );
			E^.Stat[ STAT_Destination ] := ID;
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <S Prefab>' );
			SetSAtt( E^.SA , 'ELEMENT <S Prefab>' );

			{ Maybe set this element's name. }
			Place := GearName( E );
			ReplacePat( Place , '%r%' , RandomName );
			SetSAtt( E^.SA , 'name <' + Place + '>' );

		end else begin
			ID := NewNID( Adventure );
			SetNAtt( E^.NA , NAG_Narrative , NAS_NID , ID );
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <I Prefab>' );
			SetSAtt( E^.SA , 'ELEMENT <I Prefab>' );
		end;
		SetNAtt( Plot^.NA , NAG_ElementID , N , ID );


		If MovePrefabs then begin
			{ Find out if we have to put this element somewhere else. }
			{ Memes automatically get frozen. }
			if E^.G = GG_Meme then begin
				Place := '/';
			end else if ( E^.G = GG_Secret ) or ( E^.G = GG_CityMood ) then begin
				Place := '';
			end else begin
				Place := SAttValue( Plot^.SA , 'PLACE' + BStr( N ) );
			end;

			{ If we have to put it somewhere, do so now. }
			{ Otherwise leave it where it is. }
			if Place <> '' then begin
				{ Delink the element from the plot. }
				DelinkGear( Plot^.InvCom , E );

				{ Determine its target location. }
				{ If the PLACE string starts with a tilde, we want to }
				{ place the prefab element in the same scene as the relative }
				{ element rather than the element itself. }
				InSceneNotElement := Place[1] = '~';
				if InSceneNotElement then DeleteFirstChar( Place );

				{ If the PLACE is /, then this element should start play frozen. }
				if Place[1] = '/' then begin
					Dest := SeekCurrentLevelGear( FindRoot( Adventure )^.InvCom , GG_PlotThingSet , 0 );
					InSceneNotElement := False;
				end else begin
					D := ExtractValue( Place );
					if ( Abs( D ) >= 1 ) and ( Abs( D ) <= Num_Plot_Elements ) then begin
						Dest := GetFSE( D );
					end else begin
						DialogMsg( 'ERROR: Illegal place for element ' + BStr( N ) + ' in plot ' + GearName( Plot ) );
					end;
				end;

				if InSceneNotElement and (( Dest = Nil ) or ( Dest^.G <> GG_Scene )) then begin
					{ If the destination is a metascene, locate its entrance. }
					if ( Dest = Nil ) or ( Dest^.G = GG_MetaScene ) then begin
						Dest := FindSceneEntrance( Adventure , GB , GetFSEID( Plot^.Parent , Plot , D ) );
					end;

					{ Try to find the associated scene now. }
					if Dest <> Nil then begin
						Dest := FindActualScene( GB , FindSceneID( Dest , GB ) );
					end;
				end;

				if Dest = Nil then begin
					{ An invalid location was specified... }
					DialogMsg( 'ERROR: No dest found for ' + GearName( E ) + ' in ' + GearName( Plot ) );
					DisposeGear( E );

				end else if ( Dest^.G <> GG_Scene ) and ( Dest^.G <> GG_MetaScene ) and IsLegalInvCom( Dest , E ) then begin
					{ If E can be an InvCom of Dest, stick it there. }
					InsertInvCom( Dest , E );

				end else begin
					{ If Dest isn't a scene, find the scene DEST is in itself }
					{ and stick E in there. }
					while ( Dest <> Nil ) and ( not IsAScene( Dest ) ) do Dest := Dest^.Parent;

					if Dest <> Nil then begin
						{ Maybe set this item next to another item. }
						P := Pos( '!N' , Place );
						if P > 0 then begin
							SubStr := copy( Place , P , 255 );
							ExtractWord( SubStr );
							ID := ExtractValue( SubStr );
							Target := GetFSE( ID );
							if ( Target <> Nil ) and ( ( Target^.G = GG_Scene ) or ( Target^.G = GG_MetaScene ) ) then begin
								if ID > 0 then begin
									Target := FindSceneEntrance( Adventure , GB , ElementID( Plot , ID ) );
								end else begin
									Target := FindSceneEntrance( Adventure , GB , ElementID( Plot^.Parent , Abs( ID ) ) );
								end;
							end;
							if Target <> Nil then begin
								SetNAtt( E^.NA , NAG_ParaLocation , NAS_X , NAttValue( Target^.NA , NAG_Location , NAS_X ) );
								SetNAtt( E^.NA , NAG_ParaLocation , NAS_Y , NAttValue( Target^.NA , NAG_Location , NAS_Y ) );
							end;
						end;

						{ If the destination is the current scene, }
						{ we'll want to deploy this element right away. }
						{ Otherwise just shove it in the invcoms. }
						if Dest = GB^.Scene then begin
							EquipThenDeploy( GB , E , True );
						end else begin
							InsertInvCom( Dest , E );
						end;

						{ If E is a character, this brings us to the next problem: }
						{ we need to assign a TEAM for E to be a member of. }
						if E^.G = GG_Character then begin
							SetSAtt( E^.SA , 'TEAMDATA <' + Place + '>' );
							ChooseTeam( E , Dest );
						end;

						{ If DEST is a metascene, give E an OriginalHome }
						{ of -1 so it isn't deleted when the scene ends. }
						if ( Dest^.G = GG_MetaScene ) or IsInvCom( Dest ) then SetNAtt( E^.NA , NAG_ParaLocation , NAS_OriginalHome , -1 );

					end else begin
						{ Couldn't find a SCENE gear. Get rid of E. }
						DialogMsg( 'ERROR: No dest found for ' + GearName( E ) + ' in ' + GearName( Plot ) );
						DisposeGear( E );
					end;
				end; { If Dest ... }
			end; { if Place <> '' }
		end; { if MovePrefabs }

	end;
	DeployNextPrefabElement := E;
end;

Function SelectArtifact( Adventure: GearPtr; Desc: String ): GearPtr;
	{ Select an artifact at random. If one can be found, delink it from the }
	{ artifact collection and return its address. }
var
	AC,A,Part: GearPtr;
	N: Integer;
begin
	{ Step One: Find the artifact set. }
	AC := SeekCurrentLevelGear( Adventure^.InvCom , GG_ArtifactSet , 0 );
	A := Nil;

	if AC <> Nil then begin
		{ Count the number of appropriate gears. }
		Part := AC^.InvCom;
		N := 0;
		while Part <> Nil do begin
			if PartMatchesCriteria( SAttValue( Part^.SA , 'REQUIRES' ) , Desc ) then Inc( N );
			Part := Part^.next;
		end;

		{ Next, grab one at random. }
		if N > 0 then begin
			N := Random( N );
			Part := AC^.InvCom;
			while ( Part <> Nil ) and ( A = Nil ) do begin
				if PartMatchesCriteria( SAttValue( Part^.SA , 'REQUIRES' ) , Desc ) then begin
					if N = 0 then A := Part;
					Dec( N );
				end;
				Part := Part^.next;
			end;
		end;
	end;
	if A <> Nil then DelinkGear( AC^.InvCom , A );
	SelectArtifact := A;
end;

Function NewContentNPC( Adv,Story,Plot: GearPtr; desc: String ): GearPtr;
	{ Create a new NPC. Give it whatever traits are needed. }
var
	NPC,Fac: GearPtr;
	FacID,HTID: LongInt;
begin
	{ First, we need to determine the NPC's faction and home town. }
	{ These will be stored as separate elements. }
	FacID := ExtractValue( desc );
	if FacID <> 0 then begin
		Fac := GetFSE( FacID );
		FacID := GetFactionID( Fac );
	end;

	HTID := ExtractValue( desc );
	if HTID <> 0 then HTID := GetFSEID( Story , Plot , HTID );

	{ We have the info. Time to create our NPC. }
	NPC := RandomNPC( Adv , FacID , HTID );

	{ Do the individualization. }
	IndividualizeNPC( NPC );

	{ Customize the character. }
	ApplyChardesc( NPC , Desc );

	{ Return the result. }
	NewContentNPC := NPC;
end;

Function PrepareQuestSceneElement( Adventure , Plot: GearPtr; N: Integer ): GearPtr;
	{ We've received a request for a new permanent scene. Assign a SceneID for it. }
	{ Also, copy over the difficulty rating from the plot, and mark all current }
	{ subs and invs as original content. }
	{ Also make sure to give the scene a unique name. }
	Procedure MarkChildrenAsOriginal( LList: GearPtr );
		{ Mark all the children of this quest scene as original, so if it's a }
		{ dungeon other things which get added can be set aside and placed in }
		{ the goal level. }
	begin
		while LList <> Nil do begin
			if NAttValue( LList^.NA , NAG_Narrative , NAS_QuestDungeonPlacement ) = 0 then begin
				SetNAtt( LList^.NA , NAG_NArrative , NAS_QuestDungeonPlacement , NAV_WasQDOriginal );
			end;
			LList := LList^.Next;
		end;
	end;
var
	ID,Tries: Integer;
	QS,PScene: GearPtr;
	BaseName,UniqueName: String;
begin
	ID := NewSceneID( Adventure );
	SetNAtt( Plot^.NA , NAG_ElementID , N , ID );
	QS := SeekCurrentLevelGear( Plot^.SubCom , GG_MetaScene , N );
	if QS <> Nil then begin
		{ Set the difficulty level, unless this has been overridden. }
		if NAttValue( QS^.NA , NAG_NArrative , NAS_DifficultyLevel ) = 0 then SetNAtt( QS^.NA , NAG_NArrative , NAS_DifficultyLevel , NAttValue( Plot^.NA , NAG_Narrative , NAS_DifficultyLevel ) );

		{ Mark the children as originals. }
		MarkChildrenAsOriginal( QS^.SubCom );
		MarkChildrenAsOriginal( QS^.InvCom );

		{ Assign a unique name for this scene. }
		{ Generate a unique name for this scene. }
		BaseName := SAttValue( QS^.SA , 'NAME' );
		UniqueName := ReplaceHash( BaseName , RandomName );
		Tries := 0;
		repeat
			PScene := SeekGearByName( Adventure , UniqueName );
			if PScene <> Nil then UniqueName := ReplaceHash( BaseName , RandomName );
			Inc( Tries );
		until ( PScene = Nil ) or ( Tries > 500 );

		if Tries > 500 then begin
			{ We tried, and failed, to get a unique name. }
			UniqueName := 'Ique ' + BStr( ID );
			DialogMsg( 'ERROR: Scene ' + GearName( Plot ) + ' (' + BStr( ID ) + ') couldn''t generate unique name.' );
		end;

		SetSAtt( QS^.SA , 'NAME <' + UniqueName + '>' );

	end;
	PrepareQuestSceneElement := QS;
end;

Function FindElement( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr ; MovePrefabs, Debug: Boolean ): Boolean;
	{ Locate and store the Nth element for this plot. }
	{ Return TRUE if a suitable element could be found, or FALSE }
	{ if no suitable element exists in the adventure & this plot }
	{ will have to be abandoned. }
var
	Element: GearPtr;
	Desc,EKind: String;
	OK: Boolean;
	NumElements: Integer;
begin
	{ Error check }
	if ( N < 1 ) or ( N > Num_Plot_Elements ) then Exit( False );

	{ Find the description for this element. }
	desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) );
	DeleteWhiteSpace( Desc );

	{ Initialize OK to TRUE. }
	OK := True;

	if desc <> '' then begin
		EKind := ExtractWord( Desc );

		if EKind[1] = 'C' then begin
			{ This element is a CHARACTER. Find one. }

			{ IMPORTANT!!!: Character being sought muct not have a plot already!!! }
			if ( Plot <> Nil ) then desc := 'NOTUSED ' + desc;

			Element := CharacterSearch( Adventure , Plot , Desc , GB );

			if Element <> Nil then begin
				{ Store the NPC's ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , NAttValue( Element^.NA , NAG_Personal , NAS_CID ) );
				Fast_Seek_Element[ 1 , N ] := Element;

			end else begin
				{ No free NPCs were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'S' then begin
			{ This element is a SCENE. Find one. }
			{ Pick one of the free scenes at random. }
			Element := SearchForScene( Adventure , Plot , GB , Desc );

			if Element <> Nil then begin
				{ Store the Scene ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , Element^.S );
				Fast_Seek_Element[ 1 , N ] := Element;

			end else begin
				{ No free scenes were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'M' then begin
			{ This element is a METASCENE. Find one. }
			{ Pick one of the free scenes at random. }
			Element := SearchForMetasceneEntryPoint( Adventure , Plot , GB , Desc );

			if Element <> Nil then begin
				{ Store the Scene ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , Element^.Stat[ STAT_Destination ] );
				Fast_Seek_Element[ 1 , N ] := FindMetascene( Adventure , Element^.Stat[ STAT_Destination ] );

				{ Change its type to SCENE, since it will be treated as a scene hereafter. }
				SetSAtt( PLOT^.SA , 'ELEMENT' + BStr( N ) + ' <SMETA>' );

			end else begin
				{ No free scenes were found. Bummer. }
				OK := False;
			end;

		end else if EKind[1] = 'F' then begin
			{ Faction element. }
			NumElements := NumFreeFaction( FindRoot( Adventure ) , Plot , GB , Desc );
			if NumElements > 0 then begin
				{ Pick one of the free scenes at random. }
				Element := FindFreeFaction( FindRoot( Adventure ) , Plot , GB , Desc , Random( NumElements ) + 1 );
				Fast_Seek_Element[ 1 , N ] := Element;

				{ Store the Scene ID in the plot. }
				SetNAtt( Plot^.NA , NAG_ElementID , N , Element^.S );

			end else begin
				{ No free scenes were found. Bummer. }
				OK := False;

			end;

		end else if EKind[1] = 'P' then begin
			{ PreFab element. Check Plot/InvCom and }
			{ retrieve it. }
			Element := DeployNextPrefabElement( GB , Adventure , Plot , N , MovePrefabs );
			Fast_Seek_Element[ 1 , N ] := Element;
			OK := Element <> Nil;

		end else if EKind[1] = 'Q' then begin
			{ Quest Scene. Find the metascene template being used. }
			Element := PrepareQuestSceneElement( Adventure , Plot , N );
			Fast_Seek_Element[ 1 , N ] := Element;
			OK := Element <> Nil;

		end else if EKind[1] = 'A' then begin
			{ Artifact. Select one at random, then deploy it as a prefab element. }
			Element := SelectArtifact( FindRoot( Adventure ) , desc );
			if Element <> Nil then begin
				{ We now want to deploy the artifact as though it were a }
				{ prefab element. }
				Element^.Next := Plot^.InvCom;
				Plot^.InvCom := Element;
				Element^.Parent := Plot;
				DeployNextPrefabElement( GB , Adventure , Plot , N , MovePrefabs );
				Fast_Seek_Element[ 1 , N ] := Element;
				OK := True;
			end else OK := False;

		end else if EKind[1] = 'N' then begin
			{ New NPC. Create and format one, then deploy it as a prefab element. }
			Element := NewContentNPC( Adventure , Plot^.Parent , Plot , desc );
			if Element <> Nil then begin
				{ We now want to deploy the artifact as though it were a }
				{ prefab element. }
				Element^.Next := Plot^.InvCom;
				Plot^.InvCom := Element;
				Element^.Parent := Plot;
				DeployNextPrefabElement( GB , Adventure , Plot , N , MovePrefabs );
				Fast_Seek_Element[ 1 , N ] := Element;
				OK := True;
			end else OK := False;


		end else if ( EKind[1] = '.' ) then begin
			if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
				{ Insert the current scene as this element. }
				SetSAtt( PLOT^.SA , 'ELEMENT' + BStr( N ) + ' <S>' );
				SetNAtt( PLOT^.NA , NAG_ElementID , N , RealSceneID( GB^.Scene ) );
				Fast_Seek_Element[ 1 , N ] := GB^.Scene;
				OK := True;
			end else if Adventure^.G = GG_Scene then begin
				{ Insert the current scope as this element. }
				SetSAtt( PLOT^.SA , 'ELEMENT' + BStr( N ) + ' <S>' );
				SetNAtt( PLOT^.NA , NAG_ElementID , N , RealSceneID( Adventure ) );
				Fast_Seek_Element[ 1 , N ] := Adventure;
				OK := True;

			end else OK := False;
		end;		
	end;

	if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
		if not OK then DialogMsg( 'PLOT ERROR: ' + BStr( N ) + ' Element Not Found! ' + GearName( Plot ) )
		else if desc <> '' then DialogMsg( 'PLOT ELEMENT ' + BStr( N ) + ': ' + BStr( ElementID( Plot , N ) ) + ' ' + GearName( Element ) );
	end;

	FindElement := OK;
end;

Function SeekUrbanArea( RootScene: GearPtr ): GearPtr;
	{ Locate an urban area contained within this scene. It may either be the }
	{ scene itself or a subscene thereof. An urban area is somewhere that buildings }
	{ may safely be placed. }
	Function IsUrbanArea( Scene: GearPtr ): Boolean;
	begin
		IsUrbanArea := ( Scene^.G = GG_Scene ) and AStringHasBString( SAttValue( Scene^.SA , 'TYPE' ) , 'URBAN' );
	end;
	Function SearchSubScenes( LList: GearPtr ): GearPtr;
		{ Search this list of sub-scenes to locate an urban scene. }
	var
		Scene: GearPtr;
	begin
		Scene := Nil;
		while ( Scene = Nil ) and ( LList <> Nil ) do begin
			if IsUrbanArea( LList ) then Scene := LList;
			if Scene = Nil then SearchSubScenes( LList^.SubCom );
			LList := LList^.Next;
		end;
		SearchSubScenes := Scene;
	end;
begin
	if IsUrbanArea( RootScene ) then Exit( RootScene );
	SeekUrbanArea := SearchSubScenes( RootScene^.SubCom );
end;


Procedure CreateElement( Adventure,Plot: GearPtr; N: Integer; GB: GameBoardPtr );
	{ Create and store the Nth element for this plot. }
var
	Element,Destination,Faction,EntranceList,Dest2: GearPtr;
	Desc,EKind,SubStr,job: String;
	ID,P: Integer;
begin
	{ Error check }
	if ( N < 1 ) or ( N > Num_Plot_Elements ) then Exit;

	{ Find the description for this element. }
	desc := UpCase( SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) );
	DeleteWhiteSpace( Desc );

	{ Locate the !Near clause, if it exists. }
	P := Pos( '!N' , desc );
	if P > 0 then begin
		SubStr := copy( desc , P , 255 );
		ExtractWord( SubStr );
		ID := ExtractValue( SubStr );
		Destination := GetFSE( ID );

		if ( Destination <> Nil ) and ( Destination^.G <> GG_MetaScene ) then begin
			Destination := FindActualScene( GB , FindSceneID( Destination , GB ) );
		end;
	end else begin
		Destination := Nil;
	end;

	{ Locate the !Comrade clause, if it exists. }
	{ If no !Comrade found, try !Ally as well. }
	P := Pos( '!C' , desc );
	if P = 0 then P := Pos( '!A' , desc );
	if P > 0 then begin
		SubStr := copy( desc , P , 255 );
		ExtractWord( SubStr );
		ID := ExtractValue( SubStr );
		Faction := GetFSE( ID );
		if ( Faction <> Nil ) then begin
			Faction := SeekFaction( Adventure , GetFactionID( Faction ) );
		end;
	end else begin
		Faction := Nil;
	end;


	if desc <> '' then begin
		EKind := ExtractWord( Desc );

		if EKind[1] = 'C' then begin
			{ This element is a CHARACTER. Create one. }
			job := SAttValue( Plot^.SA , 'NEVERFAIL' + BStr( N ) );
			if job = '' then begin
				Element := RandomNPC( FindRoot( Adventure ) , 0 , RealSceneID( FindRootScene( GB^.Scene ) ) );
				{ Do the individualization. }
				IndividualizeNPC( Element );
				job := SAttValue( Element^.SA , 'job' );
			end else Element := LoadNewNPC( job , True );
			if Element = Nil then Element := LoadNewNPC( 'MECHA PILOT' , True );
			SetSAtt( Element^.SA , 'job <' + job + '>' );
			SetSAtt( Element^.SA , 'TEAMDATA <Pass>' );

			{ Customize the character. }
			ApplyChardesc( Element , Desc );

			{ Store the NPC's ID in the plot. }
			ID := NewCID( Adventure );
			SetNAtt( Element^.NA , NAG_Personal , NAS_CID , ID );
			SetNAtt( Plot^.NA , NAG_ElementID , N , ID );
			Fast_Seek_Element[ 1 , N ] := Element;

		end else if EKind[1] = 'M' then begin
			{ MetaScene element. }
			{ Create a building to use as the entrance, give it a unique ID number, }
			{ then change the element type to Scene. }
			FilterElementDescription( Desc );
			if Faction <> Nil then desc := desc + ' ' + SAttValue( Faction^.SA , 'DESIG' );
			EntranceList := AggregatePattern( 'ENTRANCE_*.txt' , Series_Directory );
			Element := CloneGear( FindNextComponent( EntranceList , Desc ) );
			DisposeGear( EntranceList );
			if Element = Nil then Element := LoadNewSTC( 'BUILDING' );
			SetSAtt( Element^.SA , 'NAME <' + RandomBuildingName( Element ) + '>' );

			{ This is gonna be a new building, so don't stick it just anywhere. }
			{ We want to place this element in the URBAN area of the scene. }
			{ Note that if no urban area can be found, NEVERFAIL will actually }
			{ fail. Woah! }
			Dest2 := SeekUrbanArea( Destination );
			if Dest2 <> Nil then begin
				Destination := Dest2;
				ID := NewMetaSceneID( Adventure );
				Element^.Stat[ STAT_Destination ] := ID;
				Element^.Scale := Dest2^.V;
				SetNAtt( Plot^.NA , NAG_ElementID , N , ID );
				SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <S>' );
			end else begin
				DisposeGear( Element );
				Element := Nil;
			end;

		end else begin
			Element := Nil;
			DialogMsg( 'ERROR- CreateElement asked to create element of type ' + EKind +'.' );
			DialogMsg( 'Resultant plot ' + GearName( Plot ) + ' may fail.' );
		end;

		{ After this point, don't expect to use "desc" any more. It may have been }
		{ modified or chopped into pieces above. }

		if Element <> Nil then begin
			if Destination <> Nil then begin
				if GB^.Scene = Destination then begin
					EquipThenDeploy( GB , Element , True );
				end else begin
					InsertInvCom( Destination , Element );
				end;
				if IsAScene( Destination ) and IsMasterGear( Element ) then begin
					ChooseTeam( Element , Destination );
				end;

			end else begin
				InsertInvCom( Plot , Element );
			end;

			if Faction <> Nil then begin
				SetNAtt( Element^.NA , NAG_Personal , NAS_FactionID , Faction^.S );
			end;

			{ Indicate that this is a prefab element, so if the plot fails it'll be deleted. }
			SetSAtt( Plot^.SA , 'ELEMENT' + BStr( N ) + ' <' + SAttValue( Plot^.SA , 'ELEMENT' + BStr( N ) ) + ' PREFAB>' );
		end;
	end;
end;

Procedure AddGearXRContext( GB: GameBoardPtr; Adv,Part: GearPtr; var Context: String; palette_entry_code: Char );
	{ Add the context information for PART to CONTEXT. }
var
	F: GearPtr;
	msg,m2: String;
	T: Integer;
begin
	if Part <> Nil then begin
		Context := Context + ' ' + palette_entry_code + ':++';

		{ Add additional information about PART. }
		msg := SAttValue( Part^.SA , 'DESIG' );
		if msg <> '' then Context := Context + ' ' + palette_entry_code + ':' + msg;
		msg := SAttValue( Part^.SA , 'CONTEXT' );
		while msg <> '' do begin
			m2 := ExtractWord( msg );
			if m2 <> '' then Context := Context + ' ' + palette_entry_code + ':' + m2;
		end;

		{ If Part isn't a faction itself, add the designation of its faction. }
		if Part^.G <> GG_Faction then begin
			F := SeekFaction( Adv , NAttValue( Part^.NA , NAG_Personal , NAS_FactionID ) );
			if F <> Nil then begin
				msg := SAttValue( F^.SA , 'DESIG' );
				if msg <> '' then Context := Context + ' ' + palette_entry_code + ':' + msg;
			end;
		end else begin
			F := Part;
		end;
		if F <> Nil then begin
			{ If this faction is also the PC's faction, add a PCFAC tag. }
			if F^.S = NAttValue( FindRoot( Adv )^.NA , NAG_Personal , NAS_FactionID ) then Context := Context + ' ' + palette_entry_code + ':PCFAC';
		end else begin
			{ No faction was found. }
			Context := Context + ' ' + palette_entry_code + ':NOFAC';
		end;

		{ If Part is a character, add relationship info. Unless the }
		{ relationship is ENEMY, in which case it's covered below. }
		if Part^.G = GG_Character then begin
			Case NAttValue( Part^.NA , NAG_Relationship , 0 ) of
				NAV_Family: Context := Context + ' ' + palette_entry_code + ':FAMILY';
				NAV_Lover: Context := Context + ' ' + palette_entry_code + ':LOVER';
				NAV_Friend: Context := Context + ' ' + palette_entry_code + ':FRIEND';
			end;
			m2 := SAttValue( Part^.SA , 'JOB_DESIG' );
			if m2 <> '' then Context := Context + ' ' + palette_entry_code + ':' + m2;

			{ If the part is a lancemate, add that info. }
			if NAttValue( Part^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam then begin
				Context := Context + ' ' + palette_entry_code + ':LANCE';
			end;

			{ Add the heroic/villainous component. }
			T := NAttValue( Part^.NA , NAG_CharDescription , NAS_Heroic );
			if T > 0 then Context := Context + ' ' + palette_entry_code + ':GOOD_'
			else if T < 0 then Context := Context + ' ' + palette_entry_code + ':EVIL_';

			{ Add the character arc and attitude values. }
			AddXXCharContext( Part , Context , palette_entry_code );

		end else if Part^.G = GG_Faction then begin
			{ Add the plot arc value. }
			AddXXFactionContext( Part , Context , palette_entry_code );

		end else if Part^.G = GG_Scene then begin
			m2 := SAttValue( Part^.SA , 'TERRAIN' );
			if m2 <> '' then Context := Context + ' ' + palette_entry_code + ':' + m2;
		end;

		if IsArchEnemy( Adv , Part ) then Context := Context + ' ' + palette_entry_code + ':ENEMY';
		if IsArchAlly( Adv , Part ) then Context := Context + ' ' + palette_entry_code + ':ALLY';

	end else begin
		Context := Context + ' ' + palette_entry_code + ':--';

	end;
end;

Procedure AddElementContext( GB: GameBoardPtr; Story: GearPtr; var Context: String; palette_entry_code: Char; Element_Num: Integer );
	{ Add the context details for element T of STORY. }
var
	IsMetaScene: Boolean;
	Adv,E: GearPtr;
	msg: String;
begin
	IsMetaScene := False;
	Adv := FindRoot( Story );

	{ If this element is a scene, tell whether it's a regular scene }
	{ or a metascene. }
	msg := SAttValue( Story^.SA , 'ELEMENT' + BStr( Element_Num ) );
	if ( msg <> '' ) and ( UpCase( msg[1] ) = 'S' ) then begin
		if ElementID( Story , Element_Num ) >= 0 then begin
			Context := Context + ' ' + palette_entry_code + ':perm';
		end else begin
			Context := Context + ' ' + palette_entry_code + ':meta';
			IsMetaScene := True;
		end;
	end;

	E := SeekPlotElement( Adv , Story , Element_Num , GB );
	if ( E = Nil ) and IsMetaScene and ( FindSceneEntrance( Adv , GB , ElementID( Story , Element_Num ) ) <> Nil ) then begin
		Context := Context + ' ' + palette_entry_code + ':++';
	end else begin
		AddGearXRContext( GB , Adv , E , Context , palette_entry_code );
	end;
end;

Function DifficulcyContext( Threat: Integer ): String;
	{ Return a string describing this difficulcy level. }
begin
	if Threat > 80 then begin
		DifficulcyContext := '!Ex';
	end else if Threat > 60 then begin
		DifficulcyContext := '!Hi';
	end else if Threat > 40 then begin
		DifficulcyContext := '!Md';
	end else if Threat > 20 then begin
		DifficulcyContext := '!Lo';
	end else begin
		DifficulcyContext := '!Ne';
	end;
end;

Function StoryPlotRequest( Story: GearPtr ): String;
	{ Return the plotrequest to be used by this story. The plot request }
	{ depends on the provided XXRAN_PATTERN attribute and the dramatic }
	{ choice made by the player. }
var
	it: String;
	C: GearPtr;
begin
	{ Start with the plot request. }
	it := SAttValue( Story^.SA , 'XXRAN_PATTERN' );

	{ Attach the current choice to the plot_request. }
	C := SeekDramaticChoice( NAttValue( Story^.NA , NAG_XXRan , NAS_DramaticChoice ) );
	if C <> Nil then begin
		it := it + SAttValue( C^.SA , 'DESIG' );
	end else begin
		it := it + 'INTRO';
	end;

	StoryPlotRequest := it;
end;

Function StoryContext( GB: GameBoardPtr; Story: GearPtr ): String;
	{ Describe the context of this story in a concise string. }
const
	Merit_Badge_Tag: Array [1..NumMeritBadge] of String = (
		'STAR_', 'CHAMP', '', '', 'MORAL',
		''
	);
var
	it,msg: String;
	T: Integer;
	LList: GearPtr;
begin
	{ Start with the basic context. }
	it := StoryPlotRequest( Story ) + ' ' + SAttValue( Story^.SA , 'CONTEXT' );

	{ Add tags for the choices made so far. }
	LList := Dramatic_Choices;
	while LList <> Nil do begin
		if NAttValue( Story^.NA , NAG_Completed_DC , LList^.V ) > 0 then it := it + ' :' + SAttValue( LList^.SA , 'DESIG' );
		LList := LList^.Next;
	end;

	{ Add tags for the merit badges earned by the PC. }
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		{ Use LList to hold the adventure, for now. }
		LList := FindRoot( GB^.Scene );
		for t := 1 to NumMeritBadge do begin
			if ( Merit_Badge_Tag[ t ] <> '' ) and HasMeritBadge( LList , T ) then begin
				it := it + ' C:' + Merit_Badge_Tag[ t ];
			end;
		end;
	end;

	{ Add a description for the difficulcy rating. }
	it := it + ' ' + DifficulcyContext( NAttValue( Story^.NA , NAG_Narrative , NAS_DifficultyLevel ) );

	{ Add the extra random palette entries. }
	if ( Story^.G = GG_Story ) and ( Story^.S = GS_XRANStory ) then begin
		for t := 1 to Num_Plot_Elements do begin
			{ If this element represents to a palette entry, add its info }
			{ to the context. }
			msg := SAttValue( Story^.SA , 'palette_entry_code' + BStr( T ) );
			if msg <> '' then AddElementContext( GB , Story , it , msg[1] , T );
		end;
	end;
	StoryContext := it;
end;


Procedure InsertPFrags( Plot,Persona: GearPtr; const Context: String; ID: Integer );
	{ Prepare the persona for use in the game. Search its string attributes and }
	{ add any persona fragments that are requested. }
	Function SpaceyString( msg: String ): String;
		{ Return a version of msg with all the quotes replaced by }
		{ spaces. }
	var
		T: Integer;
	begin
		for t := 1 to Length( msg ) do if msg[t] = '"' then msg[t] := ' ';
		SpaceyString := msg;
	end;
var
	F: GearPtr;	{ The persona fragment to insert. }
	S,FS: SAttPtr;
	head,info,TypeLabel: String;
	Param: Array [1..8] of String;
	T: Integer;
begin
	S := Persona^.SA;
	while S <> Nil do begin
		if S^.Info[1] = '*' then begin
			{ This is a fragment request. Start by determining the relevant data. }
			head := RetrieveAPreamble( S^.Info );
			DeleteFirstChar( head );

			info := RetrieveAString( S^.info );
			TypeLabel := ExtractWord( info );
			for t := 1 to 8 do Param[t] := ExtractWord( Info );

			{ Next, search for a matching fragment... }
			F := FindNextComponent( persona_fragments , TypeLabel + ' ' + Context );
			if F <> Nil then begin
				{ If one was found, prep it for inclusion in the persona. }
				F := CloneGear( F );
				FS := F^.SA;
				while FS <> Nil do begin
					{ Format the strings. Tasks: }
					{ - Rename "START" to "HEAD" }
					{ - Replace %1% through %8% with parameters }
					{ - Replace %id% with BStr( ID ) }
					if UpCase( RetrieveAPreamble( FS^.Info ) ) = 'START' then begin
						FS^.Info := head + ' <' + RetrieveAString( FS^.Info ) + '>';
					end;
					ReplacePat( FS^.Info , '%id%' , BStr( ID ) );
					ReplacePat( FS^.Info , '%1%' , Param[1] );
					ReplacePat( FS^.Info , '%2%' , Param[2] );
					ReplacePat( FS^.Info , '%3%' , Param[3] );
					ReplacePat( FS^.Info , '%4%' , Param[4] );
					ReplacePat( FS^.Info , '%5%' , Param[5] );
					ReplacePat( FS^.Info , '%6%' , Param[6] );
					ReplacePat( FS^.Info , '%7%' , Param[7] );
					ReplacePat( FS^.Info , '%8%' , Param[8] );

					FS := FS^.Next;
				end;

				{ Copy everything to the main persona. }
				FS := F^.SA;
				while FS <> Nil do begin
					SetSAtt( Persona^.SA , FS^.Info );
					FS := FS^.Next;
				end;

				{ Increment the ID counter. }
				Inc( ID );

				DisposeGear( F );
			end else begin
				DialogMsg( 'ERROR: No persona fragment found for ' + TypeLabel + ' ' + SpaceyString( Context ) );
			end;
		end;

		{ - Replace %E1% through %E8% with element IDs }
		if Plot <> Nil then begin
			for t := 1 to Num_Plot_Elements do begin
				ReplacePat( S^.Info , '%E' + BStr( T ) + '%' , BStr( ElementID( Plot , T ) ) );
			end;
		end;

		S := S^.Next;

	end;
end;

Function PersonalContext( Adv,NPC: GearPtr ): String;
	{ Return the context for this NPC. The context should include the trait }
	{ description and the faction designation. }
	{ This function is used for selecting persona fragments. }
var
	it: String;
	Theme: Integer;
begin
	if NPC = Nil then exit( '' );
	it := XNPCDesc( Nil , Adv , NPC );
	{ Add the theme here. }
	Theme := NAttValue( NPC^.NA , NAG_Personal , NAS_MechaTheme );
	it := it + ' [MT' + BStr( Theme ) + ']';
	PersonalContext := it;
end;

Procedure PrepAllPersonas( Adventure,Plot: GearPtr; GB: GameBoardPtr; MinID: Integer );
	{ Prepare the personas of this plot. }
	{ Also store the mission recharge time for any NPCs involved. }
var
	P,P2,NPC: GearPtr;
	Context: String;
begin
	P := Plot^.SubCom;
	Context := SAttValue( Plot^.SA , 'CONTEXT' );
	if ( Plot^.Parent <> Nil ) and ( Plot^.Parent^.G = GG_Story ) then begin
		Context := Context + StoryContext( GB , Plot^.Parent );
{	end else begin
		Context := Context + SAttValue( Plot^.SA , 'CONTEXT' );
}	end;
	while P <> Nil do begin
		P2 := P^.Next;
		if P^.G = GG_Persona then begin
			NPC := SeekPlotElement( Adventure , Plot , P^.S , GB );
			if ( NPC <> Nil ) and ( GB <> Nil ) then SetNAtt( NPC^.NA , NAG_Personal , NAS_PlotRecharge , GB^.ComTime + 86400 );
			InsertPFrags( Plot , P , Context + PersonalContext( Adventure , NPC ) , MinID );
		end;
		P := P2;
	end;
end;

Procedure PrepMetaScenes( Adventure,Plot: GearPtr; GB: GameBoardPtr );
	{ Maps are stored by name, so each metascene needs a unique name. }
	{ Since it already has a unique ID number this shouldn't be much trouble. }
var
	M,Entrance,T: GearPtr;
	Context: String;
begin
	if ( Plot^.Parent <> Nil ) and ( Plot^.Parent^.G = GG_Story ) then begin
		Context := StoryContext( GB , Plot^.Parent );
	end else begin
		Context := SAttValue( Plot^.SA , 'CONTEXT' ) + ' ' + DifficulcyContext( NAttValue( Plot^.NA , NAG_Narrative , NAS_DifficultyLevel ) );
	end;
	M := Plot^.SubCom;
	while M <> Nil do begin
		if ( M^.G = GG_MetaScene ) and ( M^.S >= 1 ) and ( M^.S <= Num_Plot_Elements ) then begin
			{ Store the entrance of the metascene. We'll need it later. }
			Entrance := FindSceneEntrance( Adventure , GB , ElementID( Plot , M^.S ) );
			if Entrance <> Nil then begin
				SetNAtt( M^.NA , NAG_Narrative , NAS_EntranceScene , FindSceneID( Entrance , GB ) );
			end;

			{ Prep the local personas. }
			T := M^.SubCom;
			while T <> Nil do begin
				if ( T^.G = GG_Persona ) and ( T^.S >= 1 ) and ( T^.S <= Num_Plot_Elements ) then begin
					{ Replace S with the CID of element T^.S. }
					InsertPFrags( Plot , T , Context + ' ' + PersonalContext( Adventure , GetFSE( T^.S ) ) , 1 );
					T^.S := ElementID( Plot , T^.S );
				end;
				T := T^.Next;
			end;

			SetSAtt( M^.SA , 'NAME <METASCENE:' + BStr( ElementID( Plot , M^.S ) ) + '>' );
			SetSAtt( M^.SA , 'CONTEXT <' + SAttValue( M^.SA , 'CONTEXT' ) + ' ' + Context + '>' );
		end;
		M := M^.Next;
	end;
end;


Procedure InitPlot( Adventure,Plot: GearPtr; GB: GameBoardPtr );
	{ Initialize this plot. }
	{ - Format rumor strings. }
	{ - Provide unique names for all metascenes. }
begin
	PrepMetaScenes( Adventure , Plot , GB );
	PrepAllPersonas( Adventure , Plot , GB , 1 );
end;

Procedure InitRandomLoot( LList: GearPtr );
	{ Search this list for random loot requests. Upon finding one, }
	{ fill the resultant gear with sstuff. }
const
	Default_Category = 'TREASURE';
var
	LootVal: LongInt;
	Loot_Category, Loot_Factions: String;
begin
	while LList <> Nil do begin
		InitRandomLoot( LList^.SubCom );
		InitRandomLoot( LList^.InvCom );
		LootVal := NAttValue( LList^.NA , NAG_Narrative , NAS_RandomLoot );
		if LootVal > 0 then begin
			{ A request for random loot has been placed. Find the loot }
			{ categories and the loot faction, then proceed to stuff. }
			Loot_Category := SAttValue( LList^.SA , 'LOOT_CATEGORY' );
			if Loot_Category = '' then Loot_Category := Default_Category;
			Loot_Factions := 'GENERAL ' + SAttValue( LList^.SA , 'LOOT_FACTIONS' );
			RandomLoot( LList , LootVal , Loot_Category , Loot_Factions );
			SetNAtt( LList^.NA , NAG_Narrative , NAS_RandomLoot , 0 );
		end;
		LList := LList^.Next;
	end;
end;

Procedure InitPrefabMoods( Slot, Plot: GearPtr );
	{ Moods can grab elements from either the plot that spawned them or the story }
	{ that spawned the plot. Do that now. }
var
	LList,Grab_Source: GearPtr;
	t,N: LongInt;
	desc: String;
begin
	LList := Plot^.InvCom;
	while LList <> Nil do begin
		if LList^.G = GG_CityMood then begin
			for t := 1 to Num_Plot_Elements do begin
				{ If an element grab is requested, process that now. }
				desc := SAttValue( LList^.SA , 'ELEMENT' + BStr( T ) );
				if ( desc <> '' ) and ( UpCase( desc[1] ) = 'G' ) then begin
					ExtractWord( desc );
					N := ExtractValue( desc );

					{ If we got a positive value, grab from the plot. Otherwise grab from }
					{ the presumed story. }
					if N > 0 then Grab_Source := Plot
					else Grab_Source := Slot;
					N := Abs( N );

					desc := SAttValue( Grab_Source^.SA , 'ELEMENT' + BStr( N ) );

					if Desc = '' then begin
						DialogMsg( 'ERROR: ' + GearName( LList ) + ' tried to grab empty element ' + BStr( N ) + ' from ' + GearName( Grab_Source ) );
					end else begin
						{ Only copy over the first character of the element description, }
						{ since that's all we need, and also because copying a PREFAB tag }
						{ may result in story elements being unnessecarily deleted. }
						{ Copy QuestScenes as regular scenes, since by the time this mood is deployed }
						{ that's what they'll be. }
						if UpCase( desc[1] ) = 'Q' then desc[1] := 'S';
						SetSAtt( LList^.SA , 'ELEMENT' + BStr( T ) + ' <' + desc[1] + '>' );
						SetNAtt( LList^.NA , NAG_ElementID , T , ElementID( Grab_Source , N ) );
					end;
				end;
			end; { For t ... }
		end;
		LList := LList^.Next;
	end;
end;

Function MatchPlotToAdventure( Scope,Slot,Plot: GearPtr; GB: GameBoardPtr; DoFullInit,MovePrefabs,Debug: Boolean ): Boolean;
	{ This PLOT gear is meant to be inserted as an INVCOM of Slot. }
	{ Perform the insertion, select unselected elements, and make sure }
	{ that everything fits. }
	{ SLOT must be a descendant of the adventure. }
	{ SCOPE is usually the adventure- the the higest level at which element searches will take place. }
	{ IMPORTANT: PLOT must not already be inserted into SLOT!!! }
	{ This procedure also works for Stories. }
var
	T: Integer;
	E: STring;
	Adventure,PFE: GearPtr;	{ Prefab Element }
	EverythingOK,OKNow: Boolean;
begin
	{ Error Check }
	if ( Plot = Nil ) or ( Slot = Nil ) then Exit;

	EverythingOK := True;

	{ We need to stick the PLOT into the SLOT to prevent }
	{ the FindElement procedure from choosing the same item for }
	{ multiple elements. }
	InsertInvCom( Slot , Plot );

	{ Locate the adventure. It must be the root of Slot. }
	Adventure := FindRoot( Slot );

	{ Select Actors }
	{ First clear the FastSeek array. }
	for t := 1 to Num_Plot_Elements do begin
		Fast_Seek_Element[ 0 , t ] := Nil;
		Fast_Seek_Element[ 1 , t ] := Nil;
	end;

	if ( Slot^.G = GG_Story ) then begin
		for t := 1 to Num_Plot_Elements do begin
			Fast_Seek_Element[ 0 , t ] := SeekPlotElement( Adventure , Slot , T , GB );
		end;
	end else if Scope^.G = GG_CityMood then begin
		{ We've been handed a mood rather than a scene. }
		for t := 1 to Num_Plot_Elements do begin
			Fast_Seek_Element[ 0 , t ] := SeekPlotElement( Adventure , Scope , T , GB );
		end;
		{ The parent of the mood should be the city it's installed in. This is what we want as }
		{ our scope. }
		Scope := Scope^.Parent;
	end;

	for t := 1 to Num_Plot_Elements do begin
		{ Check all the plot elements. Some of these may have been inherited from the SLOT. }
		if ( ElementID( Plot , T ) = 0 ) and EverythingOK then begin
			OkNow := FindElement( Scope , Plot , T , GB , MovePrefabs , Debug );

			if AStringHasBString( SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) ) , 'NEVERFAIL' ) and ( not OkNow ) then begin
				CreateElement( Adventure , Plot , T , GB );
				if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
					DialogMsg( '...but NEVERFAIL has saved the day! ID=' + BStr( ElementID( Plot , T ) ) );
				end;

				OkNow := ElementID( Plot , t ) <> 0;
			end;
		end else if EverythingOK then begin
			Fast_Seek_Element[ 1 , T ] := SeekPlotElement( Adventure , Plot , T , GB );

			{ If the element wasn't found, this will cause an error... unless, }
			{ of course, we're dealing with a MetaScene or a new Quest Scene. }
			{ These are the only element types that can not exist and still be valid. }
			E := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			if ( E <> '' ) and ( E[1] = 'Q' ) then begin
				OkNow := True;
			end else if ( E = '' ) or ( ( UpCase( E[1] ) <> 'S' ) and ( ElementID( Plot , t ) > 0 ) ) then begin
				OkNow := Fast_Seek_Element[ 1 , T ] <> Nil;
			end else begin
				OkNow := True;
			end;
			if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
				if not OKNow then DialogMsg( 'PLOT ERROR: ' + GearName( Plot ) + BStr( T ) + ' Predefined Element ' + BStr( ElementID( Plot , t ) ) + ' Not Found!' )
				else DialogMsg( 'PLOT ELEMENT ' + BStr( T ) + ': ' + ElementName( Adventure , Plot , T , GB ) );
			end;
		end;

		if Debug or ( GearName( Plot ) = 'DEBUG' ) then begin
			if ElementID( Plot , T ) <> 0 then DialogMsg( BStr( T ) + '=> ' + BStr( ElementID( Plot , T ) ) );
		end;

		EverythingOK := EverythingOK and OKNow;
	end;

	if EverythingOK then begin
		{ The plot has been successfully installed into the }
		{ adventure. Initialize the stuff... rumor strings }
		{ mostly. }
		{ Quest content doesn't get initialized here- that gets done later. }
		if DoFullInit then InitPlot( Adventure , Plot , GB );

		{ Actually, quest content does get its treasures initialized here... }
		InitRandomLoot( Plot^.InvCom );
		InitRandomLoot( Plot^.SubCom );

		{ ...and, now that I think about it, prefab moods should grab their elements now. }
		InitPrefabMoods( Slot , Plot );

		{ Also store the names of all known elements. They might come in handy later. }
		for t := 1 to Num_Plot_Elements do begin
			{ Store the name of this element, which should still be stored in }
			{ the FSE array. }
			if GB <> Nil then begin
				SetSAtt( Plot^.SA , 'NAME_' + BStr( T ) + ' <' + ElementName( Adventure , Plot , T , GB ) + '>' );
			end else begin
				SetSAtt( Plot^.SA , 'NAME_' + BStr( T ) + ' <' + GearName( Fast_Seek_Element[ 1 , t ] ) + '>' );
			end;
		end;
	end else begin
		{ This plot won't fit in this adventure. Dispose of it. }
		{ First get rid of any already-placed prefab elements. }
		for t := 1 to Num_Plot_Elements do begin
			E := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			if AStringHasBString( E , 'PREFAB' ) then begin
				PFE := SeekPlotElement( Adventure , Plot , T , GB );
				if PFE <> Nil then begin
					if IsSubCom( PFE ) then begin
						RemoveGear( PFE^.Parent^.SubCom , PFE );
					end else if IsInvCom( PFE ) then begin
						RemoveGear( PFE^.Parent^.InvCom , PFE );
					end else if ( GB <> Nil ) and IsFoundAlongTrack( GB^.Meks , PFE ) then begin
						RemoveGear( GB^.Meks , PFE );
					end;
				end; {if PFE <> Nil}
			end;			
		end;

		RemoveGear( Plot^.Parent^.InvCom , Plot );
	end;

	MatchPlotToAdventure := EverythingOK;
end;

Function InsertStory( Slot,Story: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Stick STORY into SLOT, selecting Actors and Locations }
	{ as required. If everything is found, insert STORY as an InvCom }
	{ of the SLOT. Otherwise, delete it. }
begin
	InsertStory := MatchPlotToAdventure( FindRoot( Slot ) , Slot , Story , GB , True, True , False );
end;

Function DoElementGrabbing( Scope,Slot,Plot: GearPtr ): Boolean;
	{ Attempt to grab elements from the story to insert into the plot. }
	{ Return TRUE if the elements were grabbed successfully, or FALSE }
	{ if they could not be grabbed for whatever reason. }
var
	EverythingOK: Boolean;
	T,N: Integer;
	Desc: String;
	P2: GearPtr;
begin
	EverythingOK := True;

	if Scope^.G = GG_CityMood then Slot := Scope;

	if ( SLOT^.G = GG_Story ) or ( SLOT^.G = GG_CityMood ) then begin
		for t := 1 to Num_Plot_Elements do begin
			{ If an element grab is requested, process that now. }
			desc := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			if ( desc <> '' ) and ( UpCase( desc[1] ) = 'G' ) then begin
				ExtractWord( desc );
				N := ExtractValue( desc );
				desc := SAttValue( Slot^.SA , 'ELEMENT' + BStr( N ) );

				if Desc = '' then begin
					DialogMsg( 'ERROR: ' + GearName( Plot ) + ' tried to grab empty element ' + BStr( N ) + ' from ' + GearName( Slot ) );
					EverythingOK := False;
				end else begin
					{ Only copy over the first character of the element description, }
					{ since that's all we need, and also because copying a PREFAB tag }
					{ may result in story elements being unnessecarily deleted. }
					SetSAtt( Plot^.SA , 'ELEMENT' + BStr( T ) + ' <' + desc[1] + '>' );
					SetNAtt( Plot^.NA , NAG_ElementID , T , ElementID( Slot , N ) );

					{ If this gear is a character, better see whether or not }
					{ it is already involved in a plot. }
					if ( ElementID( Plot , T ) <> 0 ) and ( UpCase( Desc[1] ) = 'C' ) then begin
						{ Clear the Plot's stat for now, to keep it from }
						{ being returned by SeekPlotElement. }
						N := ElementID( Plot , T );
						SetNAtt( Plot^.NA , NAG_ElementID , T , 0 );

						P2 := FindPersonaPlot( FindRoot( Slot ) , N );
						if P2 <> Nil then begin
							EverythingOK := False;
						end;

						SetNAtt( Plot^.NA , NAG_ElementID , T , N );
					end;
				end;
			end;
		end;
	end;	{ If Slot^.G = GG_Story }
	DoElementGrabbing := EverythingOK;
end;

Function InsertSubPlot( Scope,Slot,SubPlot: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Stick SUBPLOT into SLOT, but better not initialize anything. }
var
	InitOK: Boolean;
begin
	InitOK := DoElementGrabbing( Scope , Slot , SubPlot );
	InitOK := InitOK and MatchPlotToAdventure( Scope , Slot , SubPlot , GB , False , False , False );

	InsertSubPlot := InitOK;
end;

Function InsertPlot( Scope,Slot,Plot: GearPtr; GB: GameBoardPtr; Threat: Integer ): Boolean;
	{ Stick PLOT into SLOT, selecting Actors and Locations }
	{ as required. If everything is found, insert PLOT as an InvCom }
	{ of SLOT. Otherwise, delete it. }
	{ All element searches will be restricted to descendants of SCOPE. }
	{ If SLOT is a story, copy over grabbed elements and so on. }
begin
	InsertPlot := InitMegaPlot( GB , Scope , Slot , Plot , Threat ) <> Nil;
end;

Function InsertMood( City,Mood: GearPtr; GB: GameBoardPtr ): Boolean;
	{ This function will insert a mood into the adventure and move it to its correct place. }
var
	AllOK: Boolean;
	TimeLimit: LongInt;
	Trigger: String;
	Dictionary: SAttPtr;
begin
	AllOK := MatchPlotToAdventure( City , City , Mood , GB , False , False , False );

	if AllOK then begin
		DelinkGear( City^.InvCom , Mood );
		InsertSubCom( City , Mood );

		{ Set the time limit, if appropriate. }
		TimeLimit := NAttValue( Mood^.NA , NAG_MoodData , NAS_MoodTimeLimit );
		if TimeLimit > 0 then SetNAtt( Mood^.NA , NAG_MoodData , NAS_MoodTimeLimit , TimeLimit + GB^.ComTime );

		{ Do string substitutions- %name1%..%name20%, %city% }
		Dictionary := Nil;
		SetSAtt( Dictionary , '%city% <' + GearName( City ) + '>' );
		for TimeLimit := 1 to Num_Plot_Elements do begin
			SetSAtt( Dictionary , '%me_' + BStr( TimeLimit ) + '% <' + BStr( ElementID( Mood, TimeLimit ) ) + '>' );
			SetSAtt( Dictionary , '%me_name' + BStr( TimeLimit ) + '% <' + SAttValue( Mood^.SA , 'NAME_' + BStr( TimeLimit ) ) + '>' );
		end;
		ReplaceStrings( Mood , Dictionary );
		DisposeSAtt( Dictionary );

		{ Run the mood's initialization code. }
		Trigger := 'UPDATE';
		TriggerGearScript( GB , Mood , Trigger );
	end;

	InsertMood := AllOK;
end;

Function InsertRSC( Source,Frag: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Insert random scene content, then save some information that will be }
	{ needed later. }
begin
	InsertRSC := MatchPlotToAdventure( FindRoot( Source ) , Source , Frag , GB , True , True , False );;
end;

Procedure EndPlot( GB: GameBoardPtr; Adv,Plot: GearPtr );
	{ This plot is over... }
	Procedure DelinkAndPutAway( var LList: GearPtr );
		{ Delink and put away everything you find that needs }
		{ to be saved in this list. }
	var
		M,M2: GearPtr;
	begin
		M := LList;
		while M <> Nil do begin
			DelinkAndPutAway( M^.InvCom );
			DelinkAndPutAway( M^.SubCom );
			M2 := M^.Next;
			if NAttValue( M^.NA , NAG_ParaLocation , NAS_OriginalHome ) <> 0 then begin
				if StdPlot_Debug then DialogMsg( 'EndPlot: Putting away ' + GearName( M ) + '.' );
				DelinkGear( LList , M );
				PutAwayGlobal( GB , M );
			end;
			M := M2;
		end;
	end;
var
	P2,P3: GearPtr;
begin
	{ Deal with metascenes and other things that need to be cleaned up. }
	P2 := Plot^.SubCom;
	while ( P2 <> Nil ) do begin
		P3 := P2^.Next;

		{ Deal with metascenes as well. }
		if ( P2^.G = GG_MetaScene ) then begin
			{ This metascene has to be deleted. Remove everything from it. }
			if GB^.Scene = P2 then begin
				{ If this scene is the current scene, just turn it into }
				{ a dynamic scene and it'll be deleted automatically }
				{ when the player exits. }
				DelinkGear( Plot^.SubCom , P2 );
				if ( P2^.S >= 1 ) and ( P2^.S <= Num_Plot_Elements ) then P2^.S := ElementID( Plot , P2^.S );
				InsertInvCom( FindRoot( Plot ) , P2 );

			end else begin
				{ Search for global gears in the invcom, storing them as needed. }
				DelinkAndPutAway( P2^.InvCom );
				DelinkAndPutAway( P2^.SubCom );
				DeleteFrozenLocation( GearName( P2 ) , GB^.Camp^.Maps );
			end;

		end;

		P2 := P3;
	end;

	{ Finally, set the PLOT's type to absolutely nothing, so it will }
	{ be removed. }
	Plot^.G := GG_AbsolutelyNothing;
end;

Function AddRandomPlot( GB: GameBoardPtr; Slot: GearPtr; Context: String; EList: ElementTable; Threat: Integer ): Boolean;
	{ Attempt to locate and add a plot with the requested context. }
	{ EList is a list of element values with which to seed the plot. }
	{ Return TRUE if the plot is successfully loaded, or FALSE otherwise. }
var
	Adv,Scene,Part: GearPtr;
	T: Integer;
	msg: String;
	Shopping_List: NAttPtr;
	InitOK: Boolean;
begin
	{ Step One- Fill out the context, including element descriptions. }
	Adv := FindRoot( GB^.Scene );
	Scene := FindRootScene( GB^.Scene );

	for t := 1 to Num_Plot_Elements do begin
		{ If this element represents a palette entry, add its info }
		{ to the context. }
		if EList[ t ].EValue <> 0 then begin
			Part := SeekGearByElementDesc( Adv , EList[ t ].EType , EList[ t ].EValue , GB );
			msg := BStr( T );
			AddGearXRContext( GB , Adv , Part , Context , msg[1] );
		end;
	end;

	{ Step Two- Create a shopping list of contenders. }
	{  If no appropriate plots are found, exit now. }
	Shopping_List := CreateComponentList( Standard_Plots , Context );
	if Shopping_List = Nil then Exit( False );

	{ Step Three- Keep trying until the list is empty or a plot is loaded. }
	InitOK := False;
	repeat
		Part := SelectComponentFromList( Standard_Plots , Shopping_List );

		if Part <> Nil then begin
			Part := CloneGear( Part );

			{ Copy over the parameters. }
			for t := 1 to Num_Plot_Elements do begin
				{ If this element represents a palette entry, add its info }
				{ to the context. }
				if EList[ t ].EValue <> 0 then begin
					SetNAtt( Part^.NA , NAG_ElementID , T , EList[ t ].EValue );
					SetSAtt( Part^.SA , 'ELEMENT' + BStr( T ) + ' <' + EList[ t ].EType + '>' );
				end;
			end;

			InitOK := InsertPlot( Adv , Slot , Part , GB , threat );
		end else InitOK := False;
	until ( Shopping_List = Nil ) or InitOK;

	DisposeNAtt( Shopping_List );

	AddRandomPlot := InitOK;
end;

Procedure PrepareNewComponent( Story: GearPtr; GB: GameBoardPtr );
	{ Load a new component for this story. }
	Procedure StoreXXRanHistory( C: GearPtr );
		{ Store the details of this component in the story. }
	var
		msg: String;
		T: Integer;
	begin
		AddSAtt( Story^.SA , 'XXRAN_SEQUENCE' , GearName( C ) );
		msg := '';
		for t := 1 to num_plot_elements do begin
			msg := msg + '[' + BStr( T ) + ':' + BStr( ElementID( Story , t ) ) + ']';
		end;
		AddSAtt( Story^.SA , 'XXRAN_SSTATE' , msg );
		msg := '';
		for t := 1 to num_plot_elements do begin
			msg := msg + '[' + BStr( T ) + ':' + BStr( ElementID( C , t ) ) + ']';
		end;
		AddSAtt( Story^.SA , 'XXRAN_PSTATE' , msg );
	end;
var
	C: GearPtr;
	Shopping_List: NAttPtr;
	plot_desc: String;
	MergeOK: Boolean;
begin
	plot_desc := StoryContext( GB , Story );
	Shopping_List := CreateComponentList( Standard_Plots , plot_desc );

	{ If xxran debug is on, print some extra information. }
	if XXRan_Debug then begin
		if NumNAtts( Shopping_List ) < 5 then begin
			DialogMsg( '[DEBUG] Only ' + BStr( NumNatts( Shopping_List ) ) + ' components for "' + plot_desc + '".' );
		end;
	end;

	repeat
		if XXRan_Wizard and ( Shopping_List <> Nil ) then begin
			C := ComponentMenu( Standard_Plots , Shopping_List );
		end else begin
			C := SelectComponentFromList( Standard_Plots , Shopping_List );
		end;

		if C <> Nil then begin
			C := CloneGear( C );
			MergeOK := InsertPlot( FindRoot( Story ) , Story , C , GB , NAttValue( Story^.NA , NAG_Narrative , NAS_DifficultyLevel ) );
		end else MergeOK := False;
	until MergeOK or ( Shopping_List = Nil );

	if MergeOK then begin
		{ Assign a ComponentID to the new component. }
		SetNAtt( C^.NA , NAG_XXRan , NAS_ComponentID , NAttValue( Story^.NA , NAG_XXRan , NAS_ComponentID ) );
		AddNAtt( Story^.NA , NAG_XXRan , NAS_ComponentID , 1 );
		SetTrigger( GB , 'UPDATE' );

		{ Store the name of this component for reference. }
		StoreXXRanHistory( C );
	end else begin
		DialogMsg( 'Plot deadend in ' + GearName( Story ) + ': ' + plot_desc );
		DialogMsg( 'Send above information to "pyrrho12@yahoo.ca". Together, we can stomp out deadends.' );
	end;

	DisposeNAtt( Shopping_List );
end;

Function InsertArenaMission( Source,Mission: GearPtr; ThreatAtGeneration: Integer ): Boolean;
	{ Insert an arena mission into the campaign. }
var
	it: Boolean;
	P: GearPtr;
	T: Integer;
	EDesc: String;
begin
	{ Look through the elements. If KEY was requested, replace it with the }
	{ core campaign enemy faction. }
	for t := 1 to Num_Plot_Elements do begin
		EDesc := UpCase( SAttValue( Mission^.SA , 'ELEMENT' + BStr( T ) ) );
		if EDesc = 'KEY' then begin
			SetSAtt( Mission^.SA , 'ELEMENT' + BStr( T ) + ' <FACTION ENEMY>' );
			SetNAtt( Mission^.NA , NAG_ElementID , T , NAttValue( Source^.NA , NAG_AHQData , NAS_CoreMissionEnemy ) );
		end;
	end;

	{ Attempt the plot insertion. }
	it := InsertPlot( Source , Source , Mission , Nil , ThreatAtGeneration );

	{ If the mission was successfully added, we need to do extra initialization. }
	if it then begin
		{ Set correct PersonaIDs for all the personas involved. }
		P := Mission^.SubCom;
		while P <> Nil do begin
			if P^.G = GG_Persona then begin
				P^.S := ElementID( Mission , P^.S );
			end;
			P := P^.Next;
		end;
	end;

	InsertArenaMission := it;
end;

Procedure UpdatePlots( GB: GameBoardPtr; Renown: Integer );
	{ It's time to update the plots. Check the city, and also its associated moods. }
	{ For each one, check to see how many associated plots it has, then try to load }
	{ a new plot if there's any room. }
var
	Adv,City,Mood: GearPtr;
	Context: String;
	Function GetControllerID( Controller: GearPtr ): LongInt;
		{ Get the Controller ID for this controller. If no Controller ID is found, }
		{ assign a new one. }
	var
		CID: LongInt;
	begin
		CID := NAttValue( Controller^.NA , NAG_Narrative , NAS_ControllerID );
		if CID = 0 then begin
			AddNAtt( Adv^.NA , NAG_Narrative , NAS_MaxControllerID , 1 );
			CID := NAttValue( Adv^.NA , NAG_Narrative , NAS_MaxControllerID );
			SetNAtt( Controller^.NA , NAG_Narrative , NAS_ControllerID , CID );
		end;
		GetControllerID := CID;
	end;
	Function NumAttachedPlots( CID: LongInt ): Integer;
		{ Return the total number of plots attached to this Controller ID. }
	var
		P: GearPtr;
		Total: Integer;
	begin
		P := Adv^.InvCom;
		Total := 0;
		while P <> Nil do begin
			if ( P^.G = GG_Plot ) and ( NAttValue( P^.NA , NAG_Narrative , NAS_ControllerID ) = CID ) then Inc( Total );
			P := P^.Next;
		end;
		NumAttachedPlots := Total;
	end;
	Function NumAllowedPlots( Controller: GearPtr ): Integer;
		{ Return the maximum number of plots that this controller can have attached. }
	begin
		if Controller^.G = GG_CityMood then begin
			NumAllowedPlots := Controller^.V;
		end else begin
			NumAllowedPlots := 10;
		end;
	end;
	Procedure AddAPlot( Controller: GearPtr );
		{ Select a legal plot for this controller and attempt to insert it into }
		{ the adventure. }
	var
		plot_cmd: String;
		Plot: GearPtr;
		ShoppingList: NAttPtr;
		N: Integer;
		ItWorked: Boolean;
	begin
		{ Determine the plot type being requested. If no explicit request is found, }
		{ go with a *GENERAL plot. }
		plot_cmd := SAttValue( Controller^.SA , 'PLOT_TYPE' );
		if plot_cmd = '' then plot_cmd := '*GENERAL';
		plot_cmd := plot_cmd + ' ' + Context;

		{ If the controller is a mood, add details of its first 9 elements. }
		if Controller^.G = GG_CityMood then begin
			for N := 1 to 9 do begin
				{ If this element represents to a palette entry, add its info }
				{ to the context. }
				if SAttValue( Controller^.SA , 'ELEMENT' + BStr( N ) ) <> '' then AddElementContext( GB , Controller , plot_cmd , BStr( N )[1] , N );
			end;
		end;

		{ Next, create a list of those plots which match the plot_cmd. }
		ShoppingList := Nil;
		Plot := Standard_Plots;
		N := 1;
		while Plot <> Nil do begin
			if ( Plot^.G = GG_Plot ) and ( StringMatchWeight( plot_cmd , SAttValue( Plot^.SA , 'REQUIRES' ) ) > 0 ) then begin
				SetNAtt( ShoppingList , N , N , 5 );
			end;
			Plot := Plot^.Next;
			Inc( N );
		end;

		{ If we have some matches, select one at random and give it a whirl. }
		if ShoppingList <> Nil then begin
			Plot := CloneGear( SelectComponentFromList( Standard_Plots , ShoppingList ) );

			{ Mark this plot with our ComponentID, }
			{ and store the plot stuff. }
			SetNAtt( Plot^.NA , NAG_Narrative , NAS_ControllerID , GetControllerID( Controller ) );
			SetSAtt( Plot^.SA , 'SPCONTEXT <' + Context + '>' );

			if StdPlot_Debug then DialogMsg( 'Attempting to insert ' + GearName( Plot ) );

			{ Attempt to add this plot to the adventure. }
			ItWorked := InsertPlot( Controller , Adv , Plot , GB , Renown );

			if StdPlot_Debug then begin
				if ItWorked then DialogMsg( 'Plot insertion succeeded.' )
				else DialogMsg( 'Plot insertion failed.' );
			end;

			{ Get rid of the shopping list. }
			DisposeNAtt( ShoppingList );
		end;
	end;
	Procedure CheckAttachedPlots( Controller: GearPtr );
		{ Check to see how many plots are associated with this controller. }
		{ If more plots are needed, add one. }
	var
		ControllerID: LongInt;
		Attached,Allowed: Integer;
	begin
		ControllerID := GetControllerID( Controller );

		{ Count how many plots are being used by the city and each of its moods. }
		Allowed := NumAllowedPlots( Controller );

		{if XXRan_Debug and ( Controller^.G = GG_Scene ) then DialogMsg( GearName( Controller ) + ': ' + BStr( NumAttachedPlots( ControllerID ) ) + '/' + Bstr( Allowed ) );}
		if Allowed > 0 then begin
			Attached := NumAttachedPlots( ControllerID );

			{ If we have room for some more plots, try adding one. }
			if Attached < Allowed then begin
				AddAPlot( Controller );
			end;
		end;
	end;
begin
	{ Locate the adventure and the city. These will be important. }
	Adv := FindRoot( GB^.Scene );
	City := FindRootScene( GB^.Scene );

	{ If either the adventure or the city cannot be found, exit. }
	if ( Adv = Nil ) or ( Adv^.G <> GG_Adventure ) or ( City = Nil ) then Exit;

	{ Determine the city context. This will be affected by moods. }
	Context := SceneContext( GB , City ) + DifficulcyContext( Renown );
	Mood := City^.SubCom;
	while Mood <> Nil do begin
		if Mood^.G = GG_CityMood then begin
			AddTraits( Context , SAttValue( Mood^.SA , 'TYPE' ) );
		end;
		Mood := Mood^.Next;
	end;
	Context := QuoteString( Context );

	{ Go through the city and the moods one by one. If there's a free space for a plot, }
	{ attempt to load one. }
	CheckAttachedPlots( City );
	Mood := City^.SubCom;
	while Mood <> Nil do begin
		if Mood^.G = GG_CityMood then CheckAttachedPlots( Mood );
		Mood := Mood^.Next;
	end;
end;

Procedure UpdateMoods( GB: GameBoardPtr );
	{ Check through all the towns in the current world. Check the time limits on all }
	{ moods found, removing those that have expired. If a town has no mood attached, }
	{ consider attaching one. }
	Function SetNewMood( Scene: GearPtr ): Boolean;
		{ Attempt to attach a new mood to this scene. Return TRUE if a mood was }
		{ added successfully, or FALSE if it wasn't. }
	var
		scene_context: String;
		Mood: GearPtr;
		InitOK: Boolean;
	begin
		scene_context := SceneContext( GB , Scene );
		Mood := FindNextComponent( Standard_Moods , scene_context );
		InitOK := False;
		if Mood <> Nil then begin
			{ We don't want to use the entry from the standard mood list; }
			{ make a clone of it that we're free to whack around. }
			Mood := CloneGear( Mood );
			SetNAtt( Mood^.NA , NAG_MoodData , NAS_MoodTimeLimit , 86400 + Random( 86400 ) + Random( 86400 ) );
			InitOK := InsertMood( Scene , Mood , GB );
		end;
		SetNewMood := InitOK;
	end;
	Procedure UpdateMoodsForScene( Scene: GearPtr );
		{ Check to see if this scene has any moods. Delete those moods which }
		{ have outlived their usefulness. If no moods were found, consider }
		{ adding one. }
	var
		Mood,M2: GearPtr;
		MoodFound: Boolean;
		TimeLimit: LongInt;
	begin
		{ If Scene = Nil, we have a major problem. }
		if Scene = Nil then Exit;

		{ No mood found yet- we haven't started searching! }
		MoodFound := False;

		{ Look through all the moods in this scene and decide what to do with them. }
		Mood := Scene^.SubCom;
		while Mood <> Nil do begin
			M2 := Mood^.Next;
			if Mood^.G = GG_CityMood then begin
				{ Even if this mood is getting deleted, we don't want to load }
				{ a new one right away, so set MOODFOUND to TRUE... as long as }
				{ it's a major mood. Otherwise, who cares about it? }
				if Mood^.S = GS_MajorMood then MoodFound := True;

				{ Check the time limit now. }
				TimeLimit := NAttValue( Mood^.NA , NAG_MoodData , NAS_MoodTimeLimit );
				if ( TimeLimit > 0 ) and ( TimeLimit < GB^.ComTime ) then begin
					RemoveGear( Scene^.SubCom , Mood );
				end;
			end;
			Mood := M2;
		end;

		{ If no moods were found, maybe add a new mood. }
		if ( not MoodFound ) and ( NAttValue( Scene^.NA , NAG_Narrative , NAS_MoodRecharge ) <= GB^.ComTime ) then begin
			{ There's a chance of loading a new mood. }
			{ NIEHH: Nothing Interesting Ever Happens Here. If the scene being examined is the }
			{ town the PC is currently in, no new mood will be loaded. }
			if ( Random( 5 ) = 1 ) and ( Scene <> FindRootScene( GB^.Scene ) ) then begin
				{ Try to set a mood. }
				{ If setting the mood fails, set the recharge timer. }
				if not SetNewMood( Scene ) then SetNAtt( Scene^.NA , NAG_Narrative , NAS_MoodRecharge , GB^.ComTime + 7200 + Random( 43200 ) );
			end else begin
				{ No mood this time- try again in a day or so. }
				SetNAtt( Scene^.NA , NAG_Narrative , NAS_MoodRecharge , GB^.ComTime + 43200 + Random( 86400 ) );
			end;
		end;
	end;
var
	World, Scene: GearPtr;
begin
	World := FindWorld( GB , GB^.Scene );
	if World <> Nil then begin
		Scene := World^.SubCom;
		while Scene <> Nil do begin
			UpdateMoodsForScene( Scene );
			Scene := Scene^.Next;
		end;
	end;
end;

Procedure CreateChoiceList( GB: GameBoardPtr; Story: GearPtr );
	{ It's time for the PC to make a dramatic choice. Create a list of }
	{ legal choices, attempt to add them to the story, then mark the ones }
	{ which load with a tag to indicate their nature. }
var
	Context: String;
	LList,DC: GearPtr;
	DCRS,t,N: Integer;	{ Dramatic Choice Reward Seed, plus two counters }
	DCRList: Array [0..4] of Byte;	{ Dramatic Choice Reward List }
begin
	{ Step One: Determine the choice context. }
	Context := StoryContext( GB , Story );

	{ Determine which instant reward will be eligible for loading. }
	{ The reward choices are numbered 11 to 20. 16 through 20 are second-tier }
	{ copies of 11 through 15. }
	N := 0;
	{ Only add a reward option if we are not yet at the conclusion. }
	if NAttValue( Story^.NA , NAG_Narrative , NAS_DifficultyLevel ) <= 80 then begin
		DCRS := NAttValue( Story^.NA , NAG_XXRan , NAS_DCRSeed );
		if DCRS = 0 then begin
			DCRS := Random( 20000 ) + 1;
			SetNAtt( Story^.NA , NAG_XXRan , NAS_DCRSeed , DCRS );
		end;
		DCRS := DCRS + NAttValue( Story^.NA , NAG_XXRan , NAS_EpisodeNumber );
		for t := 11 to 15 do begin
			if NAttValue( Story^.NA , NAG_Completed_DC , T ) = 0 then begin
				DCRList[N] := T;
				Inc( N );
			end;
		end;
		if N > 0 then begin
			N := DCRList[ DCRS mod N ];
		end else begin
			{ All of the first-tier rewards have been completed. Check the }
			{ second tier. }
			N := 0;
			for t := 16 to 20 do begin
				if NAttValue( Story^.NA , NAG_Completed_DC , T ) = 0 then begin
					DCRList[N] := T;
					Inc( N );
				end;
			end;
			if N > 0 then N := DCRList[ DCRS mod N ];
		end;
	end;

	{ Step Two: Go through the list of dramatic choices. Try to add all }
	{ which apply in this situation. }
	LList := Dramatic_Choices;
	while LList <> Nil do begin
		{ A choice can be added if: }
		{ - It was the reward option selected and stored in N. }
		{  or   }
		{ - Its REQUIRES field is satisfied by the context generated above. }
		{ - It has not already been completed. }
		if ( LList^.V > 0 ) then begin
			if ( LList^.V = N ) or ( ( ( LList^.V < 11 ) or ( LList^.V > 20 ) ) and ( NAttValue( Story^.NA , NAG_Completed_DC , LList^.V ) = 0 ) and PartMatchesCriteria( Context , SAttValue( LList^.SA , 'REQUIRES' ) ) ) then begin
				DC := CloneGear( LList );
				if InsertPlot( FindRoot( GB^.Scene ) , Story , DC , GB , NAttValue( Story^.NA , NAG_Narrative , NAS_DifficultyLevel ) ) then begin
					SetNAtt( DC^.NA , NAG_XXRan , NAS_IsDramaticChoicePlot , 1 );
				end;
			end;
		end;
		LList := LList^.Next;
	end;
end;


Procedure ClearChoiceList( Story: GearPtr );
	{ The PC has apparently made a choice. Get rid of all the choice }
	{ records from this story since we don't need them anymore. }
var
	DC,DC2: GearPtr;
begin
	DC := Story^.InvCom;
	while DC <> Nil do begin
		DC2 := DC^.Next;
		if NAttValue( DC^.NA , NAG_XXRan , NAS_IsDramaticChoicePlot ) <> 0 then begin
			RemoveGear( Story^.InvCom , DC );
		end;
		DC := DC2;
	end;
end;



initialization
	persona_fragments := AggregatePattern( 'PFRAG_*.txt' , series_directory );
	if persona_fragments = Nil then writeln( 'ERROR!!!' );
	Standard_Plots := LoadRandomSceneContent( 'PLOT_*.txt' , series_directory );
	Standard_Moods := AggregatePattern( 'MOOD_*.txt' , series_directory );
	Dramatic_Choices := AggregatePattern( 'CHOICE_*.txt' , series_directory );

finalization
	DisposeGear( persona_fragments );
	DisposeGear( Standard_Plots );
	DisposeGear( Standard_Moods );
	DisposeGear( Dramatic_Choices );

end.
