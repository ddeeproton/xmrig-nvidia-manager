unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  inifiles, Windows, Registry, MD5,
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Buttons, ExtCtrls, Spin, Menus, CheckLst;

type

  { TForm1 }

  TForm1 = class(TForm)
    CheckListBoxOptions: TCheckListBox;
    EditPathXmrigNvidia: TEdit;
    EditTemperature: TEdit;
    ImageLogo: TImage;
    ImageBackground: TImage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Memo1: TMemo;
    MenuItemShow: TMenuItem;
    MenuItemHide: TMenuItem;
    MenuItemExit: TMenuItem;
    OpenDialog1: TOpenDialog;
    PopupMenu1: TPopupMenu;
    SpeedButtonOpenDialog: TSpeedButton;
    SpeedButtonStart: TSpeedButton;
    SpeedButtonStop: TSpeedButton;
    SpeedButtonStop1: TSpeedButton;
    SpinEditTemperatureLimit: TSpinEdit;
    SpinEditSleep: TSpinEdit;
    TimerDisplayCount: TTimer;
    TimerRunDos: TTimer;
    TimerStartDelayed: TTimer;
    TrayIcon1: TTrayIcon;
    procedure CheckGroupOptionsItemClick(Sender: TObject; Index: integer);
    procedure MenuItemExitClick(Sender: TObject);
    procedure MenuItemHideClick(Sender: TObject);
    procedure MenuItemShowClick(Sender: TObject);
    procedure RunDos(Que:String);
    procedure StopDos();
    procedure OnDosOutput(line:String);
    procedure OnDosStart();
    procedure OnDosStop();
    procedure StartCount(maxSeconds: Integer);
    procedure TimerDisplayCountTimer(Sender: TObject);
    procedure TimerRunDosTimer(Sender: TObject);
    procedure TrackDosTemperatureOutput(line:String);
    procedure TrackError(line:String);
    procedure OnDosTemperatureOutput(Temperature:Integer);
    procedure OnDosTemperatureExceed(Temperature:Integer);
    procedure OnDosTemperatureAllowed(Temperature:Integer);
    function getCharsBetween(line, startChars, endChars:String):String;
    function RemoveNewlineAtEnd(line: String): String;
    procedure CloseProcessPID(pid: Integer);
    procedure LoadConfig();
    procedure SaveConfig();
    procedure ButtonStartClick(Sender: TObject);
    procedure ButtonStopClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure TimerStartDelayedTimer(Sender: TObject);
    procedure ButtonOpenDialogClick(Sender: TObject);
    procedure SpinEditTemperatureLimitChange(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;
  pid: Integer;

const
  I_RESTARTONERROR : Integer = 0;
  I_AUTOSTART: Integer = 1;
  I_BOOTWINDOWS: Integer = 2;
  I_BACKGROUNDSTART: Integer = 3;

implementation

{$R *.lfm}




{ TForm1 }


procedure TForm1.FormCreate(Sender: TObject);
var i: Integer;
begin
  Form1.DoubleBuffered := True;
  Memo1.DoubleBuffered := True;
  ImageBackground.Align := alClient;
  TimerStartDelayed.Enabled := False;
  TimerRunDos.Enabled := False;
  TimerDisplayCount.Enabled := False;
  Memo1.Clear;
  Memo1.Lines.Add('Welcome!');
  Memo1.Lines.Add('1. Download and configure XMRig');
  Memo1.Lines.Add('https://github.com/xmrig/xmrig/releases');
  Memo1.Lines.Add('');
  Memo1.Lines.Add('2. Set the XMRig path into the Manager:');
  Memo1.Lines.Add('https://github.com/ddeeproton/xmrig-nvidia-manager');
  Memo1.Lines.Add('');
  Memo1.Lines.Add('3. Optional commands:');
  Memo1.Lines.Add(ExtractFileName(Application.ExeName) + ' /autostart');
  Memo1.Lines.Add(ExtractFileName(Application.ExeName) + ' /background');
  Memo1.Lines.Add('');

  EditPathXmrigNvidia.Clear;
  EditTemperature.Text := '?';
  LoadConfig;

  if CheckListBoxOptions.Checked[I_AUTOSTART] then
    ButtonStartClick(nil);

  if CheckListBoxOptions.Checked[I_BACKGROUNDSTART] then
    MenuItemHideClick(nil);

  for i := 1 to ParamCount() do
  begin
    if LowerCase(ParamStr(i)).Contains('background')
    and not CheckListBoxOptions.Checked[I_BACKGROUNDSTART] then
    begin
      MenuItemHideClick(nil);
    end;
    if LowerCase(ParamStr(i)).Contains('autostart')
    and not CheckListBoxOptions.Checked[I_AUTOSTART] then
    begin
      ButtonStartClick(nil);
    end;
  end;

end;


procedure TForm1.LoadConfig();
var
  Setup: TIniFile;
  Reg: TRegistry;
  ShouldSave: Boolean;
begin
  // Check load on boot
  Reg := TRegistry.Create;
  Reg.RootKey := HKEY_CURRENT_USER;
  if Reg.OpenKey('\Software\Microsoft\Windows\CurrentVersion\Run', True) then
  begin
    CheckListBoxOptions.Checked[I_BOOTWINDOWS] := Reg.ValueExists(ExtractFileName(Application.ExeName)+'_'+MD5Print(MD5String(ExtractFileDir(Application.ExeName))));
    Reg.CloseKey;
  end;
  Reg.Free;

  Setup := TIniFile.Create(ExtractFileDir(Application.ExeName) + '\Setup.ini');

  ShouldSave := not Setup.ValueExists('Application', 'PathXmrigNvidia')
             or not Setup.ValueExists('Application', 'TemperatureLimit')
             or not Setup.ValueExists('Application', 'SleepOnError')
             or not Setup.ValueExists('Application', 'RestartOnError')
             or not Setup.ValueExists('Application', 'AutoStart')
             or not Setup.ValueExists('Application', 'BootWindows')
             or not Setup.ValueExists('Application', 'BackgroundStart');

  EditPathXmrigNvidia.Text := Setup.ReadString('Application', 'PathXmrigNvidia', '');
  SpinEditTemperatureLimit.Value := Setup.ReadInteger('Application', 'TemperatureLimit', 84);
  SpinEditSleep.Value := Setup.ReadInteger('Application', 'SleepOnError', 1);
  CheckListBoxOptions.Checked[I_RESTARTONERROR] := Setup.ReadBool('Application', 'RestartOnError', True);
  CheckListBoxOptions.Checked[I_AUTOSTART] := Setup.ReadBool('Application', 'AutoStart', False);
  //CheckGroupOptions.Checked[I_BOOTWINDOWS] := Setup.ReadBool('Application', 'BootWindows', False);
  CheckListBoxOptions.Checked[I_BACKGROUNDSTART] := Setup.ReadBool('Application', 'BackgroundStart', False);
  Setup.Free;

  if ShouldSave then SaveConfig();
end;

procedure TForm1.SaveConfig();
var
  Setup: TIniFile;
  Reg: TRegistry;
begin
  Reg := TRegistry.Create;
  Reg.RootKey := HKEY_CURRENT_USER;
  try
  if Reg.OpenKey('\Software\Microsoft\Windows\CurrentVersion\Run', True) then
  begin
    if CheckListBoxOptions.Checked[I_BOOTWINDOWS] then
      Reg.WriteString(ExtractFileName(Application.ExeName)+'_'+MD5Print(MD5String(ExtractFileDir(Application.ExeName))), '"'+Application.ExeName+'"')
    else
      Reg.DeleteValue(ExtractFileName(Application.ExeName)+'_'+MD5Print(MD5String(ExtractFileDir(Application.ExeName))));
    Reg.CloseKey;
  end;
  finally
    Reg.Free;
  end;

  Setup := TIniFile.Create(ExtractFileDir(Application.ExeName) + '\Setup.ini');
  Setup.WriteString('Application', 'PathXmrigNvidia', EditPathXmrigNvidia.Text);
  Setup.WriteInteger('Application', 'TemperatureLimit', SpinEditTemperatureLimit.Value);
  Setup.WriteInteger('Application', 'SleepOnError', SpinEditSleep.Value);
  Setup.WriteBool('Application', 'RestartOnError', CheckListBoxOptions.Checked[I_RESTARTONERROR]);
  Setup.WriteBool('Application', 'AutoStart', CheckListBoxOptions.Checked[I_AUTOSTART]);
  //Setup.WriteBool('Application', 'BootWindows', CheckListBoxOptions.Checked[I_BOOTWINDOWS]);
  Setup.WriteBool('Application', 'BackgroundStart', CheckListBoxOptions.Checked[I_BACKGROUNDSTART]);
  Setup.Free;


end;

procedure TForm1.RunDos(Que:String);
const
  CUANTOBUFFER = 2000;
var
  Seguridades         : TSecurityAttributes;
  PaLeer,PaEscribir   : THandle;
  start               : TStartUpInfo;
  ProcessInfo         : TProcessInformation;
  Buffer              : Pchar;
  BytesRead           : DWord;
  CuandoSale          : DWord;
  tb                  : PDWord;

  procedure readFromPipe;
  begin
    repeat
      BytesRead := 0;
      PeekNamedPipe(PaLeer, nil, 0, nil, tb, nil);
      if tb^=0 then
        break;
      ReadFile(PaLeer,Buffer[0],CUANTOBUFFER,BytesRead,nil);
      Buffer[BytesRead]:= #0;
      OemToAnsi(Buffer,Buffer);
      OnDosOutput(String(Buffer));
    until (BytesRead < CUANTOBUFFER);
  end;

begin
  with Seguridades do
  begin
    nlength              := SizeOf(TSecurityAttributes);
    binherithandle       := true;
    lpsecuritydescriptor := nil;
  end;

  if Createpipe (PaLeer, PaEscribir, @Seguridades, 0) then
  begin
    Buffer  := AllocMem(CUANTOBUFFER + 1);
    FillChar(Start,Sizeof(Start),#0);
    start.cb          := SizeOf(start);
    start.hStdOutput  := PaEscribir;
    start.hStdInput   := PaLeer;
    start.hStdError   := PaEscribir;
    start.dwFlags     := STARTF_USESTDHANDLES +
                         STARTF_USESHOWWINDOW;
    start.wShowWindow := SW_HIDE;

    if CreateProcess(nil,
      PChar(Que),
      @Seguridades,
      @Seguridades,
      true,
      NORMAL_PRIORITY_CLASS,
      nil,
      nil,
      start,
      ProcessInfo)
    then
    begin
      try
        pid := ProcessInfo.dwProcessId;
        new(tb);
        repeat
          CuandoSale := WaitForSingleObject( ProcessInfo.hProcess,100);
          readFromPipe;
          Application.ProcessMessages;
        until (CuandoSale <> WAIT_TIMEOUT);
        dispose(tb);
      except
        On E : EOSError do exit;
        On E : EAccessViolation do exit;
      end;
    end;
    FreeMem(Buffer);
    OnDosStop();
  end;

end;


procedure TForm1.MenuItemExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TForm1.MenuItemHideClick(Sender: TObject);
begin
  Application.ShowMainForm := False;
  Hide;
end;

procedure TForm1.MenuItemShowClick(Sender: TObject);
begin
  Application.ShowMainForm := True;
  Show;
end;


procedure TForm1.CloseProcessPID(pid: Integer);
var
  processHandle: THandle;
begin
  try
    processHandle := OpenProcess(PROCESS_TERMINATE or PROCESS_QUERY_INFORMATION, False, pid);
    if processHandle <> 0 then
    begin
      TerminateProcess(processHandle, 0);
      CloseHandle(ProcessHandle);
    end;
  except
    On E : EOSError do exit;
    On E : EAccessViolation do exit;
  end;
end;

procedure TForm1.StopDos();
begin
  CloseProcessPID(pid);
end;


procedure TForm1.OnDosStart();
begin
  Memo1.Lines.Add('Start mining');
end;

procedure TForm1.OnDosStop();
begin
  Memo1.Lines.Add('Stop mining');
end;

procedure TForm1.TimerRunDosTimer(Sender: TObject);
begin
  TimerRunDos.Enabled := False;
  TimerDisplayCount.Enabled := False;
  OnDosStart();
  if not FileExists(EditPathXmrigNvidia.Text) then
  begin
    Memo1.Lines.Add('Error: Path to xmrig.exe is not valid!');
    Memo1.Lines.Add('Download and configure xmrig.exe here:');
    Memo1.Lines.Add('https://github.com/xmrig/xmrig/release');
  end;
  RunDos(EditPathXmrigNvidia.Text);
end;


procedure TForm1.OnDosOutput(line:String);
begin
  Memo1.Lines.Add(RemoveNewlineAtEnd(line));
  TrackDosTemperatureOutput(line);
  TrackError(line);
end;

function TForm1.RemoveNewlineAtEnd(line: String): String;
begin
  result := line;
  if line[Length(line)-1] <> #13 then exit;
  result := Copy(line, 1, Length(line) - 2);
end;

function TForm1.getCharsBetween(line, startChars, endChars:String):String;
var
  startPos, endPos: Integer;
begin
  if Pos(startChars, line) = 0 then exit;
  if Pos(endChars, line) = 0 then exit;
  startPos := Pos(startChars, line) + Length(startChars);
  endPos := Pos(endChars, line) - startPos;
  result := Copy(line, startPos, endPos);
end;

procedure TForm1.TrackDosTemperatureOutput(line:String);
var
  startPos: String;
  Temperature, p: Integer;
begin
  // Parse line Exemple:
  // #0 01:00.0   0W 69C fan0:44%
  p := Pos('C fan', line);
  if p = 0 then exit;

  line := getCharsBetween(line, 'W ', 'C fan');
  if line = '' then Exit;

  Temperature := -100;
  TryStrToInt(line, Temperature);
  if Temperature = -100 then Exit;

  OnDosTemperatureOutput(Temperature);
end;


procedure TForm1.TrackError(line:String);
begin
  if not CheckListBoxOptions.Checked[I_RESTARTONERROR] then Exit;
  if Pos('error', line) = 0 then Exit;
  Memo1.Lines.Add('Error detected (restart in '+IntToStr(SpinEditSleep.Value)+' min)');
  StopDos();
  TimerStartDelayed.Interval := SpinEditSleep.Value * 60 * 1000;   
  StartCount(SpinEditSleep.Value * 60);
  TimerStartDelayed.Enabled := True;
end;

procedure TForm1.OnDosTemperatureOutput(Temperature:Integer);
begin
  EditTemperature.Text := IntToStr(Temperature);
  if Temperature > SpinEditTemperatureLimit.Value then
    OnDosTemperatureExceed(Temperature)
  else
    OnDosTemperatureAllowed(Temperature);
end;

procedure TForm1.OnDosTemperatureExceed(Temperature:Integer);
begin
  Memo1.Lines.Add('Temperature limit exceeded! Stop mining for '+IntToStr(SpinEditSleep.Value)+' min.');
  StopDos();
  TimerStartDelayed.Interval := SpinEditSleep.Value * 60 * 1000;
  StartCount(SpinEditSleep.Value * 60);
  TimerStartDelayed.Enabled := True;
end;

procedure TForm1.OnDosTemperatureAllowed(Temperature:Integer);
begin
  //EditTemperature.Text := IntToStr(Temperature);
end;



procedure TForm1.TimerStartDelayedTimer(Sender: TObject);
begin
  TTimer(Sender).Enabled := False;
  ButtonStartClick(nil);
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  StopDos();
end;

procedure TForm1.ButtonStartClick(Sender: TObject);
begin
  ButtonStopClick(nil);
  Application.ProcessMessages;
  TimerRunDos.Enabled := False;
  TimerDisplayCount.Enabled := False;
  Application.ProcessMessages;
  TimerRunDos.Enabled := True;
end;

procedure TForm1.ButtonStopClick(Sender: TObject);
begin
  if TimerStartDelayed.Enabled then
  begin
    TimerStartDelayed.Enabled := False;
    Memo1.Lines.Add('Cancel restart mining');
  end;
  TimerDisplayCount.Enabled := False;
  TimerRunDos.Enabled := False;
  StopDos();
end;

procedure TForm1.ButtonOpenDialogClick(Sender: TObject);
begin
  OpenDialog1.InitialDir := ExtractFileDir(Application.ExeName);
  if not OpenDialog1.Execute then Exit;
  EditPathXmrigNvidia.Text := OpenDialog1.FileName;
  SaveConfig;
end;

procedure TForm1.SpinEditTemperatureLimitChange(Sender: TObject);
begin
  SaveConfig;
end;

procedure TForm1.CheckGroupOptionsItemClick(Sender: TObject; Index: integer);
begin
  SaveConfig;
end;

//=========================
//      Display counter
//=========================

var DisplayMaxSeconds: Integer;

procedure TForm1.TimerDisplayCountTimer(Sender: TObject);
begin
  if DisplayMaxSeconds <= 0 then
  begin
    Memo1.Lines.Delete(Memo1.Lines.Count - 1);
    TimerDisplayCount.Enabled:=False;
    Exit;
  end;
  Memo1.Lines.Strings[Memo1.Lines.Count - 1] := 'Wait '+IntToStr(DisplayMaxSeconds)+'s';
  Dec(DisplayMaxSeconds);

end;

procedure TForm1.StartCount(maxSeconds: Integer);
begin
  DisplayMaxSeconds := maxSeconds - 2;
  TimerDisplayCount.Interval := 1000;
  TimerDisplayCount.Enabled := True;
end;

//=========================
//   ********************
//=========================
end.

