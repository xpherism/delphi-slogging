# delphi-slogging (WIP)
Delphi structured logging framework inspired by .NET logging framework.

Features include

- Message Templates
- Scopes
- Static and dynamic properties (enrichment)

Compiled and tested using Delphi 10.4.2

TODO Add test cases

## Documentation

[ILogger](https://github.com/xpherism/delphi-slogging/blob/677e8c77e2bf7556281baf3685c10b09bb296ede/src/SLogging.pas#L126-L162)

[LoggerFactory](https://github.com/xpherism/delphi-slogging/blob/677e8c77e2bf7556281baf3685c10b09bb296ede/src/SLogging.pas#L213-L243)

[ConsoleLogger](https://github.com/xpherism/delphi-slogging/blob/677e8c77e2bf7556281baf3685c10b09bb296ede/src/SLogging.pas#L213-L243)

[JsonConsoleLogger](https://github.com/xpherism/delphi-slogging/blob/677e8c77e2bf7556281baf3685c10b09bb296ede/src/SLogging.Console.Json.pas#L34-L53)

[FileLogger](https://github.com/xpherism/delphi-slogging/blob/677e8c77e2bf7556281baf3685c10b09bb296ede/src/SLogging.File.pas#L45-L87)

[JsonFileLogger](https://github.com/xpherism/delphi-slogging/blob/677e8c77e2bf7556281baf3685c10b09bb296ede/src/SLogging.File.Json.pas#L38-L53)

### Output formats

Console output format:
```
info TBackendUserController[0]
     Backend started
```

file output format:
```
2023-04-10T05:41:51.942867700Z INFO  TBackendUserController[0] Backend started
```

JSON output format: (All JSON log entries single line (ie. JSON-L). Shown formatted below for readability.
```json
{
    "timestamp": "2023-04-10T05:59:58.771026200Z",
    "logLevel": "error",
    "category": "System.TObject",
    "eventId": {
        "id": 1,
        "name": ""
    },
    "exception": {
        "message": "Access violation at address 005F2452 in module 'sloggingdev.exe'. Read of address 0000000C",
        "stackTrace": "005f2452 sloggingdev.exe sloggingdev 119 initialization\r\n005f255e sloggingdev.exe sloggingdev 125 initialization\r\n005f25af sloggingdev.exe sloggingdev 132 initialization\r\n005f25ce sloggingdev.exe sloggingdev 132 initialization\r\n005f25ed sloggingdev.exe sloggingdev 132 initialization\r\n005f260c sloggingdev.exe sloggingdev 132 initialization\r\n005f272a sloggingdev.exe sloggingdev 136 initialization\r\n756000f7 KERNEL32.DLL                    BaseThreadInitThunk"
    },
    "message": "Something went wrong: Access violation at address 005F2452 in module 'sloggingdev.exe'. Read of address 0000000C",
    "messageTemplate": "Something went wrong: Access violation at address 005F2452 in module 'sloggingdev.exe'. Read of address 0000000C",
    "properties": {
        "processId": 0,
        "currentUserId": 222
    },
    "scopes": [
        {
            "MessageTemplate": "Processing item #{Item}",
            "Message": "Processing item #12",
            "Category": "System.TObject",
            "Properties": {
                "Item": 12
            }
        }
    ]
}
```

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
        logger.LogWarning('Unauthorized login attempt from {ip}', [get_user_ip_addr]);
    else
        logger.LogInformation('User authorized :-)', []);
finally
    logger.EndScope;
end;
...
logger.LogInformation('Backend stopped', []);
```

All logging is handled synchronously, and any ILoggerImplementor implementation must handle any async queing or buffering manuelly, see TFileLogger for an example.

Note that the `FileNameFormatter` callback use used for each log entry and will impact performance (ie. don't database or any other heave calculation or lookups). The same is true for dynamic properties 

```pascal
WithProperty(Proc: TProc<TDictionary<string, variant>>)
```

Non JSON loggers don't output properties or scopes.
