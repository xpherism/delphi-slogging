unit SLogging.&File.Json;

interface

uses
  System.IOUtils,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Generics.Collections,
  SLogging,
  SLogging.Utils,
  SLogging.Utils.Json,
  SLogging.Utils.Queue,
  SLogging.&File;

{$B-} // Enable boolean short-circuit code generation by the compiler

type
  {* JSON File Logger *}

  TJsonFileLogger = class;
  TJsonFileLoggerProvider = class;

  TJsonFileLogger = class(TInterfacedObject, ILoggerImplementor)
  private
    FProvider: TJsonFileLoggerProvider;
  public
    constructor Create(Provider: TJsonFileLoggerProvider);

    function IsEnabled(const LogLevel: TLogLevel): boolean; inline;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>);
    procedure BeginScope(const State: TLogState);
    procedure EndScope;
  end;

  TJsonFileLoggerProvider = class(TFileLoggerProviderBase, ILoggerProvider)
  private
    FLogger: ILoggerImplementor;
    FScopes: TThreadList<TLogState>;
    FIncludeScopes: Boolean;
  protected
    function HandleDequeue(const [ref] Entry: TLogEntry): Boolean; override;
  public
    constructor Create; override;
    destructor Destroy; override;

    function CreateLogger(Category: string): ILoggerImplementor;
    procedure Close;

    property IncludeScopes: Boolean read FIncludeScopes write FIncludeScopes;
  end;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.JSON.Types,
  System.JSON.Utils,
  System.JSON.Serializers,
  System.JSON.Writers,
  System.Variants,
  System.VarUtils,
  System.DateUtils;

{ TJSONFileLoggerProvider }

constructor TJsonFileLoggerProvider.Create;
begin
  inherited;
  FScopes := TThreadList<TLogState>.Create;
  FLogger := TJsonFileLogger.Create(Self);
  FIncludeScopes := False;
end;

function TJsonFileLoggerProvider.CreateLogger(Category: string): ILoggerImplementor;
begin
  Result := FLogger;
end;

destructor TJsonFileLoggerProvider.Destroy;
begin
  FLogger := nil;

  var L := FScopes.LockList;
  try
    L.Clear;
  finally
    FScopes.UnlockList;
  end;

  FreeAndNil(FScopes);
  inherited;
end;

procedure TJsonFileLoggerProvider.Close;
begin
  Queue.Close;
end;

function TJsonFileLoggerProvider.HandleDequeue(const [ref] Entry: TLogEntry): Boolean;
begin
  var SR := TStringStream.Create;
  var JB := TJsonTextWriter.Create(TStreamWriter.Create(SR), True);
  try
    JB.WriteStartObject;

    JB.WritePropertyName('timestamp');
    JB.WriteValue(Entry.Timestamp.FormatISO8601);
    JB.WritePropertyName('logLevel');
    JB.WriteValue(JsonLogLevelNames[entry.Level]);

    JB.WritePropertyName('category');
    JB.WriteValue(Entry.Category);

    JB.WritePropertyName('eventId');
    JB.WriteEventId(Entry.EventId);

    if Entry.Exception.Message <> '' then
    begin
      JB.WritePropertyName('exception');
      JB.WriteStartObject;
      JB.WritePropertyName('message');
      JB.WriteValue(Entry.Exception.Message);

      JB.WritePropertyName('stackTrace');
      JB.WriteValue(Entry.Exception.StackTrace);
      JB.WriteEndObject;
    end;

    JB.WritePropertyName('message');
    JB.WriteValue(Entry.Message);

    JB.WritePropertyName('messageTemplate');
    JB.WriteValue(Entry.MessageTemplate);

    JB.WritePropertyName('properties');
    JB.WriteProperties(Entry.Properties);

    JB.WritePropertyName('scopes');
    JB.WriteStartArray;
    for var Scope in Entry.Scopes do
      JB.WriteScope(Scope);
    JB.WriteEndArray;

    JB.WriteEndObject;
    JB.Flush;

    Writer.WriteLine(SR.DataString, FileName, FileNameFormatter, Encoding);
  finally
    JB.Free;
    SR.Free;
  end;

  Result := True;
end;

{ TJsonFileLogger }

constructor TJsonFileLogger.Create(Provider: TJsonFileLoggerProvider);
begin
  FProvider := Provider;
end;

procedure TJsonFileLogger.Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>);
begin
  if not IsEnabled(LogLevel) then
    Exit;

  var Entry: TLogEntry;
  Entry.MessageTemplate := State.MessageTemplate;
  Entry.Message := Formatter(State);
  Entry.Category := State.Category;
  Entry.Timestamp := TLogTime.UTC;
  Entry.Properties := State.Properties;

  if TJsonFileLoggerProvider(FProvider).IncludeScopes then
  begin
    var L := TJsonFileLoggerProvider(FProvider).FScopes.LockList;
    SetLength(Entry.Scopes, L.Count);
    try
      for var I := 0 to L.Count-1 do
        Entry.Scopes[I] := L[I];
    finally
      TJsonFileLoggerProvider(FProvider).FScopes.UnlockList;
    end;
  end;

  Entry.EventId := EventId;
  Entry.Level := LogLevel;
  if Exc <> nil then
  begin
    Entry.Exception.Message := Exc.ToString;
    Entry.Exception.StackTrace := exc.StackTrace;
  end;

  FProvider.Queue.Enqueue(Entry);
end;

procedure TJsonFileLogger.BeginScope(const State: TLogState);
begin
  var L := TJsonFileLoggerProvider(FProvider).FScopes.LockList;
  try
    L.Add(State);
  finally
    TJsonFileLoggerProvider(FProvider).FScopes.UnlockList;
  end;
end;

procedure TJsonFileLogger.EndScope;
begin
  var L := TJsonFileLoggerProvider(FProvider).FScopes.LockList;
  try
    L.Delete(L.Count-1);
  finally
    TJsonFileLoggerProvider(FProvider).FScopes.UnlockList;
  end;
end;

function TJsonFileLogger.IsEnabled(const LogLevel: TLogLevel): boolean;
begin
  Result := LogLevel >= FProvider.MinLevel;
end;

end.
