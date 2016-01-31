unit effects;
	{ previosly attacker.pp }
	{ This unit handles attack, defense, and spells in GearHead. }
	{ Spells? What is this, a FRPG? Well, that's just how I usually }
	{ describe "special effects" such as healing, status changes, etc. }

	{ This unit does not concern itself with UI, so requesting }
	{ attacks and informing the user of their outcome }
	{ has to be done elsewhere. The EFFECTS_History variable }
	{ points to a list of SATTs describing the last processed }
	{ effect in full. It's up to the calling procedure to pass }
	{ this info on the user. }

	{ TARGET LISTS: A list of targets will be stored as a list of gears. The }
	{ actual gear being tageted will be stored as the parent. The number of }
	{ shots against this target will be stored as the V descriptor. }
	{ TARGET DESC }
	{   T^.Parent = Actual targeted gear }
	{   T^.V      = Number of shots against this target }
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

uses gears,locale;

const
	MOSMeasure = 5;	{ One Measure Of Success is gained for beating }
			{ the opponent's defense roll by this many points. }

	PenaltyPerDepth = 5;	{ Penalty for making called shots, per distance from root level. }
	PenaltyPerScale = 4;
	ClicksPerPenalty = 20;	{ For every 20dpr of a target's speed, there's a -1 modifier. }
	StopPenalty = 3;	{ Stopped mecha are easier to hit. }
	ImmobilePenalty = 15;	{ Broken down mecha are even easier. }

	StopBonus = 3;		{ It's easier to aim if you're standing still. }
	RunPenalty = 3;		{ It's harder to aim if you're traveling at full speed. }

	Parry_Bonus = 3;	{ Bonus to parrying an attack. }

	UnderwaterAttackPenalty = 3;	{ It's harder to aim if you're underwater. }

	Non_Weapon_MOS_Penalty = 2;	{ Non-weapons are less effective against armor. }
					{ This mostly applies to modules. }

	DodgeMeleePenalty = 5;		{ It's hard to dodge melee attacks; parry or block instead. }
					{ Note that this doesn't usually apply to thrown weapons. }

	FlyingPenalty = 3;	{ Penalty for firing at an airborne unit without AntiAir weapon. }
	HighGroundBonus = 1;	{ Bonus for firing at a target lower than self. }

	CritHitMinTar = 5;	{ Minimum target number for Spot Weakness rolls. }
	LongRangePenalty = 3;
	ShortRangeBonus = 2;

	Has_Minimum_Range = 6;	{ Weapons with a range greater than this have a minimum useful range. }
			{ Attacks against targets within this minimum range happen at a penalty. }

	{ Animation directions are stored in the history list. }
	{ An animation direction may require some additional information, }
	{ as detailed below. }
	SAtt_Anim_Direction = 'ANIM_';
	
	GS_Shot = 1;		{ X1 Y1 Z1  X2 Y2 Z2 }
	GS_DamagingHit = 2;	{ X Y Z }
	GS_ArmorDefHit = 3;	{ X Y Z }
	GS_Parry = 4;		{ X Y Z }
	GS_Dodge = 5;		{ X Y Z }
	GS_Backlash = 6;	{ X Y Z }
	GS_AreaAttack = 7;	{ X Y Z }
	GS_ECMDef = 8;		{ X Y Z }
	GS_Block = 9;		{ X Y Z }
	GS_Intercept = 10;	{ X Y Z }
	GS_Resist = 11;		{ X Y Z }

	{ Maximum length of line when adding list of destroyed parts. }
	Damage_List_Text_Length = 170;

	FX_CauseDamage = 'DAMAGE';
		{ Param 1 = Attack Skill }
		{ Param 2 = Attack Stat }
		{ Param 3 = Critical Hit Skill }
		{ Param 4 = Critical Hit Stat }
	FX_CauseStatusEffect = 'STATUS';
		{ Param 1 = Status Number }
	FX_RemoveStatusEffect = 'CURE';
		{ Param 1 = Status Number }
	FX_OVERLOAD = 'OVERLOAD';
	FX_HEALING = 'HEALING';
		{ PARAM 1 = Healing Type }
	FX_CreateSTC = 'CREATESTC';
		{ PARAM 1 = STC item designation }

	FX_CanDodge = 'CANDODGE';
	FX_CanParry = 'CANPARRY';
	FX_CanBlock = 'CANBLOCK';
	FX_CanResist = 'CANRESIST';
	FX_CanECM = 'CANECM';
	FX_CanIntercept = 'CANINTERCEPT';

	AtOp_NonLethal = -1;


var
	ATTACK_History: SAttPtr;
	CTM_Modifiers: String;	{ Records all the modifiers, for the roll history. }


Function ReadyToFire( GB: GameBoardPtr; User,Weapon: GearPtr ): Boolean;
Function FindQuickFireWeapon( GB: GameBoardPtr; Master: GearPtr ): GearPtr;
Function BasicDefenseValue( Target: GearPtr ): Integer;


Function WeaponArcCheck( GB: GameBoardPtr; Master , Weapon: GearPtr; X,Y: Integer ): Boolean;
Function WeaponArcCheck( GB: GameBoardPtr; Master , Weapon , Target: GearPtr ): Boolean;
Function RangeArcCheck( GB: GameBoardPtr; Master , Weapon: GearPtr; X,Y,Z: Integer ): Boolean;
Function RangeArcCheck( GB: GameBoardPtr; Master , Weapon , Target: GearPtr ): Boolean;
Function BlastRadius( GB: GameBoardPtr; Attacker: GearPtr; AList: String ): Integer;

Function AttackSkillNeeded( Attacker: GearPtr ): Integer;
Function AttackStatNeeded( Attacker: GearPtr ): Integer;
Function Firing_Weight( Weapon: GearPtr; AtOp: Integer ): Integer;
Function Firing_Weight_Limit( User: GearPtr ): Integer;
Function CalcTotalModifiers( gb: GameBoardPtr; Attacker,Target: GearPtr; AtOp: Integer; AtAt: String ): Integer;

Procedure DestroyTerrain( GB: GameBoardPtr; X,Y: Integer );

Procedure Explosion( GB: GameBoardPtr; X0,Y0,DC,R: Integer );

Procedure DoAttack( GB: GameBoardPtr; Attacker,Target: GearPtr; X,Y,Z,AtOp: Integer);
Procedure DoCharge( GB: GameBoardPtr; Attacker,Target: GearPtr );
Procedure DoReactorExplosion( GB: GameBoardPtr; Victim: GearPtr );

Procedure HandleEffectString( GB: GameBoardPtr; Target: GearPtr; FX_String,FX_Desc: String );
Procedure MassEffectString( GB: GameBoardPtr; FX_String,FX_Desc: String );


implementation

uses ability,action,gearutil,ghchars,ghmodule,ghguard,gearparser,ui4gh,
     ghprop,ghsensor,ghsupport,ghweapon,movement,rpgdice,skilluse,texutil,
	ghholder,ghmecha,ghmovers;

Type
	EffectRequest = Record
		AttackName,AttackMessage: String;	{ The description string for this attack's }
							{ CauseDamage effect. }
		Originator,Weapon: GearPtr;
		FXList: SAttPtr;
		FXDice,FXMod: Integer;
	end;

	DefenseReport = Record
		HiRoll: Integer;	{ The highest defense roll rolled. }
		HiRollType: Integer;	{ The type of roll. GS_Parry, GS_Dodge... }
	end;

	MapStencil = Array [1..MaxMapWidth,1..MaxMapWidth] of Boolean;

var
	EFFECTS_Event_Order: Integer;

	FX_Current_Message: String;

Procedure StartNewAnnouncement;
	{ Store the current line, then start a new one. }
begin
	AddSAtt( ATTACK_History , 'ANNOUNCE_' + BStr( EFFECTS_Event_Order ) + '_' , FX_Current_Message );
	FX_Current_Message := '';
end;


Procedure RecordAnnouncement( msg: String );
	{ Record an announcememnt in the history list. }
begin
	if Length( FX_Current_Message ) + Length( msg ) < 250 then begin
		FX_Current_Message := FX_Current_Message + ' ' + msg;
	end else begin
		StartNewAnnouncement;
		FX_Current_Message := msg;
	end;
end;

Procedure FlushAnnouncements;
	{ Make sure there are no announcements left in the queue. }
begin
	StartNewAnnouncement;
end;


Procedure Add_Shot_Precisely( GB: GameBoardPtr; X0,Y0,Z0,X1,Y1,Z1: Integer );
	{ Add a shot animation to the history list. }
var
	msg: String;
begin
	msg := BStr( GS_Shot ) + ' ' + BStr( X0 ) + ' ' + BStr( Y0 ) + ' ' + BStr( Z0 );
	msg := msg + ' ' + BStr( X1 ) + ' ' + BStr( Y1 ) + ' ' + BStr( Z1 );

	AddSAtt( ATTACK_History , SAtt_Anim_Direction + BStr( EFFECTS_Event_Order ) + '_' , msg );
end;

Procedure Add_Shot_Animation( GB: GameBoardPtr; Attacker , Target: GearPtr );
	{ Add a shot animation to the history list. }
var
	P0,P1: Point;
begin
	Attacker := FindRoot( Attacker );
	Target := FindRoot( Target );

	P0 := GearCurrentLocation( Attacker );
	P0.Z := MekAltitude( GB , FindRoot( Attacker ) );

	P1 := GearCurrentLocation( Target );
	P1.Z := MekAltitude( GB , FindRoot( Target ) );

	Add_Shot_Precisely( GB , P0.X , P0.Y , P0.Z , P1.X , P1.Y , P1.Z );
end;

Procedure Add_Point_Animation( X,Y,Z: Integer; CMD: Integer );
	{ Add a shot animation to the history list. }
var
	msg: String;
begin
	msg := BStr( cmd ) + ' ' + BStr( X ) + ' ' + BStr( Y ) + ' ' + BStr( Z );

	AddSAtt( ATTACK_History , SAtt_Anim_Direction + BStr( EFFECTS_Event_Order ) + '_' , msg );
end;

Procedure Add_Mek_Animation( GB: GameBoardPtr; Target: GearPtr; CMD: Integer );
	{ Add a shot animation to the history list. }
var
	P: Point;
begin
	{ Only add animations for visible mecha. }
	if not MekVisible( GB , Target ) then Exit;

	{ Find the location of the target, and just pass that on to }
	{ the point animation procedure above. }
	Target := FindRoot( Target );
	P := GearCurrentLocation( Target );
	Add_Point_Animation( P.X , P.Y , MekAltitude( GB , Target ) , CMD );
end;


Procedure ClearAttackHistory;
	{ Get rid of any history variables leftover from previous attacks. }
begin
	DisposeSAtt( ATTACK_History );
	EFFECTS_Event_Order := 0;
	FX_Current_Message := '';
end;

Procedure ClearStencil( var Stencil: MapStencil );
	{ Set all the tiles in the map stencil to FALSE. }
var
	X,Y: Integer;
begin
	for X := 1 to MaxMapWidth do for Y := 1 to MaxMapWidth do Stencil[ X , Y ] := False;
end;

Function InGeneralInventory( Part: GearPtr ): Boolean;
	{ If in the general inventory, it may be thrown. }
begin
	InGeneralInventory := IsInvCom( Part ) and ( Part^.Parent = FindMaster( Part ) );
end;

Function MustBeThrown( GB: GameBoardPtr; Master, Weapon: GearPtr; TX,TY: Integer ): Boolean;
	{ Return TRUE if WEAPON must be thrown in order to hit TARGET. }
	{ Return FALSE if WEAPON could be used normally, i.e. not thrown. }
	{ A weapon will only be thrown if it could not be used against }
	{ the target otherwise- this is because throwing a weapon is a }
	{ pain in the arse. You've got to go pick it up afterwards. }
begin
	if Weapon^.G = GG_Ammo then begin
		{ If you're attacking with ammo, that better be a grenade. }
		MustBeThrown := True;
	end else if InGeneralInventory( Weapon ) then begin
		{ If this weapon is in the general inventory, it must }
		{ have been thrown. }
		MustBeThrown := True;
	end else begin
		{ If the attack range is greater than the regular weapon }
		{ range, then the weapon must have been thrown. }
		MustBeThrown := ( ThrowingRange( GB , Master , Weapon ) > 0 ) and OnTheMap( GB , TX , TY ) and ( Range( Master , TX , TY ) > WeaponRange( GB , Weapon , RANGE_Long ) );
	end;
end;

Function ReadyToFire( GB: GameBoardPtr; User,Weapon: GearPtr ): Boolean;
	{ Return TRUE if the gear in question is ready to perform an attack, }
	{ or FALSE if it is currently unable to do so. }
	{ Check to make sure that... }
	{     1) ATTACKER is a functional part. }
	{     2) ATTACKER is a part that can be used in attack. }
	{     3) ATTACKER has sufficient ammunition to attack. }
	{     4) COMTIME is greater or equal to the RECHARGE time. }
	{     5) ATTACKER is mounted in a usable limb. }
	{     6) ATTACKER's MASTER is the same as ATTACKER's ROOT. }
var
	AttackOK: Boolean;
begin
	{ In order to be used, a weapon must be active and in a good module and }
	{ not have its safety switch on. }
	{ This first check will return false if Weapon is nil, so I won't check here. }
	{ Throwable weapons don't have to be in a good module- they can }
	{ be in the general inventory. }
	if ( Weapon <> Nil ) and ( User <> Nil ) and ( ThrowingRange( GB, USer, Weapon ) > 0 ) then begin
		AttackOK := PartActive( Weapon ) and ( NAttValue( Weapon^.NA , NAG_WeaponModifier , NAS_SafetySwitch ) = 0 );
	end else begin
		AttackOK := PartActive( Weapon ) and InGoodModule( Weapon ) and ( NAttValue( Weapon^.NA , NAG_WeaponModifier , NAS_SafetySwitch ) = 0 );
	end;

	if AttackOK then begin
		{ Applicability Check }
		if ( Weapon^.G = GG_Weapon ) then begin
			{ Normally, all weapons may be used to attack. Duh. }
			{ However, ballistic and missile weapons can't attack }
			{ if they have no ammo left. }
			if ( Weapon^.S = GS_Ballistic ) or ( Weapon^.S = GS_Missile ) then begin
				if LocateGoodAmmo( Weapon ) = Nil then AttackOK := False;

			{ Likewise, energy and beam weapons can't be used without power. }
			{ Mecha can fire energy weapons using reserve power, with the }
			{ problem that they'll become overloaded and maybe shut down. }
			end else if ( ( Weapon^.S = GS_BeamGun ) or ( Weapon^.S = GS_EMelee ) ) and ( User <> Nil ) then begin
				if ( EnergyPoints( User ) < EnergyCost( Weapon ) ) and ( User^.G <> GG_Mecha ) then AttackOK := False;
			end;

		end else if Weapon^.G = GG_Module then begin
			{ Only Arms, Legs, and Tails may be used. }
			if ( Weapon^.S <> GS_Arm ) and ( Weapon^.S <> GS_Leg ) and ( Weapon^.S <> GS_Tail ) then begin
				AttackOK := False;
			end;

		end else if Weapon^.G = GG_Ammo then begin
			if Weapon^.S <> GS_Grenade then AttackOK := False;
			if not InGeneralInventory( Weapon ) then AttackOK := False;

		end else begin
			{ No other parts may be used to attack. So, }
			{ set AttackOK to False. }
			AttackOK := False;

		end;

		{ ComTime Check }
		if NAttValue( Weapon^.NA , NAG_WeaponModifier , NAS_Recharge ) > GB^.ComTime then AttackOK := False;

		{ If yer piloting a mecha can't punch the other guy yourself Check }
		if FindMaster( Weapon ) <> FindRoot( Weapon ) then AttackOK := False;
	end;

	ReadyToFire := AttackOK;
end;

Function FindQuickFireWeapon( GB: GameBoardPtr; Master: GearPtr ): GearPtr;
	{ QUICKFIRE: Helper function }
	{ Finds the first weapon on Master whose QUICKFIRE NAtt is 1. }
		{ Master: The master gear to seek the QuickFire weapon of. }
	{ Returns a reference to the QuickFire weapon on success, or Nil otherwise. }
var
	FoundWpn: GearPtr;
	MaxQF: Integer;
{ PROCEDURES BLOCK }
	Procedure CheckAlongPath( Part: GearPtr );
		{ Check along the path specified for a QUICKFIRE weapon. }
	begin
		while ( Part <> Nil ) do begin
			{ To avoid affecting QuickFire settings of characters in mecha }
			if ( Part^.G <> GG_Cockpit ) then begin
				if ( Part^.G = GG_Weapon ) and ( NAttValue( Part^.NA, NAG_WeaponModifier, NAS_QuickFire ) > MaxQF ) and ReadyToFire( GB , Master , Part ) then begin
					{ Found one! }
					FoundWpn := Part;
					MaxQF := NAttValue( Part^.NA, NAG_WeaponModifier, NAS_QuickFire );
				end else begin
					CheckAlongPath( Part^.SubCom );
					CheckAlongPath( Part^.InvCom );
				end;
			end;
			Part := Part^.Next;
		end;
	end;
begin
	FoundWpn := Nil;
	MaxQF := -1;
	
	CheckAlongPath( Master^.SubCom );
	CheckAlongPath( Master^.InvCom );
	
	FindQuickFireWeapon := FoundWpn;
end;

Function WeaponArcCheck( GB: GameBoardPtr; Master , Weapon: GearPtr; X,Y: Integer ): Boolean;
	{ Return TRUE if the target is in an appropriate fire arc for }
	{ WEAPON, or FALSE otherwise. }
var
	X0 , Y0 , D: Integer;	{ Position of the firer. }
	A: Integer;	{ Range and Arc of the attack. }
begin
	if ( Master = Nil ) or ( Weapon = Nil ) then Exit( False );

	if Master^.Parent <> Nil then Master := FindRoot( Master );

	X0 := NAttValue( Master^.NA , NAG_Location , NAS_X );
	Y0 := NAttValue( Master^.NA , NAG_Location , NAS_Y );

	D := NAttValue( Master^.NA , NAG_Location , NAS_D );
	A := WeaponArc( Weapon );

	{ Now check Range and Arc. }
	WeaponArcCheck := ArcCheck( X0 , Y0 , D , X , Y , A );
end;

Function WeaponArcCheck( GB: GameBoardPtr; Master , Weapon , Target: GearPtr ): Boolean;
	{ Return TRUE if the target is in an appropriate fire arc for }
	{ WEAPON, or FALSE otherwise. }
var
	X0 , Y0 , D , X , Y: Integer;	{ Position of the firer. }
	A: Integer;	{ Range and Arc of the attack. }
begin
	if ( Target = Nil ) or ( Master = Nil ) or ( Weapon = Nil ) then Exit( False );

	if Target^.Parent <> Nil then Target := FindRoot( Target );
	if Master^.Parent <> Nil then Master := FindRoot( Master );

	X := NAttValue( Target^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Target^.NA , NAG_Location , NAS_Y );
	X0 := NAttValue( Master^.NA , NAG_Location , NAS_X );
	Y0 := NAttValue( Master^.NA , NAG_Location , NAS_Y );

	D := NAttValue( Master^.NA , NAG_Location , NAS_D );
	A := WeaponArc( Weapon );

	{ Now check Range and Arc. }
	WeaponArcCheck := ArcCheck( X0 , Y0 , D , X , Y , A );
end;

Function RangeArcCheck( GB: GameBoardPtr; Master , Weapon: GearPtr; X,Y,Z: Integer ): Boolean;
	{ Check the range, arc, and cover between the listed gear and the listed tile. }
	{ Returns true if the shot can take place, false otherwise. }
var
	X0,Y0,D,A: Integer;
	rng: Integer;	{ Range and Arc of the attack. }
	OK: Boolean;
begin
	{ Calculate Range and Arc. }
	rng := WeaponRange( GB , Weapon , RANGE_Long );

	X0 := NAttValue( Master^.NA , NAG_Location , NAS_X );
	Y0 := NAttValue( Master^.NA , NAG_Location , NAS_Y );
	D := NAttValue( Master^.NA , NAG_Location , NAS_D );
	A := WeaponArc( Weapon );

	OK := ArcCheck( X0 , Y0 , D , X , Y , A );

	{ If out of range, no shot is possible. }
	if OK and ( Range( Master , X , Y ) > rng ) then begin
		{ OK is false, unless the target is within throwing range. }
		OK := ThrowingRange( GB , Master , Weapon ) >= Range( Master , X , Y );
	end;

	{ If Line of Sight is blocked, no shot is possible. }
	if OK and ( CalcObscurement( X0 , Y0 , MekALtitude( GB , Master ) , X , Y , Z , gb ) = -1 ) then OK := False;

	RangeArcCheck := OK;
end;

Function RangeArcCheck( GB: GameBoardPtr; Master , Weapon , Target: GearPtr ): Boolean;
	{ Check the range, arc, and cover between the listed gear and the listed tile. }
	{ Returns true if the shot can take place, false otherwise. }
var
	X , Y: Integer;	{ Position of the firer. }
begin
	{ Determine initial values for all the stuff. }
	if Target = Nil then Exit( False );
	if Target^.Parent <> Nil then Target := FindRoot( Target );
	X := NAttValue( Target^.NA , NAG_Location , NAS_X );
	Y := NAttValue( Target^.NA , NAG_Location , NAS_Y );

	RangeArcCheck := RangeArcCheck( GB , Master , Weapon , X , Y , MekALtitude( GB , Target ) );
end;

Function BlastRadius( GB: GameBoardPtr; Attacker: GearPtr; AList: String ): Integer;
	{ Return the blast radius of this weapon. }
var
	AA: String;
	R,T: Integer;
begin
	if not HasAttackAttribute( AList , AA_BlastAttack ) then Exit( 0 );

	{ Initialize radius to 0. }
	R := 0;

	{ Move through the string looking for the BLAST attribute. }
	{ The radius should be right after it. }
	while ( AList <> '' ) and ( R = 0 ) do begin
		AA := UpCase( ExtractWord( AList ) );
		if AA = AA_Name[ AA_BlastAttack ] then R := ExtractValue( AList );
	end;

	if Attacker^.Scale > GB^.Scale then begin
		for t := 1 to ( Attacker^.Scale - GB^.Scale ) do r := r * 2;
	end else begin
		{ The weapon scale must be smaller then the }
		{ game board scale. }
		for t := 1 to ( GB^.Scale - Attacker^.Scale ) do r := r div 2;
	end;


	{ Error check on the blast radius's range. }
	if R < 1 then R := 1
	else if R > Max_Blast_Rating then R := Max_Blast_Rating;

	{ Return the result. }
	BlastRadius := R;
end;

Function RechargeTime( Attacker: GearPtr; AtOp: Integer ): Integer;
	{ Return the modified recharge time for this weapon. }
var
	WAO: GearPtr;
	it: Integer;
begin
	if Attacker^.G = GG_Weapon then begin
		it := Attacker^.Stat[STAT_Recharge];
	end else begin
		it := 2;
	end;

	{ Modify for weapon token. }
	WAO := Attacker^.InvCom;
	while WAO <> Nil do begin
		if ( WAO^.G = GG_WeaponAddOn ) and NotDestroyed( WAO ) then begin
			it := it + WAO^.Stat[ STAT_Recharge ];
		end;
		WAO := WAO^.Next;
	end;

	if ( Attacker^.G = GG_Weapon ) and ( Attacker^.S = GS_BeamGun ) and ( AtOp > 0 ) then begin
		{ Beamguns which use rapid fire take MUCH longer to recharge than normal. }
		RechargeTime := 2 * ClicksPerRound div it;
	end else begin
		RechargeTime := ClicksPerRound div it;
	end;
end;

Function ClearAttack( GB: GameBoardPtr; Attacker: GearPtr ; var AtOp: Integer ): Boolean;
	{ This function sets up the weapon for performing an attack. }
	{ It reduces ammo count by an appropriate amount. }
	{ It sets the RECHARGE attribute. }
	{ Return TRUE if everything is okay, FALSE if there's some reason }
	{ why this attack can't take place. }
	{ Note that this function does not do a range check. }
var
	AttackOK: Boolean;
	Ammo: GearPtr;
begin
	{ First, make sure that this attack can even take place. }
	{ Check to make sure that ATTACKER is active. }
	AttackOK := ReadyToFire( GB , FindRoot( Attacker ) , Attacker );

	{ If AtOp is less that 0 (thereby requesting a special attack), set it to zero }
	{ so as to not confuse anyone. }
	if AtOp < 0 then AtOp := 0;

	if AttackOK and ( Attacker^.G = GG_Weapon ) then begin

		{ Do an ammunition check for projectile weapons and missiles. }
		if ( Attacker^.S = GS_Missile ) or ( Attacker^.S = GS_Ballistic ) then begin
			{ Locate the ammo to be used. }
			Ammo := LocateGoodAmmo( Attacker );

			if Ammo <> Nil then begin
				{ Reduce the ammo count by an appropriate amount. }

				{ AtOp is the number of missiles being fired. }
				{ If this goes over the number of missiles present, correct that problem. }
				if ( AtOp > 0 ) then begin
					if ( Ammo^.Stat[STAT_AmmoPresent] - NAttValue( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent ) ) < (AtOp + 1) then begin
						AtOp := ( Ammo^.Stat[STAT_AmmoPresent] - NAttValue( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent ) ) - 1;
					end;
				end;

				{ Do the actual ammo count thing here. }
				AddNAtt( Ammo^.NA , NAG_WeaponModifier , NAS_AmmoSpent , AtOp + 1 );

			end else begin
				{ This weapon has no ammo. The attack cannot proceed. }
				AttackOK := False;

			end;
		end;

	end else if Attacker^.G = GG_Ammo then begin
		{ Grenades don't get a choice what AtOp they use. }
		AtOp := Attacker^.Stat[ STAT_BurstValue ];
	end;

	{ Set the recharge time now. }
	if AttackOK then begin
		SetNAtt( Attacker^.NA , NAG_WeaponModifier , NAS_Recharge , GB^.ComTime + RechargeTime( Attacker , AtOp ) );
	end;

	ClearAttack := AttackOK;
end;

Function AttackSkillNeeded( Attacker: GearPtr ): Integer;
	{ Return the index number of the skill used to attack with this }
	{ particular weapon. }
var
	ASkill: Integer;
	AMaster: GearPtr;
begin
	{ The skills for human-scale and mecha-scale are set up in }
	{ the same order, with the mecha skills being 1 to 3 and the }
	{ personal skills being 4 to 6. So, just find the skill number }
	{ based on ATTACKER's type, then add +3 if the master is a }
	{ character instead of a mecha. }


	if Attacker^.G = GG_Weapon then begin
		if ( Attacker^.S = GS_Melee ) or ( Attacker^.S = GS_EMelee ) then begin
			{ Use armed combat/weapons skill. }
			ASkill := NAS_MechaFighting;
		end else begin
			ASkill := NAS_MechaGunnery;
		end;

	end else if Attacker^.G = GG_Ammo then begin
		ASkill := NAS_MechaGunnery;

	end else begin
		{ Not a weapon- use Fighting/Martial Arts. }
		ASkill := NAS_MechaFighting;
	end;

	{ If the master isn't a mecha, add +5 to the skill index. }
	AMaster := FindMaster( Attacker );
	if ( AMaster <> Nil ) and ( AMaster^.G <> GG_Mecha ) then begin
		ASkill := ASkill + 3;
	end;

	{ Return the value we found. }
	AttackSkillNeeded := ASkill;
end;

Function AttackStatNeeded( Attacker: GearPtr ): Integer;
	{ Return the stat needed for this attack. }
var
	AtStat: Integer;
begin
	if ( Attacker^.G = GG_Weapon ) or ( Attacker^.G = GG_Ammo ) then begin
		{ Weapons have their attack stat stored. }
		AtStat := Attacker^.Stat[ STAT_AttackStat ];
	end else begin
		{ Not a weapon- use Body. }
		AtStat := STAT_Body;
	end;

	{ Return the value we found. }
	AttackStatNeeded := AtStat;
end;

Function AttemptShieldBlock(GB: GameBoardPtr; TMaster , Attacker: GearPtr; SkRoll: Integer ): Integer;
	{ Attempt to block an attack using a shield. Return the defense }
	{ roll result, or 0 if no shield could be found. }
var
	DefGear: GearPtr;
	DefSkill,DefRoll: Integer;

	Procedure SeekShield( Part: GearPtr );
		{ Seek a shield which is capable of parrying an attack. }
	begin
		while ( Part <> Nil ) do begin
			if NotDestroyed( Part ) then begin
				if ( Part^.G = GG_Shield ) and InGoodModule( Part ) then begin
					if ( NAttValue( Part^.NA , NAG_WeaponModifier , NAS_Recharge ) <= GB^.ComTime ) and ( ( Attacker = Nil ) or ( Part^.Scale >= Attacker^.Scale ) ) then begin
						if DefGear = Nil then DefGear := Part;
					end;
				end;
				if ( Part^.SubCom <> Nil ) then SeekShield( Part^.SubCom );
				if ( Part^.InvCom <> Nil ) then SeekShield( Part^.InvCom );
			end;
			Part := Part^.Next;
		end;
	end;
begin
	{ Try to find a shield. }
	DefGear := Nil;
	DefRoll := 0;
	SeekShield( TMaster^.SubCom );

	{ If a shield is found, proceed with the defense roll... }
	if DefGear <> Nil then begin
		{ Find the appropriate skill value. }
		if TMaster^.G = GG_Mecha then begin
			{ For mecha, this will be Mecha Fighting }
			DefSkill := NAS_MechaFighting;
		end else begin
			{ For characters, this will be Armed Combat }
			DefSkill := NAS_CloseCombat;
		end;

		{ Set the recharge time for the shield. }
		SetNAtt( DefGear^.NA , NAG_WeaponModifier , NAS_Recharge , GB^.ComTime + ( ClicksPerRound div 3 ) );

		{ Give some skill-specific experience points. }
		DoleSkillExperience( TMaster , DefSkill , XPA_SK_Basic );

		{ Make the skill roll + Shield Bonus }
		SkillComment( GearName( TMaster ) + ' to block with ' + GearName( DefGear ) + ' [' + SgnStr( DefGear^.Stat[ STAT_ShieldBonus ] ) + ']' );

		DefRoll := SkillRoll( GB , TMaster , DefSkill , STAT_Speed , SkRoll , DefGear^.Stat[ STAT_ShieldBonus ] , False , True );

		{ If the parry was successful, there will be some after-effects. }
		if DefRoll >= SkRoll then begin
			{ The shield is going to take damage from the hit, whether it was an }
			{ energy shield or a beam shield- but beam shields only take damage }
			{ from energy weapons. }
			if ATtacker <> Nil then begin
				if DefGear^.S = GS_EnergyShield then begin
					if CanDamageBeamShield( Attacker ) then begin
						DamageGear( GB , DefGear , Attacker , Attacker^.V , 0 , 1 , '' );
					end;
				end else begin
					{ Physical shields take damage from everything. }
					DamageGear( GB , DefGear , Attacker , Attacker^.V , 0 , 1 , '' );
				end;

				{ An energy shield will do damage back to any CC weapon that hits it. }
				if ( DefGear^.S = GS_EnergyShield ) then begin
					if ( Attacker^.G = GG_Module ) or ( Attacker^.S = GS_Melee ) then begin
						{ Indicate the attacker damage here. }
						Add_Mek_Animation( GB , FindRoot( Attacker ) , GS_Backlash );
						DamageGear( GB , Attacker , DefGear , DefGear^.V , 0 , 1 , '' );
					end;
				end;
			end;

		end;
	end;

	AttemptShieldBlock := DefRoll;
end;

Function AttemptParry(GB: GameBoardPtr; TMaster , Attacker: GearPtr; SkRoll: Integer ): Integer;
	{ Try to parry this attack, if it is in fact parryable. }
var
	DefGear: GearPtr;
	DefSkill,DefRoll: Integer;
	Procedure SeekParryWeapon( Part: GearPtr );
		{ Seek a weapon which is capable of parrying an attack. }
	begin
		while ( Part <> Nil ) do begin
			if ( Part^.G = GG_Weapon ) and (( Part^.S = GS_Melee ) or ( Part^.S = GS_EMelee )) then begin
				if ReadyToFire( GB , TMaster , Part ) and InGoodModule( Part ) and ( ( Attacker = Nil ) or ( Part^.Scale >= Attacker^.Scale ) ) then begin
					if DefGear = Nil then DefGear := Part
					else if Part^.Stat[STAT_Accuracy] > DefGear^.Stat[STAT_Accuracy] then DefGear := Part;
				end;
			end;
			if ( Part^.SubCom <> Nil ) then SeekParryWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekParryWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;

begin
	DefRoll := 0;

	{ Search for a usable CC weapon. }
	DefGear := Nil;
	SeekParryWeapon( TMaster^.SubCom );

	{ If one was found, do the parry attempt. }
	if DefGear <> Nil then begin
		{ Make an attack roll to parry. }
		DefSkill := AttackSkillNeeded( DefGear );

		SkillComment( GearName( TMaster ) + ' to parry with ' + GearName( DefGear ) + ' [' + SgnStr( DefGear^.Stat[ STAT_Accuracy ] ) + ']' );
		DefRoll := SkillRoll( GB , TMaster , DefSkill , STAT_Speed , SkRoll , Parry_Bonus + DefGear^.Stat[ STAT_Accuracy ] , False , True );

		{ Give some skill-specific experience points. }
		DoleSkillExperience( TMaster , DefSkill , XPA_SK_Basic );

		{ If the parry was successful, there will be some after-effects. }
		if DefRoll >= SkRoll then begin
			{ After a succeful parry, weapon is "tapped". }
			DefSkill := 0;
			ClearAttack( GB , DefGear , DefSkill );

			{ If the parrying weapon is not an energy weapon, }
			{ it will take damage from the parrying attempt. }
			if Attacker <> Nil then begin
				if ( DefGear^.S <> GS_EMelee ) then begin
					if ( Attacker^.G = GG_Weapon ) and ( Attacker^.S = GS_EMelee ) then begin
						DamageGear( GB , DefGear , Attacker , Attacker^.V , 0 , 1 , '' );
					end else begin
						DamageGear( GB , DefGear , Attacker , 1 , 0 , 1 , '' );
					end;

				{ If the parrying weapon is an energy weapon, then }
				{ the attacker's weapon is going to take damage unless }
				{ it too is an energy weapon. }
				end else if ( Attacker^.G <> GG_Weapon ) or ( Attacker^.S <> GS_Emelee ) then begin
					Add_Mek_Animation( GB , FindRoot( Attacker ) , GS_Backlash );
					DamageGear( GB , Attacker , DefGear , DefGear^.V , 0 , 1 , '' );
				end;
			end;
		end;
	end;

	{ Return the resultant defense roll. }
	AttemptParry := DefRoll;
end;

Function AttemptIntercept(GB: GameBoardPtr; TMaster , Attacker: GearPtr; SkRoll: Integer ): Integer;
	{ Try to intercept this attack. }
var
	DefGear: GearPtr;
	DefSkill,DefRoll: Integer;
	Procedure SeekInterceptWeapon( Part: GearPtr );
		{ Seek a weapon which is capable of intercepting an attack. }
	begin
		while ( Part <> Nil ) do begin
			if ( Part^.G = GG_Weapon ) and HasAttackAttribute( WeaponAttackAttributes( Part ) , AA_Intercept ) then begin
				if ReadyToFire( GB , TMaster , Part ) and InGoodModule( Part ) and ( ( Attacker = Nil ) or ( Part^.Scale >= Attacker^.Scale ) ) then begin
					if DefGear = Nil then DefGear := Part
					else if Part^.Stat[STAT_Accuracy] > DefGear^.Stat[STAT_Accuracy] then DefGear := Part;
				end;
			end;
			if ( Part^.SubCom <> Nil ) then SeekInterceptWeapon( Part^.SubCom );
			if ( Part^.InvCom <> Nil ) then SeekInterceptWeapon( Part^.InvCom );
			Part := Part^.Next;
		end;
	end;

begin
	DefRoll := 0;

	{ Search for a usable CC weapon. }
	DefGear := Nil;
	SeekInterceptWeapon( TMaster^.SubCom );

	{ If one was found, do the parry attempt. }
	if DefGear <> Nil then begin
		{ Make an attack roll to parry. }
		DefSkill := AttackSkillNeeded( DefGear );

		SkillComment( GearName( TMaster ) + ' to intercept with ' + GearName( DefGear ) + ' [' + SgnStr( DefGear^.Stat[ STAT_Accuracy ] + DefGear^.Stat[ STAT_BurstValue ] ) + ']' );
		DefRoll := SkillRoll( GB , TMaster , DefSkill, STAT_Speed , SkRoll , DefGear^.V + DefGear^.Stat[ STAT_Accuracy ] + DefGear^.Stat[ STAT_BurstValue ] , False , True );

		{ Give some skill-specific experience points. }
		DoleSkillExperience( TMaster , DefSkill , XPA_SK_Basic );

		{ If the parry was successful, there will be some after-effects. }
		if DefRoll >= SkRoll then begin
			{ After a succeful parry, weapon is "tapped". }
			ClearAttack( GB , DefGear , DefSkill );
		end;
	end;

	{ Return the resultant defense roll. }
	AttemptIntercept := DefRoll;
end;

Function AttemptEWBlock(GB: GameBoardPtr; TMaster , Attacker: GearPtr; SkRoll: Integer ): Integer;
	{ Try to stop this attack using Electronic Counter-Measures. }
var
	DefGear: GearPtr;
	DefRoll: Integer;
begin
	DefRoll := 0;

	{ Search for a usable CC weapon. }
	DefGear := SeekActiveIntrinsic( TMaster , GG_Sensor , GS_ECM );

	{ If one was found, do the parry attempt. }
	if DefGear <> Nil then begin
		{ Make an attack roll to block. }
		SkillComment( GearName( TMaster ) + ' to ECM with ' + GearName( DefGear ) + ' [' + SgnStr( DefGear^.V ) + ']' );
		DefRoll := SkillRoll( GB , TMaster , NAS_ElectronicWarfare , STAT_Craft , SkRoll , DefGear^.V - 5 , False , True );

		{ Give some skill-specific experience points. }
		DoleSkillExperience( TMaster , 17 , XPA_SK_Basic );
	end;

	{ Return the resultant defense roll. }
	AttemptEWBlock := DefRoll;
end;

Function AttemptResist( GB: GameBoardPtr; TMaster: GearPtr; SkRoll: Integer ): Integer;
	{ Attempt to resist damage using either the RESISTANCE or }
	{ ELECTRONIC WARFARE skills, depending upon whether the target }
	{ is a character or a mecha. }
var
	RSkill: Integer;
begin
	if TMaster^.G = GG_MEcha then begin
		{ Mecha use ELECTRONIC WARFARE. }
		RSkill := NAS_ElectronicWarfare;
	end else begin
		{ Characters use RESISTANCE. }
		RSkill := NAS_Toughness;
	end;

	{ Return the resultant defense roll. }
	DoleSkillExperience( TMaster , RSkill , XPA_SK_Basic );

	AttemptResist := SkillRoll( GB , TMaster , RSkill , STAT_Ego , SkRoll , 0 , False , True );
end;

Function AttemptDodge( GB: GameBoardPtr; TMaster,Attacker: GearPtr; SkRoll: Integer; const FX: String ): Integer;
	{ TMaster will attempt to dodge. }
var
	DodgeSkill,DodgeStat,SkMod: Integer;
begin
	SkMod := 0;
	if TMaster^.G = GG_MEcha then begin
		{ Mecha use Mecha Piloting. }
		DodgeSkill := NAS_MechaPiloting;
		DodgeStat := STAT_Reflexes;

		{ Adjust the dodge skill value for talents. }
		if ( NAttValue( TMaster^.NA , NAG_Action , NAS_MoveMode ) = MM_Walk ) and HasTalent( TMaster , NAS_SureFooted ) then begin
			SkMod := SkMod + 2;
		end else if ( NAttValue( TMaster^.NA , NAG_Action , NAS_MoveMode ) = MM_Fly ) and HasTalent( TMaster , NAS_BornToFly ) then begin
			SkMod := SkMod + 3;
		end else if ( NAttValue( TMaster^.NA , NAG_Action , NAS_MoveMode ) = MM_Roll ) and HasTalent( TMaster , NAS_RoadHog ) then begin
			SkMod := SkMod + 2;
		end;
	end else begin
		{ Characters use Dodge. }
		DodgeSkill := NAS_Dodge;
		DodgeStat := STAT_Speed;
	end;

	{ Adjust the modifier for melee attacks. These are hard to dodge, but should }
	{ be blocked or parried instead. }
	if ( Attacker <> Nil ) and ( ( Attacker^.G = GG_Module ) or (( Attacker^.G = GG_Weapon ) and (( Attacker^.S = GS_Melee ) or ( Attacker^.S = GS_EMelee )) ) ) and AStringHasBString( FX , 'WasThrown' ) then begin
		SkMod := SkMod - DodgeMeleePenalty;
	end;

	DoleSkillExperience( TMaster , DodgeSkill , XPA_SK_Basic );
	AttemptDodge := SkillRoll( GB , TMaster , DodgeSkill , DodgeStat , SkRoll , SkMod , False , True );
end;

Function AttemptAcrobatics( GB: GameBoardPtr; TMaster: GearPtr; SkRoll: Integer ): Integer;
	{ Try to evade this attack using Acrobatics. }
var
	Part,Armor: GearPtr;
	DefRoll,SkMod: Integer;
	CanUseAcrobatics: Boolean;
begin
	{ You need the talent to even attempt acrobatics. }
	if not HasTalent( TMaster , NAS_Acrobatics ) then Exit( 0 );

	CanUseAcrobatics := False;
	SkMod := 0;
	if TMaster^.G = GG_Character then begin
		{ First, check to see whether or not the character can even use Acrobatics. }
		{ In order to do so he must not be wearing any armor higher than DC2. }
		{ Assume TRUE until shown false. }
		CanUseAcrobatics := True;
		Part := TMaster^.SubCom;
		while Part <> Nil do begin
			if Part^.G = GG_Module then begin
				Armor := SeekCurrentLevelGear( Part^.InvCom , GG_EXArmor , Part^.S );
				if ( Armor <> Nil ) and ( Armor^.V > 2 ) then CanUseAcrobatics := False;
			end;
			Part := Part^.Next;
		end;
	end else if TMaster^.G = GG_Mecha then begin
		CanUseAcrobatics := HasMechaTrait( TMaster , MT_ReflexSystem );
		SkMod := -5;
	end;

	DefRoll := 0;

	{ If it's possible, do the acrobatics attempt. }
	if CanUseAcrobatics then begin
		{ Make an attack roll to block. }
		DefRoll := SkillRoll( GB , TMaster , NAS_Dodge , STAT_Speed , SkRoll , SkMod + ToolBonus( TMaster , -NAS_Acrobatics ) , False , True );
	end;

	{ Return the resultant defense roll. }
	AttemptAcrobatics := DefRoll;
end;

Function AttemptDefenses( GB: GameBoardPtr; TMaster,Attacker: GearPtr; SkRoll: Integer; const FX: String ): DefenseReport;
	{ The target has just been attacked. Roll any appropriate }
	{ defenses. Return the highest defense roll. }
var
	DefRoll: Integer;
	DR: DefenseReport;
begin
	{ First, check to see if this attack will be ineffective. }
	{ If this is a NOMETAL attack or a GASATTACK, it won't affect metal targets. }
	if ( HasAttackAttribute( FX , AA_NoMetal ) or HasAttackAttribute( FX , AA_GasAttack ) ) and ( NAttValue( TMaster^.NA , NAG_GearOps , NAS_Material ) = NAV_Metal ) then begin
		DR.HiRoll := 255;
		DR.HiRollType := GS_Resist;
		Exit( DR );
	end;
	{ If this is a GASATTACK, and the target is enviro-sealed, it won't work. }
	if HasAttackAttribute( FX , AA_GasAttack ) and IsEnviroSealed( TMaster ) then begin
		DR.HiRoll := 255;
		DR.HiRollType := GS_Resist;
		Exit( DR );
	end;

	DR.HiRoll := 0;
	DR.HiRollType := 0;

	{ All attacks get a dodge attempt. }
	{ Make the dodge roll, then dole appropriate experience. }
	DR.HiRoll := 0;
	if AStringHasBString( FX , FX_CanDodge ) then begin
		DR.HiRoll := AttemptDodge( GB , TMaster , Attacker , SkRoll , FX );
		DR.HiRollType := GS_Dodge;
	end;

	{ If dodgeable, try acrobatics next. }
	if AStringHasBString( FX , FX_CanDodge ) and ( DR.HiRoll < SkRoll ) then begin
		DefRoll := AttemptAcrobatics( GB , TMaster , SkRoll );
		if DefRoll > DR.HiRoll then begin
			DR.HiRoll := DefRoll;
			DR.HiRollType := GS_Dodge;
		end;
	end;

	{ Attempt ECM defense. }
	if AStringHasBString( FX , FX_CanECM ) and ( DR.HiRoll < SkRoll ) then begin
		DefRoll := AttemptEWBlock( GB , TMaster , ATtacker , SkRoll );
		if DefRoll > DR.HiRoll then begin
			DR.HiRoll := DefRoll;
			DR.HiRollType := GS_ECMDef;
		end;
	end;

	{ Attempt physical shield parry, if charged. }
	if AStringHasBString( FX , FX_CanBlock ) and ( DR.HiRoll < SkRoll ) then begin
		DefRoll := AttemptShieldBlock( GB , TMaster , ATtacker , SkRoll );
		if DefRoll > DR.HiRoll then begin
			DR.HiRoll := DefRoll;
			DR.HiRollType := GS_Block;
		end;
	end;

	{ Attempt anti-missile intercept. }
	if AStringHasBString( FX , FX_CanIntercept ) and ( DR.HiRoll < SkRoll ) then begin
		DefRoll := AttemptIntercept( GB , TMaster , ATtacker , SkRoll );
		if DefRoll > DR.HiRoll then begin
			DR.HiRoll := DefRoll;
			DR.HiRollType := GS_Intercept;
		end;
	end;

	{ If a close combat attack, attempt a parry with any active }
	{ CC weapon. }
	if AStringHasBString( FX , FX_CanParry ) and ( DR.HiRoll < SkRoll ) then begin
		DefRoll := AttemptParry( GB , TMaster , ATtacker , SkRoll );
		if DefRoll > DR.HiRoll then begin
			DR.HiRoll := DefRoll;
			DR.HiRollType := GS_Parry;
		end;
	end;

	{ If resistable, try to resist. }
	if AStringHasBString( FX , FX_CanResist ) and ( DR.HiRoll < SkRoll ) then begin
		DefRoll := AttemptResist( GB , TMaster , SkRoll );
		if DefRoll > DR.HiRoll then begin
			DR.HiRoll := DefRoll;
			DR.HiRollType := GS_Resist;
		end;
	end;

	{ Attempt HapKiDo block. }
	{ Can only do this if it's a character being attacked, the }
	{ talent is know, the character isn't tired... }
	if AStringHasBString( FX , FX_CanBlock ) and ( DR.HiRoll < SkRoll ) and ( TMaster^.G = GG_CHaracter ) and HasTalent( TMaster , NAS_HapKiDo ) and ( CurrentStamina( TMaster ) > 0 ) then begin
		DefRoll := SkillRoll( GB , TMaster , NAS_CloseCombat , STAT_Speed , SkRoll , 0 , False , True );
		AddStaminaDown( TMaster , 1 );
		if DefRoll > DR.HiRoll then begin
			DR.HiRoll := DefRoll;
			DR.HiRollType := GS_Block;
		end;
	end;

	{ Attempt Stunt Driving dodge. }
	{ Can only do this if it's a mecha being attacked, the }
	{ talent is know, and they're moving at full speed, and the }
	{ pilot has stamina points left... }
	if AStringHasBString( FX , FX_CanDodge ) and ( DR.HiRoll < SkRoll ) and ( TMaster^.G = GG_Mecha ) and HasTalent( TMaster , NAS_StuntDriving ) and ( NAttValue( TMaster^.NA , NAG_Action , NAS_MoveAction ) = NAV_FullSpeed ) and ( CurrentStamina( TMaster ) > 0 ) then begin
		DefRoll := SkillRoll( GB , TMaster , NAS_MechaPiloting , STAT_Speed , SkRoll , 0 , False , True );
		AddStaminaDown( TMaster , 1 );
		if DefRoll > DR.HiRoll then begin
			DR.HiRoll := DefRoll;
			DR.HiRollType := GS_Dodge;
		end;
	end;


	{ If defense was successful, may drain a point of stamina. }
	{ If the defense wasn't successful, no point adding insult }
	{ to injury. }
	if ( DR.HiRoll > SkRoll ) and ( Random( 3 ) = 1 ) then begin
		AddStaminaDown( TMaster , 1 );
	end;

	{ Return the defense report. }
	AttemptDefenses := DR;
end;

Function Firing_Weight( Weapon: GearPtr; AtOp: Integer ): Integer;
	{ Return the firing weight of this weapon operating at the given AtOp. }
var
	bfw: Integer;
begin
	bfw := GearMass( Weapon );
	{ Melee weapons count as larger than they actually are. }
	if ( Weapon^.G = GG_Weapon ) and (( Weapon^.S = GS_Melee ) or ( Weapon^.S = GS_EMelee )) then begin
		bfw := bfw * 2;
	{ Rapid fire also increases the firing weight. }
	{ Missile launchers don't get a penalty for burst firing; probably recoilless. }
	end else if ( AtOp > 0 ) and not (( Weapon^.G = GG_Weapon ) and ( Weapon^.S = GS_Missile )) then begin
		bfw := bfw + ( AtOp * 3 ) div 2;
	end;
	Firing_Weight := bfw;
end;

Function Firing_Weight_Limit( User: GearPtr ): Integer;
	{ Return the maximum firing weight this user can handle. }
begin
	if User^.G = GG_Mecha then begin
		Firing_Weight_Limit := User^.V * 2 + 2;
	end else if User^.G = GG_Character then begin
		Firing_Weight_Limit := CStat( User , STAT_Body );
	end else begin
		Firing_Weight_Limit := 100;
	end;
end;

Function CalcTotalModifiers( gb: GameBoardPtr; Attacker,Target: GearPtr; AtOp: Integer; AtAt: String ): Integer;
	{ Calculate the total modifiers to this attack roll. }
var
	SkRoll,Spd,ZA,ZT,SWB,ShortRange: Integer;
	AMaster,TMaster,AModule,AShield,Ammo,SW: GearPtr;
	Procedure AddModifier( ModLabel: String; ModValue: Integer );
		{ Add a modifier to the total. }
	begin
		if ModValue <> 0 then begin
			if CTM_Modifiers <> '' then CTM_Modifiers := CTM_Modifiers + '; ';
			CTM_Modifiers := CTM_Modifiers + ModLabel + SgnStr( ModValue );
			SkRoll := SkRoll + ModValue;
		end;
	end;
	Function NotIntegralWeapon( Part: GearPtr ): Boolean;
		{ Return TRUE if part is an invcom or the descendant of an invcom. }
	begin
		NotIntegralWeapon := IsExternalPart( AMaster , Part );
	end;
	Function WeaponWeightModifier: Integer;
		{ Return the targeting modifier caused by the weight of this weapon. }
		Function HasFreeHand( LList: GearPtr ): Boolean;
			{ Return TRUE if you can find a hand of equal scale to AMaster }
			{ along this linked list, or FALSE otherwise. }
		var
			HandFound: Boolean;
		begin
			HandFound := False;
			while ( LList <> Nil ) and ( not HandFound ) do begin
				if ( LList^.G = GG_Holder ) and ( LList^.S = GS_Hand ) and ( LList^.Scale >= AMaster^.Scale ) and ( LList^.InvCom = Nil ) then begin
					HandFound := True;
				end else begin
					HandFound := HasFreeHand( LList^.SubCom );
				end;
				LList := LList^.Next;
			end;
			HasFreeHand := HandFound;
		end;
	var
		W,L: Integer;
		Weapon_Module: GearPtr;
	begin
		W := Firing_Weight( Attacker , AtOp ) * ( Attacker^.Scale + 1 );
		L := Firing_Weight_Limit( AMaster ) * ( AMaster^.Scale + 1 );
		Weapon_Module := FindModule( Attacker );
		if ( Weapon_Module <> Nil ) and ( Weapon_Module^.S = GS_Body ) then L := L * 2;
		if HasFreeHand( AMaster^.SubCom ) then L := L * 3;
		if W > L then begin
			WeaponWeightModifier := -5 - ( ( W - L ) div ( AMaster^.Scale + 1 ) ) div 2;
		end else begin
			WeaponWeightModifier := 0;
		end;
	end;
begin
	SkRoll := 0;
	AMaster := FindRoot( Attacker );
	TMaster := FindRoot( Target );
	CTM_Modifiers := '';

	{ Add the weapon accuracy, and possibly Attack Options. }
	if Attacker^.G = GG_Weapon then begin
		if Attacker^.S = GS_Missile then begin
			Ammo := LocateGoodAmmo( Attacker );
			if Ammo <> Nil then AddModifier( 'ammo' , Ammo^.Stat[STAT_Accuracy] );
		end else begin
			AddModifier( 'acc' , Attacker^.Stat[STAT_Accuracy] );
		end;

		{ Add a modifier for any weapon add-ons that might be attached. }
		{ I'll use the AShield var for this instead of declaring a new variable... }
		AShield := Attacker^.InvCom;
		while AShield <> Nil do begin
			if ( AShield^.G = GG_WeaponAddOn ) and NotDestroyed( AShield ) then begin
				AddModifier( 'addon' , AShield^.Stat[STAT_Accuracy] );
			end;
			AShield := AShield^.Next;
		end;

		{ Missiles use sensor rating instead of targeting rating. }
		if ( Attacker^.S = GS_Missile ) and ( AMaster^.G = GG_Mecha ) then begin
			AddModifier( 'sensor' , ( MechaSensorRating( AMaster ) - MechaTargeting( AMaster ) ) );
		end;

		if ( Attacker^.S = GS_Ballistic ) or ( Attacker^.S = GS_BeamGun ) or ( Attacker^.S = GS_Missile ) then begin
			if AtOp > 0 then begin
				if AtOp < 10 then AddModifier( 'BV' , ( AtOp div 2 ) )
				else AddModifier( 'BV' , 5 );
			end;
		end;

	end else begin
		{ Modules and other non-weapon attacking parts suffer }
		{ a -2 to their hot rolls. }
		AddModifier( 'acc' , -2 );
	end;

	{ Modify the attack roll for overheavy weapons. }
	if NotIntegralWeapon( Attacker ) then begin
		AddModifier( 'weight', WeaponWeightModifier );
	end;

	{ Modify the attack roll for wielded shields. }
	AModule := FindModule( Attacker );
	if AModule <> Nil then begin
		AShield := SeekGearByG( AModule^.InvCom , GG_Shield );
		if ( AShield <> Nil ) and ( AShield <> Attacker^.Parent ) then begin
			AddModifier( 'shield' , -5 - AShield^.Stat[ STAT_ShieldBonus ] );
		end;
	end;

	{ Modify the attack score for scale and target depth. }
	{ Depth refers to the subcomponent level that TARGET is at... }
	if not HasAttackAttribute( AtAt , AA_BlastAttack ) then begin
		if Attacker^.Scale <> Target^.Scale then begin
			AddModifier( 'scale' , -( Attacker^.Scale - Target^.Scale ) * PenaltyPerScale );
		end;
		AddModifier( 'depth' , - GearDepth( Target ) * PenaltyPerDepth );
	end;

	{ Modify the attack roll for target and attacker movement. }
	{ The modifier from the attacker is based on MoveAction, }
	{ while the modifier for the defender is based upon actual speed. }
	Spd := NAttValue( AMaster^.NA , NAG_Action , NAS_MoveAction );
	if Spd = NAV_Stop then AddModifier( 'at-stop' , StopBonus )
	else if Spd = NAV_FullSpeed then AddModifier( 'at-run' , -RunPenalty );

	{ Modify for target speed. }
	Spd := CalcRelativeSpeed( TMaster , GB );
	if Spd > 0 then begin
		{ Calc the penalty. }
		Spd := Spd div ClicksPerPenalty;
		AddModifier( 'tr-speed' , -Spd );

		{ Check to see if the attacker has speed-compensation software. }
		SW := SeekSoftware( AMaster , S_SpeedComp , TMaster^.Scale , False );
		if SW <> Nil then begin
			SWB := SW^.V;
			if SWB > Spd then SWB := Spd;
			AddModifier( 'software-speedcomp' , SWB );
		end else begin
		end;

	end else begin
		if CurrentMoveRate( GB^.Scene , TMaster ) > 0 then AddModifier( 'tr-stop' , StopPenalty )
		else if ( TMaster^.G <> GG_Prop ) or ( NAttValue( TMaster^.NA , NAG_Skill , NAS_Dodge ) = 0 ) then AddModifier( 'tr-immobile' , ImmobilePenalty );
	end;

	{ Modify for attack attributes. }
	if HasAttackAttribute( AtAt , AA_STRAIN ) and ( AMaster <> Nil ) and ( CurrentStamina( AMaster ) < 1 ) then AddModifier( 'strain' , -10 );
	if HasAttackAttribute( AtAt , AA_COMPLEX ) and ( AMaster <> Nil ) and ( CurrentMental( AMaster ) < 1 ) then AddModifier( 'complex' , -10 );

	{ Do the modifiers that only count if both meks are on the game board. }
	if OnTheMap( GB , AMaster ) and OnTheMap( GB , TMaster ) then begin
		{ Add the surprise attack bonuses. }
		if not MekCanSeeTarget( GB , TMaster , AMaster ) then begin
			if HasTalent( AMaster , NAS_Ninjitsu ) then begin
				AddModifier( 'stealth' , MOSMeasure * 2 );
			end else begin
				AddModifier( 'stealth' , MOSMeasure );
			end;
		end;

		if not HasAttackAttribute( AtAt , AA_BlastAttack ) then begin
			{ Adjust the attack roll for obscurement between attacker & target. }
			{ Yeah, I'm reusing the SPD variable for cover. Big deal. }
			Spd := CalcObscurement( AMaster , TMaster , GB );
			if Spd > 0 then begin
				AddModifier( 'cover' , -Spd );
			end;
		end;

		{ If the firer is underwater, this will be a more difficult shot. }
		if MekAltitude( gb , AMaster ) < 0 then AddModifier( 'at-water' , - UnderwaterAttackPenalty );

		{ Add range modifier. }
		if IsMissileWeapon( Attacker ) then begin
			{ Still using the SPD variable for all these other uses... }
			SPD := Range( gb , AMaster , TMaster );
			ShortRange := WeaponRange( GB , Attacker , RANGE_Short );
			{ Apply penalty for within minumum range }
			if ( ShortRange > HAS_MINIMUM_RANGE ) and ( Spd < ( ShortRange - 2 ) ) then begin
				{ For every square inside minimum range, there's a -1 attack penalty. Sound familiar? }
				AddModifier( 'minrange' , -( ShortRange - 2 ) + Spd );

			end else if SPD <= ShortRange then AddModifier( 'range' , ShortRangeBonus )
			else if SPD > WeaponRange( GB , Attacker , RANGE_Medium ) then AddModifier( 'range' ,  - LongRangePenalty );
		end;

		{ Apply the blindness penalty. }
		if HasStatus( AMaster , NAS_Blinded ) and ( SPD > 0 ) then begin
			AddModifier( 'blind' ,  - SPD );
		end;

		{ Add altitude modifier. Attacking an airborne mecha is more difficult, }
		{ unless the ANTIAIR attribute is had. If the attacker is higher than the }
		{ defender there's a slight bonus there as well. }
		ZA := MekAltitude( GB , AMaster );
		ZT := MekAltitude( GB , TMaster );
		if ( ZT = 5 ) and ( ZA <> 5 ) and not HasAttackAttribute( AtAt , AA_AntiAir ) then AddModifier( 'tr-fly' , -FlyingPenalty );
		if ( ZA > ZT ) and ( ZT >= 0 ) then AddModifier( 'elevation' , HighGroundBonus );
	end;

	CalcTotalModifiers := SkRoll;
end;

Function BasicDefenseValue( Target: GearPtr ): Integer;
	{ Return the value of this target's basic defense. If the target is a }
	{ mecha, this will be its Mecha Piloting skill value. If the target is }
	{ a character, this will be its Dodge. Otherwise return 5. }
begin
	if Target = Nil then begin
		{ Error! }
		BasicDefenseValue := 0;
	end else if Target^.G = GG_Mecha then begin
		BasicDefenseValue := SkillValue( Target , NAS_MechaPiloting , STAT_Reflexes );
	end else if Target^.G = GG_Character then begin
		BasicDefenseValue := SkillValue( Target , NAS_Dodge , STAT_Speed );
	end else begin
		BasicDefenseValue := 5;
	end;
end;

{ PROCESS EFFECTS VS GEAR TARGETS }

Function PAG_CauseDamage( GB: GameBoardPtr; AtDesc: String; ER: EffectRequest; Target: GearPtr; AtOp: Integer ): Boolean;
	{ Return TRUE if the attack hit and further effects should continue, }
	{ or FALSE if the attack missed. }
var
	AtSkill,AtStat,CritSkill,CritStat,AtRoll,ModMOSMeasure,MOS,NumberOfHits,CritTar,CritHit,T: Integer;
	TPilot,TMaster: GearPtr;
	DefRep: DefenseReport;
	DR: DamageRec;
	msg: String;
	DP: SAttPtr;	{ Destroyed Part }
	Function MeleeNumberOfHits: Integer;
		{ Melee weapons and modules can cause multiple hits. Make an Initiative }
		{ roll to find out how many. ModMOSMeasure and DefRep.HiDefRoll must be }
		{ initialized already. }
	const
		Base_Number_Of_Attacks_Denominator = 3;	{ I gave this const a long name to make my CS prof proud. }
	var
		InitRoll,BonusNumH,NumH: Integer;
	begin
		{ Start by determining the maximum number of bonus attacks that this character can }
		{ have, based on skill rank. }
		BonusNumH := 1 + ( SkillRank( ER.Originator , AtSkill ) div Base_Number_Of_Attacks_Denominator );

		{ Like BV weapons, this number of hits is limited by the attack roll. }
		if BonusNumH > ( AtRoll - DefRep.HiRoll + 1 ) then BonusNumH := ( AtRoll - DefRep.HiRoll + 1 );
		if BonusNumH < 1 then BonusNumH := 1;

		{ Make an Initiative roll to maybe increase the number of hits. }
		InitRoll := SkillRoll( GB , ER.Originator , NAS_Initiative , STAT_Speed , DefRep.HiRoll , 0 , False , GearOperational( TMaster ) and IsMasterGear( TMaster ) );
		if InitRoll > DefRep.HiRoll then begin
			NumH := 2 + (( InitRoll - DefRep.HiRoll ) div ( ModMOSMeasure * 2 ));
		end else begin
			NumH := 1;
		end;

		NumH := NumH + Random( BonusNumH );

		if AStringHasBString( AtDesc , 'WasThrown' ) and ( NumH > 2 ) then NumH := 2;

		MeleeNumberOfHits := NumH;
	end;
begin
	{ Error check- if the damage is to be applied to a metaterrain gear with }
	{ a damage score of 0, just exit. There's nothing to be done here. }
	if ( Target^.G = GG_MetaTerrain ) and ( GearMaxDamage( Target ) = 0 ) then begin
		Exit( False );
	end;

	{ The four parameters for this command are the attack skill, attack stat, crit hit skill, }
	{ and crit hit stat. If the CritSkill is 0, then this attack will not use critical hits. }
	AtSkill := ExtractValue( AtDesc );
	AtStat := ExtractValue( AtDesc );
	CritSkill := ExtractValue( AtDesc );
	CritStat := ExtractValue( AtDesc );

	{ Locate the pilot and the master of the target, just in case they aren't }
	{ the pilot himself. }
	TMaster := FindRoot( Target );
	TPilot := LocatePilot( TMaster );

	{ Add the surprise attack bonuses. }
	if ( ER.Originator <> Nil ) and not MekCanSeeTarget( GB , FindRoot( TMaster ) , ER.Originator ) then begin
		if HasTalent( ER.Originator , NAS_Ninjitsu ) then begin
			ER.FXDice := ER.FXDice * 2;
		end else begin
			ER.FXDice := ER.FXDice * 4 div 3;
		end;
	end;

	{ Make the skill roll. }
	if ER.Originator <> Nil then begin
		{ Don't award any XP yet- we don't know how well the attack went. }
		AtRoll := SkillRoll( GB , ER.Originator , AtSkill , AtStat , BasicDefenseValue( TMaster ) + 2 , CalcTotalModifiers( gb , ER.Weapon , Target , AtOp , AtDesc ) + ER.FXMod , False , False );
		SkillComment( CTM_Modifiers );
	end else begin
		if AtSkill < 5 then AtSkill := 5;
		AtRoll := RollStep( AtSkill );
	end;

	{ Roll the defense dice. }
	DefRep := AttemptDefenses( GB , TMaster , ER.Weapon , AtRoll , AtDesc );

	{ If this is a blast attack, dodging becomes harder. }
	if HasAreaEffect( AtDesc ) and ( AtRoll <= DefRep.HiRoll ) then begin
		{ For every time the defense roll beat the attack roll, }
		{ the damage of the attack is reduced by half. }
		if AtRoll < 1 then AtRoll := 1;
		T := DefRep.HiRoll;
		while T >= AtRoll do begin
			T := T - MOSMeasure;
			ER.FXDice := ER.FXDice div 2;
		end;
		if ER.FXDice < 1 then DefRep.HiRoll := AtRoll + 1
		else DefRep.HiRoll := AtRoll - 1;
	end;

	if ( AtRoll > DefRep.HiRoll ) then begin
		{ The attack hit. }

		{ Dole the experience award for the roll now, since we didn't do it earlier. }
		if GearOperational( TMaster ) and IsMasterGear( TMaster ) and ( ER.Originator <> Nil ) then GiveSkillRollXPAward( ER.Originator , AtSkill , AtRoll , DefRep.HiRoll );

		{ Determine base margin of success. This will be modified later. }
		{ First, determine the modified MOSMeasure. }
		ModMOSMeasure := BasicDefenseValue( TMaster ) div 3;
		if ModMOSMeasure < MOSMeasure then ModMOSMeasure := MOSMeasure;

		{ Next, based on the hit roll, determine base MOS. }
		if IsMasterGear( TMaster ) and ( TMaster^.G <> GG_Prop ) then begin
			MOS := ( AtRoll - DefRep.HiRoll ) div ModMOSMeasure;
		end else if HasTalent( ER.Originator , NAS_GateCrasher ) then begin
			MOS := 3;
		end else begin
			MOS := 0;
		end;

		{ Set the base number of hits. This will be modified later. }
		NumberOfHits := 1 + AtOp;

		{ Perform modifications which only count if }
		{ we have a pointer to the weapon. }
		if ( ER.Weapon <> Nil ) then begin
			{ Modify number of hits by weapon type and AtAt. }
			if ER.Weapon^.G = GG_Weapon then begin
				if ( ER.Weapon^.S = GS_Ballistic ) or ( ER.Weapon^.S = GS_BeamGun ) or ( ER.Weapon^.S = GS_Missile ) then begin
					if AtOp > 0 then begin
						NumberOfHits := AtRoll - DefRep.HiRoll;
						if AtOp > 9 then begin
							if NumberOfHits > 10 then NumberOfHits := 10;
							NumberOfHits := ( ( AtOp + 1 ) * NumberOfHits ) div 10;
						end else begin
							if NumberOfHits > (AtOp + 1) then NumberOfHits := AtOp + 1;
						end;
					end;
				end else if ( ER.Weapon^.S = GS_Melee ) or ( ER.Weapon^.S = GS_EMelee ) then begin
					{ Close combat weapons can trade a high MOS for multiple hits. }
					NumberOfHits := MeleeNumberOfHits;
				end;
			end else if ER.Weapon^.G = GG_Module then begin
				{ Fighting attacks have a higher chance of scoring }
				NumberOfHits := MeleeNumberOfHits;

				MOS := MOS - Non_Weapon_MOS_Penalty;

				{ Modify the MOS for KungFu. }
				{ This will be modified again later for being a nonweapon... }
				if HasTalent( ER.Originator , NAS_KungFu ) then MOS := MOS + Non_Weapon_MOS_Penalty + 1;
			end;
		end;

		if HasAttackAttribute( AtDesc , AA_ArmorIgnore ) then MOS := MOS + 12;

		{ If called shots are illegal right now, reduce MOS }
		{ by 2 to represent the general lack of precision. }
		if CritSkill = 0 then begin
			MOS := MOS - 2;

		end else if ER.Originator <> Nil then begin
			{ Modify MOS for Critical Hit skill. }
			{ Use variable SPD to represent the critical hit target # }
			CritTar := DefRep.HiRoll;

			{ If the high defense roll was lower than the Critical }
			{ Hit Minimum Target number, raise it. }
			if CritTar < CritHitMinTar then CritTar := CritHitMinTar;
			CritHit := SkillRoll( GB , ER.Originator , CritSkill , CritStat , CritTar , 0 , False , GearOperational( TMaster ) and IsMasterGear( TMaster ) );

			if CritHit > CritTar then begin
				MOS := MOS + ( ( CritHit - CritTar ) div ModMOSMeasure ) + 1;
			end;

			{ If the originator has Spot Weakness skill, modify damage for that. }
			if HasSkill( ER.Originator , NAS_SpotWeakness ) then begin
				if HasTalent( ER.Originator , NAS_Sniper ) and ( ER.Weapon <> Nil ) and ( ER.Weapon^.G = GG_Weapon ) and (( ER.Weapon^.S = GS_Ballistic ) or ( ER.Weapon^.S = GS_BeamGun )) then begin
					ER.FXDice := ER.FXDice + SkillRank( ER.Originator , NAS_SpotWeakness );
				end else if ( ER.Weapon <> Nil ) and (( ER.Weapon^.G <> GG_Weapon ) or ( ER.Weapon^.S = GS_EMelee ) or ( ER.Weapon^.S = GS_Melee )) then begin
					ER.FXDice := ER.FXDice + ( SkillRank( ER.Originator , NAS_SpotWeakness ) div 2 );
				end else begin
					ER.FXDice := ER.FXDice + ( SkillRank( ER.Originator , NAS_SpotWeakness ) div 5 );
				end;
			end;

			{ Modify MOS for miscellaneous other talents. }
			{ ANATOMIST talent - +1 MOS vs Meat targets }
			if HasTalent( ER.Originator , NAS_Anatomist ) and ( NAttValue( Target^.NA , NAG_GearOps , NAS_Material ) = NAV_Meat ) then begin
				MOS := MOS + 1;
			end;
		end;

		{ If the weapon has the ARMORPIERCING attribute, its MOS will always be at least 2. }
		if HasAttackAttribute( AtDesc , AA_ArmorPiercing ) then begin
			if MOS < 2 then MOS := 2
			else MOS := MOS + 1;
		end;

		{ If dealing with an energy weapon, MOS has a minimum value. }
		if ( ER.Weapon <> Nil ) and ( ER.Weapon^.G = GG_Weapon ) then begin
			if ER.Weapon^.S = GS_EMelee then begin
				if MOS < 2 then MOS := 2
				else MOS := MOS + 1;
			end else if ( ER.Weapon^.S = GS_BeamGun ) and ( ER.Weapon^.Scale > 0 ) then begin
				if MOS < 1 then MOS := 1
				else MOS := MOS + 1;
			end;
		end;


		{ Modify MOS for the "HARD AS NAILS", "HULL DOWN" talents. }
		if ( TMaster^.G = GG_Character ) and HasTalent( TMaster , NAS_HardAsNails ) then MOS := MOS - 2;
		if (TMaster^.G = GG_Mecha) and HasTalent(TMaster,NAS_HullDown) and ((NAttValue(TMaster^.NA,NAG_Action,NAS_MoveMode)= MM_WALK) or (NAttValue(TMaster^.NA,NAG_Action,NAS_MoveMode)=MM_ROLL)) then MOS := MOS - 3;

		DR := DamageGear( GB , Target , ER.Weapon , ER.FXDice , MOS , NumberOfHits , AtDesc );

		{ Record the animation for this attack. }
		if DR.DamageDone < 1 then begin
			Add_Mek_Animation( GB , TMaster , GS_ArmorDefHit );
		end else begin
			Add_Mek_Animation( GB , TMaster , GS_DamagingHit );
		end;

		{ Record the announcement about this attack. }
		if ER.AttackMessage <> '' then begin
			msg := ReplaceHash( ER.AttackMessage , PilotName( TMaster ) );
		end else if NumberOfHits > 1 then begin
			msg := ReplaceHash( MsgString( '#ishit#timesfor#damage' ) , PilotName( TMaster ) );
			msg := ReplaceHash( msg , BStr( NumberOfHits ) );
		end else begin
			msg := ReplaceHash( MsgString( '#ishitfor#damage' ) , PilotName( TMaster ) );
		end;
		msg := ReplaceHash( msg , BStr( DR.DamageDone ) );

		DP := Destroyed_Parts_List;
		while ( DP <> Nil ) and ( Length( msg ) < Damage_List_Text_Length ) do begin
			msg := msg + ' ' + ReplaceHash( MsgString( '#destroyed' ) , DP^.Info );
			DP := DP^.Next;
		end;

		if DR.MechaDestroyed then begin
			if Destroyed( TMaster ) then begin
				msg := msg + ' ' + ReplaceHash( MsgString( '#destroyed!' ) , GearName( TMaster ) );
			end else begin
				msg := msg + ' ' + ReplaceHash( MsgString( '#disabled!' ) , GearName( TMaster ) );
			end;
		end;
		if DR.PilotDied then msg := msg + ' ' + ReplaceHash( MsgString( '#died' ) , GearName( TPilot ) )
		else if DR.EjectOK then msg := msg + ' ' + ReplaceHash( MsgString( '#ejected' ) , GearName( TPilot ) );

		RecordAnnouncement( msg );

		{ If, at the beginning of this attack, the target was }
		{ functioning, check to see if the attacker gets extra }
		{ experience for taking the target out. }
		if ( ER.Originator <> Nil ) then begin
			if TMaster^.G = GG_Mecha then begin
				if DR.MechaDestroyed then DoleExperience( ER.Originator , TMaster , XPA_DestroyMaster );
			end else if DR.PilotDied then begin
				DoleExperience( ER.Originator , TMaster , XPA_DestroyMaster );
			end else begin
				{ Destroying a non-master gear only gives 1 XP. }
				if Destroyed( Target ) then DoleExperience( ER.Originator , XPA_DestroyThing );
			end;
		end;

		PAG_CauseDamage := True;

	end else begin
		{ The attack missed. }
		{ Only report on the attack missing if this isn't a specially-named attack... }
		if ER.AttackMessage = '' then begin
			Add_Mek_Animation( GB , TMaster , DefRep.HiRollType );
			msg := ReplaceHash( MsgString( 'AttackMissed_' + BStr( DefRep.HiRollType ) ) , PilotName( TMaster ) );
			if msg = '' then msg := 'ERROR: Unknown Defense ' + BStr( DefRep.HiRollType );
			RecordAnnouncement( msg );
		end;
		PAG_CauseDamage := False;
	end;

	{ Receiving an attack causes the target to take a morale check, whether the attack hit or not. }
	SetNAtt( TMaster^.NA , NAG_Action , NAS_MightGiveUp , 1 );
end;

Function PAG_CauseStatusEffect( GB: GameBoardPtr; AtDesc: String; ER: EffectRequest; Target: GearPtr ): Boolean;
	{ Cause a status effect against this target. }
	{ PARAM 1 : Status Number }
var
	SFX,AtRoll: Integer;
	DefRep: DefenseReport;
begin
	{ Extract the parameters. }
	SFX := ExtractValue( AtDesc );

	{ get the root of the target. }
	Target := FindRoot( Target );
	{ If the target is dead, no status effect changes are possible. }
	if not GearActive( Target ) then Exit( False );

	if SX_Vunerability[ SFX , NAttValue( Target^.NA , NAG_GearOps , NAS_Material ) ] then begin

		{ Make the skill roll. }
		AtRoll := RollStep( ( ER.FXDice ) div 2 + 5 );

		{ Make the defense roll. }
		DefRep := AttemptDefenses( GB , Target , ER.Weapon , AtRoll , AtDesc );
		if ( DefRep.HiRoll < AtRoll ) then begin
			AddNAtt( Target^.NA , NAG_StatusEffect , SFX , 3 + Random( 4 ) );
			RecordAnnouncement( ReplaceHash( MsgString( 'Status_Announce' + BStr( SFX ) ) , GearName( Target ) ) );
		end;
	end;

	{ No matter what happened here, keep processing effects. }
	PAG_CauseStatusEffect := True;
end;

Function PAG_RemoveStatusEffect( GB: GameBoardPtr; AtDesc: String; ER: EffectRequest; Target: GearPtr ): Boolean;
	{ Remove a status effect from this target. }
	{ PARAM 1 : Status Number }
var
	SFX: Integer;
	Procedure AttemptStatusChange( Part: GearPtr );
		{ Attempt a status change for this part. If successful, record a message. }
	begin
		{ It's only possible to get a status change from an existing, }
		{ active gear. }
		if ( Part = Nil ) or not GearActive( Part ) then Exit;
		if NAttValue( Part^.NA , NAG_StatusEffect , SFX ) > 0 then begin
			SetNAtt( Part^.NA , NAG_StatusEffect , SFX , 0 );
			RecordAnnouncement( ReplaceHash( MsgString( 'Status_Remove' ) , GearName( Target ) ) );
		end;
	end;
begin
	{ Extract the parameters. }
	SFX := ExtractValue( AtDesc );

	{ get the root of the target. }
	Target := FindRoot( Target );
	{ Try to change its status. }
	AttemptStatusChange( Target );

	{ If the target is a mecha, try to change its pilot's status too. }
	if ( Target <> Nil ) and ( Target^.G = GG_Mecha ) then begin
		Target := LocatePilot( Target );
		AttemptStatusChange( Target );
	end;

	{ No matter what happened here, keep processing effects. }
	PAG_RemoveStatusEffect := True;
end;

Function PAG_Overload( GB: GameBoardPtr; AtDesc: String; ER: EffectRequest; Target: GearPtr ): Boolean;
	{ Apply overload to the target, unless it resists. }
	{ PARAM 1 = Skill to use }
var
	AtRoll: Integer;
	DefRep: DefenseReport;
begin
	{ Can only process this effect if we have a target and a valid }
	{ status effect to process. }
	Target := FindRoot( Target );
	if GearActive( Target ) and ( Target^.G = GG_Mecha ) then begin
		{ Make the skill roll. }
		AtRoll := RollStep( ( ER.FXDice ) div 2 + 5 );

		{ Make the defense roll. }
		DefRep := AttemptDefenses( GB , Target , ER.Weapon , AtRoll , AtDesc );

		if AtRoll > DefRep.HiRoll then begin
			AddNAtt( Target^.NA , NAG_Condition , NAS_PowerSpent , 10 + Random( 10 ) + ( ( AtRoll - DefRep.HiRoll ) div 2 ) );
			RecordAnnouncement( ReplaceHash( MsgString( 'Status_Overload' ) , GearName( Target ) ) );
		end else begin
			AddNAtt( Target^.NA , NAG_Condition , NAS_PowerSpent , Random( ER.FXDice ) + 2 );
		end;
	end;

	PAG_Overload := True;
end;

Function PAG_Healing( GB: GameBoardPtr; AtDesc: String; ER: EffectRequest; Target: GearPtr ): Boolean;
	{ Do healing on target. }
	{ PARAM 1 = Healing Type }
var
	RepSkill: Integer;
	RepairRoll,D0,D1: LongInt;
	msg: String;
begin
	{ Determine what repair skill to use. }
	RepSkill := ExtractValue( AtDesc );

	{ Can only process this effect if we have a target. }
	Target := FindRoot( Target );
	if ( Target <> Nil ) then begin
		{ Record how much repairable damage we started with... }
		D0 := TotalRepairableDamage( Target , RepSkill );

		{ Do some repairs. }
		RepairRoll := RollStep( ER.FXDice );
		ApplyRepairPoints( Target , RepSkill , RepairRoll , False );

		{ Find out how much repairable damage we have now... }
		D1 := TotalRepairableDamage( Target , RepSkill );

		{ Record the announcement, if any healing done. }
		if ( D0 - D1 ) > 0 then begin
			msg := ReplaceHash( MsgString( 'Healing_Announce' ) , GearName( Target ) );
			msg := ReplaceHash( msg , BStr( D0 - D1 ) );
			RecordAnnouncement( msg );
		end;
	end;

	PAG_Healing := True;
end;

Procedure DoEffectAgainstGear( GB: GameboardPtr; ER: EffectRequest; Target: GearPtr; AtOp: Integer );
	{ Perform all the bits of the provided effect request against Target. Store information }
	{ on the process as needed. }
var
	TheLine,Cmd: String;
	SA: SAttPtr;
	Continue: Boolean;
begin
	StartNewAnnouncement;

	{ The FX components of this effect are stored in the FXList. }
	{ Go through the list and do whatever needs doing. }
	SA := ER.FXList;
	Continue := True;
	while ( SA <> Nil ) and Continue do begin
		TheLine := SA^.Info;

		cmd := UpCase( ExtractWord( TheLine ) );

		if cmd = FX_CauseDamage then 		Continue := PAG_CauseDamage( GB , TheLine , ER , Target , AtOp )
		else if cmd = FX_CauseStatusEffect then	Continue := PAG_CauseStatusEffect( GB , TheLine , ER , Target )
		else if cmd = FX_RemoveStatusEffect then	Continue := PAG_RemoveStatusEffect( GB , TheLine , ER , Target )
		else if cmd = FX_Overload then		Continue := PAG_Overload( GB , TheLine , ER , Target )
		else if cmd = FX_Healing then		Continue := PAG_Healing( GB , TheLine , ER , Target );

		SA := SA^.Next;
	end;
end;



{ PROCESS EFFECTS VS TILE TARGETS }

Procedure DestroyTerrain( GB: GameBoardPtr; X,Y: Integer );
	{ Destroy the terrain in this spot. Pretty simple actually. }
var
	Smoke: GearPtr;
begin
	{ Start with an error check... }
	if not OnTheMap( GB , X , Y ) then Exit;

	{ If this terrain has a DESTROYED type set, change the tile. }
	if TerrMan[ TileTerrain( GB,X,Y ) ].Destroyed <> 0 then SetTerrain( GB,X,Y, TerrMan[ TileTerrain( GB,X,Y ) ].Destroyed );

	{ If terrain is destroyed, it will probably cause smoke and maybe fire. }
	if Random( 2 ) = 1 then begin
		Smoke := LoadNewSTC( 'SMOKE-1' );
		if Smoke <> Nil then begin
			Smoke^.Scale := GB^.Scale;
			AppendGear( GB^.Meks , Smoke );
			Smoke^.Stat[ STAT_CloudDuration ] := RollStep( 5 );
			SetNAtt( Smoke^.NA , NAG_Location , NAS_X , X );
			SetNAtt( Smoke^.NA , NAG_Location , NAS_Y , Y );
			SetNAtt( Smoke^.NA , NAG_EpisodeData , NAS_Temporary , 1 );
		end;
	end;
	if ( Random( 3 ) = 1 ) and TerrMan[ TileTerrain( GB,X,Y ) ].Flammable and (( GB^.Scene = Nil ) or ( NAttValue( GB^.Scene^.NA , NAG_EnvironmentData , NAS_Atmosphere ) <> NAV_Vacuum )) then begin
		Smoke := LoadNewSTC( 'FIRE-1' );
		if Smoke <> Nil then begin
			Smoke^.Scale := GB^.Scale;
			AppendGear( GB^.Meks , Smoke );
			SetNAtt( Smoke^.NA , NAG_Location , NAS_X , X );
			SetNAtt( Smoke^.NA , NAG_Location , NAS_Y , Y );
			SetNAtt( Smoke^.NA , NAG_EpisodeData , NAS_Temporary , 1 );
		end;
		SetTrigger( GB , 'FIRE!' );
	end;
end;

Procedure SceneryChewing( GB: GameBoardPtr; ER: EffectRequest; X,Y: Integer; Accident: Boolean; AtAt: String );
	{ Tile X,Y has been hit. Try and damage it. }
	{ Set ACCIDENT to TRUE if the tile is not the primary target of }
	{ the attack, FALSE if it is. }
var
	Terr: Integer;
	DC,Roll,R2: Integer;
begin
	{ Start with an error check... }
	if not OnTheMap( GB , X , Y ) then Exit;

	{ Add an animation. }
	if not Accident then Add_Point_Animation( X , Y , TerrMan[ TileTerrain( GB , X , Y ) ].Altitude , GS_AreaAttack );

	{ See if the weapon is big enough to damage terrain. }
	DC := ER.FXDice;
	if ( ER.Weapon <> Nil ) then begin
		{ The weapon must be at least the same scale as the map. }
		if ER.Weapon^.Scale < GB^.Scale then Exit;
	end;

	if HasAttackAttribute( AtAt , AA_Brutal ) then begin
		DC := DC * 2;
	end;
	if HasAttackAttribute( AtAt , AA_BlastAttack ) then begin
		DC := DC + Random( DC + 1 );
	end;

	{ Modify for accidental damage. If not intentionally trying }
	{ to cause terrain damage, it becomes far less likely to happen. }
	if ( DC > 0 ) and Accident then DC := Random( DC );

	if DC > 0 then begin
		Roll := Random( DC );

		{ Modify for GateCrasher talent. }
		if ( ER.Originator <> Nil ) and HasTalent( ER.Originator , NAS_GateCrasher ) then begin
			R2 := Random( DC + 1 );
			if R2 > Roll then Roll := R2;
		end;

		Terr := TileTerrain( GB,X,Y );
		if ( Roll >= TerrMan[ Terr ].DMG ) and ( TerrMan[ Terr ].DMG > 0 ) then begin
			{ Demolish the scenery... unless there's an error in the definitions. }
			if ( TerrMan[ terr ].Destroyed > 0 ) and ( TerrMan[ terr ].Destroyed <= NumTerr ) then begin
				DestroyTerrain( GB , X , Y );
			end;
		end;
	end;
end;

Procedure ProcessCreateSTC( GB: GameBoardPtr; EF: EffectRequest; X , Y: Integer; TheLine: String );
	{ Create an item from the STC file in position X,Y. }
var
	desig: String;
	item: GearPtr;
	Team: Integer;
begin
	{ Determine the designation of the item to load. }
	desig := ExtractWord( TheLine );

	item := LoadNewSTC( desig );

	{ If ITEM is a master, better do some more work on it. }
	if IsMasterGear( item ) and ( EF.Originator <> Nil ) and ( EF.Weapon <> Nil ) then begin
		{ Step one- decide on the team for our drones! }
		Team := NAttValue( FindRoot( EF.Originator )^.NA , NAG_Location , NAS_Team );
		if ( Team = NAV_DefPlayerTeam ) or ( Team = NAV_LancemateTeam ) then begin
			Team := -1;
		end;

		Rescale( Item , EF.Weapon^.Scale );
		SetNAtt( Item^.NA , NAG_Skill , 6 , EF.FXDice div 2 );
		SetNAtt( Item^.NA , NAG_Skill , 10 , ( EF.FXDice + 1 ) div 2 );
		SetNAtt( Item^.NA , NAG_Location , NAS_Team , Team );

		GearUp( Item );
	end else if ( EF.Weapon <> Nil ) and ( Item^.G = GG_MetaTerrain ) and ( Item^.S = GS_MetaCloud ) then begin
		Item^.Stat[ STAT_CloudDuration ] := EF.FXDice * 5;
		Item^.Scale := EF.Weapon^.Scale;
	end;

	SetNAtt( item^.NA , NAG_Location , NAS_X , X );
	SetNAtt( item^.NA , NAG_Location , NAS_Y , Y );
	SetNAtt( item^.NA , NAG_Location , NAS_D , Random( 8 ) );
	SetNAtt( Item^.NA , NAG_EpisodeData , NAS_Temporary , 1 );
	AppendGear( GB^.Meks , item );
	SetNAtt( item^.NA , NAG_EpisodeData, NAS_UID, MaxIdTag( GB^.Meks , NAG_EpisodeData, NAS_UID ) + 1 );
end;

Procedure DoEffectAgainstTile( GB: GameBoardPtr; ER: EffectRequest; X , Y: Integer; Accident: Boolean );
	{ Perform the required effect against this tile. }
var
	TheLine,Cmd: String;
	SA: SAttPtr;
begin
	{ The FX components of this effect are stored in the FXList. }
	{ Go through the list and do whatever needs doing. }
	SA := ER.FXList;

	while ( SA <> Nil ) do begin
		TheLine := SA^.Info;

		cmd := UpCase( ExtractWord( TheLine ) );

		if cmd = FX_CauseDamage then 		SceneryChewing( GB , ER , X , Y , Accident , TheLine )
		else if cmd = FX_CreateSTC then		ProcessCreateSTC( GB , ER , X , Y , TheLine );

		SA := SA^.Next;
	end;

end;

Procedure ProcessEffect( GB: GameBoardPtr; ER: EffectRequest; TargetList: GearPtr );
	{ An effect is taking place against a list of gears. }
var
	T: GearPtr;
	Area: MapStencil;
	P: Point;
	X,Y: Integer;
begin
	{ Keep track of where targets have been affected. }
	ClearStencil( Area );

	{ Process the targets. }
	T := TargetList;
	while T <> Nil do begin
		DoEffectAgainstGear( GB , ER , T^.Parent , T^.V );
		P := GearCurrentLocation( FindRoot( T^.Parent ) );
		if OnTheMap( GB , P.X , P.Y ) then Area[ P.X , P.Y ] := True;

		T := T^.next;
	end;

	{ Process the map tiles. }
	for X := 1 to GB^.Map_Width do begin
		for Y := 1 to GB^.Map_Height do begin
			if Area[ X , Y ] then begin
				DoEffectAgainstTile( GB , ER , X , Y , True );
			end;
		end;
	end;
end;

Procedure ProcessEffect( GB: GameBoardPtr; ER: EffectRequest; Area: MapStencil; AtOp: Integer );
	{ An effect is taking place over an area. Do the effect against every model in }
	{ the area, then against all the tiles as well. }
var
	T: GearPtr;
	P: Point;
	X,Y: Integer;
begin
	T := GB^.Meks;
	while T <> Nil do begin
		P := GearCurrentLocation( T );
		if OnTheMap( GB , P.X , P.Y ) and Area[ P.X , P.Y ] then begin
			DoEffectAgainstGear( GB , ER , T , AtOp );
		end;
		T := T^.Next;
	end;
	for X := 1 to GB^.Map_Width do begin
		for Y := 1 to GB^.Map_Height do begin
			if Area[ X , Y ] then begin
				DoEffectAgainstTile( GB , ER , X , Y , False );
			end;
		end;
	end;
end;


Procedure InitEffectRequest( var ER: EffectRequest );
	{ Given a supposedly new effect request, initialize its fields to default values. }
begin
	ER.FXList := Nil;
	ER.Originator := Nil;
	ER.Weapon := Nil;
	ER.AttackName := '';
	ER.AttackMessage := '';
	ER.FXDice := 0;
	ER.FXMod := 0;
end;

Procedure FinishEffectRequest( var ER: EffectRequest );
	{ Given an effect request, dispose of the attached lists. }
begin
	DisposeSAtt( ER.FXList );
end;

Procedure DrawBlastEffect( GB: GameBoardPtr; X0,Y0,Z0,RNG: Integer; var Stencil: MapStencil );
	{ Calculate all the squares targeted by a blast effect centered }
	{ upon X0,Y0 with radius RNG. Store the results of the calculation }
	{ in the STENCIL array. }
	{ The stencil array must have been initialized by clearing previously; it's not }
	{ done here in case multiple blast circles are to be drawn on the map. }
const
	DBA_True = 1;
	DBA_False = -1;
	DBA_Maybe = 0;
var
	temp: Array [ -Max_Blast_Rating..Max_Blast_Rating , -Max_Blast_Rating..Max_Blast_Rating ] of integer;
	x,y: Integer;

	Procedure CheckLine(XT,YT: Integer);
	var
		t: Integer;	{A counter, and a terrain type.}
		Wall: Boolean;	{Have we hit a wall yet?}
		p: Point;
	begin
		{Check every point on the line from the origin to XT,YT,}
		{recording the results in the Temp array.}

		{ The variable WALL represents a boundary that cannot be }
		{ blasted through. }
		Wall := false;

		for t := 1 to rng do begin
			{Locate the next point on the line.}
			p := SolveLine(0,0,XT,YT,t);

			{Determine the terrain of this tile.}
			if OnTheMap( GB , p.X + X0 , p.Y + Y0 ) then begin
				{If we have already encountered a wall, mark this square as UPV_False}
				if Wall then temp[p.x,p.y] := DBA_False;

				Case temp[p.x,p.y] of
					DBA_False: Break; {This LoS is blocked. No use searching any further.}
					DBA_Maybe: begin  {We will mark this one as true, but check for a wall later.}
						temp[p.x,p.y] := DBA_True;
						end;
					{If we got a DBA_True, we just skip merrily along without doing anything.}
				end;

				{If this current square is a wall,}
				{or if we have too much obscurement to see,}
				{set Wall to true.}
				if TileBlocksLOS( GB , p.X + X0 , p.Y + Y0 , Z0 ) then Wall := True;
			end;
		end;
	end;

begin
	{ Start by updating the shadow map. This is needed for the }
	{ TILEBLOCKSLOS function. }
	UpdateShadowMap( GB );

	{ Error check. }
	if not OnTheMap( GB , X0 , Y0 ) then exit;

	{Set every square in the temp array to Maybe.}
	for x := -Max_Blast_Rating to Max_Blast_Rating do begin
		for y := -Max_Blast_Rating to Max_Blast_Rating do begin
			temp[x,y] := DBA_Maybe;
		end;
	end;

	{Set the origin to True.}
	temp[0,0] := DBA_True;

	{ If the origin blocks the blast, it will be the only tile }
	{ affected. }
	if not TileBlocksLOS( GB , X0 , Y0 , Z0 ) then begin
		{Check the 4 cardinal directions}
		CheckLine( 0,  rng );
		CheckLine( 0, -rng );
		CheckLine(  rng, 0 );
		CheckLine( -rng, 0 );

		{Check the 4 diagonal directions}
		CheckLine(rng,rng);
		CheckLine(rng,-rng);
		CheckLine(-rng,rng);
		CheckLine(-rng,-rng);

		For X := -rng + 1 to -1 do begin
			Checkline(X,-rng);
			CheckLine(X,rng);
		end;

		For X := rng -1 downto 1 do begin
			Checkline(X,-rng);
			CheckLine(X,rng);
		end;


		For Y := -rng + 1 to -1 do begin
			Checkline(rng,Y);
			CheckLine(-rng,Y);
		end;

		For Y := rng - 1 downto 1 do begin
			CheckLine(rng,Y);
			CheckLine(-rng,Y);
		end;
	end;

	{ Copy over the TEMP array into the STENCIL array. }
	for x := -Max_Blast_Rating to Max_Blast_Rating do begin
		for y := -Max_Blast_Rating to Max_Blast_Rating do begin
			if OnTheMap( GB , X0 + X , Y0 + Y ) and ( temp[ X , Y ] = DBA_True ) and ( Range( 0 , 0 , X , Y ) <= rng ) then begin
				Stencil[ X0 + X , Y0 + Y ] := True;
			end;
		end;
	end;
end;

Procedure Explosion( GB: GameBoardPtr; X0,Y0,DC,R: Integer );
	{ An explosion has been requested. Do it. }
var
	ER: EffectRequest;
	Area: MapStencil;
begin
	ClearAttackHistory;
	InitEffectRequest( ER );

	ClearStencil( Area );
	DrawBlastEffect( GB , X0 , Y0 , TerrMan[ TileTerrain( GB , X0 , Y0 ) ].Altitude , R , Area );

	ER.FXDice := DC;
	StoreSAtt( ER.FXList , 'DAMAGE 10 0 0 0 BLAST 1' );

	ProcessEffect( GB , ER , Area , 0);

	{ Finalize any pending announcements. }
	FlushAnnouncements;

	{ Get rid of any dynamic resources allocated. }
	FinishEffectRequest( ER );
end;

Procedure ExperimentifyAttack( var ER: EffectRequest; var AtAt: String; var ATOp: Integer );
	{ This attack is going to get weird. An EXPERIMENTAL weapon is kind of like }
	{ a wand of wonder- you never really know what's going to happen. One special }
	{ effect will be applied to the attack- it may gain a blast radius, hit bonuses }
	{ or penalties, do nothing but launch smoke... there's no way of telling. }
var
	roll: Integer;
begin
	roll := Random( 25 ) + 1;
	case Roll of
		11:	begin	{ Accuracy Bonus }
			ER.FXMod := ER.FXMod + 5;
			end;
		12:	begin	{ Accuracy Penalty }
			ER.FXMod := ER.FXMod - 10;
			end;
		13:	begin	{ Damage Boost }
			ER.FXDice := ER.FXDice * 2;
			end;
		14:	begin	{ Damage Thwack }
			ER.FXDice := 1;
			end;
		15:	begin	{ Blast Radius }
			AtAt := AtAt + ' BLAST ' + BStr( Random( 3 ) + 1 );
			end;
		16:	begin	{ Weak Blast }
			ER.FXDice := ER.FXDice div 3 + 1;
			AtAt := AtAt + ' BLAST ' + BStr( Random( 6 ) + 1 );
			end;
		17:	begin	{ Smoke }
			AtAt := ATAt + ' SMOKE BLAST ' + BStr( Random( 4 ) + 1 );
			end;
		18:	begin	{ A Little Smoke }
			AtAt := ATAt + ' SMOKE';
			end;
		19:	begin	{ Hyper }
			AtAt := ATAt + ' HYPER';
			ER.FXDice := ER.FXDice div 2 + 1;
			ER.FXMod := ER.FXMod - 5;
			end;
		20:	begin	{ Haywire }
			AtAt := ATAt + ' HAYWIRE';
			end;
		21,22:	begin	{ Burn }
			AtAt := ATAt + ' BURN';
			end;
		23:	begin	{ Nonlethal }
			AtAt := ATAt + ' NONLETHAL';
			end;
		24:	begin	{ Weak Disintegrate }
			ER.FXDice := 1;
			ER.FXMod := ER.FXMod - 5;
			AtAt := AtAt + ' DISINTEGRATE';
			end;
		25:	begin	{ Stun }
			AtAt := ATAt + ' STUN';
			end;
	end;
end;

Procedure FunkyMartialArts( var ER: EffectRequest; var AtAt: String; var ATOp: Integer );
	{ This attack may well get some special bonuses. }
const
	NumFMABase = 10;
	Num_Funky_Things = 14;
	FT_Cost: Array [1..Num_Funky_Things] of Byte = (
		3, 3, 4, 8, 4,
		4, 4, 3, 1, 3,
		1, 2, 1, 5
	);
	FT_AA: Array [1..Num_Funky_Things] of String[15] = (
	'','','SCATTER','HYPER','ARMORPIERCING',
	'BRUTAL','STONE','HAYWIRE','STUN','FLAIL',
	'', '', '','BURN'
	);
	FT_Heroic = 1;
	FT_Zen = 2;
	FT_1000Blows = 3;
	FT_Hyper = 4;
	FT_ArmorPiercing = 5;
	FT_Brutal = 6;
	FT_Stoning = 7;
	FT_Haywire = 8;
	FT_Stunning = 9;
	FT_Snake = 10;
	FT_Tragic = 11;
	FT_Passion = 12;
	FT_Accurate = 13;
	FT_Burn = 14;
var
	SkRk,TP: Integer;
	Adjective,Noun: SAttPtr;
	msg,C: String;
	FTTaken: Array [1..Num_Funky_Things] of Boolean;
	Function CanGetFunkyThing( N: Integer ): Boolean;
		{ Return TRUE if the attacker can do this funky thing, based on }
		{ Technique Points and whatever else, or FALSE if he can't. }
	begin
		if FTTaken[N] then begin
			CanGetFunkyThing := False;
		end else if FT_Cost[ N ] <= TP then begin
			case N of
				FT_Heroic: 	CanGetFunkyThing := NAttValue( ER.Originator^.NA , NAG_CharDescription , NAS_Heroic ) > 10;
				FT_Zen:		CanGetFunkyThing := NAttValue( ER.Originator^.NA , NAG_CharDescription , NAS_Pragmatic ) < -10;
				FT_Tragic:	CanGetFunkyThing := NAttValue( ER.Originator^.NA , NAG_CharDescription , NAS_Cheerful ) < -10;
				FT_Passion:	CanGetFunkyThing := NAttValue( ER.Originator^.NA , NAG_CharDescription , NAS_Easygoing ) < -10;
			else CanGetFunkyThing := True;
			end;
		end else begin
			{ If not enough points, can't do this thing. }
			CanGetFunkyThing := False;
		end;
	end;
	Procedure ApplyFunkyThing( N: Integer );
		{ Apply the funky thing to the attack request; reduce the total number }
		{ of technique points; store a noun and an adjective to describe this }
		{ attack. }
	var
		trait: Integer;
	begin
		TP := TP - FT_Cost[ N ];
		AtAt := AtAt + ' ' + FT_AA[ N ];
		if Random( 2 ) = 1 then StoreSAtt( Adjective , MsgString( 'FMAFT_A' + BStr( N ) ) )
		else StoreSAtt( Noun , MsgString( 'FMAFT_N' + BStr( N ) ) );
		FTTaken[ N ] := True;

		{ Add bonuses for special things here. }
		if N = FT_Heroic then begin
			{ A heroic attack increases damage done based on the character's heroism. }
			ER.FXDice := ER.FXDice + ( NAttValue( ER.Originator^.NA , NAG_CharDescription , NAS_Heroic ) div 5 );
		end else if N = FT_Zen then begin
			{ A zen attack increases damage based on the character's spirituality. }
			ER.FXMod := ER.FXMod + ( Abs( NAttValue( ER.Originator^.NA , NAG_CharDescription , NAS_Pragmatic ) ) div 10 );
		end else if N = FT_Tragic then begin
			{ A tragic attack increases damage+accuracy based on the character's melancholy. }
			trait := Abs( NAttValue( ER.Originator^.NA , NAG_CharDescription , NAS_Cheerful ) );
			ER.FXDice := ER.FXDice + trait div 20;
			ER.FXMod := ER.FXMod + ( trait + 10 ) div 15;
		end else if N = FT_Passion then begin
			{ A passionate attack increases damage, decreases accuracy. }
			ER.FXDice := ER.FXDice + ( Abs( NAttValue( ER.Originator^.NA , NAG_CharDescription , NAS_Easygoing ) ) div 5 ) + 3;
			ER.FXMod := ER.FXMod - 5;
		end else if N = FT_Accurate then begin
			ER.FXMod := ER.FXMod + 1
		end;
	end;
begin
	{ First, make sure we have an originator, and that it knows kung fu. }
	if ( ER.Originator = Nil ) or ( ER.Originator^.G <> GG_Character ) or ( not HasTalent( ER.Originator , NAS_KungFu ) ) then begin
		AtOp := 0;
		exit;
	end;

	{ The attacker must have a martial arts skill of at least 5 to benefit. }
	SkRk := NAttValue( ER.Originator^.NA , NAG_Skill , NAS_CloseCombat ) - 4;
	if SkRk < 1 then begin
		if NAttValue( ER.Originator^.NA , NAG_GearOps , NAS_Material ) = NAV_Meat then AtOp := -1;
		Exit;
	end;

	{ Initialize the technique array. }
	for TP := 1 to Num_Funky_Things do FTTaken[TP] := False;

	{ TP is Technique Points. }
	TP := SkRk + Random( 3 );


	{ If any technique points were gained, put them to good use here. }
	{ Technique points can buy attack improvements: attack attributes, various bonuses, }
	{  status effects... }
	if TP > 0 then begin
		{ Initialize the variables needed for our attack name generator. }
		Adjective := Nil;
		Noun := Nil;
		if ( ER.Weapon^.S = GS_Arm ) and ( Random( 5 ) <> 1 ) then begin
			Msg := MsgString( 'FMA_Name_Punch_' + BStr( Random( NumFMABase ) + 1 ) );
		end else if ( ER.Weapon^.S = GS_Leg ) and ( Random( 5 ) <> 1 ) then begin
			Msg := MsgString( 'FMA_Name_Kick_' + BStr( Random( NumFMABase ) + 1 ) );
		end else begin
			Msg := MsgString( 'FMA_Name_Misc_' + BStr( Random( NumFMABase ) + 1 ) );
		end;

		while TP > 0 do begin
			SkRk := Random( Num_Funky_Things ) + 1;
			if CanGetFunkyThing( SkRk ) then begin
				ApplyFunkyThing( SkRk );
			end else if Random( 3 ) <> 1 then begin
				{ If the thing chosen can't be gotten, just give a bonus }
				{ to damage. }
				Inc( ER.FXDice );
				Dec( TP );
			end;
		end;

		ER.AttackName := '';
		while msg <> '' do begin
			C := ExtractWord( msg );
			if C = '%A' then begin
				if Adjective <> Nil then begin
					ER.AttackName := ER.AttackName + ' ' + SelectRandomSAtt( Adjective )^.Info;
				end else begin
					ER.AttackName := ER.AttackName + ' ' + MsgString( 'FMAFT_MISCA' + BStr( Random( 5 ) + 1 ) );
				end;
			end else if C = '%N' then begin
				if Noun <> Nil then begin
					ER.AttackName := ER.AttackName + ' ' + SelectRandomSAtt( Noun )^.Info;
				end else begin
					ER.AttackName := ER.AttackName + ' ' + MsgString( 'FMAFT_MISCN' + BStr( Random( 5 ) + 1 ) );
				end;
			end else begin
				ER.AttackName := ER.AttackName + ' ' + C;
			end;
		end;

		DisposeSAtt( Adjective );
		DisposeSAtt( Noun );
	end;
end;

Procedure AddNonDamagingEffects( var AtAt: String; var ER: EffectRequest );
	{ Add status effects and other non-damaging effects to this effect request. }
	{ ResistSkill is the skill number recorded in status effect checks; for attacks, this should }
	{ be the Electronic Warfare skill, but for non-attack effects it should be a straight }
	{ resistance target. }
var
	msg: String;
	T: Integer;
begin
	if AStringHasBString( AtAt , AA_Name[ AA_Overload ] ) then begin
		msg := FX_Overload + '  ' + FX_CANRESIST;
		StoreSAtt( ER.FXList , msg );
	end;

	if AStringHasBString( AtAt , AA_Name[ AA_Smoke ] ) then begin
		msg := FX_CreateSTC + ' SMOKE-1';
		StoreSAtt( ER.FXList , msg );
	end;
	if AStringHasBString( AtAt , AA_Name[ AA_Gas ] ) then begin
		msg := FX_CreateSTC + ' GAS-1';
		StoreSAtt( ER.FXList , msg );
	end;
	if AStringHasBString( AtAt , AA_Name[ AA_Drone ] ) then begin
		msg := FX_CreateSTC + ' DRONE-1';
		StoreSAtt( ER.FXList , msg );
	end;


	{ Add status effects here. }
	for t := 1 to Num_Status_FX do begin
		if AStringHasBString( AtAt , SX_Name[ T ] ) then begin
			{ All status effects are done using EW skill now. }
			msg := FX_CauseStatusEffect + ' ' + BStr( T ) + ' ' + FX_CANRESIST;
			StoreSAtt( ER.FXList , msg );
		end;
	end;
end;

Function BuildAttackRequest( GB: GameBoardPtr; Attacker: GearPtr; AtOp,X,Y: Integer; var AtAt: String ): EffectRequest;
	{ Create the effect request for this particular attack. }
var
	ER: EffectRequest;
	msg: String;
begin
	InitEffectRequest( ER );

	ER.FXDice := WeaponDC( Attacker );
	ER.Weapon := Attacker;
	ER.Originator := FindRoot( Attacker );

	{ Modify for power loss. }
	if ( EnergyPoints( ER.Originator ) < EnergyCost( Attacker ) ) and ( EnergyCost( Attacker ) > 0 ) then begin
		ER.FXMod := -5;
		ER.FXDice := ER.FXDice div 2;
		if ER.FXDice < 1 then ER.FXDice := 1;
		ER.AttackName := ReplaceHash( MsgString( 'LOW_POWER_ATTACK' ) , GearName( Attacker ) );
	end;

	{ Modify the AtOp for close combat attacks if NONLETHAL is turned on. }
	if ( Attacker^.G = GG_Module ) and ( NAttValue( ER.Originator^.NA , NAG_Prefrences , NAS_UseNonLethalAttacks ) <> 0 ) then AtOp := AtOp_NonLethal;

	if ( Attacker^.G = GG_Module ) and ( ER.Originator^.G = GG_Character ) and ( AtOp = 0 ) then FunkyMartialArts( ER , AtAt , AtOp );
	if HasAttackAttribute( AtAt , AA_Experimental ) then ExperimentifyAttack( ER , AtAt , AtOp );

	{ If the weapon must be thrown, make a note of that here. }
	if MustBeThrown( GB , FindRoot( Attacker ) , Attacker , X , Y ) then begin
		AtAt := AtAt + ' WasThrown';
	end;

	if not NonDamagingAttack( AtAt ) then begin
		{ This is not a NonDamaging effect. So, the first command in the }
		{ effect queue should be a damage effect. }
		{ PARAM 1 = Attack Skill }
		msg := FX_CauseDamage + ' ' + BStr( AttackSkillNeeded( Attacker ) ) + ' ' + BStr( AttackStatNeeded( Attacker ) );
		{ PARAM 3 = Critical Hit Skill, 0 for none }
		if NoCalledShots( AtAt , AtOp ) then msg := msg + ' 0 0'
		else msg := msg + ' ' + BStr( NAS_SpotWeakness ) + ' ' + BStr( STAT_Craft );

		{ All attacks can be dodged. }
		msg := msg + ' ' + FX_CanDodge;

		{ Close combat attacks can be parried. Ranged attacks can be ECM'd. }
		if ( Attacker^.G = GG_Module ) or ( Attacker^.S = GS_Melee ) or ( Attacker^.S = GS_EMelee ) then begin
			{ The one exception is flailing weapons, which can't be parried. }
			if not HasAttackAttribute( AtAt , AA_Flail ) then msg := msg + ' ' + FX_CanParry;
		end else begin
			msg := msg + ' ' + FX_CanECM;
		end;

		{ Missiles can be intercepted. }
		if ( Attacker^.G = GG_Weapon ) and ( Attacker^.S = GS_Missile ) then msg := msg + ' ' + FX_CanIntercept;

		{ If no blast radius, the attack can be blocked. }
		if not HasAreaEffect( AtAt ) then msg := msg + ' ' + FX_CanBlock;

		{ The attack attributes are added to the end of the string. }
		msg := msg + ' ' + AtAt;

		{ If this is a nonlethal attack, add the NONLETHAL attack attribute. }
		if atop = AtOp_NonLethal then msg := msg + ' ' + AA_Name[ AA_NonLethal ];

		StoreSAtt( ER.FXList , msg );
	end;

	{ Add the extra effects here. }
	AddNonDamagingEffects( AtAt , ER );

	BuildAttackRequest := ER;
end;


Procedure PostAttackCleanup( GB: GameBoardPtr; Attacker: GearPtr; TX,TY,TZ: Integer );
	{ Deal with whatever needs to be dealt with. }
var
	Master: GearPtr;
	P: Point;
begin
	Master := FindRoot( Attacker );
	P.X := TX;
	P.Y := TY;

	{ Spend power points here. }
	if ( Attacker^.G = GG_Weapon ) and ( ( Attacker^.S = GS_EMelee ) or ( Attacker^.S = GS_BeamGun ) ) then begin
		SpendEnergy( Master , EnergyCost( Attacker ) );
	end;

	if HasAttackAttribute( WeaponAttackAttributes( Attacker ) , AA_STRAIN ) and ( Master <> Nil ) then AddStaminaDown( Master , 10 );
	if HasAttackAttribute( WeaponAttackAttributes( Attacker ) , AA_COMPLEX ) and ( Master <> Nil ) then AddMentalDown( Master , 10 );

	{ If the weapon was thrown, deal with that here. }
	if MustBeThrown( GB , Master , Attacker , P.X , P.Y ) then begin
		if Attacker^.G = GG_Ammo then begin
			{ Lower the ammo count for grenades, deleting if nessecary. }
			AddNAtt( Attacker^.NA , NAG_WeaponModifier , NAS_AmmoSpent , 1 );
			if ( Attacker^.Stat[STAT_AmmoPresent] - NAttValue( Attacker^.NA , NAG_WeaponModifier , NAS_AmmoSpent ) ) < 1 then begin
				if IsInvCom( Attacker ) then begin
					RemoveGear( Attacker^.Parent^.InvCom , Attacker );
				end else if IsSubCom( Attacker ) then begin
					RemoveGear( Attacker^.Parent^.SubCom , Attacker );
				end;
			end;

		end else if not HasAttackAttribute( WeaponAttackAttributes( Attacker ) , AA_Returning ) then begin
			if IsInvCom( Attacker ) then begin
				DelinkGear( Attacker^.Parent^.InvCom , Attacker );
				AppendGear( GB^.Meks , Attacker );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_X , P.X );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_Y , P.Y );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_Team , NAttValue( Master^.NA , NAG_Location , NAS_Team ) );

			end else if IsSubCom( Attacker ) then begin
				DelinkGear( Attacker^.Parent^.SubCom , Attacker );
				AppendGear( GB^.Meks , Attacker );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_X , P.X );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_Y , P.Y );
				SetNAtt( Attacker^.NA , NAG_Location , NAS_Team , NAttValue( Master^.NA , NAG_Location , NAS_Team ) );

			end;
		end else begin
			Inc( EFFECTS_Event_Order );
			Add_Shot_Precisely( GB , TX , TY , TZ , NAttValue( Master^.NA , NAG_Location , NAS_X ) , NAttValue( Master^.NA , NAG_Location , NAS_Y ) , MekALtitude( GB , Master ) );
		end;

	end;
end;

Function SwarmRadius( GB: GameBoardPtr; Attacker: GearPtr ): Integer;
	{ Return the radius at which this weapon swarms. }
begin
	if Attacker^.Scale < GB^.Scale then begin
		SwarmRadius := 2;
	end else if Attacker^.Scale > GB^.Scale then begin
		SwarmRadius := 10;
	end else begin
		SwarmRadius := 5;
	end;
end;

Function MekIsTargetInRadius( GB: GameBoardPtr; Mek,Attacker,Weapon,Spotter: GearPtr; X,Y,R: Integer ): Boolean;
	{ Used by the NumTargetsInRadius and FindTargetInRadius functions. }
	{ Returns TRUE is Mek is an enemy of ATTACKER, is visible by }
	{ SPOTTER, and is within the prescribed screen area. }
begin
	Spotter := FindRoot( SPotter );
	MekIsTargetInRadius := AreEnemies( GB , Attacker , Mek ) and MekCanSeeTarget( GB , Spotter , Mek ) and RangeArcCheck( GB , Attacker , Weapon , Mek ) and ( Range( Mek , X , Y ) <= R ) and GearOperational( Mek );
end;

Function NumTargetsInRadius( GB: GameBoardPtr; Attacker,Weapon,Spotter: GearPtr; X,Y,R: Integer ): Integer;
	{ Determine the number of targets within the radius which can be }
	{ seen by SPOTTER and are enemies of ATTACKER. }
var
	N: Integer;
	M: GearPtr;
begin
	N := 0;
	M := GB^.Meks;
	while M <> Nil do begin
		if MekIsTargetInRadius( GB, M, Attacker, Weapon, Spotter, X, Y, R ) then Inc( N );
		M := M^.Next;
	end;
	NumTargetsInRadius := N;
end;


Function GenerateTargetList( GB: GameBoardPtr; Attacker,Target: GearPtr; X,Y,Z,AtOp: Integer; const AtAt: String; AddAnims: Boolean ): GearPtr;
	{ Generate a target list for this attack. }
	{ This procedure will also make the shot animations. }
var
	TarList: GearPtr;
	Procedure AddTargetToList( T: GearPtr; NumShots: Integer );
	var
		it: GearPtr;
	begin
		it := AddGear( TarList , Nil );
		it^.Parent := T;
		it^.V := NumShots;
		if AddAnims then Add_Shot_Animation( GB , FindRoot( Attacker ) , FindRoot( T ) );
	end;

	Procedure CreateSwarmTargetList;
		{ Create a list of targets to be affected by this swarm attack. }
	var
		Mek: GearPtr;
		r,n,T,AtOp2: Integer;
	begin
		R := SwarmRadius( GB , Attacker );
		N := NumTargetsInRadius( GB , FindRoot( Attacker ) , Attacker , FindRoot( Attacker ) , X , Y , R );

		if N > 0 then begin
			Mek := GB^.Meks;
			T := 1;
			while Mek <> Nil do begin
				AtOp2 := ( AtOp + 1 ) div N - 1;
				if T <= ( ( AtOp + 1 ) mod N ) then Inc( AtOp2 );

				if MekIsTargetInRadius( GB, Mek, FindRoot( Attacker ) , Attacker, FindRoot( Attacker ), X, Y, R ) and ( AtOp2 >= 0 ) then begin
					AddTargetToList( Mek , AtOp2 );
					Inc( T );
				end;

				mek := Mek^.Next;
			end;
		end;
	end;

begin
	if NoCalledShots( AtAt , AtOp ) then Target := FindRoot( Target );
	TarList := Nil;

	if ( AtOp > 0 ) and HasAttackAttribute( AtAt , AA_SwarmAttack ) then begin
		CreateSwarmTargetList;
	end else if ( Target <> Nil ) then begin
		AddTargetToList( Target , AtOp );
	end;

	Inc( Effects_Event_Order );

	GenerateTargetList := TarList;
end;

Function GenerateAttackTemplate( GB: GameBoardPtr; Attacker: GearPtr; var X , Y , Z , AtOp: Integer; const AtAt: String ): MapStencil;
	{ ATTACKER is a weapon supposedly with a blast radius. }
	{ See where it goes. }
	{ This procedure will also make the shot animations. }
var
	Radius,X0,Y0,Z0: Integer;
	Stencil: MapStencil;
	Procedure PlaceBlastSpot( BX,BY,BZ: Integer );
		{ A blast is gonna take place here. }
		{ Draw the shot animation and roll for deviation. }
	var
		Rng: Integer;
	begin
		Rng := Range( X0, Y0, BX , BY );
		{ Make a skill roll to see if the blast will deviate slightly. }
		if ( Radius > 0 ) and ( Rng > RollStep( SkillValue( FindRoot( Attacker ) , AttackSkillNeeded( Attacker ) , AttackStatNeeded( Attacker ) ) ) ) then begin
			BX := BX + Random( Radius div 3 + 2 ) - Random( Radius div 3 + 2 );
			BX := BX + Random( Radius div 3 + 2 ) - Random( Radius div 3 + 2 );
		end;

		Add_Shot_Precisely( GB , X0 , Y0 , Z0 , BX , BY , BZ );

		if Radius > 0 then begin
			DrawBlastEffect( GB , BX , BY , BZ , Radius , Stencil );
		end else if OnTheMap( GB , BX , BY ) then begin
			Stencil[ BX , BY ] := True;
		end;
	end;
	Procedure PlaceMultipleBlasts( Radius: Integer );
		{ While AtOp > 0, place multiple blasts around the board. }
	var
		BX,BY: Integer;
	begin
		BX := X + Random( 2 ) - Random( 2 );
		BY := Y + Random( 2 ) - Random( 2 );
		while AtOp > 0 do begin
			PlaceBlastSpot( BX , BY , Z );
			BX := X + Random( Radius + 1 ) - Random( Radius + 1 );
			BY := Y + Random( Radius + 1 ) - Random( Radius + 1 );
			Dec( AtOp );
		end;
	end;
	Procedure DrawOneLine( X1,Y1,Z1,rng: Integer );
		{ Draw a line from X0,Y0,Z0 to X1,Y1,Z1. }
	var
		T: Integer;
		P: Point;
	begin
		T := 0;
		while ( T < rng ) do begin
			Inc( T );
			P := SolveLine( X0 , Y0 , Z0 , X1 , Y1 , Z1 , T );
			if OnTheMap( GB , P.X , P.Y ) then begin
				Stencil[ P.X , P.Y ] := True;
				if TileBlocksLOS( GB , P.X , P.Y , P.Z ) then T := rng;
			end;
		end;
	end;
	Procedure PlaceLineAttack;
		{ Do the messy work involved in drawing the line attack. }
	var
		rng,t_rad: Integer;	{ Range of line attack, termination radius }
		t_stencil: MapStencil;
		TX,TY: Integer;
	begin
		rng := Range( X , Y , X0 , Y0 );

		t_rad := rng div 3;
		if t_rad > 0 then begin
			ClearStencil( t_stencil );
			DrawBlastEffect( GB , X , Y , Z , T_Rad , T_Stencil );
			for tx := 1 to MaxMapWidth do begin
				for ty := 1 to MaxMapWidth do begin
					if OnTheMap( GB , TX , TY ) and T_Stencil[ TX , TY ] then DrawOneLine( TX , TY , Z , rng );
				end;
			end;
		end else begin
			DrawOneLine( X,Y,Z,rng );
		end;
	end;
var
	TarList,Mek: GearPtr;
	P: Point;
begin
	ClearStencil( Stencil );
	Radius := BlastRadius( GB , ATtacker , AtAt );

	X0 := NAttValue( FindRoot( Attacker )^.NA , NAG_Location , NAS_X );
	Y0 := NAttValue( FindRoot( Attacker )^.NA , NAG_Location , NAS_Y );
	Z0 := MekAltitude( GB , FindRoot( Attacker ) );

	if HasAttackAttribute( AtAt , AA_LineAttack ) then begin
		{ Draw a line from the originator to the target. }
		PlaceLineAttack;

	end else if HasAttackAttribute( AtAt , AA_SwarmAttack ) and ( AtOp > 0 ) then begin
		TarList := GenerateTargetList( GB , Attacker , Nil , X , Y , Z , AtOp , AtAt , False );
		if TarList <> Nil then begin
			Mek := TarList;
			P := GearCurrentLocation( Mek^.Parent );
			PlaceBlastSpot( P.X , P.Y , MekAltitude( GB , Mek^.Parent ) );
			RemoveGear( TarList , Mek );
			Dec( AtOp );
		end else begin
			PlaceBlastSpot( X , Y , Z );
		end;
		if AtOp > 0 then PlaceMultipleBlasts( Radius );

	end else if ( Radius > 0 ) and ( AtOp > 0 ) then begin
		PlaceMultipleBlasts( Radius );
	end else begin
		PlaceBlastSpot( X , Y , Z );
	end;

	Inc( Effects_Event_Order );

	GenerateAttackTemplate := Stencil;
end;

Procedure GiveAwayPosition( GB: GameBoardPtr; Master: GearPtr );
	{ Firing weapons automatically gives away the firer's position. }
var
	EMek: GearPtr;
begin
	EMek := GB^.Meks;
	while EMek <> Nil do begin
		if AreEnemies( GB , EMek , Master ) and not MekCanSeeTarget( GB , EMek , Master ) then begin
			RevealMek( GB , Master , EMek );
		end;
		EMek := Emek^.Next;
	end;
end;

Procedure DoAttack( GB: GameBoardPtr; Attacker,Target: GearPtr; X,Y,Z,AtOp: Integer);
	{ ATTACKER is a weapon. TARGET is a target. X,Y,Z are map coordinates in case }
	{ the target=Nil. }
var
	ER: EffectRequest;
	AtAt,msg: String;
	Stencil: MapStencil;
	TarList,Master: GearPtr;
begin
	{ Clear the attack history and build the effect request. }
	ClearAttackHistory;
	AtAt := WeaponAttackAttributes( Attacker );
	ER := BuildAttackRequest( GB , Attacker , AtOp , X , Y , AtAt );

	{ Add a divider to the skill roll history. }
	SkillCommentDivider;

	{ Now that we have the effect request, see if the Originator is on the PC's team. }
	{ If so, better throw a PCATTACK trigger. }
	if ( ER.Originator <> Nil ) and ( NAttValue( ER.Originator^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam ) then SetTrigger( GB , TRIGGER_PCAttack );

	{ Either generate a template for the attack or generate the list of targets. }
	{ Also, verify that the targets are legal. If NOCALLEDSHOTS applies, take the }
	{ root level parent of the target. }
	if ClearAttack( GB , Attacker , AtOp ) then begin
		if ( Attacker^.G = GG_Module ) or ( Attacker^.S = GS_Melee ) or ( Attacker^.S = GS_EMelee ) then begin
			msg := MsgString( 'XattackswithY' );
		end else begin
			msg := MsgString( 'XfiresY' );
		end;
		msg := ReplaceHash( msg , PilotName( FindRoot( Attacker ) ) );
		if ER.AttackName <> '' then begin
			msg := ReplaceHash( msg , ER.AttackName );
		end else begin
			msg := ReplaceHash( msg , GearName( Attacker ) );
		end;
		RecordAnnouncement( msg );
		StartNewAnnouncement;

		{ Error check- make sure X,Y,Z refer to the correct spots. }
		if Target <> Nil then begin
			X := NAttValue( FindRoot( Target )^.NA , NAG_LOcation , NAS_X );
			Y := NAttValue( FindRoot( Target )^.NA , NAG_LOcation , NAS_Y );
			Z := MekAltitude( GB , FindRoot( Target ) );
		end;

		{ If this weapon has an area effect, generate the stencil here. }
		{ Otherwise, generate the list of targets. }
		if HasAreaEffect( AtAt ) then begin
			Stencil := GenerateAttackTemplate( GB , Attacker , X , Y , Z , AtOp , AtAt );
			ProcessEffect( GB , ER , Stencil , AtOp );
		end else begin
			TarList := GenerateTargetList( GB , Attacker , Target , X , Y , Z , AtOp , AtAt , True );
			if TarList = Nil then begin
				Stencil := GenerateAttackTemplate( GB , Attacker , X , Y , Z , AtOp , AtAt );
				ProcessEffect( GB , ER , Stencil , AtOp );
			end else begin
				ProcessEffect( GB , ER , TarList );
				DisposeGear( TarList );
			end;
		end;

		{ Do the side effects of the attack: set calltime, reveal the }
		{ attacker's position, and update the reactions of other teams. }
		Master := FindRoot( Attacker );
		if Master <> Nil then begin
			{ Set the calltime for the next attack. }
			SetNAtt( Master^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ReactionTime( Master ) );

			GiveAwayPosition( GB , Master );

			{ Update the alleigances of everyone involved. }
			if Target <> Nil then DeclarationOfHostilities( GB , NAttValue( Master^.NA , NAG_Location , NAS_Team ) , NAttValue( FindRoot( Target )^.NA , NAG_Location , NAS_Team ) );
		end;

		{ Perform cleanup duties. }
		PostAttackCleanup( GB , Attacker , X , Y , Z );
	end;

	{ Finalize any pending announcements. }
	FlushAnnouncements;

	{ Get rid of any dynamic resources allocated. }
	FinishEffectRequest( ER );
end;

Procedure DoCharge( GB: GameBoardPtr; Attacker,Target: GearPtr );
	{ ATTACKER is charging TARGET. Do the math. }
	{ Both ATTACKER and TARGET are root level gears of SF:1 or larger. }
	Function ChargeDCBonus( Master: GearPtr ): Integer;
		{ Certain mecha get a bonus to charge attack damage. Calculate }
		{ that here. }
	var
		CDCB: Integer;
		HeavyActuator: Integer;
	begin
		CDCB := 0;
		if Master^.G = GG_Mecha then begin
			{ May also get a bonus from heavy Actuator. }
			HeavyActuator := CountActivePoints( Master , GG_MoveSys , GS_HeavyActuator );
			if HeavyActuator > 0 then CDCB := CDCB + ( HeavyActuator div Master^.V );

			{ Zoanoids get a CC damage bonus. Apply that here. }
			if Master^.S = GS_Zoanoid then begin
				CDCB := CDCB + ZoaDmgBonus;
			end;
		end;
		ChargeDCBonus := CDCB;
	end;
	Function ChargeDC( Master: GearPtr ): Integer;
		{ Return the DC for this charge. }
	begin
		ChargeDC := ( GearMass( Master ) div 8 ) + ChargeDCBonus( Master ) + ( NAttValue( Master^.NA , NAG_Action , NAS_ChargeSpeed ) div 30 );
	end;
var
	ER: EffectRequest;
	FXScript,Msg: String;
begin
	ClearAttackHistory;
	InitEffectRequest( ER );

	ER.FXDice := ChargeDC( Attacker );
	ER.Originator := Attacker;
	ER.Weapon := Attacker;
	ER.FXMod := 2;
	FXScript := '2 3 0 0 SCATTER ' + FX_CanDodge;

	{ Add a divider to the skill roll history. }
	SkillCommentDivider;

	{ If the Originator is on the PC's team, better throw a PCATTACK trigger. }
	if NAttValue( Attacker^.NA , NAG_Location , NAS_Team ) = NAV_DefPlayerTeam then SetTrigger( GB , TRIGGER_PCAttack );

	{ Record the charge announcement. }
	msg := MsgString( 'XchargesY' );
	msg := ReplaceHash( msg , PilotName( Attacker ) );
	msg := ReplaceHash( msg , GearName( Target ) );
	RecordAnnouncement( msg );
	StartNewAnnouncement;

	{ If this attack hits, do a countercharge. }
	if PAG_CauseDamage( GB , FXScript , ER , Target , 0 ) then begin
		PrepAction( GB , Target , NAV_Stop );
		FlushAnnouncements;
		ER.FXDice := ChargeDC( Target ) div 3 + 1;
		ER.Originator := Target;
		ER.Weapon := Target;
		ER.FXMod := 0;
		FXScript := '2 3 0 0 SCATTER ' + FX_CanDodge + ' ' + FX_CanBlock;
		PAG_CauseDamage( GB , FXScript , ER , Attacker , 0 )
	end;

	{ Declare hostilities. }
	DeclarationOfHostilities( GB , NAttValue( Attacker^.NA , NAG_Location , NAS_Team ) , NAttValue( Target^.NA , NAG_Location , NAS_Team ) );

	{ Give away the charger's position. }
	GiveAwayPosition( GB , Attacker );

	{ Finalize any pending announcements. }
	FlushAnnouncements;

	{ Get rid of any dynamic resources allocated. }
	FinishEffectRequest( ER );
end;

Procedure DoReactorExplosion( GB: GameBoardPtr; Victim: GearPtr );
	{ Yay! This mecha is going to blow up. It might not actually be a mecha- maybe }
	{ it's a radioactive rat or a barrel of explosive chemicals or something else. }
const
	Standard_Reactor_Explosion = 'DAMAGE 15 0 0 0 BRUTAL BLAST 1 ' + FX_CanDodge;	{ Cause DAMAGE, Dodge 15 to defend, Brutal }
var
	FX_String: String;
	ER: EffectRequest;
	Area: MapStencil;
	P: Point;
	R: Integer;
	msg: String;
begin
	InitEffectRequest( ER );

	{ Determine the FX_String. This will tell us everything we need to know. }
	FX_String := SAttValue( Victim^.SA , SA_Explosion );
	if FX_String = '' then begin
		{ No custom string. This must be a regular reaction explosion. }
		FX_String := Standard_Reactor_Explosion;
		ER.FXDice := 5 + 3 * MasterSize( Victim );
	end else begin
		{ Custom string. Groovy. The first value should be the intensity of the effect. }
		ER.FXDice := ExtractValue( FX_String );
	end;

	{ Record the explosion announcement. }
	msg := SAttValue( Victim^.SA , 'EXPLOSION_DESC' );
	if msg = '' then msg := MsgString( 'EXPLOSION_DESC' );
	msg := ReplaceHash( msg , GearName( Victim ) );
	RecordAnnouncement( msg );
	StartNewAnnouncement;

	{ Store the primary effect. }
	StoreSAtt( ER.FXList , FX_String );

	{ Determine the non-damaging effects; status FX and the like. }
	AddNonDamagingEffects( FX_String , ER );

	{ Determine the blast radius. This will always be at least 1. }
	R := BlastRadius( GB , Victim , FX_String );
	if R < 1 then R := 1;

	{ Draw the blast radius. }
	ClearStencil( Area );
	P := GearCurrentLocation( Victim );
	DrawBlastEffect( GB , P.X , P.Y , MekAltitude( GB , Victim ) , R , Area );

	ProcessEffect( GB , ER , Area , 0);

	{ Finalize any pending announcements. }
	FlushAnnouncements;

	{ Get rid of any dynamic resources allocated. }
	FinishEffectRequest( ER );
end;

Procedure HandleEffectString( GB: GameBoardPtr; Target: GearPtr; FX_String,FX_Desc: String );
	{ An effect string has been triggered. Better do whatever it says. }
var
	ER: EffectRequest;
begin
	{ Clear the effect history and generate the effect request. }
	ClearAttackHistory;
	InitEffectRequest( ER );
	ER.AttackMessage := FX_Desc;

	{ Add a divider to the skill roll history. }
	SkillCommentDivider;

	ER.FXDice := ExtractValue( FX_String );
	StoreSAtt( ER.FXList , FX_String );

	{ Add status effects here. }
	AddNonDamagingEffects( FX_String , ER );

	DoEffectAgainstGear( GB , ER , Target , 0 );

	{ Finalize any pending announcements. }
	FlushAnnouncements;

	{ Get rid of any dynamic resources allocated. }
	FinishEffectRequest( ER );
end;

Procedure MassEffectString( GB: GameBoardPtr; FX_String,FX_Desc: String );
	{ Do an effect against every last model on the board. Wow. }
var
	ER: EffectRequest;
	M: GearPtr;
begin
	{ Initialize the effect request. }
	ClearAttackHistory;
	InitEffectRequest( ER );
	ER.AttackMessage := FX_Desc;

	{ Add a divider to the skill roll history. }
	SkillCommentDivider;

	ER.FXDice := ExtractValue( FX_String );
	StoreSAtt( ER.FXList , FX_String );

	{ Add status effects here. }
	AddNonDamagingEffects( FX_String , ER );

	{ Loop through all the models on the board, and apply the effect against them. }
	M := GB^.Meks;
	while M <> Nil do begin
		if GearActive( M ) and OnTheMap( GB , M ) then DoEffectAgainstGear( GB , ER , M , 0 );
		M := M^.Next;
	end;

	{ Finalize any pending announcements. }
	FlushAnnouncements;

	{ Get rid of any dynamic resources allocated. }
	FinishEffectRequest( ER );
end;


initialization
	{ Set the history list to 0, for now. }
	ATTACK_History := Nil;
	EFFECTS_Event_Order := 0;

finalization
	DisposeSAtt( ATTACK_History );

end.
