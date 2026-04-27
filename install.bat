@echo off
setlocal

rem Find git.exe, then derive bash.exe path (<git-prefix>\bin\bash.exe)
for /f "tokens=*" %%G in ('where git 2^>nul') do (
    set "GIT_EXE=%%G"
    goto :found_git
)
echo ERROR: Git for Windows not found. Install it from https://git-scm.com
exit /b 1

:found_git
for %%G in ("%GIT_EXE%") do set "GIT_CMD_DIR=%%~dpG"
set "BASH_EXE=%GIT_CMD_DIR%..\bin\bash.exe"

if not exist "%BASH_EXE%" (
    echo ERROR: bash.exe not found at %BASH_EXE%
    exit /b 1
)

"%BASH_EXE%" "%~dp0install.sh"
endlocal
