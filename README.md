NOTE! This repository has moved to https://codeberg.org/xpherism/delphi-slogging

# delphi-slogging (WIP)
Delphi structured logging framework inspired by .NET logging framework.

Features include

- Message Templates
- Scopes
- Static and dynamic properties (enrichment)

Compiled and tested using Delphi 10.4.2

Planned
 - Add test cases
 - Windows Events Log LoggerProvider
 - Freepascal support

## About message template arguments

In the currently implementation variants are used, as they are the only on that preserve type information for `TDateTime`.
Both open arrays and array of `TValue` (RTTI any value holder) loses `TDateTime` type information and are degraded to a `double`. We need `TDateTime` type information to be able properly format datetime value automatically.
using `class operator Implicit` we could handle implicit conversions.

For more information see https://learn.microsoft.com/en-us/dotnet/core/extensions/logging?tabs=command-line#log-message-template

## Documentation

`Variants` are used for parameter passing, as they preserve type information for TDateTime, which TValue does not (it handles them as a double, and we lose type information).

When creating a new logger
```pascal
LoggerFactory.CreateLogger<TBackendService>
LoggerFactory.CreateLogger('MyCategory')
```
an `ILogger` instance is returned.

Loggers for each provider and category are cached and reused. Scopes are provider global and thus exists across different logger category instanses for a given provider.

```pascal
  ILogger = interface
    function IsEnabled(const LogLevel: TLogLevel): boolean;

    procedure BeginScope(const Properties: TArray<TPair<string, variant>>);
    procedure EndScope;

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
```

### EventId

EventId is implemented as record which can be implicit assigned from an Integer.

```pascal
var Id: TEventId := 12;
```

EventId is a concept from Windows event log, and will used when eventlog support is implemented.

Use helper function `EventId(Id: Integer; Name: String)` to create a named EventId.

### Output formats

Current plain text and clef (json) format is supported for both console and file output

#### plain text

Console output format:
```
info TBackendUserController[0]
     Backend started
```

file output format:
```
2023-04-10T05:41:51.942867700Z INFO  TBackendUserController[0] Backend started
```

#### CLEF (json)

See https://clef-json.org/ for more details.

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
.AddProvider<TClefFileLoggerProvider>(
    procedure (Provider: TJsonFileLoggerProvider) begin
    Provider.MinLevel := TLogLevel.Trace;
    Provider.MaxQueueTime := 1000; // milliseconds
    Provider.MinQueueSize := 8;
    Provider.IncludeScopes := True;
    Provider.FileName := 'yyyymmdd".clef"';
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
logger.BeginScope([P('UserName', UserName)]);
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

Note that the `FileNameFormatter` callback use used for each log entry and will impact performance (ie. don't do database or any other heave calculation or io heavy lookups. Mostly used for rolling file names). The same is true for dynamic properties.

```pascal
WithProperty(Proc: TProc<TDictionary<string, variant>>)
```

Non JSON loggers don't output properties or scopes.
