unit SLogging.Utils;

interface

uses
  System.Classes,
  System.Variants,
  System.SysUtils;

{$B-} // Enable boolean short-circuit code generation by the compiler

type
  TStdOut = record
    Encoding: TEncoding;
    class operator Initialize(out Dest: TStdOut);
    procedure Write(const txt: string);
    procedure WriteLn(const txt: string); inline;
  end;

  TStdErr = record
    Encoding: TEncoding;
    class operator Initialize(out Dest: TStdErr);
    procedure Write(const txt: string);
    procedure WriteLn(const txt: string); inline;
  end;

  // Would be nice if generic support better constraint support
  // String span
  TStringSpan = record
  private type
    T = string;
    P = ^T;
    E = char;
  private
    FData: P;
    FStart: Integer;
    FLength: Integer;
    constructor Create(const [ref] Data: T; Start: Integer; Length: Integer);
    function GetValue(Index: Integer): E; inline;
  public
    class operator Implicit(const [ref] S: TStringSpan): T;

    property Length: Integer read FLength;
    property Values[Index: Integer]: E read GetValue; default;
  end;

  function StringSpan(const [ref] Data: TStringSpan.T; Start: Integer; Length: Integer): TStringSpan; inline;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.DateUtils;


{ TReadOnlySpan<T> }

function StringSpan(const [ref] Data: TStringSpan.T; Start: Integer; Length: Integer): TStringSpan;
begin
  Result := TStringSpan.Create(Data, Start, Length);
end;

constructor TStringSpan.Create(const [ref] Data: T; Start, Length: Integer);
begin
  FData := P(Data);
  FStart := Start;
  FLength := Length;
end;

function TStringSpan.GetValue(Index: Integer): E;
begin
  Result := String(FData)[FStart+Index-1];
end;

class operator TStringSpan.Implicit(const [ref] S: TStringSpan): T;
begin
  Result := Copy(T(S.FData), S.FStart, S.FLength);
end;

{ TStdOut }

class operator TStdOut.Initialize(out Dest: TStdOut);
begin
{$IFDEF MSWINDOWS}
  Dest.Encoding := TEncoding.GetEncoding(GetConsoleOutputCP);
{$ELSE}
  Dest.Encoding := TEncoding.Default;
{$ENDIF}
end;

procedure TStdOut.WriteLn(const txt: string);
begin
  Write(txt+sLineBreak);  // #13#10
end;

{$IFDEF MSWINDOWS}
procedure TStdOut.Write(const txt: String);
var
  h: THandle;
  s: TArray<byte>;
  DW: DWord;
begin
  h := GetStdHandle(STD_OUTPUT_HANDLE);
  s := Encoding.GetBytes(txt);
  WriteFile(h, s[0], Length(s), DW, nil);
  FlushFileBuffers(h);
end;
{$ELSE}
procedure TStdOut.Write(const txt: String);
begin
  Write(Output, txt);
  Flush(Output);
end;
{$ENDIF}

{ TStdErr }

class operator TStdErr.Initialize(out Dest: TStdErr);
begin
{$IFDEF MSWINDOWS}
  Dest.Encoding := TEncoding.GetEncoding(GetConsoleOutputCP);
{$ELSE}
  Dest.Encoding := TEncoding.Default;
{$ENDIF}
end;

procedure TStdErr.WriteLn(const txt: string);
begin
  Write(txt+sLineBreak); // #13#10
end;

{$IFDEF MSWINDOWS}
procedure TStdErr.Write(const txt: String);
var
  h: THandle;
  s: TArray<byte>;
  DW: DWord;
begin
  h := GetStdHandle(STD_ERROR_HANDLE);
  s := Encoding.GetBytes(txt);
  WriteFile(h, s[0], Length(s), DW, nil);
  FlushFileBuffers(h);
end;
{$ELSE}
procedure TStdErr.Write(const txt: String);
begin
  Write(ErrOutput, txt);
  Flush(ErrOutput);
end;
{$ENDIF}

end.
