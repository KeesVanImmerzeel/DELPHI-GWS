unit uGWSprogramSettings;

interface

uses
  SysUtils, IniFiles, Forms, Dutils, uError;


Type
  TMode = ( Batch, Interactive, Unknown );

var
  fini : TiniFile;
  LogFileName, IniFileName, InitialCurrentDir, ApplicationFileName: TFileName;
  Mode: TMode;
  ynWriteToLogFile: Boolean;

implementation

initialization
  InitialCurrentDir   := GetCurrentDir;
  LogFileName         := ChangeFileExt( Application.ExeName, '.log' );
  IniFileName         := ChangeFileExt( Application.ExeName, '.ini' );
  Mode                := Interactive;
  with FormatSettings do begin {-Delphi XE6}
    DecimalSeparator    := '.';
  end;
  Application.ShowHint := True;
  fini := TIniFile.Create( IniFileName );
  ynWriteToLogFile := True;
  WriteToLogFileFmt( DateTimeToStr(Now) + ': ' + 'Starting application: [%s].', [Application.ExeName] ) ;
finalization
  WriteToLogFileFmt( DateTimeToStr(Now) + ': ' +'Closing application: [%s].', [Application.ExeName] );
  fini.Free;
  SetCurrentDir( InitialCurrentDir );
end.
