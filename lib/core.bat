@echo off
if "%~1" neq "" goto %~1

rem --- Configuration Monochrome ---
for /f %%A in ('echo prompt $E ^| cmd') do set "ESC=%%A"
set "white=%ESC%[97m"
set "reset=%ESC%[0m"

rem Definition du Carriage Return
for /f %%a in ('copy /z "%~dpnx0" nul') do set "CR=%%a"

exit /b 0

:display_header
set "htitle=%~2"
set "hicon=%~3"
cls
echo %white%
echo  ----------------------------------------------------------------------------
echo                             [ %hicon% ] %htitle%
echo  ----------------------------------------------------------------------------
echo %reset%
goto :eof

:loading
set "ltext=%~2"
set "ldur=%~3"
if "%ldur%"=="" set "ldur=5"
set /a i_count=0
:l_loop
set /a p_val=i_count*100/ldur
set "b_str="
set /a b_len=p_val/5
for /l %%k in (1,1,%b_len%) do set "b_str=!b_str!*"
set /a e_len=20-b_len
for /l %%k in (1,1,%e_len%) do set "b_str=!b_str!-"
<nul set /p "=%white%  %ltext%... [%b_str%] %p_val%%%!CR!"
if %i_count% geq %ldur% goto :l_done
timeout /t 1 >nul
set /a i_count+=1
goto :l_loop
:l_done
echo.
echo   OK
timeout /t 1 >nul
goto :eof

:log
set "log_lvl=%~2"
set "log_msg=%~3"
if not exist "logs" mkdir "logs"
echo [%date% %time%] [%log_lvl%] %log_msg% >> logs\system.log
goto :eof

:check_admin
net session >nul 2>&1
exit /b %ERRORLEVEL%
