# 检查PS2EXE模块是否已安装
if (-not (Get-Module -ListAvailable -Name PS2EXE)) {
    Write-Host "正在安装PS2EXE模块..."
    Install-Module -Name PS2EXE -Scope CurrentUser -Force
}

# 导入模块
Import-Module PS2EXE

# 获取脚本根目录
$scriptRoot = Split-Path -Parent -Path (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition)
$srcPath = Join-Path -Path $scriptRoot -ChildPath "src\GitProxyMonitor.ps1"
$distPath = Join-Path -Path $scriptRoot -ChildPath "dist"
$iconPath = Join-Path -Path $scriptRoot -ChildPath "res\icon.ico"
$outputPath = Join-Path -Path $distPath -ChildPath "Git代理监视器.exe"

# 确保dist目录存在
if (-not (Test-Path $distPath)) {
    New-Item -ItemType Directory -Path $distPath | Out-Null
}

# 转换PowerShell脚本为EXE
Write-Host "正在构建可执行文件..."

# 检查是否有自定义图标
if (Test-Path $iconPath) {
    Invoke-ps2exe -InputFile $srcPath -OutputFile $outputPath `
                -Title "Git代理IP监视器" -Description "自动检测IP变化并更新Git代理" `
                -Version "1.0.0" -IconFile $iconPath `
                -RequireAdmin -NoConsole
} else {
    Invoke-ps2exe -InputFile $srcPath -OutputFile $outputPath `
                -Title "Git代理IP监视器" -Description "自动检测IP变化并更新Git代理" `
                -Version "1.0.0" `
                -RequireAdmin -NoConsole
}

# 复制配置文件到dist目录
$configDir = Join-Path -Path $distPath -ChildPath "config"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir | Out-Null
}

Copy-Item -Path (Join-Path -Path $scriptRoot -ChildPath "config\*") -Destination $configDir -Recurse -Force

# 创建README文件
$readmePath = Join-Path -Path $distPath -ChildPath "README.txt"
@"
Git代理IP监视器 v1.0.0
=====================

此程序会自动监听您的IP地址变化，并在变化时更新Git的HTTP和HTTPS代理设置。

使用方法:
1. 双击运行"Git代理监视器.exe"
2. 程序将在系统托盘区显示图标
3. 双击托盘图标打开主界面
4. 在主界面可以查看当前IP和代理端口

配置:
- 代理端口可在程序界面中修改
- 程序将自动检测最适合的网络连接

注意事项:
- 程序需要管理员权限才能运行
- 程序修改的是全局Git配置

"@ | Out-File -FilePath $readmePath -Encoding utf8

Write-Host "构建完成! 文件已保存到: $outputPath"
Write-Host "请查看dist目录获取完整的应用程序包"