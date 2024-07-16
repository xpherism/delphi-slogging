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

const
  ClefLogLevelNames : array [TLogLevel.Trace..TLogLevel.None] of string = ('Verbose','Debug','Information','Warning','Error','Fatal','None');

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

  var SR := TStringStream.Create;
  var JB := TJsonTextWriter.Create(TStreamWriter.Create(SR), True);
  try
    JB.WriteStartObject;

    JB.WritePropertyName('@t');
    if FProvider.UseUTC then
      JB.WriteValue(TLogTime.UTC.FormatISO8601)
    else
      JB.WriteValue(TLogTime.Now.FormatISO8601);

    if LogLevel <> TLogLevel.Information then
    begin
      JB.WritePropertyName('@l');
      JB.WriteValue(ClefLogLevelNames[LogLevel]);
    end;

    if Exc <> nil then
    begin
      JB.WritePropertyName('@x');
      JB.WriteValue(Exc.Message+sLineBreak+Exc.StackTrace);
    end;

    JB.WritePropertyName('@mt');
    JB.WriteValue(State.Template);

    if Length(State.Values) > 0 then
    begin
      JB.WritePropertyName('@r');
      JB.WriteStartArray;
      for var val in State.Values do
        JB.WriteValue(val.FmtValue);
      JB.WriteEndArray;
    end;

    if EventId.Id > 0 then
    begin
      JB.WritePropertyName('@i');
      JB.WriteValue(EventId.Id);
    end;

    // Serilog convention to call Category for SourceContext
    JB.WritePropertyName('SourceContext');
    JB.WriteValue(FCategory);

    LoggerFactory.EvalProperties(
      procedure(Name: String; Value: Variant)
      begin
        JB.WritePropertyName(Name);
        JB.WriteVariant(Value);
      end
    );

    for var item in State.Values do
    begin
      JB.WritePropertyName(item.Name);
      JB.WriteVariant(item.Value);
    end;

    if FProvider.IncludeScopes then
      TConsoleLoggerProviderAccess(FProvider).FScopes.ForEach(
        procedure(const [ref] State: TState)
        begin
          for var item in State.Values do
          begin
            JB.WritePropertyName(item.Name);
            JB.WriteVariant(item.Value);
          end;
        end
      );

    JB.WriteEndObject;
    JB.Flush;

    TConsoleLoggerProviderAccess(FProvider).FStdOut.WriteLn(SR.DataString);
  finally
    JB.Free;
    SR.Free;
  end;
end;

{ TClefConsoleLoggerProvider }

function TClefConsoleLoggerProvider.CreateLogger(Category: string): ILoggerImplementor;
begin
  var Logger := TClefConsoleLogger.Create;
  Logger.FCategory := Category;
  Logger.FProvider := Self;
  Result := Logger;
end;

end.
