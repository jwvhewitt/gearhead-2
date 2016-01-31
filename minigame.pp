unit minigame;
	{ This unit will hold descriptions for any minigames that may be used. }
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

uses gears,locale,minitype;


Function DoConcert( GB: GameBoardPtr; PC: GearPtr; AudienceSize,SkTarget: Integer ): Integer;

implementation

uses	arenacfe,action,ghchars,texutil,ui4gh,
{$IFDEF ASCII}
	vidgfx,vidmenus,vidinfo;
{$ELSE}
	sdlgfx,sdlmenus,sdlinfo;
{$ENDIF}

var
	MG_GB: GameBoardPtr;
	MG_PC: GearPtr;
	MG_Prompt: String;
	MG_Audience: AudienceListPtr;
	MG_Menu: RPGMenuPtr;

Procedure ConcertRedraw;
	{ The screen redraw routine for concerts. }
var
	N: Integer;
begin
	CombatDIsplay( MG_GB );
	SetupConcertDisplay;
	ConcertStatus( MG_PC , MG_Audience^ );
	GameMsg( MG_Prompt , ZONE_ConcertCaption , InfoGreen );
	if MG_Menu <> Nil then begin
		N := CurrentMenuItemValue( MG_Menu );
		case N of
		CMG_Trait_Emotion: 	CMessage( 'Emotion' , ZONE_ConcertDesc , PlayerBlue );
		CMG_Trait_Beat: 	CMessage( 'Beat' , ZONE_ConcertDesc , EnemyRed );
		CMG_Trait_Melody: 	CMessage( 'Melody' , ZONE_ConcertDesc , MelodyYellow );
		end;
	end;
end;

Function DoConcert( GB: GameBoardPtr; PC: GearPtr; AudienceSize,SkTarget: Integer ): Integer;
	{ The PC is going to hold a concert. Return the final concert score. }
	{ AudienceSize tells how big the audience is. It should be in the range }
	{ of 3 to 10. }
	{ SkTarget is the basic skill target roll for performance rolls. }
	{ The score returned can be read as being in the range 0-100, but scores }
	{ above 100 are also possible. Just accept that 100 is a "flawless" score. }
var
	AL: AudienceList;
	Function CreateSongMenu: RPGMenuPtr;
		{ Create the song menu. }
	var
		RPM: RPGMenuPtr;
	begin
		RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ConcertMenu );
		RPM^.Mode := RPMNoCancel;
		AddRPGMenuItem( RPM , 'Emotion Song' , CMG_Trait_Emotion );
		AddRPGMenuItem( RPM , 'Beat Song' , CMG_Trait_Beat );
		AddRPGMenuItem( RPM , 'Melody Song' , CMG_Trait_Melody );
		CreateSongMenu := RPM;
	end;
	Function NumAudience: Integer;
		{ Return the number of mobs in the audience. }
	var
		N,T: Integer;
	begin
		N := 0;
		for t := 1 to MaxAudienceSize do begin
			if AL[t].Mood > 0 then Inc( N );
		end;
		NumAudience := N;
	end;
	Function MGScore: Integer;
		{ Return the score for the current concert situation. }
	const
		PointValue: Array [0..Num_Audience_Moods] of Integer = (
		-150,0,10,30,60,100,150
		);
	var
		T,N,Total: Integer;
	begin
		N := 0;
		Total := 0;
		for t := 1 to MaxAudienceSize do begin
			if AL[t].Mood >= 0 then begin
				Inc( N );
				Total := Total + PointValue[ AL[t].Mood ];
			end;
		end;
		if N < 1 then begin
			Total := 0;
			N := 1;
		end;
		if Total < 0 then Total := 0;
		MGScore := Total div N;
	end;
	Procedure ApplySong( SongTrait: Integer );
		{ The PC has selected what song to play. Make skill rolls for }
		{ all the audience mobs. If the skill roll beats the target, }
		{ the mob's mood increases. If the skill roll is less than }
		{ half the target, the mob's mood decreases... and maybe they }
		{ will walk out. }
	const
		Audience_X_Song: Array [0..2,0..2] of Integer = (
		(-3, 2,10),
		(10,-3, 2),
		( 2,10,-3)
		);
	var
		T,MobTarget,SkRoll: Integer;
	begin
		for t := 1 to MaxAudienceSize do begin
			if AL[t].Mood > 0 then begin
				MobTarget := SkTarget + Audience_X_Song[ AL[t].Trait , SongTrait ] + Abs( AL[t].Mood - 3 );
				if MobTarget < 5 then MobTarget := 5;
				SkRoll := SkillRoll( GB , PC , NAS_Performance , STAT_Charm , MobTarget , 0 , True , True );
				if SkRoll > MobTarget then begin
					if AL[t].Mood < Num_Audience_Moods then Inc( AL[t].Mood );
				end else if SkRoll <= ( MobTarget div 2 ) then begin
					Dec( AL[t].Mood );
				end;
			end;
		end;
	end;
var
	T,Song,A0,S0,S1: Integer;
	RPM: RPGMenuPtr;
begin
	{ Initialize the display values. }
	MG_GB := GB;
	MG_PC := PC;
	MG_Audience := @AL;
	MG_Prompt := MsgString( 'CONCERT_Begin' );

	{ Range check. }
	if AudienceSize < 3 then AudienceSize := 3
	else if AudienceSize > MaxAudienceSize then AudienceSize := MaxAudienceSize;
	if SkTarget < 10 then SkTarget := 10;

	{ Initialize the audience. }
	for t := 1 to MaxAudienceSize do begin
		if T <= AudienceSize then begin
			AL[t].Mood := 3 + Random( 2 );
			AL[t].Trait := Random( 3 );
		end else begin
			AL[t].Mood := MOOD_Absent;
		end;
	end;

	{ Create the song menu. }
	RPM := CreateSongMenu;
	MG_Menu := RPM;


	{ While the concert is still ongoing... }
	Song := 1;
	while ( NumAudience > 0 ) and ( Song < 6 ) do begin
		{ Request a song from the player. }

		{ Select a song. }
		T := SelectMenu( RPM , @ConcertRedraw );

		{ Make the skill rolls for this song. }
		{ First, store the scores, so as to provide a status update afterwards. }
		s0 := MGScore;
		a0 := NumAudience;
		ApplySong( T );
		S1 := MGScore;
		if NumAudience < a0 then begin
			MG_Prompt := MsgString( 'CONCERT_LoseAudience' );
		end else if s0 > S1 then begin
			MG_Prompt := MsgString( 'CONCERT_ConcertBomb' );
		end else if S0 < S1 then begin
			MG_Prompt := MsgString( 'CONCERT_ConcertGood' );
		end else begin
			MG_Prompt := MsgString( 'CONCERT_ConcertMeh' );
		end;
		MG_Prompt := MG_Prompt + ' ' + MsgString( 'CONCERT_Song' + BStr( Song ) );

		Inc( Song );
	end;

	DisposeRPGMenu( RPM );

	{ Show the concert outcome. }
	T := MGScore;
	RPM := CreateRPGMenu( MenuItem , MenuSelect , ZONE_ConcertMenu );
	MG_Menu := RPM;
	RPM^.Mode := RPMNoCancel;
	AddRPGMenuItem( RPM , MsgString( 'Exit' ) , 0 );
	if T > 110 then begin
		MG_Prompt := MsgString( 'CONCERT_TerrificEnd' );
	end else if T > 75 then begin
		MG_Prompt := MsgString( 'CONCERT_GoodEnd' );
	end else if T > 50 then begin
		MG_Prompt := MsgString( 'CONCERT_MediumEnd' );
	end else if T > 0 then begin
		MG_Prompt := MsgString( 'CONCERT_PoorEnd' );
	end else begin
		MG_Prompt := MsgString( 'CONCERT_TerribleEnd' );
	end;
	Song := SelectMenu( RPM , @ConcertRedraw );
	DisposeRPGMenu( RPM );

	{ The concert should take some time. }
	QuickTime( GB , Song * 600 + 100 + Random( 200 ) );

	DoConcert := T;
end;

end.
