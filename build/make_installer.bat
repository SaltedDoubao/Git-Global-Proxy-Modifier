@echo off
echo 正在构建Git代理IP监视器...

REM 首先使用PowerShell构建EXE
powershell -ExecutionPolicy Bypass -File "%~dp0build.ps1"

REM 检查Inno Setup是否安装
where iscc >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo 未检测到Inno Setup，跳过创建安装程序
    echo 如需创建安装程序，请先安装Inno Setup: https://jrsoftware.org/isdl.php
    goto :EOF
)

echo 正在创建安装程序...
iscc "%~dp0installer.iss"

echo 构建完成!
echo 请查看dist目录获取生成的文件
pause