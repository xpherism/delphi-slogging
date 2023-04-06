unit SLogging.Console.Json;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  SLogging,
  SLogging.Utils,
  SLogging.Utils.Json,
  SLogging.Console;

{$B-} // Enable boolean short-circuit code generation by the compiler

type
  TJsonConsoleLogger = class;
  TJsonConsoleLoggerProvider = class;

  {* Json Console Logger *}

  TJsonConsoleLogger = class(TInterfacedObject, ILoggerImplementor)
  private
    FProvider: TJsonConsoleLoggerProvider;
  public
    constructor Create(Provider: TJsonConsoleLoggerProvider);

    function IsEnabled(const LogLevel: TLogLevel): boolean; inline;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>);
    procedure BeginScope(const State: TLogState);
    procedure EndScope;
  end;

  TJsonConsoleLoggerProvider = class(TInterfacedObject, ILoggerProvider)
  private
    FMinLevel: TLogLevel;
    FLogger: ILoggerImplementor;
    FStdOut: TStdOut;
    FScopes: TThreadList<TLogState>;
    FIncludeScopes: Boolean;
    FUseUTC: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function CreateLogger(Category: string): ILoggerImplementor;
    procedure Close;

    property MinLevel: TLogLevel read FMinLevel write FMinLevel;
    property Encoding: TEncoding read FStdOut.Encoding write FStdOut.Encoding;
    property UseUTC: Boolean read FUseUTC write FUseUTC;
    property IncludeScopes: Boolean read FIncludeScopes write FIncludeScopes;
  end;

implementation

uses
  System.JSON.Writers,
  System.DateUtils;

{ TJsonConsoleLogger }

constructor TJsonConsoleLogger.Create(Provider: TJsonConsoleLoggerProvider);
begin
  FProvider := Provider;
end;

procedure TJsonConsoleLogger.BeginScope(const State: TLogState);
begin
  var L := FProvider.FScopes.LockList;
  try
    L.Add(State);
  finally
    FProvider.FScopes.UnlockList;
  end;
end;

procedure TJsonConsoleLogger.EndScope;
begin
  var L := FProvider.FScopes.LockList;
  try
    L.Delete(L.Count-1);
  finally
    FProvider.FScopes.UnlockList;
  end;
end;

function TJsonConsoleLogger.IsEnabled(const LogLevel: TLogLevel): boolean;
begin
  Result := LogLevel >= FProvider.MinLevel;
end;

procedure TJsonConsoleLogger.Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>);
begin
  if not IsEnabled(LogLevel) then
    Exit;

  var SR := TStringStream.Create;
  var JB := TJsonTextWriter.Create(TStreamWriter.Create(SR), True);
  try
    JB.WriteStartObject;

    JB.WritePropertyName('timestamp');
    if FProvider.UseUTC then
      JB.WriteValue(TLogTime.UTC.FormatISO8601)
    else
      JB.WriteValue(TLogTime.UTC.FormatISO8601);
    JB.WritePropertyName('logLevel');
    JB.WriteValue(JsonLogLevelNames[LogLevel]);

    JB.WritePropertyName('category');
    JB.WriteValue(state.Category);

    JB.WritePropertyName('eventId');
    JB.WriteValue(EventId.Id);

    if Exc <> nil then
    begin
      JB.WritePropertyName('exception');

      JB.WriteStartObject;
      JB.WritePropertyName('message');
      JB.WriteValue(Exc.Message);

      JB.WritePropertyName('stackTrace');
      JB.WriteValue(Exc.StackTrace);
      JB.WriteEndObject;
    end;

    JB.WritePropertyName('message');
    JB.WriteValue(state.Message);

    JB.WritePropertyName('messageTemplate');
    JB.WriteValue(state.MessageTemplate);

    JB.WritePropertyName('properties');
    JB.WriteProperties(state.Properties);

    if FProvider.IncludeScopes then
    begin
      JB.WritePropertyName('scopes');
      JB.WriteStartArray;
      try
        for var Scope in FProvider.FScopes.LockList do
          JB.WriteScope(Scope);
      finally
        FProvider.FScopes.UnlockList;
      end;
      JB.WriteEndArray;
    end;

    JB.WriteEndObject;
    JB.Flush;

    FProvider.FStdOut.WriteLn(SR.DataString);
  finally
    JB.Free;
    SR.Free;
  end;
end;

{ TJsonConsoleLoggerProvider }

procedure TJsonConsoleLoggerProvider.Close;
begin

end;

constructor TJsonConsoleLoggerProvider.Create;
begin
  inherited Create;
  FMinLevel := TLogLevel.Information;
  FStdOut.Encoding := TEncoding.Default;
  FScopes := TThreadList<TLogState>.Create;
  FLogger := TJsonConsoleLogger.Create(Self);
  FUseUTC := True;
  FIncludeScopes := False;
end;

function TJsonConsoleLoggerProvider.CreateLogger(Category: string): ILoggerImplementor;
begin
  Result := FLogger;
end;

destructor TJsonConsoleLoggerProvider.Destroy;
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

end.
