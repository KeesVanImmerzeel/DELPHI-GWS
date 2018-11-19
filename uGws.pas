unit uGws;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls,
  Buttons, ExtCtrls, Dialogs, LargeArrays, AdoSets, OpWString, {Mask,} FileCtrl,
  uTSingleESRIgrid, uError, uTriwacoGrid, AVGRIDIO, SelectAdoSetDialog,
  jpeg, uTabstractESRIgrid, uGWSprogramSettings, uHelpUseAsAllokator,
  uTabPgDlg_Help_Use_As_Postprocessor, uPlane;

{.$Define Test}

type
  TOKBottomDlg1 = class(TForm)
    OKBtn: TButton;
    Label1: TLabel;
    EditFloFileName: TEdit;
    PHITAdoSet: TRealAdoSet;
    Label3: TLabel;
    EditSetName: TEdit;
    EditESRIgrid: TEdit;
    Label6: TLabel;
    SingleESRImvGrid: TSingleESRIgrid;
    GwsESRIgrid: TSingleESRIgrid;
    Label7: TLabel;
    EditGridFile: TEdit;
    OpenGridFileDialog: TOpenDialog;
    aTriwacoGrid: TtriwacoGrid;
    EditClsNdsFltFileName: TEdit;
    Label8: TLabel;
    SingleESRIgridclsndsflt: TSingleESRIgrid;
    Peilbuislokaties: TDbleMtrxUngPar;
    SelectRealAdoSetDialog1: TSelectRealAdoSetDialog;
    ButtonHelp4UseAsAllokator: TButton;
    Button1: TButton;
    RefGWSESRIgrid: TSingleESRIgrid;
    RG_Interpol_Options: TRadioGroup;
    RB_NON: TRadioButton;
    RB_LIN: TRadioButton;
    RB_KRI: TRadioButton;
    
    procedure OKBtnClick(Sender: TObject);
    procedure EditESRIgridClick(Sender: TObject);
    procedure EditGridFileClick(Sender: TObject);
    procedure EditClsNdsFltFileNameClick(Sender: TObject);

    procedure EditFloFileNameClick(Sender: TObject);
    procedure ButtonHelp4UseAsAllokatorClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  OKBottomDlg1: TOKBottomDlg1; MinTime, MaxTime, DecadeLength: Double;
  GwsCalculated: Boolean;
  PlaatjesDirStr, AscDir, GwsOutputGridShortName, dGwsOutputGridShortName,
  AHNgridShortName: String;
  ExactLocation: T2dPoint;
  ElNr: Integer;

implementation

{$R *.DFM}

procedure TOKBottomDlg1.OKBtnClick(Sender: TObject);
var
  f, h: TextFile;
  aValue, GHGmv, dist1, dist2, dist3, w1, w2, w3: Double;
  LineNr, iCellCount: LongWord;
  Save_Cursor:TCursor;
  PeilbuisFileNamStr, GwsCalcFileNameStr: String;
  Initiated: Boolean;
  i, iResult, j: Integer;
  nod1, nod2, nod3, MaxNod1, MaxElm, MaxCellDepth, CellDepth: integer;
  x, y, Mv : Single;

const
  cMaxDistForMvInterpolation = 100; {-Maximale afstand waarin maaiveldshoogte informatie nog bruikbaar wordt geacht}
  cMaxDistForGwLevelInterpolation = 500; {-Maximale afstand waarin berekende stijghoogte informatie nog bruikbaar wordt geacht}

begin
  GwsCalculated := false;

  if ( not FileExists( EditFloFileName.Text ) ) then begin
    if ( Mode = Interactive ) then
      MessageDlg( 'File: "' + ExpandFileName( EditFloFileName.Text ) + '" does not exist.',
                  mtError, [mbOk], 0)
    else Beep;
    Exit;
  end;

  PlaatjesDirStr := ExtractFileDir( ExpandFileName( EditFloFileName.Text ) ) + '\Plaatjes';
  if ( not DirectoryExists( PlaatjesDirStr ) ) then begin
    {$I-}
    MkDir(  PlaatjesDirStr );
    if ( IOResult <> 0 ) then
      Raise Exception.Create( 'Could not create dir [' + PlaatjesDirStr + '].' );
    {$I+}
  end;

  AscDir :=  PlaatjesDirStr  + '\ASC';
  if ( not DirectoryExists( AscDir ) ) then begin
    {$I-}
    MkDir(  AscDir );
    if ( IOResult <> 0 ) then
      Raise Exception.Create( 'Could not create dir [' + AscDir + '].' );
    {$I+}
  end;

  if ( Mode = Batch ) or ( ( Mode = Interactive ) ) then begin

    Try
      // AssignFile( lf, ExtractFileDir( ParamStr( 0 ) ) + '\Mv.log' ); Rewrite( lf );
      WriteToLogFile( 'Opening file: "' + EditFloFileName.Text + '"' );
      AssignFile( f, EditFloFileName.Text ); Reset( f );
    except
      Try {CloseFile( lf );} CloseFile( f ); except end;
//      if ( Mode = Interactive ) then
        MessageDlg( 'Error opening file "' + EditFloFileName.Text + '"' + #13 +
                        'Check "GLGGHGnap.log"', mtError, [mbOk], 0);
//      else MessageBeep( MB_ICONASTERISK );
      Exit;
    end;

    LineNr            := 0;
    Save_Cursor       := Screen.Cursor;
    Screen.Cursor     := crHourglass;    { Show hourglass cursor }

    WriteToLogFile( 'EditSetName.Text: ' + EditSetName.Text );
    Try
    Try
      Try
        PHITAdoSet := TRealAdoSet.InitFromOpenedTextFile( f, EditSetName.Text,
                           self, LineNr, Initiated );
      except
        Initiated := False;
      end;
      if Initiated then begin

        if not DirectoryExists( EditESRIgrid.Text ) then
          Raise Exception.Create( 'Directory [' + EditESRIgrid.Text + '] does not exist, so no attemt is made to initialise mv-grid.' );

        WriteToLogFile( 'Try to initialise mv grid ' + EditESRIgrid.Text );
        SingleESRImvGrid := TSingleESRIgrid.InitialiseFromESRIGridFile( EditESRIgrid.Text, iResult, self );
        if ( iResult <> cNoError ) then
          Raise Exception.Create( 'Cannot initialise mv grid ' + EditESRIgrid.Text );
        WriteToLogFile( 'mv grid [' + EditESRIgrid.Text + '] is read.' );

        WriteToLogFile( 'Initialising triwaco grid [' + EditGridFile.text + '].' );
        aTriwacoGrid := TTriwacoGrid.InitFromTextFile( EditGridFile.text, self, Initiated );
        if Initiated then
          WriteToLogFile( 'Triwaco grid [' + EditGridFile.text + '] is initialised.' )
        else
          Raise Exception.Create( 'Triwaco grid [' + EditGridFile.text + '] is NOT initialised.' );

        if RB_NON.Checked or RB_LIN.Checked then begin
          WriteToLogFile( 'Initialising ClsNdsf ESRI grid [' + EditClsNdsFltFileName.Text + '].' );
          SingleESRIgridclsndsflt := TSingleESRIgrid.InitialiseFromESRIGridFile( EditClsNdsFltFileName.Text, iResult, self );
          if ( iResult <> cNoError ) then
            Raise Exception.Create( 'Cannot initialise ClsNdsf ESRI grid ' + EditClsNdsFltFileName.Text );
          WriteToLogFile( 'ClsNdsf ESRI grid [' + EditClsNdsFltFileName.Text + '] is read.' );
        end;

        // Initialiseer GwsESRIgrid uit maaiveldhoogtegrid
        GwsESRIgrid := TSingleESRIgrid.InitialiseFromESRIGridFile( EditESRIgrid.Text, iResult, self );
        if ( iResult <> cNoError ) then
          Raise Exception.Create( 'GHGmvESRIgrid grid dataset is NOT initialised' );
        WriteToLogFile( 'GHGmvESRIgrid grid dataset is initialised' );

        iCellCount := 0;
        if RB_NON.Checked then begin

// *************** Perform Linear Interpolation *********************************

        WriteToLogFile( 'No interpolation used to find groundwaterlevels relative to surface level.' );
        with SingleESRImvGrid, aTriwacoGrid do begin
          MaxNod1 := aTriwacoGrid.NrOfNodes;
          for i:=1 to NRows do begin
                for j:=1 to NCols do begin
                  GwsESRIgrid[ i, j ] := MissingSingle;
                  Mv := GetValue( i, j );
                  if ( Mv <> MissingSingle ) then begin
                    GetCellCentre( i, j, x, y );
                   aValue := SingleESRIgridclsndsflt.GetValueXY( x, y );
                    if ( aValue <> MissingSingle ) then begin
                      Inc( iCellCount );
                      nod1 := Trunc( aValue );
                      if ( ( nod1 < 1 ) or ( nod1 > MaxNod1 ) ) then
                        GwsESRIgrid[ i, j ] := MissingSingle
                      else
                        GwsESRIgrid[ i, j ] := Mv - PHITAdoSet[ nod1 ];
                    end; {-if}
                  end; {-if}
                end; {-for j}
          end; {-for i}
        end; {-with}

        end else if RB_LIN.Checked then begin

// *************** Perform Linear Interpolation *********************************

        WriteToLogFile( 'Perform linear interpolation to find groundwater levels relative to surface level.' );
        aTriwacoGrid.PrepareForLinearInterpolationOnElements(PHITAdoSet);

        with SingleESRImvGrid, aTriwacoGrid do begin
          MaxElm := aTriwacoGrid.NrOfElements;
          for i:=1 to NRows do begin
                for j:=1 to NCols do begin
                  GwsESRIgrid[ i, j ] := MissingSingle;
                  Mv := GetValue( i, j );
                  if ( Mv <> MissingSingle ) then begin
                    GetCellCentre( i, j, x, y );
                    ExactLocation.X := x; ExactLocation.Y := y;
                    aValue := SingleESRIgridclsndsflt.GetValueXY( x, y );
                    if ( aValue <> MissingSingle ) then begin
                      Inc( iCellCount );
                      ElNr := Trunc( aValue );
                      if ( ( ElNr < 1 ) or ( ElNr > MaxElm ) ) then
                        GwsESRIgrid[ i, j ] := MissingSingle
                      else GwsESRIgrid[ i, j ] :=
                        Mv - aTriwacoGrid.GetInterpolatedValue( ElNr, ExactLocation );
                    end; {-if}
                  end; {-if}
                end; {-for j}
          end; {-for i}
        end; {-with}

        end;
// *************** Perform Kriging Interpolation *********************************
// NOT YET IMPLEMENTED

        WriteToLogFile( 'Nr of Mv cells found: ' + IntToStr( iCellCount  ) );
        GwsESRIgrid.SaveAs( PlaatjesDirStr + '\' + GwsOutputGridShortName );
        GwsESRIgrid.ExportToASC( AscDir + '\' + GwsOutputGridShortName + '.asc' );
        WriteToLogFileFMT( 'Arc/View binary grid [%s] is created in folder [%s]', [GwsOutputGridShortName, ExpandFileName( PlaatjesDirStr ) ] );
        MessageDlg( Format( 'Arc/View binary grid [%s] is created in folder [%s]', [GwsOutputGridShortName, ExpandFileName( PlaatjesDirStr ) ] ), mtInformation, [mbOk], 0);
        GwsCalculated := True;

        {-Probeer op peilbuislokaties de berekende GWS weg te schrijven naar tekstfile}
        PeilbuisFileNamStr := ExtractFileDir( EditGridFile.text ) + '\Peilbuislokaties.ung' ;
        if not fileExists( PeilbuisFileNamStr ) then
          Raise Exception.CreateFmt( 'File met peilbuislokaties [%s] bestaat niet,' + #13 +
                                     'dus er zijn geen grondwaterstanden op peilbuislokaties berekend.', [PeilbuisFileNamStr] );
        Peilbuislokaties := TDbleMtrxUngPar.InitialiseFromTextFile( PeilbuisFileNamStr,self );

        GwsCalcFileNameStr := PlaatjesDirStr + '\' + GwsOutputGridShortName + '_' + JustName( ExtractFileDir( ExpandFileName( EditFloFileName.Text ) ) ) + '.txt';

        AssignFile( h, GwsCalcFileNameStr ); Rewrite( h );
        Writeln( h, '"ID","PbName","X","Y","GWSmvCalc"' ); {-Header}
        with Peilbuislokaties, SingleESRImvGrid, aTriwacoGrid do begin
          for i:=1 to GetNRows do begin
                x := Getx( i ); y := Gety( i ); {-x, y van peilbuislokatie}
                Write( h, GetID( i ), ',"' + GetUngParName( i ) + '",',x:8:1,',',y:8:1,',' );
                GHGmv := -9999;
                MaxCellDepth := Trunc( cMaxDistForMvInterpolation / CellSize ); {-Zoek mv hoogte op maximaal 100 m afstand}
                GetValueNearXY( x, y, MaxCellDepth, CellDepth, Mv );
                if ( Mv <> MissingSingle ) then begin  {-Maaiveldshoogte gevonden}
                  GetClosest3Nodes( x, y, nod1, nod2, nod3, dist1, dist2, dist3 );
                  if ( dist1 < cMaxDistForGwLevelInterpolation ) then begin
                    Get3WeightsForIDWInterpolation( dist1, dist2, dist3, w1, w2, w3 );
                    GHGmv := Mv - ( w1 * PHITAdoSet[ nod1 ] + w2 * PHITAdoSet[ nod2 ] + w3 * PHITAdoSet[ nod3 ] );
                  end;
                end; {-if}
                Writeln( h, GHGmv:8:2 );
          end; {-for i}
        end; {-with}
        CloseFile( h );
        MessageDlg( 'Grondwaterstanden op peilbuislokaties weggeschreven in ['+
          ExpandFileName( GwsCalcFileNameStr ) + '].',mtInformation, [mbOk], 0);
        {CloseFile( lf );} CloseFile( f );

      end; {-If initiated}
    except
      On E: Exception do begin
            HandleError( E.Message, True );
            {MessageBeep( MB_ICONASTERISK );}
      end;
    end; {-except}
    finally
      Screen.Cursor := Save_Cursor;
    end; {-finaly}
  end; {-if}
end;

procedure TOKBottomDlg1.EditESRIgridClick(Sender: TObject);
var
  Directory: string;
begin
  Directory := GetCurrentDir;
  if SelectDirectory( Directory,  [], 0 ) then begin
    EditESRIgrid.Text := ExpandFileName( Directory );
  end;
end;

procedure TOKBottomDlg1.EditGridFileClick(Sender: TObject);
begin
  with OpenGridFileDialog do begin
    If execute then begin
      EditGridFile.Text := ExpandFileName( FileName );
    end;
  end;
end;

procedure TOKBottomDlg1.FormCreate(Sender: TObject);
begin
  InitialiseLogFile;
  Caption :=  ChangeFileExt( ExtractFileName( Application.ExeName ), '' );
end;

procedure TOKBottomDlg1.FormDestroy(Sender: TObject);
begin
FinaliseLogFile;
end;

procedure TOKBottomDlg1.Button1Click(Sender: TObject);
begin
  //FormHelpUseAsPostProcessor.ShowModal;
  PagesDlgHelpUseAsPostProcessor.ShowModal;
end;

procedure TOKBottomDlg1.ButtonHelp4UseAsAllokatorClick(Sender: TObject);
begin
  FormHelp4UseAsAllokator.ShowModal;
end;

procedure TOKBottomDlg1.EditClsNdsFltFileNameClick(Sender: TObject);
var
  Directory: string;
begin
  Directory := GetCurrentDir;
  if SelectDirectory( Directory,  [], 0 ) then begin
    EditClsNdsFltFileName.Text := ExpandFileName( Directory );
  end;
end;

procedure TOKBottomDlg1.EditFloFileNameClick(Sender: TObject);
var
  SetNames: TStringList;
begin
  SetNames :=  TStringList.Create;
  if SelectRealAdoSetDialog1.execute( 1, true, Setnames ) then begin
    EditSetName.Text := SetNames.Strings[ 0];
    EditFloFileName.Text :=  ExpandFileName( SelectRealAdoSetDialog1.FileName );
  end;
end;

initialization
//  DecimalSeparator := '.';
  FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';
  Mode := interactive;
  InitialiseGridIO;
finalization
end.
