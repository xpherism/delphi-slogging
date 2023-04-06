unit SLogging.Utils;

interface

uses
  System.Classes,
  System.Variants,
  System.SysUtils,
  SLogging;

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

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.DateUtils;

{ TStdOut }

class operator TStdOut.Initialize(out Dest: TStdOut);
begin
  Dest.Encoding := TEncoding.Default;
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
end;
{$ENDIF}

{ TStdErr }

class operator TStdErr.Initialize(out Dest: TStdErr);
begin
  Dest.Encoding := TEncoding.Default;
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
end;
{$ENDIF}

end.
