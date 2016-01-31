Program www_build;
	{ Update the GH2 web pages. }
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

uses gears,gearparser,texutil,gearutil,description;


var
	MechaBlueprint: GearPtr;
	MechaTemplate,TheLine,FName,FList: SAttPtr;
	PageList: SAttPtr;
	MechaDesc,MD: SAttPtr;
	PageID: Integer;
	F: Text;
	msg,prev_id,next_id,mecha_name: String;
	GHVersion: String;

begin
	{ Create the main index page. }
	{ First we need to know the version number being built. }
	GHVersion := ParamStr( 1 );

	MechaTemplate := LoadStringList( 'web_input/index_template.txt' );

	Assign( F , 'web_output/index.html' );
	Rewrite( F );
	TheLine := MechaTemplate;

	while TheLine <> Nil do begin
		msg := TheLine^.Info;
		ReplacePat( msg , '*version*' , GHVersion );
		writeln( F , msg );

		TheLine := TheLine^.Next;
	end;

	DisposeSAtt( MechaTemplate );
	Close( F );


	{ Load the mecha page template. }
	MechaTemplate := LoadStringList( 'web_input/mecha_template.txt' );

	{ Check the mecha directory for blueprints. }
	FList := CreateFileList( 'design/*.txt' );

	{ Sort the mecha by alphabetical order. }
	SortStringList( FList );

	{ Initialize the page list. }
	PageList := Nil;

	{ Create each individual mecha page. }
	FName := FList;
	PageID := 0;
	while FName <> Nil do begin
		MechaBluePrint := LoadFile( 'design/' + FName^.info );
		StoreSAtt( PageList , GearName( MechaBluePrint ) );

		Assign( F , 'web_output/mecha_' + BStr( PageID ) + '.html' );
		Rewrite( F );

		if PageID = 0 then Prev_id := BStr( NumSAtts( FList ) - 1 )
		else Prev_id := BStr( PageID - 1 );
		if FName^.Next = Nil then Next_ID := '0'
		else Next_ID := BStr( PageID + 1 );

		TheLine := MechaTemplate;
		while TheLine <> Nil do begin
			{ Do the needed substitutions here. }
			msg := TheLine^.Info;

			if UpCase( msg ) = '*STATS*' then begin
				msg := MechaDescription( MechaBlueprint );

			end else if UpCase( msg ) = '*COST*' then begin
				msg := '$' + BStr( GearValue( MechaBlueprint ) );

			end else if UpCase( msg ) = '*DESC*' then begin
				{ If there's an external description file, use that. }
				{ Otherwise use the desc string attribute. }
				MechaDesc := LoadStringList( 'web_input/mecha_' + GearName( MechaBlueprint ) + '.txt' );
				if MechaDesc <> Nil then begin
					msg := '';
					MD := MechaDesc;
					while MD <> Nil do begin
						writeln( F , MD^.Info );
						MD := MD^.Next;
					end;
					DisposeSAtt( MechaDesc );
				end else begin
					msg := '<P ALIGN="LEFT">' + SAttValue( MechaBlueprint^.SA , 'desc' ) + '</P>';
				end;

			end else begin
				ReplacePat( msg , '*name*' , GearName( MechaBlueprint ) );
				ReplacePat( msg , '*prev*' , Prev_id );
				ReplacePat( msg , '*next*' , Next_id );
			end;


			writeln( F , msg );
			TheLine := TheLine^.Next;
		end;

		Close( F );

		DisposeGear( MechaBluePrint );
		Inc( PageID );
		FName := FName^.Next;
	end;

	{ Create the mecha index page. }
	DisposeSATt( MechaTemplate );
	MechaTemplate := LoadStringList( 'web_input/mecha_index.txt' );

	Assign( F , 'web_output/mecha_index.html' );
	Rewrite( F );
	TheLine := MechaTemplate;

	while TheLine <> Nil do begin
		if UpCase( TheLine^.Info ) = '*MECHA_LIST*' then begin
			MD := PageList;
			PageID := 0;
			while MD <> Nil do begin
				writeln( F , '<LI><A HREF="mecha_' + BStr( PageID ) + '.html">' + MD^.Info + '</A>' );
				Inc( PageID );
				MD := MD^.Next;
			end;
		end else begin
			writeln( F , TheLine^.Info );
		end;
		TheLine := TheLine^.Next;
	end;

	Close( F );

	{ Dispose of dynamic resources. }
	DisposeSAtt( FList );
	DisposeSAtt( PageList );
	DisposeSATt( MechaTemplate );
end.
