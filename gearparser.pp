unit gearparser;
	{This unit reads a text file and converts it into game}
	{data for GearHead.}
	{ See MDLref.txt for a list of commands. }
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

uses dos,rpgdice,texutil,gears,ghmecha,ghmodule,ghchars,ghweapon,ghsupport,gearutil,locale,interact,ability,ui4gh,ghholder,movement;

Const
	SLOT_Next = 0;
	SLOT_Sub  = 1;
	SLOT_Inv  = 2;

var
	Parser_Macros: SAttPtr;

	Archetypes_List: GearPtr;
	WMonList: GearPtr;
	Standard_Equipment_List: GearPtr;
	STC_Item_List: GearPtr;
	Factions_List: GearPtr;
	Mecha_Theme_List: GearPtr;
	standard_script_list: GearPtr;

Procedure ApplyDictionaryToString( var Info: String; Dictionary: SAttPtr );

Function SkillRankForRenown( Renown: Integer ): Integer;
Procedure SetSkillsAtLevel( NPC: GearPtr; Lvl: Integer );
Function SelectMechaByFactionAndRenown( Factions: String; Renown: Integer ): String;
Procedure IndividualizeNPC( NPC: GearPtr );

Procedure CheckValidity( var it: GearPtr );
Procedure ApplyCharDesc( NPC: GearPtr; CDesc: String );

Function LoadFile( FName,DName: String ): GearPtr;
Function LoadFile( FName: String ): GearPtr;
Function LoadGearPattern( FName,DName: String ): GearPtr;

Function AggregatePattern( FName,DName: String ): GearPtr;
Function LoadRandomSceneContent( FName,DName: String ): GearPtr;

Function LoadSingleMecha( FName,DName: String ): GearPtr;
Function LoadNewMonster( MonsterName: String ): GearPtr;
Function LoadNewNPC( NPCName: String; RandomizeNPCs: Boolean ): GearPtr;
Function LoadNewSTC( Desig: String ): GearPtr;
Function LoadNewItem( FullName: String ): GearPtr;

Procedure RandomLoot( Box: GearPtr; SRP: LongInt; const l_type,l_factions: String );

implementation

uses ghswag,
{$IFDEF ASCII}
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}

Const
	Recursion_Level: Integer = 0;

Procedure SelectThemeAndSpecialty( NPC: GearPtr );
	{ Set a theme and a specialty skill for this NPC. }
const
	Default_Skill_List = '1 2 3 11 15 16 26 28';
var
	Faction,Theme: GearPtr;
	SkillPossibilities: Array [1..NumSkill] of Boolean;
	SpecSkill,T,N: Integer;
	SkList: String;
begin
	if NAttValue( NPC^.NA , NAG_Personal , NAS_SpecialistSkill ) <> 0 then begin
		DialogMsg( 'WARNING: ' + GearName( NPC ) + '/' + SAttValue( NPC^.SA , 'JOB' ) + '/' + BStr( NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) ) + ' had spec skill ' + BStr( NAttValue( NPC^.NA , NAG_Personal , NAS_SpecialistSkill ) ) + ' set.' );
	end;

	{ Start by locating the faction. This should contain a list of preferred skill specialties. }
	Faction := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID ) );
	if Faction <> Nil then SkList := SAttValue( Faction^.SA , 'Specialist_Skills' )
	else SkList := Default_Skill_List;
	if ( SkList = '' ) or ( Random(10) = 1) then SkList := Default_Skill_List;

	{ Clear the SkillPossibilities array, then fill it with entries from the SkList. }
	for t := 1 to NumSkill do SkillPossibilities[t] := False;
	while SkList <> '' do begin
		T := ExtractValue( SkList );
		if ( T >= 1 ) and ( T <= NumSkill ) then SkillPossibilities[t] := True;
	end;

	{ Count the number of skills, pick one at random. }
	N := 0;
	for t := 1 to NumSkill do if SkillPossibilities[t] then Inc( N );
	N := Random( N );
	SpecSkill := 0;
	for t := 1 to NumSkill do begin
		if SkillPossibilities[t] then begin
			Dec( N );
			if N = -1 then begin
				SpecSkill := T;
				break;
			end;
		end;
	end;
	if SpecSkill = 0 then SpecSkill := Random( 5 ) + 1;

	{ Store the specialist skill, and prepare to select the theme. }
	SetNAtt( NPC^.NA , NAG_Personal , NAS_SpecialistSkill , SpecSkill );
	SetNAtt( NPC^.NA , NAG_Skill , SpecSkill , 12 );

	{ Next, it's time to find a theme for this NPC. The theme selected }
	{ is gonna depend on a bunch of stuff: The NPC's faction, the NPC's job, }
	{ personality traits and yadda yadda yadda... }
	{ All characters can take GENERAL themes. }
	SkList := 'GENERAL ' + NPCTraitDesc( NPC ) + ' ' + SAttValue( NPC^.SA , 'JOB_DESIG' );
	{ Add the specialist skill. }
	SkList := SkList + ' [' + BStr( SpecSkill ) + ']';
	if Faction <> Nil then SkList := SkList + ' ' + SAttValue( Faction^.SA , 'DESIG' );

	Theme := FindNextComponent( Mecha_Theme_List , SkList );
	if Theme <> Nil then SetNAtt( NPC^.NA , NAG_Personal , NAS_MechaTheme , Theme^.S )
	else DialogMsg( 'ERROR: No theme found for ' + SkList );
end;

Function SkillRankForRenown( Renown: Integer ): Integer;
	{ Given this renown score, return an appropriate skill rank. }
const
	NumSkillLevel = 15;
	NeededRenown: Array [2..NumSkillLevel] of Integer = (
	-20, -13, 7, 14,
	21, 28, 35, 43, 52,
	62, 73, 85, 98, 112
	);
var
	SkLvl: Integer;
begin
	SkLvl := NumSkillLevel;
	while ( SkLvl > 1 ) and ( NeededRenown[ SkLvl ] > Renown ) do Dec( SkLvl );
	SkillRankForRenown := SkLvl;
end;

Procedure SetSkillsAtLevel( NPC: GearPtr; Lvl: Integer );
	{ Set all of this NPC's skills to an appropriate value for }
	{ the requested level. }
var
	SkLvl: Integer;
	Skill: NAttPtr;
begin
	{ If the NPC doesn't have a specialist skill, pick a skill and theme now. }
	if IsACombatant( NPC ) then begin
		if NAttValue( NPC^.NA , NAG_Personal , NAS_MechaTheme ) = 0 then SelectThemeAndSpecialty( NPC );

		{ Combatants automatically get all the basic combat skills. }
		for SkLvl := 1 to Num_Basic_Combat_Skills do SetNAtt( NPC^.NA , NAG_Skill, SkLvl , 1 );

		{ They also get all hidden skills. }
		for SkLvl := 1 to NumSkill do if SkillMan[ SkLvl ].Hidden then SetNAtt( NPC^.NA , NAG_Skill, SkLvl , 1 );
	end;

	{ Determine the value to set all skills to. }
	SkLvl := SkillRankForRenown( lvl );

	{ Go through the skills and set them. }
	Skill := NPC^.NA;
	while Skill <> Nil do begin
		if Skill^.G = NAG_Skill then begin
			Skill^.V := SkLvl;
		end;
		Skill := Skill^.Next;
	end;

	{ Apply a slight bonus to the specialist skill. }
	SkLvl := NAttValue( NPC^.NA , NAG_Personal , NAS_SpecialistSkill );
	if ( SkLvl > 0 ) and ( SkLvl <= NumSkill ) then AddNAtt( NPC^.NA , NAG_Skill , SkLvl , 1 );

	{ Record the NPC's new Renown score. }
	SetNAtt( NPC^.NA , NAG_CharDescription , NAS_Renowned , Lvl );
end;


Function SelectMechaByFactionAndRenown( Factions: String; Renown: Integer ): String;
	{ Select a mecha based on factions and renown. }
	Function MechaFileMatchWeight( MList: GearPtr ): LongInt;
		{ In order to pass this test, this file must match several }
		{ requirements. There must be mecha capable of travelling in }
		{ all terrain types, there must be at least one mecha matching }
		{ the NPC's faction. }
	var
		M: GearPtr;
		T,N: Integer;
		Total: Int64;
		FacFound: Boolean;
		TerrType: String;
		Terr_Spec_Found: Array [1..Num_Environment_Types] of Boolean;
	begin
		{ Initialize the Terr_Spec_Found array }
		for t := 1 to Num_Environment_Types do Terr_Spec_Found[t] := False;
		Total := 0;
		N := 0;
		FacFound := False;

		{ Go through the list searching for stuff. }
		M := MList;
		while M <> Nil do begin
			if M^.G = GG_Mecha then begin
				Total := Total + GearValue( M );

				if PartAtLeastOneMatch( SAttValue( M^.SA , 'FACTIONS' ) , Factions ) then FacFound := True;

				TerrType := SAttValue( M^.SA , 'TYPE' );
				for t := 1 to Num_Environment_Types do begin
					if AStringHasBString( TerrType , Environment_Idents[ t ] ) then Terr_Spec_Found[ t ] := True;
				end;

				Inc( N );
			end;
			M := M^.Next;
		end;

		{ Check to see if all the terrain types were found. }
		for t := 1 to Num_Environment_Types do if not Terr_Spec_Found[t] then FacFound := False;

		if FacFound and ( N > 0 ) then begin
			MechaFileMatchWeight := Total div N;
		end else MechaFileMatchWeight := 0;
	end;
const
	Min_Max_Cost = 400000;
	Max_Min_Cost = 750000;
var
	SRec: SearchRec;
	MechaList: SAttPtr;
	DList: GearPtr;
	Minimum_Cost, Maximum_Cost: LongInt;
	File_Cost: LongInt;
	MekName: String;
begin
	MechaList := Nil;

	Maximum_Cost := Calculate_Threat_Points( Renown , 35 );
	if Maximum_Cost < Min_Max_Cost then Maximum_Cost := Min_Max_Cost;
	Minimum_Cost := Maximum_Cost div 2 - 200000;
	if Minimum_Cost > Max_Min_Cost then Minimum_Cost := Max_Min_Cost;

	{ Start the search process going... }
	FindFirst( Design_Directory + Default_Search_Pattern , AnyFile , SRec );

	{ As long as there are files which match our description, }
	{ process them. }
	While DosError = 0 do begin
		{ Load this mecha design file from disk. }
		DList := LoadFile( SRec.Name , Design_Directory );

		File_Cost := MechaFileMatchWeight( DList );
		if File_Cost > 0 then begin
			if ( File_Cost > Minimum_Cost ) and ( File_Cost < Maximum_Cost ) then begin
				StoreSAtt( MechaList , SRec.Name );
			end;
		end;

		{ Dispose of the list. }
		DisposeGear( DList );

		{ Look for the next file in the directory. }
		FindNext( SRec );
	end;

	if MechaList <> Nil then begin
		MekName := SelectRandomSAtt( MechaList )^.Info;
		DisposeSAtt( MechaList );
	end else begin
		MekName := 'buruburu.txt';
	end;

	SelectMechaByFactionAndRenown := MekName;
end;

Procedure IndividualizeNPC( NPC: GearPtr );
	{ Randomize up this NPC a bit, to give it that hand-crafted }
	{ NPC look. }
	{ Note that if the NPC has a name by the time it reaches here, its }
	{ personality traits and stats will not be touched. }
var
	N,T,Lvl: Integer;
begin
	{ If the NPC doesn't have a body defined, create one. }
	if NPC^.SubCom = Nil then begin
		ExpandCharacter( NPC );
	end;

	{ Give the NPC a random name + gender + age + personality traits. }
	if SAttValue( NPC^.SA , 'NAME' ) = '' then begin
		SetSAtt( NPC^.SA , 'NAME <' + RandomName + '>' );
		SetNAtt( NPC^.NA , NAG_CharDescription , NAS_Gender , Random( 2 ) );
		if NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) = 0 then AddNAtt( NPC^.NA , NAG_CharDescription , NAS_DAge , 1 + Random( 10 ) - Random( 10 ) + RollStep( 5 ) );

		{ Give out some personality traits. }
		{ Most NPCs have at least a single trait in the group Sociable,Easygoing,Cheerful }
		if Random( 5 ) <> 1 then begin
			if Random( 3 ) = 1 then begin
				AddReputation( NPC, 3 + Random( 3 ) , -RollStep( 40 ) );
			end else begin
				AddReputation( NPC, 3 + Random( 3 ) ,  RollStep( 40 ) );
			end;
		end;
		{ Add RollStep(2) other personality traits. }
		N := RollStep( 2 );
		for t := 1 to N do begin
			{ Positive traits are far more common than negative ones. }
			if Random( 3 ) = 1 then begin
				if Random( 7 ) = 1 then begin
					AddReputation( NPC, Random( Num_Personality_Traits ) + 1 , -RollStep( 50 ) );
				end else begin
					AddReputation( NPC, Random( Num_Personality_Traits ) + 1 , -RollStep( 20 ) );
				end;
			end else begin
				if Random( 7 ) = 1 then begin
					AddReputation( NPC, Random( Num_Personality_Traits ) + 1 , RollStep( 50 ) );
				end else begin
					AddReputation( NPC, Random( Num_Personality_Traits ) + 1 , RollStep( 20 ) );
				end;
			end;
		end;

		{ Randomize up those stats a bit. }
		for t := 1 to NumGearStats do begin
			NPC^.Stat[T] := NPC^.Stat[T] + Random( 4 ) - Random( 4 );
			if Random( 32 ) = 1 then NPC^.Stat[T] := NPC^.Stat[T] + Random( 5 ) - Random( 5 );
			if NPC^.Stat[T] < 1 then NPC^.Stat[T] := 1;
		end;
	end;

	{ If this is a combatant character, set the skills to match the reputation. }
	if IsACombatant( NPC ) then begin
		Lvl := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned );
		if Lvl = 0 then begin
			AddReputation( NPC , Abs( NAS_Renowned ) , Random( 75 ) );
			if Random( 3 ) = 1 then AddReputation( NPC , Abs( NAS_Renowned ) , -Random( 25 ) );
			Lvl := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned );
		end;

		Lvl := Lvl + 50;
		if Lvl < 25 then Lvl := 25;
		SetSkillsAtLevel( NPC , Lvl );
	end;

	{ The random personality traits may have affected morale. }
	SetNAtt( NPC^.NA , NAG_Condition , NAS_MoraleDamage , 0 );
end;


Procedure ComponentScan( it: GearPtr );
	{ This procedure will check each individual component of a mek }
	{ to make sure it is legal. }
begin
	{Loop through all the components.}
	while it <> Nil do begin
		{Perform specific checks here.}
		CheckGearRange( it );

		if it^.SubCom <> Nil then ComponentScan(it^.SubCom);
		if it^.InvCom <> Nil then ComponentScan(it^.InvCom);
		it := it^.Next;
	end;
end;

Procedure CheckMechaMetrics(it: GearPtr);
	{ Examine the components of this mecha to make sure it has everything }
	{ it needs. }
	{ - Exactly one Cockpit }
	{ - Exactly one Body }
	{ - Exactly one engine in the body; If not present, add one. }
	{ - Exactly one gyroscope in the body; If not present, add one. }
	{ If unrecoverable errors are encountered, mark mek as invalid. }
var
	S,SG: GearPtr;
	Body,CPit: Integer;
	procedure SubComScan( P: GearPtr );
	begin
		while P <> Nil do begin
			if P^.G = GG_Cockpit then Inc( CPit );
			if P^.SubCom <> Nil then SubComScan( P^.SubCom );
			P := P^.Next;
		end;
	end;
begin
	{ Count the number of body modules. }
	{ ASSERT: All level one subcomponents will be modules, and }
	{  if a body module is found it will be of the correct size. }
	{  The range checker, called before this procedure, should have }
	{  dealt with that already. }
	S := it^.SubCom;
	Body := 0;
	while S <> Nil do begin
		if ( S^.G = GG_Module ) and ( S^.S = GS_Body ) then begin
			Inc( Body );
			if Body = 1 then begin
				{ Check for the engine. If no engine, install one. }
				SG := S^.SubCom;
				while ( SG <> Nil ) and (( SG^.G <> GG_Support ) or ( SG^.S <> GS_Engine )) do SG := SG^.Next;
				if SG = Nil then begin
					{ Add an engine here. }
					SG := NewGear( S );
					SG^.G := GG_Support;
					SG^.S := GS_Engine;
					SG^.V := S^.V;
					InitGear( SG );
					InsertSubCom( S , SG );
				end;

				{ Check for the gyro. If no gyro, install one. }
				SG := S^.SubCom;
				while ( SG <> Nil ) and (( SG^.G <> GG_Support ) or ( SG^.S <> GS_Gyro )) do SG := SG^.Next;
				if SG = Nil then begin
					{ Add an engine here. }
					SG := NewGear( S );
					SG^.G := GG_Support;
					SG^.S := GS_Gyro;
					SG^.V := 1;
					InitGear( SG );
					InsertSubCom( S , SG );
				end;
			end;
		end;
		S := S^.Next;
	end;
	if Body <> 1 then begin
		it^.G := GG_AbsolutelyNothing;
	end;

	{ Make sure the mecha has exactly one cockpit. }
	CPit := 0;
	SubComScan( it^.SubCom );
	if CPit <> 1 then begin
		it^.G := GG_AbsolutelyNothing;
	end;
end;

Procedure MetricScan( var head: GearPtr );
	{ Scan all the parts, looking for parts which need some counting done. }
var
	P,P2: GEarPtr;
begin
	P := Head;
	while P <> Nil do begin
		P2 := P^.Next;

		{Perform specific checks here.}
		if P^.G = GG_Mecha then CheckMechaMetrics( P );

		{ After the above checking, this gear might be marked for }
		{ deletion. If so, delete it. }
		if P^.G = GG_AbsolutelyNothing then begin
			RemoveGear( Head , P );
		end else begin
			if P^.SubCom <> Nil then MetricScan(P^.SubCom);
			if P^.InvCom <> Nil then MetricScan(P^.InvCom);
		end;
		P := P2;
	end;

end;

Procedure CheckValidity( var it: GearPtr );
	{Check the gears that have just been loaded and make sure}
	{that they conform to the game rules. To do this, we will}
	{scan through every gear in the list, recursing to this}
	{procedure as necessary.}
begin
	{ Do the individual components check. }
	ComponentScan( it );

	{ Do the metrics check for specific components. }
	MetricScan( it );
end;

Procedure ApplyCharDesc( NPC: GearPtr; CDesc: String );
	{ Apply a character description string to this NPC. The character description }
	{ string can contain all kinds of info: personality traits, gender, etc. }
var
	CCD_Cmd: String;	{ Command extracted from line. }
	t: Integer;
begin
	{ Error check! This command only works for characters. }
	if ( NPC = Nil ) or ( NPC^.G <> GG_Character ) then Exit;

	while CDesc <> '' do begin
		CCD_Cmd := ExtractWord( CDesc );

		{ Check to see if this is a gender command. }
		for t := 0 to 1 do begin
			if CCD_Cmd = UpCase( MsgString( 'GenderName_' + BStr( T ) ) ) then begin
				SetNAtt( NPC^.NA , NAG_CharDescription , NAS_Gender , T );
			end;
		end;

		{ If not, check to see if it's a personality command. }
		for t := 1 to Num_Personality_Traits do begin
			if CCD_Cmd = UpCase( MsgString( 'TRAITNAME_' + BStr( T ) + '_+' ) ) then begin
				if NAttValue( NPC^.NA , NAG_CharDescription , -T ) < 50 then begin
					SetNAtt( NPC^.NA , NAG_CharDescription , -T , 50 );
				end else begin
					AddNAtt( NPC^.NA , NAG_CharDescription , -T , 10 );
				end;
			end else if CCD_Cmd = UpCase( MsgString( 'TRAITNAME_' + BStr( T ) + '_-' ) ) then begin
				if NAttValue( NPC^.NA , NAG_CharDescription , -T ) > -50 then begin
					SetNAtt( NPC^.NA , NAG_CharDescription , -T , -50 );
				end else begin
					AddNAtt( NPC^.NA , NAG_CharDescription , -T , -10 );
				end;
			end;
		end;

		{ If not, check to see if it's an age command. }
		if CCD_Cmd = 'YOUNG' then begin
			{ Set the character's age to something below 20. }
			while NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) >= 0 do begin
				AddNAtt( NPC^.NA , NAG_CharDescription , NAS_DAge , -( Random( 6 ) + 1 ) );
			end;
		end else if CCD_Cmd = 'OLD' then begin
			{ Set the character's age to something above 40. }
			while NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) <= 20 do begin
				AddNAtt( NPC^.NA , NAG_CharDescription , NAS_DAge , ( Random( 15 ) + RollStep( 5 ) ) );
			end;

		{ If setting a relationship, also set the NumConversation }
		{ attribute. I'd like to avoid the original Dune's "I am Duke }
		{ Atriedes, your father" crap. }
		end else if CCD_Cmd = 'FRIEND' then begin
			SetNAtt( NPC^.NA , NAG_Relationship , 0 , NAV_Friend );
			SetNAtt( NPC^.NA , NAG_Personal , NAS_NumConversation , 100 );
		end else if CCD_Cmd = 'FAMILY' then begin
			SetNAtt( NPC^.NA , NAG_Relationship , 0 , NAV_Family );
			SetNAtt( NPC^.NA , NAG_Personal , NAS_NumConversation , 100 );
		end else if CCD_Cmd = 'LOVER' then begin
			SetNAtt( NPC^.NA , NAG_Relationship , 0 , NAV_Lover );
			SetNAtt( NPC^.NA , NAG_Personal , NAS_NumConversation , 100 );
		end else if CCD_Cmd = 'ARCHENEMY' then begin
			SetNAtt( NPC^.NA , NAG_Relationship , 0 , NAV_ArchEnemy );
			SetNAtt( NPC^.NA , NAG_Personal , NAS_NumConversation , 100 );
		end;
	end;

end;

Procedure ApplyDictionaryToString( var Info: String; Dictionary: SAttPtr );
	{ This dictionary contains a bunch of substitution strings. Apply them to }
	{ the string provided. }
var
	P,P2: Integer;
	SPat,SRep: String;
begin
	P := 1;
	while P < Length( Info ) do begin
		if ( Info[P] = '%' ) and ( P < ( Length( Info ) - 1 ) ) then begin
			{ We've found a hash. This could be a replacement string. See what string it is. }
			SPat := '%';
			P2 := P;
			repeat
				Inc( P2 );
				SPat := SPat + Info[P2];
			until ( P2 >= Length( Info ) ) or ( Info[P2] = '%' );

			{ We now have a string that may very well be something we want to replace. Check it. }
			SRep := SAttValue( Dictionary , SPat );
			if SRep <> '' then begin
				{ The pattern was found in the dictionary. Replace all instances of it. }
				ReplacePat( Info , SPat , SRep );
				P := P + Length( SRep ) - 1;
			end;
		end;

		Inc( P );
	end;
end;

Procedure InsertStandardScript( Part: GearPtr; ScriptRequest: String );
	{ This part has requested a standard script. }
var
	sr_tag,sr_type,msg: String;
	sr_script: GearPtr;
	Dictionary,SA: SAttPtr;
	T: Integer;
begin
	{ Remove the * from the beginning of the request. }
	DeleteFirstChar( ScriptRequest );

	{ Get some of the needed information. }
	sr_tag := RetrieveAPreamble( ScriptRequest );
	msg := RetrieveAString( ScriptRequest );
	sr_type := ExtractWord( msg );

	{ Locate the script to be used. }
	sr_script := SeekGearByName( standard_script_list , sr_type );
	if sr_script <> Nil then begin
		{ Create our dictionary. }
		Dictionary := Nil;
		AddNAtt( Part^.NA , NAG_GearOps , NAS_MaxStandardScriptID , 1 );
		StoreSAtt( Dictionary , '%id% <' + BStr( NAttValue( Part^.NA , NAG_GearOps , NAS_MaxStandardScriptID ) ) + '>' );
		for t := 1 to 8 do StoreSAtt( Dictionary , '%' + BStr( T ) + '% <' + ExtractWord( msg ) + '>' );

		{ Copy the START script into the sr_tag script, copy everything else }
		{ besides the name over directly. }
		SA := SR_Script^.SA;
		while SA <> Nil do begin
			sr_type := UpCase( RetrieveAPreamble( SA^.Info ) );

			if sr_type = 'START' then begin
				msg := RetrieveAString( SA^.Info );
				ApplyDictionaryToString( msg , Dictionary );
				SetSAtt( Part^.SA , sr_tag + ' <' + msg + '>' );
			end else if sr_type <> 'NAME' then begin
				msg := SA^.Info;
				ApplyDictionaryToString( msg , Dictionary );
				SetSAtt( Part^.SA , msg );
			end;

			SA := SA^.Next;
		end;

		DisposeSAtt( Dictionary );
	end else begin
		DialogMsg( 'ERROR: Standard script ' + sr_type + ' not found.' );
	end;
end;


Function ReadGear( var F: Text; RandomizeNPCs: Boolean; const ZZZFName: String ): GearPtr;
	{F is an open file of type F.}
	{Start reading information from the file, stopping}
	{whenever all the info is read.}
	{ Note that the current implementation of this procedure contracts }
	{ out all validity checking to the CheckGearRange procedure }
	{ in gearutil.pp. }
const
	NDum: GearPtr = Nil;
var
	TheLine,OriginalLine,cmd: String;
	it,C: GearPtr;	{IT is the total list which is returned.}
			{C is the current GEAR being worked on.}
	dest: Byte;	{DESTination of the next GEAR to be added.}
			{ 0 = Sibling; 1 = SubCom; 2 = InvCom }

{*** LOCAL PROCEDURES FOR GHPARSER ***}

Procedure InstallGear(IG_G,IG_S,IG_V: Integer);
	{Install a GEAR of the specified type in the currently}
	{selected installation location. }
begin
	{Determine where the GEAR is to be installed, and check to}
	{see if this is a legal place to stick it.}

	{Do the installing}
	{if C = Nil, we're installing as a sibling at the root level.}
	{ASSERT: If IT = Nil, then C = Nil as well.}
	if (dest = 0) or (C = Nil) then begin
		{NEXT COMPONENT}
		if C = Nil then C := AddGear(it,NDum)
		else C := AddGear(C,C^.Parent);

	end else if dest = 1 then begin
		{SUB COMPONENT}
		C := AddGear(C^.SubCom,C);
		dest := SLOT_Next;
	end else if dest = 2 then begin
		{INV COMPONENT}
		C := AddGear(C^.InvCom,C);
		dest := SLOT_Next;
	end;

	C^.G := IG_G;
	C^.S := IG_S;
	C^.V := IG_V;
	InitGear(C);
end;

Procedure AssignStat( AS_Slot, AS_Val: Integer );
	{ Set stat SLOT of the current gear to value VAL. }
	{ Do nothing if there's some reason why this is impossible. }
begin
	{ Can only assign a stat if the current gear is defined. }
	if C <> Nil then begin
		{ Make sure NUM is in the allowable range. }
		if ( AS_Slot >= 1 ) and ( AS_Slot <= NumGearStats ) then begin
			C^.Stat[ AS_Slot ] := AS_Val;
		end;
	end;
end;

Procedure AssignNAtt( ANA_G, ANA_S, ANA_V: LongInt );
	{ Store the described numeric attribute in the current gear. }
	{ Do nothing if there's some reason why this is impossible. }
begin
	{ Can only store info if the current gear is defined. }
	if C <> Nil then begin
		SetNAtt( C^.NA , ANA_G , ANA_S , ANA_V );
	end;
end;

Procedure CheckMacros( CM_CMD: String );
	{ This command wasn't found in the list of basic commands. }
	{ Maybe it's part of the macro file? Check and see. }
	Function GetMacroValue( var GMV_FX: String ): LongInt;
		{ Extract a value from the macro string, or read it }
		{ from the current line. }
	var
		GMV_MacDat,GMV_LineDat: String;
	begin
		{ First, read the data definition. }
		GMV_MacDat := ExtractWord( GMV_FX );

		{ If the first character is a ?, this means that we should }
		{ read the value from the regular line. }
		if ( GMV_MacDat <> '' ) and ( GMV_MacDat[1] = '?' ) then begin
			{ If the data is found, return it. }
			{ Otherwise return the macro default value. }
			GMV_LineDat := ExtractWord( TheLine );
			if GMV_LineDat <> '' then begin
				GetMacroValue := ExtractValue( GMV_LineDat );
			end else begin
				DeleteFirstChar( GMV_MacDat );
				GetMacroValue := ExtractValue( GMV_MacDat );
			end;
		end else begin
			GetMacroValue := ExtractValue( GMV_MacDat );
		end;
	end;
var
	CM_FX: String;
	CM_A, CM_B, CM_C: LongInt;
begin
	CM_FX := SAttValue( Parser_Macros , CM_CMD );

	{ If a macro matching this command was found, process it. }
	if CM_FX <> '' then begin
		CM_CMD := UpCase( ExtractWord( CM_FX ) );

		if CM_CMD[1] = 'G' then begin
			{ Gear Macro }
			CM_A := GetMacroValue( CM_FX );
			CM_B := GetMacroValue( CM_FX );
			CM_C := GetMacroValue( CM_FX );
			InstallGear( CM_A , CM_B , CM_C );

		end else if CM_CMD[1] = 'S' then begin
			{ Stat Macro }
			CM_A := GetMacroValue( CM_FX );
			CM_B := GetMacroValue( CM_FX );
			AssignStat( CM_A , CM_B );

		end else if CM_CMD[1] = 'N' then begin
			{ NAtt Macro }
			CM_A := GetMacroValue( CM_FX );
			CM_B := GetMacroValue( CM_FX );
			CM_C := GetMacroValue( CM_FX );
			AssignNAtt( CM_A , CM_B , CM_C );

		end else if CM_CMD[1] = 'M' then begin
			{ MODULE Macro }
			CM_A := GetMacroValue( CM_FX );
			InstallGear( GG_Module , CM_A , MasterSize( C ) );

		end;
	end else if CM_CMD <> '' then begin
		DialogMsg( 'ERROR: Command ' + UpCase( CM_CMD ) + ' not found in ' + ZZZFName );
		DialogMsg( '--"' + OriginalLine + '"' );
	end;
end;

Procedure CMD_Sub;
	{Set the destination to SUBCOMPONENT}
begin
	dest := SLOT_Sub;
end;

Procedure CMD_Inv;
	{Set the destination to INVCOMPONENT}
begin
	dest := SLOT_Inv;
end;

Procedure CMD_End;
	{Finish off a range of subcomponents.}
	{If Dest = 0, move to the parent gear.}
	{If Dest <> 0, set Dest to 0.}
begin
	if (dest = 0) and (C <> Nil) then C := C^.Parent
	else dest := 0;
end;


Procedure CMD_Size;
	{Set the V field of the current module to the supplied value.}
var
	CS_Size: Integer;
begin
	CS_Size := ExtractValue(TheLine);

	if C <> Nil then C^.V := CS_Size;
end;

Procedure CMD_Arch;
	{Create a new archetypal character gear.}
	{ The rest of this line is the name of the new archetype. }
begin
	InstallGear(GG_Character,0,0);
	DeleteWhiteSpace( TheLine );
	SetSAtt( C^.SA , 'Name <' + TheLine + '>' );
	TheLine := '';
end;

Procedure CMD_StatLine;
	{ Read all the stats for this gear from a single line. }
var
	CSL_N,CSL_V: Integer;
begin
	{ Error Check! }
	if C = Nil then Exit;

	CSL_N := 1;
	while ( TheLine <> '' ) and ( CSL_N <= NumGearStats ) do begin
		CSL_V := ExtractValue( TheLine );
		C^.Stat[CSL_N] := CSL_V;
		Inc( CSL_N );
	end;
end;

Procedure CMD_SetAlly;
	{ Read this team's allies from the line. }
var
	CSA_AllyID: Integer;
begin
	if ( C = Nil ) then Exit;

	while ( TheLine <> '' ) do begin
		CSA_AllyID := ExtractValue( TheLine );
		if C^.G = GG_Faction then begin
			SetNAtt( C^.NA , NAG_FactionScore , CSA_AllyID , 10 );
		end else begin
			SetNAtt( C^.NA , NAG_SideReaction , CSA_AllyID , NAV_AreAllies );
		end;
	end;
end;

Procedure CMD_SetEnemy;
	{ Read this team's enemies from the line. }
var
	CSE_EnemyID: Integer;
begin
	if ( C = Nil ) then Exit;

	while ( TheLine <> '' ) do begin
		CSE_EnemyID := ExtractValue( TheLine );
		if C^.G = GG_Faction then begin
			AddNAtt( C^.NA , NAG_FactionScore , CSE_EnemyID , -10 );
		end else begin
			SetNAtt( C^.NA , NAG_SideReaction , CSE_EnemyID , NAV_AreEnemies );
		end;
	end;
end;

Procedure META_InsertPartIntoIt( IPII_Part: GEarPtr );
	{ Insert a part into the current gear-being-loaded by the }
	{ method specified in the dest variable. Afterwards, set C }
	{ to equal this new part. }
begin
	if IPII_Part <> Nil then begin
		{ Stick the part somewhere appropriate. }
		if (dest = 0) or (C = Nil) then begin
			{NEXT COMPONENT}
			{ If there is no currently defined C component, }
			{ stick the NPC as the next component at root level. }
			if C = Nil then LastGear( it )^.Next := IPII_Part
			else begin
				LastGear( C )^.Next := IPII_Part;
				IPII_Part^.Parent := C^.Parent;
			end;
		end else if dest = 1 then begin
			{SUB COMPONENT}
			InsertSubCom( C , IPII_Part );
		end else if dest = 2 then begin
			{INV COMPONENT}
			InsertInvCom( C , IPII_Part );
		end;
		dest := SLOT_Next;

		{ Set the current gear to the item's base record. }
		{ Any further modifications will be done there. }
		C := IPII_Part;
	end;
end;

Procedure CMD_NPC;
	{ Search for & then duplicate one of the standard character }
	{ archetypes, inserting it in the gear-under-construction at }
	{ the standard insertion point. }
var
	NPC: GearPtr;
begin
	{ NPC cannot be the first gear in a list!!! }
	if it = Nil then Exit;

	{ Clone the NPC record first. }
	{ Exit the procedure if no appropriate NPC can be found. }
	DeleteWhiteSpace( TheLine );

	{ Note that this procedure doesn't randomize the NPCs itself- that }
	{ will have to wait for the second pass which will randomize all NPCs }
	{ together. }
	NPC := LoadNewNPC( TheLine , False );
	if NPC = Nil then begin
		Exit;
	end;

	{ Get rid of the NPC name, so the parser doesn't try }
	{ interpreting it as a series of commands. }
	TheLine := '';

	{ Stick the NPC somewhere appropriate. }
	META_InsertPartIntoIt( NPC );
end;

Procedure CMD_Monster;
	{ Search for & then duplicate one of the standard monster }
	{ archetypes, inserting it in the gear-under-construction at }
	{ the standard insertion point. }
var
	Mon: GearPtr;
begin
	{ Monster cannot be the first gear in a list!!! }
	if it = Nil then Exit;

	{ Clone the Monster record first. }
	{ Exit the procedure if no appropriate NPC can be found. }
	DeleteWhiteSpace( TheLine );
	Mon := LoadNewMonster( TheLine );
	if Mon = Nil then begin
		Exit;
	end;

	{ Get rid of the NPC name, so the parser doesn't try }
	{ interpreting it as a series of commands. }
	TheLine := '';

	{ Stick the monster somewhere appropriate. }
	META_InsertPartIntoIt( Mon );
end;

Procedure CMD_STC;
	{ Search for & then duplicate one of the standard item }
	{ archetypes, inserting it in the gear-under-construction at }
	{ the standard insertion point. }
var
	STC_Part: GearPtr;
begin
	{ Item cannot be the first gear in a list!!! }
	if it = Nil then Exit;

	{ Clone the item record first. }
	{ Exit the procedure if no appropriate item can be found. }
	DeleteWhiteSpace( TheLine );
	STC_Part := LoadNewSTC( TheLine );
	if STC_Part = Nil then begin
		Exit;
	end;

	{ Get rid of the item name, so the parser doesn't try }
	{ interpreting it as a series of commands. }
	TheLine := '';

	{ Stick the item somewhere appropriate. }
	META_InsertPartIntoIt( STC_Part );
end;

Procedure CMD_Item;
	{ Search for & then duplicate one of the design file }
	{ items, inserting it in the gear-under-construction at }
	{ the standard insertion point. }
var
	STC_Part: GearPtr;
begin
	{ Item cannot be the first gear in a list!!! }
	if it = Nil then Exit;

	{ Clone the item record first. }
	{ Exit the procedure if no appropriate item can be found. }
	DeleteWhiteSpace( TheLine );
	STC_Part := LoadNewItem( TheLine );
	if STC_Part = Nil then begin
		Exit;
	end;

	{ Get rid of the item name, so the parser doesn't try }
	{ interpreting it as a series of commands. }
	TheLine := '';

	{ Stick the item somewhere appropriate. }
	META_InsertPartIntoIt( STC_Part );
end;

Procedure CMD_Scale;
	{ Sets the scale field for the current gear. }
var
	CS_Scale: Integer;
begin
	{ Error check- if there is no current gear, exit this procedure. }
	if ( C = Nil ) then Exit;

	{ Determine what scale to set the current gear to. }
	CS_Scale := ExtractValue( TheLine );

	C^.Scale := CS_Scale;
end;

Procedure CMD_Set_ID;
	{ Sets the "S" descriptor of this gear. Since this gear has already likely been }
	{ initialized, this can be a bad thing to do... use "SetID" only on virtual gear types }
	{ like personas, metascenes, and so on. }
var
	CS_S: Integer;
begin
	{ Error check- if there is no current gear, exit this procedure. }
	if ( C = Nil ) then Exit;

	{ Determine what scale to set the current gear to. }
	CS_S := ExtractValue( TheLine );

	C^.S := CS_S;
end;

Procedure CMD_CharDesc;
	{ This procedure allows certain aspects of a character gear to be }
	{ modified. }
begin
	{ Call the character description procedure above, then clear the line }
	{ to make sure it's not interpreted as a command sequence. }
	ApplyCharDesc( C , TheLine );
	TheLine := '';
end;

Procedure GoIndividualize( LList: GearPtr );
	{ Individualize any NPCs found along this list or in the children of it. }
begin
	while LList <> Nil do begin
		if LList^.G = GG_Character then IndividualizeNPC( LList );
		GoIndividualize( LList^.SubCom );
		GoIndividualize( LList^.InvCom );
		LList := LList^.Next;
	end;
end;

begin
	{ Initialize variables. }
	it := Nil;
	C := Nil;
	dest := SLOT_Next;

	{ Increase the recursion level; the NPC command uses recursion }
	{ and could get stuck in an endless loop. }
	Inc( Recursion_Level );

	while not EoF(F) do begin
		{Read the line from disk, and delete leading whitespace.}
		readln(F,TheLine);
		DeleteWhiteSpace(TheLine);
		OriginalLine := TheLine;

		if ( TheLine = '' ) or ( TheLine[1] = '%' ) then begin
			{ *** COMMENT *** }
			TheLine := '';

		end else if ( TheLine[1] = '*' ) and ( C <> Nil ) and ( ( C^.G > 0 ) or ( C^.G = GG_Faction ) ) then begin
			{ *** STANDARD SCRIPT *** }
			{ This is apparently a standard script. Deal with it. }
			InsertStandardScript( C , TheLine );

		end else if Pos('<',TheLine) > 0 then begin
			{ *** STRING ATTRIBUTE *** }
			if C <> Nil then SetSAtt(C^.SA,TheLine);

		end else begin
			{ *** COMMAND LINE *** }

			{To make things easier upon us, just set the whole}
			{line to uppercase now.}
			TheLine := UpCase(TheLine);

			{Keep processing the line until the end is reached.}
			while TheLine <> '' do begin
				CMD := ExtractWord(TheLine);

				{Branch depending upon what the command is.}
					if CMD = 'SUB' then CMD_Sub
				else	if CMD = 'INV' then CMD_Inv
				else	if CMD = 'END' then CMD_End
				else	if CMD = 'SIZE' then CMD_Size
				else	if CMD = 'SETID' then CMD_Set_ID
				else	if CMD = 'ARCH' then CMD_Arch
				else	if CMD = 'STATLINE' then CMD_StatLine
				else	if CMD = 'SETALLY' then CMD_SetAlly
				else	if CMD = 'SETENEMY' then CMD_SetEnemy
				else	if CMD = 'NPC' then CMD_NPC
				else	if CMD = 'SCALE' then CMD_Scale
				else	if CMD = 'CHARDESC' then CMD_CharDesc
				else	if CMD = 'MONSTER' then CMD_Monster
				else	if CMD = 'STC' then CMD_STC
				else	if CMD = 'ITEM' then CMD_ITEM
				else	if ( CMD <> '' ) and ( CMD[1] = '%' ) then TheLine := ''
				else	CheckMacros( CmD );
			end;
		end;
	end;

	{ If the NPCs are to be randomized, do that now. Why not do it at the }
	{ point when they're loaded? Because they can still be modified by other }
	{ commands, that's why. Imagine you create a NPC, then set its faction. }
	{ if the individualization were done directly at the moment of creation, }
	{ then the individualization procedure wouldn't know the NPC's faction. }
	{ This would be bad. So, we do individualization as an extra step at the end. }
	if RandomizeNPCs then GoIndividualize( it );

	{Run a check on each of the Master Gears we have loaded,}
	{making sure that they are both valid and complete. If}
	{there are any errors, remove the offending entries.}
	{ See TheRules.txt for a brief outline of things to be checked. }
	CheckValidity(it);

	{ Decrement the recursion level. }
	Dec( Recursion_Level );

	ReadGear := it;
end; { ReadGear }

Function LoadFile( FName,DName: String ): GearPtr;
	{ Open and load a text file. }
var
	F: Text;
	it: GearPtr;
begin
	{ Use FSEARCH to confirm the file name. }
	FName := FSearch( FName , DName );
	it := Nil;
	if FName <> '' then begin
		{ The filename has been found and confirmed. }
		{ Actually load the file. }
		Assign( F , FName );
		Reset( F );
		it := ReadGear( F , True , FName );
		Close( F );
	end;
	LoadFile := it;
end;

Function LoadFile( FName: String ): GearPtr;
	{ Open and load a text file. }
begin
	LoadFile := LoadFile( FName , '.' );
end;

Function LoadGearPattern( FName,DName: String ): GearPtr;
	{ Attempt to load a gear file from disk. Search for }
	{ pattern matches. }
var
	FList: SAttPtr;
	it: GearPtr;
begin
	it := Nil;
	if FName <> '' then begin
		{ Build search list for files that match the source. }
		FList := CreateFileList( DName + FName );

		if FList <> Nil then begin
			FName := SelectRandomSAtt( FList )^.Info;
			DisposeSAtt( FList );

			it := LoadFile( FName , DName );
		end;
	end;

	{ Return the selected & loaded gears. }
	LoadGearPattern := it;
end;

Function AggregatePattern( FName,DName: String ): GearPtr;
	{ Search for the given pattern. Then, load all files that match }
	{ the pattern and concatenate them together. Did I spell that }
	{ right? Probably not. }
var
	FList,F: SAttPtr;
	part,it: GearPtr;
begin
	it := Nil;
	if FName <> '' then begin
		{ Build search list for files that match the pattern. }
		FList := CreateFileList( DName + FName );
		F := FList;

		while F <> Nil do begin
			part := LoadFile( F^.Info , DName );
			AppendGear( it , part );
			F := F^.Next;
		end;
		DisposeSAtt( FList );
	end;

	{ Return the selected & loaded gears. }
	AggregatePattern := it;
end;

Function LoadRandomSceneContent( FName,DName: String ): GearPtr;
	{ Search for the given pattern. Then, load all files that match }
	{ the pattern and concatenate them together. Don't randomize NPCs; }
	{ that will be done later. }
var
	FList,F: SAttPtr;
	part,it: GearPtr;
	InFile: Text;
begin
	it := Nil;
	if FName <> '' then begin
		{ Build search list for files that match the pattern. }
		FList := CreateFileList( DName + FName );
		F := FList;

		while F <> Nil do begin
			Assign( InFile , DName + F^.Info );
			Reset( InFile );
			part := ReadGear( InFile , False , FName );
			Close( InFile );

			AppendGear( it , part );
			F := F^.Next;
		end;
		DisposeSAtt( FList );

	end;

	{ Return the selected & loaded gears. }
	LoadRandomSceneContent := it;
end;


Function LoadSingleMecha( FName,DName: String ): GearPtr;
	{ Load a mecha file. Return a single mecha from that file. }
	{ Return Nil if the mecha could not be loaded. }
var
	MList,Mek: GearPtr;
begin
	{ Use the above procedure to load a mecha from disk. }
	MList := LoadGearPattern( FName , DName );
	Mek := Nil;

	if MList <> Nil then begin
		Mek := CloneGear( SelectRandomGear( MList ) );
		DisposeGear( MList );
	end;

	LoadSingleMecha := Mek;
end;

Function LoadNamedGear( FName,GName: String ): GearPtr;
	{ This function will load a file with the given file name. }
	{ Once that is loaded, it will search for a single gear within }
	{ that file with the given gear name. }
var
	F: Text;
	G,LList: GearPtr;
begin
	{ Open and load the archetypes. }
	Assign( F , FName );
	Reset( F );
	LList := ReadGear( F , True , FName );
	Close( F );

	{ Locate the desired archetype. }
	G := SeekGearByName( LList , GName );
	if G <> Nil then G := CloneGear( G );

	{ Dispose of the list & return the cloned gear. }
	DisposeGear( LList );
	LoadNamedGear := G;
end;


Function LoadNewMonster( MonsterName: String ): GearPtr;
	{ This function will load the default monster list and }
	{ return a monster of the requested type. }
var
	Mon: GearPtr;
begin
	{ Load monster from disk. }
	if WMonList <> Nil then begin
		Mon := CloneGear( SeekGearByName( WMonList , MonsterName ) );
	end else begin
		Mon := Nil;
	end;

	{ If it loaded successfully, set its job to "ANIMAL". }
	if Mon <> Nil then begin
		SetSATt( Mon^.SA , 'JOB <ANIMAL>' );
	end;

	{ Return whatever value was returned. }
	LoadNewMonster := Mon;
end;

Function LoadNewNPC( NPCName: String; RandomizeNPCs: Boolean ): GearPtr;
	{ This function will load the NPC archetypes list and }
	{ return a character of the requested type. }
var
	NPC: GearPtr;
begin
	{ Attempt to load the NPC from the standard archetypes file. }
	if Archetypes_List = Nil then begin
		NPC := LoadNamedGear( Archetypes_File , NPCName );
	end else begin
		NPC := CloneGear( SeekGearByName( Archetypes_List , NPCName ) );
	end;

	{ If the NPC was loaded, set its job name and individualize it. }
	if NPC <> Nil then begin
		{ Store a JOB description. This will be the archetype name. }
		SetSATt( NPC^.SA , 'JOB <' + NPCName + '>' );
		SetSAtt( NPC^.SA , 'NAME <>' );

		if RandomizeNPCs then IndividualizeNPC( NPC );
	end;

	{ Return the finished product. }
	LoadNewNPC := NPC;
end;

Function LoadNewSTC( Desig: String ): GearPtr;
	{ This function will load the STC parts list and }
	{ return an item of the requested type. }
var
	Item: GearPtr;
begin
	{ Attempt to load the item from the standard items file. }
	if STC_Item_List = Nil then Exit( Nil );

	Item := CloneGear( SeekGearByDesig( STC_Item_List , Desig ) );

	{ Return the finished product. }
	LoadNewSTC := Item;
end;

Function LoadNewItem( FullName: String ): GearPtr;
	{ This function will check the standard items list }
	{ for a gear with the provided full name. }
var
	Item: GearPtr;
begin
	{ Attempt to load the item from the standard items file. }
	if Standard_Equipment_List = Nil then Exit( Nil );

	Item := CloneGear( SeekSibByFullName( Standard_Equipment_List , FullName ) );

	{ Return the finished product. }
	LoadNewItem := Item;
end;

Procedure RandomLoot( Box: GearPtr; SRP: LongInt; const l_type,l_factions: String );
	{ Fill BOX with SRV (suggested retail price) worth of junk from the standard }
	{ equipment files. }
	Function ItemIsLegal( I: GearPtr ): Boolean;
		{ Return TRUE if I's type and factions match those requested, or }
		{ FALSE otherwise. Oh, I should also be a legal invcom of BOX. }
	begin
		ItemIsLegal := PartAtLeastOneMatch( l_type , SAttValue( I^.SA , 'CATEGORY' ) ) and PartAtLeastOneMatch( l_factions , SAttValue( I^.SA , 'FACTIONS' ) ) and IsLegalInvCom( Box , I );
	end;
	Function RLWeight( Cost,MIC: LongInt ): LongInt;
		{ Return the chance of this item being selected. }
	begin
		if Cost < ( MIC div 4 ) then begin
			RLWeight := 1;
		end else begin
			RLWeight := Cost;
		end;
	end;
	Function SelectAnItem: GearPtr;
		{ Select an appropriate item from the standard items list. }
	var
		Total: Int64;
		MIC,Cost: LongInt;
		I,Selected_Item: GearPtr;
	begin
		Selected_Item := Nil;
		{ Calculate Max Item Cost }
		MIC := ( SRP * 3 ) div 2;
		if MIC < ( SRP + 1000 ) then MIC := SRP + 1000;

		{ Start by finding the total cost of all legal items. }
		I := Standard_Equipment_List;
		Total := 0;
		while I <> Nil do begin
			if ItemIsLegal( I ) then begin
				Cost := GearCost( I );
				if ( Cost > 0 ) and ( Cost < MIC ) then Total := Total + RLWeight( Cost , MIC );
			end;
			I := I^.Next;
		end;

		{ If no items found, exit NIL. }
		if Total < 1 then Exit( Nil );

		{ Next, go through the list again, selecting one at random. }
		I := Standard_Equipment_List;
		Total := Random( Total );
		while ( I <> Nil ) and ( Selected_Item = Nil ) do begin
			if ItemIsLegal( I ) then begin
				Cost := GearCost( I );
				if ( Cost > 0 ) and ( Cost < MIC ) then begin
					Total := Total - RLWeight( Cost , MIC );
					if Total < 1 then Selected_Item := I;
				end;
			end;
			I := I^.Next;
		end;

		SelectAnItem := CloneGear( Selected_Item );
	end;
	Procedure InsertLoot( Box , Item: GearPtr );
		{ Stick ITEM into BOX, or dispose of it. }
	var
		I2: GearPtr;
	begin
		if Item^.G = GG_Set then begin
			while Item^.SubCom <> Nil do begin
				I2 := Item^.SubCom;
				DelinkGear( Item^.SubCom , I2 );
				InsertLoot( Box, I2 );
			end;
			while Item^.InvCom <> Nil do begin
				I2 := Item^.InvCom;
				DelinkGear( Item^.InvCom , I2 );
				InsertLoot( Box, I2 );
			end;
			DisposeGear( Item );
		end else begin
			InsertInvCom( Box , Item );
		end;
	end;
var
	Item: GearPtr;
begin
	{ Keep processing until we run out of money or objects. }
	while SRP > 0 do begin
		Item := SelectAnItem;
		if Item <> Nil then begin
			SRP := SRP - GearCost( Item );
			InsertLoot( Box , Item );
		end else begin
			{ No item found. Set SRP to 0. }
			SRP := 0;
		end;
	end;
end;

Procedure LoadArchetypes;
	{ Load the default, archetypal gears which may be used in the }
	{ construction of other gears. This includes NPC archetypes and }
	{ so forth. }
var
	F: Text;
begin
	{ Open and load the archetypes. }
	Assign( F , Archetypes_File );
	Reset( F );
	Archetypes_List := ReadGear( F , False , 'Archetypes' );
	Close( F );
end;

Procedure SetEquipmentLevels( TestType: Integer );
	{ Equipment will be ranked by relative value. How is relative value calculated? }
	{ First determine what "class" an item belongs in. Sort all items belonging to this }
	{ class based on value. Finally, break the items into 10 value bands based on their }
	{ position in the list. }
	{ If TESTTYPE is nonzero, the contents of this type will be written to out.txt }
type
	SELRecord = Record
		Item: GearPtr;		{ The gear we're talking about. }
		EClass,ERank: Integer;	{ What kind of gear is it? What's its current rank? }
		EValue: LongInt;	{ What's this gear's value? }
	end;
const
	IC_MechaGear = -1;
	IC_MissileWeapon = -2;
	IC_MeleeWeapon = -3;
	IC_Food = -4;
	IC_Medicine = -5;
	Function ItemClass( Item: GearPtr ): Integer;
		{ Return the class this item belongs to. In general, this will be the }
		{ "G" value of the item, unless it's a set in which case it'll be the }
		{ value of the first invcom. }
	begin
		if Item^.G = GG_Set then begin
			ItemClass := ItemClass( Item^.InvCom );
		end else if Item^.G = GG_Mecha then begin
			ItemClass := 0;
		end else if Item^.Scale > 0 then begin
			ItemClass := IC_MechaGear;
		end else if Item^.G = GG_Weapon then begin
			if ( Item^.S = GS_Melee ) or ( Item^.S = GS_EMelee ) then ItemClass := IC_MeleeWeapon
			else ItemClass := IC_MissileWeapon;
		end else if Item^.G = GG_Consumable then begin
			if ( Item^.Stat[ STAT_FoodEffectType ] = 0 ) then ItemClass := IC_Food
			else ItemClass := IC_Medicine;
		end else begin
			ItemClass := Item^.G;
		end;
	end;
	Function ELGearCost( Item: GearPtr ): LongInt;
		{ Return the value of this item, or the average value of items }
		{ in a set. }
	var
		it: LongInt;
	begin
		it := GearCost( Item );
		if ( Item^.G = GG_Set ) and ( Item^.InvCom <> Nil ) then it := it div NumSiblingGears( Item^.InvCom );
		ELGearCost := it;
	end;
var
	SEL: Array of SelRecord;
	Num_Items: Integer;
	Function ItemRanking( N: Integer ): Integer;
		{ Determine this item's ranking in the current list. }
		{ Adjust the rank of other items to compensate. }
	var
		Rank,T: Integer;
	begin
		Rank := 1;
		for T := 0 to ( N-1 ) do begin
			if SEL[t].EClass = SEL[n].EClass then begin
				if SEL[t].EValue > SEL[n].EValue then begin
					{ No idea where N places yet, but it's gotta be }
					{ below T. }
					Inc( SEL[t].ERank );
				end else if SEL[t].ERank >= Rank then begin
					{ This item isn't more expensive than N, but has }
					{ a higher rank. Better fix that. }
					Rank := SEL[t].ERank + 1;
				end;
			end;
		end;
		ItemRanking := Rank;
	end;
	Procedure InitMechaRank( Item: GearPtr );
		{ Mecha get a rank set directly from their value. Set that now, and }
		{ also mark the category. }
	const
		rank_min_val: Array [1..10] of LongInt = (
		0, 100000, 200000, 330000, 481600,
		761600, 1201600, 1801600, 2561600, 3481600
		);
	var
		mval,t,shoprank: LongInt;
	begin
		mval := GearValue( Item );
		shoprank := 1;
		for t := 1 to 10 do if mval > rank_min_val[t] then shoprank := t;
		SetNAtt( Item^.NA , NAG_GearOps , NAS_ShopRank , ShopRank );
		if Item^.G = GG_Mecha then SetSatt( Item^.SA , 'CATEGORY <MECHA>' );
	end;
	Procedure RateClass( EClass: Integer );
		{ Count the number of members in this class. Then, assign each member }
		{ a shop rank of 1 to 10 based on its position in the list. While doing this }
		{ zero out each item's value so we don't end up processing the same }
		{ category twice. }
	var
		T,N,SRank: Integer;
		SList: SAttPtr;
	begin
		{ Error check. }
		if EClass = 0 then exit;

		{ Step One: Count the members. }
		N := 0;
		for t := 0 to ( Num_Items - 1 ) do begin
			if SEL[t].EClass = EClass then Inc( N );
		end;
		SList := Nil;

		{ Step Two: Set the ratings. }
		for t := 0 to ( Num_Items - 1 ) do begin
			if SEL[t].EClass = EClass then begin
				{ We know how many items are in this class, and this item's }
				{ position within that list. From this information we should be able }
				{ to calculate a shop rank for it. }
				{ If there are fewer than 10 items in this class, just use the ranking }
				{ as the shop rank and leave the higher shop ranks empty. }
				if N <= 10 then begin
					SRank := SEL[t].ERank;
				end else begin
					SRank := ( ( SEL[t].ERank -1 ) * 10 ) div N + 1;
				end;

				{ Store the rank in the item. }
				SetNAtt( SEL[t].Item^.NA , NAG_GearOps , NAS_ShopRank , SRank );
				if ( TestType <> 0 ) and ( EClass = TestType ) then StoreSAtt( SList , WideStr( SRank , 2 ) + ' ' + WideStr( SEL[t].ERank , 3 ) + ' ' + FullGearName( SEL[t].Item ) + ' ($' + BStr( GearCost( SEL[t].Item ) ) + ')' );

				SEL[t].EValue := 0;
			end;
		end;
		if SList <> Nil then begin
			SortStringList( SList );
			SaveStringList( 'out.txt' , SList );
			DisposeSAtt( SList );
		end;
	end;
var
	T: Integer;
	Item: GearPtr;
begin
	{ Begin by dimensioning the array. }
	Num_Items := NumSiblingGears( Standard_Equipment_List );
	SetLength( SEL , Num_Items );

	{ Fill out the basic information. }
	Item := Standard_Equipment_List;
	t := 0;
	while Item <> Nil do begin
		SEL[t].Item := Item;
		SEL[t].EClass := ItemClass( Item );

		{ Determine this item's current ranking, unless it's a mecha }
		{ in which case its position is automatically set. }
		if ( Item^.G = GG_Mecha ) or ( ( Item^.G = GG_Set ) and ( Item^.InvCom <> Nil ) and ( Item^.InvCom^.G = GG_Mecha ) ) then begin
			SEL[t].EValue := 0;
			InitMechaRank( Item );
		end else begin
			SEL[t].EValue := ELGearCost( Item );
			SEL[t].ERank := ItemRanking( T );
		end;

		Item := Item^.Next;
		Inc( T );
	end;

	{ Alright, now we have all the items divided into categories and sorted. }
	for t := 0 to ( Num_Items - 1 ) do begin
		if SEL[t].EValue <> 0 then begin
			RateClass( SEL[t].EClass );
		end;
	end;
end;

initialization
	Parser_Macros := LoadStringList( Parser_Macro_File );
	standard_script_list := LoadFile( 'standard_scripts.txt' , Data_Directory );
	STC_Item_List := AggregatePattern( STC_Item_Pattern , Series_Directory );
	LoadArchetypes;
	Standard_Equipment_List := AggregatePattern( '*.txt' , Design_Directory );
	SetEquipmentLevels( 0 );

	WMonList := AggregatePattern( Monsters_File_Pattern , Series_Directory );

	Factions_List := AggregatePattern( 'FACTIONS_*.txt' , Series_Directory );
	Mecha_Theme_List := AggregatePattern( 'THEME_*.txt' , Series_Directory );

finalization
	DisposeSAtt( Parser_Macros );
	DisposeGear( Archetypes_List );
	DisposeGear( WMonList );
	DisposeGear( Standard_Equipment_List );
	DisposeGear( STC_Item_List );
	DisposeGear( Factions_List );
	DisposeGear( Mecha_Theme_List );
	DisposeGear( Standard_Script_List );
end.
