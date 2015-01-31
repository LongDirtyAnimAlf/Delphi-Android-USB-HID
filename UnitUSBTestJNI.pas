unit UnitUSBTestJNI;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Layouts, FMX.Memo, FMX.StdCtrls, FMX.Grid,
  usb2, System.Rtti;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    btnHIDCreate: TButton;
    btnHIDEnable: TButton;
    btnGetSerial: TButton;
    btnInfo: TButton;
    procedure btnHIDCreateClick(Sender: TObject);
    procedure btnHIDEnableClick(Sender: TObject);
    procedure btnGetSerialClick(Sender: TObject);
    procedure btnInfoClick(Sender: TObject);
  private
    { Private declarations }
    NewUSB:TUSB;
    procedure UpdateUSBDevice(Sender: TObject;datacarrier:integer);
  public
  end;

var
  Form1: TForm1;

implementation

uses
  StrUtils,
  System.IOUtils,
  Androidapi.JNI.Toast;

{$R *.fmx}

const
  Numtypes=2;
  Numsamples=7;

{Form1}

procedure TForm1.btnInfoClick(Sender: TObject);
var
  S:string;
begin
  S:=NewUSB.Info;
  if Length(S)>0 then
  begin
    Memo1.Lines.Append('INFO:');
    Memo1.Lines.Append(S);
  end else Memo1.Lines.Append('No new USB info.');
end;

procedure TForm1.btnHIDCreateClick(Sender: TObject);
var
  S:string;
begin
  TButton(Sender).Enabled:=False;
  Memo1.Lines.Append('HID Created.');
  NewUSB:=TUSB.Create;
  NewUSB.OnUSBDeviceChange:=UpdateUSBDevice;
  Memo1.Lines.Append('Ready.');
  S:=NewUSB.Info;
  if Length(S)>0 then
  begin
    Memo1.Lines.Append('INFO:');
    Memo1.Lines.Append(S);
  end;
  S:=NewUSB.Errors;
  if Length(S)>0 then
  begin
    Memo1.Lines.Append('ERRORS:');
    Memo1.Lines.Append(S);
  end;
  btnHIDEnable.Enabled:=True;
  btnInfo.Enabled:=True;
end;

procedure TForm1.btnHIDEnableClick(Sender: TObject);
var
  S:string;
begin
  TButton(Sender).Enabled:=False;
  Memo1.Lines.Append('HID Enabled.');
  NewUSB.Enabled:=True;
  Memo1.Lines.Append('Ready.');
  S:=NewUSB.Info;
  if Length(S)>0 then
  begin
    Memo1.Lines.Append('INFO:');
    Memo1.Lines.Append(S);
  end;
  S:=NewUSB.Errors;
  if Length(S)>0 then
  begin
    Memo1.Lines.Append('ERRORS:');
    Memo1.Lines.Append(S);
  end;
  btnGetSerial.Enabled:=True;
end;

procedure TForm1.btnGetSerialClick(Sender: TObject);
var
  S:string;
begin
  Memo1.Lines.Append('Get HID serial:');
  Memo1.Lines.Append(NewUSB.GetSerial[0]);
  Memo1.Lines.Append('Ready.');
  S:=NewUSB.Info;
  if Length(S)>0 then
  begin
    Memo1.Lines.Append('INFO:');
    Memo1.Lines.Append(S);
  end;
  S:=NewUSB.Errors;
  if Length(S)>0 then
  begin
    Memo1.Lines.Append('ERRORS:');
    Memo1.Lines.Append(S);
  end;
end;


procedure TForm1.UpdateUSBDevice(Sender: TObject;datacarrier:integer);
var
  S:string;
begin
  Memo1.Lines.Append('Measuremain board: '+InttoStr(datacarrier));
  S:=NewUSB.Info;
  if Length(S)>0 then
  begin
    Memo1.Lines.Append('INFO:');
    Memo1.Lines.Append(S);
  end;
  S:=NewUSB.Errors;
  if Length(S)>0 then
  begin
    Memo1.Lines.Append('ERRORS:');
    Memo1.Lines.Append(S);
  end;
end;

end.
