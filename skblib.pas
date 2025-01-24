unit skblib;

interface

uses
  System.Classes, System.SysUtils, System.UITypes, System.StrUtils,
  System.Generics.Collections, System.Math, System.Types,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Imaging.pngimage, Vcl.Controls, Vcl.Graphics;

type
  TForkProc = reference to procedure(Result: Boolean);

  TFork = class
  public
    class procedure Fork(exp: Boolean; onTrue: TForkProc;
      onFalse: TForkProc = nil);
  end;

  TDirection = (dUp, dDown, dLeft, dRight);

  TPosition = record
    Col: integer;
    Row: integer;
  end;

  TStringListHelper = class Helper for TStringList
    function Width: integer;
    function Height: integer;
    procedure Fill(aWidth, aHeight: integer; aChar: Char);
    procedure MoveToStringList(aPos: TPosition; aTarget: TStringList);
    function IsGoal(aPos: TPosition): Boolean;
    function isPlayer(aPos: TPosition): Boolean;
    function AtPos(aPos: TPosition): Char;
    procedure ReplaceAtPos(aPos: TPosition; aNewChar: Char);
    function MoveChar(aPos: TPosition; aDirection: TDirection): TPosition;
    function Neighbor(aPos: TPosition; aDirection: TDirection;
      var NeighberPos: TPosition): Char;
  end;

  TGoals = TStringList;
  TMap = TStringList;

  TGame = class;

  TLevel = class
  private
    FMap: TMap;
    FGoals: TGoals;
    Player: TPosition;
    [weak]
    game: TGame;
  public
    constructor create(aGame: TGame);
    destructor Destroy; override;
    procedure LoadLevel(aNo: integer);
    procedure LoadAssets;
    function MovePlayer(aDirection: TDirection): TPosition;
    property Map: TMap read FMap write FMap;
    property Goals: TGoals read FGoals write FGoals;
  end;

  TAsset = record
    symbol: Char;
    Rs_Name: String;
    Image: TPngImage;
  end;

  TSymbolsAnd = TObjectDictionary<Char, String>;
  TGameState = (gsStart, gsFinish, gsRun);

  TOnCompletePro = procedure() of Object;

  TGame = class
  private
    FLevel: TLevel;
    FOutputImage: TImage;
    Assets: TArray<TAsset>;
  private
    FState: TGameState;
    FOnComplete: TOnCompletePro;
    function findAsset(aSymbol: Char): TAsset;
    procedure SetState(const Value: TGameState);
  public
    constructor create(aOutputImage: TImage; aOnComplete: TOnCompletePro = nil);
    destructor Destroy; override;
    procedure Draw;
    function CheckCompleted: Boolean;
    procedure Step(aDirection: TDirection);
    property Level: TLevel read FLevel write FLevel;
    property OutputImage: TImage read FOutputImage;
    property State: TGameState read FState write SetState;
    property OnComplete: TOnCompletePro read FOnComplete write FOnComplete;
  end;

const
  BLOCK_SIZE = 64;
  Player = '@';
  PlayerU = 'U';
  GOAL = 'X';
  WALL = '#';
  BOX = 'O';
  EMPTY = '.';
  DEAD_END_POS: TPosition = (Col: - 1; Row: - 1);

  SYMBOLS: array [0 .. 4] of Char = (Player, EMPTY, WALL, GOAL, BOX);
  RS_NAMES: array [0 .. 4] of string = ('player_front', 'empty', 'wall',
    'goal', 'box');

function Position(aCol, aRow: integer): TPosition; inline;

{$ZEROBASEDSTRINGS ON}

implementation

{ TLevel }

function Position(aCol, aRow: integer): TPosition; inline;
begin
  Result.Col := aCol;
  Result.Row := aRow;
end;

constructor TLevel.create(aGame: TGame);
begin
  game := aGame;
end;

destructor TLevel.Destroy;
begin
  Map.Free;
end;

procedure TLevel.LoadAssets;
var
  png: TPngImage;
  asset: TAsset;
begin
  for var i: integer := low(SYMBOLS) to high(SYMBOLS) do
  begin
    png := TPngImage.create;
    png.LoadFromResourceName(HInstance, RS_NAMES[i]);
    asset.symbol := SYMBOLS[i];
    asset.Rs_Name := RS_NAMES[i];
    asset.Image := png;
    game.Assets := game.Assets + [asset];
  end;
end;

procedure TLevel.LoadLevel(aNo: integer);
var
  rs: TResourceStream;
begin
  Map.Free;
  Goals.Free;
  game.OutputImage.Picture.Assign(nil);
  rs := TResourceStream.create(HInstance, 'lvl' + aNo.ToString, RT_RCDATA);

  Map := TMap.create(TDuplicates.dupAccept, false, false);
  Map.LoadFromStream(rs);

  Goals := TGoals.create(TDuplicates.dupAccept, false, false);;
  Goals.Fill(Map.Width, Map.Height, EMPTY);

  for var Col: integer := 0 to Map.Width - 1 do
    for var Row: integer := 0 to Map.Height - 1 do
    begin
      TFork.Fork(Map.isPlayer(Position(Col, Row)),
        procedure(Result: Boolean)
        begin
          Player := Position(Col, Row);
        end);

      TFork.Fork(Map.IsGoal(Position(Col, Row)),
        procedure(Result: Boolean)
        begin
          Map.MoveToStringList(Position(Col, Row), Goals);
        end);
    end;

  LoadAssets;
  game.Draw;
  game.State := gsRun;
end;

function TLevel.MovePlayer(aDirection: TDirection): TPosition;
var
  p, nPos: TPosition;
begin
  TFork.Fork(Map.Neighbor(Player, aDirection, nPos) = EMPTY,
    procedure(Result: Boolean)
    begin
      Player := Map.MoveChar(Player, aDirection);
    end);

  TFork.Fork(Map.Neighbor(Player, aDirection, nPos) = BOX,
    procedure(Result: Boolean)
    begin
      TFork.Fork(Map.Neighbor(nPos, aDirection, p) = EMPTY,
        procedure(Result: Boolean)
        begin
          Map.MoveChar(nPos, aDirection);
          Player := Map.MoveChar(Player, aDirection);
        end);
    end);

  Result := Player;
end;

{ TStringListHelper }

function TStringListHelper.AtPos(aPos: TPosition): Char;
begin
  Result := Self[aPos.Row].Chars[aPos.Col];
end;

procedure TStringListHelper.Fill(aWidth, aHeight: integer; aChar: Char);
var
  line: String;
begin
  Self.Clear;
  line := StringOfChar(aChar, aWidth);
  for var i: integer := 0 to aHeight do
    Self.Add(line);
end;

function TStringListHelper.Height: integer;
begin
  Result := Self.Count;
end;

function TStringListHelper.IsGoal(aPos: TPosition): Boolean;
begin
  Result := Self[aPos.Row].Chars[aPos.Col] = GOAL;
end;

function TStringListHelper.isPlayer(aPos: TPosition): Boolean;
begin
  Result := Self.AtPos(aPos) = Player;
end;

function TStringListHelper.MoveChar(aPos: TPosition; aDirection: TDirection)
  : TPosition;
var
  chr: Char;
  newPos: TPosition;
begin
  chr := Self.AtPos(aPos);
  TFork.Fork(aDirection = dUp,
    procedure(Result: Boolean)
    begin
      newPos := Position(aPos.Col, aPos.Row - 1);
    end);

  TFork.Fork(aDirection = dDown,
    procedure(Result: Boolean)
    begin
      newPos := Position(aPos.Col, aPos.Row + 1);
    end);

  TFork.Fork(aDirection = dLeft,
    procedure(Result: Boolean)
    begin
      newPos := Position(aPos.Col - 1, aPos.Row);
    end);

  TFork.Fork(aDirection = dRight,
    procedure(Result: Boolean)
    begin
      newPos := Position(aPos.Col + 1, aPos.Row);
    end);

  Self.ReplaceAtPos(newPos, chr);
  Self.ReplaceAtPos(Position(aPos.Col, aPos.Row), EMPTY);
  Result := newPos;
end;

procedure TStringListHelper.MoveToStringList(aPos: TPosition;
aTarget: TStringList);
var
  chr: Char;
begin
  chr := Self.AtPos(Position(aPos.Col, aPos.Row));
  aTarget.ReplaceAtPos(aPos, chr);
  Self.ReplaceAtPos(aPos, EMPTY);
end;

function TStringListHelper.Neighbor(aPos: TPosition; aDirection: TDirection;
var NeighberPos: TPosition): Char;
var
  pos: TPosition;
begin
  TFork.Fork(aDirection = dUp,
    procedure(Result: Boolean)
    begin
      pos := Position(aPos.Col, aPos.Row - 1);
    end);

  TFork.Fork(aDirection = dDown,
    procedure(Result: Boolean)
    begin
      pos := Position(aPos.Col, aPos.Row + 1);
    end);

  TFork.Fork(aDirection = dLeft,
    procedure(Result: Boolean)
    begin
      pos := Position(aPos.Col - 1, aPos.Row);
    end);

  TFork.Fork(aDirection = dRight,
    procedure(Result: Boolean)
    begin
      pos := Position(aPos.Col + 1, aPos.Row);
    end);

  NeighberPos := pos;
  Result := AtPos(pos);
end;

procedure TStringListHelper.ReplaceAtPos(aPos: TPosition; aNewChar: Char);
var
  line: String;
begin
  line := Self[aPos.Row];
  line[aPos.Col] := aNewChar;
  Self[aPos.Row] := line;
end;

function TStringListHelper.Width: integer;
begin
  Result := Self[0].Length;
end;

{ TGame }

constructor TGame.create(aOutputImage: TImage; aOnComplete: TOnCompletePro);
begin
  FLevel := TLevel.create(Self);
  FOutputImage := aOutputImage;
  State := gsStart;
  OnComplete := aOnComplete
end;

destructor TGame.Destroy;
begin
  Level.Free;
end;

procedure TGame.Draw;
var
  asset, EmptyAsset: TAsset;
begin
  EmptyAsset := findAsset(EMPTY);

  for var Col: integer := 0 to Level.Map.Width - 1 do
    for var Row: integer := 0 to Level.Map.Height - 1 do
    begin
      OutputImage.Canvas.Draw(Col * BLOCK_SIZE, Row * BLOCK_SIZE,
        EmptyAsset.Image);

      asset := findAsset(Level.Goals.AtPos(Position(Col, Row)));
      OutputImage.Canvas.Draw(Col * BLOCK_SIZE, Row * BLOCK_SIZE, asset.Image);

      asset := findAsset(Level.Map.AtPos(Position(Col, Row)));

      TFork.Fork(asset.symbol <> EMPTY,
        procedure(Result: Boolean)
        begin
          OutputImage.Canvas.Draw(Col * BLOCK_SIZE, Row * BLOCK_SIZE,
            asset.Image);
        end);

    end;
end;

function TGame.findAsset(aSymbol: Char): TAsset;
var
  asset: TAsset;
  a: TAsset;
begin

  for asset in Assets do

    TFork.Fork(aSymbol = asset.symbol,
      procedure(expResult: Boolean)
      begin
        a := asset;
      end);
  Result := a;
end;

function TGame.CheckCompleted: Boolean;
var
  res: Boolean;
begin
  res := false;
  for var Col: integer := 0 to Level.Map.Width - 1 do
    for var Row: integer := 0 to Level.Map.Height - 1 do
    begin
      TFork.Fork((Level.Goals.AtPos(Position(Col, Row)) = GOAL) and
        (not(Level.Map.AtPos(Position(Col, Row)) = BOX)),
        procedure(R: Boolean)
        begin
          State := gsRun;
          res := true;
        end,
        procedure(R: Boolean)
        begin

        end);
    end;

  Result := res <> true;
  TFork.Fork(Result,
    procedure(finish: Boolean)
    begin
      State := gsFinish;
    end);

end;

procedure TGame.SetState(const Value: TGameState);
begin
  TFork.Fork(FState <> Value,
    procedure(Result: Boolean)
    begin
      FState := Value;
      TFork.Fork((assigned(OnComplete)) and (FState = gsFinish),
        procedure(ontherResult: Boolean)
        begin
          OnComplete();
        end)

    end);

end;

procedure TGame.Step(aDirection: TDirection);
var
  p: TPosition;
begin
  p.Col := 10;
  Level.MovePlayer(aDirection);
  Draw;
  CheckCompleted;
end;

{ TFork }

class procedure TFork.Fork(exp: Boolean; onTrue, onFalse: TForkProc);
var
  bool: Boolean;
  i: integer;
  n: double;
begin
  try
    bool := exp;
    i := exp.ToInteger;
    try
      n := 1 / i;
      onTrue(bool);
    except
      On E: EZeroDivide do
        onFalse(bool);
    end;
  except
  end;
end;

end.
