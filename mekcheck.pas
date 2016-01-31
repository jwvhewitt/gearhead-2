program mekcheck;

uses wmonster,gears,gearparser,gearutil,texutil;

var
	Class_Size_Limit: Array [1..10] of LongInt;


Procedure Filter_Mecha_List( var LList: GearPtr );
	{ Check this list. Remove anything that isn't a mecha. }
var
	I, I2: GearPtr;
begin
	I := LList;
	while I <> Nil do begin
		I2 := I^.Next;
		if I^.G <> GG_Mecha then RemoveGear( LList , I );
		I := I2;
	end;
end;

Function EMLWideStr( N,Width: LongInt ): String;
	{ Pack the string with spaces until it's the specified width. }
var
	msg: String;
begin
	msg := BStr( Abs( N ) );
	if N < 0 then msg := '-' + msg;
	while Length( msg ) < Width do msg := ' ' + msg;
	EMLWideStr := msg;
end;


Procedure Examine_Mecha_List( mecha_list: GearPtr; Facs,Faction_Desig: String );
	{ Examine the mecha list. See how complete its mecha spectrum is. }
const
	UTYPE_General = 'GENERAL';
	UTYPE_Assault = 'ASSAULT';
	UTYPE_Defense = 'DEFENSE';
	UType_Desig: Array [1..3] of String = (
		UTYPE_General, UTYPE_Assault, UTYPE_Defense
	);
	Role_Desig: Array [1..3] of String = (
		'TROOPER', 'SUPPORT', 'COMMAND'
	);
	ROLE_Trooper = 1;
	ROLE_Support = 2;
	ROLE_Command = 3;

	Function MechaRole( Mek: GearPtr; const UNIT_TYPE: String ): Integer;
		{ Return the role of this mecha, given the faction and unit type. }
	var
		roles: String;
		P: Integer;
	begin
		{ Error check- if no faction, no role. }
		if Faction_Desig = '' then Exit( 0 );

		{ Obtain the proper ROLE string from the mecha. }
		roles := UpCase( SAttValue( Mek^.SA , 'ROLE_' + Faction_Desig ) );

		{ Next, locate the clause pertaining to this unit type. }
		P := Pos( Unit_Type , roles );
		if ( P <> 0 ) and ( Length( roles ) >= ( P + Length( Unit_Type ) + 2 ) ) then begin
			Case roles[ P + Length( Unit_Type ) + 1 ] of
				'T':	P := ROLE_Trooper;
				'S':	P := ROLE_Support;
				'C':	P := ROLE_Command;
			else P := 0;
			end;
		end;
		MechaRole := P;
	end;

var
	Mecha_Graph: Array [1..10,1..3] of Integer;
	Army_List: Array [1..3,1..3] of SAttPtr;	{ X = Unit Type, Y = Role }
	mek: GearPtr;
	t,tt,total: Integer;
	mekval: LongInt;
	m: SAttPtr;
begin
	{ Start by clearing the graph. }
	for t := 1 to 10 do begin
		for tt := 1 to 3 do begin
			Mecha_Graph[ t , tt ] := 0;
		end;
	end;

	{ Also clear the army list. }
	for t := 1 to 3 do begin
		for tt := 1 to 3 do begin
			Army_List[ t , tt ] := Nil;
		end;
	end;

	{ Next, fill the graph. }
	mek := mecha_list;
	total := 0;
	while mek <> Nil do begin
		if PartAtLeastOneMatch( SAttValue( Mek^.SA , 'FACTIONS' ) , Facs ) then begin
			{ This mecha can be used by this faction. Let's see where it fits. }
			mekval := GearValue( mek );

			t := 1;
			tt := 0;
			while ( tt = 0 ) and ( t < 11 ) do begin
				if mekval <= Class_Size_Limit[ t ] then tt := t;
				Inc( T );
			end;

			if tt <> 0 then begin
				Inc( Mecha_Graph[ tt , 1 ] );
				Inc( Total );
			end;

			{ While we're at it, file this mek away in the army }
			{ list, if appropriate. }
			for t := 1 to 3 do begin
				tt := MechaRole( Mek , UTYPE_Desig[ t ] );
				if ( tt >= 1 ) and ( tt <= 3 ) then begin
					StoreSAtt( Army_List[ t , tt ] , EMLWideStr( GearValue( Mek ) , 12 ) + '   ' + FullGearName( Mek ) );
				end;
			end;
		end;

		mek := mek^.next;
	end;

	{ Output the graph }
	for t := 1 to 10 do begin
		write( '  ' + WideStr( T , 2 ) + ': ' );
		for tt := 1 to Mecha_Graph[ t , 1 ] do write( '*' );
		writeln();
	end;
	writeln( ' Total: ' , total );

	{ Output the army list. }
	writeln( '  ' );
	writeln( ' ARMY LIST' );
	for t := 1 to 3 do begin
		writeln( '  ' + UTYPE_DESIG[ t ] );
		for tt := 1 to 3 do begin
			writeln( '    ' + ROLE_DESIG[ tt ] );
			if Army_List[ t , tt ] <> Nil then begin
				SortStringList( Army_List[ t , tt ] );
				m := Army_List[ t , tt ];
				while m <> Nil do begin
					writeln( m^.info );
					m := m^.Next;
				end;
			end else begin
				writeln( '               ...' );
			end;
		end;
		writeln( '  ' );
	end;

	{ Dispose of the army list. }
	for t := 1 to 3 do begin
		for tt := 1 to 3 do begin
			DisposeSAtt( Army_List[ t , tt ] );
		end;
	end;
end;

Procedure CalcBARat( llist: GearPtr );
	{ Go through every mecha in LList. Calculate the percentage of mecha cost }
	{ not related to weapons. }
	Function WeaponsOnlyValue( plist: GearPtr ): LongInt;
		{ Return the value of this list's weapons. }
	var
		it: LongInt;
	begin
		it := 0;
		while plist <> Nil do begin
			if plist^.G = GG_Weapon then begin
				it := it + GearCost( plist );
			end else begin
				it := it + WeaponsOnlyValue( plist^.subcom );
				it := it + WeaponsOnlyValue( plist^.invcom );
			end;
			plist := plist^.next;
		end;
		WeaponsOnlyValue := it;
	end;
var
	msg: String;
	tval,wval: LongInt;
	mlist,m: SAttPtr;
begin
	mlist := Nil;
	while llist <> Nil do begin
		tval := GearCost( llist );
		wval := WeaponsOnlyValue( llist^.subcom );
		if wval > tval then wval := tval;

		msg := WideStr( tval - wval , 9 ) + '   ' + FullGearName( llist ) + ': ';
		while Length( msg ) < 45 do msg := msg + ' ';

		msg :=  msg + '%' + BStr( ( ( tval - wval ) * 100 ) div tval );

		StoreSAtt( mlist , msg );
		llist := llist^.next;
	end;

	SortStringList( mlist );
	m := mlist;
	while m <> Nil do begin
		writeln( m^.info );
		m := m^.Next;
	end;
	DisposeSAtt( mlist );
end;


var
	t: Integer;
	mecha_list,F: GearPtr;

begin
	writeln( 'Mecha Class Value Maximums' );
	for t := 1 to 10 do begin
		Class_Size_Limit[ t ] := OptimalMechaValue( t * 10 + 5 ) * 2;
		writeln( '  ' + WideSTr( t , 2 ) , ': ' , OptimalMechaValue( t * 10 - 5 ) , '-' , Class_Size_Limit[ t ] );
	end;

	mecha_list := AggregatePattern( '*.txt' , Design_Directory );
	Filter_Mecha_List( mecha_list );

	writeln();
	writeln( 'General Mecha' );
	Examine_Mecha_List( mecha_list , 'GENERAL' , '' );

	F := Factions_LIst;
	while F <> Nil do begin
		writeln();
		writeln( GearName( F ) + ' Mecha' );
		Examine_Mecha_List( mecha_list , 'GENERAL ' + SAttValue( F^.SA , 'DESIG' ) , SAttValue( F^.SA , 'DESIG' ) );

		F := F^.Next;
	end;

	writeln();
	writeln( 'MECHA BODY/ARMAMENT RATING' );
	CalcBARat( mecha_list );

	DisposeGear( mecha_list );
end.
