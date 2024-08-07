unit SLogging.Utils.Json;

interface

uses
  System.Classes,
  System.JSON.Writers,
  System.Generics.Collections,
  System.Variants,
  SLogging,
  SLogging.Utils;

{$B-} // Enable boolean short-circuit code generation by the compiler

const
  JsonLogLevelNames : array [TLogLevel.Trace..TLogLevel.None] of string = ('trace','debug','information','warning','error','critical','none');

type
  TJsonWriterHelper = class helper for TJsonWriter
  public
    procedure WriteEventId(const [ref] EventId: TEventId);
    procedure WriteVariant(const [ref] Value: Variant);
    procedure WriteProperties(const [ref] Value: TArray<TPair<string, variant>>);
    procedure WriteScope(const [ref] Value: TState);
    procedure WriteScopes(const [ref] Value: TArray<TState>);
  end;

  TLogEntryHelper = record helper for TLogEntry
  public
    function ToClef: String;
  end;

  TStdOutHelper = record helper for TStdout
  public
    procedure WriteJson(const [ref] Values: TArray<TPair<string, Variant>>);
//    procedure WriteJsonLn<T>(const MessageTemplate: string; const Args: array of T; const ValueFormatter: TMessageTemplateValueFormatter<T>);
  end;


implementation

uses
  System.SysUtils;
  
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
    WriteVariant(item.Value);
  end;
  WriteEndObject;
end;

procedure TJsonWriterHelper.WriteScope(const [ref] Value: TState);
begin
  WriteStartObject;

  if Value.Template <> '' then
  begin
    WritePropertyName('MessageTemplate');
    WriteValue(Value.Template);
  end;

  if Value.Message <> '' then
  begin
    WritePropertyName('Message');
    WriteValue(Value.Message);
  end;

  WritePropertyName('Properties');
  WriteStartObject;
  for var item in Value.Values do
  begin
    WritePropertyName(item.Name);
    WriteVariant(item.Value);
  end;
  WriteEndObject;

  WriteEndObject;
end;

procedure TJsonWriterHelper.WriteScopes(const [ref] Value: TArray<TState>);
begin
  WriteStartArray;
  for var scope in Value do
    WriteScope(scope);
  WriteEndArray;
end;

procedure TJsonWriterHelper.WriteVariant(const [ref] Value: Variant);
begin
  case VarType(Value) of
    varEmpty: WriteUndefined;
    varNull: WriteNull;
    varSmallInt: WriteValue(TVarData(Value).VSmallInt);
    varInteger: WriteValue(TVarData(Value).VInteger);
    varSingle: WriteValue(TVarData(Value).VSingle);
    varDouble: WriteValue(TVarData(Value).VDouble);
    varCurrency: WriteValue(TVarData(Value).VCurrency);
    varDate: WriteValue(TVarData(Value).VDate);
    varOleStr: WriteValue(String(TVarData(Value).VOleStr));
    varBoolean: WriteValue(TVarData(Value).VBoolean);
    varShortInt: WriteValue(TVarData(Value).VShortInt);
    varByte: WriteValue(TVarData(Value).VByte);
    varWord: WriteValue(TVarData(Value).VWord);
    varUInt32: WriteValue(TVarData(Value).VUInt32);
    varInt64: WriteValue(TVarData(Value).VInt64);
    varUInt64: WriteValue(TVarData(Value).VUInt64);
    varString:  WriteValue(String(RawByteString(TVarData(Value).VString)));
    varUString: WriteValue(UnicodeString(TVarData(Value).VUString));
//      varObject: not supported, but we should probably support TArray<TPair<string, variant>> as "object"
    else
      WriteUndefined;
  end;
end;

{ TStdOutHelper }

procedure TStdOutHelper.WriteJson(const [ref] Values: TArray<TPair<string, Variant>>);
begin
  var SR := TStringStream.Create;
  var JB := TJsonTextWriter.Create(TStreamWriter.Create(SR), True);
  try
    JB.WriteProperties(Values);
    JB.Flush;

    WriteLn(SR.DataString);
  finally
    JB.Free;
    SR.Free;
  end;
end;

{ TLogEntryHelper }

function TLogEntryHelper.ToClef: String;
const
  ClefLogLevelNames : array [TLogLevel.Trace..TLogLevel.None] of string = ('Verbose','Debug','Information','Warning','Error','Fatal','Fatal');
begin
  var SW := TStringWriter.Create;
  var JB := TJsonTextWriter.Create(SW, False);
  try
    JB.WriteStartObject;

    JB.WritePropertyName('@t');
    JB.WriteValue(Timestamp.FormatISO8601);

    if LogLevel <> TLogLevel.Information then
    begin
      JB.WritePropertyName('@l');
      JB.WriteValue(ClefLogLevelNames[LogLevel]);
    end;

    if Self.Exception.Message <> '' then
    begin
      JB.WritePropertyName('@x');
      JB.WriteValue(Exception.Message+sLineBreak+Exception.StackTrace);
    end;

    JB.WritePropertyName('SourceContext');
    JB.WriteValue(Category);

    if EventId.Id > 0 then
    begin
      JB.WritePropertyName('@i');
      JB.WriteValue(EventId.Id);
    end;

    JB.WritePropertyName('@mt');
    JB.WriteValue(MessageTemplate);

    if Length(Renderings) > 0 then
    begin
      JB.WritePropertyName('@r');
      JB.WriteStartArray;
      for var val in Renderings do
        JB.WriteValue(val);
      JB.WriteEndArray;
    end;

    for var item in Properties do
    begin
      JB.WritePropertyName(item.Key);
      JB.WriteVariant(item.Value);
    end;

    JB.WriteEndObject;
    JB.Flush;

    Result := SW.ToString;
  finally
    JB.Free;
    SW.Free;
  end;
end;

end.
