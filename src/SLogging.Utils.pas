unit SLogging.Utils;

interface

uses
  System.Classes,
  System.JSON.Types,
  System.JSON.Utils,
  System.JSON.Serializers,
  System.JSON.Writers,
  System.Generics.Collections,
  System.Variants,
  System.SysUtils,
  SLogging;

const
  JsonLogLevelNames : array [TLogLevel.Trace..TLogLevel.None] of string = ('trace','debug','information','warning','error','critical','none');

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

  TJsonWriterHelper = class helper for TJsonWriter
  public
    procedure WriteEventId(const [ref] EventId: TEventId);
    procedure WriteProperties(const [ref] Value: TArray<TPair<string, variant>>);
    procedure WriteScope(const [ref] Value: TLogState);
    procedure WriteScopes(const [ref] Value: TArray<TLogState>);
  end;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.DateUtils;

{ TJsonWriterHelper }

procedure TJsonWriterHelper.WriteEventId(const [ref] EventId: TEventId);
begin
  WriteStartObject;
  WritePropertyName('id');
  WriteValue(EventId.Id);

  WritePropertyName('name');
  WriteValue(EventId.Name);
  WriteEndObject;
end;

procedure TJsonWriterHelper.WriteProperties(const [ref] Value: TArray<TPair<string, variant>>);
begin
  WriteStartObject;
  for var item in Value do
  begin
    WritePropertyName(item.Key);

    //varArray: TODO
    //VarIsArray()

    case VarType(item.Value) of
      varEmpty: WriteUndefined;
      varNull: WriteNull;
      varSmallInt: WriteValue(TVarData(item.Value).VSmallInt);
      varInteger: WriteValue(TVarData(item.Value).VInteger);
      varSingle: WriteValue(TVarData(item.Value).VSingle);
      varDouble: WriteValue(TVarData(item.Value).VDouble);
      varCurrency: WriteValue(TVarData(item.Value).VCurrency);
      varDate: WriteValue(TVarData(item.Value).VDate);
      varOleStr: WriteValue(String(TVarData(item.Value).VOleStr));
      varBoolean: WriteValue(TVarData(item.Value).VBoolean);
      varShortInt: WriteValue(TVarData(item.Value).VShortInt);
      varByte: WriteValue(TVarData(item.Value).VByte);
      varWord: WriteValue(TVarData(item.Value).VWord);
      varUInt32: WriteValue(TVarData(item.Value).VUInt32);
      varInt64: WriteValue(TVarData(item.Value).VInt64);
      varUInt64: WriteValue(TVarData(item.Value).VUInt64);
      varString:  WriteValue(String(RawByteString(TVarData(item.Value).VString)));
      varUString: WriteValue(UnicodeString(TVarData(item.Value).VUString));
//      varObject: not supported, but we should probably support TArray<TPair<string, variant>> as "object"
      else
        WriteUndefined;
    end;
  end;
  WriteEndObject;
end;

procedure TJsonWriterHelper.WriteScope(const [ref] Value: TLogState);
begin
  WriteStartObject;

  WritePropertyName('Message');
  WriteValue(Value.Message);

  WritePropertyName('Category');
  WriteValue(Value.Category);

  WritePropertyName('Properties');
  WriteProperties(Value.Properties);

  WriteEndObject;
end;

procedure TJsonWriterHelper.WriteScopes(const [ref] Value: TArray<TLogState>);
begin
  WriteStartArray;
  for var scope in Value do
    WriteScope(scope);
  WriteEndArray;
end;

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
