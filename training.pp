unit training;
	{ Training is hereby cut off from pcaction.pp; that unit is far too }
	{ bloaty to begin with. }
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

Procedure DoTraining( GB: GameBoardPtr; PC: GearPtr; RD: RedrawProcedureType );

implementation

uses	ghchars,gearutil,texutil,ability,description,ui4gh,
{$IFDEF ASCII}
	vidmenus,vidinfo;
{$ELSE}
	sdlmenus,sdlinfo;
{$ENDIF}

var
	TRAINING_GB: GameBoardPtr;
	TRAINING_PC: GearPtr;
	TRAINING_Redrawer: RedrawProcedureType;

Procedure TrainingRedraw;
	{ Redraw the training screen. }
begin
	TRAINING_Redrawer;
	CharacterDisplay( TRAINING_PC , TRAINING_GB );
	InfoBox( ZONE_Menu );
	InfoBox( ZONE_Info );
	CMessage( 'FREE XP: ' + BStr( NAttValue( TRAINING_PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( TRAINING_PC^.NA , NAG_Experience , NAS_SpentXP ) ) , ZONE_Menu1 , InfoHilight );
end;

Procedure NewSkillRedraw;
	{ Redraw the training screen. }
begin
	TRAINING_Redrawer;
	CharacterDisplay( TRAINING_PC , TRAINING_GB );
	InfoBox( ZONE_Menu );
	InfoBox( ZONE_Info );
	CMessage( BStr( NumberOfSpecialties( TRAINING_PC ) ) + '/' + BStr( NumberOfSkillSlots( TRAINING_PC ) ) , ZONE_Menu1 , InfoHilight );
end;

Procedure DoTraining( GB: GameBoardPtr; PC: GearPtr; RD: RedrawProcedureType );
	{ The player wants to spend some of this character's }
	{ accumulated experience points. Go to it! }
	Procedure ImproveSkills( PC: GearPtr );
		{ The PC is going to improve his or her skills. }
	var
		FXP: LongInt;		{ Free XP Points }
		SkMenu: RPGMenuPtr;	{ Training Hall Menu }
		Sk: NAttPtr;		{ A skill counter }
		N: LongInt;		{ A number }
		SI,TI: Integer;		{ Selected Item , Top Item }
		msg: String;
	begin
		{ Initialize the Selected Item and Top Item to the }
		{ top of the list. }
		SI := 1;
		TI := 1;

		repeat
			{ The number of free XP is the total XP minus the spent XP. }
			FXP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP );

			{ Create the skill menu. }
			SkMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
			Sk := PC^.NA;

			SkMenu^.dtexcolor := InfoGreen;

			AttachMenuDesc( SkMenu , ZONE_Info );

			while Sk <> Nil do begin
				if ( Sk^.G = NAG_Skill ) and ( Sk^.S > 0 ) and not SkillMan[ Sk^.S ].Hidden then begin
					{ Add this skill to the menu. This is going to be one doozy of a long description. }
					AddRPGMenuItem( SkMenu , MsgString( 'SKILLNAME_' + BStr( Sk^.S ) ) + ' +' + BStr( Sk^.V ) + '   (' + BStr( SkillAdvCost( PC , Sk^.V ) ) + ' XP)' , Sk^.S , SkillDescription( Sk^.S ) );
				end;
				Sk := Sk^.Next;
			end;

			RPMSortAlpha( SkMenu );
			AddRPGMenuItem( SkMenu , MsgString( 'RANDCHAR_ASPDone' ) , -1 );

			{ Restore SelectItem , TopItem from the last time. }
			SkMEnu^.SelectItem := SI;
			SkMenu^.TopItem := TI;


			N := SelectMenu( SkMenu , @TrainingRedraw );

			{ Save the last cursor position, then dispose of }
			{ the menu. }
			SI := SkMenu^.SelectItem;
			TI := SkMenu^.TopItem;
			DisposeRPGMenu( SkMenu );

			if N > 0 then begin
				{ Locate the exact skill being improved. }
				Sk := FindNAtt( PC^.NA , NAG_Skill , N );

				{ Use N to store this skill's cost. }
				N := SkillAdvCost( PC , Sk^.V );

				{ If the PC has enough free XP, this skill will be improved. }
				{ Otherwise, do nothing. }
				if N > FXP then begin
					DialogMsg( ReplaceHash( MsgString( 'TRAINING_NotEnoughXP' ) , GearName( PC ) ) );
				end else begin
					{ Improve the skill, pay the XP. }
					msg := ReplaceHash( MsgString( 'TRAINING_Improved' ) , GearName( PC ) );
					msg := ReplaceHash( msg , MsgString( 'SKILLNAME_' + BStr( Sk^.S ) ) );
					DialogMsg( msg );
					AddNAtt( PC^.NA , NAG_Skill , Sk^.S , 1 );
					AddNAtt( PC^.NA , NAG_Experience , NAS_SpentXP , N );
				end;
			end;
		until N = -1;
	end;

	Function NumAllowedStatAdvances: LongInt;
		{ Return the number of stat advances this PC is allowed. }
	var
		XP: LongInt;
	begin
		XP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP );
		if XP > 100000 then XP := 100000;
		NumAllowedStatAdvances := XP div 5000;
	end;
	Function OneStatCanBeAdvanced: Boolean;
		{ Return TRUE if at least one stat is capable of being }
		{ advanced, or FALSE otherwise. }
	var
		t,N: Integer;
	begin
		{ To start with, count up the number of advancements so far. }
		N := 0;
		for t := 1 to NumGearStats do begin
			N := N + NAttValue( PC^.NA , NAG_StatImprovementLevel , T );
		end;
		OneStatCanBeAdvanced := N < NumAllowedStatAdvances;
	end;

	Function StatImprovementCost( CIV: Integer ): LongInt;
		{ Return the cost of improving this stat. }
	begin
		StatImprovementCost := ( CIV + 1 ) * 500;
	end;

	Procedure ImproveStats( PC: GearPtr );
		{ The PC is going to improve his or her stats. }
	var
		FXP: LongInt;		{ Free XP Points }
		StMenu: RPGMenuPtr;	{ Training Hall Menu }
		CIV: Integer;		{ Current Improvement Value. }
		N,T,SI,TI: Integer;	{ Selected Item , Top Item }
		XP: LongInt;
		msg: String;
	begin
		{ Initialize the Selected Item and Top Item to the }
		{ top of the list. }
		SI := 1;
		TI := 1;

		repeat
			{ The number of free XP is the total XP minus the spent XP. }
			FXP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP );

			{ Create the skill menu. }
			StMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );

			for t := 1 to NumGearStats do begin
				{ Find out how many times this stat has been }
				{ improved thus far. }
				CIV := NAttValue( PC^.NA , NAG_StatImprovementLevel , T );
				AddRPGMenuItem( StMenu , MsgString( 'StatName_' + BStr( T ) ) + '   (' + BStr( StatImprovementCost( CIV ) ) + ' XP)' , T );
			end;

			AddRPGMenuItem( StMenu , MsgString( 'RANDCHAR_ASPDone' ) , -1 );

			{ Restore SelectItem , TopItem from the last time. }
			StMEnu^.SelectItem := SI;
			StMenu^.TopItem := TI;

			N := SelectMenu( StMenu , @TrainingRedraw );


			{ Save the last cursor position, then dispose of }
			{ the menu. }
			SI := StMenu^.SelectItem;
			TI := StMenu^.TopItem;
			DisposeRPGMenu( StMenu );

			if N > 0 then begin
				{ Find out how many times this stat has been }
				{ improved thus far. }
				CIV := NAttValue( PC^.NA , NAG_StatImprovementLevel , N );

				XP := StatImprovementCost( CIV );

				if XP > FXP then begin

					DialogMsg( ReplaceHash( MsgString( 'TRAINING_NotEnoughXP' ) , GearName( PC ) ) );
				end else begin
					{ Improve the skill, pay the XP. }
					msg := ReplaceHash( MsgString( 'TRAINING_Improved' ) , GearName( PC ) );
					msg := ReplaceHash( msg , MsgString( 'StatName_' + BStr( N ) ) );
					DialogMsg( msg );
					Inc( PC^.Stat[ N ] );
					AddNAtt( PC^.NA , NAG_Experience , NAS_SpentXP , XP );
					AddNAtt( PC^.NA , NAG_StatImprovementLevel , N , 1 );
				end;

			end;
		until ( N = -1 ) or not OneStatCanBeAdvanced;
	end;

	Procedure ForgetLowSkill( PC: GearPtr );
		{ The PC wants to forget a currently known skill. }
		{ Choose the skill with the lowest rank to delete. }
	var
		LowSkill,LowSkillRank,T,R: Integer;
	begin
		LowSkill := 1;
		LowSkillRank := 9999;
		for t := 1 to NumSkill do begin
			R := NAttValue( PC^.NA , NAG_Skill , T );
			{ Can't forget the hidden skills. }
			if ( R > 0 ) and not SkillMan[t].Hidden then begin
				if R < LowSkillRank then begin
					LowSkill := T;
					LowSkillRank := R;
				end else if ( R = LowSkillRank ) and ( Random( 2 ) = 1 ) then begin
					LowSkill := T;
					LowSkillRank := R;
				end;
			end;
		end;
		SetNAtt( PC^.NA , NAG_Skill , LowSkill , 0 );
		{ Also remove any talents based on this skill. }
		for t := 1 to NumTalent do begin
			if Talent_PreReq[ T , 1 ] = LowSkill then SetNAtt( PC^.NA , NAG_Talent , T , 0 );
		end;
	end;

	Procedure GetNewSkill( PC: GearPtr );
		{ The PC is going to purchase a new skill. }
	var
		FXP: LongInt;		{ Free XP Points }
		SkMenu: RPGMenuPtr;	{ Training Hall Menu }
		N,N2: LongInt;		{ A number }
		SkillLimit: Integer;	{ Highest skill index that can be learned. }
					{ NPCs are generally stuck with the skills they }
					{ start with, but everyone can learn the 10 basic }
					{ combat skills. }
		msg: String;
	begin
		{ The number of free XP is the total XP minus the spent XP. }
		FXP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP );

		{ Create the skill menu. }
		{ We only want this menu to contain skills the PC does }
		{ not currently know. }
		SkMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );

		AttachMenuDesc( SkMenu , ZONE_Info );

		SkMenu^.dtexcolor := InfoGreen;

		if NAttValue( PC^.NA , NAG_Location , NAS_Team ) = NAV_LancemateTeam then SkillLimit := Num_Basic_Combat_Skills
		else SkillLimit := NumSkill;

		for N := 1 to SkillLimit do begin
			if ( NAttValue( PC^.NA , NAG_Skill , N ) = 0 ) and not SkillMan[ N ].Hidden then begin
				AddRPGMenuItem( SkMenu , MsgString( 'SkillName_' + BStr( N ) ) + '   (' + BStr( SkillAdvCost( PC , 0 ) ) + ' XP)' , N , SkillDescription( N ) );
			end;
		end;
		RPMSortAlpha( SkMenu );
		AddRPGMenuItem( SkMenu , '  Cancel' , -1 );

		N := SelectMenu( SkMenu , @NewSkillRedraw );

		DisposeRPGMenu( SkMenu );

		if N > 0 then begin
			{ If the PC has enough free XP, this skill will be improved. }
			{ Otherwise, do nothing. }
			if SkillAdvCost( PC , 0 ) > FXP then begin
				DialogMsg( ReplaceHash( MsgString( 'TRAINING_NotEnoughXP' ) , GearName( PC ) ) );

			end else begin
				{ Improve the skill, pay the XP. }
				if NumberOfSpecialties( PC ) >= NumberOfSkillSlots( PC ) then begin
					SkMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );

					AttachMenuDesc( SkMenu , ZONE_Info );

					SkMenu^.dtexcolor := InfoGreen;
					AddRPGMenuItem( SkMenu , MsgSTring( 'LearnSkill_AcceptPenalty' ) , 1 , MsgString( 'LearnSkill_Warning' ) );
					AddRPGMenuItem( SkMenu , MsgString( 'LearnSkill_ForgetPrevious' ) , 2 , MsgString( 'LearnSkill_Warning' ) );
					AddRPGMenuItem( SkMenu , MsgString( 'Cancel' ) , -1 , MsgString( 'LearnSkill_Warning' ) );


					N2 := SelectMenu( SkMenu , @NewSkillRedraw );

					if N2 = -1 then begin
						{ Cancelled learning new skill. }
						N := -1;
					end else if N2 = 2 then begin
						{ Will forget previous skill. }
						ForgetLowSkill( PC );
					end;

					DisposeRPGMenu( SkMenu );
				end;


				if ( N >= 1 ) and ( N <= NumSkill ) then begin
					msg := ReplaceHash( MsgString( 'TRAINING_Learned' ) , GearName( PC ) );
					msg := ReplaceHash( msg , MsgString( 'SKILLNAME_' + BStr( N ) ) );
					DialogMsg( msg );

					SetNAtt( PC^.NA , NAG_Skill , N , 1 );
					AddNAtt( PC^.NA , NAG_Experience , NAS_SpentXP , SkillAdvCost( PC , 0 ) );

					FXP := FXP - SkillAdvCost( PC , 0 );
				end;
			end;
		end;
	end;

	Procedure GetNewTalent( PC: GearPtr );
		{ The PC is going to purchase a new talent. }
	var
		FXP: LongInt;		{ Free XP Points }
		TMenu: RPGMenuPtr;	{ Training Hall Menu }
		N: LongInt;		{ A number }
		msg: String;
	begin
		{ The number of free XP is the total XP minus the spent XP. }
		FXP := NAttValue( PC^.NA , NAG_Experience , NAS_TotalXP ) - NAttValue( PC^.NA , NAG_Experience , NAS_SpentXP );

		{ Create the skill menu. }
		{ We only want this menu to contain skills the PC does }
		{ not currently know. }
		TMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );

		AttachMenuDesc( TMenu , ZONE_Info );

		TMenu^.dtexcolor := InfoGreen;

		for N := 1 to NumTalent do begin
			if CanLearnTalent( PC , N ) then begin
				AddRPGMenuItem( TMenu , MsgString( 'TALENT' + BStr( N ) ) , N , MsgString( 'TALENTDESC' + BStr( N ) ) );
			end;
		end;
		RPMSortAlpha( TMenu );
		AddRPGMenuItem( TMenu , '  Cancel' , -1 );

		repeat
			N := SelectMenu( TMenu , @TrainingRedraw );


			if N > 0 then begin
				{ If the PC has enough free XP, this skill will be improved. }
				{ Otherwise, do nothing. }
				if 1000 > FXP then begin
					DialogMsg( MsgString( 'CANTAFFORDTALENT' ) );
				end else if NumFreeTalents( PC ) < 1 then begin
					DialogMsg( MsgString( 'NOFREETALENTS' ) );
				end else begin
					msg := ReplaceHash( MsgString( 'TRAINING_Learned' ) , GearName( PC ) );
					msg := ReplaceHash( msg , MsgString( 'TALENT' + BStr( N ) ) );
					DialogMsg( msg );
					ApplyTalent( PC , N );
					AddNAtt( PC^.NA , NAG_Experience , NAS_SpentXP , 1000 );

					FXP := FXP - 1000;

					{ Having purchased a skill, we want to leave this procedure. }
					N := -1;
				end;
			end;
		until N = -1;

		DisposeRPGMenu( TMenu );
	end;

	Procedure ReviewTalents( PC: GearPtr );
		{ The PC is going to review his talents. }
	var
		TMenu: RPGMenuPtr;	{ Training Hall Menu }
		N: LongInt;		{ A number }
	begin
		{ Create the skill menu. }
		TMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );


		AttachMenuDesc( TMenu , ZONE_Info );

		TMenu^.dtexcolor := InfoGreen;

		for N := 1 to NumTalent do begin
			if HasTalent( PC , N ) then begin
				AddRPGMenuItem( TMenu , MsgString( 'TALENT' + BStr( N ) ) , N , MsgString( 'TALENTDESC' + BStr( N ) ) );
			end;
		end;
		RPMSortAlpha( TMenu );
		AddRPGMenuItem( TMenu , '  Exit' , -1 );

		N := SelectMenu( TMenu , @TrainingRedraw );

		DisposeRPGMenu( TMenu );
	end;

	Procedure ReviewCyberware( PC: GearPtr );
		{ The PC is going to review his talents. }
	var
		S: GearPtr;		{ Subcoms of PC. }
		TMenu: RPGMenuPtr;	{ Training Hall Menu }
	begin
		{ Create the cyber menu. }
		TMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );

		AttachMenuDesc( TMenu , ZONE_Info );

		TMenu^.dtexcolor := InfoGreen;

		S := PC^.SubCom;
		while S <> Nil do begin
			if S^.G = GG_Modifier then begin
				AddRPGMenuItem( TMenu , GearName( S ) , 0 , ExtendedDescription( GB , S ) + ' (' + SAttValue( S^.SA , 'CYBERSLOT' ) + ')' );
			end;
			S := S^.Next;
		end;
		RPMSortAlpha( TMenu );
		AddRPGMenuItem( TMenu , '  Exit' , -1 );

		SelectMenu( TMenu , @TrainingRedraw );

		DisposeRPGMenu( TMenu );
	end;

var
	DTMenu: RPGMenuPtr;
	N: Integer;
begin
	{ Error check - PC must point to the character record. }
	if PC^.G <> GG_Character then PC := LocatePilot( PC );
	if PC = Nil then Exit;

	TRAINING_PC := PC;
	TRAINING_GB := GB;
	TRAINING_Redrawer := RD;

	repeat
		DTMenu := CreateRPGMenu( MenuItem , MenuSelect , ZONE_Menu2 );
		AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_ImproveSkill' ) , 1 );
		AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_NewSkill' ) , 2 );
		AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_ReviewCyberware' ) , 6 );
		AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_ReviewTalents' ) , 5 );
		if ( NumFreeTalents( PC ) > 0 ) and ( NAttValue( PC^.NA , NAG_Location , NAS_Team ) <> NAV_LancemateTeam ) then begin
			AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_NewTalent' ) , 4 );
		end;
		if OneStatCanBeAdvanced then begin
			AddRPGMenuItem( DTMenu , MsgString( 'TRAINING_ImproveStat' ) , 3 );
		end;
		AddRPGMenuItem( DTMenu ,  MsgString( 'Exit' ) , -1 );

		N := SelectMenu( DTMenu , @TrainingRedraw );

		DisposeRPGMenu( DTMenu );

		if N = 1 then ImproveSkills( PC )
		else if N = 3 then ImproveStats( PC )
		else if N = 2 then GetNewSkill( PC )
		else if N = 4 then GetNewTalent( PC )
		else if N = 5 then ReviewTalents( PC )
		else if N = 6 then ReviewCyberware( PC );

	until N = -1;
end;



end.
