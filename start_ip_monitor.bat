@echo off
powershell -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -WindowStyle Hidden -File \"%~dp0src\monitor_ip_change.ps1\"' -Verb RunAs"
