unit SLogging.Console;

{$R-,T-,X+,H+,B-}

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  SLogging,
  SLogging.Utils;

type
  TConsoleLogger = class;
  TConsoleLoggerProvider = class;

  TJsonConsoleLogger = class;
  TJsonConsoleLoggerProvider = class;


  {* Text Console Logger *}

  TConsoleLogger = class(TInterfacedObject, ILoggerImplementor)
  private
    FProvider: TConsoleLoggerProvider;
  public
    constructor Create(Provider: TConsoleLoggerProvider);

    function IsEnabled(const LogLevel: TLogLevel): boolean; inline;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>); virtual;
    procedure BeginScope(const State: TLogState); virtual;
    procedure EndScope; virtual;
  end;

  TConsoleLoggerProvider = class(TInterfacedObject, ILoggerProvider)
  private
    FMinLevel: TLogLevel;
    FLogger: ILoggerImplementor;
    FStdOut: TStdOut;
    procedure SetMinLevel(const Value: TLogLevel);
  public
    constructor Create;
    destructor Destroy; override;

    function CreateLogger(Category: string): ILoggerImplementor; virtual;

    property MinLevel: TLogLevel read FMinLevel write SetMinLevel;
    property Encoding: TEncoding read FStdOut.Encoding write FStdOut.Encoding;
  end;


  {* Json Console Logger *}

  TJsonConsoleLogger = class(TConsoleLogger)
  public
    constructor Create(Provider: TJsonConsoleLoggerProvider); reintroduce;

    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>); override;
    procedure BeginScope(const State: TLogState); override;
    procedure EndScope; override;
  end;

  TJsonConsoleLoggerProvider = class(TConsoleLoggerProvider)
  private
    FScopes: TThreadList<TLogState>;
    FIncludeScopes: Boolean;
    FUseUTC: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function CreateLogger(Category: string): ILoggerImplementor; override;

    property UseUTC: Boolean read FUseUTC write FUseUTC;
    property IncludeScopes: Boolean read FIncludeScopes write FIncludeScopes;
  end;

implementation

uses
  System.JSON.Types,
  System.JSON.Utils,
  System.JSON.Serializers,
  System.JSON.Writers,
  System.Variants,
  System.VarUtils,
  System.DateUtils;

const
  LogLevelNames : array [TLogLevel.Trace..TLogLevel.None] of string = ('trce','dbug','info','warn','fail','crit','none');


{ TConsoleLogger }

constructor TConsoleLogger.Create(Provider: TConsoleLoggerProvider);
begin
  FProvider := Provider;
end;

function TConsoleLogger.IsEnabled(const LogLevel: TLogLevel): boolean;
begin
  Result := LogLevel >= FProvider.MinLevel;
end;

procedure TConsoleLogger.BeginScope(const State: TLogState);
begin
end;

procedure TConsoleLogger.EndScope;
begin
end;

procedure TConsoleLogger.Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>);
begin
  if not IsEnabled(LogLevel) then
    Exit;

  var SB := TStringBuilder.Create;
  try
    SB.Append(LogLevelNames[LogLevel]);
    SB.Append(' ');
    SB.Append(State.Category);
    SB.Append('[');
    SB.Append(EventId.Id);
    SB.Append(']');
    SB.Append(sLineBreak);
    SB.Append('     ');

    if Assigned(Formatter) then
      SB.Append(Formatter(State))
    else
      SB.Append('[null]');

    if Exc <> nil then
    begin
      SB.Append(sLineBreak+sLineBreak);
      SB.Append(exc.StackTrace);
      SB.Append(sLineBreak);
    end;

    FProvider.FStdOut.WriteLn(SB.ToString);
  finally
    SB.Free;
  end;
end;

{ TConsoleLoggingProvider }

constructor TConsoleLoggerProvider.Create;
begin
  FLogger := TConsoleLogger.Create(Self);
  FMinLevel := TLogLevel.Information;
  FStdOut.Encoding := TEncoding.Default;
end;

function TConsoleLoggerProvider.CreateLogger(Category: string): ILoggerImplementor;
begin
  Result := FLogger;
end;

destructor TConsoleLoggerProvider.Destroy;
begin
  FLogger := nil;
  inherited;
end;

procedure TConsoleLoggerProvider.SetMinLevel(const Value: TLogLevel);
begin
  FMinLevel := Value;
end;

{ TJsonConsoleLogger }

constructor TJsonConsoleLogger.Create(Provider: TJsonConsoleLoggerProvider);
begin
  FProvider := Provider;
end;

procedure TJsonConsoleLogger.BeginScope(const State: TLogState);
begin
  var L := TJsonConsoleLoggerProvider(FProvider).FScopes.LockList;
  try
    L.Add(State);
  finally
    TJsonConsoleLoggerProvider(FProvider).FScopes.UnlockList;
  end;
end;

procedure TJsonConsoleLogger.EndScope;
begin
  var L := TJsonConsoleLoggerProvider(FProvider).FScopes.LockList;
  try
    L.Delete(L.Count-1);
  finally
    TJsonConsoleLoggerProvider(FProvider).FScopes.UnlockList;
  end;
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
    if TJsonConsoleLoggerProvider(FProvider).UseUTC then
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

    if TJsonConsoleLoggerProvider(FProvider).IncludeScopes then
    begin
      JB.WritePropertyName('scopes');
      JB.WriteStartArray;
      try
        for var Scope in TJsonConsoleLoggerProvider(FProvider).FScopes.LockList do
          JB.WriteScope(Scope);
      finally
        TJsonConsoleLoggerProvider(FProvider).FScopes.UnlockList;
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

constructor TJsonConsoleLoggerProvider.Create;
begin
  FScopes := TThreadList<TLogState>.Create;
  FLogger := TJsonConsoleLogger.Create(Self);
  FMinLevel := TLogLevel.Information;
  FStdOut.Encoding := TEncoding.UTF8;
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
