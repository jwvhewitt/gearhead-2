program nametest;

uses gears,ghchars;

var
	avg_name_length: LongInt;

Function NameAlreadyExists( LList: SAttPtr; name: String ): Boolean;
	{ Return TRUE if name is found in LList, or FALSE otherwise. }
var
	IsFound: Boolean;
begin
	IsFound := False;
	while ( LList <> Nil ) and ( not IsFound ) do begin
		if LList^.Info = name then IsFound := True;
		LList := LList^.Next;
	end;
	NameAlreadyExists := IsFound;
end;

Function NamesUntilRepeat: LongInt;
	{ Start generating random names. Stop when a duplicate name is found. }
var
	NList: SAttPtr;
	N,L: LongInt;
	name: String;
	NameRepeated: Boolean;
begin
	NList := nil;
	N := 0;
	L := 0;
	NameRepeated := False;
	repeat
		name := UpCase( RandomName );
		L := L + Length( name );
		Inc( N );

		if NameAlreadyExists( NList , name ) then begin
			writeln( name , '  ' , N );
			NameRepeated := True;
		end else begin
			StoreSAtt( NList , name );
		end;

	until ( N > 9999 ) or NameRepeated;
	DisposeSAtt( NList );
	if N > 0 then avg_name_length := avg_name_length + ( L div N );
	NamesUntilRepeat := N;
end;

const
	NumTrials = 5000;

var
	T: Integer;
	N: LongInt;

begin
	Randomize;
	N := 0;
	avg_name_length := 0;
	for T := 1 to NumTrials do begin
		N := N + NamesUntilRepeat;
	end;

	writeln( 'Average: ' , N div NumTrials );
	writeln( 'Average length: ' , avg_name_length div NumTrials );
end.
