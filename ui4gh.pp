unit ui4gh;
	{ User Interface for GearHead. }
	{ This unit exists to keep me from copying changes back and forth between }
	{ the SDL mode units and the CRT mode units... }
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

uses gears,texutil,dos;

type
	KeyMapDesc = Record
		CmdName,CmdDesc: String;
		isacommand: Boolean;		{ Return TRUE if this key is a command. }
		KCode: Char;
	end;

const
{$IFDEF ASCII}
	RPK_UpRight = '9';
	RPK_Up = '8';
	RPK_UpLeft = '7';
	RPK_Left = '4';
	RPK_Right = '6';
	RPK_DownRight = '3';
	RPK_Down = '2';
	RPK_DownLeft = '1';

	FrameDelay: Integer = 30;
{$ELSE}
	RPK_UpRight = #$89;
	RPK_Up = #$88;
	RPK_UpLeft = #$87;
	RPK_Left = #$84;
	RPK_Right = #$86;
	RPK_DownRight = #$81;
	RPK_Down = #$82;
	RPK_DownLeft = #$83;
	RPK_MouseButton = #$90;
	RPK_TimeEvent = #$91;
	RPK_RightButton = #$92;

	FrameDelay: Integer = 0;
{$ENDIF}

	MenuBasedInput = 0;
	RLBasedInput = 1;
	ControlMethod: Byte = RLBasedInput;
	CharacterMethod: Byte = RLBasedInput;
	WorldMapMethod: Byte = RLBasedInput;
	ControlTypeName: Array [0..1] of string = ('Menu','Roguelike');

	DoFullScreen: Boolean = True;
	Mouse_Active: Boolean = True;

	Always_Save_Character: Boolean = False;
	No_Combat_Taunts: Boolean = False;
	Pillage_On: Boolean = True;

	RPG_Use_Tactics: Boolean = False;
	Arena_Use_Tactics: Boolean = True;

	TacticsRoundLength: Integer = 60;
	Tactics_Turn_In_Progess: Boolean = False;

	XXRan_Wizard: Boolean = False;
	ArenaMode_Wizard: Boolean = False;

	PC_SHOULD_RUN: Boolean = False;

	Names_Above_Heads: Boolean = False;

	Cycle_All_Weapons: Boolean = False;

	Splash_Screen_At_Start: Boolean = True;

	BV_Off = 1;
	BV_Quarter = 2;
	BV_Half = 3;
	BV_Max = 4;
	DefMissileBV: Byte = BV_Quarter;
	DefBallisticBV: Byte = BV_Max;
	DefBeamgunBV: Byte = BV_Max;
	BVTypeName: Array [1..4] of string = ('Off','1/4','1/2','Max');

	DoAutoSave: Boolean = True;

	Load_Plots_At_Start: Boolean = False;

	Reload_All_Weapons: Boolean = False;

	Display_Mini_Map: Boolean = FaLSE;

	{ *** SCREEN DIMENSIONS *** }
{$IFDEF WIN32}
	ScreenRows: Byte = 25;
{$ELSE}
	ScreenRows: Byte = 24;
{$ENDIF}
	ScreenColumns: Byte = 80;

	Revert_Slower_Safer: Boolean = False;

	XXRan_Debug: Boolean = False;
	StdPlot_Debug: Boolean = False;


	NumMappedKeys = 51;
	KeyMap: Array [1..NumMappedKeys] of KeyMapDesc = (
	(	CmdName: 'NormSpeed';
		CmdDesc: 'Travel foreword at normal speed.';
		IsACommand: True;
		KCode: '=';	),
	(	CmdName: 'FullSpeed';
		CmdDesc: 'Travel foreword at maximum speed';
		IsACommand: True;
		KCode: '+';	),
	(	CmdName: 'TurnLeft';
		CmdDesc: 'Turn to the left.';
		IsACommand: True;
		KCode: '[';	),
	(	CmdName: 'TurnRight';
		CmdDesc: 'Turn to the right.';
		IsACommand: True;
		KCode: ']';	),
	(	CmdName: 'Stop';
		CmdDesc: 'Stop moving, wait in place.';
		IsACommand: True;
		KCode: '5';	),

	(	CmdName: 'Dir-SouthWest';
		CmdDesc: 'Move southwest.';
		IsACommand: True;
		KCode: RPK_DownLeft;	),
	(	CmdName: 'Dir-South';
		CmdDesc: 'Move south.';
		IsACommand: True;
		KCode: RPK_Down;	),
	(	CmdName: 'Dir-SouthEast';
		CmdDesc: 'Move southeast.';
		IsACommand: True;
		KCode: RPK_DownRight;	),
	(	CmdName: 'Dir-West';
		CmdDesc: 'Move west.';
		IsACommand: True;
		KCode: RPK_Left;	),
	(	CmdName: 'Dir-East';
		CmdDesc: 'Move east.';
		IsACommand: True;
		KCode: RPK_Right;	),

	(	CmdName: 'Dir-NorthWest';
		CmdDesc: 'Move northwest.';
		IsACommand: True;
		KCode: RPK_UpLeft;	),
	(	CmdName: 'Dir-North';
		CmdDesc: 'Move north.';
		IsACommand: True;
		KCode: RPK_Up;	),
	(	CmdName: 'Dir-NorthEast';
		CmdDesc: 'Move northeast.';
		IsACommand: True;
		KCode: RPK_UpRight;	),
	(	CmdName: 'ShiftGears';
		CmdDesc: 'Change movement mode.';
		IsACommand: True;
		KCode: '.';	),
	(	CmdName: 'Look';
		CmdDesc: 'Look around the map.';
		IsACommand: True;
		KCode: 'l';	),

	(	CmdName: 'AttackMenu';
		CmdDesc: 'Access the attack menu.';
		IsACommand: True;
		KCode: 'A';	),
	(	CmdName: 'QuitGame';
		CmdDesc: 'Exit the game.';
		IsACommand: True;
		KCode: 'Q';	),
	(	CmdName: 'Talk';
		CmdDesc: 'Initiate conversation with a NPC.';
		IsACommand: True;
		KCode: 't';	),
	(	CmdName: 'Help';
		CmdDesc: 'View these helpful messages.';
		IsACommand: True;
		KCode: 'h';	),
	(	CmdName: 'SwitchWeapon';
		CmdDesc: 'Change the active weapon while selecting a target.';
		IsACommand: True;
		KCode: '.';	),

	(	CmdName: 'CalledShot';
		CmdDesc: 'Toggle the Called Shot option while selecting a target.';
		IsACommand: False;
		KCode: '/';	),
	(	CmdName: 'Get';
		CmdDesc: 'Pick up an item lying on the ground.';
		IsACommand: True;
		KCode: ',';	),
	(	CmdName: 'Inventory';
		CmdDesc: 'Access all carried items.';
		IsACommand: True;
		KCode: 'i';	),
	(	CmdName: 'Equipment';
		CmdDesc: 'Access all equipped items.';
		IsACommand: True;
		KCode: 'e';	),
	(	CmdName: 'Enter';
		CmdDesc: 'Use a stairway or portal.';
		IsACommand: True;
		KCode: '>';	),

	{ Commands 26 - 30 }
	(	CmdName: 'PartBrowser';
		CmdDesc: 'Examine the individual components of your PC.';
		IsACommand: True;
		KCode: 'B';	),
	(	CmdName: 'LearnSkills';
		CmdDesc: 'Spend accumulated experience points.';
		IsACommand: True;
		KCode: 'L';	),
	(	CmdName: 'Attack';
		CmdDesc: 'Perform an attack.';
		IsACommand: True;
		KCode: 'a';	),
	(	CmdName: 'SelectMecha';
		CmdDesc: 'Choose the mecha that will be used by this PC in combat.';
		IsACommand: True;
		KCode: 'M';	),
	(	CmdName: 'UseScenery';
		CmdDesc: 'Activate a stationary item, such as a door or a computer.';
		IsACommand: True;
		KCode: 'u';	),

	{ Commands 31 - 35 }
	(	CmdName: 'Messages';
		CmdDesc: 'Review all current adventure memos, email, and news.';
		IsACommand: True;
		KCode: 'm';	),
	(	CmdName: 'SaveGame';
		CmdDesc: 'Write the game data to disk, so you can come back and waste time later.';
		IsACommand: True;
		KCode: 'X';	),
	(	CmdName: 'Enter2';
		CmdDesc: 'Use a stairway or portal.';
		IsACommand: True;
		KCode: '<';	),
	(	CmdName: 'CharInfo';
		CmdDesc: 'View detailed information about your character, access option menus.';
		IsACommand: True;
		KCode: 'C';	),
	(	CmdName: 'ApplySkill';
		CmdDesc: 'Select and use a skill that the PC knows.';
		IsACommand: True;
		KCode: 's';	),

	{ Commands 36 - 40 }
	(	CmdName: 'Eject';
		CmdDesc: 'Eject from your mecha and abandon it on the field.';
		IsACommand: True;
		KCode: 'E';	),
	(	CmdName: 'Rest';
		CmdDesc: 'Take a break for one hour of game time.';
		IsACommand: True;
		KCode: 'Z';	),
	(	CmdName: 'History';
		CmdDesc: 'Display past messages.';
		IsACommand: True;
		KCode: 'V';	),
	(	CmdName: 'FieldHQ';
		CmdDesc: 'Examine and edit your personal wargear.';
		IsACommand: True;
		KCode: 'H';	),
	(	CmdName: 'Search';
		CmdDesc: 'Check the area for enemies and secrets.';
		IsACommand: True;
		KCode: 'S';	),

	{ Commands 41 - 45 }
	(	CmdName: 'Telephone';
		CmdDesc: 'Place a telephone call to a local NPC.';
		IsACommand: True;
		KCode: 'T';	),
	(	CmdName: 'SwitchBV';
		CmdDesc: 'Switch the Burst Fire option while selecting a target.';
		IsACommand: False;
		KCode: '>';	),
	(	CmdName: 'Reverse';
		CmdDesc: 'Travel backward at normal speed.';
		IsACommand: True;
		KCode: '-';	),
	(	CmdName: 'SwitchTarget';
		CmdDesc: 'Switch to next visible enemy when selecting a target.';
		IsACommand: False;
		KCode: ';';	),
	(	CmdName: 'RunToggle';
		CmdDesc: 'Toggle running on or off.';
		IsACommand: True;
		KCode: 'r';	),

	{ Commands 46 - 50 }
	(	CmdName: 'WallToggle';
		CmdDesc: 'Toggle short walls in graphical mode.';
		IsACommand: True;
		KCode: 'W';	),
	(	CmdName: 'QuickFire';
		CmdDesc: 'Single-key automatic targeting attack.';
		IsACommand: True;
		KCode: 'f'; ),
	(	CmdName: 'RollHistory';
		CmdDesc: 'View the skill roll history.';
		IsACommand: True;
		KCode: 'R'; ),
	(	CmdName: 'ExamineTarget';
		CmdDesc: 'Examine a target closely.';
		IsACommand: False;
		KCode: '?'; ),
	(	CmdName: 'PartyMode';
		CmdDesc: 'Toggle between clock mode and tactics mode.';
		IsACommand: True;
		KCode: 'P'; ),

	{ Commands 51 - 55 }
	(	CmdName: 'UseSystem';
		CmdDesc: 'Use one of the special systems in a mecha.';
		IsACommand: True;
		KCode: 'U'; )

	);

	{ *** KEYMAP COMMAND NUMBERS *** }
	KMC_NormSpeed = 1;
	KMC_FullSpeed = 2;
	KMC_TurnLeft = 3;
	KMC_TurnRight = 4;
	KMC_Stop = 5;
	KMC_SouthWest = 6;
	KMC_South = 7;
	KMC_SouthEast = 8;
	KMC_West = 9;
	KMC_East = 10;
	KMC_NorthWest = 11;
	KMC_North = 12;
	KMC_NorthEast = 13;
	KMC_ShiftGears = 14;
	KMC_ExamineMap = 15;
	KMC_AttackMenu = 16;
	KMC_QuitGame = 17;
	KMC_Talk = 18;
	KMC_Help = 19;
	KMC_SwitchWeapon = 20;
	KMC_CalledShot = 21;
	KMC_Get = 22;
	KMC_Inventory = 23;
	KMC_Equipment = 24;
	KMC_Enter = 25;
	KMC_PartBrowser = 26;
	KMC_LearnSkills = 27;
	KMC_Attack = 28;
	KMC_SelectMecha = 29;
	KMC_UseProp = 30;
	KMC_ViewMemo = 31;
	KMC_SaveGame = 32;
	KMC_Enter2 = 33;
	KMC_CharInfo = 34;
	KMC_ApplySkill = 35;
	KMC_Eject = 36;
	KMC_Rest = 37;
	KMC_History = 38;
	KMC_FieldHQ = 39;
	KMC_Search = 40;
	KMC_Telephone = 41;
	KMC_SwitchBV = 42;
	KMC_Reverse = 43;
	KMC_SwitchTarget = 44;
	KMC_RunToggle = 45;
	KMC_WallToggle = 46;
	KMC_QuickFire = 47;
	KMC_RollHistory = 48;
	KMC_ExamineTarget = 49;
	KMC_PartyMode = 50;
	KMC_UseSystem = 51;

	Direct_Skill_Learning: Boolean = False;

	Thorough_Redraw: Boolean = False;
	Use_Tall_Walls: Boolean = True;

	Iso_Dir_Offset: Integer = 0;
	Ersatz_Mouse: Boolean = False;

	Minimal_Screen_Refresh: Boolean = False;
	Use_Software_Surface: Boolean = False;
	Use_Paper_Dolls: Boolean = False;
	Mesh_On: Boolean = False;


	Full_RPGWorld_Info: Boolean = False;

var
	Text_Messages: SAttPtr;


Function MsgString( const MsgLabel: String ): String;


implementation

Procedure LoadConfig;
	{ Open the configuration file and set the variables }
	{ as needed. }
var
	F: Text;
	S,CMD,C: String;
	T: Integer;
begin
	{See whether or not there's a configuration file.}
	S := FSearch(Config_File,'.');
	if S <> '' then begin
		{ If we've found a configuration file, }
		{ open it up and start reading. }
		Assign(F,S);
		Reset(F);

		while not Eof(F) do begin
			ReadLn(F,S);
			cmd := ExtractWord(S);
			if (cmd <> '') then begin
				{Check to see if CMD is one of the standard keys.}
				cmd := UpCase(cmd);
				for t := 1 to NumMappedKeys do begin
					if UpCase(KeyMap[t].CmdName) = cmd then begin
						C := ExtractWord(S);
						if Length(C) = 1 then begin
							KeyMap[t].KCode := C[1];
						end;
					end;
				end;

				{ Check to see if CMD is the animation speed throttle. }
				if cmd = 'ANIMSPEED' then begin
					T := ExtractValue( S );
					if T < 0 then T := 0;
					FrameDelay := T;
				end else if cmd = 'MECHACONTROL' then begin
					C := UpCase( ExtractWord( S ) );
					case C[1] of
						'M': ControlMethod := MenuBasedInput;
						'R': ControlMethod := RLBasedInput;
					end;
				end else if cmd = 'CHARACONTROL' then begin
					C := UpCase( ExtractWord( S ) );
					case C[1] of
						'M': CharacterMethod := MenuBasedInput;
						'R': CharacterMethod := RLBasedInput;
					end;
				end else if cmd = 'WORLDCONTROL' then begin
					C := UpCase( ExtractWord( S ) );
					case C[1] of
						'M': WorldMapMethod := MenuBasedInput;
						'R': WorldMapMethod := RLBasedInput;
					end;

				end else if cmd = 'MISSILEBV' then begin
					C := UpCase( ExtractWord( S ) );
					for t := 1 to 4 do begin
						if UpCase(BVTypeName[t]) = C then begin
							DefMissileBV := T;
						end;
					end;

				end else if cmd = 'BALLISTICBV' then begin
					C := UpCase( ExtractWord( S ) );
					for t := 1 to 4 do begin
						if UpCase(BVTypeName[t]) = C then begin
							DefBallisticBV := T;
						end;
					end;

				end else if cmd = 'BEAMGUNBV' then begin
					C := UpCase( ExtractWord( S ) );
					for t := 1 to 4 do begin
						if UpCase(BVTypeName[t]) = C then begin
							DefBeamGunBV := T;
						end;
					end;
				end else if cmd = 'DIRECTSKILLOK' then begin
					Direct_Skill_Learning := True;

				end else if cmd = 'NOAUTOSAVE' then begin
					DoAutoSave := False;

				end else if cmd = 'ALWAYSSAVECHARACTER' then begin
					ALWAYS_SAVE_CHARACTER := True;
				end else if cmd = 'NOCOMBATTAUNTS' then begin
					No_Combat_Taunts := True;

				end else if cmd = 'LOADPLOTSATSTART' then begin
					Load_Plots_At_Start := True;

				end else if cmd = 'MINIMAPON' then begin
					Display_Mini_Map := True;

				end else if cmd = 'SCREENHEIGHT' then begin
					T := ExtractValue( S );
					if T > 255 then T := 255
					else if T < 24 then T := 24;
					ScreenRows := T;

				end else if cmd = 'SCREENWIDTH' then begin
					T := ExtractValue( S );
					if T > 255 then T := 255
					else if T < 80 then T := 80;
					ScreenColumns := T;

				end else if cmd = 'RPGMODE' then begin
					C := UpCase( ExtractWord( S ) );
					RPG_Use_Tactics := C = 'TACTICS';
				end else if cmd = 'ARENAMODE' then begin
					C := UpCase( ExtractWord( S ) );
					Arena_Use_Tactics := C = 'TACTICS';

				end else if cmd = 'WINDOW' then begin
					DoFullScreen := False;
				end else if cmd = 'FULLSCREEN' then begin
					DoFullScreen := True;

				end else if cmd = 'NOMOUSE' then begin
					Mouse_Active := False;


				end else if cmd = 'NOPILLAGE' then begin
					Pillage_On := False;

				end else if cmd = 'SHORTWALLS' then begin
					Use_Tall_Walls := False;

				end else if cmd = 'RELOAD_UNEQUIPPED_WEAPONS_AT_SHOP' then begin
					Reload_All_Weapons := True;

				end else if cmd = 'LAPTOP_ISO_KEYS' then begin
					 Iso_Dir_Offset := 1;

				end else if cmd = 'CYCLE_ALL_WEAPONS' then begin
					Cycle_All_Weapons := True;

				end else if cmd = 'MINIMAL_SCREEN_REFRESH' then begin
					Minimal_Screen_Refresh := True;
				end else if cmd = 'USE_SOFTWARE_SURFACE' then begin
					Use_Software_Surface := True;
				end else if cmd = 'NO_SPLASH_SCREEN_AT_START' then begin
					Splash_Screen_At_Start := False;

				end else if cmd = 'REVERT_SLOWER_SAFER' then begin
					Revert_Slower_Safer := True;

				end else if cmd = 'NAMESON' then begin
					Names_Above_Heads := True;

				end else if cmd = 'PAPERDOLLS' then begin
					Use_Paper_Dolls := True;
				end else if cmd = 'USEMESH' then begin
					Mesh_On := True;
				end else if cmd = 'ERSATZ_MOUSE' then begin
					Ersatz_Mouse := True;

				end else if cmd = 'GIMMEGIMMECHOICE' then begin
					XXRan_Wizard := True;
				end else if cmd = 'XXRANDEBUG' then begin
					XXRan_Debug := True;
				end else if cmd = 'YOUARE#6' then begin
					StdPlot_Debug := True;
				end else if cmd = 'GARYGYGAX' then begin
					ArenaMode_Wizard := True;
				end else if cmd = 'DEMIURGE' then begin
					Full_RPGWorld_Info := True;

				end else if cmd[1] = '#' then begin
					S := '';

				end;
			end;
		end;

		{ Once the EOF has been reached, close the file. }
		Close(F);
	end;

end;

Procedure SaveConfig;
	{ Open the configuration file and record the variables }
	{ as needed. }
var
	F: Text;
	T: Integer;
	Procedure AddBoolean( const OpTag: String; IsOn: Boolean );
		{ Add one of the boolean options to the file. }
	begin
		if IsOn then begin
			writeln( F , OpTag );
		end else begin
			writeln( F , '#' + OpTag );
		end;
	end;
begin
	{ If we've found a configuration file, }
	{ open it up and start reading. }
	Assign( F , Config_File );
	Rewrite( F );

	writeln( F , '#' );
	writeln( F , '# ATTENTION:' );
	writeln( F , '#   Only edit the config file if GearHead is not running.' );
	writeln( F , '#   Configuration overwritten at game exit.' );
	writeln( F , '#' );

	for t := 1 to NumMappedKeys do begin
		WriteLn( F, KeyMap[t].CmdName + ' ' + KeyMap[t].KCode );
	end;

	writeln( F, 'ANIMSPEED ' + BStr( FrameDelay ) );

	writeln( F, 'MECHACONTROL ' + ControlTypeName[ ControlMethod ] );
	writeln( F, 'CHARACONTROL ' + ControlTypeName[ CharacterMethod ] );
	writeln( F, 'WORLDCONTROL ' + ControlTypeName[ WorldMapMethod ] );

	writeln( F, 'MISSILEBV ' + BVTypeName[ DefMissileBV ] );
	writeln( F, 'BALLISTICBV ' + BVTypeName[ DefBallisticBV ] );
	writeln( F, 'BEAMGUNBV ' + BVTypeName[ DefBeamGunBV ] );

	if RPG_Use_Tactics then writeln( F , 'RPGMode Tactics' )
	else writeln( F , 'RPGMode Clock' );

	if Arena_Use_Tactics then writeln( F , 'ArenaMode Tactics' )
	else writeln( F , 'ArenaMode Clock' );

	AddBoolean( 'DIRECTSKILLOK' , Direct_Skill_Learning );
	AddBoolean( 'NOAUTOSAVE' , not DoAutoSave );
	AddBoolean( 'ALWAYSSAVECHARACTER' , Always_Save_Character );
	AddBoolean( 'NOCOMBATTAUNTS' , No_Combat_Taunts );

	AddBoolean( 'RELOAD_UNEQUIPPED_WEAPONS_AT_SHOP' , Reload_All_Weapons );

	AddBoolean( 'LOADPLOTSATSTART' , Load_Plots_At_Start );
	AddBoolean( 'MINIMAPON' , Display_Mini_Map );

	writeln( F , 'SCREENHEIGHT ' + BStr( ScreenRows ) );
	writeln( F , 'SCREENWIDTH ' + BStr( ScreenColumns ) );

	AddBoolean( 'WINDOW' , not DoFullScreen );
	AddBoolean( 'NOMOUSE' , not Mouse_Active );
	AddBoolean( 'NOPILLAGE' , not Pillage_On );
	AddBoolean( 'SHORTWALLS' , not Use_Tall_Walls );

	AddBoolean( 'LAPTOP_ISO_KEYS' ,  Iso_Dir_Offset <> 0 );
	AddBoolean( 'CYCLE_ALL_WEAPONS' , Cycle_All_Weapons );
	AddBoolean( 'MINIMAL_SCREEN_REFRESH' , Minimal_Screen_Refresh );
	AddBoolean( 'USE_SOFTWARE_SURFACE' , Use_Software_Surface );
	AddBoolean( 'NO_SPLASH_SCREEN_AT_START' , not Splash_Screen_At_Start );
	AddBoolean( 'REVERT_SLOWER_SAFER' , Revert_Slower_Safer );
	AddBoolean( 'NAMESON' , Names_Above_Heads );
	AddBoolean( 'PAPERDOLLS' , Use_Paper_Dolls );
	AddBoolean( 'USEMESH' , Mesh_On );
	AddBoolean( 'ERSATZ_MOUSE' , Ersatz_Mouse );

	{ The "secret options" come at the end. These tokens only get }
	{ included if they're already set. }
	if XXRAN_Wizard then writeln( F , 'GIMMEGIMMECHOICE' );
	if ArenaMode_Wizard then writeln( F , 'GARYGYGAX' );
	if XXRAN_Debug then writeln( F , 'XXRANDEBUG' );
	if StdPlot_Debug then writeln( F , 'YOUARE#6' );
	if Full_RPGWorld_Info then writeln( F , 'DEMIURGE' );

	Close(F);
end;


Function MsgString( const MsgLabel: String ): String;
	{ Return the standard message string which has the requested }
	{ label. }
begin
	MsgString := SAttValue( Text_Messages , MsgLabel );
end;

initialization
	Text_Messages := LoadStringList( Standard_Message_File );
	LoadConfig;

finalization
	SaveConfig;
	DisposeSAtt( Text_Messages );

end.
