unit action;

	{ This is the *ACTION* unit! It handles two kinds of action- }
	{ gears moving across the gameboard, and gears taking damage + }
	{ potentially blowing up. This might seem like two strange things }
	{ to combine in a single unit, but believe me it makes sense. }
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
	Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
}
{$LONGSTRINGS ON}

interface

uses gears,locale;

Type
	DamageRec = Record
		EjectRoll,EjectOK,PilotDied,MechaDestroyed: Boolean;
		DamageDone: LongInt;
	end;


const
	TRIGGER_NumberOfUnits = 'NU';
	TRIGGER_UnitEliminated = 'TD';
	TRIGGER_NPCEliminated = 'FAINT';
	TRIGGER_NPCSurrendered = 'SURRENDER';
	TRIGGER_TeamMovement = 'TMOVE';
	TRIGGER_NPCMovement = 'MOVE';
	TRIGGER_PCAttack = 'PCATTACK';

	{ *** ENACT MOVEMENT RESULTS *** }
	EMR_Blocked = -2;	{ May indicate a charge... }
	EMR_Crash = 2;		{ If either of these are returned from movement, }
				{ you should do a check to resolve crashes and charges. }

	SA_Explosion = 'EXPLOSION';

var
	Destroyed_Parts_List: SAttPtr;

Function Confused( Mek: GearPtr ): Boolean;

Procedure GiveSkillRollXPAward( Pilot: GearPtr; Skill,SkRoll,SkTar: Integer );
Function SkillRoll( GB: GameBoardPtr; PC: GearPtr; Skill,Stat,SkTar,SkMod: Integer; CasualUse,GainXP: Boolean ): Integer;
Function CheckLOS( GB: GameBoardPtr; Observer,Target: GearPtr ): Boolean;
Procedure VisionCheck( GB: GameBoardPtr; Mek: GearPtr );


Function DamageGear( gb: GameBoardPtr; O_Part,O_Weapon: GearPtr; O_DMG,O_MOS,O_NumHits: Integer; const AtAt: String ): DamageRec;
Function DamageGear( gb: GameBoardPtr; Part: GearPtr; DMG: Integer): DamageRec;
procedure Crash( gb: GameBoardPtr; Mek: GearPtr );

Procedure PrepAction( GB: GameBoardPtr; Mek: GearPtr; Action: Integer );
Procedure SetMoveMode( GB: GameBoardPtr; Mek: GearPtr; MM: Integer );
Function EnactMovement( GB: GameBoardPtr; Mek: GearPtr ): Integer;

Procedure DoDrift( GB: GameBoardPtr; Mek: GearPtr );

Procedure WaitAMinute( GB: GameBoardPtr; Mek: GearPtr; D: Integer );


implementation

uses 	ability,gearutil,ghchars,ghmodule,ghweapon,movement,rpgdice,texutil,
	math,ui4gh,ghintrinsic,ghsensor,ghprop,ghsupport,
{$IFDEF ASCII}
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}

const
	EjectDamage = 10;	{ The damage step to roll during an ejection attempt. }

	MissileConcussion = 3;
	MeleeConcussion = 3;
	ModuleConcussion = 7;

	DamagePilotChance = 75;		{ % chance to damage pilot by concussion. }
	DamageInventoryChance = 25;	{ % chance to damage inventory gears by concussion. }


	Stealth_Per_Scale = 4;		{ If scale different from map, get stealth bonus/penalty }

Function Confused( Mek: GearPtr ): Boolean;
	{ Return true if either the pilot or the mecha is either }
	{ HAYWIRE or STONED. }
var
	Pilot: GearPtr;
begin
	if Mek^.G = GG_Mecha then begin
		Pilot := LocatePilot( Mek );
	end else begin
		Pilot := Nil;
	end;

	Confused := HasStatus( Mek , NAS_Haywire ) or HasStatus( Mek , NAS_Stoned ) or HasStatus( Pilot , NAS_Haywire ) or HasStatus( Pilot , NAS_Stoned );
end;

Procedure GiveSkillRollXPAward( Pilot: GearPtr; Skill,SkRoll,SkTar: Integer );
	{ Give a skill XP award. The size of the award is going to depend on the }
	{ relation betwee SkRoll and SkTar. }
const
{	Basic_Skill_Award_Multiplier: Array [1..NumSkill] of Byte = (
		1,1,1,1,1,	2,2,2,2,2,
		1,1,1,5,1,	1,1,1,5,1,
		1,1,1,1,1,	1,5,3,3,1,
		1,3,1,3,1,	2,3,1,1,10,
		7,1,1
	);}
	MaxTarLevel = 12;
	Skill_Award_By_Level: Array [1..12] of Integer = (
		1,2,3,4,5,
		8,13,21,34,55,
		89,144
	);
var
	TarLevel: Integer;	{ Just how tough was this target? }
	SkRank: Integer;	{ Skill rank. }
begin
	Pilot := LocatePilot( Pilot );
	if ( Pilot <> Nil ) and ( Skill >= 1 ) and ( Skill <= NumSkill ) and ( SkRoll >= SkTar ) then begin
		{ Determine the TarLevel. This will tell how much XP to give. }
		TarLevel := ( SkTar + 2 ) div 3;
		if TarLevel < 1 then TarLevel := 1
		else if TarLevel > MaxTarLevel then TarLevel := MaxTarLevel;

		{ Determine the Pilot's skill rank. This will be needed later. }
		SkRank := NAttValue( Pilot^.NA , NAG_Skill , Skill );

		{ The expereince award can't exceed one level beyond the skill rank. }
		if TarLevel > ( SkRank + 1 ) then TarLevel := SkRank + 1;

		if ( SkTar > SkRank ) and ( SkRank > 0 ) then begin
			DoleSkillExperience( Pilot , Skill , Skill_Award_By_Level[ TarLevel ] * 2 );
			DoleExperience( Pilot , Skill_Award_By_Level[ TarLevel ] );
		end else if ( SkTar > ( SkRank div 2 ) ) then begin
			DoleSkillExperience( Pilot , Skill , Skill_Award_By_Level[ TarLevel ] );
			if SkRank > 0 then DoleExperience( Pilot , 1 );
		end;
	end;
end;


Function SkillRoll( GB: GameBoardPtr; PC: GearPtr; Skill,Stat,SkTar,SkMod: Integer; CasualUse,GainXP: Boolean ): Integer;
	{ Attempt to make a skill roll. }
	{ Skill = The skill to use. }
	{ SkTar = The target number to try and beat. }
	{ SkMod = The modifier to the skill roll. }
	{ CasualUse = TRUE if the PC can use things in his backpack and use the team's }
	{     help, or FALSE otherwise. }
var
	msg: String;
	SkRank,SkRoll: Integer;
	Pilot: GearPtr;
begin
	{ Determine the base skill value, and initialize the message. }
	msg := PilotName( PC ) + ' rolls ' + MSgString( 'SKILLNAME_' + BStr( Skill ) ) + '+' + MSgString( 'STATNAME_' + BStr( Stat ) ) + ' ';
	if CasualUse and ( GB <> Nil ) then begin
		SkRank := TeamSkill( GB , NAV_DefPlayerTeam , Skill , Stat );
	end else begin
		SkRank := SkillValue( PC , Skill , Stat );
	end;

	msg := msg + '[' + BStr( SkRank );
	if SkMod <> 0 then msg := msg + SgnStr( SkMod );
	msg := msg + ']';
	if SkTar > 0 then begin
		msg := msg + ' vs ' + BStr( SkTar ) + ':';
	end else begin
		msg := msg + ':';
		SkTar := SkRank div 2;
	end;

	{ Adjust the skill value by the modifier. }
	SkRank := SkRank + SkMod;
	if SkRank < 1 then SkRank := 1;

	{ Make the die roll. }
	SkRoll := RollStep( SkRank );
	msg := msg + BStr( SkRoll );

	{ Store the message. }
	{ NOTE: Awareness only gets stored if it's successful. }
	{ Otherwise the player could check the skill roll history and easily see }
	{ that there's something hidden nearby. }
	if ( Skill <> NAS_Awareness ) or ( SkRoll > SkTar ) then begin
		SkillComment( Msg );
	end;

	{ If the roll was a success, give some skill XP. }
	Pilot := LocatePilot( PC );
	if GainXP and ( Pilot <> Nil ) then begin
		GiveSkillRollXPAward( Pilot , Skill , SkRoll , SkTar );
	end;

	{ Return the result. }
	SkillRoll := SkRoll;
end;

Function CheckLOS( GB: GameBoardPtr; Observer,Target: GearPtr ): Boolean;
	{ Do the line-of-sight roll to see if Observer notices Target. }
	Function TargetStealth: Integer;
		{ Return the modified stealth rating of this target. }
	var
		T: Integer;
	begin
		T := MechaStealthRating( Target );
		if Target^.Scale > GB^.Scale then begin
			T := T - ( Target^.Scale - GB^.Scale ) * Stealth_Per_Scale;
		end else if Target^.Scale < GB^.Scale then begin
			T := T + ( GB^.Scale - Target^.Scale ) * Stealth_Per_Scale;
		end;
		if ( Target^.G = GG_MetaTerrain ) and ( Target^.S = GS_MetaEncounter ) then begin
			T := T + Range( GB , Observer , Target );
			if T < 5 then T := 5;
		end;
		TargetStealth := T;
	end;
	Function CasualUseAwareness: Boolean;
		{ Can use the team skill level if the map scale is bigger than 2. }
	begin
		CasualUseAwareness := ( GB^.Scale > 2 );
	end;
var
	O,T,Roll: Integer;
	P1,P2: Point;
	it: Boolean;
begin
	{ Calculate the obscurement. }
	O := CalcObscurement( Observer , Target , gb );

	{ Encounters can only be spotted within a limited range, }
	{ based on the observer's awareness skill. }
	if ( Target^.G = GG_MetaTerrain ) and ( Target^.S = GS_MetaEncounter ) then begin
		if Range( GB , Observer , Target ) > ( ( SkillValue( Observer , NAS_Awareness , STAT_Perception ) + 2 ) div 2 ) then O := -1;
	end;

	{ If there's nothing standing between the target and the spotter, }
	{ visibility is mostly guaranteed. }
	if ( O = 0 ) and ( Target^.G <> GG_MetaTerrain ) then begin
		{ If the target has stealth and is outside of the spotter's front arc, }
		{ then it gets a STEALTH roll. }
		if ( NAttValue( Target^.NA , NAG_Action , NAS_MoveAction ) <> NAV_FullSpeed ) and HasSkill( Target , NAS_Stealth ) then begin
			{ Get the position of the spotter and the target. }
			P1 := GearCurrentLocation( Observer );
			P2 := GearCurrentLocation( Target );

			if not ArcCheck( P1.X , P1.Y , NAttValue( Observer^.NA , NAG_Location , NAS_D ) , P2.X , P2.Y , ARC_F180 ) then begin
				{ Make the awareness roll. }
				T := TargetStealth;
				Roll := SkillRoll( GB , Observer , NAS_Awareness , STAT_Perception , T , 0 , CasualUseAwareness , AreEnemies( GB , Observer , Target ) );

				if SkillRoll( GB , Target , NAS_Stealth , STAT_Speed , Roll , -5 , False , AreEnemies( GB , Observer , Target ) ) > Roll then begin
					it := False;
				end else begin
					it := True;
				end;

			end else begin
				{ Within the front arc and with no cover, Stealth is of no help. }
				it := True;
			end;
		end else begin
			it := True;
		end;
	end else if O = -1 then begin
		it := False;
	end else begin
		{ Make the awareness roll. }
		T := O + TargetStealth;
		Roll := SkillRoll( GB , Observer , NAS_Awareness , STAT_Perception , T , 0 , CasualUseAwareness , AreEnemies( GB , Observer , Target ) );

		if Roll > T then begin
			{ The target might get a STEALTH save now. }
			if ( NAttValue( Target^.NA , NAG_Action , NAS_MoveAction ) <> NAV_FullSpeed ) and HasSkill( Target , NAS_Stealth ) then begin
				if SkillRoll( GB , Target , NAS_Stealth , STAT_Speed , Roll , 5 , False , AreEnemies( GB , Observer , Target ) ) > Roll then begin
					it := False;
				end else begin
					it := True;
				end;
			end else begin
				it := True;
			end;
		end else it := False;
	end;

	{ If the spotter is BLINDED, there's a 2/3 chance that the LOS check will fail. }
	if HasStatus( Observer , NAS_Blinded ) and ( Random( 3 ) <> 1 ) then it := False;

	CheckLOS := it;
end;

Procedure VisionCheck( GB: GameBoardPtr; Mek: GearPtr );
	{ Perform a sensor check for MEK. It might spot hidden enemy }
	{ units; it may get spotted by enemy units itself. }
var
	M2: GearPtr;
	Team: Integer;
begin
	if ( Mek = Nil ) or ( not GearOperational( Mek ) ) or ( not OnTheMap( GB , Mek ) ) then exit;
	Team := NAttValue( Mek^.NA , NAG_Location , NAS_Team );

	{ Start by assuming that the mek will be hidden after this. }
	{ Strip all of its visibility tokens. }
	StripNAtt( Mek , NAG_Visibility );

	M2 := GB^.Meks;
	while M2 <> Nil do begin
		{ We are only interested in this other mek if it's an }
		{ enemy of the one we're checking. }
		if OnTheMap( GB , M2 ) then begin
			if IsMasterGear( Mek ) and not MekCanSeeTarget( gb , Mek , M2 ) then begin
				{ If this enemy mecha has not yet been spotted, }
				{ there's a chance it will become visible. }
				if IsMasterGear( M2 ) and CheckLOS( GB , Mek , M2 ) then begin
					{ M2 has just been spotted. }
					RevealMek( GB , M2 , Mek );
				end else if ( Team = NAV_DefPlayerTeam ) and ( M2^.G = GG_MetaTerrain ) and ( M2^.S = GS_MetaEncounter ) and ( M2^.Stat[ STAT_MetaVisibility ] >= 0 ) then begin
					if CheckLOS( GB , Mek , M2 ) then begin
						RevealMek( GB , M2 , Mek );
					end;
				end;
			end;

			{ There is also a chance that M2 might spot Mek. }
			if IsMasterGear( M2 ) and GearOperational( M2 ) and not MekCanSeeTarget( GB , M2 , Mek ) then begin
				if CheckLOS( GB , M2 , Mek ) then RevealMek( GB , Mek , M2 );
			end;
		end;

		M2 := M2^.Next;
	end;

	if ( Team = NAV_DefPlayerTeam ) or ( Team = NAV_LancemateTeam ) then begin
		CheckVisibleArea( GB , Mek );
	end;

	Screen_Needs_Redraw := True;
end;


Function DamageGear( gb: GameBoardPtr; O_Part,O_Weapon: GearPtr; O_DMG,O_MOS,O_NumHits: Integer; const AtAt: String ): DamageRec;
	{ Damage the provided gear. }
var
	DR: DamageRec;
	DAMAGE_OverKill,DAMAGE_Iterations: LongInt;
{ Procedures block. }
	Function TakeDamage( Part: GearPtr; DMG: LongInt ): Boolean;
		{ Store the listed amount of damage in PART. Return TRUE if part }
		{ was operational at the start & is still operational, FALSE otherwise. }
		{ The main reason for having this procedure is to record triggers }
		{ when something is destroyed. }
	var
		Ok_At_Start: Boolean;
		GoUp: GearPtr;	{ A counter that will be used to check all of PART's parents. }
		Team: Integer;
	begin
		Ok_At_Start := GearOperational( Part );

		AddNAtt(Part^.NA,NAG_Damage,NAS_StrucDamage,DMG);

		{ If PART was destroyed by this damage, there may be triggers that }
		{ need generating. Get to work. }
		if Ok_At_Start and ( not GearOperational( Part ) ) then begin

			{ PART and all of its parents up to root need to be }
			{ checked for triggers. }
			GoUp := Part;
			while GoUp <> Nil do begin
				{ If GoUp is destroyed, and it has a UID, generate }
				{ a TD* trigger. }
				if ( NAttValue( GoUp^.NA , NAG_EpisodeData , NAS_UID ) <> 0 ) and ( Not GearOperational( GoUp ) ) then begin
					SetTrigger( GB , TRIGGER_UnitEliminated + BStr( NAttValue( GoUp^.NA , NAG_EpisodeData , NAS_UID ) ) );
				end;

				{ If GoUp is destroyed and it had a CID, generate }
				{ a UTD* trigger. }
				if ( NAttValue( GoUp^.NA , NAG_Personal , NAS_CID ) <> 0 ) and ( Not GearOperational( GoUp ) ) then begin
					SetTrigger( GB , TRIGGER_NPCEliminated + BStr( NAttValue( GoUp^.NA , NAG_Personal , NAS_CID ) ) );
				end;

				{ If this is a root level gear, generate a NU* trigger. }
				if ( GoUp^.Parent = Nil ) and IsMasterGear( GoUp ) then begin
					Team := NAttValue( GoUp^.NA , NAG_Location , NAS_Team );
					SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( Team ) );
				end;

				{ Move up one more level. }
				GoUp := GoUp^.Parent;
			end;

			{ Add this gear to the list of destroyed parts. }
			{ Only do this for non-master gears which aren't at }
			{ root level. }
			if ( Part^.Parent <> Nil ) and not IsMasterGear( Part ) then StoreSAtt( Destroyed_Parts_List , GearName( Part ) );

		end else if OK_At_Start and ( Part^.G = GG_Character ) then begin
			{ Taking damage causes the afflicted to feel worse for wear. }
			AddMoraleDmg( Part , DMG );
		end;

		TakeDamage := Ok_At_Start and NotDestroyed( Part );
	end;

	Procedure EjectionCheck( Part: GearPtr );
		{ The parent has just been destroyed. Check to see whether or not }
		{ there is a pilot inside of it, then roll to escape or be blasted }
		{ to bits. }
		{ ASSERT: PART is a subcomponent of its parent. }
	var
		P2: GearPtr;
		Master: GearPtr;
		ERoll,EMod,Team: Integer;
		SafeEject: Boolean;
	begin
		{ To start with, find the team for this unit, since we might not be }
		{ able to after the pilot ejects. }
		if Part <> Nil then Team := NAttValue( FindRoot( Part )^.NA , NAG_Location , NAS_Team );

		{ Determine if this is an honorable duel- if so, the chance of being killed }
		{ is greatly reduced. }
		SafeEject := ( GB^.Scene <> Nil ) and AStringHasBString( SAttValue( GB^.Scene^.SA , 'SPECIAL' ) , 'ARENA' );

		while ( Part <> Nil ) do begin
			P2 := Part^.Next;

			if NotDestroyed( Part ) then begin
				if Part^.G = GG_Character then begin
					{ This character must either eject or die. }
					{ Actually, eject, suffer damage, or die. }
					DR.EjectRoll := True;
					EMod := 5;

					{ First, determine what sort of module the pilot }
					{ is in. HEAD = +3 bonus to eject. }
					Master := Part^.Parent;
					while ( Master <> Nil ) and ( Master^.G <> GG_Module ) do begin
						Master := Master^.Parent;
					end;
					if Master <> Nil then begin
						{ We've found the module the cockpit is in. }
						if Master^.S = GS_Head then EMod := EMod - 3;
					end else begin
						{ We can't find a module, all the way back to root. }
						{ Try to handle things gracefully... }
						Master := Part^.Parent;
					end;

					{ Find the root-level master of this part. }
					while Master^.Parent <> Nil do begin
						Master := Master^.Parent;
					end;

					{ Do the Skill Roll - SPEED + DODGE SKILL }
					ERoll := SkillRoll( GB , Part , NAS_Dodge , STAT_Speed , EMod , 0 , False, True );
					if SafeEject then begin
						ERoll := ERoll + 20;
					end;

					if ERoll < ( EMod * 2 ) then begin
						{ The character will eject, but takes some damage. }
						TakeDamage( Part , RollDamage( EjectDamage , Part^.Scale ) );
					end;

					if ( ERoll > EMod ) and not PartHasIntrinsic( Part , NAS_Integral ) then begin
						{ Delink the chaacter, then attach as a sibling of the master gear. }
						DelinkGear( Part^.Parent^.SubCom , Part );
						SetNAtt( Part^.NA , NAG_Location , NAS_X , 0 );
						SetNAtt( Part^.NA , NAG_Location , NAS_Y , 0 );
						Part^.Next := Master^.Next;
						Master^.Next := Part;

						DR.EjectOK := True;

					end else begin
						{ The character has not managed to eject successfully. }
						{ He's toast. }
						TakeDamage( Part , GearMaxDamage( Part ) );

					end;

					if Destroyed( Part ) then begin
						DR.PilotDied := True;
					end;


					{ If an ejection has occurred, or the pilot has died trying, }
					{ better set a NUMBER OF UNITS trigger. }
					SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( Team ) );
				end else begin
					{ Check the sub components for characters. }
					EjectionCheck( Part^.SubCom );
				end;
			end;

			Part := P2;
		end;
	end;

	Procedure AmmoExplosion( Part: GearPtr );
		{ How should an ammo explosion work? Well, roll damage for the }
		{ ammo and add it to the OVERKILL history variable. }
	var
		PercentFull: Integer;
		M: GearPtr;
	begin
		{ Only installed ammo can explode. This may seem silly, and it }
		{ probably is, but otherwise carrying replacement clips is }
		{ asking for certain death. }
		if IsExternalPart( FindRoot( Part ) , Part ) then exit;

		{ First calculate the number of shots in the magazine. }
		{ If it is empty, no ammo explosion will take place. }
		if Part^.Stat[ STAT_AmmoPresent ] > 0 then PercentFull := ( ( Part^.Stat[ STAT_AmmoPresent ] - NAttValue( Part^.NA , NAG_WeaponModifier , NAS_AmmoSpent ) ) * 100 ) div Part^.Stat[ STAT_AmmoPresent ]
		else PercentFull := 100;
		if PercentFull > 0 then begin
			M := FindModule( Part );
			if ( M = Nil ) or ( M^.S <> GS_Storage ) then begin
				DAMAGE_OverKill := DAMAGE_OverKill + RollDamage( Part^.V * PercentFull div 50 , Part^.Scale );
			end;
		end;
	end;

	Procedure CriticalEngineFailure( Part: GearPtr );
		{ So sad; this mecha is set to go boom. }
	begin
		Part := FindRoot( Part );
		if ( Part <> Nil ) and ( Part^.G = GG_Mecha ) then SetNAtt( Part^.NA , NAG_Action , NAS_WillExplode , 1 );
	end;

	Procedure ApplyDamage( Part: GearPtr; DMG: LongInt);
		{ Add to the damage total of this part, }
		{ then check for special effects such as eject rolls, ammo }
		{ explosions, and whatever else has been implemented. }
	var
		OK_at_Start: Boolean;	{ Was the part OK before damage was applied? }
		M: GearPtr;
	begin
		{ERROR CHECK - If we are attempting to damage a storage}
		{module or other -1HP type, don't do anything.}

		if GearMaxDamage(Part) > 0  then begin
			OK_At_Start := NotDestroyed( Part );

			{ Calculate overkill. }
			if GearCurrentDamage( Part ) < DMG then begin
				{ Damage dealt to storage modules doesn't carry through to }
				{ overkill. The module can be blown off without affecting }
				{ the structural integrity of the whole. }
				M := FindModule( Part );
				if ( M = Nil ) or ( M^.S <> GS_Storage ) then begin
					DAMAGE_OverKill := DAMAGE_OverKill + DMG - GearCurrentDamage( Part );
				end;
				DMG := GearCurrentDamage( Part );
			end;

			TakeDamage( Part , DMG );

			if OK_At_Start and Destroyed( Part ) then begin
				{ The part started out OK, but it's been }
				{ destroyed. Check for special effects. }
				if (Part^.G = GG_Module ) or ( Part^.G = GG_Cockpit ) then begin
					EjectionCheck( Part^.SubCom );
				end else if Part^.G = GG_Ammo then begin
					AmmoExplosion( Part );
				end else if ( Part^.G = GG_Support ) and ( Part^.S = GS_Engine ) then begin
					{ If the engine is destroyed, there's a chance for a catastrophic failure. }
					if Part^.Stat[ STAT_EngineSubType ] = EST_HighPerformance then begin
						CriticalEngineFailure( Part );
					end else if Part^.Stat[ STAT_EngineSubType ] <> 0 then begin
						if Random( 4 ) = 1 then CriticalEngineFailure( Part );
					end else if Random( 100 ) = 1 then begin
						CriticalEngineFailure( Part );
					end;
				end;
			end;
		end;
	end;

	Function IsBeamAttack: Boolean;
		{ Return TRUE if this is a beam attack. How to tell? }
		{ If it's a beamgun, an emelee, or HYPER. }
	begin
		if HasAttackAttribute( AtAt , AA_Hyper ) then begin
			IsBeamAttack := TRUE;
		end else if ( O_Weapon <> Nil ) and ( O_Weapon^.G = GG_Weapon ) then begin
			IsBeamAttack := ( O_Weapon^.S = GS_BeamGun ) or ( O_Weapon^.S = GS_EMelee );
		end else IsBeamAttack := False;
	end;

	Procedure StagedPenetration( Part: GearPtr; var DMG: Longint; var MOS , Scale: Integer );
		{This procedure applies armor damage to Part.}
		{ Variables DMG and MOS will be affected by this procedure. }
	var
		XA,PMaster: GearPtr;
		MAP: Integer; {The maximum number of armor points to lose.}
		AAP: Integer; {The actual number that will be lost.}
		AType: Integer;	{ What kind of armor does this part have? }
		Armor: LongInt; { Initial armor value of the part. }
		IsHardened: Boolean;
	begin
		{ First, check InvComponents for external armor. }
		if ( Part <> Nil ) and ( not IsMasterGear( Part ) ) then begin
			XA := Part^.InvCom;
			while ( XA <> Nil ) do begin
				if XA^.G = GG_ExArmor then StagedPenetration( XA , Dmg , MOS , Scale );
				XA := XA^.Next;
			end;
		end;

		{ Damage can be affected by the armor type. }
		AType := NAttValue( Part^.NA , NAG_GearOps , NAS_ArmorType );
		if AType = NAV_Hardened then begin
			{ Hardened armor is hardened. That is all. }
			IsHardened := True;
		end else if ( AType = NAV_AntiBeam ) and IsBeamAttack then begin
			{ Anti-Beam Armor reduces beam damage by half, and counts as }
			{ hardened against it. }
			Dmg := Dmg div 2;
			IsHardened := True;
		end else begin
			IsHardened := False;
		end;

		{ Locate the master of this part, which we'll need in order }
		{ to check status conditions. }
		PMaster := FindMaster( Part );

		{ Only do armor damage to parts which have armor. }
		if ( GearMaxArmor( Part ) > 0 ) then begin
			Armor := GearCurrentArmor( Part );

			{ Reduce armor protection if the target is rusty. }
			if HasStatus( PMaster , NAS_Rust ) then ARMOR := ARMOR div 2;

			{ Next, apply damage to the armor itself. }
			{ Calculate the maximum armor damage possible. }
			{ This is determined by the scale of the attack. }
			MAP := 2;
			if Scale > 0 then for AAP := 1 to Scale do MAP := MAP * 5;

			{ If the part is MetaTerrain, the maximum armor }
			{ penetration may well be reduced. If an attack can't }
			{ get through the armor, it can't do any damage at all. }
			{ This is to prevent the PC from knocking down doors with }
			{ a lot of low-power attacks. }
			if ( Part^.G = GG_MetaTerrain ) and ( DMG < Armor ) then begin
				MAP := 0;
			end;

			{ Decide upon actual armor damage. }
			{ This will be MUCH greater if the target is rusty. }
			if HasStatus( PMaster , NAS_Rust ) then begin
				AAP := DMG div 2;
			end else begin
				AAP := Random( DMG div 2 + 1 );
				if AAP > MAP then AAP := MAP;
			end;

			{ BRUTAL attacks double their armor penetration. }
			if HasAttackAttribute( AtAt , AA_Brutal ) then begin
				AAP := AAP * 2;
				if AAP < 3 then AAP := 3;
			end;

			{ HARDENED armor takes only half damage. }
			if IsHardened then begin
				AAP := AAP div 2;
			end;

			{ Record the current armor value, then record the armor damage. }
			if AAP > GearCurrentArmor( Part ) then AAP := GearCurrentArmor( Part );
			{ Nonlethal attacks don't affect armor. }
			if not HasAttackAttribute( AtAt , AA_NonLethal ) then AddNAtt(Part^.NA,NAG_Damage,NAS_ArmorDamage,AAP);

		end else begin
			{ It's possible that this part has no armor at all. }
			{ Cover that possibility here. }
			Armor := 0;
		end;

		{ Adjust armor for MOS, then reduce MOS. }
		if ( MOS > 0 ) and ( Armor > 0 ) then begin
			if MOS < 4 then Armor := ( Armor * ( 4 - MOS ) ) div 4
			else Armor := 0;
{			MOS := MOS - 4;}
			MOS := MOS - 2;
		end;

		{ Reduce the DMG variable by the current armor level. }
		DMG := DMG - Armor;
		if DMG < 0 then DMG := 0;
	end;

	Function SelectRandomModule( LList: GearPtr ): GearPtr;
		{ Select a module from LList at random. If no module is found, }
		{ return NIL. }
	var
		M: GearPtr;
		N: Integer;
	begin
		{ First, count the number of modules present. }
		N := 0;
		M := LList;
		while M <> Nil do begin
			if M^.G = GG_Module then Inc( N );
			M := M^.Next;
		end;

		{ Next, select one of the modules randomly. }
		if N > 0 then begin
			N := Random( N );
			M := LList;
			while ( M <> Nil ) and ( N > -1 ) do begin
				if M^.G = GG_Module then Dec( N );
				if N <> -1 then M := M^.Next;
			end;
		end;

		SelectRandomModule := M;
	end;

	Function REALDamageGear( Part: GearPtr; DMG: LongInt; MOS,Scale: Integer ): LongInt;
		{This is where the REAL damage process starts.}
	var
		XA: GearPtr;
		N: Integer;
	begin
		{ Increment the ITERATIONS value. }
		Inc( DAMAGE_Iterations );
		{ Do all damage thingies, unless we want to ignore damage. }
		if Not HasAttackAttribute( AtAt, AA_ArmorIgnore ) then begin
			{ If this is the first iteration, reduce the amount of damage done }
			{ by all armor values up to root level. This is so aimed shots at }
			{ sensors/etc won't ignore the armor of the module they're located in. }
			{ Note that only sub components get upwards armor protection- }
			{ externally mounted inv components don't. }
			if ( DAMAGE_Iterations = 1 ) and IsSubCom( Part ) then begin
				XA := Part^.Parent;
				while XA <> Nil do begin
					StagedPenetration( XA , DMG , MOS , Scale );
					XA := XA^.Parent;
				end;
			end;

			{ If this is a character, apply staged penetration randomly }
			{ to the armor of one limb. }
			if ( Part^.G = GG_Character ) then begin
				XA := SelectRandomModule( Part^.SubCom );
				if XA <> Nil then StagedPenetration( XA , dmg , MOS , Scale );
			end;

			{Reduce the amount of damage by the armor rating of}
			{this gear, and do damage to the armor.}
			StagedPenetration( Part , dmg , MOS , Scale );
		end;

		if DMG > 0 then begin
			{If the damage made it through the armor, apply it to}
			{whatever's on the inside.}

			{ Increase damage by excess margin of success. }
			if ( MOS > 0 ) and ( GearMaxDamage(Part) <> -1 ) then begin
				{ Each extra point of MOS will increase damage }
				{ by 20%. }
				DMG := ( DMG * ( 5 + MOS ) ) div 5;
				MOS := 0;
			end;

			{Depending upon what the part we are damaging is, we}
			{might apply damage here or pass it on to a subcomponent.}
			N := NumActiveGears(Part^.SubCom);

			if N > 0 then begin
				{There are subcomponents. Either damage this}
				{part directly, or pass damage on to a subcom.}
				if (GearMaxDamage(Part) = -1) or ( Random(100) = 23 ) then begin
					{Damage a subcomponent. Time for recursion.}
					DMG := REALDamageGear( FindActiveGear(Part^.SubCom,Random(N)+1), DMG , MOS , Scale );

				end else if (Random(3) = 1) then begin
					{ Apply half the damage to this component, }
					{ and half the damage to its children. }
					ApplyDamage( Part,DMG div 2);

					{ Recalculate the number of active subcomponents, as it may have changed. }
					N := NumActiveGears(Part^.SubCom);
					if N > 0 then begin
						DMG := ( DMG div 2 ) + REALDamageGear( FindActiveGear(Part^.SubCom,Random(N)+1), (DMG+1) div 2 , MOS , Scale );
					end else begin
						{ Apply all damage against this part. }
						ApplyDamage( Part , ( DMG + 1 ) div 2 );
					end;

				end else begin
					ApplyDamage( Part , DMG );
				end;

			end else begin
				{There are no subcomponents. Damage this}
				{module directly.}
				ApplyDamage( Part , DMG );
			end;

		end else if DMG < 0 then begin
			{ We don't want this procedure reporting Damage less than }
			{ zero, because that's silly. }
			DMG := 0;
		end;

		REALDamageGear := DMG;
	end;

	Function NonlethalDamageGear( Part: GearPtr; DMG: LongInt; MOS,Scale: Integer ): LongInt;
		{This is where the REAL damage process starts, for nonlethal damage.}
	var
		XA: GearPtr;
	begin
		{ Reduce the damage based on the target's armor value. }
		StagedPenetration( Part , DMG , MOS , Scale );

		{ We know this is a character, so reduce by the armor value of one randomly }
		{ selected limb. }
		if ( Part^.G = GG_Character ) then begin
			XA := SelectRandomGear( Part^.SubCom );
			if XA <> Nil then StagedPenetration( XA , dmg , MOS , Scale );
		end;

		if DMG > 0 then begin
			{If the damage made it through the armor, apply it to}
			{whatever's on the inside.}

			{ Increase damage by excess margin of success. }
			if ( MOS > 0 ) then begin
				{ Each extra point of MOS will increase damage }
				{ by 25%. }
				DMG := ( DMG * ( 4 + MOS ) ) div 4;
				MOS := 0;
			end;

			AddStaminaDown( Part , DMG );

		end else if DMG < 0 then begin
			{ We don't want this procedure reporting Damage less than }
			{ zero, because that's silly. }
			DMG := 0;
		end;

		NonlethalDamageGear := DMG;
	end;

	Function ConcussionDamageAmount( Part , Weapon: GearPtr; Dmg , Scale: Integer ): Integer;
		{ Determine the amount of concussive damage this attack could }
		{ potentially apply to the soft bits of the mecha. }
	var
		it,MS: Integer;
	begin
		{ Base concussion chance is equal to the damage class of }
		{ the weapon. }
		it := Dmg; 

		{ Missiles and Melee Weapons do more concussion than normal. }
		if ( Weapon <> Nil ) then begin
			if Weapon^.G = GG_Weapon then begin
				if ( Weapon^.S = GS_Missile ) then begin
					it := it + MissileConcussion;
				end else if ( Weapon^.S = GS_Melee ) then begin
					it := it + MeleeConcussion;
				end;
			end else if Weapon^.G = GG_Module then begin
				it := it + ModuleConcussion;
			end;
		end;

		{ If the weapon scale is greater than the target scale, }
		{ more concussion is done. }
		if Scale > Part^.Scale then it := it * ( Scale - Part^.Scale + 1 )
		else if Scale < Part^.Scale then it := it div ( Part^.Scale - Scale + 3 );

		{ Determine the master size of the target. }
		MS := MasterSize( Part );
		if MS < 1 then MS := 1;

		ConcussionDamageAmount := it div MS;
	end;

	Function ApplyConcussion( Part: GearPtr; CDC: Integer; AutoDamage: Boolean ): Integer;
		{ Concussion damage is force from the impact which is passed }
		{ on to the soft parts of a mecha- i.e. its pilot. It can also }
		{ be passed on to inventory items, since these are outside }
		{ of the armor's protection. }
		{ Return the amount of damage done. }
		Function ACNow: Integer;
			{ Apply the concussion damage to PART now. }
			{ Return the amount of damage done. }
		var
			D: Integer;
		begin
			D := Random( CDC + 1 );
			if ( D > 0 ) and NotDestroyed( Part ) then ApplyDamage( Part , D );
			ACNow := D;
		end;
	var
		P2: GearPtr;
		Total: Integer;
	begin
		{ Initialize TOTAL to 0. }
		Total := 0;

		{ If this part is succeptable to concussion damage, }
		{ apply the damage. }
		if ( Part^.G = GG_Character ) and ( Part^.Parent <> Nil ) and ( Random( 100 ) < DamagePilotChance ) then begin
			Total := Total + ACNow;
		end else if AutoDamage and ( Random( 100 ) < DamageInventoryChance ) then begin
			Total := Total + ACNow;
		end;

		{ Check all sub- and inv- components of this part. }
		{ Automatically damage the inventory components. }
		P2 := Part^.SubCom;
		while P2 <> Nil do begin
			Total := Total + ApplyConcussion( P2 , CDC , False );
			P2 := P2^.Next;
		end;
		P2 := Part^.InvCom;
		while P2 <> Nil do begin
			Total := Total + ApplyConcussion( P2 , CDC , True );
			P2 := P2^.Next;
		end;

		ApplyConcussion := Total;
	end;
var
	P2: GearPtr;
	Total,T,Scale,TPDmg0: LongInt;
	TMaster,TPilot: GearPtr;
	TMasterOK,TPilotOK,OKatStart: Boolean;
	MobileAtStart: Boolean;
begin
	{ Initialize History Variables. }
	DR.EjectRoll := False;
	DR.EjectOK := False;
	DR.PilotDied := False;
	DR.MechaDestroyed := False;
	DR.DamageDone := 0;
	DAMAGE_OverKill := 0;
	DAMAGE_Iterations := 0;
	DisposeSAtt( Destroyed_Parts_List );

	TMaster := FindRoot( O_Part );
	TPilot := LocatePilot( TMaster );
	TMasterOK := ( TMaster <> TPilot ) and NotDestroyed( TMaster );
	TPilotOK := NoTDestroyed( TPilot );
	OKatStart := TMasterOK or TPilotOK;
	if TPilot <> Nil then TPDmg0 := AmountOfDamage( TPilot , False );

	MobileAtStart := CurrentMoveRate( GB^.Scene , TMaster ) > 0;

	{ Make sure at least one hit will be caused. }
	if O_NumHits < 1 then O_NumHits := 1;

	{ Reset total damage done to 0. }
	Total := 0;

	{ Determine the scale of the attack - this info is needed for }
	{ rolling damage. If no weapon was used, this was probably a }
	{ crash or other self-inflicted injury. Use the target's own }
	{ scale against it. }
	if O_Weapon = Nil then Scale := O_Part^.Scale
	else begin
		Scale := O_Weapon^.Scale;

		{ Area effect weapons deal scatter damage. }
		{ Scatter weapons do full damage against props and metaterrain. }
		if HasAreaEffect( AtAt ) and ( O_Part^.G <> GG_MetaTerrain ) and ( O_Part^.G <> GG_Prop ) then begin
			O_NumHits := O_NumHits * O_DMG;
			O_DMG := 1;
		end;
	end;

	{ Call the REAL procedure. }
	{ If this is a nonlethal attack and the target is a character and the target also }
	{ has some stamina remaining, use the special NonLethal attack procedure. }
	if HasATtackAttribute( AtAt , AA_NonLethal ) and ( TMaster^.G = GG_Character ) and ( CurrentStamina( TMaster ) > 0 ) then begin
		if NAttValue( TMaster^.NA , NAG_GearOps , NAS_Material ) = NAV_Meat then begin
			for T := 1 to O_NumHits do begin
				Total := Total + NonlethalDamageGear( TMaster ,  RollDamage(O_DMG,Scale) , O_MOS , Scale );
			end;
		end else begin
			{ Against something not made of meat, a nonlethal attack does but }
			{ a single point of damage. }
			Total := REALDamageGear( O_Part , 1 , O_MOS , Scale );
		end;

	end else if ( O_Weapon <> Nil ) and HasAttackAttribute( AtAt , AA_Hyper ) then begin
		{ If the root part has a damage score, it gets hit. }
		if ( GearMaxDamage( O_Part ) > -1 ) then begin
			for T := 1 to O_NumHits do begin
				Total := Total + REALDamageGear( O_Part , RollDamage(O_DMG,Scale) , O_MOS , Scale );
			end;
		end;

		{ Each subcomponent then gets hit individually. }
		for T := 1 to O_NumHits do begin
			P2 := O_Part^.SubCom;
			while P2 <> Nil do begin
				Total := Total + REALDamageGear( P2 , RollDamage(O_DMG,Scale) , O_MOS , Scale );
				P2 := P2^.Next;
			end;
		end;

	end else begin
		{ Normal damage. }
		for T := 1 to O_NumHits do begin
			Total := Total + REALDamageGear( O_Part , RollDamage(O_DMG,Scale) , O_MOS , Scale );
		end;
	end;

	{ Do concussion damage as appropriate. }
	T := ConcussionDamageAmount( O_Part , O_Weapon , O_Dmg , Scale );
	if ( T > 0 ) then Total := Total + ApplyConcussion( O_Part , T , False );

	{ Do overkill damage to the root torso. }
	if DAMAGE_OverKill > 0 then begin
		O_Part := FindRoot( O_Part );
		if ( O_Part^.G = GG_Mecha ) and ( O_Part^.SubCom <> Nil ) then begin
			{ For mecha, overkill damage goes directly to the torso. }
			O_Part := O_Part^.SubCom;
			while ( O_Part <> Nil ) and ( O_Part^.S <> GS_Body ) do O_Part := O_Part^.Next;
			if O_Part <> Nil then begin
				Total := Total + REALDamageGear( O_Part , DAMAGE_OverKill , O_MOS div 2 , Scale );
			end;
		end else begin
			{ Apply damage directly to the part. }
			Total := Total + REALDamageGear( O_Part , DAMAGE_OverKill , 0 , Scale );
		end;
	end;

	DR.DamageDone := Total;

	{ A surrendered gear that takes damage will un-surrender. }
	if ( Total > 0 ) and ( NAttValue( TMaster^.NA , NAG_EpisodeData , NAS_SurrenderStatus ) = NAV_NowSurrendered ) then begin
		SetNAtt( TMaster^.NA , NAG_EpisodeData , NAS_SurrenderStatus , NAV_ReAttack );
		AddNAtt( TMaster^.NA , NAG_StatusEffect , NAS_Enraged , 10 + Random( 20 ) );
	end;

	DR.PilotDied := TPilotOK and Destroyed( TPilot );
	DR.MechaDestroyed := TMasterOK and not GearOperational( TMaster );

	{ Check for explosions here. }
	if OkAtStart and Destroyed( TMaster ) then begin
		if ( SAttValue( TMaster^.SA , SA_Explosion ) <> '' ) then begin
			SetNAtt( TMaster^.NA , NAG_Action , NAS_WillExplode , 1 );
		end;
		if NAttValue( TMaster^.NA , NAG_GearOps , NAS_CorpseOp ) = NAV_NoCorpse then begin
			SetNAtt( TMaster^.NA , NAG_Action , NAS_WillDisappear , 1 );
		end;
	end;

	{ Give experience for Vitality here. }
	if ( TPilot <> Nil ) and NotDestroyed( TPilot ) then begin
		{ Determine the change in damage status for the pilot. }
		TPDmg0 := AmountOfDamage( TPilot , False ) - TPDmg0;

		{ Taking damage trains vitality... }
		{ As long as the character survives, that is. }
		if TPDmg0 > 0 then begin
			{ Give an amount of experience equal to the amount of damage }
			{ taken squared, but no more than enough to raise Vitality by one }
			{ level. }
			TPDmg0 := TPDmg0 * TPDmg0 + 4;
			T := SkillAdvCost( Nil , NAttValue( TPilot^.NA , NAG_Skill , NAS_Vitality ) );
			if TPDmg0 > T then TPDmg0 := T;
			DoleSkillExperience( TPilot , NAS_Vitality , TPDmg0 );
		end;
	end;

	if MobileAtStart and ( CurrentMoveRate( GB^.Scene , TMaster ) = 0 ) and NotDestroyed( TMaster ) then begin
		Crash( GB , TMaster );
	end;

	DamageGear := DR;
end;

Function DamageGear( gb: GameBoardPtr; Part: GearPtr; DMG: Integer): DamageRec;
	{ Apply damage without a Margin Of Success. }
begin
	DamageGear := DamageGear( gb , Part , Nil , DMG , 0 , 1 , '' );
end;

procedure Crash( gb: GameBoardPtr; Mek: GearPtr );
	{ This mek has just become incapable of moving. Crash it. }
var
	MM,MA,DMG: Integer;	{ Move Mode and Move Action }
	MT: LongInt;
	P: Point;
begin
	{ Make sure we have the root gear. }
	Mek := FindRoot( Mek );
	P := GearCurrentLocation( Mek );

	{ Determine both the move mode and the move action for this mek. }
	MM := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	MA := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );

	{ Pass on appropriate info to the damage procedure. }
	{ The amount of damage done and the number of hits depends upon }
	{ the move mode and move action. }
	if ( MM > 0 ) and ( MM <= NumMoveMode ) then begin
		{ The movemode this mek has is legal. }
		Case MM of
			MM_Walk: DMG := 1;
			MM_Roll: DMG := 1;
			MM_Skim: DMG := 2;
			MM_Fly: DMG := 5;
			else DMG := 1;
		end;
	end else begin
		{ The movemode this mek has isn't legal. }
		DMG := 1;
	end;

	if MA = NAV_FullSpeed then DMG := DMG * 5
	else if MA = NAV_NormSpeed then DMG := DMG * 3
	else DMG := DMG * 2;

	{ Note that mecha only take damage from a crash in space if they're blocked. }
	if MoveBlocked( Mek , GB ) or ( TileTerrain( GB , P.X , P.Y ) <> TERRAIN_SPACE ) then begin
		SetNAtt( Mek^.NA , NAG_Action , NAS_WillCrash , DMG );
		SetNAtt( Mek^.NA, NAG_Action , NAS_DriftSpeed , 0 );
	end;

	MT := NAttValue( Mek^.NA , NAG_Action , NAS_MoveETA );

	SetNAtt( Mek^.NA, NAG_Action , NAS_MoveAction , NAV_Stop );
	SetNAtt( Mek^.NA, NAG_Action , NAS_TimeLimit , 0 );
	SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , MT + 1000 );
	SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ClicksPerRound );
end;

Procedure DoActionSetup( GB: GameBoardPtr; Mek: GearPtr; Action: Integer );
	{ Perpare all of the mek's data structures for the action }
	{ being undertaken. }
begin
	if ( Action = NAV_Stop ) or ( Action = NAV_Hover ) or ( CPHMoveRate( GB^.Scene , Mek , GB^.Scale ) = 0 ) then begin
		if NAttValue( Mek^.NA , NAG_Action , NAS_DriftSpeed ) > 0 then begin
			{ Stopping in space takes more time than just stopping elsewhere. }
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveAction , Action );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , Max( CalcMoveTime( Mek , GB ) , ReactionTime( Mek ) ) + GB^.ComTime + 1 );
			SetNAtt( Mek^.NA , NAG_Action , NAS_DriftSpeed , 0 );

		end else if NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction ) = NAV_Stop then begin
			{ The mek is already stopped. Wait one round before calling again. }
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ( ClicksPerRound div 5 ) );

		end else begin
			{ The mek is currently moving but it wants to stop. }
			if ( Action <> NAV_Stop ) and ( Action <> NAV_Hover ) then Action := NAV_Stop;
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveAction , Action );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + 1 );
		end;

		{ Reset the jumping time limit. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );

	end else if ( Action = NAV_NormSpeed ) or ( Action = NAV_Reverse ) then begin
		{ Move foreword. }
		if NAttValue( Mek^.NA , NAG_Action, NAS_MoveAction ) <> Action then begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveACtion , Action );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , CalcMoveTime( Mek , GB ) + GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , CalcMoveTime( Mek , GB ) + GB^.ComTime );
		end else begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , NAttValue( Mek^.NA , NAG_Action , NAS_MoveETA ) + 1 );
		end;

		{ If jumping, set the jump time limit. }
		if ( NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) = MM_Fly ) and ( JumpTime( GB^.Scene , Mek ) > 0 ) then begin
			{ If this jump is just starting, set the time limit and recharge time now. }
			if NAttValue( Mek^.NA , NAG_Action , NAS_TimeLimit ) = 0 then begin
				SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , GB^.ComTime + JumpTime( GB^.Scene , Mek ) );
				SetNAtt( Mek^.NA , NAG_Action , NAS_JumpRecharge , GB^.ComTime + Jump_Recharge_Time );
			end;
		end else begin
			{ Reset the jumping time limit. }
			SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );
		end;

	end else if Action = NAV_FullSpeed then begin
		{ Move foreword, quickly. }
		if NAttValue( Mek^.NA , NAG_Action, NAS_MoveAction ) <> NAV_FullSpeed then begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveACtion , NAV_FullSpeed );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , CalcMoveTime( Mek , GB ) + GB^.ComTime );
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , CalcMoveTime( Mek , GB ) + GB^.ComTime );
		end else begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , Max( NAttValue( Mek^.NA , NAG_Action , NAS_MoveETA ) + 1 , ReactionTime( Mek ) div 2 + GB^.ComTime ) );
		end;

		{ Reset the jumping time limit. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );

	end else if Action = NAV_TurnLeft then begin
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveACtion , NAV_TurnLeft );
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , CalcMoveTime( Mek , GB ) + GB^.ComTime );
		SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , Max( CalcMoveTime( Mek , GB ) , ReactionTime( Mek ) div 2 ) + GB^.ComTime );

		{ Reset the jumping time limit. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );

	end else if Action = NAV_TurnRight then begin
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveACtion , NAV_TurnRight );
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , CalcMoveTime( Mek , GB ) + GB^.ComTime );
		SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , Max( CalcMoveTime( Mek , GB ) , ReactionTime( Mek ) div 2 ) + GB^.ComTime );

		{ Reset the jumping time limit. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );

	end;
end;

Procedure PrepAction( GB: GameBoardPtr; Mek: GearPtr; Action: Integer );
	{ Given an action, prepare all of the mek's values for it. }
begin
	if MoveLegal( GB^.Scene , Mek , Action , GB^.ComTime ) or ( CurrentMoveRate( GB^.Scene , Mek ) = 0 ) then begin
		DoActionSetup( GB , Mek , Action );
	end else begin
		if Action = NAV_Stop then begin
			if MoveLegal( GB^.Scene , Mek , NAV_NormSpeed , GB^.ComTime ) then begin
				DoActionSetup( GB , Mek , NAV_NormSpeed );
			end else begin
				Crash( GB , Mek );
			end;
		end else begin
			if MoveLegal( GB^.Scene , Mek , NAV_Stop , GB^.ComTime ) then begin
				DoActionSetup( GB , Mek , NAV_Stop );
			end else begin
				Crash( GB , Mek );
			end;
		end;
	end;
end;

Procedure SetMoveMode( GB: GameBoardPtr; Mek: GearPtr; MM: Integer );
	{ Set the requested movement mode. If this sets the mode to Jump, }
	{ the mecha will come to a halt. }
begin
	SetNAtt( Mek^.NA , NAG_Action , NAS_MoveMode , MM);
	if ( MM = MM_Fly ) and ( JumpTime( GB^.Scene , Mek ) > 0 ) then SetNAtt( Mek^.NA , NAG_Action , NAS_MoveAction , NAV_Stop );
end;

Procedure DoMoveTile( Mek: GearPtr; GB: GameBoardPtr );
	{ This mek is about to move foreword. Process the movement. }
	{ Also, check for other meks in the target hex, and do a }
	{ charge if necessary. }
	{ If the mek moves off the map, it has fled the game. }
var
	P: Point;
begin
	{ Find out the gear's destination. }
	P := GearDestination( Mek );

	{ If the destination isn't on the map, and this model isn't a player model, and it is in control }
	{ of its actions, and it's not running away, disallow the move. }
	if ( not OnTheMap( GB , P.X , P.Y ) ) and ( not Confused( Mek ) ) and ( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) <> NAV_DefPlayerTeam ) and ( NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Orders ) <> NAV_RunAway ) then begin
		{ Set ETA for next move. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , GB^.ComTime + ReactionTime( Mek ) );
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
		Exit;
	end;

	{ Set the mek's position to its new value. }
	SetNAtt( Mek^.NA , NAG_Location , NAS_X , P.X );
	SetNAtt( Mek^.NA , NAG_Location , NAS_Y , P.Y );

	{ If moving in microgravity, set the drift values. }
	{ Drift only happens if the model is at the same scale or larger than the map. }
	if OnTheMap( GB , P.X , P.Y ) and ( GB^.Scene <> Nil ) and ( NAttValue( GB^.Scene^.NA , NAG_EnvironmentData , NAS_Gravity ) = NAV_Microgravity ) and ( Mek^.Scale >= GB^.Scale ) then begin
		SetNAtt( Mek^.Na , NAG_Action , NAS_DriftVector , NAttValue( Mek^.NA , NAG_Location , NAS_D ) );
		SetNAtt( Mek^.NA , NAG_Action , NAS_DriftSpeed , GB^.ComTime - NAttValue( Mek^.NA , NAG_Action , NAS_MoveStart ) );
		SetNAtt( Mek^.NA , NAG_Action , NAS_DriftETA , GB^.ComTime + NAttValue( Mek^.NA , NAG_Action , NAS_DriftSpeed ) );
	end;

	{ If moving at top speed, set stamina drain. }
	if ( Mek^.G = GG_Character ) and ( NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction ) = NAV_FullSpeed ) then begin
		AddStaminaDown( Mek , 1 );
	end;

	{ Set ETA for next move. }
	SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , GB^.ComTime + CalcMoveTime( Mek , GB ) );
	SetNAtt( Mek^.NA , NAG_Action , NAS_MoveStart , GB^.ComTime );
end;

Procedure DoTurn( Mek: GearPtr; GB: GameBoardPtr );
	{ The mek is turning. Make it so, Mister Laforge. }
var
	cmd: Integer;	{The exact command issued.}
	D: Integer;	{The direction of the mek.}
	CallTime,DriftSpeed: LongInt;
begin
	{ Determine whether the mek is turning left or right. }
	cmd := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );

	{ Determine the direction the mek is currently facing. }
	D := NAttValue( Mek^.NA , NAG_Location , NAS_D );

	if cmd = NAV_TurnLeft then begin
		D := D - 1;
		if D < 0 then D := 7;
	end else begin
		D := D + 1;
		if D > 7 then D := 0;
	end;

	{ Set the direction to the modified value. }
	SetNAtt( Mek^.NA , NAG_Location , NAS_D , D );

	{ Set the mek's movement to Stop, and call the action selector. }
	if MoveLegal( GB^.Scene , Mek , NAV_Hover , GB^.ComTime ) then begin
		PrepAction( GB , Mek , NAV_Hover );
	end else begin
		{ The stop called after a turn will not affect the calltime or }
		{ the drift vector. }
		CallTime := NAttValue( Mek^.NA , NAG_Action , NAS_CallTime );
		DriftSpeed := NAttValue( Mek^.NA , NAG_Action , NAS_DriftSpeed );
		PrepAction( GB , Mek , NAV_Stop );
		SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , CallTime );
		SetNAtt( Mek^.NA , NAG_Action , NAS_DriftSpeed , DriftSpeed );
	end;
end;

Function CrashTarget( Alt0,Alt1,Order: Integer ): Integer;
	{ Return the target number to avoid a crash if a mecha is }
	{ traveling from Alt0 to Alt1 with movement order Order. }
var
	it: Integer;
begin
	if Alt0 <= ( Alt1 + 1 ) then begin
		it := 7;
	end else begin
		it := ( Alt0 - ALt1 - 1 ) * 8 + 4;
	end;
	if Order <> NAV_FullSpeed then it := it - 5;
	CrashTarget := it;
end;

Procedure MaybeCharge( GB: GameBoardPtr; Mek: GearPtr );
	{ This mecha is blocked by something. If it's another mecha, maybe }
	{ do a charge attack. }
var
	D: Point;
	Target: GearPtr;
begin
	{ If the mek exists, it's bigger than SF:0, and it's moved at least one tile, }
	{ then it might be ready for a charge attack. }
	if ( Mek <> Nil ) and ( Mek^.Scale > 0 ) and ( NAttValue( Mek^.NA , NAG_Action , NAS_TilesInARow ) > 0 ) then begin
		D := GearDestination( Mek );
		Target := FindBlockerXYZ( GB , D.X , D.Y , MekAltitude( GB , Mek ) );
		if ( Target <> Nil ) and AreEnemies( GB , Mek , Target ) then begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_WillCharge , NAttValue( Target^.NA , NAG_EpisodeData , NAS_UID ) );
			SetNAtt( Mek^.NA , NAG_Action , NAS_ChargeSpeed , Speedometer( GB^.Scene , Mek ) );
		end;
	end;
end;

Function EnactMovement( GB: GameBoardPtr; Mek: GearPtr ): Integer;
	{ The time has come for this mech to move. }
	{ This procedure checks to see what kind of movement is }
	{ taking place, decides whether the move should be }
	{ cancelled or delayed due to systems damage, then branches }
	{ to the appropriate procedures. }
	{ It returns 1 if the move was successful and the display }
	{ should be updated, 0 if no event took place, and -1 if }
	{ the mek in question crashed or was otherwise damaged. }
var
	ETA,Spd,StartTime,Order,Alt0,ALt1,SkRoll: LongInt;
	NeedRedraw: Integer;
	Pilot: GearPtr;
begin
	{ Note that this call to MoveThatMek might result in }
	{ no movement at all. It could be a wait call- an ETA }
	{ is set even if the mek's movemode is Inactive, or its }
	{ order is Stop. }

	NeedRedraw := 0;

	{ Locate all the important values for this mek. }
	ETA := NAttValue( Mek^.NA , NAG_Action , NAS_MoveETA );
	StartTime := NAttValue( Mek^.NA , NAG_Action , NAS_MoveStart );
	Order := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );
	Spd := CalcMoveTime( Mek , GB );

	if Order = NAV_Stop then begin
		{ The mek isn't going anywhere. This is a wait call. }
		{ Set the ETA to not call this procedure again for 1000 clicks. }

		{ The mek might not have an activated move mode for whatever reason. }
		if NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) = 0 then GearUp( Mek );

		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , ETA + 1000 );

		{ Clear the TilesInARow counter. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_TilesInARow , 0 );

	end else if ( NAttValue( Mek^.NA , NAG_Action , NAS_TimeLimit ) > 0 ) and ( NAttValue( Mek^.NA , NAG_Action , NAS_TimeLimit ) < GB^.ComTime ) then begin
		{ If the mek was jumping and overshot the time limit, }
		{ make it crash now. }
		if NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) = MM_Fly then begin
			Crash( GB , Mek );
			NeedRedraw := EMR_Crash;
			SetNAtt( Mek^.NA , NAG_Action , NAS_TilesInARow , 0 );
		end else begin
			{ If the time limit was overshot but the mek isn't }
			{ jumping, clear it now. }
			SetNAtt( Mek^.NA , NAG_Action , NAS_TimeLimit , 0 );
			SetNAtt( Mek^.NA , NAG_Action , NAS_TilesInARow , 0 );
		end;

	end else if MoveBlocked( Mek , GB ) then begin
		{ If the mecha is capable of stopping in time, then }
		{ stop. Otherwise it will crash into the obstacle. }
		if MoveLegal( GB^.Scene , Mek , NAV_Stop , GB^.ComTime ) then begin
			NeedRedraw := EMR_Blocked;
			MaybeCharge( GB , Mek );
			PrepAction( GB , Mek , NAV_Stop );
		end else begin
			MaybeCharge( GB , Mek );
			Crash( GB , Mek );
			NeedRedraw := EMR_Crash;
		end;

	end else if Spd = 0 then begin
		{ Movement mode has been disabled, or the mek }
		{ is blocked. In any case, this could be crash material. }
		Crash( GB , Mek );
		NeedRedraw := EMR_Crash;
		SetNAtt( Mek^.NA , NAG_Action , NAS_TilesInARow , 0 );

	end else if ( Mek^.G = GG_Character ) and ( Order = NAV_FullSpeed ) and ( CurrentStamina( Mek ) <= 0 ) then begin
		PrepAction( GB , Mek , NAV_NormSpeed );

	end else if (StartTime + Spd) <= ETA then begin
		{ Everything is proceeding according to schedule. }
		{ Actually process the movement. }

		{ Store the initial altitude, to see if the mecha will }
		{ require a piloting check to avoid crashing at the end. }
		Alt0 := MekAltitude( GB , Mek );

		case Order of
			NAV_NormSpeed,NAV_FullSpeed,NAV_Reverse:
				begin
				DoMoveTile( Mek , GB );
				if Order <> NAV_Reverse then AddNAtt( Mek^.NA , NAG_Action , NAS_TilesInARow , 1 );
				SetTrigger( GB , TRIGGER_TeamMovement + BStr( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) ) );
				Pilot := LocatePilot( Mek );
				if ( Pilot <> Nil ) and ( NAttValue( Pilot^.NA , NAG_Personal , NAS_CID ) <> 0 ) then SetTrigger( GB , TRIGGER_NPCMovement + BStr( NAttValue( Pilot^.NA , NAG_Personal , NAS_CID ) ) );
				end;
			NAV_TurnLeft,NAV_TurnRight:
				begin
				DoTurn( Mek , GB );
				SetNAtt( Mek^.NA , NAG_Action , NAS_TilesInARow , 0 );
				end;
		end;

		Alt1 := MekAltitude( GB , Mek );

		if ( Alt1 < ( Alt0 - 1 ) ) and ( NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) <> MM_Fly ) then begin
			if Mek^.G = GG_Mecha then begin
				SkRoll := RollStep( SkillValue( Mek , NAS_MechaPiloting , STAT_Speed ) );
			end else begin
				SkRoll := RollStep( SkillValue( Mek , NAS_Dodge , STAT_Speed ) );
			end;
			if SkRoll < CrashTarget( Alt0 , Alt1 , Order ) then begin
				Crash( GB , Mek );
				NeedRedraw := EMR_Crash;
			end else begin
				NeedRedraw := 1;
			end;
		end else begin
			NeedRedraw := 1;
		end;

	end else begin
		{ The mek has been delayed by damage, but not }
		{ immobilized. Set new ETA. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_MoveETA , StartTime + Spd );
	end;

	EnactMovement := NeedRedraw;
end;

Procedure DoDrift( GB: GameBoardPtr; Mek: GearPtr );
	{ This mecha is apparently in space, and it's going to drift. Do that now. }
var
	P1,P2: Point;
	Pilot: GearPtr;
	DD,MO: Integer;
begin
	DD := NAttValue( Mek^.NA , NAG_Action , NAS_DriftVector );
	MO := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );

	if ( DD <> NAttValue( Mek^.NA , NAG_Location , NAS_D ) ) or ( ( MO <> NAV_FullSpeed ) and ( MO <> NAV_NormSpeed ) ) then begin
		P1 := GearCurrentLocation( Mek );
		P2.X := P1.X + AngDir[ DD , 1 ];
		P2.Y := P1.Y + AngDir[ DD , 2 ];

		if MovementBlocked( Mek , GB , P1.X , P1.Y , P2.X , P2.Y ) then begin
			SetNAtt( Mek^.NA , NAG_Action , NAS_DriftSpeed , 0 );
		end else if OnTheMap( GB , P2.X , P2.Y ) then begin
			SetNAtt( Mek^.NA , NAG_Location , NAS_X , P2.X );
			SetNAtt( Mek^.NA , NAG_Location , NAS_Y , P2.Y );
			SetNAtt( Mek^.NA , NAG_Action , NAS_DriftETA , GB^.ComTime + NAttValue( Mek^.NA , NAG_Action , NAS_DriftSpeed ) );

			{ If this tile is "stable", stop drifting. }
			if ( GB^.Scene = Nil ) or ( NAttValue( GB^.Scene^.NA , NAG_EnvironmentData , NAS_Gravity ) <> NAV_Microgravity ) then SetNAtt( Mek^.NA , NAG_Action , NAS_DriftSpeed , 0 );

			SetTrigger( GB , TRIGGER_TeamMovement + BStr( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) ) );
			Pilot := LocatePilot( Mek );
			if ( Pilot <> Nil ) and ( NAttValue( Pilot^.NA , NAG_Personal , NAS_CID ) <> 0 ) then SetTrigger( GB , TRIGGER_NPCMovement + BStr( NAttValue( Pilot^.NA , NAG_Personal , NAS_CID ) ) );
		end;
	end;
end;

Procedure WaitAMinute( GB: GameBoardPtr; Mek: GearPtr; D: Integer );
	{ Force MEK to wait a short time, stopped if possible. }
var
	NextCall: LongInt;
begin
	Mek := FindRoot( Mek );
	NextCall := NAttValue( Mek^.NA , NAG_Action , NAS_CallTime );
	if ( GB <> Nil ) and ( NextCall < GB^.ComTime ) then NextCall := GB^.ComTime;
	NextCall := NextCall + D;
	if GB <> Nil then begin
		PrepAction( GB , Mek , NAV_Stop );
	end;
	SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , NextCall );
end;



initialization
	Destroyed_Parts_List := Nil;

finalization
	DisposeSAtt( Destroyed_Parts_List );

end.
