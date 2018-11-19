unit uHelpUseAsAllokator;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Imaging.jpeg, Vcl.ExtCtrls;

type
  TFormHelp4UseAsAllokator = class(TForm)
    Image1: TImage;
    Image2: TImage;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormHelp4UseAsAllokator: TFormHelp4UseAsAllokator;

implementation

{$R *.dfm}

procedure TFormHelp4UseAsAllokator.FormCreate(Sender: TObject);
begin
  Caption :=  ChangeFileExt( ExtractFileName( Application.ExeName ), '' ) +
              ': gebruik als allokator in Triwaco 4.';
end;

end.
