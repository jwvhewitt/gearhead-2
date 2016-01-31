unit gearutil;
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

uses gears,ghmecha,ghchars,ghmodule,ghweapon,ghmovers,ghholder,ghsensor,ghsupport,ghguard,ghswag,ghprop,texutil,ui4gh;

Const
	NAG_Damage = 12;

	NAS_StrucDamage = 0;	{Structural Damage is what we would}
				{normally refer to as HP loss.}
	NAS_ArmorDamage = 1;	{As armor gets hit, it loses its}
				{protective ability.}
	NAS_OutOfAction = 2;	{ if OutOfAction <> 0 , this model is OutOfAction }

	Num_Perm_Injuries = 5;
	Perm_Injury_List: Array [1..Num_Perm_Injuries] of Byte = (
		21,22,23,24,25
	);
	Perm_Injury_Slot: Array [1..Num_Perm_Injuries] of String = (
		'EYES','SPINE','MUSCULATURE','SKELETON','HEART'
	);

Function GearsAreIdentical( A,B: GearPtr ): Boolean;

Function IsMasterGear(G: GearPtr): Boolean;
Procedure InitGear(Part: GearPtr);
function FindMaster( Part: GearPtr ): GearPtr;
function FindMasterOrRoot( Part: GearPtr ): GearPtr;
Function MasterSize(Part: GearPtr): Integer;
function FindModule( Part: GearPtr ): GearPtr;

function ModifiersSkillBonus( Part: GearPtr; Skill: Integer ): Integer;
Function CharaSkillRank( PC: GearPtr; Skill: Integer ): Integer;

function InGoodModule( Part: GearPtr ): Boolean;

Function ScaleDP( DP , Scale , Material: Integer ): Integer;
Function UnscaledMaxDamage( Part: GearPtr ): Integer;
Function GearMaxDamage(Part: GearPtr): Integer;
Function GearMaxArmor(Part: GearPtr): Integer;
Function GearName(Part: GearPtr): String;
Function FullGearName(Part: GearPtr): String;

Function ComponentMass( Part: GearPtr ): Integer;
Function GearMass( Master: GearPtr ): Integer;
Function IntrinsicMass( Master: GearPtr ): LongInt;
Function EquipmentMass( Master: GearPtr ): LongInt;

Function MakeMassString( BaseMass: LongInt; Scale: Integer ): String;
Function MassString( Master: GearPtr ): String;
Function GearDepth( Part: GearPtr ): Integer;

Function ComponentComplexity( Part: GearPtr ): Integer;
Function SubComComplexity( Part: GearPtr ): Integer;

Function IsLegalInvcom( Parent, Equip: GearPtr ): Boolean;
Function IsLegalSubcom( Parent, Equip: GearPtr ): Boolean;
Function CanBeInstalled( Part , Equip: GearPtr ): Boolean;

Procedure CheckGearRange( Part: GearPtr );

Function SeekGear( Master: GearPtr; G,S: Integer; CheckInv: Boolean ): GearPtr;
Function SeekGear( Master: GearPtr; G,S: Integer ): GearPtr;

Function SeekCurrentLevelGear( Master: GearPtr; G,S: Integer ): GearPtr;
Function SeekSoftware( Mek: GearPtr; SW_Type,SW_Param: Integer; CasualUse: Boolean ): GearPtr;

Function GearEncumberance( Mek: GearPtr ): Integer;
Function BaseMVTVScore( Mek: GearPtr ): Integer;

Function ComponentValue( Part: GearPtr; CalcCost,FullLoad: Boolean ): LongInt;
Function GearCost( Master: GearPtr ): LongInt;
Function GearValue( Master: GearPtr ): LongInt;

function SeekGearByName( LList: GearPtr; Name: String ): GearPtr;
function SeekSibByFullName( LList: GearPtr; Name: String ): GearPtr;
function SeekChildByName( Parent: GearPtr; Name: String ): GearPtr;
function SeekGearByDesig( LList: GearPtr; Name: String ): GearPtr;

function SeekGearByIDTag( LList: GearPtr; G,S,V: LongInt ): GearPtr;
function CountGearsByIDTag( LList: GearPtr; G,S,V: LongInt ): LongInt;

function SeekGearByG( LList: GearPtr; G: Integer ): GearPtr;
function SeekSubsByG( LList: GearPtr; G: Integer ): GearPtr;
function MaxIDTag( LList: GearPtr; G,S: Integer ): LongInt;

function CStat( PC: GearPtr; Stat: Integer ): Integer;

Procedure WriteCGears( var F: Text; G: GearPtr );
Function ReadCGears( var F: Text ): GearPtr;

Function WeaponDC( Attacker: GearPtr ): Integer;

Function AmountOfDamage( Part: GearPtr; PlusArmor: Boolean ): LongInt;
Function GearCurrentDamage(Part: GearPtr): LongInt;
Function GearCurrentArmor(Part: GearPtr): Integer;
Function PercentDamaged( Master: GearPtr ): Integer;
Function NotDestroyed(Part: GearPtr): Boolean;
Function Destroyed(Part: GearPtr): Boolean;
Function PartActive( Part: GearPtr ): Boolean;
Function RollDamage( DC , Scale: Integer ): Integer;
Function NumActiveGears(Part: GearPtr): Integer;
Function FindActiveGear(Part: GearPtr; N: Integer): GearPtr;

Function CountActivePoints(Master: GearPtr; G,S: Integer): Integer;
Function CountActiveParts(Master: GearPtr; G,S: Integer): Integer;
Function CountTotalParts(Master: GearPtr; G,S: Integer): Integer;

Function EnergyCost( Part: GearPtr ): Integer;
Function EnergyPoints( Master: GearPtr ): LongInt;
Procedure SpendEnergy( Master: GearPtr; EP: Integer );


Function SeekActiveIntrinsic( Master: GearPtr; G,S: Integer ): GearPtr;
Function SeekItem( Master: GearPtr; G,S: Integer; CheckGeneralInv: Boolean ): GearPtr;
Function MechaManeuver( Mek: GearPtr ): Integer;
Function MechaTargeting( Mek: GearPtr ): Integer;
Function MechaSensorRating( Mek: GearPtr ): Integer;
Function MechaStealthRating( Mek: GearPtr ): Integer;

Function LocateGoodAmmo( Weapon: GearPtr ): GearPtr;
Function LocateAnyAmmo( Weapon: GearPtr ): GearPtr;

Function WeaponAttackAttributes( Attacker: GearPtr ): String;
Function HasAttackAttribute( AtAt: String; N: Integer ): Boolean;
Function HasAreaEffect( AtAt: String ): Boolean;
Function HasAreaEffect( Attacker: GearPtr ): Boolean;
Function NonDamagingAttack( AtAt: String ): Boolean;
Function NoCalledShots( AtAt: String; AtOp: Integer ): Boolean;

Function AmmoRemaining( Weapon: GearPtr ): Integer;
Function ScaleRange( Rng,Scale: Integer ): Integer;

Procedure ApplyPerminantInjury( PC: GearPtr );
Procedure ApplyCyberware( PC,Cyber: GearPtr );

Function NotAnAnimal( Master: GearPtr ): Boolean;

Function CreateComponentList( MasterList: GearPtr; const Context: String ): NAttPtr;
Function RandomComponentListEntry( ShoppingList: NAttPtr ): NAttPtr;
Function SelectComponentFromList( MasterList: GearPtr; var ShoppingList: NAttPtr ): GearPtr;

Function FindNextComponent( CList: GearPtr; const plot_desc: String ): GearPtr;

Function NumberOfSkillSlots( PC: GearPtr ): Integer;
Function TooManySkillsPenalty( PC: GearPtr; N: Integer ): Integer;
Function SkillAdvCost( PC: GearPtr; CurrentLevel: Integer ): LongInt;

Function IsExternalPart( Master,Part: GearPtr ): Boolean;

Function ToolBonus( Master: GearPtr; Skill: Integer ): Integer;

implementation

uses ghintrinsic,movement;

Const
	SaveFileContinue = 0;
	SaveFileSentinel = -1;
	GMMODE_AddAll = 0;
	GMMODE_Intrinsic = 1;
	GMMODE_Equipment = 2;
	Storage_Armor_Bonus = 2;

	MVSensorPenalty = 1;
	MVGyroPenalty = 6;
	TRSensorPenalty = 5;

Function GearsAreIdentical( A,B: GearPtr ): Boolean;
	{ Return TRUE if A and B are perfectly identical, including all child gears. }
	Function StatsMatch: Boolean;
		{ Return TRUE if all of A's and B's stats match. }
	var
		T: Integer;
		AllOK: Boolean;
	begin
		AllOK := True;
		for t := 1 to NumGearStats do AllOK := AllOK and ( A^.Stat[ T ] = B^.Stat[ T ] );
		StatsMatch := AllOK;
	end;
	Function ChildrenMatch: Boolean;
		{ Return TRUE if all of A's children are identical to B's children. Note that }
		{ this procedure may result in false negatives- if two gears are effectively identical }
		{ but their children are in a different order, this function will claim that they }
		{ aren't identical. Oh well, not a big deal... }
	var
		AllOK: Boolean;
		C1,C2: GearPtr;
	begin
		AllOK := True;
		C1 := A^.SubCom;
		C2 := B^.SubCom;
		while ( C1 <> Nil ) and ( C2 <> Nil ) and AllOK do begin
			AllOK := AllOK and GearsAreIdentical( C1 , C2 );
			C1 := C1^.Next;
			C2 := C2^.Next;
		end;
		AllOK := AllOK and ( C1 = Nil ) and ( C2 = Nil );
		C1 := A^.InvCom;
		C2 := B^.InvCom;
		while ( C1 <> Nil ) and ( C2 <> Nil ) and AllOK do begin
			AllOK := AllOK and GearsAreIdentical( C1 , C2 );
			C1 := C1^.Next;
			C2 := C2^.Next;
		end;
		AllOK := AllOK and ( C1 = Nil ) and ( C2 = Nil );
		ChildrenMatch := AllOK;
	end;
	Function AllAttAcc4( G1,G2: GearPtr ): Boolean;
		{ All Attributes Accounted For. All numeric and string attributes of G1 must }
		{ be found in G2. }
	var
		SA: SAttPtr;
		NA: NAttPtr;
		AllOK: Boolean;
		S_tag,S_data: String;
	begin
		AllOK := True;
		SA := G1^.SA;
		while ( SA <> Nil ) and AllOK do begin
			S_tag := RetrieveAPreamble( SA^.Info );
			S_data := RetrieveAString( SA^.Info );
			AllOK := AllOK and ( SAttValue( G2^.SA , S_tag ) = S_data );
			SA := SA^.Next;
		end;
		NA := G1^.NA;
		while ( NA <> Nil ) and AllOK do begin
			AllOK := AllOK and ( NAttValue( G2^.NA , NA^.G , NA^.S ) = NA^.V );
			NA := NA^.Next;
		end;
		AllAttAcc4 := AllOK;
	end;
begin
	GearsAreIdentical := ( A <> Nil ) and ( B <> Nil ) and ( A^.G = B^.G ) and ( A^.S = B^.S ) and ( A^.V = B^.V ) and StatsMatch and ChildrenMatch and AllAttAcc4( A , B ) and AllAttAcc4( B , A );
end;

Function IsMasterGear(G: GearPtr): Boolean;
	{This function checks gear G to see whether or not it counst}
	{as a Master Gear. Currently the only gears which count}
	{as masters are Mecha and Characters.}
var
	it: Boolean;
begin
	if G <> Nil then begin
		if (G^.G = GG_Mecha) or (G^.G = GG_Character) or (G^.G = GG_Prop) then it := true
		else it := false;
	end else it := False;
	IsMasterGear := it;
end;

Procedure InitGear(Part: GearPtr);
	{ Part has just been created. G, S, and V have been defined but }
	{ nothing else. Initialize its fields to the default values.}
var
	T: Integer;
begin
	{Error check- make sure we haven't just been sent a Nil.}
	if Part = Nil then exit;

	{ Clear all stats, to prevent nasty errors. }
	for t := 1 to NumGearStats do Part^.Stat[ T ] := 0;

	{For gears which are not master gears, take the scale}
	{from its parent.}
	if not IsMasterGear(Part) then begin
		if Part^.Parent <> NIl then begin
			Part^.Scale := Part^.Parent^.Scale;

			{ In addition, sub-components inherit material from }
			{ their parents. }
			if IsSubCom( Part ) then begin
				SetNAtt( Part^.NA , NAG_GearOps , NAS_Material , NAttValue( Part^.Parent^.NA , NAG_GearOps , NAS_Material ) );
			end;
		end;
	end;

	{Do the type-specific initialization routines here.}
	case Part^.G of
		GG_Mecha: InitMecha(Part);
		GG_Character: InitChar(Part);
		GG_Weapon: InitWeapon(Part);
		GG_Ammo: InitAmmo(Part);
		GG_MetaTerrain: InitMetaTerrain(Part);
		GG_Module: InitModule( Part );
		GG_MapFeature: InitMapFeature( Part );
	end;
end;

function FindMaster( Part: GearPtr ): GearPtr;
	{ Locate the master of PART. Return NIL if there is no master. }
begin
	{ Move the pointer up to either root level or the first Master parent. }
	while ( Part <> Nil ) and ( not IsMasterGear(Part) ) do Part := Part^.Parent;

	FindMaster := Part;
end;

function FindMasterOrRoot( Part: GearPtr ): GearPtr;
	{ Locate the master of PART. Failing that, find the root. }
	{ Thanks Buffered, whoever you are. }
begin
	{ Move the pointer up to either root level or the first Master parent. }
	while ( Part <> Nil ) and ( Part^.Parent <> Nil ) and ( not IsMasterGear(Part) ) do Part := Part^.Parent;

	FindMasterOrRoot := Part;
end;

Function MasterSize(Part: GearPtr): Integer;
	{Determine the size of the Master for the current gear.}
	{If the Master is a mecha, this will be its Value field.}
	{If its a Character, this will be its Body stat.}
	{If no Master can be found, return Nil.}
var
	it: Integer;
begin
	Part := FindMaster( Part );

	if Part = Nil then it := 0
	else if Part^.G = GG_Mecha then it := Part^.V
	else if Part^.G = GG_Character then begin
		{ The main purpose of this for character gears is to }
		{ determine the size of the character's limbs. }
		it := ( Part^.Stat[ STAT_Body ] + 2 ) div 3;
		if it < 1 then it := 1
		else if it > 10 then it := 10;
	end else it := 0;

	MasterSize := it;
end;

function FindModule( Part: GearPtr ): GearPtr;
	{ Locate the module of PART. Return NIL if there is no master. }
begin
	{ Move the pointer up to either root level or the first Master parent. }
	while ( Part <> Nil ) and ( Part^.G <> GG_Module ) do Part := Part^.Parent;

	FindModule := Part;
end;

function ModifiersSkillBonus( Part: GearPtr; Skill: Integer ): Integer;
	{ Determine the total skill bonus gained from MODIFIER }
	{ gears installed in PART. }
var
	MD: GearPtr;	{ Modifier gears. }
	it: Integer;
begin
	MD := Part^.SubCom;
	it := 0;
	while MD <> Nil do begin
		if ( MD^.G = GG_Modifier ) and ( MD^.S = GS_SkillModifier ) then begin
			if ( MD^.Stat[ STAT_SkillToModify ] = Skill ) and ( MD^.Stat[ STAT_SkillModBonus ] > it ) then it := MD^.Stat[ STAT_SkillModBonus ];
		end;
		MD := MD^.Next;
	end;
	ModifiersSkillBonus := it;
end;

Function CharaSkillRank( PC: GearPtr; Skill: Integer ): Integer;
	{ Return the PC's rank in this skill. }
	{ Note that PC _MUST_ be the actual PC!!! This does not work on }
	{ mecha, or props, or anything else!!! }
	{ Also note that this function does not check the presence of tools. }
var
	it: Integer;
begin
	if ( PC <> Nil ) and ( PC^.G = GG_Character ) then begin
		it := NAttValue( PC^.NA , NAG_Skill , Skill ) + ModifiersSkillBonus( PC , Skill );

		{ Normally to check for a talent we'd use the HAStALENT function, }
		{ but since that isn't available here and we know we're dealing with }
		{ the PC and also because you can't be granted talents from items or }
		{ mecha, I'll just check the NAtt to see if it's present. }
		if ( it = 0 ) and ( NAttValue( PC^.NA , NAG_Talent , NAS_JackOfAll ) <> 0 ) then it := 1;

		CharaSkillRank := it;
	end else begin
		CharaSkillRank := 0;
	end;
end;



function InGoodModule( Part: GearPtr ): Boolean;
	{ Check PART to make sure that it is mounted in a good module. }
var
	Ms,Md: GearPtr;		{ Master and Module }
begin
	Ms := FindMaster( Part );
	Md := FindModule( Part );

	{ If no master can be found, this function returns FALSE. }
	if ( Ms = Nil ) then Exit( False );

	if Ms^.G = GG_Mecha then begin
		if Md = Nil then begin
			{ This gear must be located in the general }
			{ inventory, since it isn't in a module. Items }
			{ in the general inventory can't be used until }
			{ equipped. }
			InGoodModule := False;
		end else begin
			{ With both the master and the module, look up }
			{ this combo in the Form X Module array. }
			InGoodModule := FormXModule[ Ms^.S , Md^.S ] and IsSubCom( Md );
		end;

	end else begin
		{ For characters and whatever else, every module is a }
		{ good module. If there's no module, i.e. the item is in }
		{ the general inventory, that's not good. }
		InGoodModule := ( Md <> Nil ) and IsSubCom( Md );
	end;
end;


Function ScaleDP( DP , Scale , Material: Integer ): Integer;
	{ Modify the damage point score DP for scale and construction. }
var
	T: Integer;
begin
	if DP > 0 then begin
		if Scale < 1 then begin
			if Material = NAV_Meat then DP := DP * 2
			else DP := DP * 3;
		end else begin
			if Material = NAV_Meat then DP := DP * 4
			else if Material = NAV_BioTech then DP := DP * 6
			else if Material = NAV_Metal then DP := DP * 5;

			if Scale > 1 then begin
				for t := 2 to Scale do DP := DP * 5;
			end;
		end;
	end;
	ScaleDP := DP;
end;

Function UnscaledMaxDamage( Part: GearPtr ): Integer;
	{ Return the maxdamage rating of this part, unadjusted for }
	{ scale or construction. }
var
	it: Integer;
begin
	case Part^.G of
		GG_Module:	it := ModuleBaseDamage( Part );
		GG_Mecha:	it := -1;
		GG_Character:	it := CharBaseDamage(Part , CStat( Part , STAT_Body ) , CharaSkillRank( Part , NAS_Vitality ) );
		GG_Cockpit:	it := -1;
		GG_Weapon:	it := WeaponBaseDamage(Part);
		GG_Ammo:	it := AmmoBaseDamage(Part);
		GG_MoveSys:	it := MovesysBaseDamage(Part);
		GG_Holder:	it := 1;
		GG_Sensor:	it := SensorBaseDamage( Part );
		GG_Support:	it := SupportBaseDamage( Part );
		GG_Shield:	it := -1;
		GG_ExArmor:	it := -1;
		GG_Treasure:	it := 1;
		GG_Prop:	it := Part^.V;
		GG_MetaTerrain:	it := Part^.V;
		GG_Tool:	it := ToolDamage( Part );
		GG_RepairFuel:	it := 0;
		GG_Consumable:	it := 0;
		GG_Modifier:	it := 0;
		GG_WeaponAddOn:	it := 1;
		GG_PowerSource:	it := 1;
		GG_Computer:	it := 1;
		GG_Software:	it := 0;
		GG_Harness:	it := 0;
		GG_Usable:	it := 2;
	else it := -1;
	end;

	UnscaledMaxDamage := it;
end;

Function GearMaxDamage(Part: GearPtr): Integer;
	{Calculate how much damage this particular part can take}
	{before being destroyed.}
var
	it: Integer;
begin
	{ Start with the unscaled mass damage. }
	it := UnscaledMaxDamage( Part );

	{Modify damage for scale and construction.}
	it := ScaleDP( it , PART^.Scale , NAttValue( Part^.NA , NAG_GearOps , NAS_Material ) );

	GearMaxDamage := it;
end;

Function UnscaledMaxArmor( Part: GearPtr ): Integer;
	{ Calculate the unscaled armor value of this part. }
var
	M: GearPtr;
	it: Integer;
begin
	{Error Check}
	if Part = Nil then Exit(0);

	{Modules and Cockpits have armor ratings.}
	if Part^.G = GG_Module then begin
		it := Part^.Stat[STAT_Armor];
		if Part^.S = GS_Storage then it := it + Storage_Armor_Bonus;
	end else if ( Part^.G = GG_Cockpit ) or ( Part^.G = GG_Support ) then it := Part^.Stat[STAT_Armor]
	else if ( Part^.G = GG_Shield ) then it := Part^.V * 2
	else if ( Part^.G = GG_ExArmor ) then it := Part^.V
	else if ( Part^.G = GG_MetaTerrain ) then it := Part^.V
	else if Part^.G = GG_Prop then it := Part^.V
	else it := 0;

	{ If this is an armored part, perform additional checks now. }
	if it > 0 then begin
		{ Modify armor for a GroundHugger or Arachnoid }
		M := FindMaster( Part );
		if ( M <> Nil ) and ( M^.G = GG_Mecha ) then begin
			if  M^.S = GS_GroundHugger then it := it + 2
			else if  M^.S = GS_Arachnoid then it := it + 1;
		end;
	end;
	UnscaledMaxArmor := it;
end;

Function GearMaxArmor(Part: GearPtr): Integer;
	{ Calculate how much armor protection PART has. This doesn't }
	{ include any external equipped armor.}
var
	it: Integer;
begin
	it := UnscaledMaxArmor( Part );
	if ( it > 0 ) and ( Part <> Nil ) then begin
		{Modify it for scale.}
		it := ScaleDP( it , Part^.Scale , NAV_Metal );
	end;

	GearMaxArmor := it;
end;

Function GearName(Part: GearPtr): String;
	{Determine the name of Part. If Part has a NAME attribute,}
	{this is easy. If not, locate a default name based upon}
	{Part's type.}
var
	it: String;
begin
	{Error check- make sure we aren't trying to find a name}
	{for nothing.}
	if Part = Nil then Exit( '' );

	it := SAttValue(Part^.SA,'NAME');

	if it = '' then case Part^.G of
		GG_Module:	it := ModuleName(Part);
		GG_Mecha:	it := MechaName(Part);
		GG_Character:	it := MsgString( 'CHARANAME' );
		GG_Cockpit:	it := MsgString( 'CPITNAME' );
		GG_Weapon:	it := WeaponName(Part);
		GG_Ammo:	it := AmmoName(Part);
		GG_MoveSys:	it := MoveSysName(Part);
		GG_Holder:	it := HolderName( Part );
		GG_Sensor:	it := SensorName( Part );
		GG_Support:	it := SupportName( Part );
		GG_Shield:	it := ShieldName( Part );
		GG_ExArmor:	it := ArmorName( Part );
		GG_Scene:	it := 'Scene ' + BStr( Part^.S );
		GG_Treasure:	it := MsgString( 'SWAGNAME' );
		GG_Prop:	it := MsgString( 'PROPNAME' );
		GG_MetaTerrain:	it := MsgString( 'SCENERYNAME' );
		GG_Tool:	it := MsgString( 'TOOLNAME' );
		GG_RepairFuel:	it := RepairFuelName( Part );
		GG_Consumable:	it := MsgString( 'FOODNAME' );
		GG_WeaponAddOn:	it := MsgString( 'ACCNAME' );
		GG_PowerSource: it := MsgString( 'BATTERYNAME' );
		GG_Computer:	it := MsgString( 'COMPUTERNAME' );
		GG_Software:	it := MsgString( 'SOFTWARENAME' );
		GG_Usable:	it := MsgString( 'USABLENAME_' + BStr( Part^.S ) );
		else it := {MsgString( 'UNKNOWNNAME' ) +} BStr( Part^.G ) + '/' + BStr( Part^.S ) + '/' + BStr( Part^.V );
	end;

	GearName := it;
end;

Function FullGearName(Part: GearPtr): String;
	{ Return the name + designation for this gear. }
var
	it: String;
begin
	it := SAttValue( Part^.SA , 'DESIG' );
	if it <> '' then it := it + ' ';
	FullGearName := it + GearName( Part );
end;

Function ComponentMass( Part: GearPtr ): Integer;
	{Calculate the unscaled mas of PART, ignoring for the}
	{moment its subcomponents.}
var
	it,MAV: Integer;
begin
	Case Part^.G of
		GG_Module:	it := ModuleBaseMass(Part);
		GG_Cockpit:	it := CockpitBaseMass(Part);
		GG_Weapon:	it := WeaponBaseMass(Part);
		GG_Ammo:	it := AmmoBaseMass(Part);
		GG_MoveSys:	it := MovesysBaseMass(Part);
		GG_Holder:	it := 1;
		GG_Sensor:	it := SensorBaseMass( Part );
		GG_Support:	it := SupportBaseMass( Part );
		GG_Shield:	it := ShieldBaseMass( Part );
		GG_ExArmor:	it := ArmorBaseMass( Part );
		GG_Treasure:	it := 1;
		GG_Prop:	it := Part^.V;
		GG_MetaTerrain:	it := Part^.V;
		GG_Tool:	it := ToolDamage( Part );
		GG_Consumable:	it := FoodMass( Part );
		GG_WeaponAddOn:	it := 1;
		GG_PowerSource:	it := Part^.V * 2;
		GG_Computer:	it := Part^.V * 2;
		GG_Harness:	if Part^.SubCom = Nil then it := 1 else it := 0;
		GG_Usable:	it := UsableBaseMass( Part );

	{If a component type is not listed above, it has no mass.}
	else it := 0
	end;

	{ Reduce component mass by mass adjustment value. }
	MAV := NAttValue( Part^.NA , NAG_GearOps , NAS_MassAdjust );
	it := it + MAV;
	{ Mass adjustment can't result in a negative mass. }
	if it < 0 then it := 0;

	ComponentMass := it;
end;

Function MassScaleFactor( S: LongInt ): LongInt;
	{ Return the mass scaling factor for this gear. }
	{ As of right now, only scales 0, 1, and 2 will be covered. }
const
	SFList: Array [0..2] of Integer = (1,200,1000);
begin
	if S < 0 then S := 0
	else if S > 2 then S := 2;
	MassScaleFactor := SFList[ S ];
end;

Function ScaledComponentMass( Part: GearPtr ): LongInt;
	{ Return the mass of this component, adjusted to SF:0 scale. }
begin
	if Part = Nil then Exit( 0 );
	ScaledComponentMass := ComponentMass( Part ) * MassScaleFactor( Part^.Scale );
end;

Function TrackMass( Part: GearPtr; Mode: Byte; AddThis: Boolean ): LongInt;
	{Calculate the mass of this list of gears, including all}
	{subcomponents. The mass returned will be adjusted to SF:0 units, so on }
	{ the other end make sure you convert it back to the scale you want. }
var
	it: LongInt;
begin
	{Initialize the total Mass to 0.}
	it := 0;

	{Loop through all components.}
	while Part <> Nil do begin
		{Add the mass to the total.}
		if AddThis then it := it + ScaledComponentMass(Part);

		{Check for subcomponents and invcomponents.}
		if Mode = GMMODE_AddAll then begin
			if Part^.SubCom <> Nil then it := it + TrackMass(Part^.SubCom,Mode,True);
			if Part^.InvCom <> Nil then it := it + TrackMass(Part^.InvCom,Mode,True);
		end else if Mode = GMMODE_Intrinsic then begin
			{ Calculate only the mass of pure SubComs. }
			if Part^.SubCom <> Nil then it := it + TrackMass(Part^.SubCom,Mode,True);
		end else begin
			{ Calculate only the mass of InvComs. }
			if Part^.SubCom <> Nil then it := it + TrackMass(Part^.SubCom,Mode,AddThis);
			if Part^.InvCom <> Nil then it := it + TrackMass(Part^.InvCom,Mode,True);
		end;

		{Go to the next part in the series.}
		Part := Part^.Next;
	end;

	{Return the value.}
	TrackMass := it;
end;

Function GearMass( Master: GearPtr ): Integer;
	{Calculate the mass of MASTER, including all of its}
	{subcomponents.}
begin
	{The formula to work out the total mass of this gear}
	{is basic mass + SubCom mass + InvCom mass.}
	if ( Master = Nil ) or ( Master^.G < 0 ) then begin
		GearMass := 0;
	end else begin
		GearMass := ( ScaledComponentMass(Master) + TrackMass(Master^.SubCom,GMMODE_AddAll,True) + TrackMass(Master^.InvCom,GMMODE_AddAll,True) ) div MassScaleFactor( Master^.Scale );
	end;
end;

Function IntrinsicMass( Master: GearPtr ): LongInt;
	{ Return the mass of MASTER and all its subcomponents. Do not }
	{ calculate the mass of inventory components. }
begin
	if ( Master = Nil ) or ( Master^.G < 0 ) then begin
		IntrinsicMass := 0;
	end else begin
		IntrinsicMass := ( ScaledComponentMass(Master) + TrackMass(Master^.SubCom,GMMODE_Intrinsic,True) ) div MassScaleFactor( Master^.Scale );
	end;
end;

Function EquipmentMass( Master: GearPtr ): LongInt;
	{ Return the mass of all inventory components of MASTER. Do not }
	{ include the mass of intrinsic components. }
begin
	if ( Master = Nil ) or ( Master^.G < 0 ) then begin
		EquipmentMass := 0;
	end else begin
		EquipmentMass := ( TrackMass(Master^.SubCom,GMMODE_Equipment,False) + TrackMass(Master^.InvCom,GMMODE_Equipment,True) ) div MassScaleFactor( Master^.Scale );
	end;
end;

Function MakeMassString( BaseMass: LongInt; Scale: Integer ): String;
	{ Given a mass value and a scale, create a string to express }
	{ said mass to the player. }
var
	msg: String;
	T: Integer;
begin
	if Scale >= 2 then begin
		for t := 3 to Scale do BaseMass := BaseMass * 5;
		msg := BStr( BaseMass div 2 ) + '.' + BStr( ( BaseMass mod 2 ) * 5 ) + 't';
	end else if Scale = 1 then begin
		msg := BStr( BaseMass div 10 ) + '.' + BStr( BaseMass mod 10 ) + 't';
	end else if Scale = 0 then begin
		msg := BStr( BaseMass div 2 ) + '.' + BStr( ( BaseMass mod 2 ) * 5 ) + 'kg';
	end else begin
		msg := BStr( BaseMass ) + '!';
	end;
	MakeMassString := Msg;
end;

Function MassString( Master: GearPtr ): String;
	{ Return a string describing how heavy this gear is, based upon its }
	{ scale. }
var
	BaseMass: LongInt;
begin
	BaseMass := GearMass( Master );
	MassString := MakeMassString( BaseMass , Master^.Scale );
end;

Function GearDepth( Part: GearPtr ): Integer;
	{ Calculate the depth of PART. If PART is a root level component, }
	{ depth is 0. }
var
	D: Integer;
begin
	{ Initialize D. }
	D := 0;

	{ Ascend up the structure to the root level. For each level }
	{ we have to go up, increase D by one. }
	while Part^.Parent <> Nil do begin
		Part := Part^.Parent;
		Inc( D );
	end;

	GearDepth := D;
end;

Function ComponentComplexity( Part: GearPtr ): Integer;
	{ Return the basic complexity value of this part, and only }
	{ this part. }
var
	CC: Integer;
begin
	if ( Part = Nil ) or ( Part^.G < 0 ) then begin
		CC := 0;
	end else begin
		case Part^.G of
			GG_Module: 		CC := ModuleComplexity( Part );
			GG_ExArmor,GG_Shield: 	CC := ( Part^.V + 1 ) div 2;
			GG_Weapon: 		CC := WeaponComplexity( Part );
			GG_MoveSys,GG_PowerSource: CC := Part^.V;
			GG_Computer:		CC := Part^.V;
			GG_Software:		CC := 0;
			GG_Support:		CC := 0;
			GG_Sensor:		CC := SensorComplexity( Part );
			GG_Harness:		CC := Part^.V * 2;
			GG_Usable:		CC := UsableComplexity( Part );
		else CC := 1;
		end;

		{ If the part is integral, and not a module, reduce complexity by 1 }
		{ down to a minimum value of 1. }
		if ( CC > 1 ) and ( Part^.G <> GG_Module ) and PartHasIntrinsic( Part , NAS_Integral ) then Dec( CC );
	end;

	ComponentComplexity := CC;
end;

Function SubComComplexity( Part: GearPtr ): Integer;
	{ Return the overall complexity of all of PART's subcomponents. }
var
	it: Integer;
	S: GearPtr;
begin
	it := 0;
	S := Part^.SubCom;
	while S <> Nil do begin
		if S^.Scale >= Part^.Scale then begin
			it := it + ComponentComplexity( S );
		end else begin
			Inc( it );
		end;
		S := S^.Next;
	end;
	SubComComplexity := it;
end;


Function IsLegalInvcom( Parent, Equip: GearPtr ): Boolean;
	{ Check EQUIP to see if it can be installed as a sub-component }
	{ of SLOT. Return TRUE if it can, FALSE if it can't. }
	{ This procedure only checks to make sure the slot is legal; }
	{ it doesn't check whether the slot is already occupied or }
	{ anything else. }
begin
	if ( Parent = Nil ) or ( Equip = Nil ) then begin
		{ If either of the provided gears don't really exist, }
		{ this can't very well be a legal installation, can it? }
		IsLegalInvcom := False;

	end else if Parent^.G < 0 then begin
		{ Virtal slots can hold anything. }
		IsLegalInvcom := True;

	end else if IsMasterGear( Parent ) or ( Parent^.G = GG_MetaTerrain ) then begin
		{ The inventory components of MASTER gears can hold just }
		{ about anything, since they represent the "general }
		{ inventory" from most RPGs. The only restrictions have }
		{ to do with scale and weight. }
		if Equip^.Scale > Parent^.Scale then IsLegalInvcom := False
		else if Equip^.G = GG_MetaTerrain then IsLegalInvcom := False
		else IsLegalInvcom := True;

	end else if Equip^.Scale > Parent^.Scale then begin
		{ Gears cannot equip items of a higher scale than themselves. }
		IsLegalInvCom := False;

	end else if AStringHasBString( SAttValue( Equip^.SA , 'TYPE' ) , 'CYBER' ) then begin
		{ Gears marked as "cyber" can only be internally mounted. }
		IsLegalInvcom := False;

	end else if Parent^.G = GG_Holder then begin
		{ Call the ghholder unit InvChecker to see what it says. }
		IsLegalInvcom := IsLegalHolderInv( Parent , Equip );

	end else if ( Parent^.G = GG_Weapon ) then begin
		IsLegalInvcom := IsLegalWeaponInv( Parent , Equip );

	end else if Parent^.G = GG_Module then begin
		{ Call the ghmodule unit InvChecker to see what it says. }
		if Equip^.G = GG_ExArmor then begin
			IsLegalInvcom := IsLegalModuleInv( Parent , Equip ) and ArmorFItsMaster( Equip , FindMaster( Parent ) );
		end else begin
			IsLegalInvcom := IsLegalModuleInv( Parent , Equip );
		end;

	end else begin
		{ No other slots may hold equipment. }
		IsLegalInvcom := False;
	end;
end;

Procedure CheckGearInv( Part: GearPtr );
	{ Check through a gear's Inv components, and delete any illegal }
	{ gears found. A gear is legal if it meets two requirements- }
	{ it must be legal according to the IsLegalInvcom procedure above, }
	{ and it must be the only gear with a given G value installed at }
	{ this location. }
var
	LG,LG2: GearPtr;	{ Loop Gear }
	MG: GearPtr;		{ Multiplicity Gear }
	N: Integer;		{ A number. That's all. }
begin
	LG := Part^.InvCom;
	while LG <> Nil do begin
		{ We need to save the location of the next gear, }
		{ since LG itself might get deleted. }
		LG2 := LG^.Next;

		if not IsLegalInvcom( Part , LG ) then begin
			{ LG failed the legality check. Delete it. }
			RemoveGear( Part^.InvCom , LG );
		end else if Part^.G = GG_Holder then begin
			{ Holders can only hold one item, regardless of type. }
			if NumSiblingGears( Part^.InvCom ) > 1 then begin
				RemoveGear( Part^.InvCom , LG );
			end;
		end else if ( Part^.G <> GG_MetaTerrain ) and not IsMasterGear( Part ) then begin
			{ Perform the multiplicity test. }
			N := 0;
			MG := Part^.InvCom;
			while MG <> Nil do begin
				if MG^.G = LG^.G then Inc( N );
				MG := MG^.Next;
			end;
			{ There's more than one gear here. Get rid of it. }
			if N > 1 then RemoveGear( Part^.InvCom , LG );
		end;

		LG := LG2;
	end;
end;

Function IsLegalSubcom( Parent, Equip: GearPtr ): Boolean;
	{ Check EQUIP and see if it can be a legal subcomponent of Parent. }
	{ The first rule is that EQUIP must be of a scale less than or }
	{ equal to Parent; the second rule is that it must meet whatever }
	{ conditions are set by Parent's type. }
	{ Note that this procedure only checks the legality of installation; }
	{ it does not do a multiplicity test or anything else. }
begin
	if ( Parent = Nil ) or ( Equip = Nil ) then begin
		{ If either of the provided gears don't really exist, }
		{ this can't very well be a legal installation, can it? }
		IsLegalSubcom := False;

	end else if Parent^.G < 0 then begin
		{ Virtal slots can hold anything. }
		IsLegalSubcom := True;

	end else if Equip^.Scale > Parent^.Scale then begin
		{ Can't mount a gear of larger scale than the Parent. }
		IsLegalSubcom := False;

	end else begin
		case Parent^.G of
		GG_Mecha:	IsLegalSubcom := IsLegalMechaSubCom( Parent, Equip );
		GG_Module:	IsLegalSubCom := IsLegalModuleSub( Parent, Equip );
		GG_Character:	IsLegalSubCom := IsLegalCharSub( Equip );
		GG_Cockpit:	IsLegalSubCom := IsLegalCPitSub( Parent , Equip );
		GG_Shield:	IsLegalSubCom := IsLegalShieldSub( Parent , Equip );
		GG_ExArmor:	IsLegalSubCom := IsLegalArmorSub( Equip );
		GG_Weapon:	IsLegalSubCom := IsLegalWeaponSub( Parent , Equip );
		GG_Prop:	IsLegalSubCom := True;
		GG_MetaTerrain:	IsLegalSubCom := True;
		GG_WeaponAddOn:	IsLegalSubCom := Equip^.G = GG_Weapon;
		GG_Computer:	IsLegalSubCom := IsLegalComputerSub( Parent , Equip );
		GG_Harness:	IsLegalSubCom := IsLegalHarnessSub( Equip );
		GG_Tool:	IsLegalSubCom := IsLegalToolSub( Equip );

		else IsLegalSubcom := False
		end;
	end;
end;

Function MaximumInstancesAllowed( Slot: GearPtr; Equip_G,Equip_S: Integer ): Integer;
	{ Return the maximum number of (G,S) gears that can be }
	{ installed in SLOT, or 0 if as many as wanted can be installed. }
	{ Note that the results of this function are undefined if the }
	{ part cannot be legally installed in the slot in the first place. }
begin
	if Equip_G = GG_MoveSys then begin
		MaximumInstancesAllowed := 1;
	end else if Equip_G = GG_Support then begin
		MaximumInstancesAllowed := 1;
	end else if ( Equip_G = GG_Module ) and ( Equip_S = GS_Body ) then begin
		MaximumInstancesAllowed := 1;
	end else if Equip_G = GG_Ammo then begin
		MaximumInstancesAllowed := 1;
	end else if Equip_G = GG_PowerSource then begin
		MaximumInstancesAllowed := 1;
	end else if Equip_G = GG_Holder then begin
		if ( Slot^.G = GG_Module ) and ( Slot^.S = GS_Body ) then begin
			{ Body modules may have up to two mounting points. }
			MaximumInstancesAllowed := 2;
		end else begin
			{ All other locations may have only one holder of each type. }
			MaximumInstancesAllowed := 1;
		end;
	end else begin
		MaximumInstancesAllowed := 0;
	end;
end;

Function NumberOfMatches( Parent,Exclude: GearPtr; G,S: Integer ): Integer;
	{ Count up the number of gears present which match }
	{ the descriptors G, S. }
	{ Don't count part EXCLUDE. }
var
	N: Integer;
	PSC: GearPtr;	{ Part SubCom }
begin
	N := 0;
	PSC := Parent^.SubCom;
	while PSC <> Nil do begin
		if ( PSC^.G = G ) and ( PSC^.S = S ) and ( PSC <> Exclude ) then Inc( N );
		PSC := PSC^.Next;
	end;
	NumberOfMatches := N;
end;

Function MultiplicityCheck( Slot, Item: GearPtr ): Boolean;
	{ Certain gears may only be installed a set number of times. }
	{ For instance, an arm may only have one hand, etc... This }
	{ function centralizes the multiplicity check. Return TRUE if }
	{ ITEM can be installed in SLOT, or FALSE otherwise. }
var
	it: Boolean;
	N: Integer;
	CyberSlot: String;
	Function CyberMatches: Integer;
		{ Return the number of subcoms of SLOT which bear the same }
		{ cyberslot as ITEM, excluding ITEM itself. }
	var
		N: Integer;
		PSC: GearPtr;	{ Part SubCom }
	begin
		N := 0;
		PSC := Slot^.SubCom;
		CyberSlot := UpCase( CyberSlot );
		while PSC <> Nil do begin
			if ( UpCase( SAttValue( PSC^.SA , SATT_CyberSlot ) ) = CyberSlot ) and ( PSC <> Item ) then Inc( N );
			PSC := PSC^.Next;
		end;
		CyberMatches := N;
	end;
begin
	{ Start by assuming TRUE. }
	it := True;

	{ Check the MaximumInstancesAllowed. }
	N := MaximumInstancesAllowed( Slot , Item^.G , Item^.S );
	if N > 0 then begin
		it := ( NumberOfMatches( Slot , Item , Item^.G , Item^.S ) < N );
	end;

	{ Check Cyberslot. }
	if it then begin
		CyberSlot := SAttValue( Item^.SA , SATT_CyberSlot );
		if CyberSlot <> '' then begin
			it := CyberMatches = 0;
		end;
	end;

	{ Return the result. }
	MultiplicityCheck := it;
end;

Procedure CheckGearSubs( Part: GearPtr );
	{ Examine the subcomponents of this gear to make sure everything }
	{ is nice and legal. }
	{ First do a legality check for each subcom, then do a }
	{ multiplicity test if the subcom is a type which requires that. }
var
	LG,LG2: GearPtr;	{ Loop Gear }
begin
	LG := Part^.SubCom;
	while LG <> Nil do begin
		{ We need to save the location of the next gear, }
		{ since LG itself might get deleted. }
		LG2 := LG^.Next;

		if not IsLegalSubCom( Part , LG ) then begin
			{ LG failed the legality check. Delete it. }
			RemoveGear( Part^.SubCom , LG );
		end else begin

			{ *** MULTIPLICITY CHECK *** }
			if not MultiplicityCheck( Part , LG ) then begin
				RemoveGear( Part^.SubCom , LG );
			end;
		end;

		LG := LG2;
	end;
end;

Function CanBeInstalled( Part , Equip: GearPtr ): Boolean;
	{ Return TRUE if the part can be installed, or FALSE }
	{ otherwise. }
var
	it: Boolean;
begin
	it := IsLegalSubCom( Part , Equip );

	if it then begin
		it := MultiplicityCheck( Part , Equip );

		if it and ( Equip^.G = GG_Module ) and ( Part^.G = GG_Mecha ) then begin
			it := FormXModule[ Part^.S , Equip^.S ];
		end;
	end;
	CanBeInstalled := it;
end;

Procedure CheckGearRange( Part: GearPtr );
	{ Check the G , S , V , Stat , SubCom , and InvCom values of }
	{ this gear to make sure everything is all nice and legal. }
begin
	if Part^.G = GG_Mecha then CheckMechaRange( Part )
	else if Part^.G = GG_Module then CheckModuleRange( Part )
	else if Part^.G = GG_Cockpit then CheckCPitRange( Part )
	else if Part^.G = GG_Weapon then CheckWeaponRange( Part )
	else if Part^.G = GG_Ammo then CheckAmmoRange( Part )
	else if Part^.G = GG_Holder then CheckHolderRange( Part )
	else if Part^.G = GG_MoveSys then CheckMoverRange( Part )
	else if Part^.G = GG_Sensor then CheckSensorRange( Part )
	else if Part^.G = GG_Support then CheckSupportRange( Part )
	else if Part^.G = GG_Shield then CheckShieldRange( Part )
	else if Part^.G = GG_ExArmor then CheckArmorRange( Part )
	else if Part^.G = GG_Prop then CheckPropRange( Part )
	else if Part^.G = GG_Tool then CheckToolRange( Part )
	else if Part^.G = GG_RepairFuel then CheckRepairFuelRange( Part )
	else if Part^.G = GG_Consumable then CheckFoodRange( Part )
	else if Part^.G = GG_Modifier then CheckModifierRange( Part )
	else if Part^.G = GG_WeaponAddOn then CheckWeaponAddOnRange( Part )
	else if Part^.G = GG_PowerSource then CheckPowerSourceRange( Part )
	else if Part^.G = GG_Computer then CheckComputerRange( Part )
	else if Part^.G = GG_Software then CheckSoftwareRange( Part )
	else if Part^.G = GG_Harness then CheckHarnessRange( Part )
	else if Part^.G = GG_Usable then CheckUsableRange( Part )
	;

	{ Next, check the children of this gear to make sure everything }
	{ there is all nice and legal. }
	{ Note that the children of the gear don't have to be checked }
	{ if this gear is one of the virtual types; see gears.pp for }
	{ more information about that. }
	if Part^.G >= 0 then begin
		CheckGearInv( Part );
		CheckGearSubs( Part );
	end;
end;

Function SeekGear( Master: GearPtr; G,S: Integer; CheckInv: Boolean ): GearPtr;
	{ Search through all the subcoms and invcoms of MASTER and }
	{ find a part which matches G,S. If more than one applicable }
	{ part is found, return the part with the highest V field... }
	{ Unless it's repairfuel, in which case return the one with the lowest V. }
	{ If no such part is found, return Nil. }
{ FUNCTIONS BLOCK }
	Function CompGears( P1,P2: GearPtr ): GearPtr;
		{ Given two gears, P1 and P2, return the gear with }
		{ the higest V field. }
	var
		it: GearPtr;
	begin
		it := Nil;
		if P1 = Nil then it := P2
		else if P2 = Nil then it := P1
		else if G = GG_RepairFuel then begin
			if P1^.V < P2^.V then it := P1
			else it := P2;
		end else begin
			if P1^.V > P2^.V then it := P1
			else it := P2;
		end;
		CompGears := it;
	end;

	Function SeekPartAlongTrack( P: GearPtr ): GearPtr;
		{ Search this line of sibling components for a part }
		{ which matches G , S. }
	var
		it: GearPtr;
	begin
		it := Nil;
		while P <> Nil do begin
			if ( P^.G = G ) and ( P^.S = S ) then begin
				it := CompGears( it , P );
			end;
			if P^.G <> GG_Cockpit then begin
				it := CompGears( SeekPartAlongTrack( P^.SubCom ) , it );
				if CheckInv then it := CompGears( it , SeekPartAlongTrack( P^.InvCom ) );
			end;
			P := P^.Next;
		end;
		SeekPartAlongTrack := it;
	end;

begin
	if CheckInv then
		SeekGear := CompGears( SeekPartAlongTrack( Master^.InvCom ) , SeekPartAlongTrack( Master^.SubCom ) )
	else
		SeekGear := SeekPartAlongTrack( Master^.SubCom );
end;

Function SeekGear( Master: GearPtr; G,S: Integer ): GearPtr;
	{ Seek an active gear, automatically checking the inventory as }
	{ well as the subcomponents. }
begin
	SeekGear := SeekGear( Master , G , S , True );
end;

Function SeekCurrentLevelGear( Master: GearPtr; G,S: Integer ): GearPtr;
	{ Seek a gear which is along the specified path. }
var
	CLG: GearPtr;
begin
	CLG := Nil;
	while ( Master <> Nil ) and ( CLG = Nil ) do begin
		if ( Master^.G = G ) and ( Master^.S = S ) then CLG := Master;
		Master := Master^.Next;
	end;
	SeekCurrentLevelGear := CLG;
end;

Function SeekSoftware( Mek: GearPtr; SW_Type,SW_Param: Integer; CasualUse: Boolean ): GearPtr;
	{ Attempt to locate software of the requested type. The software must be }
	{ installed in a computer, and the computer must not be destroyed. If CASUALUSE, }
	{ computers in the general inventory may be searched as well as intrinsic }
	{ computers. }
	Function CompGears( P1,P2: GearPtr ): GearPtr;
		{ Given two software gears, P1 and P2, return the gear with }
		{ the higest V field. }
	var
		it: GearPtr;
	begin
		it := Nil;
		if P1 = Nil then it := P2
		else if P2 = Nil then it := P1
		else begin
			if P1^.V > P2^.V then it := P1
			else it := P2;
		end;
		CompGears := it;
	end;

	Function SeekPartAlongTrack( P: GearPtr ): GearPtr;
		{ Search this line of sibling components for a part }
		{ which matches G , S. }
	var
		it: GearPtr;
	begin
		it := Nil;
		while P <> Nil do begin
			if ( P^.G = GG_Software ) and ( P^.Parent <> Nil ) and ( P^.Parent^.G = GG_Computer ) and ( P^.Stat[ STAT_SW_Type ] = SW_Type ) and ( P^.Stat[ STAT_SW_Param ] = SW_Param ) then begin
				it := CompGears( it , P );
			end;
			if NotDestroyed( P ) then begin
				it := CompGears( SeekPartAlongTrack( P^.SubCom ) , it );
				it := CompGears( it , SeekPartAlongTrack( P^.InvCom ) );
			end;
			P := P^.Next;
		end;
		SeekPartAlongTrack := it;
	end;
var
	it: GearPtr;
begin
	it := SeekPartAlongTrack( Mek^.SubCom );
	if CasualUse then it := CompGears( it , SeekPartAlongTrack( Mek^.InvCom ) );
	SeekSoftware := it;
end;

Function GearEncumberance( Mek: GearPtr ): Integer;
	{ Return how many unscaled mass units this gear may carry without }
	{ incurring a penalty. }
var
	HM: Integer;
begin
	if Mek = Nil then begin
		GearEncumberance := 0;
	end else if Mek^.G = GG_Mecha then begin
		{ Encumberance value is basic MassPerMV + Size of mecha + bonus for heavy Actuator. }
		HM := CountActivePoints( Mek , GG_MoveSys , GS_HeavyActuator ) div Mek^.V;
		if HM > 2 then HM := 2;
		GearEncumberance := MassPerMV + Mek^.V + HM;
	end else if Mek^.G = GG_Character then begin
		{ Encumberance value is BODY stat + 5 + exponential bonus for BODY > 10. }
		HM := CStat( Mek , STAT_Body );
		if HM > 10 then HM := HM + ( HM * HM div 25 ) - 3;
		GearEncumberance := HM + 5 + CountActivePoints( Mek , GG_MoveSys , GS_HeavyActuator ) * 2;
	end else begin
		GearEncumberance := 0;
	end;
end;

Function BaseMVTVScore( Mek: GearPtr ): Integer;
	{ Calculate the basic MV/TV score, ignoring for the moment }
	{ such things as form, tarcomps, gyros, falafel, etc. }
var
	IMass,EMass: LongInt;
	MV,EV: Integer;
	CPit: GearPtr;
begin
	MV := 0;

	{ Basic MV/TV is determined by the gear's mass and it's equipment. }
	IMass := IntrinsicMass( Mek );
	EV := GearEncumberance( Mek );
	if EV < 1 then EV := 1;
	EMass := EquipmentMass( Mek ) - EV;
	if EMass < 0 then EMass := 0;

	MV := - ( IMass div MassPerMV + EMass div EV );

	{ Seek the cockpit. If it's located in the head, +1 to MV and TR. }
	CPit := SeekGear( Mek , GG_Cockpit , 0 , False );
	if CPit <> Nil then begin
		{ The head bonus only applies for those forms which are cleared }
		{ to use their heads. }
		if InGoodModule( CPit ) and ( FindModule( CPit )^.S = GS_Head ) then Inc( MV );
	end;

	{ Seek the engine. If it's high performance, +1 to both MV and TR. }
	CPit := SeekGear( Mek , GG_Support , GS_Engine , False );
	if CPit <> Nil then begin
		if CPit^.Stat[ STAT_EngineSubType ] = EST_HighPerformance then MV := MV + 1;
	end;

	BaseMVTVScore := MV;
end;

Function ManeuverCost( Mek: GearPtr ): Integer;
	{ Determine the MV cost multiplier for this mecha. }
	{ A high MV results in a high multiplier; an augmented MV }
	{ (by Gyros or other systems) increases that multiplier }
	{ considerably. }
var
	MC,BMV,MV: Integer;
	SW: GearPtr;
begin
	{ Error check- MV can only be calculated for valid mecha. }
	if (Mek = Nil) or (Mek^.G <> GG_Mecha) then Exit( 0 );

	{ Find the basic maneuver value. }
	BMV := FormMVBonus[ Mek^.S ] + BaseMVTVScore( Mek );
	MV := BMV;

	{ Add the software bonus. }
	SW := SeekSoftware( Mek , S_MVBoost , Mek^.Scale , False );
	if SW <> Nil then MV := MV + SW^.V;

	{ Up to this point, no modifiers should take MV above 0. }
	if MV > 0 then MV := 0;

	{ Calculate the basic Maneuver Cost, in percentage. }
	if MV < -5 then begin
		MC := -35;
	end else if MV < 0 then begin
		MC := -5 - MV * MV;
	end else MC := 0;

	ManeuverCost := MC;
end;

Function TargetingCost( Mek: GearPtr ): Integer;
	{ Determine the TR cost multiplier for this mecha. }
	{ A high TR results in a high multiplier; an augmented TR }
	{ (by TarComp or other systems) increases that multiplier }
	{ considerably. }
var
	TC,BTR,TR: Integer;
	SW: GearPtr;	{ Software }
begin
	{ Error check- MV can only be calculated for valid mecha. }
	if (Mek = Nil) or (Mek^.G <> GG_Mecha) then Exit( 0 );

	BTR := FormTRBonus[ Mek^.S ] + BaseMVTVScore( Mek );
	TR := BTR;

	{ Add the software bonus. }
	SW := SeekSoftware( Mek , S_TRBoost , Mek^.Scale , False );
	if SW <> Nil then TR := TR + SW^.V;

	{ Up to this point, no modifiers should take TR above 0. }
	if TR > 0 then TR := 0;

	{ Calculate the basic Targeting Cost, in percentage. }
	if TR < -5 then begin
		TC := -30;
	end else if TR < 0 then begin
		TC := -5 - (TR * TR) + 2 * Abs( TR );
	end else TC := 0;

	TargetingCost := TC;
end;


Function ComponentValue( Part: GearPtr; CalcCost,FullLoad: Boolean ): LongInt;
	{Calculate the scaled value of PART, ignoring for the}
	{moment its subcomponents.}
	{ If CALCCOST is TRUE, we are calculating the cost of this component }
	{ rather than its value. Add in the fudge factor and other modifiers. }
	{ If FULLLOAD is TRUE, ignore any spent bullets or expended capabilities }
	{ and return the value as though PART were fully loaded. }
var
	it: LongInt;
	t,n,MAV: Integer;
begin
	Case Part^.G of
		GG_Module:	it := ModuleValue( Part );
		GG_Weapon:	it := WeaponValue(Part);
		GG_Ammo:	if FullLoad then it := BaseAmmoValue( Part )
				else it := AmmoValue(Part);
		GG_MoveSys:	it := MovesysValue(Part);
		GG_Holder:	it := 15;
		GG_ExArmor:	it := ArmorValue( Part );
		GG_Cockpit:	it := 25 * Part^.Stat[ STAT_Armor ];
		GG_Sensor:	it := SensorValue( Part );
		GG_Support:	it := SupportValue( Part );
		GG_Shield:	it := ShieldValue( Part );
		GG_Treasure:	if CalcCost then it := 5
				else it := 0;
		GG_Tool:	it := ToolValue( Part );
		GG_RepairFuel:	it := RepairFuelValue( Part );
		GG_Consumable:	if CalcCost then it := FoodValue( Part )
				else it := 0;
		GG_Modifier:	it := ModifierCost( Part );
		GG_WeaponAddOn:	it := WeaponAddOnCost( Part );
		GG_PowerSource: it := PowerSourceCost( Part );
		GG_Computer:	it := ComputerValue( Part );
		GG_Software:	it := SoftwareValue( Part );
		GG_Harness:	it := HarnessValue( Part );
		GG_Mecha:	it := MechaCost( Part );
		GG_Usable:	it := UsableValue( Part );

	{If a component type is not listed above, it has no value.}
	else it := 0
	end;

	{ Modify for mass adjustment. }
	MAV := NAttValue( PArt^.NA , NAG_GearOps , NAS_MassAdjust );

	{ If at scale 0, mass reduction is FAR more expensive. }
	if ( Part^.Scale = 0 ) and ( MAV < 0 ) then MAV := MAV * 5;
	if ( MAV > 0 ) and ( it > 0 ) then begin
		it := ( it * ( MassPerMV * 4 - MAV ) ) div ( MassPerMV * 4 );
		if it < 1 then it := 1;
	end else if MAV < 0 then begin
		it := it * ( MassPerMV + Abs( MAV )) div MassPerMV;
	end;

	{ Modify for material. }
	if NAttValue( Part^.NA , NAG_GearOps , NAS_Material ) = NAV_BioTech then begin
		if Part^.G = GG_Mecha then begin
			it := Part^.V * 250;
		end else begin
			it := ( it * 3 ) div 2;
		end;
	end;

	{ Modify for being overstuffed. }
	if not IsMasterGear( Part ) then begin
		N := ComponentComplexity( Part );
		T := SubComComplexity( Part );
		if ( N < T ) and ( T > 0 ) then begin
			it := ( it * ( 10 + T - N ) ) div 10;
		end;
	end;

	{ Modify for scale. }
	if ( it > 0 ) and ( Part^.Scale > 0 ) then begin
		{ GH2- all high-scale items now are double the price, then x5 per scale. }
		{ This is done to compensate for the changes made to the MV/TR cost calculator. }
		it := it * 2;
		for t := 1 to Part^.Scale do it := it * 5;
	end else if CalcCost and ( it > 0 ) and ( Part^.Scale = 0 ) then begin
		{ Increase consumer cost of all SF:0 equipment. }
		it := it * 5;
	end;

	{ Modify for intrinsics. }
	it := it + IntrinsicCost( Part );

	{ Modify for Fudge and Discount. }
	if CalcCost then begin
		it := it + NAttValue( Part^.NA , NAG_GearOps , NAS_Fudge );
		t := NAttValue( Part^.NA , NAG_GearOps , NAS_CostAdjust );
		if t < -90 then t := -90;
		if t <> 0 then it := ( it * ( t + 100 ) ) div 100;
	end;

	ComponentValue := it;
end;

Function TrackValue( Part: GearPtr; CalcCost: Boolean ): LongInt;
	{Calculate the value of this list of gears, including all}
	{subcomponents.}
var
	it: LongInt;
begin
	{Initialize the total Value to 0.}
	it := 0;

	{Loop through all components.}
	while Part <> Nil do begin
		it := it + ComponentValue( Part , CalcCost , False );

		{Check for subcomponents and invcomponents.}
		if Part^.SubCom <> Nil then it := it + TrackValue(Part^.SubCom , CalcCost);
		if Part^.InvCom <> Nil then it := it + TrackValue(Part^.InvCom , CalcCost);

		{Go to the next part in the series.}
		Part := Part^.Next;
	end;

	{Return the value.}
	TrackValue := it;
end;

Function BaseGearValue( Master: GearPtr; CalcCost: Boolean ): LongInt;
	{Calculate the value of MASTER, including all of its}
	{subcomponents.}
begin
	{The formula to work out the total value of this gear}
	{is basic value + SubCom value + InvCom value.}
	BaseGearValue := ComponentValue( Master , CalcCost , False ) + TrackValue( Master^.SubCom , CalcCost ) + TrackValue( Master^.InvCom , CalcCost );
end;

Function GearCost( Master: GearPtr ): LongInt;
	{ Return the cash value of this gear. }
begin
	GearCost := BaseGearValue( Master , True );
end;

Function GearValue( Master: GearPtr ): LongInt;
	{ Calculate the value of this gear, adjusted for mecha stats. }
var
	it: Int64;	{ Using a larger container than the cost needs so as to catch }
	MV: LongInt;	{ overflow when doing calculations. }
begin
	it := BaseGearValue( Master , False );

	{ Mecha have a special on-top-of-everything cost modifier for }
	{ a high MV or TR. }
	if Master^.G = GG_Mecha then begin
		MV := ManeuverCost( Master );
		it := ( it * ( 100 + MV ) ) div 100;

		{ The same rule applies for targeting. }
		MV := TargetingCost( Master );
		it := ( it * ( 100 + MV ) ) div 100;

	end;

	GearValue := it;
end;

function SeekGearByName( LList: GearPtr; Name: String ): GearPtr;
	{ Seek a gear with the provided name. If no such gear is }
	{ found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	Name := UpCase( Name );
	while LList <> Nil do begin
		if UpCase( GearName( LList ) ) = Name then it := LList;
		if ( it = Nil ) then it := SeekGearByName( LList^.SubCom , Name );
		if ( it = Nil ) then it := SeekGearByName( LList^.InvCom , Name );
		LList := LList^.Next;
	end;
	SeekGearByName := it;
end;

function SeekSibByFullName( LList: GearPtr; Name: String ): GearPtr;
	{ Seek a gear with the provided full name. If no such gear is }
	{ found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	Name := UpCase( Name );
	while ( LList <> Nil ) and ( it = Nil ) do begin
		if UpCase( FullGearName( LList ) ) = Name then it := LList;
		LList := LList^.Next;
	end;
	SeekSibByFullName := it;
end;

function SeekChildByName( Parent: GearPtr; Name: String ): GearPtr;
	{ Look for a gear that's a child of this gear. }
var
	it: GearPtr;
begin
	it := Nil;
	Name := UpCase( Name );
	if UpCase( GearName( Parent ) ) = Name then it := Parent;
	if it = Nil then it := SeekGearByName( Parent^.SubCom , Name );
	if it = Nil then it := SeekGearByName( Parent^.InvCom , Name );
	SeekChildByName := it;
end;

function SeekGearByDesig( LList: GearPtr; Name: String ): GearPtr;
	{ Seek a gear with the provided designation. If no such gear is }
	{ found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	Name := UpCase( Name );
	while LList <> Nil do begin
		if UpCase( SAttValue( LList^.SA , 'DESIG' ) ) = Name then it := LList;
		if ( it = Nil ) then it := SeekGearByDesig( LList^.SubCom , Name );
		if ( it = Nil ) then it := SeekGearByDesig( LList^.InvCom , Name );
		LList := LList^.Next;
	end;
	SeekGearByDesig := it;
end;

function SeekGearByIDTag( LList: GearPtr; G,S,V: LongInt ): GearPtr;
	{ Seek a gear which posesses a NAtt with the listed G,S,V score. }
	{ Normally this procedure will be used to find things based on }
	{ ID numbers like Personal/CID or Narrative/NID, but I guess you }
	{ could use it to find a part that's taken Damage/Struct/40 or }
	{ whatever. }
var
	it: GearPtr;
begin
	it := Nil;
	while LList <> Nil do begin
		if NAttValue( LList^.NA , G , S ) = V then it := LList;
		if ( it = Nil ) then it := SeekGearByIDTag( LList^.SubCom , G , S , V );
		if ( it = Nil ) then it := SeekGearByIDTag( LList^.InvCom , G , S , V );
		LList := LList^.Next;
	end;
	SeekGearByIDTag := it;
end;

function CountGearsByIDTag( LList: GearPtr; G,S,V: LongInt ): LongInt;
	{ Count the number of non-destroyed gears which posess this ID tag. }
var
	N: LongInt;
begin
	N := 0;
	while LList <> Nil do begin
		if ( NAttValue( LList^.NA , G , S ) = V ) and NotDestroyed( LList ) then Inc( N );
		N := N + CountGearsByIDTag( LList^.SubCom , G , S , V );
		N := N + CountGearsByIDTag( LList^.InvCom , G , S , V );
		LList := LList^.Next;
	end;
	CountGearsByIDTag := N;
end;


function SeekGearByG( LList: GearPtr; G: Integer ): GearPtr;
	{ Seek a gear with the provided general type. }
	{ If no such gear is found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	while ( LList <> Nil ) and ( it = Nil ) do begin
		if LList^.G = G then it := LList;
		if ( it = Nil ) then it := SeekGearByG( LList^.SubCom , G );
		if ( it = Nil ) then it := SeekGearByG( LList^.InvCom , G );
		LList := LList^.Next;
	end;
	SeekGearByG := it;
end;

function SeekSubsByG( LList: GearPtr; G: Integer ): GearPtr;
	{ As above, but only check subcoms. }
	{ If no such gear is found, return NIL. }
var
	it: GearPtr;
begin
	it := Nil;
	while ( LList <> Nil ) and ( it = Nil ) do begin
		if LList^.G = G then it := LList;
		if ( it = Nil ) then it := SeekGearByG( LList^.SubCom , G );
		LList := LList^.Next;
	end;
	SeekSubsByG := it;
end;

function MaxIDTag( LList: GearPtr; G,S: Integer ): LongInt;
	{ Find the maximum NAtt value whose G and S descriptors match }
	{ those which have been provided. This function can be used to }
	{ find a new unique ID for a character or puzzle item added to an }
	{ existing campaign. }
var
	IT,N: LongInt;
begin
	it := 1;
	while LList <> Nil do begin
		{ Check this item. }
		N := NAttValue( LList^.NA , G , S );
		if N > IT then it := N;

		{ Check its children. }
		N := MaxIDTag( LList^.SubCom , G , S );
		if N > IT then it := N;
		N := MaxIDTag( LList^.InvCom , G , S );
		if N > IT then it := N;

		{ Move to the next item. }
		LList := LList^.Next;
	end;
	MaxIDTag := it;
end;

Function EncumberanceLevel( PC: GearPtr ): Integer;
	{ Return a value indicating this character's current }
	{ encumberance level. }
var
	EMass,EV: Integer;
begin
	EV := GearEncumberance( PC );
	if EV < 1 then EV := 1;
	EMass := EquipmentMass( PC ) - EV;

	{ For characters, allow a greater amount of "free" weight. }
	if PC^.G = GG_Character then begin
		EMass := EMass - EV;
	end;

	if EMass > 0 then begin
		EncumberanceLevel := EMass div EV;
	end else begin
		EncumberanceLevel := 0;
	end;
end;

function CStat( PC: GearPtr; Stat: Integer ): Integer;
	{ Player character statistics may be improved or hindered }
	{ by any number of things- equipment, encumberance, status }
	{ effects, training, et cetera. }
const
	Hunger_Stat_Rank: Array [1..NumGEarStats] of Byte = (
		5, 3, 1, 4, 6, 7, 2, 0
	);
	Morale_Stat_Rank: Array [1..NumGEarStats] of Byte = (
		30, 20, 50, 40, 70, 10, 60, 80
	);
var
	it,SP,MP,Tenths: Integer;
	MG,AG: GearPtr;	{ Modifier Gears, Armor Gears. }
	SFX: NAttPtr;	{ Status Effects. }
begin
	if ( PC = Nil ) or ( PC^.G <> GG_Character ) or ( Stat < 1 ) or ( Stat > NumGearStats ) then begin
		CStat := 0;
	end else begin
		it := PC^.Stat[ Stat ];

		{ SPEED and REFLEXES are penalized by encumberance. }
		if ( STAT = STAT_SPeed ) then begin
			it := it - EncumberanceLevel( PC );
		end else if ( STAT = STAT_Reflexes ) then begin
			it := it - ( EncumberanceLevel( PC ) div 2 );
		end;

		{ All stats are penalized by exhaustion. }
		SP := CharStamina( PC ) - NAttValue( PC^.NA , NAG_Condition , NAS_StaminaDown );
		MP := CharMental( PC ) - NAttValue( PC^.NA , NAG_Condition , NAS_MentalDown );
		if ( SP < 1 ) and ( MP < 1 ) then begin
			it := it - 3;
		end else if ( SP < 1 ) or ( MP < 1 ) then begin
			it := it - 1;
		end;

		{ Hungry PCs get penalized. }
		MP := NAttValue( PC^.NA , NAG_Condition , NAS_Hunger ) - Hunger_Penalty_Starts - NumGearStats;
		if MP > 0 then begin
			it := it - ( ( MP + Hunger_Stat_Rank[ STAT ] ) div NumGearStats );
		end;

		{ Demoralized PCs get penalized. }
		MP := NAttValue( PC^.NA , NAG_Condition , NAS_MoraleDamage );
		if ( MP + Morale_Stat_Rank[ STAT ] ) > 100 then begin
			it := it - 1;
		end else if ( MP - Morale_Stat_Rank[ STAT ] ) < -100 then begin
			it := it + 1;
		end;

		{ Check for modifier gears. }
		MG := PC^.SubCom;
		tenths := 0;
		while MG <> Nil do begin
			if ( MG^.G = GG_Modifier ) and ( MG^.S = GS_StatModifier ) then begin
				it := it + MG^.Stat[ STAT ];
			{ GH2 v0.211 - Also check for stat-modifying armor. }
			end else if ( MG^.G = GG_Module ) and ( MG^.Scale = 0 ) then begin
				AG := SeekCurrentLevelGear( MG^.InvCom , GG_EXArmor , MG^.S );
				if ( AG <> Nil ) and ( AG^.Stat[ STAT ] <> 0 ) and NoTDestroyed( AG ) and NotDestroyed( MG ) then begin
					tenths := tenths + AG^.Stat[ STAT ];
				end;
			end;
			MG := MG^.Next;
		end;

		{ Add the modifier from ExArmor. }
		it := it + ( Tenths div 10 );

		{ If there's another master, i.e. a mecha, add in the }
		{ modifiers from there as well. }
		if ( PC^.Parent <> Nil ) and ( FindMaster( PC^.Parent ) <> Nil ) then begin
			MG := FindMaster( PC^.Parent )^.SubCom;
			while MG <> Nil do begin
				if ( MG^.G = GG_Modifier ) and ( MG^.S = GS_StatModifier ) then begin
					it := it + MG^.Stat[ STAT ];
				end;
				MG := MG^.Next;
			end;
		end;

		{ Check status effects. }
		SFX := PC^.NA;
		while SFX <> Nil do begin
			if ( SFX^.G = NAG_StatusEffect ) and ( SFX^.S >= 1 ) and ( SFX^.S <= Num_Status_FX ) then begin
				it := it + SX_StatMod[ SFX^.S , Stat ];
			end;
			SFX := SFX^.Next;
		end;

		{ Stats never drop below 1. }
		if it < 1 then it := 1;

		CStat := it;
	end;
end;

Procedure WriteCGears( var F: Text; G: GearPtr );
	{ This procedure writes to file F a compacted list of gears. }
	{ Hopefully, it will be an efficient procedure, saving }
	{ only as much data as is needed. }
var
	Sam: GearPtr;	{ The sample gear, for comparing standard values. }
	msg: String;	{ A single line for the save file. }
	T: Integer;
	NA: NAttPtr;	{ Numeric Attribute pointer }
	SA: SAttPtr;	{ String Attribute pointer }
begin
	{ Allocate memory for our SAMple. }
	Sam := NewGear( Nil );

	while G <> Nil do begin
		{ Write the proceed value here. }
		{ Record G , S , V , and Scale. }
		msg := BStr( SaveFileContinue ) + ' ' + BStr( G^.G ) + ' ' + BStr( G^.S ) + ' ' + BStr( G^.V ) + ' ' + BStr( G^.Scale );
		writeln( F , msg );

		{ Compare the other gear values to an initialized Sam. }
		Sam^.G := G^.G;
		Sam^.S := G^.S;
		Sam^.V := G^.V;
		InitGear( Sam );

		{ Export a single line to record any stats this gear has }
		{ which differ from the default values. }
		msg := 'Stats ';
		for t := 1 to NumGearStats do begin
			if G^.Stat[T] <> Sam^.Stat[T] then begin
				msg := msg + BStr( T ) + ' ' + BStr( G^.Stat[T] ) + ' ';
			end;
		end;
		writeln( F , msg );

		{ Export Numeric Attributes }
		NA := G^.NA;
		while NA <> Nil do begin
			msg := BStr( SaveFileContinue ) + ' ' + BStr( NA^.G ) + ' ' + BStr( NA^.S ) + ' ' + BStr( NA^.V );
			writeln( F , msg );
			NA := NA^.Next;
		end;
		{ Write the sentinel line here. }
		writeln( F , SaveFileSentinel );

		{ Export String Attributes }
		SA := G^.SA;
		while SA <> Nil do begin
			{ Error check- only output valid string attributes. }
			if Pos('<',SA^.Info) > 0 then writeln( F , SA^.Info );
			SA := SA^.Next;
		end;
		{ Write the sentinel line here. }
		writeln( F , 'Z' );

		{ Export the subcomponents and invcomponents of this gear. }
		WriteCGears( F , G^.InvCom );
		WriteCGears( F , G^.SubCom );

		{ Move to the next gear in the list. }
		G := G^.Next;
	end;

	{ Write the sentinel line here. }
	writeln( F , SaveFileSentinel );

	{ Deallocate SAM. }
	DisposeGear( Sam );
end;

Function ReadCGears( var F: Text ): GearPtr;
	{ Read a series of gears which have been saved by the SaveGears }
	{ procedure. The 'C' means Compact. }

	Function ReadNumericAttributes( var it: NAttPtr ): NAttPtr;
		{ Read some numeric attributes from the file. }
	var
		N,G,S: Integer;
		V: LongInt;
		TheLine: String;
	begin
		{ Keep processing this file until either the sentinel }
		{ is encountered or we run out of data. }
		repeat
			{ read the next line of the file. }
			readln( F , TheLine );

			{ Error check- if we got a blank line, that's an error. }
			if TheLine = '' then Break;

			{ Extract the action code. }
			N := ExtractValue( TheLine );

			{ If this action code implies that there's a gear }
			{ to load, get to work. }
			if N = SaveFileContinue then begin
				{ Read the specific values of this NAtt. }
				G := ExtractValue( TheLine );
				S := ExtractValue( TheLine );
				V := ExtractValue( TheLine );
				SetNAtt( it , G , S , V );
			end;
		until ( N = SaveFileSentinel ) or EoF( F );

		ReadNumericAttributes := it;
	end;

	Function ReadStringAttributes( var it: SAttPtr ): SAttPtr;
		{ Read some string attributes from the file. }
	var
		TheLine: String;
	begin
		{ Keep processing this file until either the sentinel }
		{ is encountered or we run out of data. }
		repeat
			{ read the next line of the file. }
			readln( F , TheLine );

			{ If this is a valid string attribute, file it. }
			if Pos('<',TheLine) > 0 then begin
				SetSAtt( it , TheLine );
			end;
		until ( Pos('<',TheLine) = 0 ) or EoF( F );

		ReadStringAttributes := it;
	end;

	Function REALReadGears( Parent: GearPtr ): GearPtr;
		{ This is the workhorse procedure. It's the part that }
		{ actually does the reading from disk. }
	var
		it,Part: GearPtr;
		TheLine: String; { The info is read one text line at a time. }
		N,G,S,V,Scale: Integer;
	begin
		{ Initialize our gear list to NIL. }
		it := Nil;

		{ Keep processing this file until either the sentinel }
		{ is encountered or we run out of data. }
		repeat
			{ read the next line of the file. }
			readln( F , TheLine );

			{ Extract the action code. }
			N := ExtractValue( TheLine );

			{ If this action code implies that there's a gear }
			{ to load, get to work. }
			if N = SaveFileContinue then begin
				{ Extract the remaining values from the line. }
				G := ExtractValue( TheLine );
				S := ExtractValue( TheLine );
				V := ExtractValue( TheLine );
				Scale := ExtractValue( TheLine );

				{ Add a new gear to the list, and initialize it. }
				Part := AddGear( it , Parent );
				Part^.G := G;
				Part^.S := S;
				Part^.V := V;

				InitGear( Part );

				{ Clear any numeric attributes that may }
				{ have been set by InitGear. }
				if Part^.NA <> Nil then DisposeNAtt( Part^.NA );

				{ Set SCALE to the stored value, since }
				{ INITGEAR probably set it to parent scale. }
				Part^.Scale := Scale;

				{ Read the stats line, and save it for now. }
				readln( F , TheLine );

				{ Remove the STATS tag }
				ExtractWord( TheLine );
				{ Keep processing until we run out of string. }
				while TheLine <> '' do begin
					{ Determine what stat to adjust. }
					G := ExtractValue( TheLine );
					V := ExtractValue( TheLine );
					{ If this is a legal stat, adjust it. Otherwise, ignore. }
					if ( G > 0 ) and ( G <= NumGearStats ) then begin
						Part^.Stat[G] := V;
					end;
				end;

				{ Read Numeric Attributes }
				ReadNumericAttributes( Part^.NA );

				{ Read String Attributes }
				ReadStringAttributes( Part^.SA );

				{ Read InvComs }
				Part^.InvCom := RealReadGears( Part );

				{ Read SubComs }
				Part^.SubCom := RealReadGears( Part );
			end;

		until ( N = SaveFileSentinel ) or EoF( F );

		RealReadGears := it;
	end;

begin
	{ Call the real procedure with a PARENT value of Nil. }
	ReadCGears := REALReadGears( Nil );
end;



Function WeaponDC( Attacker: GearPtr ): Integer;
	{ Calculate the amount of damage that this gear can do when used }
	{ in an attack. }
var
	D: Integer;
	Master,Ammo: GearPtr;
	Procedure ApplyCCBonus;
		{ Apply the close combat bonus for weapons. }
	const
		HeavyAct_Denominator = 4;
	var
		Module: GearPtr;
		HeavyActuator: Integer;
	begin
		if Master <> Nil then begin
			if Master^.G = GG_Character then begin
				D := D + ( CStat( Master, STAT_Body ) - 10 ) div 2;

				{ Martial Arts attacks get a bonus based on skill level. }
				if Attacker^.G = GG_Module then begin
					D := D + ( CharaSkillRank( Master , NAS_CloseCombat ) + 1 ) div 2;
				end;

				if D < 1 then D := 1;
			end else if Master^.G = GG_Mecha then begin
				D := D + ( Master^.V - 1 ) div 2;

				{ May also get a bonus from heavy Actuator. }
				HeavyActuator := CountActivePoints( Master , GG_MoveSys , GS_HeavyActuator );
				if HeavyActuator > 0 then D := D + ( HeavyActuator div HeavyAct_Denominator );

				{ Having an oversized module gives a +1 bonus to damage. }
				Module := FindModule( Attacker );
				if Module <> Nil then begin
					if Module^.V > Master^.V then Inc( D );
				end;

				{ Zoanoids get a CC damage bonus. Apply that here. }
				if Master^.S = GS_Zoanoid then begin
					D := D + ZoaDmgBonus;
				end;
			end;
		end;
	end;
begin
	{ Error check - make sure we have a valid weapon. }
	if Attacker = Nil then Exit( 0 );

	{ Locate the master of this gear. }
	Master := FindMaster( Attacker );

	if Attacker^.G = GG_Weapon then begin
		D := Attacker^.V;

		{ Apply damage bonuses here. }
		if ( Attacker^.S = GS_Melee ) or ( Attacker^.S = GS_EMelee ) then begin
			ApplyCCBonus;
		end else if ( Attacker^.S = GS_Ballistic ) then begin
			{ A ballistic weapon can do no more damage than its ammunition will allow. }
			Ammo := LocateGoodAmmo( Attacker );
			if ( Ammo <> Nil ) and ( Ammo^.V < D ) then D := Ammo^.V;
		end else if ( Attacker^.S = GS_Missile ) then begin
			{ The damage of a missile is determined by the missile. Duh. }
			Ammo := LocateGoodAmmo( Attacker );
			if Ammo <> Nil then D := Ammo^.V
			else D := 0;
		end;

	end else if Attacker^.G = GG_Module then begin
		D := Attacker^.V div 2;
		if Attacker^.S = GS_Leg then D := D + 1;
		if D < 1 then D := 1;
		ApplyCCBonus;

	end else if Attacker^.G = GG_Ammo then begin
		D := Attacker^.V;

	end else begin
		D := 0;
	end;

	{ Apply bonuses for weapon add-ons. }
	Master := Attacker^.InvCom;
	while Master <> Nil do begin
		if ( Master^.G = GG_WeaponAddOn ) and NotDestroyed( Master ) then begin
			D := D + Master^.V;
		end;
		Master := Master^.Next;
	end;

	WeaponDC := D;
end;

Function AmountOfDamage( Part: GearPtr; PlusArmor: Boolean ): LongInt;
	{ Return the amount of damage this part has taken. If PlusArmor is true }
	{ then include the armor damage; otherwise just return the structural damage. }
var
	it: LongInt;
	SP: GearPtr;
begin
	it := 0;
	if Part <> Nil then begin
		it := it + NAttValue( Part^.NA , NAG_Damage , NAS_StrucDamage );
		if PlusArmor then it := it + NAttValue( Part^.NA , NAG_Damage , NAS_ArmorDamage );
		SP := Part^.SubCom;
		while SP <> Nil do begin
			it := it + AmountOfDamage( SP , PlusArmor );
			SP := SP^.Next;
		end;
		SP := Part^.InvCom;
		while SP <> Nil do begin
			it := it + AmountOfDamage( SP , PlusArmor );
			SP := SP^.Next;
		end;
	end;
	AmountOfDamage := it;
end;

Function GearCurrentDamage(Part: GearPtr): LongInt;
	{Calculate the current remaining damage points for}
	{this gear.}
var
	it: LongInt;
begin
	it := GearMaxDamage(Part);
	if it > 0 then begin
		it := it - NAttValue(Part^.NA,NAG_Damage,NAS_StrucDamage);
		if it < 0 then it := 0;
	end;
	GearCurrentDamage := it;
end;

Function GearCurrentArmor(Part: GearPtr): Integer;
	{Calculate the current remaining armor PV for}
	{this gear.}
var
	it: Integer;
begin
	if ( Part <> Nil ) and ( Part^.G >= 0 ) then begin
		it := GearMaxArmor(Part);
		it := it - NAttValue( Part^.NA , NAG_Damage , NAS_ArmorDamage );
		if it < 0 then it := 0;
	end else begin
		it := 0;
	end;
	GearCurrentArmor := it;
end;

Function PercentDamaged( Master: GearPtr ): Integer;
	{ Add up the damage scores of every part on this mecha, and }
	{ return the percentage of undamaged mek. }
var
	MD,CD: LongInt;		{ Max Damage , Current Damage }

	procedure CheckPart( Part: GearPtr );
		{ Examine this part and its children for damage. }
	var
		D: Integer;
		SPart: GearPtr;
	begin
		D := GearMaxDamage( Part );
		if D > 0 then begin
			MD := MD + D;
			CD := CD + GearCurrentDamage( Part );
		end;

		{ Check sub components. }
		SPart := Part^.SubCom;
		while SPart <> Nil do begin
			CheckPart( SPart );
			SPart := SPart^.Next;
		end;

		{ Check inv components. }
		SPart := Part^.InvCom;
		while SPart <> Nil do begin
			CheckPart( SPart );
			SPart := SPart^.Next;
		end;
	end;
begin
	MD := 0;
	CD := 0;
	CheckPart( Master );

	{ Error check - don't divide by 0. }
	if MD < 1 then MD := 1;
	PercentDamaged := ( CD * 100 ) div MD;
end;

Function NotDestroyed(Part: GearPtr): Boolean;
	{Check this part and see whether or not it's been}
	{destroyed. For most parts, it isn't destroyed if it}
	{has any hits remaining. For parts whose HP = -1, the}
	{part counts as not destroyed if it has any not-destroyed}
	{subcomponents. For master gears, the not destroyed check}
	{might be a bit more complicated...}
var
	CD: Integer;
	it: Boolean;
begin
	if Part = Nil then begin
		{ Error Check - Undefined parts automatically count }
		{   as destroyed. }
		it := False;

	end else if Part^.G < 0 then begin
		{ Virtual types never count as destroyed. }
		it := True;

	end else if ( Part^.G = GG_Shield ) or ( Part^.G = GG_ExArmor ) then begin
		{ Armor type gears count as not destroyed if they have }
		{ any armor rating left. }
		CD := GearCurrentArmor(Part);
		it := CD > 0;

	end else if Part^.G = GG_Mecha then begin
		{In order for a mecha to count as not destroyed,}
		{its body + engine must have some hits remaining.}
		{Locate the body...}
		Part := Part^.SubCom;
		{ ASSERT: All level one subcomponents will be Modules. }
		while (Part <> Nil) and (Part^.S <> GS_Body) do begin
			Part := Part^.Next;
		end;

		{The nondestroyedness of the mecha depends upon the}
		{state of the body.}
		if Part = Nil then it := false
		else it := NotDestroyed(Part);

		{ If the body is ok, check the engine. }
		if it then begin
			Part := Part^.SubCom;
			while (Part <> Nil) and ((Part^.G <> GG_Support) or (Part^.S <> GS_Engine)) do begin
				Part := Part^.Next;
			end;

			{ The nondestroyedness of the mecha now depends }
			{ upon the state of the engine. }
			if Part = Nil then it := false
			else it := NotDestroyed(Part);
		end;

	end else if Part^.G = GG_Character then begin
		{In order for a character to count as not destroyed,}
		{its main gear must have some hits remaining,}
		{as well as any subcom bodies & heads.}
		it := GearCurrentDamage(Part) > 0;

		if it then begin
			{ Check all subcomponents. Bodies and heads must be intact. }
			Part := Part^.SubCom;
			while (Part <> Nil) do begin
				if Part^.G = GG_Module then begin
					if ( Part^.S = GS_Body ) or ( Part^.S = GS_Head ) then begin
						it := it and NotDestroyed( Part );
					end;
				end;
				Part := Part^.Next;
			end;
		end;

	end else begin

		{Calculate the current damage points of the gear.}
		CD := GearCurrentDamage(Part);

		if CD = -1 then begin
			{This gear is a pod or other storage type.}
			{It counts as not destroyed if it has any not}
			{destroyed children.}
			Part := Part^.SubCom;
			it := false;

			while Part <> Nil do begin
				it := it OR NotDestroyed(Part);
				Part := Part^.Next;
			end;
		end else if GearMaxDamage( Part ) = 0 then begin
			{ Parts with Max Damage = 0 can't be destroyed. }
			it := True;

		end else begin
			{This is a regular type gear with positive HP.}
			{Whether or not the gear is destroyed is based}
			{on whether or not it has HP left.}
			it := CD > 0;
		end;
	end;

	NotDestroyed := it;
end;

Function Destroyed(Part: GearPtr): Boolean;
	{ Some other procedures could use this one... }
begin
	Destroyed := Not NotDestroyed( Part );
end;

Function PartActive( Part: GearPtr ): Boolean;
	{ This function will check to see whether or not PART is }
	{ fully functioning. A part is "active" if it is not destroyed, }
	{ and if all of its parents up to root are also not destroyed. }
begin
	{ ERROR CHECK - make sure PART is a valid pointer. }
	if Part = Nil then Exit( False );

	if Part^.Parent = Nil then
		PartActive := NotDestroyed( PART )
	else
		PartActive := NotDestroyed( PART ) and PartActive( Part^.Parent );
end;

Function RollDamage( DC , Scale: Integer ): Integer;
	{ Roll random damage, then modify for scale. }
	{ DC is Damage Class, DP is Damage Points. }
var
	DP,T: Integer;
begin
	DP := 1;
	while DC > 5 do begin
		DP := DP + Random( 10 );
		DC := DC - 5;
	end;
	DP := DP + Random( DC * 2 );
	if Scale > 0 then DP := DP * 4;
	if Scale > 1 then begin
		for t := 2 to Scale do DP := DP * 5;
	end;
	RollDamage := DP;
end;

Function NumActiveGears(Part: GearPtr): Integer;
	{Calculate the number of active sibling components in}
	{the list of parts PART.}
var
	N: Integer;
begin
	N := 0;
	while Part <> Nil do begin
		if NotDestroyed(Part) then Inc(N);
		Part := Part^.Next;
	end;
	NumActiveGears := N;
end;

Function FindActiveGear(Part: GearPtr; N: Integer): GearPtr;
	{Given a list of gears PART, locate the Nth gear which}
	{is not destroyed. If no such gear exists, closest match.}
	{Return NIL if there are no nondestroyed gears in the list.}
var
	t: Integer;	{A counter}
	it: GearPtr;	{the gear that will be returned}
begin
	{Error check. If N is less than 1, we can't process the}
	{request. There is no gear before the first, after all...}
	if N < 1 then N := 1;

	{Initialize values.}
	t := 0;
	it := Nil;

	{Process the list.}
	while (t <> N) and (Part <> Nil) do begin
		if NotDestroyed(PART) then begin
			it := Part;
			Inc(T);
		end;
		Part := Part^.Next;
	end;

	FindActiveGear := it;
end;


Function CountUpSibs(Part: GearPtr; G,S,Scale: Integer): Integer;
	{Count up the number of "active points" in this line}
	{of sibling parts, recursing to find the number of APs}
	{in all child parts.}
var
	CD,MD,it: Integer;
begin
	{Initialize our count to 0.}
	it := 0;

	{Scan through all parts in the line.}
	while Part <> Nil do begin
		{Check to see if this part matches our description.}
		{We are only concerned about parts which have not}
		{yet been destroyed.}
		if NotDestroyed(Part) then begin
			if (Part^.G = G) and (Part^.S = S) and (Part^.Scale >= Scale) then begin
				{Calculate the max damage of this part.}
				MD := GearMaxDamage(Part);

				if MD > 0 then begin
					CD := GearCurrentDamage(Part);
					it := it + ( Part^.V * CD + MD - 1 ) div MD;
				end else begin
					it := it + Part^.V;
				end;

			end;

			{Check the subcomponents.}
			if Part^.SubCom <> Nil then it := it + CountUpSibs(Part^.SubCom,G,S,Scale);
			if Part^.InvCom <> Nil then it := it + CountUpSibs(Part^.InvCom,G,S,Scale);

		end; { IF NOTDESTROYED }

		Part := Part^.Next;
	end;

	CountUpSibs := it;
end;

Function CountActivePoints(Master: GearPtr; G,S: Integer): Integer;
	{Count up the number of "active points" worth of components}
	{which may be described by G,S. }
begin
	CountActivePoints := CountUpSibs( Master^.SubCom , G , S , Master^.Scale );
end;

Function CountTheBits(Part: GearPtr; G,S,Scale: Integer): Integer;
	{Count up the number of nondestroyed parts which correspond}
	{to description G,S.}
var
	it: Integer;
begin
	{Initialize our count to 0.}
	it := 0;

	{Scan through all parts in the line.}
	while Part <> Nil do begin
		{Check to see if this part matches our description.}
		{We are only concerned about parts which have not}
		{yet been destroyed.}
		if NotDestroyed(Part) then begin
			if (Part^.G = G) and (Part^.S = S) and (Part^.Scale >= Scale) then Inc(it);

			{Check the subcomponents.}
			if Part^.SubCom <> Nil then it := it + CountTheBits(Part^.SubCom,G,S,Scale);
			if Part^.InvCom <> Nil then it := it + CountTheBits(Part^.InvCom,G,S,Scale);
		end;

		Part := Part^.Next;
	end;

	CountTheBits := it;
end;

Function CountActiveParts(Master: GearPtr; G,S: Integer): Integer;
	{Count the number of nondestroyed components which correspond}
	{to description G,S.}
begin
	CountActiveParts := CountTheBits( Master^.SubCom , G , S , Master^.Scale );
end;

Function CountTotalBits(Part: GearPtr; G,S,Scale: Integer): Integer;
	{Count up the number of parts which correspond}
	{to description G,S.}
var
	it: Integer;
begin
	{Initialize our count to 0.}
	it := 0;

	{Scan through all parts in the line.}
	while Part <> Nil do begin
		{Check to see if this part matches our description.}
		if (Part^.G = G) and (Part^.S = S) and (Part^.Scale >= Scale) then begin
			Inc(it);

			{Check the subcomponents.}
			if Part^.SubCom <> Nil then it := it + CountTotalBits(Part^.SubCom,G,S,Scale);
			if Part^.InvCom <> Nil then it := it + CountTotalBits(Part^.InvCom,G,S,Scale);
		end;

		Part := Part^.Next;
	end;

	CountTotalBits := it;
end;

Function CountTotalParts(Master: GearPtr; G,S: Integer): Integer;
	{Count the number of components which correspond}
	{to description G,S.}
begin
	CountTotalParts := CountTotalBits( Master^.SubCom , G , S , Master^.Scale );
end;

Function PartEnergyPoints( Part: GearPtr ): Integer;
	{ Return how many energy points this item contains. }
var
	it,t: Integer;
begin
	it := 0;
	if Part^.G = GG_PowerSource then begin
		it := Part^.V * 25;
	end else if ( Part^.G = GG_Support ) and ( Part^.S = GS_Engine ) then begin
		it := Part^.V * 25;
		if Part^.Stat[ STAT_EngineSubType ] = EST_HighOutput then it := it * 2
		else if Part^.Stat[ STAT_EngineSubType ] = EST_HighPerformance then it := it div 2;
	end else if Part^.G = GG_Prop then begin
		{ Props get loads of energy. Being stationary, it's easy to add lots of }
		{ batteries or connect them to a power source. }
		it := Part^.V * 25;
	end;
	{ Increase for scale. }
	for t := 1 to Part^.Scale do it := it * 5;

	{ Reduce by the points already spent. }
	it := it - NAttValue( Part^.NA , NAG_Condition , NAS_PowerSpent );
	if it < 0 then it := 0;

	PartEnergyPoints := it;
end;

Function EnergyCost( Part: GearPtr ): Integer;
	{ Return the point cost to use PART. }
var
	it,t: Integer;
begin
	if ( Part^.G = GG_Weapon ) and (( Part^.S = GS_BeamGun ) or ( Part^.S = GS_EMelee )) then begin
		it := Part^.V;
		if HasAttackAttribute( WeaponAttackAttributes( Part ) , AA_Hyper ) then it := it * 3;
		if HasAreaEffect( Part ) then it := it * 2;

		{ Increase for scale. }
		if Part^.Scale = 0 then it := it * 2
		else for t := 1 to Part^.Scale do it := it * 5;
	end else it := 0;
	EnergyCost := it;
end;

Function EnergyPoints( Master: GearPtr ): LongInt;
	{ Count the number of unused energy points this master gear has. }
	Function CountEPAlongPath( Part: GearPtr ): LongInt;
		{Count up the number of "energy points" in this line}
		{of sibling parts, recursing to find the number of EPs}
		{in all child parts.}
	var
		it: LongInt;
	begin
		{Initialize our count to 0.}
		it := 0;

		{Scan through all parts in the line.}
		while Part <> Nil do begin
			{Check to see if this part matches our description.}
			{We are only concerned about parts which have not}
			{yet been destroyed.}
			if NotDestroyed(Part) and ( Part^.G <> GG_Cockpit ) then begin
				it := it + PartEnergyPoints( Part );

				{Check the subcomponents.}
				if Part^.SubCom <> Nil then it := it + CountEPAlongPath( Part^.SubCom );
				if Part^.InvCom <> Nil then it := it + CountEPAlongPath( Part^.InvCom );

			end; { IF NOTDESTROYED AND NOT-COCKPIT }

			Part := Part^.Next;
		end;

		CountEPAlongPath := it;
	end;
begin
	if Master = Nil then Exit( 0 );
	EnergyPoints := PartEnergyPoints( Master ) + CountEPAlongPath( Master^.SubCom );
end;

Procedure SpendEnergy( Master: GearPtr; EP: Integer );
	{ Spend a certain number of this mecha's energy points. If there are }
	{ any that can't be assigned to a power source, assign them to the }
	{ mecha as overload. }
	Procedure CheckEPAlongPath( Part: GearPtr );
		{ Spend energy points along this path. }
	var
		it: Integer;
	begin
		{Scan through all parts in the line.}
		while ( Part <> Nil ) and ( EP > 0 ) do begin
			{Check to see if this part matches our description.}
			{We are only concerned about parts which have not}
			{yet been destroyed.}
			if NotDestroyed(Part) and ( Part^.G <> GG_Cockpit ) then begin
				it := PartEnergyPoints( Part );
				if it > 0 then begin
					if it < EP then begin
						AddNAtt( Part^.NA , NAG_Condition , NAS_PowerSpent , it );
						EP := EP - it;
					end else begin
						AddNAtt( Part^.NA , NAG_Condition , NAS_PowerSpent , EP );
						EP := 0;
					end;
				end;

				{Check the subcomponents.}
				if Part^.SubCom <> Nil then CheckEPAlongPath( Part^.SubCom );
				if Part^.InvCom <> Nil then CheckEPAlongPath( Part^.InvCom );

			end; { IF NOTDESTROYED AND NOT-COCKPIT }

			Part := Part^.Next;
		end;
	end;
var
	t: Integer;
begin
	CheckEPAlongPath( Master^.SubCom );
	if ( EP > 0 ) and ( Master^.G = GG_Mecha ) then begin
		for t := 1 to Master^.Scale do EP := EP div 5;
		AddNAtt( Master^.NA , NAG_Condition , NAS_PowerSpent , EP );
	end;
end;


Function SeekActiveIntrinsic( Master: GearPtr; G,S: Integer ): GearPtr;
	{ Search through all the subcoms and equipment of MASTER and }
	{ find a part which matches G,S. If more than one applicable }
	{ part is found, return the part with the highest V field. }
	{ If no such part is found, return Nil. }
{ FUNCTIONS BLOCK }
	Function CompGears( P1,P2: GearPtr ): GearPtr;
		{ Given two gears, P1 and P2, return the gear with }
		{ the higest V field. }
	var
		it: GearPtr;
	begin
		it := Nil;
		if P1 = Nil then it := P2
		else if P2 = Nil then it := P1
		else begin
			if P1^.V > P2^.V then it := P1
			else it := P2;
		end;
		CompGears := it;
	end;

	Function SeekPartAlongTrack( P: GearPtr ): GearPtr;
		{ Search this line of sibling components for a part }
		{ which matches G , S. }
	var
		it: GearPtr;
	begin
		it := Nil;
		while P <> Nil do begin
			if NotDestroyed( P ) then begin
				if ( P^.G = G ) and ( P^.S = S ) and ( P^.Scale >= Master^.Scale ) then begin
					it := CompGears( it , P );
				end;
				it := CompGears( SeekPartAlongTrack( P^.SubCom ) , it );
				it := CompGears( it , SeekPartAlongTrack( P^.InvCom ) );
			end;
			P := P^.Next;
		end;
		SeekPartAlongTrack := it;
	end;

begin
	{ Note that this procedure does not check the general inventory. }
	SeekActiveIntrinsic := SeekPartAlongTrack( Master^.SubCom );
end;

Function SeekItem( Master: GearPtr; G,S: Integer; CheckGeneralInv: Boolean ): GearPtr;
	{ Locate a component matching G,S. The component must be working, }
	{ but otherwise can be located anywhere in the PART tree. }
	{ This procedure doesn't even care about scale... We just want }
	{ the largest example of the part we're after. }
	Function CompGears( P1,P2: GearPtr ): GearPtr;
		{ Given two gears, P1 and P2, return the gear with }
		{ the higest V field. }
	var
		it: GearPtr;
	begin
		it := Nil;
		if P1 = Nil then it := P2
		else if P2 = Nil then it := P1
		else begin
			if P1^.V > P2^.V then it := P1
			else it := P2;
		end;
		CompGears := it;
	end;
	Function SeekPartAlongTrack( P: GearPtr ): GearPtr;
		{ Search this line of sibling components for a part }
		{ which matches G , S. }
	var
		it: GearPtr;
	begin
		it := Nil;
		while P <> Nil do begin
			if NotDestroyed( P ) then begin
				if ( P^.G = G ) and ( P^.S = S ) then begin
					it := CompGears( it , P );
				end;
				it := CompGears( SeekPartAlongTrack( P^.SubCom ) , it );
				it := CompGears( it , SeekPartAlongTrack( P^.InvCom ) );
			end;
			P := P^.Next;
		end;
		SeekPartAlongTrack := it;
	end;
	
begin
	if CheckGeneralInv then begin
		SeekItem := CompGears( SeekPartAlongTrack( Master^.SubCom ) , SeekPartAlongTrack( Master^.InvCom ) );
	end else begin
		SeekItem := SeekPartAlongTrack( Master^.SubCom );
	end;
end;

Function MechaManeuver( Mek: GearPtr ): Integer;
	{ Check out a mecha-type gear and determine its }
	{ maneuverability class, adjusted for damage. }
var
	MV,OL,LegPoints: Integer;
	Gyro,SW: GearPtr;
begin
	{ Error check- MV can only be calculated for valid mecha. }
	if (Mek = Nil) or (Mek^.G <> GG_Mecha) then Exit( 0 );

	MV := FormMVBonus[ Mek^.S ] + BaseMVTVScore( Mek );

	{ Modify for the gyroscope and sensor package. }
	if SeekActiveIntrinsic( Mek , GG_Sensor , GS_MainSensor ) = Nil then MV := MV - MVSensorPenalty;
	Gyro := SeekActiveIntrinsic( Mek , GG_Support , GS_Gyro );
	if Gyro = Nil then MV := MV - MVGyroPenalty;

	{ Add the software bonus. }
	SW := SeekSoftware( Mek , S_MVBoost , Mek^.Scale , False );
	if SW <> Nil then MV := MV + SW^.V;

	{ Add the penalty for engine overload. }
	OL := NAttValue( Mek^.NA , NAG_Condition , NAS_PowerSpent );
	if OL > 14 then begin
		MV := MV - ( ( OL - 5 ) div 10 );
	end;

	{ Add the bonus for extra legs. }
	if ( NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) = MM_Walk ) or ( NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode ) = 0 ) then begin
		LegPoints := CountActivePoints( Mek , GG_Module , GS_Leg );
		OL := Mek^.V * 2 - 2;
		if OL < 1 then OL := 1;
		if LegPoints >= ( OL * 4) then MV := MV + 2
		else if LegPoints >= ( OL * 2 ) then MV := MV + 1;
	end;

	{ Up to this point, no modifiers should take MV above 0. }
	if MV > 0 then MV := 0;

	{ Biotech mecha get a +1 to MV and TR. }
	if NAttValue( Mek^.NA , NAG_GearOps , NAS_Material ) = NAV_BioTech then Inc( MV );

	MechaManeuver := MV;
end;

Function MechaTargeting( Mek: GearPtr ): Integer;
	{ Check out a mecha-type gear and determine its }
	{ targeting class, adjusted for damage. }
var
	TR,OL: Integer;
	SW: GearPtr;
begin
	{ Error check- MV can only be calculated for valid mecha. }
	if (Mek = Nil) or (Mek^.G <> GG_Mecha) then Exit( 0 );

	TR := FormTRBonus[ Mek^.S ] + BaseMVTVScore( Mek );

	{ Modify for sensors, or lack thereof. }
	if SeekActiveIntrinsic( Mek , GG_Sensor , GS_MainSensor ) = Nil then TR := TR - TRSensorPenalty;

	{ Modify for software. }
	SW := SeekSoftware( Mek , S_TRBoost , Mek^.Scale , False );
	if SW <> Nil then TR := TR + SW^.V;

	{ Add the penalty for engine overload. }
	OL := NAttValue( Mek^.NA , NAG_Condition , NAS_PowerSpent );
	if OL > 9 then begin
		TR := TR - ( OL div 10 );
	end;

	{ Up to this point, no modifiers should take TR above 0. }
	if TR > 0 then TR := 0;

	{ Biotech mecha get a +1 to MV and TR. }
	if NAttValue( Mek^.NA , NAG_GearOps , NAS_Material ) = NAV_BioTech then Inc( TR );

	MechaTargeting := TR;
end;

Function MechaSensorRating( Mek: GearPtr ): Integer;
	{ Calculate the sensor rating for this mecha. }
var
	SR: Integer;
	Sens: GearPtr;
begin
	{ Error check- MV can only be calculated for valid mecha. }
	if (Mek = Nil) or (Mek^.G <> GG_Mecha) then Exit( 0 );

	{ Locate the sensor package. }
	Sens := SeekActiveIntrinsic( Mek , GG_Sensor , GS_MainSensor );

	if Sens = Nil then SR := -8
	else begin
		SR := Sens^.V - 7;

		{ If the sensors are mounted in a Head module, +3 bonus. }
		{ This bonus only applies to forms which are allowed to }
		{ have heads- so, if you had a transforming battroid/tank, }
		{ the sensors would always work but the +3 bonus would only }
		{ apply in battroid form. }
		if InGoodModule( Sens ) then begin
			Sens := FindModule( Sens );
			if ( Sens <> Nil ) and ( Sens^.S = GS_Head ) then SR := SR + 3;
		end;
	end;

	MechaSensorRating := SR;
end;

Function MechaStealthRating( Mek: GearPtr ): Integer;
	{ Calculate the stealth rating for this mecha. This will be }
	{ the target number to beat when trying to spot the mecha. }
var
	SR: Integer;
begin
	if Mek = Nil then begin
		SR := 0;
	end else if Mek^.G = GG_Character then begin
		SR := 25 - Mek^.Stat[ STAT_Body ];
	end else if Mek^.G = GG_Mecha then begin
		SR := 16 - Mek^.V;
	end else if Mek^.G = GG_MetaTerrain then begin
		SR := Mek^.Stat[ STAT_MetaVisibility ] + 5;
	end else SR := 12;
	if SR < 5 then SR := 5;
	MechaStealthRating := SR;
end;

Function LocateGoodAmmo( Weapon: GearPtr ): GearPtr;
	{ Locate the first block of usable ammunition for the weapon listed. }
	{ In order to be usable, it must: Fail the NotGoodAmmo function, and }
	{ also it must not be destroyed. }
	{ If no good ammo exists, this function returns NIL. }
var
	Ammo,GAmmo: GearPtr;
begin
	Ammo := Weapon^.SubCom;
	GAmmo := Nil;
	while ( Ammo <> Nil ) and ( GAmmo = Nil ) do begin
		if NotDestroyed( Ammo ) and not (NotGoodAmmo(Weapon,Ammo)) then begin
			GAmmo := Ammo;
		end;
		ammo := ammo^.Next;
	end;
	LocateGoodAmmo := GAmmo;
end;

Function LocateAnyAmmo( Weapon: GearPtr ): GearPtr;
	{ There is no good ammo. Just return anything. }
var
	Ammo,GAmmo: GearPtr;
begin
	Ammo := Weapon^.SubCom;
	GAmmo := Nil;
	while ( Ammo <> Nil ) and ( GAmmo = Nil ) do begin
		if Ammo^.G = GG_Ammo then begin
			GAmmo := Ammo;
		end;
		ammo := ammo^.Next;
	end;
	LocateAnyAmmo := GAmmo;
end;

Function WeaponAttackAttributes( Attacker: GearPtr ): String;
	{ Return the attack type for this particular attack. }
var
	it: String;
	ammo: GearPtr;
begin
	{ Error check. }
	if Attacker = Nil then Exit( '' );

	{ Grab the TYPE SAtt from the weapon itself. }
	it := SAttValue( Attacker^.SA , 'TYPE' );

	{ If appropriate, grab the TYPE from its ammo as well. }
	if Attacker^.G = GG_Weapon then begin
		if ( Attacker^.S = GS_Ballistic ) or ( Attacker^.S = GS_Missile ) then begin
			Ammo := LocateGoodAmmo( Attacker );
			if Ammo <> Nil then begin
				it := SAttValue( Ammo^.SA , 'TYPE' ) + ' ' + it;
			end;
		end;
	end;

	{ Add the TYPE from the weapon add-ons. }
	Ammo := Attacker^.InvCom;
	while Ammo <> Nil do begin
		if ( Ammo^.G = GG_WeaponAddOn ) and NotDestroyed( Ammo ) then begin
			it := SAttValue( Ammo^.SA , 'TYPE' ) + ' ' + it;
		end;

		Ammo := Ammo^.Next;
	end;

	WeaponAttackAttributes := it;
end;

Function HasAttackAttribute( AtAt: String; N: Integer ): Boolean;
	{ Return TRUE if the listed attack attribute is posessed by }
	{ this weapon, or FALSE otherwise. }
begin
	if ( N < 1 ) or ( N > Num_Attack_Attributes ) then Exit( False );
	HasAttackAttribute := AStringHasBString( AtAt , AA_Name[ N ] );
end;

Function HasAreaEffect( AtAt: String ): Boolean;
	{ Return TRUE if the provided attack attributes will result }
	{ in an area effect attack, or FALSE otherwise. }
begin
	HasAreaEffect := AStringHasBString( ATAt , AA_Name[AA_BlastAttack] ) or AStringHasBString( ATAt , AA_Name[AA_LineAttack] ) or AStringHasBString( ATAt , AA_Name[AA_Scatter] );
end;

Function HasAreaEffect( Attacker: GearPtr ): Boolean;
	{ Return TRUE if the listed weapon is of an area effect type, }
	{ or FALSE otherwise. }
begin
	HasAreaEffect := HasAreaEffect( WeaponAttackAttributes( Attacker ) );
end;

Function NonDamagingAttack( AtAt: String ): Boolean;
	{ Return TRUE if the Attacker is a non-damaging attack. }
begin
	NonDamagingAttack := HasAttackAttribute( AtAt, AA_Smoke ) or HasAttackAttribute( AtAt , AA_Gas ) or HasAttackAttribute( AtAt , AA_Drone );
end;

Function NoCalledShots( AtAt: String; AtOp: Integer ): Boolean;
	{ Return TRUE if the weapon in question, using the requested }
	{ attack option value, is incapable of making a called shot. }
begin
	if ( AtOp > 0 ) or AStringHasBString( AtAt , AA_Name[AA_SwarmAttack] ) or AStringHasBString( AtAt , AA_Name[AA_Hyper] ) or HasAreaEffect( AtAt ) then begin
		NoCalledShots := True;
	end else begin
		NoCalledShots := False;
	end;
end;

Function AmmoRemaining( Weapon: GearPtr ): Integer;
	{ Determine how many shots this weapon has remaining. }
var
	Ammo: GearPtr;
begin
	{ Error Check- make sure this is actually a weapon. }
	if ( Weapon = Nil ) or ( Weapon^.G <> GG_Weapon ) then Exit( 0 );

	{ Find the ammo gear, if one exists. }
	Ammo := LocateGoodAmmo( Weapon );
	if Ammo = Nil then Exit( 0 );

	{ Return the number of shots left. }
	AmmoRemaining := Ammo^.Stat[STAT_AmmoPresent] - NAttValue( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent );
end;


Function ScaleRange( Rng,Scale: Integer ): Integer;
	{ Provide a universal range measurement. }
begin
	while Scale > 0 do begin
		Rng := Rng * 2;
		Dec( Scale );
	end;
	ScaleRange := Rng;
end;


Procedure ApplyPerminantInjury( PC: GearPtr );
	{ The PC has been through a beating. Apply a perminant injury, and destroy }
	{ any relevant cyberware found. }
var
	Injury: Integer;
	SC,SC2: GearPtr;
begin
	Injury := Random( Num_Perm_Injuries ) + 1;
	SetNAtt( PC^.NA , NAG_StatusEffect , Perm_Injury_List[ Injury ] , -1 );

	SC := PC^.SubCom;
	while SC <> Nil do begin
		SC2 := SC^.Next;

		if UpCase( SAttValue( SC^.SA , SAtt_CyberSlot ) ) = Perm_Injury_Slot[ Injury ] then begin
			RemoveGear( PC^.SubCom , SC );
		end;

		SC := SC2;
	end;
end;

Procedure ApplyCyberware( PC,Cyber: GearPtr );
	{ A cybernetic item is being installed into the PC. This may heal a current }
	{ perminant injury. Yay! Check to see whether or not it will. }
var
	Slot: String;
	T: Integer;
begin
	Slot := UpCase( SAttValue( Cyber^.SA , SAtt_CyberSlot ) );
	for t := 1 to Num_Perm_Injuries do begin
		if Perm_Injury_Slot[ t ] = Slot then begin
			SetNAtt( PC^.NA , NAG_StatusEffect , Perm_Injury_List[ T ] , 0 );
		end;
	end;
end;

Function NotAnAnimal( Master: GearPtr ): Boolean;
	{ Returns TRUE if the provided gear is not, in fact, an animal. This is }
	{ determined by looking at the JOB SAtt. }
begin
	NotAnAnimal := ( Master = Nil ) or ( UpCase( SAttValue( Master^.SA , 'JOB' ) ) <> 'ANIMAL' );
end;

Function CreateComponentList( MasterList: GearPtr; const Context: String ): NAttPtr;
	{ Create a list of components to be used by SELECTCOMPONENTFROMLIST below. }
	{ The list will be of the form G:0 S:[Component Index] V:[Match Weight]. }
var
	C: GearPtr;	{ A component. }
	N: Integer;	{ A counter. }
	MW: Integer;	{ The match-weight of the current component. }
	ShoppingList: NAttPtr;	{ The list of legal components. }
begin
	{ Initialize all the values. }
	ShoppingList := Nil;
	C := MasterList;
	N := 1;

	{ Go through the list, adding everything that matches. }
	while C <> Nil do begin
		MW := StringMatchWeight( Context , SAttValue( C^.SA , 'REQUIRES' ) );
		if MW > 0 then begin
			SetNAtt( ShoppingList , 0 , N , MW );
		end;

		Inc( N );
		C := C^.Next;
	end;

	CreateComponentList := ShoppingList;
end;

Function RandomComponentListEntry( ShoppingList: NAttPtr ): NAttPtr;
	{ We've been handed a shopping list. Select one of the elements from this }
	{ list randomly based on the weight of the V values. }
var
	N: Integer;
	C,It: NAttPtr;
begin
	{ Error check- no point in working with an empty list. }
	if ShoppingList = Nil then Exit( Nil );

	{ Step one- count the number of matching plots. }
	C := ShoppingList;
	N := 0;
	while C <> Nil do begin
		N := N + C^.V;
		C := C^.Next;
	end;

	{ Pick one of the matches at random. }
	C := ShoppingList;
	N := Random( N );
	it := Nil;
	while ( C <> Nil ) and ( it = Nil ) do begin
		N := N - C^.V;
		if ( N < 0 ) and ( it = Nil ) then it := C;
		C := C^.Next;
	end;

	{ Return the entry we found. }
	RandomComponentListEntry := it;
end;

Function SelectComponentFromList( MasterList: GearPtr; var ShoppingList: NAttPtr ): GearPtr;
	{ Given a list of numeric attributes holding the selection weights of all legal }
	{ components from MasterList, select one of those components and return a pointer }
	{ to its entry in MasterList. }
	{ Afterwards remove the selected component's entry from the shopping list. }
var
	N: Integer;
	It: NAttPtr;
begin
	{ Error check- no point in working with an empty list. }
	if ShoppingList = Nil then Exit( Nil );

	{ Step one- pick an entry. }
	it := RandomComponentListEntry( ShoppingList );

	{ Remove IT from the list, and return the gear it points to. }
	{ Store the index before deleting IT. }
	N := it^.S;
	RemoveNAtt( ShoppingList , it );
	SelectComponentFromList := RetrieveGearSib( MasterList , N );
end;

Function FindNextComponent( CList: GearPtr; const plot_desc: String ): GearPtr;
	{ Locate a single gear whose "REQUIRES" satt matches the provided description. }
	{ Weight the decision based on how much of the description is matched. }
var
	ShoppingList: NAttPtr;
	it: GearPtr;
begin
	{ Step one- count the number of matching plots. }
	ShoppingList := CreateComponentList( CList , plot_desc );
	it := SelectComponentFromList( CList , ShoppingList );
	DisposeNAtt( ShoppingList );
	FindNextComponent := it;
end;


Function NumberOfSkillSlots( PC: GearPtr ): Integer;
	{ Return the number of skill slots this PC has. }
var
	N: Integer;
begin
	N := ( PC^.Stat[ STAT_Knowledge ] div 5 ) + 8;
	if NAttValue( PC^.NA , NAG_Talent , NAS_Polymath ) <> 0 then N := N + 3;
	NumberOfSkillSlots := N;
end;

Function TooManySkillsPenalty( PC: GearPtr; N: Integer ): Integer;
	{ Return the % XP penalty that this character will suffer. }
begin
	N := N - NumberOfSkillSlots( PC );
	N := N * 25 - 10;
	if N < 0 then N := 0;
	TooManySkillsPenalty := N;
end;

Function SkillAdvCost( PC: GearPtr; CurrentLevel: Integer ): LongInt;
	{ Return the cost, in XP points, to improve this skill by }
	{ one level. }
const
	chart: Array [1..15] of LongInt = (
		100,100,200,300,400,
		500,800,1300,2100,3400,
		5500,8900,14400,23300,37700
	);
var
	SAC,N: LongInt;
begin
	{ The chart lists skill costs according to desired level, }
	{ not current level. So, modify things a bit. }
	Inc( CurrentLevel );

	{ Range check - after level 15, it all costs the same. }
	if CurrentLevel < 1 then CurrentLevel := 1;
	if CurrentLevel <= 15 then begin
		{ Base level advance cost is found in the chart. }
		SAC := chart[ CurrentLevel ];
	end else begin
		{ For "epic level" skills, lay on a nice pile of deep hurting. }
		SAC := chart[ 15 ] * ( ( CurrentLevel - 15 ) * ( CurrentLevel - 15 ) + 1 );
	end;


	{ May be adjusted upwards if PC has too many skills... }
	if ( PC <> Nil ) and ( PC^.G = GG_Character ) then begin
		N := TooManySkillsPenalty( PC , NumberOfSpecialties( PC ) );
		if N > 0 then begin
			SAC := ( SAC * ( 100 + N ) ) div 100;
		end;
	end;

	SkillAdvCost := SAC;
end;

Function IsExternalPart( Master,Part: GearPtr ): Boolean;
	{ Return TRUE if Part is an invcom or a descendant of an invcom. }
var
	IsXP: Boolean;
begin
	{ Assume FALSE until proven TRUE. }
	IsXP := False;
	while ( Part <> Nil ) and ( Part <> Master ) and not IsXP do begin
		if IsInvCom( Part ) then IsXP := True;
		Part := Part^.Parent;
	end;
	IsExternalPart := IsXP;
end;

Function ToolBonus( Master: GearPtr; Skill: Integer ): Integer;
	{ Return the tool bonus that this master has. If Skill is positive it refers to a skill; }
	{ if negative, it affects a talent. }
	Function MustBeEquipped: Boolean;
		{ Return TRUE if this tool must be equipped, or FALSE otherwise. }
	begin
		if ( Skill >= 1 ) and ( Skill <= NumSkill ) then begin
			MustBeEquipped := SkillMan[ Skill ].Usage = 0;
		end else if ( Skill <= -1 ) and ( Skill >= -NumTalent ) then begin
			MustBeEquipped := Talent_Usage[ Abs( Skill ) ] = 0;
		end else MustBeEquipped := True;
	end;
var
	Tool: GearPtr;
begin
	if MustBeEquipped then begin
		Tool := SeekItem( Master , GG_Tool , Skill , False );
	end else begin
		{ If this is an activatable skill, it doesn't matter if }
		{ the relevant tool has been equipped or not. }
		Tool := SeekItem( Master , GG_Tool , Skill , True );
	end;
	if Tool <> Nil then begin
		ToolBonus := Tool^.V;
	end else if ( Skill >= 1 ) and ( Skill <= NumSkill ) and ( SkillMan[ Skill ].ToolNeeded <> TOOL_None ) then begin
		ToolBonus := -5;
	end else begin
		ToolBonus := 0;
	end;
end;

end.
