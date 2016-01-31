unit rpgdice;
	{This unit handles some of my frequently-wanted dice}
	{routines.}
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
	DieSize: Array [1..5] of byte = (4,6,8,10,12);
	DieStep: Array [1..10,1..5] of byte = (
	{	d4	d6	d8	d10	d12	}
	(	1,	0,	0,	0,	0),
	(	0,	1,	0,	0,	0),
	(	0,	0,	1,	0,	0),
	(	0,	0,	0,	1,	0),
	(	0,	0,	0,	0,	1),

	(	0,	1,	1,	0,	0),
	(	0,	1,	0,	1,	0),
	(	0,	0,	1,	1,	0),
	(	0,	0,	0,	2,	0),
	(	0,	0,	0,	1,	1)
	);

Function Dice(die: integer): Integer;
Function RollStep(n: Integer): Integer;
Function RollStat(n: integer): integer;
	{Roll Nd6; take the three highest values, add them together,}
	{and return the result. N must be in the range of 1 to 10.}

implementation

const
   { Limit on value returned (the Pascal distribution has no natural upper
     bound).  The optimized version requires that the limit be 30 units under
     the maximum value of Integer ($7fff - 30 = 32737).  However, it may 
     be desired to set a lower value to avoid overflows in procedures 
     that call RandPascal().
   }
   SafetyLimit = $7fff - 30;

   {These tables uniform distributed random integers in range 0 .. $3fffffff
    to integer values distributed differently.

    The first (30-N) entries of table N follow a Pascal distribution with 
    parameters (p=1/2, r = N).  The remaining entries follow a binomial 
    distribution with parameters (p=1/2, n = 30).

    These odd distributions allow the equivalent of 30 coinflips to be 
    done with a single call to Random().
  }

   Tables : Array[1..30,1..30] of LongInt =
   (
    ($20000000,$30000000,$38000000,$3c000000,$3e000000,$3f000000,
     $3f800000,$3fc00000,$3fe00000,$3ff00000,$3ff80000,$3ffc0000,
     $3ffe0000,$3fff0000,$3fff8000,$3fffc000,$3fffe000,$3ffff000,
     $3ffff800,$3ffffc00,$3ffffe00,$3fffff00,$3fffff80,$3fffffc0,
     $3fffffe0,$3ffffff0,$3ffffff8,$3ffffffc,$3ffffffe,$3fffffff),
    ($10000000,$20000000,$2c000000,$34000000,$39000000,$3c000000,
     $3dc00000,$3ec00000,$3f500000,$3fa00000,$3fcc0000,$3fe40000,
     $3ff10000,$3ff80000,$3ffbc000,$3ffdc000,$3ffed000,$3fff6000,
     $3fffac00,$3fffd400,$3fffe900,$3ffff400,$3ffff9c0,$3ffffcc0,
     $3ffffe50,$3fffff20,$3fffff8c,$3fffffc4,$3fffffe1,$3fffffff),
    ($08000000,$14000000,$20000000,$2a000000,$31800000,$36c00000,
     $3a400000,$3c800000,$3de80000,$3ec40000,$3f480000,$3f960000,
     $3fc38000,$3fddc000,$3fecc000,$3ff54000,$3ffa0800,$3ffcb400,
     $3ffe3000,$3fff0200,$3fff7580,$3fffb4c0,$3fffd740,$3fffea00,
     $3ffff428,$3ffff9a4,$3ffffc98,$3ffffe2e,$3fffffe1,$3fffffff),
    ($04000000,$0c000000,$16000000,$20000000,$28c00000,$2fc00000,
     $35000000,$38c00000,$3b540000,$3d0c0000,$3e2a0000,$3ee00000,
     $3f51c000,$3f97c000,$3fc24000,$3fdbc000,$3feae400,$3ff3cc00,
     $3ff8fe00,$3ffc0000,$3ffdbac0,$3ffeb7c0,$3fff4780,$3fff98c0,
     $3fffc674,$3fffe00c,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($02000000,$07000000,$0e800000,$17400000,$20000000,$27e00000,
     $2e700000,$33980000,$37760000,$3a410000,$3c358000,$3d8ac000,
     $3e6e4000,$3f030000,$3f62a000,$3f9f3000,$3fc50a00,$3fdc6b00,
     $3feab480,$3ff35a40,$3ff88a80,$3ffba120,$3ffd7450,$3ffe8688,
     $3fff267e,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($01000000,$04000000,$09400000,$10400000,$18200000,$20000000,
     $27380000,$2d680000,$326f0000,$36580000,$3946c000,$3b68c000,
     $3ceb8000,$3df74000,$3eacf000,$3f261000,$3f758d00,$3fa8fc00,
     $3fc9d840,$3fde9940,$3feb91e0,$3ff39980,$3ff886e8,$3ffb86b8,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00800000,$02400000,$05c00000,$0b000000,$11900000,$18c80000,
     $20000000,$26b40000,$2c918000,$3174c000,$355dc000,$38634000,
     $3aa76000,$3c4f5000,$3d7e2000,$3e521800,$3ee3d280,$3f466740,
     $3f881fc0,$3fb35c80,$3fcf7730,$3fe18858,$3fed07a0,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00400000,$01400000,$03800000,$07400000,$0c680000,$12980000,
     $194c0000,$20000000,$2648c000,$2bdec000,$309e4000,$3480c000,
     $37941000,$39f1b000,$3bb7e800,$3d050000,$3df46940,$3e9d6840,
     $3f12c400,$3f631040,$3f9943b8,$3fbd6608,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00200000,$00b00000,$02180000,$04ac0000,$088a0000,$0d910000,
     $136e8000,$19b74000,$20000000,$25ef6000,$2b46d000,$2fe3c800,
     $33bbec00,$36d6ce00,$39475b00,$3b262d80,$3c8d4b60,$3d9559d0,
     $3e540ee8,$3edb8f94,$3f3a69a6,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00100000,$00600000,$013c0000,$02f40000,$05bf0000,$09a80000,
     $0e8b4000,$14214000,$1a10a000,$20000000,$25a36800,$2ac39800,
     $2f3fc200,$330b4800,$36295180,$38a7bf80,$3a9a8570,$3c17efa0,
     $3d35ff44,$3e08c76c,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00080000,$00340000,$00b80000,$01d60000,$03ca8000,$06b94000,
     $0aa24000,$0f61c000,$14b93000,$1a5c9800,$20000000,$2561cc00,
     $2a50c700,$2eae0780,$326bac80,$3589b600,$38121db8,$3a1506ac,
     $3ba582f8,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00040000,$001c0000,$006a0000,$01200000,$02754000,$04974000,
     $079cc000,$0b7f4000,$101c3800,$153c6800,$1a9e3400,$20000000,
     $25286380,$29eb3580,$2e2b7100,$31da9380,$34f6589c,$3785afa4,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00020000,$000f0000,$003c8000,$00ae4000,$0191c000,$03148000,
     $0558a000,$086bf000,$0c441400,$10c03e00,$15af3900,$1ad79c80,
     $20000000,$24f59ac0,$299085e0,$2db58cb0,$3155f2a6,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00010000,$00080000,$00224000,$00684000,$00fd0000,$0208c000,
     $03b0b000,$060e5000,$09293200,$0cf4b800,$1151f880,$1614ca80,
     $1b0a6540,$20000000,$24c842f0,$293ee7d0,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00008000,$00044000,$00134000,$003dc000,$009d6000,$01531000,
     $0281e000,$04481800,$06b8a500,$09d6ae80,$0d945380,$11d48f00,
     $166f7a20,$1b37bd10,$20000000,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00004000,$00024000,$000ac000,$00244000,$0060d000,$00d9f000,
     $01ade800,$02fb0000,$04d9d280,$07584080,$0a764a00,$0e256c80,
     $124a7350,$16c11830,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00002000,$00013000,$0005f800,$00151c00,$003af600,$008a7300,
     $011c2d80,$020b96c0,$0372b4a0,$05657a90,$07ede248,$0b09a764,
     $0eaa0d5a,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00001000,$0000a000,$00034c00,$000c3400,$00239500,$00570400,
     $00b998c0,$016297c0,$026aa630,$03e81060,$05eaf954,$087a505c,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000800,$00005400,$0001d000,$00070200,$00154b80,$003627c0,
     $0077e040,$00ed3c00,$01abf118,$02ca00bc,$045a7d08,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000400,$00002c00,$0000fe00,$00040000,$000ca5c0,$002166c0,
     $004ca380,$009cefc0,$0124706c,$01f73894,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000200,$00001700,$00008a80,$00024540,$00077580,$00146e20,
     $003088d0,$0066bc48,$00c5965a,$015e6777,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000100,$00000c00,$00004b40,$00014840,$00045ee0,$000c6680,
     $001e77a8,$004299f8,$00841829,$015e6777,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000080,$00000640,$000028c0,$0000b880,$00028bb0,$00077918,
     $0012f860,$002ac92c,$00841829,$015e6777,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000040,$00000340,$00001600,$00006740,$00017978,$00047948,
     $000bb8d4,$002ac92c,$00841829,$015e6777,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000020,$000001b0,$00000bd8,$0000398c,$0000d982,$0002a965,
     $000bb8d4,$002ac92c,$00841829,$015e6777,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000010,$000000e0,$0000065c,$00001ff4,$00007cbb,$0002a965,
     $000bb8d4,$002ac92c,$00841829,$015e6777,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000008,$00000074,$00000368,$000011ae,$00007cbb,$0002a965,
     $000bb8d4,$002ac92c,$00841829,$015e6777,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000004,$0000003c,$000001d2,$000011ae,$00007cbb,$0002a965,
     $000bb8d4,$002ac92c,$00841829,$015e6777,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000002,$0000001f,$000001d2,$000011ae,$00007cbb,$0002a965,
     $000bb8d4,$002ac92c,$00841829,$015e6777,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff),
    ($00000001,$0000001f,$000001d2,$000011ae,$00007cbb,$0002a965,
     $000bb8d4,$002ac92c,$00841829,$015e6777,$0328dace,$066a66b2,
     $0b922edb,$12b592c5,$1b608c18,$249f73e8,$2d4a6d3b,$346dd125,
     $3995994e,$3cd72532,$3ea19889,$3f7be7d7,$3fd536d4,$3ff4472c,
     $3ffd569b,$3fff8345,$3fffee52,$3ffffe2e,$3fffffe1,$3fffffff)
  );

Function Dice(die: integer): Integer;
	{Roll a die- D(6), D(8), D(100), whatever.}
	{Die rolling is done as per Earthdawn- whenever a maximum is}
	{rolled, the score is kept and the die rerolled. }
var
	total,dr: Integer;
begin
	{Range check}
	if die < 2 then die := 2;

	total := 0;
	repeat
		dr := Random( die ) + 1;
		total := total + dr;
	until dr <> Die;

	Dice := total;
end;


Function RandPascal(Average : Integer) : Integer;
	{ The Pascal distribution (no relation to the Pascal language) is a
	  discrete distibution, with a lower bound of 0 and an infinite upper 
	  bound (ignoring the degenerate case of a zero average).

	  At Average = 1, it is exactly the same as a geometric distribution (1/2
	  chance of 0, 1/4 chance of 1, 1/8 chance of 2, and so on).  As Average
	  increases it will look more and more like a Gaussian (Bell curve)
	  distribution.

	  For this particular family of Pascal distributions (where the "p" 
	  parameter is 1/2), the standard deviation is the square root of (2 *
	  Average). 

	  The distributions form a smooth progression -- the distribution of 
	  "RandPascal(x)+RandPascal(y)" is the same as "RandPascal(x+y)".
	}
var
    Result, Rolls: Integer;
    SelectedTable : Integer;
    Selector: LongInt;
begin

    Result := 0;

    while Average > 0 do
    begin
        if Average > 30
        then SelectedTable := 30
        else SelectedTable := Average;

        { Obtain a 30-bit random integer, hopefully uniform}
        Selector := Random($40000000);

	{ Open coded binary search to find the number of successes associated 
          with the selector value.  The kink at the end (Rolls < 30) is  
          because the table length is one short of a power of two }
        Rolls := 0;
        if Selector >= Tables[SelectedTable,Rolls + 16] 
          then Rolls := Rolls + 16;
        if Selector >= Tables[SelectedTable,Rolls + 8] 
          then Rolls := Rolls + 8;
        if Selector >= Tables[SelectedTable,Rolls + 4]
          then Rolls := Rolls + 4;
        if Selector >= Tables[SelectedTable,Rolls + 2] 
          then Rolls := Rolls + 2;
        if (Rolls < 30) and (Selector >= Tables[SelectedTable,Rolls + 1]) 
          then Rolls := Rolls + 1;

        { Add number of "White" coinflips to result }
        Result := Result + Rolls;
        { Subtract number of "Black" coinflips from Average.  If Average
          becomes nonpositive, we are done. }
        Average := Average - (30 - Rolls);
 
        if Result >= SafetyLimit then
	begin
            Result := SafetyLimit;
	    Average := 0;
        end;
    end;
    RandPascal := Result;
end;


Function RollStep(n: Integer): Integer;
	{Roll a dice step number, a la Earthdawn.}
var
	RS: Integer;
begin
	if N > 0 then begin
		RS := RandPascal( N );
		if RS < 1 then RS := 1;
	end else begin
		RS := 0;
	end;
	RollStep := RS;
end;

Function RollStat(n: integer): integer;
	{Roll Nd6; take the three highest values, add them together,}
	{and return the result. N must be in the range of 1 to 10.}
var
	k: array [1..10] of integer;
	t,tt: integer;	{Loop counters.}
	l: integer;	{in theory, the low value.}
	stat: integer;	{The total value rolled}
begin
	{Range check.}
	if n>10 then n := 10;

	{Initialize stat}
	stat := 0;

	{Roll the indicated number of dice.}
	for t := 1 to n do begin
		{Roll the die}
		k[t] := Random(6) + 1;

		{Add it to the total}
		stat := stat + k[t];
	end;

	{If we rolled more dice than we need, go through and eliminate}
	{the low rolls.}
	if n > 3 then for t := 1 to n-3 do begin
		{locate the first nonzero value for l}
		l := 1;

		while k[l] = 0 do Inc(l);

		for tt := 1 to n do begin
			if (k[tt] > 0) and (k[tt] < k[l]) then l := tt
		end;
		stat := stat - k[l];
		k[l] := 0;
	end;

	RollStat := stat;
end;


initialization
	{Set the random seed}
	Randomize;

end.
