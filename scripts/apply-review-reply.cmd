@echo off
setlocal
set "LOGLIFE_BASH_TARGET=%~dp0apply-review-reply.sh"
call "%~dp0windows-run-bash.cmd" %*
exit /b %ERRORLEVEL%
