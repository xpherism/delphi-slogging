unit SLogging.Console.Clef;

// https://clef-json.org/

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
  TClefConsoleLogger = class;
  TClefConsoleLoggerProvider = class;

  {* Clef Console Logger *}

  TClefConsoleLogger = class(TConsoleLogger)
  public
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const State: TState; const Exc: Exception; const Formatter: TStateFormatter); override;
  end;

  TClefConsoleLoggerProvider = class(TConsoleLoggerProvider)
  public
    function CreateLogger(Category: string): ILoggerImplementor; override;
  end;

implementation

uses
  System.Rtti,
  System.JSON.Writers,
  System.DateUtils;

type
  TConsoleLoggerProviderAccess = class(TConsoleLoggerProvider);

{ TClefConsoleLogger }

procedure TClefConsoleLogger.Log(const LogLevel: TLogLevel; const EventId: TEventId; const State: TState; const Exc: Exception; const Formatter: TStateFormatter);
begin
  if not IsEnabled(LogLevel) then
    Exit;

  var Entry: TLogEntry;
  Entry.MessageTemplate := State.Template;
  Entry.Message := Formatter(State, Exc);
  Entry.Category := FCategory;
  if Provider.UseUTC then
    Entry.TimeStamp := TLogTime.UTC
  else
    Entry.TimeStamp := TLogTime.Now;
  Entry.EventId := EventId;
  Entry.LogLevel := LogLevel;

  var Props := TDictionary<string, variant>.Create(Length(state.Values));
  try
    // Get static and dynamic properties
    LoggerFactory.EvalProperties(
      procedure(Name: String; Value: Variant)
      begin
        Props.AddOrSetValue(Name, Value);
      end
    );

    // Get scope properties
    if Provider.IncludeScopes then
      TConsoleLoggerProviderAccess(Provider).FScopes.ForEach(
        procedure(const [ref] State: TState)
        begin
          for var item in State.Values do
          begin
            Props.AddOrSetValue(item.Name, item.Value);
          end;
        end
      );

    var r := 0;
    SetLength(Entry.Renderings, Length(state.Values));
    // Get message template properties (values and renderings)
    for var I := 0 to Length(state.Values)-1 do
    begin
      if state.Values[I].Fmt <> '' then
      begin
        Entry.Renderings[r] := state.Values[I].FmtValue;
        Inc(r);
      end;
      Props.AddOrSetValue(state.Values[I].Name, state.Values[I].Value);
    end;
    SetLength(Entry.Renderings, r);

    Entry.Properties := Props.ToArray;
  finally
    Props.Free;
  end;

  if Exc <> nil then
  begin
    Entry.Exception.Message := Exc.ToString;
    Entry.Exception.StackTrace := exc.StackTrace;
  end;

  TConsoleLoggerProviderAccess(Provider).FStdOut.WriteLn(Entry.ToClef);
end;

{ TClefConsoleLoggerProvider }

function TClefConsoleLoggerProvider.CreateLogger(Category: string): ILoggerImplementor;
begin
  var Logger := TClefConsoleLogger.Create;
  Logger.FCategory := Category;
  Logger.FProvider := Self;
  Result := ILoggerImplementor<TConsoleLoggerProvider>(Logger);
end;

end.
