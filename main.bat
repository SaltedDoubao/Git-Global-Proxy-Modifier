@echo off
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do set local_ip=%%a
set local_ip=%local_ip: =%
echo Local IPv4 address: %local_ip%
set /p port=Enter port number (default is 7890): 
if "%port%"=="" set port=7890
git config --global http.proxy http://%local_ip%:%port%
git config --global https.proxy http://%local_ip%:%port%
echo Git HTTPS proxy has been set to: http://%local_ip%:%port%
pause
