unit ghswag;
	{ This unit handles various items that will probably be }
	{ carried around by adventurers, but not might be found }
	{ in the tactical game. }
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

uses gears;

	{ TREASURE format }
	{ G = GG_Treasure               }
	{ S = Undefined                 }
	{ V = Undefined                 }

	{ TOOL format }
	{ G = GG_Tool                }
	{ S = Skill/Talent Affected  }
	{ V = Skill Bonus            }

	{ REPAIRFUEL format }
	{ G = GG_Usable             }
	{ S = Repair Type           }
	{ V = DP Capacity           }

	{ CONSUMABLE format }
	{ G = GG_CONSUMABLE         }
	{ S = NA                    }
	{ V = Hunger Points         }

Const
	STAT_MoraleBoost = 1;

	STAT_FoodEffectType = 4;
		Num_FoodEffectType = 4;
		FET_Healing = 1;
		FET_Regeneration = 2;
		FET_CauseStatus = 3;
		FET_CureStatus = 4;
	STAT_FoodEffectMod = 5;
	STAT_FoodSkillXP = 6;		{ Does this food provide a bonus to SkillXP? }
	STAT_FoodSkillXPAmount = 7;	{ How much skill experience does it provide? }

	Repair_Cost_Multiplier: Array [0..NumMaterial] of Byte = (
		1, 1, 5
	);

	Food_Effect_String: Array [1..Num_FoodEffectType] of String = (
		'# HEALING 1',
		'# STATUS 3',
		'9 STATUS #',
		'9 CURE #'
	);

Function ToolDamage( Part: GearPtr ): Integer;
Function ToolValue( Part: GearPtr ): Integer;
Procedure CheckToolRange( Part: GearPtr );

Function IsLegalToolSub( Equip: GearPtr ): Boolean;

Function RepairFuelName( Part: GearPtr ): String;
Procedure CheckRepairFuelRange( Part: GearPtr );
Function RepairFuelValue( Part: GearPtr ): LongInt;

Procedure CheckFoodRange( Part: GearPtr );
Function FoodMass( Part: GearPtr ): Integer;
Function FoodValue( Part: GearPtr ): LongInt;

implementation

uses ghchars,ghweapon,ui4gh,texutil;


Function ToolDamage( Part: GearPtr ): Integer;
	{ Return how much damage this usable gear can withstand. }
begin
	ToolDamage := 1;
end;

Function ToolValue( Part: GearPtr ): Integer;
	{ Return the value of this usavle gear. }
begin
	ToolValue := Part^.V * Part^.V * 450 + 150;
end;

Procedure CheckToolRange( Part: GearPtr );
	{ Examine the various bits of this gear to make sure everything }
	{ is all nice and legal. }
begin
	{ Check S - Usable Type; corresponds to a skill }
	{  or a talent. May not target the basic combat skills. }
	if Part^.S > 0 then begin
		if Part^.S <= Num_Basic_Combat_Skills then Part^.S := Num_Basic_Combat_Skills + 1
		else if Part^.S > NumSkill then Part^.S := NumSkill;
	end else begin
		if Part^.S > -1 then Part^.S := -1
		else if Part^.S < -NumTalent then Part^.S := -1;
	end;

	{ Check V - Skill Bonus }
	if Part^.V < 0 then Part^.V := 0
	else if Part^.V > 5 then Part^.V := 5;

	{ Scale must be 0. }
	Part^.Scale := 0;

	{ No stats defined. }
end;

Function IsLegalToolSub( Equip: GearPtr ): Boolean;
	{ Return TRUE if EQUIP can be installed into TOOL, or FALSE otherwise. }
begin
	IsLegalToolSub := ( Equip^.G = GG_Weapon ) or ( Equip^.G = GG_PowerSource ) or ( Equip^.G = GG_Computer );
end;

Function RepairFuelName( Part: GearPtr ): String;
	{ Returns a default name for some repairfuel. }
begin
	RepairFuelName := MsgString( 'SKILLNAME_' + BStr( Part^.S ) ) + ' Kit';
end;

Procedure CheckRepairFuelRange( Part: GearPtr );
	{ Examine the various bits of this gear to make sure everything }
	{ is all nice and legal. }
begin
	{ Check S - Skill Type }
	if Part^.S < 0 then Part^.S := 0
	else if Part^.S > NumMaterial then Part^.S := NumMaterial;
end;

Function RepairFuelValue( Part: GearPtr ): LongInt;
	{ Return the value of this repair fuel. }
begin
	RepairFuelValue := Part^.V * Repair_Cost_Multiplier[ Part^.S ];
end;

Procedure CheckFoodRange( Part: GearPtr );
	{ Check the range for this consumable gear. }
begin
	{ V = Hunger Value }
	if Part^.V < 0 then Part^.V := 0
	else if Part^.V > 60 then Part^.V := 60;

	{ Stat 1 = Morale Boost }
	if Part^.Stat[ STAT_MoraleBoost ] > 10 then Part^.Stat[ STAT_MoraleBoost ] := 10
	else if Part^.Stat[ STAT_MoraleBoost ] < -5 then Part^.Stat[ STAT_MoraleBoost ] := -5;

	{ Stat 4 - Food Effect Type }
	if Part^.Stat[ STAT_FoodEffectType ] < 0 then Part^.Stat[ STAT_FoodEffectType ] := 0
	else if Part^.Stat[ STAT_FoodEffectType ] > Num_FoodEffectType then Part^.Stat[ STAT_FoodEffectType ] := 0;

	{ Stat 5 - Food Effect Mod }
	if Part^.Stat[ STAT_FoodEffectType ] <> 0 then begin
		if Part^.Stat[ STAT_FoodEffectType ] = FET_CureStatus then begin
			if Part^.Stat[ STAT_FoodEffectMod ] < 1 then Part^.Stat[ STAT_FoodEffectMod ] := 1
			else if Part^.Stat[ STAT_FoodEffectMod ] > Num_Status_FX then Part^.Stat[ STAT_FoodEffectMod ] := Num_Status_FX;
		end else begin
			if Part^.Stat[ STAT_FoodEffectMod ] < 1 then Part^.Stat[ STAT_FoodEffectMod ] := 1
			else if Part^.Stat[ STAT_FoodEffectMod ] > Num_Status_FX then Part^.Stat[ STAT_FoodEffectMod ] := Num_Status_FX;
		end;
	end else Part^.Stat[ STAT_FoodEffectMod ] := 0;

	{ Stat 6 - Skill XP }
	if Part^.STAT[ STAT_FoodSkillXP ] > NumSkill then Part^.STAT[ STAT_FoodSkillXP ] := 0
	else if Part^.STAT[ STAT_FoodSkillXP ] < 0 then Part^.STAT[ STAT_FoodSkillXP ] := 0;

	{ Stat 7 - Skill XP amount }
	if Part^.STAT[ STAT_FoodSkillXP ] > 0 then begin
		if Part^.STAT[ STAT_FoodSkillXPAmount ] < 1 then Part^.STAT[ STAT_FoodSkillXPAmount ] := 1
		else if Part^.STAT[ STAT_FoodSkillXPAmount ] > 1000 then Part^.STAT[ STAT_FoodSkillXPAmount ] := 1000;
	end;

end;

Function FoodMass( Part: GearPtr ): Integer;
	{ Return the basic mass value for this food. }
begin
	FoodMass := Part^.V div 5;
end;

Function FoodValue( Part: GearPtr ): LongInt;
	{ Return the cost of this food. }
var
	it,M: LongInt;
begin
	it := Part^.V div 3;

	Case Part^.Stat[ STAT_FoodEffectType ] of
		FET_Healing: it := it + 55 * Part^.Stat[ STAT_FoodEffectMod ];
		FET_Regeneration: it := it + 45 * Part^.Stat[ STAT_FoodEffectMod ];
		FET_CureStatus: it := it + SX_RepCost[ Part^.Stat[ STAT_FoodEffectMod ] ] * 10;
	end;

	if Part^.Stat[ STAT_MoraleBoost ] > 0 then begin
		it := it + ( Part^.Stat[ STAT_MoraleBoost ] * ( 75 - Part^.V ) );
	end else begin
		M := it * ( Part^.Stat[ STAT_MoraleBoost ] + 10 ) div 10;
		if M < ( it div 2 ) then M := it div 2;
		it := M;
	end;

	{ Add the SkillXP cost. }
	it := it + Part^.STAT[ STAT_FoodSkillXPAmount ] * Credits_Per_XP;

	FoodValue := it;
end;

end.
