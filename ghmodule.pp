unit ghmodule;
	{This unit holds modules- arms, legs, pods... body}
	{parts, basically. Both mecha and living creatures}
	{use the same module descriptions.}
	{ This unit also holds the stuff for modifiers. Modifiers }
	{ are most frequently encountered as cybernetic implants... }
	{ They modify the stats or skills of whatever they're in. }
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

uses gears,ghholder,texutil,ui4gh,ghmecha;


Const
	NumModule = 8;

	{ G = GG_Module }
	{ S = Module Type }
	{ V = Module Size }
	{ Stat[1] = Armour }

	GS_Body = 1;
	GS_Head = 2;
	GS_Arm = 3;
	GS_Leg = 4;
	GS_Wing = 5;
	GS_Tail = 6;
	GS_Turret = 7;
	GS_Storage = 8;

	STAT_Armor = 1;
	STAT_PrimaryModuleForm = 2;	{ Modules, like mecha, can be transformable. }
	STAT_VariableModuleForm = 3;	{ In the event of transformation the primary form is favored. }

	{ This array tells which modules are usable by which forms. }
	{ Some systems ( movers, sensors, cockpits ) will function no matter where they are mounted. }
	{ Others ( weapons, shields, hands ) will not function if placed in a bad module. }
	FORMxMODULE: Array [0..NumForm-1, 1..NumModule] of Boolean = (
{		 	Body	Head	Arm	Leg	Wing	Tail	Turret	Storage }
{Battroid}	(	True,	True,	True,	True,	True,	True,	False,	True	),
{Zoanoid}	(	True,	True,	False,	True,	True,	True,	False,	True	),
{GroundHugger}	(	True,	False,	False,	False,	False,	False,	True,	True	),
{Arachnoid}	(	True,	True,	False,	True,	False,	True,	True,	True	),
{AeroFighter}	(	True,	False,	False,	False,	True,	False,	False,	True	),
{Ornithoid}	(	True,	True,	False,	True,	True,	True,	False,	True	),
{Gerwalk}	(	True,	True,	True,	True,	True,	True,	False,	True	),
{HoverFighter}	(	True,	False,	False,	False,	True,	False,	True,	True	),
{GroundCar}	(	True,	False,	False,	False,	False,	False,	True,	True	)

	);

	{ MODULE HIT POINT DEFINITIONS }
	{All these definitions are based on the module's size.}
	MHP_NoHP = 0;		{Used for storage pods. All dmg passed on to SubMods.}
	MHP_HalfSize = 4;	{ HP = ( Size + 1 ) div 2 }
	MHP_EqualSize = 1;	{ HP = Size }
	MHP_SizePlusOne = 2;	{ HP = Size + 1 }
	MHP_SizeTimesTwo = 3;	{ HP = Size * 2 }

	ModuleHP: Array [1..NumModule] of Byte = (
		{Body}	MHP_SizeTimesTwo,
		{Head}	MHP_HalfSize,
		{Arm}	MHP_EqualSize,
		{Leg}	MHP_SizePlusOne,
		{Wing}	MHP_HalfSize,
		{Tail}	MHP_EqualSize,
		{Turret} MHP_HalfSize,
		{Storage} MHP_NoHP
	);


	{ MODIFIER GEAR }
	{ G = GG_Modifier             }
	{ S = Modification Type       }
	{ V = Chara/Mecha Modifier    }

	GS_StatModifier = 1;
	GS_SkillModifier = 2;
	GV_CharaModifier = 1;
	GV_MechaModifier = 2;

	{ Only one gear with a given 'cyberslot' type should be installed }
	{ at any given time. Attempting to install another should result }
	{ in the first being deleted. }
	{ Without a cyberslot, the modifier won't interfere with other }
	{ modifier gears at all. }
	{ Sample slot names: EYE, EAR, MUSCULAR, SKELETON, HEART, etc. }
	SATT_CyberSlot = 'CYBERSLOT';

	STAT_SkillToModify = 1;
	STAT_SkillModBonus = 2;

Function BaseArmorCost( Part: GearPtr; DV: Integer ): LongInt;

Procedure InitModule( Part: GearPtr );

Function ModuleBaseDamage(Part: GearPtr): Integer;
Function ModuleComplexity( Part: GearPtr ): Integer;
Function ModuleName(Part: GearPtr): String;
Function ModuleBaseMass(Part: GearPtr): Integer;
Function ModuleValue( Part: GearPtr ): LongInt;

Procedure CheckModuleRange( Part: GearPtr );

Function IsLegalModuleInv( Slot, Equip: GearPtr ): Boolean;
Function IsLegalModuleSub( Slot, Equip: GearPtr ): Boolean;

Function StatModifierCost( Part: GearPtr ): LongInt;
Function ModifierCost( Part: GearPtr ): LongInt;
Procedure CheckModifierRange( Part: GearPtr );
Function TraumaValue( Part: GearPtr ): Integer;

implementation

uses ghintrinsic,ghchars;

Function BaseArmorCost( Part: GearPtr; DV: Integer ): LongInt;
	{ Return the cost of this armor value. }
	{ Modify this if the HARDENED intrinsic is had. }
const
	ATypePremium: Array [1..NumArmorType] of Byte = (
		10, 6
	);
var
	AType,it,Premium: LongInt;
begin
	{ Start with the basic formula. }
	it := DV * DV * DV * 5 + DV * DV * 10 + DV * 35;

	{ Modify upwards if the HARDENED intrinsic is applied. }
	AType := NAttValue( Part^.NA , NAG_GearOps , NAS_ArmorType );
	if ( AType > 0 ) and ( AType <= NumArmorType ) then begin
		if DV > 5 then Premium := it * ( DV - 1 )
		else Premium := it * 4;
		Premium := ( Premium * ATypePremium[ AType ] ) div 10;
		it := it + Premium;
	end;

	{ Return the finished value. }
	BaseArmorCost := it;
end;

Procedure InitModule( Part: GearPtr );
	{ This doesn't really do much except initialize the primary form. }
begin
	Part^.Stat[ STAT_PrimaryModuleForm ] := Part^.S;
end;

Function ModuleBaseDamage(Part: GearPtr): Integer;
	{For module PART, calculate the unscaled amount of}
	{damage that it can take before being destroyed.}
var
	it: Integer;
begin
	{Error check - make sure we actually have a Module.}
	if Part = Nil then Exit(0);
	if Part^.G <> GG_Module then Exit(0);
	if (Part^.S < 1) or (Part^.S > NumModule) then Exit(0);

	Case ModuleHP[Part^.S] of
		MHP_NoHP:		it := -1;
		MHP_HalfSize:		it := ( Part^.V + 1 ) div 2;
		MHP_EqualSize:		it := Part^.V;
		MHP_SizePlusOne:	it := Part^.V + 1;
		MHP_SizeTimesTwo: 	it := Part^.V * 2;
	else it := 0;
	end;

	{ Increase the HP of character modules based on the Vitality skill. }
	if ( Part^.Parent <> Nil ) and ( Part^.Parent^.G = GG_Character ) and ( it > 0 ) then begin
		it := it + NAttValue( Part^.Parent^.NA , NAG_Skill , NAS_Vitality );
	end;

	ModuleBaseDamage := it;
end;

Function ModuleComplexity( Part: GearPtr ): Integer;
	{ Return the complexity value for this part. }
begin
	if ( Part^.S = GS_Body ) or ( ( Part^.S = GS_Storage ) and ( Part^.Stat[ STAT_VariableModuleForm ] = 0 ) ) then begin
		ModuleComplexity := ( Part^.V + 1 ) * 2;
	end else begin
		ModuleComplexity := Part^.V + 1;
	end;
end;

Function ModuleName(Part: GearPtr): String;
	{Determine the geneic name for this particular module.}
begin
	{Eliminate all error cases first off...}
	if (Part = Nil) or (Part^.G <> GG_Module) or (Part^.S < 1) or (Part^.S > NumModule) then Exit('Unknown');

	ModuleName := MsgString( 'MODULENAME_' + BStr( Part^.S ) );
end;

Function ModuleBaseMass(Part: GearPtr): Integer;
	{For module PART, calculate the unscaled mass.}
var
	form,it: Integer;
begin
	{Error check - make sure we actually have a Module.}
	if Part = Nil then Exit(0);
	if Part^.G <> GG_Module then Exit(0);

	{ The mass of a part is the maximum of its forms. }
	form := Part^.Stat[ STAT_PrimaryModuleForm ];
	if ( Part^.Stat[ STAT_VariableModuleForm ] <> 0 ) and ( ModuleHP[ Part^.Stat[ STAT_VariableModuleForm ] ] > ModuleHP[ form ] ) then form := Part^.Stat[ STAT_VariableModuleForm ];

	Case ModuleHP[ form ] of
		MHP_NoHP:			it := 0;
		MHP_EqualSize,MHP_Halfsize:	it := Part^.V;
		MHP_SizePlusOne:		it := Part^.V + 1;
		MHP_SizeTimesTwo:	 	it := Part^.V * 2;
	else it := 0;
	end;

	{Armor also adds weight to a module.}
	it := it + Part^.Stat[ STAT_Armor ];

	ModuleBaseMass := it;
end;

Function ModuleValue( Part: GearPtr ): LongInt;
	{ Calculate the price of this module. }
var
	it: LongInt;
begin
	{ The basic module cost is 25 per point of size plus half the }
	{ value of the armor. Why only half? Because ExArmor is cost-penalized }
	{ due to several intrinsic advantages. }
	it := 25 * Part^.V + ( BaseArmorCost( Part , Part^.Stat[ STAT_Armor ] ) div 2 );

	{ Variable modules cost 20% more. }
	if Part^.Stat[ STAT_VariableModuleForm ] <> 0 then it := ( it * 6 ) div 5;

	ModuleValue := it;
end;

Procedure CheckModuleRange( Part: GearPtr );
	{ Check a MODULE gear to make sure all values are within appropriate }
	{ range. }
var
	InAMek: Boolean;
	T: Integer;
begin
	{ Check S - Module Type }
	if Part^.S < 1 then Part^.S := GS_Storage
	else if Part^.S > NumModule then Part^.S := GS_Storage;

	if ( Part^.Parent = Nil ) then InAMek := False
	else if Part^.Parent^.G = GG_Mecha then InAMek := True
	else InAMek := False;

	{ Check V - Module Size }
	{ If this module is installed in a Mecha, there'll be a }
	{ limit on its size. }
	if InAMek then begin
		if Part^.S = GS_Body then Part^.V := Part^.Parent^.V
		else if Part^.V > ( Part^.Parent^.V + 1 ) then Part^.V := ( Part^.Parent^.V + 1 );
	end;
	if Part^.V > 10 then Part^.V := 10
	else if Part^.V < 1 then Part^.V := 1;

	{ Check Stats }
	{ Stat 1 - Armor }
	if Part^.Stat[1] < 0 then Part^.Stat[1] := 0
	else if InAMek then begin
		{ Armor rating may not exceed the size of the mecha. }
		if Part^.Stat[1] > Part^.Parent^.V then Part^.Stat[1] := Part^.Parent^.V;
	end else begin
		if Part^.Stat[1] > 10 then Part^.Stat[1] := 10;
	end;

	{ Stat 3 - Variable Form }
	{ Body modules can't be variable form. }
	if Part^.S = GS_Body then Part^.Stat[ STAT_VariableModuleForm ] := 0
	else if Part^.Stat[ STAT_VariableModuleForm ] <> 0 then begin
		{ If this module has a variable form, it must be a non-body module type. }
		if Part^.Stat[ STAT_VariableModuleForm ] < 2 then Part^.Stat[ STAT_VariableModuleForm ] := 0
		else if Part^.Stat[ STAT_VariableModuleForm ] > NumModule then Part^.Stat[ STAT_VariableModuleForm ] := 0;
	end;

	for t := 4 to NumGearStats do Part^.Stat[ T ] := 0;
end;

Function IsLegalModuleInv( Slot, Equip: GearPtr ): Boolean;
	{ Check EQUIP to see if it can be stored in SLOT. }
	{ INPUTS: Slot and Equip must both be properly allocated gears. }
	{ See therules.txt for a list of acceptable equipment. }
var
	it: Boolean;
begin
	if Equip^.G = GG_Harness then begin
		{ Harnesses fit if their type is the same as the module being checked. }
		it := Equip^.S = Slot^.Stat[ STAT_PrimaryModuleForm ];
	end else if  Slot^.Stat[ STAT_PrimaryModuleForm ] = GS_Arm then begin
		Case Equip^.G of
			GG_ExArmor:	begin
					it := Slot^.Stat[ STAT_PrimaryModuleForm ] = Equip^.S;
					end;
			GG_Shield:	it := true;
			else it := False;
		end;
	end else if Slot^.Stat[ STAT_PrimaryModuleForm ] = GS_Tail then begin
		Case Equip^.G of
			GG_ExArmor:	begin
					it := Slot^.Stat[ STAT_PrimaryModuleForm ] = Equip^.S;
					end;
			GG_Shield:	it := true;
			else it := False;
		end;
	end else begin
		Case Equip^.G of
			GG_ExArmor:	begin
					it := Slot^.Stat[ STAT_PrimaryModuleForm ] = Equip^.S;
					end;
			else it := False;
		end;
	end;

	{ If the item is of a different scale than the holder, }
	{ it can't be held. }
	if Equip^.Scale <> Slot^.Scale then it := False;

	IsLegalModuleInv := it;
end;

Function IsLegalModuleSub( Slot, Equip: GearPtr ): Boolean;
	{ Return TRUE if EQUIP can be installed in SLOT, }
	{ FALSE otherwise. }
begin
	if Slot^.S = GS_Body then begin
		case Equip^.G of
			GG_Cockpit:	IsLegalModuleSub := True;
			GG_Weapon:	IsLegalModuleSub := True;
			GG_MoveSys:	IsLegalModuleSub := True;
			GG_Holder:	begin
						if Equip^.S = GS_Hand then IsLegalModuleSub := False
						else IsLegalModuleSub := True;
					end;
			GG_Sensor:	IsLegalModuleSub := True;
			GG_Support:	IsLegalModuleSub := True;
			GG_PowerSource:	IsLegalModuleSub := True;
			GG_Computer:	IsLegalModuleSub := True;
			GG_Usable:	IsLegalModuleSub := True;
		else IsLegalModuleSub := False
		end;
	end else begin
		case Equip^.G of
			GG_Cockpit:	IsLegalModuleSub := True;
			GG_Weapon:	IsLegalModuleSub := True;
			GG_MoveSys:	IsLegalModuleSub := True;
			GG_Holder:	begin
						if ( Equip^.S = GS_Hand ) and ( Slot^.Stat[ STAT_PrimaryModuleForm ] <> GS_Arm ) then IsLegalModuleSub := False
						else IsLegalModuleSub := True;
					end;
			GG_Sensor:	IsLegalModuleSub := True;
			GG_PowerSource:	IsLegalModuleSub := True;
			GG_Computer:	IsLegalModuleSub := True;
			GG_Usable:	IsLegalModuleSub := True;

		else IsLegalModuleSub := False
		end;
	end;
end;

Function StatModifierCost( Part: GearPtr ): LongInt;
	{ Return a price for this particular stat modifier. }
const
	CostFactor = 8000;
	DiscountFactor = 3500;
var
	plusses,minuses,T: Integer;
	it: LongInt;
begin
	{ Initialize our counters. }
	plusses := 0;
	minuses := 0;
	it := 0;

	for t := 1 to NumGearStats do begin
		if Part^.Stat[ T ] > 0 then begin
			{ ExArmor measures stat bonuses in tenths of a point, so rescale the }
			{ values we get. }
			if Part^.G = GG_ExArmor then begin
				Plusses := Plusses + Part^.Stat[ T ];
			end else begin
				plusses := plusses + ( ( Part^.Stat[ T ] * Part^.Stat[ T ] ) - 1 + Part^.Stat[ T ] ) * 10;
			end;
		end else if Part^.Stat[ T ] < 0 then begin
			minuses := minuses - Part^.Stat[ T ];
		end;
	end;

	if Plusses > 0 then begin
		it := Plusses * CostFactor div 10;

		if Minuses > 0 then begin
			it := it - DiscountFactor * Minuses;
		end else if Part^.G <> GG_ExArmor then begin
			{ If no minuses, a 50% increase in price. }
			it := ( it * 3 ) div 2;
		end;

		{ Make sure the cost doesn't fall below the minimum value. }
		if ( it < CostFactor )  then it := CostFactor;
	end;

	StatModifierCost := it;
end;

Function ModifierCost( Part: GearPtr ): LongInt;
	{ The cost of a modifier part will depend upon how many +s it }
	{ gives versus how many -s it imparts. }
const
	BasePrice: Array [1..5] of Byte = (10,25,45,70,100);
	PriceFactor = 2000;
var
	plusses: Integer;
	it: LongInt;
begin
	{ Initialize our counters. }
	plusses := 0;
	it := 0;

	{ Count up the plusses and minuses. }
	if Part^.S = GS_StatModifier then begin
		it := StatModifierCost( Part );
	end else if Part^.S = GS_SkillModifier then begin
		Plusses := Part^.Stat[ STAT_SkillModBonus ];
		if Plusses > 0 then begin
			it := BasePrice[ Plusses ] * PriceFactor + it;
		end;
	end;

	{ Make sure the cost doesn't fall below the minimum value. }
	if it < PriceFactor then it := PriceFactor;

	{ Return the calculated value. }
	ModifierCost := it;
end;

Procedure CheckModifierRange( Part: GearPtr );
	{ Make sure that this modification gear is within the accepted }
	{ range bands. }
var
	T: Integer;
begin
	{ S = Modifier Type, must be 1 or 2. }
	if Part^.S < 1 then Part^.S := 1
	else if Part^.S > 2 then Part^.S := 2;

	{ V = Trauma Value, may be from 0 to 80 }
	if Part^.V < 0 then Part^.V := 0
	else if Part^.V > 100 then Part^.V := 80;

	{ Scale - Must be 0! }
	if Part^.Scale <> 0 then Part^.Scale := 0;

	{ Check the stats for range. }
	if Part^.S = GS_StatModifier then begin
		for t := 1 to NumGearStats do begin
			if Part^.Stat[ T ] > 5 then Part^.Stat[ T ] := 5
			else if Part^.Stat[ T ] < -3 then Part^.Stat[ T ] := -3;
		end;

	end else if Part^.S = GS_SkillModifier then begin
		if Part^.Stat[ 2 ] < 1 then Part^.Stat[ 2 ] := 1
		else if Part^.Stat[ 2 ] > 3 then Part^.Stat[ 2 ] := 3;
	end;

end;

Function TraumaValue( Part: GearPtr ): Integer;
	{ Return how much trauma this part causes. The more bonuses it provides }
	{ the higher the trauma. }
var
	total,T: Integer;
begin
	total := 0;

	if Part^.S = GS_StatModifier then begin
		for t := 1 to NumGearStats do begin
			if Part^.Stat[ T ] > 0 then total := total + Part^.Stat[ T ];
		end;
	end else if Part^.S = GS_SkillModifier then begin
		total := Part^.Stat[ STAT_SkillModBonus ];
		if Part^.Stat[ STAT_SkillToModify ] <= Num_Basic_Combat_Skills then Inc( total );
	end;

	TraumaValue := total;
end;

end.
