unit ghsupport;
	{ This unit handles support gears - various things needed for a }
	{ mecha's operation which don't fit in elsewhere. }

	{ It also handles cockpits. }

	{ And usables. }

	{ *** RULES *** }
	{ - Support gears may only be installed in the BODY module. }
	{ - Every mecha needs an engine. }
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

uses texutil,gears,ui4gh;

	{ *** SUPPORT FORMAT *** }
	{ G = GG_Support }
	{ S = System Type }
	{ V = System Rating }
	{ Stat[1] = Armor Rating }
	{ Stat[2] = Engine Subtype }

const
	NumSupportType = 2;
	GS_Gyro = 1;
	GS_Engine = 2;

	STAT_EngineSubType = 2;
	EST_HighOutput = 1;		{ Increased energy point supply }
	EST_HighPerformance = 2;	{ Improved MV/TR, reduced energy points, may go boom }


	{ G = GG_Cockpit }
	{ S = Undefined }
	{ V = Cockpit Style }
	{ STAT 1 = Armor Rating }
	{ STAT 2 = Passenger Scale }

	{ G = GG_Usable }
	{ S = Usable Type }
		Num_Usable_System_Types = 4;
		GS_Transformation = 1;
		GS_ForceField = 2;
		GS_Holograms = 3;
		GS_LongRangeScanner = 4;
	{ V = Power Level/Parameter }


Function CockpitBaseMass( CPit: GearPtr ): Integer;
Procedure CheckCPitRange( CPit: GearPtr );
Function IsLegalCPitSub( Part, Equip: GearPtr ): Boolean;

Function UsableBaseMass( Part: GearPtr ): Integer;
Function UsableComplexity( Part: GearPtr ): Integer;
Procedure CheckUsableRange( Part: GearPtr );
Function UsableValue( Part: GearPtr ): LongInt;

Function SupportBaseDamage( Part: GearPtr ): Integer;
Function SupportName( Part: GearPtr ): String;
Function SupportBaseMass( Part: GearPtr ): Integer;
Function SupportValue( Part: GearPtr ): LongInt;
Procedure CheckSupportRange( Part: GearPtr );


implementation

uses ghmecha;

Function CockpitBaseMass( CPit: GearPtr ): Integer;
	{Cockpits usually have no weight... unless they're}
	{armored. In that case, the weight of the cockpit}
	{equals the armor rating assigned to it.}
begin
	CockpitBaseMass := CPit^.Stat[1];
end;

Procedure CheckCPitRange( CPit: GearPtr );
	{ Examine the values of all the cockpit's stats and make sure }
	{ everything is nice and legal. }
var
	T: Integer;
begin
	{ Check S - Currently Undefined }
	CPit^.S := 0;

	{ Check V - Cockpit Type; Currently Undefined }
	CPit^.V := 0;

	{ Check Stats }
	{ Stat 1 - Armor }
	if CPit^.Stat[1] < 0 then CPit^.Stat[1] := 0
	else if CPit^.Stat[1] > 2 then CPit^.Stat[1] := 2;

	{ Stat 2 - Pilot Scale }
	{ The scale of the piot must be less than or equal to the scale of }
	{ the cockpit. }
	if CPit^.Stat[2] >= CPit^.Scale then CPit^.Stat[2] := CPit^.Scale - 1;

	for t := 3 to NumGearStats do CPit^.Stat[ T ] := 0;
end;

Function IsLegalCPitSub( Part, Equip: GearPtr ): Boolean;
	{ Return TRUE if the specified EQUIP may be legally installed }
	{ in PART, FALSE if it can't be. }
begin
	if ( Equip^.G = GG_Character ) and ( Equip^.Scale = Part^.Stat[2] ) then IsLegalCPitSub := True
	else IsLegalCPitSub := False;
end;

Function UsableBaseMass( Part: GearPtr ): Integer;
	{ Return the basic mass of this part. }
begin
	if Part^.S = GS_Transformation then begin
		UsableBaseMass := 1;
	end else if Part^.S = GS_LongRangeScanner then begin
		UsableBaseMass := Part^.V;
	end else begin
		UsableBaseMass := Part^.V * 2;
	end;
end;

Function UsableComplexity( Part: GearPtr ): Integer;
	{ Return the basic complexity of this part- the number of }
	{ slots it takes when installed in a mecha. }
begin
	if Part^.S = GS_Transformation then begin
		UsableComplexity := 2;
	end else if Part^.S = GS_ForceField then begin
		UsableComplexity := Part^.V * 2;
	end else begin
		UsableComplexity := Part^.V;
	end;
end;

Procedure CheckUsableRange( Part: GearPtr );
	{ Check the range of this usable gear to make sure that it's all }
	{ nice and legal. If anything is found out of the ordinary, }
	{ change it. }
begin
	{ Check S- Usable Type }
	if Part^.S < 1 then Part^.S := 1
	else if Part^.S > Num_Usable_System_Types then Part^.S := Num_Usable_System_Types;

	{ Check V- Power/Parameter }
	if Part^.S = GS_Transformation then begin
		if Part^.V < 0 then Part^.V := 0
		else if Part^.V > NumForm then Part^.V := NumForm;
	end else begin
		if Part^.V < 1 then Part^.V := 1
		else if Part^.V > 10 then Part^.V := 10;
	end;
end;

Function UsableValue( Part: GearPtr ): LongInt;
	{ Return the basic cost of this part. }
begin
	case Part^.S of
		GS_Transformation:	UsableValue := 1000;
		GS_ForceField:		UsableValue := Part^.V * Part^.V * Part^.V * 25 + Part^.V * Part^.V * 50 + Part^.V * 175;
		GS_Holograms:		UsableValue := Part^.V * Part^.V * Part^.V * 25 + Part^.V * 75 + 750;
		GS_LongRangeScanner:	UsableValue := Part^.V * Part^.V * 50 + Part^.V * 100 + 500;
	end;
end;

Function SupportBaseDamage( Part: GearPtr ): Integer;
	{ Return the amount of damage this system can withstand. }
begin
	if Part^.S = GS_Engine then begin
		SupportBaseDamage := 3;
	end else begin
		SupportBaseDamage := 1;
	end;
end;

Function SupportName( Part: GearPtr ): String;
	{ Return a name for this particular sensor. }
begin
	SupportName := MsgString( 'SUPPORTGEARNAME_' + BStr( Part^.S ) );
end;

Function SupportBaseMass( Part: GearPtr ): Integer;
	{ Return the mass of this system. }
begin
	{ The mass is equal to the armor value }
	SupportBaseMass := Part^.Stat[1];
end;

Function SupportValue( Part: GearPtr ): LongInt;
	{ Calculate the base cost of this sensor type. }
var
	it: LongInt;
begin
	if Part^.S = GS_Gyro then begin
		it := 50;
	end else if Part^.S = GS_Engine then begin
		case Part^.Stat[ STAT_EngineSubType ] of
			EST_HighOutput: it := Part^.V * 200;
			EST_HighPerformance: it := Part^.V * 200;
			else it := Part^.V * 45;
		end;
	end else it := Part^.V * 45;

	{ Add the armor cost. }
	it := it + Part^.Stat[1] * 25;

	SupportValue := it;
end;


Procedure CheckSupportRange( Part: GearPtr );
	{ Examine this support system to make sure everything is legal. }
begin
	{ Check S - System Type }
	if Part^.S < 1 then Part^.S := 1
	else if Part^.S > NumSupportType then Part^.S := 1;

	{ Check V - System Rating. Must be in the range from 1 to 10. }
	if ( Part^.S = GS_Engine ) and ( Part^.Parent <> Nil ) then begin
		if Part^.V <> Part^.Parent^.V then Part^.V := Part^.Parent^.V;
		if Part^.Scale <> Part^.Parent^.Scale then Part^.Scale := Part^.Parent^.Scale;
	end else begin
		{ GH2 - Gyros no longer have ratings. }
		Part^.V := 1;
	end;

	{ Check Stats - Stat 1 is armor. }
	if Part^.Stat[1] < 0 then Part^.Stat[1] := 0
	else if Part^.Stat[1] > 2 then Part^.Stat[2] := 2;
end;

end.
