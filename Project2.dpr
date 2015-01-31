program Project2;

uses
  //System.SysUtils,
  System.StartUpCopy,
  FMX.Forms,
  UnitUSBTestJNI in 'UnitUSBTestJNI.pas' {Form1},
  android.hardware.usb.UsbDeviceConnection in '.\AndroidUSBHeaders\android.hardware.usb.UsbDeviceConnection.pas',
  android.hardware.usb.UsbEndpoint in '.\AndroidUSBHeaders\android.hardware.usb.UsbEndpoint.pas',
  android.hardware.usb.UsbManager in '.\AndroidUSBHeaders\android.hardware.usb.UsbManager.pas',
  android.hardware.usb.UsbDevice in '.\AndroidUSBHeaders\android.hardware.usb.UsbDevice.pas',
  android.hardware.usb.UsbInterface in '.\AndroidUSBHeaders\android.hardware.usb.UsbInterface.pas',
  android.hardware.usb.UsbConstants in '.\AndroidUSBHeaders\android.hardware.usb.UsbConstants.pas',
  android.app.PendingIntent in '.\AndroidHeaders\android.app.PendingIntent.pas',
  Androidapi.JNI.Toast in '.\AndroidHeaders\Androidapi.JNI.Toast.pas',
  USB2 in 'USB2.pas',
  android.hardware.usb.HID in 'android.hardware.usb.HID.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
  //FreeAndNil(Application);
end.
