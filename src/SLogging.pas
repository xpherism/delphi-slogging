unit SLogging;

{*
  Structured Logging framework for Delphi inspired by .NET Logging

  Important notes!

  TLogState if passed by reference but is allocated on the stack.
  Any ILoggerImplementor that involves async operations (ie. queuing) must
  make a copy (ie. assign to stack local variable or allocate on heap).
*}

{$R-,T-,X+,H+,B-}

interface

uses
  System.Variants,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  {$SCOPEDENUMS ON}
  TLogLevel = (Trace=0, Debug=1, Information=2, Warning=3, Error=4, Critical=5, None=6);
  {$SCOPEDENUMS OFF}

  TLogTime = record
    Year: Word;
    Month: Word;
    Day: Word;
    Hour: Word;
    Minute: Word;
    Second: Word;
    NanoSecond: Int64;
    IsUTC: Boolean;
    class function Now: TLogTime; static;
    class function UTC: TLogTime; static;
    function FormatISO8601: string; inline;
  end;

  TEventId = record
  private
    FId: Integer;
    FName: string;
  public
    constructor Create(const Id: Integer; const Name: string); overload;
    constructor Create(const Id: Integer); overload;

    class operator Implicit(Id: Integer): TEventId;

    property Id: Integer read FId;
    property Name: string read FName;
  end;

  // Delphi interfaces does not support generic function.
  // Use inheritance to override instead
  // Default log state that supports message templates
  TLogState = record
  private
  var
    FMessageTemplate: string;
    FMessage: string;
    FCategory: string;
    FProperties: TArray<TPair<string, variant>>;
  public
//    class operator Finalize(var Dest: TLogState);
//    class operator Initialize(out Dest: TLogState);

    property MessageTemplate: string read FMessageTemplate;
    property Message: string read FMessage;
    property Category: string read FCategory;
    property Properties: TArray<TPair<string, variant>> read FProperties;
  end;

  TValueFormatter = reference to function(const Fmt: string; const Value: variant): string;

  // Exception is not provided as an argument to Formatters (https://github.com/aspnet/Logging/issues/442)
  TStateFormatter<T> = reference to function(const [ref] State: T): string;

  // Delphi does not support helper methods for interfaces, so we need a specific interface for
  // implementation specific and proxy interface for general usage
  ILoggerImplementor = interface
    function IsEnabled(const LogLevel: TLogLevel): boolean;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>);
    procedure BeginScope(const State: TLogState);
    procedure EndScope;
  end;

  // Providers should always have zero argument constructor
  ILoggerProvider = interface
    function CreateLogger(Category: string): ILoggerImplementor;
  end;

  {*
    Proxy implementation with support for message templates

    Variant keeps "distinct" type info during assignment (ie. TDateTime is varDate and not float), which TValue or TVarRec does not do
    This is the proxy interface that everyone uses, T is the type used for category name
  *}

  ILogger = interface
    function IsEnabled(const LogLevel: TLogLevel): boolean;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant);
    procedure BeginScope(const MessageTemplate: string; const Args: array of variant);
    procedure EndScope;

    // helper methods
    procedure LogTrace(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogTrace(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogTrace(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogTrace(const MessageTemplate: string; const Args: array of variant); overload;

    procedure LogDebug(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogDebug(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogDebug(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogDebug(const MessageTemplate: string; const Args: array of variant); overload;

    procedure LogInformation(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogInformation(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogInformation(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogInformation(const MessageTemplate: string; const Args: array of variant); overload;

    procedure LogWarning(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogWarning(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogWarning(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogWarning(const MessageTemplate: string; const Args: array of variant); overload;

    procedure LogError(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogError(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogError(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogError(const MessageTemplate: string; const Args: array of variant); overload;

    procedure LogCritical(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogCritical(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogCritical(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogCritical(const MessageTemplate: string; const Args: array of variant); overload;
  end;

  TLogger = class(TInterfacedObject, ILogger)
  private
    FCategory: String;
    constructor Create(const Category: string);
  public
    function IsEnabled(const LogLevel: TLogLevel): boolean;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant);
    procedure BeginScope(const MessageTemplate: string; const Args: array of variant);
    procedure EndScope;

    procedure LogTrace(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogTrace(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogTrace(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogTrace(const MessageTemplate: string; const Args: array of variant); overload;

    procedure LogDebug(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogDebug(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogDebug(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogDebug(const MessageTemplate: string; const Args: array of variant); overload;

    procedure LogInformation(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogInformation(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogInformation(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogInformation(const MessageTemplate: string; const Args: array of variant); overload;

    procedure LogWarning(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogWarning(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogWarning(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogWarning(const MessageTemplate: string; const Args: array of variant); overload;

    procedure LogError(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogError(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogError(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogError(const MessageTemplate: string; const Args: array of variant); overload;

    procedure LogCritical(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogCritical(const EventId: TEventId; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogCritical(const Exc: Exception; const MessageTemplate: string; const Args: array of variant); overload;
    procedure LogCritical(const MessageTemplate: string; const Args: array of variant); overload;
  end;

  ILogger<T> = interface(ILogger)
  end;

  TLogger<T> = class(TLogger, ILogger<T>)
  private
    constructor Create; reintroduce;
  end;


  TLoggerFactory = class
  private
    FProviders: TDictionary<string, ILoggerProvider>;
    FStaticProps: TDictionary<string, variant>;
    FDynamicProps: TList<TProc<TDictionary<string, variant>>>;
    FValueFormatter: TValueFormatter;
    FStateFormatter: TStateFormatter<TLogState>;
  public
    constructor Create;
    destructor Destroy; override;

    function CreateLogger<T>: ILogger<T>; overload;
    function CreateLogger(const Category: string): ILogger; overload;

    function AddProvider<T: ILoggerProvider>(Provider: T; ConfigureProc: TProc<T> = nil): TLoggerFactory; overload;
    function AddProvider<T: ILoggerProvider>(ConfigureProc: TProc<T> = nil): TLoggerFactory; overload;

    function WithProperty(const Name: string; const Value: variant): TLoggerFactory; overload; // static properties ie. process id, correlation id etc.
    function WithProperty(const Proc: TProc<TDictionary<string, variant>>): TLoggerFactory; overload; // dynamic properties called on every log event, thread id,

    property ValueFormatter: TValueFormatter read FValueFormatter write FValueFormatter;
    property StateFormatter: TStateFormatter<TLogState> read FStateFormatter write FStateFormatter;
  end;


  function DefaultValueFormatter(const Fmt: string; const Value: variant): string; inline;
  function DefaultStateFormatter(const [ref] State: TLogState): string; inline;

  function FormatMessageTemplate(const MessageTemplate: string; const Args: array of variant; const Properties: TDictionary<string, variant>): string;

var
  LoggerFactory: TLoggerFactory = nil;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.Rtti,
  System.DateUtils,
  System.TypInfo,
  System.StrUtils;


{ TLogTime }

function TLogTime.FormatISO8601: string;
begin
  if IsUTC then
    Result := Format('%.4d-%.2d-%.2dT%.2d:%.2d:%.2d.%.9dZ', [year, month, day, hour, minute, second, nanosecond])
  else
    Result := Format('%.4d-%.2d-%.2dT%.2d:%.2d:%.2d.%.9d', [year, month, day, hour, minute, second, nanosecond])
end;

class function TLogTime.Now: TLogTime;
begin
  Result.IsUTC := False;
{$IFDEF MSWINDOWS}
  var ft: TFileTime;
  var unixtime_ns: UInt64;
  GetSystemTimeAsFileTime(ft);
  unixtime_ns := UInt64(ft.dwHighDateTime) shl 32 + ft.dwLowDateTime; // 100-nanosecond intervals since January 1, 1601
  unixtime_ns := unixtime_ns - UInt64(116444736000000000); 	          // change starting time to the Epoch (00:00:00 UTC, January 1, 1970)
  unixtime_ns := unixtime_ns * 100;                                   // convert into nanoseconds
  var utc := TTimeZone.Local.ToLocalTime(UnixToDateTime(unixtime_ns div 1000000000, True));
  var msec: word;
  DecodeDate(utc, Result.Year, Result.Month, Result.Day);
  DecodeTime(utc, Result.Hour, Result.Minute, Result.Second, MSec);
  Result.NanoSecond := unixtime_ns mod 1000000000;
{$ELSE}
  var utc := System.SysUtils.Now;
  var msec: word;
  DecodeDate(utc, Result.Year, Result.Month, Result.Day);
  DecodeTime(utc, Result.Hour, Result.Minute, Result.Second, MSec);
  Result.NanoSecond := msec * 1000000;
{$ENDIF}
end;

class function TLogTime.UTC: TLogTime;
begin
  Result.IsUTC := True;
{$IFDEF MSWINDOWS}
  var ft: TFileTime;
  var unixtime_ns: UInt64;
  GetSystemTimeAsFileTime(ft);
  unixtime_ns := UInt64(ft.dwHighDateTime) shl 32 + ft.dwLowDateTime; // 100-nanosecond intervals since January 1, 1601
  unixtime_ns := unixtime_ns - UInt64(116444736000000000); 	          // change starting time to the Epoch (00:00:00 UTC, January 1, 1970)
  unixtime_ns := unixtime_ns * 100;                                   // convert into nanoseconds
  var utc := UnixToDateTime(unixtime_ns div 1000000000, True);
  var msec: word;
  DecodeDate(utc, Result.Year, Result.Month, Result.Day);
  DecodeTime(utc, Result.Hour, Result.Minute, Result.Second, MSec);
  Result.NanoSecond := unixtime_ns mod 1000000000;
{$ELSE}
  var utc := TTimeZone.Local.ToUniversalTime(System.SysUtils.Now);
  var msec: word;
  DecodeDate(utc, Result.Year, Result.Month, Result.Day);
  DecodeTime(utc, Result.Hour, Result.Minute, Result.Second, MSec);
  Result.NanoSecond := msec * 1000000;
{$ENDIF}
end;

// This should never throw an exception
// Template message format: {Name[:format]} => format is passed to formatter function
function FormatMessageTemplate(const MessageTemplate: string;
  const Args: array of variant;
  const Properties: TDictionary<string, variant>): string;
type
  TState = (Scan, TextDone, ArgScan, ArgFail, ArgDone, Done);

  function FindIndexOf(str: string; needle: char; fromIndex, toIndex: integer): integer; inline;
  begin
    Result := -1;
    for var I := fromIndex to toIndex do
      if str[I] = needle then
        Exit(I);
  end;

begin
  var L := MessageTemplate.Length;

  if L = 0 then Exit('');

  var state := TState.Scan;

  var T1 := 1;
  var T2 := 1;
  var AN := 0;

  var B := TStringBuilder.Create(L);
  try

    while State <> TState.Done do
    begin
      case state of

        TState.Scan: begin
          // {{ (escaped {)
          if (MessageTemplate[T2] = '{') and (T2+1 <= L) and (MessageTemplate[T2+1] = MessageTemplate[T2]) then
          begin
            B.Append(MessageTemplate, T1-1, T2-T1+1);
            T1 := T2+2;
            T2 := T1;
          end
          // }} (escaped })
          else if (MessageTemplate[T2] = '}') and (T2+1 <= L) and (MessageTemplate[T2+1] = MessageTemplate[T2]) then
          begin
            B.Append(MessageTemplate, T1-1, T2-T1+1);
            T1 := T2+2;
            T2 := T1;
          end
          // { start argument parsing
          else if (MessageTemplate[T2] = '{')  then
          begin
            B.Append(MessageTemplate, T1-1, T2-T1);
            T1 := T2+1;
            T2 := T1;
            State := TState.ArgScan;
          end
          // no more characters we are done
          else if (T2 > L) then
          begin
            B.Append(MessageTemplate, T1-1, T2-T1);
            break;
          end
          else
            Inc(T2);
        end;

        TState.ArgScan: begin
          if T2 > L then
            state := TState.Scan
          else if MessageTemplate[T2] = '}' then
            state := TState.ArgDone
          else if MessageTemplate[T2] = '{' then
            state := TState.Scan
          else
            Inc(T2);
        end;

        TState.ArgDone: begin
          var Name: string;
          var Value: variant;
          var ValueFmt: string;
          var FormattedValue: string;

          if AN < Length(Args) then
            Value := Args[AN]
          else
            Value := NULL;

          var Index := FindIndexOf(MessageTemplate, ':', T1, T2);
          if Index <> -1 then
          begin
            Name := Copy(MessageTemplate, T1, Index-T1);
            ValueFmt := Copy(MessageTemplate, Index+1, T2-Index-1);
          end
          else
          begin
            Name := Copy(MessageTemplate, T1, T2-T1);
            ValueFmt := '';
          end;

          FormattedValue := LoggerFactory.ValueFormatter(ValueFmt, Value);

          if Properties <> nil then
            Properties.AddOrSetValue(Name, Value);

          B.Append(FormattedValue);
          Inc(AN);

          T1 := T2+1;
          T2 := T1;

          state := TState.Scan;
        end;
      end;
    end;

    Result := B.ToString;
  finally
    B.Free;
  end;
end;

function DefaultValueFormatter(const Fmt: string; const Value: Variant): string;
begin
  if Fmt <> '' then
    case VarType(Value) of
      varEmpty: Result := '';
      varNull: Result := '(null)';
      varSmallInt: Result := Format(Fmt, [TVarData(Value).VSmallInt]);
      varInteger: Result := Format(Fmt, [TVarData(Value).VInteger]);
      varSingle: Result := Format(Fmt, [TVarData(Value).VSingle]);
      varDouble: Result := Format(Fmt, [TVarData(Value).VDouble]);
      varCurrency: Result := Format(Fmt, [TVarData(Value).VCurrency]);
      varDate: Result := FormatDateTime(Fmt, TVarData(Value).VDate);
      varOleStr: Format(Fmt, [String(TVarData(Value).VOleStr)]);
      varBoolean: Result := BoolToStr(Value, Fmt <> '1');
      varShortInt: Result := Format(Fmt, [TVarData(Value).VShortInt]);
      varByte: Result := Format(Fmt, [TVarData(Value).VByte]);
      varWord: Result := Format(Fmt, [TVarData(Value).VWord]);
      varUInt32: Result := Format(Fmt, [TVarData(Value).VUInt32]);
      varInt64: Result := Format(Fmt, [TVarData(Value).VInt64]);
      varUInt64: Result := Format(Fmt, [TVarData(Value).VUInt64]);
      varString:  Result := Format(Fmt, [RawByteString(TVarData(Value).VString)]);
      varUString: Result := Format(Fmt, [UnicodeString(TVarData(Value).VUString)]);
      else
        Result := VarToStr(Value);
    end
  else if Value = NULL then
    Result := '(null)'
  else
    Result := VarToStr(Value);
end;

function DefaultStateFormatter(const [ref] State: TLogState): string;
begin
  Result := State.Message;
end;

{ TEventId }

constructor TEventId.Create(const Id: Integer; const Name: string);
begin
  FId := Id;
  FName := Name;
end;

constructor TEventId.Create(const Id: Integer);
begin
  FId := Id;
  FName := '';
end;

class operator TEventId.Implicit(Id: Integer): TEventId;
begin
  Result.FId := Id;
  Result.FName := '';
end;

{ TLogger<T> }

constructor TLogger<T>.Create;
begin
  var ctx := TRttiContext.Create;
  try
    FCategory := ctx.GetType(TypeInfo(T)).QualifiedName;
  finally
    ctx.Free;
  end;
end;

{ TLogger }

constructor TLogger.Create(const Category: string);
begin
  FCategory := Category;
end;

procedure TLogger.BeginScope(const MessageTemplate: string; const Args: array of variant);
begin
  var state: TLogState;
  state.FCategory := FCategory;
  state.FMessageTemplate := MessageTemplate;

  var props := TDictionary<string, variant>.Create;
  try
    state.FMessage := FormatMessageTemplate(MessageTemplate, Args, props);
    state.FProperties := props.ToArray;
  finally
    props.Free;
  end;

  // for each logger instance (CreateLogger normally caches logger)
  for var Provider in LoggerFactory.FProviders.Values do
    Provider.CreateLogger(FCategory).BeginScope(state);
end;

procedure TLogger.EndScope;
begin
  for var Provider in LoggerFactory.FProviders.Values do
    Provider.CreateLogger(FCategory).EndScope;
end;

function TLogger.IsEnabled(const LogLevel: TLogLevel): boolean;
begin
  for var Provider in LoggerFactory.FProviders.Values do
    if Provider.CreateLogger(FCategory).IsEnabled(LogLevel) then
      Exit(True);

  Result := False;
end;

procedure TLogger.Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: array of variant);
begin
  var state: TLogState;
  state.FCategory := FCategory;
  state.FMessageTemplate := MessageTemplate;

  var props := TDictionary<string, variant>.Create;
  try
    state.FMessage := FormatMessageTemplate(MessageTemplate, Args, props);

    // Add static properties
    for var prop in LoggerFactory.FStaticProps do
      props.AddOrSetValue(prop.Key, prop.Value);

    // Add dynamic properties
    for var proc in LoggerFactory.FDynamicProps do
      proc(props);

    state.FProperties := props.ToArray;
  finally
    props.Free;
  end;

  for var Provider in LoggerFactory.FProviders.Values do
    Provider.CreateLogger(FCategory).Log(LogLevel, EventId, Exc, state, DefaulTStateFormatter);
end;

procedure TLogger.LogCritical(const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Critical, 0, nil, MessageTemplate, Args);
end;

procedure TLogger.LogCritical(const Exc: Exception;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Critical, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogCritical(const EventId: TEventId;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Critical, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogCritical(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Critical, EventId, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogDebug(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Debug, EventId, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogDebug(const EventId: TEventId;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Debug, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogDebug(const Exc: Exception;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Debug, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogDebug(const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Debug, 0, nil, MessageTemplate, Args);
end;

procedure TLogger.LogError(const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Error, 0, Nil, MessageTemplate, Args);
end;

procedure TLogger.LogError(const Exc: Exception;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Error, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogError(const EventId: TEventId;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Error, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogError(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Error, EventId, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogInformation(const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Information, 0, nil, MessageTemplate, Args);
end;

procedure TLogger.LogInformation(const Exc: Exception;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Information, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogInformation(const EventId: TEventId;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Information, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogInformation(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Information, EventId, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogTrace(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Trace, EventId, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogTrace(const EventId: TEventId;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Trace, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogTrace(const Exc: Exception;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Trace, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogTrace(const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Trace, 0, nil, MessageTemplate, Args);
end;

procedure TLogger.LogWarning(const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Warning, 0, nil, MessageTemplate, Args);
end;

procedure TLogger.LogWarning(const Exc: Exception;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Warning, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogWarning(const EventId: TEventId;
  const MessageTemplate: string; const Args: array of variant);
begin
  Log(TLogLevel.Warning, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogWarning(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: array of variant);
begin
  Log(TLogLevel.Warning, EventId, Exc, MessageTemplate, Args);
end;

{ TLogState }

//class operator TLogState.Finalize(var Dest: TLogState);
//begin
//  WriteLn(Format('Finalize %p', [@Dest]));
//end;

//class operator TLogState.Initialize(out Dest: TLogState);
//begin
//  WriteLn(Format('Initialize %p', [@Dest]));
//end;


{ TLoggerFactory }

function TLoggerFactory.WithProperty(
  const Proc: TProc<TDictionary<string, variant>>): TLoggerFactory;
begin
  Result := Self;

  FDynamicProps.Add(Proc);
end;

function TLoggerFactory.WithProperty(const Name: string;
  const Value: variant): TLoggerFactory;
begin
  Result := Self;

  FStaticProps.AddOrSetValue(Name, Value);
end;

function TLoggerFactory.AddProvider<T>(ConfigureProc: TProc<T>): TLoggerFactory;
begin
  var Provider: T := nil;

  var ctx := TRttiContext.Create;
  try
    var typ := ctx.GetType(TypeInfo(T));
    for var method in typ.GetMethods do
    begin
      // find zero arg constructor
      if typ.IsInstance and method.IsConstructor and (Length(method.GetParameters) = 0) then
      begin
        var val := method.Invoke(typ.AsInstance.MetaclassType, []);
        Provider := val.AsType<T>;
        Break;
      end;
    end;

    if Provider = nil then
      raise EArgumentException.Create(Format('Unsupported type: %s', [typ.ToString]));
  finally
    ctx.Free;
  end;

  Result := AddProvider<T>(Provider, ConfigureProc);
end;

function TLoggerFactory.AddProvider<T>(Provider: T; ConfigureProc: TProc<T>): TLoggerFactory;
begin
  var Name := (Provider as TObject).QualifiedClassName;

  FProviders.Add(Name, Provider);

  if Assigned(ConfigureProc) then
    ConfigureProc(Provider);

  Result := Self;
end;

constructor TLoggerFactory.Create;
begin
  FProviders := TDictionary<string, ILoggerProvider>.Create;
  FStaticProps := TDictionary<string, variant>.Create;
  FDynamicProps := TList<TProc<TDictionary<string, variant>>>.Create;

  FValueFormatter := DefaultValueFormatter;
  FStateFormatter := DefaultStateFormatter;
end;

function TLoggerFactory.CreateLogger(const Category: string): ILogger;
begin
  Result := TLogger.Create(Category);
end;

function TLoggerFactory.CreateLogger<T>: ILogger<T>;
begin
  Result := TLogger<T>.Create;
end;

destructor TLoggerFactory.Destroy;
begin
  FStaticProps.Clear;
  FDynamicProps.Clear;
  FProviders.Clear;
  FreeAndNil(FStaticProps);
  FreeAndNil(FDynamicProps);
  FreeAndNil(FProviders);
  inherited;
end;

initialization
  LoggerFactory := TLoggerFactory.Create;

finalization
  FreeAndNil(LoggerFactory);

end.

