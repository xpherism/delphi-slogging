unit SLogging.&File;

{$R-,T-,X+,H+,B-}

interface

uses
  System.IOUtils,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Generics.Collections,
  SLogging,
  SLogging.Utils;

type
  TFileLogger = class;
  TFileLoggerProvider = class;

  // this record is used for a final snapshot of the entire log entry, used for queuing etc.
  TLogFileEntry = record
    Timestamp: TLogTime;
    EventId: TEventId;
    Level: TLogLevel;
    MessageTemplate: string;
    &Message: string;
    Category: string;
    Properties: TArray<TPair<string, variant>>;
    Scopes: TArray<TLogState>;
    &Exception: record
      &Message: string;
      StackTrace: string;
    end;
//    class operator Assign(var Dest: TLogState; const [ref] Src: TLogEntry);
//    class operator Finalize(var Dest: TLogState);
//    class operator Initialize(out Dest: TLogState);
  end;

  {* File Logger *}
  TFileWriter = class;

  TFileWriterCls = class of TFileWriter;

  TFileWriter = class
  private
    FActiveFileName: String;
    FFile: TFileStream;
  protected
    procedure EnsureFile(const FileName: string; Formatter: TFunc<string, string>); inline;
  public
    procedure Write(const Entry: TLogFileEntry; const FileName: string; Formatter: TFunc<string, string>; const Encoding: TEncoding); virtual;
  end;

  TFileLogger = class(TInterfacedObject, ILoggerImplementor)
  private
    FProvider: TFileLoggerProvider;
  public
    constructor Create(Provider: TFileLoggerProvider);

    function IsEnabled(const LogLevel: TLogLevel): boolean; inline;
    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>); virtual;
    procedure BeginScope(const State: TLogState); virtual;
    procedure EndScope; virtual;
  end;

  TFileLoggerProvider = class(TInterfacedObject, ILoggerProvider)
  private
    FEvent: TEvent;
    FTask: ITask;
    FMinLevel: TLogLevel;
    FLogger: ILoggerImplementor;
    FQueue: TThreadedQueue<TLogFileEntry>;
    FEncoding: TEncoding;
    FFileName: String;
    FFilenameFormatter: TFunc<string, string>;
    FMaxQueueTime: Integer;
    FMinQueueSize: Integer; 
    procedure SetMinLevel(const Value: TLogLevel);
    procedure StartWorker(Cls: TFileWriterCls);
  public
    constructor Create;
    destructor Destroy; override;

    function CreateLogger(Category: string): ILoggerImplementor; virtual;

    property MinLevel: TLogLevel read FMinLevel write SetMinLevel;
    property FileName: string read FFilename write FFileName;
    property FileNameFormatter: TFunc<string, string> read FFilenameFormatter write FFilenameFormatter;
    property Encoding: TEncoding read FEncoding write FEncoding;
    // <summary>flush queue if the number of entries X or more</summary>
    property MaxQueueTime: Integer read FMaxQueueTime write FMaxQueueTime;
    // <summary>flush queue if more than X milliseconds since last write</summary>
    property MinQueueSize: Integer read FMinQueueSize write FMinQueueSize;
  end;

  {* JSON File Logger *}

  TJsonFileLogger = class;
  TJsonFileLoggerProvider = class;

  TJsonFileWriter = class(TFileWriter)
  public
    procedure Write(const Entry: TLogFileEntry; const FileName: string; Formatter: TFunc<string, string>; const Encoding: TEncoding); override;
  end;

  TJsonFileLogger = class(TFileLogger)
  public
    constructor Create(Provider: TJsonFileLoggerProvider); reintroduce;

    procedure Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>); override;
    procedure BeginScope(const State: TLogState); override;
    procedure EndScope; override;
  end;

  TJsonFileLoggerProvider = class(TFileLoggerProvider)
  private
    FScopes: TThreadList<TLogState>;
    FIncludeScopes: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    function CreateLogger(Category: string): ILoggerImplementor; override;

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

const
  LogLevelNames : array [TLogLevel.Trace..TLogLevel.None] of string = ('TRACE','DEBUG','INFO ','WARN ','ERROR','FATAL','NONE ');

{ TLogFileWriter }

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

procedure TFileWriter.Write(const Entry: TLogFileEntry; const FileName: string; Formatter: TFunc<string, string>; const Encoding: TEncoding);
begin
  EnsureFile(FileName, Formatter);

  var SB := TStringBuilder.Create;
  try
    SB.Append(entry.Timestamp.FormatISO8601);
    SB.Append(' ');
    SB.Append(LogLevelNames[entry.Level]);
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

    var writer := TStreamWriter.Create(FFile, Encoding);
    try
      writer.WriteLine(SB.ToString);
      Writer.Flush;
    finally
      writer.Free;
    end;
  finally
    SB.Free;
  end;
end;


{ TFileLogger }

constructor TFileLogger.Create(Provider: TFileLoggerProvider);
begin
  FProvider := Provider;
end;

function TFileLogger.IsEnabled(const LogLevel: TLogLevel): boolean;
begin
  Result := LogLevel >= FProvider.MinLevel;
end;

procedure TFileLogger.BeginScope(const State: TLogState);
begin
end;

procedure TFileLogger.EndScope;
begin
end;

procedure TFileLogger.Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>);
begin
  if not IsEnabled(LogLevel) then
    Exit;

  FProvider.StartWorker(TFileWriter);

  var Entry: TLogFileEntry;
  Entry.MessageTemplate := State.MessageTemplate;
  Entry.Message := Formatter(State);
  Entry.Category := State.Category;
  Entry.Timestamp := TLogTime.UTC;
  Entry.Properties := State.Properties;
//  Entry.Scopes := FProvider.FScopes;
  Entry.EventId := EventId;
  Entry.Level := LogLevel;
  if Exc <> nil then
  begin
    Entry.Exception.Message := Exc.ToString;
    Entry.Exception.StackTrace := exc.StackTrace;
  end;

  FProvider.FQueue.PushItem(Entry);
  FProvider.FEvent.SetEvent;
end;

{ TFileLoggerProvider }

constructor TFileLoggerProvider.Create;
begin
  inherited;

  FEvent := TEvent.Create;
  FEvent.ResetEvent;

  FLogger := TFileLogger.Create(Self);
  FMinLevel := TLogLevel.Information;
  FQueue := TThreadedQueue<TLogFileEntry>.Create(64);
  FEncoding := TEncoding.UTF8;
  FMinQueueSize := 16;   // flush when queue reaching 16 entries
  FMaxQueueTime := 1000; // wait a maximum of 1000 milliseconds before flushing queue
end;

function TFileLoggerProvider.CreateLogger(Category: string): ILoggerImplementor;
begin
  Result := FLogger;
end;

destructor TFileLoggerProvider.Destroy;
begin
  FTask.Cancel;
  while FTask <> nil do
    CheckSynchronize(1000);

  FLogger := nil;
  FreeAndNil(FEvent);

  inherited;
end;

procedure TFileLoggerProvider.StartWorker(Cls: TFileWriterCls);
begin
  if FTask <> nil then
    Exit;

  FTask := TTask.Create(
    procedure
    begin
      try
        var Writer := Cls.Create;
        try
          var LastWriteTs := Now;
          
          repeat
            case FEvent.WaitFor(100) of
              wrTimeout:
                ;      // check
              wrAbandoned:
                break; // If TEvent is destroyed
              wrError:
                RaiseLastOSError;
              wrSignaled:
                FEvent.ResetEvent;
            end;

            if (MilliSecondsBetween(Now, LastWriteTs) >= FMaxQueueTime) or (FQueue.QueueSize >= FMinQueueSize) or (FTask.Status = TTaskStatus.Canceled) then
              while FQueue.QueueSize > 0 do
              begin
                Writer.Write(FQueue.PopItem, FileName, FileNameFormatter, Encoding);                
                LastWriteTs := Now;
              end;              
          until FTask.Status = TTaskStatus.Canceled;
        finally
          FreeAndNil(Writer);
        end;
      finally
        TThread.Queue(nil,
          procedure begin
            FTask := nil;
          end
        );
      end;
    end
  );
  
  FTask.Start;
end;

procedure TFileLoggerProvider.SetMinLevel(const Value: TLogLevel);
begin
  FMinLevel := Value;
end;

{ TJSONLogFileWriter }

procedure TJsonFileWriter.Write(const Entry: TLogFileEntry;
  const FileName: string; Formatter: TFunc<string, string>;
  const Encoding: TEncoding);
begin
  EnsureFile(FileName, Formatter);

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

    var writer := TStreamWriter.Create(FFile, Encoding);
    try
      writer.WriteLine(SR.DataString);
      Writer.Flush;
    finally
      writer.Free;
    end;
  finally
    JB.Free;
    SR.Free;
  end;
end;

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

{ TJsonFileLogger }

constructor TJsonFileLogger.Create(Provider: TJsonFileLoggerProvider);
begin
  FProvider := Provider;
end;

procedure TJsonFileLogger.Log(const LogLevel: TLogLevel; const EventId: TEventId; const Exc: Exception; const State: TLogState; Formatter: TStateFormatter<TLogState>);
begin
  if not IsEnabled(LogLevel) then
    Exit;

  FProvider.StartWorker(TJsonFileWriter);

  var Entry: TLogFileEntry;
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

  FProvider.FQueue.PushItem(Entry);
  FProvider.FEvent.SetEvent;
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

end.
