unit USelectGLGGHGnap;

  {-Berekenen van GLG- en -GHG (m+NAP) op basis van:
    - een reeks gws-gegevens van 1 of meer peilbuizen. Per regel wordt verwacht:
      Day Month Year Gws [ Day Month Year Gws ] [..]
      Deze uitvoer wordt overigens aangemaakt door het programma DawaExp.
      Er wordt 1 uitvoerbestand gemaakt met de kolommen:
      GLG GHG GEM Count [ GLG GHG GEM Count ] [..]
      In het 'log'-bestand 'GLGGHGnap.log' zijn tevens de waarden per jaar
      opgenomen.
      Bij de optie 'Prn-file' worden alleen grondwaterstanden < 999 worden
      verwerkt; waarden >=999 worden als 'novalue' beschouwd.
      Alleen de waarnemingen waarvoor geldt: MinJaar <= Time <= MaxJaar
      worden gebruikt. MinJaar en MaxJaar hebben betrekking op HYDROLOGISCHE
      jaren. Als bijvoorbeeld MinJaar=1990 dan worden gegevens gebruikt vanaf
      1 april 1990. Als MaxJaar=1990 dan worden gegevens gebruikt tot en met
      31 maart 1991!
      Invoerbestand moet het hele jaartal bevatten, dus niet 80 maar 1980.
    - of: ado-sets.

    Er wordt gewerkt met het HYDROLOGISCH jaar het gemiddelde van de
    3 laagste en de drie hoogste waarnemingen. Een hydrologische jaar
    loopt van 1 april t/m 31 maart.

    De uitvoer van GLGGHGnap kan worden gebruikt voor het bepalen van de Gt
    met het programma'CalcGt'. Bij het werken met ado-sets is dan eerst een
    conversie nodig naar m-mv (via Trishell). Met prn-files kan de conversie
    binnen het programma'CalcGt' worden uitgevoerd. Wel moet dan een bestand
    met maaiveldshoogten worden gespecificeerd.
    }


interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls,
  Buttons, ExtCtrls, Dialogs, {uCalcGt,} LargeArrays, DUtils, uMinMaxJaar,
  OpWString;

const
  cGLGYear = 1; cGVGYear = 2; cGHGYear = 3; cAvYear = 4; cNrValuesInYear = 5;
  cDay     = 1; cCurrentMonth = 2; cCurrentYear = 3; cGws = 4;

type
  TOKBottomDlg = class(TForm)
    FloBtn: TButton;
    PrnBtn: TButton;
    Bevel1: TBevel;
    Label1: TLabel;
    OpenDialogPrnFile: TOpenDialog;
    DoubleMatrixGWSreeksen: TDoubleMatrix;
    SaveDialogGLGGHG: TSaveDialog;
    ResultDoubleMatrix: TDoubleMatrix;
    CompactResultDoubleMatrix: TDoubleMatrix;
    procedure PrnBtnClick(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  OKBottomDlg: TOKBottomDlg;

implementation

uses uShowResults;

{$R *.DFM}

procedure TOKBottomDlg.PrnBtnClick(Sender: TObject);
const
  NoValue = 999;
var
  lf, f: TextFile;
  PRNfileStr, GLGGHGFileStr: String;
  i, j, AantalPeilbuizen, NrOfYears, MaxTime, MinTime: Integer;
  buf: TStringList;

  Function ReadInfoFromDINOfile( var f: TextFile; var buf: TStringList ): Boolean;
  var
    Found: Boolean;
    Regel: String;
    Len: Integer;
    Stijghoogte: Double;
    Datum: TDateTime;
  Const
    WordDelims : CharSet = [','];
  begin
    Result := False;
    {Vind start van waarnemingen}
    Repeat
      Readln( f, Regel );
      Found := Pos( 'Locatie', Regel ) <> 0;
    until ( EOF( f ) or Found );
    if Found then begin
      Repeat
        Readln( f, Regel );
        Found := Pos( 'Locatie', Regel ) <> 0;
      until ( EOF( f ) or Found );
    end else begin
      Exit;
    end;

    Repeat
      Readln( f, Regel );
      Try
        Datum := StrToDate( ExtractWord( 3, Regel,  WordDelims, Len ) );
        Stijghoogte := StrToFloat( ExtractWord( 6, Regel,  WordDelims, Len ) );
        Stijghoogte := Stijghoogte / 100;
        Regel :=  FormatDateTime('dd mm yyyy', Datum ) + ' ' + FloatToStrF( Stijghoogte,  ffNumber, 10, 2 );
        Writeln( lf, Regel );
        buf.Append( Regel );
      except

      end;
    until ( EOF( f ) );
    Result := true;
  end;

  Procedure CopyBuf( var Buf: TStringList; var DoubleMatrixGWSreeksen: TDoubleMatrix );
  var
    i, Len: Integer;
  Const
    WordDelims : CharSet = [' '];
  begin
    for i:=1 to buf.count do begin
      DoubleMatrixGWSreeksen[ i, 1 ] :=  StrToFloat( ExtractWord( 1,  buf[ i-1 ],  WordDelims, Len ) );
      DoubleMatrixGWSreeksen[ i, 2 ] :=  StrToFloat( ExtractWord( 2,  buf[ i-1 ],  WordDelims, Len ) );
      DoubleMatrixGWSreeksen[ i, 3 ] :=  StrToFloat( ExtractWord( 3,  buf[ i-1 ],  WordDelims, Len ) );
      DoubleMatrixGWSreeksen[ i, 4 ] :=  StrToFloat( ExtractWord( 4,  buf[ i-1 ],  WordDelims, Len ) );
    end;
  end;

  Procedure Undo;
  begin
    Try
      CloseFile( lf ); CloseFile( f );
      DoubleMatrixGWSreeksen.Free;  ResultDoubleMatrix.Free;
    Except
    end;
  end;

  Procedure ProcessPeilbuis( const PeilbuisNr: Integer );
  var
    GLGCount, GVGCount, TotalNrValues, i, n, m, Day, CurrentMonth, CurrentYear,
    NrValuesInYear, BeginMonth, BeginYear: Integer;
    GLG, GHG, Gws, AvGws, AvYear, GVG,
    Min1Year, Min2Year, Min3Year, Max1Year, Max2Year, Max3Year, GVGyear: Double;
    ValidDataFound: Boolean;

    Function CurrentTimeIsSelected: Boolean;
    begin
      CurrentTimeIsSelected := true;
      if   ( CurrentYear < MinTime ) or
         ( ( CurrentYear = MinTime ) and ( CurrentMonth <= 3 ) ) or
           ( CurrentYear > ( MaxTime + 1 ) ) or
         ( ( CurrentYear = ( MaxTime + 1 ) ) and ( CurrentMonth >= 4 ) ) then
      CurrentTimeIsSelected := False;
    end; {-Function CurrentTimeIsSelected}

    Function IsVoorjaar: Boolean;
    begin
      Result := ( ( CurrentMonth = 3 ) and ( Day > 25 ) ) or ( ( CurrentMonth = 4 ) and ( Day < 5 ) );
    end;

    Procedure ResetYearValues;
    begin
      NrValuesInYear := 1; AvYear := Gws;
      Min1Year := Gws; Min2Year := Gws; Min3Year := Gws; Max1Year := Gws; Max2Year := Gws; Max3Year := Gws;
      BeginMonth := CurrentMonth;
      BeginYear := CurrentYear;
      if ( BeginMonth <= 3 ) then Dec( BeginYear );
      {Writeln( lf, 'NrValuesInYear, Gws, AvYear: ', NrValuesInYear, ' ', Gws:8:2, ' ', AvYear:8:2 );}
      if IsVoorjaar then begin
        GVGyear := Gws;
      end else begin
        GVGyear := NoValue;
      end;
    end;

    Function NewYear: Boolean;
    begin
      NewYear := ( ( CurrentYear > BeginYear ) and ( CurrentMonth > 3 ) ) or
         ( ( CurrentYear = BeginYear ) and ( BeginMonth <= 3 ) and ( CurrentMonth > 4 ) );
    end; {-Function NewYear}

    Procedure ProcessYear;
    begin
      Inc( NrValuesInYear );
      AvYear := AvYear + Gws;
      {Writeln( lf, 'NrValuesInYear, Gws, AvYear: ', NrValuesInYear, ' ', Gws:8:2, ' ', AvYear:8:2 );}
      if ( Gws < Min1Year ) then begin
        Min3Year := Min2Year; Min2Year := Min1Year; Min1Year := Gws;
      end else if ( Gws < Min2Year ) then begin
        Min3Year := Min2Year; Min2Year := Gws;
      end else if ( Gws < Min3Year ) then begin
        Min3Year := Gws;
      end;
      if ( Gws > Max1Year ) then begin
        Max3Year := Max2Year; Max2Year := Max1Year; Max1Year := Gws;
      end else if ( Gws > Max2Year ) then begin
        Max3Year := Max2Year; Max2Year := Gws;
      end else if ( Gws > Max3Year ) then begin
        Max3Year := Gws;
      end;
      if IsVoorjaar then begin
        GVGyear := Gws;
      end;
    end; {-Procedure ProcessYear;}

    Procedure ProcessYearResults;
    var
      i: Integer;
      GLGYear, GHGYear: Double;
    begin
      if ( NrValuesInYear >= 1 ) then begin
        AvYear  := AvYear / NrValuesInYear;
        GHGYear := Max1Year ;       GLGYear := Min1Year;       i := 1;
        GHG     := GHG + Max1Year;  GLG     := GLG + Min1Year; Inc( GLGCount );
        if ( NrValuesInYear >= 2 ) then begin
          Inc( i );
          GHGYear := GHGYear + Max2Year ; GLGYear := GLGYear + Min2Year;
          GHG := GHG + Max2Year; GLG := GLG + Min2Year; Inc( GLGCount );
        end;
        if ( NrValuesInYear >= 3 ) then begin
          Inc( i );
          GHGYear := GHGYear + Max3Year ; GLGYear := GLGYear + Min3Year;
          GHG := GHG + Max3Year; GLG := GLG + Min2Year; Inc( GLGCount );
        end;
        GHGYear := GHGYear / i; GLGYear := GLGYear / i;
        if GVGyear <> NoValue then begin
          GVG := GVG + GVGYear; Inc( GVGCount );
        end;

        ResultDoubleMatrix[ BeginYear-MinTime+1, (PeilbuisNr-1)*5+cGLGYear ]        := GLGYear;
        ResultDoubleMatrix[ BeginYear-MinTime+1, (PeilbuisNr-1)*5+cGVGYear ]        := GVGyear;
        ResultDoubleMatrix[ BeginYear-MinTime+1, (PeilbuisNr-1)*5+cGHGYear ]        := GHGYear;
        ResultDoubleMatrix[ BeginYear-MinTime+1, (PeilbuisNr-1)*5+cAvYear ]         := AvYear;
        ResultDoubleMatrix[ BeginYear-MinTime+1, (PeilbuisNr-1)*5+cNrValuesInYear ] := NrValuesInYear;

        Writeln( lf, 'Result peilbuis ', PeilbuisNr, ', jaar ', CurrentYear-1, '-', CurrentYear, '.' );
        Writeln( lf, 'GLG, GVG, GHG, AvYear, NrValuesInYear: ', GLGYear:8:2, ' ', GVGYear:8:2, ' ', GHGYear:8:2, ' ', AvYear:8:2, ' ', NrValuesInYear );
      end; {-if ( NrValuesInYear >= 1 )}
    end; {-Procedure ProcessYearResults}

  begin
    Writeln( lf, 'Verwerk peilbuis: ', PeilbuisNr );

    GLGCount := 0; TotalNrValues:= 0; GLG := 0; GHG := 0; AvGws := 0; GVGCount := 0; GVG := 0;
    n := DoubleMatrixGWSreeksen.GetNRows;
    ValidDataFound := False;
    for i:=1 to n do begin
      Day          := Trunc( DoubleMatrixGWSreeksen[ i, (PeilbuisNr-1)*4+cDay ] );
      CurrentMonth := Trunc( DoubleMatrixGWSreeksen[ i, (PeilbuisNr-1)*4+cCurrentMonth ] );
      CurrentYear  := Trunc( DoubleMatrixGWSreeksen[ i, (PeilbuisNr-1)*4+cCurrentYear ] );
      Gws          := DoubleMatrixGWSreeksen[ i, (PeilbuisNr-1)*4+cGws ];
      if CurrentTimeIsSelected and ( Gws < NoValue ) then begin

        Inc( TotalNrValues );
        AvGws := AvGws + Gws;
        if ( not ValidDataFound ) then begin {-Eerste gegeven: initialiseer}
          ValidDataFound := True;
          ResetYearValues;
          Writeln( lf, Day, ' ', CurrentMonth, ' ', CurrentYear, ' ', Gws:8:2 );
        end else begin {-Niet eerste gegeven}
          if ( not NewYear ) then begin {-GEEN nieuw hydrologisch jaar}
            Writeln( lf, Day, ' ', CurrentMonth, ' ', CurrentYear, ' ', Gws:8:2 );
            ProcessYear;
          end else begin {-Nieuw hydrologisch jaar}
            ProcessYearResults;
            ResetYearValues;
            Writeln( lf, Day, ' ', CurrentMonth, ' ', CurrentYear, ' ', Gws:8:2 );
          end;
        end; {-if ValidDataFound}

      end; {-if CurrentTimeIsSelected}
    end; {-for}

    if ValidDataFound then begin {-Er zijn gegevens gevonden}
      ProcessYearResults; {-Verwerk de laatste gegevens}
      m := ResultDoubleMatrix.GetNRows;
      {-Schrijf eindresultaat}
      if ( GLGCount > 0 ) then begin
        GLG := GLG / GLGCount; GHG := GHG / GLGCount; AvGws := AvGws / TotalNrValues;
        ResultDoubleMatrix[ m, (PeilbuisNr-1)*5+cGLGYear ]        := GLG;
        ResultDoubleMatrix[ m, (PeilbuisNr-1)*5+cGHGYear ]        := GHG;
        ResultDoubleMatrix[ m, (PeilbuisNr-1)*5+cNrValuesInYear ] := GLGCount;
        ResultDoubleMatrix[ m, (PeilbuisNr-1)*5+cAvYear ]         := AvGws;
        CompactResultDoubleMatrix[ PeilbuisNr, 1 ] := GLG;
        CompactResultDoubleMatrix[ PeilbuisNr, 3 ] := GHG;
        CompactResultDoubleMatrix[ PeilbuisNr, 4 ] := AvGws;
        CompactResultDoubleMatrix[ PeilbuisNr, 5 ] := GLGCount;
        CompactResultDoubleMatrix[ PeilbuisNr, 6 ] := GVGCount;
      end; {-if ( GLGCount > 0 )}
      if ( GVGCount > 0 ) then begin
        GVG := GVG / GVGCount;
        ResultDoubleMatrix[ m, (PeilbuisNr-1)*5+cGVGYear ]  := GVG;
        CompactResultDoubleMatrix[ PeilbuisNr, 2 ] := GVG;
      end;
    end; {-if ValidDataFound}

  end; {-Procedure ProcessPeilbuis}


begin
  {MessageDlg( 'IN okbottomdlg', mtInformation, [mbOk], 0);}
  with OpenDialogPrnFile do begin
    if execute then begin
      AssignFile( lf, 'GLGGHGnap.log' ); Rewrite( lf );

      PRNfileStr := ExpandFileName( FileName );

      Try
        AssignFile( f, PRNfileStr ); Reset( f );
      Except
        raise Exception.Create( 'Error initialising prn-file: "' + PRNfileStr + '".' );
        Undo; Exit;
      end;

      if ( UpperCase( ExtractFileExt( FileName ) ) = '.CSV' ) then begin  {-dino gegevens}
        buf := TStringList.Create;
        if ReadInfoFromDINOfile( f, buf ) then begin
          DoubleMatrixGWSreeksen := TDoubleMatrix.Create( buf.count, 4, self );
          CopyBuf( Buf, DoubleMatrixGWSreeksen );
        end;
        Buf.Free;
      end else begin
        DoubleMatrixGWSreeksen := TDoubleMatrix.InitialiseFromTextFile( f, self );
      end;
      CloseFile( f );

      with DoubleMatrixGWSreeksen do begin
        if ( GetNCols < 4 ) or ( GetNRows <= 0 ) then begin
          raise Exception.Create( 'Unable to read contents of prn file.' );
          Undo; Exit;
        end;
        with SaveDialogGLGGHG do begin
          FileName := ChangeFileExt( OpenDialogPrnFile.FileName, '.out' );
          if execute then begin

            GLGGHGFileStr := ExpandFileName( FileName );
            Try
              AssignFile( f, GLGGHGFileStr ); Rewrite( f );
            Except
              raise Exception.Create( 'Error initialising result prn-file: "' + GLGGHGFileStr + '".' );
              Undo; Exit;
            end;

            AantalPeilbuizen   := GetNCols div 4;

            with OKBottomDlg2 do begin
              ShowModal;
              Try
                MinTime := StrToInt( EditMinJaar.Text );
                NrOfYears := StrToInt( EditAantalJaren.Text );
              except
                raise Exception.Create( 'Ongeldige min/max waarden.' );
                Undo; Exit;
              end;
            end;

            MaxTime := MinTime + NrOfYears;
            ResultDoubleMatrix        := TDoubleMatrix.CreateF( NrOfYears+1, AantalPeilbuizen * 5, NoValue, self );
            CompactResultDoubleMatrix := TDoubleMatrix.CreateF( AantalPeilbuizen, 6 , NoValue, self );
            for j:=1 to AantalPeilbuizen do
              for i:=1 to NrOfYears+1 do
                ResultDoubleMatrix[ i, (j-1)*4+cNrValuesInYear ] := 0;


            for i:=1 to AantalPeilbuizen do
              ProcessPeilbuis( i );

            ResultDoubleMatrix.WriteToTextFile( lf, ' ' );
            CompactResultDoubleMatrix.WriteToTextFile( f, ' ' );
            CloseFile( f );

            with OKDialogResults do begin
              Caption := 'GLG GVG GHG & GEM of [' + GLGGHGFileStr + ']';
              MemoResults.Clear;
              MemoResults.Lines.LoadFromFile( GLGGHGFileStr );
              ShowModal;
            end;

            {MessageDlg( IntToStr( AantalPeilbuizen ) + ' GLG/GHG''s written to file', mtInformation, [mbOk], 0);}

          end; {-if execute}
        end; {-with SaveDialogGLGGHG}
      end; {with DoubleMatrixGWSreeksen}

      Undo;
    end; {-if execute}
  end; {-with OpenDialogPrnFile}

end;



end.
