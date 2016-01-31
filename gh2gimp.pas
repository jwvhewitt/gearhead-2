Program gh2gimp;

uses gears,texutil,colormenu;

Function B3Str( N: Integer ): String;
	{ Return the value as a string which is exactly three characters }
	{ wide. Pad the front of the string with spaces, if needed. }
var
	msg: String;
begin
	msg := BStr( N );
	while Length( msg ) < 3 do msg := ' ' + msg;
	B3Str := msg;
end;

var
	T: Integer;
	F: Text;

begin
	Assign( F , 'GH2_Game.gpl' );
	Rewrite( F );

	writeln( F , 'GIMP Palette' );
	writeln( F , 'Name: GH2_Game.gpl' );
	writeln( F , 'Columns: 0' );
	writeln( F , '#' );

	for T := 0 to ( Num_Available_Colors - 1 ) do begin
		writeln( F , B3Str( Available_Colors[ t ].rgb.r ) + ' ' + B3Str( Available_Colors[ t ].rgb.g ) + ' ' + B3Str( Available_Colors[ t ].rgb.b ) + '	' + Available_Colors[ t ].name );
	end;

	Close( F );
end.
