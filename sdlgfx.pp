unit sdlgfx;
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
	Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
}
{
	This is a 2DSD interface for GH2, because acronyms rock.
}

{$MODE FPC}
{$LONGSTRINGS ON}

{$IFDEF ASCII}
Interrupt compilation now.
{$ENDIF}

interface

uses SDL,SDL_TTF,SDL_Image,gears,texutil,dos,ui4gh;

Type
	SensibleSpritePtr = ^SensibleSprite;
	SensibleSprite = Record
		Name,Color: String;
		W,H: Integer;	{ Width and Height of each cell. }
		Img: PSDL_Surface;
		Next: SensibleSpritePtr;
	end;

	RedrawProcedureType = Procedure;

    DynamicRect = Object
        dx,dy,w,h,anchor: Integer;
        function GetRect: TSDL_Rect;
    end;


const
	Avocado: TSDL_Color =		( r:136; g:141; b:101 );
	Bacardi: TSDL_Color =		( r:121; g:105; b:137 );
	Jade: TSDL_Color =		( r: 66; g:121; b:119 );
	BrightJade: TSDL_Color =	( r:100; g:200; b:180 );

	StdBlack: TSDL_Color =		( r:  5; g:  5; b:  5 );
	StdWhite: TSDL_Color =		( r:255; g:255; b:255 );
	MenuItem: TSDL_Color =		( r: 88; g:161; b:159 );
	MenuSelect: TSDL_Color =	( r:125; g:250; b:125 );
	TerrainGreen: TSDL_Color =	( r:100; g:210; b:  0 );
	PlayerBlue: TSDL_Color =	( r:  0; g:141; b:211 );
	AllyPurple: TSDL_Color =	( r:236; g:  0; b:211 );
	EnemyRed: TSDL_Color =		( r:230; g:  0; b:  0 );
	NeutralGrey: TSDL_Color =	( r:150; g:150; b:150 );
	DarkGrey: TSDL_Color =		( r:100; g:100; b:100 );
	InfoGreen: TSDL_Color =		( r:  0; g:240; b:  0 );
	InfoHiLight: TSDL_Color =	( r: 70; g:255; b: 70 );
	TextboxGrey: TSDL_Color =	( r:130; g:120; b:125 );
	NeutralBrown: TSDL_Color =	( r:230; g:191; b: 81 );
	BorderBlue: TSDL_Color =	( r:  0; g:101; b:151 );
	Cyan: TSDL_Color = 		( r:  0; g:255; b:155 );
	MelodyYellow: TSDL_Color = 	( r:250; g:200; b: 0  );

	BorderColor: TSDL_Color = 	( r:200; g: 50; b:  0 );

	ScreenWidth = 800;
	ScreenHeight = 600;
	FontSize = 12;
	SmallFontSize = 9;

	Right_Column_Width = 180;

    ANC_upperleft = 0;
    ANC_upper = 1;
    ANC_upperright = 2;
    ANC_left = 3;
    ANC_middle = 4;
    ANC_right = 5;
    ANC_lowerleft = 6;
    ANC_lower = 7;
    ANC_lowerright = 8;

	ZONE_TextInputPrompt: DynamicRect = ( dx:-210; dy:-51; w:420; h:16; anchor: ANC_middle );
	ZONE_TextInput: DynamicRect = ( dx:-210; dy:-27; w:420; h:16; anchor: ANC_middle );
	ZONE_TextInputBigBox: DynamicRect = ( dx:-220; dy:-61; w:440; h:56; anchor: ANC_middle );
    ZONE_PhoneInstructions: DynamicRect = ( dx:-200; dy:15; w:400; h:16; anchor: ANC_middle );

	Model_Status_Width =   250;
	Model_Status_Height =  120;

	Console_History_Length = 240;
	Dialog_Area_Height = Model_Status_Height;

	ZONE_Info: DynamicRect = ( dx:  -Right_Column_Width - 10 ; dy:10; w:Right_Column_Width; h:150; anchor: ANC_upperright );
	ZONE_Menu: DynamicRect = ( dx:  -Right_Column_Width - 10 ; dy:170; w:Right_Column_Width; h:ScreenHeight - 220 - Dialog_Area_Height; anchor: ANC_upperright );
	ZONE_Menu1: DynamicRect = ( dx:  -Right_Column_Width - 10 ; dy:170; w:Right_Column_Width; h:130; anchor: ANC_upperright );
	ZONE_Menu2: DynamicRect = ( dx:  - Right_Column_Width - 10 ; dy:310; w:Right_Column_Width; h:ScreenHeight - 350 - Dialog_Area_Height; anchor: ANC_upperright );

	ZONE_Dialog: DynamicRect = ( dx: Model_Status_Width - 375; dy: -Model_Status_Height-10; w: 750 - Model_Status_Width; h: Model_Status_Height; anchor: ANC_lower );
	ZONE_PCStatus: DynamicRect = ( dx: -380; dy: -Model_Status_Height - 10; w: Model_Status_Width; h: Model_Status_Height; anchor: ANC_lower );

	KEY_REPEAT_DELAY = 200;
	KEY_REPEAT_INTERVAL = 75;

	RPK_MouseButton = #$90;
	RPK_TimeEvent = #$91;
	RPK_RightButton = #$92;


	ZONE_MoreText: DynamicRect = ( dx:-350; dy:-270; w: 700 ; h: 385; anchor: ANC_middle );
	ZONE_MorePrompt: DynamicRect = ( dx:-300; dy: 130 ; w:600; h:30; anchor: ANC_middle );

    ZONE_CharGenChar: DynamicRect = ( dx:-368; dy:-210; w: 500 ; h: 400; anchor: ANC_middle );
	ZONE_CharGenMenu: DynamicRect = ( dx:148; dy:-50; w:220; h:230; anchor: ANC_middle );
	ZONE_CharGenCaption: DynamicRect = ( dx:148; dy:190; w:220; h:20; anchor: ANC_middle );
	ZONE_CharGenDesc: DynamicRect = ( dx:148; dy:-210; w:220; h:150; anchor: ANC_middle );
	ZONE_CharGenPrompt: DynamicRect = ( dx:-150; dy:-245; w:300; h:20; anchor: ANC_middle );
	ZONE_CharGenHint: DynamicRect = ( dx:-160; dy:225; w:320; h:20; anchor: ANC_middle );

    ZONE_CharViewChar: DynamicRect = ( dx:-368; dy:-260; w: 500 ; h: 400; anchor: ANC_middle );
	ZONE_CharViewMenu: DynamicRect = ( dx:148; dy:-100; w:220; h:230; anchor: ANC_middle );
	ZONE_CharViewCaption: DynamicRect = ( dx:148; dy:140; w:220; h:20; anchor: ANC_middle );
	ZONE_CharViewDesc: DynamicRect = ( dx:148; dy:-260; w:220; h:150; anchor: ANC_middle );


    ZONE_ShopNPCName: DynamicRect = ( dx:-330; dy: -230; w: 100; h: 32; anchor: ANC_middle );
    ZONE_ShopNPCPortrait: DynamicRect = ( dx:-330; dy: -210; w: 100; h: 150; anchor: ANC_middle );
    ZONE_ShopText: DynamicRect = ( dx:-225; dy: -230; w: 287; h: 170; anchor: ANC_middle );
    ZONE_ShopPCName: DynamicRect = ( dx:-330; dy: -30; w: 100; h: 32; anchor: ANC_middle );
    ZONE_ShopPCPortrait: DynamicRect = ( dx:-330; dy: -10; w: 100; h: 150; anchor: ANC_middle );
    ZONE_ShopMenu: DynamicRect = ( dx:-225; dy: -35; w: 287; h: 190; anchor: ANC_middle );

	ZONE_ShopInfo: DynamicRect = (dx:85; dY:-225; W: 250; H: 340; anchor: ANC_middle);
    ZONE_ShopCash: DynamicRect = ( dx:135; dy: 130; w: 150; h: 16; anchor: ANC_middle );
    ZONE_ShopTop: DynamicRect = ( dx:-335; dy: -235; w: 402; h: 180; anchor: ANC_middle );
    ZONE_ShopBottom: DynamicRect = ( dx:-335; dy: -40; w: 402; h: 200; anchor: ANC_middle );

	Concert_Zone_Width = 500;
	Concert_X0 = -(Concert_Zone_Width div 2);
	Concert_X1 = Concert_X0 + 110;
	Concert_Text_Width = Concert_Zone_Width - 110;
	Concert_Zone_Height = 300;
	Concert_y0 = -180;
	Concert_Audience_Height = 140;
	Concert_Y1 = Concert_Y0 + Concert_Audience_Height + 10;
	ZONE_ConcertTotal: DynamicRect = ( dx: Concert_X0 ; dy: Concert_Y0; w: Concert_Zone_Width; h: Concert_Zone_Height; anchor: ANC_middle );
	ZONE_ConcertAudience: DynamicRect =  ( dx: Concert_X0 ; dy: Concert_Y0; w: Concert_Zone_Width; h: Concert_Audience_Height; anchor: ANC_middle );
	ZONE_ConcertCaption: DynamicRect =  ( dx: Concert_X1 ; dy: Concert_Y1; w: Concert_Text_Width; h: 40; anchor: ANC_middle );
	ZONE_ConcertMenu: DynamicRect =  ( dx: Concert_X1 ; dy: Concert_Y1 + 45; w: Concert_Text_Width; h: 80; anchor: ANC_middle );
	ZONE_ConcertDesc: DynamicRect =  ( dx: Concert_X1 ; dy: Concert_Y1 + 130; w: Concert_Text_Width; h: 20; anchor: ANC_middle );
	ZONE_ConcertPhoto:  DynamicRect =  ( dx: Concert_X0 ; dy: Concert_Y1; w: 100; h: 150; anchor: ANC_middle );

	ZONE_InteractStatus: DynamicRect = ( dx:-250; dy: -210; w: 395; h: 40; anchor: ANC_middle );
	ZONE_InteractMsg: DynamicRect = ( dx: -250; dy:-120; w:395; h: 110; anchor: ANC_middle );
	ZONE_InteractMenu: DynamicRect = ( dx: -250; dy:-5; w:500; h: 120; anchor: ANC_middle );
	ZONE_InteractPhoto: DynamicRect = ( dx: 150; dy: -185; w: 100; h: 150; anchor: ANC_middle );
	ZONE_InteractInfo: DynamicRect = ( dx: -250; dy:-165; w:395; h:40; anchor: ANC_middle );
	ZONE_InteractTotal: DynamicRect = ( dx: -255; dy: -215; w: 510; h: 335; anchor: ANC_middle );

    ZONE_CenterMenu: DynamicRect = ( dx:-120; dy:-155; w:240; h:210; anchor: ANC_middle );

	{ The ITEMS ZONE is used for both the backpack and shopping interfaces. }
	ItemsLeftWidth = 345;
	ItemsRightWidth = 225;
	ItemsZoneLeftTab = ( ScreenWidth - ItemsLeftWidth - ItemsRightWidth - 10 ) div 2;
	ItemsZoneRightTab = ItemsZoneLeftTab + ItemsLeftWidth + 10;

	ZONE_ItemsInfo: DynamicRect = (dx:30; dY:-210; W: 250; H: 340; anchor: ANC_middle);
	//ZONE_ItemsPCInfo: TSDL_Rect = ( x: ItemsZoneRightTab; y:ScreenHeight Div 2 + 70; w: ItemsRightWidth; h: 30 );

    ZONE_FHQTitle: DynamicRect = ( dx:-165; dy:-255; w:300; h:20; anchor: ANC_middle ); 
    ZONE_FieldHQMenu: DynamicRect = ( dx:-280; dy:-210; w:292; h:340; anchor: ANC_middle );
    ZONE_FHQMenu1: DynamicRect = ( dx:-280; dy:-210; w:292; h:180; anchor: ANC_middle );
    ZONE_FHQMenu2: DynamicRect = ( dx:-280; dy: -15; w:292; h:145; anchor: ANC_middle );

	ZONE_BPTotal: DynamicRect = (dx:-285; dY:-215; W: 570; H: 350; anchor: ANC_middle);
    ZONE_BPHeader: DynamicRect = (dx:-280; dY:-210; W: 292; H: 40; anchor: ANC_middle);
	ZONE_EqpMenu: DynamicRect = ( dx:-280; dy:-165; w:292; h:100; anchor: ANC_middle );
	ZONE_InvMenu: DynamicRect = ( dx:-280; dy:-60; w:292; h:145; anchor: ANC_middle );
	ZONE_BackpackInstructions: DynamicRect = (dx:-280; dY:90; W: 292; H: 40; anchor: ANC_middle);
	ZONE_BPInfo: DynamicRect = (dx:30; dY:-210; W: 250; H: 340; anchor: ANC_middle);


	CaptionWidth = Model_Status_Width;
	ZONE_Caption: DynamicRect = ( dx: -( CaptionWidth div 2 ); dy: 20; w: CaptionWidth; h: Model_Status_Height; anchor: ANC_upper );
	SubCaptionWidth = FontSize * 20;
	ZONE_SubCaption: DynamicRect = ( dx: -( SubCaptionWidth div 2 ); dy: 35 + Model_Status_Height; w: SubCaptionWidth; h: FontSize + 2; anchor: ANC_upper );

//	ZONE_CharacterInfo: TSDL_Rect = ( x: ScreenWidth div 2 - 275; y: ScreenHeight Div 2 - 200; w: 450; h: 295 );


	SideInfoWidth = FontSize * 16;
	SideInfoHeight = ( FontSize + 2 ) * 6;
	ZONE_RightInfo: DynamicRect = ( dx: -SideInfoWidth - 10; dy: 15; w: SideInfoWidth; h: SideInfoHeight; anchor: ANC_upperright );
	ZONE_LeftInfo: DynamicRect = ( dx: 10; dy: 15; w: SideInfoWidth; h: SideInfoHeight; anchor: ANC_upperleft );

	ZONE_GetItemMenu: DynamicRect = ( dx:-100; dy:-125; w:200; h:250; anchor: ANC_middle );

	//ZONE_UsagePrompt: TSDL_Rect = ( x:500; y:190; w:130; h:170 );
	//ZONE_UsageMenu: TSDL_Rect = ( x:50; y:155; w:380; h:245 );

	ZONE_MemoText: DynamicRect = ( dx:-175; dy:-150; w:350; h:200; anchor: ANC_middle );
	ZONE_MemoMenu: DynamicRect = ( dx:-175; dy:55; w:350; h:50; anchor: ANC_middle );
    ZONE_MemoTotal: DynamicRect = ( dx:-180; dy:-155; w:360; h:265; anchor: ANC_middle );

	{ The SelectArenaMission zones. }
	ZONE_SAMMenu: DynamicRect = ( dx:-200; dy:-190; w:400; h:200; anchor: ANC_middle );
	ZONE_SAMText: DynamicRect = ( dx:-200; dy:25; w:400; h:50; anchor: ANC_middle );

	ZONE_WorldMap: TSDL_Rect = ( x: ScreenWidth div 2 - 160; y: ScreenHeight div 2 - 160; W:320; H:320 );

	ZONE_Clock: DynamicRect = ( dx: -150; dy: 30; w: 120; H:20; anchor: ANC_upperright );

	Monologue_Width = 400;
	Monologue_Height = 205;
	ZONE_MonologueTotal: DynamicRect = ( dx: -210; dy: -150; w: Monologue_Width + 20; h: Monologue_Height + 20; anchor: ANC_middle );
	ZONE_MonologueInfo: DynamicRect = ( dx: -200; dy: -150; w: Monologue_Width; h:30; anchor: ANC_middle );
	ZONE_MonologueText: DynamicRect = ( dx: -200; dy: -110; w: Monologue_Width - 110; h: Monologue_Height - 40; anchor: ANC_middle );
	ZONE_MonologuePortrait: DynamicRect = ( dx: 100; dy: -110; w: 100; h: 150; anchor: ANC_middle );

	Arena_List_Width = 240;
	Arena_List_Height = ScreenHeight - ( Dialog_Area_Height + 40 );
	ZONE_ArenaPilotMenu: DynamicRect = ( dx: -390; dy: -290; w: Arena_List_Width; h: Arena_List_Height; anchor: ANC_middle );
	ZONE_ArenaMechaMenu: DynamicRect = ( dx: -110; dy: -290; w: Arena_List_Width; h: Arena_List_Height; anchor: ANC_middle );
	ZONE_ArenaInfo: DynamicRect = ( dx: 150; dy: -290; w: ItemsRightWidth; h: Arena_List_Height; anchor: ANC_middle );


    ZONE_Title_Screen_Version: DynamicRect = ( dx:-70; dy:-25; w:100; h:20; anchor: ANC_lowerright );
    ZONE_Title_Screen_Menu: DynamicRect = ( dx:-100; dy:50; w:200; h:115; anchor: ANC_middle );
	ZONE_TitleLogo:  DynamicRect =  ( dx: -312; dy: -161; w: 624; h: 162; anchor: ANC_Middle );

	Animation_Phase_Period = 6000;

var
	Actual_Screen,Game_Screen: PSDL_Surface;
	Game_Font,Small_Font,Info_Font: PTTF_Font;
	Game_Sprites: SensibleSpritePtr;
	Last_Clock_Update: QWord;
	Animation_Phase: Integer;
	Mouse_X, Mouse_Y: LongInt;
	Cursor_Sprite: SensibleSpritePtr;
	Console_History: SAttPtr;
	Title_Screen,Title_Stars,Title_Logo: SensibleSpritePtr;
	Ersatz_Mouse_Sprite: SensibleSpritePtr;

	RK_NumKeys:	PInt;
	RK_KeyState:	PUInt8;

Procedure DoFlip;

Procedure QuickText( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
Procedure QuickTextC( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
Procedure QuickTextRJ( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );

Procedure DisposeSpriteList(var LList: SensibleSpritePtr);
Procedure RemoveSprite(var LMember: SensibleSpritePtr);

procedure DrawSprite( Spr: SensibleSpritePtr; MyDest: TSDL_Rect; Frame: Integer );
procedure DrawSprite( Spr: SensibleSpritePtr; MyCanvas: PSDL_Surface; MyDest: TSDL_Rect; Frame: Integer );

function LocateSprite( const Name, Color: String; W,H: Integer ): SensibleSpritePtr;
function LocateSprite( const Name: String; W,H: Integer ): SensibleSpritePtr;

Procedure CleanSpriteList;

function RPGKey: Char;


Procedure ClrZone( const Z: TSDL_Rect );
Procedure ClrScreen;

Procedure GetNextLine( var TheLine , msg , NextWord: String; Width: Integer; MyFont: PTTF_Font );
Function PrettyPrint( msg: string; Width: Integer; var FG: TSDL_Color; DoCenter: Boolean; MyFont: PTTF_Font ): PSDL_Surface;
Function PrettyPrint( msg: string; Width: Integer; var FG: TSDL_Color; DoCenter: Boolean ): PSDL_Surface;
Procedure CMessage( msg: String; Z: TSDL_Rect; C: TSDL_Color; MyFont: PTTF_Font );
Procedure CMessage( msg: String; Z: TSDL_Rect; C: TSDL_Color );
Procedure CMessage( msg: String; DZ: DynamicRect; C: TSDL_Color );
Procedure GameMSG( msg: string; Z: TSDL_Rect; C: TSDL_Color; MyFont: PTTF_Font );
Procedure GameMSG( msg: string; Z: TSDL_Rect; C: TSDL_Color );
Procedure GameMSG( msg: string; DZ: DynamicRect; C: TSDL_Color );

Function IsMoreKey( A: Char ): Boolean;
Procedure MoreKey;
Function TextLength( F: PTTF_Font; msg: String ): LongInt;

Function GetStringFromUser( Prompt: String; ReDrawer: RedrawProcedureType ): String;

Function MoreHighFirstLine( LList: SAttPtr ): Integer;

Procedure MoreText( LList: SAttPtr; FirstLine: Integer; ReDrawer: RedrawProcedureType );

Procedure RedrawConsole;
Procedure DialogMSG(msg: string);

Procedure ClearExtendedBorder( Dest: TSDL_Rect );

Procedure DrawBPBorder;
Procedure DrawGetItemBorder;
Procedure SetupInteractDisplay( TeamColor: TSDL_Color );
Procedure SetupServicesDisplay;
Procedure SetupFHQDisplay;
Procedure SetupMemoDisplay;
Procedure DrawMonologueBorder;

Procedure FillRectWithSprite( MyRect: TSDL_Rect; MySprite: SensibleSpritePtr; MyFrame,OffX,OffY: Integer );
Procedure FillRectWithSprite( MyRect: TSDL_Rect; MySprite: SensibleSpritePtr; MyFrame: Integer );

Procedure InfoBox( MyBox: TSDL_Rect );
Procedure InfoBox( MyBox: DynamicRect );

Procedure Idle_Display;

Procedure SetupArenaDisplay;
Procedure SetupArenaMissionMenu;
Procedure SetupConcertDisplay;
Procedure SetupTitleScreenDisplay;

implementation

const
	WindowName: PChar = 'GearHead II';
	IconName: PChar = 'GearHead II';

var
	Infobox_Border,Infobox_Backdrop: SensibleSpritePtr;

Function DynamicRect.GetRect: TSDL_Rect;
    { Return the TSDL_Rect described by this DynamicRect, given the current }
    { screen size. }
var
    MyRect: TSDL_Rect;
begin
    MyRect.W := Self.W;
    MyRect.H := Self.H;
    MyRect.X := Game_Screen^.W * (self.anchor mod 3) div 2 + Self.DX;
    MyRect.Y := Game_Screen^.H * (self.anchor div 3) div 2 + Self.DY;
    GetRect := MyRect;
end;


Procedure DoFlip;
	{ Flip out, man! This flips from the newly drawn screen to the physical screen. }
	{ Go look up Double Buffering on Wikipedia for more info. }
var
	MyDest: TSDL_Rect;
begin
	if Ersatz_Mouse then begin
		MyDest.X := Mouse_X;
		MyDest.Y := Mouse_Y;
		DrawSprite( Ersatz_Mouse_Sprite , MyDest , 0 );
	end;
	SDL_Flip( Game_Screen );
	Animation_Phase := ( Animation_Phase + 1 ) mod Animation_Phase_Period;
end;

Procedure QuickText( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
var
	pline: PChar;
	MyText: PSDL_Surface;
begin
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( F , pline , C );
{$IFDEF LINUX}
	if MyText <> Nil then SDL_SetColorKey( MyText , SDL_SRCCOLORKEY , SDL_MapRGB( MyText^.Format , 0 , 0, 0 ) );
{$ENDIF}
	Dispose( pline );
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure QuickTextC( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
	{ The text will be centered in the given zone. }
var
	pline: PChar;
	MyText: PSDL_Surface;
begin
	if msg = '' then Exit;
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( F , pline , C );
{$IFDEF LINUX}
	if MyText <> Nil then SDL_SetColorKey( MyText , SDL_SRCCOLORKEY , SDL_MapRGB( MyText^.Format , 0 , 0, 0 ) );
{$ENDIF}
	Dispose( pline );
	MyDest.X := MyDest.X + ( MyDest.W - MyText^.W ) div 2;
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure QuickTextRJ( msg: String; MyDest: TSDL_Rect; C: TSDL_Color; F: PTTF_Font );
	{ Quickly draw some text to the screen, without worrying about }
	{ line-splitting or justification or anything. }
	{ This variation on the procedure is right-justified. }
var
	pline: PChar;
	MyText: PSDL_Surface;
begin
	pline := QuickPCopy( msg );
	MyText := TTF_RenderText_Solid( F , pline , C );
{$IFDEF LINUX}
	if MyText <> Nil then SDL_SetColorKey( MyText , SDL_SRCCOLORKEY , SDL_MapRGB( MyText^.Format , 0 , 0, 0 ) );
{$ENDIF}
	Dispose( pline );
	MyDest.X := MyDest.X - MyText^.W;
	SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
	SDL_FreeSurface( MyText );
end;

Procedure DrawAnimImage( Image,Canvas: PSDL_Surface; W,H,Frame: Integer; var MyDest: TSDL_Rect );
	{ This procedure is modeled after the command from Blitz Basic. }
var
	MySource: TSDL_Rect;
begin
	MySource.W := W;
	MySource.H := H;
	if W > Image^.W then W := Image^.W;
	MySource.X := ( Frame mod ( Image^.W div W ) ) * W;
	MySource.Y := ( Frame div ( Image^.W div W ) ) * H;

	SDL_BlitSurface( Image , @MySource , Canvas , @MyDest );
end;

Function ScaleColorValue( V , I: Integer ): Byte;
	{ Scale a color value. }
begin
	V := ( V * I ) div 200;
	if V > 255 then V := 255;
	ScaleColorValue := V;
end;


Function MakeSwapBitmap( MyImage: PSDL_Surface; RSwap,YSwap,GSwap: PSDL_Color ): PSDL_Surface;
	{ Given a bitmap, create an 8-bit copy with pure colors. }
	{         0 : Transparent (0,0,255) }
	{   1 -  63 : Grey Scale            }
	{  64 - 127 : Pure Red              }
	{ 128 - 191 : Pure Yellow           }
	{ 192 - 255 : Pure Green            }
	{ Then, swap those colors out for the requested colors. }
var
	MyPal: Array [0..255] of TSDL_Color;
	T: Integer;
	MyImage2: PSDL_Surface;
begin
	{ Initialize the palette. }
	for t := 1 to 64 do begin
		MyPal[ T - 1 ].r := ( t * 4 ) - 1;
		MyPal[ T - 1 ].g := ( t * 4 ) - 1;
		MyPal[ T - 1 ].b := ( t * 4 ) - 1;

		MyPal[ T + 63 ].r := ( t * 4 ) - 1;
		MyPal[ T + 63 ].g := 0;
		MyPal[ T + 63 ].b := 0;

		MyPal[ T + 127 ].r := ( t * 4 ) - 1;
		MyPal[ T + 127 ].g := ( t * 4 ) - 1;
		MyPal[ T + 127 ].b := 0;

		MyPal[ T + 191 ].r := 0;
		MyPal[ T + 191 ].g := ( t * 4 ) - 1;
		MyPal[ T + 191 ].b := 0;
	end;
	MyPal[ 0 ].r := 0;
	MyPal[ 0 ].g := 0;
	MyPal[ 0 ].b := 255;

	{ Create replacement surface. }
	MyImage2 := SDL_CreateRGBSurface( SDL_SWSURFACE , MyImage^.W , MyImage^.H , 8 , 0 , 0 , 0 , 0 );
	SDL_SetPalette( MyImage2 , SDL_LOGPAL or SDL_PHYSPAL , MyPal , 0 , 256 );
	SDL_FillRect( MyImage2 , Nil , SDL_MapRGB( MyImage2^.Format , 0 , 0 , 255 ) );
	SDL_SetColorKey( MyImage2 , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( MyImage2^.Format , 0 , 0, 255 ) );

	{ Blit from the original to the copy. }
	SDL_BlitSurface( MyImage , Nil , MyImage2 , Nil );

	{ Redefine the palette. }
	for t := 1 to 64 do begin
		MyPal[ T + 63 ].r := ScaleColorValue( RSwap^.R , t * 4 );
		MyPal[ T + 63 ].g := ScaleColorValue( RSwap^.G , t * 4 );
		MyPal[ T + 63 ].b := ScaleColorValue( RSwap^.B , t * 4 );

		MyPal[ T + 127 ].r := ScaleColorValue( YSwap^.R , t * 4 );
		MyPal[ T + 127 ].g := ScaleColorValue( YSwap^.G , t * 4 );
		MyPal[ T + 127 ].b := ScaleColorValue( YSwap^.B , t * 4 );

		MyPal[ T + 191 ].r := ScaleColorValue( GSwap^.R , t * 4 );
		MyPal[ T + 191 ].g := ScaleColorValue( GSwap^.G , t * 4 );
		MyPal[ T + 191 ].b := ScaleColorValue( GSwap^.B , t * 4 );
	end;
	SDL_SetPalette( MyImage2 , SDL_LOGPAL or SDL_PHYSPAL , MyPal , 0 , 256 );

	MakeSwapBitmap := MyImage2;
end;

Procedure GenerateColor( var ColorString: String; var ColorStruct: TSDL_Color );
	{ Generate the color from the string. }
var
	n: Integer;
begin
	n := ExtractValue( ColorString );
	if n > 255 then n := 255;
	ColorStruct.R := n;
	n := ExtractValue( ColorString );
	if n > 255 then n := 255;
	ColorStruct.G := n;
	n := ExtractValue( ColorString );
	if n > 255 then n := 255;
	ColorStruct.B := n;
end;


Function LocateSpriteByNameColor( const name,color: String ): SensibleSpritePtr;
	{ Locate the sprite which matches the name provided. }
	{ If no such sprite exists, return Nil. }
var
	S: SensibleSpritePtr;
begin
	S := Game_Sprites;
	while ( S <> Nil ) and ( ( S^.Name <> name ) or ( S^.Color <> Color ) ) do begin
		S := S^.Next;
	end;
	LocateSpriteByNameColor := S;
end;

Function NewSprite: SensibleSpritePtr;
	{ Add an empty sprite description to the list. }
var
	it: SensibleSpritePtr;
begin
	New(it);
	if it = Nil then exit( Nil );
	{Initialize values.}
	it^.Next := Game_Sprites;
	Game_Sprites := it;
	NewSprite := it;
end;

Function AddSprite( name, color: String; W,H: Integer ): SensibleSpritePtr;
	{ Add a new element to the Sprite List. Load the image for this sprite }
	{ from disk, if possible. }
var
	fname: PChar;
	it: SensibleSpritePtr;
	tmp: PSDL_Surface;
	RSwap,YSwap,GSwap: TSDL_Color;
begin
	{Allocate memory for our new element.}
	it := NewSprite;
	if it = Nil then Exit( Nil );
	it^.Name := Name;
	it^.Color := Color;
	it^.W := W;
	it^.H := H;

	name := FSearch( name , Graphics_Directory );

	if name <> '' then begin
		fname := QuickPCopy( name );

		{ Attempt to load the image. }
		it^.Img := IMG_Load( fname );

		if it^.Img <> Nil then begin
			{ Set transparency color. }
			SDL_SetColorKey( it^.Img , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( it^.Img^.Format , 0 , 0, 255 ) );

			{ If a color swap has been specified, handle that here. }
			if Color <> '' then begin
				GenerateColor( Color , RSwap );
				GenerateColor( Color , YSwap );
				GenerateColor( Color , GSwap );

				tmp := MakeSwapBitmap( it^.Img , @RSwap , @YSwap , @GSwap );
				SDL_FreeSurface( it^.Img );
				it^.img := tmp;
			end;

			{ Convert to the screen mode. }
			{ This will make blitting far quicker. }
			tmp := SDL_ConvertSurface( it^.Img , Game_Screen^.Format , SDL_SRCCOLORKEY );
			SDL_FreeSurface( it^.Img );
			it^.Img := TMP;
		end;

		Dispose( fname );
	end else begin
		it^.Img := Nil;

	end;

	{Return a pointer to the new element.}
	AddSprite := it;
end;

Procedure DisposeSpriteList(var LList: SensibleSpritePtr);
	{Dispose of the list, freeing all associated system resources.}
var
	LTemp: SensibleSpritePtr;
begin
	while LList <> Nil do begin
		LTemp := LList^.Next;

		if LList^.Img <> Nil then SDL_FreeSurface( LList^.Img );

		Dispose(LList);
		LList := LTemp;
	end;
end;


Procedure RemoveSprite(var LMember: SensibleSpritePtr);
	{Locate and extract member LMember from list LList.}
	{Then, dispose of LMember.}
var
	a,b: SensibleSpritePtr;
begin
	{Initialize A and B}
	B := Game_Sprites;
	A := Nil;

	{Locate LMember in the list. A will thereafter be either Nil,}
	{if LMember if first in the list, or it will be equal to the}
	{element directly preceding LMember.}
	while (B <> LMember) and (B <> Nil) do begin
		A := B;
		B := B^.next;
	end;

	if B = Nil then begin
		{Major FUBAR. The member we were trying to remove can't}
		{be found in the list.}
		writeln('ERROR- RemoveLink asked to remove a link that doesnt exist.');
		end
	else if A = Nil then begin
		{There's no element before the one we want to remove,}
		{i.e. it's the first one in the list.}
		Game_Sprites := B^.Next;
		B^.Next := Nil;
		DisposeSpriteList(B);
		end
	else begin
		{We found the attribute we want to delete and have another}
		{one standing before it in line. Go to work.}
		A^.next := B^.next;
		B^.Next := Nil;
		DisposeSpriteList(B);
	end;

	LMember := Nil;
end;

procedure DrawSprite( Spr: SensibleSpritePtr; MyDest: TSDL_Rect; Frame: Integer );
	{ Draw a sensible sprite. }
begin
	{ First make sure that we have some valid sprite data... }
	if ( Spr <> Nil ) and ( Spr^.Img <> Nil ) then begin
		{ All the info checks out. Print it. }
		DrawAnimImage( Spr^.Img , Game_Screen , Spr^.W , Spr^.H , Frame , MyDest );
	end;
end;

procedure DrawSprite( Spr: SensibleSpritePtr; MyCanvas: PSDL_Surface; MyDest: TSDL_Rect; Frame: Integer );
	{ Draw a sensible sprite to an arbitrary canvas. }
begin
	{ First make sure that we have some valid sprite data... }
	if ( Spr <> Nil ) and ( Spr^.Img <> Nil ) then begin
		{ All the info checks out. Print it. }
		DrawAnimImage( Spr^.Img , MyCanvas , Spr^.W , Spr^.H , Frame , MyDest );
	end;
end;

function LocateSprite( const Name,Color: String; W,H: Integer ): SensibleSpritePtr;
	{ Try to locate the requested sprite in the requested color. If the sprite }
	{ is already loaded, then return its address. If not, load it and color it. }
var
	S: SensibleSpritePtr;
begin
	{ First, find the sprite. If by some strange chance it hasn't been }
	{ loaded yet, load it now. }
	S := LocateSpriteByNameColor( Name , Color );
	if S = Nil then S := AddSprite( Name , Color , W , H );

	{ Set the width and height fields. }
	S^.W := W;
	S^.H := H;

	LocateSprite := S;
end;

function LocateSprite( const Name: String; W,H: Integer ): SensibleSpritePtr;
	{ Find the requested sprite, either in memory or from disk. }
var
	S: SensibleSpritePtr;
begin
	{ First, find the sprite. If by some strange chance it hasn't been }
	{ loaded yet, load it now. }
	LocateSprite := LocateSprite( Name , '' , W , H );
end;

Procedure CleanSpriteList;
	{ Go through the sprite list and remove those sprites we aren't likely to }
	{ need immediately... i.e., erase those ones which have a COLOR string defined. }
var
	S,S2: SensibleSpritePtr;
begin
	S := Game_Sprites;
	while S <> Nil do begin
		S2 := S^.Next;

		if S^.Color <> '' then begin
			RemoveSprite( S );
		end;

		S := S2;
	end;
end;

function RPGKey: Char;
	{ Read a readable key from the keyboard and return its ASCII value. }
	{ This function will always return within a close approximation of 30ms }
	{ from the last time it was called. It will also update the array of }
	{ keypresses. }
var
	a: String;
	event : TSDL_Event;
	Procedure ProcessThatEvent;
		{ An event has been recieved. Process it. }
    var
        width,height: Integer;
	begin
		if event.type_ = SDL_KEYDOWN then begin
			{ Check to see if it was an ASCII character we recieved. }
			case event.key.keysym.sym of
				SDLK_Up,SDLK_KP8:	a := RPK_Up;
				SDLK_Down,SDLK_KP2:	a := RPK_Down;
				SDLK_Left,SDLK_KP4:	a := RPK_Left;
				SDLK_Right,SDLK_KP6:	a := RPK_Right;
				SDLK_KP7:		a := RPK_UpLeft;
				SDLK_KP9:		a := RPK_UpRight;
				SDLK_KP1:		a := RPK_DownLeft;
				SDLK_KP3:		a := RPK_DownRight;
				SDLK_Backspace:		a := #8;
				SDLK_KP_Enter:		a := #10;
				SDLK_KP5:		a := '5';
			else
				if( event.key.keysym.unicode <  $80 ) and ( event.key.keysym.unicode > 0 ) then begin
					a := Char( event.key.keysym.unicode );
				end;
			end;

		end else if ( event.type_ = SDL_MOUSEButtonDown ) then begin
			{ Return a mousebutton event, and call DoFlip to set the mouse position }
			{ variables. }
			if event.button.button = SDL_BUTTON_LEFT then begin
				a := RPK_MouseButton;
			end else if event.button.button = SDL_BUTTON_RIGHT then begin
				a := RPK_RightButton;
			end;

        end else if event.type_ = SDL_VIDEORESIZE then begin
            width := event.resize.w;
            if width < 800 then width := 800;
            height := event.resize.h;
            if height < 600 then height := 600;
            Game_Screen := SDL_SetVideoMode(width, height, 0, SDL_HWSURFACE or SDL_DoubleBuf or SDL_RESIZABLE );

		end;
	end;
var
	D: QWord;
	PResult: Integer;
begin
	if Minimal_Screen_Refresh then begin
		a := RPK_TimeEvent;
		repeat
			if SDL_WaitEvent( @event ) = 1 then begin
				ProcessThatEvent;
			end;
		until a <> RPK_TimeEvent;
	end else begin
		{ Go through the accumulated events looking for good ones. }
		a := RPK_TimeEvent;
		repeat
			PResult := SDL_PollEvent( @event );
			if PResult = 1 then begin
				{ See if this event is a keyboard one... }
				ProcessThatEvent;
			end;
		until ( PResult <> 1 ) or ( a <> RPK_TimeEvent );

		{ If necessary, do a delay. }
		if SDL_GetTicks < ( Last_Clock_Update + 20 ) then begin
			D := Last_Clock_Update + 30 - SDL_GetTicks;
			SDL_Delay( D );
		end;
		Last_Clock_Update := SDL_GetTicks + 30;
	end;

	RK_KeyState := SDL_GetKeyState( RK_NumKeys );
	SDL_GetMouseState( Mouse_X , Mouse_Y );

	if a <> '' then RPGKey := a[1]
	else RPGKey := 'Z';
end;

Procedure ClrZone( const Z: TSDL_Rect );
	{ Clear the specified screen zone. }
begin
	SDL_FillRect( game_screen , @Z , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 0 ) );
end;

Procedure ClrScreen;
	{ Clear the specified screen zone. }
begin
	SDL_FillRect( game_screen , Nil , SDL_MapRGBA( Game_Screen^.Format , 0 , 0 , 255 , 0 ) );
end;

Function TextLength( F: PTTF_Font; msg: String ): LongInt;
	{ Determine how long "msg" will be using the default "game_font". }
var
	pmsg: PChar;	{ Gotta convert to pchar, pain in the ass... }
	W,Y: LongInt;	{ W means width I guess... Y is anyone's guess. Height? }
begin
	{ Convert the string to a pchar. }
	pmsg := QuickPCopy( msg );

	{ Call the alleged size calculation function. }
	TTF_SizeText( F , pmsg , W , Y );

	{ get rid of the PChar, since it's served its usefulness. }
	Dispose( pmsg );

	TextLength := W;
end;

Procedure GetNextLine( var TheLine , msg , NextWord: String; Width: Integer; MyFont: PTTF_Font );
	{ Get a line of text of maximum width "Width". }
var
	LC: Boolean;	{ Loop Condition. So I wasn't very creative when I named it, so what? }
begin
	{ Loop condition starts out as TRUE. }
	LC := True;

	{ Start building the line. }
	repeat
		NextWord := ExtractWord( Msg );

		if TextLength( MyFont , THEline + ' ' + NextWord) < Width then
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

end;

Function PrettyPrint( msg: string; Width: Integer; var FG: TSDL_Color; DoCenter: Boolean; MyFont: PTTF_Font ): PSDL_Surface;
	{ Create a SDL_Surface containing all the text within "msg" formatted }
	{ in lines of no longer than "width" pixels. Sound simple? Mostly just }
	{ tedious, I'm afraid. }
var
	SList,SA: SAttPtr;
	S_Total,S_Temp: PSDL_Surface;
	MyDest: SDL_Rect;
	pline: PChar;
	NextWord: String;
	THELine: String;	{The line under construction.}
begin
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	if msg = '' then Exit( Nil );

	{THELine = The first word in this iteration}
	THELine := ExtractWord( msg );
	NextWord := '';
	SList := Nil;

	{Start the main processing loop.}
	while TheLine <> '' do begin
		GetNextLine( TheLine , msg , NextWord , Width, MyFont );

		{ Output the line. }
		{ Next append it to whatever has already been created. }
		StoreSAtt( SList , TheLine );

		{ Prepare for the next iteration. }
		TheLine := NextWord;
	end; { while TheLine <> '' }

	{ Create a bitmap for the message. }
	if SList <> Nil then begin
		{ Create a big bitmap to hold everything. }
{		S_Total := SDL_CreateRGBSurface( SDL_SWSURFACE , width , TTF_FontLineSkip( MyFont ) * NumSAtts( SList ) , 16 , 0 , 0 , 0 , 0 );
}		S_Total := SDL_CreateRGBSurface( SDL_SWSURFACE , width , TTF_FontLineSkip( MyFont ) * NumSAtts( SList ) , 32 , $FF000000 , $00FF0000 , $0000FF00 , $000000FF );
		MyDest.X := 0;
		MyDest.Y := 0;

		{ Add each stored string to the bitmap. }
		SA := SList;
		while SA <> Nil do begin
			pline := QuickPCopy( SA^.Info );
			S_Temp := TTF_RenderText_Solid( MyFont , pline , fg );
{$IFDEF LINUX}
			SDL_SetColorKey( S_Temp , SDL_SRCCOLORKEY , SDL_MapRGB( S_Temp^.Format , 0 , 0, 0 ) );
{$ENDIF}

			Dispose( pline );

			{ We may or may not be required to do centering of the text. }
			if DoCenter then begin
				MyDest.X := ( Width - TextLength( MyFont , SA^.Info ) ) div 2;
			end else begin
				MyDest.X := 0;
			end;

			SDL_BlitSurface( S_Temp , Nil , S_Total , @MyDest );
			SDL_FreeSurface( S_Temp );
			MyDest.Y := MyDest.Y + TTF_FontLineSkip( MyFont );
			SA := SA^.Next;
		end;
		DisposeSAtt( SList );

	end else begin
		S_Total := Nil;
	end;


	PrettyPrint := S_Total;
end;

Function PrettyPrint( msg: string; Width: Integer; var FG: TSDL_Color; DoCenter: Boolean ): PSDL_Surface;
    { Overloaded version of above, using default font. }
begin
    PrettyPrint := PrettyPrint( msg, width, FG, DoCenter, Game_Font );
end;


Procedure CMessage( msg: String; Z: TSDL_Rect; C: TSDL_Color; MyFont: PTTF_Font );
	{ Print a message to the screen, centered in the requested rect. }
	{ Clear the specified zone before doing so. }
var
	MyText: PSDL_Surface;
	MyDest: TSDL_Rect;
begin
	MyText := PrettyPrint( msg , Z.W , C , True, MyFont );
	if MyText <> Nil then begin
		MyDest := Z;
		MyDest.Y := MyDest.Y + ( Z.H - MyText^.H ) div 2;
		SDL_SetClipRect( Game_Screen , @Z );
		SDL_BlitSurface( MyText , Nil , Game_Screen , @MyDest );
		SDL_FreeSurface( MyText );
		SDL_SetClipRect( Game_Screen , Nil );
	end;
end;

Procedure CMessage( msg: String; Z: TSDL_Rect; C: TSDL_Color );
    { Use the default font. }
begin
    CMessage( msg, Z, C, Game_Font );
end;

Procedure CMessage( msg: String; DZ: DynamicRect; C: TSDL_Color );
    { Print a message centered in a DynamicRect. }
begin
    CMessage( msg, DZ.GetRect(), C );
end;

Procedure GameMSG( msg: string; Z: TSDL_Rect; C: TSDL_Color; MyFont: PTTF_Font );
    { Print a game message. }
var
	MyText: PSDL_Surface;
begin
	MyText := PrettyPrint( msg , Z.W , C , True, MyFont );
	if MyText <> Nil then begin
		SDL_SetClipRect( Game_Screen , @Z );
		SDL_BlitSurface( MyText , Nil , Game_Screen , @Z );
		SDL_FreeSurface( MyText );
		SDL_SetClipRect( Game_Screen , Nil );
	end;
end;

Procedure GameMSG( msg: string; Z: TSDL_Rect; C: TSDL_Color );
    { Overloaded version using default font. }
begin
    GameMsg( msg, Z, C, Game_Font );
end;

Procedure GameMSG( msg: string; DZ: DynamicRect; C: TSDL_Color );
	{ As above, but no pageflip. }
begin
    GameMsg( msg, DZ.GetRect(), C );
end;

Function IsMoreKey( A: Char ): Boolean;
	{ Return TRUE if A is a "more" key, that should skip to the next message in a list. }
begin
	IsMoreKey := ( A = ' ' ) or ( A = #27 ) or ( A = RPK_MouseButton );
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

Procedure ClearExtendedBorder( Dest: TSDL_Rect );
	{ Draw the inner box for border displays. }
begin
	Dest.X := Dest.X - 1;
	Dest.Y := Dest.Y - 1;
	Dest.W := Dest.W + 2;
	Dest.H := Dest.H + 2;
	SDL_FillRect( game_screen , @Dest , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 0 ) );
end;

Function GetStringFromUser( Prompt: String; ReDrawer: RedrawProcedureType ): String;
	{ Does what it says. }
const
	AllowableCharacters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ 1234567890()-=_+,.?"*';
	MaxInputLength = 80;
var
	A: Char;
	it: String;
	MyBigBox,MyInputBox,MyDest: TSDL_Rect;
begin
	{ Initialize string. }
	it := '';

	repeat
        MyBigBox := ZONE_TextInputBigBox.GetRect();
        MyInputBox := ZONE_TextInput.GetRect();

		{ Set up the display. }
		if ReDrawer <> Nil then ReDrawer;
		InfoBox( MyBigBox );
		{SDL_FillRect( game_screen , @MyBigBox , SDL_MapRGB( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B ) );}
		SDL_FillRect( game_screen , @MyInputBox , SDL_MapRGB( Game_Screen^.Format , StdBlack.R , StdBlack.G , StdBlack.B ) );

		CMessage( Prompt , ZONE_TextInputPrompt.GetRect() , StdWhite );
		CMessage( it , MyInputBox , InfoGreen );
		MyDest.Y := MyInputBox.Y + 2;
		MyDest.X := MyInputBox.X + ( MyInputBox.W div 2 ) + ( TextLength( Game_Font , it ) div 2 );
		DrawSprite( Cursor_Sprite , MyDest , ( Animation_Phase div 2 ) mod 4 );

		DoFlip;
		A := RPGKey;

		if ( A = #8 ) and ( Length( it ) > 0 ) then begin
			it := Copy( it , 1 , Length( it ) - 1 );
		end else if ( Pos( A , AllowableCharacters ) > 0 ) and ( Length( it ) < MaxInputLength ) then begin
			it := it + A;
		end;
	until ( A = #13 ) or ( A = #27 );

	GetStringFromUser := it;
end;


Function MoreHighFirstLine( LList: SAttPtr ): Integer;
	{ Determine the highest possible FirstLine value. }
var
	it: Integer;
begin
	it := NumSAtts( LList ) - ( ZONE_MoreText.H  div  TTF_FontLineSkip( game_font ) ) + 1;
	if it < 1 then it := 1;
	MoreHighFirstLine := it;
end;

Procedure MoreText( LList: SAttPtr; FirstLine: Integer; ReDrawer: RedrawProcedureType );
	{ Browse this text file across the majority of the screen. }
	{ Clear the screen upon exiting, though restoration of the }
	{ previous display is someone else's responsibility. }
	Procedure DisplayTextHere( const MyZone: TSDL_Rect );
	var
		T: Integer;
		MyDest: TSDL_Rect;
		MyImage: PSDL_Surface;
		CLine: SAttPtr;	{ Current Line }
		PLine: PChar;
	begin
		{ Set the clip area. }
		SDL_SetClipRect( Game_Screen , @MyZone );
		MyDest := MyZone;

		{ Error check. }
		if FirstLine < 1 then FirstLine := 1
		else if FirstLine > MoreHighFirstLine( LList ) then FirstLine := MoreHighFirstLine( LList );

		CLine := RetrieveSATt( LList , FirstLine );
		for t := 1 to ( MyZone.H  div  TTF_FontLineSkip( game_font ) ) do begin
			if CLine <> Nil then begin
				pline := QuickPCopy( CLine^.Info );
				MyImage := TTF_RenderText_Solid( game_font , pline , NeutralGrey );
				Dispose( pline );
                {$IFDEF LINUX}
		        SDL_SetColorKey( MyImage , SDL_SRCCOLORKEY , SDL_MapRGB( MyImage^.Format , 0 , 0, 0 ) );
                {$ENDIF}

				SDL_BlitSurface( MyImage , Nil , Game_Screen , @MyDest );
				SDL_FreeSurface( MyImage );
				MyDest.Y := MyDest.Y + TTF_FontLineSkip( game_font );
				CLine := CLine^.Next;
			end;
		end;

        if (Animation_Phase div 10 mod 2) = 1 then begin
            if FirstLine > 1 then begin
                MyDest.X := MyZone.X + MyZone.W - 16;
                MyDest.Y := MyZone.Y;
                QuickText('+', MyDest, MenuSelect, Game_Font );
            end;
            if CLine <> Nil then begin
                MyDest.X := MyZone.X + MyZone.W - 16;
                MyDest.Y := MyZone.Y + MyZone.H - TTF_FontLineSkip( game_font );
                QuickText('+', MyDest, MenuSelect, Game_Font );
            end;
        end;

		{ Restore the clip area. }
		SDL_SetClipRect( Game_Screen , Nil );
		DoFlip;
	end;
var
	A: Char;
    MyPromptZone,MyTextZone: TSDL_Rect;
begin
	repeat
		{ Get input from user. }
		A := RPGKey;

		{ Possibly process this input. }
		if A = RPK_Down then begin
			Inc( FirstLine );
		end else if A = RPK_Up then begin
			Dec( FirstLine );
        end else if A = RPK_TimeEvent then begin
            MyTextZone := ZONE_MoreText.GetRect();
            MyPromptZone := ZONE_MorePrompt.GetRect();
            if Redrawer <> Nil then Redrawer();
            InfoBox( MyTextZone );
            InfoBox( MyPromptZone );
	        CMessage( MsgString( 'MORETEXT_Prompt' ) , MyPromptZone , InfoGreen );

	        { Display the screen. }
	        DisplayTextHere( MyTextZone );
		end;

	until ( A = #27 ) or ( A = 'Q' ) or ( A = #8 );
end;

Procedure RedrawConsole;
	{ Redraw the console. Yay! }
var
	SL: SAttPtr;
	MyZone,MyDest: TSDL_Rect;
	NumLines,LineNum: Integer;
begin
	{Clear the message area, and set clipping bounds.}
    MyZone := ZONE_Dialog.GetRect();
	InfoBox( MyZone );
	SDL_SetClipRect( Game_Screen , @MyZone );

	MyDest := MyZone;
	NumLines := ( MyZone.H div TTF_FontLineSkip( game_font ) ) + 1;
	LineNum := NumLines;
	SL := RetrieveSAtt( Console_History , NumSAtts( Console_History ) - NumLines + 1 );
	if SL = Nil then begin
		SL := Console_History;
		LineNum := NumSAtts( Console_History );
	end;

	while LineNum > 0 do begin
		{ Set the coords for this line. }
		MyDest.X := MyZone.X;
		MyDest.Y := MyZone.Y + MyZone.H - LineNum * TTF_FontLineSkip( game_font );

		{ Output the line. }
		QuickText( SL^.Info , MyDest , InfoGreen , Game_font );

		Dec( LineNum );
		SL := SL^.Next;
	end;

	{ Restore the clip zone to the full screen. }
	SDL_SetClipRect( Game_Screen , Nil );
end;

Procedure DialogMSG( msg: string );
	{ Print a message in the scrolling dialog box, }
	{ then store the line in Console_History. }
	{ Don't worry about screen output since the console will be redrawn the next time }
	{ the screen updates. }
var
	NextWord: String;
	THELine: String;	{The line under construction.}
	SA: SAttPtr;
begin
	{ CLean up the message a bit. }
	DeleteWhiteSpace( msg );
	if msg = '' then Exit;
	msg := '> ' + Msg;

	{THELine = The first word in this iteration}
	THELine := ExtractWord( msg );
	NextWord := '';

	{Start the main processing loop.}
	while TheLine <> '' do begin
		GetNextLine( TheLine , msg , NextWord , ZONE_Dialog.w, Game_Font );

		{ If appropriate, save the line. }
		if TheLine <> '' then begin
			if NumSAtts( Console_History ) >= Console_History_Length then begin
				SA := Console_History;
				RemoveSAtt( Console_History , SA );
			end;
			StoreSAtt( Console_History , TheLine );
		end;


		{ Prepare for the next iteration. }
		TheLine := NextWord;
	end; { while TheLine <> '' }
end;

Procedure DrawBPBorder;
	{ Draw borders for the backpack display. }
var
    MyRect: TSDL_Rect;
begin
    MyRect := ZONE_BPTotal.GetRect();
	ClearExtendedBorder( MyRect );
	SDL_FillRect( game_screen , @MyRect , SDL_MapRGB( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B ) );
	ClearExtendedBorder( ZONE_EqpMenu.GetRect() );
	ClearExtendedBorder( ZONE_InvMenu.GetRect() );
	ClearExtendedBorder( ZONE_BPHeader.GetRect() );
	ClearExtendedBorder( ZONE_BackpackInstructions.GetRect() );
	ClearExtendedBorder( ZONE_BPInfo.GetRect() );
    FillRectWithSprite( ZONE_BPInfo.GetRect(), Infobox_Backdrop, 0 );
end;



Procedure DrawGetItemBorder;
	{ Draw borders for the get item display. }
begin
	InfoBox( ZONE_GetItemMenu );
end;


Procedure SetupInteractDisplay( TeamColor: TSDL_Color );
	{ Draw the display for the interaction interface. }
var
    MyDest: TSDL_Rect;
begin
    MyDest := ZONE_InteractTotal.GetRect();
	ClearExtendedBorder( MyDest );
	SDL_FillRect( game_screen , @MyDest , SDL_MapRGB( Game_Screen^.Format , TeamColor.R , TeamColor.G , TeamColor.B ) );
	ClearExtendedBorder( ZONE_InteractStatus.GetRect() );
	ClearExtendedBorder( ZONE_InteractMsg.GetRect() );
	ClearExtendedBorder( ZONE_InteractMenu.GetRect() );
	ClearExtendedBorder( ZONE_InteractPhoto.GetRect() );
	ClearExtendedBorder( ZONE_InteractInfo.GetRect() );
end;

Procedure SetupServicesDisplay;
	{ Draw the display for the services interface. }
begin
    InfoBox( ZONE_ShopTop.GetRect() );
    InfoBox( ZONE_ShopBottom.GetRect() );
    InfoBox( ZONE_ShopInfo.GetRect() );
    InfoBox( ZONE_ShopCash.GetRect() );
end;

Procedure SetupFHQDisplay;
	{ Draw the display for the services interface. }
begin
    InfoBox( ZONE_FieldHQMenu.GetRect() );
    InfoBox( ZONE_ItemsInfo.GetRect() );
end;

Procedure SetupMemoDisplay;
	{ Set up the memo display. }
begin
	InfoBox( ZONE_MemoTotal );
end;

Procedure DrawMonologueBorder;
	{ Draw the border for the monologue. }
begin
	InfoBox( ZONE_MonologueTotal.getRect() );
end;

Function GrowRect( MyRect: TSDL_Rect; GrowX,GrowY: Integer ): TSDL_Rect;
    { Expand this rect by the requested amount, remaining centered on the }
    { original rect. }
begin
    MyRect.x := MyRect.x - GrowX;
    MyRect.y := MyRect.y - GrowY;
    MyRect.w := MyRect.w + 2 * GrowX;
    MyRect.h := MyRect.h + 2 * GrowY;
    GrowRect := MyRect;
end;

Procedure FillRectWithSprite( MyRect: TSDL_Rect; MySprite: SensibleSpritePtr; MyFrame,OffX,OffY: Integer );
    { Fill this area of the screen perfectly with the provided sprite. }
var
    MyDest: TSDL_Rect;
    X,Y,GridW,GridH: Integer;
begin
	GridW := MyRect.W div MySprite^.W + 1;
	GridH := MyRect.H div MySprite^.H + 1;
	SDL_SetClipRect( Game_Screen , @MyRect );

    MyRect.X := MyRect.X + (OffX mod MySprite^.W) - MySprite^.W;
    MyRect.Y := MyRect.Y + (OffY mod MySprite^.H) - MySprite^.H;

	{ Draw the backdrop. }
	for X := 0 to GridW do begin
		MyDest.X := MyRect.X + X * MySprite^.W;
		for Y := 0 to GridH do begin
			MyDest.Y := MyRect.Y + Y * MySprite^.H;
			DrawSprite( MySprite , MyDest , MyFrame );
		end;
	end;

	SDL_SetClipRect( Game_Screen , Nil );
end;

Procedure FillRectWithSprite( MyRect: TSDL_Rect; MySprite: SensibleSpritePtr; MyFrame: Integer );
    { Do a FillRect with offset 0,0. }
begin
    FillRectWithSprite( MyRect, MySprite, MyFrame, 0, 0 );
end;

Procedure InfoBox( MyBox: TSDL_Rect );
	{ Do a box for drawing something else inside of. }
const
	tex_width = 16;
	border_width = tex_width div 2;
	half_dat = border_width div 2;
var
    MyFill,Dest: TSDL_Rect;
	X0,Y0,W32,H32,X,Y: Integer;
begin
    { Fill the middle of the box with the backdrop. }
    MyFill := GrowRect( MyBox, 4, 4 );
    FillRectWithSprite( MyFill, Infobox_Backdrop, 0 );

    { Expand the rect to its full dimensions, and draw the outline. }
    MyFill := GrowRect( MyBox, 8, 8 );
	DrawSprite( Infobox_Border , MyFill , 0 );

    Dest.X := MyFill.X;
	Dest.Y := MyFill.Y + MyFill.H - 8;
	DrawSprite( Infobox_Border , Dest , 4 );

    Dest.X := MyFill.X + MyFill.W - 8;
	Dest.Y := MyFill.Y;
	DrawSprite( Infobox_Border , Dest , 3 );

    Dest.X := MyFill.X + MyFill.W - 8;
	Dest.Y := MyFill.Y + MyFill.H - 8;
	DrawSprite( Infobox_Border , Dest , 5 );

    MyFill := GrowRect( MyBox, 0, 8 );
	SDL_SetClipRect( Game_Screen , @MyFill );
	for X := 0 to ( MyFill.W div 8 + 1 ) do begin
		Dest.X := MyFill.X + X * 8;
		Dest.Y := MyFill.Y;
		DrawSprite( Infobox_Border , Dest , 1 );
		Dest.Y := MyFill.Y + MyFill.H - 8;
		DrawSprite( Infobox_Border , Dest , 1 );
	end;
    MyFill := GrowRect( MyBox, 8, 0 );
	SDL_SetClipRect( Game_Screen , @MyFill );
	for Y := 0 to ( MyFill.H div 8 + 1 ) do begin
		Dest.Y := MyFill.Y + Y * 8;
		Dest.X := MyFill.X;
		DrawSprite( Infobox_Border , Dest , 2 );
		Dest.X := MyFill.X + MyFill.W - 8;
		DrawSprite( Infobox_Border , Dest , 2 );
	end;
	SDL_SetClipRect( Game_Screen , Nil );
end;

Procedure InfoBox( MyBox: DynamicRect );
	{ Do a box for drawing something else inside of. }
begin
    InfoBox( MyBox.GetRect() );
end;

Procedure Idle_Display;
	{ Something is happening that's likely to take a long time. Load an idle }
	{ image from disk and show it to the user. }
var
	FList: SAttPtr;
	PFName: PChar;
	MyImage: PSDL_Surface;
	MyDest: TSDL_Rect;
begin
	{ Create a list of all the images in the idle_pics drawer. }
	FList := CreateFileList( Graphics_Directory + 'poster_*.*' );
	if FList <> Nil then begin
		{ Load one at random, and display it. }
		PFName := QuickPCopy( Graphics_Directory + SelectRandomSAtt( FList )^.Info );
		MyImage := IMG_Load( PFName );
		SDL_BlitSurface( MyImage , Nil , Game_Screen , Nil );
		DoFlip;
		SDL_FreeSurface( MyImage );
		Dispose( PFName );
		DisposeSAtt( FList );
	end;
end;

Procedure SetupArenaDisplay;
	{ Draw the borders for all the arena-mode menus. }
begin
	SDL_FillRect( game_screen , Nil , SDL_MapRGBA( Game_Screen^.Format , BorderBlue.R , BorderBlue.G , BorderBlue.B , 255 ) );
	InfoBox( ZONE_ArenaInfo );
	InfoBox( ZONE_ArenaPilotMenu );
	InfoBox( ZONE_ArenaMechaMenu );
	InfoBox( ZONE_PCStatus );
	RedrawConsole;
end;

Procedure SetupArenaMissionMenu;
	{ Set up the menu from which the mission will be selected in arena mode. }
begin
	InfoBox( ZONE_MemoTotal );
{	ClearExtendedBorder( ZONE_SAMText );
	ClearExtendedBorder( ZONE_SAMMenu );}
end;

Procedure SetupConcertDisplay;
	{ Set up the concert display. }
begin
	InfoBox( ZONE_ConcertTotal );
{	ClearExtendedBorder( ZONE_ConcertAudience );
	ClearExtendedBorder( ZONE_ConcertCaption );
	ClearExtendedBorder( ZONE_ConcertMenu );
	ClearExtendedBorder( ZONE_ConcertDesc );
	ClearExtendedBorder( ZONE_ConcertPhoto );}
end;

Procedure SetupTitleScreenDisplay;
	{ Draw the title screen. }
var
    MyRect: TSDL_Rect;
begin
    MyRect.X := 0;
    MyRect.Y := 0;
    MyRect.W := Game_Screen^.W;
    MyRect.H := Game_Screen^.H;
    FillRectWithSprite(MyRect,Title_Stars,0,Animation_Phase,Animation_Phase div 2);
    DrawSprite( Title_Logo, ZONE_TitleLogo.GetRect(), 0 );
    InfoBox( ZONE_Title_Screen_Menu );
	{SDL_BlitSurface( Title_Screen^.Img , Nil , Game_Screen , Nil );}

end;

initialization

	SDL_Init( SDL_INIT_VIDEO );

	if DoFullScreen then begin
		Game_Screen := SDL_SetVideoMode(ScreenWidth, ScreenHeight, 32, SDL_DOUBLEBUF or SDL_FULLSCREEN );
	end else begin
{		Game_Screen := SDL_SetVideoMode(ScreenWidth, ScreenHeight, 0, SDL_DOUBLEBUF or SDL_HWSURFACE );}
		Game_Screen := SDL_SetVideoMode(ScreenWidth, ScreenHeight, 0, SDL_HWSURFACE or SDL_DoubleBuf or SDL_RESIZABLE );
	end;

	if Ersatz_Mouse then SDL_ShowCursor( SDL_Disable );

	ClrScreen;
	SDL_SetColorKey( Game_Screen , SDL_SRCCOLORKEY or SDL_RLEACCEL , SDL_MapRGB( Game_Screen^.Format , 0 , 0 , 255 ) );

        SDL_EnableUNICODE( 1 );
	SDL_EnableKeyRepeat( KEY_REPEAT_DELAY , KEY_REPEAT_INTERVAL );

	TTF_Init;

	Game_Font := TTF_OpenFont( Graphics_Directory + 'VeraBd.ttf' , FontSize );
	Small_Font := TTF_OpenFont( Graphics_Directory + 'VeraBd.ttf' , SmallFontSize );
	Info_Font := TTF_OpenFont( Graphics_Directory + 'VeraMoBd.ttf' , 11 );

	Game_Sprites := Nil;

	Cursor_Sprite := LocateSprite( 'cursor.png' , 8 , 16 );
	Title_Screen := LocateSprite( 'title_screen.png' , 800 , 600 );
    Title_Stars := LocateSprite( 'sys_titlescreenbackground.png' , 512 , 512 );
    Title_Logo := LocateSprite( 'sys_logo.png' , 623 , 161 );
	Ersatz_Mouse_Sprite := LocateSprite( 'ersatz_mouse.png' , 16 , 16 );

	Console_History := Nil;

	Last_Clock_Update := 0;

	if Splash_Screen_At_Start then begin
		Randomize();
		Idle_Display;
	end;

	SDL_WM_SetCaption( WindowName , IconName );

	Infobox_Border := LocateSprite( 'sys_boxborder.png' , 8 , 8 );
	Infobox_Backdrop := LocateSprite( 'sys_boxbackdrop.png' , 16 , 16 );

	if Transparent_Interface then SDL_SetAlpha( Infobox_Backdrop^.Img , SDL_SRCAlpha , 224 );


finalization

	DisposeSAtt( Console_History );
	DisposeSpriteList( Game_Sprites );
	TTF_CloseFont( Game_Font );
	TTF_CloseFont( Small_Font );
	TTF_Quit;

	SDL_FreeSurface( Game_Screen );
	SDL_Quit;
end.
