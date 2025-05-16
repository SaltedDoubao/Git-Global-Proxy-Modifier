#define MyAppName "Git代理IP监视器"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Your Organization"
#define MyAppURL "https://github.com/yourusername/Git-Global-Proxy-Modifier"
#define MyAppExeName "Git代理监视器.exe"

[Setup]
; 应用程序ID用于唯一标识应用程序
AppId={{B34D3847-651A-4ADB-A7C4-F815A22A63E0}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
; 以下行禁用"欢迎"向导页
DisableWelcomePage=yes
; 取消注释以下行以在Windows中运行64位安装程序
; ArchitecturesInstallIn64BitMode=x64
; 取消注释以下行，以创建启动菜单项
CreateStartMenuShortcut=yes
; 在程序和功能中可见
Uninstallable=yes
; 需要管理员权限
PrivilegesRequired=admin
OutputDir=..\dist
OutputBaseFilename=GitProxyMonitor_Setup
SetupIconFile=..\res\icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startupicon"; Description: "开机自动启动"; GroupDescription: "自动启动:"

[Files]
Source: "..\dist\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\dist\config\*"; DestDir: "{app}\config"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\dist\README.txt"; DestDir: "{app}"; Flags: ignoreversion isreadme

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{commonstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startupicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall runasoriginaluser