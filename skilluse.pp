unit SkillUse;
	{ This unit should cover the usage of skills for the RPG game. }
	{ Actually, it doesn't cover the usage of all skills- most of }
	{ them get implemented in other places (combat skills in the }
	{ attacker unit, conversation skills in the interact unit, etc). }
	{ This unit covers those skills which pretty well need their }
	{ own interface/code... repair skills, picking pockets, etc. }
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

uses gears,locale,ghchars;

const
	Repair_Mental_Strain = 1;
	Repair_Max_Tries = 5;

	Performance_Range = 9;
	Performance_Base_Cash = -50;

	TRIGGER_Applause = 'APPLAUSE';

	Repair_Skill_Needed: Array [0..NumMaterial] of Byte = (
		NAS_Repair, NAS_Medicine, NAS_Repair
	);



Function TotalRepairableDamage( Target: GearPtr; Material: Integer ): LongInt;
Procedure ApplyRepairPoints( Target: GearPtr; Material: Integer; var RP: LongInt; CureStatus: Boolean );
Procedure ApplyEmergencyRepairPoints( Target: GearPtr; Material: Integer; var RP: LongInt );
Function RepairNeededBySkill( Target: GearPtr; Skill: Integer ): LongInt;
Function CanRepairUsingSkill( NPC,Target: GearPtr; Skill: Integer ): Boolean;
Function UseRepairSkill( GB: GameBoardPtr; PC,Target: GearPtr; Skill: Integer ): Boolean;
Procedure DoCompleteRepair( Target: GearPtr );

Function SelectPerformanceTarget( GB: GameBoardPtr; PC: GearPtr ): GearPtr;
Function UsePerformance( GB: GameBoardPtr; PC,NPC: GearPtr ): LongInt;


implementation

uses ability,action,gearutil,ghholder,ghmodule,ghmovers,ghswag,
     ghweapon,movement,interact,rpgdice,texutil,narration,ghsupport;

Function TotalRepairableDamage( Target: GearPtr; Material: Integer ): LongInt;
	{ Search through TARGET, and calculate how much damage it has }
	{ that can be repaired using SKILL. }
var
	Part: GearPtr;
	AD,SD,TCom,SCom,it: LongInt;
	T: Integer;
begin
	{ Normally damage must be positive I know, but I just had a bug }
	{ which resulted in negative damage. This prevented the rest of }
	{ the damage to a mek/character from being repaired. So, taking }
	{ absolute value should fix all the mess & prevent it from }
	{ happening again. }
	SD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_StrucDamage ) );
	AD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_ArmorDamage ) );
	it := 0;

	{ If this part is damaged, and if the needed repair skill is }
	{ the skill we're looking for, add the damage to the total. }
	if NAttValue( Target^.NA , NAG_GearOps , NAS_Material ) = Material then begin
		it := AD + SD;

		{ Modify for complexity. }
		if not IsMasterGear( Target ) then begin
			TCom := ComponentComplexity( Target );
			SCom := SubComComplexity( Target );
			if SCom > TCom then begin
				it := ( it * SCom ) div TCom;
			end;
		end;

		{ Check for status effects. }
		for t := 1 to Num_Status_FX do begin
			if SX_Repairable[t] and ( NAttValue( Target^.NA , NAG_StatusEffect , T ) <> 0 ) then begin
				it := it + SX_RepCost[ T ];
			end;
		end;
	end;

	{ Check the sub-components for damage. }
	Part := Target^.SubCom;
	while Part <> Nil do begin
		it := it + TotalRepairableDamage( Part , Material );
		Part := Part^.Next;
	end;

	{ Check the inv-components for damage. }
	Part := Target^.InvCom;
	while Part <> Nil do begin
		it := it + TotalRepairableDamage( Part , Material );
		Part := Part^.Next;
	end;

	TotalRepairableDamage := it;
end;

Procedure ApplyRepairPoints( Target: GearPtr; Material: Integer; var RP: LongInt; CureStatus: Boolean );
	{ Search through TARGET, and restore DPs to parts }
	{ that can be repaired using SKILL. }
var
	Part: GearPtr;
	SD,AD,TCom,SCom,ARP,RPNeeded: LongInt;
	T: Integer;
begin
	{ Only examine TARGET for damage if it's of a type that can be }
	{ repaired using SKILL. }
	if NAttValue( Target^.NA , NAG_GearOps , NAS_Material ) = Material then begin
		{ Calculate structural damage and armor damage. }
		SD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_StrucDamage ) );
		if ( SD > 0 ) and ( RP > 0 ) then begin
			{ Modify for complexity. }
			ARP := RP;
			RPNeeded := SD;

			if not IsMasterGear( Target ) then begin
				TCom := ComponentComplexity( Target );
				SCom := SubComComplexity( Target );
				if SCom > TCom then begin
					RPNeeded := ( RPNeeded * SCom ) div TCom;
					ARP := ( ARP * TCom ) div SCom;
					if ARP < 1 then ARP := 1;
				end;
			end;

			SD := SD - ARP;
			RP := RP - RPNeeded;
			if SD < 0 then SD := 0;
			SetNAtt( Target^.NA , NAG_Damage , NAS_StrucDamage , SD );
		end;

		AD := Abs( NAttValue( Target^.NA , NAG_Damage , NAS_ArmorDamage ) );
		if ( AD > 0 ) and ( RP > 0 ) then begin
			{ Modify for complexity. }
			ARP := RP;
			RPNeeded := AD;

			if not IsMasterGear( Target ) then begin
				TCom := ComponentComplexity( Target );
				SCom := SubComComplexity( Target );
				if SCom > TCom then begin
					RPNeeded := ( RPNeeded * SCom ) div TCom;
					ARP := ( ARP * TCom ) div SCom;
					if ARP < 1 then ARP := 1;
				end;
			end;

			AD := AD - ARP;
			RP := RP - RPNeeded;
			if AD < 0 then AD := 0;
			SetNAtt( Target^.NA , NAG_Damage , NAS_ArmorDamage , AD );
		end;

		{ Check for status effects. }
		if CureStatus then begin
			for t := 1 to Num_Status_FX do begin
				if SX_Repairable[ t ] and ( NAttValue( Target^.NA , NAG_StatusEffect , T ) <> 0 ) then begin
					if RP >= SX_RepCost[ t ] then begin
						RP := RP - SX_RepCost[ t ];
						SetNAtt( Target^.NA , NAG_StatusEffect , T , 0 );
					end;
				end;
			end;
		end;
	end;

	{ Check the sub-components for damage. }
	Part := Target^.SubCom;
	while ( Part <> Nil ) and ( RP > 0 ) do begin
		ApplyRepairPoints( Part , Material , RP , CureStatus );
		Part := Part^.Next;
	end;

	{ Check the inv-components for damage. }
	Part := Target^.InvCom;
	while ( Part <> Nil ) and ( RP > 0 ) do begin
		ApplyRepairPoints( Part , Material , RP , CureStatus );
		Part := Part^.Next;
	end;
end;

Procedure ApplyEmergencyRepairPoints( Target: GearPtr; Material: Integer; var RP: LongInt );
	{ Try to apply the repair points first to those parts of TARGET nessecary }
	{ for it to function. If there are any points left over, apply these to the rest. }
	Procedure ApplyPointsToPart( G,S: Integer );
		{ Locate a part with the Gear G and S descriptors provided, }
		{ and apply repair points to it first. }
	var
		Part: GearPtr;
	begin
		Part := SeekGear( Target , G , S , False );
		if ( Part <> Nil ) and ( RP > 0 ) and Destroyed( Part ) then begin
			ApplyRepairPoints( Part, Material, RP, False );
		end;
	end;
begin
	if Target^.G = GG_Character then begin
		ApplyPointsToPart( GG_Module , GS_Head );
		ApplyPointsToPart( GG_Module , GS_Body );
		if RP > 0 then ApplyRepairPoints( Target, Material, RP, False );
	end else if Target^.G = GG_Mecha then begin
		ApplyPointsToPart( GG_Support , GS_Engine );
		ApplyPointsToPart( GG_Module , GS_Body );
		if RP > 0 then ApplyRepairPoints( Target, Material, RP, False );
	end else ApplyRepairPoints( Target, Material, RP, False );
	if RP > 0 then ApplyRepairPoints( Target, Material, RP, True );
end;

Function RepairNeededBySkill( Target: GearPtr; Skill: Integer ): LongInt;
	{ Return the amount of damage that can be affected by the listed skill. }
var
	T,Total,RP: Longint;
begin
	Total := 0;
	for t := 0 to NumMaterial do begin
		if ( Repair_Skill_Needed[ t ] = Skill ) then begin
			RP := TotalRepairableDamage( Target , T );
			if RP > 0 then Total := Total + RP;
		end;
	end;
	RepairNeededBySkill := Total;
end;

Function AmountOfRepairFuel( PC: GearPtr; Material: Integer ): LongInt;
	{ Return the total amount of repair fuel that the PC has. }
var
	Total: LongInt;
	Procedure SeekRFAlongTrack( LList: GearPtr );
	begin
		while LList <> Nil do begin
			if ( LList^.G = GG_RepairFuel ) and ( LList^.S = Material ) then begin
				Total := Total + LList^.V;
			end else begin
				SeekRFAlongTrack( LList^.SubCom );
				SeekRFAlongTrack( LList^.InvCom );
			end;
			LList := LList^.Next;
		end;
	end;
begin
	PC := FindRoot( PC );
	Total := 0;
	SeekRFAlongTrack( PC^.InvCom );
	SeekRFAlongTrack( PC^.SubCom );
	AmountOfRepairFuel := Total;
end;


Function CanRepairUsingSkill( NPC,Target: GearPtr; Skill: Integer ): Boolean;
	{ Return TRUE if this target has repairable damage which can be healed using SKILL, }
	{ and the NPC has the required repair fuel. Return FALSE otherwise. }
var
	CanRepair: Boolean;
	T,Total,RP: Longint;
begin
	CanRepair := False;
	for t := 0 to NumMaterial do begin
		if ( Repair_Skill_Needed[ t ] = Skill ) then begin
			RP := TotalRepairableDamage( Target , T );
			if RP > 0 then begin
				{ Alright, we found some damage to repair. }
				{ Check for repair fuel. }
				if AmountOfRepairFuel( NPC , T ) > 0 then CanRepair := True;
			end;
		end;
	end;
	CanRepairUsingSkill := CanRepair;
end;

Function UseRepairSkill( GB: GameBoardPtr; PC,Target: GearPtr; Skill: Integer ): Boolean;
	{ The PC wants to use the requested repair SKILL on TARGET. }
	{ Roll to see how many DPs will be restored, apply these DPs }
	{ to the TARGET, then reduce PC's MPs. }
	{ Return TRUE if the repair process went smoothly, or FALSE if it was }
	{ halted due to a shortage of materials. Note that this procedure will return }
	{ TRUE in the case of a critical failure even if the PC has no repair fuel. }
	Function Repair_Skill_Target: Integer;
		{ Return a good skill target for repair skills. }
		{ This will be decreased as TARGET's scale increases. }
	var
		RST: Integer;
	begin
		if Target^.Scale = 0 then begin
			RST := 4;
		end else if Target^.Scale = 1 then begin
			RST := 3;
		end else begin
			RST := 2;
		end;
		if Destroyed( Target ) then RST := RST + 3;
		Repair_Skill_Target := RST;
	end;
	Procedure SpendRepairFuel( PC: GearPtr; Material , RP: LongInt );
		{ Spend the requested repair fuel. If any fuel is depleted, }
		{ remove it from the inventory. }
		Procedure SpendRFAlongTrack( LList: GearPtr );
			{ Search for repair fuel to use, then use it. }
		var
			L2: GearPtr;
		begin
			while ( LList <> Nil ) and ( RP > 0 ) do begin
				L2 := LList^.Next;

				if ( LList^.G = GG_RepairFuel ) and ( LList^.S = Material ) then begin
					if RP >= LList^.V then begin
						RP := RP - LList^.V;
						if IsInvCom( LList ) then RemoveGear( LList^.Parent^.InvCom , LList )
						else RemoveGear( LList^.Parent^.SubCom , LList );
					end else begin
						LList^.V := LList^.V - RP;
						RP := 0;
					end;
				end else begin
					SpendRFAlongTrack( LList^.SubCom );
					SpendRFAlongTrack( LList^.InvCom );
				end;
				LList := L2;
			end;
		end;
	begin
		PC := FindRoot( PC );
		SpendRFAlongTrack( PC^.InvCom );
		SpendRFAlongTrack( PC^.SubCom );
	end;
	Function ActivateRepair( Material: Integer; var SkRoll: Integer ): Boolean;
		{ Activate the repair. Return the number of repair points used. }
		{ Reduce SkRoll by this same amount. }
		{ Return TRUE if repairfuel was found for this repair job, or FALSE }
		{ if no repair at all could take place. }
	var
		RP: LongInt;
		RepairFuel: LongInt;
		RFFound: Boolean;
	begin
		RP := TotalRepairableDamage( Target , Material );
		RFFound := False;
		{ Locate the repair fuel. }
		RepairFuel := AmountOfRepairFuel( PC , Material );

		if RepairFuel > 0 then begin
			{ The amount of damage recovered will not exceed the skill roll * 2. }
			if RP > ( SkRoll * 2 ) then RP := ( SkRoll * 2 );

			{ Nor will it exceed the amount of repair fuel. }
			if RP > RepairFuel then RP := RepairFuel;

			{ The skill roll will be reduced by the amount of damage to be repaired. }
			SkRoll := SkRoll - ( RP div 2 );

			{ Spend the repair fuel. }
			SpendRepairFuel( PC , Material , RP );

			{ Apply the repair points. }
			ApplyRepairPoints( Target , Material , RP , True );
			RFFound := True;
		end;
		ActivateRepair := RFFound;
	end;
var
	RP: LongInt;
	T,tries,SkRoll,SkTar,PercentDamage: Integer;
	IsSafeRepair,HadRepairFuel: Boolean;
	TMaster: GearPtr;
begin
	{ First, locate the PC. }
	PC := LocatePilot( PC );
	if PC = Nil then Exit( False );

	TMaster := FindMaster( Target );
	if TMaster = Nil then TMaster := Target;
	PercentDamage := PercentDamaged( TMaster );

	{ Depending upon the situation, this repair will either fix some damage or all the }
	{ damage in one go. If in a safe area and repairing a mecha which is not currently in play, }
	{ the entire thing can be fixed. On the other hand, if in a dangerous area or working on a }
	{ mecha which is in play, only a limited amount of DP will be restored. }
	{ If the target is destroyed, this never counts as a safe repair. }
	IsSafeRepair := IsSafeArea( GB ) and ( not OnTheMap( GB , FindRoot( Target ) ) ) and ( ( TMaster = Nil ) or NotDestroyed( TMaster ) );

	{ Assume we have no repair fuel, unless we find some. }
	HadRepairFuel := False;

	{ Make a skill roll against the base difficulty number. This will determine the rate }
	{ at which points may be restored. }
	SkTar := Repair_Skill_Target;
	SkRoll := SkillRoll( GB , PC , Skill , STAT_Craft , SkTar , 0 , IsSafeArea( GB ) , True ) - SkTar;

	tries := 1;

	if IsSafeRepair then begin
		{ Safe repairs get a bonus to the repair rate, since you don't have to worry }
		{ about people shooting at you. This bonus also helps to mitigate the effect of }
		{ high and low skill rolls. }
		SkRoll := SkRoll + SkillValue( PC , Skill , STAT_Craft );
		if SkRoll < 5 then SkRoll := 5;

		{ Because a safe repair will repair everything in one go, call the }
		{ repair activator with an arbitrarily huge skillroll. }
		for t := 0 to NumMaterial do begin
			RP := TotalRepairableDamage( Target , T );
			if ( Repair_Skill_Needed[ t ] = Skill ) and ( RP > 0 ) then begin
				tries := tries + RP div SkRoll;
				SkTar := 10000;
				HadRepairFuel := HadRepairFuel or ActivateRepair( T , SkTar );
			end;
		end;

		{ Don't make the PC wait for longer than 10 actions. }
		if tries > 10 then tries := 10;

	end else if SkRoll > 0 then begin
		{ Apply the skill roll against all legal materials. }
		for t := 0 to NumMaterial do begin
			RP := TotalRepairableDamage( Target , T );
			if ( Repair_Skill_Needed[ t ] = Skill ) and ( RP > 0 ) and ( SkRoll > 0 ) then begin
				HadRepairFuel := HadRepairFuel or ActivateRepair( T , SkRoll );
			end;
		end;

	end else begin
		{ The repair attempt failed. }
		{ At this point repair fuel is a moot point, so return TRUE. }
		HadRepairFuel := True;
	end;

	{ If you fail to revive a dead character, there's not much else you can do. }
	if ( TMaster <> Nil ) and ( TMaster^.G = GG_Character ) and Destroyed( TMaster ) and HadRepairFuel then begin
		AddNAtt( TMaster^.NA , NAG_Damage , NAS_StrucDamage , 30 );
	end;

	{ Determine the percentage of damage repaired. This will determine the XP award. }
	PercentDamage := PercentDamaged( TMaster ) - PercentDamage;
	if ( PercentDamage > 0 ) and IsMasterGear( TMaster ) then begin
		DoleExperience( PC , PercentDamage div 2 );
		DoleSkillExperience( PC , Skill , ( PercentDamage + 1 ) div 2 );
	end;

	{ Using repair takes time and concentration. }
	WaitAMinute( GB , PC , ReactionTime( PC ) * Tries );
	AddMentalDown( PC , Tries + Random( 3 ) );

	UseRepairSkill := HadRepairFuel;
end;


Procedure DoCompleteRepair( Target: GearPtr );
	{ Repair everything that can be repaired on Target. }
	{ Basically, go through all the repair skills and apply as many points }
	{ as are needed of each. }
var
	T: Integer;
	Pts: LongInt;
begin
	for t := 0 to ( NumMaterial - 1 ) do begin
		if TotalRepairableDamage( Target , T ) > 0 then begin
			Pts := TotalRepairableDamage( Target , T );
			ApplyRepairPoints( Target , T , Pts , True );
		end;
	end;
end;

Function PerformSkillTar( NPC: GearPtr ): Integer;
	{ Return the performance skill target for this particular NPC. }
var
	it: Integer;
begin
	it := CStat( NPC , STAT_Ego ) + NAttValue( NPC^.NA , NAG_Personal , NAS_PerformancePenalty ) - 5;
	if it < 5 then it := 5;
	PerformSkillTar := it;
end;

Function SelectPerformanceTarget( GB: GameBoardPtr; PC: GearPtr ): GearPtr;
	{ Search through the map and locate someone who has not yet responded to }
	{ the PC's music today. If nobody is found, return NIL. }
const
	PerformanceRange = 8;
var
	M,it: GearPtr;
	team: Integer;
begin
	{ Start looking through the gameboard. }
	M := GB^.Meks;
	it := Nil;
	while M <> Nil do begin
		team := NAttValue( M^.NA , NAG_Location , NAS_Team );
		if ( M^.G = GG_Character ) and ( team <> NAV_DefPlayerTeam ) and ( team <> NAV_LancemateTeam ) and ( M <> PC ) and ( Range( GB , M , PC ) <= PerformanceRange ) and OnTheMap( GB , M ) and GearActive( M ) and ( not AreEnemies( GB , M , PC ) ) and NotAnAnimal( M ) and ( NAttValue( M^.NA , NAG_Personal , NAS_CashOnHandRestock ) <= GB^.ComTime ) then begin
			{ This is a potential target. Check to see if its skill target is lower }
			{ than that of the current candidate. }
			if it = Nil then begin
				it := M;
			end else if PerformSkillTar( M ) < PerformSkillTar( it ) then begin
				it := M;
			end;
		end;
		M := M^.Next;
	end;
	SelectPerformanceTarget := it;
end;

Function UsePerformance( GB: GameBoardPtr; PC,NPC: GearPtr ): LongInt;
	{ The PC is about to use a performance skill. }
	{  1) Select a nearby non-lancemate NPC }
	{  2) Make a performance roll }
	{  3) Profit }
	{ Return -1 for a bad performance, 0 for a mediocre performance, }
	{ and a positive number if the PC made any tips. }
var
	SkRoll,SkRank,Target: Integer;	{ Skill roll target }
	N: Integer;		{ Number of successes }
	Cash: LongInt;
begin
	{ Reduce stamina and mental now. }
	{ Performing is both mentally and physically exhausting. }
	if Random( 2 ) = 1 then begin
		AddStaminaDown( PC , 1 );
	end else begin
		AddMentalDown( PC , 1 );
	end;

	Cash := 0;

	Target := PerformSkillTar( NPC );
	if Target < 5 then Target := 5;

	{ Set the recharge timer for this target. }
	SetNAtt( NPC^.NA , NAG_Personal , NAS_CashOnHandRestock , GB^.ComTime + 43200 + Random( 86400 ) );

	{ Add to the performance resistance. }
	if Random( 2 ) = 1 then AddNAtt( NPC^.NA , NAG_Personal , NAS_PerformancePenalty , 1 );

	SkRoll := SkillRoll( GB , PC , NAS_Performance , STAT_Charm , Target , 0 , True , False );
	if SkRoll > Target then begin
		DoleSkillExperience( PC , NAS_Performance , Target );

		if SkRoll > ( Target + 5 ) then begin
			{ On a good roll, the PC earns some money. }
			SkRank := SkillRank( PC , NAS_Performance ) + 1;
			N := SkRoll - Target - 5;
			if N > SkRank then N := SkRank
			else if N < 1 then N := 1;
			Cash := SkillAdvCost( Nil , N ) div 10;
			AddNAtt( PC^.NA , NAG_Experience , NAS_Credits , Cash );
		end;

		{ Set the applause trigger. }
		SetTrigger( GB , TRIGGER_Applause );

	end else if ( SkRoll + PersonalityCompatability( PC , NPC ) - 5 ) < Target then begin
		AddMoraleDmg( PC , Rollstep( 1 ) );
		Cash := -1;
	end;

	UsePerformance := Cash;
end;



end.
