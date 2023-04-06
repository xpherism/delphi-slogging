unit SLogging.Console;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  SLogging,
  SLogging.Utils;

{$B-} // Enable boolean short-circuit code generation by the compiler

type
  TConsoleLogger = class;
  TConsoleLoggerProvider = class;

  {* Console Logger *}

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
  public
    constructor Create;
    destructor Destroy; override;

    function CreateLogger(Category: string): ILoggerImplementor; virtual;
    procedure Close;

    property MinLevel: TLogLevel read FMinLevel write FMinLevel;
    property Encoding: TEncoding read FStdOut.Encoding write FStdOut.Encoding;
  end;

implementation

uses
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

procedure TConsoleLoggerProvider.Close;
begin

end;

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

end.
