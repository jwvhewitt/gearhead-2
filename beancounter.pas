Program beancounter;
{
	This program will examine the character development subplots and
	produce a graph of Motivation x Attitude, showing how many options
	exist for each combination.

	It's named for the Beanpole, the 12 episode initial series of the
	core story.
}
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

uses gears,narration,gearutil,texutil,mpbuilder;

const
	Propp_M: Array [0..Num_XXR_Motivations] of Integer = (
		0,
		1,2,7,3,4,
		5,6,8
	);
	Propp_A: Array [0..Num_XXR_Attitudes] of Integer = (
		0,
		11, 1, 2, 12, 10,
		3, 4, 5, 14, 13,
		6, 7, 8, 9
	);


Procedure CountTheBeans( var ResultList: SAttPtr; base_context: String; npc_ident: Char; LList: GearPtr );
	{ Given the listed base_context, find out how many components there are }
	{ in LList which match each Attitude/Motivation combo of the NPC identified }
	{ by NPC_Ident. Store the results as a nicely formatted graph in }
	{ ResultList. }
var
	A,M: Integer;	{ Attitude, Motivation counters. }
	MA_Results: Array [0..Num_XXR_Motivations,0..Num_XXR_Attitudes] of Integer;
	context: String;
	ShoppingList: NAttPtr;
begin
	{ Clear the results array. }
	for A := 0 to Num_XXR_Attitudes do begin
		for M := 0 to Num_XXR_Motivations do begin
			MA_Results[ M , A ] := 0;
		end;
	end;

	{ Start checking the combos. }
	for A := 0 to Num_XXR_Attitudes do begin
		for M := 0 to Num_XXR_Motivations do begin
			{ Generate the context for this combo. }
			Context := base_context + ' ' + npc_ident + ':M.' + XXR_Motivation[ Propp_M[ M ] ] + ' ' + npc_ident + ':A.' + XXR_Attitude[ Propp_A[ A ] ];

			{ Generate a shopping list for this context. }
			ShoppingList := CreateComponentList( LList , Context );

			{ Store the number of legal components, delete the }
			{ shopping list. }
			MA_Results[ M , A ] := NumNAtts( ShoppingList );
			DisposeNAtt( ShoppingList );
		end;
	end;

	{ We should have all the results. Store them in a nicely formatted }
	{ table, just like we used to make all the time on the C64. Yay! }
	{ Start with the motivation key. }
	context := '     ';
	for M := 0 to Num_XXR_Motivations do context := context + ' ' + XXR_Motivation[ Propp_M[ M ] ];
	StoreSAtt( ResultList , Context );
	{ Now, the data cells. }
	for A := 0 to Num_XXR_Attitudes do begin
		context := XXR_Attitude[ Propp_A[ A ] ] + '  ';
		for M := 0 to Num_XXR_Motivations do begin
			if MA_Results[ M , A ] > 0 then begin
				context := context + ' ' + WideStr( MA_Results[ M , A ] , 3 );
			end else begin
				context := context + '  - ';
			end;
		end;
		StoreSAtt( ResultList , Context );
	end;
end;

const
	CS_Enemy_Chardev = '*:CS_MIX_Confrontation *:CS_StopNPCMission&IsEnemyNPC *:CS_MechaEncounter *:CS_GatherInformation *:CS_FetchItem  &Beancounter  E:++ F:++';

var
	ResultList: SAttPtr;

begin
	ResultList := Nil;
	StoreSAtt( ResultList , 'Core Story Enemy Chardev' );
	CountTheBeans( ResultList , CS_Enemy_Chardev + ' !Hi' , 'E' , Sub_Plot_List );
	StoreSAtt( ResultList , '  ' );

	StoreSAtt( ResultList , 'Core Story Confrontation Chardev' );
	CountTheBeans( ResultList , '*:CS_MIX_Confrontation  E:++ F:++ !Hi' , '1' , Sub_Plot_List );
	StoreSAtt( ResultList , '  ' );

	StoreSAtt( ResultList , 'Rookie Enemy Chardev' );
	CountTheBeans( ResultList , CS_Enemy_Chardev + ' !Ne' , 'E' , Sub_Plot_List );
	StoreSAtt( ResultList , '  ' );

	StoreSAtt( ResultList , 'Lancemate NonCom Chardev' );
	CountTheBeans( ResultList , '*LM_NonComCharDev *LM_PersonalJob &BeanCounter !Ne !Lo !Md !Hi !Ex 1:++ 1:TRAIN 1:NOFAC' , '1' , Sub_Plot_List );
	SaveStringList( 'out.txt' , ResultList );
	DisposeSAtt( ResultList );
end.

