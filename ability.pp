unit ability;
	{ This unit handles character and mecha abilities. }
	{ Mostly, it's used for obtaining and rolling skill }
	{ totals and stuff. }

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

uses ui4gh,rpgdice,texutil,gears,gearutil,movement,ghintrinsic;

const
	XPA_AttackHit = 2;
	XPA_PerMOS = 3;
	XPA_DestroyMaster = 75;
	XPA_DestroyThing = 1;
	XPA_AvoidAttack = 3;
	XPA_GoodRepairJob = 4;
	XPA_GoodChat = 1;
	XPA_SK_Critical = 2;
	XPA_SK_Basic = 1;	{ XP for just using a combat skill. }
	XPA_SK_UseRepair = 3;

	{ PERSONAL COMMUNICATION CAPABILITIES }
	PCC_Memo = NAS_Memo;	{ Can view adventure memos }
	PCC_EMail = NAS_EMail;	{ Can receive emails from NPCs }
	PCC_Phone = NAS_Phone;	{ Can send phone calls in local area }
	PCC_News = NAS_News;	{ Can view internet global news }


	NAG_EpisodeData = -4;

	NAS_UID = 0;
	NAS_Target = 1;
	NAS_ATarget = 3;	{ Absolute Target }

	NAS_PrevDamage = 4;	{ Previous damage rating. }
	NAS_InitRecharge = 6;	{ Initiative Recharge for NPCs }

	{ Orders are filed under NAG_EpisodeData }
	NAS_Orders = 2;

	NumAITypes = 5;
	NAV_SeekAndDestroy = 0;
	NAV_GotoSpot = 1;
	NAV_SeekEdge = 2;
	NAV_Passive = 3;
	NAV_RunAway = 4;
	NAV_Follow = 5;

	NAS_ContinuousOrders = 7;	{ reminder variable for the aibrain unit, }
				{ so it can remember what a particular model is doing. }
	NAS_ChatterRecharge = 8;	{ Chatter Recharge for NPCs }

	{ These refer to things that have happened to corpses/wreckage }
	NAS_Ransacked = 11;
	NAS_Gutted = 9;
	NAS_Flayed = 10;

	NAS_Temporary = 13;	{ If nonzero, this item should be deleted by DelinkJjang. }

	NAS_SurrenderStatus = 14;	{ This counter tells whether or not an NPC has surrendered. }
		NAV_NowSurrendered = 1;	{ NPC is currently surrendered. }
		NAV_ReAttack = 2;	{ NPC surrendered once, but now will attack again. }

	NAS_TauntResistance = 15;	{ After being taunted too much, one begins to build up }
					{ a resistance to it. See the VerbalAttack procedure }
					{ for more information. }


	NAS_EncounterVisibility = 16;	{ Timer for encounter visibility. }

	NAS_WeaponUpgrades = 17;	{ Number of times this weapon has been upgraded. }
					{ Used by the mecha customizer. }

	NAS_SpecialActionRecharge = 18;	{ NPCs will only use special systems once a minute or so. }

	AI_Type_Label: Array [0..NumAITypes] of String = (
		'SD','GO','EDGE','PASS','RUN','FOL'
	);


var
	Skill_Roll_History: SAttPtr;


Function LocatePilot( Mecha: GearPtr ): GearPtr;
Function GearOperational( Mek: GearPtr ): Boolean;
Function GearActive( Mek: GearPtr ): Boolean;
function SkillValue( Master: GearPtr; Skill,Stat: Integer ): Integer;
function ReactionTime( Master: GearPtr ): Integer;
function PilotName( Part: GearPtr ): String;

Function MonsterThreatLevel( M: GearPtr ): Integer;

Procedure DoleExperience( Mek: GearPtr; XPV: LongInt );
Procedure DoleExperience( Mek,Target: GearPtr; XPV: LongInt );
Function DoleSkillExperience( Mek: GearPtr; Skill,XPV: LongInt ): Boolean;

procedure ExpandCharacter( PC: GearPtr );

Function MappingRange( Mek: GearPtr; Scale: Integer ): Integer;
Procedure AddMoraleDMG( PC: GearPtr; M: Integer );
Procedure AddReputation( PC: GearPtr; R,V: Integer );
Procedure AddStaminaDown( PC: GearPtr; Strain: Integer );
Procedure AddMentalDown( PC: GearPtr; Strain: Integer );

Function CurrentMental( PC: GearPtr ): Integer;
Function CurrentStamina( PC: GearPtr ): Integer;

Function HasPCommCapability( PC: GearPtr; C: Integer ): Boolean;
Function HasTalent( PC: GearPtr; T: Integer ): Boolean;
Function HasIntrinsic( PC: GearPtr; I: Integer; CasualUse: Boolean ): Boolean;

Function IsEnviroSealed( PC: GearPtr ): Boolean;
Function PartyPetSlots( PC: GearPtr ): Integer;

Function SkillRank( PC: GearPtr; Skill: Integer ): Integer;
Function HasSkill( PC: GearPtr; Skill: Integer ): Boolean;

Procedure SkillComment( const Msg: String );
Procedure SkillCommentDivider;

Function Calculate_Threat_Points( Level,Percent: Integer ): LongInt;


implementation

uses ghchars,ghmodule,ghholder,ghsensor,ghmecha;

Function LocatePilot( Mecha: GearPtr ): GearPtr;
	{ Locate the pilot of this mecha. If no pilot may be found, }
	{ return Nil. }
var
	CPit, Pilot: GearPtr;	{ Pointers to the Cockpit and Pilot }
begin
	{ Error Check - make sure we have a valid mecha here. }
	if ( Mecha = Nil ) then Exit( Nil );
	if not IsMasterGear( Mecha ) then Mecha := FindMaster( Mecha );

	if Mecha = Nil then begin
		Pilot := Nil;

	end else if Mecha^.G = GG_Character then begin
		{ Just return this character, since we can't find a mecha. }
		Pilot := Mecha;

	end else begin
		{ This is probably a mecha. }
		{ Locate the cockpit. If no cockpit may be found, return Nil. }
		CPit := SeekGear( Mecha , GG_Cockpit , 0 , False );
		if CPit = Nil then Exit( Nil );

		{ Locate the pilot. }
		Pilot := CPit^.SubCom;
		while ( Pilot <> Nil ) and ( Pilot^.G <> GG_Character ) do begin
			Pilot := Pilot^.Next;
		end;
	end;

	LocatePilot := Pilot;
end;

Function GearOperational( Mek: GearPtr ): Boolean;
	{ A gear is operational if it is capable of action. }
	{ Mecha need a pilot in order to be operational. }
	{ Other gears are operational if they aren't destroyed. }
var
	MO: Boolean;	{ This func used to be called MekOperational, so MO }
begin
	{ Error Check }
	if ( Mek = Nil ) then begin
		MO := False
	end else if Mek^.G = GG_Mecha then begin
		MO := NotDestroyed( Mek ) and NotDestroyed( LocatePilot( Mek ) );
	end else MO := NotDestroyed( Mek );

	GearOperational := MO;
end;

Function GearActive( Mek: GearPtr ): Boolean;
	{ ACTIVE means that a given gear is capable of self-controlled action. }
	{ Generally only master gears may be active. }
begin
	if Mek = Nil then GearActive := False
	else if Mek^.G = GG_Character then GearActive := GearOperational( Mek ) and ( NAttValue( Mek^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) <> NAV_NowSurrendered )
	else if IsMasterGear( Mek ) then GearActive := GearOperational( Mek )
	else GearActive := False;
end;

Function SkillRank( PC: GearPtr; Skill: Integer ): Integer;
	{ Return the PC's rank in this skill. }
begin
	{ Make sure we're dealing with the real PC here. }
	PC := LocatePilot( PC );
	SkillRank := CharaSkillRank( PC , Skill );
end;

function SkillValue( Master: GearPtr; Skill,Stat: Integer ): Integer;
	{ Find MASTER's skill roll value. This is the }
	{ skill rank + the attribute value + any modifiers }
	{ that might apply (maneuver class, etc). }
	function UnitSkillValue( M: GearPtr ): Integer;
		{ Return the skill value of this unit. }
		{ M points to the list of unit models. }
	var
		MSkill,BigSkill,TSkill: Integer;
	begin
		{ Check through every mek on the board. }
		BigSkill := 0;
		TSkill := 0;
		while m <> Nil do begin
			if M^.G = GG_Character then begin
				MSkill := SkillValue( M , Skill , Stat );
				if MSkill > BigSkill then BigSkill := MSkill;
				if MSkill >= 5 then TSkill := TSkill + ( MSkill div 5 );
			end;
			m := m^.Next;
		end;
		UnitSkillValue := BigSkill + TSkill - ( BigSkill div 5 );
	end;

var
	C,Tool: GearPtr;	{Ptr to the controling character / skill bank.}
	SkRk,StRk: Integer;	{Skill Rank, Stat Rank. }
	SkMod,Morale: Integer;		{Skill Roll Modifier. }
	it: Integer;
begin
	{ Error check- make sure that we're actually dealing }
	{ with a master gear and not a ham sandwich or anything. }
	if ( Master = Nil ) or Not ( IsMasterGear( Master ) or ( Master^.G = GG_Adventure ) ) then Exit( 0 );

	{ Error check- make sure we have valid skill and stat numbers. }
	if (Skill < 1) or (Skill > NumSkill) then Exit( 0 );
	if ( Stat < 1 ) or ( Stat > num_character_stats ) then Exit( 0 );

	{ Skill Roll Modifier starts out at 0. }
	SkMod := 0;

	if Master^.G = GG_Character then begin
		{ Since this is a character, just grab the needed }
		{ ranks from the gear's stats and attributes. }
		SkRk := CharaSkillRank( Master , Skill );
		StRk := CStat( Master , Stat );

		C := Master;

		{ If the skill isn't known at all, there's a penalty. }
		if ( SkRk < 1 ) then SkMod := -2;

		{ Check for tools. }
		SkMod := SkMod + ToolBonus( Master , Skill );

		{ If this is a combat skill, check for RAGE. }
		if ( Skill <= 10 ) and ( NAttValue( Master^.NA , NAG_Talent , NAS_Rage ) <> 0 ) then begin
			Morale := NAttValue( Master^.NA , NAG_Condition , NAS_MoraleDamage );
			if Morale > 0 then begin
				SkRk := SkRk + Morale div 20;
			end else if Morale < -20 then begin
				SkRk := SkRk - 2;
			end;
		end;

	end else if Master^.G = GG_Adventure then begin
		{ This must be an arena unit. }
		{ We don't need the additional checks below; just calculate }
		{ the skill value and return it. }
		Exit( UnitSkillValue( Master^.SubCom ) );

	end else if Master^.G = GG_Mecha then begin
		{ As of this implementation, mecha are assumed to }
		{ have a single pilot. }
		C := LocatePilot( Master );
		if C = Nil then Exit( 0 );

		SkRk := SkillValue( C , Skill , Stat ) + ModifiersSkillBonus( Master , Skill );
		StRk := 0;

		{ If this mecha has reflex control, there may be a +1 bonus to this skill. }
		if HasMechaTrait( Master , MT_ReflexSystem ) and ( Skill < 4 ) then begin
			if CharaSkillRank( C , Skill + 3 ) >= CharaSkillRank( C , Skill ) then Inc( SkRk );
		end;

		if SkillMan[Skill].MekSys = MS_Maneuver then begin
			SkMod := SkMod + MechaManeuver( Master );
		end else if SkillMan[Skill].MekSys = MS_Targeting then begin
			SkMod := SkMod + MechaTargeting( Master );
		end else if SkillMan[Skill].MekSys = MS_Sensor then begin
			SkMod := SkMod + MechaSensorRating( Master );
		end;

	end else begin
		{ Props are easy. Return the basic skill rank. }
		StRk := 0;
		SkRk := NAttValue( Master^.NA , NAG_Skill , Skill);
		C := Master;

	end;

	{ The final value equals the Skill Rank plus }
	{ stat modifier plus skill roll modifier. }
	it := ( ( StRk + 1 ) div 2 ) + SkRk + SkMod;
	if it < 1 then it := 1;

	{ Last minute check- if the character is dead, they don't get }
	{ to roll dice. }
	if Destroyed( C ) then it := 0;

	SkillValue := it;
end;


function ReactionTime( Master: GearPtr ): Integer;
	{ Determine the reaction time for this character/mecha. }
const
	{ Even the slowest people will react at this base speed. }
	Minimum_Initiative = 10;
	{ To prevent huge differences in reaction time, all times }
	{ get modified by a baseline. }
	Baseline_Initiative = 15;
var
	I,RT: Integer;
begin
	{ Determine the Initiative skill value for this character. }
	if Master^.G = GG_Prop then begin
		I := SkillValue( Master , NAS_Initiative , STAT_Speed ) + 1;
		if I < 1 then I := 1;
	end else begin
		Master := LocatePilot( Master );
		if Master <> Nil then begin
			I := CStat( Master , STAT_Speed ) + CharaSkillRank( Master , NAS_Initiative );
			if ( I < Minimum_Initiative ) then I := Minimum_Initiative;
		end else I := 1;
	end;
	RT := ( ClicksPerRound * 10 ) div ( I + Baseline_Initiative );
	if RT > ClicksPerRound then RT := ClicksPerRound
	else if RT < 2 then RT := 2;
	ReactionTime := RT;
end;

function PilotName( Part: GearPtr ): String;
	{ Locate the name of the pilot of this thing; }
	{ provide the best substitute if no controller can be found. }
var
	M: GearPtr;
	name: String;
begin
	M := Part;
	if not IsMasterGear( Part ) then M := FindMaster( Part );

	if M = Nil then begin
		if Part = Nil then name := 'Nothing'
		else name := GearName( Part );

	end else if M^.G = GG_Mecha then begin
		Part := LocatePilot( M );
		if Part = Nil then name := GearName( M )
		else name := GearName( Part );

	end else begin
		name := GearName( M );
	end;

	PilotName := Name;
end;

Function MonsterThreatLevel( M: GearPtr ): Integer;
	{ Return the threat level of this monster. This is used for generating random monsters }
	{ and also for assigning XP from kills. }
begin
	if M = Nil then begin
		MonsterThreatLevel := 0;
	end else if ( M^.G = GG_Character ) or ( M^.G = GG_Prop ) then begin
		MonsterThreatLevel := NAttValue( M^.NA , NAG_GearOps , NAS_MonsterTV );
	end else begin
		MonsterThreatLevel := 0;
	end;
end;

Procedure DoleExperience( Mek: GearPtr; XPV: LongInt );
	{ Give XPV experience points to whoever is behind the wheel of }
	{ master unit Mek. }
var
	P: GearPtr;	{ The pilot, in theory. }
begin
	P := LocatePilot( Mek );
	if P <> Nil then begin
		AddNAtt( P^.NA , NAG_Experience , NAS_TotalXP , XPV );
		if XPV > Random(25) then AddMoraleDmg( P , -1 );
	end;
end;

Procedure DoleExperience( Mek,Target: GearPtr; XPV: LongInt );
	{ Give XPV experience points to whoever is behind the wheel of }
	{ master unit Mek. Scale the experience points by the relative }
	{ values of Mek and Target. }
var
	MPV,TPV,MonPV: LongInt;	{ Mek PV, Target PV }
	XP2: Int64;	{ To prevent arithmetic overflows. }
begin
	MPV := GearValue( Mek );
	if MPV < 1 then MPV := 1;
	if Target <> Nil then begin
		TPV := GearValue( Target );

		{ Monsters might benefit from an upward-adjusted TPV based on }
		{ their difficulcy rating. }
		if MonsterThreatLevel( Target ) > 0 then begin
			MonPV := MonsterThreatLevel( Target ) * MonsterThreatLevel( Target ) * 10 - MonsterThreatLevel( Target ) * 100;
			if MonPV > TPV then TPV := MonPV;
		end;
		XP2 := ( XPV * TPV * ( Target^.Scale + 1 ) ) div MPV;
		XPV := XP2;
	end;
	if XPV < 1 then XPV := 1;
	DoleExperience( Mek , XPV );
end;

Function DoleSkillExperience( Mek: GearPtr; Skill,XPV: LongInt ): Boolean;
	{ Give XPV experience points to whoever is behind the wheel of }
	{ master unit Mek. Apply these XP directly to SKILL. }
	{ Return TRUE if this results in a skill increase, or FALSE if not. }
var
	P: GearPtr;	{ The pilot, in theory. }
	SkLvl: Integer;
	it,DidIncrease: Boolean;
begin
	P := LocatePilot( Mek );
	it := False;	{ Assume FALSE unless shown otherwise. }
	if P <> Nil then begin
		AddNAtt( P^.NA , NAG_Experience , NAS_Skill_XP_Base + Skill , XPV );

		{ Check to see if enough skill-specific XPs have been earned to advance the skill. }
		repeat
			SkLvl := NAttValue( P^.NA , NAG_Skill , Skill );
			{ Assume FALSE unless proven TRUE. }
			DidIncrease := False;
			{ Hidden skills can always improve from natural experience, since that's the }
			{ only way to improve them. }
			if ( NATTValue( P^.NA , NAG_Experience , NAS_Skill_XP_Base + Skill ) >= SkillAdvCost( Nil , SkLvl ) ) and ( ( NAttValue( P^.NA , NAG_Skill , Skill ) > 0 ) or SkillMan[ Skill ].Hidden or Direct_Skill_Learning ) then begin
				{ Set IT to true, advance the skill, and decrease the }
				{ number of skill-specific XPs the character has. }
				it := True;
				DidIncrease := True;
				AddNAtt( P^.NA , NAG_Experience , NAS_Skill_XP_Base + Skill , -SkillAdvCost( Nil , SkLvl ) );
				AddNAtt( P^.NA , NAG_Skill , Skill , 1 );
			end;
		until not DidIncrease;
	end;

	{ Return the boolean value. }
	DoleSkillExperience := it;
end;

procedure ExpandCharacter( PC: GearPtr );
	{ Create a body for a currently disembodied character gear. }
var
	M,H: GearPtr;	{ Module , Hand }
{ PROCEDURES BLOCK }
	Procedure InsertLimb( N: Integer );
	begin
		M := AddGear( PC^.SubCom , PC );
		M^.G := GG_Module;
		M^.S := N;
		M^.V := MasterSize( M );
		InitGear( M );
	end;
begin
	if PC^.SubCom = Nil then begin
		InsertLimb( GS_Head );
		InsertLimb( GS_Body );

		InsertLimb( GS_Arm );
		SetSAtt( M^.SA , 'NAME <' + MsgString( 'EXPAND_RightArm' ) + '>' );
		H := AddGear( M^.SubCom , M );
		H^.G := GG_Holder;
		H^.S := GS_Hand;
		SetSAtt( H^.SA , 'NAME <' + MsgString( 'EXPAND_RightHand' ) + '>' );
		InitGear( H );

		InsertLimb( GS_Arm );
		SetSAtt( M^.SA , 'NAME <' + MsgString( 'EXPAND_LeftArm' ) + '>' );
		H := AddGear( M^.SubCom , M );
		H^.G := GG_Holder;
		H^.S := GS_Hand;
		SetSAtt( H^.SA , 'NAME <' + MsgString( 'EXPAND_LeftHand' ) + '>' );
		InitGear( H );

		InsertLimb( GS_Leg );
		SetSAtt( M^.SA , 'NAME <' + MsgString( 'EXPAND_RightLeg' ) + '>' );
		InsertLimb( GS_Leg );
		SetSAtt( M^.SA , 'NAME <' + MsgString( 'EXPAND_LeftLeg' ) + '>' );
	end;
end;

Function MappingRange( Mek: GearPtr; Scale: Integer ): Integer;
	{ Determine how far this mek can see new map tiles. }
	{ This is determined by two things- first, the mek's sensor }
	{ rating, and secondly the pilot's Perception stat. }
var
	Sensor,Pilot: GearPtr;
	it,t: Integer;
begin
	it := 0;

	Sensor := SeekActiveIntrinsic( Mek , GG_Sensor , GS_MainSensor );
	if Sensor <> Nil then begin
		it := it + Sensor^.V;
	end;

	Pilot := LocatePilot( Mek );
	if Pilot <> Nil then begin
		it := it + ( CStat( Pilot , STAT_Perception ) div 3 );
	end;

	{ Adjust the mapping range for scale. }
	if Mek^.Scale > Scale then begin
		for t := ( Scale + 1 ) to Mek^.Scale do it := it * 2;
	end else if Mek^.Scale < ( Scale + 1 ) then begin
		for t := 1 to ( Scale - Mek^.Scale - 1 ) do it := it div 2;
		if it < 1 then it := 1;
	end;

	MappingRange := it;
end;

Procedure AddMoraleDMG( PC: GearPtr; M: Integer );
	{ Add some morale to the PC, keeping it withing the normal }
	{ range of +100 (miserable) to -100 (ecstatic). }
var
	CL: Integer;	{ Current Level }
begin
	if PC^.G <> GG_Character then PC := LocatePilot( PC );

	if ( PC <> Nil ) and ( PC^.G = GG_Character ) then begin
		CL := NAttValue( PC^.NA , NAG_Condition , NAS_MoraleDamage );

		{ If it's positive morale damage and CL is negative, }
		{ make a RESISTANCE roll to avoid losing mood. }
		if ( M > 1 ) and ( CL < 0 ) then begin
			if RollStep( SkillValue( PC , NAS_Toughness , STAT_Ego ) ) < ( M + 1 ) then begin
				CL := CL div 2;
			end;
		end;

		if Abs( CL + M ) > 100 then begin
			SetNATt( PC^.NA , NAG_Condition , NAS_MoraleDamage , 100 * Sgn( CL ) );
		end else begin
			SetNATt( PC^.NA , NAG_Condition , NAS_MoraleDamage , CL + M );
		end;
	end;
end;

Procedure AddReputation( PC: GearPtr; R,V: Integer );
	{ Add a certain amount to reputation R, keeping in mind that }
	{ the allowable range is -100..+100. }
const
	MaxPositiveHeroism = 100;
var
	CL,PosHero: Integer;	{ Current Level, Positive Heroism }
begin
	if PC^.G <> GG_Character then PC := LocatePilot( PC );
	R := Abs( R );

	if ( PC <> Nil ) and ( PC^.G = GG_Character ) then begin
		CL := NAttValue( PC^.NA , NAG_CHarDescription , -R );

		{ Increasing a favored reputation improves morale, }
		{ while decreasing a reputation abuses it. }
		if R = -NAS_Renowned then begin
			{ Gaining renown always improves mood, losing it always }
			{ abuses mood. }
			if V > 0 then begin
				AddMoraleDmg( PC , -MORALE_RepSmall );
			end else if V < 0 then begin
				AddMoraleDmg( PC , MORALE_RepSmall );
			end;
		end else if Sgn( CL ) = Sgn( V ) then begin
			if Abs( V ) = 1 then begin
				AddMoraleDmg( PC , -MORALE_RepSmall );
			end else begin
				AddMoraleDmg( PC , -MORALE_RepBig );
			end;
		end else if Sgn( CL ) = -Sgn( V ) then begin
			if Abs( V ) = 1 then begin
				AddMoraleDmg( PC , MORALE_RepSmall );
			end else begin
				AddMoraleDmg( PC , MORALE_RepBig );
			end;
		end;

		{ Any act of major villainy or comission of crimes }
		{ (greater than a -1 change)  will completely wipe }
		{ out any heroic or lawful reputation that }
		{ this character may have had. }
		{ Acts of positive heroism may be limited. You can only gain }
		{ up to 100 positive heroic points, so it's not possible to }
		{ farm heroic points. }
		if ( R <= 2 ) and ( V < -1 ) and ( CL > 0 ) then begin
			CL := 0;
		end else if ( R = -NAS_Heroic ) and ( V > 0 ) then begin
			PosHero := NAttValue( PC^.NA , NAG_CHarDescription , NAS_PositiveHeroism );
			AddNAtt( PC^.NA , NAG_CHarDescription , NAS_PositiveHeroism , V );
			if ( PosHero + V ) > MaxPositiveHeroism then begin
				V := MaxPositiveHeroism - PosHero;
				if V < 0 then V := 0;
			end;
		end;

		if Abs( CL + V ) > 100 then begin
			SetNATt( PC^.NA , NAG_CharDescription , -R , 100 * Sgn( CL ) );
		end else begin
			SetNATt( PC^.NA , NAG_CharDescription , -R , CL + V );
		end;
	end;
end;

Procedure AddStaminaDown( PC: GearPtr; Strain: Integer );
	{ Apply stamina drain to the PC. }
begin
	{ Begin with a battery of error checks. }
	if ( PC <> Nil ) and ( Strain > 0 ) then begin
		if PC^.G <> GG_Character then PC := LocatePilot( PC );
		if ( PC <> Nil ) then begin
			if ( CurrentStamina( PC ) > 0 ) then begin
				AddNAtt( PC^.NA , NAG_Condition , NAS_StaminaDown , Strain );

				{ Using SP trains athletics. }
				DoleSkillExperience( PC , NAS_Athletics , Strain * 2 );
			end else begin
				AddMoraleDmg( PC , Strain );
			end;
		end;
	end;
end;

Procedure AddMentalDown( PC: GearPtr; Strain: Integer );
	{ Apply mental drain to the PC. }
begin
	{ Begin with a battery of error checks. }
	if ( PC <> Nil ) and ( Strain > 0 ) then begin
		if PC^.G <> GG_Character then PC := LocatePilot( PC );
		if ( PC <> Nil ) then begin
			if ( CurrentMental( PC ) > 0 ) then begin
				AddNAtt( PC^.NA , NAG_Condition , NAS_MentalDown , Strain );

				{ Using MP trains concentration. }
				DoleSkillExperience( PC , NAS_Concentration , Strain * 2 );
			end else begin
				AddMoraleDMG( PC , Strain );
			end;
		end;
	end;
end;

Function CurrentMental( PC: GearPtr ): Integer;
	{ Return how many mental points this character currently has. }
var
	it: Integer;
begin
	PC := LocatePilot( PC );
	if PC <> Nil then begin
		it := CharMental( PC ) - NAttValue( PC^.NA , NAG_Condition , NAS_MentalDown );
		if it < 0 then it := 0;
		CurrentMental := it;
	end else begin
		CurrentMental := 0;
	end;
end;

Function CurrentStamina( PC: GearPtr ): Integer;
	{ Return how many stamina points this character currently has. }
var
	it: Integer;
begin
	PC := LocatePilot( PC );
	if PC <> Nil then begin
		it := CharStamina( PC ) - NAttValue( PC^.NA , NAG_Condition , NAS_StaminaDown );
		if it < 0 then it := 0;
		CurrentStamina := it;
	end else begin
		CurrentStamina := 0;
	end;
end;


Function HasPCommCapability( PC: GearPtr; C: Integer ): Boolean;
	{ Return TRUE if the listed PC has the requested Personal }
	{ Communications Capability. }
begin
	HasPCommCapability := HasIntrinsic( PC , C , True );
end;

Function HasTalent( PC: GearPtr; T: Integer ): Boolean;
	{ Return TRUE if PC has the listed talent, FALSE otherwise. }
var
	it: Boolean;
begin
	if ( PC <> Nil ) and ( PC^.G = GG_Adventure ) then begin
		PC := PC^.SubCom;
		it := False;
		while ( PC <> Nil ) and not it do begin
			if PC^.G = GG_Character then it := HasTalent( PC , T );
			PC := PC^.Next;
		end;
	end else begin
		PC := LocatePilot( PC );
		it := ( PC <> Nil ) and ( NAttValue( PC^.NA , NAG_Talent , T ) <> 0 );
	end;
	HasTalent := it;
end;

Function HasIntrinsic( PC: GearPtr; I: Integer; CasualUse: Boolean ): Boolean;
	{ Return TRUE if the PC has the listed intrinsic, or FALSE otherwise. }
	{ If this is casual use, search the general inventory. Otherwise }
	{ just search the subcomponents. }
	Function IntrinsicFoundAlongTrack( Part: GearPtr ): Boolean;
		{ Return TRUE if the intrinsic is found along this track. }
	var
		WasFound: Boolean;
	begin
		{ Begin by assuming FALSE. }
		WasFound := False;

		{ Search along the track until we run out of parts or find }
		{ the intrinsic. }
		while ( Part <> Nil ) and not WasFound do begin
			if NotDestroyed( Part ) then begin
				WasFound := NAttValue( Part^.NA , NAG_Intrinsic , I ) <> 0;
				if not WasFound then WasFound := IntrinsicFoundAlongTrack( Part^.SubCom );
				if not WasFound then WasFound := IntrinsicFoundAlongTrack( Part^.InvCom );
			end;
			Part := Part^.Next;
		end;

		IntrinsicFoundAlongTrack := WasFound;
	end;
var
	it: Boolean;
begin
	{ Start with an error check- if this isn't a regular intrinsic, return FALSE. }
	if ( PC = Nil ) or ( I < 1 ) or ( I > NumIntrinsic ) then Exit( False );

	it := NAttValue( PC^.NA , NAG_Intrinsic , I ) <> 0;
	if not it then it := IntrinsicFoundAlongTrack( PC^.SubCom );
	if CasualUse and not it then it := IntrinsicFoundAlongTrack( PC^.InvCom );
	HasIntrinsic := it;
end;

Function IsEnviroSealed( PC: GearPtr ): Boolean;
	{ Return TRUE if the PC is environmentally sealed, or FALSE otherwise. }
	{ The PC counts as environmentally sealed if either 1) the main chara gear }
	{ has the sealed intrinsic, or 2) all modules individually have the }
	{ sealed intrinsic. }
	{ Oh, 3) Mecha and other non-characters automatically count as sealed. }
var
	M: GearPtr;
	it: Boolean;
begin
	if ( NAttValue( PC^.NA , NAG_Intrinsic , NAS_EnviroSealed ) <> 0 ) or ( PC^.G <> GG_Character ) then begin
		IsEnviroSealed := true;
	end else begin
		{ Check all the limbs for sealing. }
		M := PC^.SubCom;
		{ Assume TRUE unless shown FALSE. }
		it := True;

		{ If a single limb is found that isn't sealed, then the entirety isn't sealed. }
		while M <> Nil do begin
			if ( M^.G = GG_Module ) and NotDestroyed( M ) then begin
				if not HasIntrinsic( M , NAS_EnviroSealed , True ) then it := False;
			end;

			M := M^.Next;
		end;

		IsEnviroSealed := it;
	end;
end;

Function PartyPetSlots( PC: GearPtr ): Integer;
	{ Return however many pets the PC can have. }
begin
	PC := LocatePilot( PC );
	if PC = Nil then Exit( 0 );
	PartyPetSlots := 1 + CStat( PC , STAT_Charm ) div 4;
end;

Function HasSkill( PC: GearPtr; Skill: Integer ): Boolean;
	{ Return TRUE if the PC has the listed skill, or FALSE otherwise. }
var
	it: Boolean;
begin
	if ( PC <> Nil ) and ( PC^.G = GG_Adventure ) then begin
		PC := PC^.SubCom;
		it := False;
		while ( PC <> Nil ) and not it do begin
			if PC^.G = GG_Character then it := HasSkill( PC , Skill );
			PC := PC^.Next;
		end;
	end else begin
		{ Make sure we're dealing with the real PC here. }
		PC := LocatePilot( PC );

		if PC <> Nil then begin
			it := ( NAttValue( PC^.NA , NAG_Skill , Skill ) > 0 ) or HasTalent( PC , NAS_JackOfAll );
		end else begin
			it := False;
		end;
	end;
	HasSkill := it;
end;

Procedure SkillComment( const Msg: String );
	{ Add a comment to the skill roll history. }
var
	SA: SAttPtr;
begin
	if NumSAtts( Skill_Roll_History ) >= 100 then begin
		SA := Skill_Roll_History;
		RemoveSAtt( Skill_Roll_History , SA );
	end;
	StoreSAtt( Skill_Roll_History , Msg );
end;

Procedure SkillCommentDivider;
	{ Draw a nice divider in the skill roll history list. }
begin
	SkillComment( '--' );
end;

Function Calculate_Threat_Points( Level,Percent: Integer ): LongInt;
	{ Calculate an appropriate threat value, based upon the modified }
	{ renown level and the % scale factor. }
var
	it: LongInt;
begin
	if Level < 0 then Level := 0
	else if Level > 300 then Level := 300;

	{ This formula looks strange; it was created using some expected values and then }
	{ deriving an equation to fit. }

	{ For low level encounters, use a linear equation. }
	if Level < 31 then begin
		it := Level * 10000 div 30;
	{ Higher on, switch to the quadratic. }
	end else begin
		it := 20 * Level * Level - 900 * Level + 19040;
	end;

	{ Modify for the percent requested. }
	it := it * Percent;

	Calculate_Threat_Points := it;
end;

initialization
	Skill_Roll_History := Nil;

finalization
	DisposeSATt( Skill_Roll_History );

end.
