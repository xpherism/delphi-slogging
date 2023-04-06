unit SLogging.Utils.Json;

interface

uses
  System.Classes,
  System.JSON.Writers,
  System.Generics.Collections,
  System.Variants,
  SLogging;

{$B-} // Enable boolean short-circuit code generation by the compiler

const
  JsonLogLevelNames : array [TLogLevel.Trace..TLogLevel.None] of string = ('trace','debug','information','warning','error','critical','none');

type
  TJsonWriterHelper = class helper for TJsonWriter
  public
    procedure WriteEventId(const [ref] EventId: TEventId);
    procedure WriteProperties(const [ref] Value: TArray<TPair<string, variant>>);
    procedure WriteScope(const [ref] Value: TLogState);
    procedure WriteScopes(const [ref] Value: TArray<TLogState>);
  end;

implementation

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

end.
