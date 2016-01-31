unit vidinfo;
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

uses locale,gears,vidgfx,minitype;

Procedure DisplayModelStatus( GB: GameBoardPtr; M: GearPtr; Z: VGFX_Zone );
Procedure QuickModelStatus( GB: GameBoardPtr; M: GearPtr );

Procedure NPCPersonalInfo( NPC: GearPtr; Z: VGFX_Zone );

Procedure DoMonologueDisplay( GB: GameBoardPtr; NPC: GearPtr; msg: String );
Procedure DisplayInteractStatus( GB: GameBoardPtr; NPC: GearPtr; React,Endurance: Integer );

Procedure CharacterDisplay( PC: GearPtr; GB: GameBoardPtr );
Procedure InjuryViewer( PC: GearPtr; redraw: RedrawProcedureType );

Procedure BrowserInterfaceInfo( GB: GameBoardPtr; Part: GearPtr; Z: VGFX_Zone );
Procedure BrowserInterfaceMystery( Part: GearPtr; Z: VGFX_Zone );

Procedure ArenaTeamInfo( Source: GearPtr; Z: VGFX_Zone );
Procedure TacticsTimeInfo( GB: GameBoardPtr );


Procedure ConcertStatus( PC: GearPtr; AL: AudienceList );

Procedure PersonadexInfo( NPC,HomeTown: GearPtr; Z: VGFX_Zone );


implementation

uses 	video,ghweapon,ghchars,ability,ghmodule,gearutil,description,
	movement,texutil,ui4gh,narration;

const
	SX_Char: Array [1..Num_Status_FX] of Char = (
		'P','B','R','S','H',
		'V','T','D','R','P',
		'A','G','L','N','Z',
		'X','S','R','S','I',
		'@','@','@','@','@',
		'!','?','D','B'
	);
	SX_Color: Array [1..Num_Status_FX] of Byte = (
		Magenta, LightRed, LightGreen, Magenta, Yellow,
		Cyan, Cyan, Cyan, Cyan, Cyan,
		Cyan, Cyan, Cyan, Cyan, Cyan,
		Cyan, Cyan, Red, Yellow, Magenta,
		Red, Red, Red, Red, Red,
		Red, Magenta, LightRed, DarkGray
	);


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

Function StatusColor( Full , Current: LongInt ): Byte;
	{ Given a part's Full and Current hit ratings, decide on a good status color. }
begin
	if Full = Current then StatusColor := LightGreen
	else if Current > ( Full div 2 ) then StatusColor := Green
	else if Current > ( Full div 4 ) then StatusColor := Yellow
	else if Current > ( Full div 8 ) then StatusColor := LightRed
	else if Current > 0 then StatusColor := Red
	else StatusColor := DarkGray;
end;

Function EnduranceColor( Full , Current: LongInt ): Byte;
	{ Choose colour to show remaining endurance (Stamina or Mental points)}
begin
        { This is absolute rather than relative. }
	if Full = Current then EnduranceColor := LightGreen
	else if Current > 5 then EnduranceColor := Green
	else if Current > 0 then EnduranceColor := Yellow
	else EnduranceColor := LightRed;
end;

Function HitsColor( Part: GearPtr ): LongInt;
	{ Decide upon a nice color to represent the hits of this part. }
begin
	if PartActive( Part ) then
		HitsColor := StatusColor( GearMaxDamage( Part ) , GearCurrentDamage( Part ) )
	else
		HitsColor := StatusColor( 100 , 0 );
end;

Function ArmorColor( Part: GearPtr ): LongInt;
	{ Decide upon a nice color to represent the armor of this part. }
begin
	ArmorColor := StatusColor( MaxTArmor( Part ) , CurrentTArmor( Part ) );
end;

Function ArmorDamageColor( Part: GearPtr ): LongInt;
	{ Decide upon a nice color to represent the armor of this part. }
var
	MA,CA: LongInt;	{ Max Armor, Current Armor }
begin
	MA := MaxTArmor( Part );
	CA := CurrentTArmor( Part );

	if MA = 0 then begin
		ArmorDamageColor := Magenta;
	end else if ( CA >= ( MA * 3 div 4 ) ) then begin
		ArmorDamageColor := Black;
	end else if ( CA > MA div 4 ) then begin
		ArmorDamageColor := Blue;
	end else begin
		ArmorDamageColor := LightGray;
	end;
end;

Procedure ShowStatus( Part: GearPtr; OX,OY: Integer );
	{ Display all this part's status conditions. }
	{ The status display starts at OX,OY and proceeds to the right until exiting the clip zone. }
	Procedure DrawStatusGlyph( Img: Char; C: Byte );
	begin
		DrawGlyph( Img , OX , OY , C , Black );
		Inc( OX );
	end;
var
	T: LongInt;
begin
	{ Show the character's status conditions. }

	{ Display whether or not the mecha is hidden. }
	if ( Part^.Parent = Nil ) and IsHidden( Part ) then begin
		DrawStatusGlyph( 'S' , DarkGray );
	end;

	{ Hunger and morale come next. }
	if Part^.G = GG_Character then begin
		T := NAttValue( Part^.NA , NAG_Condition , NAS_Hunger ) - Hunger_Penalty_Starts;
		if T > ( NumGearStats * 3 ) then begin
			DrawStatusGlyph( 'H' , LightRed );
		end else if T > ( NumGearStats * 2 ) then begin
			DrawStatusGlyph( 'H' , Yellow );
		end else if T > 0 then begin
			DrawStatusGlyph( 'H' , Green );
		end;

		T := NAttValue( Part^.NA , NAG_Condition , NAS_MoraleDamage );
		if T < -20 then begin
			DrawStatusGlyph( '+' , LightGreen );
		end else if T > ( 65 ) then begin
			DrawStatusGlyph( '-' , LightRed );
		end else if T > ( 40 ) then begin
			DrawStatusGlyph( '-' , Yellow );
		end else if T > 20 then begin
			DrawStatusGlyph( '-' , Green );
		end;

	end else if Part^.G = GG_Mecha then begin
		{ Mecha may be overloaded. }
		T := NAttValue( Part^.NA , NAG_Condition , NAS_PowerSpent );;
		if T > 10 then begin
			DrawStatusGlyph( 'O' , LightRed );
		end else if T > 10 then begin
			DrawStatusGlyph( 'O' , Yellow );
		end else if T > 0 then begin
			DrawStatusGlyph( 'O' , Blue );
		end;
	end;

	for t := 1 to Num_Status_FX do begin
		if NAttValue( Part^.NA , NAG_StatusEffect , T ) <> 0 then begin
			DrawStatusGlyph( SX_Char[ T ] , SX_Color[ T ] );
		end;
	end;

	if NAttValue( Part^.NA , NAG_EpisodeData , NAS_Ransacked ) = 1
	then DrawStatusGlyph( '$' , DarkGray );
end;

Procedure DisplayModules( Mek: GearPtr; X0,Y0: Integer );
	{ Draw a lovely little diagram detailing this mek's modules. }
	{ X0 is the center of the display, Y0 is the top of the display. }
var
	N: Integer;
	MD: GearPtr;
	Flayed, Gutted : Boolean;
	Procedure AddPartsToDiagram( GS: Integer );
		{ Add parts to the status diagram whose gear S value }
		{ is equal to the provided number. }
	var
		X: Integer;
		FG, BG: Byte;
	begin
		MD := Mek^.SubCom;
		while ( MD <> Nil ) do begin
			if ( MD^.G = GG_Module ) and ( MD^.S = GS ) then begin

				FG := HitsColor( MD );
				BG := ArmorDamageColor( MD );
				
				if (FG = DarkGray) And (BG <> Black)
				    then FG := Black;

				if Flayed Or (Gutted And (GS = GS_Body)) 
				then begin
				    if Gutted
				    then FG := White
				    else FG := LightMagenta;
				    BG := Red;
				end;


				if Odd( N ) then X := X0 - ( N div 2 ) - 1
				else X := X0 + ( N div 2 );
				Inc( N );
				Case GS of
					GS_Head:	DrawGlyph( 'o' , X , Y0 , FG , BG );
					GS_Turret:	DrawGlyph('=' , X , Y0 , FG , BG );
					GS_Storage:	DrawGlyph('x' , X , Y0 , FG , BG );
					GS_Body:	DrawGlyph('B' , X , Y0 , FG , BG );
					GS_Arm:		DrawGlyph('+' , X , Y0 , FG , BG );
					GS_Wing:	DrawGlyph('W' , X , Y0 , FG , BG );
					GS_Tail:	DrawGlyph('t' , X , Y0 , FG , BG );
					GS_Leg:		DrawGlyph('l' , X , Y0 , FG , BG );
				end;
			end;
			MD := MD^.Next;
		end;
	end;

begin
	if Mek^.G = GG_Prop then begin
		DrawGlyph( '@' , X0 , Y0 + 1 , HitsColor( Mek ) , ArmorDamageColor( Mek ) );
	end else begin
		{ this "if" is just a shortcut }
		if GearOperational(Mek)
		then begin
		    Gutted := False;
		    Flayed := False;             
		end
		else begin
		    Gutted := (NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Gutted) = 1);
		    Flayed := (NAttValue( Mek^.NA , NAG_EpisodeData , NAS_Flayed) = 1);
		end;

		{ Draw the status diagram for this mek. }
		{ Line One - Heads, Turrets, Storage }
		N := 0;
		AddPartsToDiagram( GS_Head );
		AddPartsToDiagram( GS_Turret );
		if N < 1 then N := 1;	{ Want storage to either side of body. }
		AddPartsToDiagram( GS_Storage );
		Inc( Y0 );

		{ Line Two - Torso, Arms, Wings }
		N := 0;
		AddPartsToDiagram( GS_Body );
		AddPartsToDiagram( GS_Arm );
		AddPartsToDiagram( GS_Wing );
		Inc( Y0 );

		{ Line Three - Tail, Legs }
		N := 0;
		AddPartsToDiagram( GS_Tail );
		if N < 1 then N := 1;	{ Want legs to either side of body; tail in middle. }
		AddPartsToDiagram( GS_Leg );
		Inc( Y0 );
	end;

	{ Restore background color to black. }
	TextBackground( Black );
end;

Procedure DisplayMoveStatus( GB: GameBoardPtr; Part: GearPtr; CX,CY: Integer );
	{ Display the movement compass centered on CX,CY. }
var
	D,Z: Integer;
begin
	D := NAttValue( Part^.NA , NAG_Location , NAS_D );
	Z := MekAltitude( gb , Part );
	if Z >= 0 then begin
		TextColor( NeutralGrey );
		TextOut( CX , CY , BStr( Z ) );
	end else begin
		TextColor( Blue );
		TextOut( CX , CY , BStr( Abs( Z ) ) );
	end;

	DrawGlyph( '+' , CX + AngDir[D,1] , CY + AngDir[D,2] , White , Black );
	DrawGlyph( '=' , CX - AngDir[D,1] , CY - AngDir[D,2] , DarkGray , Black );

	{ Speedometer. }
	if Speedometer( GB^.Scene , Part ) > 0 then begin
		if NAttValue( Part^.NA , NAG_Action , NAS_MoveAction ) = NAV_FullSPeed then begin
			DrawGlyph( 'G' , CX - 2 , CY - 1 , LightCyan , Black );
		end else begin
			DrawGlyph( 'G' , CX - 2 , CY - 1 , Cyan , Black );
		end;

		DrawGlyph( 'S' , CX - 2 , CY     , DarkGray , Black );
	end else begin
		DrawGlyph( 'G' , CX - 2 , CY - 1 , DarkGray , Black );
		if CurrentMoveRate( GB^.Scene , Part ) > 0 then begin
			DrawGlyph( 'S' , CX - 2 , CY     , Cyan , Black );
		end else begin
			DrawGlyph( 'S' , CX - 2 , CY     , DarkGray , Black );
		end;
	end;
end;

Procedure CharacterHPSPMP( M: GearPtr; X0,Y0: Integer );
	{ Display the HP, SP, and MP for this model. }
var
	CurP,MaxP: Integer;
	msg: String;
begin
	TextColor( LightGray );
	TextOut( X0 , Y0 , 'HP:' );
	TextOut( X0 , Y0 + 1 , 'SP:' );
	TextOut( X0 , Y0 + 2 , 'MP:' );

	CurP := GearCurrentDamage( M );
	MaxP := GearMaxDamage( M );
	msg := BStr( CurP );
	TextColor( StatusColor( MaxP , CurP ) );
	TextOut( X0 + 7 - Length( msg ) , Y0 , msg );

	CurP := CurrentStamina( M );
	MaxP := CharStamina( M );
	msg := BStr( CurP );
	TextColor( EnduranceColor( MaxP , CurP ) );
	TextOut( X0 + 7 - Length( msg ) , Y0 + 1 , msg );

	CurP := CurrentMental( M );
	MaxP := CharMental( M );
	msg := BStr( CurP );
	TextColor( EnduranceColor( MaxP , CurP ) );
	TextOut( X0 + 7 - Length( msg ) , Y0 + 2 , msg );
end;

Procedure CharStatDisplay( M: GearPtr; X0,Y0: Integer );
	{ Display the stats for this character. }
var
	T,S: Integer;
begin
	for t := 1 to 4 do begin
		TextColor( LightGray );
		TextOut( X0 + ( T - 1 ) * 6 , Y0 + 0 , MsgString( 'STATABRV_' + BStr( t ) ) );
		TextOut( X0 + ( T - 1 ) * 6 , Y0 + 1 , MsgString( 'STATABRV_' + BStr( t + 4 ) ) );

		S := CSTat( M , T );
		if S > M^.Stat[ T ] then TextColor( LightGreen )
		else if S < M^.Stat[ T ] then TextColor( LightRed )
		else TextColor( Green );
		TextOut( X0 + ( T - 1 ) * 6 + 3 , Y0 + 0 , BStr( S ) );

		S := CSTat( M , T + 4 );
		if S > M^.Stat[ T + 4 ] then TextColor( LightGreen )
		else if S < M^.Stat[ T + 4 ] then TextColor( LightRed )
		else TextColor( Green );
		TextOut( X0 + ( T - 1 ) * 6 + 3 , Y0 + 1 , BStr( S ) );
	end;
end;

Procedure MechaMVTRSE( M: GearPtr; X0,Y0: Integer );
	{ Display the MV, TR, and SE for this model. }
var
	msg: String;
begin
	TextColor( LightGray );
	TextOut( X0 , Y0 , 'MV:' );
	TextOut( X0 , Y0 + 1 , 'TR:' );
	TextOut( X0 , Y0 + 2 , 'SE:' );

	TextColor( LightGreen );
	msg := SgnStr( MechaManeuver( M ) );
	TextOut( X0 + 7 - Length( msg ) , Y0 ,     msg );
	msg := SgnStr( MechaTargeting( M ) );
	TextOut( X0 + 7 - Length( msg ) , Y0 + 1 , msg );
	msg := SgnStr( MechaSensorRating( M ) );
	TextOut( X0 + 7 - Length( msg ) , Y0 + 2 , msg );
end;

Procedure DisplayModelStatus( GB: GameBoardPtr; M: GearPtr; Z: VGFX_Zone );
	{ Display the status for this model in the upper status area. }
var
	MyDest: VGFX_Rect;
	msg: String;
begin
	MyDest := ZoneToRect( Z );
	InfoBox( ZONE_Info );
	ClipZone( MyDest );

	TextColor( White );
	msg := MechaPilotName( M );
	TextOut( MyDest.X + ( MyDest.W - Length( msg ) ) div 2 , MyDest.Y , msg );
	DisplayMoveStatus( GB , M , MyDest.X + 3 , MyDest.Y + 2 );
	DisplayModules( M , MyDest.X + MyDest.W div 2 , MyDest.Y + 1 );

	if M^.G = GG_Character then begin
		CharacterHPSPMP( M , MyDest.X + MyDest.W - 7 , MyDest.Y + 1 );
		CharStatDisplay( M , MyDest.X , MyDest.Y + 4 );
	end else if M^.G = GG_Mecha then begin
		MechaMVTRSE( M , MyDest.X + MyDest.W - 7 , MyDest.Y + 1 );
	end;

	ShowStatus( M , MyDest.X + 1 , MyDest.Y + MyDest.H - 1 );
	MaxClipZone;
end;

Procedure QuickModelStatus( GB: GameBoardPtr; M: GearPtr );
	{ Display the model status in the info area. }
begin
	DisplayModelStatus( GB , M , ZONE_Caption );
end;

Procedure NPCPersonalInfo( NPC: GearPtr; Z: VGFX_Zone );
	{ Display the name, job, age, and gender of the NPC. }
var
	R: VGFX_Rect;
begin
	R := ZoneToRect( Z );
	R.H := 1;
	CMessage( GearName( NPC ) , R , LightGreen );
	Inc( R.Y );
	CMessage( JobAgeGenderDesc( NPC ) , R , Green );
end;

Procedure DoMonologueDisplay( GB: GameBoardPtr; NPC: GearPtr; msg: String );
	{ Show the NPC's portrait, name, and description, as well as the message. }
var
	Z_Text: VGFX_Rect;
begin
	Z_Text := ZoneToRect( ZONE_MonologueText );

	InfoBox( ZONE_MonologueInfo );
	InfoBox( Z_Text );

	NPCPersonalInfo( NPC , ZONE_MonologueInfo );
	GameMsg( Msg , Z_Text , InfoHiLight );
end;

Procedure DisplayInteractStatus( GB: GameBoardPtr; NPC: GearPtr; React,Endurance: Integer );
	{ Display the interact status. }
var
	StatusRect: VGFX_Rect;
	msg: String;
	C: Byte;
	T: Integer;
begin
	NPCPersonalInfo( NPC , ZONE_InteractName );

	StatusRect := ZoneToRect( ZONE_InteractStatus );

	if React > 0 then begin
		msg := '';
		for T := 0 to ( React div 4 ) do msg := msg + '+';
		C := LightGreen;
	end else if React < 0 then begin
		msg := '';
		for T := 0 to ( Abs(React) div 4 ) do msg := msg + '-';
		C := LightRed;
	end else begin
		msg := '~~~';
		C := Yellow;
	end;
	TextColor( Green );
	TextOut( StatusRect.X , StatusRect.Y , '[:)]' );
	TextColor( C );
	TextOut( StatusRect.X + 4 , StatusRect.Y , msg );

	msg := '';
	if Endurance > 10 then Endurance := 10;
	for t := 1 to Endurance do msg := msg + '>';
	TextColor( Green );
	TextOut( StatusRect.X + StatusRect.W - 14 , StatusRect.Y , '[Zz]' );
	TextColor( LightGreen );
	TextOut( StatusRect.X + StatusRect.W - 10 , StatusRect.Y , msg );


end;

Procedure CharacterDisplay( PC: GearPtr; GB: GameBoardPtr );
	{ Display the character stats, background, etc. }
var
	MyDest: VGFX_Rect;
	msg: String;
	T,S,R,FID: LongInt;
	C: Byte;
	Mek: GearPtr;
begin
	{ Begin with one massive error check... }
	if PC = Nil then Exit;
	if PC^.G <> GG_Character then PC := LocatePilot( PC );
	if PC = Nil then Exit;

	{ Set up the display. }
	MyDest := ZoneToRect( ZONE_CharacterDisplay );
	InfoBox( ZONE_CharacterDisplay );
	ClipZone( MyDest );
	ClrZone( MyDest );

	{ Start by printing the character's name and AgeGenderJob line. }
	TextColor( White );
	msg := GearName( PC );
	TextOut( MyDest.X + MyDest.W div 2 - Length( msg ) div 2 , MyDest.Y , msg );

	TextColor( Green );
	msg := JobAgeGenderDesc( PC );
	TextOut( MyDest.X + MyDest.W div 2 - Length( msg ) div 2 , MyDest.Y + 1 , msg );

	{ Show the stats. }
	for t := 1 to 8 do begin
		TextColor( LightGray );
		TextOut( MyDest.X + 1 , MyDest.Y + 2 + T , MsgString( 'STATNAME_' + BStr( T ) ) );

		{ Find the adjusted stat value for this stat. }
		S := CStat( PC , T );
		R := ( S + 2 ) div 3;
		if R > 7 then R := 7;

		{ Determine an appropriate color for the stat, depending }
		{ on whether its adjusted value is higher or lower than }
		{ the basic value. }
		if S > PC^.Stat[ T ] then C := LighTGreen
		else if S < PC^.Stat[ T ] then C := LightRed
		else C := Green;

		TextColor( C );
		msg := BStr( S );
		TextOut( MyDest.X + 14 - Length( msg ) , MyDest.Y + 2 + T , msg );
		TextOut( MyDest.X + 15 , MyDest.Y + 2 + T , MsgString( 'STATRANK' + BStr( R ) ) );
	end;

	{ Output the PC's total XP and free XP. }
	TextColor( LightGray );
	TextOut( MyDest.X + 25 , MyDest.Y + 3 , MsgString( 'INFO_XP' ) );
	S := NAttVAlue( PC^.NA , NAG_Experience , NAS_TotalXP );
	msg := BStr( S );
	TextColor( Green );
	TextOut( MyDest.X + MyDest.W - 1 - Length( msg ) , MyDest.Y + 3 , msg );

	TextColor( LightGray );
	TextOut( MyDest.X + 25 , MyDest.Y + 4 , MsgString( 'INFO_XPLeft' ) );
	S := S - NAttVAlue( PC^.NA , NAG_Experience , NAS_SpentXP );
	msg := BStr( S );
	TextColor( Green );
	TextOut( MyDest.X + MyDest.W - 1 - Length( msg ) , MyDest.Y + 4 , msg );

	TextColor( LightGray );
	TextOut( MyDest.X + 25 , MyDest.Y + 5 , MsgString( 'INFO_Credits' ) );
	S := NAttVAlue( PC^.NA , NAG_Experience , NAS_Credits );
	msg := '$' + BStr( S );
	TextColor( Green );
	TextOut( MyDest.X + MyDest.W - 1 - Length( msg ) , MyDest.Y + 5 , msg );

	{ Print info on the PC's mecha, if appropriate. }
	if ( GB <> Nil ) then begin
		Mek := FindPilotsMecha( GB^.Meks , PC );
		if Mek <> Nil then begin
			TextColor( LightGray );
			TextOut( MyDest.X + 25 , MyDest.Y + 7 , MsgString( 'INFO_MekSelect' ) );

			msg := FullGearName( Mek );
			TextColor( Green );
			TextOut( MyDest.X + MyDest.W - 1 - Length( msg ) , MyDest.Y + 8 , msg );
		end;
	end;

	{ Print info on the PC's faction, if appropriate. }
	FID := NAttValue( PC^.NA , NAG_Personal , NAS_FactionID );
	if ( FID <> 0 ) and ( GB <> Nil ) and ( GB^.Scene <> Nil ) then begin
		Mek := SeekFaction( GB^.Scene , FID );
		if Mek <> Nil then begin
			TextColor( LightGray );
			TextOut( MyDest.X + 25 , MyDest.Y + 9 , MsgString( 'INFO_Faction' ) );

			msg := GearName( Mek );
			TextColor( Green );
			TextOut( MyDest.X + MyDest.W - 1 - Length( msg ) , MyDest.Y + 10 , msg );
		end;
	end;

	{ Print the biographical information. }
	msg := SAttValue( PC^.SA , 'BIO1' );
	if msg <> '' then begin
		MyDest.X := MyDest.X + 2;
		MyDest.W := MyDest.W - 4;
		MyDest.Y := MyDest.Y + 11;
		MyDest.H := MyDest.H - 11;
		GameMsg( msg , MyDest , Green );
	end;


	MaxClipZone;
end;

Procedure InjuryViewer( PC: GearPtr; redraw: RedrawProcedureType );
	{ Display a brief listing of all the PC's major health concerns. }
	{ Display a brief listing of all the PC's major health concerns. }
var
	YPos: Integer;
	MyDest: VGFX_Rect;
	Procedure WriteStatus( msg: String; C: Byte );
	begin
		TextColor( C );
		TextOut( MyDest.X , YPos , msg );
		Inc( YPos );
	end;
	Procedure ShowSubInjuries( Part: GearPtr );
		{ Show the injuries of this part, and also for its subcoms. }
	var
		MD,CD: Integer;
	begin
		while Part <> Nil do begin
			MD := GearMaxDamage( Part );
			CD := GearCurrentDamage( Part );
			if not PartActive( Part ) then begin
				WriteStatus( GearName( Part ) + MsgString( 'INFO_IsDisabled' ) , StatusColor( MD , CD ) );
			end else if CD < MD then begin
				WriteStatus( GearName( Part ) + MsgString( 'INFO_IsHurt' ) , StatusColor( MD , CD ) );
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

		{ Show exhaustion status first. }
		SP := CurrentStamina( PC );
		MP := CurrentMental( PC );
		if ( SP = 0 ) and ( MP = 0 ) then begin
			WriteStatus( MsgString( 'INFO_FullExhausted' ) , Red );
		end else if ( SP = 0 ) or ( MP = 0 ) then begin
			WriteStatus( MsgString( 'INFO_PartExhausted' ) , LightRed );
		end;

		{ Hunger next. }
		T := NAttValue( PC^.NA , NAG_Condition , NAS_Hunger ) - Hunger_Penalty_Starts;
		if T > ( NumGearStats * 3 ) then begin
			WriteStatus( MsgString( 'INFO_ExtremeHunger' ) , Red );
		end else if T > ( NumGearStats * 2 ) then begin
			WriteStatus( MsgString( 'INFO_Hunger' ) , LightRed );
		end else if T > 0 then begin
			WriteStatus( MsgString( 'INFO_MildHunger' ) , Yellow );
		end;

		{ Low morale next. }
		T := NAttValue( PC^.NA , NAG_Condition , NAS_MoraleDamage );
		if T > 65 then begin
			WriteStatus( MsgString( 'INFO_ExtremeMorale' ) , Red );
		end else if T > 40 then begin
			WriteStatus( MsgString( 'INFO_Morale' ) , LightRed );
		end else if T > 20 then begin
			WriteStatus( MsgString( 'INFO_MildMorale' ) , Yellow );
		end;


		for t := 1 to Num_Status_FX do begin
			if NAttValue( PC^.NA , NAG_StatusEffect , T ) <> 0 then begin
				WriteStatus( MsgString( 'INFO_Status' + BStr( T ) ) , Red );
			end;
		end;

		{ Show limb injuries. }
		ShowSubInjuries( PC^.SubCom );
	end;
var
	msg: String;
begin
	MyDest := ZoneToRect( ZONE_CharacterDisplay );
	Redraw;
	InfoBox( MyDest );
	ClrZone( MyDest );
	ClipZone( MyDest );

	msg := MsgString( 'INFO_InjuriesTitle' );
	TextColor( StdWhite );
	TextOut( MyDest.X + MyDest.W div 2 - Length( msg ) div 2 , MyDest.Y , msg );

	YPos := MyDest.Y + 1;
	RealInjuryDisplay;
	MaxClipZone;
	DoFlip;
	MoreKey;
end;

Procedure BrowserInterfaceInfo( GB: GameBoardPtr; Part: GearPtr; Z: VGFX_Zone );
	{ Display the basic information for this gear. }
var
	MyDest: VGFX_Rect;
	msg: String;
	X,YEnd,N: Integer;
	Cost: LongInt;
begin
	MyDest := ZoneToRect( Z );
	ClrZone( MyDest );
	msg := GearName( Part );
	TextColor( InfoHilight );
	TextOut( MyDest.X + MyDest.W div 2 - Length( msg ) div 2 , MyDest.Y , msg );

	YEnd := MyDest.Y + MyDest.H - 1;

	{ Display the part's armor rating. }
	if IsMasterGear( Part ) then begin
		N := PercentDamaged( Part );
		msg := BStr( N ) + '%';
		TextColor( StatusColor( 100 , N ) );
		TextOut( MyDest.X , MyDest.Y + 1 , msg );
		X := MyDest.X + 1;
	end else begin
		N := GearCurrentArmor( Part );
		if N > 0 then msg := '[' + BStr( N )
		else msg := '[-';
		msg := msg + '] ';
		TextColor( ArmorColor( Part ) );
		TextOut( MyDest.X , MyDest.Y + 1 , msg );
		X := MyDest.X + Length( msg ) + 1;

		{ Display the part's damage rating. }
		N := GearCurrentDamage( Part );
		if N > 0 then msg := BStr( N )
		else msg := '-';
		TextColor( HitsColor( Part ) );
		TextOut( X , MyDest.Y + 1 , msg );
	end;

	textColor( DarkGray );
	TextOut( X + Length( msg ) , MyDest.Y + 1 , 'DP' );

	{ Display the part's mass. }
	N := ( GearMass( Part ) + 1 ) div 2;
	if N > 0 then begin
		msg := MassString( Part );
		TextOut( MyDest.X + MyDest.W - Length( msg ) , MyDest.Y + 1 , msg );
	end;

	{ Display the cost. }
	if Part^.G = GG_Mecha then begin
		Cost := GearValue( Part );
		if Cost > 0 then begin
			msg := 'PV:' + BStr( Cost );
			TextOut( MyDest.X  , MyDest.Y + 2 , msg );
		end;
	end else begin
		Cost := GearCost( Part );
		if ( Cost > 0 ) then begin
			msg := '$' + BStr( Cost );
			TextOut( MyDest.X  , MyDest.Y + 2 , msg );
		end;
	end;
	{ Display the spaces. }
	if not IsMasterGear( Part ) then begin
		if ( Part^.G = GG_Module ) or ( Part^.G = GG_ExArmor ) or ( Part^.G = GG_Shield ) or ( Part^.G = GG_Harness ) then begin
			msg := BStr( SubComComplexity( Part ) ) + '/' + BStr( ComponentComplexity( Part ) ) + ' slots used';
			TextOut( MyDest.X + MyDest.W - Length( msg )  , MyDest.Y + 2 , msg );
		end else begin
			msg := BStr( ComponentComplexity( Part ) ) + ' slots';
			TextOut( MyDest.X + MyDest.W - Length( msg )  , MyDest.Y + 2 , msg );
		end;
	end;
	{ Next, the extended description and the regular description. }
	{ Create the zone for this text. }
	MyDest.Y := MyDest.Y + 3;
	MyDest.H := MyDest.H - 3;

	{ See if there is an extended description. }
	msg := ExtendedDescription( GB , Part );
	if msg <> '' then begin
		GameMsg( msg , MyDest , Green );
		MyDest.Y := vg_y + 2;
		MyDest.H := YEnd - MyDest.Y + 1;
	end;

	GameMsg( SAttValue( Part^.SA , 'DESC' ) , MyDest , Green );
end;

Procedure BrowserInterfaceMystery( Part: GearPtr; Z: VGFX_Zone );
	{ This gear is a mystery. Display its name, and that's about it. }
var
	MyDest: VGFX_Rect;
	msg: String;
begin
	MyDest := ZoneToRect( Z );
	ClrZone( MyDest );
	msg := GearName( Part );
	TextColor( InfoHilight );
	TextOut( MyDest.X + MyDest.W div 2 - Length( msg ) div 2 , MyDest.Y , msg );
end;



Procedure ArenaTeamInfo( Source: GearPtr; Z: VGFX_Zone );
	{ Print the important information for this team. }
var
	MyDest: VGFX_Rect;
	msg: String;
	Fac: GearPtr;
	Renown: Integer;
begin
	MyDest := ZoneToRect( Z );
	TextColor( White );
	msg := GearName( Source );
	TextOut( MyDest.X + ( MyDest.W - Length( msg ) ) div 2 , MyDest.Y , msg );
	TextColor( LightGreen );
	msg := '$' + BStr( NAttValue( Source^.NA , NAG_Experience , NAS_Credits ) );
	TextOut( MyDest.X + ( MyDest.W - Length( msg ) ) div 2 , MyDest.Y + 1 , msg );
	Fac := SeekFaction( Source , NAttValue( Source^.NA , NAG_Personal , NAS_FactionID ) );
	if Fac <> Nil then begin
		TextColor( LightGray );
		msg := GearName( Fac );
		TextOut( MyDest.X + ( MyDest.W - Length( msg ) ) div 2 , MyDest.Y + 2 , msg );
	end;
	Renown := NAttValue( Source^.NA , NAG_CharDescription , NAS_Renowned );
	msg := RenownDesc( Renown );
	TextColor( Green );
	TextOut( MyDest.X + ( MyDest.W - Length( msg ) ) div 2 , MyDest.Y + 3 , msg );
end;

Procedure TacticsTimeInfo( GB: GameBoardPtr );
	{ Tell how much free time the currently active model has. }
var
	TimeLeft,W,T: LongInt;
	MyDest: VGFX_Rect;
begin
	TimeLeft := TacticsRoundLength - ( GB^.ComTime - NAttValue( GB^.Scene^.NA , NAG_SceneData , NAS_TacticsTurnStart ) );
	MyDest := ZoneToRect( ZONE_Clock );

	TextColor( White );
	TextOut( MyDest.X , MyDest.Y , 'TIME:' );

	W := (( MyDest.W - 5 ) * TimeLeft ) div TacticsRoundLength;
	for t := 1 to W do begin
		DrawGlyph( '=' , MyDest.X + T + 4 , MyDest.Y , LightGreen , Black );
	end;
end;


Procedure ConcertStatus( PC: GearPtr; AL: AudienceList );
	{ Display the status information for the concert minigame. }
Const
	Mood_Glyph: Array [0..Num_Audience_Moods] of Char = (
	'-','-','-','~','+','+','+'
	);
	Mood_Color: Array [0..Num_Audience_Moods] of Byte = (
	DarkGray, Red, Yellow, Yellow, Yellow, Green, LightGreen
	);
	Trait_Color: Array [0..2] of Byte = (
	LightBlue, LightRed, Yellow
	);
var
	MyDest: VGFX_Rect;
	T: Integer;
begin
	MyDest := ZoneToRect( ZONE_ConcertAudience );
	CMessage( '=AUDIENCE=' , ZONE_ConcertAudience , DarkGray );
	for t := 1 to MaxAudienceSize do begin
		if AL[t].Mood <> MOOD_Absent then begin
			DrawGlyph( Mood_Glyph[AL[t].Mood] , MyDest.X + T - 1, MyDest.Y , Mood_Color[AL[t].Mood] , Black );
			if AL[t].Mood <> MOOD_WalkOut then begin
				DrawGlyph( '@' , MyDest.X + T - 1, MyDest.Y + 1 , Trait_Color[AL[t].Trait] , Black );
			end;
		end;
	end;
end;

Procedure PersonadexInfo( NPC,HomeTown: GearPtr; Z: VGFX_Zone );
	{ Display personality info about this NPC. }
var
	MyDest: VGFX_Rect;
	msg: String;
begin
	MyDest := ZoneToRect( Z );
	ClipZone( MyDest );

	TextColor( White );
	TextOut( MyDest.X , MyDest.Y , MsgString( 'PDEX_Attitude' ) + ':'  );
	TextOut( MyDest.X , MyDest.Y + 1 , MsgString( 'PDEX_Motivation' ) + ':'  );
	TextOut( MyDest.X , MyDest.Y + 2 , MsgString( 'PDEX_Location' ) + ':'  );
	TextOut( MyDest.X , MyDest.Y + 3 , MsgString( 'PDEX_SkillRank' ) + ':'  );

	TextColor( LightGreen );
	msg := MsgString( 'Attitude_' + BStr( NAttValue( NPC^.NA , NAG_XXRan , NAS_XXChar_Attitude ) ) );
	TextOut( MyDest.X + MyDest.W - Length( Msg ) , MyDest.Y , msg );

	msg := MsgString( 'Motivation_' + BStr( NAttValue( NPC^.NA , NAG_XXRan , NAS_XXChar_Motivation ) ) );
	TextOut( MyDest.X + MyDest.W - Length( Msg ) , MyDest.Y + 1 , msg );

	if HomeTown = Nil then msg := '???'
	else msg := GearName( HomeTown );
	TextOut( MyDest.X + MyDest.W - Length( Msg ) , MyDest.Y + 2 , msg );

	if IsACombatant( NPC ) then msg := RenownDesc( NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned ) )
	else msg := 'N/A';
	TextOut( MyDest.X + MyDest.W - Length( Msg ) , MyDest.Y + 3 , msg );

	MyDest.Y := MyDest.Y + 4;
	MyDest.H := MyDest.H - 4;
	GameMsg( SAttValue( NPC^.SA , 'BIO' ) , MyDest , LightGray );

	MaxClipZone;
end;

end.
