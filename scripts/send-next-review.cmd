@echo off
setlocal
set "LOGLIFE_BASH_TARGET=%~dp0send-next-review.sh"
call "%~dp0windows-run-bash.cmd" %*
exit /b %ERRORLEVEL%
