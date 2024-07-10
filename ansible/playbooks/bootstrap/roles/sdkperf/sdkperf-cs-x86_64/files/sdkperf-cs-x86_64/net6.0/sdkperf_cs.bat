@echo off
where dotnet || goto NO_DOTNET

SETLOCAL EnableDelayedExpansion

set APP_DIR=%~dp0
set CURRENT_DIR=%cd%

set PATH=%APP_DIR%\runtimes\win-x64\native;%APP_DIR%\runtimes\win-x86\native;%PATH%

dotnet %APP_DIR%\sdkperf_cs.dll %* || goto EXIT_ERROR

goto EXIT_CLEAN

:NO_DOTNET
echo Missing dotnet core runtime From PATH

:EXIT_ERROR
ENDLOCAL
exit /b 1

:EXIT_CLEAN
ENDLOCAL
exit /b 0