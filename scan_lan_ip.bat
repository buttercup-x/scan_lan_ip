@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

set "count=0"
set "keys="

echo.
echo  Available networks:
echo.

for /f "tokens=1,2 delims=|" %%a in ('powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike '*Loopback*' } | ForEach-Object { '{0}|{1}' -f $_.InterfaceAlias, $_.IPAddress }"') do (
    set "if_name=%%a"
    set "ip_raw=%%b"
    
    for /f "tokens=1-3 delims=." %%c in ("!ip_raw!") do (
        set "sub=%%c.%%d.%%e"
        
        set "exists=0"
        for /l %%x in (1,1,!count!) do (
            if "!sub!"=="!net_%%x!" set "exists=1"
        )
        
        if "!exists!"=="0" (
            set /a count+=1
            set "net_!count!=!sub!"
            set "keys=!keys!!count!"
            echo  [!count!] !if_name! [!sub!.0/24]
        )
    )
)

if !count! EQU 0 (
    echo [!] No active IPv4 networks found.
    pause
    exit /b
)

echo.
echo  Press the number of the network to scan...
choice /c !keys! /n >nul
set "choice_idx=%errorlevel%"

set "subnet=!net_%choice_idx%!"

echo.
echo  --- Scan: !subnet!.0/24
echo  --- Wait...
echo.

set "temp_file=%temp%\net_scan_data.txt"
if exist "%temp_file%" del "%temp_file%"

for /l %%i in (1,1,254) do (
    set "curr_ip=%subnet%.%%i"
    title Search: !curr_ip!
    ping -n 1 -w 40 !curr_ip! >nul
    if !errorlevel! EQU 0 (
        set "name=---"
        set "mac=--:--:--:--:--:--"
        for /f "tokens=1" %%n in ('nbtstat -A !curr_ip! 2^>nul ^| findstr /C:"<00>" ^| findstr /V /C:"GROUP"') do (
            set "raw_n=%%n"
            if not "!raw_n!"=="" set "name=!raw_n:<00>=!"
        )
        if "!name!"=="---" (
            for /f "tokens=2" %%n in ('ping -a -n 1 -w 10 !curr_ip! ^| findstr /i "Pinging"') do (
                if not "%%n"=="!curr_ip!" set "name=%%n"
            )
        )
        for /f "tokens=2,3" %%m in ('arp -a !curr_ip! 2^>nul ^| findstr /c:"!curr_ip!"') do (
            set "m1=%%m"
            set "m2=%%n"
            echo !m1! | findstr /R "..-..-..-..-..-.." >nul
            if !errorlevel! EQU 0 (set "raw_mac=!m1!") else (set "raw_mac=!m2!")
            if not "!raw_mac!"=="" set "mac=!raw_mac:~0,17!"
        )
        echo !curr_ip!^|!name!^|!mac! >> "%temp_file%"
        echo  [+] Detected: !curr_ip! [!name!]
    )
)

cls
echo.
echo  ===========================================================================
echo      Devices list
echo  ===========================================================================
echo   IP          Device name         MAC
echo  ---------------------------------------------------------------------------
if exist "%temp_file%" (
    for /f "usebackq tokens=1-3 delims=|" %%a in ("%temp_file%") do (
        set "f_ip=%%a               "
        set "f_name=%%b                    "
        set "f_mac=%%c                   "
        echo   !f_ip:~0,15!   !f_name:~0,20!   !f_mac:~0,17!
    )
    del "%temp_file%"
)
echo  ===========================================================================
title Complited
pause
