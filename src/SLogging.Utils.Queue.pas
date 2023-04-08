unit SLogging.Utils.Queue;

interface

uses
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.Generics.Collections,
  System.Variants,
  System.SysUtils,
  SLogging;

{$B-} // Enable boolean short-circuit code generation by the compiler

type
  // this record is used for a final snapshot of an entire log entry
  TLogEntry = record
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
  end;

  ILogQueueWorker<T> = interface
    function HandleDequeue(const [ref] Entry: T): Boolean;
  end;

  TLogQueue<T> = class
  private
    FLock: TObject;
    FQueue: TQueue<T>;
    FEvent: TEvent;
    FTask: ITask;
    FMinQueueSize: Integer;
    FMaxQueueTime: Integer;
    FWorker: ILogQueueWorker<T>;
    FOnWorkerError: TProc<Exception>;
    procedure EnsureWorker;
    procedure HandleWorkerError(Exc: Exception); inline;
  public
    constructor Create(Worker: ILogQueueWorker<T>);
    destructor Destroy; override;
    procedure Close;

    procedure Enqueue(const [ref] Entry: T);

    property MinQueueSize: Integer read FMinQueueSize write FMinQueueSize;
    property MaxQueueTime: Integer read FMaxQueueTime write FMaxQueueTime; // milliseconds
    property OnWorkerError: TProc<Exception> read FOnWorkerError write FOnWorkerError;
  end;

implementation

uses
  System.DateUtils;

{ TLogQueue<T> }

constructor TLogQueue<T>.Create(Worker: ILogQueueWorker<T>);
begin
  if Worker = nil then
    raise EArgumentNilException.Create('Worker cannot be nil');

  FWorker := Worker;
  FMinQueueSize := 8;
  FMaxQueueTime := 1000;
  FLock := TObject.Create;
  FQueue := TQueue<T>.Create;
  FEvent := TEvent.Create;
  FEvent.ResetEvent;
  FTask := nil;
end;

destructor TLogQueue<T>.Destroy;
begin
  FTask.Cancel;
  while FTask <> nil do
    CheckSynchronize(1000);

  FQueue.Clear;
  FreeAndNil(FEvent);
  FreeAndNil(FQueue);
  FreeAndNil(FLock);
end;

procedure TLogQueue<T>.Close;
begin
  if FTask <> nil then
    FTask.Cancel;
end;

procedure TLogQueue<T>.Enqueue(const [ref] Entry: T);
begin
  EnsureWorker;

  TMonitor.Enter(FLock);
  try
    FQueue.Enqueue(Entry);
  finally
    TMonitor.Exit(FLock);
  end;
  FEvent.SetEvent;
end;

procedure TLogQueue<T>.EnsureWorker;
begin
  if FTask <> nil then
    Exit;

  FTask := TTask.Create(
    procedure
    begin
      try
        var LastWriteTs := Now;
        repeat
          try
            case FEvent.WaitFor(100) of
              wrTimeout:
                ;
              wrAbandoned:
                break;
              wrError:
                RaiseLastOSError;
              wrSignaled:
                FEvent.ResetEvent;
            end;

            // if max queue time or min queue size is reached the flush queue
            // if task has been canceled the also flush to empty queue before exiting.
            if (MilliSecondsBetween(Now, LastWriteTs) >= FMaxQueueTime) or (FQueue.Count >= FMinQueueSize) or (FTask.Status = TTaskStatus.Canceled) then
              while FQueue.Count > 0 do
              begin
                // How to best handle writer errors? how many retries to dequeue? should we throw away log messages?
                TMonitor.Enter(FLock);
                try
                  if FWorker.HandleDequeue(FQueue.Peek) then
                    FQueue.Dequeue;
                finally
                  TMonitor.Exit(FLock);
                end;
                LastWriteTs := Now;
              end;

          except on E: Exception do
            HandleWorkerError(E);
          end;
        until FTask.Status = TTaskStatus.Canceled;
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

procedure TLogQueue<T>.HandleWorkerError(Exc: Exception);
begin
  if Assigned(FOnWorkerError) then
    FOnWorkerError(Exc);
end;

end.
