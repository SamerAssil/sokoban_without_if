program sokoban;

{$R *.dres}

uses
  System.Math,
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  skblib in 'skblib.pas';

{$R *.res}

begin
  SetExceptionMask(GetExceptionMask - [exZeroDivide]);
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
