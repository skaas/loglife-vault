@echo off
setlocal

if not defined LOGLIFE_BASH_TARGET (
  >&2 echo windows wrapper: LOGLIFE_BASH_TARGET is not set.
  exit /b 1
)

set "BASH_EXE="
for %%I in (bash.exe) do (
  if not "%%~$PATH:I"=="" set "BASH_EXE=%%~$PATH:I"
)

if not defined BASH_EXE if defined ProgramW6432 if exist "%ProgramW6432%\Git\bin\bash.exe" set "BASH_EXE=%ProgramW6432%\Git\bin\bash.exe"
if not defined BASH_EXE if defined ProgramFiles if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH_EXE if defined ProgramFiles(x86) if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH_EXE=%ProgramFiles(x86)%\Git\bin\bash.exe"

if not defined BASH_EXE (
  >&2 echo windows wrapper: bash.exe not found. Install Git for Windows and add bash.exe to PATH.
  exit /b 1
)

"%BASH_EXE%" "%LOGLIFE_BASH_TARGET%" %*
exit /b %ERRORLEVEL%
