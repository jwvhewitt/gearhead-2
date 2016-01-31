program attacktest;

uses	gears,gearutil,locale,gearparser,effects,randmaps,ghchars,ghweapon,texutil,ghintrinsic,ability,movement,action;

const
	Tar_X = 9;
	Tar_Y = 8;

	Num_Trials = 2000;

	Skill_Level = 50;

	Target_Move_Action = NAV_NormSpeed;

var
	results: SAttPtr;

Procedure DeleteAllClouds( GB: GameBoardPtr );
	{ Get rid of any clouds that may be cluttering up the map. }
var
	M,M2: GearPtr;
begin
	M := GB^.Meks;
	while M <> Nil do begin
		M2 := M^.Next;
		if M^.G = GG_MetaTerrain then begin
			RemoveGear( GB^.Meks , M );
		end;
		M := M2;
	end;
end;


Procedure TestThisWeapon( GB: GameBoardPtr; AMaster , Attacker , Target: GearPtr );
	{ Test the provided weapon. It must already be installed in AMaster. }
	{ Run this attack a lot of times, and see how long it takes to destroy }
	{ the target. }
var
	TTK: LongInt;	{ Times To Kill }
	T,TT,N: LongInt;
	Dmg,Total,AtOp: LongInt;
	P1,P2: GearPtr;
	Histiogram: Array [1..50] of Integer;
begin
	Total := 0;
	P1 := LocatePilot( AMaster );
	P2 := LocatePilot( Target );
	StripNAtt( FindRoot( Attacker ) , NAG_Damage );
	StripNAtt( FindRoot( Target ) , NAG_Damage );
	AtOp := Attacker^.Stat[ STAT_BurstValue ];

	{ Clear the histiogram. }
	for t := 1 to 50 do Histiogram[ t ] := 0;

	for T := 1 to Num_Trials do begin
		{ See how many attacks it takes before the target is destroyed. }
		N := 0;

		{ Prep the movement modes. }
		SetNAtt( AMaster^.NA , NAG_Action , NAS_MoveMode , MM_Skim );
		PrepAction( GB , Target , NAV_Stop );
		SetNAtt( Target^.NA , NAG_Action , NAS_MoveMode , MM_Skim );
		PrepAction( GB , Target , Target_Move_Action );

		SetSkillsAtLevel( P1 , Skill_Level );
		SetSkillsAtLevel( P2 , Skill_Level );

		repeat
			DoAttack( GB , Attacker , Target , Tar_X , Tar_Y , 0 , AtOp );

			StripNAtt( AMaster , NAG_Condition );
			StripNAtt( AMaster , NAG_Damage );
			StripNAtt( AMaster , NAG_WeaponModifier );
			StripNAtt( AMaster , NAG_StatusEffect );

			DeleteAllClouds( GB );

			Inc( N );
		until ( N >= 50 ) or not GearActive( Target );

		Inc( Histiogram[ N ] );
		Total := Total + N;

		{ Delete the damage from the target for the next runthrough. }
		StripNAtt( FindRoot( Target ) , NAG_Condition );
		StripNAtt( FindRoot( Target ) , NAG_Damage );
		StripNAtt( FindRoot( Target ) , NAG_WeaponModifier );
		StripNAtt( FindRoot( Target ) , NAG_StatusEffect );
	end;

	{ Determine the TimesToKill and MedianToKill. }
	TTK := Total div Num_Trials;

	N := 1;
	for t := 1 to 50 do if Histiogram[ T ] > Histiogram[ N ] then N := T;

	StoreSAtt( Results, FullGearName( Attacker ) + ': Mean ' + BStr( TTK ) + ', Median ' + Bstr( N ) + '  ($' + BStr( GearValue( Attacker ) ) + ')' );
end;

Procedure TestThings( GB: GameBoardPtr; AMaster , Hand , Target: GearPtr; TestWeapon: String );
	{ Test the requested weapon. }
var
	Attacker: GearPtr;
begin
	Attacker := LoadNewSTC( TestWeapon );
	if Attacker = Nil then begin
		StoreSAtt( results, TestWeapon + ' not found!' );
	end else begin
		InsertInvCom( Hand , Attacker );
		TestThisWeapon( GB , AMaster , Attacker , Target );
		RemoveGear( Hand^.InvCom , Attacker );
		writeln( TestWeapon + ' done.' );
	end;
end;

Procedure TestDC( GB: GameBoardPtr; AMaster , Hand , Target: GearPtr );
	{ Test the requested weapon. }
var
	Attacker: GearPtr;
	T: LongInt;	{ Times To Kill }
begin
	Attacker := LoadNewSTC( 'LAS-10' );
	if Attacker <> Nil then begin
		InsertInvCom( Hand , Attacker );
		for t := 1 to 5 do begin
			Attacker^.V := t * 5;

			SetSAtt( Attacker^.SA , 'name <DC' + BStr( t * 5 ) + '>' );
			SetSAtt( Attacker^.SA , 'type <>' );
			TestThisWeapon( GB , AMaster , Attacker , Target );

			SetSAtt( Attacker^.SA , 'name <DC' + BStr( t * 5 ) + '+B>' );
			SetSAtt( Attacker^.SA , 'type <BRUTAL>' );
			TestThisWeapon( GB , AMaster , Attacker , Target );

			SetSAtt( Attacker^.SA , 'name <DC' + BStr( t * 5 ) + '+AP>' );
			SetSAtt( Attacker^.SA , 'type <ARMORPIERCING>' );
			TestThisWeapon( GB , AMaster , Attacker , Target );

			SetSAtt( Attacker^.SA , 'name <DC' + BStr( t * 5 ) + '+BS>' );
			SetSAtt( Attacker^.SA , 'type <BRUTAL SCATTER>' );
			TestThisWeapon( GB , AMaster , Attacker , Target );

			StoreSAtt( Results , '  ' );
		end;
		RemoveGear( Hand^.InvCom , Attacker );
	end;
end;

Procedure TestBV( GB: GameBoardPtr; AMaster , Hand , Target: GearPtr );
	{ Test the requested weapon. }
var
	Attacker: GearPtr;
	T: LongInt;	{ Times To Kill }
begin
	Attacker := LoadNewSTC( 'LAS-10' );
	if Attacker <> Nil then begin
		InsertInvCom( Hand , Attacker );

		Attacker^.V := 24;
		SetSAtt( Attacker^.SA , 'name <DC24x1>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.V := 12;
		Attacker^.Stat[ STAT_BurstValue ] := 1;
		SetSAtt( Attacker^.SA , 'name <DC12x2>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.V := 8;
		Attacker^.Stat[ STAT_BurstValue ] := 2;
		SetSAtt( Attacker^.SA , 'name <DC8x3>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.V := 6;
		Attacker^.Stat[ STAT_BurstValue ] := 3;
		SetSAtt( Attacker^.SA , 'name <DC6x4>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.V := 4;
		Attacker^.Stat[ STAT_BurstValue ] := 5;
		SetSAtt( Attacker^.SA , 'name <DC4x6>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.V := 3;
		Attacker^.Stat[ STAT_BurstValue ] := 7;
		SetSAtt( Attacker^.SA , 'name <DC3x8>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		RemoveGear( Hand^.InvCom , Attacker );
	end;
end;

Procedure TestAttributes( GB: GameBoardPtr; AMaster , Hand , Target: GearPtr );
	{ Test the requested weapon. }
var
	Attacker: GearPtr;
	T: LongInt;	{ Times To Kill }
begin
	Attacker := LoadNewSTC( 'SC-9' );
	if Attacker <> Nil then begin
		InsertInvCom( Hand , Attacker );

		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.Stat[ STAT_BurstValue ] := 2;
		SetSAtt( Attacker^.SA , 'name <BV3>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.Stat[ STAT_BurstValue ] := 4;
		SetSAtt( Attacker^.SA , 'name <BV5>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.Stat[ STAT_BurstValue ] := 7;
		SetSAtt( Attacker^.SA , 'name <BV8>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

{		Attacker^.Stat[ STAT_Accuracy ] := 2;
		SetSAtt( Attacker^.SA , 'name <ACC+2>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.Stat[ STAT_Accuracy ] := 5;
		SetSAtt( Attacker^.SA , 'name <ACC+5>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.Stat[ STAT_Accuracy ] := -2;
		SetSAtt( Attacker^.SA , 'name <ACC-2>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.Stat[ STAT_Accuracy ] := -5;
		SetSAtt( Attacker^.SA , 'name <ACC-5>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.Stat[ STAT_Accuracy ] := 0;
		SetSAtt( Attacker^.SA , 'type <ARMORPIERCING>' );
		SetSAtt( Attacker^.SA , 'name <ArmorPiercing>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		SetSAtt( Attacker^.SA , 'type <BRUTAL>' );
		SetSAtt( Attacker^.SA , 'name <Brutal>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		SetSAtt( Attacker^.SA , 'type <OVERLOAD>' );
		SetSAtt( Attacker^.SA , 'name <Overload>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		SetSAtt( Attacker^.SA , 'type <SCATTER>' );
		SetSAtt( Attacker^.SA , 'name <Scatter>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		SetSAtt( Attacker^.SA , 'type <SCATTER BRUTAL>' );
		SetSAtt( Attacker^.SA , 'name <Scatter + Brutal>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		SetSAtt( Attacker^.SA , 'type <HYPER>' );
		SetSAtt( Attacker^.SA , 'name <Hyper>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		SetSAtt( Attacker^.SA , 'type <EXPERIMENTAL>' );
		SetSAtt( Attacker^.SA , 'name <Mystery>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );

		Attacker^.Stat[ STAT_Accuracy ] := 5;
		SetSAtt( Attacker^.SA , 'type <SCATTER BRUTAL HYPER ARMORPIERCING OVERLOAD>' );
		SetSAtt( Attacker^.SA , 'name <Ultima>' );
		TestThisWeapon( GB , AMaster , Attacker , Target );
}
		RemoveGear( Hand^.InvCom , Attacker );
	end;
end;


var
	GB: GameBoardPtr;
	Scene,Hand,AMaster,Target,P1,P2,CP: GearPtr;


begin
	{ For the attacker and defender, load some nice SAN-D1 Daums. }
	{ Install a generic pilot in each. }
	AMaster := LoadNewItem( 'SAN-D1 Daum' );
	CP := SeekGear( AMaster , GG_CockPit , 0 );
	if CP <> Nil then begin
		P1 := LoadNewNPC( 'Arena Pilot' , FALSE );
{		SetNAtt( P1^.NA , NAG_Skill , NAS_SpotWeakness , 10 );
}		SetSkillsAtLevel( P1 , 50 );
		SetNAtt( P1^.NA , NAG_Intrinsic , NAS_Integral , 1 );
		InsertSubCom( CP , P1 );
	end;
	Target := SeekGearByName( AMaster , 'Bolt Cannon' )^.Parent;
	if Target <> Nil then begin
		Hand := Target^.Parent;
		while Hand^.InvCom <> Nil do begin
			Target := Hand^.InvCom;
			RemoveGear( Hand^.InvCom , Target );
		end;
	end else begin
		writeln( 'ERROR: No Bolt Cannon found.' );
	end;

	Target := LoadNewItem( 'AD26c Vadel' );
{	Target := LoadNewSTC( 'ATTACKTEST-TARGET' );}
	CP := SeekGear( Target , GG_CockPit , 0 );
	if CP <> Nil then begin
		P2 := LoadNewNPC( 'Arena Pilot' , FALSE );
		SetNAtt( P2^.NA , NAG_Intrinsic , NAS_Integral , 1 );
		InsertSubCom( CP , P2 );
	end;

	Scene := LoadNewSTC( 'SCENE_EmptyBuilding' );
	GB := RandomMap( Scene );
	AppendGear( GB^.Meks , AMaster );
	AppendGear( GB^.Meks , Target );

	SetNAtt( AMaster^.NA , NAG_Location , NAS_X , Tar_X - 5 );
	SetNAtt( AMaster^.NA , NAG_Location , NAS_Y , Tar_Y );
	SetNAtt( Target^.NA , NAG_Location , NAS_X , Tar_X );
	SetNAtt( Target^.NA , NAG_Location , NAS_Y , Tar_Y );

	results := Nil;

{	TestDC( GB , AMaster , Hand , Target );
	StoreSAtt( results , '  ' );
	TestBV( GB , AMaster , Hand , Target );
	StoreSAtt( results , '  ' );
}
	TestAttributes( GB , AMaster , Hand , Target );
	StoreSAtt( results , '  ' );

{	TestThings( GB , AMaster , Hand , Target , 'MBAZ-17' );
	TestThings( GB , AMaster , Hand , Target , 'PAR-2' );
	TestThings( GB , AMaster , Hand , Target , 'PAR-6' );
	TestThings( GB , AMaster , Hand , Target , 'PAR-13' );
	TestThings( GB , AMaster , Hand , Target , 'PHS-8' );
	TestThings( GB , AMaster , Hand , Target , 'PHS-25' );
	TestThings( GB , AMaster , Hand , Target , 'GR-12' );
	TestThings( GB , AMaster , Hand , Target , 'GR-24' );
	TestThings( GB , AMaster , Hand , Target , 'MAC-4' );
	TestThings( GB , AMaster , Hand , Target , 'RG-8' );
	TestThings( GB , AMaster , Hand , Target , 'RG-16' );
	TestThings( GB , AMaster , Hand , Target , 'MAC-2' );
	TestThings( GB , AMaster , Hand , Target , 'VC-5' );
	TestThings( GB , AMaster , Hand , Target , 'SC-9' );
	TestThings( GB , AMaster , Hand , Target , 'MB-7' );
	TestThings( GB , AMaster , Hand , Target , 'MRIF-5' );
}
	StoreSAtt( results , 'Attacker Skill = ' + BStr( NAttValue( P1^.NA , NAG_Skill , NAS_MechaGunnery ) ) );
	StoreSAtt( results , 'Defender Skill = ' + BStr( NAttValue( P2^.NA , NAG_Skill , NAS_MechaPiloting ) ) );

	SaveStringList( 'atest_out.txt' , results );
	SaveStringList( 'atest_out2.txt' , Skill_Roll_History );

	DisposeSAtt( results );
	DisposeMap( GB );
end.
