{ ==================================================================== }
{                                                                      }
{   TETRIS (1986) -- reconstructed source code                         }
{                                                                      }
{   (C) AcademySoft CCAS USSR Moscow, 1986                             }
{   Game by A. Pajitnov & V. Gerasimov                                 }
{                                                                      }
{   Recovered by reverse engineering of the original TETRIS.COM        }
{   (24245 bytes, Turbo Pascal 3.0, "Copyright (C) 1985 BORLAND Inc"). }
{                                                                      }
{   The original was written in Turbo Pascal 3.0, so this port is      }
{   also in Pascal, preserving the original program structure: the     }
{   same procedures, variables and formulas.                           }
{                                                                      }
{ ==================================================================== }
{$R-}{$Q-}{$S-}{$A-}{$N-}{$E-}
program Tetris;
uses Crt, Dos;

const
  RightWallX = 11; BottomWallY = 21;
  PlayW = 10; PlayH = 20; Wall = 9;
  GlassCol = 15; GlassRow = 1;
  MaxState = 19; HiCount = 20;

type
  Shape = record
    dx,dy: array[0..3] of Integer
  end;
  PlayerName = string[15];
  HiRec = packed record
    Name: PlayerName;
    Level: Integer;
    Score: Real                 { TP 6-byte real }
  end;
  HiFile = file of HiRec;
  ScreenBuf = array[0..3999] of Integer;

const
  Shapes: array[1..MaxState] of Shape = (
    (dx:(-1,0,-1,0);dy:(0,0,1,1)),
    (dx:(-1,0,1,0);dy:(1,0,0,1)),
    (dx:(-1,0,1,0);dy:(0,0,1,1)),
    (dx:(-1,0,1,-2);dy:(0,0,0,0)),
    (dx:(-1,0,1,-1);dy:(0,0,0,1)),
    (dx:(-1,0,1,0);dy:(0,0,0,1)),
    (dx:(-1,0,1,1);dy:(0,0,0,1)),
    (dx:(1,0,0,1);dy:(1,0,-1,0)),
    (dx:(0,0,1,1);dy:(1,0,-1,0)),
    (dx:(0,0,0,0);dy:(1,0,-1,2)),
    (dx:(0,0,0,1);dy:(1,0,-1,1)),
    (dx:(1,0,-1,1);dy:(0,0,0,-1)),
    (dx:(0,0,0,-1);dy:(-1,0,1,-1)),
    (dx:(0,0,0,1);dy:(1,0,-1,0)),
    (dx:(1,0,-1,0);dy:(0,0,0,-1)),
    (dx:(0,0,0,-1);dy:(-1,0,1,0)),
    (dx:(0,0,0,1);dy:(1,0,-1,-1)),
    (dx:(1,0,-1,-1);dy:(0,0,0,-1)),
    (dx:(0,0,0,-1);dy:(-1,0,1,1)) );
  RotateTo: array[1..MaxState] of Integer =
    (1,8,9,10,11,14,17,2,3,4,12,13,5,15,16,6,18,19,7);
  PieceColor: array[0..9] of Integer = (0,1,2,3,4,5,6,7,9,9);
  LevelLines: array[0..9] of Integer =
    (10,20,30,40,50,60,70,80,90,100);
  StatRow: array[1..7] of Integer = (15,11,13,7,5,9,17);
  StatCells: array[1..7,0..3,0..1] of Integer = (
    ((32,15),(33,15),(32,16),(33,16)),
    ((32,11),(33,11),(31,12),(32,12)),
    ((28,13),(29,13),(29,14),(30,14)),
    ((30,7),(31,7),(32,7),(33,7)),
    ((28,5),(29,5),(30,5),(28,6)),
    ((28,9),(29,9),(30,9),(29,10)),
    ((28,17),(29,17),(30,17),(30,18)) );

var
  Glass: array[0..RightWallX,0..BottomWallY] of Integer;
  RowCount: array[0..PlayH] of Integer;
  FallDelayUnits,CurrentShapeState,CurrentPieceKind: Integer;
  CurX,CurY: Integer;
  PieceLanded: Boolean;
  Score,NextBonusScore,Level,StartLevel,NextPieceKind,Lines: Integer;
  ShowNext: Boolean;
  Stats: array[1..7] of Integer;
  TotalPieces: Integer;
  HiTable: array[1..HiCount] of HiRec;
  WideMode: Boolean;
  PreviousNext: Integer;
  SavedCursor: Word;
  SaveBuf: ScreenBuf;
  SavedX,SavedY: Byte;
  VideoSeg: Word;
  TpSeed: LongInt;

function TpRandom(N: Integer): Integer;
var Raw: LongInt;
begin
  TpSeed := TpSeed * 129 + $361962E9;
  Raw := ((TpSeed shr 16) and $FFFF) shr 1;
  TpRandom := Raw mod N
end;

procedure SeedOriginalRandom;
var H,M,S,HS: Word;
begin
  GetTime(H,M,S,HS);
  TpSeed := (LongInt((H shl 8) or M) shl 16) or
            LongInt((S shl 8) or HS)
end;

procedure DetectWideMode;
begin
  WideMode := Mem[$0040:$0049]=7;
  SavedCursor := MemW[$0040:$0060]
end;

procedure DetectVideoSeg;
begin
  if WideMode then VideoSeg:=$B000 else VideoSeg:=$B800
end;

procedure SetTextMode(M: Integer);
begin
  if WideMode then TextMode(7) else TextMode(M)
end;
procedure SetTextMode3; begin SetTextMode(CO80) end;
procedure SetTextMode1; begin SetTextMode(CO40) end;

procedure HideCursor;
var R: Registers;
begin R.AH:=$01; R.CX:=$3030; Intr($10,R) end;
procedure ShowCursor;
var R: Registers;
begin R.AH:=$01; R.CX:=SavedCursor; Intr($10,R) end;

procedure SaveScreen;
var I: Integer;
begin
  SavedX:=WhereX; SavedY:=WhereY; DetectVideoSeg;
  for I:=0 to 3999 do SaveBuf[I]:=MemW[VideoSeg:I*2]
end;

procedure RestoreScreen;
var I: Integer;
begin
  DetectVideoSeg;
  for I:=0 to 3999 do MemW[VideoSeg:I*2]:=SaveBuf[I];
  if (SavedX<1) or (SavedX>80) or (SavedY<1) or (SavedY>25) then
  begin SavedX:=1; SavedY:=1 end;
  GotoXY(SavedX,SavedY)
end;

procedure GotoXYW(X,Y: Integer);
begin if WideMode then GotoXY(X+X-1,Y) else GotoXY(X,Y) end;
procedure WriteWF(S: string; Filler: Char);
var I: Integer;
begin
  if WideMode then
    for I:=1 to Length(S) do Write(S[I],Filler)
  else Write(S)
end;
procedure WriteW(S: string); begin WriteWF(S,' ') end;
procedure WriteWSolid(S: string);
var I: Integer;
begin
  if WideMode then
    for I:=1 to Length(S) do Write(S[I],S[I])
  else Write(S)
end;

procedure DrawCell(GX,GY,Kind: Integer);
begin
  if GY=0 then Exit;
  GotoXYW(GlassCol+GX,GlassRow+GY);
  if Kind=Wall then
  begin TextBackground(Black); TextColor(LightBlue); WriteWSolid(Chr(15)) end
  else if Kind=0 then
  begin
    TextBackground(Black); TextColor(Blue);
    if Odd(GX) then WriteW(' ') else WriteW('.')
  end
  else
  begin TextBackground(Kind); WriteWSolid(' '); TextBackground(Black) end;
  TextColor(LightGray)
end;

procedure DrawPiece(X,Y,State: Integer);
var I: Integer;
begin
  for I:=0 to 3 do
    DrawCell(X+Shapes[State].dx[I],Y+Shapes[State].dy[I],
             PieceColor[CurrentPieceKind])
end;
procedure ErasePiece(X,Y,State: Integer);
var I: Integer;
begin
  for I:=0 to 3 do
    DrawCell(X+Shapes[State].dx[I],Y+Shapes[State].dy[I],0)
end;

function Fits(X,Y,State: Integer): Boolean;
var I,GX,GY: Integer; OK: Boolean;
begin
  OK:=True;
  for I:=0 to 3 do
  begin
    GX:=X+Shapes[State].dx[I]; GY:=Y+Shapes[State].dy[I];
    if (GX<0) or (GX>RightWallX) or (GY<0) or (GY>BottomWallY) then
      OK:=False
    else if Glass[GX,GY]<>0 then OK:=False
  end;
  Fits:=OK
end;

procedure DrawScore;
begin
  TextBackground(Black); TextColor(LightGray);
  GotoXYW(1,2); WriteW('Your level:'); Write(Level:2);
  GotoXYW(1,3); WriteW('Full lines:'); Write(Lines:2,' ');
  GotoXYW(2,5); WriteW('SCORE'); TextColor(Brown);
  GotoXYW(8,5); Write(Score:5); TextColor(LightGray)
end;

procedure DrawStats;
var I,K: Integer;
begin
  TextBackground(Black); TextColor(LightGray);
  GotoXYW(30,4); WriteW('STATISTICS');
  for I:=1 to 7 do
  begin
    TextBackground(I);
    for K:=0 to 3 do
    begin GotoXYW(StatCells[I,K,0]+1,StatCells[I,K,1]+1); WriteWSolid(' ') end;
    TextBackground(Black); TextColor(I);
    GotoXYW(36,StatRow[I]+1); WriteW('-');
    GotoXYW(37,StatRow[I]+1); Write(Stats[I]:4)
  end;
  TextColor(LightGray); GotoXYW(29,20); WriteWF('------------','-');
  GotoXYW(31,21); WriteW(Chr(228)); GotoXYW(36,21); WriteW(':');
  GotoXYW(37,21); Write(TotalPieces:4)
end;

procedure DrawNext;
const CenterX=6; CenterY=22;
var I: Integer;
begin
  TextBackground(Black); TextColor(LightGray);
  GotoXYW(4,20); WriteW('Next:');
  for I:=0 to 3 do
  begin
    GotoXYW(CenterX+Shapes[PreviousNext].dx[I],
            CenterY+Shapes[PreviousNext].dy[I]); WriteWSolid(' ')
  end;
  if not ShowNext then Exit;
  TextBackground(PieceColor[NextPieceKind]);
  for I:=0 to 3 do
  begin
    GotoXYW(CenterX+Shapes[NextPieceKind].dx[I],
            CenterY+Shapes[NextPieceKind].dy[I]); WriteWSolid(' ')
  end;
  TextBackground(Black); TextColor(LightGray); PreviousNext:=NextPieceKind
end;

procedure DrawHelp;
begin
  TextBackground(Black); TextColor(LightGray);
  GotoXYW(4,9); WriteW('H E L P');
  GotoXYW(2,11); WriteW('7:Left'); GotoXYW(2,12); WriteW('9:Right');
  GotoXYW(2,13); WriteW('8:Rotate'); GotoXYW(2,14); WriteW('1:Draw next');
  GotoXYW(2,15); WriteW('6:Speed up'); GotoXYW(2,16); WriteW('4:Drop');
  GotoXYW(3,17); WriteW('SPACE:Drop')
end;

procedure DrawFrame;
var X,Y: Integer;
begin
  TextBackground(Black); TextColor(LightGray); ClrScr;
  for Y:=1 to BottomWallY do for X:=0 to RightWallX do DrawCell(X,Y,Glass[X,Y]);
  DrawHelp; TextBackground(Black); TextColor(Red);
  GotoXYW(15,24); WriteW('Play TETRIS !'); TextColor(LightGray);
  DrawScore; DrawStats; DrawNext; HideCursor
end;

procedure RedrawGlass(YFrom,YTo: Integer);
var X,Y: Integer;
begin for Y:=YFrom to YTo do for X:=1 to PlayW do DrawCell(X,Y,Glass[X,Y]) end;

function NewPiece: Boolean;
begin
  CurrentShapeState:=NextPieceKind; NextPieceKind:=TpRandom(7)+1;
  CurX:=6; CurY:=1; NewPiece:=Fits(CurX,CurY,CurrentShapeState);
  CurrentPieceKind:=CurrentShapeState; DrawPiece(CurX,CurY,CurrentShapeState);
  Inc(Stats[CurrentPieceKind]); Inc(TotalPieces); DrawStats;
  if ShowNext then DrawNext
end;

procedure StepDown;
begin
  if Fits(CurX,CurY+1,CurrentShapeState) then
  begin ErasePiece(CurX,CurY,CurrentShapeState); Inc(CurY); DrawPiece(CurX,CurY,CurrentShapeState) end
  else PieceLanded:=True;
  Dec(Score); if Score<0 then Score:=0
end;
procedure MoveLeft;
begin
  if Fits(CurX-1,CurY,CurrentShapeState) then
  begin ErasePiece(CurX,CurY,CurrentShapeState); Dec(CurX); DrawPiece(CurX,CurY,CurrentShapeState); PieceLanded:=False end
end;
procedure MoveRight;
begin
  if Fits(CurX+1,CurY,CurrentShapeState) then
  begin ErasePiece(CurX,CurY,CurrentShapeState); Inc(CurX); DrawPiece(CurX,CurY,CurrentShapeState); PieceLanded:=False end
end;
procedure RotatePiece;
var NS: Integer;
begin
  NS:=RotateTo[CurrentShapeState]; ErasePiece(CurX,CurY,CurrentShapeState);
  if Fits(CurX,CurY,NS) then CurrentShapeState:=NS;
  DrawPiece(CurX,CurY,CurrentShapeState)
end;
procedure DropPiece;
var Y0: Integer;
begin
  Y0:=CurY; while Fits(CurX,CurY+1,CurrentShapeState) do Inc(CurY);
  PieceLanded:=True; ErasePiece(CurX,Y0,CurrentShapeState); DrawPiece(CurX,CurY,CurrentShapeState)
end;
procedure LockPiece;
var I,GX,GY: Integer;
begin
  for I:=0 to 3 do
  begin
    GX:=CurX+Shapes[CurrentShapeState].dx[I]; GY:=CurY+Shapes[CurrentShapeState].dy[I];
    Glass[GX,GY]:=PieceColor[CurrentPieceKind]; Inc(RowCount[GY])
  end;
  Score:=Score+25+3*Level; DrawScore
end;

procedure LineSound;
begin Sound(300);Delay(20);Sound(200);Delay(20);Sound(400);Delay(20);NoSound end;

procedure RemoveLines;
var Full,X,Src,Y: Integer;
begin
  repeat
    Full:=0;
    for Y:=PlayH downto 1 do if (Full=0) and (RowCount[Y]=PlayW) then Full:=Y;
    if Full<>0 then
    begin
      for X:=1 to PlayW do DrawCell(X,Full,0); LineSound;
      for Src:=Full downto 1 do
      begin
        for X:=1 to PlayW do
          if Src>1 then Glass[X,Src]:=Glass[X,Src-1] else Glass[X,Src]:=0;
        if Src>1 then RowCount[Src]:=RowCount[Src-1] else RowCount[Src]:=0
      end;
      RowCount[0]:=0; Inc(Lines); RedrawGlass(1,Full); DrawScore;
      if (Lines>LevelLines[Level]) and (Level<9) then
      begin Inc(Level); Dec(FallDelayUnits,5); if FallDelayUnits<5 then FallDelayUnits:=5 end
    end
  until Full=0
end;

procedure FlushKeys;
var C: Char;
begin
  while KeyPressed do begin C:=ReadKey; if (C=#0) and KeyPressed then C:=ReadKey end
end;

procedure AskPlayerName(var Nm: PlayerName);
begin
  SetTextMode3; TextBackground(Black); TextColor(LightGray); ClrScr;
  GotoXYW(1,24); TextColor(Red); WriteW('Enter Your Name:');
  TextColor(LightGray); ShowCursor; ReadLn(Nm); HideCursor
end;

procedure QuitGame;
begin
  ShowCursor; SetTextMode3; RestoreScreen; WriteLn;
  TextColor(Black);TextBackground(Red);WriteLn('                 ');
  TextColor(LightGray);TextBackground(Black);WriteLn;
  TextColor(Black);TextBackground(Red);WriteLn('  Play TETRIS !  ');
  TextColor(LightGray);TextBackground(Black);WriteLn;
  TextColor(Black);TextBackground(Red);WriteLn('                 ');
  TextColor(Cyan);TextBackground(Black);WriteLn;TextColor(LightGray);Halt(0)
end;

procedure SpeedUp;
begin
  if Level<9 then begin Inc(Level);Dec(FallDelayUnits,5);if FallDelayUnits<5 then FallDelayUnits:=5;DrawScore end
end;
procedure ToggleNext;
begin
  ShowNext:=not ShowNext;
  if ShowNext then begin Dec(Score,5);if Score<0 then Score:=0 end;
  DrawNext
end;

procedure HandleKey;
var C: Char;
begin
  if not KeyPressed then Exit; C:=ReadKey;
  if C=#27 then QuitGame;
  if C=#0 then
  begin
    C:=ReadKey;
    case C of
      #71:MoveLeft; #72:RotatePiece; #73:MoveRight;
      #75:DropPiece; #77:SpeedUp; #79:ToggleNext
    end;
    Exit
  end;
  case C of
    '7':MoveLeft; '9':MoveRight; '8':RotatePiece;
    '4',' ':DropPiece; '1','o','O':ToggleNext; '6':SpeedUp
  end
end;

procedure ClearHiTable;
begin
  FillChar(HiTable,SizeOf(HiTable),0)
end;

function HiTableValid: Boolean;
var I: Integer; OK: Boolean;
begin
  OK:=SizeOf(HiRec)=24;
  I:=1;
  while (I<=HiCount) and OK do
  begin
    if Ord(HiTable[I].Name[0])>15 then OK:=False;
    if (HiTable[I].Level<0) or (HiTable[I].Level>9) then OK:=False;
    if (HiTable[I].Score<0) or (HiTable[I].Score>32767) then OK:=False;
    if I>1 then
      if HiTable[I].Score>HiTable[I-1].Score then OK:=False;
    Inc(I)
  end;
  HiTableValid:=OK
end;

procedure HiSave; forward;

procedure HiLoad;
var F: HiFile; I: Integer; Bad: Boolean;
begin
  ClearHiTable;
  Assign(F,'tetris.res'); {$I-} Reset(F); {$I+};
  if IOResult<>0 then Exit;
  Bad:=FileSize(F)<>HiCount;
  I:=1;
  while (I<=HiCount) and (not Eof(F)) do begin Read(F,HiTable[I]);Inc(I) end;
  Close(F);
  if Bad or (not HiTableValid) then
  begin ClearHiTable;HiSave end
end;
procedure HiSave;
var F: HiFile; I: Integer;
begin
  Assign(F,'tetris.res'); {$I-} Rewrite(F); {$I+};
  if IOResult<>0 then Exit;
  for I:=1 to HiCount do Write(F,HiTable[I]); Close(F)
end;

function HiInsert(AName: PlayerName; Sc: Integer): Integer;
var I: Integer;
begin
  if HiTable[HiCount].Score>=Sc then begin HiInsert:=0;Exit end;
  I:=HiCount;
  while (I>1) and (HiTable[I-1].Score<Sc) do begin HiTable[I]:=HiTable[I-1];Dec(I) end;
  HiTable[I].Name:=Copy(AName,1,15); HiTable[I].Level:=Level; HiTable[I].Score:=Sc; HiInsert:=I
end;
function HiColor(I: Integer): Integer;
begin
  if I=1 then HiColor:=7 else if I<=3 then HiColor:=4 else if I<=6 then HiColor:=2
  else if I<=10 then HiColor:=3 else if I<=15 then HiColor:=1 else HiColor:=5
end;
function HiX(I: Integer): Integer;
begin if I<=10 then HiX:=25 else if I<=15 then HiX:=5 else HiX:=45 end;
function HiY(I: Integer): Integer;
begin if I<=10 then HiY:=4+I else HiY:=17+(I-1) mod 5 end;
procedure HiShow(Marked: Integer);
var I,X,Y: Integer;
begin
  SetTextMode3;TextBackground(Black);ClrScr;HideCursor;TextColor(Brown);
  GotoXYW(26,1);Write('TETRIS Game 20 Highest Results');
  for I:=1 to HiCount do if HiTable[I].Score<>0 then
  begin
    X:=HiX(I);Y:=HiY(I);
    if I=Marked then begin TextColor(Brown);GotoXYW(X-2,Y);Write('* ') end;
    TextColor(HiColor(I));GotoXYW(X,Y);Write(I:2,'.',HiTable[I].Name);
    GotoXYW(X+18,Y);Write(HiTable[I].Level:2);Write(HiTable[I].Score:10:0)
  end
end;

procedure TitleScreen;
const
  BannerRows=14;
  Banner: array[1..BannerRows] of string[75] = (
    '....###########.###########.###########.##########....#######....#########',
    '....###########.###########.###########.###########.....###.....###########',
    '........###.....###.............###.....###.....###.....###.....###.....###',
    '........###.....###.............###.....###.....###.....###.....###',
    '........###.....###.............###.....###.....###.....###.....###',
    '........###.....###.............###.....###.....###.....###.....###',
    '........###.....########........###.....###########.....###......#######',
    '........###.....########........###.....##########......###.......#######',
    '........###.....###.............###.....########........###.............###',
    '........###.....###.............###.....#######.........###.............###',
    '........###.....###.............###.....###.####........###.....###.....###',
    '........###.....###.............###.....###..####.......###.....###.....###',
    '........###.....###########.....###.....###...####......###.....###########',
    '........###.....###########.....###.....###....####...#######....########');
var I,J,Bg: Integer; K: Char; Stop: Boolean;
begin
  TextBackground(Black);ClrScr;HideCursor;Bg:=1;Stop:=False;
  repeat
    I:=1;
    while (I<=BannerRows) and (not Stop) do
    begin
      TextBackground(Bg);
      for J:=1 to Length(Banner[I]) do if Banner[I][J]='#' then
      begin GotoXYW(J,2+I);WriteWSolid(' ') end;
      Delay(80);Stop:=KeyPressed;Inc(I)
    end;
    TextBackground(Black);TextColor(LightGray);
    GotoXYW(20,21);WriteW('(C) AcademySoft CCAS USSR Moscow, 1986');
    TextColor(Red);GotoXYW(20,23);WriteW('Game  by  A. Pajitnov  &  V. Gerasimov');
    TextColor(LightGray);GotoXY(1,25);
    if Bg<7 then Inc(Bg) else Bg:=1;
    Stop:=KeyPressed
  until Stop;
  K:=ReadKey;if K=#0 then K:=ReadKey;if K=#27 then QuitGame
end;

procedure AskLevel;
var C: Char;
begin
  SetTextMode3;TextBackground(Black);ClrScr;TextColor(LightGreen);
  GotoXYW(26,12);WriteW('Enter your level (0-9) [5] > ');ShowCursor;
  C:=ReadKey;if C=#0 then C:=ReadKey;if C=#27 then QuitGame;
  if C in ['0'..'9'] then begin StartLevel:=Ord(C)-Ord('0');Write(C) end
  else begin StartLevel:=5;Write('5') end;
  HideCursor;TextColor(LightGray);Delay(50);SetTextMode1
end;

procedure ResetGame;
var X,Y: Integer;
begin
  for X:=0 to RightWallX do for Y:=0 to BottomWallY do Glass[X,Y]:=0;
  for Y:=0 to BottomWallY do begin Glass[0,Y]:=Wall;Glass[RightWallX,Y]:=Wall end;
  for Y:=0 to PlayH do RowCount[Y]:=0;
  for X:=0 to RightWallX do begin Glass[X,0]:=Wall;Glass[X,BottomWallY]:=Wall end;
  for X:=1 to 7 do Stats[X]:=0;
  Score:=0;NextBonusScore:=1000;Lines:=0;TotalPieces:=0;ShowNext:=False;
  NextPieceKind:=TpRandom(7)+1;PreviousNext:=NextPieceKind;
  Level:=StartLevel;FallDelayUnits:=50-5*Level
end;

procedure PlayOneGame;
var Nm: PlayerName; I,Candidate: Integer;
begin
  SetTextMode1; ResetGame;DrawFrame;
  while NewPiece do
  begin
    PieceLanded:=False;
    while not PieceLanded do
    begin
      Delay(FallDelayUnits*5);HandleKey;
      if not PieceLanded then StepDown;
      Delay(FallDelayUnits*5);HandleKey
    end;
    LockPiece;RemoveLines;
    if Score>=NextBonusScore then
    begin
      Inc(NextBonusScore,1000);
      Sound(1000);Delay(8);Sound(500);Delay(8);Sound(1000);Delay(8);Sound(500);Delay(8);NoSound
    end
  end;
  for I:=1 to 25 do begin Sound(I*300+200);Delay(4) end;NoSound;
  TextBackground(Black);TextColor(LightGray);
  GotoXYW(15,10);WriteW('            ');GotoXYW(15,14);WriteW('            ');
  TextColor(Black);TextBackground(LightGray);
  GotoXYW(15,11);WriteW('            ');GotoXYW(15,12);WriteW(' GAME  OVER ');
  GotoXYW(15,13);WriteW('            ');TextBackground(Black);TextColor(LightGray);Delay(400);
  Candidate:=0;
  if HiTable[HiCount].Score<Score then
  begin AskPlayerName(Nm);Candidate:=HiInsert(Nm,Score);HiSave end;
  HiShow(Candidate)
end;

procedure AskAgain(var Again: Boolean);
var C: Char;
begin
  GotoXYW(1,25);FlushKeys;TextColor(Cyan);Write('Once more? (Y/N) > ');
  repeat C:=ReadKey;if C=#0 then C:=ReadKey;if C=#27 then QuitGame until UpCase(C) in ['Y','N'];
  Again:=UpCase(C)='Y';if Again then WriteLn('Yes') else begin WriteLn('No');QuitGame end
end;

var Again: Boolean;
begin
  DetectWideMode;DetectVideoSeg;SaveScreen;SeedOriginalRandom;
  TitleScreen;HiLoad;AskLevel;
  repeat PlayOneGame;AskAgain(Again) until not Again
end.
