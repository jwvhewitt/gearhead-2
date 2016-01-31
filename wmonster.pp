unit WMonster;
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

const
	{ This is the minimum point value for meks when calling the STOCKSCENE }
	{ procedure. }
	MinPointValue = 65000;


Procedure RestockRandomMonsters( GB: GameBoardPtr );
Procedure StockBoardWithMonsters( GB: GameBoardPtr; Renown,Strength,TeamID: Integer; MDesc: String );

Function MechaMatchesFaction( Mek: GearPtr; const Factions: String ): Boolean;
Function OptimalMechaValue( Renown: Integer ): LongInt;

Procedure AddTeamForces( GB: GameBoardPtr; TeamID,Renown,Strength: Integer );

Function SelectNPCMecha( GB: GameBoardPtr; Scene,NPC: GearPtr ): GearPtr;
Procedure SelectEquipmentForNPC( GB: GameBoardPtr; NPC: GearPtr; Renown: Integer );
Procedure EquipThenDeploy( GB: GameBoardPtr; NPC: GearPtr; PutOnMap: Boolean );

implementation

uses dos,ability,action,gearutil,ghchars,gearparser,texutil,narration,movement,
	customization,ghweapon,ghmodule,ghholder,ui4gh,
{$IFDEF ASCII}
	vidmap,vidgfx;
{$ELSE}
	sdlmap,sdlgfx;
{$ENDIF}

const
	UTYPE_General = 'GENERAL';
	UTYPE_Assault = 'ASSAULT';
	UTYPE_Defense = 'DEFENSE';
	ROLE_Trooper = 1;
	ROLE_Support = 2;
	ROLE_Command = 3;

Function MatchWeight( S, M: String ): Integer;
	{ Return a value showing how well the monster M matches the }
	{ quoted source S. }
var
	Trait: String;
	it: Integer;
begin
	it := 0;

	while M <> '' do begin
		Trait := ExtractWord( M );

		if AStringHasBString( S , Trait ) then begin
			if it = 0 then it := 1
			else it := it * 2;
		end;
	end;

	MatchWeight := it;
end;

Function MonsterStrength( Mon: GearPtr; Renown: Integer ): Integer;
	{ Return the Strength, or point cost, of this monster. The strength }
	{ isn't based objectively on the monster's level, but calculated }
	{ relatively from the provided threat value. }
const
	BaseStrengthValue = 15;
	MinStrengthValue = 1;
var
	it: Integer;
begin
	it := MonsterThreatLevel( Mon );
	if Renown < 1 then Renown := 1;
	if it > Renown then begin
		it := ( it * 3 - Renown * 2 ) * BaseStrengthValue div Renown;
	end else begin
		it := it * BaseStrengthValue div Renown;
	end;
	if it < MinStrengthValue then it := MinStrengthValue;
	MonsterStrength := it;
end;

Function GenerateMonster( Renown,Scale: Integer; const MType,Habitat: String; Scene: GearPtr ): GearPtr;
	{ Generate a monster with no greater than MaxTV threat value, }
	{ which corresponds to MDesc. Its type must match MType and its habitat must be compatable with Habitat. }
	{ Finally, the monsters's characteristics must be appropriate for the scene it will be placed in: }
	{ really, the big thing to check is that the generated monster will be able to breathe in this scene. }
	Function HabitatMatch( M: GearPtr ): Boolean;
		{ Return TRUE if M can appear in this habitat, or FALSE otherwise. }
	var
		MHabitat: String;
	begin
		if Habitat = '' then Exit( True );
		MHabitat := SAttValue( M^.SA , 'HABITAT' );
		HabitatMatch := ( MHabitat = '' ) or PartAtLeastOneMatch( Habitat , MHabitat );
	end;
	Function EnvironmentMatch( M: GearPtr ): Boolean;
		{ Return TRUE if this monster can survive in SCENE, or FALSE otherwise. }
	begin
		if Scene = Nil then begin
			EnvironmentMatch := True;
		end else if NAttValue( Scene^.NA , NAG_EnvironmentData , NAS_Atmosphere ) = NAV_Vacuum then begin
			EnvironmentMatch := IsEnviroSealed( M ) or ( NAttValue( M^.NA , NAG_GearOps , NAS_Material ) = NAV_Metal );
		end else begin
			EnvironmentMatch := True;
		end;
	end;
var
	MonRenown,MaxRenown: Integer;
	ShoppingList,ShoppingItem: NAttPtr;
	Total,Smallest,SmallTV: LongInt;
	WM: GearPtr;
	N,Match: Integer;
begin
	ShoppingList := Nil;
	WM := WMonList;
	N := 1;
	Total := 0;
	Smallest := 0;
	SmallTV := 100000;
	if Renown < 1 then Renown := 1;
	MaxRenown := ( Renown * 3 ) div 2;
	if MaxRenown < ( Renown + 20 ) then MaxRenown := Renown + 20;
	while WM <> Nil do begin
		{ If this monster matches our criteria, maybe add its number to the list. }
		if ( WM^.Scale <= Scale ) and HabitatMatch( WM ) and EnvironmentMatch( WM ) then begin
			MonRenown := MonsterThreatLevel( WM );
			Match := MatchWeight( MType , SAttValue( WM^.SA , 'TYPE' ) );
			if ( Match > 0 ) then begin
				if ( ( MonRenown > ( Renown + 10 ) ) or ( MonRenown < ( Renown - 20 ) ) ) then begin
					Match := Match div 4;
				end;
				if Match < 1 then Match := 1;
			end;

			{ If this monster's threat value is within the acceptable range, add it to the list. }
			{ Otherwise see if it's the smallest TV found so far, in which case store its identity }
			{ just in case no monsters with acceptable TV are found. }
			if MonRenown <= MaxRenown then begin
				SetNAtt( ShoppingList , 0 , N , Match );
				Total := Total + Match;
			end else if MonsterThreatLevel( WM ) < SmallTV then begin
				Smallest := N;
				SmallTV := MonsterThreatLevel( WM );
			end;
		end;

		{ Move to the next monster, and increase the monster index. }
		WM := WM^.Next;
		Inc( N );
	end;


	if Total > 0 then begin
		Match := Random( Total );
		ShoppingItem := ShoppingList;
		while Match > ShoppingItem^.V do begin
			Match := Match - ShoppingItem^.V;
			ShoppingItem := ShoppingItem^.Next;
		end;
		N := ShoppingItem^.S;

		{ Return the selected monster. }
		WM := CloneGear( RetrieveGearSib( WMonList , N ) );
	end else if Smallest > 0 then begin
		WM := CloneGear( RetrieveGearSib( WMonList , Smallest ) );
	end else begin
		{ Return a random monster. }
		WM := CloneGear( SelectRandomGear( WMonList ) );
	end;

	DisposeNAtt( ShoppingList );
	SetSATt( WM^.SA , 'JOB <ANIMAL>' );
	GenerateMonster := WM;
end;

Procedure AddRandomMonsters( GB: GameBoardPtr; const WMonType: String; TeamID , Renown,Strength,Gen: Integer );
	{ Place some wandering monsters on the map. }
var
	WM: GearPtr;
	Habitat: String;
begin
	{ Find the WMonType and the Habitat. }
	if GB^.Scene <> Nil then begin
		Habitat := SAttValue( GB^.Scene^.SA , 'HABITAT' );
	end else Habitat := '';

	while ( Gen > 0 ) and ( Strength > 0 ) do begin
		WM := GenerateMonster( Renown , GB^.Scale , WMonType , Habitat , GB^.Scene );
		SetNAtt( WM^.NA , NAG_Location , NAS_Team , TeamID );
		DeployGear( GB , WM , True );

		{ Reduce the generation counter and the threat points. }
		Strength := Strength - MonsterStrength( WM , Renown );
		Dec( Gen );
	end;
end;

Procedure StockBoardWithMonsters( GB: GameBoardPtr; Renown,Strength,TeamID: Integer; MDesc: String );
	{ Place some monsters in this scene. }
begin
	AddRandomMonsters( GB , MDesc , TeamID , Renown , Strength , 9999 );
end;

Function TeamTV( MList: GearPtr; Team,Threat: Integer ): LongInt;
	{ Calculate the total monster strength value of active models belonging }
	{ to TEAM which are present on the map. }
	{ Generally, only characters have monster threat values. }
var
	it: LongInt;
begin
	it := 0;

	while MList <> Nil do begin
		if GearActive( MList ) and ( NAttValue( MList^.NA , NAG_Location , NAS_TEam ) = Team ) then begin
			it := it + MonsterStrength( MList , Threat );
		end;
		MList := MList^.Next;
	end;

	TeamTV := it;
end;

Procedure RestockRandomMonsters( GB: GameBoardPtr );
	{ Replenish this level's supply of random monsters. }
var
	Team: GearPtr;
	TPV: LongInt;
	DungeonStrength: Integer;
begin
	{ Error check - make sure the scene is defined. }
	if ( GB = Nil ) or ( GB^.Scene = Nil ) then Exit;

	DungeonStrength := GB^.map_width * GB^.map_height div 10;

	{ Search through the scene gear for teams which need random }
	{ monsters. If they don't have enough PV, add some monsters. }
	Team := GB^.Scene^.SubCom;
 	while Team <> Nil do begin
		{ if this gear is a team, and it has a wandering monster }
		{ allocation set, add some monsters. }
		if ( Team^.G = GG_Team ) and ( Team^.STat[ STAT_WanderMon ] > 0 ) then begin
			{ Calculate total point value of this team's units. }
			TPV := TeamTV( GB^.Meks , Team^.S , Team^.Stat[ STAT_WanderMon ] );

			if TPV < DungeonStrength then begin
				AddRandomMonsters( GB , SAttValue( Team^.SA , 'TYPE' ) , Team^.S , Team^.Stat[ STAT_WanderMon ] , DungeonStrength - TPV , Random( 3 ) );
			end;
		end;

		{ Move to the next gear. }
		Team := Team^.Next;
	end;
end;

Function MechaMatchesFaction( Mek: GearPtr; const Factions: String ): Boolean;
	{ Return TRUE if this mecha matches one of the listed factions. }
begin
	MechaMatchesFaction := PartAtLeastOneMatch( SAttValue( Mek^.SA , 'FACTIONS' ) , Factions );
end;

Function MechaMatchesFactionAndTerrain( Mek: GearPtr; const Factions,Terrain_Type: String ): Boolean;
	{ Return TRUE if MEK is a legal design for the faction and map, }
	{ or FALSE otherwise. }
begin
	MechaMatchesFactionAndTerrain := ( Mek^.G = GG_Mecha ) and MechaMatchesFaction( Mek , Factions ) and PartMatchesCriteria( SAttValue( Mek^.SA , 'TYPE' ) , Terrain_Type );
end;


Function GenerateMechaList( MPV: LongInt; Fac: GearPtr; Factions,Desc,Unit_Type: String ): NAttPtr;
	{ Build a list of mechas from the DESIGN diectory which have }
	{ a maximum point value of MPV or less. }
	{ FAC is the controlling faction. }
	{ FACTIONS is the list of faction designations from which mecha may be chosen. }
	{ DESC is the terrain description taken from the scene. }
	{ UNIT_TYPE is the kind of unit being built. }
	{  }
	{ The shopping list will be a list of numeric attributes in this format: }
	{   G = List position of mecha. }
	{   S = Role of mecha, given the UNIT_TYPE. }
	{   V = Value of mecha. }
	Function MechaRole( Mek: GearPtr ): Integer;
		{ Return the role of this mecha, given the faction and unit type. }
	var
		roles: String;
		P: Integer;
	begin
		{ Error check- if no faction, no role. }
		if Fac = Nil then Exit( 0 );

		{ Obtain the proper ROLE string from the mecha. }
		roles := UpCase( SAttValue( Mek^.SA , 'ROLE_' + SAttValue( Fac^.SA , 'DESIG' ) ) );

		{ Next, locate the clause pertaining to this unit type. }
		P := Pos( Unit_Type , roles );
		if ( P <> 0 ) and ( Length( roles ) >= ( P + Length( Unit_Type ) + 2 ) ) then begin
			Case roles[ P + Length( Unit_Type ) + 1 ] of
				'T':	P := ROLE_Trooper;
				'S':	P := ROLE_Support;
				'C':	P := ROLE_Command;
			else P := 0;
			end;
		end;
		MechaRole := P;
	end;
var
	it: NAttPtr;
	Mek: GearPtr;
	N,MinValFound,LVN: LongInt;	{ The lowest value found so far. }
	LVMek: GearPtr;		{ Pointer to the lowest value mek. }
begin
	it := Nil;
	MinValFound := 0;
	LVMek := Nil;
	LVN := 0;

	if unit_type = '' then unit_type := UTYPE_General;

	{ All the meks are contained in the STANDARD_EQUIPMENT_LIST. }
	Mek := Standard_Equipment_List;
	N := 1;
	while Mek <> Nil do begin
		if ( Mek^.G = GG_Mecha ) then begin
			if ( GearValue( Mek ) <= MPV ) and MechaMatchesFactionAndTerrain( Mek , Factions , DESC ) then begin
				SetNAtt( it , N , MechaRole( Mek ) , GearValue( Mek ) );
			end;
			if ( ( GearValue( Mek ) < MinValFound ) or ( MinValFound = 0 ) ) and MechaMatchesFactionAndTerrain( Mek , Factions , DESC ) then begin
				LVMek := Mek;
				LVN := N;
				MinValFound := GearValue( Mek );
			end;
		end;

		Inc( N );
		Mek := Mek^.Next;
	end;

	{ Error check- we don't want to return an empty list, }
	{ but we will if we have to. }
	if ( it = Nil ) and ( LVMek <> Nil ) then begin
		SetNAtt( it , LVN , MechaRole( LVMek ) , GearValue( LVMek ) );
	end;

	GenerateMechaList := it;
end;

Function OptimalMechaValue( Renown: Integer ): LongInt;
	{ Return the optimal mecha value for a grunt NPC fighting a character }
	{ with the provided renown. }
const
	MinOMV = 50000;
var
	it: LongInt;
begin
	it := Calculate_Threat_Points( Renown , 20 );
	if it < MinOMV then it := MinOMV;
	OptimalMechaValue := it;
end;

Function PurchaseForces( ShoppingList: NAttPtr; Renown,Strength: Integer; Fac: GearPtr ): GearPtr;
	{ Pick a number of random meks. Add pilots to these meks. }
	{ The expected PC skill level is measured by RENOWN. The difficulty of the }
	{ encounter is measured by STRENGTH, which is a percentage with 100 representing }
	{ an average fight. }
	{ SHOPPINGLIST is a list of possible mecha from GenerateMechaList above. }
	{ FAC is the faction these mecha belong to. }
	{ Within this procedure it is assumed that 7 points of renown translate to one }
	{ point of skill. That isn't necessarily true at the high and low ends of the spectrum, }
	{ but it's a good heuristic. }
const
	BasicGruntCost = 30;
	SkillPlusCost = 15;
	SkillMinusCost = 7;
	SkillStep = 7;		{ The amount of Renown needed to change the skill rank. }
	BasicEnemyRenownModifier = -20;
var
	OptimalValue: LongInt;	{ The ideal value for a mecha. }
	MList: GearPtr;		{ The list of mecha we will eventually return. }

	Function ObtainMek( N: Integer ): GearPtr;
		{ Clone mek N from the standard equipment list. }
	begin
		{ Clone the mecha we want. }
		ObtainMek := CloneGear( RetrieveGearSib( Standard_Equipment_List , N ) );
	end;

	Function SelectNextMecha: Integer;
		{ Select a mecha file to load. Try to make it appropriate }
		{ to the point value of the encounter. }
	var
		M1,M2: NAttPtr;
		T: Integer;
		V,V2: LongInt;
	begin
		{ Select a mecha at random, and find out its point value. }
		M1 := SelectRandomNAtt( ShoppingList );
		V := M1^.V;

		{ If the PV of this mecha seems a bit low, }
		{ look for a more expensive model and maybe pick that }
		{ one instead. }
		if Strength >= BasicGruntCost then begin
			t := 3;
			while ( t > 0 ) and ( V < ( OptimalValue div 2 ) ) do begin
				M2 := SelectRandomNAtt( ShoppingList );
				V2 := M2^.V;
				if V2 > V then begin
					M1 := M2;
					V := V2;
				end;

				Dec( T );
			end;
		end else begin
			{ If STRENGTH is running out, select a small mecha instead. }
			t := 2;
			while ( t > 0 ) do begin
				M2 := SelectRandomNAtt( ShoppingList );
				V2 := M2^.V;
				if V2 < V then begin
					M1 := M2;
					V := V2;
				end;

				Dec( T );
			end;
		end;

		{ Return the info string selected. }
		SelectNextMecha := M1^.G;
	end;
	Function SelectMechaByRole( Role,MaxCost: LongInt ): Integer;
		{ Select a mecha based on the given role and maximum }
		{ cost. If no legal mecha is found, return 0. }
	type
		smbr_ChoiceRec = Record
			N: Integer;
			Cost: LongInt;
		end;
	const
		Num_Possible_Choices = 3;
	var
		Possible_Choices: Array [1..Num_Possible_Choices] of smbr_ChoiceRec;
		T,N: Integer;
		Mek: NAttPtr;
	begin
		{ Initialization. }
		for t := 1 to Num_Possible_Choices do Possible_Choices[ t ].N := 0;

		{ Step One: Create a list of up to 3 possibilities. }
		Mek := ShoppingList;
		N := 0;
		while Mek <> Nil do begin
			if ( Mek^.S = Role ) and ( Mek^.V <= MaxCost ) then begin
				{ This mecha has the right role and a legal cost. }
				{ Let's see if it's more expensive than what we currently }
				{ have in the array. }
				T := 1;
				while ( T <= Num_Possible_Choices ) and ( Possible_Choices[ t ].Cost > Mek^.V ) do begin
					Inc( T );
				end;
				if T <= Num_Possible_Choices then begin
					Possible_Choices[ t ].N := Mek^.G;
					Possible_Choices[ t ].Cost := Mek^.V;
					if N < Num_Possible_Choices then Inc( N );
				end;
			end;
			Mek := Mek^.Next;
		end;

		{ Step Two: If there are any choices, pick one at random. }
		if N > 0 then begin
			N := Possible_Choices[ Random( N ) + 1 ].N;
		end;

		SelectMechaByRole := N;
	end;
	Function MechaStrengthCost( MPV: LongInt ): LongInt;
		{ Return the strength cost of this mecha, based on its value. }
	var
		it: LongInt;
	begin
		it := ( MPV * BasicGruntCost ) div OptimalValue;
		if it < 5 then it := 5;
		MechaStrengthCost := it;
	end;

	Procedure AddMechaToTeam( Mek: GearPtr; Lvl: Integer );
		{ Add this mecha to the team, along with a pilot of the }
		{ requested level. }
	var
		CP,Pilot: GearPtr;
	begin
{DialogMsg( 'Adding ' + FullGearName( Mek ) + ' at R' + BStr( Lvl ) + ': ' + BStr( Strength ) );}
		{ Add this mecha to our list. }
		AppendGear( MList , Mek );

		{ Create a pilot, add it to the mecha. }
		CP := SeekGear( Mek , GG_CockPit , 0 );
		if CP <> Nil then begin
			Pilot := RandomPilot( 72  , 10 );
			SetSkillsAtLevel( Pilot , Lvl );
			InsertSubCom( CP , Pilot );
		end;
	end;

	Procedure AddAUnit;
		{ We are going to try to add an organized unit to this team. }
		{ A unit consists of 2 to 6 identical troopers, 0 to 2 support, }
		{ and 0 to 1 commander. }
		{ STRENGTH should be at least 80 when calling this procedure. }
	var
		MekID,N,T,MaxNumberOfMeks,PilotLvl: Integer;
		StrCost: LongInt;	{ The number of strength points this mecha will cost. }
		Mek: GearPtr;
		PilotBoost: Boolean;
	begin
		{ Step One: Decide on a good trooper mecha. }
		MekID := SelectMechaByRole( ROLE_Trooper , OptimalValue * 3 div 2 );
		PilotBoost := False;

		if MekID > 0 then begin
			StrCost := MechaStrengthCost( NAttValue( ShoppingList , MekID , ROLE_Trooper ) ) - SkillMinusCost;
			PilotLvl := Renown + BasicEnemyRenownModifier - SkillStep;
			if StrCost < 11 + Random( 10 ) then begin
				PilotLvl := PilotLvl + SkillStep;
				StrCost := StrCost + SkillMinusCost;
				PilotBoost := True;
			end;

			MaxNumberOfMeks := Strength div StrCost;
			if MaxNumberOfMeks > 8 then MaxNumberOfMeks := 8;

			N := Random( 5 ) + Random( 5 ) + 2;

			if N > MaxNumberOfMeks then N := MaxNumberOfMeks
			else if N < ( MaxNumberOfMeks div 2 ) then N := MaxNumberOfMeks div 2;

			for t := 1 to N do begin
				Mek := ObtainMek( MekID );
{DialogMsg( 'TROOPER: ' + FullGearName( Mek ) );}
				AddMechaToTeam( Mek , PilotLvl );
				Strength := Strength - StrCost;
			end;

			{ Next, see about adding some support. }
			if ( N > 1 ) and ( Strength > 40 ) and ( Random( 5 ) <> 1 ) then begin

				MekID := SelectMechaByRole( ROLE_Support , OptimalValue * 3 div 2 );

				if MekID > 0 then begin
					StrCost := MechaStrengthCost( NAttValue( ShoppingList , MekID , ROLE_Support ) ) - SkillMinusCost;
					PilotLvl := Renown + BasicEnemyRenownModifier - SkillStep;
					{ If the troopers got a bonus, and we can afford a bonus here, dole one out. }
					if PilotBoost and ( ( StrCost + SkillMinusCost ) <= Strength ) then begin
						PilotLvl := PilotLvl + SkillStep;
						StrCost := StrCost + SkillMinusCost;
					end;
					MaxNumberOfMeks := Strength div StrCost;
					{ At this point in time, N should still equal the number of }
					{ troopers generated. No more than half the unit may be support. }
					if MaxNumberOfMeks > ( N div 2 ) then MaxNumberOfMeks := N div 2;

					N := Random( MaxNumberOfMeks + 2 );
					if N > MaxNumberOfMeks then N := MaxNumberOfMeks;

					if N > 0 then begin
						for t := 1 to N do begin
							Mek := ObtainMek( MekID );
{DialogMsg( 'SUPPORT: ' + FullGearName( Mek ) );}
							AddMechaToTeam( Mek , PilotLvl );
							Strength := Strength - StrCost;
						end;
					end;
				end;
			end;

			{ Finally, see about adding a commander. }
			if ( Strength > ( 30 + Random( 20 ) ) ) and ( Random( 3 ) <> 1 ) then begin
				MekID := SelectMechaByRole( ROLE_Command , OptimalValue * 2 );
				if MekID > 0 then begin
					StrCost := MechaStrengthCost( NAttValue( ShoppingList , MekID , ROLE_Command ) );
					Mek := ObtainMek( MekID );
{DialogMsg( 'COMMAND: ' + FullGearName( Mek ) );}
					{ The commander gets a skill bonus. }
					AddMechaToTeam( Mek , Renown + BasicEnemyRenownModifier + Random( 10 ) );
					Strength := Strength - StrCost - SkillPlusCost;
				end;
			end;
		end;
	end;
	Procedure AssortedMechaExtravaganza;
		{ We're done with that high-falootin' organized unit business. }
		{ Spend the rest of our points on a random grab-bag of mecha. }
	var
		MPV: LongInt;
		StrCost: LongInt;	{ The number of strength points this mecha will cost. }

		Lvl,Bonus: LongInt;		{ Pilot level. }
		CTheme,CPoints: Integer;	{ Customization theme and points. }
		Mek: GearPtr;
	begin
		{ Keep processing until we run out of points. }
		{ The points are represented by STRENGTH. }
		while ( Strength > 0 ) and ( ShoppingList <> Nil ) do begin
			{ Select a mek at random. }
			{ Load & Clone the mek. }
			Mek := ObtainMek( SelectNextMecha );

			{ Determine its cash value. }
			MPV := GearValue( Mek );

			{ From this, we may determine its base STRENGTH value. }
			StrCost := MechaStrengthCost( MPV );

			{ If we have a lot of STRENGTH, and are at a sufficiently high RENOWN, consider }
			{ making this mecha a custom model. }
			if ( Strength > ( 150 + Random( 300 ) - Renown ) ) and ( StrCost < Random( 40 ) ) and ( Renown > ( 60 + Random( 50 ) ) ) then begin
				{ Encountering a custom mecha in the RPG campaign is like finding }
				{ a shiny pokemon, except actually useful. }
				if Fac <> Nil then CTheme := NAttValue( Fac^.NA , NAG_Narrative , NAS_DefaultFacTheme )
				else CTheme := 0;

				CPoints := 2 + Random( 2 );
				if StrCost < 25 then CPoints := CPoints + Random( 4 );

				StrCost := StrCost + CPoints * 3;
				MechaMakeover( Mek , Random( 3 ) + 1 , CTheme , CPoints );
			end;

			{ Select a pilot skill level. }
			{ Base pilot level is 20 beneath the PC's renown. }
			Lvl := Renown + BasicEnemyRenownModifier;

			{ This level may be adjusted up or down depending on the mecha's cost. }
			if StrCost > Strength then begin
				{ We've gone overbudget. Whack this mecha's pilot. }
				Lvl := Lvl - ( StrCost - Strength );
				StrCost := Strength;

			end else if ( ( StrCost * 3 ) < Strength ) and ( Strength > 90 ) and ( Random( 3 ) <> 1 ) then begin
				{ We have plenty of points to spare. Give this pilot some lovin'. }
				Bonus := Random( 3 ) + 1;
				Lvl := Lvl + Bonus * SkillStep;
				StrCost := StrCost + Bonus * SkillPlusCost;

			end else if ( StrCost > ( BasicGruntCost + 1 + Random( 20 ) ) ) and ( Strength < ( 76 + Random( 175 ) ) ) then begin
				{ Slightly overbudget... can reduce the cost with skill reduction. }
				{ Note that we won't be reducing skills at all if STRENGTH is }
				{ sufficiently high. }
				Bonus := Random( 4 );
				Lvl := Lvl - Bonus * SkillStep;
				StrCost := StrCost - Bonus * SkillMinusCost;

			end else if StrCost < ( BasicGruntCost - 1 - Random( 15 ) ) then begin
				{ Underbudget... we can afford a better pilot. }
				Bonus := Random( 3 );
				if Random( 10 ) = 4 then Inc( Bonus );
				Lvl := Lvl + Bonus * SkillStep;
				StrCost := StrCost + Bonus * SkillPlusCost;
			end;

			{ If Strength is extremely high, maybe give an extra skill point }
			{ in order to increase the cost. This extra skill point costs more than }
			{ the above, since it can potentially raise the pilot to named-NPC-like }
			{ status. }
			if ( Strength > ( 201 + Random( 300 ) ) ) and ( Strength > ( StrCost * 3 ) ) then begin
				Lvl := Lvl + SkillStep;
				StrCost := StrCost + SkillPlusCost * 2;
			end;

			AddMechaToTeam( Mek , Lvl );

			{ Reduce UPV by an appropriate amount. }
			Strength := Strength - StrCost;
		end;
	end;
begin
	{ Initialize our list to Nil. }
	MList := Nil;

	{ Record the optimal mecha value. }
	OptimalValue := OptimalMechaValue( Renown );

	if Strength > 80 then AddAUnit;
	if Strength > 0 then AssortedMechaExtravaganza;

	PurchaseForces := MList;
end;

Procedure AddTeamForces( GB: GameBoardPtr; TeamID,Renown,Strength: Integer );
	{ Add forces to the gameboard. }
	{ RENOWN is the expected renown of the player's team. }
	{ STRENGTH is the difficulty level of this fight expressed as a percent. }
var
	SList: NAttPtr;
	MList,Mek,Pilot: GearPtr;
	desc,fdesc,unit_type: String;
	team,fac,LFac,rscene: GearPtr;
	MaxMekShare,MPV: LongInt;
begin
	{ First, generate the mecha description. }
	{ GENERAL mecha are always welcome. }
	fdesc := 'GENERAL';
	team := LocateTeam( GB , TeamID );
	if team <> Nil then begin
		Fac := SeekFaction( GB^.Scene , NAttValue( Team^.NA , NAG_Personal , NAS_FactionID ) );
		if Fac <> Nil then fdesc := fdesc + ' ' + SAttValue( Fac^.SA , 'DESIG' );

		{ The unit_type is also stored in the team. }
		unit_type := SAttValue( team^.SA , 'TYPE' );
	end else begin
		unit_type := '';
	end;

	{ Also add the terrain description from the scene. }
	desc := '';
	if GB^.Scene <> Nil then begin
		desc := desc + ' ' + SAttValue( GB^.Scene^.SA , 'TERRAIN' );

		{ Also locate the faction of the root scene; this will give the "generic" }
		{ mecha for this particular region. }
		if Fac = Nil then begin
			rscene := FindRootScene( GB^.Scene );
			if rscene <> Nil then begin
				LFac := SeekFaction( GB^.Scene , NAttValue( RScene^.NA , NAG_Personal , NAS_FactionID ) );
				if LFac <> Nil then fdesc := fdesc + ' ' + SAttValue( LFac^.SA , 'DESIG' );
			end;
		end;
	end;

	{ Generate the list of mecha. }
	if Strength < 202 then MaxMekShare := 200
	else MaxMekShare := ( Strength div 2 ) + 100;
	MPV := ( OptimalMechaValue( Renown ) * MaxMekShare ) div 100;
	if MPV < 300000 then MPV := 300000;
	SList := GenerateMechaList( MPV , fac , fdesc , desc , unit_type );

	{ Generate the mecha list. }
	MList := PurchaseForces( SList , Renown , Strength , Fac );

	{ Get rid of the shopping list. }
	DisposeNAtt( SList );

	{ Deploy the mecha on the map. }
	while MList <> Nil do begin
		{ Delink the first gear from the list. }
		Mek := MList;
		Pilot := LocatePilot( Mek );
		DelinkGear( MList , Mek );

		{ Set its team to the requested value. }
		SetNAtt( Mek^.NA , NAG_Location , NAS_Team , TeamID );
		if Pilot <> Nil then SetNAtt( Pilot^.NA , NAG_Location , NAS_Team , TeamID );

		{ Designate both mecha and pilot as temporary. }
		SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Temporary , 1 );
		if Pilot <> Nil then begin
			SetNAtt( Pilot^.NA , NAG_EpisodeData , NAS_Temporary , 1 );
		end;

		{ Mark the mecha as salvage- if the PC recovers it, it won't have }
		{ a very high resale price. }
		MarkGearsWithNAtt( Mek , NAG_GearOps , NAS_CostAdjust , -90 );
		MarkGearsWithSAtt( Mek , 'SALETAG <' + MSgString( 'SALETAG_Salvage' ) + '>' );

		{ Place it on the map. }
		DeployGear( GB , Mek , True );
	end;
end;



Function SelectNPCMecha( GB: GameBoardPtr; Scene,NPC: GearPtr ): GearPtr;
	{ Select a mecha for the provided NPC. }
	{ This mecha must match the NPC's faction, renown, and must also be legal for }
	{ this game board. }
	Function SelectMechaByValue( LList: GearPtr ): GearPtr;
		{ We now have a list of mecha. Select one of them from the list, with }
		{ emphasis given to the most expensive one there. }
	var
		m,mek: GearPtr;
		Total: Int64;
	begin
		m := LList;
		mek := Nil;
		Total := 0;
		while M <> nil do begin
			Total := Total + GearValue( M );
			m := m^.next;
		end;
		Total := Random( Total );
		m := LList;
		while ( Total >= 0 ) and ( m <> Nil ) do begin
			Total := Total - GearValue( M );
			if Total < 0 then Mek := M;
			M := M^.Next;
		end;
		SelectMechaByValue := mek;
	end;
const
	Min_Max_Cost = 400000;
	Max_Min_Cost = 1000000;
var
	MechaList: GearPtr;
	Factions,Terrain_Type: String;
	Renown: LongInt;
	SRec: SearchRec;
	M,M2,Fac,DList,RScene: GearPtr;
	Cost,Minimum_Cost, Maximum_Cost: LongInt;
begin
	MechaList := Nil;

	Renown := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned );

	{ Determine the factions to be used by the NPC. }
	Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
	Factions := 'GENERAL';
	if Fac <> Nil then Factions := Factions + ' ' + SAttValue( Fac^.SA , 'DESIG' )
	else begin
		rscene := FindRootScene( Scene );
		if rscene <> Nil then begin
			Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( RScene^.NA , NAG_Personal , NAS_FactionID ) );
			if Fac <> Nil then factions := factions + ' ' + SAttValue( Fac^.SA , 'DESIG' );
		end;
	end;

	{ Determine the terrain type to be used. }
	if ( Scene <> Nil ) then Terrain_Type := SAttValue( Scene^.SA , 'TERRAIN' )
	else Terrain_Type := 'GROUND';

	{ Determine the maximum and minimum mecha costs. }
	Maximum_Cost := OptimalMechaValue( Renown ) * 4;
	if Maximum_Cost < Min_Max_Cost then Maximum_Cost := Min_Max_Cost;
	Minimum_Cost := Maximum_Cost div 3;
	if Minimum_Cost > Max_Min_Cost then Minimum_Cost := Max_Min_Cost;

	{ Start the search process going... }
	FindFirst( Design_Directory + Default_Search_Pattern , AnyFile , SRec );

	{ As long as there are files which match our description, }
	{ process them. }
	While DosError = 0 do begin
		{ Load this mecha design file from disk. }
		DList := LoadFile( SRec.Name , Design_Directory );

		{ Look through this list for mecha to use. }
		M := DList;
		while M <> Nil do begin
			M2 := M^.Next;
			if MechaMatchesFactionAndTerrain( M , Factions , Terrain_Type ) then begin
				Cost := GearValue( M );
				if ( Cost >= Minimum_Cost ) and ( Cost <= Maximum_Cost ) then begin
					{ This is a legal mecha, usable in this terrain, and }
					{ within our price range. Add it to the list. }
					DelinkGear( DList , M );
					AppendGear( MechaList , M );
				end;
			end;
			M := M2;
		end;

		{ Dispose of the design list. }
		DisposeGear( DList );

		{ Look for the next file in the directory. }
		FindNext( SRec );
	end;

	{ By now, we should have a mecha list full of candidates. If not, we better load }
	{ something generic and junky. }
	if MechaList <> Nil then begin
		M := SelectMechaByValue( MechaList );
		DelinkGear( MechaList , M );
		DisposeGear( MechaList );
	end else begin
		DialogMsg( GearName( NPC ) + ' is forced to take a crappy mecha...' + Terrain_Type + ' ' + Factions + BStr( Minimum_Cost ) + ' - ' + Bstr( Maximum_Cost ) );
		M := LoadSingleMecha( 'buruburu.txt' , Design_Directory );
	end;

	if XXRan_Debug then DialogMsg( 'Mecha for ' + GearName( NPC ) + ' [' + Bstr( Renown ) + '] ($' + BStr( Minimum_Cost ) + '-$' + BStr( Maximum_Cost ) + '): ' + GearName( M ) + ' ($' + Bstr( GearValue( M ) ) + ')' );

	SelectNPCMecha := M;
end;

Procedure SelectEquipmentForNPC( GB: GameBoardPtr; NPC: GearPtr; Renown: Integer );
	{ This procedure will select some decent equipment for the given NPC from the standard }
	{ equipment list. Faction will be taken into account. }
	{ Many of these procedures will rely upon a special kind of shopping list }
	{ composed of numeric attributes. }
	{ SHOPPING LIST }
	{ G = Item index in Standard_Equipment_List }
	{ S = Undefined }
	{ V = Item "goodness"- basically cost plus a bonus for appropriateness }
var
	Faction_Desc: String;
	Spending_Limit,Legality_Limit: LongInt;

	Function ItemLegalForFaction( I: GearPtr ): Boolean;
		{ Return TRUE if this item can be used by the NPC's faction, or FALSE }
		{ otherwise. }
		{ This function uses the FACTION_DESC string, so better initialize it }
		{ before calling this one. }
	begin
		ItemLegalForFaction := PartAtLeastOneMatch( SAttValue( I^.SA , 'FACTIONS' ) , Faction_Desc ) and ( NAttValue( I^.NA , NAG_GearOps , NAS_Legality ) <= Legality_Limit );
	end;
	Procedure AddToShoppingList( var ShoppingList: NAttPtr; Item: GearPtr; N: Integer );
		{ Calculate this item's desirability and add it to the list. }
	var
		Desi: LongInt;	{ Short for desirability. }
	begin
		Desi := GearValue( Item );
		{ If this item is limited to certain factions, it gets extra desirability. }
		if not AStringHasBString( SAttValue( Item^.SA , 'FACTIONS' ) , 'GENERAL' ) then Desi := ( Desi * 5 ) div 4;
		SetNAtt( ShoppingList , N , 0 , Desi );
	end;
	Procedure EquipItem( Slot , Item: GearPtr );
		{ This is the real equipping procedure. Stuff ITEM into SLOT. }
		{ As noted in TheRules.txt, any nonmaster gear can only have one }
		{ item of any particular "G" type equipped at a time. So, if }
		{ SLOT already has equipment of type ITEM^.G, unequip that and }
		{ stuff it into PC's general inventory. }
	var
		I2,I3: GearPtr;
	begin
		{ First, check for already equipped items. }
		I2 := Slot^.InvCom;
		while I2 <> Nil do begin
			I3 := I2^.Next;		{ This next step might delink I2, so... }
			if ( I2^.G = Item^.G ) or ( Slot^.G = GG_Holder ) then begin
				if NAttValue( I2^.NA , NAG_Narrative , NAS_IsRandomEquipment ) <> 0 then begin
					RemoveGear( Slot^.InvCom , I2 );
				end else begin
					DelinkGear( Slot^.InvCom , I2 );
					InsertInvCom( NPC , I2 );
				end;
			end;
			I2 := I3;
		end;

		{ Mark ITEM as being generated randomly. }
		SetNAtt( Item^.NA , NAG_Narrative , NAS_IsRandomEquipment , 1 );

		{ We can now link ITEM into SLOT. }
		InsertInvCom( Slot , Item );
	end;
	Function SelectItemForNPC( ShoppingList: NAttPtr ): GearPtr;
		{ Considering this shopping list, select an item for the NPC }
		{ based on the listed desirabilities. Then, locate the item }
		{ referred to in the master item list, clone it, and return the }
		{ copy. Hooray! }
	var
		SLI: NAttPtr;
		Total: Int64;
		N: Integer;
		Item: GearPtr;
	begin
		{ Quick way out- if this list is empty, no sense in doing any real }
		{ work, is there? }
		if ShoppingList = Nil then Exit( Nil );

		{ To start, go through the list and count up how many }
		{ points we'll be dealing with. }
		{ Quadratic weighting didn't work so well- back to linear. }
		Total := 0;
		SLI := ShoppingList;
		while SLI <> Nil do begin
			Total := Total + SLI^.V;
{			Total := Total + ( SLI^.V * SLI^.V );}
			SLI := SLI^.Next;
		end;

		{ Next, go through one more time and pick one randomly. }
		Total := Random( Total );
		SLI := ShoppingList;
		N := 0;
		while ( N = 0 ) and ( SLI <> Nil ) do begin
			Total := Total - SLI^.V;
{			Total := Total - ( SLI^.V * SLI^.V );}
			if Total < 0 then N := SLI^.G;
			SLI := SLI^.Next;
		end;

		{ Ah, finally. We should now have a usable number. }
		Item := RetrieveGearSib( Standard_Equipment_List , N );
		SelectItemForNPC := CloneGear( Item );
	end;
	Function GenerateShoppingList( Slot: GearPtr; GG: Integer; MaxValue: LongInt ): NAttPtr;
		{ Generate a shopping list of items with Gear General value GG which }
		{ can be equipped as InvComs of Slot. }
		Function ModifiedGearValue( Item: GearPtr ): LongInt;
			{ This just basically calls GearValue, but applies an extra markup to melee weapons. }
			{ I do this to keep the high end melee weapons out of the hands of low end thugs. }
			{ Melee weapons are naturally cheaper than ranged weapons, so to keep the low to high }
			{ spread we'll have to fudge things a little. }
		begin
			if ( Item^.G = GG_Weapon ) and ( ( Item^.S = GS_Melee ) or ( Item^.S = GS_EMelee ) ) then begin
				ModifiedGearValue := GearValue( Item ) * 3;
			end else begin
				ModifiedGearValue := GearValue( Item );
			end;
		end;
	var
		ShoppingList: NAttPtr;
		Item: GearPtr;
		N: Integer;
	begin
		ShoppingList := Nil;
		Item := Standard_Equipment_List;
		N := 1;
		while Item <> Nil do begin
			if ( Item^.G = GG ) and ItemLegalForFaction( Item ) and isLegalInvCom( Slot , Item ) and ( ModifiedGearValue( Item ) < MaxValue ) then begin
				AddToShoppingList( ShoppingList , Item , N );
			end;
			Inc( N );
			Item := Item^.Next;
		end;
		GenerateShoppingList := ShoppingList;
	end;
	Procedure GenerateItemForSlot( Slot: GearPtr; GG: Integer; MaxValue: LongInt );
		{ Generate an item for this slot of the requested GG type and equip it. }
	var
		ShoppingList: NAttPtr;
		Item: GearPtr;
	begin
		ShoppingList := GenerateShoppingList( Slot , GG , MaxValue );
		Item := SelectItemForNPC( ShoppingList );
		DisposeNAtt( ShoppingList );
		if Item <> Nil then EquipItem( Slot , Item )
		else DialogMsg( 'Couldn''t generate item for ' + GearName( Slot ) + '/' + GearName( NPC ) + ', $' + BStr( MaxValue ) );
	end;
	Procedure BuyArmorForNPC();
		{ Armor will be purchased in sets if possible. }
		Function IsArmorSet( S: GearPtr ): Boolean;
			{ Is this gear an armor set? }
			{ This procedure seems a bit like overkill, but it should cover all }
			{ possibilities. }
		var
			A: GearPtr;
			SampleLeg,SampleArm,SampleBody: GearPtr;
			NeededLegs,NeededArms,NeededBodies: Integer;
		begin
			if S^.G <> GG_Set then Exit( False );

			{ Locate the sample arm, leg, and body that we're going to need. }
			SampleLeg := SeekCurrentLevelGear( NPC^.SubCom , GG_Module , GS_Leg );
			if SampleLeg <> Nil then NeededLegs := 2
			else NeededLegs := 0;

			SampleArm := SeekCurrentLevelGear( NPC^.SubCom , GG_Module , GS_Arm );
			if SampleArm <> Nil then NeededArms := 2
			else NeededArms := 0;

			SampleBody := SeekCurrentLevelGear( NPC^.SubCom , GG_Module , GS_Body );
			if SampleBody <> Nil then NeededBodies := 1
			else NeededBodies := 0;

			{ Check through the armor to make sure it has a body, two arms, and two legs }
			{ in SF: 0. The helmet is optional. }
			A := S^.InvCom;
			while A <> Nil do begin
				if ( A^.G = GG_ExArmor ) and ( A^.Scale = 0 ) then begin
					if ( A^.S = GS_Arm ) and IsLegalInvCom( SampleArm , A ) then Dec( NeededArms )
					else if ( A^.S = GS_Leg ) and IsLegalInvCom( SampleLeg , A ) then Dec( NeededLegs )
					else if ( A^.S = GS_Body ) and IsLegalInvCom( SampleBody , A ) then Dec( NeededBodies );
				end;
				A := A^.Next;
			end;

			IsArmorSet := (NeededLegs < 1 ) and ( NeededArms < 1 ) and ( NeededBodies < 1 );
		end;
		Function SetInPriceRange( S: GearPtr ): Boolean;
			{ Check this armor set to make sure that nothing within it }
			{ is more expensive than our spending limit. }
		var
			A: GearPtr;
			AllOK: Boolean;
		begin
			{ Assume TRUE unless found FALSE. }
			AllOK := TRUE;
			A := S^.InvCom;
			while A <> Nil do begin
				if GearValue( A ) > Spending_Limit then AllOK := False;
				A := A^.Next;
			end;
			SetInPriceRange := AllOK;
		end;
		Procedure GetArmorForLimb( Limb: GearPtr );
			{ We're getting armor for this particular limb. }
		begin
			GenerateItemForSlot( Limb , GG_ExArmor , Spending_Limit );
		end;
		Procedure WearArmorSet( ASet: GearPtr );
			{ An armor set has been chosen. Wear it by going through }
			{ the NPC's modules and applying armor to each one by one. }
		var
			Limb,Armor: GearPtr;
		begin
			Limb := NPC^.SubCom;
			while Limb <> Nil do begin
				if Limb^.G = GG_Module then begin
					{ Try to locate armor for this part. }
					Armor := SeekCurrentLevelGear( ASet^.InvCom , GG_ExArmor , Limb^.S );
					if Armor <> Nil then begin
						if IsLegalInvCom( Limb , Armor ) then begin
							DelinkGear( ASet^.InvCom , Armor );
							EquipItem( Limb , Armor );
						end else begin
							RemoveGear( ASet^.InvCom , Armor );
							GetArmorForLimb( Limb );
						end;
					end else if Random( 60 ) <= Renown then begin
						GetArmorForLimb( Limb );
					end;
				end;

				Limb := Limb^.Next;
			end;
		end;
		Procedure ApplyPiecemealArmor();
			{ No armor set was found. Instead, go through each limb and }
			{ locate an independant piece of armor for each. }
		var
			Limb: GearPtr;
		begin
			Limb := NPC^.SubCom;
			while Limb <> Nil do begin
				if Limb^.G = GG_Module then begin
					{ Try to locate armor for this part. }
					if Random( 40 ) <= Renown then GetArmorForLimb( Limb );
				end;

				Limb := Limb^.Next;
			end;
		end;
	var
		A: GearPtr;
		ShoppingList: NAttPtr;
		N: Integer;
	begin
		{ Start by looking for an armor set. }
		{ Create the shopping list. }
		ShoppingList := Nil;
		A := Standard_Equipment_List;
		N := 1;
		while A <> Nil do begin
			if IsArmorSet( A ) and SetInPriceRange( A ) and ItemLegalForFaction( A ) then begin
				AddToShoppingList( ShoppingList , A , N );
			end;
			Inc( N );
			A := A^.Next;
		end;

		{ Select a set from the shopping list. }
		A := SelectItemForNPC( ShoppingList );
		DisposeNAtt( ShoppingList );

		{ If we got something, use it. }
		if A <> Nil then begin
			WearArmorSet( A );
			{ Get rid of the leftover set bits. }
			DisposeGear( A );
		end else begin
			{ No armor set was found. Instead, apply piecemeal armor to }
			{ this character. }
			ApplyPiecemealArmor();
		end;
	end;
	Procedure BuyWeaponsForNPC();
		{ In order to buy weapons we're going to have to search for appropriate parts. }
		{ Look for some arms- the first arm found gets a primary weapon. Each additional }
		{ arm has a random chance of getting either a secondary weapon or a shield. I }
		{ know that people usually only come with two arms, but as with all things it's best }
		{ to keep this procedure as versatile as possible. }
		Function WSNeeded( Wep: GearPtr ): Integer;
			{ Return the skill needed by this weapon. }
			{ Note that WEP absolutely must be a weapon. No passing me other kinds of crap!!! }
		begin
			if ( Wep^.S = GS_Melee ) or ( Wep^.S = GS_EMelee ) then WSNeeded := 8
			else if ( Wep^.S = GS_Missile ) or ( Wep^.S = GS_Grenade ) or ( Wep^.V > 10 ) then WSNeeded := 7
			else WSNeeded := 6;
		end;
		Function GenerateWeaponList( Slot: GearPtr; WS: Integer; MaxValue: LongInt ): NAttPtr;
			{ Generate a shopping list of weapons using the provided skill which }
			{ can be equipped as InvComs of Slot. }
		var
			ShoppingList: NAttPtr;
			Item,Best_Offer: GearPtr;
			N,Best_N: Integer;
			WCost,Best_Value: LongInt;
		begin
			ShoppingList := Nil;
			Item := Standard_Equipment_List;
			N := 1;
			Best_Offer := Nil;
			Best_Value := 0;
			while Item <> Nil do begin
				if ( Item^.G = GG_Weapon ) and ItemLegalForFaction( Item ) and isLegalInvCom( Slot , Item ) and ( WSNeeded( Item ) = WS ) then begin
					WCost := GearValue( Item );
					if ( WCost < MaxValue ) then begin
						AddToShoppingList( ShoppingList , Item , N );
					end else begin
						if ( Best_Offer = Nil ) or ( WCost < Best_Value ) then begin
							Best_Offer := Item;
							Best_N := N;
							Best_Value := WCost;
						end;
					end;
				end;
				Inc( N );
				Item := Item^.Next;
			end;
			{ If, after all that, the list is empty... good thing we went looking for a spare, innit? }
			if ( ShoppingList = Nil ) and ( Best_Offer <> Nil ) then AddToShoppingList( ShoppingList , Best_Offer , Best_N );
			GenerateWeaponList := ShoppingList;
		end;
		Procedure GenerateWeaponForSlot( Slot: GearPtr; WS: Integer; MaxValue: LongInt );
			{ Generate an weapon for this slot of the requested WS type and equip it. }
		var
			ShoppingList: NAttPtr;
			Item: GearPtr;
		begin
			ShoppingList := GenerateWeaponList( Slot , WS , MaxValue );
			Item := SelectItemForNPC( ShoppingList );
			DisposeNAtt( ShoppingList );
			EquipItem( Slot , Item );
		end;

	var
		Limb,Hand: GearPtr;
		NeedPW,NeedRanged: Boolean;	{ Need Primary Weapon }
		AC_Skill,HW_Skill,SA_Skill: Integer;
	begin
		Limb := NPC^.SubCom;
		NeedPW := True;
		NeedRanged := True;
		AC_Skill := SkillValue( NPC , NAS_CloseCombat , STAT_Reflexes );
		HW_Skill := SkillValue( NPC , NAS_RangedCombat , STAT_Perception );
		SA_Skill := SkillValue( NPC , NAS_RangedCombat , STAT_Reflexes );
		while Limb <> Nil do begin
			if ( Limb^.G = GG_Module ) and ( Limb^.S = GS_Arm ) then begin
				Hand := SeekCurrentLevelGear( Limb^.SubCom , GG_Holder , GS_Hand );
				if ( Hand <> Nil ) then begin
					if NeedPW then begin
						if ( SA_Skill >= HW_Skill ) and ( SA_Skill >= AC_Skill ) then begin
							{ Small Arms skill dominates. Better get a small arms weapon. }
							GenerateWeaponForSlot( Hand , 6 , Spending_Limit * 2 );
							NeedRanged := False;
						end else if ( AC_Skill >= HW_Skill ) then begin
							{ Armed Combat dominates. Better get a melee weapon. }
							GenerateWeaponForSlot( Hand , 8 , Spending_Limit * 2 );
						end else begin
							{ Might as well get a heavy weapon. }
							GenerateWeaponForSlot( Hand , 7 , Spending_Limit * 2 );
							NeedRanged := False;
						end;
						NeedPW := False;
					end else if Random( 100 ) < Renown then begin
						{ Add either a shield or a second weapon. }
						if Random( 20 ) = 1 then begin
							GenerateItemForSlot( Limb , GG_Shield , Spending_Limit );
						end else if NeedRanged then begin
							if SA_Skill >= HW_Skill then GenerateWeaponForSlot( Hand , 6 , Spending_Limit )
							else GenerateWeaponForSlot( Hand , 7 , Spending_Limit );
							NeedRanged := False;
						end else begin
							GenerateItemForSlot( Hand , GG_Weapon , Spending_Limit );
						end;
					end;
				end;
			end;
			Limb := Limb^.Next;
		end;
	end;
const
	Min_Spending_Limit = 2500;
var
	Fac,Scene: GearPtr;
begin
	{ Initialize the values. }
	Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
	Faction_Desc := 'GENERAL ';
	if Fac <> Nil then Faction_Desc := Faction_Desc + SAttValue( Fac^.SA , 'DESIG' );
	if ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Scene := FindRootScene( GB^.Scene );
		if Scene <> Nil then begin
			Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( Scene^.NA , NAG_Personal , NAS_FactionID ) );
			if Fac <> Nil then Faction_Desc := Faction_Desc + ' ' + SAttValue( Fac^.SA , 'DESIG' );
		end;
	end;

	if Renown < 10 then Renown := 10;
	Spending_Limit := Calculate_Threat_Points( Renown , 1 );
	if Spending_Limit < Min_Spending_Limit then Spending_Limit := Min_Spending_Limit;

	Legality_Limit := -NAttValue( NPC^.NA , NAG_CharDescription , NAS_Lawful );
	if Legality_Limit < 10 then Legality_Limit := 10;

	{ Unlike the previous, this will split things into several separate parts. }
	BuyArmorForNPC();

	{ Purchase some weapons. }
	BuyWeaponsForNPC();
end;


Procedure EquipThenDeploy( GB: GameBoardPtr; NPC: GearPtr; PutOnMap: Boolean );
	{ If NPC requires any equipment or mecha, give those, then put it on the map. }
var
	Mek: GearPtr;
begin
	if ( NPC^.G = GG_Character ) and IsACombatant( NPC ) and NotAnAnimal( NPC ) and ( NAttValue( NPC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then begin

		{ On big maps, load a mecha. On small maps, give equipment. }
		if GB^.Scene^.V > 0 then begin
			MEK := SelectNPCMecha( GB , GB^.Scene , NPC );

			if ( Mek <> Nil ) and ( Mek^.SCale <= GB^.Scene^.V ) and ( Mek^.G = GG_Mecha ) then begin
				{ Customize the mecha for its pilot. }
				MechaMakeover( Mek , NAttValue( NPC^.NA , NAG_Personal , NAS_SpecialistSkill ) , NAttValue( NPC^.NA , NAG_Personal , NAS_MechaTheme ) , MechaModPoints( NPC ) );

				{ Stick the mecha in the scene, stick the pilot in the mecha, and }
				{ set the needed values. }
				SetNAtt( MEK^.NA , NAG_Location , NAS_Team , NAttValue( NPC^.NA , NAG_Location , NAS_Team ) );
				SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_Temporary , 1 );
				SetNAtt( Mek^.NA , NAG_Personal , NAS_FactionID , NATtValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
				if BoardMecha( Mek , NPC ) then begin
					NPC := Mek;
				end else begin
					DisposeGear( Mek );
				end;
			end else if Mek <> Nil then begin
				DisposeGear( Mek );
			end;
		end else begin
			{ This is a personal-scale map. Give this combatant }
			{ some equipment to use. }
			SelectEquipmentForNPC( GB , NPC , NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned ) );
		end;
	end;

	DeployGear( GB , NPC , PutOnMap );
end;

end.
