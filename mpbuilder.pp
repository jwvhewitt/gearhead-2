unit mpbuilder;
	{ MEGA PLOT ASSEMBLE! It's like a Voltron of narrative content! }
	{ This unit contains the functions and procedures for creating }
	{ big amalgamations of components. }
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

uses gears,locale,narration;

Type
	ElementDesc = Record
		EType: Char;
		EValue: LongInt;
	end;
	{ I feel just like Dmitri Mendelev writing this... }
	ElementTable = Array [1..Num_Plot_Elements] of ElementDesc;

var
	Sub_Plot_List: GearPtr;


Procedure ReplaceStrings( Part: GearPtr; Dictionary: SAttPtr );
Function ComponentMenu( CList: GearPtr; var ShoppingList: NAttPtr ): GearPtr;
Procedure ClearElementTable( var ET: ElementTable );

Function ExpandDungeon( Dung: GearPtr ): GearPtr;
Procedure ConnectScene( Scene: GearPtr; DoInitExits: Boolean );

Function InitMegaPlot( GB: GameBoardPtr; Scope,Slot,Plot: GearPtr; Threat: Integer ): GearPtr;

Function LoadQuestFragments: GearPtr;
Function AddQuest( Adv,City,QPF_Proto: GearPtr; var Quest_Frags: GearPtr; QReq: String ): Boolean;


implementation

uses playwright,texutil,gearutil,gearparser,ghchars,randmaps,
	ui4gh,wmonster,rpgdice,ghprop,ability,
{$IFDEF ASCII}
	vidgfx,vidmenus;
{$ELSE}
	sdlgfx,sdlmenus;
{$ENDIF}

Const
	Num_Sub_Plots = 8;

Var
	standard_trigger_list: SAttPtr;
	changes_used_so_far: String;
	MasterEntranceList: GearPtr;


Procedure ComponentMenuRedraw;
	{ The redraw for the component selector below. }
begin
	ClrScreen;
	InfoBox( ZONE_Menu );
	InfoBox( ZONE_Info );
	InfoBox( ZONE_Caption );
	GameMsg( 'Select the next component in the core story.', ZONE_Caption , StdWhite );
	RedrawConsole;
end;

Function ComponentMenu( CList: GearPtr; var ShoppingList: NAttPtr ): GearPtr;
	{ Select one of the components from a menu. }
var
	RPM: RPGMenuPtr;
	C: GearPtr;
	N: Integer;
	SL: NAttPtr;
begin
	RPM := CreateRPGMenu( MenuItem, MenuSelect , ZONE_Menu );
	AttachMenuDesc( RPM , ZONE_Info );
	SL := ShoppingList;
	while SL <> Nil do begin
		C := RetrieveGearSib( CList , SL^.S );
		AddRPGMenuItem( RPM , '[' + BStr( SL^.V ) + ']' + GearName( C ) , SL^.S , SAttValue( C^.SA , 'DESC' ) );
		SL := SL^.Next;
	end;

	N := SelectMenu( RPM , @ComponentMenuRedraw );
	SetNAtt( ShoppingList , 0 , N , 0 );
	DisposeRPGMenu( RPM );
	ComponentMenu := RetrieveGearSib( CList , N );
end;

Function NewPlotID( Adv: GearPtr; IsAQuest: Boolean ): LongInt;
	{ Calculate a new unique Plot ID. }
	{ Plots have positive PlotIDs, quests have negative PlotIDs. }
begin
	{ Increase the previous ID by one, and return that. }
	AddNAtt( Adv^.NA , NAG_Narrative , NAS_MaxPlotID , 1 );
	if IsAQuest then begin
		NewPlotID := -NAttValue( Adv^.NA , NAG_Narrative , NAS_MaxPlotID );
	end else begin
		NewPlotID := NAttValue( Adv^.NA , NAG_Narrative , NAS_MaxPlotID );
	end;
end;

Function NewLayerID( Slot: GearPtr ): LongInt;
	{ Calculate a new unique Layer ID. }
begin
	{ Increase the previous ID by one, and return that. }
	AddNAtt( Slot^.NA , NAG_Narrative , NAS_MaxPlotLayer , 1 );
	NewLayerID := NAttValue( Slot^.NA , NAG_Narrative , NAS_MaxPlotLayer );
end;

Procedure ClearElementTable( var ET: ElementTable );
	{ Clear this table's stored elements by setting all IDs }
	{ to zero. }
var
	t: Integer;
begin
	for t := 1 to Num_Plot_Elements do begin
		ET[t].EValue := 0;
	end;
end;

Procedure CreatePlotPlaceholder( Slot , Shard: GearPtr );
	{ Create a new plot gear to hold all of SHARD's elements, and store it }
	{ in SLOT. IT will be marked with a PlotLayer of -(plotlayer), and this marking }
	{ will be used to dispose of all the placeholders after assembly. }
var
	it: GearPtr;
	T: Integer;
	EID: LongInt;
begin
	it := NewGear( Slot );
	InsertInvCom( Slot , It );
	it^.G := GG_Plot;
	SetSAtt( it^.SA , 'name <Placeholder>' );
	SetNAtt( it^.NA , NAG_Narrative , NAS_PlotLayer , -NAttValue( Shard^.NA , NAG_Narrative , NAS_PlotLayer ) );
	for t := 1 to Num_Plot_Elements do begin
		EID := ElementID( Shard , T );
		if EID <> 0 then begin
			SetNAtt( It^.NA , NAG_ElementID , T , EID );
			SetSAtt( It^.SA , 'ELEMENT' + BStr( T ) + ' <' + SAttValue( Shard^.SA , 'ELEMENT' + BStr( T ) ) + '>' );
		end;
	end;
end;

Procedure DeleteSpecificPlaceholder( Slot,Shard: GearPtr );
	{ Delete the placeholder belonging specifically to this shard. }
var
	p,p2: GearPtr;
	plotid: LongInt;
begin
	plotid := -NAttValue( Shard^.NA , NAG_Narrative , NAS_PlotLayer );
	P := Slot^.InvCom;
	while P <> Nil do begin
		P2 := P^.Next;
		if NAttValue( P^.NA , NAG_Narrative , NAS_PlotLayer ) = PlotID then begin
			RemoveGear( Slot^.InvCom , P );
		end;
		P := P2;
	end;
end;

Procedure DeletePlotPlaceholders( Slot: GearPtr );
	{ Delete all the plot placeholders. They should be invcoms of SLOT, }
	{ and be marked with negative PlotLayers. }
var
	PP,PP2: GearPtr;
begin
	PP := Slot^.InvCom;
	while PP <> Nil do begin
		PP2 := PP^.Next;
		if NAttValue( PP^.NA , NAG_Narrative , NAS_PlotLayer ) < 0 then RemoveGear( Slot^.InvCom , PP );
		PP := PP2;
	end;
end;

Function AddSubPlot( GB: GameBoardPtr; Scope,Slot,Plot0,QPF_Proto: GearPtr; var Quest_Frags: GearPtr; SPReq: String; EsSoFar, LayerID, SubPlotSlot: LongInt; IsAQuest,DoDebug: Boolean ): GearPtr; forward;

Function InitShard( GB: GameBoardPtr; Scope,Slot,Shard: GearPtr; var Quest_Frags: GearPtr; EsSoFar,PlotID,LayerID,Threat: LongInt; const ParamIn: ElementTable; IsAQuest,DoDebug: Boolean ): GearPtr;
	{ SHARD is a plot fragment candidate. Attempt to add it to the Slot. }
	{ Attempt to add its subplots as well. }
	{ SHARD can only be added if its number of new elements plus the current }
	{ element total is less than the number of total possible elements. }
	{ EsSoFar is the number of elements allocated so far. }
	{ Before initializing a shard, the following will be done: }
	{ - Parameter elements copied over }
	{ - Any character gears present will be randomized }
	{ Initializing includes the following: }
	{ - Set combatant skill levels for quests }
	{ Upon successfully initializing a shard, this procedure will then do the following: }
	{ - Delink the shard from the Slot, and attach all subplots. }
	{ - Create a plot stub and mark it with the PlotID; copy over all elements used by }
	{   this shard and place it as Slot's invcom. This stub is to prevent other shards }
	{   from selecting characters or items used here. }
	{ - Initialize quest metascenes with the PlotID. }
	{ - Return the shard list }
	{ If installation fails, SHARD will be deleted and NIL will be returned. }
	Procedure DisposeSPList( SPList: GearPtr );
		{ Delete this subplot list, taking with it any associated placeholders. }
	var
		SP: GearPtr;
	begin
		while SPList <> Nil do begin
			DeleteSpecificPlaceholder( Slot , SPList );
			SP := SPList;
			RemoveGear( SPList , SP );
		end;
	end;
	Procedure ScaleRandomTreasure( LList: GearPtr );
		{ Scale any random loot values found along this path. }
		{ The treasures found as part of a quest should be }
		{ commesurate with the Difficulty rating of the quest. }
	var
		LootValue: LongInt;
	begin
		while LList <> Nil do begin
			if NAttValue( LList^.NA , NAG_Narrative , NAS_RandomLoot ) > 0 then begin
				LootValue := Calculate_Threat_Points( Threat , 10 + Random( 15 ) );
				SetNAtt( LList^.NA , NAG_Narrative , NAS_RandomLoot , LootValue );
			end;
			ScaleRandomTreasure( LList^.SubCom );
			ScaleRandomTreasure( LList^.InvCom );
			LList := LList^.Next;
		end;
	end;
	Procedure PrepQuestCombatants( LList: GearPtr );
		{ If this is a quest, scale any combatant NPCs to the proper level. }
	begin
		while LList <> Nil do begin
			if ( LList^.G = GG_Character ) then begin
				if NotAnAnimal( Llist ) and IsACombatant( LList ) then begin
					SetSkillsAtLevel( LList , Threat );
				end;
			end;
			LList := LList^.Next;
		end;
	end;

	Procedure InitializeMapFeatures( LList: GearPtr );
		{ Mark all map features, their subs and invs, with the PlotID of the }
		{ parent scene. Why do this? So scripts can then locate the quest }
		{ without too much difficulty. }
	begin
		while LList <> Nil do begin
			if NAttValue( LList^.NA , NAG_Narrative , NAS_PlotID ) = 0 then SetNAtt( LList^.NA , NAG_Narrative , NAS_PlotID , PlotID );
			if LList^.G = GG_MapFeature then begin
				InitializeMapFeatures( LList^.SubCom );
				InitializeMapFeatures( LList^.InvCom );
			end;
			LList := LList^.Next;
		end;
	end;
	Procedure PrepQuestMetascenes( LList: GearPtr );
		{ If this is a quest, mark the map features. }
	begin
		while LList <> Nil do begin
			if ( LList^.G = GG_MetaScene ) then begin
				{ Also mark all of the scene's things with the PlotID, so scripts can locate }
				{ the quest easily. }
				InitializeMapFeatures( LList^.SubCom );
				InitializeMapFeatures( LList^.InvCom );
			end;
			LList := LList^.Next;
		end;
	end;
var
	InitOK: Boolean;
	T,NumParam,NumElem: Integer;
	I,SubPlot,SPList: GearPtr;
	SPID: LongInt;
	SPReq,original_changes,EDesc: String;
begin
	{ Assign the values to this shard. }
	SetNAtt( Shard^.NA , NAG_Narrative , NAS_PlotID , PlotID );
	SetNAtt( Shard^.NA , NAG_Narrative , NAS_PlotLayer , LayerID );
	SetNAtt( Shard^.NA , NAG_Narrative , NAS_DifficultyLevel , Threat );

	{ Scale the random treasure, based upon the threat value provided. }
	ScaleRandomTreasure( Shard^.SubCom );
	ScaleRandomTreasure( Shard^.InvCom );

	{ Record the original changes_used_so_far string; if things go sour in this procedure, }
	{ we're going to have to restore it. }
	original_changes := changes_used_so_far;

	{ Add the changes from this shard. }
	SPReq := SAttValue( Shard^.SA , 'CHANGES' );
	if SPReq <> '' then AddToQuoteString( changes_used_so_far , SPReq );

	{ Start by copying over all provided parameters. }
	{ Also count the number of parameters passed; it could be useful. }
	NumParam := 0;
	for t := 1 to Num_Plot_Elements do begin
		if ParamIn[ t ].EValue <> 0 then begin
			SetNAtt( Shard^.NA , NAG_ElementID , T , ParamIn[ t ].EValue );
			SetSAtt( Shard^.SA , 'ELEMENT' + BStr( T ) + ' <' + ParamIn[ t ].EType + '>' );
			Inc( NumParam );
		end;
	end;

	{ If this is a quest, check the remaining parameters for artifacts. }
	if IsAQuest then begin
		for t := ( NumParam + 1 ) to Num_Plot_Elements do begin
			EDesc := UpCase( SAttValue( Shard^.SA , 'ELEMENT' + BStr( T ) ) );
			if ( EDesc <> '' ) and ( EDesc[1] = 'A' ) then begin
				{ This is an artifact request. If no difficulcy context has been }
				{ defined, add one ourselves. }
				if not AStringHasBString( EDesc , '!' ) then begin
					EDesc := EDesc + ' ' + DifficulcyContext( Threat );
					SetSAtt( Shard^.SA , 'ELEMENT' + BStr( T ) + ' <' + EDesc + '>' );
				end;
			end;
		end;
	end;

	{ Next, randomize the NPCs. }
	{ Only do this is we aren't constructing a quest; if we are, then the }
	{ NPCs have already been individualized. }
	if not IsAQuest then begin
		I := Shard^.InvCom;
		while I <> Nil do begin
			{ Character gears have to be individualized. }
			if ( I^.G = GG_Character ) and NotAnAnimal( I ) then begin
				IndividualizeNPC( I );
			end;
			I := I^.Next;
		end;
	end;

	{ Initialize the subplot list to prevent trouble later on. }
	SPList := Nil;

	{ Attempt the basic content insertion routine. }
	if DoDebug then SetSAtt( Shard^.SA , 'name <DEBUG>' );
	InitOK := InsertSubPlot( Scope, Slot, Shard , GB );

	{ If the installation has gone well so far, time to move on. }
	if InitOK then begin
		{ Count the number of unique elements. If more elements have been }
		{ defined than will fit in a single plot, then loading of this subplot }
		{ will fail. }
		NumElem := 0;
		for t := 1 to Num_Plot_Elements do begin
			if NAttValue( Shard^.NA , NAG_ElementID , T  ) <> 0 then begin
				Inc( NumElem );
			end;
		end;
		NumElem := NumElem - NumParam + EsSoFar;

		if NumElem <= Num_Plot_Elements then begin
			{ We have room for the elements. Good. Now move on by installing the subplots. }

			{ Initialize the prefab NPCs for a quest. }
			if IsAQuest then begin
				PrepQuestCombatants( Shard^.InvCom );
				PrepQuestMetascenes( Shard^.SubCom );
			end;

			{ If any of the needed subplots fail, installation of this shard fails }
			{ as well. }
			{ Arena missions may not request subplots. Sorry, that's just how it is. }
			if Shard^.G <> GG_Scene then begin
				for t := 1 to Num_Sub_Plots do begin
					SPReq := SAttValue( Shard^.SA , 'SUBPLOT' + BStr( T ) );
					if SPReq <> '' then begin
						SPID := NewLayerID( Slot );
						SubPlot := AddSubPlot( GB , Scope , Slot , Shard , Nil , Quest_Frags , SPReq , NumElem , SPID , T , IsAQuest, DoDebug );
						if SubPlot <> Nil then begin
							{ A subplot was correctly installed. Add it to the list. }
							AppendGear( SPList , SubPlot );
							NumElem := NumElem + NAttValue( SubPlot^.NA , NAG_Narrative , NAS_NumSPElementsUsed );
						end else begin
							{ The subplot request failed, meaning that this shard fails }
							{ as well. }
							InitOK := False;
							RemoveGear( Slot^.InvCom , Shard );
							Break;
						end;
					end;
				end;
			end;

		end else begin
			{ We have too many elements to merge back into the main plot. }
			if XXRan_Debug then begin
				DialogMsg( 'ERROR: ' + GearName( Shard ) + ' has too many elements: ' + BStr( NumElem ) + ' / ' + BStr( EsSoFar ) );
				for t := 1 to Num_Plot_Elements do begin
					DialogMsg( ' ' + BStr( T ) + ' ' + SAttValue( Shard^.SA , 'NAME_' + BStr( T ) ) + ' ' + BStr( ElementID( Shard , T ) ) );
				end;
			end;
			InitOk := False;
			RemoveGear( Slot^.InvCom , Shard );
		end;
	end;

	{ Return our result. }
	if InitOk then begin
		{ Delink the shard. }
		DelinkGear( Slot^.InvCom , Shard );

		{ Create the plot placeholder stub, to prevent characters from being }
		{ selected by different parts of the same superplot. }
		CreatePlotPlaceholder( Slot , Shard );

		{ Append the SPList to the shard. }
		AppendGear( Shard , SPList );

		SetNAtt( Shard^.NA , NAG_Narrative , NAS_NumSPElementsUsed , NumElem - EsSoFar );
		InitShard := Shard;
	end else begin
		{ Initialization failed. Delete the existing subplots and restore the }
		{ changes_used_so_far list. }
		changes_used_so_far := original_changes;
		DisposeSPList( SPList );
		InitShard := Nil;
	end;
end;

Function QuestIsReusable( Q: GearPtr ): Boolean;
	{ Return TRUE if this quest is reusable, or FALSE otherwise. }
begin
	QuestIsReusable := AStringHasBString( SAttValue( Q^.SA , 'SPECIAL' ) , 'REUSABLE' );
end;

Function AddSubPlot( GB: GameBoardPtr; Scope,Slot,Plot0,QPF_Proto: GearPtr; var Quest_Frags: GearPtr; SPReq: String; EsSoFar, LayerID, SubPlotSlot: LongInt; IsAQuest,DoDebug: Boolean ): GearPtr;
	{ A request has been issued for a subplot. Search through the plot }
	{ component list and see if there's anything that matches our criteria. }
	{ Plot0 = the plot requesting the subplot. If this is a quest it may be }
	{ nil, but don't you dare try pulling that crap otherwise. }
	{ QPF_PROTO is a prototype of a prefab element to be inserted into a quest. }
	{ QUEST_FRAGS contains a list of quest fragents. If constructing a quest, these may be used }
	{ in addition to the regular megaplot comps. Once a quest fragment is used, it cannot usually }
	{ be used again. }
	Function CreateSubPlotList( const CReq: String ): NAttPtr;
		{ Create the list of legal subplots. Start with the regular ones, }
		{ then if appropriate add the not-in-use quest fragments. }
		{ Regular subplots will be added as positive G,S. }
		{ Quest fragments will be added as negative G,S. }
	var
		CList: NAttPtr;
		N,MW: Integer;
		C: GearPtr;
	begin
		{ Start by adding the standard components. }
		CList := CreateComponentList( Sub_Plot_List , CReq );

		{ Next, add the quest fragments. }
		if IsAQuest and ( Quest_Frags <> Nil ) then begin
			N := -1;
			C := Quest_Frags;
			while C <> nil do begin
				if NAttValue( C^.NA , NAG_Narrative , NAS_QuestInUse ) = 0 then begin
					MW := StringMatchWeight( CReq , SAttValue( C^.SA , 'REQUIRES' ) );
					if MW > 0 then begin
						SetNAtt( CList , N , N , MW );
					end;
				end;
				Dec( N );
				C := C^.Next;
			end;
		end;
		CreateSubPlotList := CList;
	end;
	Function SelectNextSubPlot( var ShoppingList: NAttPtr ): GearPtr;
		{ Select a new subplot prototype, and return a pointer to it. }
		{ If a quest fragment is selected, mark it as used. }
		{ Previously, we'd mark a quest fragment as used when it was selected and }
		{ unmark it if the quest initialization failed. This time around it'll stay }
		{ marked for the duration of this quest; if an earlier component can't }
		{ initialize the fragment, chances are good that a later component in the }
		{ same quest won't be able to either. }
	var
		it: NAttPtr;
		N: Integer;
		Proto: GearPtr;
	begin
		{ Select one of the components, and delete its entry from the }
		{ shopping list. }
		it := RandomComponentListEntry( ShoppingList );
		N := it^.S;
		RemoveNAtt( ShoppingList , it );

		if N < 0 then begin
			Proto := RetrieveGearSib( quest_frags , Abs( N ) );
			if not QuestIsReusable( Proto ) then SetNAtt( Proto^.NA , NAG_Narrative , NAS_QuestInUse , 1 );
		end else begin
			Proto := RetrieveGearSib( sub_plot_list , N );
		end;
		SelectNextSubPlot := Proto;
	end;
var
	ShoppingList: NAttPtr;
	Context,EDesc,SPContext,changes_list: String;
	ParamList: ElementTable;
	T,E,Threat: Integer;
	Shard,QPF_Clone: GearPtr;
	NotFoundMatch: Boolean;
	PlotID: LongInt;
	IsBranchPlot: Boolean;
begin
	{ First determine the context. }
	Context := ExtractWord( SPReq );
	DeleteWhiteSpace( SPReq );

	{ Determine the difficulty rating of this subplot. }
	if ( SPReq <> '' ) and ( SPReq[1] = '#' ) then begin
		DeleteFirstChar( SPReq );
		T := ExtractValue( SPReq );
		if T > 0 then Threat := T;
	end else if ( Plot0 <> Nil ) then begin
		threat := NAttValue( Plot0^.NA , NAG_Narrative , NAS_DifficultyLevel );
	end else begin
		threat := 10;
	end;

	{ Next complete the context. }
	if Slot^.G = GG_Story then Context := Context + ' ' + StoryContext( GB , Slot );
	if IsAQuest then Context := Context + ' ' + QuoteString( SceneContext( Nil , Scope ) ) + ' ' + DifficulcyContext( Threat );
	if Plot0 <> Nil then begin
		SPContext := SAttValue( Plot0^.SA , 'SPContext' );
		if SPContext <> '' then Context := Context + ' ' + SPContext;
	end else begin
		SPContext := '';
	end;

	{ Determine whether this is a regular subplot or a branch plot that will start its own narrative thread. }
	IsBranchPlot := ( Length( Context ) > 2 ) and ( Context[2] = ':' );
	{ This will determine whether we inherit the PlotID from Plot0, or generate a new one. }
	if IsBranchPlot or ( Plot0 = Nil ) then PlotID := NewPlotID( FindRoot( Slot ) , IsAQuest )
	else PlotID := NAttValue( Plot0^.NA , NAG_Narrative , NAS_PlotID );

	{ Store the details for this subplot in Plot0. }
	if Plot0 <> Nil then begin
		SetNAtt( Plot0^.NA , NAG_SubPlotLayerID , SubPlotSlot , LayerID );
		SetNAtt( Plot0^.NA , NAG_SubPlotPlotID , SubPlotSlot , PlotID );

		{ Determine the parameters to be sent, and add context info for them. }
		{ We only need parameters if Plot0 = Nil, since root quests take no params. }
		ClearElementTable( ParamList );
		T := 1;
		while ( SPReq <> '' ) and ( T <= Num_Plot_Elements ) do begin
			E := ExtractValue( SPReq );
			if ( E >= 1 ) and ( E <= Num_Plot_Elements ) then begin
				{ This element is being shared with the subplot. }
				ParamList[t].EValue := ElementID( Plot0 , E );
				EDesc := SAttValue( Plot0^.SA , 'ELEMENT' + BStr( E ) );
				if EDesc <> '' then ParamList[t].EType := EDesc[1];
				AddElementContext( GB , Plot0 , Context , BStr( T )[1] , E );
				Inc( T );
			end;
		end;
	end else begin
		{ We have no parameters to send. Clear the param list. }
		ClearElementTable( ParamList );
	end;

	{ We have the context. Create the shopping list. }
	{ Positive component values are from the main subplot list. Negative }
	{ component values point to items from the quest_frags list. }
	ShoppingList := CreateSubPlotList( Context );

	if XXRan_Debug and ( Slot^.G = GG_Story ) then begin
		if NumNAtts( ShoppingList ) < 5 then begin
			DialogMsg( '[DEBUG] Only ' + BStr( NumNatts( ShoppingList ) ) + ' components for "' + Context + '".' );
		end;
	end;

	{ Based on this shopping list, search for applocable subplots and attempt to }
	{ fit them into the adventure. }
	NotFoundMatch := True;
	Shard := Nil;
	while ( ShoppingList <> Nil ) and NotFoundMatch do begin
		if XXRan_Wizard and ( ShoppingList <> Nil ) and ( Slot^.G = GG_Story ) and not IsAQuest then begin
{			DialogMsg( Context );}
			Shard := CloneGear( ComponentMenu( Sub_Plot_List , ShoppingList ) );
		end else if DoDebug and not IsAQuest then begin
			DialogMsg( Context );
			Shard := CloneGear( ComponentMenu( Sub_Plot_List , ShoppingList ) );
		end else begin
			Shard := CloneGear( SelectNextSubPlot( ShoppingList ) );
		end;
		if Shard <> Nil then begin
			{ Make sure this candidate doesn't violate our changes_used_so_far list. }
			changes_list := SAttValue( Shard^.SA , 'CHANGES' );
			if ( changes_list = '' ) or NoQItemsMatch( changes_used_so_far , changes_list ) then begin
				{ Insert the QPF gear, if appropriate. This is naively appended to the }
				{ invcoms, so the Element ID must be the last requested prefab. }
				if QPF_Proto <> Nil then begin
					QPF_Clone := CloneGear( QPF_Proto );
					InsertInvCom( Shard , QPF_Clone );
				end;

				{ See if we can add this one to the list. If not, it will be }
				{ deleted by InitShard. }
				if SPContext <> '' then SetSAtt( Shard^.SA , 'SPCONTEXT <' + SPContext + '>' );
				Shard := InitShard( GB , Scope , Slot , Shard , Quest_Frags , EsSoFar , PlotID , LayerID , Threat , ParamList , IsAQuest , DoDebug );
				if Shard <> Nil then NotFoundMatch := False;
			end else begin
				{ This shard wants to change something we've already changed elsewhere }
				{ in this plot. Better not include it; things could get weird. }
				DisposeGear( Shard );
			end;
		end;
	end;

	{ Get rid of the shopping list. }
	DisposeNAtt( ShoppingList );

	{ Return our selected subplot. }
	AddSubPlot := Shard;
end;

Procedure ReplaceStrings( Part: GearPtr; Dictionary: SAttPtr );
	{ We have a dictionary of substitute strings, and a part to do the replacements on. }
var
	S: SAttPtr;
begin
	S := Part^.SA;
	while S <> Nil do begin
		ApplyDictionaryToString( S^.Info , Dictionary );
		S := S^.Next;
	end;
end;

Procedure InitListStrings( LList: GearPtr; Dictionary: SAttPtr );
	{ Run LList, all of its siblings and children, through the ReplaceStrings }
	{ procedure. }
begin
	while LList <> Nil do begin
		ReplaceStrings( LList , Dictionary );
		InitListStrings( LList^.SubCom , Dictionary );
		InitListStrings( LList^.InvCom , Dictionary );
		LList := LList^.Next;
	end;
end;

Procedure MergeElementLists( MasterPlot , SubPlot: GearPtr );
	{ The element list of SUBPLOT should be merged into MASTERPLOT. }
	{ If a SUBPLOT element is found in MASTERPLOT already, no need }
	{ to merge. Store the master plot element indicies in SubPlot. }
	{ Also copy the PLACE strings here. }
var
	FirstFreeSlot,T,PlotIndex: Integer;
	EID: LongInt;
	EDesc: String;
	Dictionary: SAttPtr;
begin
	{ Locate the first free slot in MasterPlot. }
	FirstFreeSlot := 1;
	While ( FirstFreeSlot <= Num_Plot_Elements ) and ( ElementID( MasterPlot , FirstFreeSlot ) <> 0 ) do Inc( FirstFreeSlot );
	Dictionary := Nil;

	{ Go through the elements of SubPlot. Check to see if they are found in }
	{ MasterPlot. If so, do nothing. If not, add them. }
	for T := 1 to Num_Plot_Elements do begin
		EID := ElementID( SubPlot , T );
		if EID <> 0 then begin
			EDesc := SAttValue( SubPlot^.SA , 'ELEMENT' + BStr( T ) );
			PlotIndex := PlotElementID( MasterPlot , EDesc[1] , EID );
			if PlotIndex = 0 then begin
				{ This element apparently doesn't currently have a }
				{ place in this plot. Add it. }
				PlotIndex := FirstFreeSlot;
				Inc( FirstFreeSlot );
				SetNAtt( MasterPlot^.NA , NAG_ElementID , PlotIndex , EID );
				SetSAtt( MasterPlot^.SA , 'ELEMENT' + BStr( PlotIndex ) + ' <' + EDesc + '>' );
				SetSAtt( MasterPlot^.SA , 'TEAM' + BStr( PlotIndex ) + ' <' + SAttValue( SubPlot^.SA , 'TEAM' + BStr( T ) ) + '>' );
			end;

			{ We should now have a working PlotIndex. Save it in SubPlot, }
			{ and copy over the PLACE to MasterPlot. }
			SetNAtt( SubPlot^.NA , NAG_MasterPlotElementIndex , T , PlotIndex );
			SetSAtt( Dictionary , '%e' + BStr( T ) + '% <' + BStr( PlotIndex ) + '>' );
		end;
	end;

	InitListStrings( SubPlot , Dictionary );
	DisposeSAtt( Dictionary );

	{ After initializing the strings, do one more loop to copy over the PLACE info. }
	for T := 1 to Num_Plot_Elements do begin
		EID := ElementID( SubPlot , T );
		if EID <> 0 then begin
			PlotIndex := NAttValue( SubPlot^.NA , NAG_MasterPlotElementIndex , T );
			EDesc := SAttValue( SubPlot^.SA , 'PLACE' + BStr( T ) );
			if EDesc <> '' then SetSAtt( MasterPlot^.SA , 'PLACE' + BStr( PlotIndex ) + ' <' + EDesc + '>' );
		end;
	end;
end;

Procedure MergePersona( MainPlot , SubPlot , Persona: GearPtr; IsAQuest: Boolean );
	{ We have a persona that needs to be merged into the main plot. }
	{ If the main plot already has a persona for this character, merge }
	{ this new persona in as a megalist. If no persona currently exists, }
	{ delink this persona from MainPlot and stick in SubPlot. }
var
	MPIndex: Integer;
	MainPersona: GearPtr;
begin
	{ Determine the index of this element in the main plot. }
	MPIndex := NAttValue( SubPlot^.NA , NAG_MasterPlotElementIndex , Persona^.S );

	{ Attempt to locate the main persona. }
	MainPersona := SeekCurrentLevelGear( MainPlot^.SubCom , GG_Persona , MPIndex );
	if MainPersona = Nil then begin
		{ No main persona- create one. }
		if IsAQuest then begin
			MainPersona := LoadNewSTC( 'PERSONA_BLANK' );
		end else begin
			MainPersona := LoadNewSTC( 'PERSONA_REVERT' );
		end;
		InsertSubCom( MainPlot , MainPersona );
		SetSAtt( MainPersona^.SA , 'SPECIAL <' + SAttValue( Persona^.SA , 'SPECIAL' ) + '>' );
		{ Store the PlotID of this layer, since it's the first to provide a persona for this NPC. }
		SetNAtt( MainPersona^.NA , NAG_Narrative , NAS_PlotID , NAttValue( SubPlot^.NA , NAG_Narrative , NAS_PlotID ) );
		MainPersona^.S := MPIndex;
	end;

	{ Combine the two plots together. }
	BuildMegalist( MainPersona , Persona^.SA );
end;

Procedure MergeMetascene( MainPlot , SubPlot , MS: GearPtr );
	{ Combine the sub-metascene with the main metascene. }
	{ If no main metascene exists, simply move and relabel the }
	{ one provided here. }
var
	MPIndex: Integer;
	MainScene,Thing: GearPtr;
begin
	{ Determine the index of this element in the main plot. }
	MPIndex := NAttValue( SubPlot^.NA , NAG_MasterPlotElementIndex , MS^.S );

	{ Attempt to locate the main metascene. }
	MainScene := SeekCurrentLevelGear( MainPlot^.SubCom , GG_MetaScene , MPIndex );
	if MainScene = Nil then begin
		{ No main scene- delink, move, and relabel this one. }
		DelinkGear( SubPlot^.SubCom , MS );
		InsertSubCom( MainPlot , MS );

		{ Store the PlotID of this layer, since it's the first to provide details for this metascene. }
		SetNAtt( MS^.NA , NAG_Narrative , NAS_PlotID , NAttValue( SubPlot^.NA , NAG_Narrative , NAS_PlotID ) );

		MS^.S := MPIndex;
	end else begin
		{ Combine the two scenes together. }
		BuildMegalist( MainScene , MS^.SA );

		{ Copy over all InvComs and SubComs. }
		while ( MS^.InvCom <> Nil ) do begin
			Thing := MS^.InvCom;
			DelinkGear( MS^.InvCom , Thing );
			InsertInvCom( MainScene , Thing );
		end;
		while ( MS^.SubCom <> Nil ) do begin
			Thing := MS^.SubCom;
			DelinkGear( MS^.SubCom , Thing );
			InsertSubCom( MainScene , Thing );
		end;
	end;
end;

Procedure CombinePlots( MasterPlot, SubPlot: GearPtr; IsAQuest: Boolean );
	{ Combine SubPlot into MasterPlot, including all elements, scripts, }
	{ personas, metascenes, and so on. }
	{ - Merge element lists }
	{ - Copy PLACE strings from SUBPLOT to MASTERPLOT. }
	{   A place defined in a subplot take precedence over anything }
	{   defined earlier. }
	{ - Megalist scripts }
	{ - Megalist personas }
	{ - Combine MetaScenes }
	{ - Move InvComs }
	{ - Add victory points }
var
	Thing,T2: GearPtr;
begin
	MergeElementLists( MasterPlot , SubPlot );
	BuildMegalist( MasterPlot , SubPlot^.SA );

	{ Take a look at the things in this subplot. }
	{ Deal with them separately, as appropriate. }
	Thing := SubPlot^.SubCom;
	while Thing <> Nil do begin
		T2 := Thing^.Next;

		if Thing^.G = GG_Persona then begin
			MergePersona( MasterPlot , SubPlot , Thing , IsAQuest );
		end else if Thing^.G = GG_MetaScene then begin
			MergeMetascene( MasterPlot , SubPlot , Thing );
		end;

		Thing := T2;
	end;

	{ Move over the InvComs. }
	while SubPlot^.InvCom <> Nil do begin
		Thing := SubPlot^.InvCom;
		DelinkGear( SubPlot^.InvCom , Thing );
		InsertInvCom( MasterPlot , Thing );
	end;

	{ If the master plot doesn't have a PayRate set, the subplot gets to }
	{ set one. }
	if NAttValue( MasterPlot^.NA , NAG_ArenaMissionInfo , NAS_PayRate ) = 0 then SetNAtt(  MasterPlot^.NA , NAG_ArenaMissionInfo , NAS_PayRate , NAttValue(  SubPlot^.NA , NAG_ArenaMissionInfo , NAS_PayRate ) );
end;

Function IsStandardTrigger( const S_Head: String ): Boolean;
	{ Return TRUE if S_Head is one of the standard triggers, or FALSE if it }
	{ isn't. }
var
	ST: SAttPtr;
	MatchFound: Boolean;
begin
	{ Go through the list of standard triggers; stop when we find a match. }
	ST := standard_trigger_list;
	MatchFound := False;
	while ( ST <> Nil ) and not MatchFound do begin
		if HeadMatchesString( ST^.Info , S_Head ) then MatchFound := True;
		ST := ST^.Next;
	end;
	IsStandardTrigger := MatchFound;
end;

Function AssembleMegaPlot( Slot , SPList: GearPtr; var Quest_Frags: GearPtr; IsAQuest: Boolean ): GearPtr;
	{ SPList is a list of subplots. Assemble them into a single coherent megaplot. }
	{ The first item in the list is the base plot- all other plots get added to it. }
	{ - Delete all placeholder stubs from SLOT }
	{ - Process each fragment in turn. }
	{   - Delink from list }
	{   - Sequester the standard scripts }
	{   - Do string substitutions }
	{   - Combine plots }
	{   - If a non-reusable quest fragment, delete the prototype }
	{ - Insert the finished plot into slot as an invcom }
	Procedure PrepStandardScripts( SubPlot: GearPtr );
		{ A subplot's standard scripts (those attached to basic game triggers, as }
		{ listed in ASLRef.txt) will only be called when the subplot is active. }
	var
		sline: SAttPtr;	{ our counter for moving through the list. }
		s_Head,s_Script: String;
	begin
		sline := SubPlot^.SA;
		while sline <> Nil do begin
			S_Head := RetrieveAPreamble( sline^.Info ); 
			if IsStandardTrigger( S_Head ) then begin
				{ This is a standard script. It needs to be moved to a new location, }
				{ and this original line needs to be replace with a redirect. }
				{ First, get the script info. }
				S_Script := RetrieveAString( sline^.Info );

				{ Next, install the redirect. }
				sline^.info := S_Head + ' <if= PlotStatus %plotid% %id% else %pop% LTrigger .%id%_' + S_Head + ' Goto %pop%>';

				{ Finally, place the original script in its new home. }
				SetSAtt( SubPlot^.SA , '.%id%_' + S_Head + ' <' + S_Script + '>' );
			end;
			sline := sline^.next;
		end;
	end;
	Procedure InitMetasceneFactions( SubPlot: GearPtr );
		{ Certain metascenes may have a faction defined. Don't use that numeric faction; }
		{ instead, use the element being referred to. }
	var
		MScene: GearPtr;
		FID: Integer;
	begin
		MScene := SubPlot^.SubCom;
		while MScene <> Nil do begin
			if MScene^.G = GG_MetaScene then begin
				FID := NAttValue( MScene^.NA , NAG_Personal , NAS_FactionID );
				if FID <> 0 then begin
					SetNAtt( MScene^.NA , NAG_Personal , NAS_FactionID , ElementID( SubPlot , FID ) );
				end;
			end;

			MScene := MScene^.Next;
		end;
	end;
	Procedure DoStringSubstitutions( SubPlot: GearPtr; IsMasterPlot: Boolean );
		{ Do the string substitutions for this subplot. Basically, }
		{ create the dictionary and pass it on to the substituter. }
	var
		Dictionary: SAttPtr;
		T: Integer;
	begin
		{ Begin creating. }
		Dictionary := Nil;
		SetSAtt( Dictionary , '%plotid% <' + BStr( NAttValue( SubPlot^.NA , NAG_Narrative , NAS_PlotID ) ) + '>' );
		SetSAtt( Dictionary , '%id% <' + BStr( NAttValue( SubPlot^.NA , NAG_Narrative , NAS_PlotLayer ) ) + '>' );
		SetSAtt( Dictionary , '%threat% <' + BStr( NAttValue( SubPlot^.NA , NAG_Narrative , NAS_DifficultyLevel ) ) + '>' );
		for t := 1 to Num_Sub_Plots do begin
			SetSAtt( Dictionary , '%id' + BStr( T ) + '% <' + Bstr( NAttValue( SubPlot^.NA , NAG_SubPlotLayerID , T ) ) + '>' );
			SetSAtt( Dictionary , '%plotid' + BStr( T ) + '% <' + Bstr( NAttValue( SubPlot^.NA , NAG_SubPlotPlotID , T ) ) + '>' );
		end;
		for t := 1 to Num_Plot_Elements do begin
			{ If dealing with the main plot, do substitutions for the Element Indicies now. }
			if IsMasterPlot then SetSAtt( Dictionary , '%E' + BStr( T ) + '% <' + BStr( T ) + '>' );
			SetSAtt( Dictionary , '%' + BStr( T ) + '% <' + BStr( ElementID( SubPlot , T ) ) + '>' );
			SetSAtt( Dictionary , '%name' + BStr( T ) + '% <' + SAttValue( SubPlot^.SA , 'name_' + BStr( T ) ) + '>' );
		end;

		{ Run the provided subplot through the convertor. }
		InitListStrings( SubPlot , Dictionary );
		DisposeSAtt( Dictionary );
	end;
	Procedure InitMPSubs( MasterPlot: GearPtr );
		{ All personas and metascenes must be marked with the PlotID }
		{ of the subplot wot spawned 'em. }
	var
		LList: GearPtr;
	begin
		LList := MasterPlot^.SubCom;
		while LList <> Nil do begin
			if ( LList^.G = GG_Persona ) or ( LList^.G = GG_MetaScene ) then begin
				SetNAtt( LList^.NA , NAG_Narrative , NAS_PlotID , NAttValue( MasterPlot^.NA , NAG_Narrative , NAS_PlotID ) );
			end;
			LList := LList^.Next;
		end;
	end;
	Procedure DeleteQuestPrototype( Plot: GearPtr );
		{ It's possible that this subplot is based on a quest fragment. }
		{ If said fragment isn't reusable, remove it from the list. }
	var
		Frag: GearPtr;
	begin
		if ( Quest_Frags <> Nil ) and ( Plot^.S > 0 ) then begin
			Frag := SeekCurrentLevelGear( Quest_Frags , GG_Plot , Plot^.S );
			if ( Frag <> Nil ) and ( not QuestIsReusable( Frag ) ) then begin
				RemoveGear( Quest_Frags , Frag );
			end;
		end;
	end;
	Procedure ResetQuestPrototypes;
		{ Clear the INUSE frag from all remaining prototypes. }
	var
		Frag: GearPtr;
	begin
		Frag := Quest_Frags;
		while Frag <> Nil do begin
			SetNAtt( Frag^.NA , NAG_Narrative , NAS_QuestInUse , 0 );
			Frag := Frag^.Next;
		end;
	end;
var
	MasterPlot,SubPlot: GearPtr;
begin
	{ Delete the placeholders. }
	DeletePlotPlaceholders( Slot );

	{ Extract the master plot. It should be the first one in the list. }
	MasterPlot := SPList;
	DelinkGear( SPList , MasterPlot );
	DoStringSubstitutions( MasterPlot , True );
	InitMetasceneFactions( MasterPlot );
	InitMPSubs( MasterPlot );
	InsertInvCom( Slot , MasterPlot );
	DeleteQuestPrototype( MasterPlot );

	{ Store the PlotID being used. Do so for all subplot IDs as well. }
	SetNAtt( MasterPlot^.NA , NAG_PlotStatus , NAttValue( MasterPlot^.NA , NAG_Narrative , NAS_PlotID ) , 1 );

	{ Keep processing until we run out of subplots. }
	while SPList <> Nil do begin
		SubPlot := SPList;
		DelinkGear( SPList , SubPlot );
		AddSAtt( MasterPlot^.SA , 'SUBPLOT_NAME' , GearName( SubPlot ) );
		SetNAtt( MasterPlot^.NA , NAG_PlotStatus , NAttValue( SubPlot^.NA , NAG_Narrative , NAS_PlotID ) , 1 );

		{ Do the substitutions for standard triggers here. }
		PrepStandardScripts( SubPlot );

		InitMetasceneFactions( SubPlot );
		DeleteQuestPrototype( SubPlot );

		DoStringSubstitutions( SubPlot , False );
		CombinePlots( MasterPlot, SubPlot , IsAQuest );
		DisposeGear( SubPlot );
	end;

	{ After assembling the plot, clear any INUSE tags left over on the }
	{ quest frags. }
	ResetQuestPrototypes;

	{ Return the finished plot. }
	AssembleMegaPlot := MasterPlot;
end;

Procedure MoveElements( GB: GameBoardPtr; Adv,Plot: GearPtr; IsAQuest: Boolean );
	{ There are a bunch of elements in this plot. Some of them need to be moved. }
	{ Make it so. }
	{ GB may be nil, but Adv must be a component of the adventure. }
var
	T,PlaceIndex: Integer;
	PlaceCmd,EDesc,TeamName,DebugRec: String;
	Element,Dest,MF,Team,MS,Thing,DScene,Dest0: GearPtr;
	InSceneNotElement: Boolean;
	EID: LongInt;
begin
	{ Loop through all elements, looking for stuff to move. }
	for t := 1 to Num_Plot_ELements do begin
		PlaceCmd := SAttValue( Plot^.SA , 'PLACE' + BStr( T ) );
		if PlaceCmd <> '' then begin
			EDesc := SAttValue( Plot^.SA , 'ELEMENT' + BStr( T ) );
			DebugRec := PlaceCmd;
			if ( EDesc <> '' ) and ( UpCase( EDesc[1] ) = 'S' ) then begin
				{ I can't believe you just asked me to move a scene... }
				{ What you really must want is for me to move an encounter }
				{ attached to a metascene. Yeah, that must be it. }
				EID := ElementID( Plot , T );
				if EID < 0 then begin
					Element := FindSceneEntrance( FindRoot( Adv ) , GB , EID );
				end else begin
					Element := Nil;
				end;
			end else begin
				{ Just find the regular element. }
				Element := SeekPlotElement( FindRoot( Adv ) , Plot , T , GB );
			end;

			InSceneNotElement := ( PlaceCmd[1] = '~' );
			if InSceneNotElement then DeleteFirstChar( PlaceCmd );

			if PlaceCmd = '/' then begin
				Dest := SeekCurrentLevelGear( FindRoot( Adv )^.InvCom , GG_PlotThingSet , 0 );
				InSceneNotElement := False;
			end else begin
				PlaceIndex := ExtractValue( PlaceCmd );
				Dest := SeekPlotElement( FindRoot( Adv ) , Plot , PlaceIndex , GB );
			end;

			TeamName := RetrieveBracketString( PlaceCmd );

			if Element = Nil then begin
				DialogMsg( 'ERROR- Element ' + BStr( T ) + ' of ' + GearName( Plot ) + ' not found for movement.' );
				Exit;
			end;

			{ Next, delink the gear for movement... but there's a catch. }
			{ We don't want the delinker to give our element an OriginalHome }
			{ if it's a prefab element, because we want to do that ourselves }
			{ now in a bit. }
			{ Don't delink if we have a scene- in that case, we're just here to transfer }
			{ over the metascene stuff. }
			if Element^.G <> GG_Scene then begin
				if ( Element^.Parent <> Nil ) and ( Element^.Parent^.G = GG_Plot ) and IsInvCom( Element ) then begin
					DelinkGear( Element^.Parent^.InvCom , Element );
				end else begin
					DelinkGearForMovement( GB , Element );
				end;
			end;

			if InSceneNotElement and (( Dest = Nil ) or ( Dest^.G <> GG_Scene )) then begin
				{ If the destination is a metascene, locate its entrance. }
				if ( Dest = Nil ) or ( Dest^.G = GG_MetaScene ) then begin
					Dest := FindSceneEntrance( FindRoot( Adv ) , GB , ElementID( Plot , PlaceIndex ) );
				end;

				{ Try to find the associated scene now. }
				if ( Dest <> Nil ) and not IsAQuest then begin
					Dest := FindActualScene( GB , FindSceneID( Dest , GB ) );
				end;
			end;

			if ( Dest <> Nil ) then begin
				if ( Dest^.G <> GG_Scene ) and ( Dest^.G <> GG_MetaScene ) and IsLegalInvCom( Dest , Element ) then begin
					{ If E can be an InvCom of Dest, stick it there. }
					InsertInvCom( Dest , Element );
				end else begin
					{ If Dest isn't a scene, find the scene DEST is in itself }
					{ and stick E in there. }
					Dest0 := Dest;
					while ( Dest <> Nil ) and ( not IsAScene( Dest ) ) do Dest := Dest^.Parent;
					if Dest = Nil then begin
						DialogMsg( 'ERROR: ' + GearName( Dest0 ) + ' selected as place for ' + GearName( Element ) );
						Exit;
					end;

					if IsMasterGear( Element ) then begin
						if TeamName <> '' then begin
							Team := SeekChildByName( Dest , TeamName );
							if ( Team <> Nil ) and ( Team^.G = GG_Team ) then begin
								SetNAtt( Element^.NA , NAG_Location , NAS_Team , Team^.S );
							end else begin
								ChooseTeam( Element , Dest );
							end;
						end else begin
							ChooseTeam( Element , Dest );
						end;
					end;

					{ If a Metascene map feature has been defined as this element's home, }
					{ stick it there instead of in the scene proper. Such an element will }
					{ always be MiniMap component #1, so set that value here too. }
					if ( Dest^.G = GG_MetaScene ) then begin
						MF := SeekGearByDesig( Dest^.SubCom , 'HOME ' + BStr( T ) );
						if MF <> Nil then begin
							Dest := MF;
							SetNAtt( Element^.NA , NAG_ComponentDesc , NAS_ELementID , 1 );
						end;
					end;

					{ If this is a quest, then this element might have some supplemental }
					{ scene content. Better take a look. }
					if IsAQuest and IsAScene( Dest ) then begin
						MS := SeekCurrentLevelGear( Plot^.SubCom , GG_MetaScene , T );
						if MS <> Nil then begin
							{ Store the destination scene- we'll need it later. }
							DScene := Dest;

							{ This metascene may also contain a home for this element. }
							MF := SeekGearByDesig( MS^.SubCom , 'HOME' );
							if ( MF <> Nil ) and ( Element^.G <> GG_Scene ) then begin
								Dest := MF;
								SetNAtt( Element^.NA , NAG_ComponentDesc , NAS_ELementID , 1 );
							end;

							{ Copy over all InvComs and SubComs. }
							while ( MS^.InvCom <> Nil ) do begin
								Thing := MS^.InvCom;
								DelinkGear( MS^.InvCom , Thing );
								InsertInvCom( DScene , Thing );
							end;
							while ( MS^.SubCom <> Nil ) do begin
								Thing := MS^.SubCom;
								DelinkGear( MS^.SubCom , Thing );
								InsertSubCom( DScene , Thing );
							end;
						end;
					end;

					{ If this is a prefab element and we're deploying }
					{ to a metascene, assign an OriginalHome value of -1 }
					{ to make sure it doesn't get deleted when the plot }
					{ ends. }
					if NAttValue( Element^.NA , NAG_ParaLocation , NAS_OriginalHome ) = 0 then begin
						if Dest^.G = GG_MetaScene then SetNAtt( Element^.NA , NAG_ParaLocation , NAS_OriginalHome , -1 );
					end;

					if ( GB <> Nil ) and ( Dest = GB^.Scene ) then begin
						EquipThenDeploy( GB , Element , True );
					end else if Element^.G <> GG_Scene then begin
						InsertInvCom( Dest , Element );
					end;
				end;
			end else begin
				DialogMsg( 'ERROR: Destination not found for ' + GearName( Element ) + '/' + GearName( Plot )  + ' PI:' + BStr( PlaceIndex ) );
				DialogMsg( DebugRec );
				InsertInvCom( Plot , Element );
			end;
		end;
	end;
end;

Procedure DeployPlot( GB: GameBoardPtr; Slot,Plot: GearPtr; Threat: Integer );
	{ Actually add the plot to the adventure. Set it in place, move any elements as }
	{ requested. }
	{ - Insert persona fragments as needed }
	{ - Deploy elements as indicated by PLACE strings }
begin
	PrepAllPersonas( FindRoot( Slot ) , Plot , GB , NAttValue( Slot^.NA , NAG_Narrative , NAS_MaxPlotLayer ) + 1 );

	if Plot^.G <> GG_Scene then begin
		MoveElements( GB , FindRoot( Slot ) , Plot , False );
		PrepMetascenes( FindRoot( Slot ) , Plot , GB );
	end;
end;

Function ExpandDungeon( Dung: GearPtr ): GearPtr;
	{ Expand this dungeon. Return the "goal scene", which is the lowest level generated. }
	{ Add sub-levels, branches, and goal requests. }
	{ Note that this procedure will not assign SceneIDs nor will it connect the levels }
	{ with entrances. }
var
	name_base,type_base: String;
	branch_number: Integer;
	sub_scenes: GearPtr;
	LowestLevel: GearPtr;
	Function ExtractSubScenes: GearPtr;
		{ Remove any scenes that are subcoms of the dungeon, and }
		{ return them in a list. }
	var
		it,S,S2: GearPtr;
	begin
		it := Nil;
		S := Dung^.SubCom;
		while S <> Nil do begin
			S2 := S^.Next;
			if S^.G = GG_Scene then begin
				DelinkGear( Dung^.SubCom , S );
				AppendGear( it , S );
			end;
			S := S2;
		end;
		ExtractSubScenes := it;
	end;
	Procedure EliminateClonedScenes( DL: GearPtr );
		{ When cloning the prototype dungeon level, don't copy }
		{ the sub-scenes as well. }
	var
		S,S2: GearPtr;
	begin
		S := DL^.SubCom;
		while S <> Nil do begin
			S2 := S^.Next;
			if S^.G = GG_Scene then begin
				RemoveGear( DL^.SubCom , S );
			end;
			S := S2;
		end;
	end;
	Procedure AddNewDungeonLevel( S: GearPtr; Branch: Integer );
	var
		S2,T: GearPtr;
	begin
		S2 := CloneGear( S );
		{ Eliminate any sub-scenes of S2. }
		EliminateClonedScenes( S2 );
		InsertSubCom( S , S2 );
		{ We don't want to use the main dungeon entrance type for this entrance, }
		{ so copy the DEntrance string instead. }
		SetSAtt( S2^.SA , 'ENTRANCE <' + SAttValue( S^.SA , 'DENTRANCE' ) + '>' );

		{ Increase the dungeon level. }
		AddNAtt(  S2^.NA , NAG_Narrative , NAS_DungeonLevel , 1 );
		if NAttValue( S2^.NA , NAG_Narrative , NAS_DungeonLevel ) > NAttValue( LowestLevel^.NA , NAG_Narrative , NAS_DungeonLevel ) then LowestLevel := S2;
		SetNAtt( S2^.NA , NAG_Narrative , NAS_DungeonBranch , Branch );

		{ Increase the difficulcy level. }
		T := S2^.SubCom;
		while T <> Nil do begin
			if ( T^.G = GG_Team ) and ( T^.Stat[ STAT_WanderMon ] > 0 ) then begin
				T^.Stat[ STAT_WanderMon ] := T^.Stat[ STAT_WanderMon ] + 1 + Random( 3 ) + Random( 2 );

				{ Add the context description for the difficulcy level. }
				SetSAtt( S2^.SA , 'type <' + type_base + ' ' + DifficulcyContext( T^.Stat[ STAT_WanderMon ] ) );

			end;
			T := T^.Next;
		end;
	end;
	Procedure ExpandThisLevel( S: GearPtr );
		{ Search for dungeons among the adventure's scenes. If you find any, }
		{ maybe expand them by adding sub-dungeons. }
	const
		Branch_Suffix: Array [1..10] of char = ( 'a','b','c','d','e','f','g','h','i','j' );
		dungeon_goal_content_string = 'SOME 1 # SUB *DUNGEON_GOAL';
	var
		S2: GearPtr;
		Branch: Integer;
	begin
		Branch := NAttValue( S^.NA , NAG_Narrative , NAS_DungeonBranch );
		if ( S^.G = GG_Scene ) and AStringHasBString( SAttValue( S^.SA , 'TYPE' ) , 'DUNGEON' ) and ( SAttValue( S^.SA , 'DENTRANCE' ) <> '' ) then begin
			if NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) < ( RollStep( 3 ) + 1 ) then begin
				{ Maybe add a branch. }
				AddNewDungeonLevel( S , Branch );

				if ( Random( 5 ) = 1 ) and ( Branch_Number < 9 ) then begin
					AddNewDungeonLevel( S , Branch_Number + 1 );
					Inc( Branch_Number );
				end;
			end else begin
				{ If not adding a deeper level, add DungeonGoal content. }
				AddSAtt( S^.SA , 'CONTENT' , ReplaceHash( dungeon_goal_content_string , BSTr( NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) * 10 + 15 ) ) )
			end;

			{ Name the dungeon. }
			if Branch = 0 then begin
				SetSAtt( S^.SA , 'name <' + name_base + ', L' + BStr( NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) + 1 ) );
			end else begin
				SetSAtt( S^.SA , 'name <' + name_base + ', L' + BStr( NAttValue( S^.NA , NAG_Narrative , NAS_DungeonLevel ) + 1 )  + Branch_Suffix[ Branch ] );
			end;
		end;
		S2 := S^.SubCom;
		while S2 <> Nil do begin
			ExpandThisLevel( S2 );
			S2 := S2^.Next;
		end;
	end;
begin
	{ Record some information, initialize some variables. }
	name_base := GearName( Dung );
	if Full_RPGWorld_Info then DialogMsg( 'Expanding ' + name_base );
	SetSAtt( Dung^.SA , 'DUNGEONNAME <' + name_base + '>' );
	type_base := SAttValue( Dung^.SA , 'TYPE' );
	sub_scenes := ExtractSubScenes;
	LowestLevel := Dung;
	Branch_Number := 0;

	ExpandThisLevel( Dung );

	if Sub_Scenes <> Nil then InsertSubCom( lowestLevel , Sub_Scenes );

	ExpandDungeon := lowestlevel;
end;



Procedure ConnectScene( Scene: GearPtr; DoInitExits: Boolean );
	{ SCENE needs to be connected to its parent scene. This means that any }
	{ entrances in PARENT pointing to SCENE have to be given the correct }
	{ destination number, and any entrances in SCENE leading back to PARENT }
	{ also have to be given the correct destination number. }
	{ PRECON: Scene and its parent must have already been given scene IDs. }
	Function FindEntranceByName( EG: GearPtr; Name: String ): GearPtr;
		{ Find an entrance with the provided name. }
		{ This may be in one of the parent scene's subcoms, or one of its }
		{ map feature's subcoms or invcoms. }
	var
		it: GearPtr;
	begin
		it := Nil;
		Name := UpCase( Name );
		while ( EG <> Nil ) and ( it = Nil ) do begin
			if ( EG^.G = GG_MetaTerrain ) and ( UpCase( SAttValue( EG^.SA , 'NAME' ) ) = Name ) then it := EG
			else if ( EG^.G = GG_MapFeature ) then begin
				it := FindEntranceByName( EG^.SubCom , Name );
				if ( it = Nil ) then it := FindEntranceByName( EG^.InvCom , Name );
			end;
			EG := EG^.Next;
		end;
		FindEntranceByName := it;
	end;
	Procedure InitExits( S,E: GearPtr );
		{ Locate exits with a nonzero destination, then give them the proper }
		{ destination of the parent scene. }
	begin
		while E <> Nil do begin
			if E^.G = GG_MapFeature then begin
				InitExits( S , E^.SubCom );
				InitExits( S , E^.InvCom );
			end else if ( E^.G = GG_MetaTerrain ) and ( E^.Stat[ STAT_Destination ] <> 0 ) then begin
				if ( S^.Parent^.G = GG_Scene ) then begin
					E^.Stat[ STAT_Destination ] := S^.Parent^.S;
				end else if S^.Parent^.G = GG_MetaScene then begin
					{ We must be dealing with a quest scene. No problem- }
					{ I know exactly where its SceneID is. }
					E^.Stat[ STAT_Destination ] := ElementID( S^.Parent^.Parent , S^.Parent^.S );
				end;
			end;

			E := E^.Next;
		end;
	end;
var
	E,Loc: GearPtr;
	Entrance,EName: String;
begin
	{ Insert entrance to super-scene. }
	E := FindEntranceByName( Scene^.Parent^.SubCom , GearName( Scene ) );
	if E = Nil then begin
		Entrance := SAttValue( Scene^.SA , 'DUNGEONNAME' );
		if Entrance <> '' then begin
			E := FindEntranceByName( Scene^.Parent^.SubCom , Entrance );
		end;
	end;
	if ( E <> Nil ) and ( E^.G = GG_MetaTerrain ) then begin
		{ A named entrance was found. Initialize it. }
		E^.Stat[ STAT_Destination ] := Scene^.S;
	end else begin
		{ No entrance for this scene was specified. Better create one. }
		E := FindNextComponent( MasterEntranceList , SAttValue( Scene^.SA , 'ENTRANCE' ) );
		if E <> Nil then begin
			E := CloneGear( E );
			if ( E^.S = GS_MetaBuilding ) or ( E^.S = GS_MetaEncounter ) then begin
				EName := SAttValue( Scene^.SA , 'DUNGEONNAME' );
				if EName = '' then EName := GearName( Scene );
				SetSAtt( E^.SA , 'NAME <' + EName + '>' );
			end;
			E^.Stat[ STAT_Destination ] := Scene^.S;
			if Scene^.Parent^.G <> GG_World then E^.Scale := Scene^.Parent^.V;
			if NAttValue( Scene^.NA , NAG_LOcation , NAS_X ) <> 0 then begin
				SetNAtt( E^.NA , NAG_Location , NAS_X , NAttValue( Scene^.NA , NAG_LOcation , NAS_X ) );
				SetNAtt( E^.NA , NAG_Location , NAS_Y , NAttValue( Scene^.NA , NAG_LOcation , NAS_Y ) );
			end;

			{ Insert "E" as an InvCom of the parent scene. }
			{ If E isn't a building or the parent scene isn't a world, }
			{ also insert a subzone for E so it won't be stuck randomly somewhere. }
			if ( E^.S = GS_MetaBuilding ) or ( E^.S = GS_MetaEncounter ) or ( Scene^.Parent^.G = GG_World ) then begin
				InsertInvCom( Scene^.Parent , E );
			end else begin
				Loc := NewSubZone( Scene^.Parent );
				InsertSubCom( Loc , E );
			end;
		end;
	end;

	{ Initialize exits back to the upper level. }
	if DoInitExits then begin
		InitExits( Scene , Scene^.SubCom );
		InitExits( Scene , Scene^.InvCom );
	end;
end;

Procedure PrepQuestDungeon( Adv,SceneProto: GearPtr );
	{ Prepare this dungeon, please. To do this we'll need to expand the dungeon }
	{ by several levels, assign unique IDs to all our new scenes, and connect }
	{ them all to each other. }
	{ The SceneID which has already been assigned will be the SceneID of the }
	{ goal level. The ScenePrototype, which will serve as the entry level, }
	{ will be given a new SceneID. Make sure that you use this new SceneID }
	{ for assigning the entrance. }
	{ The procedure for expanding a quest dungeon is as follows: }
	{ 1 - Remove non-original subs and invs, saving them for the goal level. }
	{ 2 - Expand the dungeon. }
	{ 3 - Assign SceneIDs as needed and connect the scenes. }
	{     At the same time, record the ID of the entry level. }
	{ 4 - Reinstall the subs and invs from step 1 into the goal level. }
var
	GoalLevel,NOSubs,NOInvs: GearPtr;
	EntryLevelID: Integer;
	Procedure AssignSceneIDs( SList: GearPtr );
		{ Assign unique IDs to all the scenes in this list and all of }
		{ their children scenes. Also do the connections, as long as we're here. }
		{ On top of that, record the entry level ID. Got all that? Good. }
	begin
		while SList <> Nil do begin
			if ( SList^.G = GG_Scene ) then begin
				if SList <> GoalLevel then SList^.S := NewSceneID( Adv );

				{ Record the entry level ID. }
				SetNAtt( SList^.NA , NAG_Narrative , NAS_DungeonEntrance , EntryLevelID );

				ConnectScene( SList , True );
			end;
			if SList <> GoalLevel then AssignSceneIDs( SList^.SubCom );
			SList := SList^.next;
		end;
	end;
	Procedure InitPrototype;
		{ The prototype must be initialized. }
		{ Things to do: }
		{ - Set the L1 Difficulty rating }
		{ - Strip out the non-original SubComs and InvComs. }
		Function StripNonOriginals( var LList: GearPtr ): GearPtr;
			{ Remove anything from this list that doesn't have the WasQDOriginal tag. }
			{ Return the list of removed items. }
		var
			LL,LL2,OutList: GearPtr;
		begin
			LL := LList;
			OutList := Nil;
			while LL <> Nil do begin
				LL2 := LL^.Next;
				if NAttValue( LL^.NA , NAG_Narrative , NAS_QuestDungeonPlacement ) <> NAV_WasQDOriginal then begin
					DelinkGear( LList , LL );
					AppendGear( OutList , LL );
				end;
				LL := LL2;
			end;
			StripNonOriginals := OutList;
		end;
	var
		Team: GearPtr;
	begin
		{ Assign the Difficulty number. }
		Team := SceneProto^.SubCom;
		while Team <> Nil do begin
			if ( Team^.G = GG_Team ) and ( Team^.Stat[ STAT_WanderMon ] > 0 ) then begin
				Team^.Stat[ STAT_WanderMon ] := NAttValue( SceneProto^.NA , NAG_Narrative , NAS_DifficultyLevel ) - 10;
				if Team^.Stat[ STAT_WanderMon ] < 4 then Team^.Stat[ STAT_WanderMon ] := 2 + Random( 3 );
			end;
			Team := Team^.Next;
		end;

		{ Strip out the non-original subs and invs. }
		NOSubs := StripNonOriginals( SceneProto^.SubCom );
		NOInvs := StripNonOriginals( SceneProto^.InvCom );
	end;
	Procedure ReinstallSubsAndInvs;
		{ Reinstall the subs and invs, placing them in either the goal or the }
		{ entry levels. }
	var
		part: GearPtr;
	begin
		{ Begin with the subs. }
		while NoSubs <> Nil do begin
			part := NoSubs;
			DelinkGear( NoSubs , part );
			if NAttValue( Part^.NA , NAG_Narrative , NAS_QuestDungeonPlacement ) = NAV_ForEntryLevel then begin
				InsertSubCom( SceneProto , part );
			end else begin
				InsertSubCom( GoalLevel , part );
			end;
		end;

		{ Finish with the invs. }
		while NOInvs <> Nil do begin
			part := NoInvs;
			DelinkGear( NoInvs , part );
			if NAttValue( Part^.NA , NAG_Narrative , NAS_QuestDungeonPlacement ) = NAV_ForEntryLevel then begin
				InsertInvCom( SceneProto , part );
			end else begin
				InsertInvCom( GoalLevel , part );
			end;
		end;
	end;
begin
	{ **************** }
	{ *** STEP ONE *** }
	{ **************** }
	{ Start by initializing the dungeon prototype. }
	InitPrototype;

	{ **************** }
	{ *** STEP TWO *** }
	{ **************** }
	{ Next expand the dungeon. }
	GoalLevel := ExpandDungeon( SceneProto );

	{ ****************** }
	{ *** STEP THREE *** }
	{ ****************** }
	{ Next, pass out the UniqueIDs. }
	{ Also take this opportunity to connect everything. }
	SceneProto^.S := NewSceneID( Adv );
	EntryLevelID := SceneProto^.S;
	AssignSceneIDs( SceneProto^.SubCom );

	{ ***************** }
	{ *** STEP FOUR *** }
	{ ***************** }
	{ Re-insert the NOSubs and NOInvs into the finished dungeon. }
	ReinstallSubsAndInvs;
end;


Procedure InstallQuestScenes( Adv , City , Quest: GearPtr );
	{ QUEST probably contains a number of metascenes which we have to deal with. }
	{ If these are newly-defined scenes, they get placed in the adventure. Otherwise }
	{ they get combined with existing scenes. }
	{ 1 - Locate the destination for each scene. }
	{   - If a destination cannot be found, assign it to the city. }
	{   - Clear the PLACE attribute after reading it. }
	{ 2 - Move scene to its destination, and change type. }
	{   - Perform additional initialization. }
	{ 3 - Expand dungeons. }
	{   - If this isn't a dungeon, initialize any WMon teams that may exist. }
	{   - Element ID will be the SceneID of the goal level. }
	{ 4 - Locate and initialize entrances. }
	{   - Make sure dungeon entrances point to the entrance, not the goal level. }
	{   - If no entrance can be found, use default ConnectScene procedure. }
	{ 5 - Locate and initialize exits. }
	Procedure PrepWMonTeams( Scene: GearPtr );
		{ Check for monster teams. Set appropriate threat levels. }
	var
		Team: GearPtr;
	begin
		Team := Scene^.SubCom;
		while Team <> Nil do begin
			if ( Team^.G = GG_Team ) and ( Team^.Stat[ STAT_WanderMon ] > 0 ) then begin
				Team^.Stat[ STAT_WanderMon ] := NAttValue( Scene^.NA , NAG_Narrative , NAS_DifficultyLevel );
				if Team^.Stat[ STAT_WanderMon ] < 3 then Team^.Stat[ STAT_WanderMon ] := 3;
			end;
			Team := Team^.Next;
		end;
	end;
	Procedure InitializeEntrance( Scene: GearPtr; SIDtoSeek: Integer );
		{ Initialize the entrances for this scene. Note that because of dungeons, }
		{ the SceneID to seek might not be the same as the current SceneID of the }
		{ scene. Therefore, search for the provided SceneID, but set the SceneID }
		{ of the provided scene. }
	var
		Entrance: GearPtr;
		EDesig: String;
		FoundAnEntrance: Boolean;
	begin
		{ Haven't started... therefore, we haven't found an entrance yet. }
		FoundAnEntrance := False;

		{ Create the designation that we're looking for. }
		EDesig := 'ENTRANCE ' + BStr( SIDtoSeek );

		{ Now that we have this, start searching for entrances until we }
		{ run out of them. There may be more than one. }
		repeat
			ENtrance := SeekGearByDesig( Quest , EDesig );
			if ENtrance = Nil then begin
				Entrance := SeekGearByDesig( Adv , EDesig );
			end;

			if Entrance <> Nil then begin
				FoundAnEntrance := True;
				Entrance^.Stat[ STAT_Destination ] := Scene^.S;
				SetSAtt( Entrance^.SA , 'DESIG <FINAL' + BStr( Scene^.S ) + '>' );
			end;

		until Entrance = Nil;

		{ If we haven't found any entrances, or if we're requesting one, }
		{ call the automatic scene connector. }
		if ( SAttValue( Scene^.SA , 'ENTRANCE' ) <> '' ) or not FoundAnEntrance then begin
			{ Don't bother initializing the exits, because we're doing that ourselves below. }
			ConnectScene( Scene , False );
		end;
	end;
	Procedure InitExits( S,E: GearPtr );
		{ Locate exits with a nonzero destination, then give them the proper }
		{ destination of the parent scene. }
	begin
		while E <> Nil do begin
			if E^.G = GG_MapFeature then begin
				InitExits( S , E^.SubCom );
				InitExits( S , E^.InvCom );
			end else if ( E^.G = GG_MetaTerrain ) and ( E^.Stat[ STAT_Destination ] = -1 ) then begin
				if ( S^.Parent^.G = GG_Scene ) then begin
					E^.Stat[ STAT_Destination ] := S^.Parent^.S;
				end else if S^.Parent^.G = GG_MetaScene then begin
					{ We must be dealing with a quest scene. No problem- }
					{ I know exactly where its SceneID is. }
					E^.Stat[ STAT_Destination ] := ElementID( S^.Parent^.Parent , S^.Parent^.S );
				end;
			end;

			E := E^.Next;
		end;
	end;
var
	QS,QS2,Dest: GearPtr;
	EDesc,DDesc: String;
	N,EIn: Integer;
begin
	{ Loop through all the subcoms looking for potential quest scenes. }
	QS := Quest^.SubCom;
	while QS <> Nil do begin
		QS2 := QS^.Next;

		if QS^.G = GG_MetaScene then begin
			{ Find out whether this is a quest scene or not. If not, }
			{ then it's just a list of contents to stuff into one of the }
			{ pre-existing scenes. }
			EDesc := SAttValue( Quest^.SA , 'ELEMENT' + BStr( QS^.S ) );
			if ( EDesc <> '' ) and ( UpCase( EDesc[1] ) = 'Q' ) then begin
				{ **************** }
				{ *** STEP ONE *** }
				{ **************** }
				{ We've got a live one. Start by locating the destination. }
				DDesc := SAttValue( Quest^.SA , 'PLACE' + BStr( QS^.S ) );
				N := ExtractValue( DDesc );
				Dest := SeekPlotElement( Adv , Quest , N , Nil );
				if ( Dest = Nil ) or not IsAScene( Dest ) then Dest := City;
				{ Remove the PLACE string, so the element placer doesn't try to move it. }
				SetSAtt( Quest^.SA , 'PLACE' + BStr( QS^.S ) + ' <>' );

				{ **************** }
				{ *** STEP TWO *** }
				{ **************** }
				{ Move the new scene to its destination. Change it from a metascene }
				{ into an actual scene. Update its element description in the quest. }
				DelinkGear( Quest^.SubCom , QS );
				InsertSubCom( Dest , QS );
				{ Record the element index. }
				EIn := QS^.S;
				SetSAtt( Quest^.SA , 'ELEMENT' + BStr( EIn ) + ' <S>' );
				QS^.G := GG_Scene;
				QS^.S := ElementID( Quest , EIn );

				{ Also copy over the HABITAT, if this scene doesn't have one. }
				if SAttValue( QS^.SA , 'HABITAT' ) = '' then SetSAtt( QS^.SA , 'HABITAT <' + SAttValue( City^.SA , 'HABITAT' ) + '>' );

				{ ****************** }
				{ *** STEP THREE *** }
				{ ****************** }
				{ If this scene is a dungeon, expand it. The current SceneID will be }
				{ retained by the goal level; check QS^.S to find the ID of the entry. }
				if AStringHasBString( SAttValue( QS^.SA , 'TYPE' ) , 'DUNGEON' ) then PrepQuestDungeon( Adv, QS )
				else PrepWMonTeams( QS );

				{ ***************** }
				{ *** STEP FOUR *** }
				{ ***************** }
				{ Locate and initialize the scene's entrance. }
				{ Just in case this is a dungeon, don't forget to use QS^.S rather than }
				{ the ElementID. }
				InitializeEntrance( QS , ElementID( Quest , EIn ) );

				{ ***************** }
				{ *** STEP FIVE *** }
				{ ***************** }
				{ Locate and initialize the scene's exits. These should point to the }
				{ parent scene. }
				InitExits( QS , QS^.SubCom );
				InitExits( QS , QS^.InvCom );
			end;
		end;

		QS := QS2;
	end;
end;

Procedure DeployQuest( Adv , City , Quest: GearPtr );
	{ Deploy this quest. }
	Procedure ConvertPersonas;
		{ Change the quest personas from plot-style element-indexed ones to }
		{ regular style CID-indexed ones. }
	var
		P: GearPtr;
	begin
		P := Quest^.SubCom;
		while P <> Nil do begin
			if P^.G = GG_Persona then begin
				P^.S := ElementID( Quest , P^.S );
			end;
			P := P^.Next;
		end;
	end;
begin
	{ Remove the quest from the adventure, and stick it into the city. }
	DelinkGear( Adv^.InvCom , Quest );
	InsertSubCom( City , Quest );

	PrepAllPersonas( Adv , Quest , Nil , NAttValue( Adv^.NA , NAG_Narrative , NAS_MaxPlotLayer ) + 1 );
	ConvertPersonas;
	InstallQuestScenes( Adv , City , Quest );
	MoveElements( Nil , Adv , Quest , True );
end;

Function InitMegaPlot( GB: GameBoardPtr; Scope,Slot,Plot: GearPtr; Threat: Integer ): GearPtr;
	{ We've just been handed a prospective megaplot. }
	{ Create all subplots, and initialize everything. }
	{ 1 - Create list of components }
	{ 2 - Merge all components into single plot }
	{ 3 - Insert persona fragments }
	{ 4 - Deploy elements as indicated by PLACE strings }
var
	SPList,FakeFrags: GearPtr;
	PlotID,LayerID: LongInt;
	FakeParams: ElementTable;
begin
	{ The plot we've been handed will serve as the base component. The first thing }
	{ to do, then, is to initialize it via the InitShard procedure. This will also }
	{ give us a list of subplots. If InitShard fails, PLOT will be deleted. }
	{ First, we need to clear SLOT's current Plot Layer ID to start fresh, then }
	{ request a new later ID from Slot and a Plot ID from the adventure. }
	PlotID := NewPlotID( FindRoot( Slot ) , False );
	SetNAtt( Slot^.NA , NAG_Narrative , NAS_MaxPlotLayer , 0 );
	LayerID := NewLayerID( Slot );

	{ Initialize some of the variables we're going to need. }
	changes_used_so_far := '';
	FakeFrags := Nil;

	ClearElementTable( FakeParams );
	SPList := InitShard( GB , Scope , Slot , Plot , FakeFrags , 0 , PlotID , LayerID , Threat , FakeParams , False , ( GearName( Plot ) = 'DEBUG' ) );

	{ Now that we have the list, assemble it. }
	if SPList <> Nil then begin
		Plot := AssembleMegaPlot( Slot , SPList , FakeFrags , False );
		DeployPlot( GB , Slot , Plot , Threat );
	end;

	InitMegaPlot := SPList;
end;

Procedure InitPlaceStrings( P: GearPtr );
	{ Initialize all the place strings of the standard subplots. }
	{ To be comprehended, place strings need to point to the master plot }
	{ element slot, but for human readability it's better to point them }
	{ at the subplot element slot. This procedure converts any subplot }
	{ element slots to master plot slot references. }
var
	T: Integer;
	PlaceCmd,DestSlot: String;
	HasTilde: Boolean;
begin
	while P <> Nil do begin
		for t := 1 to Num_Plot_Elements do begin
			PlaceCmd := SAttValue( P^.SA , 'PLACE' + BStr( T ) );
			DeleteWhiteSpace( PlaceCmd );
			if ( PlaceCmd <> '' ) and ( PlaceCmd[1] <> '/' ) then begin
				if PlaceCmd[1] = '~' then begin
					HasTilde := True;
					DeleteFirstChar( PlaceCmd );
				end else HasTilde := False;

				if PlaceCmd[1] <> '%' then begin
					DestSlot := ExtractWord( PlaceCmd );
					PlaceCmd := '%e' + DestSlot + '% ' +PlaceCmd;
				end;
				if HasTilde then PlaceCmd := '~' + PlaceCmd;
				SetSAtt( P^.SA , 'PLACE' + BStr( T ) + ' <' + PlaceCmd + '>' );
			end;
		end;
		P := P^.Next;
	end;
end;

Function LoadQuestFragments: GearPtr;
	{ Load and initialize the quest fragments. }
	Procedure AssignMasterListIDNumbers( M: GearPtr );
		{ Each fragment in the master list needs a unique ID number, stored }
		{ in its "S" descriptor. }
	var
		ID: Integer;
	begin
		ID := 0;
		while M <> Nil do begin
			M^.S := ID;
			Inc( ID );
			M := M^.Next;
		end;
	end;
var
	Frags: GearPtr;
begin
	Frags := AggregatePattern( 'QUEST_*.txt' , Series_Directory );

	{ Initialize the quest fragments. }
	AssignMasterListIDNumbers( Frags );
	InitPlaceStrings( Frags );

	LoadQuestFragments := Frags;
end;

Function AddQuest( Adv,City,QPF_Proto: GearPtr; var Quest_Frags: GearPtr; QReq: String ): Boolean;
	{ Add a quest to the provided city. }
	{ QPF_Proto is a prototype for a prefab element to be added to a quest. }
	{ Quest_Frags is the list of quest fragments. Some of them may get deleted here. }
	{ QReq is the quest request taken from the ATLAS. }
var
	QList,Quest: GearPtr;
begin
	{ Initialize some of the global variables. }
	changes_used_so_far := '';

	{ Step One- Select a starting fragment. }
	QList := AddSubPlot( Nil, City, Adv, Nil, QPF_Proto , Quest_Frags, QReq, 0, NewLayerID( Adv ), 0, True, False );

	{ This will give us a list of quest fragments. Assemble them. }
	if QList <> Nil then begin
		Quest := AssembleMegaPlot( Adv , QList , Quest_Frags , True );
		DeployQuest( Adv , City , Quest );
		AddQuest := True;
	end else begin
		AddQuest := False;
	end;
end;


initialization
	{ Load the list of subplots from disk. }
	Sub_Plot_List := LoadRandomSceneContent( 'MEGA_*.txt' , series_directory );
	standard_trigger_list := LoadStringList( Data_Directory + 'standard_triggers.txt' );
	InitPlaceStrings( Sub_Plot_List );
	MasterEntranceList := AggregatePattern( 'ENTRANCE_*.txt' , Series_Directory );


finalization
	{ Dispose of the list of subplots. }
	DisposeGear( Sub_Plot_List );
	DisposeSAtt( standard_trigger_list );
	DisposeGear( MasterEntranceList );

end.
