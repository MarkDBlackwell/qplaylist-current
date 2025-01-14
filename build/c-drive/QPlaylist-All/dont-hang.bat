@echo off

rem Author: Mark D. Blackwell (google me)
rem May 16, 2016 - created
rem August 22, 2017 - prevent infinite recursion

rem --------------
rem Prevent accidental, infinite recursion when renaming files:
if NOT DEFINED guard goto :after_guard
echo Already running
timeout 5
exit
:after_guard
set guard=running

rem %cd:~0,2% is the current drive:
set original_working_drive=%cd:~0,2%

rem %cd% is the current drive and working directory, without trailing
rem  backslash:
set original_working_location=%cd%

rem %~d0 is the drive containing this Windows batch script:
set script_drive=%~d0

rem %~p0 is the path to the directory containing this Windows batch
rem script. It includes a trailing backslash:
set script_directory_path=%~p0

rem --------------
rem Navigate to the directory containing the QPlaylist batch file:
%script_drive%
cd %script_directory_path%

rem To make Windows Task Scheduler think the task is completed,
rem don't say "/wait" here:
start %COMSPEC% /c playlist.bat

rem --------------
rem In the parent console, restore the original working drive and directory:
%original_working_drive%
cd %original_working_location%\
