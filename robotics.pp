unit robotics;
	{	This unit handles the Robotics skill. Take some spare parts }
	{	and build yourself a plastic pal who's fun to be with. }
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

{
	Overview:
	To build a robot, first you select a list of components. These components
	provide you with a pool of points which are then spent to purchase a frame
	and customize it. The four types of points are Build, Armor, Computer, and Power.

	Build is the generic currency, needed for everything.
	Armor contributes to BOD and the final armor value of the robot.
	Computer contributes to PER, CRA, KNO, and CHA
	Power contributes to REF, SPD, and EGO
}


interface

uses gears,locale;

Procedure BuildRobot( GB: GameBoardPtr; PC: GearPtr );


implementation

uses 	gearutil,ghchars,texutil,arenacfe,ability,ui4gh,menugear,
	rpgdice,ghmodule,ghholder,ghmovers,action,narration,interact,
	arenascript,gearparser,
{$IFDEF ASCII}
	vidgfx,vidmenus,vidinfo;
{$ELSE}
	sdlgfx,sdlmenus,sdlinfo;
{$ENDIF}

const
	Num_Robot_Skill = 9;
	Robot_Skill: Array [1..Num_Robot_Skill] of Byte = (
		NAS_Awareness, NAS_Toughness, NAS_Medicine , NAS_Repair, NAS_SpotWeakness,
		NAS_Stealth, NAS_Science, NAS_MechaEngineering, NAS_CodeBreaking
	);

var
	Robotics_GB: GameBoardPtr;
	Robotics_Menu: RPGMenuPtr;
	Robotics_Source,Robotics_Parts: GearPtr;
	Robotic_Forms: GearPtr;
	Robotics_Instructions,Robotics_Info: String;

Function R_BuildPoints( LList: GearPtr ): LongInt;
	{ Build points are the fundamental currency of Robotics. }
var
	BP: LongInt;
begin
	BP := 0;
	while LList <> Nil do begin
		if LList^.G = GG_RepairFuel then begin
			BP := BP + LList^.V;
		end else if ( LList^.G = GG_Computer ) or ( LList^.G = GG_PowerSource ) then begin
			BP := BP + LList^.V * 25;
		end else begin
			BP := BP + GearMaxDamage( LList ) + GearMaxArmor( LList ) + GearMass( LList );
		end;
		BP := BP + R_BuildPoints( LList^.SubCom );
		LList := LList^.Next;
	end;
	R_BuildPoints := BP;
end;

Function R_ArmorPoints( LList: GearPtr ): LongInt;
	{ Armor points determine the armor rating of the finished robot. }
var
	BP: LongInt;
begin
	BP := 0;
	while LList <> Nil do begin
		BP := BP + ( GearMaxDamage( LList ) div 10 ) + GearMaxArmor( LList );
		BP := BP + R_ArmorPoints( LList^.SubCom );
		LList := LList^.Next;
	end;
	R_ArmorPoints := BP;
end;

Function R_ComputerPoints( LList: GearPtr ): LongInt;
	{ Computer points give a bonus to certain stats, and are needed for certain builds. }
var
	BP: LongInt;
begin
	BP := 0;
	while LList <> Nil do begin
		if LList^.G = GG_Computer then BP := BP + LList^.V;
		BP := BP + R_ComputerPoints( LList^.SubCom );
		LList := LList^.Next;
	end;
	R_ComputerPoints := BP;
end;

Function R_PowerPoints( LList: GearPtr ): LongInt;
	{ Power points give a bonus to certain stats, and are needed for certain builds. }
var
	BP: LongInt;
begin
	BP := 0;
	while LList <> Nil do begin
		if LList^.G = GG_PowerSource then BP := BP + LList^.V;
		BP := BP + R_PowerPoints( LList^.SubCom );
		LList := LList^.Next;
	end;
	R_PowerPoints := BP;
end;

Procedure RobotPartRedraw;
	{ Redraw procedure for the robot part selector. }
var
	N: Integer;
	Part: GearPtr;
begin
	if Robotics_GB <> Nil then CombatDisplay( Robotics_GB );

	{ We're going to be using the same border as the inventory panel. }
	DrawBPBorder;

	{ Show details of the item currently being examined. }
	if ( Robotics_Menu <> Nil ) and ( Robotics_Source <> Nil ) then begin
		N := CurrentMenuItemValue( Robotics_Menu );
		if N > 0 then begin
			Part := RetrieveGearSib( Robotics_Source , N );
			if Part <> Nil then begin
				BrowserInterfaceInfo( Robotics_GB , Part , ZONE_ItemsInfo );
			end;
		end;
	end;

	{ Display the info and instructions strings. }
	GameMsg( Robotics_Instructions , ZONE_BackpackInstructions , InfoHilight );
	GameMsg( Robotics_Info , ZONE_EqpMenu , InfoHilight );
end;

Function IngredientsDesc( Ingredients: GearPtr ): String;
	{ Return a string describing the build points gained from this list of }
	{ ingredients. }
begin
	IngredientsDesc := MsgString( 'ROBOTICS_BP' ) + BStr( R_BuildPoints( Ingredients ) ) + #13 + ' ' +
		MsgString( 'ROBOTICS_AP' ) + BStr( R_ArmorPoints( Ingredients ) ) + #13 + ' ' +
		MsgString( 'ROBOTICS_CP' ) + BStr( R_ComputerPoints( Ingredients ) ) + #13 + ' ' +
		MsgString( 'ROBOTICS_PP' ) + BStr( R_PowerPoints( Ingredients ) );
end;

Function IsGoodRobotPart( Part: GearPtr ): Boolean;
	{ Return TRUE if this part can be installed in a robot, or FALSE otherwise. }
begin
	if ( Part^.G = GG_Weapon ) or ( Part^.G = GG_Shield ) or ( Part^.G = GG_ExArmor ) or ( Part^.G = GG_Computer ) or ( Part^.G = GG_Powersource ) or ( Part^.G = GG_Tool ) then begin
		IsGoodRobotPart := True;
	end else if ( Part^.G = GG_RepairFuel ) then begin
		IsGoodRobotPart := ( ( Part^.S = 15 ) or ( Part^.S = 23 ) );
	end else if Part^.G = GG_Harness then begin
		IsGoodRobotPart := ( R_ComputerPoints( Part^.SubCom ) > 0 ) or ( R_PowerPoints( Part^.SubCom ) > 0 );
	end else begin
		IsGoodRobotPart := False;
	end;
end;

Function SelectRobotParts( GB: GameBoardPtr; PC: GearPtr ): GearPtr;
	{ Select up to 10 parts to build a robot with. }
	{ Delink them from the INVENTORY and return them as a list. }
var
	Part,P2: GearPtr;
	N: Integer;
begin
	Robotics_GB := GB;

	Robotics_Parts := Nil;
	Robotics_Instructions := MsgString( 'Robotics_SelectParts_Directions' );
	repeat
		Robotics_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );

		Robotics_Info := IngredientsDesc( Robotics_Parts );
		Robotics_Source := PC^.InvCom;

		Part := PC^.InvCom;
		N := 1;
		while Part <> Nil do begin
			if IsGoodRobotPart( Part ) then begin
				AddRPGMenuItem( Robotics_Menu , GearName( Part ) , N );
			end;
			Part := Part^.Next;
			Inc( N );
		end;
		RPMSortAlpha( Robotics_Menu );
		AlphaKeyMenu( Robotics_Menu );
		AddRPGMenuItem( Robotics_Menu , MsgString( 'EXIT' ) , -1 );

		N := SelectMenu( Robotics_Menu , @RobotPartRedraw );
		DisposeRPGMenu( Robotics_Menu );

		if N > -1 then begin
			Part := RetrieveGearSib( PC^.InvCom , N );
			DelinkGear( PC^.InvCom , Part );
			while Part^.InvCom <> Nil do begin
				P2 := Part^.InvCom;
				DelinkGear( Part^.InvCom , P2 );
				InsertInvCom( PC , P2 );
			end;
			AppendGear( Robotics_Parts , Part );
		end;

	until ( NumSiblingGears( Robotics_Parts ) > 9 ) or ( N = -1 );

	SelectRobotParts := Robotics_Parts;
end;

Function BuildPointsNeeded( Rob: GearPtr ): LongInt;
	{ Return the number of build points needed to make this robot. }
var
	s: Integer;	{ Stat counter }
	BP: LongInt;
begin
	BP := 0;
	for s := 1 to 8 do begin
		BP := BP + Rob^.Stat[ S ] * 10;
	end;
	BuildPointsNeeded := BP;
end;

Function RobotStatSpecialPointsNeeded( StatVal: Integer ): Integer;
	{ High baseline stats may require special materials. The usual amount }
	{ is one special point of materials per 2 points of stat over 4. }
begin
	if StatVal > 5 then begin
		RobotStatSpecialPointsNeeded := ( StatVal - 4 ) div 2;
	end else begin
		RobotStatSpecialPointsNeeded := 0;
	end;
end;

Function ArmorPointsNeeded( Rob: GearPtr ): LongInt;
	{ Return the number of build points needed to make this robot. }
begin
	ArmorPointsNeeded := RobotStatSpecialPointsNeeded( Rob^.STAT[ STAT_Body ] );
end;

Function ComputerPointsNeeded( Rob: GearPtr ): LongInt;
	{ Return the number of build points needed to make this robot. }
begin
	ComputerPointsNeeded := RobotStatSpecialPointsNeeded( Rob^.STAT[ STAT_Perception ] ) + RobotStatSpecialPointsNeeded( Rob^.STAT[ STAT_Craft ] ) + RobotStatSpecialPointsNeeded( Rob^.STAT[ STAT_Knowledge ] ) + Rob^.STAT[ STAT_Charm ] - 1;
end;

Function PowerPointsNeeded( Rob: GearPtr ): LongInt;
	{ Return the number of build points needed to make this robot. }
begin
	PowerPointsNeeded := RobotStatSpecialPointsNeeded( Rob^.STAT[ STAT_Reflexes ] ) + RobotStatSpecialPointsNeeded( Rob^.STAT[ STAT_Speed ] ) + RobotStatSpecialPointsNeeded( Rob^.STAT[ STAT_Ego ] );
end;

Function R_SkillLevelNeeded( Rob: GearPtr ): Integer;
	{ Determine the minimum Robotics skill needed to attempt this robot. }
var
	T,SkLvl: Integer;
begin
	{ The basic skill level needed is the highest stat. }
	SkLvl := 1;
	for t := 1 to 8 do begin
		if Rob^.Stat[ t ] > SkLvl then SkLvl := Rob^.Stat[ t ];
	end;

	{ If this is a sentient robot, minimum skill level is 11. }
	if ( Rob^.Stat[ STAT_Charm ] > 1 ) then begin
		if SkLvl < 8 then SkLvl := 11
		else SkLvl := SkLvl + 3;
	end;
	R_SkillLevelNeeded := SkLvl;
end;

Function SelectRobotForm( GB: GameBoardPtr; PC,Ingredients: GearPtr ): GearPtr;
	{ Given the provided list of ingredients and the PC's skill level, select }
	{ one of the legal robot forms to try and build. }
var
	BP,AP,CP,PP: LongInt;	{ Build, Armor, Computer, and Power points. }
	SkRank,N: Integer;	{ The PC's skill rank, and a counter. }
	Rob: GearPtr;		{ Robot Body Form }
begin
	Robotics_Source := Robotic_Forms;
	Robotics_Parts := Ingredients;

	{ Start by calculating the number of points we're dealing with. }
	BP := R_BuildPoints( Ingredients );
	AP := R_ArmorPoints( Ingredients );
	CP := R_ComputerPoints( Ingredients );
	PP := R_PowerPoints( Ingredients );

	SkRank := SkillRank( PC , NAS_Science );

	{ Create the menu. Determine which forms the PC can choose from. }
	Robotics_Menu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_InvMenu );
	Robotics_Instructions := MsgString( 'Robotics_SelectForm_Directions' );

	N := 1;
	Rob := Robotic_Forms;

	while Rob <> Nil do begin
		if ( BuildPointsNeeded( Rob ) <= BP ) and ( ArmorPointsNeeded( Rob ) <= AP ) and ( ComputerPointsNeeded( Rob ) <= CP ) and ( PowerPointsNeeded( Rob ) <= PP ) and ( R_SkillLevelNeeded( Rob ) <= SkRank ) then begin
			{ This robot can be built. We have the technology. }
			AddRPGMenuItem( Robotics_Menu , GearName( Rob ) , N );
		end;

		Rob := Rob^.Next;
		Inc( N );
	end;

	RPMSortAlpha( Robotics_Menu );
	AlphaKeyMenu( Robotics_Menu );
	AddRPGMenuItem( Robotics_Menu , MsgString( 'EXIT' ) , -1 );

	{ We now have a menu. Select a form. }
	Robotics_Source := Robotic_Forms;
	Robotics_Info := IngredientsDesc( Ingredients );
	N := SelectMenu( Robotics_Menu , @RobotPartRedraw );
	DisposeRPGMenu( Robotics_Menu );

	{ At this exact point, the variable ROB must be Nil because of the while }
	{ loop above. Because we're returning a clone of ROB, if menu selection }
	{ was cancelled we don't have any more work to do. }
	if N > -1 then begin
		Rob := CloneGear( RetrieveGearSib( Robotic_Forms , N ) );
	end;

	SelectRobotForm := Rob;
end;

Function RandomRobotName: String;
	{ Generate random St*r-W*rs sounding robot name. }
const
	NumLetter = 30;
	Letters: Array [1..NumLetter] of char = (
	'A','B','C','D','E', 'F','G','H','I','J',
	'K','L','M','N','O', 'P','Q','R','S','T',
	'U','V','W','X','Y', 'Z','C','P','D','R'
	);
	Function AlphaNum: String;
		{ Generate a random sequence of letters and numbers. }
	var
		msg: String;
	begin
		msg := Letters[ Random( NumLetter ) + 1 ];
		if Random( 2 ) = 1 then msg := msg + Letters[ Random( NumLetter ) + 1 ];
		if Random( 2 ) = 1 then msg := msg + BStr( Random( 10 ) )
		else msg := BStr( Random( 10 ) ) + msg;
		if Random( 10 ) = 1 then msg := msg + BStr( Random( 10 ) )
		else if Random( 9 ) = 1 then msg := BStr( Random( 10 ) ) + msg
		else if Random( 8 ) = 1 then msg := msg + Letters[ Random( NumLetter ) + 1 ]
		else if Random( 8 ) = 1 then msg := Letters[ Random( NumLetter ) + 1 ] + msg;
		AlphaNum := msg;
	end;
	Function JustNum: String;
		{ Return a random sequence of numbers. }
	begin
		JustNum := BStr( Random( 499 ) + Random( 489 ) + 10 );
	end;
var
	name: String;
begin
	name := AlphaNum;
	repeat
		if Random( 2 ) = 1 then begin
			name := name + '-' + AlphaNum;
		end else begin
			name := name + '-' + JustNum;
		end;
	until ( Length( name ) > 10 ) or ( Random( 2 ) = 1 );
	RandomRobotName := name;
end;


Function UseRobotics( GB: GameBoardPtr; PC,Ingredients,Form: GearPtr ): GearPtr;
	{ Given the above list of ingredients, the PC will try to construct a robot. }
	{ This function returns the robot, or NIL if construction failed. }
	{ The calling procedure should place the robot on the map or dispose of it. }
	{ FORM is the form being attempted. It should be a free-floating gear at this point. }
var
	BP,AP,CP,PP: LongInt;	{ Build, Armor, Computer, and Power points. }
	SkRoll,SkRank,T,RobotSize,ArmorVal: Integer;
	Part: GearPtr;
begin
	{ Add the stamina decrease here. }
	AddMentalDown( PC , 10 );

	{ Pay the point cost for the robot. }
	BP := R_BuildPoints( Ingredients ) - BuildPointsNeeded( Form );
	AP := R_ArmorPoints( Ingredients ) - ArmorPointsNeeded( Form );
	CP := R_ComputerPoints( Ingredients ) - ComputerPointsNeeded( Form );
	PP := R_PowerPoints( Ingredients ) - PowerPointsNeeded( Form );

	{ Start with allocating the robot's base gear. }
	SetNAtt( Form^.NA , NAG_GearOps , NAS_Material , NAV_Metal );
	SetSAtt( Form^.SA , 'TYPE <ROBOT>' );
	SetSAtt( Form^.SA , 'JOB <ANIMAL>' );
	SetSAtt( Form^.SA , 'NAME <' + RandomRobotName + '>' );
	SetNAtt( Form^.NA , NAG_CharDescription , NAS_DAge , -19 );
	SetSAtt( Form^.SA , 'ROGUECHAR <R>' );
	SetSAtt( Form^.SA , 'SDL_COLORS <80 80 85 170 155 230 6 42 120>' );

	{ Make a skill roll for the robot stats. You only get one skill roll; }
	{ the target number is the stat in question. If your skill roll for any }
	{ of the stats fail, you can make up for it by spending build points. }
	SkRoll := SkillRoll( GB , PC , NAS_Science , STAT_Knowledge , R_SkillLevelNeeded( Form ) + 5 , ToolBonus( PC , -NAS_Robotics ) , True , True );
	SkRank := SkillRank( PC , NAS_Science );

	{ Check the skill roll against each of the form's stats. }
	{ If we finish with non-negative build points, all is well. }
	for t := 1 to 8 do begin
		if SkRoll <= Form^.Stat[ T ] then begin
			BP := BP - ( Form^.Stat[ T ] - SkRoll ) * 15;
		end else if ( SkRoll > 10 ) and ( ( T <> STAT_Charm ) or ( Form^.Stat[ T ] > 1 ) ) then begin
			Form^.Stat[ T ] := Form^.Stat[ T ] + Random( ( SkRoll - 7 ) div 2 );
		end;
	end;

	{ If the robot has been created successfully, move on and perform the rest of the }
	{ initialization. }
	if BP > 0 then begin
		{ Apply any special effects associated with the ingredients. }


		{ Spend any remaining BP, AP, CP, and PP on perks. }
		{ Record ArmorVal before spending AP. }
		ArmorVal := AP div 5 + 1;
		while AP > 0 do begin
			if Random( 3 ) = 1 then begin
				AddNAtt( Form^.NA , NAG_Skill , NAS_Vitality , 1 );
				AP := AP - ( NAttValue( Form^.NA , NAG_Skill , NAS_Vitality ) + 2 );
			end else begin
				Inc( Form^.Stat[ STAT_Body ] );
				AP := AP - 5;
			end;
		end;

		while CP > 0 do begin
			if Random( 10 ) = 1 then begin
				{ Add a new skill. }
				AddNAtt( Form^.NA , NAG_Skill , Robot_Skill[ Random( Num_RObot_Skill ) + 1 ] , 1 );
				CP := CP - 2;
			end else if Random( 3 ) = 1 then begin
				Inc( Form^.Stat[ STAT_Perception ] );
				CP := CP - 3;
			end else if Random( 2 ) = 1 then begin
				Inc( Form^.Stat[ STAT_Craft ] );
				CP := CP - 3;
			end else begin
				Inc( Form^.Stat[ STAT_Knowledge ] );
				CP := CP - 3;
			end;
		end;

		while PP > 0 do begin
			if Random( 3 ) = 1 then begin
				Inc( Form^.Stat[ STAT_Reflexes ] );
				PP := PP - 5;
			end else if Random( 2 ) = 1 then begin
				Inc( Form^.Stat[ STAT_Speed ] );
				PP := PP - 4;
			end else begin
				Inc( Form^.Stat[ STAT_Ego ] );
				PP := PP - 4;
			end;
		end;

		{ Initialize the limbs- set size and armor value. }
		Part := Form^.SubCom;
		RobotSize := MasterSize( Form );
		if ArmorVal > ( RobotSize + 1 ) then ArmorVal := ( RobotSize + 1 );
		while Part <> Nil do begin
			if Part^.G = GG_Module then begin
				Part^.V := RobotSize;
				Part^.Stat[ STAT_Armor ] := ArmorVal;
			end;
			Part := Part^.Next;
		end;

		{ Set the basic skills for the robot. }
		for t := 4 to 6 do SetNAtt( Form^.NA , NAG_Skill , T , Random( SkRank ) + 1 );

		{ If this robot is self-aware, set a job and assign a CID. }
		if Form^.Stat[ STAT_Charm ] > 1 then begin
			SetNAtt( Form^.NA , NAG_Personal , NAS_CID , NewCID( FindRoot( GB^.Scene ) ) );
			AddNAtt( PC^.NA , NAG_ReactionScore , NAttValue( Form^.NA , NAG_Personal , NAS_CID ) , 20 );
			SetSAtt( Form^.SA , 'JOB <ROBOT>' );
			{ Robots typically acquire the personality traits of their creator. }
			for t := 1 to Num_Personality_Traits do begin
				if Random( 3 ) <> 1 then begin
					SetNAtt( Form^.NA , NAG_CharDescription , -T , NAttValue( PC^.NA , NAG_CharDescription , -T ) );
				end else if Random( 5 ) > SkRoll then begin
					SetNAtt( Form^.NA , NAG_CharDescription , -T , -NAttValue( PC^.NA , NAG_CharDescription , -T ) );
				end;
			end;
			{ Intelligent robots start with mecha combat skills. }
			for t := 1 to 3 do SetNAtt( Form^.NA , NAG_Skill , T , Random( SkRank ) + 1 );
		end;

	end else begin
		{ Robot construction has failed. }
		DisposeGear( Form );

		{ As a cold consolation to the PC, give back repair fuel equal to about 80% }
		{ of the build points put into the robot. }
		BP := ( R_BuildPoints( Ingredients ) * 4 ) div 5;
		if BP > 30000 then BP := 30000
		else if BP < 1 then BP := 1;
		Part := LoadNewSTC( 'SPAREPARTS-1' );
		if Part <> Nil then begin
			if IsLegalInvCom( PC , Part ) then begin
				Part^.V := BP;
				InsertInvCom( PC , Part );
			end else begin
				DisposeGear( Part );
			end;
		end;
	end;

	{ Advance time by the required amount. }
	WaitAMinute( GB , PC , ReactionTime( PC ) * 10 );

	{ Get rid of the ingredients list. }
	DisposeGear( Ingredients );
	UseRobotics := Form;
end;

Procedure BuildRobot( GB: GameBoardPtr; PC: GearPtr );
	{ Start performing on a musical instrument. First this procedure }
	{ will seek the best instrument currently held, then it will set }
	{ up the continuous action. }
var
	Ingredients,Form,Robot: GearPtr;
	T: Integer;
begin
	if CurrentMental( PC ) < 1 then begin
		DialogMsg( MsgString( 'BUILD_ROBOT_TOO_TIRED' ) );
		Exit;
	end else if not IsSafeArea( GB ) then begin
		DialogMsg( MsgString( 'BUILD_ROBOT_NOT_SAFE' ) );
		Exit;
	end;

	PC := LocatePilot( PC );
	DialogMsg( MsgString( 'BUILD_ROBOT_START' ) );
	Ingredients := SelectRobotParts( GB , PC );

	{ If no ingredients were selected, no robot will be built. }
	if Ingredients = Nil then begin
		DialogMsg( MsgString( 'BUILD_ROBOT_NO_PARTS' ) );
		Exit;
	end;

	Form := SelectRobotForm( GB , PC , Ingredients );
	{ If no form was selected, no robot will be built and the ingredients }
	{ will be returned to the PC. }
	if Form = Nil then begin
		InsertInvCom( PC , Ingredients );
		Exit;
	end;

	Robot := UseRobotics( GB , PC , Ingredients , Form );
	if Robot = Nil then begin
		DialogMsg( MsgString( 'BUILD_ROBOT_FAILED' ) );
	end else begin
		SetNAtt( Robot^.NA , NAG_Location , NAS_Team , NAV_LancemateTeam );
		SetNAtt( Robot^.NA , NAG_Relationship , 0 , NAV_ArchAlly );
		SetNAtt( Robot^.NA , NAG_CharDescription , NAS_CharType , NAV_CTLancemate );
		DeployGear( GB , Robot , True );

		if NAttValue( Robot^.NA , NAG_Personal , NAS_CID ) <> 0 then begin
			if NumLancemateSlots( GB^.Scene , PC ) < LancematesPresent( GB ) then RemoveLancemate( GB , Robot , False );
			DialogMsg( ReplaceHash( MsgString( 'BUILD_ROBOT_SENTIENT' ) , GearName( Robot ) ) );
		end else begin
			if PetsPresent( GB ) > PartyPetSlots( PC ) then RemoveLancemate( GB , Robot , False );
			DialogMsg( ReplaceHash( MsgString( 'BUILD_ROBOT_SUCCESS' ) , GearName( Robot ) ) );
		end;

		{ Give the PC a rundown on the new robot's skills. }
		for t := 1 to Num_Robot_Skill do begin
			if NAttValue( Robot^.NA , NAG_Skill , Robot_Skill[ T ] ) > 0 then begin
				DialogMsg( ReplaceHash( ReplaceHash( MsgString( 'BUILD_ROBOT_SKILL' ) , GearName( Robot ) ) , MsgString( 'SKILLNAME_' + BStr( Robot_Skill[ t ] ) ) ) );
			end;
		end;
	end;
end;

initialization
	{ Load the robotic forms from disk. }
	Robotic_Forms := AggregatePattern( 'ROBOTS_*.txt' , Series_Directory );

finalization
	{ Dispose of the robotic forms. }
	DisposeGear( Robotic_Forms );

end.
