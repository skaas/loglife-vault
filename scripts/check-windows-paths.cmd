@echo off
setlocal
set "LOGLIFE_BASH_TARGET=%~dp0check-windows-paths.sh"
call "%~dp0windows-run-bash.cmd" %*
exit /b %ERRORLEVEL%
