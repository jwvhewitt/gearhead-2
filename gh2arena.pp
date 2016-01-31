unit gh2arena;
	{ Oct 23, 2006: }
	{ This is it. I've been programming GH2 for a while now, and even though }
	{ it's getting more and more playable all the time it'll still be a long }
	{ time before it's really playable. So I started to think back to the humble }
	{ beginnings of GH1. I decided that development of GH2 could be improved if }
	{ I added arena mode; a simple, combat-focused use of the engine that would }
	{ provide a fun game while the RPG campaign gets bulked up. I also got a few }
	{ comments on the forum indicating that I should put more work into tactics }
	{ mode. So here it is, the new humble beginning of GearHead arena, Mk2. }
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

uses gears,locale,
{$IFDEF ASCII}
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}

const
	{ ArenaMissionInfo moved to playwright.pp }

	NAG_MissionCoupon = 24;		{ Certain missions can only be taken a set number }
					{ of times. }
		NumMissionCouponTypes = 2;
		NAS_SkillTrain_Coupon = 1;
		NAS_MechaFac_Coupon = 2;

	NAG_AHQSkillTrainer = 25;	{ Tells what skill trainers the PC has acquired. }
	NAG_AHQMechaSource = 26;	{ Tells what mecha factions the PC has acquired. }


Procedure StartArenaCampaign;
Procedure RestoreArenaCampaign( RDP: RedrawProcedureType );

implementation

uses arenaplay,arenascript,interact,gearutil,narration,texutil,ghprop,rpgdice,ability,
     ghchars,ghweapon,movement,ui4gh,gearparser,playwright,randmaps,wmonster,
	pcaction,menugear,navigate,services,skilluse,training,backpack,chargen,
	description,
{$IFDEF ASCII}
	vidinfo,vidmap,vidmenus;
{$ELSE}
	sdlmap,sdlmenus,sdlinfo;
{$ENDIF}

Const
	GS_CharacterSet = 1;
	GS_CoreMissionSet = 2;

	NumArenaNPCs = 6;
	ANPC_FactionHead = 1;
	ANPC_Commander = 2;
	ANPC_Mechanic = 3;
	ANPC_Medic = 4;
	ANPC_Supply = 5;
	ANPC_Intel = 6;

	{ Play Arena Mission selection types. }
	PAM_Regular = 0;
	PAM_Debug_Missions = 1;
	PAM_Debug_Core = 2;

	SaleFactor = 25;

var
	ADR_Source: GearPtr;	{ Source gear for various redrawers. }
	ADR_SourceMenu: RPGMenuPtr;
	ADR_HQCamp: CampaignPtr;

	ADR_NumPilotsSelected,ADR_PilotsAllowed: Integer;

	ADR_PilotMenu,ADR_MechaMenu: RPGMenuPtr;

	ANPC_MasterPersona: GearPtr;

	Arena_Mission_Master_List,Core_Mission_Master_List: GearPtr;


{ *** REDRAW PROCEDURES *** }

Procedure BasicArenaRedraw;
	{ Just draw the basic setup for the arena mode menus. }
begin
	SetupArenaDisplay;
	if ADR_PilotMenu <> Nil then DisplayMenu( ADR_PilotMenu , Nil );
	if ADR_MechaMenu <> Nil then DisplayMenu( ADR_MechaMenu , Nil );
	if ADR_HQCamp <> Nil then ArenaTeamInfo( ADR_HQCamp^.Source , ZONE_PCStatus );
end;

Procedure HQMonologue( Adv: GearPtr; ArenaNPC: LongInt; Msg: String );
	{ NPC is about to deliver a line. }
var
	NPC: GearPtr;
	A: Char;
begin
	NPC := SeekGearByCID( Adv^.InvCom , ArenaNPC );
	repeat
		BasicArenaRedraw;
		DoMonologueDisplay( Nil , NPC , Msg );
		DoFlip;

		A := RPGKey;
	until IsMoreKey( A );

	DialogMsg( '[' + GearName( NPC ) + ']: ' + Msg );
end;

Procedure SelectAMissionRedraw;
	{ Do the basic display, then draw the select forces dialog on top of that. }
begin
	BasicArenaRedraw;
	SetupArenaMissionMenu;
end;

Procedure SelectAMForcesRedraw;
	{ Do the basic display, then draw the select forces dialog on top of that. }
begin
	BasicArenaRedraw;
	SetupMemoDisplay;
	CMessage( BStr( ADR_NumPilotsSelected ) + '/' + Bstr( ADR_PilotsAllowed ) + ' ' + MsgString( 'ARENA_SAMFRD_PilotsSelected' ) , ZONE_MemoMenu , InfoGreen );
end;

Procedure ViewMechaRedraw;
	{ The PC is viewing the mecha list. }
var
	N: Integer;
	Part: GearPtr;
begin
	SetupArenaDisplay;
	if ADR_PilotMenu <> Nil then DisplayMenu( ADR_PilotMenu , Nil );
	if ADR_HQCamp <> Nil then ArenaTeamInfo( ADR_HQCamp^.Source , ZONE_PCStatus );
	if ( ADR_SourceMenu <> Nil ) and ( ADR_Source <> Nil ) then begin
		N := CurrentMenuItemValue( ADR_SourceMenu );
		if N > 0 then begin
			Part := RetrieveGearSib( ADR_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( Nil , Part , ZONE_ArenaInfo );
			end;
		end;
	end;
end;

Procedure ViewPilotRedraw;
	{ The PC is viewing the mecha list. }
var
	N: Integer;
	Part: GearPtr;
begin
	SetupArenaDisplay;
	if ADR_MechaMenu <> Nil then DisplayMenu( ADR_MechaMenu , Nil );
	if ADR_HQCamp <> Nil then ArenaTeamInfo( ADR_HQCamp^.Source , ZONE_PCStatus );
	if ( ADR_SourceMenu <> Nil ) and ( ADR_Source <> Nil ) then begin
		N := CurrentMenuItemValue( ADR_SourceMenu );
		if N > 0 then begin
			Part := RetrieveGearSib( ADR_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( Nil , Part , ZONE_ArenaInfo );
			end;
		end;
	end;
end;

Procedure ViewSourcePilotRedraw;
	{ The PC is viewing a specific gear. }
begin
	SetupArenaDisplay;
	if ADR_MechaMenu <> Nil then DisplayMenu( ADR_MechaMenu , Nil );
	if ADR_HQCamp <> Nil then ArenaTeamInfo( ADR_HQCamp^.Source , ZONE_PCStatus );
	if ADR_Source <> Nil then begin
		BrowserInterfaceInfo( Nil , ADR_Source , ZONE_ArenaInfo );
	end;
end;

Procedure ViewSourceMechaRedraw;
	{ The PC is viewing a specific gear. }
begin
	SetupArenaDisplay;
	if ADR_PilotMenu <> Nil then DisplayMenu( ADR_PilotMenu , Nil );
	if ADR_HQCamp <> Nil then ArenaTeamInfo( ADR_HQCamp^.Source , ZONE_PCStatus );
	if ADR_Source <> Nil then begin
		BrowserInterfaceInfo( Nil , ADR_Source , ZONE_ArenaInfo );
	end;
end;

Procedure AddPilotRedraw;
	{ Draw the basic setup for the arena mode menus, then display character info }
	{ for ADR_SOURCE. }
begin
	BasicArenaRedraw;
	if ADR_Source <> Nil then CharacterDisplay( ADR_Source , Nil );
end;

Procedure PurchaseHardwareRedraw;
	{ The PC is buying hardware. Open the shopping display! }
var
	N: Integer;
	Part: GearPtr;
begin
	BasicArenaRedraw;
	SetupFHQDisplay;
	if ( ADR_SourceMenu <> Nil ) and ( ADR_Source <> Nil ) then begin
		N := CurrentMenuItemValue( ADR_SourceMenu );
		if N > 0 then begin
			Part := RetrieveGearSib( ADR_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( Nil , Part , ZONE_ItemsInfo );
			end;
		end;
	end;
end;

Procedure ViewListRedraw;
	{ The PC is viewing either the pilots list or the mecha list. }
var
	N: Integer;
	Part: GearPtr;
begin
	BasicArenaRedraw;
	if ( ADR_SourceMenu <> Nil ) and ( ADR_Source <> Nil ) then begin
		N := CurrentMenuItemValue( ADR_SourceMenu );
		if N > 0 then begin
			Part := RetrieveGearSib( ADR_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( Nil , Part , ZONE_ArenaInfo );
			end;
		end;
	end;
end;

Procedure ViewSourceRedraw;
	{ The PC is viewing a specific gear. }
begin
	BasicArenaRedraw;
	if ADR_Source <> Nil then begin
		BrowserInterfaceInfo( Nil , ADR_Source , ZONE_ArenaInfo );
	end;
end;

Procedure DoPurchaseRedraw;
	{ The PC has browsed, and is now making a real purchase. }
begin
	BasicArenaRedraw;
	SetupFHQDisplay;
	if ADR_Source <> Nil then begin
		BrowserInterfaceInfo( Nil , ADR_Source , ZONE_ItemsInfo );
	end;
end;


{ *** UTILITY FUNCTIONS *** }

Function ArenaNPCMessage( Adv: GearPtr; ArenaNPC: LongInt; const Msg_Key: String ): String;
	{ Try to find an appropriate message for the requested NPC to say. }
var
	NPC: GearPtr;
begin
	NPC := SeekGearByCID( Adv^.InvCom , ArenaNPC );
	ArenaNPCMessage := NPCScriptMessage( Msg_Key , Nil , NPC , ANPC_MasterPersona );
end;

Function FindMechasPilot( U , Mek: GearPtr ): GearPtr;
	{ Search unit U to locate whatever pilot is assigned to mecha Mek. }
	{ If no such pilot is found, clear Mek's PILOT attribute and }
	{ return Nil. }
var
	pc,mpc: GearPtr;
	name: String;
begin
	{ Begin by finding the pilot's name. }
	name := SAttValue( Mek^.SA , 'pilot' );

	{ Search through the unit's Sub looking for a character of }
	{ this name. }
	pc := U^.SubCom;
	mpc := Nil;
	while ( pc <> Nil ) and ( mpc = Nil ) do begin
		if pc^.G = GG_Character then begin
			if GearName( PC ) = name then mpc := pc;
		end;
		pc := pc^.Next;
	end;

	{ If the required pilot could not be found, }
	{ delete this mecha's PILOT attribute. }
	if mpc = Nil then begin
		SetSAtt( Mek^.SA , 'pilot <>' );
	end;

	FindMechasPilot := mpc;
end;

Function UnitSkill( HQCamp: CampaignPtr; Skill,SkStat: Integer ): Integer;
	{ Return the "unit skill" value for the requested skill. Usually this }
	{ will be the highest skill rank in the unit. }
begin
	{ Check through every mek on the board. }
	UnitSkill := SkillValue( HQCamp^.Source , Skill , SkStat );
end;

Function ModifiedCost( HQCamp: CampaignPtr; BaseCost: LongInt; Skill: Integer ): LongInt;
	{ The unit has to spend money on something, but this amount of money can be }
	{ reduced based on a certain skill. When buying things the skill is shopping. }
	{ When fixing things the skill is the appropriate repair skill. }
begin
	{ Determine the unit skill value. }
	if ( Skill >= 1 ) and ( Skill <= NumSkill ) then begin
		Skill := UnitSkill( HQCamp , Skill , STAT_Charm );
	end else Skill := 0;

	{ Each point of skill gives a 2% discount on the cost. }
	Skill := Skill * 2;
	{ You can't get more than a 75% discount, no matter how you try. }
	if Skill > 75 then Skill := 75;

	{ Return the modified cost. }
	ModifiedCost := BaseCost * ( 100 - Skill ) div 100;
end;

Function AHQRepairCost( HQCamp: CampaignPtr; Part: GearPtr ): LongInt;
	{ Return the cash cost to repair this gear completely. }
var
	Material: Integer;
	Total: LongInt;
begin
	Total := 0;
	for Material := 0 to NumMaterial do begin
		Total := Total + ModifiedCost( HQCamp , RepairMasterCost( Part , Material ) , Repair_Skill_Needed[ Material ] );
	end;
	AHQRepairCost := Total;
end;

Procedure DoFullRepair( HQCamp: CampaignPtr; Part: GearPtr );
	{ Do all the repair that this gear needs. }
var
	Material: Integer;
	Cost,TRD: LongInt;
begin
	for Material := 0 to NumMaterial do begin
		Cost := RepairMasterCost( Part , Material );
		if Cost > 0 then begin
			TRD := TotalRepairableDamage( Part , Material );
			ApplyRepairPoints( Part , Material , TRD , True );
			AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , -Cost );
		end;
	end;
end;

Function HQCash( HQCamp: CampaignPtr ): LongInt;
	{ This is pretty much just a macro for returning the amount of }
	{ cash this arena unit has. }
begin
	HQCash := NAttValue( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits );
end;

Function HQRenown( HQCamp: CampaignPtr ): LongInt;
	{ This is pretty much just a macro for returning the amount of }
	{ renown this arena unit has. }
	{ This procedure will also check to make sure the renown doesn't }
	{ drop below zero. }
var
	it: LongInt;
begin
	it := NAttValue( HQCamp^.Source^.NA , NAG_CharDescription , NAS_Renowned );
	if it < 0 then begin
		it := 0;
		SetNAtt( HQCamp^.Source^.NA , NAG_CharDescription , NAS_Renowned , 0 );
	end;
	HQRenown := it;
end;

Function HQFac( HQCamp: CampaignPtr ): Integer;
	{ Return the faction of this arena unit. }
begin
	HQFac := NAttValue( HQCamp^.Source^.NA , NAG_Personal , NAS_FactionID );
end;

Function HQMaxMissions( HQCamp: CampaignPtr ): Integer;
	{ Return the maximum number of missions this unit can have available. }
	{ This number is based on the unit's conversation skill. }
var
	C: Integer;
begin
	C := ( UnitSkill( HQCamp , NAS_Conversation , STAT_Charm ) + 4 ) div 3;
	if C < 3 then C := 3;
	HQMaxMissions := C;
end;


Procedure ArenaReloadMaster( HQCamp: CampaignPtr; PC: GearPtr );
	{ Reload the mecha, and make the unit PAY!!! Money, that is. }
	{ Bullets aren't free. }
begin
	AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , -ReloadMasterCost( PC , Reload_All_Weapons ) );
	DoReloadMaster( PC , Reload_All_Weapons );
end;

Function ExpectedMissionReward( HQCamp: CampaignPtr; Scene: GearPtr ): LongInt;
	{ Return the amount of cash the PC can expect if he completes this }
	{ mission. }
var
	TL,PayRate: LongInt;
begin
	TL := HQRenown( HQCamp );
	PayRate := NAttValue( Scene^.NA , NAG_ArenaMissionInfo , NAS_PayRate );
	if PayRate = 0 then PayRate := 400;
	ExpectedMissionReward := Calculate_Reward_Value( Nil , TL , PaYRate );
end;


Procedure PrepMission( HQCamp: CampaignPtr; Scene: GearPtr );
	{ Prepare the mission right before combat. Mostly, this just }
	{ involves initializing the cash payout counter and NPCs. }
var
	F,TL: LongInt;
	M: GearPtr;
	Desc: String;
begin
	TL := HQRenown( HQCamp );
	SetNAtt( Scene^.NA , NAG_ArenaMissionInfo , NAS_Pay , ExpectedMissionReward( HQCamp , Scene ) );
	SetSAtt( Scene^.SA , 'name <>' );
	Desc := SAttValue( Scene^.SA , 'TYPE' ) + ' ' + DifficulcyContext( TL );
	SetSAtt( Scene^.SA , 'TYPE <' + Desc + '>' );

	{ Prep the NPCs to the correct level. }
	M := Scene^.InvCom;
	while M <> Nil do begin
		if M^.G = GG_Character then begin
			{ Set the faction. }
			F := NAttValue( M^.NA , NAG_Personal , NAS_FactionID );
			if F < 0 then SetNAtt( M^.NA , NAG_Personal , NAS_FactionID , ElementID( Scene , Abs( F ) ) );
			SetSkillsAtLevel( M , TL );
		end;
		M := M^.Next;
	end;
end;

Function NumMissions( HQCamp: CampaignPtr ): Integer;
	{ Return the number of missions currently waiting for the PC. }
var
	M: GearPtr;
	N: Integer;
begin
	N := 0;
	M := HQCamp^.Source^.InvCom;
	while M <> Nil do begin
		if M^.G = GG_Scene then Inc( N );
		M := M^.Next;
	end;
	NumMissions := N;
end;

Function GetMission( HQCamp: CampaignPtr; N: Integer ): GearPtr;
	{ Retrieve mission N. }
var
	it,M: GearPtr;
begin
	M := HQCamp^.Source^.InvCom;
	it := Nil;
	while ( M <> Nil ) and ( it = Nil ) do begin
		if M^.G = GG_Scene then begin
			Dec( N );
			if N = 0 then it := M;
		end;
		M := M^.Next;
	end;
	GetMission := it;
end;

Function HQContext( HQCamp: CampaignPtr ): String;
	{ Return a context for this arena unit. }
	{ The context is used to determine what missions can be }
	{ loaded. }
var
	Fac: GearPtr;
	HQC: String;
	Renown,T: Integer;
begin
	{ Start with the faction designation. }
	Fac := SeekCurrentLevelGear( HQCamp^.Source^.InvCom , GG_Faction , HQFac( HQCamp ) );
	if Fac <> Nil then begin
		HQC := SAttValue( Fac^.SA , 'TYPE' ) + ' ' + SAttValue( Fac^.SA , 'DESIG' );
	end else begin
		HQC := 'FDFOR MILITARY';
	end;

	{ Add the difficulcy level. }
	Renown := HQRenown( HQCamp );
	HQC := HQC + ' ' + DifficulcyContext( Renown );

	{ Add tags for the skills and mecha factions that the PC hasn't earned yet. }
	for t := 1 to NumSkill do begin
		if NAttValue( HQCamp^.Source^.NA , NAG_AHQSkillTrainer , T ) = 0 then begin
			HQC := HQC + ' [s' + BStr( T ) + ']';
		end;
	end;

	Fac := Factions_List;
	while Fac <> Nil do begin
		if NAttValue( HQCamp^.Source^.NA , NAG_AHQMechaSource , Fac^.S ) = 0 then begin
			HQC := HQC + ' [f' + BStr( Fac^.S ) + ']';
		end;
		Fac := Fac^.Next;
	end;

	HQContext := HQC;
end;

Function HQCoupons( HQCamp: CampaignPtr ): STring;
	{ Return the coupons this campaign has. }
const
	Coupons_Per_Level: Array [1..NumMissionCouponTypes,1..5] of Byte = (
	( 2, 4, 6, 8, 10 ),	{ Skill Trainers }
	( 1, 2, 3, 4, 5 )	{ Mecha Factions }
	);
	Coupon_Tag: Array [1..NumMissionCouponTypes] of String = (
		'SKILL_TRAIN_MISSION',
		'MECHA_SOURCE_MISSION'
	);
	Function CanAddCoupon( N: Integer ): Boolean;
		{ You can add this coupon if no currently loaded mission is using it. }
	var
		M: GearPtr;
		CAC:Boolean;
	begin
		{ Assume true until shown false. }
		CAC := True;
		M := HQCamp^.Source^.InvCom;
		while M <> Nil do begin
			if ( M^.G = GG_Scene ) and AStringHasBString( SAttValue( M^.SA , 'REQUIRES' ) , Coupon_Tag[ N ] ) then CAC := False;
			M := M^.Next;
		end;
		CanAddCoupon := CAC;
	end;
var
	HQC: String;
	Renown,T: Integer;
begin
	HQC := '';

	{ Add any mission coupons that haven't been spent yet. }
	{ Determine the faction level. }
	Renown := HQRenown( HQCamp );
	if Renown < 1 then Renown := 1;
	Renown := ( Renown + 19 ) div 20;
	{ Check for coupons. }
	for t := 1 to NumMissionCouponTypes do begin
		if ( Coupons_Per_Level[ T , Renown ] - NAttValue( HQCamp^.Source^.NA , NAG_MissionCoupon , T ) ) >  0 then begin
			{ We have a coupon left. Add a note. }
			if CanAddCoupon( T ) then begin
				HQC := HQC + ' ' + Coupon_Tag[ T ];
			end;
		end;
	end;

	HQCoupons := HQC;
end;

Function AddCoreMission( HQCamp: CampaignPtr ): Boolean;
	{ Add a core mission. If there's a mission stored in the core mission holder, }
	{ and it hasn't been completed yet (check CoreMissionID against the CoreMissionStep) }
	{ then use that one. Otherwise generate a new mission. }
	{ Return TRUE if the core mission was generated successfully, or FALSE if the }
	{ generation fails. This procedure should print an error message if the generation }
	{ fails, since that's a pretty serious thing. }
	Function CoreCampaignContext( CMStep: Integer ): String;
		{ Return the context of the core campaign. This includes the }
		{ story state, the difficulcy level, the context of the player's faction (P:), }
		{ and the context of the enemy faction (F:). }
	var
		Context: String;
		Fac: GearPtr;
	begin
		{ Determine the campaign context. This is stored right in the adventure gear itself. }
		Context := SAttValue( HQCamp^.Source^.SA , 'CORE_CONTEXT' );
		if Context = '' then begin
			Context := '+P--';
			SetSAtt( HQCamp^.Source^.SA , 'CORE_CONTEXT <+P-->' );
		end;

		{ Locate the player faction and the element faction. Provide context for both. }
		Fac := SeekCurrentLevelGear( HQCamp^.Source^.InvCom , GG_Faction , HQFac( HQCamp ) );
		AddGearXRContext( Nil , HQCamp^.Source , Fac , Context , 'P' );

		Fac := SeekCurrentLevelGear( HQCamp^.Source^.InvCom , GG_Faction , NAttValue( HQCamp^.Source^.NA , NAG_AHQData , NAS_CoreMissionEnemy ) );
		AddGearXRContext( Nil , HQCamp^.Source , Fac , Context , 'F' );

		{ Add the difficulcy context. }
		Context := COntext + ' ' + DifficulcyContext( CMStep * 10 + 5 );

		CoreCampaignContext := Context;
	end;
	Function NewCoreMissionPrototype( CMSet: GearPtr ): GearPtr;
		{ Select a new core mission for the next step in the progress. }
		{ Set its core mission ID, and return a pointer to it. }
		{ If no appropriate mission can be found, print an error message and return Nil. }
	var
		CMStep: Integer;
		Context: String;
		CM,CMProto,CMTest: GearPtr;
		ShoppingList: NAttPtr;
	begin
		{ Determine the threat level of this mission. }
		CMStep := NAttValue( HQCamp^.Source^.NA , NAG_AHQData , NAS_CoreMissionStep ) + 1;

		{ Determine the campaign context. }
		Context := CoreCampaignContext( CMStep );

		{ Create the shopping list of potential candidates. }
		ShoppingList := CreateComponentList( Core_Mission_Master_List , Context );

		{ As long as we still have candidates, look for one to select. }
		{ Attempt to load it into the adventure- if loading succeeds, it's }
		{ a good one. Delete the temporary copy and stick the clone in the set. }
		CMProto := Nil;
		while ( ShoppingList <> Nil ) and ( CMProto = Nil ) do begin
			CM := SelectComponentFromList( Core_Mission_Master_List , ShoppingList );
			CMTest := CloneGear( CM );
			if InsertArenaMission( HQCamp^.Source , CMTest , HQRenown( HQCamp ) ) then begin
				CMProto := CloneGear( CM );
				InsertInvCom( CMSet , CMProto );
				RemoveGear( HQCamp^.Source^.InvCom , CMTest );
			end;
		end;

		{ If no mission was found, print a debugging message along with the }
		{ context so that future generations can learn from my mistakes. Or }
		{ so I can add a new mission to fill in the gap. }
		if CMProto = Nil then begin
			Dialogmsg( 'ERROR: Core mission not found for context:' + Context );
		end;

		{ Dispose of the shopping list. }
		DisposeNAtt( ShoppingList );

		{ Return a pointer to the new mission. }
		NewCoreMissionPrototype := CMProto;
	end;
var
	CMSet,CMProto,CM: GearPtr;
	AddOK: Boolean;
begin
	AddOK := False;

	{ Start by locating the core mission set, if it exists. }
	CMSet := SeekCurrentLevelGear( HQCamp^.Source^.InvCom , GG_Set , GS_CoreMissionSet );
	if CMSet = Nil then begin
		{ We don't have a Core Mission Set. Horrors! Better add one. }
		CMSet := NewGear( Nil );
		CMSet^.G := GG_Set;
		CMSet^.S := GS_CoreMissionSet;
		InsertInvCom( HQCamp^.Source , CMSet );
	end;

	{ This set should contain a single gear- the core mission. If this mission }
	{ doesn't exist, or if it has already been completed, better generate another }
	{ one. }
	CMProto := CMSet^.InvCom;
	if CMProto = Nil then begin
		CMProto := NewCoreMissionPrototype( CMSet );
	end else if NAttValue( CMProto^.NA , NAG_ArenaMissionInfo , NAS_IsCoreMission ) <= NAttValue( HQCamp^.Source^.NA , NAG_AHQData , NAS_CoreMissionStep ) then begin
		RemoveGear( CMSet^.InvCom , CMProto );
		CMProto := NewCoreMissionPrototype( CMSet );
	end;

	{ If the prototype was found, insert a clone. }
	if CMProto <> Nil then begin
		CM := CloneGear( CMProto );
		AddOK := InsertArenaMission( HQCamp^.Source , CM , HQRenown( HQCamp ) );
		if not AddOK then begin
			DialogMsg( 'ERROR: Insertion of core mission ' + GearName( CMProto ) + ' failed.' );
		end;
	end;

	AddCoreMission := AddOK;
end;

Procedure AddMissions( HQCamp: CampaignPtr; N: Integer );
	{ Refresh the missions. Yay! Basically make sure there are some missions to }
	{ choose between. }
	Procedure AddAMission( var ShoppingList: NAttPtr );
		{ Add a mission from the provided list. }
	var
		MissionOK: Boolean;
		M: GearPtr;
	begin
		MissionOK := False;
		while ( ShoppingList <> Nil ) and not MissionOK do begin
			M := CloneGear( SelectComponentFromList( Arena_Mission_Master_List , ShoppingList ) );
			if InsertArenaMission( HQCamp^.Source , M , HQRenown( HQCamp ) ) then begin
				MissionOK := True;
			end;
		end;
	end;
	Function NoCoreMissionFound: Boolean;
		{ Return TRUE if none of the pending missions belong to the core campaign, }
		{ or FALSE if one of them does. }
	var
		M: GearPtr;
		NCMF: Boolean;
	begin
		{ Assume true unless proven otherwise. }
		NCMF := True;
		M := HQCamp^.Source^.InvCom;
		while M <> Nil do begin
			if ( M^.G = GG_Scene ) and ( NAttValue( M^.NA , NAG_ArenaMissionInfo , NAS_IsCoreMission ) <> 0 ) then NCMF := False;
			M := M^.Next;
		end;
		NoCoreMissionFound := NCMF;
	end;
	Function CanAddCoreMission: Boolean;
		{ Return TRUE if a core mission can currently be loaded, or FALSE if }
		{ it can't be. It can be loaded if: }
		{  A) the player hasn't already completed the core campaign }
		{  B) the unit's renown is high enough to load the next step }
		{  C) there isn't currently a core mission in the pending list }
	var
		CMS: Integer;
	begin
		{ Determine the core mission step. }
		CMS := NAttValue( HQCamp^.Source^.NA , NAG_AHQData , NAS_CoreMissionStep );
		CanAddCoreMission := ( CMS < 8 ) and ( ( ( CMS + 1 ) * 10 ) <= HQRenown( HQCamp ) ) and NoCoreMissionFound;
	end;
var
	Context: String;
	MissionList,RewardList: NAttPtr;
begin
	{ Start by determining the arena unit's context. This is determied by the }
	{ current faction being fought for plus the arena unit's renown. }
	Context := HQContext( HQCamp );

	{ Next create the list of potential content to add. }
	{ There are two content lists- regular content, and reward content. One reward mission }
	{ should be loaded per five regular missions. A core campaign mission could also be selected, }
	{ but this is handled differently. }
	MissionList := CreateComponentList( Arena_Mission_Master_List , '*MISSION ' + Context );
	RewardList := Nil;

	while N > 0 do begin
		{ Decrement the mission timers, and add special mission types as appropriate. }
		AddNAtt( HQCamp^.Source^.NA , NAG_AHQData , NAS_RewardMissionTimer , -1 );
		if CanAddCoreMission then AddNAtt( HQCamp^.Source^.NA , NAG_AHQData , NAS_CoreMissionTimer , -1 );

		if ( NAttValue( HQCamp^.Source^.NA , NAG_AHQData , NAS_CoreMissionTimer ) < 0 ) and CanAddCoreMission then begin
			if AddCoreMission( HQCamp ) then begin
				{ Set the mission recharge timer to something large. }
				SetNAtt( HQCamp^.Source^.NA , NAG_AHQData , NAS_CoreMissionTimer , 20 + Random( 10 ) + N );
			end else begin
				{ Adding the core mission failed for some reason, probably }
				{ a plot deadend. }
				SetNAtt( HQCamp^.Source^.NA , NAG_AHQData , NAS_CoreMissionTimer , 10 + N );
				Inc( N );
			end;
		end else if ( NAttValue( HQCamp^.Source^.NA , NAG_AHQData , NAS_RewardMissionTimer ) < 0 ) then begin
			RewardList := CreateComponentList( Arena_Mission_Master_List , '*REWARD ' + Context + ' ' + HQCoupons( HQCamp ) );
			if RewardList <> Nil then begin
				AddAMission( RewardList );
			end else begin
				AddAMission( MissionList );
			end;
			SetNAtt( HQCamp^.Source^.NA , NAG_AHQData , NAS_RewardMissionTimer , 4 );
			DisposeNAtt( RewardList );
		end else begin
			AddAMission( MissionList );
		end;
		Dec( N );
	end;

	DisposeNAtt( MissionList );
	DisposeNAtt( RewardList );
end;

Procedure UpdateMissions( HQCamp: CampaignPtr );
	{ Check to see if there are enough missions. Maybe delete some of them. }
	{ Bring the total back to max. }
var
	N: Integer;
	M: GearPtr;
begin
	{ Step one- delete some missions at random. }
	N := NumMissions( HQCamp );
	Repeat
		if N > 1 then begin
			M := GetMission( HQCamp , Random( N ) + 1 );
			if M <> Nil then RemoveGear( HQCamp^.Source^.InvCom , M );
		end;
		Dec( N );
	until ( N < 1 ) or ( Random( 3 ) <> 1 );

	{ Step one point five- remove the core campaign mission if the unit's }
	{ renown has fallen beneath the critical threshold. }
	M := HQCamp^.Source^.InvCom;
	while M <> Nil do begin
		if ( M^.G = GG_Scene ) and ( NAttValue( M^.NA , NAG_ArenaMissionInfo , NAS_IsCoreMission ) <> 0 ) then begin
			if HQRenown( HQCamp ) < ( ( NAttValue( M^.NA , NAG_ArenaMissionInfo , NAS_IsCoreMission ) + 1 ) * 10 ) then begin
				RemoveGear( HQCamp^.Source^.InvCom , M );
				Break;
			end;
		end;
		M := M^.Next;
	end;

	{ Step two- make sure we have enough missions. }
	AddMissions( HQCamp , HQMaxMissions( HQCamp ) - NumMissions( HQCamp ) );
end;

Procedure ClearWeaponRecharge( LList: GearPtr );
	{ To prevent strange bugs from happening, clear all weapon recharge times }
	{ upon leaving combat. }
begin
	while LList <> Nil do begin
		SetNAtt( LList^.NA , NAG_WeaponModifier , NAS_Recharge , 0 );
		ClearWeaponRecharge( LList^.InvCom );
		ClearWeaponRecharge( LList^.SubCom );
		LList := LList^.Next;
	end;
end;

Procedure PostMissionCleanup( HQCamp: CampaignPtr; PCForces: GearPtr );
	{ After a battle is over, deal with the survivors. There are survivors? }
	{ I must not have made the mission hard enough... }
var
	PC: GearPtr;
	Cost: LongInt;
begin
	{ To start with, recharge/repair everyone in the list. }
	{ We'll make three passes: First, "repair" all characters. }
	{ Second, repair all mecha. Third, restock all mecha and characters. }

	{ First pass- medical attention for characters. }
	PC := PCForces;
	while PC <> Nil do begin
		{ Status effects get repaired for free- otherwise, a low-on-cash }
		{ arena unit could enter the next battle with a mecha still on fire from their }
		{ last battle, and that would suck. Also remove conditions now, since }
		{ everybody needs that done. }
		StripNAtt( PC , NAG_StatusEffect );
		StripNAtt( PC , NAG_Condition );
		ClearWeaponRecharge( PC^.SubCom );
		ClearWeaponRecharge( PC^.InvCom );

		if PC^.G = GG_Character then begin
			Cost := AHQRepairCost( HQCamp , PC );
			if ( Cost > 0 ) and ( HQCash( HQCamp ) >= Cost ) then begin
				DoFullRepair( HQCamp , PC );
			end;
		end;

		PC := PC^.Next;
	end;

	{ Second pass- repair all mecha. }
	PC := PCForces;
	while PC <> Nil do begin
		if PC^.G = GG_Mecha then begin
			Cost := AHQRepairCost( HQCamp , PC );
			if ( Cost > 0 ) and ( HQCash( HQCamp ) >= Cost ) then begin
				DoFullRepair( HQCamp , PC );
			end;
		end;

		PC := PC^.Next;
	end;

	{ Third pass- reload all weapons. }
	PC := PCForces;
	while PC <> Nil do begin
		Cost := ReloadMasterCost( PC , Reload_All_Weapons );
		if ( Cost > 0 ) and ( HQCash( HQCamp ) >= Cost ) then begin
			ArenaReloadMaster( HQCamp , PC );
		end;
		PC := PC^.Next;
	end;

	{ Once that's been taken care of, stick the PCs back in the unit. }
	InsertSubCom( HQCamp^.Source , PCForces );

	{ Finally update the missions. }
	UpdateMissions( HQCamp );
end;

Procedure AddDamageReloadStatus( HQCamp: CampaignPtr; M: GearPtr; var msg: String );
	{ If this model needs repairs or reloading, indicate that here. }
var
	POK: Integer;	{ Percent OK }
begin
	if AHQRepairCost( HQCamp ,  M ) > 0 then begin
		POK := PercentDamaged( M );
		if POK = 100 then POK := 99;
		msg := msg + ' (%' + BStr( POK ) + ')';
	end;
	if ReloadMasterCost( M , Reload_All_Weapons ) > 0 then msg := msg + ' -ammo-';
end;

Function AHQMechaName( HQCamp: CampaignPtr; Mek: GearPtr ): String;
	{ Return the name of this mecha along with its pilot. }
	{ If the mecha's pilot can't be found, clear the PILOT string attribute. }
var
	name,pname: String;
	Pilot: GearPtr;
begin
	name := FullGearName( Mek );
	pname := SAttValue( Mek^.SA , 'pilot' );
	if pname <> '' then begin
		Pilot := SeekGearByName( HQCamp^.Source^.SubCom , pname );
		if Pilot = Nil then begin
			{ Oops, no pilot. Must have died or been removed }
			{ from the unit. Fix this mecha's data. }
			SetSatt( Mek^.SA , 'pilot <>' );
		end else begin
			{ Pilot has been found. Add to the name. }
			name := name + ' [' + pname + ']';
		end;
	end;
	AddDamageReloadStatus( HQCamp , Mek , name );
	AHQMechaName := name;
end;

Procedure UpdatePilotMechaMenus( HQCamp: CampaignPtr );
	{ Add the pilots and the mecha to their respective menus. }
	{ If any mecha/pilot matchups are invalid, clear them. }
	{ This is done via the above function, BTW. }
var
	N,PMI,MMI: Integer;
	M: GearPtr;
	name: String;
begin
	{ If either of the menus currently exist, dispose of them. }
	if ADR_PilotMenu <> Nil then begin
		PMI := ADR_PilotMenu^.selectitem;
		DisposeRPGMenu( ADR_PilotMenu );
	end else begin
		PMI := 1;
	end;
	if ADR_MechaMenu <> Nil then begin
		MMI := ADR_MechaMenu^.selectitem;
		DisposeRPGMenu( ADR_MechaMenu );
	end else begin
		MMI := 1;
	end;

	{ Allocate the menus. }
	ADR_PilotMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaPilotMenu );
	ADR_MechaMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaMechaMenu );

	{ Go through the unit contents, adding to whichever menu is appropriate. }
	M := HQCamp^.Source^.SubCom;
	N := 1;
	while M <> Nil do begin
		if M^.G = GG_Character then begin
			name := GearName( M );
			AddDamageReloadStatus( HQCamp , M , name );
			AddRPGMenuItem( ADR_PilotMenu , name , N );
		end else if M^.G = GG_Mecha then begin
			{ For a mecha, add not just the mecha's name but also the }
			{ pilot's name. If no pilot can be found, clean up that mess. }
			name := AHQMechaName( HQCamp , M );
			AddRPGMenuItem( ADR_MechaMenu , name , N );
		end else begin
			AddRPGMenuItem( ADR_MechaMenu , '*' + GearName( M ) , N );
		end;

		Inc( N );
		M := M^.Next;
	end;

	{ Sort the menus. }
	RPMSortAlpha( ADR_PilotMenu );
	RPMSortAlpha( ADR_MechaMenu );
	SetItemByPosition( ADR_PilotMenu , PMI );
	SetItemByPosition( ADR_MechaMenu , MMI );
end;

Procedure StripAllMecha( var PC: GearPtr );
	{ We've been provided with a linked list. Remove everything }
	{ that isn't a mecha. }
var
	Mek,M2: GearPtr;
	Total: LongInt;
begin
	Mek := PC;
	Total := 0;
	while Mek <> Nil do begin
		M2 := Mek^.Next;
		if Mek^.G <> GG_Character then begin
			Total := Total + GearCost( Mek );
			RemoveGear( PC , Mek );
		end;
		Mek := M2;
	end;
	if ( PC <> Nil ) and ( PC^.Next = Nil ) then AddNAtt( PC^.NA , NAG_Experience, NAS_Credits , Total );
end;

Function HasSkillTrainers( HQCamp: CampaignPtr ): Boolean;
	{ Return TRUE if this campaign has some skill trainers, or FALSE otherwise. }
var
	HasTrainer: Boolean;
	T: Integer;
begin
	HasTrainer := False;
	for T := 1 to NumSkill do begin
		if NAttValue( HQCamp^.Source^.NA , NAG_AHQSkillTrainer , T ) <> 0 then begin
			HasTrainer := True;
			Break;
		end;
	end;
	HasSkillTrainers := HasTrainer;
end;

{ *** USER INTERFACE BITS *** }

procedure AddPilotToUnit( HQCamp: CampaignPtr );
	{ Browse the disk for a character file. If one is selected, }
	{ display the character's stats and ask whether or not to hire }
	{ this character. If hired, add the character to the unit, }
	{ save the game, then delete the character's individual file. }
	Function HiringPrice( PC: GearPtr ): LongInt;
		{ Return the price of recruiting this character into the unit. }
	begin
		HiringPrice := GearValue( PC );
	end;
	Function IChooseYou( PC: GearPtr ): Boolean;
		{ Maybe add this character to the unit. This is going to cost }
		{ money, so maybe not. }
	var
		YNMenu: RPGMenuPtr;
		cost: LongInt;
		ISaidYes: Boolean;
	begin
		{ Create the menu. }
		YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
		cost := HiringPrice( PC );
		if HQCash( HQCamp ) >= cost then begin
			AddRPGMenuItem( YNMenu , MsgString( 'ARENA_APTU_Yes' ) + ' ($' + BStr( cost ) + ')' , 1 );
			AddRPGMenuItem( YNMenu , MsgString( 'ARENA_APTU_No' ) , -1 );
		end else begin
			AddRPGMenuItem( YNMenu , MsgString( 'ARENA_APTU_TooExpensive' ) , -1 );
		end;
		ADR_Source := PC;

		if SelectMenu( YNMenu , @DoPurchaseRedraw ) = 1 then begin
			ISaidYes := True;
		end else begin
			ISaidYes := False;
		end;

		{ Get rid of the Yes/No menu. }
		DisposeRPGMenu( YNMenu );

		IChooseYou := ISaidYes;
	end;
var
	PCList,PC: GearPtr;
	PCMenu: RPGMenuPtr;
	FList,FName: SAttPtr;
	F: Text;
	N: Integer;
begin
	DialogMSG( MsgString( 'ARENA_APTU_Prompt' ) );

	{ Build the character list. Filter out any characters that can't be added }
	{ to the unit. }
	FList := CreateFileList( Save_Character_Base + Default_Search_Pattern );
	PCList := Nil;

	FName := FList;
	while FName <> Nil do begin
		Assign( F , Save_Game_Directory + FName^.info );
		reset(F);
		PC := ReadCGears(F);
		Close(F);

		StripAllMecha( PC );
		SetSAtt( PC^.SA , 'filename <' + FName^.Info + '>' );
		AppendGear( PCList , PC );

		FName := FName^.Next;
	end;
	DisposeSAtt( FList );

	{ Keep querying for characters until cancel is selected. }
	repeat
		{ Create the PC menu. }
		PCMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
		BuildSiblingMenu( PCMenu , PCList );
		RPMSortAlpha( PCMenu );
		AlphaKeyMenu( PCMenu );
		AddRPGMenuItem( PCMenu , MsgString( 'Exit' ) , -1 );

		{ Select a file, then dispose of the menu. }
		{ Don't need to worry about the menu being empty because }
		{ of the EXIT item. }
		ADR_Source := PCList;
		ADR_SourceMenu := PCMenu;
		N := SelectMenu( PCMenu , @PurchaseHardwareRedraw );
		DisposeRPGMenu( PCMenu );

		{ If a file was selected, load it and see if the player }
		{ wants to keep it. }
		if N > 0 then begin

			PC := RetrieveGearSib( PCList , N );
			DelinkGear( PCList , PC );

			{ Ask the player what to do with this character. }
			if IChooseYou( PC ) then begin
				{ Add the character to the unit. }
				InsertSubCom( HQCamp^.Source , PC );

				{ Saving the game is done before deleting }
				{ the character file so that if there's a }
				{ problem in saving, at least the original }
				{ character file will be intact. }
				PCSaveCampaign( HQCamp , Nil , False );
				Assign( F , Save_Game_Directory + SAttValue( PC^.SA , 'filename' ) );
				Erase(F);

				{ Update the menus here. }
				UpdatePilotMechaMenus( HQCamp );
			end else begin
				{ Stick this character back in the list. }
				AppendGear( PCList , PC );
			end;
		end;
	until N = -1;

	DisposeGear( PCList );
end;

procedure PurchaseGear( HQCamp: CampaignPtr; Part: GearPtr );
	{ The unit may or may not want to buy PART. }
	{ Show the price of this gear, and ask whether or not the }
	{ player wants to make this purchase. }
var
	YNMenu: RPGMenuPtr;
	Cost: LongInt;
begin
	Cost := ModifiedCost( HQCamp , GearCost( Part ) , NAS_Shopping );

	YNMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
	AddRPGMenuItem( YNMenu , ReplaceHash( MsgString( 'ARENA_PurchaseYes' ) , GearName( Part ) ) + ' ($' + BStr( Cost ) + ')' , 1 );
	AddRPGMenuItem( YNMenu , MsgSTring( 'ARENA_PurchaseNo' ) , -1 );

	ADR_Source := Part;

	if SelectMenu( YNMenu , @DoPurchaseRedraw ) = 1 then begin
		if NAttValue( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits ) >= Cost then begin
			{ Copy the gear, then stick it in inventory. }
			Part := CloneGear( Part );
			InsertSubCom( HQCamp^.Source , Part );

			{ Reduce the buyer's cash by the cost of the gear. }
			AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , -Cost );

			DialogMSG( ReplaceHash( MsgString( 'ARENA_PurchaseComplete' ) , GearName( Part ) ) );
		end else begin
			{ Not enough cash to buy... }
			DialogMSG( ReplaceHash( MsgString( 'ARENA_PurchaseFail' ) , GearName( Part ) ) );
		end;
	end;

	DisposeRPGMenu( YNMenu );
end;

procedure AHQShopping( HQCamp: CampaignPtr );
	{ Create a list of mecha which are within this unit's price }
	{ range, then allow the user to browse the list and maybe }
	{ purchase some. }
var
	MekList: GearPtr;
	MekMenu: RPGMenuPtr;
	m1,mek: GearPtr;	{ The start of the mecha file, }
			{ and the mek being considered for purchase. }
	N: Integer;
	Factions,DefaultColors: String;
begin
	{ Create the list of mecha that can be purchased. }
	MekList := AggregatePattern( '*.txt' , Design_Directory );

	{ Create the list of factions that mecha can be purchased from. }
	Factions := 'GENERAL';
	mek := SeekCurrentLevelGear( HQCamp^.Source^.InvCom , GG_Faction , HQFac( HQCamp ) );
	if mek <> Nil then begin
		Factions := Factions + ' ' + SAttValue( mek^.SA , 'DESIG' );
		DefaultColors := 'SDL_COLORS <' + SAttValue( mek^.SA , 'mecha_colors' ) + '>';
	end else begin
		DefaultColors := 'SDL_COLORS <66 121 179 210 215 80 205 25 0>';
	end;

	{ Add the faction designations for the earned mecha source rewards. }
	mek := Factions_List;
	while mek <> Nil do begin
		if NAttValue( HQCamp^.Source^.NA , NAG_AHQMechaSource , Mek^.S ) <> 0 then begin
			Factions := Factions + ' ' + SAttValue( mek^.SA , 'DESIG' );
		end;
		mek := mek^.Next;
	end;

	{ Remove non-mecha, expensive mecha, and extra-factional mecha. }
	{ I don't think extra-factional is a word, but it's 1:30 at night and you know what I mean. }
	mek := MekList;
	while mek <> Nil do begin
		M1 := mek^.Next;
		{ If it doesn't fit, remove it. }
		if ( Mek^.G <> GG_Mecha ) or ( ModifiedCost( HQCamp , GearCost( Mek ) , NAS_Shopping ) > HQCash( HQCamp ) ) or not MechaMatchesFaction( Mek , Factions ) then RemoveGear( MekList , Mek )
		{ If it does fit, paint it. }
		else SetSAtt( Mek^.SA , DefaultColors );
		mek := M1;
	end;

	{ Create the mecha menu. }
	MekMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_FieldHQMenu );
	BuildSiblingMenu( MekMenu , MekList );
	RPMSortAlpha( MekMenu );
	AddRPGMenuItem( MekMenu , MsgString( 'Exit' ) , -1 );

	repeat
		ADR_Source := MekList;
		ADR_SourceMenu := MekMenu;

		{ Prompt the user for a file selection. }
		N := SelectMenu( MekMenu , @PurchaseHardwareRedraw );

		if N > 0 then begin
			Mek := RetrieveGearSib( MekList , N );
			PurchaseGear( HQCamp , Mek );
			UpdatePilotMechaMenus( HQCamp );
		end;
	until N = -1;

	{ Get rid of dynamic resources. }
	DisposeRPGMenu( MekMenu );
	DisposeGear( MekList );
end;

Procedure ViewMecha( HQCamp: CampaignPtr; PC: GearPtr );
	{ Examine this mecha. Call up a menu with options related to this }
	{ character. }
	Procedure SellMecha( SalePrice: LongInt );
		{ This mecha should be removed from the unit, and some cash gained. }
	begin
		DialogMsg( ReplaceHash( MsgString( 'ARENA_VMEK_SMI_SellItem' ) , GearName( PC ) ) );
		RemoveGear( HQCamp^.Source^.SubCom , PC );
		AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , SalePrice );
		PCSaveCampaign( HQCamp , Nil , False );
	end;
	Procedure AssignPilotForMecha;
		{ Select a pilot for this mecha, then associate the two. }
	var
		Mek: GearPtr;
		N: Integer;
	begin
		DialogMSG( ReplaceHash( MsgString( 'ARENA_VMEK_APFM_SelectPilot' ) , GearName( PC ) ) );

		ADR_Source := HQCamp^.Source^.SubCom;
		ADR_SourceMenu := ADR_PilotMenu;
		AddRPGMenuItem( ADR_PilotMenu , MsgString( 'CANCEL' ) , -1 );

		N := SelectMenu( ADR_PilotMenu , @ViewPilotRedraw );

		if ( N <> -1 ) then begin
			Mek := RetrieveGearSib( HQCamp^.Source^.SubCom , N );
			if Mek <> Nil then begin
				AssociatePilotMek( HQCamp^.Source^.SubCom , Mek , PC );
			end;
		end;

		{ Update the display. }
		UpdatePilotMechaMenus( HQCamp );
	end;
	Function InventoryValue: LongInt;
		{ Return the value of all gears in this mecha's general }
		{ inventory. }
	var
		I: GearPtr;
		Total: LongInt;
	begin
		I := PC^.InvCom;
		Total := 0;
		while I <> Nil do begin
			Total := Total + GearCost( I );
			I := I^.Next;
		end;
		InventoryValue := Total div SaleFactor;
	end;
	Procedure SellMechaInventory;
		{ This mecha's inventory should be deleted, and some cash gained. }
	var
		I: GearPtr;
	begin
		AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , InventoryValue );
		while PC^.InvCom <> Nil do begin
			I := PC^.InvCom;
			DialogMsg( ReplaceHash( MsgString( 'ARENA_VMEK_SMI_SellItem' ) , GearName( I ) ) );
			RemoveGear( PC^.InvCom , I );
		end;
		PCSaveCampaign( HQCamp , Nil , False );
	end;
	Procedure RenameMecha;
		{ Rename this mecha. Very easy. }
	var
		name: String;
	begin
		name := GetStringFromUser( ReplaceHash( MsgString( 'FHQ_Rename_Prompt' ) , GearName( PC ) ) , @ViewSourceMechaRedraw );
		if name <> '' then SetSAtt( PC^.SA , 'name <' + name + '>' );
	end;
var
	RPM: RPGMenuPtr;
	N: Integer;
	SalePrice,Cost: LongInt;
begin
	SalePrice := GearCost( PC ) div SaleFactor;
	repeat
		ADR_Source := PC;

		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaMechaMenu );

		AddRPGMenuItem( RPM , MsgString( 'ARENA_VMEK_AssignPilot' ) , 1 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VMEK_ViewInventory' ) , 5 );

		AddRPGMenuItem( RPM , MsgString( 'FHQ_Rename' ) , 7 );


		if HasSkill( HQCamp^.Source , NAS_MechaEngineering ) then AddRPGMenuItem( RPM , MsgString( 'ARENA_VMEK_EditParts' ) , 6 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VMEK_SellMecha' ) + ' ($' + BStr( SalePrice ) + ')' , -2 );
		if PC^.InvCom <> Nil then AddRPGMenuItem( RPM , MsgString( 'ARENA_VMEK_SellMechaInv' ) + ' ($' + BStr( InventoryValue ) + ')' , 4 );
		Cost := AHQRepairCost( HQCamp ,  PC );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_RepairUnit' ) , GearName( PC ) ) + ' ($' + BStr( Cost ) + ')' , 2 );
		end;

		Cost := ReloadMasterCost( PC , Reload_All_Weapons );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_ReloadUnit' ) , GearName( PC ) ) + ' ($' + BStr( Cost ) + ')' , 3 );
		end;

		AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

		N := SelectMenu( RPM , @ViewSourceMechaRedraw );
		DisposeRPGMenu( RPM );

		case N of
			1:	AssignPilotForMecha;
			2:	DoFullRepair( HQCamp , PC );
			3:	ArenaReloadMaster( HQCamp , PC );
			4:	begin
				SellMechaInventory;
				SalePrice := GearCost( PC ) div SaleFactor;
				end;
			5:	ArenaHQBackpack( HQCamp^.Source , PC , @BasicArenaRedraw );
			6:	MechaPartEditor( Nil , HQCamp^.Source^.SubCom , HQCamp^.Source , PC , @BasicArenaRedraw );
			7:	RenameMecha;
			-2:	SellMecha( SalePrice );
		end;
	until N < 0;
end;

Procedure ViewItem( HQCamp: CampaignPtr; Part: GearPtr );
	{ Examine this item. Call up a menu with options related to it. }
	Procedure SellItem( SalePrice: LongInt );
		{ This item should be removed from the unit, and some cash gained. }
	begin
		DialogMsg( ReplaceHash( MsgString( 'ARENA_VMEK_SMI_SellItem' ) , GearName( Part ) ) );
		RemoveGear( HQCamp^.Source^.SubCom , Part );
		AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , SalePrice );
		PCSaveCampaign( HQCamp , Nil , False );
	end;
	Procedure GiveItemToTeamMate;
		{ Give this item to whoever can hold it. }
	var
		RPM: RPGMenuPtr;
		Mek: GearPtr;
		N: Integer;
	begin
		{ Start by allocating the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaMechaMenu );

		{ Add all the whoevers that might be able to accept this item. }
		Mek := HQCamp^.Source^.SubCom;
		N := 1;
		while Mek <> Nil do begin
			if IsLegalInvCom( Mek , Part ) and ( Mek <> Part ) then begin
				AddRPGMenuItem( RPM , AHQMechaName( HQCamp , Mek ) , N );
			end;
			Inc( N );
			Mek := Mek^.Next;
		end;

		{ Select an item from the menu. }
		if RPM^.NumItem > 0 then begin
			DialogMsg( ReplaceHash( MsgString( 'ARENA_VITEM_GiveItem_Prompt' ) , GearName( Part ) ) );
			ADR_Source := HQCamp^.Source^.SubCom;
			ADR_SourceMenu := RPM;
			N := SelectMenu( RPM , @ViewMechaRedraw );
		end else begin
			N := -1;
		end;
		DisposeRPGMenu( RPM );

		if N > -1 then begin
			Mek := RetrieveGearSib( HQCamp^.Source^.SubCom , N );
			if Mek <> Nil then begin
				DelinkGear( HQCamp^.Source^.SubCom , Part );
				InsertInvCom( Mek , Part );
			end;
		end;
	end;
var
	RPM: RPGMenuPtr;
	N: Integer;
	SalePrice,Cost: LongInt;
begin
	SalePrice := GearCost( Part ) div SaleFactor;
	repeat
		ADR_Source := Part;

		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaMechaMenu );

		AddRPGMenuItem( RPM , MsgString( 'ARENA_VItem_SellItem' ) + ' ($' + BStr( SalePrice ) + ')' , -2 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VItem_GiveItem' ) , -3 );

		Cost := AHQRepairCost( HQCamp ,  Part );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_RepairUnit' ) , GearName( Part ) ) + ' ($' + BStr( Cost ) + ')' , 2 );
		end;

		Cost := ReloadMasterCost( Part , Reload_All_Weapons );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_ReloadUnit' ) , GearName( Part ) ) + ' ($' + BStr( Cost ) + ')' , 3 );
		end;

		AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

		N := SelectMenu( RPM , @ViewSourceMechaRedraw );
		DisposeRPGMenu( RPM );

		case N of

			2:	DoFullRepair( HQCamp , Part );
			3:	ArenaReloadMaster( HQCamp , Part );

			-2:	SellItem( SalePrice );
			-3:	GiveItemToTeamMate;
		end;
	until N < 0;
end;

procedure ExamineMecha( HQCamp: CampaignPtr );
	{ Examine the unit's mecha, and do any mecha-related things }
	{ that need doing. }
var
	N: Integer;
	Mek: GearPtr;
begin
	repeat
		UpdatePilotMechaMenus( HQCamp );
		AddRPGMenuItem( ADR_MechaMenu , MsgString( 'EXIT' ) , -1 );

		ADR_SourceMenu := ADR_MechaMenu;
		ADR_Source := HQCamp^.Source^.SubCom;
		N := SelectMenu( ADR_MechaMenu , @ViewMechaRedraw );

		if N > 0 then begin
			Mek := RetrieveGearSib( HQCamp^.Source^.SubCom , N );
			if Mek^.G = GG_Mecha then begin
				ViewMecha( HQCamp , Mek );
			end else begin
				ViewItem( HQCamp , Mek );
			end;
		end;

	until N = -1;
end;

Procedure HQSchool( HQCamp: CampaignPtr; PC: GearPtr );
	{ Let the teaching commence! I was hoping to use the services.pp/OpenSchool procedure, }
	{ but really this procedure is mostly a frontend for the DoleSkillExperience function }
	{ and making it work in both cases would be more trouble than it's worth. }
	{ The going rate for training is $100 = 1XP. }
	{ I should probably share the constants between both procedures... heh. }
const
	XPStep: Array [1..40] of Integer = (
		1,2,3,4,5, 6,7,8,9,10,
		12,15,20,25,50, 75,100,150,200,250,
		500,750,1000,1500,2000, 2500,3000,3500,4000,4500,
		5000,6000,7000,8000,9000, 10000,12500,15000,20000,25000
	);
	Knowledge_First_Bonus = 14;
	Knowledge_First_Penalty = 8;
	CostFactor = 250;
var
	SkillMenu,CostMenu: RPGMenuPtr;
	Skill,N: Integer;
	Cash: LongInt;
	DSLTemp: Boolean;
begin
	ADR_Source := PC;

	{ When using a school, can always learn directly. }
	DSLTemp := Direct_Skill_Learning;
	Direct_Skill_Learning := True;

	{ Step One: Create the skills menu. }
	SkillMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaPilotMenu );

	for N := 1 to NumSkill do begin
		if NAttValue( HQCamp^.Source^.NA , NAG_AHQSkillTrainer , N ) <> 0 then begin
			AddRPGMenuItem( SkillMenu , MsgString( 'SKILLNAME_' + BStr( N ) ) , N , SkillDescription( N ) );
		end;
	end;
	RPMSortAlpha( SkillMenu );
	AddRPGMenuItem( SkillMenu , MsgString( 'SCHOOL_Exit' ) , -1 );

	repeat
		{ Get a selection from the menu. }
		Skill := SelectMenu( SkillMenu , @ViewSourcePilotRedraw );

		{ If a skill was chosen, do the training. }
		if ( Skill >= 1 ) and ( Skill <= NumSkill ) then begin
			{ Create the CostMenu, and see how much the }
			{ player wants to spend. }
			CostMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaPilotMenu );
			Cash := HQCash( HQCamp );

			{ Add menu entries for each of the cost values }
			{ that the PC can afford. }
			for N := 1 to 40 do begin
				if XPStep[ N ] * CostFactor <= Cash then begin
					AddRPGMenuItem( CostMenu , '$' + BStr( XPStep[ N ] * CostFactor ) , N );
				end;
			end;

			{ Add the exit option, so that we'll never have }
			{ an empty menu. }
			AddRPGMenuItem( CostMenu , MsgString( 'SCHOOL_ExitCostSelector' ) , -1 );

			N := SelectMenu( CostMenu , @ViewSourcePilotRedraw );
			DisposeRPGMenu( CostMenu );

			{ If CANCEL wasn't selected, take away the cash }
			{ and give the PC some experience. }
			if N <> -1 then begin
				AddNAtt( HQCamp^.Source^.NA , NAG_Experience , NAS_Credits , -( XPStep[ N ] * CostFactor ) );

				{ Calculate the number of XPs earned. }
				Cash := XPStep[ N ];

				{ Add bonus for high Knowledge stat, }
				{ or penalty for low Knowledge stat. }
				if CStat( PC , STAT_Knowledge ) >= Knowledge_First_Bonus then begin
					Cash := ( Cash * ( 100 + ( CStat( PC , STAT_Knowledge ) - Knowledge_First_Bonus + 1 ) * 5 ) ) div 100;
				end else if CStat( PC , STAT_Knowledge ) <= Knowledge_First_Penalty then begin
					Cash := ( Cash * ( 100 - ( Knowledge_First_Penalty - CStat( PC , STAT_Knowledge ) + 1 ) * 10 ) ) div 100;
					if Cash < 1 then Cash := 1;
				end;

				DialogMsg( ReplaceHash( MsgString( 'SCHOOL_STUDY' ) , MsgString( 'SKILLNAME_' + BStr( Skill ) ) ) );
				if DoleSkillExperience( PC , Skill , Cash ) then begin
					DialogMsg( MsgString( 'SCHOOL_Learn' + BStr( Random( 5 ) + 1 ) ) );
				end;
			end;
		end;
	until Skill = -1;

	{ Restore the Direct_Skill_Learning setting. }
	Direct_Skill_Learning := DSLTemp;

	DisposeRPGMenu( SkillMenu );
end;

Procedure ViewCharacter( HQCamp: CampaignPtr; PC: GearPtr );
	{ Examine this character. Call up a menu with options related to this }
	{ character. }
	Procedure RemoveCharacter;
		{ This character should be delinked from the unit and saved to disk. }
	begin
		DelinkGear( HQCamp^.Source^.SubCom , PC );
		SaveChar( PC );
		PCSaveCampaign( HQCamp , Nil , False );
		DisposeGear( PC );
	end;
	Procedure AssignMechaForPilot;
		{ Select a mecha for this pilot, then associate the two. }
	var
		Mek: GearPtr;
		N: Integer;
	begin
		DialogMSG( ReplaceHash( MsgString( 'ARENA_VCHAR_AMFP_SelectMecha' ) , GearName( PC ) ) );

		ADR_Source := HQCamp^.Source^.SubCom;
		ADR_SourceMenu := ADR_MechaMenu;
		AddRPGMenuItem( ADR_MechaMenu , MsgString( 'CANCEL' ) , -1 );

		N := SelectMenu( ADR_MechaMenu , @ViewMechaRedraw );

		if ( N <> -1 ) then begin
			Mek := RetrieveGearSib( HQCamp^.Source^.SubCom , N );
			if Mek <> Nil then begin
				AssociatePilotMek( HQCamp^.Source^.SubCom , PC , Mek );
			end;
		end;

		{ Update the display. }
		UpdatePilotMechaMenus( HQCamp );
	end;

var
	RPM: RPGMenuPtr;
	N: Integer;
	Cost: LongInt;
begin
	repeat
		ADR_Source := PC;

		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaPilotMenu );

		AddRPGMenuItem( RPM , MsgString( 'ARENA_VCHAR_DoTraining' ) , 4 );
		if HasSkillTrainers( HQCamp ) then AddRPGMenuItem( RPM , MSgString( 'ARENA_OpenSchool' ) , 6 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VCHAR_ViewInventory' ) , 5 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VCHAR_AssignMecha' ) , 1 );
		AddRPGMenuItem( RPM , MsgString( 'ARENA_VCHAR_RemoveCharacter' ) , -2 );
		Cost := AHQRepairCost( HQCamp ,  PC );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_RepairUnit' ) , GearName( PC ) ) + ' ($' + BStr( Cost ) + ')' , 2 );
		end;

		Cost := ReloadMasterCost( PC , Reload_All_Weapons );
		if ( Cost > 0 ) and ( Cost <= HQCash( HQCamp ) ) then begin
			AddRPGMenuItem( RPM , ReplaceHash( MsgSTring( 'ARENA_ReloadUnit' ) , GearName( PC ) ) + ' ($' + BStr( Cost ) + ')' , 3 );
		end;

		AddRPGMenuItem( RPM , MsgString( 'EXIT' ) , -1 );

		N := SelectMenu( RPM , @ViewSourcePilotRedraw );
		DisposeRPGMenu( RPM );

		case N of
			1:	AssignMechaForPilot;
			2:	DoFullRepair( HQCamp , PC );
			3:	ArenaReloadMaster( HQCamp , PC );
			4:	DoTraining( Nil , PC , @BasicArenaRedraw );
			5:	ArenaHQBackpack( HQCamp^.Source , PC , @BasicArenaRedraw );
			6:	HQSchool( HQCamp , PC );
			-2:	RemoveCharacter;
		end;
	until N < 0;
end;

procedure ExamineCharacters( HQCamp: CampaignPtr );
	{ Take a look through this unit's characters. Maybe do stuff to them. }
var
	N: Integer;
begin
	repeat
		UpdatePilotMechaMenus( HQCamp );
		AddRPGMenuItem( ADR_PilotMenu , MsgString( 'EXIT' ) , -1 );

		ADR_SourceMenu := ADR_PilotMenu;
		ADR_Source := HQCamp^.Source^.SubCom;
		N := SelectMenu( ADR_PilotMenu , @ViewPilotRedraw );

		if N > 0 then begin
			ViewCharacter( HQCamp , RetrieveGearSib( HQCamp^.Source^.SubCom , N ) );
		end;

	until N = -1;
end;

Procedure DeliverMissionDebriefing( Adv,Scene: GearPtr );
	{ Deliver any pending news to the player. The big news will be which characters died, }
	{ which ones were rescued by the Medicine skill, which mecha were destroyed, and which }
	{ mecha were returned from the brink. }
	{ If any characters died or mecha were lost, a small renown penalty will be applied to }
	{ the team. }
	Procedure GiveTheNews( NPC: Integer; const Msg_Key: String; NameList: SAttPtr );
		{ The provided NPC will give the provided message about the provided names. }
	begin
		while NameList <> Nil do begin
			HQMonologue( Adv, NPC , ReplaceHash( ArenaNPCMessage( Adv , NPC , Msg_Key ) , NameList^.Info ) );
			NameList := NameList^.Next;
		end;
	end;
var
	Dead,Healed,Destroyed,Fixed,Captured,SList: SAttPtr;	{ The various message classes. }
begin
	Dead := Nil;
	Healed := Nil;
	Destroyed := Nil;
	Fixed := Nil;
	Captured := Nil;

	{ Step one: Look for matching messages. }
	SList := Scene^.SA;
	while SList <> Nil do begin
		if HeadMatchesString( ARENAREPORT_CharRecovered , SList^.Info ) then StoreSAtt( Healed , RetrieveAString( SList^.Info ) )
		else if HeadMatchesString( ARENAREPORT_CharDied , SList^.Info ) then begin
			StoreSAtt( Dead , RetrieveAString( SList^.Info ) );
			AddNAtt( Adv^.NA , NAG_CharDescription , NAS_Renowned , -2 );
		end else if HeadMatchesString( ARENAREPORT_MechaRecovered , SList^.Info ) then StoreSAtt( Fixed , RetrieveAString( SList^.Info ) )
		else if HeadMatchesString( ARENAREPORT_MechaDestroyed , SList^.Info ) then begin
			StoreSAtt( Destroyed , RetrieveAString( SList^.Info ) );
			AddNAtt( Adv^.NA , NAG_CharDescription , NAS_Renowned , -1 );
		end else if HeadMatchesString( ARENAREPORT_MechaObtained , SList^.Info ) then StoreSAtt( Captured , RetrieveAString( SList^.Info ) )
		;
		SList := SList^.Next;
	end;

	{ Step two: Report the stuff we just found out. }
	GiveTheNews( ANPC_Medic , 'PCHealed' , Healed );
	GiveTheNews( ANPC_Medic , 'PCDead' , Dead );
	GiveTheNews( ANPC_Mechanic , 'MechaFixed' , Fixed );
	GiveTheNews( ANPC_Mechanic , 'MechaDestroyed' , Destroyed );
	GiveTheNews( ANPC_Supply , 'MechaObtained' , Captured );

	DisposeSAtt( Dead );
	DisposeSAtt( Healed );
	DisposeSAtt( Destroyed );
	DisposeSAtt( Fixed );
	DisposeSAtt( Captured );
end;

Procedure DeliverSalvageReport( Adv , PCList: GearPtr );
	{ Report on any salvage recovered from the battle. }
begin
	while PCList <> Nil do begin
		if NAttValue( PCList^.NA , NAG_MissionReport , NAS_WasSalvaged ) <> 0 then begin
			HQMonologue( Adv, ANPC_Supply , ReplaceHash( ArenaNPCMessage( Adv , ANPC_Supply , 'SalvageReport' ) , FullGearName( PCList ) ) );
		end;
		PCList := PCList^.Next;
	end;
end;

Procedure DeliverPersonalDebriefing( Adv , Scene: GearPtr );
	{ Deliver personal debriefing messages from the faction NPCs. }
var
	SList,Messages: SAttPtr;
	NPC: LongInt;
begin
	{ Step one: Look for matching messages. }
	SList := Scene^.SA;
	Messages := Nil;
	while SList <> Nil do begin
		if HeadMatchesString( ARENAREPORT_Personal , SList^.Info ) then StoreSAtt( Messages , RetrieveAString( SList^.Info ) );
		SList := SList^.Next;
	end;

	{ Step Two: Deliver those messages. }
	SList := Messages;
	while SList <> Nil do begin
		NPC := ExtractValue( SList^.Info );
		HQMonologue( Adv, NPC , SList^.Info );
		SList := SList^.Next;
	end;

	{ Step three- dispose of the messages. }
	DisposeSAtt( Messages );
end;

Function MissionFrontEnd( HQCamp: CampaignPtr; Scene,PCForces: GearPtr ): Integer;
	{ Play the mission, along with all the needed wrapper stuff. }
	Procedure ReportRenownGain( R0,R1: Integer );
		{ The team has gained some renown. If this causes a change in rank, }
		{ the Intel officer will let the player know. }
		{ R0 is initial renown, R1 is current renown. }
	var
		T,NewRank: Integer;
	begin
		NewRank := 0;
		for t := 1 to 4 do begin
			if ( R1 > ( t * 20 ) ) and ( R0 <= ( t * 20 ) ) then NewRank := T + 1;
		end;
		if NewRank <> 0 then HQMonologue( HQCamp^.Source , ANPC_Intel , ReplaceHash( ArenaNPCMessage( HQCamp^.Source , ANPC_Intel , 'GainPromotion' ) , MsgSTring( 'AHQRANK_' + BStr( NewRank ) ) ) );
	end;
	Procedure ReportRenownLoss( R0,R1: Integer );
		{ Check for the team's rank dropping; if so, report it. }
		{ R0 is initial renown, R1 is current renown. }
	var
		T,NewRank: Integer;
	begin
		NewRank := 0;
		for t := 1 to 4 do begin
			if ( R0 > ( t * 20 ) ) and ( R1 <= ( t * 20 ) ) then NewRank := T;
		end;
		if NewRank <> 0 then HQMonologue( HQCamp^.Source , ANPC_Intel , ReplaceHash( ArenaNPCMessage( HQCamp^.Source , ANPC_Intel , 'LosePromotion' ) , MsgSTring( 'AHQRANK_' + BStr( NewRank ) ) ) );
	end;
var
	N: Integer;
	C0,C1: LongInt;	{ Cash0, Cash1 }
	R0,R1: Integer;	{ Renown0, Renown1 }
begin
	{ Save the initial money and renown. }
	C0 := HQCash( HQCamp );
	R0 := HQRenown( HQCamp );

	N := ScenePlayer( HQCamp , Scene , PCForces );

	{ After the mission is over, deliver any reports. }
	if N <> 0 then begin
		{ Deliver the member debriefings first. }
		DeliverPersonalDebriefing( HQCamp^.Source , Scene );

		{ The mission has ended properly; it wasn't quit. }
		{ Do the debriefing here. }
		C1 := HQCash( HQCamp );
		if C1 > C0 then begin
			HQMonologue( HQCamp^.Source , ANPC_Commander , ReplaceHash( ArenaNPCMessage( HQCamp^.Source , ANPC_Commander , 'ReportEarnings' ) , BStr( C1 - C0 ) ) );
		end;

		DeliverMissionDebriefing( HQCamp^.Source , Scene );

		DeliverSalvageReport( HQCamp^.Source , PCForces );
	end;

	{ After finishing the battle, get rid of the scene. }
	RemoveGear( HQCamp^.Source^.InvCom , Scene );

	{ Reinsert the surviving PCForces into the unit. }
	PostMissionCleanup( HQCamp , PCForces );

	{ See how much money the repairs/reload cost. }
	if N <> 0 then begin
		C0 := HQCash( HQCamp );
		if C0 < C1 then HQMonologue( HQCamp^.Source , ANPC_Mechanic , ReplaceHash( ArenaNPCMessage( HQCamp^.Source , ANPC_Mechanic , 'ReportExpenses' ) , BStr( C1 - C0 ) ) );

		R1 := HQRenown( HQCamp );
		if R1 > R0 then ReportRenownGain( R0 , R1 )
		else if R1 < R0 then ReportRenownLoss( R0 , R1 );
	end;

	MissionFrontEnd := N;
end;

Function PlayArenaMission( HQCamp: CampaignPtr; SelectionMode: Byte ): Boolean;
	{ Play an arena mission. Yahoo! }
	{ Return TRUE if the mission was completed, or FALSE if the mission was }
	{ quit in progress. }
	Function SelectAMission: GearPtr;
		{ Select a mission. }
	var
		RPM: RPGMenuPtr;
		N: Integer;
		M: GearPtr;
	begin
		{ Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_SAMMenu );
		AttachMenuDesc( RPM , ZONE_SAMText );

		{ Add all the missions to the menu. }
		N := 1;
		M := HQCamp^.Source^.InvCom;
		while M <> Nil do begin
			if M^.G = GG_Scene then begin
				AddRPGMenuItem( RPM , GearName( M ) , N , SAttValue( M^.SA , 'DESC' ) + ' ($' + BStr( ExpectedMissionReward( HQCamp , M ) ) + ')' );
				Inc( N );
			end;
			M := M^.Next;
		end;

		RPMSortAlpha( RPM );
		AlphaKeyMenu( RPM );
		AddRPGMenuItem( RPM , MsgString( 'CANCEL' ) , -2 );

		N := SelectMenu( RPM , @SelectAMissionRedraw );
		DisposeRPGMenu( RPM );

		if N > -1 then begin
			M := GetMission( HQCamp , N );
		end else begin
			M := Nil;
		end;
		SelectAMission := M;
	end;
	Function GetCustomMission( LList: GearPtr ): GearPtr;
		{ Select one of the missions from LList. Initialize it, }
		{ stick it in the adventure, and return a pointer to it. }
	var
		RPM: RPGMenuPtr;
		N: Integer;
		M: GearPtr;
	begin
		{ Step one- select something from the list. This is going to require }
		{ a menu. }
		{ Create the menu. }
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_SAMMenu );
		AttachMenuDesc( RPM , ZONE_SAMText );

		{ Add all the missions to the menu. }
		N := 1;
		M := LList;
		while M <> Nil do begin
			AddRPGMenuItem( RPM , GearName( M ) , N , SAttValue( M^.SA , 'DESC' ) );
			Inc( N );
			M := M^.Next;
		end;

		RPMSortAlpha( RPM );
		AlphaKeyMenu( RPM );
		AddRPGMenuItem( RPM , MsgString( 'CANCEL' ) , -2 );

		N := SelectMenu( RPM , @SelectAMissionRedraw );
		DisposeRPGMenu( RPM );

		if N > -1 then begin
			{ Clone the mission we want. Set its name to DEBUG. }
			M := CloneGear( RetrieveGearSib( LList , N ) );
			SetSAtt( M^.SA , 'name <DEBUG>' );

			{ Attempt to place it in the adventure. }
			if not InsertArenaMission( HQCamp^.Source , M , HQRenown( HQCamp ) ) then M := Nil;
		end;
		GetCustomMission := M;
	end;
	Function SelectAMForces: GearPtr;
		{ Select a number of pilots for this mission. Only pilots who have }
		{ mecha will be considered. }
	var
		ECM: RPGMenuPtr;
		PCForces,Mek,Pilot: GearPtr;
		N: Integer;
	begin
		PCForces := Nil;
		ADR_NumPilotsSelected := 0;
		ADR_PilotsAllowed := 5;
		Repeat
			{ Create the menu. }
			ECM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_MemoText );
			Mek := HQCamp^.Source^.SubCom;
			N := 1;
			while Mek <> Nil do begin
				if ( Mek^.G = GG_Mecha ) then begin
					Pilot := FindMechasPilot( HQCamp^.Source , Mek );
					if Pilot <> Nil then AddRPGMenuItem( ECM , GearName( Pilot ) + ' [' + GearName( Mek ) + ']' , N );
				end;
				Mek := Mek^.Next;
				Inc( N );
			end;

			RPMSortAlpha( ECM );
			AlphaKeyMenu( ECM );
			AddRPGMenuItem( ECM , MsgString( 'ARENA_SAMF_StartMission' ) , -1 );
			AddRPGMenuItem( ECM , MsgString( 'CANCEL' ) , -2 );

			N := SelectMenu( ECM , @SelectAMForcesRedraw );
			DisposeRPGMenu( ECM );

			if N > -1 then begin
				Mek := RetrieveGearSib( HQCamp^.Source^.SubCom , N );
				Pilot := FindMechasPilot( HQCamp^.Source , Mek );
				DialogMsg( ReplaceHash( MsgString( 'ARENA_SAMF_AddPilot' ) , GearName( Pilot ) ) );
				DelinkGear( HQCamp^.Source^.SubCom , Mek );
				DelinkGear( HQCamp^.Source^.SubCom , Pilot );
				AppendGear( PCForces , Mek );
				AppendGear( PCForces , Pilot );
				inc( ADR_NumPilotsSelected );
			end;
		until ( N < 1 ) or ( ADR_NumPilotsSelected >= ADR_PilotsAllowed );
		if N = -2 then begin
			InsertSubCom( HQCamp^.Source , PCForces );
			PCForces := Nil;
			DialogMsg( MsgString( 'ARENA_SAMF_Cancel' ) );
		end;
		SelectAMForces := PCForces;
	end;
var
	PCForces,Scene: GearPtr;
	N: Integer;
begin
	{ Start by selecting the mission. }
	if NumMissions( HQCamp ) < 1 then AddMissions( HQCamp , HQMaxMissions( HQCamp ) );
	if SelectionMode = PAM_Debug_Missions then begin
		{ Select an insert a mission from the master list for }
		{ debugging purposes. }
		Scene := GetCustomMission( Arena_Mission_Master_List );
	end else if SelectionMode = PAM_Debug_Core then begin
		{ Select and insert a mission from the core campaign }
		{ list for debugging purposes. }
		Scene := GetCustomMission( Core_Mission_Master_List );
	end else begin
		Scene := SelectAMission;
	end;
	if Scene = Nil then Exit( True );

	{ Start by selecting the PCForces. }
	PCForces := SelectAMForces;

	if PCForces <> Nil then begin
		{ Prep the mission, and pass to the mission front end. }
		PrepMission( HQCamp , Scene );
		N := MissionFrontEnd( HQCamp , Scene , PCForces );

	end else begin
		{ Selection was cancelled. }
		N := 1;
	end;
	PlayArenaMission := N <> 0;
end;

Procedure CreateNewPilot( Camp: CampaignPtr );
	{ Create a new pilot, and add it to the unit. }
var
	Egg,PC,S: GearPtr;
begin
	Egg := CharacterCreator( HQFac( Camp ) );
	if Egg <> Nil then begin
		PC := Nil;
		while Egg^.SubCom <> Nil do begin
			S := Egg^.SubCom;
			DelinkGear( Egg^.SubCom , S );
			AppendGear( PC , S );
		end;
		DisposeGear( Egg );
		StripAllMecha( PC );
		InsertSubCom( Camp^.Source , PC );
	end;
end;

Procedure CheckFactionsPresent( Adv: GearPtr );
	{ Check to make sure that all of the factions which currently exist are represented }
	{ in this adventure. Update the alliegances as necessary. }
	Procedure ModifyFacRelations( NewFac: GearPtr );
		{ NewFac has just been added to the game. Check through the existing factions, and }
		{ make sure they all have the appropriate reaction score for it. }
	var
		Fac,ProtoFac: GearPtr;
	begin
		Fac := Adv^.InvCom;
		while Fac <> Nil do begin
			if ( Fac^.G = GG_Faction ) and ( NewFac <> Fac ) then begin
				{ We've found a faction, and it's not the new faction. How does }
				{ this faction feel about the new faction? The answer can be found }
				{ in the faction prototype. }
				ProtoFac := SeekCurrentLevelGear( Factions_List , GG_Faction , Fac^.S );
				if ProtoFac <> Nil then begin
					SetNAtt( Fac^.NA , NAG_FactionScore , NewFac^.S , NAttValue( ProtoFac^.NA , NAG_FactionScore , NewFac^.S ) );
				end;
			end;
			Fac := Fac^.Next;
		end;
	end;
var
	FLF,InGameFac: GearPtr;
begin
	{ Start by looking through the Faction List Factions }
	FLF := Factions_List;
	while FLF <> Nil do begin
		InGameFac := SeekCurrentLevelGear( Adv^.InvCom , GG_Faction , FLF^.S );
		if InGameFac = Nil then begin
			{ We don't have this faction in the campaign. Horrors! In order to fix things, }
			{ copy it over, then copy over all the faction relations. }
			InGameFac := CloneGear( FLF );
			InsertInvCom( Adv , InGameFac );
			ModifyFacRelations( InGameFac );
		end;
		FLF := FLF^.Next;
	end;
end;

Procedure CheckFactionPersonalities( Adv: GearPtr );
	{ Check to make sure that the faction personalities are loaded, and that all }
	{ positions are accounted for. }
var
	NPCSet,NPCFile,FacNPCs,NewNPC: GearPtr;
	T: Integer;
begin
	{ Search for the NPC Set. }
	NPCSet := SeekCurrentLevelGear( Adv^.InvCom , GG_Set , GS_CharacterSet );
	if NPCSet = Nil then begin
		{ We don't have a NPCSet. Horrors! Better add one. }
		NPCSet := NewGear( Nil );
		NPCSet^.G := GG_Set;
		NPCSet^.S := GS_CharacterSet;
		InsertInvCom( Adv , NPCSet );

		{ Load the NPC file from disk, and copy over the appropriate NPCs for the adventure faction. }
		NPCFile := LoadFile( 'ARENADATA_Personalities.txt' , Series_Directory );
		FacNPCs := SeekCurrentLevelGear( NPCFile , GG_Set , NAttValue( Adv^.NA , NAG_Personal , NAS_FactionID ) );
		if FacNPCs <> Nil then begin
			{ We found a set containing this faction's members. Move them over to the NPCSet. }
			while FacNPCs^.InvCom <> Nil do begin
				NewNPC := FacNPCs^.InvCom;
				DelinkGear( FacNPCs^.InvCom , NewNPC );
				InsertInvCom( NPCSet , NewNPC );
			end;

		end else begin
			{ We found nothing. Create a bunch of stand-in NPCs. }
			for t := 1 to NumArenaNPCs do begin
				NewNPC := LoadNewNPC( 'CITIZEN' , True );
				SetNAtt( NewNPC^.NA , NAG_Personal , NAS_CID , T );
				InsertInvCom( NPCSet , NewNPC );
			end;
		end;
		DisposeGear( NPCFile );
	end;
end;

Procedure WipeMissions( HQCamp: CampaignPtr );
	{ Delete all currently loaded missions, and regenerate the list. }
var
	M,M2: GearPtr;
begin
	{ Also print the context, for debugging purposes. }
	DialogMsg( HQContext( HQCamp ) );
	M := HQCamp^.Source^.InvCom;
	while M <> Nil do begin
		M2 := M^.Next;
		if M^.G = GG_Scene then begin
			RemoveGear( HQCamp^.Source^.InvCom , M );
		end;
		M := M2;
	end;
end;

Procedure PlayArenaCampaign( Camp: CampaignPtr );
	{ Play this arena campaign. }
var
	N: Integer;
	RPM: RPGMenuPtr;
begin
	{ Set the campaign pointer for redraw purposes. }
	ADR_HQCamp := Camp;

	{  As soon as the campaign has been loaded, do some checks to make sure it has everything }
	{ it needs. These checks are done here so that save files from previous versions will remain }
	{ compatable with the current version. }
	CheckFactionsPresent( Camp^.Source );
	CheckFactionPersonalities( Camp^.Source );

	{ If Camp^.GB exists, then the game was saved in the middle of a battle. }
	{ Handle that battle before heading to the main menu. }
	if Camp^.GB <> Nil then begin
		N := MissionFrontEnd( Camp , Camp^.GB^.Scene , Nil );

		{ If a quit signal was recieved, just exit without going to }
		{ the main menu below. }
		if N = 0 then Exit;
	end else begin
		N := 1;

	end;

	{ Main Menu here }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaInfo );
	AddRPGMenuItem( RPM , MsgSTring( 'ARENA_ExamineCharacters' ) , 5 );
	AddRPGMenuItem( RPM , MsgSTring( 'ARENA_ExamineMecha' ) , 1 );
	AddRPGMenuItem( RPM , MsgSTring( 'ARENA_PurchaseHardware' ) , 2 );
	AddRPGMenuItem( RPM , MsgString( 'ARENA_HireCharacter' ) , 3 );
	AddRPGMenuItem( RPM , MsgString( 'ARENA_CreateNewCharacter' ) , 4 );
	AddRPGMenuItem( RPM , MsgString( 'ARENA_EnterCombat' ) , 6 );
	if ArenaMode_Wizard then begin
		AddRPGMenuItem( RPM , 'Debug Missions' , 7 );
		AddRPGMenuItem( RPM , 'Debug Core Campaign' , 8 );
		AddRPGMenuItem( RPM , 'Wipe Missions' , 9 );
	end;
	AddRPGMenuItem( RPM , MsgString( 'ARENA_ExitToMain' ) , 0 );
	RPM^.mode := RPMNoCancel;

	repeat
		UpdatePilotMechaMenus( Camp );
		N := SelectMenu( RPM , @BasicArenaRedraw );

		Case N of
			1: ExamineMecha( Camp );
			2: AHQShopping( Camp );
			3: AddPilotToUnit( Camp );
			4: CreateNewPilot( Camp );
			5: ExamineCharacters( Camp );
			6: if not PlayArenaMission( Camp , PAM_Regular ) then N := -1;
			7: if not PlayArenaMission( Camp , PAM_Debug_Missions ) then N := -1;
			8: if not PlayArenaMission( Camp , PAM_Debug_Core ) then N := -1;
			9: WipeMissions( Camp );
		end;

	until N < 1;

	{ Save the campaign on the way out. }
	{ Don't save the campaign if the game was saved in combat! }
	if N <> -1 then PCSaveCampaign( Camp , Nil , False );

	{ Dispose of dynamic resources. }
	DisposeRPGMenu( RPM );

	{ Clear the campaign pointer. }
	ADR_HQCamp := Nil;

	{ Also get rid of the two menus. }
	DisposeRPGMenu( ADR_PilotMenu );
	DisposeRPGMenu( ADR_MechaMenu );
end;

Procedure StartArenaCampaign;
	{ Initialize a new Arena campaign and start it. }
	Function SelectAFaction: Integer;
		{ Select a faction for this arena unit. }
	var
		RPM: RPGMenuPtr;
		Fac: GearPtr;
		N: Integer;
	begin
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ArenaInfo );
		AttachMenuDesc( RPM , ZONE_Dialog );
		RPM^.mode := RPMNoCancel;
		Fac := Factions_List;
		while Fac <> Nil do begin
			if AStringHasBString( SAttValue( Fac^.SA , 'TYPE' ) , 'ARENAOK' ) then begin
				AddRPGMenuItem( RPM , GearName( Fac ) , Fac^.S , SAttValue( Fac^.SA , 'DESC' ) );
			end;
			Fac := Fac^.Next;
		end;
		RPMSortALpha( RPM );
		AlphaKeyMenu( RPM );
		N := SelectMenu( RPM , @BasicArenaRedraw );
		DisposeRPGMenu( RPM );
		SelectAFaction := N;
	end;
var
	Camp: CampaignPtr;
	Factions: GearPtr;
	name: String;
begin
	{ Create the campaign and the adventure. }
	Camp := NewCampaign;
	Camp^.Source := LoadFile( 'arenastub.txt' , Series_Directory );

	{ Insert the factions into the adventure. }
	Factions := AggregatePattern( 'FACTIONS_*.txt' , Series_Directory );
	InsertInvCom( Camp^.Source , Factions );

	{ Select one faction for this unit. }
	SetNAtt( Camp^.Source^.NA , NAG_Personal , NAS_FactionID , SelectAFaction );

	{ Give the new arena unit a name. }
	name := GetStringFromUser( MsgString( 'ARENA_NewArenaName' ) , @BasicArenaRedraw );

	if name <> '' then begin
		{ Store the name. }
		SetSAtt( Camp^.Source^.SA , 'name <' + name + '>' );

		{ Actually play with the new campaign. }
		PlayArenaCampaign( Camp );
	end;

	{ Once we're finished, get rid of the campaign. }
	DisposeCampaign( Camp );
end;

Procedure RestoreArenaCampaign( RDP: RedrawProcedureType );
	{ Load an arena campaign from disk and start it. }
var
	RPM: RPGMenuPtr;
	rpgname: String;	{ Campaign Name }
	Camp: CampaignPtr;
	F: Text;		{ A File }
begin
	{ Create a menu listing all the units in the SaveGame directory. }
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Title_Screen_Menu );
	BuildFileMenu( RPM , Save_Unit_Base + Default_Search_Pattern );

	{ If any units are found, allow the player to load one. }
	if RPM^.NumItem > 0 then begin
		RPMSortAlpha( RPM );
		DialogMSG('Select campaign file to load.');

		rpgname := SelectFile( RPM , RDP );

		if rpgname <> '' then begin
			Assign(F, Save_Game_Directory + rpgname );
			reset(F);
			Camp := ReadCampaign(F);
			Close(F);
			PlayArenaCampaign( Camp );
			DisposeCampaign( Camp );
		end;
	end;

	DisposeRPGMenu( RPM );
end;

initialization
	{ Set all things to NIL to begin with. }
	ADR_PilotMenu := Nil;
	ADR_MechaMenu := Nil;
	ADR_HQCamp := Nil;

	ANPC_MasterPersona := LoadFile( 'ARENADATA_NPCMessages.txt' , Series_Directory );

	Arena_Mission_Master_List := LoadRandomSceneContent( 'ARENAMISSION_*.txt' , Series_Directory );
	Core_Mission_Master_List := LoadRandomSceneContent( 'ARENACORE_*.txt' , Series_Directory );


finalization
	DisposeGear( Arena_Mission_Master_List );
	DisposeGear( Core_Mission_Master_List );
	DisposeGear( ANPC_MasterPersona );

end.
