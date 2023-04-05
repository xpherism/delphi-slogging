# delphi-slogging
Delphi structured logging framework inspired by .NET logging framework.

Features includede

- Message Templates
- Scopes
- Static and dynamic properties (enrichment)

## Example

The following examples output informations level or more severe to stdout in plain text format and outputs detailed logging in JSON format everything to time based log file.

ProcessId is added as an extra static property.

```pascal
LoggerFactory
.AddProvider<TConsoleLoggerProvider>(
    procedure (Provider: TConsoleLoggerProvider) begin
        Provider.MinLevel := TLogLevel.Information;
    end
)
.AddProvider<TJsonFileLoggerProvider>(
    procedure (Provider: TJsonFileLoggerProvider) begin
    Provider.MinLevel := TLogLevel.Trace;
    Provider.MaxQueueTime := 1000; // milliseconds
    Provider.MinQueueSize := 8;
    Provider.IncludeScopes := True;
    Provider.FileName := 'yyyymmdd".log"';
    Provider.FileNameFormatter :=
        function(FileName: string): string
        begin
            Result := FormatDateTime(FileName, Now);
        end;
    end
)
.WithProperty('processId', GetProcessIdOfThread(MainThreadID))
.WithProperty(
    procedure(props: TDictionary<string, variant>)
    begin
        props.AddOrSetValue('correlationId', ExtractCollectionIdFromEnv);
    end
);

var logger := LoggerFactory.CreateLogger<TBackendUserController>;
logger.LogInformation('Backend started', []);
...
logger.BeginScope('Processing user {User} request', [UserName]);
try
    logger.LogTrace('checking authorization...', []);
    try
        some_exiting_db_checkup;
    except on E: Exception do
        logger.LogError(E, 'Unknown error', [])
    end;
    if not user_authorized then
        logger.LogWarning('Unorthorized login attempt from {ip}', [get_user_ip_addr]);
    else
        logger.LogInformation('User authorized :-)', []);
finally
    logger.EndScope;
end;
...
logger.LogInformation('Backend stopped', []);
```

All logging is handled synchronously, and any implementation of loggers should be fast enough to not be a performance bottle neck. Any logger write to possible slow IO, should use a queue to buffer messages, and handle those async. fx. See TFileLogger for example.

Note that the `FileNameFormatter` callback use used for each log entry and will impact performance (ie. don't database or any other heave calculation or lookups). The same is true for dynamic properties 

```pascal
WithProperty(Proc: TProc<TDictionary<string, variant>>)
```

Non JSON loggers don't output properties or scopes.