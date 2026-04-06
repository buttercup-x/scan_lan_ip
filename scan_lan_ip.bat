@echo off
setlocal enabledelayedexpansion

:: Самодиагностика: если файл скачан с LF, пересобираем его с CRLF
findstr /R "$" "%~f0" > "%temp%\clean_scan.bat" 2>nul
if "%~f0" NEQ "%temp%\clean_scan.bat" (
    "%temp%\clean_scan.bat" %* & exit /b
)

chcp 65001 >nul

set "subnet="
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /R "IPv4"') do (
    for /f "tokens=1-3 delims=." %%b in ("%%a") do (
        set "b_trim=%%b"
        set "subnet=!b_trim:~1!.%%c.%%d"
    )
)

if "!subnet!"=="" exit /b

echo.
echo  --- Scan lan: !subnet!.0/24 ---
echo  --- ПОЖАЛУЙСТА ПОДОЖДИТЕ... ---
echo.

set "temp_file=%temp%\net_scan_data.txt"
if exist "%temp_file%" del "%temp_file%"

for /l %%i in (1,1,254) do (
    set "curr_ip=%subnet%.%%i"
    title Поиск: !curr_ip!
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
        echo  [+] Найдено: !curr_ip! [!name!]
    )
)

cls
echo.
echo  ===========================================================================
echo      СПИСОК УСТРОЙСТВ
echo  ===========================================================================
echo   IP-адрес          Имя устройства         MAC-адрес
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
title Готово
pause
