unit customization;
	{ This unit handles the customization of mecha. }
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

uses gears;

Const
	WT_SmallGun = 1;
	WT_BigGun = 2;
	WT_MissileLauncher = 3;
	WT_MeleeWeapon = 4;

Function MechaModPoints( NPC: GearPtr ): Integer;
Function WeaponThemeClass( W: GearPtr ): Integer;

Procedure MechaMakeover( Mek: GearPtr; Skill,Theme,MP: Integer );

Procedure ShopkeeperModifyMek( NPC,Mek: GearPtr );

Procedure CheckTheme( Theme: GearPtr );


implementation

uses 	ghchars,gearutil,gearparser,ghintrinsic,effects,ghweapon,ability,ui4gh,
	texutil,rpgdice,
{$IFDEF ASCII}
	vidgfx;
{$ELSE}
	sdlgfx;
{$ENDIF}

Function MechaModPoints( NPC: GearPtr ): Integer;
	{ Return the number of modification points this NPC should be given, based }
	{ on his renown and Mecha Engineering skill. }
var
	MP: Integer;
begin
	MP := NAttValue( NPC^.NA , NAG_CharDescription , NAS_Renowned ) div 10;
	if MP < 1 then MP := 1;
	MP := MP + ( ( NAttValue( NPC^.NA , NAG_Skill , NAS_MechaEngineering ) + 2 ) div 3 );
	MechaModPoints := MP;
end;

Function WeaponThemeClass( W: GearPtr ): Integer;
	{ Return the weapon type of this gear. }
begin
	if ( W^.S = GS_Melee ) or ( W^.S = GS_EMelee ) then begin
		WeaponThemeClass := WT_MeleeWeapon;
	end else if W^.S = GS_Missile then begin
		WeaponThemeClass := WT_MissileLauncher;
	end else if W^.V > 10 then begin
		WeaponThemeClass := WT_BigGun;
	end else begin
		WeaponThemeClass := WT_SmallGun;
	end;
end;

Procedure MechaMakeover( Mek: GearPtr; Skill,Theme,MP: Integer );
	{ Original title of this procedure was going to be "PimpMyMecha", }
	{ but the word "pimp" is awfully overused these days, isn't it? }
var
	PartsBox: GearPtr;
	OriginalMV,NumMassAdjusts: Integer;

	Function SwapParts( OldPart, NewPart: GearPtr ): Boolean;
		{ Attempt to swap OldPart with NewPart. If the exchange is impossible }
		{ for any reason, return FALSE and dispose of NewPart. Otherwise return TRUE. }
	var
		Slot: GearPtr;
	begin
		Slot := OldPart^.Parent;
		if IsInvCom( OldPart ) then begin
			{ This part is an invcom. Remove it, then insert the NewPart. }
			DelinkGear( Slot^.InvCom , OldPart );

			{ Attempt to insert NewPart. }
			if IsLegalInvCom( Slot , NewPart ) then begin
				InsertInvCom( Slot , NewPart );
				DisposeGear( OldPart );
				SwapParts := True;

			end else begin
				{ Can't insert the new part. Just stick the old one back. }
				InsertInvCom( Slot , OldPart );
				DisposeGear( NewPart );
				SwapParts := False;
			end;

		end else if IsSubCom( OldPart ) then begin
			{ This part is an subcom. Remove it, then insert the NewPart. }
			DelinkGear( Slot^.SubCom , OldPart );
			if IsLegalSubCom( Slot , NewPart ) then begin
				InsertSubCom( Slot , NewPart );
				DisposeGear( OldPart );
				SwapParts := True;

			end else begin
				{ Can't insert the new part. Just stick the old one back. }
				InsertSubCom( Slot , OldPart );
				DisposeGear( NewPart );
				SwapParts := False;
			end;


		{ If the part to swap isn't an invcom or a subcom, that's a major FUBAR. }
		end else SwapParts := False;
	end;

	Procedure CheckManeuverScore;
		{ The maneuverability score of the mecha shouldn't get any worse than }
		{ it started. }
		Function ComponentExcessMass( Part: GearPtr ): LongInt;
			{ Return the excess mass points of this component. }
			{ What's an excess mass point? In excess of 1. Weight reduction }
			{ should not take any item to Mass:0, so ignore those gears. }
		var
			it: LongInt;
		begin
			it := ComponentMass( Part ) - 1;
			if it < 0 then it := 0;
			ComponentExcessMass := it;
		end;
		Function NumExcessMassPoints( LList: GearPtr ): LongInt;
			{ Add up all the excess mass points in this linked list. }
			{ For the point of brevity, ignore gears of a smaller scale }
			{ than the Mek itself. }
		var
			total: LongInt;
		begin
			total := 0;
			while LList <> Nil do begin
				if ( LList^.Scale >= Mek^.Scale ) then begin
					total := total + ComponentExcessMass( LList );
					total := total + NumExcessMassPoints( LList^.SubCom );
					total := total + NumExcessMassPoints( LList^.InvCom );
				end;
				if IsMasterGear( LList ) then LList := Nil
				else LList := LList^.Next;
			end;
			NumExcessMassPoints := total;
		end;
		Function GetExcessMassPoint( LList: GearPtr; var N: Integer ): GearPtr;
			{ Return the gear that has excess mass point N, as if all }
			{ the excess mass points were individually numbered. I think maybe }
			{ I shouldn't be writing comments in summer when I feel dizzy but }
			{ I'm sure you all know what I mean. Still, that sentance looks }
			{ messy. Hi Peter. }
		var
			it: gearPtr;
		begin
			it := Nil;
			while ( LList <> Nil ) and ( it = Nil ) do begin
				if ( LList^.Scale >= Mek^.Scale ) then begin
					N := N - ComponentExcessMass( LList );
					if N < 0 then it := LList;
					if it = Nil then it := GetExcessMassPoint( LList^.SubCom , N );
					if it = Nil then it := GetExcessMassPoint( LList^.InvCom , N );
				end;
				if IsMasterGear( LList ) then LList := Nil
				else LList := LList^.Next;
			end;
			GetExcessMassPoint := it;
		end;
	var
		EMP: Integer;
		Part: GearPtr;
	begin
		{ As long as our maneuverability is too high, reduce the mass from }
		{ parts randomly. }
		While ( MechaManeuver( Mek ) < OriginalMV ) and ( MP > 0 ) do begin
			EMP := NumExcessMassPoints( Mek );
			if EMP > 0 then begin
				EMP := Random( EMP );
				Part := GetExcessMassPoint( Mek , EMP );
				if Part <> Nil then begin
					inc( NumMassAdjusts );
					if ( NumMassAdjusts mod 5 ) = 0 then Dec( MP );
					AddNAtt( Part^.NA , NAG_GearOps , NAS_MassAdjust , -1 );
					if XXRAN_DEBUG then DialogMsg( 'Reducing mass of ' + GearName( Part ) + '.' );
				end else begin
					DialogMsg( 'ERROR: Part ' + BStr( EMP ) + '/' + BStr( NumExcessMassPoints( Mek ) ) + ' not found in customization/CheckManeuverScore' );
					Break;
				end;
			end else break;
		end;
	end;

	Procedure AddNewWeapon;
		{ Add a new weapon to the mecha. }
		Function SeekMountingPoint( LList: GearPtr ): GearPtr;
			{ Try to find an empty mounting point along this list }
			{ or through its equal-scale subcoms. }
		var
			it: GearPtr;
		begin
			it := Nil;
			while ( LList <> Nil ) and ( it = Nil ) do begin
				if LList^.Scale >= Mek^.Scale then begin
					if ( LList^.G = GG_Holder ) and ( LList^.InvCom = Nil ) then it := LList
					else it := SeekMountingPoint( LList^.SubCom );
				end;
				LList := LList^.Next;
			end;
			SeekMountingPoint := it;
		end;
		Function GetNewWeaponToInstall: GearPtr;
			{ Locate a new weapon to install; pick the smallest weapon }
			{ listed of a randomly selected category. }
		var
			WT,Tries: Integer;
			Part,it: GearPtr;
			PartValue,ItValue: LongInt;
		begin
			WT := Random( 4 ) + 1;
			it := Nil;
			Tries := 0;

			while ( it = Nil ) and ( Tries < 4 ) do begin
				Part := PartsBox^.InvCom;
				while Part <> Nil do begin
					if ( Part^.G = GG_Weapon ) and ( WeaponThemeClass( Part ) = WT ) then begin
						{ We've found a weapon of the appropriate type. Compare }
						{ it against IT to see whether or not to choose it. }
						PartValue := GearValue( Part );
						if ( it = Nil ) then begin
							it := Part;
							ItValue := GearValue( Part );
						end else if ( PartValue < ItValue ) then begin
							it := Part;
							ItValue := PartValue;
						end;
					end;
					Part := Part^.Next;
				end;
				WT := WT + 1;
				if WT = 5 then WT := 1;
				Inc( Tries );
			end;
			GetNewWeaponToInstall := it;
		end;
		Function SeekEmptiestModule: GearPtr;
			{ Search through the modules of this mecha, looking for one that has }
			{ the least amount of junk already installed. }
		var
			M,it: GearPtr;
			MSpace,ItSpace: Integer;
		begin
			M := Mek^.SubCom;
			it := Nil;
			itSpace := 0;
			while M <> Nil do begin
				if ( M^.G = GG_Module ) and ( M^.Scale >= mek^.Scale ) then begin
					{ This module is one we'll have to consider. Find out how }
					{ much space it has for installing new things. }
					if it = Nil then begin
						it := M;
						ItSpace := ComponentComplexity( M ) - SubComComplexity( M );
					end else begin
						MSpace := ComponentComplexity( M ) - SubComComplexity( M );
						if MSpace > ItSpace then begin
							it := M;
							ItSpace := MSpace;
						end;
					end;
				end;

				M := M^.Next;
			end;
			SeekEmptiestModule := it;
		end;
	var
		Weapon,Slot: GearPtr;	{ The new weapon, and the spot to put it. }
	begin
		{ Step one: Find a weapon to use. }
		Weapon := GetNewWeaponToInstall;
		if Weapon = Nil then begin
			if XXRAN_DEBUG then DialogMsg( 'Error- No weapon found for install.' );
			Exit;
		end else if XXRAN_DEBUG then DialogMsg( 'Installing new ' + GearName( Weapon ) + '.' );

		{ Step two: Find a place to stick it. }
		Slot := SeekMountingPoint( Mek^.SubCOm );
		if Slot <> Nil then begin
			if IsLegalInvCom( Slot , Weapon ) then InsertInvCom( Slot , CloneGear( Weapon ) )
			else if XXRAN_DEBUG then DialogMsg( 'Install ' + GearName( Weapon ) + ' failed.' );
		end else begin
			Slot := SeekEmptiestModule;
			if ( Slot <> Nil ) and IsLegalSubCom( Slot , Weapon ) then InsertSubCom( Slot , CloneGear( Weapon ) )
			else if XXRAN_DEBUG then DialogMsg( 'Install ' + GearName( Weapon ) + ' failed.' );
		end;
	end;

	Procedure UpgradeWeapons;
		{ Replace a weapon on this mecha with an even better weapon taken }
		{ from the parts box. }
		Function WUWeight( Part: GearPtr ): LongInt;
			{ How much do I want to change this weapon? I want to change the }
			{ most expensive weapons first, but preference is strongly given }
			{ to weapons mounted as InvComs. }
		var
			it: LongInt;
		begin
			it := GearValue( Part );
			if ( Part^.Parent <> Nil ) and ( Part^.Parent^.G = GG_Holder ) then it := it * 3;
			WUWeight := it;
		end;
		Function LocateWeaponToUpgrade( LList,Best: GearPtr ): GearPtr;
			{ Search through this list, its invcoms and subcoms, looking }
			{ for a weapon to upgrade. }
		var
			ASkill1,ASkill2: Integer;
		begin
			while LList <> Nil do begin
				if ( LList^.G = GG_Weapon ) and ( NAttValue( LList^.NA , NAG_EpisodeData , NAS_WeaponUpgrades ) <> -1 ) and ( not PartHasIntrinsic( LList , NAS_Integral ) ) then begin
					if Best = Nil then begin
						{ Better to have some weapon than no weapon. }
						Best := LList;
					end else if NAttValue( LList^.NA , NAG_EpisodeData , NAS_WeaponUpgrades ) < NAttValue( Best^.NA , NAG_EpisodeData , NAS_WeaponUpgrades ) then begin
						{ The weapon which has been upgraded the least }
						{ will always be selected. }
						Best := LList;
					end else if NAttValue( LList^.NA , NAG_EpisodeData , NAS_WeaponUpgrades ) = NAttValue( Best^.NA , NAG_EpisodeData , NAS_WeaponUpgrades ) then begin
						ASkill1 := AttackSkillNeeded( Best );
						ASkill2 := AttackSkillNeeded( LList );
						if ( ASkill2 = Skill ) and ( ASkill1 <> Skill ) then begin
							{ Always go with a weapon that uses the preferred skill. }
							Best := LList;
						end else if ( ASkill1 = ASkill2 ) and ( ASkill1 = Skill ) and ( WUWeight( LList ) > WUWeight( Best ) ) then begin
							{ Both weapons use the preferred skill- modify the most expensive first. }
							Best := LList;
						end else if ( ASkill1 <> Skill ) and ( WUWeight( LList ) > WUWeight( Best ) ) then begin
							{ Neither weapon uses the preferred skill- take the most expensive. }
							Best := LList;
						end;
					end;
				end;

				{ Check along the subcoms and invcoms. }
				if LList^.G <> GG_Cockpit then begin
					Best := LocateWeaponToUpgrade( LList^.SubCom , Best );
					Best := LocateWeaponToUpgrade( LList^.InvCom , Best );
				end;
				LList := LList^.Next;
			end;
			LocateWeaponToUpgrade := Best;
		end;
		Function SelectReplacementWeapon( WeaponToReplace: GearPtr ): GearPtr;
			{ Searching along PartsBox^.InvCom, look for a weapon of the same }
			{ type as WeaponToReplace but more expensive. Return the cheapest }
			{ such weapon found. }
		var
			WT: Integer;	{ Weapon type to match. }
			Part,It: GearPtr;
			MinValue,PartValue,ItValue: LongInt;
		begin
			WT := WeaponThemeClass( WeaponToReplace );
			MinValue := GearValue( WeaponToReplace );
			It := Nil;
			ItValue := 0;
			Part := PartsBox^.InvCom;
			while Part <> Nil do begin
				if ( Part^.G = GG_Weapon ) and ( WeaponThemeClass( Part ) = WT ) then begin
					{ We've found a weapon of the appropriate type. Compare }
					{ it against IT to see whether or not to choose it. }
					PartValue := GearValue( Part );
					if ( it = Nil ) and ( PartValue > MinValue ) then begin
						it := Part;
						ItValue := GearValue( Part );
					end else if ( PartValue > MinValue ) and ( PartValue < ItValue ) then begin
						it := Part;
						ItValue := GearValue( Part );
					end;
				end;
				Part := Part^.Next;
			end;
			SelectReplacementWeapon := it;
		end;
	var
		WeaponToReplace,NewWeapon: GearPtr;
	begin
		repeat
			WeaponToReplace := LocateWeaponToUpgrade( Mek^.SubCom , Nil );
			if WeaponToReplace = Nil then break;

			{ Step two- locate a new weapon from the parts list which: }
			{ 1) is of the same basic type as the weapon being replaced, }
			{ 2) has a value greater than that of the weapon being replaced }
			{    but smaller than any other weapon matching 1. }
			NewWeapon := SelectReplacementWeapon( WeaponToReplace );

			{ If no NewWeapon can be found for the current WeaponToReplace, }
			{ mark this weapon as unreplacable and attempt another. }
			if NewWeapon = Nil then SetNAtt( WeaponToReplace^.NA , NAG_EpisodeData , NAS_WeaponUpgrades , -1 );
		until ( WeaponToReplace <> Nil ) and ( NewWeapon <> Nil );

		{ If either WeaponToReplace or NewWeapon are Nil, call the AddNewWeapon upgrade }
		{ instead. }
		if ( WeaponToReplace = Nil ) or ( NewWeapon = Nil ) then begin
			AddNewWeapon;
			exit;
		end;

		{ Record the WeaponUpgrades total. }
		NewWeapon := CloneGear( NewWeapon );
		SetNAtt( NewWeapon^.NA , NAG_EpisodeData , NAS_WeaponUpgrades , NAttValue( WeaponToReplace^.NA , NAG_EpisodeData , NAS_WeaponUpgrades ) + 1 );

		if XXRAN_DEBUG then DialogMsg( 'Replacing ' + GearName( WeaponToReplace ) + ' with ' + GearName( NewWeapon ) + '.' );

		{ Step three- perform the swap. }
		{ Record the number of upgrades + 1 in the new weapon. }
		SwapParts( WeaponToReplace , NewWeapon );
	end;
	Procedure ReDesignate;
		{ Since this mecha has been extensively modified, it can't keep the }
		{ same old factory designation it once had. Let's give it a name to }
		{ indicate its new abilities... a name even StrongBad would be proud }
		{ of. }
		{ The new designation will consist of an adjective + a noun. Each }
		{ theme should have a list of 5 adjectives and 5 nouns specifically }
		{ for this purpose. One or the other of the words may be taken from }
		{ a general list instead. }
	var
		NormComp: Integer;
		Desig: String;
	begin
		NormComp := Random( 3 );
		if NormComp = 1 then Desig := MSgString( 'CUSTOMIZATION_ADJECTIVE_' + BStr( Random( 5 ) ) )
		else Desig := SAttValue( PartsBox^.SA , 'CUSTOMIZATION_ADJECTIVE_' + BStr( Random( 5 ) ) );

		if NormComp = 2 then Desig := Desig + ' ' + MSgString( 'CUSTOMIZATION_NOUN_' + BStr( Random( 5 ) ) )
		else Desig := Desig + ' ' + SAttValue( PartsBox^.SA , 'CUSTOMIZATION_NOUN_' + BStr( Random( 5 ) ) );

		SetSAtt( Mek^.SA , 'DESIG <' + Desig + '>' );
	end;
begin
	{ Start by locating the parts list. }
	{ If Theme = 0 then select a random theme. }
	if Theme = 0 then begin
		PartsBox := SelectRandomGear( Mecha_Theme_List );
	end else begin
		{ The actual parts we want will be invcoms of this gear. }
		PartsBox := SeekCurrentLevelGear( Mecha_Theme_List , Mecha_Theme_List^.G , Theme );
	end;

	if PartsBox = Nil then begin
		Exit;
	end;

	{ Record the original maneuverability score of the mecha. If this changes, we }
	{ need to lose some weight. }
	OriginalMV := MechaManeuver( Mek );
	NumMassAdjusts := 0;

	while MP > 0 do begin
		if Random( 20 ) = 1 then begin
			AddNewWeapon;
		end else begin
			UpgradeWeapons;
		end;
		Dec( MP );

		{ After all modifications, check to make sure the MV is as good as it ever was. }
		CheckManeuverScore;
	end;

	{ Give this mecha a new designation. }
	ReDesignate;
end;

Procedure ShopkeeperModifyMek( NPC,Mek: GearPtr );
	{ The NPC is going to modify this mecha for sale in his/her shop. }
	{ Decide on a random theme and a number of modification points, then send everything }
	{ to the above procedure. }
	{ Note that if the NPC makes a bad roll, it's quite possible for the mecha to leave this }
	{ procedure without being modified at all. }
var
	SkRoll,MP: Integer;
	Theme: GearPtr;
begin
	{ Make a skill roll against the size of the mecha. If it succeeds, then }
	{ we'll have some modification points to work with. }
	SkRoll := RollStep( SkillValue( NPC , NAS_MechaEngineering , STAT_Knowledge ) ) - ( Mek^.S + 4 );
	if SkRoll > 0 then begin
		{ Okay, we have some points. Now, pick a theme. }
		Theme := SelectRandomGear( Mecha_Theme_List );

		MP := ( SkRoll + 2 ) div 3;
		if MP > 9 then MP := 9;

		{ Send all the info to the MechaMakeover procedure. }
		MechaMakeover( Mek , 0 , Theme^.S , MP );
	end;
end;

Procedure CheckTheme( Theme: GearPtr );
	{ Check this theme. See if it has all the required weapons. }
	{ There are four weapon types and about 10 cost classes. }
const
	Cost_Max: Array [ 1..4 , 0..10 ] of LongInt = (
	( 0 , 30000 , 45000 , 65000 , 90000 , 120000  ,  160000 , 210000 , 270000 , 340000 , 420000 ),	{ Small Guns }
	( 0 , 30000 , 45000 , 65000 , 90000 , 120000  ,  160000 , 210000 , 270000 , 340000 , 420000 ),	{ Big Guns }
	( 0 , 30000 , 45000 , 65000 , 90000 , 120000  ,  160000 , 210000 , 270000 , 340000 , 420000 ),	{ Missile Launchers }
	( 0 , 10000 , 15000 , 25000 , 40000 , 60000  ,  90000 , 130000 , 180000 , 240000 , 310000 )	{ Melee Weapons }
	);
var
	Memo: SAttPtr;	{ List of comments. }
	Procedure CheckTypeRank( WP_Type,WP_Rank: Integer );
		{ Check this weapon type/rank to make sure one appropriate weapon is present. }
		{ If more than one is present, that's an error. If less than one is present, that's }
		{ an error too. }
	var
		W: GearPtr;
		N: Integer;
		Cost: LongInt;
	begin
		W := Theme^.InvCom;
		N := 0;
		while W <> Nil do begin
			if WeaponThemeClass( W ) = WP_Type then begin
				Cost := GearValue( W );
				if ( Cost > Cost_Max[ WP_Type , WP_Rank - 1 ] ) and ( Cost <= Cost_Max[ WP_Type , WP_Rank ] ) then Inc( N );
			end;
			W := W^.Next;
		end;

		{ Store any errors in MEMO. }
		if N = 0 then begin
			StoreSAtt( Memo , 'ERROR: Type ' + BStr( WP_Type ) + ' Rank ' + BStr( WP_Rank ) + ' has no weapon.' );
		end else if N > 1 then begin
			StoreSAtt( Memo , 'ERROR: Type ' + BStr( WP_Type ) + ' Rank ' + BStr( WP_Rank ) + ' has ' + BStr( N ) + ' weapons.' );
			W := Theme^.InvCom;
			while W <> Nil do begin
				if WeaponThemeClass( W ) = WP_Type then begin
					Cost := GearValue( W );
					if ( Cost > Cost_Max[ WP_Type , WP_Rank - 1 ] ) and ( Cost <= Cost_Max[ WP_Type , WP_Rank ] ) then begin
						if ( WP_Type = WT_MissileLauncher ) and ( W^.SubCom <> Nil ) then StoreSAtt( Memo , '     ->' + FullGearName( W^.SubCom ) + ' [' + BStr( W^.SubCom^.Stat[ STAT_AmmoPresent ] ) + ']' )
						else StoreSAtt( Memo , '     ->' + GearName( W ) );
					end;
				end;
				W := W^.Next;
			end;
		end;
	end;
var
	C,R: Integer;
begin
	Memo := Nil;
	for C := 1 to 4 do begin
		for R := 1 to 10 do begin
			CheckTypeRank( C , R );
		end;
	end;
	if Memo <> Nil then begin
		MoreText( Memo , 1 );
		DisposeSAtt( Memo );
	end;
end;


end.
