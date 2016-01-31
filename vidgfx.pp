unit vidgfx;
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

uses Video,Keyboard,ui4gh,texutil,gears;

Type
	vgfx_rect = Record
		X,Y,W,H: Byte;
	end;

	vgfx_zone = Record
		X_Anchor,X_Justify,W: Integer;
		Y_Anchor,Y_Justify,H: Integer;
	end;


	RedrawProcedureType = Procedure;


Const
	vg_Pen: Byte = 0;	{ Will be initialied to proper value below. }

	{ The real values for ZONE_Console get set at initialization below. }
	ZONE_Console: vgfx_rect = ( x:1; y:21; w:80; h:5 );

	Console_History_Length = 240;
	NormMode: TVideoMode = ( Col: 80; Row: 25; Color: True );

	RightColumnWidth = 25;

	ANC_Low = 0;
	ANC_Mid = 1;
	ANC_High = 2;

	ZONE_CharGenMenu: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: -25; W: 24;
		Y_Anchor: ANC_Mid; Y_Justify: -3; H: 10;
	);
	ZONE_CharGenPrompt: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: -25; W: 24;
		Y_Anchor: ANC_Mid; Y_Justify: -10; H: 6;
	);
	ZONE_CharGenCaption: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: -25; W: 24;
		Y_Anchor: ANC_Mid; Y_Justify: 9; H: 2;
	);
	ZONE_CharGenDesc: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -37; W: 74;
		Y_Anchor: ANC_High; Y_Justify: -3; H: 3;
	);


	ZONE_Caption: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -8; W: 16;
		Y_Anchor: ANC_Low; Y_Justify: 3; H: 3;
	);

	ZONE_Info: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: -RightColumnWidth + 1; W: RightColumnWidth - 2;
		Y_Anchor: ANC_Mid; Y_Justify: -10; H: 7;
	);
	ZONE_Menu: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: -RightColumnWidth + 1; W: RightColumnWidth - 2;
		Y_Anchor: ANC_Mid; Y_Justify: -2; H: 10;
	);
	ZONE_Menu1: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: -RightColumnWidth + 1; W: RightColumnWidth - 2;
		Y_Anchor: ANC_Mid; Y_Justify: -2; H: 5;
	);
	ZONE_Menu2: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: -RightColumnWidth + 1; W: RightColumnWidth - 2;
		Y_Anchor: ANC_Mid; Y_Justify: 4; H: 4;
	);
	ZONE_SubCaption: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: -RightColumnWidth + 1; W: RightColumnWidth - 2;
		Y_Anchor: ANC_Mid; Y_Justify: 7; H: 1;
	);
	ZONE_Clock: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: -RightColumnWidth + 2; W: RightColumnWidth - 4;
		Y_Anchor: ANC_Mid; Y_Justify: 8; H: 1;
	);


	ZONE_GetItemMenu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -16; W: 32;
		Y_Anchor: ANC_Mid; Y_Justify: - 4; H: 8;
	);

	ZONE_ShopCaption: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -37; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify: - 9; H: 2;
	);
	ZONE_ShopMsg: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -37; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify: - 6; H:  6;
	);
	ZONE_ShopMenu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -37; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify:   1; H:  7;
	);

	ZONE_ItemsInfo: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify:  5; W: 33;
		Y_Anchor: ANC_Mid; Y_Justify: -9; H: 14;
	);
	ZONE_ItemsPCInfo: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify:  5; W: 33;
		Y_Anchor: ANC_Mid; Y_Justify:  6; H: 2;
	);

	ZONE_EqpMenu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -37; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify: - 6; H:  6;
	);
	ZONE_InvMenu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -37; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify:   1; H:  5;
	);
	ZONE_BackpackInstructions: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -37; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify: - 9; H: 2;
	);

	ZONE_FieldHQMenu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -37; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify: - 9; H: 15;
	);


	InteractAreaWidth = 75;
	Interact_X_Justify = -37;
	Interact_Y_Justify = -9;

	{ The name zone includes the JobAgeGender description. }
	ZONE_InteractName: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: Interact_X_Justify; W: InteractAreaWidth;
		Y_Anchor: ANC_Mid; Y_Justify: Interact_Y_Justify; H: 2;
	);
	ZONE_InteractStatus: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: Interact_X_Justify; W: InteractAreaWidth;
		Y_Anchor: ANC_Mid; Y_Justify: Interact_Y_Justify + 2; H: 1;
	);
	ZONE_InteractMsg: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: Interact_X_Justify; W: InteractAreaWidth;
		Y_Anchor: ANC_Mid; Y_Justify: Interact_Y_Justify + 3; H: 5;
	);
	ZONE_InteractMenu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: Interact_X_Justify; W: InteractAreaWidth;
		Y_Anchor: ANC_Mid; Y_Justify: Interact_Y_Justify + 8; H:  7;
	);

	{ *** INTERNAL USE ONLY *** }
	ZONE_InteractTotal: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: Interact_X_Justify; W: InteractAreaWidth;
		Y_Anchor: ANC_Mid; Y_Justify: Interact_Y_Justify; H: 15;
	);
	{ *** INTERNAL USE ONLY *** }

	ZONE_MemoText: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify: - 6; H: 8;
	);
	ZONE_MemoMenu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify:   3; H:  3;
	);

	{ The SelectArenaMission display zones: }
	ZONE_SAMText: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify:   0; H:  5;
	);
	ZONE_SAMMenu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify:  -6; H:  5;
	);

	ZONE_UsagePrompt: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify: - 8; H: 10;
	);
	ZONE_UsageMenu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify:   3; H:  7;
	);

	{ Note that in ASCII mode, RightInfo and LeftInfo aren't to the right and left, }
	{ but instead occupy the Menu1 and Menu2 zones. }
	ZONE_RightInfo: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: 1; W: 20;
		Y_Anchor: ANC_Low; Y_Justify:   3; H:  7;
	);
	ZONE_LeftInfo: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify: -21; W: 20;
		Y_Anchor: ANC_Low; Y_Justify:   3; H:  7;
	);

	ZONE_CharacterDisplay: vgfx_zone = (
		X_Anchor: ANC_Low; X_Justify: 1; W: 52;
		Y_Anchor: ANC_Low; Y_Justify: 1; H: 19;
	);

	ZONE_WorldMap: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -13; W: 25;
		Y_Anchor: ANC_Mid; Y_Justify: - 8; H: 15;
	);

	ZONE_MonologueInfo: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify: -8; H: 1
	);
	ZONE_MonologueText: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify: -6; H: 10
	);

	ZONE_ArenaPilotMenu: vgfx_zone = (
		X_Anchor: ANC_Low; X_Justify: 2; W: 20;
		Y_Anchor: ANC_Low; Y_Justify: 1; H: 15
	);
	ZONE_ArenaMechaMenu: vgfx_zone = (
		X_Anchor: ANC_Low; X_Justify: 23; W: 20;
		Y_Anchor: ANC_Low; Y_Justify: 1; H: 15
	);
	ZONE_ArenaInfo: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify:  -34; W: 33;
		Y_Anchor: ANC_Low; Y_Justify: 1; H: 10;
	);
	ZONE_PCStatus: vgfx_zone = (
		X_Anchor: ANC_High; X_Justify:  -34; W: 33;
		Y_Anchor: ANC_Low; Y_Justify: 12; H: 4;
	);

	ZONE_Dialog: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify:  -39; W: 80;
		Y_Anchor: ANC_Low; Y_Justify: 12; H: 3;
	);


	ZONE_ConcertAudience: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -30; W: 60;
		Y_Anchor: ANC_Mid; Y_Justify: -7; H: 2;
	);
	ZONE_ConcertCaption: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -30; W: 60;
		Y_Anchor: ANC_Mid; Y_Justify: -4; H: 4;
	);
	ZONE_ConcertMenu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -30; W: 60;
		Y_Anchor: ANC_Mid; Y_Justify: 1; H: 4;
	);
	ZONE_ConcertDesc: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -30; W: 60;
		Y_Anchor: ANC_Mid; Y_Justify: 6; H: 1;
	);

	ZONE_Title_Screen_Top: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -15; W: 30;
		Y_Anchor: ANC_Mid; Y_Justify: -10; H: 2;
	);
	ZONE_Title_Screen_Title: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -15; W: 30;
		Y_Anchor: ANC_Mid; Y_Justify: -10; H: 1;
	);
	ZONE_Title_Screen_Version: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -15; W: 30;
		Y_Anchor: ANC_Mid; Y_Justify: -9; H: 1;
	);
	ZONE_Title_Screen_Menu: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -15; W: 30;
		Y_Anchor: ANC_Mid; Y_Justify: -7; H: 15;
	);


{ *** STANDARD COLORS *** }
	StdBlack: Byte = Black;
	StdWhite: Byte = White;
	MenuItem: Byte = Cyan;
	MenuSelect: Byte = LightCyan;
	TerrainGreen: Byte = Green;
	PlayerBlue: Byte = LightBlue;
	AllyPurple: Byte = LightMagenta;
	EnemyRed: Byte = Red;
	NeutralGrey: Byte = LightGray;
	InfoGreen: Byte = Green;
	InfoHiLight: Byte = LightGreen;
	TextboxGrey: Byte = DarkGray;
	AttackColor: Byte = LightRed;
	NeutralBrown: Byte = Yellow;
	BorderBlue: Byte = Blue;
	MelodyYellow: Byte = Yellow;

{ STATE VARIABLES - USE WITH CAUTION }
{ External setting of these vars is not supported, but reading should }
{ be okay most of the time. }
	vg_FGColor: Byte = LightGray;
	vg_BGColor: Byte = Black;
	vg_X: Byte = 1;	{ Cursor Position. }
	vg_Y: Byte = 1;	{ Cursor Position. }
	vg_Window: vgfx_rect = ( x:1 ; y:1 ; w:80 ; h:25 );

Var
	Console_History: SAttPtr;


Procedure DoFlip;

Function RPGKey: Char;
Function IsMoreKey( A: Char ): Boolean;
Procedure MoreKey;


Procedure ClrZone( const Z: vgfx_Rect );
Procedure ClrScreen;

Procedure TextColor( C: Byte );
Procedure TextBackground( C: Byte );
Procedure TextOut(X,Y : Word;Const S : String);
Procedure ClipZone( Z: vgfx_rect );
Procedure MaxClipZone;
Function ZoneToRect( Z: VGFX_Zone ): VGFX_Rect;
Procedure DrawGlyph( img: Char; X,Y,FG,BG: Byte );

Procedure GameMSG( msg: string; Z: vgfx_rect; C: Byte );
Procedure GameMSG( msg: string; Z: vgfx_zone; C: Byte );
Procedure CMessage( const msg: String; Z: VGFX_Rect; C: Byte );
Procedure CMessage( const msg: String; Z: VGFX_Zone; C: Byte );

Procedure RedrawConsole;
Procedure DialogMSG(msg: string);

Function MoreHighFirstLine( LList: SAttPtr ): Integer;
Procedure MoreText( LList: SAttPtr; FirstLine: Integer );

Function GetStringFromUser( const Prompt: String; Redraw: RedrawProcedureType ): String;

Procedure SetupMemoDisplay;
Procedure DrawBPBorder;
Procedure SetupFHQDisplay;
Procedure DrawGetItemBorder;
Procedure SetupInteractDisplay( C: Byte );
Procedure SetupServicesDisplay;


Procedure InfoBox( MyDest: VGFX_Rect );
Procedure InfoBox( Z: VGFX_Zone );
Procedure ClockBorder;

Procedure SetupArenaDisplay;
Procedure SetupArenaMissionMenu;
Procedure SetupConcertDisplay;
Procedure SetupTitleScreenDisplay;


implementation

Procedure DoFlip;
	{ Update the screen. }
begin
	UpdateScreen( False );
end;

Function RawKey: Char;
	{Read a keypress from the keyboard. Convert it into a form}
	{that my other procedures would be willing to call useful.}
var
	getit: Char;
	TK: TKeyEvent;
begin
	TK := TranslateKeyEvent( GetKeyEvent );

	if GetKeyEventFlags( TK ) = kbASCII then begin
		getit := GetKeyEventChar( TK );
	end else if GetKeyEventFlags( TK ) = kbFnKey then begin
		case GetKeyEventCode( TK ) of
			kbdUp:		getit := KeyMap[ KMC_North ].KCode; {Up Cursor Key}
			kbdHome:	getit := KeyMap[ KMC_NorthWest ].KCode; {Home Cursor Key}
			kbdPgUp:	getit := KeyMap[ KMC_NorthEast ].KCode; {PageUp Cursor Key}
			kbdDown:	getit := KeyMap[ KMC_South ].KCode; {Down Cursor Key}
			kbdEnd:		getit := KeyMap[ KMC_SouthWest ].KCode; {End Cursor Key}
			kbdPgDn:	getit := KeyMap[ KMC_SouthEast ].KCode; {PageDown Cursor Key}
			kbdLeft:	getit := KeyMap[ KMC_West ].KCode; {Left Cursor Key}
			kbdRight:	getit := KeyMap[ KMC_East ].KCode; {Right Cursor Key}
		end;
	end else begin
		getit := ' ';
	end;

	RawKey := getit;
end;

Function RPGKey: Char;
	{ Basically, call RAWKEY then convert the result. }
var
	getit: Char;
begin
	getit := RawKey;
	case getit of
		#8:	getit := #27;	{ Convert backspace to escape. }
		#10:	getit := ' ';	{ Convert enter to space. }
		#13:	getit := ' ';	{ Convert enter to space. }
	end;
	RPGKey := getit;
end;

Function IsMoreKey( A: Char ): Boolean;
	{ Return TRUE if A is a "more" key, that should skip to the next message in a list. }
begin
	IsMoreKey := ( A = ' ' ) or ( A = #27 );
end;

Procedure MoreKey;
	{ Wait for the user to press either the space bar or the ESC key. }
var
	A: Char;
begin
	{ Keep reading keypresses until either a space or an ESC is found. }
	repeat
		A := RPGKey;
	until IsMoreKey( A );
end;

Function BufferPos( X,Y: Integer ): Integer;
	{ Translate screen coordinates X,Y into a video buffer index. }
begin
	BufferPos := (X-1)+(Y-1)*ScreenWidth;
end;

Procedure ClrZone( const Z: vgfx_Rect );
	{ Clear the specified zone. }
const
	ClrChar: TVideoCell = Ord(' ')+($07 shl 8);
var
	X,Y,P: Integer;
begin
	for X := Z.X to ( Z.X + Z.W - 1 ) do begin
		for Y := Z.Y to ( Z.Y + Z.H - 1 ) do begin
			P := BufferPos( X , Y );
			if ( P >= 0 ) and ( P < ( ScreenWidth * ScreenHeight ) ) then VideoBuf^[ BufferPos( X , Y ) ] := ClrChar;
		end;
	end;
end;

Procedure ClrScreen;
	{ Clear the entire screen. Yay! }
var
	sz: vgfx_rect;
begin
	sz.X := 1;
	sz.Y := 1;
	sz.H := screenheight;
	sz.W := screenwidth;
	ClrZone( sz );
end;

Procedure VClrEOL;
	{ Clear from the current write position to the end of the current line. }
var
	sz: vgfx_rect;
begin
	sz.X := VG_X;
	sz.Y := VG_Y;
	sz.H := 1;
	sz.W := screenwidth - VG_X;
	if sz.W > ( vg_window.X + vg_window.W - 1 ) then sz.W := ( vg_window.X + vg_window.W - VG_X );
	ClrZone( sz );
end;

Procedure CalcPen;
	{ Calculate the color bit value, based on the requested FGPen and BGPen. }
begin
	VG_Pen := VG_FGColor + ( VG_BGColor shl 4 );
end;

Procedure TextColor( C: Byte );
	{ Set the foreground color. }
begin
	VG_FGColor := C;
	CalcPen;
end;

Procedure TextBackground( C: Byte );
	{ Set the background color. }
begin
	VG_BGColor := C;
	CalcPen;
end;

Procedure TextColorBackground( FG,BG: Byte );
	{ Set the foreground color. }
begin
	VG_FGColor := FG;
	VG_BGColor := BG;
	CalcPen;
end;

Function InWindow( X , Y: Byte ): Boolean;
	{ Return TRUE if X,Y is in the window, or FALSE otherwise. }
begin
	InWindow := ( X >= vg_window.X ) and ( Y >= vg_window.Y ) and ( X < ( vg_window.X + vg_window.w ) ) and ( Y < ( vg_window.y + vg_window.h ) );
end;

Procedure TextOut(X,Y : Word;Const S : String);
	{ Write text to the screen at the listed coordinates. This procedure }
	{ was ripped more or less exactly from the FPC documentation. }
Var
	P,I,M : Word;
begin
	P:=((X-1)+(Y-1) * ScreenWidth);
	M:=Length(S);
	If ( P + M ) > ScreenWidth*ScreenHeight then M:=ScreenWidth*ScreenHeight-P;
	For I:=1 to M do if InWindow( X + I - 1 , Y ) then VideoBuf^[P+I-1]:=Ord(S[i])+( VG_Pen shl 8 );
end;

Procedure ClipZone( Z: vgfx_rect );
	{ Set the clipping bounds to this defined zone. }
begin
	vg_window := Z;
	vg_x := Z.X;
	vg_y := Z.Y;
end;

Procedure VGotoXY( X,Y: Integer );
	{ Set the write position to the requested coordinates. }
begin
	vg_x := X;
	vg_y := Y;
end;

Procedure MaxClipZone;
	{ Restore the clip area to the maximum possible area. }
begin
	vg_window.X := 1;
	vg_window.Y := 1;
	vg_window.W := ScreenColumns;
	vg_Window.H := ScreenRows;
end;

Procedure DrawGlyph( img: Char; X,Y,FG,BG: Byte );
	{ Draw a character at the requested location with the given foreground and }
	{ background colors. }
var
	I: Integer;
begin
	I := ( Y-1 ) * ScreenWidth + X - 1;
	if InWindow( X,Y ) and ( I < VideoBufSize ) then begin
		TextColorBackground( FG , BG );
		VideoBuf^[ I ] := Ord( img )+( VG_Pen shl 8 );
	end;
end;

Procedure VWrite( Const S: String );
	{ Write to the screen using Video. }
Var
	P,I,M : Word;
begin
	P:=((VG_X-1)+(VG_Y-1) * ScreenWidth);
	M:=Length(S);
	If ( P + M ) > ScreenWidth*ScreenHeight then M:=ScreenWidth*ScreenHeight-P;
	For I:=1 to M do begin
		if InWindow( vg_x , vg_y ) then begin
			VideoBuf^[P+I-1]:=( Ord(S[i]) )+( VG_Pen shl 8 );
		end;
		Inc( vg_X );
	end;
end;

Procedure VWriteln( Const S: String );
	{ Write to the screen using Video. Move to the next line afterwards. }
Var
	P,I,M : Word;
begin
	P:=((VG_X-1)+(VG_Y-1) * ScreenWidth);
	M:=Length(S);
	If ( P + M ) > ScreenWidth*ScreenHeight then M:=ScreenWidth*ScreenHeight-P;
	For I:=1 to M do begin
		if InWindow( vg_x , vg_y ) then begin
			VideoBuf^[P+I-1]:=Ord(S[i])+( VG_Pen shl 8 );
		end;
		Inc( vg_X );
	end;
	vg_X := vg_window.X;
	InC( vg_y );
end;

Function ZoneToRect( Z: VGFX_Zone ): VGFX_Rect;
	{ Convert the provided zone to a rect. }
var
	it: VGFX_Rect;
begin
	it.W := Z.W;
	it.H := Z.H;
	case Z.X_Anchor of
		ANC_Low:	it.X := 1;
		ANC_Mid:	it.X := ScreenColumns div 2;
		ANC_High:	it.X := ScreenColumns;
	end;
	it.X := it.X + Z.X_Justify;
	case Z.Y_Anchor of
		ANC_Low:	it.Y := 1;
		ANC_Mid:	it.Y := ScreenRows div 2;
		ANC_High:	it.Y := ScreenRows;
	end;
	it.Y := it.Y + Z.Y_Justify;
	ZoneToRect := it;
end;

Procedure GameMSG( msg: string; Z: vgfx_rect; C: Byte );
	{Prettyprint the string MSG with color C in screen zone Z.}
var
	NextWord: String;
	THELine: String;	{The line under construction.}
	LC: Boolean;		{Loop Condition.}
begin
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	TextColorBackground( C , Black );

	{Clear the message area, and set clipping bounds.}
	ClrZone( Z );
	ClipZone( Z );

	{THELine = The first word in this iteration}
	THELine := ExtractWord( msg );

	{Start the main processing loop.}
	while TheLine <> '' do begin
		{Set the LoopCondition to True.}
		LC := True;

		{ Start building the line. }
		repeat
			NextWord := ExtractWord( Msg );

			if Length(THEline + ' ' + NextWord) < Z.W then
				THEline := THEline + ' ' + NextWord
			else
				LC := False;

		until (not LC) or (NextWord = '') or ( TheLine[Length(TheLine)] = #13 );

		{ If the line ended due to a line break, deal with it. }
		if ( TheLine[Length(TheLine)] = #13 ) then begin
			{ Display the line break as a space. }
			TheLine[Length(TheLine)] := ' ';
			NextWord := ExtractWord( msg );
		end;

		{ Output the line. }
		if NextWord = '' then begin
			VWrite(THELine);
		end else begin
			VWriteLn(THELine);
		end;

		{ Prepare for the next iteration. }
		TheLine := NextWord;

	end; { while msg <> '' }

	{Restore the clip window to its maximum size.}
	MaxClipZone;
end;

Procedure GameMSG( msg: string; Z: vgfx_zone; C: Byte );
	{ Convert the zone to a rect and send it to the above procedure. }
begin
	GameMsg( msg , ZoneToRect( Z ) , C );
end;

Procedure CMessage( const msg: String; Z: VGFX_Rect; C: Byte );
	{ Display MSG centered in zone Z. }
var
	X,Y: Integer;
begin
	{ Figure out the coordinates for centered display. }
	X := Z.X + ( Z.W div 2 ) - ( Length( msg ) div 2 );
	Y := Z.Y + Z.H div 2;

	{ Actually do the output. }
	ClrZone( Z );
	ClipZone( Z );
	if X < 1 then X := 1;
	if Y < 1 then Y := 1;
	VGotoXY( X , Y );
	TextColor( C );
	VWrite(msg);
	MaxClipZone;
end;

Procedure CMessage( const msg: String; Z: VGFX_Zone; C: Byte );
	{ Convert the zone to a rect, and print the message. }
begin
	CMessage( msg , ZoneToRect( Z ) , C );
end;

Procedure RedrawConsole;
	{ Draw the console to the screen. }
var
	T: Integer;
	N: Integer;
begin
	TextColorBackground( Green , Black );
	N := NumSAtts( Console_History );
	ClipZone( ZONE_Console );
	for t := 1 to ZONE_Console.H do begin
		if ( t + N - ZONE_Console.H ) > 0 then begin
			VWriteLn( RetrieveSAtt( Console_History , ( t + N - ZONE_Console.H ) )^.Info );
		end else begin
			VWriteLn( ' ' );
		end;
	end;
	MaxClipZone;
end;

Procedure DialogMSG(msg: string); {not const-able}
	{ Print a message in the scrolling dialog box. }
var
	NextWord: String;
	THELine: String;	{The line under construction.}
	LC: Boolean;		{Loop Condition.}
	SA: SAttPtr;
begin
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	msg := '> ' + msg;

	{THELine = The first word in this iteration}
	THELine := ExtractWord( msg );

	{Start the main processing loop.}
	while TheLine <> '' do begin
		{Set the LoopCondition to True.}
		LC := True;

		{ Start building the line. }
		repeat
			NextWord := ExtractWord( Msg );

			if Length(THEline + ' ' + NextWord) < ZONE_Console.W then
				THEline := THEline + ' ' + NextWord
			else
				LC := False;

		until (not LC) or (NextWord = '') or ( TheLine[Length(TheLine)] = #13 );

		{ If the line ended due to a line break, deal with it. }
		if ( TheLine[Length(TheLine)] = #13 ) then begin
			{ Display the line break as a space. }
			TheLine[Length(TheLine)] := ' ';
			NextWord := ExtractWord( msg );
		end;

		{ Output the line. }
		if TheLine <> '' then begin
			if NumSAtts( Console_History ) >= Console_History_Length then begin
				SA := Console_History;
				RemoveSAtt( Console_History , SA );
			end;
			StoreSAtt( Console_History , TheLine );
		end;

		{ Prepare for the next iteration. }
		TheLine := NextWord;

	end; { while msg <> '' }

	{ Redraw the dialog area. }
	RedrawConsole;
end;

Function MoreHighFirstLine( LList: SAttPtr ): Integer;
	{ Determine the highest possible FirstLine value. }
var
	it: Integer;
begin
	it := NumSAtts( LList ) - ( ScreenHeight - 3 );
	if it < 1 then it := 1;
	MoreHighFirstLine := it;
end;

Procedure MoreText( LList: SAttPtr; FirstLine: Integer );
	{ Browse this text file across the majority of the screen. }
	{ Clear the screen upon exiting, though restoration of the }
	{ previous display is someone else's responsibility. }
	Procedure DisplayTextHere;
	var
		CLine: SAttPtr;	{ Current Line }
	begin
		{ Error check. }
		if FirstLine < 1 then FirstLine := 1
		else if FirstLine > MoreHighFirstLine( LList ) then FirstLine := MoreHighFirstLine( LList );
		VGotoXY( 1 , 1 );

		CLine := RetrieveSATt( LList , FirstLine );
		while ( VG_Y < ( ScreenHeight - 1 ) ) do begin
			VClrEOL;
			if CLine <> Nil then begin
				vwriteln( Copy( CLine^.Info , 1 , ScreenWidth - 1 ) );
				CLine := CLine^.Next;
			end else begin
				vwriteln( '' );
			end;
		end;
		DoFlip;
	end;
var
	A: Char;
begin
	ClrScreen;
	VGotoXY( 1 , ScreenHeight );
	TextColorBackground( LightGreen , Black );
	VWrite( MsgString( 'MORETEXT_Prompt' ) );

	{ Display the screen. }
	TextColor( LightGray );
	DisplayTextHere;

	repeat
		{ Get input from user. }
		A := RPGKey;

		{ Possibly process this input. }
		if A = KeyMap[ KMC_South ].KCode then begin
			Inc( FirstLine );
			DisplayTextHere;
		end else if A = KeyMap[ KMC_North ].KCode then begin
			Dec( FirstLine );
			DisplayTextHere;
		end;

	until ( A = #27 ) or ( A = 'Q' );

	{ CLear the display area. }
	ClrScreen;
end;

Function GetStringFromUser( const Prompt: String; Redraw: RedrawProcedureType ): String;
	{ Does what it says. }
const
	AllowableCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890()-=_+,.?"';
	MaxInputLength = 39;

	ZONE_TextInputFull: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify:  -1; H: 2;
	);
	ZONE_TextInputPrompt: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify:  -1; H: 1;
	);
	ZONE_TextInput: vgfx_zone = (
		X_Anchor: ANC_Mid; X_Justify: -20; W: 40;
		Y_Anchor: ANC_Mid; Y_Justify:   0; H: 1;
	);

var
	A: Char;
	it: String;
begin
	{ Initialize string. }
	it := '';

	Redraw;
	InfoBox( ZONE_TextInputFull );

	{ Give us a nice blinky cursor, please. }
	SetCursorType( crBlock );

	repeat
		{ Set up the display. }
		CMessage( Prompt , ZONE_TextInputPrompt , White );
		CMessage( it , ZONE_TextInput , Green );
		TextColor( LightGreen );

		SetCursorPos( VG_X - 1 , VG_Y - 1 );

		DoFlip;
		A := RawKey;

		if ( A = #8 ) and ( Length( it ) > 0 ) then begin
			it := Copy( it , 1 , Length( it ) - 1 );
		end else if ( Pos( A , AllowableCharacters ) > 0 ) and ( Length( it ) < MaxInputLength ) then begin
			it := it + A;
		end;
	until ( A = #13 ) or ( A = #27 );

	{ Get rid of the cursor, again. }
	SetCursorType( crHidden );

	GetStringFromUser := it;
end;

Procedure SetupMemoDisplay;
	{ Draw a border for the memo browser. }
begin
	InfoBox( ZONE_MemoText );
	InfoBox( ZONE_MemoMenu );
end;

Procedure DrawBPBorder;
	{ Draw the backpack border. }
begin
	InfoBox( ZONE_EqpMenu );
	InfoBox( ZONE_InvMenu );
	InfoBox( ZONE_BackpackInstructions );
	InfoBox( ZONE_ItemsInfo );
	InfoBox( ZONE_ItemsPCInfo );
end;

Procedure SetupFHQDisplay;
	{ Draw the backpack border. }
begin
	InfoBox( ZONE_FieldHQMenu );
	InfoBox( ZONE_BackpackInstructions );
	InfoBox( ZONE_ItemsInfo );
	InfoBox( ZONE_ItemsPCInfo );
end;


Procedure DrawGetItemBorder;
	{ Draw the get items border. }
begin
	InfoBox( ZONE_GetItemMenu );
end;

Procedure SetupInteractDisplay( C: Byte );
	{ Draw the backpack border. }
begin
	ClrZone( ZoneToRect( ZONE_InteractTotal ) );
	InfoBox( ZONE_InteractTotal );
end;

Procedure SetupServicesDisplay;
	{ Draw the display for the services interface. }
begin
	InfoBox( ZONE_ShopCaption );
	InfoBox( ZONE_ShopMsg );
	InfoBox( ZONE_ShopMenu );
	InfoBox( ZONE_ItemsInfo );
	InfoBox( ZONE_ItemsPCInfo );
end;

Procedure InfoBox( MyDest: VGFX_Rect );
	{ Draw a box around the specified location. }
var
	X,Y: Integer;
begin
	ClrZone( MyDest );

	if MyDest.X > 0 then Dec( MyDest.X );
	if MyDest.Y > 0 then Dec( MyDest.Y );
	MyDest.W := MyDest.W + 2;
	MyDest.H := MyDest.H + 2;
	for X := ( MyDest.X + 1 ) to ( MyDest.X + MyDest.W - 2 ) do begin
		DrawGlyph( '-' , X , MyDest.Y , BorderBlue , StdBlack );
		DrawGlyph( '-' , X , MyDest.Y + MyDest.H - 1 , BorderBlue , StdBlack );
	end;
	for y := ( MyDest.Y + 1 ) to ( MyDest.Y + MyDest.H - 2 ) do begin
		DrawGlyph( '|' , MyDest.X , Y , BorderBlue , StdBlack );
		DrawGlyph( '|' , MyDest.X + MyDest.W - 1 , Y , BorderBlue , StdBlack );
	end;
	DrawGlyph( '+' , MyDest.X , MyDest.Y , BorderBlue , StdBlack );
	DrawGlyph( '+' , MyDest.X + MyDest.W - 1 , MyDest.Y , BorderBlue , StdBlack );
	DrawGlyph( '+' , MyDest.X + MyDest.W - 1 , MyDest.Y + MyDest.H - 1 , BorderBlue , StdBlack );
	DrawGlyph( '+' , MyDest.X , MyDest.Y + MyDest.H - 1 , BorderBlue , StdBlack );
end;

Procedure InfoBox( Z: VGFX_Zone );
	{ Draw a box around the specified location. }
var
	MyDest: VGFX_Rect;
begin
	MyDest := ZoneToRect( Z );
	InfoBox( MyDest );
end;

Procedure ClockBorder;
	{ Draw the setup for the clock. }
var
	MyDest: VGFX_Rect;
begin
	MyDest := ZoneToRect( ZONE_Clock );
	DrawGlyph( '[' , MyDest.X - 1 , MyDest.Y , BorderBlue , Black );
	DrawGlyph( ']' , MyDest.X + MyDest.W + 1 , MyDest.Y , BorderBlue , Black );
end;

Procedure SetupArenaDisplay;
	{ Setup the borders for the menus. }
begin
	ClrScreen;
	InfoBox( ZONE_ArenaInfo );
	InfoBox( ZONE_ArenaPilotMenu );
	InfoBox( ZONE_ArenaMechaMenu );
	InfoBox( ZONE_PCStatus );
	RedrawConsole;
end;

Procedure SetupArenaMissionMenu;
	{ This sets up the select arena mission menu. }
begin
	InfoBox( ZONE_SAMText );
	InfoBox( ZONE_SAMMenu );
end;

Procedure SetupConcertDisplay;
	{ Set up the concert display. }
begin
	InfoBox( ZONE_ConcertAudience );
	InfoBox( ZONE_ConcertCaption );
	InfoBox( ZONE_ConcertMenu );
	InfoBox( ZONE_ConcertDesc );
end;

Procedure SetupTitleScreenDisplay;
	{ Set up the concert display. }
begin
	ClrScreen;
	InfoBox( ZONE_Title_Screen_Top );
	InfoBox( ZONE_Title_Screen_Menu );
	CMessage( 'GearHead II' , ZONE_Title_Screen_Title , StdWhite );
end;


initialization
	InitVideo;

	InitKeyboard;
	CalcPen;

	NormMode.Col := ScreenColumns;
	NormMode.Row := ScreenRows;
	SetVideoMode( NormMode );
	SetCursorType( crHidden );

	Console_History := Nil;


	ZONE_Console.W := ScreenColumns;
	ZONE_Console.Y := ScreenRows - 4;

	ZONE_RightInfo := ZONE_Menu1;
	ZONE_LeftInfo := ZONE_Menu2;
	ZONE_Caption := ZONE_Info;
	ZONE_SubCaption := ZONE_Clock;
	ZONE_Dialog := ZONE_PCStatus;

	ZONE_CharGenMenu := ZONE_Menu1;
	ZONE_CharGenCaption := ZONE_Menu2;
	ZONE_CharGenPrompt := ZONE_Info;

finalization
{$IFNDEF ASCII}
	ClrScreen;
	DoFlip;
{$ENDIF}
	DoneVideo;
	DoneKeyboard;

	DisposeSAtt( Console_History );

end.
