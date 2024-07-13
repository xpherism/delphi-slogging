unit SLogging.&File.Clef;

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
  SLogging.Utils.Json,
  SLogging.Utils.Queue,
  SLogging.&File;

{$B-} // Enable boolean short-circuit code generation by the compiler

const
  ClefLogLevelNames : array [TLogLevel.Trace..TLogLevel.None] of string = ('Verbose','Debug','Information','Warning','Error','Fatal','None');

type
  {* CLEF File Logger *}

  TClefFileLoggerProvider = class;

  TClefFileLoggerProvider = class(TFileLoggerProvider)
  protected
    function HandleDequeue(const [ref] Entry: TLogEntry): Boolean; override;
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

type
  TFileLoggerProviderAccess = class(TFileLoggerProvider);

{ TClefFileLoggerProvider }

function TClefFileLoggerProvider.HandleDequeue(const [ref] Entry: TLogEntry): Boolean;
begin
  var SR := TStringStream.Create;
  var JB := TJsonTextWriter.Create(TStreamWriter.Create(SR), True);
  try
    JB.WriteStartObject;

    JB.WritePropertyName('@t');
    JB.WriteValue(Entry.Timestamp.FormatISO8601);

    if Entry.LogLevel <> TLogLevel.Information then
    begin
      JB.WritePropertyName('@l');
      JB.WriteValue(ClefLogLevelNames[entry.LogLevel]);
    end;

    if Entry.Exception.Message <> '' then
    begin
      JB.WritePropertyName('@x');
      JB.WriteValue(Entry.Exception.Message+sLineBreak+Entry.Exception.StackTrace);
    end;

    JB.WritePropertyName('SourceContext');
    JB.WriteValue(Entry.Category);

    if Entry.EventId.Id > 0 then
    begin
      JB.WritePropertyName('@i');
      JB.WriteValue(Entry.EventId.Id);
    end;

    JB.WritePropertyName('@mt');
    JB.WriteValue(Entry.MessageTemplate);

    if Length(Entry.Renderings) > 0 then
    begin
      JB.WritePropertyName('@r');
      JB.WriteStartArray;
      for var val in Entry.Renderings do
        JB.WriteValue(val);
      JB.WriteEndArray;
    end;

    for var item in Entry.Properties do
    begin
      JB.WritePropertyName(item.Key);
      JB.WriteVariant(item.Value);
    end;

    JB.WriteEndObject;
    JB.Flush;

    Writer.WriteLine(SR.DataString, FileName, FileNameFormatter, Encoding);
  finally
    JB.Free;
    SR.Free;
  end;

  Result := True;
end;

end.
