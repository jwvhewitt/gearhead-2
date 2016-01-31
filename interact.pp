unit interact;
	{ This unit contains the rules for using interaction skills, }
	{ such as Conversation, et cetera. }
	{ It also, by reason of necessity, contains some procedures }
	{ related to random plots. The main unit for plots is }
	{ playwright.pp; see that unit for more details. }
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

Const
	{ *** PERSONA GEAR *** }
	{ G = GG_Persona                              }
	{ S = Character ID or Plot Element Number     }
	{ V = na                                      }

	{ *** FACTION GEAR *** }
	{ G = GG_Faction                              }
	{ S = Faction ID                              }
	{ V = Undefined                               }


	{ This attribute records how well two characters like each other or }
	{ hate each other. The "S" identifier is the CID of the character }
	{ to which this reaction score applies. }
	NAG_ReactionScore = 6;

	{ This attribute records the relationship between two factions. }
	NAG_FactionScore = 8;

	{ This attribute records the relationship this NPC has with }
	{ another NPC in the game. }
	NAG_Relationship = 10;
	{ S descriptor is the CID of the other NPC. }
	{ ... or 0 for the PC. }
	NAV_ArchEnemy = -1;
	NAV_Friend = 1;
	NAV_ArchAlly = 2;	{ Is there such a thing as an arch-ally? }
				{ Who really knows. }
		{ If the relationship type is greater than or equal to NAV_ArchAlly, }
		{ the NPC can join the lance. }
	NAV_Family = 3;
	NAV_Lover = 4;

	ArchEnemyReactionPenalty = 25;

	Same_Faction_Bonus = 10;
	MaxFactionScore = 25;
	MinFactionScore = -50;

var
	{ Strings for the random conversation generator. }
	Noun_List,Phrase_List,Adjective_List,RLI_List,Chat_Msg_List,Threat_List: SAttPtr;


function MadLibString( SList: SAttPtr ): String;

Function PersonalityCompatability( PC, NPC: GearPtr ): Integer;
Function ReactionScore( Scene, PC, NPC: GearPtr ): Integer;

Function IdleChatter: String;
Function IsSexy( PC, NPC: GearPtr ): Boolean;

Function IsArchEnemy( Adv,NPC: GearPtr ): Boolean;
Function IsArchAlly( Adv,NPC: GearPtr ): Boolean;

Function IsRegularLancemate( NPC: GearPtr ): Boolean;
Function LancematesPresent( GB: GameBoardPtr ): Integer;
Function PetsPresent( GB: GameBoardPtr ): Integer;

Function FindLocalNPCByKeyWord( GB: GameBoardPtr; KW: String ): GearPtr;
Function CanContactByPhone( GB: GameBoardPtr; NPC: GearPtr ): Boolean;

Procedure AddReact( GB: GameBoardPtr; PC,NPC: GearPtr; DReact: Integer );


implementation

uses narration,texutil,rpgdice,ghchars,gearutil,ability,ui4gh,ghprop,action;

const
	Num_Openings = 7;	{ Number of TraitChatter opening phrases. }

	Chat_MOS_Measure = 5;

var
	Trait_Chatter: Array [1..Num_Personality_Traits,1..2] of SAttPtr;


Function GeneralCompatability( PC1, PC2: GearPtr ): Integer;
	{ This function will determine the general level of }
	{ compatability between two characters. This is the }
	{ modifier which will be applied to most interaction }
	{ rolls. }
	{ It is determined by several things - }
	{  - Similarity of stats and skills }
var
	T,S1,S2: Integer;
	BCS: Integer;	{ Base compatability score }
begin
	{ Error Check - Make sure both PCs are valid gears. }
	if ( PC1 = Nil ) or ( PC2 = Nil ) then begin
		GeneralCompatability := 0;

	{ Error Check - Make sure both PCs are characters. }
	end else if ( PC1^.G <> GG_Character ) or ( PC2^.G <> GG_Character ) then begin
		GeneralCompatability := 0;

	end else begin
		{ Initialize the compatability score to 0. }
		BCS := 0;

		{ Check the stats. Every stat that is wildly different will }
		{ cause a drop in compatability, while every stat which is }
		{ very similar will cause a rise in compatability. }
		for t := 1 to 8 do begin
			if Abs( PC1^.Stat[t] - PC2^.Stat[t] ) > 8 then begin
				Dec( BCS );
			end else if ( PC1^.Stat[t] - PC2^.Stat[t] ) < 3 then begin
				Inc( BCS );
			end;
		end;

		{ Check the skills. Every skill that both PCs have will }
		{ cause a rise in compatability. }
		for t := 1 to NumSkill do begin
			S1 := NAttValue( PC1^.NA , NAG_Skill , T );
			S2 := NAttValue( PC2^.NA , NAG_Skill , T );

			if ( S1 > 10 ) and ( S2 > 10 ) then begin
				BCS := BCS + 3;
			end else if ( S1 > 5 ) and ( S2 > 5 ) then begin
				BCS := BCS + 2;
			end else if ( S1 > 0 ) and ( S2 > 0 ) then begin
				BCS := BCS + 1;
			end;
		end;

		GeneralCompatability := BCS;
	end;
end;

Function PersonalityCompatability( PC, NPC: GearPtr ): Integer;
	{ Calculate the compatability between PC and NPC based on their }
	{ personality traits. }
var
	T,CS: Integer;
	NPC_Score,PC_Score: Integer;
begin
	{ Initialize the Compatability Score to 0. }
	CS := 0;

	{ Loop through all the personality traits. }
	for t := 1 to Num_Personality_Traits do begin
		{ Determine the scores of both PC and NPC with regard to this }
		{ personality trait. }
		PC_Score := NAttValue( PC^.NA , NAG_CharDescription , -T );
		NPC_Score := NAttValue( NPC^.NA , NAG_CharDescription , -T );

		{ If the personality trait being discussed here is Villainousness, }
		{ this always causes a negative reaction. Otherwise, a reaction }
		{ will only happen if both the PC and the NPC have points in }
		{ this trait. }
		if ( T = Abs( NAS_Heroic ) ) and (PC_Score < -10 ) then begin
			CS := CS - Abs( PC_Score ) div 2;

		end else if ( T = Abs( NAS_Renowned ) ) then begin
			{ Being renowned is always good, while being wangtta is }
			{ always bad. }
			if PC_Score > 0 then begin
				CS := CS + ( PC_Score div 10 );
			end else begin
				CS := CS - ( Abs( PC_Score ) div 10 );
			end;

		end else if ( PC_Score <> 0 ) and ( NPC_Score <> 0 ) then begin
			if Sgn( PC_Score ) = Sgn( NPC_Score ) then begin
				{ The traits are in agreement. Increase CS. }
				CS := CS + Abs( PC_Score ) div 10;

			end else if ( Abs( PC_Score ) > 10 ) and ( Abs( NPC_Score ) > 10 ) then begin
				{ The traits are in opposition. Decrease CS. }
				CS := CS - 5;

			end;
		end;
	end;

	PersonalityCompatability := CS;
end;

Function FactionScore( Scene: GearPtr; F0,F1: Integer ): Integer;
	{ Given two factions, return the amount by which they are }
	{ allied to each other or hate each other. }
var
	Fac_0: GearPtr;
	it: Integer;
begin
	if ( F0 = 0 ) or ( F1 = 0 ) then begin
		it := 0;

	end else if F0 = F1 then begin
		it := Same_Faction_Bonus;

	end else begin
		Fac_0 := SeekFaction( Scene , F0 );
		if Fac_0 <> Nil then begin
			it := NAttValue( Fac_0^.NA , NAG_FactionScore , F1 );
		end else begin
			it := 0;
		end;

	end;
	FactionScore := it;
end;

Function FactionCompatability( Scene, PC, NPC: GearPtr ): Integer;
	{ Determine the faction compatability scores between PC and NPC. }
	{ + the PC's reputation with the NPC's faction. }
	{ - if PC is enemy of allied faction. }
	{ - if PC is ally of enemy faction. }
var
	NPC_FID,PC_FID,it: Integer;
begin
	{ Step one - Locate the FACTION information of the NPC, and }
	{ the PC's FACTION ID.. }
	NPC_FID := NAttValue( NPC^.NA , NAG_Personal , NAS_FactionID );
	PC_FID := NAttValue( PC^.NA , NAG_Personal , NAS_FactionID );

	it := FactionScore( Scene , NPC_FID , PC_FID );

	if it > MaxFactionScore then it := MaxFactionScore
	else if it < MinFactionScore then it := MinFactionScore;

	FactionCompatability := it;
end;

Function ReactionScore( Scene, PC, NPC: GearPtr ): Integer;
	{ Return a score in the range of -100..+100 which tells how much }
	{ the NPC likes the PC. }
var
	it,Persona: Integer;
	Charm: Integer;
begin
	{ The basic Reaction Score is equal to GENERAL COMPATABILITY + the }
	{ existing reaction modifier. }
	Persona := NAttValue( NPC^.NA , NAG_Personal , NAS_CID );
	PC := LocatePilot( PC );
	it := GeneralCompatability( PC , NPC ) + PersonalityCompatability( PC , NPC ) + NAttValue( PC^.NA , NAG_ReactionScore , Persona );

	{ If the scene is defined, add the faction compatability score. }
	if Scene <> Nil then it := it + FactionCompatability( Scene , PC , NPC );

	{ Add a bonus based on the PC's charm. }
	Charm := CStat( PC , STAT_Charm );
	if Charm > 10 then begin
		it := it + Charm * 2 - 25;
	end else begin
		it := it + Charm * 3 - 35;
	end;

	{ A nemesis will never have a greater reaction score than 0. }
	if NAttValue( NPC^.NA , NAG_Relationship , NAttValue( PC^.NA , NAG_Personal , NAS_CID ) ) = NAV_ArchEnemy then begin
		it := it - ArchEnemyReactionPenalty;
		if it > 0 then it := 0;
	end else if NAttValue( NPC^.NA , NAG_Relationship , NAttValue( PC^.NA , NAG_Personal , NAS_CID ) ) > 0 then begin
		{ An ally/other relationship will be slightly friendlier to the PC. }
		it := it + 5;
	end;

	{ Make sure IT doesn't go out of bounds. }
	if it > 100 then it := 100
	else if it < -100 then it := -100;

	ReactionScore := it;
end;

Function BlowOff: String;
	{ The NPC will just say something mostly useless to the PC. }
begin
	{ At some point in time I will make a lovely procedure that will }
	{ create all sorts of useless chatter. Right now, I'll just return }
	{ the following constant string. }
	BlowOff := MsgString( 'BlowOff' );
end;

function MadLibString( SList: SAttPtr ): String;
	{ Given a list of string attributes, return one of them at random. }
var
	SA: SAttPtr;
begin
	SA := SelectRandomSAtt( SList );
	if SA <> Nil then MadLibString := SA^.Info
	else MadLibString := '***ERROR***';
end;

Function FormatChatString( Msg1: String ): String;
	{ Do formatting on this string, adding nouns, adjectives, }
	{ and threats as needed. }
var
	msg2,w: String;
begin
	msg2 := '';

	while msg1 <> '' do begin
		w := ExtractWord( msg1 );

		if W[1] = '%' then begin
			DeleteFirstChar( W );
			if UpCase( W[1] ) = 'N' then begin
				DeleteFirstChar( W );
				W := MadLibString( Noun_List ) + W;
			end else if UpCase( W[1] ) = 'T' then begin
				DeleteFirstChar( W );
				W := MadLibString( Threat_List ) + W;
			end else begin
				DeleteFirstChar( W );
				W := MadLibString( Adjective_List ) + W;
			end;
		end;

		msg2 := msg2 + ' ' + w;
	end;

	DeleteWhiteSpace( Msg2 );
	FormatChatString := Msg2;
end;

Function IdleChatter: String;
	{ Create a Mad-Libs style line for the NPC to tell the PC. }
	{ Hopefully, these mad-libs will simulate the cheerfully nonsensical }
	{ things that poorly tanslated anime characters often say to }
	{ each other. }
	{ After testing this procedure, the effect is more akin to the }
	{ konglish slogans which adorn stationary & other character goods... }
	{ Close enough! I've got a winner here... }
var
	msg1: String;
begin
	{ Start with a MadLib form in msg1, and nothing in Msg2. }
	{ Transfer the message from M1 to M2 one word at a time, replacing }
	{ nouns and adjectives along the way. }
	msg1 := MadLibString( Phrase_List );
	msg1 := FormatChatString( Msg1 );
	AtoAn( msg1 );

	IdleChatter := msg1;
end;

Function DoTraitChatter( NPC: GearPtr; Trait: Integer ): String;
	{ The NPC needs to say a line which should give some indication }
	{ as to his/her orientation with respect to the listed }
	{ personality trait. }
const
	Num_Phrase_Bases = 3;
var
	Rk,Pro: Integer;
	msg: String;
begin
	{ To start with, find the trait rank. }
	Rk := NAttValue( NPC^.NA , NAG_CharDescription , -Trait );

	{ Insert a basic starting phrase in the message, or perhaps none }
	{ at all... }
	if Random( 10 ) <> 1 then begin
		msg := SAttValue( Chat_Msg_List , 'TRAITCHAT_Lead' + BStr( Random( Num_Openings ) + 1 ) ) + ' ';
	end else begin
		msg := '';
	end;

	if Abs( Rk ) > 10 then begin
		{ Determine which side of the trait the NPC is in favor of. }
		if Rk > 0 then Pro := 1
		else Pro := 2;

		{ The NPC will either say that they like something from their own side, }
		{ or that they dislike something from the other. }
		if Random( 5 ) <> 1 then begin
			{ Like something. }
			msg := msg + SAttValue( Chat_Msg_List , 'TRAITCHAT_Like' + BStr( Random( Num_Phrase_Bases ) + 1 ) ) + ' ' + MadLibString( Trait_Chatter[ Trait , Pro ] ) + '.';

		end else begin
			{ Dislike something. }
			msg := msg + SAttValue( Chat_Msg_List , 'TRAITCHAT_Hate' + BStr( Random( Num_Phrase_Bases ) + 1 ) ) + ' ' + MadLibString( Trait_Chatter[ Trait , 3 - Pro ] ) + '.';

		end;
	end else begin
		Pro := Random( 2 ) + 1;
		msg := msg + SAttValue( Chat_Msg_List , 'TRAITCHAT_Ehhh' + BStr( Random( Num_Phrase_Bases ) + 1 ) ) + ' ' + MadLibString( Trait_Chatter[ Trait , Pro ] ) + '.';

	end;

	DoTraitChatter := Msg;
end;

function InOpposition( PC , NPC: GearPtr; Trait: Integer ): Boolean;
	{ If the PC and the NPC disagree on this personality TRAIT, }
	{ return TRUE. Otherwise return FALSE. }
var
	T1,T2: Integer;
begin
	T1 := NAttValue( PC^.NA , NAG_CharDescription , -Trait );
	T2 := NAttValue( NPC^.NA , NAG_CharDescription , -Trait );

	if ( Abs( T1 ) > 10 ) and ( Abs( T2 ) > 10 ) then begin
		{ The characters are in opposition if their trait }
		{ values are on opposite sides of 0. }
		InOpposition := Sgn( T1 ) <> Sgn( T2 );
	end else begin
		{ If the traits aren't strongly held by both, then }
		{ no real opposition. }
		InOpposition := False;
	end;
end;

function InHarmony( PC , NPC: GearPtr; Trait: Integer ): Boolean;
	{ If the PC and the NPC agree on this personality TRAIT, }
	{ return TRUE. Otherwise return FALSE. }
var
	T1,T2: Integer;
begin
	T1 := NAttValue( PC^.NA , NAG_CharDescription , -Trait );
	T2 := NAttValue( NPC^.NA , NAG_CharDescription , -Trait );

	if ( Abs( T1 ) > 10 ) and ( Abs( T2 ) > 10 ) then begin
		{ The characters are in opposition if their trait }
		{ values are on opposite sides of 0. }
		InHarmony := Sgn( T1 ) = Sgn( T2 );
	end else begin
		{ If the traits aren't strongly held by both, then }
		{ no real opposition. }
		InHarmony := False;
	end;
end;

Function IsSexy( PC, NPC: GearPtr ): Boolean;
	{ Return TRUE if there are some potential sparks between }
	{ the PC and NPC, or FALSE if there aren't. In this simple }
	{ universe we'll describe that as being if their genders }
	{ aren't equal to each other. }
begin
	IsSexy := ( NAttValue( PC^.NA , NAG_CharDescription , NAS_Gender ) <> NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) ) or HasTalent( PC , NAS_Bishounen );
end;

Procedure LoadTraitChatter;
	{ Load the trait chatter elements from disk. }
var
	t: integer;
begin
	for t := 1 to Num_Personality_Traits do begin
		Trait_Chatter[ T , 1 ] := LoadStringList( Trait_Chatter_Base + BStr( T ) + '_1.txt' );
		Trait_Chatter[ T , 2 ] := LoadStringList( Trait_Chatter_Base + BStr( T ) + '_2.txt' );
	end;
end;

Procedure FreeTraitChatter;
	{ Remove the trait chatter elements from memory. }
var
	t: integer;
begin
	for t := 1 to Num_Personality_Traits do begin
		DisposeSAtt( Trait_Chatter[ T , 1 ] );
		DisposeSAtt( Trait_Chatter[ T , 2 ] );
	end;
end;

Function IsArchEnemy( Adv,NPC: GearPtr ): Boolean;
	{ Return TRUE if the NPC is an arch-enemy of the PC, or }
	{ FALSE otherwise. }
	{ The NPC will be an arch-enemy if it has that particular }
	{ relationship set, or if the NPC and the PC belong to }
	{ warring factions, or if the PC is an enemy of the NPC's factions's controller. }
var
	it: Boolean;
	PCF,NPCF: Integer;
	Faction: GearPtr;
begin
	it := NATtValue( NPC^.NA , NAG_Relationship , 0 ) = NAV_ArchEnemy;

	{ If this character is not an intrinsic enemy of the PC, maybe }
	{ it will be an enemy because of faction relations. }
	if ( Adv <> Nil ) and not it then begin
		NPCF := GetFactionID( NPC );
		Faction := SeekFaction( Adv , NPCF );
		PCF := NAttValue( FindRoot( Adv )^.NA , NAG_Personal , NAS_FactionID );
		if Faction <> Nil then begin
			it := ( FactionScore( Adv , NPCF , PCF ) < 0 ) or ( NAttValue( Faction^.NA , NAG_Relationship , 0 ) = NAV_ArchEnemy );

			{ If the PC isn't an enemy of the NPC's faction, see if he's an enemy }
			{ of the controlling faction. }
			if not it then begin
				NPCF := NAttValue( Faction^.NA , NAG_Narrative , NAS_ControllingFaction );
				Faction := SeekFaction( Adv , NPCF );
				if Faction <> Nil then it := ( FactionScore( Adv , NPCF , PCF ) < 0 ) or ( NAttValue( Faction^.NA , NAG_Relationship , 0 ) = NAV_ArchEnemy );
			end;
		end;
	end;

	IsArchEnemy := it;
end;

Function IsArchAlly( Adv,NPC: GearPtr ): Boolean;
	{ Return TRUE if the NPC is an arch-ally of the PC, or }
	{ FALSE otherwise. }
	{ The NPC will be an arch-ally if it has that particular }
	{ relationship set, or if the NPC and the PC belong to }
	{ the same faction. }
var
	it: Boolean;
	PCF,NPCF: Integer;
	Faction: GearPtr;
begin
	it := NATtValue( NPC^.NA , NAG_Relationship , 0 ) >= NAV_ArchAlly;

	{ If this character is not an intrinsic ally of the PC, maybe }
	{ it will be an ally because of faction relations. }
	if ( Adv <> Nil ) and not it then begin
		NPCF := GetFactionID( NPC );
		Faction := SeekFaction( Adv , NPCF );
		PCF := NAttValue( FindRoot( Adv )^.NA , NAG_Personal , NAS_FactionID );

		if Faction <> Nil then begin
			it := ( FactionScore( Adv , NPCF , PCF ) > 0 ) or ( NAttValue( Faction^.NA , NAG_Relationship , 0 ) = NAV_ArchAlly );

			{ If the PC isn't an ally of the NPC's faction, see if he's an ally }
			{ of the controlling faction. }
			if not it then begin
				NPCF := NAttValue( Faction^.NA , NAG_Narrative , NAS_ControllingFaction );
				Faction := SeekFaction( Adv , NPCF );
				if Faction <> Nil then it := ( FactionScore( Adv , NPCF , PCF ) > 0 ) or ( NAttValue( Faction^.NA , NAG_Relationship , 0 ) = NAV_ArchAlly );
			end;
		end;

	end;

	IsArchAlly := it;
end;


Function IsRegularLancemate( NPC: GearPtr ): Boolean;
	{ NPC is a lancemate. Return TRUE if NPC is not a pet and not a temp. }
begin
	NPC := LocatePilot( NPC );
	IsRegularLancemate := ( NPC <> Nil ) and ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) <> 0 ) and ( NAttValue( NPC^.NA , NAG_CharDescription , NAS_CharType ) <> NAV_TempLancemate );
end;

Function LancematesPresent( GB: GameBoardPtr ): Integer;
	{ Return the number of free lancemates present. A free lancemate is one who: }
	{ - is human (no pets) }
	{ - isn't a temp lancemate }
var
	M: GearPtr;
	N: Integer;
begin
	M := GB^.Meks;
	N := 0;
	while M <> Nil do begin
		if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and GearActive( M ) then begin
			if IsRegularLancemate( M ) then begin
				Inc( N );
			end;
		end;
		M := M^.Next;
	end;
	LancematesPresent := N;
end;

Function PetsPresent( GB: GameBoardPtr ): Integer;
	{ Count the number of pets on the lancemate team. If COUNTROBOTS is true, }
	{ only count those pets made out of metal. Otherwise, only count those pets }
	{ not made out of metal. }
var
	M: GearPtr;
	N: Integer;
begin
	M := GB^.Meks;
	N := 0;
	while M <> Nil do begin
		if ( NAttValue( M^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam ) and ( M^.G = GG_Character ) and ( NAttValue( M^.NA , NAG_Personal , NAS_CID ) = 0 ) then begin
			Inc( N );
		end;
		M := M^.Next;
	end;
	PetsPresent := N;
end;

Function FindLocalNPCByKeyWord( GB: GameBoardPtr; KW: String ): GearPtr;
	{ Attempt to locate a NPC by keyword. The keyword may be the job of the NPC, or }
	{ it may be a phrase listed in the NPC's Persona's KEYWORDS string attribute. }
	{ The NPC must be local to the PC: That is, it must be either located on the }
	{ game board or within the root scene. }
	Function NPCMatchesKW( NPC: GearPtr ): Boolean;
	var
		desc: String;
		Persona: GearPtr;
	begin
		desc := SAttValue( NPC^.SA , 'JOB' );
		Persona := SeekPersona( GB , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) );
		if Persona <> Nil then desc := desc + SAttValue( Persona^.SA , 'KEYWORDS' );
		NPCMatchesKW := AStringHasBString( desc , KW );
	end;
	Function NumNPCsAlongPath( M: GearPtr ): Integer;
		{ Find out how many NPCs match the given keyword checking along }
		{ this path, including subcoms and invcoms. }
	var
		N: Integer;
	begin
		N := 0;
		while M <> Nil do begin
			if M^.G = GG_Character then begin
				if NPCMatchesKW( M ) then Inc( N );
			end;
			N := N + NumNPCsAlongPath( M^.SubCom );
			N := N + NumNPCsAlongPath( M^.InvCom );
			M := M^.Next;
		end;
		NumNPCsAlongPath := N;
	end;
	Function FindNPCAlongPath( M: GearPtr; var N: Integer ): GearPtr;
		{ Find the Nth NPC searching along this path and through its children. }
	var
		NPC: GearPtr;
	begin
		NPC := Nil;
		while ( M <> Nil ) and ( NPC = Nil ) do begin
			if ( M^.G = GG_Character ) and NPCMatchesKW( M ) then begin
				Dec( N );
				if N = -1 then begin
					NPC := M;
				end;
			end;
			if NPC = Nil then NPC := FindNPCAlongPath( M^.SubCom , N );
			if NPC = Nil then NPC := FindNPCAlongPath( M^.InvCom , N );
			M := M^.Next;
		end;
		FindNPCAlongPath := NPC;
	end;
var
	N: Integer;
	RootScene,M: GearPtr;
begin
	{ Pass one: Locate all NPCs who match the keyword provided. }
	{ Search order: GB, Root Scene SubComs }
	N := NumNPCsAlongPath( GB^.Meks );
	M := Nil;
	RootScene := FindRootScene( GB^.Scene );
	if RootScene <> Nil then begin
		N := N + NumNPCsAlongPath( RootScene^.SubCom );
		N := N + NumNPCsAlongPath( RootScene^.InvCom );
	end;

	{ Pass two: Pick one at random, and select it. }
	if N > 0 then begin
		N := Random( N );
		M := FindNPCAlongPath( GB^.Meks , N );
		if ( M = Nil ) and ( RootScene <> Nil ) then begin
			M := FindNPCAlongPath( RootScene^.SubCom , N );
			if M = Nil then M := FindNPCAlongPath( RootScene^.InvCom , N );
		end;
	end;

	{ Return the NPC found. }
	FindLocalNPCByKeyWord := M;
end;

Function CanContactByPhone( GB: GameBoardPtr; NPC: GearPtr ): Boolean;
	{ Return TRUE if NPC can be contacted by phone, or FALSE otherwise. }
	{ PRECONDITIONS: NPC is in the current city, and is a valid NPC with a CID. }
var
	Persona: GearPtr;
	it: Boolean;
begin
	{ If passed a null pointer, no conversation possible. }
	if NPC = Nil then Exit( False );

	{ Locate the persona. }
	Persona := SeekPersona( GB , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) );
	if Persona <> Nil then begin
		{ If the Persona's SPECIAL attribute holds an UNLISTED tag, }
		{ this conversation cannot proceed by phone. }
		CanContactByPhone := not AStringHasBString( SAttValue( Persona^.SA , 'SPECIAL' ) , 'UNLISTED' );
	end else begin
		CanContactByPhone := True;
	end;
end;

Procedure AddReact( GB: GameBoardPtr; PC,NPC: GearPtr; DReact: Integer );
	{ Adjust the reaction score between the PC and this NPC, causing any other }
	{ status changes as needed. }
begin
	if ( PC <> Nil ) and ( NPC <> Nil ) and ( GB <> Nil ) then begin
		{ We have a PC and an NPC. Do the math. }
		AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) , DReact );

		{ If this brings the reaction over 50, and the change was positive, and }
		{ the NPC doesn't currently have a relationship to the PC, maybe become friends. }
		if ( DReact > 0 ) and ( NAttValue( NPC^.NA , NAG_Relationship , 0 ) = 0 ) and ( ReactionScore( GB^.Scene , PC , NPC ) > ( 50 + Random( 10 ) ) ) then begin
			SetNAtt( NPC^.NA , NAG_Relationship , 0 , NAV_Friend );
			DoleExperience( PC , 50 );
		end;
	end;
end;

initialization

	Noun_List := LoadStringList( Standard_Nouns_File );
	Phrase_List := LoadStringList( Standard_Phrases_File );
	Adjective_List := LoadStringList( Standard_Adjectives_File );
	RLI_List := LoadStringList( Standard_Rumors_File );
	Threat_List := LoadStringList( Standard_Threats_File );
	Chat_Msg_List := LoadStringList( Standard_Chatter_File );
	LoadTraitChatter;

finalization
	DisposeSAtt( Noun_List );
	DisposeSAtt( Phrase_List );
	DisposeSAtt( Adjective_List );
	DisposeSAtt( RLI_List );
	DisposeSAtt( Threat_List );
	DisposeSAtt( Chat_Msg_List );
	FreeTraitChatter;
end.
