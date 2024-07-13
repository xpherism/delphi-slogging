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
  ILogQueueWorker<T> = interface
    function HandleDequeue(const [ref] Entry: T): Boolean;
  end;

  ELogQueueFullException = class(Exception);

  {$SCOPEDENUMS ON}
  TLogQueueFullAction = (
    Error,   // raise exception
    Ignore,  // ignore new entries
    Discard  // discard old entries
  );
  {$SCOPEDENUMS OFF}

  TLogQueue<T> = class
  private
    FLock: TObject;
    FQueue: TQueue<T>;
    FEvent: TEvent;
    FTask: ITask;
    FMinQueueSize: Integer;
    FMaxQueueSize: Integer;
    FMaxQueueTime: Integer;
    FWorker: ILogQueueWorker<T>;
    FOnWorkerError: TProc<Exception>;
    FWhenQueueFull: TLogQueueFullAction;
    procedure EnsureWorker;
    procedure HandleWorkerError(Exc: Exception); inline;
    procedure SetMinQueueSize(Value: Integer);
    procedure SetMaxQueueSize(Value: Integer);
  public
    constructor Create(Worker: ILogQueueWorker<T>);
    destructor Destroy; override;
    procedure Close;

    procedure Enqueue(const [ref] Entry: T);

    property MaxQueueTime: Integer read FMaxQueueTime write FMaxQueueTime; // max. queue wait time in milliseconds before flushing
    property MinQueueSize: Integer read FMinQueueSize write SetMinQueueSize; // min. number of entries before flushing
    property MaxQueueSize: Integer read FMaxQueueSize write SetMaxQueueSize; // max. number entries to contain (< 1 mean infinite queue length)
    property WhenQueueFull: TLogQueueFullAction read FWhenQueueFull write FWhenQueueFull;

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
  FMaxQueueSize := 1024;
  FWhenQueueFull := TLogQueueFullAction.Discard;
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
    if (FMaxQueueSize > 0) and (FQueue.Count >= FMaxQueueSize) then
      case FWhenQueueFull of
        TLogQueueFullAction.Error: raise ELogQueueFullException.Create('Queue full');
        TLogQueueFullAction.Ignore: Exit;
        TLogQueueFullAction.Discard: FQueue.Dequeue;
      end;
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
            case FEvent.WaitFor(FMaxQueueTime) of
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
                // A queue is FIFO ordered and we only use one worker.
                // This means we can peek the first entry without locking
                // and remove it only if handled by worker; which will require
                // locking due to TQueue using array as a circular buffer
                // for implementation and will need to update pointers and
                // reallocate if it needs to grow.
                var Entry := FQueue.Peek;

                if FWorker.HandleDequeue(Entry) then
                begin
                  TMonitor.Enter(FLock);
                  try
                    FQueue.Dequeue;
                  finally
                    TMonitor.Exit(FLock);
                  end;
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

procedure TLogQueue<T>.SetMinQueueSize(Value: Integer);
begin
  if (FMaxQueueSize >= 0) and (Value >= FMaxQueueSize) then
    raise EArgumentOutOfRangeException.Create('MinQueueSize must be smaller than MaxQueueSize');

  FMinQueueSize := Value;
end;

procedure TLogQueue<T>.SetMaxQueueSize(Value: Integer);
begin
  if (Value < FMinQueueSize) then
    raise EArgumentOutOfRangeException.Create('MinQueueSize must be smaller than MaxQueueSize');

  FMaxQueueSize := Value;
end;


end.
