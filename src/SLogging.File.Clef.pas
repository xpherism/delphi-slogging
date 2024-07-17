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
  Writer.WriteLine(Entry.ToClef, FileName, FileNameFormatter, Encoding);
  Result := True;
end;

end.
