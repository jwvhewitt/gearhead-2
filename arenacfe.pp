unit ArenaCFE;
	{ The Arena Combat Front End. }
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

Procedure Monologue( GB: GameBoardPtr; NPC: GearPtr; Msg: String );

Procedure CombatDisplay( GB: GameBoardPtr );
Procedure BeginTurn( GB: GameBoardPtr; M: GearPtr );


Procedure AttackerFrontEnd( GB: GameBoardPtr; Attacker,Weapon: GearPtr; X,Y,Z,AtOp: Integer );
Procedure AttackerFrontEnd( GB: GameBoardPtr; Attacker,Weapon,Target: GearPtr; AtOp: Integer );
Procedure EffectFrontEnd( GB: GameBoardPtr; Target: GearPtr; FX_String,FX_Desc: String );
Procedure MassEffectFrontEnd( GB: GameBoardPtr; FX_String,FX_Desc: String );
Procedure StatusEffectCheck( GB: GameBoardPtr );


Procedure RandomExplosion( GB: GameBoardPtr );

Procedure AdvanceGameClock( GB: GameBoardPtr; BeQuick,GetHungry: Boolean );
Procedure QuickTime( GB: GameBoardPtr; Time: LongInt );
Procedure TransitTime( GB: GameBoardPtr; Time: LongInt );
Procedure DisplayConsoleHistory( GB: GameBoardPtr );

Procedure SayCombatTaunt( GB: GameBoardPtr; NPC: GearPtr; Msg_Label: String );

Procedure AI_Eject( Mek: GearPtr; GB: GameBoardPtr );
Procedure AI_Surrender( GB: GameBoardPtr; Mek: GearPtr );
Function MightSurrender( GB: GameBoardPtr; NPC: GearPtr ): Boolean;

Procedure DoTaunt( GB: GameBoardPtr; Attacker,Target: GearPtr );

Procedure DoVerbalAttack( GB: GameBoardPtr; Attacker,Target: GearPtr );

Procedure ResolveAfterEffects( GB: GameBoardPtr );

implementation

uses ability,effects,gearutil,ghchars,ghweapon,rpgdice,texutil,movement,
     ui4gh,sysutils,description,action,ghmodule,backpack,
{$IFDEF ASCII}
	vidmap,vidgfx,vidinfo;
{$ELSE}
	sdlgfx,sdlmap,sdlinfo,sdl;
{$ENDIF}

var
	NPC_Chatter_Standard: SAttPtr;


Procedure BattleMapDisplay( GB: GameBoardPtr );
	{ Redraw the display. }
begin
	ClrScreen;
{$IFNDEF ASCII}
	ScrollMap( GB );
{$ENDIF}
	RenderMap( GB );
	RedrawConsole;

{$IFNDEF ASCII}
	if Display_Mini_Map then DisplayMiniMap( GB );
	if Focused_On_Mek <> Nil then DisplayModelStatus( GB , Focused_On_Mek , ZONE_PCStatus );
	if OnTheMap( GB , tile_X , tile_y ) and ( tile_z >= LoAlt ) and ( tile_z <= ( HiAlt + 1 ) ) and ( model_map[ Tile_x , tile_y , tile_z ] <> Nil ) then begin
		QuickModelStatus( GB , model_map[ Tile_x , tile_y , tile_z ] );
	end;
	InfoBox( ZONE_Clock );
{$ELSE}
	if Focused_On_Mek <> Nil then QuickModelStatus( GB , Focused_On_Mek );
	ClockBorder;
{$ENDIF}

	if Tactics_Turn_In_Progess then begin
		TacticsTimeInfo( GB );
	end else begin
		CMessage( TimeString( GB^.ComTime ) , ZONE_Clock , StdWhite );
	end;
{$IFNDEF ASCII}
	Render_Off_Map_Models;
{$ENDIF}
end;

Procedure WorldMapDisplay( GB: GameBoardPtr );
	{ Redraw the world map display. }
var
	PC: GearPtr;
begin
	ClrScreen;
	InfoBox( ZONE_Caption );
	InfoBox( ZONE_SubCaption );
	CMessage( GearName( GB^.Scene ) , ZONE_Caption , StdWhite );
	CMessage( TimeString( GB^.ComTime ) , ZONE_SubCaption , StdWhite );
	PC := GB^.Meks;
	while ( PC <> Nil ) and ( NAttValue( PC^.NA , NAG_Location , NAS_Team ) <> NAV_DefPlayerTeam ) do PC := PC^.Next;
	if PC <> Nil then RenderWorldMap( GB , PC , NAttValue(PC^.NA , NAG_Location , NAS_X ) , NAttValue(PC^.NA , NAG_Location , NAS_Y ) );
	RedrawConsole;
end;

Procedure CombatDisplay( GB: GameBoardPtr );
	{ Redraw the display. }
begin
	if ( GB = Nil ) then begin
		ClrScreen;
	end else if ( GB^.Scene <> Nil ) and ( GB^.Scene^.G = GG_World ) then begin
		WorldMapDisplay( GB );
	end else begin
		BattleMapDisplay( GB );
	end;
end;

Procedure BeginTurn( GB: GameBoardPtr; M: GearPtr );
	{ A player-controlled model is starting their tactics turn. Let the player }
	{ know whose turn it is, and away to go. }
const
	Scroll_Step = 0.3;
var
{$IFNDEF ASCII}
	P: Point;
{$ENDIF}
	A: Char;
	msg: String;
begin
	msg := ReplaceHash( MsgString( 'BEGIN_TACTICS_TURN' ) , PilotName( M ) );
	FocusOn( M );

	repeat
		CombatDisplay( GB );
		InfoBox( ZONE_Caption );
		GameMsg( msg , ZONE_Caption , InfoHilight );
		DoFlip;

		A := RPGKey;
	until IsMoreKey( A );
end;

Function DisplayAnnouncements( N: Integer ): Boolean;
	{ Display all the announcements stored for sequence slice N. }
	{ Return TRUE if an announcement was found, or FALSE otherwise. }
var
	L: String;
	A: SAttPtr;
	MessageFound: Boolean;
begin
	A := ATTACK_History;
	MessageFound := False;

	L := 'ANNOUNCE_' + BStr( N ) + '_';

	while A <> Nil do begin
		if HeadMatchesString( L , A^.Info ) then begin
			MessageFound := True;
			DialogMsg( RetrieveAString( A^.Info ) );
		end;
		A := A^.Next;
	end;

	DisplayAnnouncements := MessageFound;
end;


Procedure ProcessAnimations( GB: GameBoardPtr; var AnimList: GearPtr );
	{ Display all the queued animations, deleting them as we go along. }
var
	AnimOb,A2: GearPtr;
	DelayThisFrame,PointDelay: Boolean;
begin
	{ Keep processing until we run out of animation objects. }
	while AnimList <> Nil do begin
		{ Erase all current image overlays. }
		ClearOverlays;

		AnimOb := AnimList;

		{ Assume there'll be no animation delay, unless }
		{ otherwise requested. }
		DelayThisFrame := False;

		while AnimOb <> Nil do begin
			A2 := AnimOb^.Next;

			{ Call a routine based upon the type of }
			{ animation requested. }
			case AnimOb^.S of

			GS_Shot: PointDelay := ProcessShotAnimation( GB , AnimList , AnimOb ) or DelayThisFrame;
			GS_DamagingHit: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );
			GS_ArmorDefHit: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );
			GS_Parry: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );
			GS_Dodge: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );
			GS_Backlash: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );
			GS_AreaAttack: PointDelay := ProcessPointAnimation( GB , AnimList , AnimOb );

			{ If no routine was found to deal with the animation }
			{ requested, just delete the gear. }
			else RemoveGear( AnimList , AnimOb );
			end;

			DelayThisFrame := DelayThisFrame or PointDelay;

			{ Move to the next animation. }
			AnimOb := A2;
		end;

		{ Delay the animations, if appropriate. }
		if DelayThisFrame then begin
			CombatDisplay( GB );
			DoFlip;
{$IFDEF ASCII}
			if ( FrameDelay > 0 ) then Sleep(FrameDelay);
{$ELSE}
			if ( FrameDelay > 0 ) then SDL_Delay(FrameDelay);
{$ENDIF}
		end;
	end;

	ClearOverlays;
{	CombatDisplay( GB );
	DoFlip;}
end;

Function DisplayEffectAnimations( GB: GameBoardPtr; N: Integer ): Boolean;
	{ Display all the animations stored for sequence slice N. }
	{ Return TRUE if an animation was found, or FALSE otherwise. }
var
	A: SAttPtr;
	T: Integer;
	AnimFound: Boolean;
	AnimList,AnimItem: GearPtr;
	AnimLabel,AnimCode: String;
begin
	A := ATTACK_History;
	AnimFound := False;
	AnimList := Nil;

	AnimLabel := SATT_Anim_Direction + BStr( N ) + '_';

	{ Start by creating the animation list. }
	while A <> Nil do begin
		if HeadMatchesString( AnimLabel , A^.Info ) then begin
			AnimFound := True;

			{ Insert animation handling code here. }
			AnimItem := AddGear( AnimList , Nil );
			AnimCode := RetrieveAString( A^.Info );
			AnimItem^.S := ExtractValue( AnimCode );

			T := 1;
			while ( AnimCode <> '' ) and ( T <= NumGearStats ) do begin
				AnimItem^.Stat[ T ] := ExtractValue( AnimCode );
				Inc( T );
			end;
		end;
		A := A^.Next;
	end;

	{ Process each animation. }
	ProcessAnimations( GB , AnimList );

	DisplayEffectAnimations := AnimFound;
end;


Procedure Display_Effect_History( GB: GameBoardPtr );
	{ Display all the messages stored by the attack routines and show all the }
	{ animations requested. }
var
	N: Integer;
	NoAnnounce,NoAnim: Boolean;
begin
	N := 0;

	{ Just keep going until we reach an iteration at which there are no more animations and }
	{ no more announcements to display. That's how we know that we're finished. }
	repeat
		NoAnnounce := Not DisplayAnnouncements( N );
		NoAnim := not DisplayEffectAnimations( GB , N );

		Inc( N );
{ Pump the events after the loop to keep Windows from doing the "Not Responding" }
{ thing during long enemy turns- thanks Buffered. }
{$IFNDEF ASCII}
		if ( N mod 3 ) = 0 then SDL_PumpEvents();
{$ENDIF}
	until NoAnnounce and NoAnim;

end;

Function CloneMap( GB: GameBoardPtr ): GameBoardPtr;
	{ Copy the map and all its contents. }
var
	FakeGB: GameBoardPtr;
	mek,FakeMek: GearPtr;
begin
	FakeGB := NewMap( GB^.Map_Width , GB^.Map_Height );
	FakeGB^.ComTime := GB^.ComTime;
	FakeGB^.Scale := GB^.Scale;
	FakeGB^.map := GB^.Map;
	FakeGB^.Scene := GB^.Scene;
	FakeGB^.Camp := GB^.Camp;

	mek := GB^.Meks;
	while mek <> Nil do begin
		FakeMek := CloneGear( Mek );
		AppendGear( FakeGB^.Meks , FakeMek );
		Mek := Mek^.Next;
	end;

	CloneMap := FakeGB;
end;

Procedure DisposeMapClone( FakeGB: GameBoardPtr );
	{ Get rid of the fake map. }
begin
	FakeGB^.Scene := Nil;
	DisposeMap( FakeGB );
end;

Procedure AttackerFrontEnd( GB: GameBoardPtr; Attacker,Weapon: GearPtr; X,Y,Z,AtOp: Integer );
	{ This is a front end for the ATTACKER procedures. It calls those }
	{ procedures, and also informs the player of what's going on }
	{ both textually (description) and visually (graphics). }
var
	FakeGB: GameBoardPtr;
begin
	{ Generate a fake gameboard to be used for screen output. }
	FakeGB := CloneMap( GB );

	{ Actually do the attack. }
	DoAttack(GB,Weapon,Nil,X,Y,Z,AtOp);

	{ Report the effect of the attack. }
	Display_Effect_History( FakeGB );
	DisposeMapClone( FakeGB );

	{ Resolve any crashes resulting from the attack. }
	ResolveAfterEffects( GB );

	{ AT the end, redisplay the map. }
	CombatDisplay( GB );
end;

Procedure AttackerFrontEnd( GB: GameBoardPtr; Attacker,Weapon,Target: GearPtr; AtOp: Integer );
	{ This is a front end for the ATTACKER procedures. It calls those }
	{ procedures, and also informs the player of what's going on }
	{ both textually (description) and visually (graphics). }
var
	FakeGB: GameBoardPtr;
begin
	{ Generate a fake gameboard to be used for screen output. }
	FakeGB := CloneMap( GB );

	{ Actually do the attack. }
	DoAttack(GB,Weapon,Target,0,0,0,AtOp);

	{ Report the effect of the attack. }
	Display_Effect_History( FakeGB );
	DisposeMapClone( FakeGB );

	{ Resolve any crashes resulting from the attack. }
	ResolveAfterEffects( GB );

	{ AT the end, redisplay the map. }
	CombatDisplay( GB );
end;

Procedure EffectFrontEnd( GB: GameBoardPtr; Target: GearPtr; FX_String,FX_Desc: String );
	{ An effect string has just been triggered. Call the effect handler, }
	{ then display the outcome for the user. }
begin
	HandleEffectString( GB , Target , FX_String , FX_Desc );
	Display_Effect_History( GB );

	{ Resolve any crashes resulting from the effect. }
	ResolveAfterEffects( GB );
end;

Procedure MassEffectFrontEnd( GB: GameBoardPtr; FX_String,FX_Desc: String );
	{ An effect string has just been triggered. Call the effect handler, }
	{ then display the outcome for the user. }
begin
	MassEffectString( GB , FX_String , FX_Desc );
	Display_Effect_History( GB );

	{ Resolve any crashes resulting from the effect. }
	ResolveAfterEffects( GB );
end;

Procedure RandomExplosion( GB: GameBoardPtr );
	{ Stick a random explosion somewhere on the map. This procedure is used by the }
	{ BOMB ASL command. }
var
	X,Y: Integer;
begin
	X := Random( GB^.MAP_Width ) + 1;
	Y := Random( GB^.MAP_HEIGHT ) + 1;
	Explosion( GB , X , Y , 5 , 8 );

	{ Report the effect of the attack. }
	Display_Effect_History( GB );

	{ Resolve any crashes resulting from the effect. }
	ResolveAfterEffects( GB );
end;

Procedure StatusEffectCheck( GB: GameBoardPtr );
	{ Check all status effects, removing those which have expired }
	{ and performing effects for those which haven't. }
	{ This will also deal with a mecha's OVERLOAD condition, since }
	{ I want the count decremented every 3 minutes or so and it }
	{ would be inefficient to loop through the list twice. }
var
	M: GearPtr;
	FX,FX2: NAttPtr;
begin
	M := GB^.Meks;
	while M <> Nil do begin
		if GearActive( M ) and OnTheMap( GB , M ) then begin
			FX := M^.NA;
			while FX <> Nil do begin
				FX2 := FX^.Next;
				if ( FX^.G = NAG_StatusEffect ) and ( FX^.S >= 1 ) and ( FX^.S <= Num_Status_FX )then begin
					if SX_Effect_String[ FX^.S ] <> '' then begin
						EffectFrontEnd( GB , M , SX_Effect_String[ FX^.S ] , MSgString( 'Status_FXDesc' + BStr( FX^.S ) ) );
					end;

					if ( FX^.V > 0 ) and ( SX_ResistTarget[ FX^.S ] = -1 ) then begin
						{ Set rate of diminishment }
						if Random( 2 ) = 1 then Dec( FX^.V );
						if FX^.V = 0 then SetNAtt( M^.NA , NAG_StatusEffect , FX^.S , 0 );
					end else if ( FX^.V > 0 ) and ( SX_ResistTarget[ FX^.S ] > 0 ) and ( RollStep( SkillValue( M , NAS_Toughness , STAT_Ego ) ) > SX_ResistTarget[ FX^.S ] ) then begin
						{ Diminishment determined by RESISTANCE }
						Dec( FX^.V );
						if FX^.V = 0 then SetNAtt( M^.NA , NAG_StatusEffect , FX^.S , 0 );
					end;
				end;
				FX := FX2;
			end;
		end;

		M := M^.Next;
	end;
end;

Procedure CyberneticsCheck( PC: GearPtr );
	{ Update the cybernetic trauma score for the PC. }
const
	Num_Disfunction = 12;
	Dis_Index: Array [1..Num_Disfunction] of Byte = (
		6,7,8,9,10, 11,12,13,14,15, 16,17
	);
	Dis_Cost: Array [1..Num_Disfunction] of Byte = (
		30,35,45,50,55, 60,65,70,80,85, 90,95
	);
var
	TT: Integer;	{ Total Trauma }
	SC: GearPtr;	{ Sub-Components of PC; looking for cyberware. }
	N: Integer;	{ Number of implants. }
	D: Integer;	{ Disfunction # }
begin
	{ To start with, add up all the trauma points the PC has. }
	TT := 0;
	N := 0;
	SC := PC^.SubCom;
	while SC <> Nil do begin
		if ( SC^.G = GG_Modifier ) and ( SC^.V = GV_CharaModifier ) then begin
			TT := TT + TraumaValue( SC );
		end;
		SC := SC^.Next;
	end;

	{ Reduce the total trauma by Ego/4, and reduce further if Cybertech talent known. }
	TT := TT - ( CStat( PC , STAT_Ego ) div 4 ) - Random( 2 );
	if HasTalent( PC , NAS_Extropian ) then TT := TT - 5;

	{ If there is any trauma, the PC must make a skill roll against it. }
	if TT > 0 then begin
		AddNAtt( PC^.NA , NAG_Condition , NAS_CyberTrauma , 1 );
		if RollStep( SkillValue( PC , NAS_Toughness , STAT_Ego ) ) < ( TT + 5 ) then AddNAtt( PC^.NA , NAG_Condition , NAS_CyberTrauma , 1 );

		{ If the PC has enough trauma points to consider }
		{ getting a disfunction, deal with that now. }
		if ( NAttValue( PC^.NA , NAG_Condition , NAS_CyberTrauma ) > 72 ) and ( Random( 3 ) = 1 ) then begin
			{ Select a disfunction at random. The PC might }
			{ get this if he doesn't already have it and }
			{ if it's cheap enough. }
			D := Random( Num_Disfunction ) + 1;
			if ( NAttValue( PC^.NA , NAG_StatusEffect , Dis_Index[ D ] ) = 0 ) and ( Random( NAttValue( PC^.NA , NAG_Condition , NAS_CyberTrauma ) ) > Dis_Cost[ D ] ) then begin
				SetNAtt( PC^.NA , NAG_StatusEffect , Dis_Index[ D ] , -1 );
				SetNAtt( PC^.NA , NAG_Condition , NAS_CyberTrauma , NAttValue( PC^.NA , NAG_Condition , NAS_CyberTrauma ) div 2 );
				DialogMsg( ReplaceHash( MsgString( 'Disfunction_' + BStr( D ) ) , GearName( PC ) ) );
			end;
		end;
	end;
end;

Procedure RegenerationCheck( MList: GearPtr; BeQuick,GetHungry: Boolean );
	{ Go through MList and all siblings and all children. Any gears }
	{ found which are of type MEAT will recover one point of damage, }
	{ if damaged. }
	{ If BEQUICK, don't do a cybernetics check because the PC doesn't have any chance to }
	{ go see a doctor. }
const
	STAMINA_CHANCE = 30;	{ Determines speed of Stamina/Mental recovery. }
var
	MAT,Drain,Recovery,N,Morale: Integer;
	PCTeam,CanRegen: Boolean;
begin
	while MList <> Nil do begin
		PCTeam := ( NAttValue( MList^.NA , NAG_Location , NAS_Team ) = 1 ) and ( MList^.G = GG_Character );
		if PCTeam then Morale := NAttValue( MList^.NA , NAG_Condition , NAS_MoraleDamage );

		CanRegen := NAttValue( MList^.NA , NAG_StatusEffect , NAS_Anemia ) = 0;

		{ Whether or not a gear can regenerate is determined }
		{ by its material. }
		MAT := NAttValue( MList^.NA , NAG_GearOps , NAS_Material );
		if ( MAT < 0 ) or ( MAT > NumMaterial ) then MAT := 0;

		if MAT_Regenerate[ MAT ] and NotDestroyed( MList ) and CanRegen then begin
			{ If there's any HP damage, regenerate a point. }
			if ( NAttValue( MList^.NA , NAG_Damage , NAS_StrucDamage ) > 0 ) and ( Random( 200 ) < GearMaxDamage( MList ) ) then begin
				AddNAtt( MList^.NA , NAG_Damage , NAS_StrucDamage , -1 );
				if PCTeam then AddMoraleDmg( MList , MORALE_HPRegen );
			end;

			{ Natural armor heals *MUCH* more slowly than normal HP damage. }
			if ( NAttValue( MList^.NA , NAG_Damage , NAS_ArmorDamage ) > 0 ) and ( Random( 500 ) < GearMaxArmor( MList ) ) then begin
				AddNAtt( MList^.NA , NAG_Damage , NAS_ArmorDamage , -1 );
				if PCTeam then AddMoraleDmg( MList , MORALE_HPRegen );
			end;
		end;

		{ Also attempt to regenerate SP and MP here. }
		if MList^.G = GG_Character then begin
			Drain := NAttValue( MList^.NA , NAG_Condition , NAS_StaminaDown );
			if ( Drain > 0 ) and CanRegen then begin
				Recovery := 0;
				N := CharStamina( MList );
				if N > STAMINA_CHANCE then begin
					Recovery := N div STAMINA_CHANCE;
					N := N mod STAMINA_CHANCE;
				end;
				if Random( STAMINA_CHANCE ) <= N then Inc( Recovery );
				if Recovery > Drain then Recovery := Drain;
				AddNAtt( MList^.NA , NAG_Condition , NAS_StaminaDown , -Recovery );
				if PCTeam and ( Random( 8 ) = 1 ) then AddMoraleDmg( MList , 1 );
			end;

			Drain := NAttValue( MList^.NA , NAG_Condition , NAS_MentalDown );
			if ( Drain > 0 ) and CanRegen then begin
				Recovery := 0;
				N := CharMental( MList );
				if N > STAMINA_CHANCE then begin
					Recovery := N div STAMINA_CHANCE;
					N := N mod STAMINA_CHANCE;
				end;
				if Random( STAMINA_CHANCE ) <= N then Inc( Recovery );
				if Recovery > Drain then Recovery := Drain;
				AddNAtt( MList^.NA , NAG_Condition , NAS_MentalDown , -Recovery );
				if PCTeam and ( Random( 8 ) = 1 ) then AddMoraleDmg( MList , 1 );
			end;

			{ Characters also get hungry... }
			if PCTeam and GetHungry then begin
				AddNAtt( MList^.NA , NAG_Condition , NAS_Hunger , 1 );
				if NAttValue( MList^.NA , NAG_Condition , NAS_Hunger ) > Hunger_Penalty_Starts then begin
					DialogMsg( ReplaceHash( MsgString( 'REGEN_Hunger' ) , GearName( MList ) ) );
				end;

				{ Check for the cyber-disfunctions Depression, }
				{ Rejection, and Irrational ANger here. }
				if NAttValue( MList^.NA , NAG_StatusEffect , NAS_Rejection ) <> 0 then begin
					{ A character suffering REJECTION earns one extra trauma point per regen check. }
					AddNAtt( MList^.NA , NAG_Condition , NAS_CyberTrauma , 1 );
				end;
				if NAttValue( MList^.NA , NAG_StatusEffect , NAS_Depression ) <> 0 then begin
					{ A depressed character always loses morale. }
					AddMoraleDmg( MList , 1 );
				end;
				if NAttValue( MList^.NA , NAG_StatusEffect , NAS_Anger ) <> 0 then begin
					{ An angry character might pick up Villainous reputation. }
					if Random( 50 ) = 1 then AddReputation( MList , 1 , -1 );
				end;

				{ If nothing happened this regen check to make }
				{ the PC feel worse, morale moves one point }
				{ closer to zero. }
				if ( Random( 2 ) = 1 ) and ( Morale = NAttValue( MList^.NA , NAG_Condition , NAS_MoraleDamage ) ) then begin
					if Morale > 0 then begin
						AddNAtt( MList^.NA , NAG_Condition , NAS_MoraleDamage , -1 );
					end else if Morale < 0 then begin
						AddNAtt( MList^.NA , NAG_Condition , NAS_MoraleDamage , 1 );
					end;
				end;

				{ Check the PC's cyberware... }
				if not BeQuick then CyberneticsCheck( MList );
			end;
		end;

		{ Check the children - InvCom and SubCom. }
		RegenerationCheck( MList^.InvCom , BeQuick , GetHungry );
		RegenerationCheck( MList^.SubCom , BeQuick , GetHungry );

		{ Move to the next sibling. }
		MList := MList^.Next;
	end;
end;

Procedure ReduceOverload( GB: GameBoardPtr );
	{ Mecha lose one point of power overload every 10 seconds. }
	Procedure CheckOverloadAlongPath( M: GearPtr );
	begin
		while M <> Nil do begin
			{ Decrease OVERLOAD by 1 every 10 seconds }
			if NAttValue( M^.NA , NAG_Condition , NAS_PowerSpent ) > 0 then begin
				AddNAtt( M^.NA , NAG_Condition , NAS_PowerSpent , -1 );
			end;
			CheckOverloadAlongPath( M^.SubCom );
			CheckOverloadAlongPath( M^.InvCom );
			M := M^.Next;
		end;
	end;
begin
	CheckOverloadAlongPath( GB^.Meks );
end;

Procedure AdvanceGameClock( GB: GameBoardPtr; BeQuick,GetHungry: Boolean );
	{ Increment the game clock and do any checks that need to be }
	{ done. }
	{ Set BEQUICK to TRUE in order to skip the 5min and halfhour triggers. }
begin
	Inc( GB^.ComTime );

	if (( GB^.Comtime mod AP_5Minutes ) = 0) and not BeQuick then SetTrigger( GB , TRIGGER_FiveMinutes );
	if (( GB^.Comtime mod AP_HalfHour ) = 0) and not BeQuick then SetTrigger( GB , TRIGGER_HalfHour );
	if ( GB^.Comtime mod AP_Hour ) = 0 then SetTrigger( GB , TRIGGER_Hour );
	if ( GB^.Comtime mod AP_Quarter ) = 0 then SetTrigger( GB , TRIGGER_Quarter );

	{ Restore lost power every 10 seconds. }
	if ( GB^.ComTime mod 10 ) = 0 then begin
		ReduceOverload( GB );
	end;

	{ Once every 10 minutes, living gears regenerate. }
	if ( GB^.ComTime mod AP_10minutes ) = 0 then begin
		RegenerationCheck( GB^.Meks , BeQuick , GetHungry );
	end;

	{ Once every 3 minutes, update the status effects. }
	if ( GB^.ComTime mod AP_3minutes ) = 97 then StatusEffectCheck( GB );
end;

Procedure QuickTime( GB: GameBoardPtr; Time: LongInt );
	{ Advance time quickly by the specified amount. }
begin
	while Time > 0 do begin
		Dec( Time );
		AdvanceGameClock( GB , True , True );
	end;
end;

Procedure TransitTime( GB: GameBoardPtr; Time: LongInt );
	{ Advance time quickly by the specified amount. }
	{ During this time the PC will not get hungry. }
begin
	while Time > 0 do begin
		Dec( Time );
		AdvanceGameClock( GB , True , False );
	end;
end;

Procedure DisplayConsoleHistory( GB: GameBoardPtr );
	{ Display the console history, then restore the display. }
begin
	MoreText( Console_History , MoreHighFirstLine( Console_History ) );
	CombatDisplay( GB );
end;

Function GetTauntString( NPC: GearPtr; Msg_Label: String ): String;
	{ Determine an appropriate string for the type of taunt requested. }
var
	MList: SAttPtr;
	Procedure HarvestMessages( LList: SAttPtr; head: String );
		{ Look through LList and collect all strings that match HEAD. }
	var
		M: SAttPtr;
	begin
		M := LList;
		while M <> Nil do begin
			if HeadMatchesString( head , M^.Info ) then StoreSAtt( MList , RetrieveAString( M^.Info ) );
			M := M^.Next;
		end;
	end;
var
	T,V: Integer;
	msg: String;
begin
	{ Start with an error check. }
	NPC := LocatePilot( NPC );
	if NPC = Nil then Exit( '' );

	{ Initialize our message list to NIL. }
	MList := Nil;

	{ First, search through NPC itself looking for appropriate messages. }
	HarvestMessages( NPC^.SA , msg_label );

	{ Next, pick some contenders from the standard chatter list. }
	{ Only characters with CIDs get this. }
	HarvestMessages( NPC_Chatter_Standard , msg_label + '_ALL' );

	for t := 1 to Num_Personality_Traits do begin
		V := NAttValue( NPC^.NA , NAG_CharDescription , -T );
		if V > 0 then begin
			HarvestMessages( NPC_Chatter_Standard , msg_label + '_T' + BStr( T ) + '+' );
		end else if V < 0 then begin
			HarvestMessages( NPC_Chatter_Standard , msg_label + '_T' + BStr( T ) + '-' );
		end;
	end;

	if MList <> Nil then begin
		msg := SelectRandomSAtt( MList )^.Info;
		DisposeSAtt( MList );
	end else begin
		msg := '';
	end;

	GetTauntString := msg;
end;

Procedure SayCombatTaunt( GB: GameBoardPtr; NPC: GearPtr; Msg_Label: String );
	{ NPC is going to say something... maybe. Search the NPC gear for things to say, }
	{ then search the standard chatter list for things to say, then pick one of them }
	{ and say it. }
	{ Note that this will not nessecarily be an actual taunt. It's more likely to be }
	{ something completely different... but I didn't feel like calling this procedure }
	{ "NPC_Mutters"... }
var
	msg: String;
begin
	{ Make sure we have a proper NPC, and not a mecha. }
	NPC := LocatePilot( NPC );
	if NPC = Nil then Exit;

	{ Make sure combat taunts are enabled. }
	if No_Combat_Taunts then begin
		SetNAtt( FindRoot( NPC )^.NA , NAG_EpisodeData , NAS_ChatterRecharge , GB^.ComTime + ( 2500 div CStat( NPC , STAT_Charm ) ) );
		Exit;
	end;

	{ If at least one phrase was found, and the NPC is visible, it can say something. }
	if NotAnAnimal( NPC ) and ( ( Msg_Label = 'CHAT_EJECT' ) or ( NAttValue( NPC^.NA , NAG_Personal , NAS_CID ) <> 0 ) ) then begin
		if ( ( Msg_Label = 'CHAT_EJECT' ) or MekVisible( GB , FindRoot( NPC ) ) ) then begin
			msg := GetTauntString( NPC , Msg_Label );
			if msg <> '' then DialogMsg( '[' + GearName( NPC ) + ']: ' + msg );
		end;
	end;

	{ Add the chatter recharge time. }
	SetNAtt( FindRoot( NPC )^.NA , NAG_EpisodeData , NAS_ChatterRecharge , GB^.ComTime + ( 2500 div CStat( NPC , STAT_Charm ) ) );
end;

Procedure Monologue( GB: GameBoardPtr; NPC: GearPtr; Msg: String );
	{ NPC is about to deliver a line. }
var
	A: Char;
begin
	NPC := LocatePilot( NPC );
	repeat
		CombatDisplay( GB );
		DoMonologueDisplay( GB , NPC , Msg );
		DoFlip;

		A := RPGKey;
	until IsMoreKey( A );

	DialogMsg( '[' + PilotName( NPC ) + ']: ' + Msg );
end;

Procedure AI_Eject( Mek: GearPtr; GB: GameBoardPtr );
	{ This NPC is ejecting from his mecha! }
var
	Pilot: GearPtr;
	Msg: String;
begin
	{ Better set the following triggers. }
	SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) ) );
	SetTrigger( GB , TRIGGER_UnitEliminated + BStr( NAttValue( Mek^.NA , NAG_EpisodeData , NAS_UID ) ) );

	repeat
		Pilot := ExtractPilot( Mek );

		if Pilot <> Nil then begin
			Msg := GetTauntString( Pilot , 'CHAT_EJECT' );
			Monologue( GB , Pilot , Msg );
			DialogMsg( ReplaceHash( MsgString( 'EJECT_AI' ) , GearName( Pilot ) ) );
			DeployGear( GB , Pilot , False );
		end;
	until Pilot = Nil;
end;

Procedure AI_Surrender( GB: GameBoardPtr; Mek: GearPtr );
	{ This NPC is surrendering! }
var
	Msg: String;
begin
	{ Better set the following triggers. }
	SetTrigger( GB , TRIGGER_NumberOfUnits + BStr( NAttValue( Mek^.NA , NAG_Location , NAS_Team ) ) );
	SetTrigger( GB , TRIGGER_UnitEliminated + BStr( NAttValue( Mek^.NA , NAG_EpisodeData , NAS_UID ) ) );

	if NAttValue( Mek^.NA , NAG_Personal , NAS_CID ) <> 0 then begin
		SetTrigger( GB , TRIGGER_NPCSurrendered + BStr( NAttValue( Mek^.NA , NAG_Personal , NAS_CID ) ) );
	end;

	Msg := GetTauntString( Mek , 'CHAT_SURRENDER' );
	Monologue( GB , Mek , Msg );

	DialogMsg( ReplaceHash( MsgString( 'SURRENDER_AI' ) , GearName( Mek ) ) );

	SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_SurrenderStatus , NAV_NowSurrendered );
end;

Function MightEject( Mek: GearPtr ): Boolean;
	{ Return TRUE if it's possible that MEK might eject given its }
	{ current situation, or FALSE otherwise. }
begin
	MightEject := GearActive( Mek ) and ( ( PercentDamaged( Mek ) < 75 ) or not HasAtLeastOneValidMovemode( Mek ) );
end;

Function CapableOfSurrender( GB: GameBoardPtr; NPC: GearPtr ): Boolean;
	{ This model might surrender, sometime, under some circumstances, not necessarily these. }
begin
	CapableOfSurrender := GearActive( NPC ) and AreEnemies(GB,NAttValue(NPC^.NA,NAG_Location,NAS_Team),NAV_DefPlayerTeam) and (NAttValue(NPC^.NA,NAG_EpisodeData,NAS_SurrenderStatus) = 0) and NotAnAnimal( NPC );
end;

Function MightSurrender( GB: GameBoardPtr; NPC: GearPtr ): Boolean;
	{ Return TRUE if it's possible that NPC might surrender given its }
	{ current situation, or FALSE otherwise. }
begin
	MightSurrender := CapableOfSurrender( GB , NPC ) and (( CurrentStamina(NPC) = 0 ) or ( GearCurrentDamage( NPC ) < Random( 6 ) ));
end;

Function HasAtLeastOneValidWeapon( Mek: GearPtr ): Boolean;
	{ Return TRUE if this mecha has at least one weapon capable of being used, }
	{ or FALSE if all of its weapons have been destroyed/run out of ammo/otherwise }
	{ neutralized. }
var
	HALOVW: Boolean;
	Procedure CheckVWAlongPath( LList: GearPtr );
		{ Check along this path, recursing through children, looking }
		{ for at least one valid weapon. }
	begin
		while ( llist <> Nil ) and not HALOVW do begin
			if NotDestroyed( llist ) then begin
				if LList^.G = GG_Weapon then begin
					{ This could be it! It's a weapon, and it's not destroyed... }
					{ The only thing that could hold us back now is ammo. }
					if ( LList^.S = GS_Ballistic ) or ( LList^.S = GS_Missile ) then begin
						HALOVW := LocateGoodAmmo( LList ) <> Nil;
					end else begin
						{ No ammo, but don't need ammo. }
						HALOVW := True;
					end;
				end;
				if not HALOVW then begin
					CheckVWAlongPath( llist^.subcom );
					CheckVWAlongPath( llist^.invcom );
				end;
			end;
			llist := llist^.Next;
		end;
	end;
begin
	{ Assume FALSE until shown TRUE. }
	HALOVW := False;

	{ Check the subcoms. }
	CheckVWAlongPath( Mek^.SubCom );

	{ Return the result. }
	HasAtLeastOneValidWeapon := HALOVW;
end;

Function ShouldEject( Mek: GearPtr; GB: GameBoardPtr ): Boolean;
	{ Return TRUE if this mecha should eject, or FALSE otherwise. }
var
	Dmg,PrevDmg,Intimidation,LeaderShip,TeamID: Integer;
	Team: GearPtr;
begin
	{ Error check- members of the PC team never eject. }
	TeamID := NAttValue( Mek^.NA , NAG_Location , NAS_Team );
	if TeamID = NAV_DefPlayerTeam then Exit( False );

	{ Calculate the Intimidation and Leadership values. }
	Intimidation := 5;
	Leadership := TeamSkill( GB , TeamID , NAS_Intimidation , STAT_Ego );
	if GB^.Scene <> Nil then begin
		Team := GB^.Scene^.SubCom;
		while Team <> Nil do begin
			if ( Team^.S <> TeamID ) and AreAllies( GB , Team^.S , TeamID ) then begin
				Dmg := TeamSkill( GB , Team^.S , NAS_Concentration , STAT_Ego );
				if Dmg > Leadership then Leadership := Dmg;
			end else if ( Team^.S <> TeamID ) and AreEnemies( GB , Team^.S , TeamID ) then begin
				Dmg := TeamSkill( GB , Team^.S , NAS_Intimidation , STAT_Ego );
				if Dmg > Intimidation then Intimidation := Dmg;
			end;
			Team := Team^.Next;
		end;
	end;

	Dmg := PercentDamaged( Mek );
	if not HasAtLeastOneValidWeapon( Mek ) then Dmg := Dmg - 15;
	PrevDmg := 100 - NAttValue( Mek^.NA , NAG_EpisodeData , NAS_PrevDamage );
	SetNAtt( Mek^.NA , NAG_EpisodeData , NAS_PrevDamage , 100 - DMG );
	if MightEject( Mek ) and ( DMG < PrevDmg ) then begin
		if CurrentMoveRate( GB^.Scene , Mek ) = 0 then Dmg := Dmg - 25;
 		ShouldEject := Dmg < ( Random( 65 ) + RollStep( Intimidation ) - RollStep( Leadership ) );

	end else ShouldEject := False;
end;

Function ShouldSurrender( GB: GameBoardPtr; NPC: GearPtr ): Boolean;
	{ Check to see whether or not NPC should surrender. Surrender should take place }
	{ if the following conditions are met: The NPC has no stamina left, the NPC is }
	{ an enemy of Team1, the NPC has not previously surrendered, the NPC is not an }
	{ animal, }
	{ ...and Team1 can manage an intimidation roll. }
	{ Surrender will be automatic if 50% of a target's limbs are destroyed. }
	Function BlackKnightSituation: Boolean;
		{ The Black Knight situation happens when 50% or more of a target's limbs are }
		{ disabled. Any rational person would surrender then. It's not just a flesh wound. }
	var
		limb: GearPtr;
		total,d_total: Integer;
	begin
		total := 0;
		d_total := 0;
		limb := NPC^.SubCom;
		while limb <> Nil do begin
			if Limb^.G = GG_Module then begin
				inc( Total );
				if Destroyed( Limb ) then Inc( D_total );
			end;
			limb := limb^.Next;
		end;
		BlackKnightSituation := ( Total > 0 ) and ( D_total >= ( Total div 2 ) );
	end;
var
	SkRank,NPC_Stamina,Dmg,PrevDmg: Integer;
begin
	if Destroyed( NPC ) then Exit( False );

	Dmg := PercentDamaged( NPC );
	NPC_Stamina := CurrentStamina(NPC);
	if NPC_Stamina = 0 then Dmg := Dmg - 5;
	PrevDmg := 100 - NAttValue( NPC^.NA , NAG_EpisodeData , NAS_PrevDamage );
	SetNAtt( NPC^.NA , NAG_EpisodeData , NAS_PrevDamage , 100 - DMG );
	if BlackKnightSituation and CapableOfSurrender( GB , NPC ) then begin
		ShouldSurrender := True;
	end else if ( DMG < PrevDmg ) and MightSurrender( GB , NPC ) then begin
		SkRank := TeamSkill( GB , NAV_DefPlayerTeam , NAS_Intimidation , STAT_Ego );
		PrevDmg := GearCurrentDamage( NPC );
		if PrevDmg < 10 then SkRank := SkRank + 15 - PrevDmg;
		ShouldSurrender := RollStep( SkRank ) > ( CStat( NPC , STAT_Ego ) + Dmg div 10 );
	end else begin
		ShouldSurrender := False;
	end;
end;

Procedure ResolveAfterEffects( GB: GameBoardPtr );
	{ Check the gameboard for mecha which have either crashed or charged. }
	{ 1. Charge }
	{ 2. Explosions }
	{ 3. Crashes }
	{ 4. Ejection/Surrender }
var
	FakeGB: GameBoardPtr;
	Mek,Target: GearPtr;
	FX_Desc: String;
	V: LongInt;
	DidExplode: Boolean;
begin
	{ Check for charges first. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		V := NAttValue( Mek^.NA , NAG_Action , NAS_WillCharge );
		if GearActive( Mek ) and ( V <> 0 ) and OnTheMap( GB , Mek ) then begin
			Target := LocateMekByUID( GB , V );

			if ( Target <> Nil ) and NotDestroyed( Target ) and OnTheMap( GB , Target ) then begin
				{ Generate a fake gameboard to be used for screen output. }
				FakeGB := CloneMap( GB );

				DoCharge( GB , Mek , Target );

				{ Report the effect of the attack. }
				Display_Effect_History( FakeGB );
				DisposeMapClone( FakeGB );
			end;

			SetNAtt( Mek^.NA , NAG_Action , NAS_WillCharge , 0 );
			SetNAtt( Mek^.NA , NAG_Action , NAS_ChargeSpeed , 0 );
		end;
		Mek := Mek^.Next;
	end;

	{ Check for explosions and disappearance now. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		V := NAttValue( Mek^.NA , NAG_Action , NAS_WillExplode );
		if V > 0 then begin
			DidExplode := True;

			{ Generate a fake gameboard to be used for screen output. }
			FakeGB := CloneMap( GB );

			DoReactorExplosion( GB , Mek );

			{ Report the effect of the attack. }
			Display_Effect_History( FakeGB );
			DisposeMapClone( FakeGB );

			SetNAtt( Mek^.NA , NAG_Action , NAS_WillExplode , 0 );
		end else begin
			DidExplode := False;
		end;

		V := NAttValue( Mek^.NA , NAG_Action , NAS_WillDisappear );
		if ( V > 0 ) or DidExplode then begin
			{ Shake down this model at its current location. }
			ShakeDown( GB , Mek , NAttValue( Mek^.NA , NAG_Location , NAS_X ) , NAttValue( Mek^.NA , NAG_Location , NAS_Y ) );

			{ Move this model off the map. }
			SetNAtt( Mek^.NA , NAG_Location , NAS_X , 0 );

			{ If this is a spontaneous disappearance, print a message. }
			if not DidExplode then DialogMsg( ReplaceHash( MsgString( 'Model_Disappeared' ) , GearName( Mek ) ) );

			SetNAtt( Mek^.NA , NAG_Action , NAS_WillDisappear , 0 );
		end;
		Mek := Mek^.Next;
	end;

	{ Check for crashes now. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		V := NAttValue( Mek^.NA , NAG_Action , NAS_WillCrash );
		if ( V > 0 ) and OnTheMap( GB , Mek ) then begin
			{ Generate a fake gameboard to be used for screen output. }
			FakeGB := CloneMap( GB );
			if Mek^.G = GG_Character then begin
				FX_Desc := MsgString( 'FXDESC_FALL' );
			end else begin
				FX_Desc := MsgString( 'FXDESC_CRASH' );
			end;

			HandleEffectString( GB , Mek , BStr( V ) + ' ' + FX_CauseDamage + ' 10 0 SCATTER' , FX_Desc );

			{ Report the effect of the attack. }
			Display_Effect_History( FakeGB );
			DisposeMapClone( FakeGB );

			SetNAtt( Mek^.NA , NAG_Action , NAS_WillCrash , 0 );
		end;
		Mek := Mek^.Next;
	end;

	{ Finally, check for ejection and surrender. }
	Mek := GB^.Meks;
	while Mek <> Nil do begin
		V := NAttValue( Mek^.NA , NAG_Action , NAS_MightGiveUp );
		if V <> 0 then begin
			if ( Mek^.G = GG_Mecha ) and ShouldEject( Mek , GB ) then begin
				AI_EJECT( Mek , GB );
			end else if ( Mek^.G = GG_Character ) and ShouldSurrender( GB , Mek ) then begin
				AI_SURRENDER( GB , Mek );
			end;
			SetNAtt( Mek^.NA , NAG_Action , NAS_MightGiveUp , 0 );
		end;
		Mek := Mek^.Next;
	end;
end;

Procedure DoTaunt( GB: GameBoardPtr; Attacker,Target: GearPtr );
	{ ATTACKER is going to taunt TARGET, whose mother probably smells of elderberries. }
const
	MinTauntTarget = 5;
var
	AtRoll,DefRoll,CounterRoll: Integer;
	msg: String;
begin
	{ Make the defense roll. Since most characters don't have the Taunt skill }
	{ there's a minimum target number of 5. }
	DefRoll := SkillRoll( GB , Target , NAS_Toughness , STAT_Ego , 0 , 0 , False , True );
	if DefRoll < MinTauntTarget then DefRoll := MinTauntTarget;
	AddMentalDown( Attacker , 1 );

	AtRoll :=  SkillRoll( GB , Attacker , NAS_Taunt , STAT_Charm , DefRoll , 0 , False , True );
	msg := GetTauntString( Attacker , 'CHAT_VA.ATTACK' );
	Monologue( GB , Attacker , msg );

	CounterRoll := SkillRoll( GB , Target , NAS_Taunt , STAT_Charm , AtRoll , 0 , False , True );

	if CounterRoll > AtRoll then begin
		msg := GetTauntString( Target , 'CHAT_VA.RIPOSTE' );
		Monologue( GB , Target , msg );
		Attacker := LocatePilot( Attacker );
		if Attacker <> Nil then begin
			AddNAtt( Attacker^.NA , NAG_StatusEffect , NAS_Flummoxed , 1 + Random( 10 ) );
			AddMoraleDmg( Attacker , 1 + AtRoll - DefRoll );
			AddMentalDown( Attacker , 1 + Random( 4 ) );
		end;

		{ Countering a verbal attack sets the Target's recharge. }
		{ It also makes sure that the attacker won't try a taunt again for 5 minutes. }
		SetNAtt( Target^.NA , NAG_EpisodeData , NAS_ChatterRecharge , GB^.ComTime + 91 + Random( 120 ) );
		SetNAtt( Attacker^.NA , NAG_EpisodeData , NAS_ChatterRecharge , GB^.ComTime + 300 + Random( 120 ) )

	end else if AtRoll > DefRoll then begin
		msg := GetTauntString( Target , 'CHAT_VA.SUCCESS' );
		Monologue( GB , Target , msg );
		Target := LocatePilot( Target );
		if Target <> Nil then begin
			AddNAtt( Target^.NA , NAG_StatusEffect , NAS_Flummoxed , 1 + Random( 10 ) );
			AddMoraleDmg( Target , 1 + AtRoll - DefRoll );
		end;

		{ Insulting your enemies makes you happy. }
		AddMoraleDmg( Attacker , -( 5 + Random( 10 ) ) );

	end else begin
		msg := GetTauntString( Target , 'CHAT_VA.FAILURE' );
		Monologue( GB , Target , msg );
		{ A failure delays the next taunt for at least five minutes. }
		SetNAtt( Attacker^.NA , NAG_EpisodeData , NAS_ChatterRecharge , GB^.ComTime + 300 + Random( 120 ) )
	end;
end;

Function SituationalEjectionModifier( GB: GameBoardPtr; Attacker,Target: GearPtr ): Integer;
	{ Return the situational modifier to the verbal attack roll. This modifier is based }
	{ on the following: }
	{ - Relative damage level of the attacker }
	{ - Being outnumbered }
	{ - Mobility status }
	{ - Weapon status }
	{ A higher value is worse for the attacker. }
var
	SEM,A,T: Integer;
	mek: GearPtr;
begin
	{ Start with a basic modifier of +5. }
	SEM := 5;

	{ Relative damage levels. }
	A := PercentDamaged( Attacker );
	T := PercentDamaged( Target );
	if A < T then SEM := SEM + ( ( T - A ) div 5 );

	{ Being outnumbered. }
	A := 0;
	T := 0;
	mek := GB^.Meks;
	while mek <> Nil do begin
		if IsMasterGear( mek ) and OnTheMap( GB , mek ) and GearActive( mek ) then begin
			if AreAllies( GB , Target , mek ) then Inc( T )
			else if AreEnemies( GB , Target , mek ) then Inc( A );
		end;
		mek := mek^.next;
	end;
	if A > T then begin
		SEM := SEM - ( A - T );
	end else if T > A then begin
		SEM := SEM + ( ( T - A ) div 2 );
	end;

	{ Mobility status. }
	if not HasAtLeastOneValidMovemode( Target ) then SEM := SEM - 3;

	{ Weapon status. }
	if not HasAtLeastOneValidWeapon( Target ) then SEM := SEM - 5;

	SituationalEjectionModifier := SEM;
end;

Procedure DoVerbalAttack( GB: GameBoardPtr; Attacker,Target: GearPtr );
	{ ATTACKER is going to spew abuse upon TARGET. If ATTACKER is a member of the }
	{ PC team and TARGET is in hard shape, this attack has a chance of }
	{ causing surrender or ejection. Note that the ATTACKER has only one chance to }
	{ get an ejection, and every time he fails to gain a surrender it gets harder. }
const
	MinSurrenderDefRoll = 5;
	MinEjectDefRoll = 10;
	ConversationEjectPenalty = 3;
	Function SelectTactic: Integer;
		{ ATTACKER has to select a tactic to use against TARGET. }
		{ This tactic is going to be one of the interaction skills. }
		{ The nominees are: CONVERSATION and INTIMIDATION. }
	var
		Con_Rank,Int_Rank: Integer;
	begin
		Con_Rank := SkillValue( Attacker , NAS_Conversation , STAT_Charm ) - ConversationEjectPenalty;
		if Con_Rank < 0 then Con_Rank := 0;
		Int_Rank := SkillValue( Attacker , NAS_Intimidation , STAT_Ego );

		if Random( Int_Rank + Con_Rank ) < Int_Rank then begin
			SelectTactic := NAS_Intimidation;
		end else begin
			SelectTactic := NAS_Conversation;
		end;
	end;
var
	AtSkill,AtRoll,DefRoll: Integer;
	msg: String;
begin
	if ( Target^.G = GG_Character ) then begin
		DefRoll := SkillRoll( GB , Target , NAS_Concentration , STAT_Ego , 0 , 0 , False , True );
		if DefRoll < MinSurrenderDefRoll then DefRoll := MinSurrenderDefRoll;
		AddMentalDown( Attacker , 3 );

		AtSkill := SelectTactic;
		msg := GetTauntString( Attacker , 'CHAT_VA.FORCESURRENDER.' + BStr( AtSkill ) );
		if AtSkill = NAS_Conversation then begin
			AtRoll :=  SkillRoll( GB , Attacker , AtSkill , STAT_Charm , DefRoll , -5 - NAttValue( Target^.NA , NAG_EpisodeData , NAS_TauntResistance ) , False , True );
		end else begin
			AtRoll :=  SkillRoll( GB , Attacker , AtSkill , STAT_Ego , DefRoll , -NAttValue( Target^.NA , NAG_EpisodeData , NAS_TauntResistance ) , False , True );
		end;
		AddNAtt( Target^.NA , NAG_EpisodeData , NAS_TauntResistance , 1 + Random(3) );
		Monologue( GB , Attacker , msg );

		if AtRoll > DefRoll then begin
			if MightSurrender( GB , Target ) then begin
				{ The surrender procedure will print a message, so no need to do that here. }
				AI_Surrender( GB , target );
			end else begin
				{ No surrender- just abuse MP and SP. }
				AddMentalDown( Target , 1 + ( AtRoll - DefRoll ) div 3 );
				AddStaminaDown( Target , 1 + ( AtRoll - DefRoll ) div 3 );
			end;

		end else begin
			msg := GetTauntString( Target , 'CHAT_VA.FORCEFAILURE' );
			Monologue( GB , Target , msg );
		end;

	end else if ( target^.G = GG_Mecha ) and ( NAttValue( Attacker^.NA , NAG_Location, NAS_Team ) = NAV_DefPlayerTeam ) and MightEject( Target ) then begin
		DefRoll := SkillRoll( GB , Target , NAS_Concentration , STAT_Ego , 0 , NAttValue( Target^.NA , NAG_EpisodeData , NAS_TauntResistance ) , False , True );
		if DefRoll < MinEjectDefRoll then DefRoll := MinEjectDefRoll;
		AddMentalDown( Attacker , 3 );

		AtSkill := SelectTactic;
		msg := GetTauntString( Attacker , 'CHAT_VA.FORCEEJECT.' + BStr( AtSkill ) );
		if AtSkill = NAS_Conversation then begin
			AtRoll :=  SkillRoll( GB , Attacker , AtSkill , STAT_Charm , DefRoll , -SituationalEjectionModifier( GB , Attacker , Target ) - ConversationEjectPenalty , False , True );
		end else begin
			AtRoll :=  SkillRoll( GB , Attacker , AtSkill , STAT_Ego , DefRoll , -SituationalEjectionModifier( GB , Attacker , Target ) , False , True );
		end;

		AddNAtt( Target^.NA , NAG_EpisodeData , NAS_TauntResistance , 1 + Random( 6 ) );
		Monologue( GB , Attacker , msg );

		if AtRoll > DefRoll then begin
			{ The eject procedure will print a message, so no need to do that here. }
			AI_Eject( target , GB );

		end else begin
			msg := GetTauntString( Target , 'CHAT_VA.FORCEFAILURE' );
			Monologue( GB , Target , msg );
		end;

	end else begin
		DoTaunt( GB , Attacker , Target );
	end;
end;


initialization

	NPC_Chatter_Standard := LoadStringList( NPC_Chatter_File );

finalization

	DisposeSAtt( NPC_Chatter_Standard );


end.
