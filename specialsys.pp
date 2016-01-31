unit specialsys;
	{ This unit handles special systems- GG_Usable gears. }
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


Function CanDoTransformation( GB: GameBoardPtr; mek,part: GearPtr ): Boolean;
Procedure DoTransformation( GB: GameBoardPtr; mek,part: GearPtr; ForReal: Boolean );
Function AIShouldTransform( GB: GameBoardPtr; mek,part: GearPtr ): Boolean;

Function CanLRScanHere( GB: GameBoardPtr; Part: GearPtr ): Boolean;
Function LongRangeScanEPCost( GB: GameBoardPtr; Part: GearPtr ): LongInt;
Procedure DoLongRangeScan( GB: GameBoardPtr; PC , Part: GearPtr );
Function AIShouldLRScan( GB: GameBoardPtr; mek,part: GearPtr ): Boolean;

implementation

uses movement,ghmodule,ability,ui4gh,texutil,gearutil,ghprop,action,
{$IFDEF ASCII}
	vidgfx
{$ELSE}
	sdlgfx
{$ENDIF}
	;

Function CanDoTransformation( GB: GameBoardPtr; mek,part: GearPtr ): Boolean;
	{ Return TRUE if the provided mecha can transform to the requested form }
	{ given the terrain conditions, or FALSE otherwise. }
var
	P: Point;
	MMFound: Boolean;
	T,Terrain: Integer;
begin
	{ Do the transformation first. }
	DoTransformation( GB , mek , part , False );

	{ Assume FALSE unless shown to be true. }
	MMFound := False;

	{ Determine the position of this mecha. }
	P := GearCurrentLocation( Mek );
	if OnTheMap( GB , P.X , P.Y ) then begin
		{ Check to make sure there's at least one movemode usable in the new form }
		{ which is not blocked in this tile. }
		Terrain := TileTerrain( GB , P.X , P.Y );

		for T := 1 to NumMoveMode do begin
			if BaseMoveRate( GB^.Scene , Mek , T ) > 0 then begin
				if not IsBlockingTerrainForMM( GB, Mek, Terrain, T ) then begin
					MMFound := True;
					Break;
				end;
			end;
		end;
	end;

	DoTransformation( GB , mek , part , False );
	CanDoTransformation := MMFound;
end;

Procedure DoTransformation( GB: GameBoardPtr; mek,part: GearPtr; ForReal: Boolean );
	{ This mecha is about to do a transformation. }
	{ The steps involved are: }
	{ - Swap the mecha form. }
	{ - Swap the mecha's visual representation. }
	{ - Transform limbs as needed. }
	{ - Set a new movement mode. }
	{ If this function is called, assume that the transformation is legal. }
	{ If FORREAL is true this is an actual transformation; if false, we're just }
	{ checking something out. }
var
	SpriteName,msg: String;
	Form: Integer;
	TMod: GearPtr;
begin
	{ Swap the form. }
	Form := mek^.s;
	mek^.S := Part^.V;
	Part^.V := Form;

	{ Swap the sprites. }
	SpriteName := SAttValue( mek^.SA , 'SDL_SPRITE' );
	SetSAtt( mek^.SA , 'SDL_SPRITE <' + SAttValue( part^.SA , 'SDL_SPRITE2' ) + '>' );
	SetSAtt( part^.SA , 'SDL_SPRITE2 <' + SpriteName + '>' );
	SpriteName := SAttValue( mek^.SA , 'CUTE_SPRITE' );
	SetSAtt( mek^.SA , 'CUTE_SPRITE <' + SAttValue( part^.SA , 'CUTE_SPRITE2' ) + '>' );
	SetSAtt( part^.SA , 'CUTE_SPRITE2 <' + SpriteName + '>' );

	{ Transform the limbs as needed. }
	TMod := Mek^.SubCom;
	while TMod <> Nil do begin
		if ( TMod^.G = GG_Module ) and ( TMod^.Stat[ STAT_VariableModuleForm ] <> 0 ) then begin
			if FORMxMODULE[ Mek^.S , TMod^.Stat[ STAT_PrimaryModuleForm ] ] then begin
				TMod^.S := TMod^.Stat[ STAT_PrimaryModuleForm ];
			end else if FORMxMODULE[ Mek^.S , TMod^.Stat[ STAT_VariableModuleForm ] ] then begin
				TMod^.S := TMod^.Stat[ STAT_VariableModuleForm ];
			end else begin
				TMod^.S := TMod^.Stat[ STAT_PrimaryModuleForm ];
			end;
		end;

		TMod := TMod^.Next;
	end;

	if ForReal then begin
		{ Set a new movement mode. }
		GearDownToLowestMM( Mek , GB , NAttValue( Mek^.NA , NAG_Location , NAS_X ) , NAttValue( Mek^.NA , NAG_Location , NAS_Y ) );

		{ Set call time. }
		SetNAtt( Mek^.NA , NAG_Action , NAS_CallTime , GB^.ComTime + ReactionTime( Mek ) );

		{ Display the message. }
		msg := MsgString( 'TRANSFORM_Announce' );
		msg := ReplaceHash( msg , PilotName( Mek ) );
		msg := ReplaceHash( msg , MsgString( 'FORMNAME_' + BStr( Mek^.S ) ) );
		DialogMsg( msg );
	end;
end;

Function AIShouldTransform( GB: GameBoardPtr; mek,part: GearPtr ): Boolean;
	{ Given this transformation system, should the AI in question transform? }
begin
	if not CanDoTransformation( GB , mek , part ) then begin
		AIShouldTransform := False;
	end else begin
		{ For now, let's just transform as much as possible. }
		AIShouldTransform := True;
	end;
end;

Function CanLRScanHere( GB: GameBoardPtr; Part: GearPtr ): Boolean;
	{ Return TRUE if the scanner can be used here, or FALSE otherwise. }
begin
	CanLRScanHere := GB^.Scale <= ( Part^.Scale + 1 );
end;

Function LongRangeScanEPCost( GB: GameBoardPtr; Part: GearPtr ): LongInt;
	{ Return the cost of this long range scan, in energy points. }
var
	it: LongInt;
begin
	{ Power usage is ( Map Scale )^2 * Scanner Size * 7 }
	it := Part^.V * 7;
	if GB^.Scale > 1 then it := it * GB^.Scale * GB^.Scale;
	LongRangeScanEPCost := it;
end;

Function LongRangeScanRange( GB: GameBoardPtr; Part: GearPtr ): Integer;
	{ Return the range of this scanner. }
var
	R: Integer;
begin
	{ The range differs depending on whether we're doing a local scan or not. }
	if GB^.Scale <= Part^.Scale then begin
		R := Part^.V * 5 + 10;
	end else begin
		R := Part^.V * 5;
	end;
	LongRangeScanRange := R;
end;

Procedure DoLongRangeScan( GB: GameBoardPtr; PC , Part: GearPtr );
	{ Use a long range scanner. This will light up any unseen encounters or }
	{ models within range, at the price of lots of energy. }
var
	R,team,N: Integer;
	m2: GearPtr;
	msg: String;
begin
	R := LongRangeScanRange( GB , Part );

	Team := NAttValue( PC^.NA , NAG_Location , NAS_Team );
	N := 0;

	{ Look through the meks on the gameboard and try to spot them one by one. }
	m2 := GB^.meks;
	while m2 <> Nil do begin
		if OnTheMap( GB , M2 ) and ( Range( GB , PC , M2 ) <= R ) then begin
			if not MekCanSeeTarget( gb , PC , M2 ) then begin
				{ If this enemy mecha has not yet been spotted, }
				{ there's a chance it will become visible. }
				if IsMasterGear( M2 ) then begin
					{ M2 has just been spotted. }
					RevealMek( GB , M2 , PC );
					Inc( N );
				end else if ( Team = NAV_DefPlayerTeam ) and ( M2^.G = GG_MetaTerrain ) and ( M2^.S = GS_MetaEncounter ) and ( M2^.Stat[ STAT_MetaVisibility ] >= 0 ) then begin
					RevealMek( GB , M2 , PC );
					Inc( N );
				end;
			end;
		end;

		m2 := m2^.next;
	end;

	{ Report the results. }
	msg := ReplaceHash( MsgString( 'LONGRANGESCAN_Announce' ) , PilotName( PC ) );
	if N = 0 then begin
		msg := msg + MsgString( 'LONGRANGESCAN_NoTargets' );
	end else if N = 1 then begin
		msg := msg + MsgString( 'LONGRANGESCAN_OneTarget' );
	end else begin
		msg := msg + ReplaceHash( MsgString( 'LONGRANGESCAN_ManyTargets' ) , BStr( N ) );
	end;
	DialogMsg( msg );

	{ Spend the energy. }
	SpendEnergy( FindRoot( Part ) , LongRangeScanEPCost( GB , Part ) );

	{ The scanner must wait a minute. }
	WaitAMinute( GB , FindRoot( Part ) , ReactionTime( FindRoot( Part ) ) );
end;

Function AIShouldLRScan( GB: GameBoardPtr; mek,part: GearPtr ): Boolean;
	{ As usual, the computer cheats. This NPC will use the long range }
	{ scanner if there are enemy models within range. }
var
	R: Integer;
	M2: GearPtr;
	ShouldScan: Boolean;
begin
	{ Start by checking the power- don't scan if you don't have the juice. }
	if LongRangeScanEPCost( GB, Part ) > ( EnergyPoints( Mek ) - Random( 200 ) ) then Exit( False );

	R := LongRangeScanRange( GB , Part );
	ShouldScan := False;

	{ Look through the meks on the gameboard and try to spot them one by one. }
	M2 := GB^.meks;
	while m2 <> Nil do begin
		if OnTheMap( GB , M2 ) and ( Range( GB , Mek , M2 ) <= R ) then begin
			if IsMasterGear( M2 ) and AreEnemies( GB , Mek , M2 ) and not MekCanSeeTarget( gb , Mek , M2 ) then begin
				ShouldScan := True;
				Break;
			end;
		end;

		m2 := m2^.next;
	end;

	AIShouldLRScan := ShouldScan;
end;


end.
