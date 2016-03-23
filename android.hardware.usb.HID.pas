unit android.hardware.usb.HID;

interface

{.$define WITHPERMISSION}

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Generics.Collections,

  Androidapi.JNI.Toast,

  android.hardware.usb.UsbDeviceConnection,
  android.hardware.usb.UsbEndpoint,
  android.hardware.usb.UsbManager,
  android.hardware.usb.UsbDevice,
  android.hardware.usb.UsbInterface,
  Androidapi.JNI.App,
  Androidapi.JNIBridge,
  Androidapi.JNI.JavaTypes,
  Androidapi.JNI.Embarcadero,
  Androidapi.JNI.GraphicsContentViewText
  ;

type
  TJvHidDeviceController = class;
  TJvHidDevice = class;

  TBroadcastReceiverListener = class(TJavaLocal, JFMXBroadcastReceiverListener)
  private
    FHidDC:TJvHidDeviceController;
  public
    constructor Create(aOwner:TJvHidDeviceController);
    procedure onReceive(context: JContext; intent: JIntent); cdecl;
    property HidDC:TJvHidDeviceController read FHidDC;
  end;


  TJvHidPnPInfo = class(TObject)
  private
    FUSBDevice:JUSBDevice;
    FDeviceID: DWORD;
    FFriendlyName: string;
    FProductId: DWORD;
    FVendorId: DWORD;
    FDeviceClass: DWORD;
    FDeviceProtocol: DWORD;
    FDeviceSubclass: DWORD;
  public
    property DeviceID: DWORD read FDeviceID write FDeviceID;
    property FriendlyName: string read FFriendlyName;
    constructor Create(ADevice:JUSBDevice);
    destructor Destroy; override;
  end;


  TJvHidDeviceReadThread = class(TThread)
  private
    procedure DoData;
    procedure DoDataError;
    constructor CtlCreate(const aDevice: TJvHidDevice);
  protected
    procedure Execute; override;
  public
    Device:TJvHidDevice;
    NumBytesRead: word;
    Report: array of Byte;
    constructor Create(CreateSuspended: Boolean);
  end;

  TJvHidPlugEvent = procedure(HidDev: TJvHidDevice) of object;
  TJvHidUnplugEvent = TJvHidPlugEvent;

  TJvHidDataEvent = procedure(HidDev: TJvHidDevice; ReportID: Byte;
    const Data: Pointer; Size: Word) of object;

  TJvHidDataErrorEvent = procedure(HidDev: TJvHidDevice; Error: DWORD) of object;
  TJvHidDeviceCreateError = procedure(Controller: TJvHidDeviceController; PnPInfo: TJvHidPnPInfo; var Handled: Boolean; var RetryCreate: Boolean) of object;


  // check out test function
  TJvHidCheckCallback = function(HidDev: TJvHidDevice): Boolean; stdcall;

  THIDPCAPS = record
    InputReportByteLength:     Word;
    OutputReportByteLength:    Word;
    FeatureReportByteLength:   Word;
  end;

  THIDDAttributes = record
    VendorID:      Word;
    ProductID:     Word;
    VersionNumber: Word;
  end;

  TJvHidDevice = class(TObject)
  private
    FMyController: TJvHidDeviceController;

    FUsbDevice : JUSBDevice;
    FUsbDeviceConnection : JUSBDeviceConnection;
    FUsbInterface : JUSBInterface;
    FEpOut,FEpIn : JUSBEndPoint;

    FIsPluggedIn: Boolean;
    FIsCheckedOut: Boolean;
    FIsEnumerated: Boolean;
    FData: TJvHidDataEvent;
    FUnplug: TJvHidUnplugEvent;
    FDataThread: TJvHidDeviceReadThread;
    fCaps:THIDPCaps;
    FAttributes: THIDDAttributes;
    FPnPInfo: TJvHidPnPInfo;
    FVendorName: String;
    FProductName: String;
    FSerialNumber: String;
    FLanguageStrings : TStringList;
    FThreadSleepTime: Integer;
    FDebugInfo : TStringList;
    function GetCaps: THIDPCaps;
    function GetAttributes: boolean;
    function GetVendorName: String;
    function GetProductName: String;
    function GetSerialNumber: String;
    function GetDeviceString(Idx: Byte): string;
    function GetFeatureReport: string;
    procedure SetDataEvent(const DataEvent: TJvHidDataEvent);
    procedure SetThreadSleepTime(const SleepTime: Integer);
    procedure StartThread;
    procedure StopThread;
    constructor CtlCreate(const APnPInfo: TJvHidPnPInfo; const LocalController: TJvHidDeviceController);
  protected
    // internal event implementor
    procedure DoUnplug;
  public
    // dummy constructor
    constructor Create;
    destructor Destroy; override;
    function OpenFile:boolean;
    procedure CloseFile;
    procedure FlushQueue;
    function ReadFile(var Report; ToRead: DWord; var BytesRead: DWord): Boolean;
    function WriteFile(var Report; ToWrite: Dword; var BytesWritten: DWord): Boolean;
    function CheckOut: Boolean;
    property Caps: THIDPCaps read GetCaps;
    //property Attributes: THIDDAttributes read GetAttributes;
    property Attributes: THIDDAttributes read FAttributes;
    property IsCheckedOut: Boolean read FIsCheckedOut;
    property IsPluggedIn: Boolean read FIsPluggedIn;
    property PnPInfo: TJvHidPnPInfo read FPnPInfo;
    property VendorName: String read GetVendorName;
    property ProductName: String read GetProductName;
    property SerialNumber: String read GetSerialNumber;
    property ThreadSleepTime: Integer read FThreadSleepTime write SetThreadSleepTime;
    property DeviceStrings[Idx: Byte]: string read GetDeviceString;
    property Connection:JUSBDeviceConnection read FUsbDeviceConnection;
    property EpIn:JUSBEndPoint read FEpIn;
    property EpOut:JUSBEndPoint read FEpOut;
    property OnData: TJvHidDataEvent read FData write SetDataEvent;
    property OnUnplug: TJvHidUnplugEvent read FUnplug write FUnplug;
  end;

  //THidDevList = TObjectList<TJvHidDevice>;
  THidDevList = TList<TJvHidDevice>;
  //THidDevList = TList;

  TJvHidDeviceController = class(TComponent)
  private
    FArrivalEvent: TJvHidPlugEvent;
    FDeviceChangeEvent: TNotifyEvent;
    FDevUnplugEvent: TJvHidUnplugEvent;
    FRemovalEvent: TJvHidUnplugEvent;
    FOnDeviceCreateError: TJvHidDeviceCreateError;
    FDevThreadSleepTime: Integer;
    FContinue: Boolean;
    FRunning: Boolean;
    FEnabled: Boolean;
    FUsbManager : JUSBManager;
    FBroadcastReceiverListener: JFMXBroadcastReceiverListener;
    FReceiver: JFMXBroadcastReceiver;
    {$ifdef WITHPERMISSION}
    FPermissionIntent : JPendingIntent;
    {$endif}
    FDevDataEvent: TJvHidDataEvent;
    FList:THidDevList;
    FNumCheckedInDevices: Integer;
    FNumCheckedOutDevices: Integer;
    FNumUnpluggedDevices: Integer;
    FInDeviceChange: Boolean;
    function  CheckThisOut(var HidDev: TJvHidDevice; Idx: Integer; Check: Boolean): Boolean;
    procedure SetEnabled(Value: Boolean);
    procedure SetDevThreadSleepTime(const DevTime: Integer);
    procedure SetDevData(const DataEvent: TJvHidDataEvent);
    procedure SetDeviceChangeEvent(const Notifier: TNotifyEvent);
    procedure SetDevUnplug(const Unplugger: TJvHidUnplugEvent);
  protected
    procedure DoArrival(HidDev: TJvHidDevice);
    procedure DoRemoval(HidDev: TJvHidDevice);
    procedure DoDeviceChange;
    //procedure StartControllerThread;
    //procedure StopControllerThread;
    property  Continue: Boolean read FContinue write FContinue;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
    procedure CheckIn(var HidDev: TJvHidDevice);
    function  CheckOut(var HidDev: TJvHidDevice): Boolean;
    function  CheckOutByID(var HidDev: TJvHidDevice; const Vid, Pid: Integer): Boolean;
    function  CheckOutByIndex(var HidDev: TJvHidDevice; const Idx: Integer): Boolean;
    function  CheckOutByProductName(var HidDev: TJvHidDevice; const ProductName: String): Boolean;
    function  CheckOutByVendorName(var HidDev: TJvHidDevice; const VendorName: String): Boolean;
    function  CheckOutByCallback(var HidDev: TJvHidDevice; Check: TJvHidCheckCallback): Boolean;
    // methods to count HID device objects
    function  CountByID(const Vid, Pid: Integer): Integer;
    function  CountByProductName(const ProductName: String): Integer;
    function  CountByVendorName(const VendorName: String): Integer;
    function  CountByCallback(Check: TJvHidCheckCallback): Integer;
    //property    DebugInfo: String read GetDebugInfo write SetDebugInfo;
    property  HidDevices:THidDevList read FList;
    property  NumCheckedInDevices: Integer read FNumCheckedInDevices;
    property  NumCheckedOutDevices: Integer read FNumCheckedOutDevices;
    property  NumUnpluggedDevices: Integer read FNumUnpluggedDevices;
    property  USBManager:JUSBManager read FUSBManager;
    {$ifdef WITHPERMISSION}
    property  PermissionIntent: JPendingIntent read FPermissionIntent;
    {$endif}
    property  InDeviceChange: Boolean read FInDeviceChange write FInDeviceChange;
  published
    property  Enabled: Boolean read FEnabled write SetEnabled;
    property  DevThreadSleepTime: Integer read FDevThreadSleepTime write SetDevThreadSleepTime default 100;
    property  OnDeviceData: TJvHidDataEvent read FDevDataEvent write SetDevData;
    property  OnArrival: TJvHidPlugEvent read FArrivalEvent write FArrivalEvent;
    property  OnDeviceChange: TNotifyEvent read FDeviceChangeEvent write SetDeviceChangeEvent;
    property  OnDeviceCreateError: TJvHidDeviceCreateError read FOnDeviceCreateError write FOnDeviceCreateError;
    property  OnDeviceUnplug: TJvHidUnplugEvent read FDevUnplugEvent write SetDevUnplug;
    property  OnRemoval: TJvHidUnplugEvent read FRemovalEvent write FRemovalEvent;
    procedure DeviceChange;
  end;

implementation

uses
  FMX.Platform.Android,
  android.hardware.usb.UsbConstants,
  Androidapi.JNI,
  Androidapi.Helpers;

type
  EControllerError = class(Exception);
  EHidClientError = class(Exception);

resourcestring
  RsEDirectThreadCreationNotAllowed = 'Direct creation of a TJvDeviceReadThread object is not allowed';
  RsEDirectHidDeviceCreationNotAllowed = 'Direct creation of a TJvHidDevice object is not allowed';
  RsEDeviceCannotBeIdentified = 'Device cannot be identified';
  RsEDeviceCannotBeOpened = 'Device cannot be opened';
  RsEOnlyOneControllerPerProgram = 'Only one TJvHidDeviceController allowed per program';

const
  ACTION_USB_PERMISSION='com.android.example.USB_PERMISSION';
  USBTIMEOUT = 250;

function translateDeviceClass(deviceClass:integer):string;
begin
  case deviceClass of
    TJUsbConstantsUSB_CLASS_APP_SPEC:result:='Application specific USB class';
    TJUsbConstantsUSB_CLASS_AUDIO:result:='USB class for audio devices';
    TJUsbConstantsUSB_CLASS_CDC_DATA:result:='USB class for CDC devices (communications device class)';
    TJUsbConstantsUSB_CLASS_COMM: result:='USB class for communication devices';
    TJUsbConstantsUSB_CLASS_CONTENT_SEC: result:='USB class for content security devices';
    TJUsbConstantsUSB_CLASS_CSCID: result:='USB class for content smart card devices';
    TJUsbConstantsUSB_CLASS_HID: result:='USB class for human interface devices (for example, mice and keyboards)';
    TJUsbConstantsUSB_CLASS_HUB: result:='USB class for USB hubs';
    TJUsbConstantsUSB_CLASS_MASS_STORAGE: result:='USB class for mass storage devices';
    TJUsbConstantsUSB_CLASS_MISC: result:='USB class for wireless miscellaneous devices';
    TJUsbConstantsUSB_CLASS_PER_INTERFACE: result:='USB class indicating that the class is determined on a per-interface basis';
    TJUsbConstantsUSB_CLASS_PHYSICA: result:='USB class for physical devices';
    TJUsbConstantsUSB_CLASS_PRINTER: result:='USB class for printers';
    TJUsbConstantsUSB_CLASS_STILL_IMAGE: result:='USB class for still image devices (digital cameras)';
    TJUsbConstantsUSB_CLASS_VENDOR_SPEC: result:='Vendor specific USB class';
    TJUsbConstantsUSB_CLASS_VIDEO: result:='USB class for video devices';
    TJUsbConstantsUSB_CLASS_WIRELESS_CONTROLLER: result:='USB class for wireless controller devices';
  else
    result:='Unknown USB class!';
  end;
end;

constructor TJvHidPnPInfo.Create(ADevice:JUSBDevice);
begin
  inherited Create;
  FUSBDevice:=ADevice;
  FFriendlyName := JStringToString(FUSBDevice.getDeviceName);
  FDeviceID := FUSBDevice.getDeviceId;
  FProductId:= FUSBDevice.getProductId;
  FVendorId:= FUSBDevice.getVendorId;
  FDeviceClass:= FUSBDevice.getDeviceClass;
  FDeviceProtocol:= FUSBDevice.getDeviceProtocol;
  FDeviceSubclass:= FUSBDevice.getDeviceSubclass;
end;

destructor TJvHidPnPInfo.Destroy;
begin
  inherited Destroy;
end;


constructor TJvHidDeviceReadThread.CtlCreate(const aDevice: TJvHidDevice);
begin
  inherited Create(True);
  FreeOnTerminate:=False;
  Device:=aDevice;
  NumBytesRead := 0;
  Finalize(Report);
  SetLength(Report, Device.EpIn.getMaxPacketSize);
  Start;
end;

constructor TJvHidDeviceReadThread.Create(CreateSuspended: Boolean);
begin
  // direct creation of thread not allowed !!
  raise EControllerError.CreateRes(@RsEDirectThreadCreationNotAllowed);
end;

procedure TJvHidDeviceReadThread.DoData;
begin
  Device.OnData(Device, Report[0], @Report[1], NumBytesRead);
end;

procedure TJvHidDeviceReadThread.DoDataError;
begin
  //if Assigned(Device.FDataError) then
  //  Device.FDataError(Device, FErr);
end;


procedure TJvHidDeviceReadThread.Execute;
var
 i,FBytesRead:integer;
 FIBuffer : TJavaArray<Byte>;
begin
  if NOT Assigned(Device.Connection) then exit;
  FIBuffer := TJavaArray<Byte>.Create(Device.EPIn.getMaxPacketSize);
  while not Terminated do
  begin
    while assigned(Device.Connection) and (not Terminated) do
    begin
      FBytesRead := Device.Connection.bulkTransfer(Device.EPIn, FIBuffer, FIBuffer.Length, 0);
      if FBytesRead > 0 then
      begin
        for i := 0 to (FBytesRead-1) do Report[i+1]:=FIBuffer.Items[i];
        if not Terminated then DoData;
        //if not Terminated then Synchronize(DoData);
      end;
    end;
    Sleep(10);
  end;
  FIBuffer.Free;
end;

procedure TJvHidDevice.StartThread;
begin
  if Assigned(FData) and Assigned(EpIn) and IsPluggedIn and IsCheckedOut and
     not Assigned(FDataThread) then
  begin
    FDataThread := TJvHidDeviceReadThread.CtlCreate(Self);
  end;
end;

procedure TJvHidDevice.StopThread;
begin
  if Assigned(FDataThread) then
  begin
    FDataThread.Terminate;
    FDataThread.WaitFor;
    FDataThread.Free;
    FDataThread := nil;
  end;
end;

procedure TJvHidDevice.SetThreadSleepTime(const SleepTime: Integer);
begin
  // limit to 10 msec .. 10 sec
  if (SleepTime >= 10) and (SleepTime <= 10000) then
    FThreadSleepTime := SleepTime;
end;


procedure TJvHidDevice.SetDataEvent(const DataEvent: TJvHidDataEvent);
begin
  if not Assigned(DataEvent) then StopThread;
  FData := DataEvent;
  StartThread;
end;

procedure TJvHidDevice.CloseFile;
begin
  if Assigned(FUsbDeviceConnection) then
  begin
    if Assigned(FUsbInterface) then FUsbDeviceConnection.releaseInterface(FUsbInterface);
    FUsbDeviceConnection.close;
  end;
  FUsbDeviceConnection:=nil;
  FUsbInterface:=nil;
  FEpOut := nil;
  FEpIn := nil;
end;


function TJvHidDevice.OpenFile:boolean;
var
  FUsbEP:JUSBEndPoint;
  error:boolean;
begin

  if NOT Assigned(FUsbDeviceConnection) then
  begin

    try

      if NOT FMyController.UsbManager.hasPermission(FUsbDevice) then
      begin
        //raise Exception.Create('No permission to access USB device.');
        error:=True;
        {$ifdef WITHPERMISSION}
        FMyController.UsbManager.requestPermission(FUsbDevice,FMyController.PermissionIntent);
        {$endif}
        exit;
      end;

      error:=false;

      FUsbInterface := FUsbDevice.getInterface(0);

      FEpOut:=nil;
      FEpIn:=nil;

      // Get HID endpoint 0
      if FUsbInterface.getEndpointCount>0 then
      begin
        FUsbEP := FUsbInterface.getEndpoint(0);
        if FUsbEP.getType=TJUsbConstantsUSB_ENDPOINT_XFER_INT then
        begin
          if FUsbEP.getDirection = TJUsbConstantsUSB_DIR_OUT then
          begin
            FEpOut := FUsbEP;
          end
          else if FUsbEP.getDirection = TJUsbConstantsUSB_DIR_IN then
          begin
            FEpIn := FUsbEP;
          end;
        end;
      end;

      // Get HID endpoint 1
      if FUsbInterface.getEndpointCount>1 then
      begin
        FUsbEP := FUsbInterface.getEndpoint(1);
        if FUsbEP.getType=TJUsbConstantsUSB_ENDPOINT_XFER_INT then
        begin
          if FUsbEP.getDirection = TJUsbConstantsUSB_DIR_OUT then
          begin
            FEpOut := FUsbEP;
          end
          else if FUsbEP.getDirection = TJUsbConstantsUSB_DIR_IN then
          begin
            FEpIn := FUsbEP;
          end;
        end;
      end;

      if (EpIn=nil) AND (EpOut=nil) then
      begin
        //raise Exception.Create('Not endpoints found !!.');
        error:=True;
        exit;
      end;

      // Open device
      FUsbDeviceConnection := FMyController.UsbManager.openDevice(FUsbDevice);
      if not assigned( FUsbDeviceConnection) then
      begin
        //raise Exception.Create('Failed to open device.');
        error:=True;
        exit;
      end;

      if not FUsbDeviceConnection.claimInterface(FUsbInterface, True) then
      begin
        //raise Exception.Create('Failed to claim interface.');
        error:=True;
        exit;
      end;

    finally
      if error then
      begin
        result:=False;
        CloseFile;
        //raise Exception.Create('Failed to open USB device.');
      end;
    end;

  end;

  result:=Assigned(FUsbDeviceConnection);

end;


procedure TJvHidDevice.FlushQueue;
begin
  // not implemented
end;

function TJvHidDevice.ReadFile(var Report; ToRead: DWORD; var BytesRead: DWORD): Boolean;
var
  bufferMaxLength:integer;
  i : Word;
  Buffer2 : JByteBuffer;
  Buffer : TJavaArray<Byte>;
  retval: integer;
  inrequest: JUSbRequest;
  returnrequest: JUSbRequest;
  //retval: boolean;
  readBufferByte: array[0..64] of byte;
begin

  BytesRead:=0;

  if OpenFile then
  begin

    if Assigned(EpIn) then
    begin

      FillChar(readBufferByte, SizeOf(readBufferByte), 0);

      bufferMaxLength:=EpIn.getMaxPacketSize;

      Buffer := TJavaArray<Byte>.Create(bufferMaxLength);

      repeat
    		retval := FUsbDeviceConnection.bulkTransfer(EpIn, Buffer, Buffer.Length, USBTIMEOUT);
    	until (retval >= 0);

      BytesRead:=retval;
      if BytesRead>bufferMaxLength then BytesRead:=bufferMaxLength;
      // include ReportID : +1
      Inc(BytesRead);
      if BytesRead>ToRead then BytesRead:=ToRead;
      if BytesRead>SizeOf(readBufferByte) then BytesRead:=SizeOf(readBufferByte);

      if BytesRead>0 then
      begin
        for i:=0 to BytesRead-1 do
            readBufferByte[i+1]:=Buffer.Items[i];
        Move(readBufferByte,Report,BytesRead);
      end;
      Move(Report,readBufferByte,1);

      Buffer.Free;

      Result :=(BytesRead>=0);

      {

      Buffer2:=TJByteBuffer.JavaClass.allocate(bufferMaxLength+1);
      Buffer2.clear;

      //inRequest := TJUsbRequest.Create;
      inRequest:=TJUsbRequest.JavaClass.init;
      inRequest.initialize(FUsbDeviceConnection, EpIn);

      retval:=inRequest.queue(buffer2, bufferMaxLength);

      if retval then
      begin
        returnrequest:=FUsbDeviceConnection.requestWait;
        //if returnrequest<>nil then
        begin
          if returnrequest.equals(inrequest) then
          begin
            Buffer2.rewind;
            BytesRead := bufferMaxLength;
            for i:=0 to BytesRead-1 do
            begin
              //if Buffer2.hasRemaining then readBufferByte[i+1]:=Buffer2.get;
              readBufferByte[i+1]:=Buffer2.get;
            end;
            Move(Report,readBufferByte,1);
            Move(readBufferByte,Report,SizeOf(Report));
          end;
        end;
      end;
      //inRequest.close;
      }
    end;
  end;
  //Result :=(BytesRead>=0);
end;


function TJvHidDevice.WriteFile(var Report; ToWrite: DWORD; var BytesWritten: DWORD): Boolean;
var
  bufferMaxLength:integer;
  i : Word;
  Buffer2 : JByteBuffer;
  Buffer : TJavaArray<Byte>;
  retval: integer;
  outrequest: JUSbRequest;
  returnrequest: JUSbRequest;
  //retval: boolean;
  writeBufferByte: array[0..64] of byte;
begin
  result:=False;

  if OpenFile then
  begin

    if Assigned(EpOut) then
    begin

      bufferMaxLength:=EPOut.getMaxPacketSize;

      FillChar(writeBufferByte, SizeOf(writeBufferByte), #0);
      Move(Report,writeBufferByte,ToWrite);

      Buffer := TJavaArray<Byte>.Create(bufferMaxLength);
      for i:=1 to ToWrite-1 do Buffer.Items[i-1] := writeBufferByte[i];

      repeat
    		retval := FUsbDeviceConnection.bulkTransfer(EpOut, Buffer, Buffer.Length, USBTIMEOUT);
    	until (retval >= 0);

      Buffer.Free;

      Result :=(retval>=0);

      result:=True;

      {
      Buffer2:=TJByteBuffer.JavaClass.allocate(bufferMaxLength+1);
      Buffer2.clear;

      //outrequest := TJUsbRequest.Create;
      outRequest:=TJUsbRequest.JavaClass.init;
      outrequest.initialize(FUsbDeviceConnection,EpOut);

      FillChar(writeBufferByte, SizeOf(writeBufferByte), #0);
      Move(Report,writeBufferByte,ToWrite);

      for i:=1 to ToWrite-1 do Buffer2.put(writeBufferByte[i]);

      retval := outrequest.queue(Buffer2, ToWrite-1);

      returnrequest:=FUsbDeviceConnection.requestWait;
      //if returnrequest<>nil then
      begin
        if returnrequest.equals(outrequest) then
        begin
          BytesWritten:=ToWrite;
          result:=True;
        end;
      end;
      //outRequest.close;
    }
    end;
  end;
end;

function TJvHidDevice.GetCaps: THIDPCaps;
begin
  if Openfile then
  begin
    if Assigned(EpOut) AND (fCaps.OutputReportByteLength=0)
       then fCaps.OutputReportByteLength:=EpOut.getMaxPacketSize+1;
    if Assigned(EpIn) AND (fCaps.InputReportByteLength=0)
       then fCaps.InputReportByteLength:=EpIn.getMaxPacketSize+1;
    // for now ... not yet correct
    if Assigned(EpIn) AND (fCaps.FeatureReportByteLength=0)
       then fCaps.FeatureReportByteLength:=EpIn.getMaxPacketSize+1;
  end;
  Result:=fCaps;
end;

function TJvHidDevice.GetAttributes: boolean;
begin
  result:=False;
  if Assigned(fusbdevice) then
  begin
    //  if FAttributes.VendorID=0 then
       FAttributes.VendorID:=fusbdevice.getVendorId;
    //  if FAttributes.ProductID=0 then
       FAttributes.ProductID:=fusbdevice.getProductId;
    //  if FAttributes.VersionNumber=0 then
       FAttributes.VersionNumber:=fusbdevice.getDeviceProtocol;
    result:=True;
  end;
end;

function TJvHidDevice.CheckOut: Boolean;
begin
  Result := Assigned(FMyController) and IsPluggedIn and not IsCheckedOut;
  if Result then
  begin
    FIsCheckedOut := True;
    Inc(FMyController.FNumCheckedOutDevices);
    Dec(FMyController.FNumCheckedInDevices);
    StartThread;
  end;
end;

function TJvHidDevice.GetDeviceString(Idx: Byte): string;
const
  STD_USB_REQUEST_GET_DESCRIPTOR = $06;
  STD_USB_REQUEST_GET_REPORT = $01;
  LIBUSB_FEATURE_REPORT = $0301; //Feature report, ID = 1
  LIBUSB_DT_STRING = $03;
var
  i,rdo:integer;
  rawDescs,buffer : TJavaArray<Byte>;
  requestidx:integer;
  S : String;
begin

  if Openfile then
  begin
    rawDescs := FUsbDeviceConnection.getRawDescriptors;

    if (13+Idx)>rawDescs.Length then
    begin
      result:='';
      exit;
    end;

    requestidx := rawDescs[13+Idx];

    rawDescs.Free;

    buffer := TJavaArray<Byte>.Create(255);

    rdo := FUsbDeviceConnection.controlTransfer(
           (TJUsbConstantsUSB_DIR_IN	OR TJUsbConstantsUSB_TYPE_STANDARD),
           STD_USB_REQUEST_GET_DESCRIPTOR,
           ((LIBUSB_DT_STRING SHL 8) OR requestidx),
           0,
           buffer,
           $FF,
           0);

    if rdo>100 then rdo:=100;

    if rdo<3 then
    begin
      result:='';
      exit;
    end;

    S:='';
    for i:=1 to (rdo-2) do
    begin
      S:=S+Char(buffer.Items[i+1]);
    end;
    result:=S;
    buffer.Free;
  end
  else result:='';
end;

function TJvHidDevice.GetFeatureReport: string;
const
  STD_USB_REQUEST_RECIPIENT = $01; // Interface
  STD_USB_REQUEST_GET_REPORT = $01; //HID GET_REPORT
  STD_USB_REQUEST_SET_REPORT = $09; //HID SET_REPORT
  LIBUSB_FEATURE_REPORT = $0301; //Feature report ($0300), ID = 1 ($01)
  LIBUSB_FEATURE_REPORT_LENGTH = $FF;
var
  i,rdo:integer;
  buffer : TJavaArray<Byte>;
  S : String;
begin

  if Openfile then
  begin

    buffer := TJavaArray<Byte>.Create(255);

    rdo := FUsbDeviceConnection.controlTransfer(
           (TJUsbConstantsUSB_DIR_IN OR TJUsbConstantsUSB_TYPE_CLASS OR STD_USB_REQUEST_RECIPIENT),
           STD_USB_REQUEST_GET_REPORT,
           LIBUSB_FEATURE_REPORT,
           0,
           buffer,
           LIBUSB_FEATURE_REPORT_LENGTH,
           2000);

    if rdo<0 then
    begin
      buffer.Free;
      result:='';
      exit;
    end;

    if rdo>255 then rdo:=255;

    S:='';
    for i:=0 to rdo do
    begin
      S:=S+Char(buffer.Items[i]);
    end;
    result:=S;
    buffer.Free;
  end
  else result:='';
end;


function TJvHidDevice.GetVendorName: String;
begin
  if FVendorName = '' then
  begin
    FVendorName := GetDeviceString(1);
  end;
  Result := FVendorName;
end;

function TJvHidDevice.GetProductName: String;
begin
  if FProductName = '' then
  begin
    FProductName := GetDeviceString(2);
    //FProductName := JStringToString(FUsbDevice.getDeviceName);
  end;
  Result := FProductName;
end;

function TJvHidDevice.GetSerialNumber: String;
begin
  if FSerialNumber = '' then
  begin
    FSerialNumber:=GetDeviceString(3);
    //if Openfile then FSerialNumber:=JStringToString(FUsbDeviceConnection.getSerial);
  end;
  Result := FSerialNumber;
end;

procedure TJvHidDevice.DoUnplug;
begin
  CloseFile;
  FIsPluggedIn := False;
  // event even for checked in devices
  if Assigned(FUnplug) then
    FUnplug(Self);
  // guarantees that event is only called once
  OnUnplug := nil;
end;


constructor TJvHidDevice.CtlCreate(const APnPInfo: TJvHidPnPInfo; const LocalController: TJvHidDeviceController);
begin
  inherited Create;

  FPnPInfo := APnPInfo;
  FUSBDevice:=FPnPInfo.FUSBDevice;
  FMyController := LocalController;

  FIsPluggedIn := True;
  FIsCheckedOut := False;
  FIsEnumerated := False;
  FVendorName := '';
  FProductName := '';
  FSerialNumber := '';
  FLanguageStrings := TStringList.Create;
  FDebugInfo := TStringList.Create;

  FillChar(fCaps, SizeOf(THIDPCaps), #0);
  FillChar(FAttributes, SizeOf(THIDDAttributes), #0);

  FThreadSleepTime := 100;
  FDataThread := nil;

  OnData := FMyController.OnDeviceData;
  OnUnplug := FMyController.OnDeviceUnplug;

  if NOT GetAttributes then
     raise EControllerError.CreateRes(@RsEDeviceCannotBeIdentified);

  // the file is closed to stop using up resources
  CloseFile;
end;

// dummy constructor to catch invalid Create calls
constructor TJvHidDevice.Create;
begin
  inherited Create;
  raise EControllerError.CreateRes(@RsEDirectHidDeviceCreationNotAllowed);
end;

destructor TJvHidDevice.Destroy;
var
  I: Integer;
  TmpOnData: TJvHidDataEvent;
  TmpOnUnplug: TJvHidUnplugEvent;
  Dev: TJvHidDevice;
begin
  // if we need to clone the object
  TmpOnData := OnData;
  TmpOnUnplug := OnUnplug;
  // to prevent strange problems
  OnData := nil;
  OnUnplug := nil;

  // free the data which needs special handling
  CloseFile;

  FLanguageStrings.Free;

  if FMyController <> nil then
    with FMyController do
    begin
      // delete device from controller list
      for I := 0 to FList.Count - 1 do
        if  TJvHidDevice(FList.Items[I]) = Self then
        begin
          // if device is plugged in create a checked in copy
          if IsPluggedIn then
          begin
            Dev := nil;
            try
              Dev := TJvHidDevice.CtlCreate(FPnPInfo, FMyController);
              // make it a complete clone
              Dev.OnData := TmpOnData;
              Dev.OnUnplug := TmpOnUnplug;
              Dev.ThreadSleepTime := ThreadSleepTime;
              FList.Items[I] := Dev;
              // the FPnPInfo has been handed over to the new object
              FPnPInfo := nil;
              if IsCheckedOut then
              begin
                Dec(FNumCheckedOutDevices);
                Inc(FNumCheckedInDevices);
              end;
            except
              on EControllerError do
              begin
                FList.Delete(I);
                Dev.Free;
                Dec(FNumUnpluggedDevices);
              end;
            end;
          end
          else
          begin
            FList.Delete(I);
            Dec(FNumUnpluggedDevices);
          end;
          Break;
        end;
    end;
  FPnPInfo.Free;
  inherited Destroy;
end;

constructor TJvHidDeviceController.Create(AOwner: TComponent);
var
  JavaObject : JObject;
begin
  inherited Create(AOwner);

  FNumCheckedInDevices := 0;
  FNumCheckedOutDevices := 0;
  FNumUnpluggedDevices := 0;

  FInDeviceChange := False;

  //FList := THidDevList.Create(False);
  FList := THidDevList.Create;

  JavaObject := SharedActivityContext.getSystemService(TJContext.JavaClass.USB_SERVICE);
  FUsbManager := TJUSBManager.Wrap((JavaObject as ILocalObject).GetObjectID);
  if not Assigned(FUsbManager) then
  begin
    raise Exception.Create('No USB manager adapter present');
  end;
end;


destructor TJvHidDeviceController.Destroy;
var
  I: Integer;
  HidDev: TJvHidDevice;
begin
  for I := 0 to FList.Count - 1 do
  begin
    HidDev := FList.Items[I];
    with HidDev do
    begin
      // set to uncontrolled
      FMyController := nil;
      if IsCheckedOut then
        DoUnplug; // pull the plug for checked out TJvHidDevices
      //else
      Free; // kill TJvHidDevices which are not checked out
    end;
  end;
  FList.Free;

  inherited Destroy;
end;



procedure TJvHidDeviceController.CheckIn(var HidDev: TJvHidDevice);
begin
  if HidDev <> nil then
  begin
    HidDev.StopThread;
    HidDev.CloseFile;

    if HidDev.IsPluggedIn then
    begin
      HidDev.FIsCheckedOut := False;
      Dec(FNumCheckedOutDevices);
      Inc(FNumCheckedInDevices);
    end
    else
      HidDev.Free;
    HidDev := nil;
  end;
end;

procedure TJvHidDeviceController.SetDevData(const DataEvent: TJvHidDataEvent);
var
  I: Integer;
  Dev: TJvHidDevice;
begin
  if @DataEvent <> @FDevDataEvent then
  begin
    // change all OnData events with the same old value
    for I := 0 to FList.Count - 1 do
    begin
      Dev := FList.Items[I];
      if @Dev.OnData = @FDevDataEvent then
        Dev.OnData := DataEvent;
    end;
    FDevDataEvent := DataEvent;
  end;
end;

procedure TJvHidDeviceController.SetDeviceChangeEvent(const Notifier: TNotifyEvent);
begin
  if @FDeviceChangeEvent <> @Notifier then
  begin
    FDeviceChangeEvent := Notifier;
    {
    if not (csLoading in ComponentState) then
      DeviceChange;
    }
  end;
end;

procedure TJvHidDeviceController.DoDeviceChange;
begin
  if Assigned(FDeviceChangeEvent) then
    FDeviceChangeEvent(Self);
end;


procedure TJvHidDeviceController.DoArrival(HidDev: TJvHidDevice);
begin
  if Assigned(FArrivalEvent) then
  begin
    HidDev.FIsEnumerated := True;
    FArrivalEvent(HidDev);
    HidDev.FIsEnumerated := False;
  end;
end;

procedure TJvHidDeviceController.DoRemoval(HidDev: TJvHidDevice);
begin
  if Assigned(FRemovalEvent) then
  begin
    HidDev.FIsEnumerated := True;
    FRemovalEvent(HidDev);
    HidDev.FIsEnumerated := False;
  end;
end;

procedure TJvHidDeviceController.SetDevUnplug(const Unplugger: TJvHidUnplugEvent);
var
  I: Integer;
  Dev: TJvHidDevice;
begin
  if @Unplugger <> @FDevUnplugEvent then
  begin
    // change all OnUnplug events with the same old value
    for I := 0 to FList.Count - 1 do
    begin
      Dev := FList.Items[I];
      if @Dev.OnUnplug = @FDevUnplugEvent then
        Dev.OnUnplug := Unplugger;
    end;
    FDevUnplugEvent := Unplugger;
  end;
end;

function TJvHidDeviceController.CheckThisOut(var HidDev: TJvHidDevice; Idx: Integer; Check: Boolean): Boolean;
begin
  Result := Check and not TJvHidDevice(FList.Items[Idx]).IsCheckedOut;
  if Result then
  begin
    HidDev := FList[Idx];
    HidDev.FIsCheckedOut := True;
    Inc(FNumCheckedOutDevices);
    Dec(FNumCheckedInDevices);
    HidDev.StartThread;
  end;
end;

// method CheckOutByProductName hands out the first HidDevice with a matching ProductName

function TJvHidDeviceController.CheckOutByProductName(var HidDev: TJvHidDevice;
  const ProductName: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  HidDev := nil;
  if ProductName <> '' then
    for I := 0 to FList.Count - 1 do
    begin
      Result := CheckThisOut(HidDev, I, ProductName = TJvHidDevice(FList[I]).ProductName);
      if Result then
        Break;
    end;
end;

// method CheckOutByVendorName hands out the first HidDevice with a matching VendorName

function TJvHidDeviceController.CheckOutByVendorName(var HidDev: TJvHidDevice;
  const VendorName: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  HidDev := nil;
  if VendorName <> '' then
    for I := 0 to FList.Count - 1 do
    begin
      Result := CheckThisOut(HidDev, I, VendorName = TJvHidDevice(FList[I]).VendorName);
      if Result then
        Break;
    end;
end;

// method CheckOutByCallback hands out the first HidDevice which is accepted by the Check function
// only checked in devices are presented to the Check function
// the device object is usable like during Enumerate


function TJvHidDeviceController.CheckOutByCallback(var HidDev: TJvHidDevice;
  Check: TJvHidCheckCallback): Boolean;
var
  I: Integer;
  Dev: TJvHidDevice;
begin
  Result := False;
  HidDev := nil;
  for I := 0 to FList.Count - 1 do
  begin
    Dev := FList[I];
    if not Dev.IsCheckedOut then
    begin
      Dev.FIsEnumerated := True;
      Result := CheckThisOut(HidDev, I, Check(Dev));
      Dev.FIsEnumerated := False;
      if not Result then
      begin
        Dev.CloseFile;
      end;
      if Result then
        Break;
    end;
  end;
end;


// method CheckOutByID hands out the first HidDevice with a matching VendorID and ProductID
// Pid = -1 matches all ProductIDs

function TJvHidDeviceController.CheckOutByID(var HidDev: TJvHidDevice;
  const Vid, Pid: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  HidDev := nil;
  for I := 0 to FList.Count - 1 do
  begin
    Result := CheckThisOut(HidDev, I, (Vid = TJvHidDevice(FList[I]).Attributes.VendorID) and
      ((Pid = TJvHidDevice(FList[I]).Attributes.ProductID) or (Pid = -1)));
    if Result then
      Break;
  end;
end;

// method CheckOutByIndex hands out the HidDevice in the list with the named index
// this is mainly for check out during OnEnumerate

function TJvHidDeviceController.CheckOutByIndex(var HidDev: TJvHidDevice;
  const Idx: Integer): Boolean;
begin
  Result := False;
  HidDev := nil;
  if (Idx >= 0) and (Idx < FList.Count) then
    Result := CheckThisOut(HidDev, Idx, True);
end;

function TJvHidDeviceController.CountByID(const Vid, Pid: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FList.Count - 1 do
    if TJvHidDevice(FList[I]).IsPluggedIn and
      (Vid = TJvHidDevice(FList[I]).Attributes.VendorID) and
      ((Pid = TJvHidDevice(FList[I]).Attributes.ProductID) or (Pid = -1)) then
      Inc(Result);
end;

function TJvHidDeviceController.CountByProductName(const ProductName: String): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FList.Count - 1 do
    if TJvHidDevice(FList[I]).IsPluggedIn and
      (ProductName = TJvHidDevice(FList[I]).ProductName) then
      Inc(Result);
end;

function TJvHidDeviceController.CountByVendorName(const VendorName: String): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FList.Count - 1 do
    if TJvHidDevice(FList[I]).IsPluggedIn and
      (VendorName = TJvHidDevice(FList[I]).VendorName) then
      Inc(Result);
end;

function TJvHidDeviceController.CountByCallback(Check: TJvHidCheckCallback): Integer;
var
  I: Integer;
  Dev: TJvHidDevice;
begin
  Result := 0;
  for I := 0 to FList.Count - 1 do
  begin
    if TJvHidDevice(FList[I]).IsPluggedIn then
    begin
      Dev := FList[I];
      Dev.FIsEnumerated := True;
      if Check(Dev) then
        Inc(Result);
      Dev.FIsEnumerated := False;
      if not Dev.IsCheckedOut then
      begin
        Dev.CloseFile;
      end;
    end;
  end;
end;


// method CheckOut simply hands out the first available HidDevice in the list

function TJvHidDeviceController.CheckOut(var HidDev: TJvHidDevice): Boolean;
var
  I: Integer;
begin
  Result := False;
  HidDev := nil;
  for I := 0 to FList.Count - 1 do
  begin
    Result := CheckThisOut(HidDev, I, True);
    if Result then
      Break;
  end;
end;


procedure TJvHidDeviceController.SetDevThreadSleepTime(const DevTime: Integer);
var
  I: Integer;
  Dev: TJvHidDevice;
begin
  if DevTime <> FDevThreadSleepTime then
  begin
    // change all DevThreadSleepTime with the same old value
    for I := 0 to FList.Count - 1 do
    begin
      Dev := FList.Items[I];
      if Dev.ThreadSleepTime = FDevThreadSleepTime then
        Dev.ThreadSleepTime := DevTime;
    end;
    FDevThreadSleepTime := DevTime;
  end;
end;


procedure TJvHidDeviceController.DeviceChange;
var
  I,J: Integer;
  HidDev: TJvHidDevice;
  Changed: Boolean;
  NewList:THidDevList;

  // internal worker function to find all HID devices and create their objects
  procedure FillInList;
  var
    LocalHidDev: TJvHidDevice;
    LocalPnPInfo: TJvHidPnPInfo;
    DeviceList : JHashMap;
    LocalUSBDevice : JUSBDevice;
    LocalUSBInterface : JUSBInterface;
    iter : Jiterator;
    Handled: Boolean;
    RetryCreate: Boolean;
  begin
    DeviceList := FUsbManager.getDeviceList;
    iter := DeviceList.values.iterator;
    while iter.hasNext do
    begin
      LocalUSBDevice := TJUSBDevice.Wrap((iter.next as ILocalObject).GetObjectID);
      if LocalUsbDevice.getInterfaceCount>0 then
      begin
        LocalUsbInterface := LocalUsbDevice.getInterface(0);
        // HID device available ?
        if LocalUsbInterface.getInterfaceClass=TJUsbConstantsUSB_CLASS_HID then
        begin
          LocalPnPInfo := TJvHidPnPInfo.Create(LocalUsbDevice);
          RetryCreate := False;
          LocalHidDev := nil;
          repeat
            try
              LocalHidDev := TJvHidDevice.CtlCreate(LocalPnPInfo, Self);
            except
              on EControllerError do
                 if Assigned(OnDeviceCreateError) then
                 begin
                   Handled := False;
                   OnDeviceCreateError(Self, LocalPnPInfo, Handled, RetryCreate);
                   if not Handled then
                     raise;
                 end
                 else
                   raise;
            end;
          until not RetryCreate;
          if Assigned(LocalHidDev) then NewList.Add(LocalHidDev);
        end;
      end;
    end;
  end;

begin

  Changed:=False;

  // get new device list
  NewList := THidDevList.Create;

  FillInList;

  // unplug devices in FList which are not in NewList
  for I := FList.Count - 1 downto 0 do
  begin
    HidDev := FList.Items[I];
    for J := NewList.Count - 1 downto 0 do
      if (TJvHidDevice(NewList.Items[J]).PnPInfo.DeviceID = HidDev.PnPInfo.DeviceID) and
        HidDev.IsPluggedIn then
      begin
        HidDev := nil;
        Break;
      end;
    if HidDev <> nil then
    begin
      HidDev.DoUnplug;
      DoRemoval(HidDev);
      // delete from list
      if not HidDev.IsCheckedOut then
      begin
        FList.Delete(I);
        HidDev.Free;
        //HidDev.Destroy;
      end;
      Changed := True;
    end;
  end;

  // delete devices from NewList which are in FList
  for I := 0 to NewList.Count - 1 do
  begin
    //HidDev := NewList.Items[I];
    HidDev := NewList[I];
    for J := 0 to FList.Count - 1 do
      if (HidDev.PnPInfo.DeviceID = TJvHidDevice(FList[J]).PnPInfo.DeviceID) and
        TJvHidDevice(FList[J]).IsPluggedIn then
      begin
        HidDev.FMyController := nil; // prevent Free/Destroy from accessing this controller
        HidDev.Free;
        HidDev := nil;
        //NewList[I] := nil;
        Break;
      end;
  end;

  // add the remains in NewList to FList
  for I := 0 to NewList.Count - 1 do
    if NewList[I] <> nil then
    begin
      FList.Add(NewList[I]);
      Changed := True;
      DoArrival(NewList[I]);
    end;

  //Toast('FList filled. Count: '+InttoStr(FList.Count)+'.');
  // throw away helper list
  NewList.Free;

  // recount the devices
  FNumCheckedInDevices := 0;
  FNumCheckedOutDevices := 0;
  FNumUnpluggedDevices := 0;
  for I := 0 to FList.Count - 1 do
  begin
    HidDev := FList.Items[I];
    Inc(FNumCheckedInDevices, Ord(not HidDev.IsCheckedOut));
    Inc(FNumCheckedOutDevices, Ord(HidDev.IsCheckedOut));
    Inc(FNumUnpluggedDevices, Ord(not HidDev.IsPluggedIn));
  end;
  FNumCheckedOutDevices := FNumCheckedOutDevices - FNumUnpluggedDevices;

  if Changed then
     DoDeviceChange;
end;

procedure TJvHidDeviceController.SetEnabled(Value: Boolean);
var
  Filter: JIntentFilter;
begin
  if Value <> FEnabled then
  begin
    FEnabled := Value;
    if FEnabled then
    begin
      DeviceChange;

     {$ifdef WITHPERMISSION}
      FPermissionIntent:=TJPendingIntent.JavaClass.getBroadcast(SharedActivityContext, 0, TJIntent.JavaClass.init(StringToJString(ACTION_USB_PERMISSION)), 0);
      {$endif}
      Filter := TJIntentFilter.JavaClass.init;
     {$ifdef WITHPERMISSION}
      Filter.addAction(StringToJString(ACTION_USB_PERMISSION));
      {$endif}
      Filter.addAction(TJUsbManager.JavaClass.ACTION_USB_DEVICE_ATTACHED);
      Filter.addAction(TJUsbManager.JavaClass.ACTION_USB_DEVICE_DETACHED);

      FBroadcastReceiverListener := TBroadcastReceiverListener.Create(Self);
      FReceiver := TJFMXBroadcastReceiver.JavaClass.init(FBroadcastReceiverListener);
      try
        SharedActivityContext.getApplicationContext.registerReceiver(
          FReceiver,
          Filter);
      except
      end;
    end
    else
    begin
     if
      (FReceiver <> nil) and
      (not (SharedActivityContext as JActivity).isFinishing)
      then
      try
        SharedActivityContext.getApplicationContext.unregisterReceiver(FReceiver);
      except
      end;
      FReceiver := nil;
    end;
  end;
end;

function HasPermission(const Permission: string): Boolean;
begin
   //Permissions listed at http://d.android.com/reference/android/Manifest.permission.html
   Result := SharedActivity.checkCallingOrSelfPermission(
     StringToJString(Permission)) =
     TJPackageManager.JavaClass.PERMISSION_GRANTED
end;

constructor TBroadcastReceiverListener.Create(aOwner:TJvHidDeviceController);
begin
  inherited Create;
  FHidDC:=aOwner;
end;

procedure TBroadcastReceiverListener.OnReceive(
  context: JContext;
  intent: JIntent);
begin

  //if TJUsbManager.JavaClass.ACTION_USB_DEVICE_ATTACHED.equals(intent.getAction) OR TJUsbManager.JavaClass.ACTION_USB_DEVICE_DETACHED.equals(intent.getAction) then
  if TJUsbManager.JavaClass.ACTION_USB_DEVICE_ATTACHED.equals(intent.getAction) then
  begin
    //HidDC.DeviceChange;
    TThread.CreateAnonymousThread(
    procedure
    begin
      TThread.Synchronize(
        TThread.CurrentThread,
        procedure
        begin
          //Toast('Android USB device attached.');
          HidDC.DeviceChange;
        end
      );
    end
    ).Start;
  end;

  if TJUsbManager.JavaClass.ACTION_USB_DEVICE_DETACHED.equals(intent.getAction) then
  begin
    //HidDC.DeviceChange;
    //CallInUiThread(
    TThread.CreateAnonymousThread(
    procedure
    begin
      TThread.Synchronize(
        TThread.CurrentThread,
        procedure
        begin
          //Toast('Android USB device detached.');
          HidDC.DeviceChange;
        end
      );
    end
    ).Start;
  end;


  {$ifdef WITHPERMISSION}

  //if not HasPermission('android.permission.SEND_SMS') then
  //   MessageDlg('App does not have the SEND_SMS permission',
  //     TMsgDlgType.mtError, [TMsgDlgBtn.mbCancel], 0)
  // else

  if JStringToString(intent.getAction)=ACTION_USB_PERMISSION then
  begin
    if (intent.getBooleanExtra(TJUsbManager.JavaClass.EXTRA_PERMISSION_GRANTED, false)) then
    begin
      Toast('Permission granted. Thanks !');
      if not HidDC.InDeviceChange then
      try
        HidDC.InDeviceChange := True;
        HidDC.DeviceChange;
      finally
        HidDC.InDeviceChange := False;
      end;
    end
    else
    begin
      Toast('Permission not granted');
    end;
  end;
  {$endif}
end;

end.
