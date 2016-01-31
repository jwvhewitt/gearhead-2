unit menugear;
	{ This is the RPGMenus / Gear Tree utilities unit. }
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
	vidmenus;
{$ELSE}
	sdlmenus;
{$ENDIF}

Procedure BuildGearMenu( RPM: RPGMenuPtr; Master: GearPtr; G: Integer; IncludeDestroyed: Boolean );
Procedure BuildGearMenu( RPM: RPGMenuPtr; Master: GearPtr; G: Integer );
Procedure BuildGearMenu( RPM: RPGMenuPtr; Master: GearPtr );

Procedure BuildEquipmentMenu( RPM: RPGMenuPtr; Master: GearPtr );
Procedure BuildInventoryMenu( RPM: RPGMenuPtr; Master: GearPtr; UseSaleTag: Boolean );
Procedure BuildSlotMenu( RPM: RPGMenuPtr; Master,Item: GearPtr );
Procedure BuildSubMenu( RPM: RPGMenuPtr; Master,Item: GearPtr; DoMultiplicityCheck: Boolean );

Function LocateGearByNumber( Master: GearPtr; Num: Integer ): GearPtr;
Function FindNextWeapon( GB: GameBoardPtr; Master,Weapon: GearPtr; MinRange: Integer ): GearPtr;
Function FindGearIndex( Master , FindThis: GearPtr ): Integer;

Procedure BuildSiblingMenu( RPM: RPGMenuPtr; LList: GearPtr );

Procedure AlphaKeyMenu( RPM: RPGMenuPtr );

implementation

uses effects,gearutil,ghswag,ghweapon,texutil;

Procedure BuildGearMenu( RPM: RPGMenuPtr; Master: GearPtr; G: Integer; IncludeDestroyed: Boolean );
	{ Search through MASTER, adding to menu RPM any part which }
	{ corresponds to descriptor G. Add each matching part to the }
	{ menu, along with its locator number. }
var
	N: Integer;
{ PROCEDURES BLOCK }
	Procedure CheckAlongPath( Part: GearPtr; AddToMenu: Boolean );
		{ CHeck along the path specified. }
	var
		PartOK: Boolean;
	begin
		while Part <> Nil do begin
			Inc(N);
			PartOK := NotDestroyed( Part );
			if ( Part^.G = G ) and AddToMenu and ( PartOK or IncludeDestroyed ) then AddRPGMenuItem( RPM , GearName( Part ) , N );
			if Part^.G = GG_Cockpit then begin
				{ Don't add parts beyond the cockpit barrier. }
				CheckAlongPath( Part^.InvCom , False );
				CheckAlongPath( Part^.SubCom , False );
			end else begin
				CheckAlongPath( Part^.InvCom , AddToMenu and ( PartOK or IncludeDestroyed ) );
				CheckAlongPath( Part^.SubCom , AddToMenu and ( PartOK or IncludeDestroyed ) );
			end;
			Part := Part^.Next;
		end;
	end;
begin
	N := 0;
	if Master^.G = G then AddRPGMenuItem( RPM , GearName( Master ) , 0 );
	CheckAlongPath( Master^.InvCom , True );
	CheckAlongPath( Master^.SubCom , True );
end; { BuildGearMenu }

Procedure BuildGearMenu( RPM: RPGMenuPtr; Master: GearPtr; G: Integer );
	{ Call the above procedure, counting even destroyed gears. }
begin
	BuildGearMenu( RPM , Master , G , True );
end;

Procedure BuildGearMenu( RPM: RPGMenuPtr; Master: GearPtr );
	{ Search through MASTER, adding to menu all parts. }
const
	InvStr = '+';
	SubStr = '>';
var
	N: Integer;
{ PROCEDURES BLOCK }
	Procedure CheckAlongPath( Part: GearPtr; TabPos,Prefix: String );
		{ CHeck along the path specified. }
	begin
		while Part <> Nil do begin
			Inc(N);
			if Part^.G <> GG_AbsolutelyNothing then AddRPGMenuItem( RPM , TabPos + Prefix + GearName( Part ) , N );
			CheckAlongPath( Part^.InvCom , TabPos + '   ' , InvStr );
			CheckAlongPath( Part^.SubCom , TabPos + '   ' , SubStr );
			Part := Part^.Next;
		end;
	end;{CheckAlongPath}
begin
	N := 0;
	AddRPGMenuItem( RPM , GearName( Master ) , 0 );
	CheckAlongPath( Master^.InvCom , '   ' , '+' );
	CheckAlongPath( Master^.SubCom , '   ' , '>' );
end; { BuildGearMenu }

Procedure BuildEquipmentMenu( RPM: RPGMenuPtr; Master: GearPtr );
	{ Create a menu for this master's equipment. Equipment is defined as }
	{ an InvCom of any part other than the master itself. }
var
	N: Integer;
	Procedure CheckAlongPath( Part: GearPtr; IsInv: Boolean );
		{ CHeck along the path specified. }
	var
		msg: String;
	begin
		while Part <> Nil do begin
			Inc(N);
			if ( Part^.G <> GG_AbsolutelyNothing ) and IsInv then begin
				{ Creating a message line for this equipment is made tricky by the }
				{ fact that a pilot riding in a mecha has a separate inventory from }
				{ the mecha itself. }
				if IsMasterGear( Part^.Parent ) then begin
					msg := '[' + GearName( Part^.Parent ) + '] ' + GearName( Part );
				end else begin
					msg := GearName( Part ) + ' [';
					if FindMaster(Part)^.Parent <> Nil then msg := msg + GearName( FindMaster( Part ) ) + ':';
					msg := msg + GearName( Part^.Parent ) + ']';
				end;
				AddRPGMenuItem( RPM , msg , N , SAttValue( Part^.SA , 'DESC' ) );
			end;
			CheckAlongPath( Part^.InvCom , True );
			CheckAlongPath( Part^.SubCom , False );
			Part := Part^.Next;
		end;
	end;{CheckAlongPath}
begin
	N := 0;
	CheckAlongPath( Master^.InvCom , False );
	CheckAlongPath( Master^.SubCom , False );
end; {BuildEquipmentMenu}

Procedure BuildInventoryMenu( RPM: RPGMenuPtr; Master: GearPtr; UseSaleTag: Boolean );
	{ Create a menu for this master's inventory. Inventory is defined as }
	{ any InvCom of the master. }
var
	N,T: Integer;
	Part: GearPtr;
	num_items,num_extras: Integer;
	was_already_added: Array of Boolean;
	Procedure CountTheKids( P: GearPtr );
		{ This procedure ignores the sub/inv components of things }
		{ in the general inventory, but they have to be counted so }
		{ the locator numbers will work properly. }
	begin
		While P <> Nil do begin
			Inc( N );
			if P^.InvCom <> Nil then CountTheKids( P^.InvCom );
			if P^.SubCom <> Nil then CountTheKids( P^.SubCom );
			P := P^.Next;
		end;
	end;
	Function IMString( P: GearPtr; num_copies: Integer ): String;
		{ Given part P, return a string to use in the menu. }
	var
		msg,msg2: String;
		ShotsUsed: Integer;
	begin
		msg := FullGearName( P );

		{ Add extra information, depending upon item type. }
		if UseSaleTag then begin
			msg2 := SAttValue( P^.SA , 'SALETAG' );
			if msg2 <> '' then msg := msg + ' (' + msg2 + ')';
		end else begin
			if P^.G = GG_Weapon then begin
				msg := msg + '  (DC:' + BStr( ScaleDC( P^.V , P^.Scale ) ) + ')';
			end else if ( P^.G = GG_ExArmor ) or ( P^.G = GG_Shield ) then begin
				msg := msg + '  [AC:' + BStr( GearMaxArmor( P ) ) + ']';
			end else if P^.G = GG_Ammo then begin
				ShotsUsed := NAttValue( P^.NA , NAG_WeaponModifier , NAS_AmmoSpent );
				msg := msg + '  (' + BStr( P^.STat[ STAT_AmmoPresent ] - ShotsUSed ) + '/' + BStr( P^.Stat[ STAT_AmmoPresent ] ) + 'a)';
			end;
		end;

		if num_copies > 0 then msg := msg + ' x' + Bstr( num_copies + 1 );

		IMString := Msg;
	end;
	Function CountIdenticalSibs( P1: GearPtr; T1: Integer ): Integer;
		{ Return how many identical siblings this gear has. }
	var
		P2: GearPtr;
		it: Integer;
	begin
		it := 0;
		P2 := P1^.Next;
		while P2 <> Nil do begin
			inc( T1 );
			if GearsAreIdentical( P1 , P2 ) then begin
				Inc( it );
				was_already_added[ t1 ] := True;
			end;
			P2 := P2^.Next;
		end;
		CountIdenticalSibs := it;
	end;
begin
	N := 0;
	Part := Master^.InvCom;
	if Part = Nil then Exit;

	{ Determine the number of items in the inventory, and initialize the Was_Already_Added array. }
	num_items := NumSiblingGears( Part );
	SetLength( was_already_added , num_items + 1 );
	for t := 1 to num_items do was_already_added[ t ] := False;
	T := 0;

	while Part <> Nil do begin
		{ N is the tree index for the current part. T is its sibling index. }
		Inc( N );
		Inc( T );

		if not was_already_added[ t ] then begin
			num_extras := CountIdenticalSibs( Part , T );
			AddRPGMenuItem( RPM , IMString( Part , num_extras ) , N , SAttValue( Part^.SA , 'DESC' ) );
		end;
		if Part^.InvCom <> Nil then CountTheKids( Part^.InvCom );
		if Part^.SubCom <> Nil then CountTheKids( Part^.SubCom );
		Part := Part^.Next;
	end;

end;

Procedure BuildSlotMenu( RPM: RPGMenuPtr; Master,Item: GearPtr );
	{ Search through MASTER, adding to menu all parts which can }
	{ equip ITEM. }
var
	N: Integer;
{ PROCEDURES BLOCK }
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while Part <> Nil do begin
			Inc(N);
			if IsLegalInvCom( Part , Item ) and PartActive( Part ) then AddRPGMenuItem( RPM , GearName( Part ) , N );
			CheckAlongPath( Part^.InvCom );
			CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;{CheckAlongPath}
begin
	N := 0;
	CheckAlongPath( Master^.InvCom );
	CheckAlongPath( Master^.SubCom );
end; { BuildSlotMenu }

Procedure BuildSubMenu( RPM: RPGMenuPtr; Master,Item: GearPtr; DoMultiplicityCheck: Boolean );
	{ Search through MASTER, adding to menu all parts which can }
	{ take ITEM as a subcomponent. }
var
	N: Integer;
{ PROCEDURES BLOCK }
	Function MenuMsg( Part: GearPtr ): String;
	begin
		MenuMsg := GearName( Part ) + ' (' + BStr( SubComComplexity( Part ) ) + '/' + BStr( ComponentComplexity( Part ) ) + ')';
	end;
	Procedure CheckThisBit( Part: GearPtr );
		{ Check this bit, and maybe add it to the menu. }
	begin
		if DoMultiplicityCheck then begin
			if CanBeInstalled( Part , Item ) then AddRPGMenuItem( RPM , MenuMsg( Part ) , N );
		end else begin
			if IsLegalSubCom( Part , Item ) then AddRPGMenuItem( RPM , GearName( Part ) , N );
		end;
	end;
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while Part <> Nil do begin
			Inc(N);
			CheckThisBit( Part );
			CheckAlongPath( Part^.InvCom );
			CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;{CheckAlongPath}
begin
	N := 0;
	CheckThisBit( Master );
	CheckAlongPath( Master^.InvCom );
	CheckAlongPath( Master^.SubCom );
end; { BuildSubMenu }


Procedure BuildSiblingMenu( RPM: RPGMenuPtr; LList: GearPtr );
	{ Build a menu of these sibling gears. The index numbers will be }
	{ sibling indicies, not the universal gear numbers used in other }
	{ procedures here. }
var
	N: Integer;
begin
	N := 1;
	while LList <> Nil do begin
		AddRPGMenuItem( RPM , FullGearName( LList ) , N );
		Inc( N );
		LList := LList^.Next;
	end;
end;

Function LocateGearByNumber( Master: GearPtr; Num: Integer ): GearPtr;
	{ Locate the Nth part in the tree. }
var
	N: Integer;
	TheGearWeWant: GearPtr;
{ PROCEDURES BLOCK. }
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while ( Part <> Nil ) and ( TheGearWeWant = Nil ) do begin
			Inc(N);
			if N = Num then TheGearWeWant := Part;
			if TheGearWeWant = Nil then CheckAlongPath( Part^.InvCom );
			if TheGearWeWant = Nil then CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
begin
	TheGearWeWant := Nil;
	N := 0;

	{ Part 0 is the master gear itself. }
	if Num < 1 then Exit( Master );

	CheckAlongPath( Master^.InvCom );
	if TheGearWeWant = Nil then CheckAlongPath( Master^.SubCom );

	LocateGearByNumber := TheGearWeWant;
end; { LocateGearByNumber }

Function FindNextWeapon( GB: GameBoardPtr; Master,Weapon: GearPtr; MinRange: Integer ): GearPtr;
	{ This procedure will check recursively through MASTER looking }
	{ for the first weapon (ready to fire) in standard order following PART. }
	{ If MinRange > 0, the weapon's range or throwing range must exceed MinRange. }
	{ If no further weapons are found, it will return the first }
	{ weapon. }
var
	FirstWep,NextWep: GearPtr;
	FoundStart: Boolean;
{ PROCEDURES BLOCK }
	Function WeaponIsOkay( W: GearPtr ): Boolean;
		{ Return TRUE if W is ready to fire and meets our other criteria, or }
		{ FALSE otherwise. }
	begin
		if MinRange = 0 then begin
			WeaponIsOkay := ReadyToFire( GB , Master , W );
		end else begin
			WeaponIsOkay := ReadyToFire( GB , Master , W ) and ( ( WeaponRange( GB , W , RANGE_Long ) >= MinRange ) or ( ThrowingRange( GB , Master , W ) >= MinRange ) );
		end;
	end;
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while Part <> Nil do begin
			if WeaponIsOkay( Part ) then begin
				if FirstWep = Nil then FirstWep := Part;
				if FoundStart and ( NextWep = Nil ) then NextWep := Part;
			end;

			if Part = Weapon then FoundStart := True;

			CheckAlongPath( Part^.InvCom );
			CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
begin
	FirstWep := Nil;
	NextWep := Nil;

	if Weapon = Nil then FoundStart := True
	else FoundStart := False;

	CheckAlongPath( Master^.InvCom );
	CheckAlongPath( Master^.SubCom );

	{ Return either the next weapon or the first weapon, }
	{ depending upon what we found. }
	if NextWep = Nil then begin
		if FirstWep = Nil then FindNextWeapon := Weapon
		else FindNextWeapon := FirstWep;
	end else FindNextWeapon := NextWep;
end; { FindNextWeapon }

Function FindGearIndex( Master , FindThis: GearPtr ): Integer;
	{ Search through master looking for FINDTHIS. }
	{ Once found, return its index number. Return -1 if it }
	{ cannot be found. }
var
	N,it: Integer;
{ PROCEDURES BLOCK }
	Procedure CheckAlongPath( Part: GearPtr );
		{ CHeck along the path specified. }
	begin
		while ( Part <> Nil ) and ( it = -1 ) do begin
			Inc(N);
			if ( Part = FindThis ) then it := N;
			CheckAlongPath( Part^.InvCom );
			CheckAlongPath( Part^.SubCom );
			Part := Part^.Next;
		end;
	end;
begin
	N := 0;
	it := -1;
	if Master = FindThis then it := 0;
	CheckAlongPath( Master^.InvCom );
	CheckAlongPath( Master^.SubCom );
	FindGearIndex := it;
end; { FindGearIndex }

Procedure AlphaKeyMenu( RPM: RPGMenuPtr );
	{ Alter this menu so that each item in it has a letter key }
	{ hotlinked. }
	{ This procedure has nothing to do with gears, but it's easier }
	{ to stick it here than keep two copies in the conmenus and }
	{ sdlmenus units. What I really need is a separate menu-utility }
	{ unit, I guess. }
var
	Key: Char;
	MI: RPGMenuItemPtr;
begin
	{ The hotkeys start with 'a'. }
	Key := 'a';

	MI := RPM^.firstitem;
	while MI <> Nil do begin
		{ Alter the message. }
		MI^.msg := Key + ') ' + MI^.msg;

		{ Add the key. }
		AddRPGMenuKey( RPM , Key , MI^.value );

		{ Move to the next letter in the series. }
		{ note that only 52 letters can be assigned. }
		if key = 'z' then key := 'A'
		else inc( key );

		MI := MI^.Next;
	end;
end;

end.
