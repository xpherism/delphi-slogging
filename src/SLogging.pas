unit SLogging;

{*
  Structured Logging framework for Delphi inspired by .NET Logging

  Important notes:

  TState is passed by reference but is allocated on the stack.
  Any ILoggerImplementor that involves async operations (ie. queuing) must
  make a copy (ie. assign to stack local variable or allocate on heap).
*}

{$B-} // Enable boolean short-circuit code generation by the compiler

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
    function ToDateTime: TDateTime;
    function ToLocalTime: TLogTime;
    function FormatISO8601: string; inline;
  end;

  TEventId = record
  private
    FId: Integer;
    FName: string;
  public
    class operator Implicit(Id: Integer): TEventId;

    property Id: Integer read FId;
    property Name: string read FName;
  end;

  TValueFormatter<T> = reference to function(const Fmt: string; const [ref] Value: T): string;

  TFormattedValue<T> = record
    Name: string;
    Value: T;
    FormattedValue: string;
  end;

  // When using structured logging the same message template is used multiple times
  // Using a TMessageTemplate we can cache these, save time normally spent parsing (use hashing to key templates)
  // Template message format: {Name[:format]} => format is passed to formatter function
  TMessageTemplate = class
  private type
    TSpan = record
      &Type: (Text, Value, LBrace, RBrace);
      Start: Integer;
      Length: Integer;
      FmtPos: Integer;
    end;
  private
    FCount: Integer;
    FSpans: TArray<TSpan>;
    FTemplate: string;
    procedure Parse;
  public
    constructor Create(const Format: string);
    destructor Destroy; override;
    function Format<T>(const Args: TArray<T>; const ValueFormatter: TValueFormatter<T>; var Values: TArray<TFormattedValue<T>>): String;
    property Template: string read FTemplate;
  end;
    
  // Delphi interfaces does not support generic function.
  // Use inheritance to override instead
  // Default log state that supports message templates
  TState = record
  private
    class var Lock: TObject;
    class var Formatters: TDictionary<string, TMessageTemplate>; // Format is key
  var
    FFormatter: TMessageTemplate;
    FTemplate: string;
    FMessage: string;
    FValues: TArray<TFormattedValue<Variant>>;
  public
    constructor Create(const Format: String; const Values: TArray<Variant>); overload;
    constructor Create(const Properties: TArray<TPair<String, Variant>>); overload;
    
    property Template: string read FTemplate;
    property &Message: string read FMessage;
    property Values: TArray<TFormattedValue<Variant>> read FValues;
  end;

  // Exception is not provided as an argument to Formatters (https://github.com/aspnet/Logging/issues/442)
  TStateFormatter = reference to function(const [ref] State: TState; const Exc: Exception): string;

  TLogEntry = record
    TimeStamp: TLogTime;
    LogLevel: TLogLevel;
    Category: String;
    EventId: TEventId;
    &Message: String;
    &MessageTemplate: String;
    &Exception: record
      &Message: String;
      StackTrace: String;
    end;
    Properties: TArray<TPair<String, Variant>>;
    Renderings: TArray<String>;
  end;

  TScopeForEachProc<T> = reference to procedure(const [ref] State: T);

  IScopeHandler<T> = interface
    procedure BeginScope(const State: T);
    procedure EndScope;
    procedure ForEach(const Proc: TScopeForEachProc<T>);
  end;

  TScopeHandler<T> = class(TInterfacedObject, IScopeHandler<T>)
  private
    FScopes: TThreadList<T>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure BeginScope(const State: T);
    procedure EndScope;
    procedure ForEach(const Proc: TScopeForEachProc<T>);
  end;

  // Delphi does not support helper methods for interfaces, so we need a specific interface for
  // implementation specific and proxy interface for general usage
  ILoggerImplementor = interface
    function IsEnabled(const LogLevel: TLogLevel): boolean;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const State: TState; const Exc: Exception; const Formatter: TStateFormatter);
    procedure BeginScope(const State: TState);
    procedure EndScope;
  end;

  // Providers should always have zero argument constructor
  ILoggerProvider = interface
    function CreateLogger(Category: string): ILoggerImplementor;
    procedure Close;
  end;

  {*
    Proxy implementation with support for message templates

    Variant keeps "distinct" type info during assignment (ie. TDateTime is varDate and not float), which TValue or TVarRec does not do
    This is the proxy interface that everyone uses, T is the type used for category name
  *}

  ILogger = interface
    function IsEnabled(const LogLevel: TLogLevel): boolean;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>);

    procedure BeginScope(const Properties: TArray<TPair<string, variant>>);
    procedure EndScope;

    // Is this what we want to do, scope from MS is kind all over the place
    //    procedure BeginScope(const MessageTemplate: string; const Args: TArray<Variant>);
    //    procedure EndScope;

    // helper methods
    procedure LogTrace(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogTrace(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogTrace(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogTrace(const MessageTemplate: string; const Args: TArray<Variant>); overload;

    procedure LogDebug(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogDebug(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogDebug(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogDebug(const MessageTemplate: string; const Args: TArray<Variant>); overload;

    procedure LogInformation(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogInformation(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogInformation(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogInformation(const MessageTemplate: string; const Args: TArray<Variant>); overload;

    procedure LogWarning(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogWarning(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogWarning(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogWarning(const MessageTemplate: string; const Args: TArray<Variant>); overload;

    procedure LogError(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogError(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogError(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogError(const MessageTemplate: string; const Args: TArray<Variant>); overload;

    procedure LogCritical(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogCritical(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogCritical(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogCritical(const MessageTemplate: string; const Args: TArray<Variant>); overload;
  end;

  TLogger = class(TInterfacedObject, ILogger)
  private
    FLoggers: TList<ILoggerImplementor>;
    FCategory: String;
    constructor Create(const Category: string);
  public
    destructor Destroy; override;
    
    function IsEnabled(const LogLevel: TLogLevel): boolean;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>);
    procedure BeginScope(const Properties: TArray<TPair<string, variant>>);
    procedure EndScope;

//    procedure BeginScope(const MessageTemplate: string; const Args: TArray<Variant>);
//    procedure EndScope;

    procedure LogTrace(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogTrace(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogTrace(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogTrace(const MessageTemplate: string; const Args: TArray<Variant>); overload;

    procedure LogDebug(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogDebug(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogDebug(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogDebug(const MessageTemplate: string; const Args: TArray<Variant>); overload;

    procedure LogInformation(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogInformation(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogInformation(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogInformation(const MessageTemplate: string; const Args: TArray<Variant>); overload;

    procedure LogWarning(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogWarning(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogWarning(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogWarning(const MessageTemplate: string; const Args: TArray<Variant>); overload;

    procedure LogError(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogError(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogError(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogError(const MessageTemplate: string; const Args: TArray<Variant>); overload;

    procedure LogCritical(const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogCritical(const EventId: TEventId; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogCritical(const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>); overload;
    procedure LogCritical(const MessageTemplate: string; const Args: TArray<Variant>); overload;
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
    FStaticProps: TDictionary<string, Variant>;
    FDynamicProps: TDictionary<string, TFunc<Variant>>;
    FValueFormatter: TValueFormatter<Variant>;
    FStateFormatter: TStateFormatter;
    FOnException: TProc<Exception>;
  public
    constructor Create;
    destructor Destroy; override;

    function CreateLogger<T>: ILogger<T>; overload;
    function CreateLogger(const Category: string): ILogger; overload;

    function AddProvider<T: ILoggerProvider, constructor>(ConfigureProc: TProc<T> = nil): TLoggerFactory; overload;
    function AddProvider<T: ILoggerProvider, constructor>(Provider: T; ConfigureProc: TProc<T> = nil): TLoggerFactory; overload;

    // static properties ie. process id, correlation id etc.
    function WithProperty(const Name: string; const Value: Variant): TLoggerFactory; overload;
    // dynamic properties called on every log event, thread id,
    function WithProperty(const Name: string; const Func: TFunc<Variant>): TLoggerFactory; overload;

    procedure EvalProperties(const Proc: TProc<String, Variant>);
    
    property ValueFormatter: TValueFormatter<Variant> read FValueFormatter write FValueFormatter;
    property StateFormatter: TStateFormatter read FStateFormatter write FStateFormatter;

    procedure HandleInternalException(const Exc: Exception); inline;

    property OnException: TProc<Exception> read FOnException write FOnException;
  end;
  
  function DefaultValueFormatter(const Fmt: string; const [ref] Value: Variant): string; inline;  
  function DefaultStateFormatter(const [ref] State: TState; const Exc: Exception): string; inline;

  function EventId(Id: Integer; Name: String): TEventId; inline;
  function P(const Name: String; Value: Variant): TPair<string, variant>;

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

function P(const Name: String; Value: Variant): TPair<string, variant>; inline;
begin
  Result.Key := Name;
  Result.Value := Value;
end;

function DefaultValueFormatter(const Fmt: string; [ref] const Value: Variant): string;
begin
  if Fmt <> '' then
    case VarType(Value) of
      varEmpty: Result := '(null)';
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
  else if (Value = NULL) or (Value = Unassigned) then
    Result := '(null)'
  else
    Result := VarToStr(Value);
end;

function DefaultStateFormatter(const [ref] State: TState; const Exc: Exception): string;
begin
  Result := State.Message;
end;

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
  var local := TTimeZone.Local.ToLocalTime(UnixToDateTime(unixtime_ns div 1000000000, True));
  var msec: word;
  DecodeDate(local, Result.Year, Result.Month, Result.Day);
  DecodeTime(local, Result.Hour, Result.Minute, Result.Second, MSec);
  Result.NanoSecond := unixtime_ns mod 1000000000;
{$ELSE}
  var local := System.SysUtils.Now;
  var msec: word;
  DecodeDate(local, Result.Year, Result.Month, Result.Day);
  DecodeTime(local, Result.Hour, Result.Minute, Result.Second, MSec);
  Result.NanoSecond := msec * 1000000;
{$ENDIF}
end;

function TLogTime.ToDateTime: TDateTime;
begin
  Result := EncodeDateTime(Year, Month, Day, Hour, Minute, Second, NanoSecond div 1000000);
end;

function TLogTime.ToLocalTime: TLogTime;
begin
  if not IsUTC then
    Exit(Self);

  Result := Self;
  var _: WORD;
  DecodeDateTime(TTimeZone.Local.ToLocalTime(ToDateTime), Year, Month, Day, Hour, Minute, Second, _);
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

{ TMessageTemplate }

constructor TMessageTemplate.Create(const Format: string);
begin
  SetLength(FSpans, 8);

  FCount := 0;
  FTemplate := Format;
  try
    Parse;
  except
    SetLength(FSpans, 0);
    raise;
  end;
end;

destructor TMessageTemplate.Destroy;
begin
  SetLength(FSpans, 0);
  inherited;
end;

function TMessageTemplate.Format<T>(const Args: TArray<T>; const ValueFormatter: TValueFormatter<T>; var Values: TArray<TFormattedValue<T>>): String;
begin
  SetLength(Values, Length(Args));

  var B := TStringBuilder.Create(FTemplate.Length);
  try
    var ArgNum := 0;
    for var I := 0 to FCount-1 do
    begin
      case FSpans[I].&Type of
        Text:
          B.Append(FTemplate, FSpans[I].Start-1, FSpans[I].Length);
        LBrace:
          B.Append('{');
        RBrace:
          B.Append('}');
        Value: begin
          var Name: string;
          var Value: T;
          var ValueFmt: string;
          var FormattedValue: string;

          if ArgNum < Length(Args) then
            Value := Args[ArgNum]
          else
            Value := Default(T);

          if FSpans[I].FmtPos <> -1 then
          begin
            Name := Copy(Template, FSpans[I].Start+1, FSpans[I].FmtPos-FSpans[I].Start-1);
            ValueFmt := Copy(Template, FSpans[I].FmtPos+1, FSpans[I].Length-(FSpans[I].FmtPos-FSpans[I].Start)-2);
          end
          else
          begin
            Name := Copy(Template, FSpans[I].Start+1, FSpans[I].Length-2);
            ValueFmt := '';
          end;

          FormattedValue := ValueFormatter(ValueFmt, Value);

          Values[ArgNum].Name := Name;
          Values[ArgNum].Value := Value;
          Values[ArgNum].FormattedValue := FormattedValue;

          B.Append(FormattedValue);

          Inc(ArgNum);
        end;
      end;
    end;
    Result := B.ToString;
  finally
    B.Free;
  end;
end;

procedure TMessageTemplate.Parse;
type
  TState = (Scan, TextDone, ArgScan, ArgFail, ArgDone, Done);

  function FindIndexOf(const [ref] str: string; needle: char; fromIndex, toIndex: integer): integer; inline;
  begin
    Result := -1;
    for var I := fromIndex to toIndex do
      if str[I] = needle then
        Exit(I);
  end;

  procedure AppendLBrace(Start, Length: Integer);
  begin
    if System.Length(FSpans) >= FCount then
      SetLength(FSpans, System.Length(FSpans)+4);

    FSpans[FCount].&Type := LBrace;
    FSpans[FCount].Start := Start;
    FSpans[FCount].Length := Length;
    FSpans[FCount].FmtPos := -1;
    Inc(FCount);
  end;

  procedure AppendRBrace(Start, Length: Integer);
  begin
    if System.Length(FSpans) >= FCount then
      SetLength(FSpans, System.Length(FSpans)+4);

    FSpans[FCount].&Type := RBrace;
    FSpans[FCount].Start := Start;
    FSpans[FCount].Length := Length;
    FSpans[FCount].FmtPos := -1;
    Inc(FCount);
  end;

  procedure AppendText(Start, Length: Integer);
  begin
    if System.Length(FSpans) >= FCount then
      SetLength(FSpans, System.Length(FSpans)+4);

    FSpans[FCount].&Type := Text;
    FSpans[FCount].Start := Start;
    FSpans[FCount].Length := Length;
    FSpans[FCount].FmtPos := -1;
    Inc(FCount);
  end;

  procedure AppendValue(Name: String; Start, Length, FmtPos: Integer);
  begin
    if System.Length(FSpans) >= FCount then
      SetLength(FSpans, System.Length(FSpans)+4);

    FSpans[FCount].&Type := Value;
    FSpans[FCount].Start := Start;
    FSpans[FCount].Length := Length;
    FSpans[FCount].FmtPos := FmtPos;

    Inc(FCount);
  end;

begin
  var L := FTemplate.Length;

  if L = 0 then Exit;

  var state := TState.Scan;
  var P1 := 1;
  var P2 := 1;

  while State <> TState.Done do
  begin
    case state of

      TState.Scan: begin
        // {{ (escaped {)
        if (FTemplate[P2] = '{') and (P2+1 <= L) and (FTemplate[P2+1] = FTemplate[P2]) then
        begin
          AppendText(P1, P2-P1);
          AppendLBrace(P2, 2);
          P1 := P2+2;
          P2 := P1;
        end
        // }} (escaped })
        else if (FTemplate[P2] = '}') and (P2+1 <= L) and (FTemplate[P2+1] = FTemplate[P2]) then
        begin
          AppendText(P1, P2-P1);
          AppendRBrace(P2, 2);
          P1 := P2+2;
          P2 := P1;
        end
        // { start argument parsing
        else if (FTemplate[P2] = '{')  then
        begin
          AppendText(P1, P2-P1);
          P1 := P2+1;
          P2 := P1;
          State := TState.ArgScan;
        end
        // no more characters we are done
        else if (P2 > L) then
        begin
          if P2 > P1 then
            AppendText(P1, P2-P1);
          break;
        end
        else
          Inc(P2);
      end;

      TState.ArgScan: begin
        if P2 > L then
          state := TState.Scan
        else if FTemplate[P2] = '}' then
          state := TState.ArgDone
        else if FTemplate[P2] = '{' then
          state := TState.Scan
        else
          Inc(P2);
      end;

      TState.ArgDone: begin
        var Index := FindIndexOf(Template, ':', P1, P2);
        if Index <> -1 then
          AppendValue(Copy(Template, P1, Index-P1), P1-1, P2-P1+2, Index)
        else
          AppendValue(Copy(Template, P1, P2-P1), P1-1, P2-P1+2, Index);

        P1 := P2+1;
        P2 := P1;

        state := TState.Scan;
      end;
    end;
  end;
end;

{ TEventId }

function EventId(Id: Integer; Name: String): TEventId; inline;
begin
  Result.FId := Id;
  Result.FName := Name;
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
    inherited Create(ctx.GetType(TypeInfo(T)).QualifiedName);
  finally
    ctx.Free;
  end;
end;

{ TLogger }

constructor TLogger.Create(const Category: string);
begin
  FLoggers := TList<ILoggerImplementor>.Create;
  FCategory := Category;
  
  for var Provider in LoggerFactory.FProviders.Values do
    FLoggers.Add(Provider.CreateLogger(FCategory));
end;

destructor TLogger.Destroy;
begin
  FLoggers.Clear;
  FreeAndNil(FLoggers);
      
  inherited;
end;

//procedure TLogger.BeginScope(const MessageTemplate: string; const Args: TArray<Variant>);
//begin
//  var State := TState.Create(MessageTemplate, Args);
//
//  for var Logger in FLoggers do
//    Logger.BeginScope(State)
//end;

procedure TLogger.BeginScope(const Properties: TArray<TPair<string, variant>>);
begin
  var State := TState.Create(Properties);

  for var Logger in FLoggers do
    Logger.BeginScope(State)
end;

procedure TLogger.EndScope;
begin
  for var Logger in FLoggers do
    Logger.EndScope;
end;

function TLogger.IsEnabled(const LogLevel: TLogLevel): boolean;
begin
  for var Logger in FLoggers do
    if Logger.IsEnabled(LogLevel) then
      Exit(True);

  Result := False;
end;

procedure TLogger.Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const MessageTemplate: string; const Args: TArray<Variant>);
begin
  if FLoggers.Count = 0 then
    Exit;

  var State := TState.Create(MessageTemplate, Args);

  for var Logger in FLoggers do
    Logger.Log(LogLevel, EventId, State, Exc, LoggerFactory.StateFormatter);
end;

procedure TLogger.LogCritical(const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Critical, 0, nil, MessageTemplate, Args);
end;

procedure TLogger.LogCritical(const Exc: Exception;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Critical, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogCritical(const EventId: TEventId;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Critical, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogCritical(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Critical, EventId, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogDebug(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Debug, EventId, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogDebug(const EventId: TEventId;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Debug, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogDebug(const Exc: Exception;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Debug, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogDebug(const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Debug, 0, nil, MessageTemplate, Args);
end;

procedure TLogger.LogError(const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Error, 0, Nil, MessageTemplate, Args);
end;

procedure TLogger.LogError(const Exc: Exception;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Error, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogError(const EventId: TEventId;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Error, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogError(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Error, EventId, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogInformation(const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Information, 0, nil, MessageTemplate, Args);
end;

procedure TLogger.LogInformation(const Exc: Exception;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Information, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogInformation(const EventId: TEventId;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Information, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogInformation(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Information, EventId, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogTrace(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Trace, EventId, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogTrace(const EventId: TEventId;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Trace, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogTrace(const Exc: Exception;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Trace, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogTrace(const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Trace, 0, nil, MessageTemplate, Args);
end;

procedure TLogger.LogWarning(const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Warning, 0, nil, MessageTemplate, Args);
end;

procedure TLogger.LogWarning(const Exc: Exception;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Warning, 0, Exc, MessageTemplate, Args);
end;

procedure TLogger.LogWarning(const EventId: TEventId;
  const MessageTemplate: string; const Args: TArray<Variant>);
begin
  Log(TLogLevel.Warning, EventId, nil, MessageTemplate, Args);
end;

procedure TLogger.LogWarning(const EventId: TEventId;
  const Exc: Exception; const MessageTemplate: string;
  const Args: TArray<Variant>);
begin
  Log(TLogLevel.Warning, EventId, Exc, MessageTemplate, Args);
end;

{ TLoggerFactory }

function TLoggerFactory.WithProperty(const Name: String; const Func: TFunc<Variant>): TLoggerFactory;
begin
  Result := Self;
  FDynamicProps.AddOrSetValue(Name, Func);
end;

function TLoggerFactory.WithProperty(const Name: string; const Value: Variant): TLoggerFactory;
begin
  Result := Self;
  FStaticProps.AddOrSetValue(Name, Value);
end;

function TLoggerFactory.AddProvider<T>(ConfigureProc: TProc<T>): TLoggerFactory;
begin
  Result := AddProvider<T>(T.Create, ConfigureProc);
end;

function TLoggerFactory.AddProvider<T>(Provider: T; ConfigureProc: TProc<T>): TLoggerFactory;
begin
  var Name := (Provider as TInterfacedObject).QualifiedClassName;

  FProviders.Add(Name, Provider);

  if Assigned(ConfigureProc) then
    ConfigureProc(Provider);

  Result := Self;
end;

constructor TLoggerFactory.Create;
begin
  FProviders := TDictionary<string, ILoggerProvider>.Create;
  FStaticProps := TDictionary<string, Variant>.Create;
  FDynamicProps := TDictionary<string, TFunc<Variant>>.Create;

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

  for var Provider in FProviders.Values do
    Provider.Close;

  FProviders.Clear;
  FreeAndNil(FStaticProps);
  FreeAndNil(FDynamicProps);
  FreeAndNil(FProviders);
  inherited;
end;

procedure TLoggerFactory.EvalProperties(const Proc: TProc<String, Variant>);
begin
  if not Assigned(Proc) then
    Exit;
    
  for var Item in FStaticProps do
    Proc(Item.Key, Item.Value);

  for var Item in FDynamicProps do
    if Assigned(Item.Value) then    
      Proc(Item.Key, Item.Value());
end;

procedure TLoggerFactory.HandleInternalException(const Exc: Exception);
begin
  if Assigned(FOnException) then
    FOnException(Exc);
end;

{ TState }

constructor TState.Create(const Format: String; const Values: TArray<Variant>);
begin
  TMonitor.Enter(TState.Lock);
  try
    TState.Formatters.TryGetValue(Format, FFormatter);
  finally
    TMonitor.Exit(TState.Lock);
  end;
  
  if FFormatter <> nil then
    Exit;
      
  try
    FFormatter := TMessageTemplate.Create(Format);
  except on E: Exception do
    begin
      FreeAndNil(FFormatter);
      LoggerFactory.HandleInternalException(E);
    end;
  end;
    
  if FFormatter = nil then
    Exit;
  
  TMonitor.Enter(TState.Lock);
  try
    TState.Formatters.Add(Format, FFormatter);
  finally
    TMonitor.Exit(TState.Lock);
  end;  

  FTemplate := Format;
  FMessage := FFormatter.Format<Variant>(Values, LoggerFactory.ValueFormatter, FValues);
end;                         

constructor TState.Create(const Properties: TArray<TPair<String, Variant>>);
begin
  FTemplate := '';
  SetLength(FValues, Length(Properties));
  for var I := 0 to High(Properties) do
  begin
    FValues[I].Name := Properties[I].Key;
    FValues[I].Value := Properties[I].Value;
  end;
end;

{ TScopeHandler }

constructor TScopeHandler<T>.Create;
begin
  inherited;
  FScopes := TThreadList<T>.Create;
end;

destructor TScopeHandler<T>.Destroy;
begin
  var L := FScopes.LockList;
  try
    L.Clear;
  finally
    FScopes.UnlockList;
  end;

  FreeAndNil(FScopes);

  inherited;
end;

procedure TScopeHandler<T>.BeginScope(const State: T);
begin
  var L := FScopes.LockList;
  try
    L.Add(State);
  finally
    FScopes.UnlockList;
  end;
end;

procedure TScopeHandler<T>.EndScope;
begin
  var L := FScopes.LockList;
  try
    if L.Count > 0 then
      L.Delete(L.Count-1);
  finally
    FScopes.UnlockList;
  end;
end;

procedure TScopeHandler<T>.ForEach(const Proc: TScopeForEachProc<T>);
begin
  if not Assigned(Proc) then
    Exit;

  var L := FScopes.LockList;
  try
    for var Item in L do
      Proc(Item);
  finally
    FScopes.UnlockList;
  end;
end;


initialization
  TState.Lock := TObject.Create;
  TState.Formatters := TDictionary<string, TMessageTemplate>.Create;
  LoggerFactory := TLoggerFactory.Create;

finalization
  FreeAndNil(LoggerFactory);
  FreeAndNil(TState.Formatters);
  FreeAndNil(TState.Lock);

end.


