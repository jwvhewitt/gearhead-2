unit ghmecha;
	{This unit handles stuff for MECHA GEARS.}

	{ G = GG_MECHA }
	{ S = Mecha Form (Transformation Mode) }
	{ V = Size Class of Mecha }
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

uses gears,texutil,ui4gh;

Const
	NumForm = 9;		{ The number of different FORMs which exist in the game.}

	GS_Battroid = 0;	{ Default form }
	GS_Zoanoid = 1;		{ Animal Form Mecha }
	GS_GroundHugger = 2;	{ Land Vehicle - Heavy Armor }
	GS_Arachnoid = 3;	{ Walker type tank }
	GS_AeroFighter = 4;	{ Fighter Jet type }
	GS_Ornithoid = 5;	{ Bird Form Mecha }
	GS_Gerwalk = 6;		{ Half robot half plane }
	GS_HoverFighter = 7;	{ Helicopter, etc. }
	GS_GroundCar = 8;	{ Land Vehicle - High Speed }

	STAT_MechaTrait = 1;	{ The design perk associated with this design. }
		NumMechaTrait = 1;
		MT_ReflexSystem = 1;	{ Bonus to mecha skills if matched by personal skills. }

	FormMVBonus: Array [ 0 .. ( NumForm - 1 ) ] of SmallInt = (
		1, 2, -1, 0, -5,
		-1, -3, -3, -1
	);

	FormTRBonus: Array [ 0 .. ( NumForm - 1 ) ] of SmallInt = (
		1, -1, 2, 1 , -1,
		-2, 0, 0, 1
	);


Procedure InitMecha(Part: GearPtr);
Function MechaName(Part: GearPtr): String;
Procedure CheckMechaRange( Mek: GearPtr );
Function IsLegalMechaSubCom( Part, Equip: GearPtr ): Boolean;

Function MechaCost( Mek: GearPtr ): LongInt;

Function MechaTraitDesc( Mek: GearPtr ): String;
Function HasMechaTrait( Mek: GearPtr; Trait: Integer ): Boolean;


implementation

uses ghmodule;

Procedure InitMecha(Part: GearPtr);
	{Part is a newly created Mecha record.}
	{Initialize fields to default values.}
begin
	{Default Scale = 2}
	Part^.Scale := 2;
end;

Function MechaName(Part: GearPtr): String;
	{Figure out a default name for a mecha.}
begin
	MechaName := MsgString( 'FORMNAME_' + BStr( Part^.S ) );
end;

Procedure CheckMechaRange( Mek: GearPtr );
	{ Check a MECHA gear to make sure all values are within appropriate }
	{ range. }
var
	T: Integer;
begin
	{ Check S - Mecha Form }
	if Mek^.S < 0 then Mek^.S := 0
	else if Mek^.S > ( NumForm - 1 ) then Mek^.S := GS_Battroid;

	{ Check V - Mecha Size }
	if Mek^.V < 1 then Mek^.V := 1
	else if Mek^.V > 10 then Mek^.V := 10;

	{ Check Stats }
	if Mek^.Stat[ STAT_MechaTrait ] < 0 then Mek^.Stat[ STAT_MechaTrait ] := 0
	else if Mek^.Stat[ STAT_MechaTrait ] > NumMechaTrait then Mek^.Stat[ STAT_MechaTrait ] := 0;
	
	for t := 2 to NumGearStats do Mek^.Stat[ T ] := 0;
end;

Function IsLegalMechaSubCom( Part, Equip: GearPtr ): Boolean;
	{ Return TRUE if EQUIP can be installed as a subcomponent }
	{ of PART, FALSE otherwise. Both inputs should be properly }
	{ defined & initialized. }
begin
	if Equip^.G = GG_Module then begin
		{ The size of a module may not exceed the declared }
		{ size of the mecha by more than one, and the size }
		{ of the BODY module must exactly match the size of }
		{ the mecha. }
		{ Also, the material of a module must match the material of the mecha. }
		if Equip^.S = GS_Body then begin
			if Equip^.V = Part^.V then IsLegalMechaSubCom := ( NAttValue( Part^.NA , NAG_GearOps , NAS_Material ) = NAttValue( Equip^.NA , NAG_GearOps , NAS_Material ) )
			else IsLegalMechaSubCom := False;
		end else begin
			if Equip^.V <= ( Part^.V + 1 ) then IsLegalMechaSubCom := ( NAttValue( Part^.NA , NAG_GearOps , NAS_Material ) = NAttValue( Equip^.NA , NAG_GearOps , NAS_Material ) )
			else IsLegalMechaSubCom := False;
		end;

	{ Mecha can mount modification gears. }
	end else if Equip^.G = GG_Modifier then begin
		IsLegalMechaSubCom := Equip^.V = GV_MechaModifier;

	{ No other components may be subcoms of a mecha. }
	end else IsLegalMechaSubCom := False;
end;

Function MechaCost( Mek: GearPtr ): LongInt;
	{ Return the basic cost of this mecha. Cost gets increased based on material and trait. }
const
	TraitCost: Array [0..NumMechaTrait] of LongInt = (
	0,
	1000
	);
begin
	if ( Mek^.Stat[ STAT_MechaTrait ] >= 0 ) and ( Mek^.Stat[ STAT_MechaTrait ] <= NumMechaTrait ) then begin
		MechaCost := TraitCost[ Mek^.Stat[ STAT_MechaTrait ] ] * Mek^.V;
	end else begin
		MechaCost := 0;
	end;
end;

Function MechaTraitDesc( Mek: GearPtr ): String;
	{ Create a string describing the traits of this mecha. }
	{ At the moment, this only contains form name. }
begin
	MechaTraitDesc := MsgString( 'FORMNAME_' + BStr( Mek^.S ) );
end;

Function HasMechaTrait( Mek: GearPtr; Trait: Integer ): Boolean;
	{ Return TRUE if this mecha has the specified trait. }
begin
	HasMechaTrait := ( Mek <> Nil ) and ( Mek^.G = GG_Mecha ) and ( Mek^.Stat[ STAT_MechaTrait ] = Trait );
end;

end.
