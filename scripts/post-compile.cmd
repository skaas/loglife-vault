@echo off
setlocal
set "LOGLIFE_BASH_TARGET=%~dp0post-compile.sh"
call "%~dp0windows-run-bash.cmd" %*
exit /b %ERRORLEVEL%
