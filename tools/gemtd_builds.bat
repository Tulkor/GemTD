@echo off
rem GemTD-Builds einsortieren
rem  - verschiebt GemTD_V*.zip aus dem Downloads-Ordner nach Desktop\GemTD\Zips
rem  - entpackt jede Version, die noch fehlt, nach Desktop\GemTD\Spiel\V0_x
rem Aufruf mit /still: kein "Taste druecken" am Ende (fuer geplante Aufgaben).
setlocal EnableExtensions

rem Desktop und Downloads ueber Windows ermitteln (klappt auch mit OneDrive-Desktop)
set "DESK="
set "DL="
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESK=%%D"
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path"`) do set "DL=%%D"
if not defined DESK set "DESK=%USERPROFILE%\Desktop"
if not defined DL set "DL=%USERPROFILE%\Downloads"

set "ZIPS=%DESK%\GemTD\Zips"
set "SPIEL=%DESK%\GemTD\Spiel"
if not exist "%ZIPS%" mkdir "%ZIPS%"
if not exist "%SPIEL%" mkdir "%SPIEL%"

echo Downloads: %DL%
echo Ziel:      %DESK%\GemTD
echo.

set /a NEU_ZIPS=0
set /a NEU_SPIEL=0

for %%F in ("%DL%\GemTD_V*.zip") do call :verschieben "%%~fF"
for %%F in ("%ZIPS%\GemTD_V*.zip") do call :entpacken "%%~fF"

echo.
echo Fertig: %NEU_ZIPS% Zip(s) verschoben, %NEU_SPIEL% Version(en) entpackt.
echo Spiele liegen in %SPIEL%
if /i not "%~1"=="/still" pause
exit /b 0


:verschieben
rem nur echte Namen wie GemTD_V0_10.zip, keine Kopien wie "GemTD_V0_10 (1).zip"
echo %~n1| findstr /r /x /c:"GemTD_V[0-9][0-9]*_[0-9][0-9]*" >nul || goto :eof
if exist "%ZIPS%\%~nx1" (
    echo %~nx1 ist schon in Zips, uebersprungen.
    goto :eof
)
move "%~1" "%ZIPS%\" >nul
if errorlevel 1 (
    echo FEHLER beim Verschieben von %~nx1
    goto :eof
)
echo %~nx1 nach Zips verschoben.
set /a NEU_ZIPS+=1
goto :eof


:entpacken
echo %~n1| findstr /r /x /c:"GemTD_V[0-9][0-9]*_[0-9][0-9]*" >nul || goto :eof
set "NAME=%~n1"
set "VERSION=%NAME:GemTD_=%"
if exist "%SPIEL%\%VERSION%" goto :eof
echo Entpacke %~nx1 nach Spiel\%VERSION% ...
set "GEMTD_ZIP=%~1"
set "GEMTD_ZIEL=%SPIEL%\%VERSION%"
rem Entpackt erst in einen Hilfsordner. Liegt darin nur ein Ordner (z.B. GemTD\),
rem wird dessen Inhalt direkt zu Spiel\V0_x, damit die exe nicht tief verschachtelt ist.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $z=$env:GEMTD_ZIP; $d=$env:GEMTD_ZIEL; $t=$d+'.tmp'; if (Test-Path -LiteralPath $t) { Remove-Item -LiteralPath $t -Recurse -Force }; Expand-Archive -LiteralPath $z -DestinationPath $t; $k=@(Get-ChildItem -LiteralPath $t -Force); if ($k.Count -eq 1 -and $k[0].PSIsContainer) { Move-Item -LiteralPath $k[0].FullName -Destination $d; Remove-Item -LiteralPath $t -Recurse -Force } else { Move-Item -LiteralPath $t -Destination $d }"
if errorlevel 1 (
    echo FEHLER beim Entpacken von %~nx1
    goto :eof
)
echo   ok
set /a NEU_SPIEL+=1
goto :eof
