@echo off
setlocal
set "LOGLIFE_BASH_TARGET=%~dp0build-calendar-candidates.sh"
call "%~dp0windows-run-bash.cmd" %*
exit /b %ERRORLEVEL%
