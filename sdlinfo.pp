unit sdlinfo;
	{ This unit holds the information display stuff. }
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

uses sdl,locale,gears,minitype,sdlgfx;

Function InfoImageName( Part: GearPtr ): String;

Procedure DisplayModelStatus( GB: GameBoardPtr; M: GearPtr;  MyDest: TSDL_Rect );
Procedure QuickModelStatus( GB: GameBoardPtr; M: GearPtr );

Procedure NPCPersonalInfo( NPC: GearPtr; Z: TSDL_Rect );
Procedure DisplayInteractStatus( GB: GameBoardPtr; NPC: GearPtr; React,Endurance: Integer );
Procedure CharacterDisplay( PC: GearPtr; GB: GameBoardPtr );
Procedure InjuryViewer( PC: GearPtr; redraw: RedrawProcedureType );

Procedure BrowserInterfaceInfo( GB: GameBoardPtr; Part: GearPtr; Z: TSDL_Rect );
Procedure BrowserInterfaceMystery( Part: GearPtr; Z: TSDL_Rect );

Procedure DoMonologueDisplay( GB: GameBoardPtr; NPC: GearPtr; msg: String );

Procedure ArenaTeamInfo( Source: GearPtr; Z: TSDL_Rect );
Procedure TacticsTimeInfo( GB: GameBoardPtr );

Procedure ConcertStatus( PC: GearPtr; AL: AudienceList );

Procedure PersonadexInfo( NPC,HomeTown: GearPtr; Z: TSDL_Rect );


implementation

uses 	sdl_ttf,description,texutil,gearutil,
	ghmodule,ghchars,ghweapon,movement,ability,
	narration,ui4gh,sdlmap;

const
	StatusPerfect:TSDL_Color =	( r:  0; g:255; b: 65 );
	StatusOK:TSDL_Color =		( r: 30; g:190; b: 10 );
	StatusFair:TSDL_Color =		( r:220; g:190; b:  0 );
	StatusBad:TSDL_Color =		( r:220; g: 50; b:  0 );
	StatusCritical:TSDL_Color =	( r:150; g:  0; b:  0 );
	StatusKO:TSDL_Color =		( r: 75; g: 75; b: 75 );

	Interact_Sprite_Name = 'interact.png';
	Module_Sprite_Name = 'modules.png';
	PropStatus_Sprite_Name = 'modu_prop.png';
	Backdrop_Sprite_Name = 'backdrops.png';

	Altimeter_Sprite_Name = 'altimeter.png';
	Speedometer_Sprite_Name = 'speedometer.png';
	StatusFX_Sprite_Name = 'statusfx.png';
	OtherFX_Sprite_Name = 'otherfx.png';

	default_item_portrait = 'item_box.png';
	default_mecha_portrait = 'item_noimage.png';

var
	CZone,CDest: TSDL_Rect;		{ Current Zone, Current Destination }
	Interact_Sprite,Module_Sprite,PropStatus_Sprite,Backdrop_Sprite: SensibleSpritePtr;
	Altimeter_Sprite,Speedometer_Sprite: SensibleSpritePtr;
	StatusFX_Sprite,OtherFX_Sprite: SensibleSpritePtr;
	Concert_Mob_Sprite,Concert_Mood_Sprite: SensibleSpritePtr;


Procedure SetInfoZone( var Z: TSDL_Rect );
	{ Copy the provided coordinates into this unit's global }
	{ variables, then draw a nice little border and clear the }
	{ selected area. }
begin
	{ Copy the dimensions provided into this unit's global variables. }
	CZone := Z;
	CDest := Z;
end;



Function MaxTArmor( Part: GearPtr ): LongInt;
	{ Find the max amount of armor on this gear, counting external armor. }
var
	it: LongInt;
	S: GearPtr;
begin
	it := GearMaxArmor( Part );
	S := Part^.InvCom;
	while S <> Nil do begin
		if S^.G = GG_ExArmor then it := it + GearMaxArmor( S );
		S := S^.Next;
	end;
	MaxTArmor := it;
end;

Function CurrentTArmor( Part: GearPtr ): LongInt;
	{ Find the current amount of armor on this gear, counting external armor. }
var
	it: LongInt;
	S: GearPtr;
begin
	it := GearCurrentArmor( Part );
	S := Part^.InvCom;
	while S <> Nil do begin
		if S^.G = GG_ExArmor then it := it + GearCurrentArmor( S );
		S := S^.Next;
	end;
	CurrentTArmor := it;
end;

Function StatusColor( Full , Current: LongInt ): TSDL_Color;
	{ Given a part's Full and Current hit ratings, decide on a good status color. }
begin
	if Full = Current then StatusColor := StatusPerfect
	else if Current > ( Full div 2 ) then StatusColor := StatusOK
	else if Current > ( Full div 4 ) then StatusColor := StatusFair
	else if Current > ( Full div 8 ) then StatusColor := StatusBad
	else if Current > 0 then StatusColor := StatusCritical
	else StatusColor := StatusKO;
end;

Function EnduranceColor( Full , Current: LongInt ): TSDL_Color;
	{ Choose color to show remaining endurance (stamina or mental points)}
begin
	if Full = Current then EnduranceColor := StatusPerfect
	else if Current > 5 then EnduranceColor := StatusOK
	else if Current > 0 then EnduranceColor := StatusFair
	else EnduranceColor := StatusBad;
end;

Function HitsColor( Part: GearPtr ): TSDL_Color;
	{ Decide upon a nice color to represent the hits of this part. }
begin
	if PartActive( Part ) then
		HitsColor := StatusColor( GearMaxDamage( Part ) , GearCurrentDamage( Part ) )
	else
		HitsColor := StatusColor( 100 , 0 );
end;

Function ArmorColor( Part: GearPtr ): TSDL_Color;
	{ Decide upon a nice color to represent the armor of this part. }
begin
	ArmorColor := StatusColor( MaxTArmor( Part ) , CurrentTArmor( Part ) );
end;

Procedure AI_NextLine;
	{ Move the cursor to the next line. }
begin
	CDest.Y := CDest.Y + TTF_FontLineSkip( Game_Font );
end;

Procedure AI_Title( msg: String; C: TSDL_Color );
	{ Draw a centered message on the current line, then skip to the next line. }
var
	MyImage: PSDL_Surface;
	PLine: PChar;
begin
	pline := QuickPCopy( msg );
	MyImage := TTF_RenderText_Solid( Game_Font , pline , C );
	Dispose( pline );

	if MyImage <> Nil then CDest.X := CZone.X + ( ( CZone.W - MyImage^.W ) div 2 );

	SDL_BlitSurface( MyImage , Nil , Game_Screen , @CDest );
	SDL_FreeSurface( MyImage );

	CDest.Y := CDest.Y + TTF_FontLineSkip( Game_Font );
end;


Procedure AI_PrintFromRight( msg: String; Tab: Integer; C: TSDL_Color; F: PTTF_Font );
	{ Draw a left justified message on the current line. }
begin
	CDest.X := CZone.X + Tab;
	QuickText( msg , CDest , C , F );
end;

Procedure AI_PrintFromLeft( msg: String; Tab: Integer; C: TSDL_Color; F: PTTF_Font );
	{ Draw a left justified message on the current line. }
begin
	CDest.X := CZone.X + Tab;
	QuickTextRJ( msg , CDest , C , F );
end;


Procedure DisplayModules( Mek: GearPtr );
	{ Draw a lovely little diagram detailing this mek's modules. }
var
	X0: LongInt;	{ Midpoint of the info display. }
	N: Integer;	{ Module number on the current line. }
	MyDest: TSDL_Rect;
	MM,A,B: Integer;
	MD: GearPtr;

	Function PartStructImage( GS, CuD, MxD: Integer ): Integer;
		{ Given module type GS, with current damage score CuD and maximum damage }
		{ score MxD, return the correct image to use for it in the diagram. }
	begin
		if ( MxD > 0 ) and ( CuD < 1 ) then begin
			PartStructImage := ( MD^.S * 9 ) - 1;
		end else begin
			PartStructImage := ( MD^.S * 9 ) - 1 - ( CuD * 8 div MxD );
		end;
	end;

	Function PartArmorImage( GS, CuD, MxD: Integer ): Integer;
		{ Given module type GS, with current armor score CuD and maximum armor }
		{ score MxD, return the correct image to use for it in the diagram. }
	begin
		if CuD < 1 then begin
			PartArmorImage := ( MD^.S * 9 ) + 71;
		end else begin
			PartArmorImage := ( MD^.S * 9 ) + 71 - ( CuD * 8 div MxD );
		end;
	end;

	Function PropStructImage(): Integer;
		{ Return the correct image to use in the diagram. }
	var
		MxD,CuD: Integer;
	begin
		MxD := GearMaxDamage( Mek );
		CuD := GearCurrentDamage( Mek );
		if ( MxD > 0 ) and ( CuD < 1 ) then begin
			PropStructImage := 8;
		end else begin
			PropStructImage := 8 - ( CuD * 8 div MxD );
		end;
	end;

	Function PropArmorImage(): Integer;
		{ Return the correct image to use in the diagram. }
	var
		MxD,CuD: Integer;
	begin
		MxD := MaxTArmor( Mek );
		CuD := CurrentTArmor( Mek );
		if CuD < 1 then begin
			PropArmorImage := 18;
		end else begin
			PropArmorImage := 18 - ( CuD * 8 div MxD );
		end;
	end;

	Procedure AddPartsToDiagram( GS: Integer );
		{ Add parts to the status diagram whose gear S value }
		{ is equal to the provided number. }
	var
		CuD,MxD,Armor,Structure: Integer;	{ Armor & Structural damage values. }
	begin
		MD := Mek^.SubCom;
		while ( MD <> Nil ) do begin
			if ( MD^.G = GG_Module ) and ( MD^.S = GS ) then begin
				{ First, determine the spot at which to display the image. }
				if Odd( N ) then MyDest.X := X0 - ( N div 2 ) * 12 - 12
				else MyDest.X := X0 + ( N div 2 ) * 12;
				Inc( N );

				{ Display the structure. }
				MxD := GearMaxDamage( MD );
				CuD := GearCurrentDamage( MD );
				DrawSprite( Module_Sprite , MyDest , PartStructImage( MD^.S , CuD , MxD ) );

				{ Display the armor. }
				MxD := MaxTArmor( MD );
				CuD := CurrentTArmor( MD );
				if MxD <> 0 then begin
					DrawSprite( Module_Sprite , MyDest , PartArmorImage( MD^.S , CuD , MxD ) );

				end;
			end;
			MD := MD^.Next;
		end;
	end;
begin
	if Mek^.G = GG_Prop then begin
		MyDest.Y := CDest.Y + 8;
		MyDest.X := CZone.X + ( CZone.W div 2 ) - 16;
		DrawSprite( PropStatus_Sprite , MyDest , PropStructImage );
		DrawSprite( PropStatus_Sprite , MyDest , PropArmorImage );

	end else begin
		{ Draw the status diagram for this mek. }
		{ Line One - Heads, Turrets, Storage }
		MyDest.Y := CDest.Y;
		X0 := CZone.X + ( CZone.W div 2 ) - 7;

		N := 0;
		AddPartsToDiagram( GS_Head );
		AddPartsToDiagram( GS_Turret );
		if N < 1 then N := 1;	{ Want pods to either side of body; head and/or turret in middle. }
		AddPartsToDiagram( GS_Storage );

		{ Line Two - Torso, Arms, Wings }
		N := 0;
		MyDest.Y := MyDest.Y + 17;
		AddPartsToDiagram( GS_Body );
		AddPartsToDiagram( GS_Arm );
		AddPartsToDiagram( GS_Wing );

		{ Line Three - Tail, Legs }
		N := 0;
		MyDest.Y := MyDest.Y + 17;
		AddPartsToDiagram( GS_Tail );
		if N < 1 then N := 1;	{ Want legs to either side of body; tail in middle. }
		AddPartsToDiagram( GS_Leg );
	end;
	AI_NextLine;
end;

Procedure DisplayStatusFX( Part: GearPtr );
	{ Show status effects and other things this part might be suffering from. }
var
	MyDest: TSDL_Rect;
	T: Integer;
begin
	MyDest.X := CZone.X + 4;
	MyDest.Y := CZone.Y + CZone.H - 12;

	{ Display whether or not the mecha is hidden. }
	if ( Part^.Parent = Nil ) and IsHidden( Part ) then begin
		DrawSprite( OtherFX_Sprite , MyDest , 14 + ( Animation_Phase div 5 mod 2 ) );
		MyDest.X := MyDest.X + 10;
	end;


	if Part^.G = GG_Character then begin
		T := NAttValue( Part^.NA , NAG_Condition , NAS_Hunger ) - Hunger_Penalty_Starts;
		if T > ( NumGearStats * 3 ) then begin
			DrawSprite( OtherFX_Sprite , MyDest , 4 + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end else if T > ( NumGearStats * 2 ) then begin
			DrawSprite( OtherFX_Sprite , MyDest , 2 + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end else if T > 0 then begin
			DrawSprite( OtherFX_Sprite , MyDest , ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end;

		T := NAttValue( Part^.NA , NAG_Condition , NAS_MoraleDamage );
		if T < -20 then begin
			DrawSprite( OtherFX_Sprite , MyDest , 12 );
			MyDest.X := MyDest.X + 10;
		end else if T > 20 then begin
			DrawSprite( OtherFX_Sprite , MyDest , 13 );
			MyDest.X := MyDest.X + 10;
		end;

	end else if Part^.G = GG_Mecha then begin
		T := NAttValue( Part^.NA , NAG_Condition , NAS_PowerSpent );
		if T > 25 then begin
			DrawSprite( OtherFX_Sprite , MyDest , 10 + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end else if T > 10 then begin
			DrawSprite( OtherFX_Sprite , MyDest , 8 + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end else if T > 0 then begin
			DrawSprite( OtherFX_Sprite , MyDest , 6 + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end;

	end;

	for t := 1 to Num_Status_FX do begin
		if NAttValue( Part^.NA , NAG_StatusEffect , T ) <> 0 then begin
			DrawSprite( STatusFX_Sprite , MyDest , (( T - 1 ) * 2 ) + ( Animation_Phase div 5 mod 2 ) );
			MyDest.X := MyDest.X + 10;
		end;
	end;

end;

Procedure DisplayMoveStatus( GB: GameBoardPtr; M: GearPtr );
	{ Display the movement status for this model. }
var
	N: Integer;
	MyDest: TSDL_Rect;
begin
	n := mekAltitude( GB , M ) + 3;
	if N < 0 then n := 0
	else if N > 8 then n := 8;
	MyDest.Y := CZone.Y + 14;
	MyDest.X := CZone.X + CZone.W - 26;
	DrawSprite( Altimeter_Sprite , MyDest , N );

	N := NAttValue( M^.Na , NAG_Action , NAS_MoveAction );
	if not GearOperational( M ) then begin
		N := 0;
	end else if N = NAV_FullSpeed then begin
		N := ( Animation_Phase div 2 ) mod 4 + 6;
	end else if ( N <> NAV_Stop ) and ( N <> NAV_Hover ) then begin
		N := ( Animation_Phase div 3 ) mod 4 + 2;
	end else if CurrentMoveRate( GB^.Scene , M ) > 0 then begin
		N := 1;
	end else begin
		N := 0;
	end;
	MyDest.Y := CZone.Y + 14;
	MyDest.X := CZone.X;
	DrawSprite( Speedometer_Sprite , MyDest , N );
end;

Procedure CharacterHPSPMP( M: GearPtr );
	{ Display the HP, SP, and MP for this model. }
const
	StatName: Array [1..8] of String = (
	'Re','Bo','Sp','Pe','Cr','Eg','Kn','Ch'
	);
	GutterWidth = 20;
var
	CurP,MaxP: Integer;
	msg: String;
	T,X,S: Integer;
	C: TSDL_Color;
begin
	CDest.Y := CZone.Y + TTF_FontLineSkip( Game_Font ) + 65;

	AI_PrintFromRight( 'HP:' , GutterWidth , NeutralGrey , Small_Font );
	CurP := GearCurrentDamage( M );
	MaxP := GearMaxDamage( M );
	msg := BStr( CurP );
	AI_PrintFromLeft( msg , CZone.W div 3 - GutterWidth , StatusColor( MaxP , CurP ) , Small_Font );

	AI_PrintFromRight( 'SP:' , CZone.W div 3 + GutterWidth , NeutralGrey , Small_Font );
	CurP := CurrentStamina( M );
	MaxP := CharStamina( M );
	msg := BStr( CurP );
	AI_PrintFromLeft( msg , CZone.W * 2 div 3 - GutterWidth , EnduranceColor( MaxP , CurP ) , Small_Font );

	AI_PrintFromRight( 'MP:' , CZone.W * 2 div 3 + GutterWidth , NeutralGrey , Small_Font );
	CurP := CurrentMental( M );
	MaxP := CharMental( M );
	msg := BStr( CurP );
	AI_PrintFromLeft( msg , CZone.W - GutterWidth , EnduranceColor( MaxP , CurP ) , Small_Font );

	CDest.Y := CDest.Y + TTF_FontLineSkip( Small_Font );
	for t := 1 to 8 do begin
		AI_PrintFromRight( StatName[t] , CZone.W * (t - 1) div 8 + 2 , NeutralGrey , Small_Font );

		S := CSTat( M , T );
		if S > M^.Stat[ T ] then C := InfoHilight
		else if S < M^.Stat[ T ] then C := StatusBad
		else C := InfoGreen;

		AI_PrintFromLeft( BStr( S ) , CZone.W * t div 8 - 3 , C , Small_Font );
	end;
end;

Procedure MechaMVTRSE( M: GearPtr );
	{ Display the MV, TR, and SE for this model. }
const
	GutterWidth = 20;
var
	CurP,MaxP: Integer;
	msg: String;
	MyDest: TSDL_Rect;
begin
	CDest.Y := CZone.Y + TTF_FontLineSkip( Game_Font ) + 65;

	AI_PrintFromRight( 'MV:' , GutterWidth , NeutralGrey , Small_Font );
	msg := SgnStr( MechaManeuver( M ) );
	AI_PrintFromLeft( msg , CZone.W div 3 - GutterWidth , StatusOK , Small_Font );

	AI_PrintFromRight( 'TR:' , CZone.W div 3 + GutterWidth , NeutralGrey , Small_Font );
	msg := SgnStr( MechaTargeting( M ) );
	AI_PrintFromLeft( msg , CZone.W * 2 div 3 - GutterWidth , StatusOK , Small_Font );

	AI_PrintFromRight( 'SE:' , CZone.W * 2 div 3 + GutterWidth , NeutralGrey , Small_Font );
	msg := SgnStr( MechaSensorRating( M ) );
	AI_PrintFromLeft( msg , CZone.W - GutterWidth , StatusOK , Small_Font );
	MyDest.X := CZone.X;
	MyDest.W := CZone.W;
	MyDest.Y := CDest.Y + TTF_FontLineSkip( Small_Font );
	QuickTextC( MassString( M ) + ' ' + MsgString( 'FORMNAME_' + BStr( M^.S ) ) , MyDest , NeutralGrey , Small_Font );
end;

Procedure DisplayModelStatus( GB: GameBoardPtr; M: GearPtr; MyDest: TSDL_Rect );
	{ Display the model status in a window near the mouse. }
var
	Box,Box2: TSDL_Rect;
	HP,HPD: Integer;
	name: String;
begin
	InfoBox( MyDest );
	SetInfoZone( MyDest );

	name := MechaPilotName( M );
	GameMsg( name , MyDest , StdWhite );
	AI_NextLine;
	if IsMasterGear( M ) then begin
		DisplayModules( M );
		DisplayMoveStatus( GB , M );
		DisplayStatusFX( M );
	end;

	if M^.G = GG_Character then CharacterHPSPMP( M )
	else if M^.G = GG_Mecha then MechaMVTRSE( M );
end;

Procedure QuickModelStatus( GB: GameBoardPtr; M: GearPtr );
	{ Display the status of this model quickly in the caption area. }
var
	MyDest: TSDL_Rect;
begin
	MyDest.X := Mouse_X + 8;
	MyDest.Y := Mouse_Y + 8;
	MyDest.W := Model_Status_Width;
	MyDest.H := Model_Status_Height;
	if ( MyDest.X + MyDest.W ) > ( ScreenWidth - 10 ) then MyDest.X := MyDest.X - MyDest.W - 32;
	if ( MyDest.Y + MyDest.H ) > ( ScreenHeight - 10 ) then MyDest.Y := MyDest.Y - MyDest.H - 32;
	DisplayModelStatus( GB , M , MyDest );
end;

Function PortraitName( NPC: GearPtr ): String;
	{ Return a name for this NPC's protrait. }
var
	it,Criteria: String;
	PList,P,P2: SAttPtr;	{ Portrait List. }
	IsOld: Integer;	{ -1 for young, 0 for medium, 1 for old }
	IsCharming: Integer;	{ -1 for low Charm, 0 for medium, 1 for high charm }
	HasMecha: Boolean;	{ TRUE if NPC has a mecha, FALSE otherwise. }
		{ Y Must have positive value }
		{ N Must have negative valie }
		{ - May have either value }
	PisOK: Boolean;
begin
	{ Error check - better safe than sorry, unless in an A-ha song. }
	if NPC = Nil then Exit( '' );

	{ Check the standard place first. If no portrait is defined, }
	{ grab one from the IMAGE/ directory. }
	it := SAttValue( NPC^.SA , 'SDL_PORTRAIT' );
	if it = '' then begin
		{ Create a portrait list based upon the character's gender. }
		if NAttValue( NPC^.NA , NAG_CharDescription , NAS_Gender ) = NAV_Male then begin
			PList := CreateFileList( Graphics_Directory + 'por_m_*.*' );
		end else begin
			PList := CreateFileList( Graphics_Directory + 'por_f_*.*' );
		end;

		{ Filter the portrait list based on the NPC's traits. }
		if NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) < 6 then begin
			IsOld := -1;
		end else if NAttValue( NPC^.NA , NAG_CharDescription , NAS_DAge ) > 15 then begin
			IsOld :=  1;
		end else IsOld := 0;
		if NPC^.Stat[ STAT_Charm ] < 10 then begin
			IsCharming := -1;
		end else if NPC^.Stat[ STAT_Charm ] >= 15 then begin
			IsCharming :=  1;
		end else IsCharming := 0;
		HasMecha := IsACombatant( NPC );
		P := PList;
		while P <> Nil do begin
			P2 := P^.Next;
			Criteria := RetrieveBracketString( P^.Info );
			PisOK := True;
			if Length( Criteria ) >= 3 then begin
				{ Check youth. }
				Case Criteria[1] of
					'O':	PisOK := IsOld > 0;
					'Y':	PisOK := IsOld < 0;
					'A':	PisOK := IsOld > -1;
					'J':	PisOK := IsOld < 1;
				end;

				{ Check charm. }
				if PisOK then Case Criteria[2] of
					'C':	PisOK := IsCharming > 0;
					'U':	PisOK := IsCharming < 0;
					'P':	PisOK := IsCharming < 1;
					'A':	PisOK := IsCharming > -1;
				end;

				{ Check mecha. }
				if PisOK then Case Criteria[3] of
					'Y':	PisOK := HasMecha;
					'N':	PisOK := not HasMecha;
				end;
			end;
			if not PisOK then RemoveSAtt( PList , P );
			P := P2;
		end;

		{ As long as we found some appropriate files, select one of them }
		{ randomly and save it for future reference. }
		if PList <> Nil then begin
			it := SelectRandomSAtt( PList )^.Info;
			DisposeSAtt( PList );
			SetSAtt( NPC^.SA , 'SDL_PORTRAIT <' + it + '>' );
		end;
	end;

	PortraitName := it;
end;

Procedure NPCPersonalInfo( NPC: GearPtr; Z: TSDL_Rect );
	{ Display the name, job, age, and gender of the NPC. }
begin
	{ First the name, then the description. }
	QuickTextC( GearName( NPC ) , Z , InfoHiLight , game_font );
	Z.Y := Z.Y + TTF_FontLineSkip( Game_Font );
	QuickTextC( JobAgeGenderDesc( NPC ) , Z , InfoGreen , game_font );
end;

Procedure DoMonologueDisplay( GB: GameBoardPtr; NPC: GearPtr; msg: String );
	{ Show the NPC's portrait, name, and description, as well as the message. }
var
	SS: SensibleSpritePtr;
begin
	DrawMonologueBorder;
	NPCPersonalInfo( NPC , ZONE_MonologueInfo );
	DrawSprite( Backdrop_Sprite , ZONE_MonologuePortrait , 0 );
	SS := LOcateSprite( PortraitName( NPC ) , SpriteColor( GB , NPC ) , 100 , 150 );

	{ If the current portrait doesn't work, clear the portrait attribute so a new one }
	{ will be selected. }
	if SS^.Img = Nil then SetSAtt( NPC^.SA , 'SDL_PORTRAIT <>' );

	DrawSprite( SS , ZONE_MonologuePortrait , 0 );
	GameMsg( Msg , ZONE_MonologueText , InfoHiLight );
end;

Procedure DisplayInteractStatus( GB: GameBoardPtr; NPC: GearPtr; React,Endurance: Integer );
	{ Show the needed information regarding this conversation. }
var
	MyDest: TSDL_Rect;
	T,RStep: Integer;
	SS: SensibleSpritePtr;
begin
	SetInfoZone( ZONE_InteractStatus );

	NPCPersonalInfo( NPC , ZONE_InteractStatus );

	{ Prepare to draw the reaction indicators. }
	ClrZone( ZONE_InteractInfo );
	MyDest := ZONE_InteractInfo;
	MyDest.Y := MyDest.Y + ( MyDest.H - 32 ) div 4;
	MyDest.X := MyDest.X + ( MyDest.H - 32 ) div 4;
	for t := 0 to 3 do begin
		DrawSprite( INTERACT_SPRITE , MyDest , t );
		MyDest.X := MyDest.X + 4;
	end;

	{ Calculate how many 4-pixel-wide measures we can show in the zone, }
	{ to indicate a Reaction of 100. }
	RStep := 400 div ( ZONE_InteractInfo.W - ZONE_InteractInfo.H + 16 );
	if RStep < 1 then RStep := 1;

	{ Draw the reaction indicators. }
	if React > 0 then begin
		for t := 0 to ( React * ( ZONE_InteractInfo.W - ZONE_InteractInfo.H + 16 ) div 400 ) do begin
			DrawSprite( INTERACT_SPRITE , MyDest , 8 );
			MyDest.X := MyDest.X + 4;
		end;
	end else if React < 0 then begin
		for t := 0 to ( Abs( React ) * ( ZONE_InteractInfo.W - ZONE_InteractInfo.H + 16 ) div 400 ) do begin
			DrawSprite( INTERACT_SPRITE , MyDest , 9 );
			MyDest.X := MyDest.X + 4;
		end;
	end else begin
		DrawSprite( INTERACT_SPRITE , MyDest , 10 );
	end;

	MyDest := ZONE_InteractInfo;
	MyDest.Y := MyDest.Y + MyDest.H div 2 + ( MyDest.H - 32 ) div 4;
	MyDest.X := MyDest.X + ( MyDest.H - 32 ) div 4;
	for t := 4 to 7 do begin
		DrawSprite( INTERACT_SPRITE , MyDest , t );
		MyDest.X := MyDest.X + 4;
	end;
	if Endurance > 5 then begin
		RStep := 11;
	end else if Endurance > 2 then begin
		RStep := 12;
	end else begin
		RStep := 13;
	end;
	for t := 1 to ( Endurance * ( ZONE_InteractInfo.W - ZONE_InteractInfo.H + 16 ) div 40 ) do begin
		DrawSprite( INTERACT_SPRITE , MyDest , RStep );
		MyDest.X := MyDest.X + 4;
	end;

	{ Draw the portrait. }
	DrawSprite( Backdrop_Sprite , ZONE_InteractPhoto , 0 );
	SS := LOcateSprite( PortraitName( NPC ) , SpriteColor( GB , NPC ) , 100 , 150 );

	{ If the current portrait doesn't work, clear the portrait attribute so a new one }
	{ will be selected. }
	if SS^.Img = Nil then SetSAtt( NPC^.SA , 'SDL_PORTRAIT <>' );

	DrawSprite( SS , ZONE_InteractPhoto , 0 );
end;


Procedure CharacterDisplay( PC: GearPtr; GB: GameBoardPtr );
	{ Display the important stats for this PC in the map zone. }
var
	msg,job: String;
	T,R,FID: Integer;
	S: LongInt;
	C: TSDL_Color;
	X0,X1,Y0: Integer;
	Mek: GearPtr;
	MyDest: TSDL_Rect;
	SS: SensibleSpritePtr;
begin
	{ Begin with one massive error check... }
	if PC = Nil then Exit;
	if PC^.G <> GG_Character then PC := LocatePilot( PC );
	if PC = Nil then Exit;

	SetInfoZone( ZONE_CharacterInfo );
	InfoBox( ZONE_CharacterInfo );

	AI_Title( GearName( PC ) , NeutralGrey );
	AI_Title( JobAgeGenderDesc( PC ) , InfoGreen );
	AI_NextLine;

	{ Record the current Y position- we'll be coming back here later. }
	Y0 := CDest.Y;

	MyDest.Y := CDest.Y;
	X0 := ZONE_CharacterInfo.X + ( ZONE_CharacterInfo.W div 3 );

	for t := 1 to NumGearStats do begin
		{ Find the adjusted stat value for this stat. }
		S := CStat( PC , T );
		R := ( S + 2 ) div 3;
		if R > 7 then R := 7;

		{ Determine an appropriate color for the stat, depending }
		{ on whether its adjusted value is higher or lower than }
		{ the basic value. }
		if S > PC^.Stat[ T ] then C := InfoHilight
		else if S < PC^.Stat[ T ] then C := StatusBad
		else C := InfoGreen;

		{ Do the output. }
		MyDest.X := ZONE_CharacterInfo.X + 10;
		QuickText( MsgString( 'StatName_' + BStr( T ) ) , MyDest , NeutralGrey , game_font );
		msg := BStr( S );
		MyDest.X := X0 - 30 - TextLength( Game_Font , msg );
		QuickText( msg , MyDest , C , game_font );

		MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
	end;

	{ Set column measurements for the next column. }
	MyDest.Y := Y0;
	X0 := ZONE_CharacterInfo.X + ( ZONE_CharacterInfo.W div 3 );
	X1 := ZONE_CharacterInfo.X + ( ZONE_CharacterInfo.W * 2 div 3 ) - 10;

	MyDest.X := X0;
	QuickText( MsgString( 'INFO_XP' ) , MyDest , NeutralGrey , game_font );
	msg := BStr( NAttVAlue( PC^.NA , NAG_Experience , NAS_TotalXP ) );
	MyDest.X := X1 - TextLength( Game_Font , msg );
	QuickText( msg , MyDest , InfoGreen , game_font );
	MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );

	MyDest.X := X0;
	QuickText( MsgString( 'INFO_XPLeft' ) , MyDest , NeutralGrey , game_font );
	msg := BStr( NAttVAlue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttVAlue( PC^.NA , NAG_Experience , NAS_SpentXP ) );
	MyDest.X := X1 - TextLength( Game_Font , msg );
	QuickText( msg , MyDest , InfoGreen , game_font );
	MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );

	MyDest.X := X0;
	QuickText( MsgString( 'INFO_Credits' ) , MyDest , NeutralGrey , game_font );
	msg := '$' + BStr( NAttVAlue( PC^.NA , NAG_Experience , NAS_Credits ) );
	MyDest.X := X1 - TextLength( Game_Font , msg );
	QuickText( msg , MyDest , InfoGreen , game_font );
	MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );

	if ( GB <> Nil ) then begin
		{ Print the name of the PC's mecha. }
		Mek := FindPilotsMecha( GB^.Meks , PC );
		if Mek <> Nil then begin
			MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
			MyDest.X := X0;
			QuickText( MsgString( 'INFO_MekSelect' ) , MyDest , NeutralGrey , game_font );
			MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );

			msg := FullGearName( Mek );
			MyDest.X := X1 - TextLength( Game_Font , msg );
			QuickText( msg , MyDest , InfoGreen , game_font );
		end;

		{ And also of the PC's faction. }
		FID := NAttValue( PC^.NA , NAG_Personal , NAS_FactionID );
		if ( FID <> 0 ) and ( GB^.Scene <> Nil ) then begin
			Mek := SeekFaction( GB^.Scene , FID );
			if Mek <> Nil then begin
				MyDest.X := X0;
				MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
				QuickText( MsgString( 'INFO_Faction' ) , MyDest , NeutralGrey , game_font );
				MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );

				msg := GearName( Mek );
				MyDest.X := X1 - TextLength( Game_Font , msg );
				QuickText( msg , MyDest , InfoGreen , game_font );
			end;
		end;
	end;

	{ Show the character portrait. }
	MyDest.X := ZONE_CharacterInfo.X + ( ZONE_CharacterInfo.W * 5 div 6 ) - 50;
	MyDest.Y := Y0;
	DrawSprite( Backdrop_Sprite , MyDest , 0 );
	SS := LocateSprite( PortraitName( PC ) , SAttValue( PC^.SA , 'SDL_COLORS' ) , 100 , 150 );

	{ If the current portrait doesn't work, clear the portrait attribute so a new one }
	{ will be selected. }
	if SS^.Img = Nil then SetSAtt( PC^.SA , 'SDL_PORTRAIT <>' );

	DrawSprite( SS , MyDest , 0 );


	{ Print the biography. }
	MyDest.X := ZONE_CharacterInfo.X + 49;
	MyDest.W := ZONE_CharacterInfo.W - 98;
	MyDest.Y := Y0 + 160;
	MyDest.H := 80;

	MyDest.X := MyDest.X + 1;
	MyDest.Y := MyDest.Y + 1;
	MyDest.W := MyDest.W - 2;
	MyDest.H := MyDest.H - 2;
	GameMsg( SAttValue( PC^.SA , 'BIO1' ) , MyDest , InfoGreen );
end;



Procedure InjuryViewer( PC: GearPtr; redraw: RedrawProcedureType );
	{ Display a brief listing of all the PC's major health concerns. }
	{ Display a brief listing of all the PC's major health concerns. }
	Procedure ShowSubInjuries( Part: GearPtr );
		{ Show the injuries of this part, and also for its subcoms. }
	var
		MD,CD: Integer;
	begin
		while Part <> Nil do begin
			MD := GearMaxDamage( Part );
			CD := GearCurrentDamage( Part );
			if not PartActive( Part ) then begin
				AI_PrintFromRight( GearName( Part ) + MsgString( 'INFO_IsDisabled' ) , 2 , StatusColor( MD , CD ) , Game_Font );
				AI_NextLine;
			end else if CD < MD then begin
				AI_PrintFromRight( GearName( Part ) + MsgString( 'INFO_IsHurt' ) , 2 , StatusColor( MD , CD ) , Game_Font );
				AI_NextLine;
			end;
			ShowSubInjuries( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
	Procedure RealInjuryDisplay;
	var
		SP,MP,T: Integer;
	begin
		{ Begin with one massive error check... }
		if PC = Nil then Exit;
		if PC^.G <> GG_Character then PC := LocatePilot( PC );
		if PC = Nil then Exit;

		SetInfoZone( ZONE_CharacterInfo );

		AI_Title( MsgString( 'INFO_InjuriesTitle' ) , StdWhite );

		{ Show exhaustion status first. }
		SP := CurrentStamina( PC );
		MP := CurrentMental( PC );
		if ( SP = 0 ) and ( MP = 0 ) then begin
			AI_PrintFromRight( MsgString( 'INFO_FullExhausted' ) , 2 , StatusBad , Game_Font );
			AI_NextLine;
		end else if ( SP = 0 ) or ( MP = 0 ) then begin
			AI_PrintFromRight( MsgString( 'INFO_PartExhausted' ) , 2 , StatusFair , Game_Font );
			AI_NextLine;
		end;

		{ Hunger next. }
		T := NAttValue( PC^.NA , NAG_Condition , NAS_Hunger ) - Hunger_Penalty_Starts;
		if T > ( NumGearStats * 3 ) then begin
			AI_PrintFromRight( MsgString( 'INFO_ExtremeHunger' ) , 2 , StatusBad , Game_Font );
			AI_NextLine;
		end else if T > ( NumGearStats * 2 ) then begin
			AI_PrintFromRight( MsgString( 'INFO_Hunger' ) , 2 , StatusFair , Game_Font );
			AI_NextLine;
		end else if T > 0 then begin
			AI_PrintFromRight( MsgString( 'INFO_MildHunger' ) , 2 , StatusOK , Game_Font );
			AI_NextLine;
		end;

		{ Low morale next. }
		T := NAttValue( PC^.NA , NAG_Condition , NAS_MoraleDamage );
		if T > 65 then begin
			AI_PrintFromRight( MsgString( 'INFO_ExtremeMorale' ) , 2 , StatusBad , Game_Font );
			AI_NextLine;
		end else if T > 40 then begin
			AI_PrintFromRight( MsgString( 'INFO_Morale' ) , 2 , StatusFair , Game_Font );
			AI_NextLine;
		end else if T > 20 then begin
			AI_PrintFromRight( MsgString( 'INFO_MildMorale' ) , 2 , StatusOK , Game_Font );
			AI_NextLine;
		end;


		for t := 1 to Num_Status_FX do begin
			if NAttValue( PC^.NA , NAG_StatusEffect , T ) <> 0 then begin
				AI_PrintFromRight( MsgString( 'INFO_Status' + BStr( T ) ) , 2 , StatusBad , Game_Font );
				AI_NextLine;
			end;
		end;

		{ Show limb injuries. }
		ShowSubInjuries( PC^.SubCom );
	end;
var
	A: Char;
begin
	repeat
		Redraw;
		InfoBox( ZONE_CharacterInfo );
		RealInjuryDisplay;
		DoFlip;
		A := RPGKey;
	until ( A = ' ' ) or ( A = #27 ) or ( A = #8 );
end;

Procedure BriefGearStats( Part: GearPtr; Z: TSDL_Rect );
	{ Display some brief stats on this gear in the requested screen area. }
	{ This is the information to the right of the gear's portrait. }
var
	N: LongInt;
	msg: String;
	MyDest: TSDL_Rect;
begin
	{ Display the part's armor rating. }
	MyDest.X := Z.X + Z.W - 5;
	MyDest.Y := Z.Y;
	QuickTextRJ( 'DP' , MyDest , NeutralGrey , game_font );
	MyDest.X := MyDest.X - TextLength( Game_Font , ' DP' );

	if IsMasterGear( Part ) then begin
		{ Display the percent damaged. }
		N := PercentDamaged( Part );
		msg := BStr( N ) + '%';
		QuickTextRJ( Msg , MyDest , StatusColor( 100 , N ) , game_font );
	end else begin
		{ Display the part's damage rating. }
		N := GearCurrentDamage( Part );
		if N > 0 then msg := BStr( N )
		else msg := '-';
		QuickTextRJ( Msg , MyDest , HitsColor( Part ) , game_font );

		{ Display the part's armor rating. }
		MyDest.X := MyDest.X - TextLength( Game_Font , msg );
		N := GearCurrentArmor( Part );
		if N > 0 then msg := '[' + BStr( N )
		else msg := '[-';
		msg := msg + '] ';
		QuickTextRJ( Msg , MyDest , ArmorColor( Part ) , game_font );
	end;

	{ Display the mass. }
	N := GearMass( Part );
	MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
	MyDest.X := Z.X + Z.W - 5;
	if N > 0 then QuickTextRJ( MassString( Part ) , MyDest , NeutralGrey , game_font );

	{ Display the cost. }
	MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
	MyDest.X := Z.X + Z.W - 5;
	if Part^.G = GG_Mecha then begin
		N := GearValue( Part );
		if N > 0 then QuickTextRJ( 'PV:' + BStr( N ) , MyDest , NeutralGrey , game_font );
	end else begin
		N := GearCost( Part );
		if N > 0 then QuickTextRJ( '$' + BStr( N ) , MyDest , NeutralGrey , game_font );
	end;

	if ( Part^.G < 0 ) and ( Part^.G <> GG_Set ) then begin
		MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
		MyDest.X := Z.X + Z.W - 5;
		QuickTextRJ( 'G:' + BStr( Part^.G ) + '/' + BStr( Part^.S ) + '/' + BStr( Part^.V ) , MyDest , NeutralGrey , game_font );
	end;

	{ Display the spaces. }
	if not IsMasterGear( Part ) then begin
		MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
		MyDest.X := Z.X + Z.W - 5;
		if ( Part^.G = GG_Module ) or ( Part^.G = GG_ExArmor ) or ( Part^.G = GG_Shield ) or ( Part^.G = GG_Harness ) then begin
			QuickTextRJ( BStr( SubComComplexity( Part ) ) + '/' + BStr( ComponentComplexity( Part ) ) + ' slots used' , MyDest , NeutralGrey , game_font );
		end else begin
			QuickTextRJ( BStr( ComponentComplexity( Part ) ) + ' slots' , MyDest , NeutralGrey , game_font );
		end;
	end;

end;

Procedure BriefCharaStats( Part: GearPtr; Z: TSDL_Rect );
	{ Display some brief stats on this character. }
	{ This is the information to the right of the gear's portrait. }
var
	T,X0,X1,S: Integer;
	MyDest: TSDL_Rect;
	C: TSDL_Color;
begin
	X1 := Z.X + Z.W - 5;
	X0 := X1 - 30;
	MyDest.Y := Z.Y;
	for t := 1 to 8 do begin
		MyDest.X := X0;
		QuickTextRJ( MsgString( 'StatName_' + BStr( T ) ) + ':' , MyDest , NeutralGrey , game_font );

		S := CSTat( Part , T );
		if S > Part^.Stat[ T ] then C := InfoHilight
		else if S < Part^.Stat[ T ] then C := StatusBad
		else C := InfoGreen;

		MyDest.X := X1;
		QuickTextRJ( BStr( S ) , MyDest , C , game_font );

		MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
	end;
end;

Function InfoImageName( Part: GearPtr ): String;
	{ Return the name for this part. }
var
	name: String;
begin
	if Part^.G = GG_Character then begin
		InfoImageName := PortraitName( Part );
	end else begin
		name := SAttValue( Part^.SA , 'SDL_PORTRAIT' );
		if name = '' then begin
			if Part^.G = GG_Mecha then name := default_mecha_portrait
			else name := default_item_portrait;
		end;
		InfoImageName := name;
	end;
end;

Procedure BrowserInterfaceInfo( GB: GameBoardPtr; Part: GearPtr; Z: TSDL_Rect );
	{ Display the "Browser Interface" info for this part. This information }
	{ includes the mass, damage, stats, picture (in gfx mode), extended description }
	{ and regular description. }
var
	MyDest: TSDL_Rect;
	MyText: PSDL_Surface;
	msg: String;
	SS: SensibleSpritePtr;
begin
	SDL_SetClipRect( Game_Screen , @Z );

	{ Draw the picture in the upper-left part of the zone. }
	MyDest.X := Z.X;
	MyDest.Y := Z.Y;
	msg := SAttValue( Part^.SA , 'SDL_COLORS' );
	SS := LocateSprite( InfoImageName( Part ) , msg , 100 , 150 );
	DrawSprite( SS , MyDest , 0 );

	{ Display the brief stats based on gear type. }
	{ Calculate the brief stats window area. }
	MyDest.X := Z.X + 100;
	MyDest.Y := Z.Y;
	MyDest.W := Z.W - 100;
	MyDest.H := 150;
	if Part^.G = GG_Character then begin
		BriefCharaStats( Part , MyDest );
	end else begin
		BriefGearStats( Part , MyDest );
	end;

	MyDest.X := Z.X;
	MyDest.Y := Z.Y + 155;

	{ Display the extended description. }
	msg := ExtendedDescription( GB , Part );
	if msg <> '' then begin
		MyText := PrettyPrint( msg , Z.W , InfoGreen , True );
		if MyText <> Nil then begin
			SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
			MyDest.Y := MyDest.Y + MyText^.H + 10;
			SDL_FreeSurface( MyText );
		end;
	end;

	{ Display the description. }
	if MyDest.Y < ( Z.Y + Z.H ) then begin
		MyDest.W := Z.W;
		MyDest.H := Z.H + Z.Y - MyDest.Y - 5;
		GameMsg( SAttValue( Part^.SA , 'DESC' ) , MyDest , InfoGreen );
	end;

	{ Restore the clip zone. }
	SDL_SetClipRect( Game_Screen , Nil );
end;

Procedure BrowserInterfaceMystery( Part: GearPtr; Z: TSDL_Rect );
	{ This gear is a mystery. Display its name, and that's about it. }
var
	MyDest: TSDL_Rect;
	MyText: PSDL_Surface;
	msg: String;
	SS: SensibleSpritePtr;
begin
	SDL_SetClipRect( Game_Screen , @Z );

	{ Draw the picture in the upper-left part of the zone. }
	MyDest.X := Z.X;
	MyDest.Y := Z.Y;
	msg := SAttValue( Part^.SA , 'SDL_COLORS' );
	SS := LocateSprite( InfoImageName( Part ) , msg , 100 , 150 );
	DrawSprite( SS , MyDest , 0 );

	MyDest.X := Z.X;
	MyDest.Y := Z.Y + 155;

	{ Display the extended description. }
	msg := GearName( Part );
	if msg <> '' then begin
		MyText := PrettyPrint( msg , Z.W , InfoGreen , True );
		if MyText <> Nil then begin
			SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
			MyDest.Y := MyDest.Y + MyText^.H + 10;
			SDL_FreeSurface( MyText );
		end;
	end;

	{ Restore the clip zone. }
	SDL_SetClipRect( Game_Screen , Nil );
end;

Procedure ArenaTeamInfo( Source: GearPtr; Z: TSDL_Rect );
	{ Print the important information for this team. }
var
	Fac: GearPtr;
	Renown: Integer;
begin
	SetInfoZone( Z );
	AI_Title( GearName( Source ) , StdWhite );
	AI_NextLine;
	AI_Title( '$' + BStr( NAttValue( Source^.NA , NAG_Experience , NAS_Credits ) ) , InfoGreen );
	AI_NextLine;

	Fac := SeekFaction( Source , NAttValue( Source^.NA , NAG_Personal , NAS_FactionID ) );
	if Fac <> Nil then begin
		AI_Title( GearName( Fac ) , NeutralGrey );
	end;
	AI_NextLine;
	Renown := NAttValue( Source^.NA , NAG_CharDescription , NAS_Renowned );
	AI_Title( RenownDesc( Renown ) , InfoGreen );
end;

Procedure TacticsTimeInfo( GB: GameBoardPtr );
	{ Tell how much free time the currently active model has. }
var
	TimeLeft,W: LongInt;
	MyDest: TSDL_Rect;
begin
	TimeLeft := TacticsRoundLength - ( GB^.ComTime - NAttValue( GB^.Scene^.NA , NAG_SceneData , NAS_TacticsTurnStart ) );
	MyDest := ZONE_Clock;
	QuickText( 'TIME:' , MyDest , StdWhite , game_font );
	W := TextLength( Game_Font , 'TIME:' ) + 5;

	MyDest.X := MyDest.X + W;
	MyDest.W := MyDest.W - W;
	SDL_FillRect( game_screen , @MyDest , SDL_MapRGB( Game_Screen^.Format , 150 , 150 , 150 ) );
	MyDest.W := ( MyDest.W * TimeLeft ) div TacticsRoundLength;
	SDL_FillRect( game_screen , @MyDest , SDL_MapRGB( Game_Screen^.Format , 0 , 250 , 50 ) );
end;

Procedure ConcertStatus( PC: GearPtr; AL: AudienceList );
	{ Display the status information for the concert minigame. }
const
	Mob_Position: Array [1..MaxAudienceSize,1..2] of Integer = (
	(200,80),(100,80),(300,80),(150,60),(250,60),
	(0,80),(400,80),(50,60),(350,60),(200,40),
	(100,40),(300,40)
	);
	Dance_Position: Array [0..3,1..2] of Integer = (
	(0,0),(-1,-1),(0,0),(1,-1)
	);
var
	T,Dance_Phase: Integer;
	SS: SensibleSpritePtr;
	MyDest: TSDL_Rect;
begin
	{ Draw the audience status. }
	{ First, clip the area. }
	SDL_SetClipRect( Game_Screen , @ZONE_ConcertAudience );

	{ Draw each audience mob, and the symbol indicating their mood. }
	for t := MaxAudienceSize downto 1 do begin
		if AL[t].Mood <> MOOD_Absent then begin
			MyDest := ZONE_ConcertAudience;
			if AL[t].Mood <> MOOD_WalkOut then begin
				Dance_Phase := ( Animation_Phase div ( 100 div ( AL[t].Mood * AL[t].Mood + 3 ) ) + T * 7 ) mod 4;
			end else Dance_Phase := 0;
			MyDest.X := MyDest.X + Mob_Position[T,1] + Dance_Position[ Dance_Phase , 1 ];
			MyDest.Y := MyDest.Y + Mob_Position[T,2] + Dance_Position[ Dance_Phase , 2 ];

			if AL[t].Mood <> MOOD_WalkOut then begin
				DrawSprite( Concert_Mob_Sprite , MyDest , AL[T].Trait );
			end;

			MyDest.X := MyDest.X + 42 - Dance_Position[ Dance_Phase , 1 ];
			MyDest.Y := MyDest.Y + 4  - Dance_Position[ Dance_Phase , 2 ];
			DrawSprite( Concert_Mood_Sprite , MyDest , AL[T].Mood );
		end;
	end;

	{ Restore the clip zone. }
	SDL_SetClipRect( Game_Screen , Nil );

	{ Draw the portrait of the singer. }
	DrawSprite( Backdrop_Sprite , ZONE_ConcertPhoto , 0 );
	SS := LocateSprite( PortraitName( PC ) , SAttValue( PC^.SA , 'SDL_COLORS' ) , 100 , 150 );
	DrawSprite( SS , ZONE_ConcertPhoto , 0 );
end;

Procedure PersonadexInfo( NPC,HomeTown: GearPtr; Z: TSDL_Rect );
	{ Display personality info about this NPC. }
	Procedure PersonaStats( MyZone: TSDL_Rect );
		{ Display some brief stats on this character. }
		{ This is the information to the right of the gear's portrait. }
	var
		T,X0,X1,S: Integer;
		MyDest: TSDL_Rect;
		C: TSDL_Color;
		Procedure PStat_NextLine;
		begin
			MyDest.Y := MyDest.Y + TTF_FontLineSkip( Game_Font );
		end;
	begin
		X1 := MyZone.X + MyZone.W - 5;
		X0 := MyZone.X + 5;
		MyDest.Y := MyZone.Y;

		MyDest.X := X0;
		MyDest.H := TTF_FontLineSkip( Game_Font ) * 2;
		QuickText( GearName( NPC ) , MyDest , StdWhite , game_font );
		MyDest.Y := MyDest.Y + 2 * TTF_FontLineSkip( Game_Font );

		QuickText( MsgString( 'PDEX_Attitude' ) , MyDest , NeutralGrey , game_font );
		PStat_NextLine;

		MyDest.X := X1;
		QuickTextRJ( MsgString( 'Attitude_' + BStr( NAttValue( NPC^.NA , NAG_XXRan , NAS_XXChar_Attitude ) ) ) , MyDest , InfoGreen , game_font );
		PStat_NextLine;

		MyDest.X := X0;
		QuickText( MsgString( 'PDEX_Motivation' ) , MyDest , NeutralGrey , game_font );
		PStat_NextLine;

		MyDest.X := X1;
		QuickTextRJ( MsgString( 'Motivation_' + BStr( NAttValue( NPC^.NA , NAG_XXRan , NAS_XXChar_Motivation ) ) ) , MyDest , InfoGreen , game_font );
		PStat_NextLine;

		MyDest.X := X0;
		QuickText( MsgString( 'PDEX_Location' ) , MyDest , NeutralGrey , game_font );
		PStat_NextLine;

		MyDest.X := X1;
		if HomeTown <> Nil then begin
			QuickTextRJ( GearName( HomeTown ) , MyDest , InfoGreen , game_font );
		end else begin
			QuickTextRJ( '???' , MyDest , InfoGreen , game_font );
		end;
		PStat_NextLine;

		MyDest.X := X0;
		QuickText( MsgString( 'PDEX_SkillRank' ) , MyDest , NeutralGrey , game_font );
		PStat_NextLine;

		MyDest.X := X1;
		if IsACombatant( NPC ) then begin
			QuickTextRJ( RenownDesc( NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned ) ) , MyDest , InfoGreen , game_font );
		end else begin
			QuickTextRJ( 'N/A' , MyDest , InfoGreen , game_font );
		end;
	end;
var
	MyDest: TSDL_Rect;
	MyText: PSDL_Surface;
	msg: String;
	SS: SensibleSpritePtr;
begin
	{ Set the clip rectangle. }
	SDL_SetClipRect( Game_Screen , @Z );

	{ Draw the picture in the upper-left part of the zone. }
	MyDest.X := Z.X;
	MyDest.Y := Z.Y;
	msg := SAttValue( NPC^.SA , 'SDL_COLORS' );
	SS := LocateSprite( InfoImageName( NPC ) , msg , 100 , 150 );
	DrawSprite( SS , MyDest , 0 );

	{ Display the brief stats based on gear type. }
	{ Calculate the brief stats window area. }
	MyDest.X := Z.X + 100;
	MyDest.Y := Z.Y;
	MyDest.W := Z.W - 100;
	MyDest.H := 150;
	PersonaStats( MyDest );

	MyDest.X := Z.X;
	MyDest.Y := Z.Y + 155;

	{ Display the JobAgeGender description. }
	msg := JobAgeGenderDesc( NPC );
	if msg <> '' then begin
		MyText := PrettyPrint( msg , Z.W , InfoGreen , True );
		if MyText <> Nil then begin
			SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
			MyDest.Y := MyDest.Y + MyText^.H + 10;
			SDL_FreeSurface( MyText );
		end;
	end;

	{ Display the biography. }
	if MyDest.Y < ( Z.Y + Z.H ) then begin
		MyDest.W := Z.W;
		MyDest.H := Z.H + Z.Y - MyDest.Y - 5;
		GameMsg( SAttValue( NPC^.SA , 'BIO' ) , MyDest , InfoGreen );
	end;

	{ Restore the clip zone. }
	SDL_SetClipRect( Game_Screen , Nil );
end;

initialization
	Interact_Sprite := LocateSprite( Interact_Sprite_Name , 4 , 16 );
	Module_Sprite := LocateSprite( Module_Sprite_Name , 16 , 16 );
	PropStatus_Sprite := LocateSprite( PropStatus_Sprite_Name , 32 , 32 );
	Backdrop_Sprite := LocateSprite( Backdrop_Sprite_Name , 100 , 150 );
	Altimeter_Sprite := LocateSprite( Altimeter_Sprite_Name , 26 , 65 );
	Speedometer_Sprite := LocateSprite( Speedometer_Sprite_Name , 26 , 65 );
	StatusFX_Sprite := LocateSprite( StatusFX_Sprite_Name , 10 , 12 );
	OtherFX_Sprite := LocateSprite( OtherFX_Sprite_Name , 10 , 12 );

	Concert_Mob_Sprite := LocateSprite( 'mini_audience.png' , 100 , 60 );
	Concert_Mood_Sprite := LocateSprite( 'mini_mood.png' , 16 , 16 );

end.
