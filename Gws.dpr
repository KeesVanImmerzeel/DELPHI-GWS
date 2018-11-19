program Gws;

{-Opm.: bij gebruik vanuit trishell: als de 'Description' de tekst RP1 bevat
  dan wordt de 'GLG/GHG' berekend van een tijdsafhankelijke RP1 dataset
  (t.b.v. bepalen drainageweerstanden.

  KVI 170106  }

uses
  Forms,
  USelectGLGGHGnap in 'USelectGLGGHGnap.pas' {OKBottomDlg},
  uGws in 'uGws.pas' {OKBottomDlg1},
  IniFiles,
  OpWString,
  Dutils,
  SysUtils,
  Dialogs,
  windows,
  Controls,
  uError,
  System.UITypes,
  uTTrishellDataSet,
  AVGRIDIO,
  uTAbstractESRIgrid,
  uTSingleESRIgrid,
  uGWSprogramSettings in 'uGWSprogramSettings.pas',
  uHelpUseAsAllokator in 'uHelpUseAsAllokator.pas' {FormHelp4UseAsAllokator},
  uTabPgDlg_Help_Use_As_Postprocessor in 'uTabPgDlg_Help_Use_As_Postprocessor.pas' {PagesDlgHelpUseAsPostProcessor},
  USelectAdoSetDialog in '..\..\ServiceComponents\Triwaco\AdoSets\SelectAdoSetDialog\USelectAdoSetDialog.pas' {AdoSetsForm};

var
  f_ini: TiniFile;
  RunDirStr, cfgFileStr, ExpressionStr, DefaultStr, DescriptionStr,
  ResultFileStr, MapFileStr, ResultSetStr, MvGridStr,
  TriwacoGridfileStr, ClsNdsFltFileStr, S, ParamStr1, PathNameOfBaseDataSet,
  SetStr, AllocatorOptionsStr: String;
  iError, i, j: Integer;
  TrishellDataSetType: TTrishellDataSetType;
Const
  WordDelims: CharSet = ['.'];

{$R *.RES}

Function GetSetNameFromDescriptionString( const DescriptionStr: String ): String;
var Len: Integer;
const
  WordDelims = ['#'];
begin
  Result := ExtractWord( 2,  DescriptionStr, WordDelims, Len );
  if ( Len = 0 ) then
    Result := '';
end;

begin
  Application.Initialize;
  Application.NormalizeTopMosts;

  InitialiseGridIO;

  Application.CreateForm(TOKBottomDlg1, OKBottomDlg1);
  Application.CreateForm(TOKBottomDlg, OKBottomDlg);
  Application.CreateForm(TFormHelp4UseAsAllokator, FormHelp4UseAsAllokator);
  Application.CreateForm(TPagesDlgHelpUseAsPostProcessor, PagesDlgHelpUseAsPostProcessor);
  Application.CreateForm(TAdoSetsForm, AdoSetsForm);
  GwsOutputGridShortName := fini.ReadString( 'Settings', 'GwsOutputGridShortName', 'Gws'  );
  dGwsOutputGridShortName := 'd' + GwsOutputGridShortName;
  WriteToLogFile( 'GwsOutputGridShortName = ' + GwsOutputGridShortName );
  AHNgridShortName := fini.ReadString( 'Settings', 'AHNgridShortName', 'AHN'  );
  WriteToLogFile( 'AHNgridShortName = ' + AHNgridShortName );

  Mode := Interactive;

  if ( ParamCount >= 3 ) then begin //Use as allokator
    Mode := Batch;
    RunDirStr   := ParamStr( 1 );
    cfgFileStr  := RunDirStr + '\' + ParamStr( 3 );
    f_ini := TiniFile.Create( cfgFileStr );
    AllocatorOptionsStr := Uppercase( f_ini.ReadString( 'Allocator', 'options', 'NON' ) );
    if (AllocatorOptionsStr <> 'NON') and (AllocatorOptionsStr <> 'LIN') and
      (AllocatorOptionsStr <> 'KRI') then
      AllocatorOptionsStr := 'NON';
    WriteToLogFileFMT( 'Allocator Option = %S', [AllocatorOptionsStr] );
    MapFileStr     := f_ini.ReadString( 'Allocator', 'datasource', 'Error' ); {-Triwaco 4, vector dataset specified}
    if ( MapFileStr = 'Error' ) then begin
      MapFileStr     := f_ini.ReadString( 'Allocator', 'mapfile', 'Error' );  {-Triwaco 3}
      ExpressionStr  := f_ini.ReadString( 'Allocator', 'expression', 'Error' );
      MvGridStr := '';          {-geen GxG output ESRII grids gemaakt}
      TriwacoGridfileStr := '';
      ClsNdsFltFileStr := '';
    end else begin {-Triwaco 4}
//      ExpressionStr  := f_ini.ReadString( 'Allocator', 'options', 'Error' );
      MvGridStr :=  f_ini.ReadString( 'Allocator', 'idfield', 'Error' );
      TriwacoGridfileStr := f_ini.ReadString( 'Allocator', 'gridfile', 'Error' );
      ClsNdsFltFileStr := ExtractFileDir(  TriwacoGridfileStr );
      if AllocatorOptionsStr='NON' then begin
        ClsNdsFltFileStr := ClsNdsFltFileStr  + '\clsndsf';  // ESRII grid with node numbers in influence area's
        OKBottomDlg1.RB_NON.Checked := True;
      end else if AllocatorOptionsStr='LIN' then begin
        ClsNdsFltFileStr := ClsNdsFltFileStr  + '\clselmsf'; // ESRII grid with element numbers
        OKBottomDlg1.RB_LIN.Checked := True;
      end else begin
        ClsNdsFltFileStr := ClsNdsFltFileStr  + '\factors.bin'; //Kriging factors
        OKBottomDlg1.RB_KRI.Checked := True;
      end;
    end;

    DefaultStr     := f_ini.ReadString( 'Allocator', 'default', 'Error' );
    ResultFileStr  := f_ini.ReadString( 'Allocator', 'resultfile', 'Error' );
    ResultSetStr   := f_ini.ReadString( 'Allocator', 'setname', 'Error' );
    SetStr := f_ini.ReadString( 'Allocator', 'layer', 'Error' );

    GwsOutputGridShortName := ResultSetStr;
    dGwsOutputGridShortName := 'd' + ResultSetStr;

    DescriptionStr := f_ini.ReadString( 'Allocator', 'description', 'Error' );
    f_ini.Free;
    with OKBottomDlg1 do begin
      EditFloFileName.Text       := Trim( MapFileStr ); // 'Allocator', 'datasource'
      EditESRIgrid.Text          := Trim( MvGridStr ); //  'Allocator', 'idfield'
      EditGridFile.Text          := Trim( TriwacoGridfileStr ); // 'Allocator', 'gridfile'
      EditClsNdsFltFileName.Text := Trim( ClsNdsFltFileStr );  // Uit: 'Allocator', 'gridfile'
      EditSetName.Text  := Trim( SetStr ); // 'Allocator', 'layer'
      // Remark: radiobuttons concerning interpolation options are already set.
      SetCurrentDir( ExtractFileDir( ResultFileStr ) );  // 'Allocator', 'resultfile'
      Try
      Except
        if ( Mode = Interactive ) then begin
          MessageDlg( 'Invalid input value(s): values replaced by defaults', mtWarning, [mbOk], 0);
        end else begin
          Beep( 300, 500 );
          Exit;
        end;
      end;
    end; {-with OKBottomDlg1}
    if pos( 'DEBUG', Uppercase( DescriptionStr ) ) <> 0 then
      Mode := Interactive;
  end else if (ParamCount = 1) then begin  //Use as Post processor?
    Mode := Unknown;
    ParamStr1 := ExpandFileName( ParamStr( 1 ) );
    if Tri4_IsTrishellModelIniFile( ParamStr1 ) then begin
      WriteToLogFileFMT( 'Model.ini-file specified: [%s]', [ParamStr1] ) ;
      Try
        Try
          TrishellDataSetType := ReadTrishellDataSetType( ParamStr1, iError );
          if not ( ( TrishellDataSetType = Calibration ) or ( TrishellDataSetType = Scenario ) ) then
            raise Exception.Create('Model.ini is not of type "Calibration" or "Scenario". ');

          with OKBottomDlg1 do begin
            EditFloFileName.Text := ExtractFilePath( ParamStr1 ) + 'flairs.flo';
            WriteToLogFileFMT( 'Flo-file = [%s].', [ EditFloFileName.Text ] );

            S := Tri4_ReadFullPathNameOfGridFileName( ParamStr1, iError );
            if ( iError <> cNoError ) then
              raise Exception.CreateFmt( 'Could not read Triwaco Grid Filename from file [%s]', [ParamStr1] );
            EditGridFile.Text := S;
            WriteToLogFileFMT( 'Triwaco grid-file = [%s]', [EditGridFile.Text] );

            S := ExtractFilePath(  EditGridFile.Text );

            // Other interpolation then 'NON' options are not yet made available
            // when called by post processor.
            RB_NON.Checked := True;
            EditClsNdsFltFileName.Text := S + 'ClsNdsf';
            if not IsArcViewBinaryGrid( EditClsNdsFltFileName.Text ) then
              raise Exception.CreateFmt('[%s] Does not exist (or is not an ArcViewBinaryGrid).', [EditClsNdsFltFileName.Text] );
            WriteToLogFileFMT( 'Binary Arc/View grid (ClsNdsF) used = [%s]', [EditClsNdsFltFileName.Text] );

            // Probeer het AHN grid te vinden in dezelfde folder als waar "model.ini" staat
            S := ExtractFilePath( ParamStr1 );
            EditESRIgrid.Text := S + AHNgridShortName;
            if IsArcViewBinaryGrid( EditESRIgrid.Text ) then
              WriteToLogFileFMT( 'AHN = [%s]', [EditESRIgrid.Text] )
            else begin
              // Probeer het AHN grid te vinden in dezelfde folder als waar het Triwaco-grid bestand staat
              S := ExtractFilePath(  EditGridFile.Text );
              EditESRIgrid.Text := S + AHNgridShortName;
              if IsArcViewBinaryGrid( EditESRIgrid.Text ) then
                WriteToLogFileFMT( 'AHN = [%s]', [EditESRIgrid.Text] )
              else begin
                raise Exception.Create('No AHN specified so gws not calculated.' );
                WriteToLogFile( 'Geen AHN gespecificeerd, dus gws niet berekend.' );
              end;
            end;

            SetCurrentDir( ExtractFileDir ( ParamStr1 ) );

            Mode := Batch;
            OKBtn.Click;  {-bereken gws}
            Mode := Unknown;

          end; {-with OKBottomDlg1}

          if ( not GwsCalculated ) then
            raise Exception.Create('Gws could not be calculated so dGws also cannot be calculated.');
          // Kijk of dGws kan worden uitegerekend
          PathNameOfBaseDataSet := Tri4_ReadFullPathNameOfBaseDataSet( ParamStr1, iError );
          if ( iError <> cNoError ) or ( not DirectoryExists( PathNameOfBaseDataSet ) ) then
            Exception.CreateFmt( 'Base Dataset [%s] cannot be determined of does not exist so [%s] cannot be calculated.', [PathNameOfBaseDataSet, dGwsOutputGridShortName] );
          TrishellDataSetType := ReadTrishellDataSetType( ParamStr1, iError );
          if ( iError <> cNoError ) or not ( ( TrishellDataSetType = Calibration ) or ( TrishellDataSetType = Scenario ) ) then
            raise Exception.CreateFmt('Base dataset is not of type "Calibration" or "Scenario" so [%s] cannot be calculated. ', [dGwsOutputGridShortName]);
          S :=  PathNameOfBaseDataSet + '\Plaatjes\' + GwsOutputGridShortName;
          with OKBottomDlg1 do begin
            RefGWSESRIgrid := TSingleESRIgrid.InitialiseFromESRIGridFile( S, iError, OKBottomDlg1 );
            if iError <> cNoError then
              raise Exception.CreateFmt( 'Cannot initialise RefGWSESRIgrid [%s] so [%s] cannot be calculated.', [S, dGwsOutputGridShortName] );
            if ( RefGWSESRIgrid.NRows <> GWSESRIgrid.NRows ) or
               ( RefGWSESRIgrid.NCols <> GWSESRIgrid.NCols ) then
              raise Exception.CreateFmt('NRows/NCols in RefGWSESRIgrid differs from GWSESRIgrid so [%s] cannot be calculated.', [dGwsOutputGridShortName]);
            // Bereken dGws
            for i:=1 to GWSESRIgrid.NRows do begin
              for j := 1 to GWSESRIgrid.NCols do begin
                GWSESRIgrid[ i, j ] := RefGWSESRIgrid[ i, j ] - GWSESRIgrid[ i, j ];
              end;
            end;
            GWSESRIgrid.SaveAs( PlaatjesDirStr + '\' + dGwsOutputGridShortName );
            GwsESRIgrid.ExportToASC( AscDir + '\' + dGwsOutputGridShortName + '.asc' );
            MessageDlg( Format( 'Arc/View binary [%s] grid is created in folder [%s]', [dGwsOutputGridShortName, ExpandFileName( PlaatjesDirStr )] ), mtInformation, [mbOk], 0);
          end;
          // Mode := Batch;
        Except
          On E: Exception do begin
            HandleError( E.Message, True );
            Mode := Unknown;
          end;
        end;
      Finally

      End;
    end; {-if 'model.ini' specified als ParamStr( 1 )}
  end;

  if ( Mode = Interactive ) then begin
    Application.Run;
  end else if (Mode = Batch) then begin
    OKBottomDlg1.OKBtn.Click;
  end else begin
    // MessageDlg( Format( 'Application [%s] is not used.', [ParamStr(0)] ), mtInformation, [mbOk], 0, mbOk);
  end;
  Application.RestoreTopMosts;

end.
