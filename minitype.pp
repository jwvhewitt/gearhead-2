unit minitype;
	{ Contains type definitions for the minigame unit. These are separated out }
	{ so that the xxinfo units can see what's going on without using magic numbers. }
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

Const
	MaxAudienceSize = 12;	{ Maximum audience size for concert minigame. }

	Num_Audience_Moods = 6;	{ Number of moods, excluding absent mobs and walking out. }
	MOOD_Absent = -1;
	MOOD_WalkOut = 0;

	CMG_Trait_Emotion = 0;
	CMG_Trait_Beat = 1;
	CMG_Trait_Melody = 2;

Type
	AudienceMember = Record		{ Records an audience mob for the concert minigame. }
		Mood,Trait: Integer;
	end;
	AudienceList = Array [1..MaxAudienceSize] of AudienceMember;
	AudienceListPtr = ^AudienceList;


implementation


end.
