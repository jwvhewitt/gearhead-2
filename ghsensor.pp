unit ghsensor;
	{ This unit covers sensors and electronics. }
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

uses texutil,gears,ui4gh,ghchars;

	{ *** SENSOR FORMAT *** }
	{ G = GG_Sensor }
	{ S = Sensor Type }
	{ V = Sensor Rating / Sensor Function (depending on type) }


	{ *** COMPUTER FORMAT *** }
	{ G = GG_Computer }
	{ S = Undefined }
	{ V = Compy Power }

	{ *** SOFTWARE FORMAT *** }
	{ G = GG_Software }
	{ S = Undefined }
	{ V = Software Rating }
	{ STAT 1 = Software Type }
	{ STAT 2 = Software Parameter }

const
	NumSensorType = 3;
	GS_MainSensor = 1;

	GS_ECM = 3;

	STAT_SW_Type = 1;
		S_MVBoost = 1;	{ Boosts MV score; Param is mecha scale }
		S_TRBoost = 2;	{ Boosts TR score; Param is mecha scale }
		S_SpeedComp = 3;	{ Speed Compensation Targeting Computer; Param is mecha scale }
		S_Information = 4;	{ Contains information. Kind of a software intrinsic. }
			{ Information Software must have value 1. }
	STAT_SW_Param = 2;
		SInfo_CreatureDex = 1;
		SInfo_RobotDex = 2;
		SInfo_SynthDex = 3;
		SInfo_MechaDex = 4;

	Num_SWInfo_Types = 4;
	Software_Information_ZG: Array [1..Num_SWInfo_Types] of Integer = (
		1,1,2,30
	);

Function SensorBaseDamage( Part: GearPtr ): Integer;
Function SensorName( Part: GearPtr ): String;
Function SensorBaseMass( Part: GearPtr ): Integer;
Function SensorValue( Part: GearPtr ): LongInt;
Function SensorComplexity( Part: GearPtr ): Integer;

Procedure CheckSensorRange( Part: GearPtr );

Procedure CheckComputerRange( Part: GearPtr );
Procedure CheckSoftwareRange( Part: GearPtr );
Function ComputerValue( Part: GearPtr ): LongInt;
Function SoftwareValue( Part: GearPtr ): LongInt;

Function ZetaGigs( part: GearPtr ): Integer;

Function IsLegalComputerSub( Compy,Softy: GearPtr ): Boolean;


implementation

Function SensorBaseDamage( Part: GearPtr ): Integer;
	{ Return the amount of damage this sensor can withstand. }
begin
	SensorBaseDamage := 1;
end;

Function SensorName( Part: GearPtr ): String;
	{ Return a name for this particular sensor. }
begin
	SensorName := ReplaceHash( MsgString( 'SENSORNAME_' + BStr( Part^.S ) ) , BStr( Part^.V ) );
end;

Function SensorBaseMass( Part: GearPtr ): Integer;
	{ Return the amount of damage this sensor can withstand. }
begin
	{ As with most other components, the weight of a sensor is }
	{ equal to the amount of damage it can withstand. }
	if Part^.V > 5 then begin
		SensorBaseMass := Part^.V - 4;
	end else begin
		SensorBaseMass := 1;
	end;
end;

Function SensorValue( Part: GearPtr ): LongInt;
	{ Calculate the base cost of this sensor type. }
begin
	if Part^.S = GS_MainSensor then begin
		SensorValue := Part^.V * Part^.V * 2 + 2;

	end else if Part^.S = GS_ECM then begin
		SensorValue := Part^.V * Part^.V * Part^.V * 20 - Part^.V * Part^.V * 14;
	end else SensorValue := 0;
end;

Procedure CheckSensorRange( Part: GearPtr );
	{ Examine this sensor to make sure everything is legal. }
begin
	{ Check S - Sensor Type }
	if Part^.S < 1 then Part^.S := 1
	else if Part^.S > NumSensorType then Part^.S := 1;

	{ Check V - Sensor Rating / Sensor Function }
	if Part^.V < 1 then Part^.V := 1
	else if Part^.V > 10 then Part^.V := 10;

	{ Check Stats - No Stats Defined. }

end;

Function SensorComplexity( Part: GearPtr ): Integer;
	{ Return the number of slots taken up by this sensor. }
begin
	if Part^.V > 5 then begin
		SensorComplexity := Part^.V - 4;
	end else begin
		SensorComplexity := 1;
	end;
end;

Procedure CheckComputerRange( Part: GearPtr );
	{ Check this computer gear, make sure everything is legal. }
begin
	{ V = Computer size; must be in the range 1 to 10 }
	if Part^.V < 1 then Part^.V := 1
	else if Part^.V > 10 then Part^.V := 10;
end;

Procedure CheckSoftwareRange( Part: GearPtr );
	{ Check this software, fixing any illegal values encountered. }
begin
	{ V = Software value; must be in the range 1 to 5 }
	{ Information software doesn't get a value. }
	if ( Part^.V < 1 ) or ( Part^.Stat[STAT_SW_Type] = S_Information ) then Part^.V := 1
	else if Part^.V > 5 then Part^.V := 5;

	{ Information software must be clamped to the right range. }
	if Part^.Stat[ STAT_SW_Type ] = S_Information then begin
		if Part^.Stat[ STAT_SW_Param ] < 1 then Part^.Stat[ STAT_SW_Param ] := 1
		else if Part^.Stat[ STAT_SW_Param ] > Num_SWInfo_Types then Part^.Stat[ STAT_SW_Param ] := Num_SWInfo_Types;
	end;

	{ Check scale- must be 0. }
	Part^.Scale := 0;
end;

Function ComputerValue( Part: GearPtr ): LongInt;
	{ Return the unscaled value of this computer. }
begin
	ComputerValue := Part^.V * 100;
end;

Function SoftwareValue( Part: GearPtr ): LongInt;
	{ Return the value of this software. }
var
	it,t: LongInt;
begin
	if ( Part^.Stat[ STAT_SW_Type ] = S_MVBoost ) or ( Part^.Stat[ STAT_SW_Type ] = S_TRBoost ) then begin
		{ The basic price is quadratic, multiplied upwards by the scale it's }
		{ meant to apply to. }
		it := Part^.V * Part^.V * 100;
		for t := 1 to Part^.Stat[ STAT_SW_Param ] do it := it * 5;
	end else if Part^.Stat[ STAT_SW_Type ] = S_SpeedComp then begin
		it := Part^.V * Part^.V * 35;
		for t := 1 to Part^.Stat[ STAT_SW_Param ] do it := it * 5;

	end else if Part^.Stat[ STAT_SW_Type ] = S_Information then begin
		it := Software_Information_ZG[ Part^.Stat[ STAT_SW_Param ] ] * Software_Information_ZG[ Part^.Stat[ STAT_SW_Param ] ] * 30 + 90;

	end else begin
		it := 100;
	end;
	SoftwareValue := it;
end;

Function ZetaGigs( part: GearPtr ): Integer;
	{ Return the computing power of this component. }
	{ For computers, this is the amount of software that can be stored. }
	{ For software, this is the amount of resources it takes to run. }
	{ It's also the amount of energy that's consumed every time the computer }
	{ program is used, if the program requires energy. }
var
	ZG,T: Integer;
begin
	if Part^.G = GG_Computer then begin
		ZG := Part^.V * 2;
		for t := 1 to Part^.Scale do ZG := ZG * 5;
	end else if Part^.G = GG_Software then begin
		if ( Part^.Stat[ STAT_SW_Type ] = S_MVBoost ) or ( Part^.Stat[ STAT_SW_Type ] = S_TRBoost ) then begin
			ZG := Part^.V * 2;
			for t := 1 to Part^.Stat[ STAT_SW_Param ] do ZG := ZG * 5;
		end else if Part^.Stat[ STAT_SW_Type ] = S_SpeedComp then begin
			ZG := Part^.V;
			for t := 1 to Part^.Stat[ STAT_SW_Param ] do ZG := ZG * 5;
		end else if Part^.Stat[ STAT_SW_Type ] = S_Information then begin
			ZG := Software_Information_ZG[ Part^.Stat[ STAT_SW_Param ] ];
		end else begin
			ZG := 1;
		end;
	end else ZG := 0;
	ZetaGigs := ZG;
end;

Function IsLegalComputerSub( Compy,Softy: GearPtr ): Boolean;
	{ Check to see if this software can be installed in this computer in }
	{ the current state. In order to be installed, the computer must have }
	{ sufficient C-Pow to hold the software. }
var
	S: GearPtr;
	CP: Integer;
begin
	{ Only software can be installed in a computer- if Softy is anything else, exit. }
	if ( Softy = Nil ) or ( Softy^.G <> GG_Software ) then Exit( False );

	{ Count up how many software points the computer's using already. }
	CP := 0;
	S := Compy^.SubCom;
	while S <> Nil do begin
		if S <> Softy then begin
			CP := CP + ZetaGigs( S );
		end;
		S := S^.Next;
	end;

	IsLegalComputerSub := ZetaGigs( Compy ) >= ( CP + ZetaGigs( Softy ) );
end;

end.
