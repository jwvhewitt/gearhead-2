Program rnpc;
	{ This program will generate random NPC age, gender, and }
	{ colors. }
{$LONGSTRINGS ON}


uses gears,gearparser,texutil,gearutil,description;

const
	colormenu_mode_allcolors = 0;
	colormenu_mode_character = 1;
	colormenu_mode_mecha = 2;

	Num_Color_Sets = 6;
	CS_Clothing = 1;
	CS_Skin = 2;
	CS_Hair = 3;
	CS_PrimaryMecha = 4;
	CS_SecondaryMecha = 5;
	CS_Detailing = 6;

type
	rnpc_color = Record
		R,G,B,A: Integer;
	end;

	ColorDesc = Record
		name: String;
		rgb: rnpc_Color;
		cs: Array [1..Num_Color_Sets] of Boolean;
	end;

var
	Available_Colors: Array of ColorDesc;
	Num_Available_Colors: Integer;
	Num_Colors_Per_Set: Array [1..Num_Color_Sets] of Integer;


Procedure LoadColorList;
	{ Load the standard colors from disk, and convert them to the colormenu format. }
var
	CList,C: SAttPtr;
	T,tt: Integer;
	msg: String;
begin
	{ Begin by loading the definitions from disk. }
	CList := LoadStringList( Data_Directory + 'sdl_colors.txt' );

	{ Clear the Num_Colors_Per_Set array. }
	for t := 1 to Num_Color_Sets do begin
		Num_Colors_Per_Set[ t ] := 0;
	end;

	{ Now that we know how many colors we're dealing with, we can size the }
	{ colors array to the perfect dimensions. }
	Num_Available_Colors := NumSAtts( CList );
	SetLength( Available_Colors , Num_Available_Colors );

	{ Copy the data into the array. }
	C := CList;
	T := 0;
	while C <> Nil do begin
		msg := RetrieveAPreamble( C^.Info );
		if Length( msg ) < 8 then msg := msg + '------:ERROR';

		Available_Colors[ t ].name := Copy( msg , 8 , 255 );
		for tt := 1 to Num_Color_Sets do begin
			Available_Colors[ t ].cs[tt] := msg[tt] = '+';
			if Available_Colors[ t ].cs[tt] then Inc( Num_Colors_Per_Set[ tt ] );
		end;

		msg := RetrieveAString( C^.Info );
		Available_Colors[ t ].rgb.r := ExtractValue( msg );
		Available_Colors[ t ].rgb.g := ExtractValue( msg );
		Available_Colors[ t ].rgb.b := ExtractValue( msg );

		C := C^.Next;
		Inc( T );
	end;

	{ Get rid of the color definitions. }
	DisposeSAtt( CList );
end;


Function RandomColor( ColorSet: Integer ): Integer;
	{ Select a random color string belonging to the provided color set. }
var
	N,T,it: Integer;
begin
	{ Make sure we've been given a valid color set, and that there are }
	{ colors in the set. }
	if ( ColorSet < 1 ) or ( ColorSet > Num_Color_Sets ) or ( Num_Colors_Per_Set[ ColorSet ] < 1 ) then Exit( 2 );

	{ Select one of the colors at random, then find it. }
	N := Random( Num_Colors_Per_Set[ ColorSet ] );
	T := 0;
	it := -1;
	while ( it = -1 ) and ( T < Num_Available_Colors ) do begin
		if Available_Colors[ t ].cs[ ColorSet ] then begin
			Dec( N );
			if N = -1 then begin
				it := T;
			end;
		end;
		Inc( T );
	end;

	if it <> -1 then begin
		RandomColor := it;
	end else begin
		{ Use bright purple, as a warning that a bug has occurred. }
		RandomColor := 1;
	end;
end;


var
	NPC: GearPtr;
	C: Integer;

begin
	LoadColorList;
	NPC := LoadNewNPC( 'Citizen' , True );

	writeln( GearName( NPC ) );
	writeln( JobAgeGenderDesc( NPC ) );

	C := RandomColor( CS_Skin );
	writeln( 'Skin: ' + Available_Colors[ C ].name + ' (' , Available_Colors[ C ].rgb.r , ' ' , Available_Colors[ C ].rgb.g , ' ' , Available_Colors[ C ].rgb.b , ')' );

	C := RandomColor( CS_Hair );
	writeln( 'Hair: ' + Available_Colors[ C ].name + ' (' , Available_Colors[ C ].rgb.r , ' ' , Available_Colors[ C ].rgb.g , ' ' , Available_Colors[ C ].rgb.b , ')' );

	DisposeGear( NPC );
end.
