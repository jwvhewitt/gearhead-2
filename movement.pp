unit movement;
	{ This is one of the primitives for GearHead. }
	{ The main purpose of this unit is to calculate the }
	{ movement rates of mecha, then return them as either }
	{ hexes per turn or clicks per hex. }

	{ *** GLOSSARY *** }
	{ Hex: One tile on the game map. }
	{ Decihex: 10 decihexes = 1 hex. A measurement I just made up to make the math nicer. }
	{ Round: One combat turn in a pen-and-paper mecha game. }
	{ Click: One time unit by the game clock. }
	{ Map Scale: Movement rates are based on the assumption that a unit will be }
	{  traveling on a game map designed for its scale. If an out of scale unit }
	{  is on the map, its movement rate will need to be adjusted. }
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

uses gears,ghmecha,ghmodule,ghmovers,ghchars,ghsupport,gearutil;


const
	NumMoveMode = 5;
	MM_Walk = 1;
	MM_Roll = 2;
	MM_Skim = 3;
	MM_Fly = 4;
	MM_Space = 5;

	FormXMode: Array [0..NumForm-1,1..NumMoveMode] of boolean = (
	{	WALK	ROLL	SKIM	FLY	SPACE	}
	(	True,	True,	True,	True,	True	),	{Battroid}
	(	True,	False,	False,	True,	True	),	{Zoanoid}
	(	False,	True,	True,	False,	False	),	{GroundHugger}
	(	True,	False,	False,	True,	False	),	{Arachnoid}
	(	False,	False,	False,	True,	True	),	{AeroFighter}
	(	True,	False,	False,	True,	True	),	{Ornithoid}
	(	True,	False,	True,	True,	True	),	{GerWalk}
	(	False,	False,	True,	True,	True	),	{HoverFighter}
	(	False,	True,	False,	False,	False	)	{GroundCar}
	);

	FormSpeedLimit: Array [0..NumForm-1,1..NumMoveMode] of Integer = (
	{	WALK	ROLL	SKIM	FLY	SPACE	}
	(	200,	100,	150,	150,	300	),	{Battroid}
	(	200,	0,	0,	200,	300	),	{Zoanoid}
	(	200,	150,	200,	0,	300	),	{GroundHugger}
	(	200,	0,	0,	100,	300	),	{Arachnoid}
	(	200,	0,	0,	300,	500	),	{AeroFighter}
	(	200,	0,	0,	300,	300	),	{Ornithoid}
	(	60,	0,	300,	250,	300	),	{GerWalk}
	(	200,	0,	300,	250,	300	),	{HoverFighter}
	(	200,	200,	0,	0,	300	)	{GroundCar}
	);


	{ This next array correlates thrust points with movement systems. }
	MSysXMode: Array [1..NumMoveSys,3..NumMoveMode+1] of Integer = (
	{	SKIM	FLY	SPACE	OVER	}
	(	0,	0,	0,	0	),	{ Wheels }
	(	0,	0,	0,	0	),	{ Tracks }
	(	85,	11,	79,	0	),	{ Hover Jets }
	(	0,	102,	85,	0	),	{ Flight Jets }
	(	90,	90,	79,	0	),	{ Arc Jets }
	(	7,	7,	11,	140	),	{ Overchargers }
	(	0,	0,	90,	0	),	{ Space Flight }
	(	0,	0,	0,	0	)	{ Heavy Actuator }
	);
	THRUST_Overchargers = NumMoveMode + 1;

	MinWalkSpeed = 20;
	MinFlightSpeed = 150;	{ Minimum needed speed for true flight. }
				{ Slower than this, only jumping possible. }
	MinJumpSpeed = 30;	{ Minimum speed needed to jump. Slower }
				{ than this, and speed drops to 0. }
	ClicksPerRound = 60;	{ Used for calculating CPH move rate. }
	MinCPH = 2;		{ Fastest possible speed, in Clicks Per Hex. }

	SpeedLimit = 50;	{ Speeds higher than this get scaled down. }
	OCSpeedLimit = 20;	{ OverCharger bonuses higher than this get scaled down. }

	NAG_Action = -2;	{ These items describe the action state of the mecha.}
	NAS_MoveMode = 0;	{ Walking, Wheels, Hover, etc. }

	Jump_Recharge_Time = 100;

	Thrust_Per_Wing = 80;	{ Thrust per wing point for critters. }
	CharaThrustPerWing = 90;	{ Skim thrust per wing point. }

	NAS_MoveAction = 1;	{ Stop, Cruise, Flank Speed, Turn }
		NAV_Stop = 0;
		NAV_NormSpeed = 1;
		NAV_FullSpeed = 2;
		NAV_TurnLeft = 3;
		NAV_TurnRight = 4;
		NAV_Reverse = 5;
		NAV_Hover = 6;

	NAS_MoveETA = 2;	{ Estimated Time of Arrival }
	NAS_MoveStart = 3;	{ Time when movement started }
	NAS_CallTime = 4;	{ Time when control procedure is called }
	NAS_TimeLimit = 5;	{ Time limit for jumping movement. }
	NAS_JumpRecharge = 6;

	NAS_DriftVector = 7;	{ Direction of speed, in space }
	NAS_DriftSpeed = 8;	{ Speed of movement, in space }
	NAS_DriftETA = 9;	{ When drifting will happen, in space }

	NAS_TilesInARow = 10;	{ Counts how many tiles the model has been going forward. }
	NAS_WillCrash = 11;	{ If nonzero, this mecha is due for a crashing. }
				{ The value is the damage due from the crash. }
	NAS_WillCharge = 12;	{ If nonzero, this mecha is set to charge another mecha. }
				{ The value is the UID of the target. }
	NAS_ChargeSpeed = 13;	{ Speed at the time the charge is declared. }
	NAS_MightGiveUp = 14;	{ The NPC will make an ejection/surrender check now. }
	NAS_WillExplode = 15;	{ The target's gonna blow up real good. }
	NAS_WillDisappear = 16;	{ The target's gonna get shaken down and will disappear. }

	NAG_EnvironmentData = 22;	{ Tells things about the scene. }
					{ Environment data is inherited by encounters and }
					{ dynamic scenes. }
		Num_Environment_Variables = 3;
		NAS_Gravity = 1;
			NAV_Earthlike = 0;	{ Default for all variables. }
			NAV_Microgravity = 1;
		NAS_Atmosphere = 2;
			NAV_Vacuum = 1;
		NAS_Ceiling = 3;
			NAV_HasCeiling = 1;

	Num_Environment_Types = 3;
		ENV_Ground = 1;
		ENV_Space = 2;
		ENV_Inside = 3;

	Environment_Idents: Array [1..Num_Environment_Types] of string = (
		'GROUND', 'SPACE', 'INSIDE'
	);


function FormMoveRate( Scene, Master: GearPtr ; MoveMode,MechaForm: Integer ): Integer;
function BaseMoveRate( Scene, Master: GearPtr ; MoveMode: Integer ): Integer;
function CurrentMoveRate( Scene, Master: GearPtr ): Integer;
Function AdjustedMoveRate( Scene, Master: GearPtr; MoveMode, MoveOrder: Integer): Integer;
function Speedometer( Scene, Master: GearPtr ): Integer;
procedure GearUP( Mek: GearPtr );
function CPHMoveRate( Scene, Master: GearPtr ; MapScale: Integer ): Integer;
Function JumpTime( Scene, Master: GearPtr ): Integer;
Function MoveLegal( Scene, Mek: GEarPtr; MoveMode,MoveAction: Integer; COmTime: LongInt ): Boolean;
Function MoveLegal( Scene, Mek: GEarPtr; MoveAction: Integer; COmTime: LongInt ): Boolean;

Function HasAtLeastOneValidMovemode( Mek: GearPtr ): Boolean;

Function MekCanEnterScene( Mek,Scene: GearPtr ): Boolean;

implementation

const
	ZoaWalkBonus = 20;	{ Bonus to walking movement for Zoanoid mecha. }

	TMWalkSpeed = 240;	{ Tripled Maximum Walking Speed }
	TMRollSpeed = 360;	{ Tripled Maximum Rolling Speed }

	CharWalkMultiplier = 3;
	CharRollMultiplier = 5;

Function CountThrustPoints( Master: GearPtr; MM,Scale: Integer ): LongInt;
	{ Count the number of thrust points for movemode MM that this }
	{ master gear has. }
var
	it,BaseTP: LongInt;
	Bitz: GearPtr;
begin
	{ Initialize the count to 0. }
	it := 0;

	{ Start looking for movement systems. }
	{ Only nondestroyed systems of an appropriate scale need }
	{ be checked. }
	if NotDestroyed( Master ) then begin
		{ If this gear is itself a movement system, add its }
		{ thrust points to the total. }
		if ( Master^.G = GG_MoveSys ) and ( Scale = Master^.Scale ) then begin
			BaseTP := MSysXMode[ Master^.S , MM ] * Master^.V;
			{ Movement systems mounted in legs and wings get a thrust point }
			{ bonus- 10% and 25% respectively. }
			if ( Master^.Parent <> Nil ) and ( Master^.Parent^.G = GG_Module ) then begin
				if Master^.Parent^.S = GS_Wing then BaseTP := ( BaseTP * 5 ) div 4
				else if Master^.Parent^.S = GS_Leg then BaseTP := ( BaseTP * 11 ) div 10
			end;
			it := it + BaseTP;
		end;

		{ Check sub-components. }
		Bitz := Master^.SubCom;
		while Bitz <> Nil do begin
			it := it + CountThrustPoints( Bitz , MM , Scale );
			Bitz := Bitz^.Next;
		end;

		{ Check inventory components, unless MASTER is itself }
		{ a master gear (confusing I know) in which case its }
		{ inventory components will be the general inventory, }
		{ and we don't want movement systems from there to count }
		{ until they're equipped. }
		if not IsMasterGear( Master ) then begin
			Bitz := Master^.InvCom;
			while Bitz <> Nil do begin
				it := it + CountThrustPoints( Bitz , MM , Scale );
				Bitz := Bitz^.Next;
			end;
		end;
	end;

	CountThrustPoints := it;
end;

function CalcWalk( Mek: GearPtr; Form: Integer ): Integer;
	{ Calculate the base walking rate for this mecha. }
const
	ThrustPerHM = 25;
var
	mass,spd: Integer;
	ActualLegPoints,MinLegPoints,NumLegs,MaxLegs,HM: Integer;
begin
	if Mek^.G = GG_Mecha then begin
		{ Find the mass of the mecha. This will give the basic }
		{ movement rate. }
		mass := GearMass( Mek );
		if mass < 20 then mass := 20;
		spd := (TMWalkSpeed - mass) div 3;

		if Form = GS_Zoanoid then spd := spd + ZoaWalkBonus;

		if spd < MinWalkSpeed then spd := MinWalkSpeed;

		{ This base movement rate may be reduced considerably if }
		{ the mek is damaged, or if it was just built with stubby }
		{ legs. Ideally, the number of leg points must be no less }
		{ than mecha Size * 2 - 2 }
		MinLegPoints := Mek^.V * 2 - 2;
		if MinLegPoints < 2 then MinLegPoints := 2;

		ActualLegPoints := CountActivePoints( Mek , GG_Module , GS_Leg );

		{ Add a bonus for heavy Actuator. }
		HM := CountActivePoints( Mek , GG_MoveSys , GS_HeavyActuator ) * ThrustPerHM;
		if HM > Mass then begin
			spd := spd + ( HM * 10 ) div mass;
		end;

		if ActualLegPoints < MinLegPoints then begin
			spd := (spd * ActualLegPoints) div MinLegPoints;
			if spd < 1 then spd := 1;
		end;

		{If the number of legs has dropped below half+1,}
		{walking becomes impossible.}
		NumLegs := CountActiveParts(Mek , GG_Module , GS_Leg);
		MaxLegs := CountTotalParts(Mek , GG_Module , GS_Leg);
		if ( NumLegs * 2 ) < ( MaxLegs + 2 ) then spd := 0;

		{ Finally, check the gyroscope. Mecha can't walk without one. }
		if SeekActiveIntrinsic( Mek , GG_Support , GS_Gyro ) = Nil then spd := 0;

	end else if Mek^.G = GG_Character then begin
		spd := CStat( Mek , STAT_Speed ) * CharWalkMultiplier;

		{ Reduce the walking speed if the character's legs have }
		{ been hurt. }
		MaxLegs := CountTotalParts(Mek , GG_Module , GS_Leg);
		if MaxLegs > 0 then begin
			NumLegs := CountActiveParts(Mek , GG_Module , GS_Leg);
			if ( NumLegs * 2 ) < ( MaxLegs + 2 ) then begin
				{ Unlike mecha, characters don't get entirely }
				{ immobilized by leg damage. It's assumed a }
				{ legless character can still drag itself to the }
				{ hospital using its arms, upper lip, etc. }
				spd := spd div 10;
			end else if NumLegs < MaxLegs then begin
				spd := (spd * NumLegs) div MaxLegs;
			end;

			if spd < MinWalkSpeed then spd := MinWalkSpeed;
		end;

	end else spd := 0;

	CalcWalk := spd;
end;

function CalcRoll( Mek: GearPtr; Form: Integer ): Integer;
	{ Calculate the base ground movement rate for this mecha. }
var
	mass,spd: Integer;
	ActualWheelPoints,MinWheelPoints: Integer;
begin
	{ Find the mass of the mecha. This will give the basic }
	{ movement rate. }
	if Mek^.G = GG_Mecha then begin
		mass := GearMass( Mek );
		if mass < 20 then mass := 20;
		spd := ( TMRollSpeed - mass ) div 3;
		if spd < MinWalkSpeed then spd := MinWalkSpeed;

		if Form = GS_GroundCar then begin
			spd := ( spd * 3 ) div 2;
		end;

		MinWheelPoints := Mek^.V * 2 - 2;
		if MinWheelPoints < 2 then MinWheelPoints := 2;

	end else if Mek^.G = GG_Character then begin
		spd := CStat( Mek , STAT_Speed ) * CharRollMultiplier;

		MinWheelPoints := 10;

	end else begin
		Exit( 0 );

	end;

	ActualWheelPoints := CountActivePoints( Mek , GG_MoveSys , GS_Wheels ) + CountActivePoints( Mek , GG_MoveSys , GS_Tracks );

	if ActualWheelPoints = 0 then Exit(0);

	if ActualWheelPoints < MinWheelPoints then begin
		spd := (spd * ActualWheelPoints) div MinWheelPoints;
		if spd < 1 then spd := 1;
	end;

	CalcRoll := spd;
end;

function CalcSkim( Mek: GearPtr; Form: Integer ): Integer;
	{ Calculate the base hovering speed for this mecha. }
var
	mass,thrust,spd: Integer;
begin
	if Mek^.G = GG_Mecha then begin
		{ Calculate the mass... }
		mass := GearMass( Mek );
	end else begin
		mass := GearMass( Mek ) + 25;
	end;

	{ Calculate the number of thrust points. This is equal to }
	{ the number of active hover jets times the thrust per jet }
	{ constant. }
	thrust := CountThrustPoints( mek , MM_Skim , mek^.Scale );

	{ Characters (i.e. monsters) get skim points for having wings. }
	if Mek^.G = GG_Character then begin
		thrust := thrust + CountActivePoints( mek , GG_Module , GS_Wing ) * CharaThrustPerWing;
	end;

	if thrust >= mass then begin
		{ Speed is equal to Thrust divided by Mass. }
		{ Multiply by 10 since we want it expressed in }
		{ decihexes per round. }
		spd := (thrust * 10) div mass;

		{ Check the gyroscope. Lacking one will slow down the mek. }
		if ( SeekActiveIntrinsic( Mek , GG_Support , GS_Gyro ) = Nil ) and ( Mek^.G = GG_Mecha ) then spd := spd div 2;

	end else begin
		{ This mecha doesn't have enough thrust to move at all. }
		spd := 0;
	end;

	CalcSkim := spd;
end;

function CalcFly( Scene, Mek: GearPtr; Form: Integer; TrueSpeed: Boolean ): Integer;
	{ Calculate the base flight speed for this mecha. }
	{ Set TRUESPEED to TRUE if you want the actual speed of the }
	{ mecha, or to FALSE if you want its projected speed (needed }
	{ to calculate jumpjet time- see below). }
var
	mass,thrust,t2,spd,WingPoints: Integer;
	IsAVacuum: Boolean;
begin
	{ Ceiling check- if this scene has a ceiling, no-one's flying anywhere. }
	if ( Scene <> Nil ) and ( NAttValue( Scene^.NA , NAG_EnvironmentData , NAS_Ceiling ) = NAV_HasCeiling ) then begin
		Exit( 0 );
	end;

	if Mek^.G = GG_Mecha then begin
		{ Calculate the mass... }
		mass := GearMass( Mek );
	end else begin
		mass := GearMass( Mek ) + 25;
	end;

	IsAVacuum := ( not ( Scene = Nil ) ) and ( NAttValue( Scene^.NA , NAG_EnvironmentData , NAS_Atmosphere ) = NAV_Vacuum );

	{ Calculate the number of thrust points. This is equal to }
	{ the number of active hover jets times the thrust per jet }
	{ constant. }
	thrust := CountThrustPoints( mek , MM_Fly , mek^.Scale );

	{ In a vacuum, space flight can substitute for regular flight. Why? Because otherwise you'd }
	{ have the case where a space flying mecha would encounter enemies on an asteroid and immediately }
	{ get grounded. }
	if IsAVacuum then begin
		t2 := CountThrustPoints( mek , MM_Space , mek^.Scale );
		if t2 > thrust then thrust := t2;
	end;

	{ Count the number of wing points present. }
	{ If there aren't enough, give a penalty to thrust. }
	if not IsAVacuum then begin
		WingPoints := CountActivePoints( Mek , GG_Module , GS_Wing );
		if WingPoints < MasterSize( mek ) then begin
			thrust := thrust div 2;
		end;
	end else begin
		WingPoints := 0;
	end;

	{ If this is a character, wings alone provide thrust }
	{ points. This is mostly to make flying monsters work. }
	if mek^.G = GG_Character then begin
		thrust := thrust + WingPoints * Thrust_Per_Wing;

	end else if mek^.G = GG_Mecha then begin
		{ If this is a mecha, modify thrust points based }
		{ upon the type of mecha we're dealing with. }
		case Form of
		GS_AeroFighter: if WingPoints > MasterSize( Mek ) then Thrust := Thrust * 2 else Thrust := ( Thrust * 5 ) div 4;
		GS_HoverFighter,GS_GerWalk: Thrust := ( Thrust * 5 ) div 4;
		GS_Ornithoid: begin
				if WingPoints > MasterSize( Mek ) then Thrust := ( Thrust * 3 ) div 2;
				Thrust := Thrust + WingPoints * Thrust_Per_Wing;
			end;

		end;
	end;


	if thrust >= mass then begin
		{ Speed is equal to Thrust divided by Mass. }
		{ Multiply by 10 since we want it expressed in }
		{ decihexes per round. }
		spd := (thrust * 10) div mass;

		{ The speed will not drop below the minimum flight speed, }
		{ so long as it's above the minimum jump speed. }
		{ Jumping happens at MFS, it's just that the amount }
		{ of time you can spend in the air is lessened. }
		if ( Spd < MinJumpSpeed ) then Spd := 0
		else if ( spd < MinFlightSpeed ) and TrueSpeed then spd := MinFlightSpeed;

		{ Check the gyroscope. Lacking one will ground the mek. }
		if ( SeekActiveIntrinsic( Mek , GG_Support , GS_Gyro ) = Nil ) and ( Mek^.G = GG_Mecha ) then spd := 0;

	end else begin
		{ This mecha doesn't have enough thrust to move at all. }
		spd := 0;
	end;

	CalcFly := spd;
end;

function CalcSpace( Mek: GearPtr; Form: Integer ): Integer;
	{ Calculate the base space flight speed for this mecha. }
var
	mass,thrust,spd: Integer;
begin
	if Mek^.G = GG_Mecha then begin
		{ Calculate the mass... }
		mass := GearMass( Mek );
	end else begin
		mass := GearMass( Mek ) + 25;
	end;

	{ Calculate the number of thrust points. This is equal to }
	{ the number of active hover jets times the thrust per jet }
	{ constant. }
	thrust := CountThrustPoints( mek , MM_Space , mek^.Scale );
	if Mek^.G = GG_Mecha then begin
		case Form of
			GS_AeroFighter: Thrust := Thrust * 2;
			GS_HoverFighter,GS_GerWalk,GS_Ornithoid: Thrust := ( Thrust * 4 ) div 3;
		end;
	end;

	if thrust >= mass then begin
		{ Speed is equal to Thrust divided by Mass. }
		{ Multiply by 10 since we want it expressed in }
		{ decihexes per round. }
		spd := (thrust * 10) div mass;
	end else begin
		{ This mecha doesn't have enough thrust to move at all. }
		spd := 0;
	end;

	CalcSpace := spd;
end;


Function OverchargeBonus( Master: GearPtr ): Integer;
	{ Overchargers add a bonus to a mek's FULLSPEED action. }
var
	mass,thrust,it,T,SF: Integer;
begin
	if Master^.G = GG_Mecha then begin
		{ Calculate the mass... }
		mass := GearMass( Master );
	end else begin
		mass := GearMass( Master ) + 25;
	end;
	thrust := CountThrustPoints( Master , THRUST_Overchargers , Master^.Scale );
	it := ( thrust * 10 ) div mass;

	{ If the speed is too high, scale it back a bit. }
	for t := 1 to 10 do begin
		{ SF stands for Speed Factor. }
		SF := T * OCSpeedLimit;
		if it > SF then begin
			it := SF + ( ( it - SF ) div 2 );
		end;
	end;

	OverchargeBonus := it;
end;

function FormMoveRate( Scene, Master: GearPtr ; MoveMode,MechaForm: Integer ): Integer;
	{Check the master gear MASTER and determine how fast it can}
	{move using movement rate MOVEMODE. If the mecha is not}
	{capable of using this movemode, return 0.}
	{The movement rate is givin in decihexes per round.}
var
	it,SF,t: Integer;
begin
	{Error check- make sure we have a valid master here.}
	if not IsMasterGear(Master) then Exit( 0 );
	if MoveMode = 0 then Exit( 0 );

	{Check to make sure the movemode is supported by the mecha's}
	{current form.}
	if Master^.G = GG_Mecha then begin
		if not FormXMode[MechaForm,MoveMode] then Exit(0);
	end;

	case MoveMode of
		MM_Walk:	it := CalcWalk( Master , MechaForm );
		MM_Roll:	it := CalcRoll( Master , MechaForm );
		MM_Skim:	it := CalcSkim( Master , MechaForm );
		MM_Fly:		it := CalcFly( Scene , Master , MechaForm , True );
		MM_Space:	it := CalcSpace( Master , MechaForm );
		else it := 0;
	end;

	{ If the speed is too high, scale it back a bit. }
	for t := 1 to 10 do begin
		{ SF stands for Speed Factor. }
		SF := T * SpeedLimit;
		if it > SF then begin
			it := SF + ( ( it - SF ) div 2 );
		end;
	end;

	{ If the speed is higher than the mecha form speed limit, }
	{ reduce it a bit as well. }
	if Master^.G = GG_Mecha then begin
		if it > FormSpeedLimit[MechaForm,MoveMode] then begin
			it := FormSpeedLimit[MechaForm,MoveMode] + ( ( it - FormSpeedLimit[Master^.S,MoveMode] ) div 2 );
		end;
	end;

	FormMoveRate := it;
end;

function BaseMoveRate( Scene, Master: GearPtr ; MoveMode: Integer ): Integer;
	{ Return the basic move rate for the current form. }
begin
	BaseMoveRate := FormMoveRate( Scene, Master, MoveMode, Master^.S );
end;

function CurrentMoveRate( Scene, Master: GearPtr ): Integer;
	{ Determine the basic movement rate for the mecha based upon its }
	{ current move mode. Do not adjust for actions. }
begin
	CurrentMoveRate := BaseMoveRate( Scene, Master , NAttValue( Master^.NA , NAG_Action , NAS_MoveMode ) );
end;

function CalcMaxTurnRate( Mek: GearPtr ): Integer;
	{ Calculate the maximum possible turn rate for this mecha. }
	{ The actual turn rate will be limited by the mecha's actual }
	{ movement rate. }
var
	mass,spd: Integer;
begin
	if Mek^.G = GG_Mecha then begin
		{ Find the mass of the mecha. This will give the basic }
		{ movement rate. }
		mass := GearMass( Mek );
		if mass < 20 then mass := 20;
		spd := (TMWalkSpeed - mass) div 3;

		if Mek^.S = GS_Zoanoid then spd := spd + ZoaWalkBonus;

		if spd < MinWalkSpeed then spd := MinWalkSpeed;

	end else if Mek^.G = GG_Character then begin
		spd := CStat( Mek , STAT_Speed ) * CharWalkMultiplier;
	end else spd := 0;
	CalcMaxTurnRate := spd;
end;

Function AdjustedMoveRate( Scene, Master: GearPtr; MoveMode, MoveOrder: Integer): Integer;
	{ Return the movement rate of this gear, adjusted for the }
	{ current movement action. }
var
	BMR,T: Integer;
begin
	BMR := BaseMoveRate( Scene, Master , MoveMode );

	{ If turning, the mecha's speed will be limited by the }
	{ maximum turn rate. }
	if ( MoveOrder = NAV_TurnLeft ) or ( MoveOrder = NAV_TurnRight ) then begin
		T := CalcMaxTurnRate( Master );
		if T < BMR then BMR := T;
	end;

	{ If traveling at full speed, increase move rate for the }
	{ overchargers. }
	if MoveOrder = NAV_FullSpeed then begin
		BMR := BMR + OverchargeBonus( Master );
	end;

	{ Increase movement rate if the mecha is traveling at full speed.}
	if MoveOrder = NAV_FullSpeed then BMR := (BMR * 3) div 2;

	{ Turning is usually faster than moving straight ahead. }
	if ( MoveOrder = NAV_TurnLeft ) or ( MoveOrder = NAV_TurnRight ) then begin
		{ If the mecha is walking, turning is even faster }
		if MoveMode = MM_Walk then BMR := BMR * 8
		else BMR := BMR * 2;
	end;

	AdjustedMoveRate := BMR;
end;

function Speedometer( Scene, Master: GearPtr ): Integer;
	{ Determine the movement rate for the current move mode and }
	{ action. }
var
	MM,Order: Integer;
begin
	MM := NAttValue( Master^.NA , NAG_Action , NAS_MoveMode );
	Order := NAttValue( Master^.NA , NAG_Action , NAS_MoveAction );

	if ( Order = NAV_Stop ) or ( Order = NAV_Hover ) then begin
		Speedometer := 0;
	end else begin
		Speedometer := AdjustedMoveRate( Scene, Master , MM , Order );
	end;
end;

procedure GearUP( Mek: GearPtr );
	{ Set the mek's MoveMode attribute to the lowest }
	{ active movemode that this mek has. }
var
	T,MM: Integer;
begin
	MM := 0;
	for T := NumMoveMode downto 1 do begin
		if BaseMoveRate( Nil , Mek , T ) > 0 then MM := T;
	end;
	SetNAtt( Mek^.NA , NAG_Action , NAS_MoveMode , MM);
end;

function CPHMoveRate( Scene, Master: GearPtr ; MapScale: Integer ): Integer;
	{Determine the mecha's Clicks Per Hex movement rate.}
	{If this movemode is inactive, return a 0.}
	{Adjust it to deal with map scale.}
	{ *** NOTE: THIS PROCEDURE DOES NOT ADJUST FOR TERRAIN!!! *** }
var
	MoveMode,Spd,T,Order: Integer;
begin
	MoveMode := NAttValue( Master^.NA , NAG_Action , NAS_MoveMode );
	Order := NAttValue( Master^.NA , NAG_Action , NAS_MoveAction );
	Spd := AdjustedMoveRate( Scene, Master , MoveMode , Order );


	if Spd > 0 then begin
		{Convert from decihexes per round to clicks per hex.}
		Spd := ( ClicksPerRound * 10 ) div Spd;

		{As long as the mecha isn't turning, adjust time for scale.}
		if (Order <> NAV_TurnLeft) and (Order <> NAV_TurnRight) then begin
			if MapScale > Master^.Scale then begin
				for t := 1 to (MapScale - Master^.Scale) do begin
					spd := spd * 2;
				end;
			end else if MapScale < Master^.Scale then begin
				for t := 1 to (MapScale - Master^.Scale) do begin
					spd := spd div 2;
				end;
			end;
		end;

		if Spd < MinCPH then Spd := MinCPH;
	end;

	CPHMoveRate := Spd;
end;

Function JumpTime( Scene, Master: GearPtr ): Integer;
	{ Return the amount of time that this jumping mecha can stay }
	{ in the air. If the mecha is capable of true flight }
	{ return 0. If the mecha is not capable of either jumping or }
	{ flight, the return of this function is undefined, but just }
	{ between you and me it's gonna be 0. }
var
	it: Integer;
begin
	it := CalcFly( Scene , Master , Master^.S , False );

	{ Zoanoids and Arachnoids cannot fly, but they jump really well. }
	if ( Master^.G = GG_Mecha ) and (( Master^.S = GS_Zoanoid ) or ( Master^.S = GS_Arachnoid )) then begin
		it := ( it * 3 ) div 2;
	end else if it >= MinFlightSpeed then begin
		it := 0;
	end;

	JumpTime := ( it + 1 ) div 2;
end;

Function MoveLegal( Scene, Mek: GEarPtr; MoveMode,MoveAction: Integer; COmTime: LongInt ): Boolean;
	{ Return TRUE if the given action is legal for this mecha, }
	{ or FALSE if it isn't. }
var
	it: Boolean;
	CMA: Integer;
begin
	{ Assume TRUE unless this is one of the exceptions. }
	it := True;

	{ Find the current move action being used. }
	CMA := NAttValue( Mek^.NA , NAG_Action , NAS_MoveAction );

	{ Reverse movement is only possible if walking or rolling. }
	if MoveAction = NAV_Reverse then begin
		it := ( MoveMode = MM_Walk ) or ( MoveMode = MM_Roll );
	end else if MoveMode = MM_Fly then begin
		if ( JumpTime( Scene, Mek ) > 0 ) then begin
			{ Jumping meks are forbidden from turning while airborne. }
			if ( MoveAction = NAV_TurnLeft ) or ( MoveAction = NAV_TurnRight ) then begin
				if CMA <> NAV_Stop then it := false;
			end else if ( MoveAction = NAV_FullSpeed ) or ( MoveAction = NAV_Hover ) then begin
				it := False;
			end else if ( MoveAction = NAV_NormSpeed ) and ( CMA <> NAV_NormSpeed ) then begin
				it := NAttValue( Mek^.NA , NAG_Action , NAS_JumpRecharge ) < ComTime;
			end;

		end else if ( MoveAction = NAV_Stop ) or ( MoveAction = NAV_Hover ) then begin
			{ Flying mecha can only stop if they are }
			{ capable of skimming, or on an oversized map. }
			it := ( BaseMoveRate( Scene, Mek , MM_Skim ) > 0 ) or ( ( Scene <> Nil ) and ( Scene^.V > Mek^.Scale ) );
		end;
	end else if MoveAction = NAV_Hover then begin
		{ Only flying mecha are capable of hovering, and even those might not }
		{ be able to do it... }
		it := False;
	end;

	MoveLegal := it;
end;

Function MoveLegal( Scene, Mek: GEarPtr; MoveAction: Integer; COmTime: LongInt ): Boolean;
	{ Return TRUE if the specified action is legal for the specified }
	{ movemode, or FALSE if it isn't. }
var
	MoveMode: Integer;
begin
	MoveMode := NAttValue( Mek^.NA , NAG_Action , NAS_MoveMode );
	MoveLegal := MoveLegal( Scene, Mek , MoveMode , MoveAction , ComTime );
end;

Function HasAtLeastOneValidMovemode( Mek: GearPtr ): Boolean;
	{ Return TRUE if this mecha has some way of moving, or FALSE if it doesn't. }
var
	T: Integer;
	ItDoes: Boolean;
begin
	{ Assume FALSE, until we find a working movemode. }
	ItDoes := False;
	for t := 1 to NumMoveMode do begin
		if BaseMoveRate( Nil, Mek , T ) > 0 then ItDoes := True;
	end;
	HasAtLeastOneValidMovemode := ItDoes;
end;

Function MekCanEnterScene( Mek,Scene: GearPtr ): Boolean;
	{ Depending on what type of scene SCENE is, check to make sure that the }
	{ mecha in question has at least one valid movemode. }
const
	Env_Legal_Movemode: Array [1..Num_Environment_Types,1..NumMoveMode] of Boolean = (
		( True, True, True, True, False ),	{ Ground }
		( False, False, False, False, True ),	{ Space }
		( True, True, True, False, False )	{ Inside }
	);
var
	e_ident: String;
	E,T: Integer;
	CanMove: Boolean;
begin
	{ Start by determining this scene's environment type. }
	{ Initialize E to 1, which is the default value. }
	E := 1;
	if Scene <> Nil then begin
		e_ident := UpCase( SAttValue( Scene^.SA , 'TERRAIN' ) );
		for T := 1 to Num_Environment_Types do begin
			if e_ident = Environment_Idents[ t ] then E := T;
		end;
	end;

	{ Now that we have an environment, check to make sure this mecha can }
	{ function there. Assume FALSE until proven TRUE. }
	CanMove := False;
	for t := 1 to NumMoveMode do begin
		if Env_Legal_Movemode[ E , T ] then begin
			if BaseMoveRate( Scene , Mek , T ) > 0 then begin
				CanMove := True;
				Break;
			end;
		end;
	end;
	MekCanEnterScene := CanMove;
end;

end.
