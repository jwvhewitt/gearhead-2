unit description;

	{ This unit provides the descriptions for gears. Its purpose is to }
	{ explain to the player exactly what a given item does, and how it }
	{ differs from other items. }
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

uses texutil,ui4gh,gears,gearutil,movement,locale;

Function WeaponDescription( GB: GameBoardPtr; Weapon: GearPtr ): String;
Function ExtendedDescription( GB: GameBoardPtr; Part: GearPtr ): String;

Function MechaDescription( Mek: GearPtr ): String;

Function TimeString( ComTime: LongInt ): String;
Function JobAgeGenderDesc( NPC: GearPtr ): String;
Function SkillDescription( N: Integer ): String;

Function MechaPilotName( Mek: GearPtr ): String;
Function TeamMateName( M: GearPtr ): String;

Function RenownDesc( Renown: Integer ): String;


implementation

uses 	ghmodule,ghweapon,ghsensor,ghsupport,ghmovers,ghguard,ghswag,ghholder,ghchars,
	ability,ghintrinsic,interact,ghmecha;

Function BasicWeaponDesc( Weapon: GearPtr ): String;
	{Supply a default name for this particular weapon.}
begin
	{Convert the size of the weapon to a string.}
	if Weapon^.G = GG_Weapon then begin
		BasicWeaponDesc := DCName( WeaponDC( Weapon ) , Weapon^.Scale ) + ' ' + MsgString( 'WEAPONNAME_' + BStr( Weapon^.S ) );
	end else begin
		BasicWeaponDesc := DCName( WeaponDC( Weapon ) , Weapon^.Scale );
	end;
end;

Function WeaponDescription( GB: GameBoardPtr; Weapon: GearPtr ): String;
	{ Create a description for this weapon. }
var
	Master,Ammo: GearPtr;
	desc,AA: String;
	S,M,L: Integer;
begin
	{ Take the default name for the weapon from the WeaponName }
	{ function in ghweapon. }
	desc := BasicWeaponDesc( Weapon ) + ' (' + MsgSTring( 'STATABRV_' + BStr( Weapon^.Stat[ STAT_AttackStat ] ) ) + ')';

	if Weapon^.G = GG_Weapon then begin
		Master := FindMaster( Weapon );
		Ammo := LocateGoodAmmo( Weapon );

		if ( Weapon^.S = GS_Missile ) and ( Ammo <> Nil ) then begin
			desc := BasicWeaponDesc( Ammo );
		end;

		if Master <> Nil then begin
			if Master^.Scale <> Weapon^.Scale then begin
				desc := desc + ' SF:' + BStr( Weapon^.Scale );
			end;
		end else if Weapon^.Scale > 0 then begin
			desc := desc + ' SF:' + BStr( Weapon^.Scale );
		end;

		AA := WeaponAttackAttributes( Weapon );

		if (Weapon^.S = GS_Ballistic) or (Weapon^.S = GS_BeamGun) or ( Weapon^.S = GS_Missile ) then begin
			S := ScaleRange( WeaponRange( Nil , Weapon , RANGE_Short ) , Weapon^.Scale );
			M := ScaleRange( WeaponRange( Nil , Weapon , RANGE_Medium ) , Weapon^.Scale );
			L := ScaleRange( WeaponRange( Nil , Weapon , RANGE_Long ) , Weapon^.Scale );
			if HasAttackAttribute( AA , AA_LineAttack ) then begin
				desc := desc + ' RNG:' + BStr( S ) + '-' + BStr( L );
			end else begin
				desc := desc + ' RNG:' + BStr( S ) + '-' + BStr( M ) + '-' + BStr( L );
			end;

		end else if HasAttackAttribute( AA , AA_Extended ) then begin
			desc := desc + ' RNG:' + BStr( ScaleRange( 2 , Weapon^.Scale ) );
		end;

		if Weapon^.S <> GS_Missile then begin
			desc := desc + ' ACC:' + SgnStr( Weapon^.Stat[STAT_Accuracy] );
		end else if Ammo <> Nil then begin
			desc := desc + ' ACC:' + SgnStr( Ammo^.Stat[STAT_Accuracy] );
		end;

		desc := desc + ' SPD:' + BStr( Weapon^.Stat[STAT_Recharge] );

		if (Weapon^.S = GS_Ballistic) or (Weapon^.S = GS_BeamGun) then begin
			if Weapon^.Stat[ STAT_BurstValue ] > 0 then desc := desc + ' BV:' + BStr( Weapon^.Stat[ STAT_BurstValue ] + 1 );
		end;

		if (Weapon^.S = GS_Ballistic) or (Weapon^.S = GS_Missile) then begin
			if Ammo <> Nil then begin
				desc := desc + ' ' + BStr( AmmoRemaining( Weapon ) ) + '/' + BStr( Ammo^.Stat[ STAT_AmmoPresent] ) + 'a';
			end else begin
				desc := desc + MsgString( 'AMMO-EMPTY' );
			end;
		end else if ( Weapon^.S = GS_BeamGun ) or ( Weapon^.S = GS_EMelee ) then begin
			desc := desc + ' EP:' + BStr( EnergyCost( Weapon ) ) + '/' + BStr( EnergyPoints( FindMasterOrRoot( Weapon ) ) );
		end;

		if HasAttackAttribute( AA , AA_Mystery ) then begin
			desc := desc + ' ???';
		end else begin
			if AA <> '' then begin
				desc := desc + ' ' + UpCase( AA );
			end;
		end;

		if SAttValue( Weapon^.SA , 'CALIBER' ) <> '' then desc := desc + ' ' + SAttValue( Weapon^.SA , 'CALIBER' );

	end else if Weapon^.G = GG_Ammo then begin
		AA := WeaponAttackAttributes( Weapon );

		if Weapon^.S = GS_Grenade then begin
			desc := desc + ' RNG:T';

			if Weapon^.Stat[ STAT_BurstValue ] > 0 then desc := desc + ' BV:' + BStr( Weapon^.Stat[ STAT_BurstValue ] + 1 );
		end;

		desc := desc + ' ' + BStr( Weapon^.Stat[STAT_AmmoPresent] - NAttValue( Weapon^.NA , NAG_WeaponModifier , NAS_AmmoSpent ) ) + '/' + BStr( Weapon^.Stat[ STAT_AmmoPresent] ) + 'a';

		if HasAttackAttribute( AA , AA_Mystery ) then begin
			desc := desc + ' ???';
		end else begin
			if AA <> '' then begin
				desc := desc + ' ' + UpCase( AA );
			end;
		end;


	end;

	desc := desc + ' ARC:' + MsgString( 'WEAPONINFO_ARC' + BStr( WeaponArc( Weapon ) ) );

	WeaponDescription := desc;
end;

Function WAODescription( Weapon: GearPtr ): String;
	{ Create a description for this weapon. }
var
	desc,AA: String;
begin
	{ Take the default name for the weapon from the WeaponName }
	{ function in ghweapon. }
	desc := MsgString( 'WAO_' + BStr( Weapon^.S ) );

	if Weapon^.V <> 0 then desc := desc + ' DC:' + SgnStr( Weapon^.V );
	if Weapon^.Stat[ STAT_Range ] <> 0 then desc := desc + ' RNG:' + SgnStr( Weapon^.Stat[ STAT_Range ] );
	if Weapon^.Stat[ STAT_Accuracy ] <> 0 then desc := desc + ' ACC:' + SgnStr( Weapon^.Stat[ STAT_Accuracy ] );
	if Weapon^.Stat[ STAT_Recharge ] <> 0 then desc := desc + ' SPD:' + SgnStr( Weapon^.Stat[ STAT_Recharge ] );

	AA := WeaponAttackAttributes( Weapon );
	if HasAttackAttribute( AA , AA_Mystery ) then begin
		desc := desc + ' ???';
	end else if AA <> '' then begin
		desc := desc + ' ' + UpCase( AA );
	end;

	WAODescription := desc;
end;

Function MoveSysDescription( Part: GearPtr ): String;
	{ Return a description of the size/type of this movement }
	{ system. }
begin
	MoveSysDescription := MsgString( 'MoveSys_Class' ) + ' ' + BStr( Part^.V ) + ' ' + MoveSysName( Part );
end;

Function ModifierDescription( Part: GearPtr ): String;
	{ Return a description for this modifier gear. }
var
	it: String;
	T: Integer;
begin
	if Part^.S = GS_StatModifier then begin
		it := '';
		for t := 1 to NumGearStats do begin
			if Part^.Stat[ T ] <> 0 then begin
				if it <> '' then it := it + ', ';
				it := it + SgnStr( Part^.Stat[ T ] ) + ' ' + MsgString( 'STATNAME_' + BStr( T ) );
			end;
		end;
	end else if Part^.S = GS_SkillModifier then begin
		it := MsgString( 'SKILLNAME_' + Bstr( Part^.Stat[ STAT_SkillToModify ] ) );
		it := it + ' ' + SgnStr( Part^.Stat[ STAT_SkillModBonus ] );
	end;

	if it <> '' then it := it + '.';
	ModifierDescription := it;
end;

Function ShieldDescription( Part: GearPtr ): String;
	{ Return a description of the size/type of this movement }
	{ system. }
begin
	ShieldDescription := MsgString( 'Shield_Desc' ) + SgnStr( Part^.Stat[ STAT_ShieldBonus ] );
end;

Function ToolDescription( Part: GearPtr ): String;
	{ Return a description of the size/type of this movement }
	{ system. }
var
	msg: String;
begin
	if Part^.S > 0 then begin
		msg := SgnStr( Part^.V ) + ' ' + MsgString( 'SKILLNAME_' + Bstr( Part^.S ) );
	end else begin
		msg := SgnStr( Part^.V ) + ' ' + MsgString( 'TALENT' + Bstr( Abs( Part^.S ) ) );
	end;
	ToolDescription := msg;
end;

Function IntrinsicsDescription( Part: GearPtr ): String;
	{ Return a list of all the intrinsics associated with this part. }
var
	T: Integer;
	it: String;
begin
	it := '';

	{ Start by adding the armor type, if appropriate. }
	T := NAttValue( Part^.NA , NAG_GearOps , NAS_ArmorType );
	if T <> 0 then it := MsgString( 'ARMORTYPE_' + BStr( T ) );

	{ We're only interested if the intrinsics are attached directly }
	{ to this part. }
	for t := 1 to NumIntrinsic do begin
		if NAttValue( Part^.NA , NAG_Intrinsic , T ) <> 0 then begin
			if it = '' then begin
				it := MsgString( 'INTRINSIC_' + BStr( T ) );
			end else begin
				it := it + ', ' + MsgString( 'INTRINSIC_' + BStr( T ) );
			end;
		end;
	end;

	IntrinsicsDescription := it;
end;

Function ArmorDescription( Part: GearPtr ): String;
	{ Return a description of this armor's stat modifiers, if any. }
var
	it: String;
	T: Integer;
begin
	it := ArmorName( Part );
	for t := 1 to NumGearStats do begin
		if Part^.Stat[t] <> 0 then begin
			it := it + ', +' + BStr( Part^.Stat[t] div 10 ) + '.' + BStr( Part^.Stat[t] mod 10 ) + ' ' + MsgString( 'STATNAME_' + BStr( T ) );
		end;
	end;
	ArmorDescription := it;
end;

Function RepairFuelDescription( Part: GearPtr ): String;
	{ Return a description for this repair fuel. }
begin
	RepairFuelDescription := MsgString( 'REPAIRTYPE_' + BStr( Part^.S ) ) + ' ' + BStr( Part^.V ) + ' DP';
end;

Function PowerSourceDescription( Part: GearPtr ): String;
	{ Return a description of the size of this power source. }
var
	msg: String;
begin
	msg := ReplaceHash( MsgString( 'PowerSource_Desc' ) , BStr( Part^.V ) );
	PowerSourceDescription := msg;
end;

Function ComputerDescription( Part: GearPtr ): String;
	{ Return a description of this computer. }
var
	msg: String;
	ZG,SWZG: Integer;
	SW: GearPtr;
begin
	msg := ReplaceHash( MsgString( 'Computer_Desc' ) , BStr( Part^.V ) );
	ZG := ZetaGigs( Part );
	SWZG := 0;
	SW := Part^.SubCom;
	while SW <> Nil do begin
		SWZG := SWZG + ZetaGigs( SW );
		SW := SW^.Next;
	end;
	msg := ReplaceHash( msg , BStr( ZG - SWZG ) );
	msg := ReplaceHash( msg , BStr( ZG ) );

	ComputerDescription := Msg;
end;

Function SoftwareDescription( Part: GearPtr ): String;
	{ Return a description of this software's function. }
var
	msg: String;
begin
	msg := SgnStr( Part^.V ) + ' ';

	case Part^.Stat[ STAT_SW_Type ] of
	S_MVBoost:	msg := msg + ReplaceHash( MsgString( 'SOFTWARE_MVBOOST_DESC' ) , Bstr( Part^.Stat[ STAT_SW_Param ] ) );
	S_TRBoost:	msg := msg + ReplaceHash( MsgString( 'SOFTWARE_TRBOOST_DESC' ) , Bstr( Part^.Stat[ STAT_SW_Param ] ) );
	S_SpeedComp:	msg := msg + ReplaceHash( MsgString( 'SOFTWARE_SPEEDCOMP_DESC' ) , Bstr( Part^.Stat[ STAT_SW_Param ] ) );
	S_Information:	msg := MsgSTring( 'SOFTWARE_INFORMATION_' + Bstr( Part^.Stat[ STAT_SW_Param ] ) );
	else msg := msg + MsgString( 'SOFTWARE_MISC_DESC' );
	end;

	msg := msg + '; ' + BStr( ZetaGigs( Part ) ) + ' ZeG';

	SoftwareDescription := msg;
end;

Function UsableDescription( Part: GearPtr ): String;
	{ Return a description for this usable gear. }
begin
	if Part^.S = GS_Transformation then begin
		UsableDescription := MsgString( 'USABLENAME_1' ) + ': ' + MsgString( 'FORMNAME_' + BStr( Part^.V ) );
	end else begin
		UsableDescription := MsgString( 'USABLE_CLASS' ) + ' ' + BStr( Part^.V ) + ' ' + MsgString( 'USABLENAME_' + BStr( Part^.S ) );
	end;
end;

Function CharaDescription( PC: GearPtr ): String;
	{ Return a description of this character. For now, the description will }
	{ just be a list of the character's talents. }
var
	T: Integer;
	msg: String;
begin
	msg := '';
	for t := 1 to NumTalent do begin
		if NAttValue( PC^.NA , NAG_Talent , T ) <> 0 then begin
			if msg = '' then msg := MsgSTring( 'TALENT' + BStr( T ) )
			else msg := msg + ', ' + MsgSTring( 'TALENT' + BStr( T ) );
		end;
	end;
	CharaDescription := msg;
end;

Function ExtendedDescription( GB: GameBoardPtr; Part: GearPtr ): String;
	{ Provide an extended description telling all about the }
	{ attributes of this particular item. }
var
	it,IntDesc: String;
	SC: GearPtr;
begin
	{ Error check first. }
	if Part = Nil then Exit( '' );

	{ Start examining the part. }
	it := '';
	if ( Part^.G = GG_Weapon ) then begin
		it := WeaponDescription( GB , Part );
	end else if Part^.G = GG_Mecha then begin
		it := MechaDescription( Part );
	end else if Part^.G = GG_RepairFuel then begin
		it := RepairFuelDescription( Part );
	end else if ( Part^.G = GG_Ammo ) then begin
		it := WeaponDescription( GB , Part );
	end else if Part^.G = GG_MoveSys then begin
		it := MoveSysDescription( Part );
	end else if Part^.G = GG_Modifier then begin
		it := ModifierDescription( Part );
	end else if Part^.G = GG_Character then begin
		it := CharaDescription( Part );
	end else if Part^.G = GG_Tool then begin
		it := ToolDescription( Part );

		SC := Part^.SubCom;
		while ( SC <> Nil ) do begin
			it := it + '; ' + ExtendedDescription( GB , SC );
			SC := SC^.Next;
		end;

	end else if Part^.G = GG_PowerSource then begin
		it := PowerSourceDescription( Part );
	end else if Part^.G = GG_COmputer then begin
		it := ComputerDescription( Part );
	end else if Part^.G = GG_Software then begin
		it := SoftwareDescription( Part );
	end else if Part^.G = GG_ExArmor then begin
		it := ArmorDescription( Part );

		SC := Part^.SubCom;
		while ( SC <> Nil ) do begin
			it := it + '; ' + ExtendedDescription( GB , SC );
			SC := SC^.Next;
		end;

	end else if Part^.G = GG_Shield then begin
		it := ShieldDescription( Part );

		SC := Part^.SubCom;
		while ( SC <> Nil ) do begin
			it := it + '; ' + ExtendedDescription( GB , SC );
			SC := SC^.Next;
		end;

	end else if Part^.G = GG_WeaponAddOn then begin
		it := WAODescription( Part );

		SC := Part^.SubCom;
		while ( SC <> Nil ) do begin
			it := it + '; ' + ExtendedDescription( GB , SC );
			SC := SC^.Next;
		end;

	end else if Part^.G = GG_Support then begin
		it := ReplaceHash( MsgString( 'SupportDesc' ) , BStr( Part^.V ) );

	end else if Part^.G = GG_Usable then begin
		it := UsableDescription( Part );

	end else if Part^.G <> GG_Module then begin
		SC := Part^.SubCom;
		while ( SC <> Nil ) do begin
			if it = '' then it := ExtendedDescription( GB , SC )
			else it := it + '; ' + ExtendedDescription( GB , SC );
			SC := SC^.Next;
		end;

	end else begin
		{ This is a module, as determined by the above clause. }
		if Part^.Stat[ STAT_VariableModuleForm ] <> 0 then it := MsgString( 'VariableModule' ) + ' ' + MsgString( 'MODULENAME_' + BStr( Part^.Stat[ STAT_PrimaryModuleForm ] ) ) + '/' + MsgString( 'MODULENAME_' + BStr( Part^.Stat[ STAT_VariableModuleForm ] ) );

	end;

	IntDesc := IntrinsicsDescription( Part );
	if IntDesc <> '' then begin
		if it = '' then it := IntDesc
		else it := it + ', ' + IntDesc;
	end;

	ExtendedDescription := it;
end;

Function MechaDescription( Mek: GearPtr ): String;
	{ Return a text description of this mecha's technical points. }
var
	it,i2: String;
	MM,MMS,MaxSpeed,FullSpeed: Integer;
	CanMove: Boolean;
	Engine: GearPtr;
begin
	it := MassString( Mek ) + ' ' + MsgString( 'FORMNAME_' + BStr( Mek^.S ) );
	it := it + ' ' + 'MV:' + SgnStr(MechaManeuver(Mek));
	it := it + ' ' + 'TR:' + SgnStr(MechaTargeting(Mek));
	it := it + ' ' + 'SE:' + SgnStr(MechaSensorRating(Mek));

	MM := CountActiveParts( Mek , GG_Holder , GS_Hand );
	if MM > 0 then begin
		it := it + ' ' + MsgString( 'MEKDESC_Hands' ) + ':' + BStr( MM );
	end;

	MM := CountActiveParts( Mek , GG_Holder , GS_Mount );
	if MM > 0 then begin
		it := it + ' ' + MsgString( 'MEKDESC_Mounts' ) + ':' + BStr( MM );
	end;

	CanMove := False;
	MaxSpeed := 0;
	for MM := 1 to NumMoveMode do begin
		MMS := BaseMoveRate( Nil , Mek , MM );
		FullSpeed := AdjustedMoveRate( Nil , Mek , MM , NAV_FullSpeed );
		if FullSpeed > MaxSpeed then MaxSpeed := FullSpeed;
		if MMS > 0 then begin
			CanMove := True;

			{ Add a description for this movemode. }
			if MM = MM_Fly then begin
				{ Check to see whether the mecha can }
				{ fly or just jump. }
				if JumpTime( Nil , Mek ) = 0 then begin
					it := it + ' ' + MsgString( 'MoveModeName_' + BStr( MM ) ) + ':' + BStr( MMS );
				end else begin
					it := it + ' ' + MsgString( 'MEKDESC_Jump' ) + ':' + BStr( JumpTime( Nil , Mek ) ) + 's';
				end;
			end else begin
				it := it + ' ' + MsgString( 'MoveModeName_' + BStr( MM ) ) + ':' + BStr( MMS );
			end;
		end;
	end;

	if MaxSpeed > 0 then it := it + ' Max:' + BStr( MaxSpeed );

	if Mek^.Stat[ STAT_MechaTrait ] <> 0 then begin
		it := it + ' ' + MsgString( 'MECHATRAIT_' + BStr( Mek^.Stat[ STAT_MechaTrait ] ) );
	end;

	Engine := SeekGear( Mek , GG_Support , GS_Engine );
	if Engine <> Nil then begin
		i2 := MsgString( 'MEKDESC_ENGINE' + Bstr( Engine^.Stat[ STAT_EngineSubtype ] ) );
		if i2 <> '' then it := it + ' ' + i2;
	end;

	{ Add warnings for different conditions. }
	if not CanMove then begin
		it := it + ' ' + MsgString( 'MEKDESC_Immobile' );
	end;
	if Destroyed( Mek ) then begin
		it := it + ' ' + MsgString( 'MEKDESC_Destroyed' );
	end;
	if SeekGear(mek,GG_CockPit,0) = Nil then begin
		it := it + ' ' + MsgString( 'MEKDESC_NoCockpit' );
	end;

	MechaDescription := it;
end;


Function TimeString( ComTime: LongInt ): String;
	{ Create a string to express the time listed in COMTIME. }
var
	msg: String;
	S,M,H,D: LongInt;	{ Seconds, Minutes, Hours, Days }
begin
	S := ComTime mod 60;
	M := ( ComTime div 60 ) mod 60;
	H := ( ComTime div AP_Hour ) mod 24;
	D := ComTime div AP_Day;

	msg := Bstr( H ) + ':' + WideStr( M , 2 ) + ':' + WideStr( S , 2 ) + MsgString( 'CLOCK_days' ) + BStr( D );
	TimeString := msg;
end;

Function JobAgeGenderDesc( NPC: GearPtr ): String;
	{ Return the Job, Age, and Gender of the provided character in }
	{ a nicely formatted string. }
var
	msg,job: String;
	R: Integer;
begin
	R := NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) + 20;
	if R > 0 then msg := BStr( R )
	else msg := '???';
	msg := msg + ' year old ' + LowerCase( MsgString( 'GenderName_' + BStr( NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) ) ) );
	job := SAttValue( NPC^.SA , 'JOB' );
	if job <> '' then msg := msg + ' ' + LowerCase( job );
	{ Check the NPC's relationship with the PC. }
	r := NAttValue( NPC^.NA , NAG_Relationship , 0 );
	if R > 0 then begin
		job := MsgString( 'RELATIONSHIP_' + BStr( R ) );
		if job <> '' then msg := msg + ', ' + job;
	end;
	msg := msg + '.';
	JobAgeGenderDesc := msg;
end;

Function SkillDescription( N: Integer ): String;
	{ Return a description for this skill. The main text is taken }
	{ from the messages.txt file, plus the name of the stat which }
	{ governs this skill. }
var
	msg: String;
begin
	msg := '';

	{ Error check- only provide description for a legal skill }
	{ number. Otherwise just return an empty string. }
	if ( N >= 1 ) and ( N <= NumSkill ) then begin
		msg := MsgString( 'SKILLDESC_' + BStr( N ) );
	end;
	SkillDescription := msg;
end;

Function MechaPilotName( Mek: GearPtr ): String;
	{ Return the name of the mecha and the pilot, together. }
var
	Msg,PName: String;
begin
	msg := GearName( Mek );
	if Mek^.G = GG_Mecha then begin
		PName := PilotName( Mek );
		if PName <> msg then msg := msg + ' (' + PName + ')';
	end;
	MechaPilotName := msg;
end;

Function TeamMateName( M: GearPtr ): String;
	{ Return the name of this team-mate. If the team-mate is a mecha, }
	{ also return the name of its pilot if appropriate. }
var
	msg,pname: String;
begin
	msg := FullGearName( M );
	if M^.G = GG_Mecha then begin
		pname := SAttValue( M^.SA , 'pilot' );
		if pname <> '' then msg := msg + ' (' + pname + ')';
	end;
	TeamMateName := msg;
end;

Function RenownDesc( Renown: Integer ): String;
	{ Return a description for the provided renown. }
begin
	if Renown > 80 then begin
		RenownDesc := MsgString( 'AHQRANK_5' );
	end else if Renown > 60 then begin
		RenownDesc := MsgString( 'AHQRANK_4' );
	end else if Renown > 40 then begin
		RenownDesc := MsgString( 'AHQRANK_3' );
	end else if Renown > 20 then begin
		RenownDesc := MsgString( 'AHQRANK_2' );
	end else begin
		RenownDesc := MsgString( 'AHQRANK_1' );
	end;
end;

end.
