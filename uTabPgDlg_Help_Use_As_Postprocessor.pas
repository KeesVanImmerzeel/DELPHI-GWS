unit uTabPgDlg_Help_Use_As_Postprocessor;

interface

uses Winapi.Windows, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Forms,
  Vcl.Controls, Vcl.StdCtrls, Vcl.Buttons, Vcl.ComCtrls, Vcl.ExtCtrls,
  Vcl.Imaging.jpeg;

type
  TPagesDlgHelpUseAsPostProcessor = class(TForm)
    Panel1: TPanel;
    PageControl1: TPageControl;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    Image2: TImage;
    Memo1: TMemo;
    Image3: TImage;
    Memo2: TMemo;
    Image1: TImage;
    Memo3: TMemo;
    Image4: TImage;
    TabSheet4: TTabSheet;
    Memo4: TMemo;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  PagesDlgHelpUseAsPostProcessor: TPagesDlgHelpUseAsPostProcessor;

implementation

{$R *.dfm}

procedure TPagesDlgHelpUseAsPostProcessor.FormCreate(Sender: TObject);
begin
  Caption :=  ChangeFileExt( ExtractFileName( Application.ExeName ), '' ) +
              ': gebruik als Postprocessor in Triwaco 4.';

end;

end.

