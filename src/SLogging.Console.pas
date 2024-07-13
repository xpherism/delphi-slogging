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
  protected
    FProvider: TConsoleLoggerProvider;
    FCategory: String;
  public
    function IsEnabled(const LogLevel: TLogLevel): boolean; inline;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const State: TState; const Exc: Exception; const Formatter: TStateFormatter); virtual;
    procedure BeginScope(const State: TState);
    procedure EndScope;
  end;

  TConsoleLoggerProvider = class(TInterfacedObject, ILoggerProvider)
  private
    FMinLevel: TLogLevel;
    FUseUtc: Boolean;
    FIncludeScopes: Boolean;
  protected
    FScopes: IScopeHandler<TState>;
    FStdOut: TStdOut;
  public
    constructor Create;
    destructor Destroy; override;

    function CreateLogger(Category: string): ILoggerImplementor; virtual;
    procedure Close;

    property MinLevel: TLogLevel read FMinLevel write FMinLevel;
    property Encoding: TEncoding read FStdOut.Encoding write FStdOut.Encoding;
    property UseUTC: Boolean read FUseUTC write FUseUTC;
    property IncludeScopes: Boolean read FIncludeScopes write FIncludeScopes;
  end;

implementation

uses
  System.Variants,
  System.VarUtils,
  System.DateUtils;

const
  LogLevelNames : array [TLogLevel.Trace..TLogLevel.None] of string = ('trce','dbug','info','warn','fail','crit','none');

{ TConsoleLogger }

function TConsoleLogger.IsEnabled(const LogLevel: TLogLevel): boolean;
begin
  Result := LogLevel >= FProvider.MinLevel;
end;

procedure TConsoleLogger.BeginScope(const State: TState);
begin
  FProvider.FScopes.BeginScope(State);
end;

procedure TConsoleLogger.EndScope;
begin
  FProvider.FScopes.EndScope;
end;

procedure TConsoleLogger.Log(const LogLevel: TLogLevel; const EventId: TEventId; const State: TState; const Exc: Exception; const Formatter: TStateFormatter);
begin
  if not IsEnabled(LogLevel) then
    Exit;

  var SB := TStringBuilder.Create;
  try
    SB.Append(LogLevelNames[LogLevel]);
    SB.Append(' ');
    SB.Append(FCategory);
    SB.Append('[');
    SB.Append(EventId.Id);
    SB.Append(']');
    SB.Append(sLineBreak);
    SB.Append('     ');
    SB.Append(Formatter(State, Exc));

    if Exc <> nil then
    begin
      SB.Append(sLineBreak+sLineBreak);
      SB.Append(Exc.Message);
      SB.Append(sLineBreak);
      SB.Append(Exc.StackTrace);
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
  inherited;
end;

constructor TConsoleLoggerProvider.Create;
begin
  FMinLevel := TLogLevel.Information;
  FStdOut.Encoding := TEncoding.Default;
  FScopes := TScopeHandler<TState>.Create;
  FIncludeScopes := False;
  FUseUtc := True;
end;

function TConsoleLoggerProvider.CreateLogger(Category: string): ILoggerImplementor;
begin
  var Logger := TConsoleLogger.Create;
  Logger.FProvider := Self;
  Logger.FCategory := Category;
  Result := Logger;
end;

destructor TConsoleLoggerProvider.Destroy;
begin
  FScopes := nil;
  inherited;
end;

end.
