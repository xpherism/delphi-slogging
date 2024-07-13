unit SLogging.&File;

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
  SLogging.Utils.Queue;

{$B-} // Enable boolean short-circuit code generation by the compiler

type
  TFileLogger = class;
  TFileLoggerProvider = class;

  {* File Writer *}

  TFileWriter = class
  protected
    FActiveFileName: String;
    FFile: TFileStream;
    procedure EnsureFile(const FileName: string; Formatter: TFunc<string, string>); inline;
  public
    procedure WriteLine(const Line: String; const FileName: string; FileNameFormatter: TFunc<string, string>; const Encoding: TEncoding);
  end;

  TFileLogger = class(TInterfacedObject, ILoggerImplementor)
  protected
    FCategory: String;
    FProvider: TFileLoggerProvider;
  public
    constructor Create;

    function IsEnabled(const LogLevel: TLogLevel): boolean; inline;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const State: TState; const Exc: Exception; const Formatter: TStateFormatter); virtual;
    procedure BeginScope(const State: TState);
    procedure EndScope;
  end;

  TFileLoggerProvider = class (TInterfacedObject, ILogQueueWorker<TLogEntry>, ILoggerProvider)
  private
    FUseUTC: Boolean;
    FMinLevel: TLogLevel;
    FEncoding: TEncoding;
    FFileName: String;
    FIncludeScopes: Boolean;
    FFilenameFormatter: TFunc<string, string>;
    procedure SetMinLevel(const Value: TLogLevel);
    function GetMaxQueueTime: Integer;
    function GetMinQueueSize: Integer;
    procedure SetMaxQueueTime(const Value: Integer);
    procedure SetMinQueueSize(const Value: Integer);
  protected
    FQueue: TLogQueue<TLogEntry>;
    FWriter: TFileWriter;
    FScopes: IScopeHandler<TState>;
    function HandleDequeue(const [ref] Entry: TLogEntry): Boolean; virtual;
    property Queue: TLogQueue<TLogEntry> read FQueue;
    property Writer: TFileWriter read FWriter;
  public
    constructor Create; virtual;
    destructor Destroy; override;

    function CreateLogger(Category: string): ILoggerImplementor; virtual;
    procedure Close;

    property UseUTC: Boolean read FUseUTC write FUseUTC;
    property MinLevel: TLogLevel read FMinLevel write SetMinLevel;
    property IncludeScopes: Boolean read FIncludeScopes write FIncludeScopes;
    property FileName: string read FFilename write FFileName;
    property FileNameFormatter: TFunc<string, string> read FFilenameFormatter write FFilenameFormatter;
    property Encoding: TEncoding read FEncoding write FEncoding;
    // <summary>flush queue if more than X milliseconds since last write</summary>
    property MaxQueueTime: Integer read GetMaxQueueTime write SetMaxQueueTime;
    // <summary>flush queue if the number of entries X or more</summary>
    property MinQueueSize: Integer read GetMinQueueSize write SetMinQueueSize;
  end;

implementation

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  System.Variants,
  System.VarUtils,
  System.DateUtils;

const
  LogLevelNames : array [TLogLevel.Trace..TLogLevel.None] of string = ('TRACE','DEBUG','INFO ','WARN ','ERROR','FATAL','NONE ');

{ TFileWriter }

procedure TFileWriter.EnsureFile(const FileName: string; Formatter: TFunc<string, string>);
var
  NewFileName: String;
  Handle: Cardinal;
begin
  if Assigned(Formatter) then
    NewFileName := Formatter(FileName)
  else
    NewFileName := FileName;

  // close file (and reopen later) if filename has changed or file has been deleted
  if (FFile <> nil) and ((FActiveFileName <> NewFileName) or not TFile.Exists(FActiveFileName)) then
    FreeAndNil(FFile);

  if FFile = nil then
  begin
{$IFDEF MSWINDOWS}
    Handle := CreateFile(
      PChar(NewFileName),
      GENERIC_READ or GENERIC_WRITE,
      FILE_SHARE_READ or FILE_SHARE_DELETE,
      nil,
      OPEN_ALWAYS,
      FILE_ATTRIBUTE_NORMAL or FILE_FLAG_WRITE_THROUGH, // or FILE_FLAG_NO_BUFFERING (=> EOS ERROR 87),
      0
    );

    if Handle = INVALID_HANDLE_VALUE then
      RaiseLastOSError;

    FActiveFileName := NewFileName;

    FFile := TFileStream.Create(Handle);
    FFile.Seek(0, soFromEnd);
{$ELSE}
    FActiveFileName := NewFileName;
    FFile := TFileStream.Create(FActiveFileName, fmOpenReadWrite or fmShareDenyWrite);
    FFile.Seek(0, soFromEnd);
{$ENDIF}
  end;
end;


procedure TFileWriter.WriteLine(const Line: string; const FileName: string; FileNameFormatter: TFunc<string, string>; const Encoding: TEncoding);
begin
  EnsureFile(FileName, FileNameFormatter);

  var writer := TStreamWriter.Create(FFile, Encoding);
  try
    writer.WriteLine(Line);
    Writer.Flush;
  finally
    writer.Free;
  end;
end;

{ TFileLogger }

constructor TFileLogger.Create;
begin
  inherited;
end;

function TFileLogger.IsEnabled(const LogLevel: TLogLevel): boolean;
begin
  Result := LogLevel >= FProvider.MinLevel;
end;

procedure TFileLogger.BeginScope(const State: TState);
begin
  FProvider.FScopes.BeginScope(State);
end;

procedure TFileLogger.EndScope;
begin
  FProvider.FScopes.EndScope;
end;

procedure TFileLogger.Log(const LogLevel: TLogLevel; const EventId: TEventId; const State: TState; const Exc: Exception; const Formatter: TStateFormatter);
begin
  if not IsEnabled(LogLevel) then
    Exit;

  var Entry: TLogEntry;
  Entry.MessageTemplate := State.Template;
  Entry.Message := Formatter(State, Exc);
  Entry.Category := FCategory;
  if FProvider.UseUTC then
    Entry.TimeStamp := TLogTime.UTC
  else
    Entry.TimeStamp := TLogTime.Now;
  Entry.EventId := EventId;
  Entry.LogLevel := LogLevel;
  SetLength(Entry.Renderings, Length(state.Values));

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
    if FProvider.IncludeScopes then
      FProvider.FScopes.ForEach(
        procedure(const [ref] State: TState)
        begin
          for var item in State.Values do
          begin
            Props.AddOrSetValue(item.Name, item.Value);
          end;
        end
      );

    // Get message template properties (values and renderings)
    for var I := 0 to Length(state.Values)-1 do
    begin
      Entry.Renderings[I] := state.Values[I].FormattedValue;
      Props.AddOrSetValue(state.Values[I].Name, state.Values[I].Value);
    end;

    Entry.Properties := Props.ToArray;
  finally
    Props.Free;
  end;

  if Exc <> nil then
  begin
    Entry.Exception.Message := Exc.ToString;
    Entry.Exception.StackTrace := exc.StackTrace;
  end;

  FProvider.FQueue.Enqueue(Entry);
end;

{ TFileLoggerProvider }

procedure TFileLoggerProvider.Close;
begin
  FQueue.Close;
end;

constructor TFileLoggerProvider.Create;
begin
  inherited;
  FIncludeScopes := False;
  FScopes := TScopeHandler<TState>.Create;
  FWriter := TFileWriter.Create;
  FQueue := TLogQueue<TLogEntry>.Create(Self);
  FQueue.OnWorkerError :=
    procedure (Exc: Exception)
    begin
      LoggerFactory.HandleInternalException(Exc);
    end;
  FMinLevel := TLogLevel.Information;
  FEncoding := TEncoding.UTF8;
  FUseUTC := True;
end;

destructor TFileLoggerProvider.Destroy;
begin
  FreeAndNil(FQueue);
  FreeAndNil(FWriter);
  FScopes := nil;

  inherited;
end;

function TFileLoggerProvider.GetMaxQueueTime: Integer;
begin
  Result := FQueue.MaxQueueTime;
end;

function TFileLoggerProvider.GetMinQueueSize: Integer;
begin
  Result := FQueue.MinQueueSize;
end;

procedure TFileLoggerProvider.SetMaxQueueTime(const Value: Integer);
begin
  FQueue.MaxQueueTime := Value;
end;

procedure TFileLoggerProvider.SetMinLevel(const Value: TLogLevel);
begin
  FMinLevel := Value;
end;

procedure TFileLoggerProvider.SetMinQueueSize(const Value: Integer);
begin
  FQueue.MinQueueSize := Value;
end;

function TFileLoggerProvider.CreateLogger(Category: string): ILoggerImplementor;
begin
  var Logger := TFileLogger.Create;
  Logger.FCategory := Category;
  Logger.FProvider := Self;
  Result := Logger;
end;

function TFileLoggerProvider.HandleDequeue(const [ref] Entry: TLogEntry): Boolean;
begin
  var SB := TStringBuilder.Create;
  try
    SB.Append(entry.Timestamp.FormatISO8601);
    SB.Append(' ');
    SB.Append(LogLevelNames[entry.LogLevel]);
    SB.Append(' ');
    SB.Append(entry.Category);
    SB.Append('[');
    SB.Append(entry.EventId.Id);
    SB.Append('] ');
    SB.Append(entry.Message);

    if entry.Exception.Message <> '' then
    begin
      SB.Append(sLineBreak);
      SB.Append(entry.Exception.Message);
      SB.Append(sLineBreak);
      SB.Append(entry.Exception.StackTrace);
    end;

    Writer.WriteLine(SB.ToString, FileName, FileNameFormatter, Encoding);
  finally
    SB.Free;
  end;

  Result := True;
end;

end.
