unit chargen;
	{ This unit contains the nuts and bolts of the GearHead }
	{ character generator. }
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

{ ******************** }
{ ***   THE  EGG   *** }
{ ******************** }
{  EGG^.G = GG_Set    }
{  EGG^.S = NA        }
{  EGG^.V = NA        }
{ }
{ Egg Subcoms: The PC and their mecha. }
{ Egg Invcoms: All the NPCs connected to the PC. }
{ }
{ The Character Creator returns an "Egg" containing not only the PC, but also }
{ said PC's life experience and social network. When the egg is imported into }
{ an RPG campaign these elements are placed and initialized. }
{ }
{ }


interface

uses gears;

Const
	RC_DirList = Series_Directory + OS_Search_Separator + OS_Current_Directory;

	BaseStatPts = 80;
	MaxStartingSkill = 5;
	MaxStartingStat = 20;

var
	Jobs_List,Family_List,Bio_List: GearPtr;
	Goal_List,Focus_List: GearPtr;
	Hometown_List: GearPtr;

Function CharacterCreator( Fac: Integer ): GearPtr;
Function RandomNPC( Adv: GearPtr; Fac,Hometown: Integer ): GearPtr;

implementation

uses 	gearutil,ghchars,texutil,ui4gh,description,gearparser,playwright,
	ability,wmonster,dos,locale,menugear,
{$IFDEF ASCII}
	vidgfx,vidinfo,vidmenus;
{$ELSE}
	colormenu,sdlgfx,sdlinfo,sdlmenus;
{$ENDIF}

type
	SkillArray = Array [1..NumSkill] of Integer;

var
	RCPC: GearPtr;
	RCPromptMessage,RCDescMessage,RCCaption: String;

Procedure RandCharRedraw;
	{ Redraw the screen for SDL. }
begin
	ClrScreen;
	if RCPC <> Nil then CharacterDisplay( RCPC , Nil );
	InfoBox( ZONE_CharGenDesc );
	InfoBox( ZONE_CharGenPrompt );
	InfoBox( ZONE_CharGenCaption );
	InfoBox( ZONE_CharGenMenu );

	GameMsg( RCDescMessage , ZONE_CharGenDesc , InfoGreen );
	GameMsg( RCPromptMessage , ZONE_CharGenPrompt , InfoGreen );
	if RCCaption <> '' then CMessage( RCCaption , ZONE_CharGenCaption , InfoGreen );
end;

Procedure EasyStatPoints( PC: GearPtr; StatPt: Integer );
	{ Allocate the stat points for the PC mostly randomly, making sure there are no }
	{ obvious deficiencies. }
const
	NumBaseLineTypes = 7;
	BaseLineName: Array [1..NumBaseLineTypes] of String = (
		'ACADE|MEDIC','CORPO|TRADE','LABOR','MEDIA|POLIT','MILIT',
		'THIEF','CRAFT'
	);
	BaseLineStats: Array [0..NumBaseLineTypes,1..NumGearStats] of Byte = (
	{	Ref	Bod	Spd	Per	Cra	Ego	Kno	Cha	}
	(	8,	8,	8,	8,	8,	8,	8,	8	),	
	(	7,	5,	7,	8,	10,	8,	12,	8	),	{Professor}
	(	8,	7,	8,	8,	8,	8,	8,	9	),	{Corporate}
	(	8,	10,	8,	6,	9,	8,	6,	8	),	{Labor}
	(	7,	8,	7,	6,	7,	10,	7,	12	),	{Celeb}
	(	10,	10,	10,	10,	7,	7,	6,	6	),	{Soldier}
	(	8,	5,	10,	10,	10,	6,	8,	8	),	{Thief}
	(	7,	7,	7,	10,	11,	6,	9,	7	)	{Tech}
	);

var
	Job_Desig: String;
	T,BL: Integer;	{ BL = BaseLine, determined by job. }
begin
	{ Start by determining the baseline stats for this character. Those are going }
	{ to depend upon the job designation. }
	Job_Desig := SAttValue( PC^.SA , 'JOB_DESIG' );
	BL := 0;
	if ( Job_Desig <> '' ) then begin
		for t := 1 to NumBaseLineTypes do begin
			if AStringHasBString( BaseLineName[ T ] , Job_Desig ) then begin
				BL := T;
				Break;
			end;
		end;
	end;

	{ Copy over the baseline values, and reduce the number of free stat points }
	{ appropriately. }
	for t := 1 to NumGearStats do begin
		PC^.Stat[ T ] := BaseLineStats[ BL , T ];
		StatPt := StatPt - BaseLineStats[ BL , T ];
	end;

	{ Spend remaining stat points randomly. }
	if StatPt > 0 then RollStats( PC , StatPt );
end;

Procedure ClearSkillArray( var PCSkills: SkillArray );
	{ Clear the skill array. Seems simple enough. }
var
	T: Integer;
begin
	{ Zero out the base skill values. }
	for t := 1 to NumSkill do begin
		PCSkills[ T ] := 0;
	end;
end;

Function CGPCHasSkill( PC: GearPtr; const PCSkills: SkillArray; Skill: Integer ): Boolean;
	{ Return TRUE if the character being generated has this skill, or FALSE otherwise. }
	{ Don't count the hidden skills, which everyone has. }
begin
	CGPCHasSkill := ( not SkillMan[ Skill ].Hidden ) and ( ( NAttValue( PC^.NA , NAG_Skill , Skill ) > 0 ) or ( PCSkills[ Skill ] > 0 ) );
end;

Function NumPickedSkills( PC: GearPtr; const PCSkills: SkillArray ): Integer;
	{ Return the number of skills this character knows. }
var
	SkT,NPS: Integer;
begin
	NPS := 0;
	for SkT := 1 to NumSkill do begin
		if CGPCHasSkill( PC , PCSkills , SkT ) then Inc( NPS );
	end;
	NumPickedSkills := NPS;
end;

Function CanIncreaseSkill( SkillVal, SkillPt: Integer ): Boolean;
	{ Return TRUE if this skill value can be increased given the remaining number of }
	{ skill points, or FALSE if it can't be. }
	{ To increase a skill by one rank, one must spend SkillVal skill points. }
	{ For instance, to increase a skill from Rank 3 to Rank 4 one would have to }
	{ spend 3 skill points. }
begin
	CanIncreaseSkill := ( SkillVal < MaxStartingSkill ) and ( SkillPt >= SkillVal ) and ( SkillPt > 0 );
end;

Procedure CGImproveSkill( var PCSkills: SkillArray; Skill: Integer; var SkillPt: Integer );
	{ Improve this skill, reducing SkillPt by the appropriate amount. }
begin
	if PCSkills[ Skill ] = 0 then begin
		Dec( SkillPt );
	end else begin
		SkillPt := SkillPt - PCSkills[ Skill ];
	end;
	Inc( PCSkills[ Skill ] );
end;

Procedure SpendSkillPointsRandomly( PC: GearPtr; var PCSkills: SkillArray; SkillPt: Integer );
	{ Spend all remaining skill points randomly. Maybe purchase some new skills, }
	{ if appropriate. At the end of the process, leftover skill points will be }
	{ converted to XP at a rate of 100XP per skill point. }
	{ The SkillArray will not be combined back into the PC; the calling procedure }
	{ must do that itself. }
	Function NumIncreasableSkills: Integer;
		{ Return the number of known skills which may be increased given the number }
		{ of free skill points. }
	var
		Skill,Total: Integer;
	begin
		Total := 0;
		For Skill := 1 to NumSkill do if CGPCHasSkill( PC , PCSkills , Skill ) and CanIncreaseSkill( PCSkills[ Skill ] , SkillPt ) then Inc( Total );
		NumIncreasableSkills := Total;
	end;
	Function NumFreeSkillSlots: Integer;
		{ Return the number of free skill slots. }
		{ Note that this procedure assumes that all characters will want to learn }
		{ the six basic combat skills, so the skill slots equal the number of regular }
		{ skill slots minus ten minus the number of noncombat skills known. }
	var
		SkT,NPS: Integer;
	begin
		NPS := 0;
		for SkT := 7 to NumSkill do begin
			if CGPCHasSkill( PC , PCSkills , SkT ) then Inc( NPS );
		end;

		NumFreeSkillSlots := NumberOfSkillSlots( PC ) - 6 - NPS;
	end;
	Procedure AddNewSkill;
		{ Try to add a new skill to this PC. }
		{ Usually we'll add one of the generic skills that absolutely any character }
		{ might know, but sometimes we'll go all freaky and give out something like }
		{ Biotech or Acrobatics. }
	const
		NumBeginnerSkills = 10;
		BeginnerSkills: Array [1..NumBeginnerSkills] of Byte = (
			NAS_Awareness, NAS_Initiative, NAS_Repair, NAS_Medicine, NAS_ElectronicWarfare,
			NAS_SpotWeakness, NAS_Conversation, NAS_MechaEngineering, NAS_Insight, NAS_Taunt
		);
	var
		Skill: Integer;
	begin
		if Random( 8 ) = 1 then begin
			Skill := Random( NumSkill ) + 1;
		end else begin
			Skill := BeginnerSkills[ Random( NumBeginnerSkills ) + 1 ];
		end;
		if ( not SkillMan[ Skill ].Hidden ) and ( not CGPCHasSkill( PC , PCSkills , Skill ) ) then begin
			CGImproveSkill( PCSkills , Skill , SkillPt );
		end;
	end;
	Procedure ImproveExistingSkill( N: Integer );
		{ Improve the N'th improvable skill known by this PC. }
	var
		Skill: Integer;
	begin
		Skill := 1;
		while ( Skill <= NumSkill ) and ( N > 0 ) do begin
			if CGPCHasSkill( PC , PCSkills , Skill ) and CanIncreaseSkill( PCSkills[ Skill ] , SkillPt ) and ( not SkillMan[ Skill ].Hidden ) then begin
				Dec( N );
				if N = 0 then begin
					CGImproveSkill( PCSkills , Skill , SkillPt );
				end;
			end;
			Inc( Skill );
		end;
	end;
var
	tries,NumSkill,NumSlot: Integer;
begin
	tries := 0;
	while ( SkillPt > 0 ) and ( Tries < 10000 ) do begin

		NumSkill := NumIncreasableSkills;
		NumSlot := NumFreeSkillSlots;

		if ( NumSlot > ( Random( 50 ) + 1 ) ) then begin
			{ Add a new skill. }
			AddNewSkill;
		end else if NumSkill > 0 then begin
			{ Improve an existing skill. }
			ImproveExistingSkill( Random( NumSkill ) + 1 );
		end else begin
			{ Add a new skill. }
			AddNewSkill;
		end;

		Inc( Tries );
	end;

	{ Convert remaining skill points into experience points. }
	if SkillPt > 0 then AddNAtt( PC^.NA , NAG_Experience , NAS_TotalXP , SkillPt * 100 );
end;

Procedure RecordSkills( PC: GearPtr; const PCSkills: SkillArray );
	{ Record the purchased skills in the PC record. }
var
	T: Integer;
begin
	for T := 1 to NumSkill do AddNAtt( PC^.NA , NAG_Skill , T , PCSkills[T] );
end;

Procedure AllocateSkillPoints( PC: GearPtr; SkillPt: Integer );
	{ Distribute the listed number of points out to the PC. }
var
	RPM: RPGMenuPtr;
	PCSkills: SkillArray;
	T,SkNum: Integer;
	Function SkillSelectorMsg( N: Integer ): String;
	var
		msg: String;
	begin
		msg := MsgString( 'SkillName_' + BStr( N ) );
{$IFNDEF ASCII}
		while TextLength( Game_Font , msg ) < ( ZONE_CharGenMenu.W - 50 ) do msg := msg + ' ';
{$ELSE}
		while Length( msg ) < 20 do msg := msg + ' ';
{$ENDIF}
		msg := msg + BStr( NAttValue( PC^.NA , NAG_Skill , N ) + PCSkills[ N ] );
		SkillSelectorMsg := msg;
	end;
	Function FreeSkillSlots: Integer;
		{ Return the number of free skill slots. }
	begin
		FreeSkillSlots := NumberOfSkillSlots( PC ) - NumPickedSkills( PC , PCSkills );
	end;
begin
	ClearSkillArray( PCSkills );

	{ Create the menu & set up the display. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
	RPM^.Mode := RPMNoCleanup;

	RCDescMessage := MsgString( 'RANDCHAR_SkillDesc' );
	RCPromptMessage := '';
	RCCaption := '';

	for t := 1 to NumSkill do begin
		if ( not SkillMan[ T ].Hidden ) then AddRPGMenuItem( RPM , SkillSelectorMsg( T ) , T , SkillDescription( T ) );
	end;
	RPMSortAlpha( RPM );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_ASPDone' ) , -2 );

	RPM^.dtexcolor := InfoGreen;

	AttachMenuDesc( RPM , ZONE_CharGenPrompt );


	{ Add RPGKeys for the left and right buttons, since these will be }
	{ used to spend & retrieve points. }
{$IFNDEF ASCII}
	AddRPGMenuKey( RPM , RPK_Right ,  1 );
	AddRPGMenuKey( RPM , RPK_Left , -1 );
{$ELSE}
	AddRPGMenuKey( RPM , KeyMap[ KMC_East ].KCode ,  1 );
	AddRPGMenuKey( RPM , KeyMap[ KMC_West ].KCode , -1 );
{$ENDIF}

	repeat
		RCCaption := ReplaceHash( MsgString( 'RANDCHAR_ASPPrompt' ) , BStr( SkillPt ) );
		RCCaption := ReplaceHash( RCCaption , BStr( FreeSkillSlots ) );

		T := SelectMenu( RPM , @RandCharRedraw );

		if ( T > 0 ) and ( SkillPt > 0 ) then begin
			{ Increase Skill }
			{ Figure out which skill we're changing... }
			SkNum := RPMLocateByPosition(RPM , RPM^.selectitem )^.value;

			if ( SkNum > 0 ) and ( SkNum <= NumSkill ) and CanIncreaseSkill( PCSkills[ SkNum ] , SkillPt ) then begin
				if CGPCHasSkill( PC , PCSkills , SkNum ) or ( FreeSkillSlots > 0 ) then begin
					CGImproveSkill( PCSkills, SkNum , SkillPt );

					{ Replace the message line. }
					RPMLocateByPosition(RPM , RPM^.selectitem )^.msg := SkillSelectorMsg( SkNum );
				end;
			end; 

		end else if ( T = -1 ) then begin
			{ Decrease Skill }
			{ Figure out which skill we're changing... }
			SkNum := RPMLocateByPosition(RPM , RPM^.selectitem )^.value;

			{ Only decrease if the skill > 0... }
			if ( SkNum > 0 ) and ( SkNum <= NumSkill ) and ( PCSkills[ SkNum ] > 0 ) then begin
				if PCSkills[ SkNum ] = 1 then begin
					Inc( SkillPt );
				end else begin
					SkillPt := SkillPt + PCSkills[ SkNum ] - 1;
				end;
				Dec( PCSkills[ SkNum ] );

				{ Replace the message line. }
				RPMLocateByPosition(RPM , RPM^.selectitem )^.msg := SkillSelectorMsg( SkNum );
			end; 

		end;

	until T = -2;

	{ Spend remaining skill points randomly. }
	if SkillPt > 0 then SpendSkillPointsRandomly( PC , PCSkills , SkillPt );

	{ Copy temporary values into the PC record. }
	RecordSkills( PC , PCSkills );

	{ Get rid of the menu. }
	DisposeRPGMenu( RPM );
end;

Procedure RandomSkillPoints( PC: GearPtr; SkillPt: Integer; IsNPC: Boolean );
	{ Allocate out some sensible skill points to hopefully keep this beginning character }
	{ alive. }
	{ Step One: Decide on primary skills for this character. }
	{ Step Two: Pass remaining points on to the random skill allocator. }
const
	PointsForLevel: Array [1..5] of Byte = (
		1,2,4,7,11
	);
	Function CheckLevel( L: Integer ): Integer;
		{ If the requested skill level is too great for the }
		{ number of skill points posessed, reduce it. }
	begin
		if SkillPt < 1 then Exit( 0 );
		while SkillPt < PointsForLevel[ L ] do Dec( L );
		CheckLevel := L;
	end;
var
	t,L: Integer;
	PCSkills: SkillArray;
begin
	ClearSkillArray( PCSkills );

	{ First give decent Mecha Piloting and Dodge scores. }
	t := CheckLevel( Random( 2 ) + 4 );
	PCSkills[ NAS_MechaPiloting ] := T;
	SkillPt := SkillPt - PointsForLevel[ t ];

	t := CheckLevel( Random( 2 ) + 4 );
	PCSkills[ NAS_Dodge ] := T;
	SkillPt := SkillPt - PointsForLevel[ t ];

	{ Give the guaranteed skill. }
	{ PCs automatically get Conversation. }
	t := CheckLevel( Random( 3 ) + 1 );
	if not IsNPC then begin
		PCSkills[ NAS_Conversation ] := T;
		SkillPt := SkillPt - PointsForLevel[ t ];
	end;

	{ Add combat skills. }
	{ The default character will get all combat skills. }
	for t := 1 to Num_Basic_Combat_Skills do begin
		L := CheckLevel( 2 + Random( 2 ) );
		PCSkills[ T ] := L;
		if L > 0 then SkillPt := SkillPt - PointsForLevel[ L ];
	end;

	{ Spend remaining skill points randomly. }
	if SkillPt > 0 then SpendSkillPointsRandomly( PC , PCSkills , SkillPt );

	{ Copy temporary values into the PC record. }
	RecordSkills( PC , PCSkills );
end;


Function SelectMode: Integer;
	{ Prompt the user for a mode selection. }
var
	RPM: RPGMenuPtr;
	G: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );

	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_SMOp0' ) , 0 );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_SMOp1' ) , 1 );

	RCPromptMessage := MsgString( 'RANDCHAR_SMPrompt' );
	RCDescMessage := MsgString( 'RANDCHAR_SMDesc' );
	RCCaption := '';
	G := SelectMenu( RPM , @RandCharRedraw );

	DisposeRPGMenu( RPM );
	SelectMode := G;
end;

Function SelectGender: Integer;
	{ Prompt the user for a gender selection. }
var
	RPM: RPGMenuPtr;
	G: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );

	AddRPGMenuItem( RPM , MsgString( 'GenderName_0' ) , NAV_Male );
	AddRPGMenuItem( RPM , MsgString( 'GenderName_1' ) , NAV_Female );

	RCDescMessage := MsgString( 'RANDCHAR_SGDesc' );
	RCPromptMessage := MsgString( 'RANDCHAR_SGPrompt' );
	RCCaption := '';
	G := SelectMenu( RPM , @RandCharRedraw );

	DisposeRPGMenu( RPM );

	SelectGender := G;
end;

Function SelectAge: Integer;
	{ Prompt the user for character age. }
var
	RPM: RPGMenuPtr;
	T: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );

	for t := -4 to 10 do begin
		AddRPGMenuItem( RPM , BStr( T + 20 ) + ' years old' , T );
	end;

	RCDescMessage := MsgString( 'RANDCHAR_SADesc' );
	RCPromptMessage := MsgString( 'RANDCHAR_SAPrompt' );
	RCCaption := '';
	T := SelectMenu( RPM , @RandCharRedraw );

	DisposeRPGMenu( RPM );
	SelectAge := T;
end;

Procedure StoreHomeTownDataInPC( PC,City: GearPtr );
	{ Store the information for this PC's home town in the character record. }
var
	msg: String;
	Fac: GearPtr;
begin
	StoreSAtt( PC^.SA , 'HOMETOWN <' + GearName( City ) + '>' );
	StoreSAtt( PC^.SA , 'HOMETOWN_FACTIONS <' + SAttValue( City^.SA , 'FACTIONS' ) + '>' );
	msg := SAttValue( City^.SA , 'TYPE' ) + ' ' + SAttValue( City^.SA , 'DESIG' );

	Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( City^.NA , NAG_Personal , NAS_FactionID ) );
	if Fac <> Nil then begin
		msg := msg + ' ' + SAttValue( Fac^.SA , 'DESIG' );
		StoreSAtt( PC^.SA , 'HOMETOWN_GOVERNMENT <' + SAttValue( Fac^.SA , 'DESIG' ) + '>' );
	end;

	StoreSAtt( PC^.SA , 'HOMETOWN_CONTEXT <' + msg + '>' );
end;

Procedure SelectHomeTown( PC: GearPtr; CanEdit: Boolean; ForceFac: Integer );
	{ Select the PC's home town. Store the home town information in the PC }
	{ string attributes. }
	{ If ForceFac is nonzero, the generated PC must belong to this faction or }
	{ no faction at all. So, only allow cities where this faction is active. }
var
	City,Fac: GearPtr;
	N: Integer;
	RPM: RPGMenuPtr;
	FacDesig: String;
begin
	if ForceFac <> 0 then begin
		Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , ForceFac );
		FacDesig := SAttValue( Fac^.SA , 'DESIG' );
	end;

	{ Create the menu. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
	AttachMenuDesc( RPM , ZONE_CharGenPrompt );

	RCDescMessage := MsgString( 'RANDCHAR_CityDesc' );
	RCPromptMessage := '';
	RCCaption := MsgString( 'RANDCHAR_CityPrompt' );

	{ Add all faction-legal HOMETOWNs to the menu. }
	N := 1;
	City := Hometown_List;
	while City <> Nil do begin
		if ( ForceFac = 0 ) or AStringHasBString( SAttValue( City^.SA , 'FACTIONS' ) , FacDesig ) then begin
			AddRPGMenuItem( RPM , GearName( City ) , N , SAttValue( City^.SA , 'DESC' ) );
		end;
		Inc( N );
		City := City^.Next;
	end;
	RPMSortAlpha( RPM );

	if RPM^.NumItem < 1 then begin
		{ We've got ourselves an empty menu. Just pick a hometown randomly. }
		N := Random( NumSiblingGears( Hometown_List ) ) + 1;
	end else if CanEdit then begin
		{ Can edit - allow the PC to select a home town. }
		N := SelectMenu( RPM , @RandCharRedraw );
		if N = -1 then begin
			N := RPMLocateByPosition( RPM , Random( RPM^.NumItem ) + 1 )^.value;
		end;
	end else begin
		{ Can't edit- select a home town randomly. }
		N := RPMLocateByPosition( RPM , Random( RPM^.NumItem ) + 1 )^.value;
	end;
	DisposeRPGMenu( RPM );

	{ Store the data for this city. }
	City := RetrieveGearSib( Hometown_List , N );
	if City <> Nil then begin
		StoreHomeTownDataInPC( PC , City );
	end;
end;

Function FilterList( Source: GearPtr; const PContext: String ): GearPtr;
	{ Create a list of things based on the context provided. }
	{ Yeah, I know, real specific there... }
var
	it,J: GearPtr;
	Context: String;
begin
	{ Add a GENERAL tag to the context. Everybody gets a GENERAL tag. }
	context := 'GENERAL ' + PContext;
	it := Nil;

	{ Go through the jobs list and copy everything that matches the context. }
	J := Source;
	while J <> Nil do begin
		if StringMatchWeight( Context , SAttValue( J^.SA , 'REQUIRES' ) ) > 0 then begin
			AppendGear( it , CloneGear( J ) );
		end;
		J := J^.Next;
	end;

	{ Return the finished list. }
	FilterList := it;
end;

Procedure ApplyJobModifiers( PC, Job: GearPtr );
	{ Given the provided job, apply its bonuses and whatnot to the }
	{ provided PC. }
var
	N,T: Integer;
begin
	{ Copy over the details and bonuses from this job. }
	{ Each job will give a +1 bonus to a number of skills, and also some starting }
	{ cash. The more skills given, the less money the PC starts with. }
	N := 0;
	for t := 1 to NumSkill do begin
		if NAttValue( Job^.NA , NAG_Skill , T ) <> 0 then begin
			AddNAtt( PC^.NA , NAG_Skill , T , 1 );
			inc( N );
		end;
	end;
	if N > 3 then N := 3;
	AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , 45000 * ( 3 - N ) );

	{ Copy the personality traits. }
	for t := 1 to Num_Personality_Traits do begin
		AddReputation( PC , T , NAttValue( Job^.NA , NAG_CharDescription , -T ) );
	end;

	SetNAtt( PC^.NA , NAG_Personal , NAS_FactionID , NAttValue( Job^.NA , NAG_Personal , NAS_FactionID ) );
	SetSAtt( PC^.SA , 'JOB <' + SAttValue( Job^.SA , 'NAME' ) + '>' );
	SetSAtt( PC^.SA , 'JOB_DESIG <' + SAttValue( Job^.SA , 'DESIG' ) + '>' );
end;

Procedure GenerateFamilyHistory( Egg , PC: GearPtr; CanEdit: Boolean );
	{ Generate the PC's personal history up to this point. This step will }
	{ determine the following information: }
	{ - Starting skill XP bonuses }
	{ - the PC's parentage (or lack thereof) }
	{ - the PC's starting XXRan context + enemy faction }
	{ - NPCs for the PC's egg (family, friends, and otherwise) }
	{ - The PC's personal conflict }
const
	Parental_XP = 210;
var
	RPM: RPGMenuPtr;
	LegalJobList,Fam,BioEvent: GearPtr;
	N: Integer;
	Context,Bio1: String;
{ Procedures block. }
	Procedure ApplyParentalBonus( Job: GearPtr );
	var
		N,T: Integer;
	begin
		{ Error check - Job might be NIL. }
		if Job = Nil then begin
			AddNAtt( PC^.NA , NAG_Experience , NAS_TotalXP , ( Parental_XP * 2 ) div 3 );
			Exit;
		end;

		{ See what's in there. }
		{ We have to make two passes- one to see how many skills there are, }
		{ then a second one to apply the experience. }
		N := 0;
		{ Count skills. }
		for t := 1 to NumSkill do begin
			if NAttValue( Job^.NA , NAG_SKill , T ) <> 0 then begin
				Inc( N );
			end;
		end;

		{ Apply bonuses. }
		if N > 0 then begin
			for t := 1 to NumSkill do begin
				if NAttValue( Job^.NA , NAG_SKill , T ) <> 0 then begin
					AddNAtt( PC^.NA , NAG_Experience , NAS_Skill_XP_Base + t , Parental_XP div N );
				end;
			end;
		end else begin
			AddNAtt( PC^.NA , NAG_Experience , NAS_TotalXP , ( Parental_XP * 2 ) div 3 );
		end;
	end;
	Procedure ApplyBiographyEvent( Bio: GearPtr );
		{ Apply the changes brought about by this biography event. }
	var
		Base,Changes: String;
		T: Integer;
		Jobs: GearPtr;
	begin
		{ An empty biography has no effect. }
		if Bio = Nil then begin
			AddNAtt( PC^.NA , NAG_Experience , NAS_TotalXP , ( Parental_XP * 4 ) div 3 );
			Exit;
		end;

		{ Copy over the personality traits from the biography event. }
		for t := 1 to Num_Personality_Traits do begin
			AddNAtt( PC^.NA , NAG_CharDescription , -T , NAttValue( Bio^.NA , NAG_CharDescription , -T ) );
		end;

		{ Copy the changes to the PC's context. }
		Base := SAttValue( PC^.SA , 'CONTEXT' );
		Changes := SAttValue( Bio^.SA , 'CONTEXT' );
		AlterDescriptors( Base , Changes );
		SetSAtt( PC^.SA , 'CONTEXT <' + Base + '>' );

		{ Copy over the egg attributes, if appropriate. }
		Base := SAttValue( Bio^.SA , 'CONFLICT' );
		if Base <> '' then SetSAtt( Egg^.SA , 'CONFLICT <' + Base + '>' );

		{ Apply the bonuses from the jobs. }
		{ Only two jobs may be applied as bonuses. }
		Jobs := Bio^.SubCom;
		T := 2;
		while ( Jobs <> Nil ) and ( T > 0 ) do begin
			ApplyParentalBonus( Jobs );
			Dec( T );
			Jobs := Jobs^.Next;
		end;
		if T > 0 then begin
			AddNAtt( PC^.NA , NAG_Experience , NAS_TotalXP , ( Parental_XP * T * 2 ) div 3 );
		end;

		{ Copy over the background NPCs. }
		while Bio^.InvCom <> Nil do begin
			Jobs := Bio^.InvCom;
			DelinkGear( Bio^.InvCom , Jobs );
			InsertInvCom( Egg , Jobs );
		end;
	end;
	Procedure InitBackground( BGGear: GearPtr );
		{ Initialize this background gear and any NPCs it }
		{ requests. Initialize the description. }
	var
		desc: String;
		NPC,Job1: GearPtr;
		N: Integer;
	begin
		if BGGear = Nil then Exit;
		desc := SAttValue( BGGear^.SA , 'DESC' );
		ReplacePat( desc , '%job%' , SAttValue( PC^.SA , 'JOB' ) );
		if NAttValue( PC^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then begin
			ReplacePat( desc , '%sd%' , MsgString( 'SON' ) );
		end else begin
			ReplacePat( desc , '%sd%' , MsgString( 'DAUGHTER' ) );
		end;

		{ Initialize the NPCs requested by this event. If they are a }
		{ mentor, store their jobs as subcoms of BGGear }
		NPC := BGGear^.invcom;
		N := 1;
		while NPC <> Nil do begin
			{ Assign the NPC a name, and ititialize its age. }
			SetSAtt( NPC^.SA , 'NAME <' + RandomName + '>' );
			AddNAtt( NPC^.NA , NAG_CharDescription , NAS_DAge , NAttValue( PC^.NA , NAG_CharDescription , NAS_DAge )  + Random( 4 ) - Random( 4 ) );

			{ Select a job. }
			Job1 := SelectRandomGear( LegalJobList );
			if NAttValue( NPC^.NA , NAG_CharDescription , NAS_IsMentor ) <> 0 then begin
				InsertSubCom( BGGear , CloneGear( Job1 ) );
			end;
			ApplyJobModifiers( NPC , Job1 );

			{ Alter the DESC }
			ReplacePat( desc , '%job' + BStr( N ) + '%' , GearName( Job1 ) );
			ReplacePat( desc , '%name' + BStr( N ) + '%' , GearName( NPC ) );

			{ Allocate stat and skill points. }
			EasyStatPoints( NPC , 105 );
			RandomSkillPoints( NPC , 50 , True );

			Inc( N );
			NPC := NPC^.Next;
		end;

		SetSAtt( BGGear^.SA , 'DESC <' + desc + '>' );
	end;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_FHAccept' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_FHDecline' ) , -1 );

	if CanEdit then begin
		RCPromptMessage := '';
		RCDescMessage := MsgString( 'RANDCHAR_FHDesc' );
		RCCaption := MsgString( 'RANDCHAR_FHPrompt' );
	end;

	Context := SAttValue( PC^.SA , 'HOMETOWN_CONTEXT' ) + ' ' + SAttValue( PC^.SA , 'JOB_DESIG' ) + ' ' + SAttValue( PC^.SA , 'CG_FACDESIG' );
	LegalJobList := FilterList( Jobs_List , Context );
	Fam := Nil;
	BioEvent := Nil;

	repeat
		{ Decide upon the family history here, giving skill points }
		{ and whatever. }

		{ Start with a random component. }
		if Fam <> Nil then DisposeGear( Fam );
		if BioEvent <> Nil then DisposeGear( BioEvent );

		{ Roll the family type for the PC. }
		Fam := CloneGear( FindNextComponent( Family_List , 'GENERAL ' + Context ) );
		InitBackground( Fam );
		bio1 := SAttValue( Fam^.SA , 'DESC' );

		{ Roll the biography event for the PC. }
		if Random( 3 ) <> 1 then begin
			BioEvent := CloneGear( FindNextComponent( Bio_List , 'GENERAL ' + Context + ' ' + SAttValue( Fam^.SA , 'CONTEXT' ) ) );
			if BioEvent <> Nil then begin
				InitBackground( BioEvent );
				bio1 := bio1 + ' ' + SAttValue( BioEvent^.SA , 'DESC' );
			end;
		end;

		AtoAn( bio1 );

		{ Display the created biography for the user. }
		SetSAtt( PC^.SA , 'BIO1 <' + Bio1 + '>' );

		{ Decide whether to accept or decline this family history. }
		if CanEdit then begin
			N := SelectMenu( RPM , @RandCharRedraw );
		end else begin
			N := 1;
		end;
	until N = 1;

	ApplyBiographyEvent( Fam );
	DisposeGear( Fam );
	ApplyBiographyEvent( BioEvent );
	DisposeGear( BioEvent );

	SetSAtt( PC^.SA , 'BIO1 <' + Bio1 + '>' );

	DisposeRPGMenu( RPM );

	DisposeGear( LegalJobList );
end;


Procedure SelectJobAndFaction( PC: GearPtr; CanEdit: Boolean; ForceFac: Integer );
	{ Select a job for the PC. }
	{ Based on this job, select a faction. }
	function NeedsFaction( Job: GearPtr ): Boolean;
		{ Return TRUE if the provided job absolutely must have a faction }
		{ associated with it, or FALSE otherwise. }
	begin
		NeedsFaction := AStringHasBString( SAttValue( Job^.SA , 'SPECIAL' ) , 'NeedsFaction' );
	end;
	Function JobFitsFaction( Job,Faction: GearPtr ): Boolean;
		{ Return TRUE if this job fits this faction, or FALSE otherwise. }
	begin
		JobFitsFaction := AStringHasBString( SAttValue( Faction^.SA , 'JOBS' ) , SAttValue( Job^.SA , 'Desig' ) );
	end;
	Function CreateFactionList( Loc_Factions: String; Job: GearPtr ): GearPtr;
		{ Create a list of legal factions for the PC to choose from. }
		{ It must be a faction featured in the PC's home town, and it must }
		{ be hiring people on the PC's job path. }
		{ If ForceFac is nonzero, it must be that faction. }
	var
		it,F: GearPtr;
	begin
		if ForceFac <> 0 then begin
			it := CloneGear( SeekCurrentLevelGear( Factions_List , GG_Faction , ForceFac ) );
		end else begin
			it := Nil;
			F := Factions_List;
			while F <> Nil do begin
				if AStringHasBString( Loc_Factions , SAttValue( F^.SA , 'DESIG' ) ) and JobFitsFaction( Job , F ) then begin
					AppendGear( it , CloneGear( F ) );
				end;
				F := F^.Next;
			end;
		end;
		CreateFactionList := it;
	end;
	Procedure DoExtraFacFilter( Fac: GearPtr; var LegalJobList: GearPtr );
		{ The PC must belong to a specific faction or no faction at all. }
		{ If any of these jobs have a preset faction or require a faction }
		{ but can't be taken by the available faction, they get deleted from }
		{ the list. That's an awful run-on sentance but I was busy all day }
		{ making kimchi. }
	var
		J,J2: GearPtr;
		FID: Integer;
	begin
		J := LegalJobList;
		while J <> Nil do begin
			J2 := J^.Next;
			FID := NAttValue( J^.NA , NAG_Personal , NAS_FactionID );
			if ( FID <> 0 ) and ( FID <> ForceFac ) then begin
				RemoveGear( LegalJobList , J );
			end else if NeedsFaction( J ) and not JobFitsFaction( J , Fac ) then begin
				RemoveGear( LegalJobList , J );
			end;

			J := J2;
		end;
	end;
	Function JobDescription( Job: GearPtr ): String;
		{ Return a description for this job: This will be its category }
		{ and its list of skills. }
	var
		msg: String;
		S,N: Integer;
	begin
		{ Start with the job category. }
		msg := '(' + SAttValue( Job^.SA , 'DESIG' ) + ') ';

		{ Add the skills. }
		N := 0;
		for S := 1 to NumSkill do begin
			if NAttValue( Job^.NA , NAG_Skill , S ) <> 0 then begin
				if N > 0 then msg := msg + ', ';
				msg := msg + MsgString( 'SkillName_' + BStr( S ) );
				inc( N );
			end;
		end;
		JobDescription := msg;
	end;
var
	RPM: RPGMenuPtr;
	LegalJobList,Job,LegalFactionList,F: GearPtr;
	Context: String;
	N: Integer;
{ Procedures block. }
begin
	Context := SAttValue( PC^.SA , 'HOMETOWN_CONTEXT' );
	LegalJobList := FilterList( Jobs_List , Context );

	if ForceFac <> 0 then DoExtraFacFilter( SeekCurrentLevelGear( Factions_List , GG_Faction , ForceFac ) , LegalJobList );

	if CanEdit then begin
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
		AttachMenuDesc( RPM , ZONE_CharGenPrompt );

		RCPromptMessage := '';
		RCDescMessage := MsgString( 'RANDCHAR_JobDesc' );
		RCCaption := MsgString( 'RANDCHAR_JobPrompt' );

		{ Fill the menu. }
		Job := LegalJobList;
		N := 1;
		while Job <> Nil do begin
			AddRPGMenuItem( RPM , GearName( Job ) , N , JobDescription( Job ) );
			Inc( N );
			Job := Job^.Next;
		end;
		RPMSortAlpha( RPM );

		{ Select an item from the menu. }
		N := SelectMenu( RPM , @RandCharRedraw );
		DisposeRPGMenu( RPM );

		{ Locate the Job gear selected. If no job was selected, pick one randomly. }
		if N > -1 then begin
			Job := RetrieveGearSib( LegalJobList , N );
		end else begin
			Job := SelectRandomGear( LegalJobList );
		end;

	end else begin
		Job := SelectRandomGear( LegalJobList );
	end;

	ApplyJobModifiers( PC , Job );

	{ Copy the changes to the PC's context. }
	Context := SAttValue( PC^.SA , 'CONTEXT' ) + ' C:' + SAttValue( Job^.SA , 'DESIG' );
	SetSAtt( PC^.SA , 'CONTEXT <' + Context + '>' );


	{ Next, see about a faction. Some jobs have factions assigned to them... }
	{ For instance, if your job is "Knight", you'll start as a member of the }
	{ Silver Knights. The designation of your job and your home town will }
	{ determine what factions you can join. You are also free to not join a }
	{ faction, unless your job indicates that it requires a faction choice. }
	if NAttValue( Job^.NA , NAG_Personal , NAS_FactionID ) <> 0 then begin
		{ This job comes with a pre-assigned faction. }
		SetNAtt( PC^.NA , NAG_Personal , NAS_FactionID , NAttValue( Job^.NA , NAG_Personal , NAS_FactionID ) );
	end else if CanEdit or NeedsFaction( Job ) then begin
		{ This job can maybe have a faction assigned. }
		LegalFactionList := CreateFactionList( SAttValue( PC^.SA , 'HOMETOWN_FACTIONS' ) , Job );


		if CanEdit and ( LegalFactionList <> Nil ) then begin
			{ Create the menus. }
			RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
			AttachMenuDesc( RPM , ZONE_CharGenPrompt );
			RCCaption := MsgString( 'RANDCHAR_FactionPrompt' );
			RCDescMessage := MsgString( 'RANDCHAR_FactionDesc' );

			{ Add the factions. }
			F := LegalFactionList;
			while F <> Nil do begin
				AddRPGMenuItem( RPM , GearName( F ) , F^.S , SAttValue( F^.SA , 'DESC' ) );
				F := F^.Next;
			end;
			RPMSortAlpha( RPM );

			{ If this job absolutely requires a faction, don't add the "NoFac" option }
			{ to the menu. }
			if not NeedsFaction( Job ) then AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_NoFactionPlease' ) , -1 );

			{ If there are any factions in the menu, select one. }
			if RPM^.NumItem > 1 then begin
				N := SelectMenu( RPM , @RandCharRedraw );
			end else N := RPM^.FirstItem^.Value;

			F := SeekCurrentLevelGear( LegalFactionList , GG_Faction , N );
			if ( F = Nil ) and NeedsFaction( Job ) then F := SelectRandomGear( LegalFactionList );

			{ Get rid of the menu. }
			DisposeRPGMenu( RPM );

		end else if NeedsFaction( Job ) or ( Random( 3 ) = 1 ) then begin
			F := SelectRandomGear( LegalFactionList );
		end;

		{ Apply the bonuses for this faction. }
		if F <> Nil then begin
			SetNAtt( PC^.NA , NAG_Personal , NAS_FactionID , F^.S );
			AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , 50000 );
			SetSAtt( PC^.SA , 'CG_FacDesig <' + SAttValue( F^.SA , 'DESIG' ) + '>' );
		end;

		{ Get rid of the factions list. }
		DisposeGear( LegalFactionList );
	end;

	DisposeGear( LegalJobList );
end;

Procedure AllocateStatPoints( PC: GearPtr; StatPt: Integer );
	{ Distribute the listed number of points out to the PC. }
var
	RPM: RPGMenuPtr;
	PCStats: Array [1..NumGearStats] of Integer;
	T: Integer;
	Function StatSelectorMsg( N: Integer ): String;
	var
		msg: String;
	begin
		msg := MsgString( 'StatName_' + BStr( N ) );

{$IFNDEF ASCII}
		while TextLength( Game_Font , msg ) < ( ZONE_CharGenMenu.W - 50 ) do msg := msg + ' ';
{$ELSE}
		while Length( msg ) < 12 do msg := msg + ' ';
{$ENDIF}
		msg := msg + BStr( PCStats[ N ] + PC^.Stat[ N ] );
		StatSelectorMsg := msg;
	end;
begin
	{ Zero out the base stat line, and make sure minimum values are met. }
	for t := 1 to NumGearStats do begin
		PCStats[ T ] := 0;
		if PC^.Stat[ T ] < 1 then begin
			PC^.Stat[ T ] := 1;
			Dec( StatPt );
		end;
	end;

	{ Create the menu & set up the display. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );

	RPM^.Mode := RPMNoCleanup;
	RCDescMessage := MsgString( 'RANDCHAR_ASPDesc' );
	RCPromptMessage := '';

	for t := 1 to NumGearStats do begin
		AddRPGMenuItem( RPM , StatSelectorMsg( T ) , 1 , MsgString( 'STATDESC_' + BStr( T ) ) );
	end;
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_ASPDone' ) , 2 );

	RPM^.dtexcolor := InfoGreen;

	AttachMenuDesc( RPM , ZONE_CharGenPrompt );

	{ Add RPGKeys for the left and right buttons, since these will be }
	{ used to spend & retrieve points. }
{$IFNDEF ASCII}
	AddRPGMenuKey( RPM , RPK_Right ,  1 );
	AddRPGMenuKey( RPM , RPK_Left , -1 );
{$ELSE}
	AddRPGMenuKey( RPM , KeyMap[ KMC_East ].KCode ,  1 );
	AddRPGMenuKey( RPM , KeyMap[ KMC_West ].KCode , -1 );
{$ENDIF}

	repeat
		RCCaption := ReplaceHash( MsgString( 'RANDCHAR_SelectStatsCap' ) , BStr( StatPt ) );
		T := SelectMenu( RPM , @RandCharRedraw );

		if ( T = 1 ) and ( RPM^.selectitem <= NumGearStats ) and ( StatPt > 0 ) then begin
			{ Increase Stat }
			{ Only do this if the stat is currently below the max value. }
			if PCStats[ RPM^.selectitem ] < MaxStartingStat then begin
				{ Only do this if the player has enough points to do so... }
				if ( StatPt > 1 ) or ( PCStats[ RPM^.selectitem ] < NormalMaxStatValue ) then begin
					{ Increase the stat. }
					Inc( PCStats[ RPM^.selectitem ] );

					{ Decrease the free stat points. Take away 2 if }
					{ this stat has been improved to the normal maximum. }
					Dec( StatPt );
					if PCStats[ RPM^.selectitem ] > NormalMaxStatValue then Dec( StatPt );

					{ Replace the message line. }
					RPMLocateByPosition(RPM , RPM^.selectitem )^.msg := StatSelectorMsg( RPM^.selectitem );
				end;
			end;
		end else if ( T = -1 ) and ( RPM^.selectitem <= NumGearStats ) then begin
			{ Decrease Stat }
			if PCStats[ RPM^.selectitem ] > 0 then begin
				{ Decrease the stat. }
				Dec( PCStats[ RPM^.selectitem ] );

				{ Increase the free stat points. Give back 2 if }
				{ this stat has been improved to the normal maximum. }
				Inc( StatPt );
				if PCStats[ RPM^.selectitem ] >= NormalMaxStatValue then Inc( StatPt );

				{ Replace the message line. }
				RPMLocateByPosition(RPM , RPM^.selectitem )^.msg := StatSelectorMsg( RPM^.selectitem );
			end;

		end;

	until T = 2;

	{ Copy temporary values into the PC record. }
	for T := 1 to NumGearStats do PC^.Stat[T] := PC^.Stat[T] + PCStats[T];

	{ Spend remaining stat points randomly. }
	if StatPt > 0 then RollStats( PC , StatPt );

	{ Get rid of the menu. }
	DisposeRPGMenu( RPM );
end;


Procedure SelectATalent( PC: GearPtr );
	{ The PC needs to select a talent. Create a list of all the }
	{ legally available talents, then have the PC select one. }
var
	RPM: RPGMenuPtr;
	T: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
	AttachMenuDesc( RPM , ZONE_CharGenPrompt );

	{ Add the legal talents. }
	for t := 1 to NumTalent do begin
		if CanLearnTalent( PC , T ) then AddRPGMenuItem( RPM , MsgString( 'TALENT' + BStr( T ) ) , T , MsgString( 'TALENTDESC' + BStr( T ) ) );
	end;

	RCCaption := MsgString( 'RANDCHAR_TalentPrompt' );
	RCDescMessage := MsgString( 'RANDCHAR_TalentDesc' );
	RPM^.Mode := RPMNoCancel;
	RPMSortAlpha( RPM );
	ALphaKeyMenu( RPM );

	T := SelectMenu( RPM , @RandCharRedraw );
	DisposeRPGMenu( RPM );

	ApplyTalent( PC , T );
end;

Procedure SelectRandomTalent( PC: GearPtr );
	{ Select one of the generic talents for this PC. }
begin
	{ If the PC has high Martial Arts skill, assign either Kung Fu or Hap Ki Do. }
	if CanLearnTalent( PC , NAS_KungFu ) and ( Random( 3 ) <> 1 ) then begin
		ApplyTalent( PC , NAS_KungFu );
	end else if CanLearnTalent( PC , NAS_HapKiDo ) then begin
		ApplyTalent( PC , NAS_HapKiDo );
	end else if CanLearnTalent( PC , NAS_Ninjitsu ) and ( Random( 2 ) <> 1 ) then begin
		ApplyTalent( PC , NAS_Ninjitsu );
	end else if CanLearnTalent( PC , NAS_HardAsNails ) and ( Random( 2 ) <> 1 ) then begin
		ApplyTalent( PC , NAS_HardAsNails );
	end else if CanLearnTalent( PC , NAS_Camaraderie ) and ( Random( 2 ) <> 1 ) then begin
		ApplyTalent( PC , NAS_Camaraderie );
	end else if CanLearnTalent( PC , NAS_JackOfAll ) and ( Random( 2 ) <> 1 ) then begin
		ApplyTalent( PC , NAS_JackOfAll );
	end else if CanLearnTalent( PC , NAS_Sniper ) and ( Random( 2 ) <> 1 ) then begin
		ApplyTalent( PC , NAS_Sniper );
	end else if CanLearnTalent( PC , NAS_BusinessSense ) and ( Random( 2 ) <> 1 ) then begin
		ApplyTalent( PC , NAS_BusinessSense );
	end else if CanLearnTalent( PC , NAS_StuntDriving ) and ( Random( 3 ) <> 1 ) then begin
		ApplyTalent( PC , NAS_StuntDriving );
	end else if CanLearnTalent( PC , NAS_Bishounen ) and ( Random( 5 ) <> 1 ) then begin
		ApplyTalent( PC , NAS_Bishounen );

	{ At the very end, if no other talents can be learned, apply one of the two }
	{ generic talents which don't have any pre-requisites. }
	end else if ( Random( 5 ) = 1 ) and CanLearnTalent( PC , NAS_Polymath ) then begin
		ApplyTalent( PC , NAS_Polymath );
	end else begin
		ApplyTalent( PC , NAS_Idealist );
	end;
end;

Procedure SelectMecha( Egg,PC: GearPtr; CanEdit: Boolean );
	{ Select a mecha for the PC to start with. }
const
	BaseMechaAllowance = 250000;
	MaxMechaAllowance = 350000;
var
	Factions: String;
	MechaList,MList,Mek: GearPtr;
	Fac: GearPtr;
	MVP,cash,N: LongInt;
	RPM: RPGMenuPtr;
	SRec: SearchRec;
begin
	{ Determine what mechas the PC can use. }
	Factions := 'GENERAL ' + SATtValue( PC^.SA , 'HOMETOWN_GOVERNMENT' );
	Fac := SeekCurrentLevelGear( Factions_List , GG_Faction , NAttValue( PC^.NA , NAG_Personal , NAS_FactionID ) );
	if Fac <> Nil then factions := factions + ' ' + SAttValue( Fac^.SA , 'DESIG' );

	{ Determine the maximum value of a mecha to select. This is modified upwards }
	{ if the PC has a lot of money. }
	MVP := BaseMechaAllowance;
	cash := NAttValue( PC^.NA , NAG_Experience , NAS_Credits );
	if Cash > 10000 then MVP := BaseMechaAllowance + ( Cash div 2 ) - 5000;
	if MVP > MaxMechaAllowance then MVP := MaxMechaAllowance;


	{ Generate the mecha shopping list. }
	MechaList := Nil;

	{ Start the search process going... }
	FindFirst( Design_Directory + Default_Search_Pattern , AnyFile , SRec );

	{ As long as there are files which match our description, }
	{ process them. }
	While DosError = 0 do begin
		{ Load this mecha design file from disk. }
		MList := LoadFile( SRec.Name , Design_Directory );

		{ Search through it for mecha. }
		Mek := MList;
		while Mek <> Nil do begin
			if ( Mek^.G = GG_Mecha ) then begin
				if ( GearValue( Mek ) <= MVP ) and PartMatchesCriteria( SAttValue( Mek^.SA , 'TYPE' ) , All_Terrain_Designations ) and PartAtLeastOneMatch( SAttValue( Mek^.SA , 'FACTIONS' ) , Factions ) then begin
					AppendGear( MechaList , CloneGear( Mek ) );
				end;
			end;
			Mek := Mek^.Next;
		end;

		{ Dispose of the list. }
		DisposeGear( MList );

		{ Look for the next file in the directory. }
		FindNext( SRec );
	end;

	{ Select a mecha. }
	{ The exact method is gonna depend on whether or not the PC can edit. }
	if CanEdit then begin
		{ Allocate the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
		AttachMenuDesc( RPM , ZONE_CharGenPrompt );
		RCCaption := MsgString( 'RANDCHAR_MechaPrompt' );
		RCDescMessage := MsgString( 'RANDCHAR_MechaDesc' );
		RPM^.Mode := RPMNoCancel;

		{ Add the mecha to the menu. }
		Mek := MechaList;
		N := 1;
		while Mek <> Nil do begin
			AddRPGMenuItem( RPM , FullGearName( Mek ) , N , SAttValue( Mek^.SA , 'DESC' ) );
			Inc( N );
			Mek := Mek^.Next;
		end;

		{ Select one of them. }
		N := SelectMenu( RPM , @RandCharRedraw );
		DisposeRPGMenu( RPM );

		Mek := RetrieveGearSib( MechaList , N );
	end else begin
		Mek := SelectRandomGear( MechaList );
	end;


	{ Attach a copy of the selected mecha to the egg. }
	if Mek <> Nil then begin
		Mek := CloneGear( Mek );
		InsertSubCom( Egg , Mek );
		if GearValue( mek ) > BaseMechaAllowance then begin
			AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , BaseMechaAllowance - GearValue( Mek ) );
		end;
	end;

	{ Dispose of the shopping list. }
	DisposeGear( MechaList );
	RCCaption := '';
end;

Procedure SetTraits( PC: GearPtr );
	{ Set some personality traits for the PC. }
	Procedure DoTraitType( MasterList: GearPtr );
		{ Do the menu for this trait type. }
	var
		RPM: RPGMenuPtr;
		T: GearPtr;
		Base,Changes: String;
		N: Integer;
	begin
		{ Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
		RPM^.Mode := RPMNoCancel;

		{ Add the traits. }
		T := MasterList;
		N := 1;
		while T <> Nil do begin
			AddRPGMenuItem( RPM , GearName( T ) , N );
			T := T^.Next;
			Inc( N );
		end;
		RPMSortAlpha( RPM );

		{ Get a menu selection. }
		N := SelectMenu( RPM , @RandCharRedraw );
		DisposeRPGMenu( RPM );

		{ Locate the trait selected, and copy over its stuff. }
		T := RetrieveGearSib( MasterList , N );
		if T <> Nil then begin
			{ Copy over the personality traits from the biography event. }
			for N := 1 to Num_Personality_Traits do begin
				AddReputation( PC , N , NAttValue( T^.NA , NAG_CharDescription , -N ) );
			end;

			{ Copy the changes to the PC's context. }
			Base := SAttValue( PC^.SA , 'CONTEXT' );
			Changes := SAttValue( T^.SA , 'CONTEXT' );
			AlterDescriptors( Base , Changes );
			SetSAtt( PC^.SA , 'CONTEXT <' + Base + '>' );
		end;
	end;
begin
	RCDescMessage := MsgString( 'RANDCHAR_TraitDesc' );

	RCPromptMessage := MsgString( 'RANDCHAR_FocusPrompt' );
	DoTraitType( Focus_List );

	RCPromptMessage := MsgString( 'RANDCHAR_GoalPrompt' );
	DoTraitType( Goal_List );
end;

{$IFNDEF ASCII}
Procedure SelectColors( PC: GearPtr; CanEdit: Boolean );
	{ Select colors for this character. }
var
	sdl_colors: String;
begin
	RCDescMessage := '';
	RCPromptMessage := MsgString( 'RANDCHAR_SelectColorsPrompt' );

	if CanEdit then sdl_colors := SelectColorPalette( colormenu_mode_character, SAttValue( PC^.SA , 'SDL_PORTRAIT' ), SAttValue( PC^.SA , 'SDL_COLORS' ), 100, 150, @RandCharRedraw )
	else sdl_colors := RandomColorString( CS_Clothing ) + ' ' + RandomColorString( CS_Skin ) + ' ' + RandomColorString( CS_Hair );

	{ Record the colors. }
	SetSAtt( PC^.SA , 'SDL_Colors <' + sdl_colors + '>' );
end;

Procedure SelectSprite( PC: GearPtr );
	{ Select a sprite for the PC's portrait. }
var
	RPM: RPGMenuPtr;
	PList: SAttPtr;
	P,N: Integer;
begin
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_CharGenMenu );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_NextPicture' ) , 1 );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_LastPicture' ) , 2 );
	AddRPGMenuItem( RPM , MsgString( 'RANDCHAR_AcceptPicture' ) , -1 );

	if NAttValue( PC^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then begin
		PList := CreateFileList( Graphics_Directory + 'por_m_*.*' );
	end else begin
		PList := CreateFileList( Graphics_Directory + 'por_f_*.*' );
	end;

	RCDescMessage := '';
	RCPromptMessage := MsgString( 'RANDCHAR_PicturePrompt' );
	RCCaption := '';
	P := 1;

	repeat
		CleanSpriteList;

		SetSAtt( PC^.SA , 'SDL_PORTRAIT <' + RetrieveSAtt( PList , P )^.Info + '>' );
		N := SelectMenu( RPM , @RandCharRedraw );

		if N = 1 then begin
			Inc( P );
			if P > NumSatts( PList ) then P := 1;
		end else if N = 2 then begin
			Dec( P );
			if P < 1 then P := NumSatts( PList );
		end;
	until N = -1;
	DisposeSAtt( PList );
	DisposeRPGMenu( RPM );
end;
{$ENDIF}

Procedure ReputationCompensation( PC: GearPtr );
	{ If the PC starts the game as Wangtta, Villainous, or Criminal, better }
	{ give him some bonuses to make up for all the #@@!$! he's gonna get }
	{ once the campaign starts. }
var
	Trait,Pts: Integer;
begin
	Pts := 0;

	{ Start by checking heroism. }
	Trait := NAttValue( PC^.NA , NAG_CharDescription , NAS_Heroic );
	if Trait < -10 then begin
		Pts := Abs( Trait );
	end else if Trait < 0 then begin
		Pts := 5;
	end;

	{ Next, check law. }
	Trait := NAttValue( PC^.NA , NAG_CharDescription , NAS_Lawful );
	if Trait < -10 then begin
		Pts := Pts + 10;
	end else if Trait < 0 then begin
		Pts := Pts + 1;
	end;

	{ Finally, check renown. }
	Trait := NAttValue( PC^.NA , NAG_CharDescription , NAS_Renowned );
	if Trait < -10 then begin
		Pts := Pts + 7;
	end else if Trait < 0 then begin
		Pts := Pts + 5;
	end;

	while Pts > 0 do begin
		if Random( 2 ) = 1 then begin
			{ Experience award. }
			AddNAtt( PC^.NA , NAG_Experience, NAS_TotalXP , Random( 5 ) );
		end else begin
			{ Cash award. }
			AddNAtt( PC^.NA , NAG_Experience, NAS_Credits , Random( 200 ) );
		end;
		Dec( Pts );
	end;
end;

Function CharacterCreator( Fac: Integer ): GearPtr;
	{ This is my brand-spankin' new character generator. It is meant }
	{ to emulate the interactive way in which characters are generated }
	{ for such games as Mekton and Traveller. }
	{ The character may be limited to a certain faction, in which case }
	{ FAC will be non-zero. }
const
	MODE_Regular = 1;
	MODE_Easy = 0;
var
	Egg,PC: GearPtr;
	M: Integer;
	N,StatPt,SkillPt: LongInt;
	name: String;
begin
	RCPC := Nil;
	M := SelectMode;
	if M = -1 then Exit( Nil );

	{ Start by allocating the PC record. }
	Egg := NewGear( Nil );
	PC := NewGear( Nil );
	InsertSubCom( Egg , PC );
	PC^.G := GG_Character;
	InitGear( PC );
	StatPt := 90;
	SkillPt := 50;
	SetSAtt( PC^.SA , 'SDL_COLORS <49 91 161 252 212 195 150 112 89>' );

	{ First select gender, keeping in mind that the selection may be }
	{ cancelled. }
	N := SelectGender;
	if N = -1 then begin
		DisposeGear( PC );
		Exit( Nil );
	end else begin
		SetNAtt( PC^.NA , NAG_CharDescription , NAS_Gender , N );
	end;

	{ Next select age. }
	if M = MODE_Regular then begin
		N := SelectAge;
		SetNAtt( PC^.NA , NAG_CharDescription , NAS_DAge , N );
		CharacterDisplay( PC , Nil );
	end else begin
		N := Random( 10 ) - Random( 5 );
		SetNAtt( PC^.NA , NAG_CharDescription , NAS_DAge , N );
	end;

	{ Adjust cash & free skill points based on Age. }
	AddNAtt( PC^.NA , NAG_Experience , NAS_TotalXP , ( N + 5 ) * 25 );
	AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , 150000 - N * 5000 + Random( 1000 ) );
	RCPC := PC;

	{ Next, select home town. }
	if M = MODE_Regular then begin
		SelectHomeTown( PC , True , Fac );
	end else begin
		SelectHomeTown( PC , False , Fac );
	end;

	SelectJobAndFaction( PC , M = MODE_Regular , Fac );

	GenerateFamilyHistory( Egg , PC , M = MODE_Regular );

	{ Allocate stat points. }
	if M = MODE_Regular then begin
		AllocateStatPoints( PC , StatPt );
		CharacterDisplay( PC , Nil );
	end else begin
		EasyStatPoints( PC , StatPt );
	end;

	{ Allocate skill points. }
	if M = MODE_Regular then begin
		AllocateSkillPoints( PC , SkillPt );
		CharacterDisplay( PC , Nil );
	end else begin
		RandomSkillPoints( PC , SkillPt , False );
	end;

	{ Select a talent. }
	if M = MODE_Regular then begin
		SelectATalent( PC );
	end else begin
		SelectRandomTalent( PC );
	end;

	SelectMecha( Egg , PC , M = MODE_Regular );

	{ Set personality traits. }
	if M = MODE_Regular then begin
		SetTraits( PC );
		CharacterDisplay( PC , Nil );
	end;

	{ The background and so forth may have started the PC with a bad reputation. }
	{ If this has happened, give the PC some XP and cash to compensate. }
	ReputationCompensation( PC );

{$IFNDEF ASCII}
	{ In SDLMode, before selecting a name, finalize the portrait. }
	SelectSprite( PC );
	SelectColors( PC , M = MODE_Regular );
{$ENDIF}

	{ Select a name. }
	{ If no name is entered, this cancels character creation. }
	name := GetStringFromUser( MsgString( 'RANDCHAR_GetName' ) , @RandCharRedraw );

	if  Name <> '' then begin
		SetSAtt( PC^.SA , 'NAME <'+name+'>');
		if PC^.Next <> Nil then SetSAtt( PC^.Next^.SA , 'PILOT <' + name + '>' );
		CharacterDisplay( PC , Nil );

	end else begin
		DisposeGear( Egg );

	end;

	{ Clear the screen, and return the PC. }
	CharacterCreator := Egg;
end;

Function RandomNPC( Adv: GearPtr; Fac,Hometown: Integer ): GearPtr;
	{ Create a random character, using most of the same materials as available }
	{ for a regular character. }
var
	NPC,City: GearPtr;
begin
	NPC := NewGear( Nil );
	NPC^.G := GG_Character;
	InitGear( NPC );

	{ Set a random gender and age. }
	SetNAtt( NPC^.NA , NAG_CharDescription , NAS_Gender , Random( 2 ) );
	SetNAtt( NPC^.NA , NAG_CharDescription , NAS_DAge , Random( 10 ) - Random( 5 ) );

	{ If no home town was provided, select one randomly. }
	if HomeTown = 0 then begin
		SelectHomeTown( NPC , False , Fac );
	end else begin
		City := SeekGear( Adv , GG_Scene , HomeTown , False );
		if ( City <> Nil ) and ( City^.G = GG_Scene ) then begin
{			City := FindRootScene( City );}
			StoreHomeTownDataInPC( NPC , City );
		end else begin
			SelectHomeTown( NPC , False , Fac );
		end;
	end;

	{ Select a job and maybe even a faction. }
	SelectJobAndFaction( NPC , False , Fac );

	{ Allocate stats and skills. }
	EasyStatPoints( NPC , 100 );
	RandomSkillPoints( NPC , 50 , True );

	{ Set this NPC as a combatant. }
	SetNAtt( NPC^.NA , NAG_CharDescription , NAS_IsCombatant , 1 );

	{ Remove the character context, since it will get in the way later. }
	SetSAtt( NPC^.SA , 'CONTEXT <>' );

	{ Return the result. }
	RandomNPC := NPC;
end;

Procedure TrimTheAtlas();
	{ Remove everything from the atlas that isn't a hometown. }
var
	City,C2: GearPtr;
begin
	City := Hometown_List;
	while City <> Nil do begin
		C2 := City^.Next;
		if not( ( City^.G = GG_Scene ) and AStringHasBString( SAttValue( City^.SA , 'TYPE' ) , 'HOMETOWN' ) ) then begin
			{ This isn't a home town. Delete it. }
			RemoveGear( Hometown_List , City );
		end else begin
			{ This is a home town. Delete its children. }
			DisposeGear( City^.SubCom );
			DisposeGear( City^.InvCom );
		end;
		City := C2;
	end;
end;

initialization
	Jobs_List := AggregatePattern( 'CG_JOBS_*.txt' , Series_Directory );
	Family_List := LoadRandomSceneContent( 'CG_FAMILY_*.txt' , Series_Directory );
	Bio_List := LoadRandomSceneContent( 'CG_BIO_*.txt' , Series_Directory );
	Goal_List := AggregatePattern( 'CG_GOAL_*.txt' , Series_Directory );
	Focus_List := AggregatePattern( 'CG_FOCUS_*.txt' , Series_Directory );
	Hometown_List := AggregatePattern( 'ATLAS_*.txt' , Series_Directory );
	TrimTheAtlas();

finalization
	DisposeGear( Jobs_List );
	DisposeGear( Family_List );
	DisposeGear( Bio_List );
	DisposeGear( Goal_List );
	DisposeGear( Focus_List );
	DisposeGear( Hometown_List );

end.
