@echo off

rem Author: Mark D. Blackwell (google me)
rem April 20, 2016 - created

rem --------------
rem Description:
rem  This Windows batch file:
rem    1. Runs a batch file for each song stream (e.g., FM and HD2);
rem    2. Resides in a directory separate from those of the song
rem       streams.

rem --------------
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
rem Process the FM song stream:

rem Navigate to the directory containing the song stream's batch file:
%script_drive%
cd %script_directory_path%..\QPlaylist-FM\etc\

start /wait playlist.bat

rem --------------
rem Process the HD2 song stream:

rem Navigate to the directory containing the song stream's batch file:
%script_drive%
cd %script_directory_path%..\QPlaylist-HD2\etc\

start /wait playlist.bat

rem --------------
rem In the parent console, restore the original working drive and directory:
%original_working_drive%
cd %original_working_location%\
