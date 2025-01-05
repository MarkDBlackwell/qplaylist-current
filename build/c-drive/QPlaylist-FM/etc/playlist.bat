@echo off

rem --------------
rem %cd:~0,2% is the current drive:
set original-working-drive=%cd:~0,2%

rem %cd% is the current drive and working directory, without trailing
rem  backslash:
set original-working-location=%cd%

rem %~p0 is the path to the directory containing this Windows batch
rem script. It includes a trailing backslash:
set script-directory-path=%~p0

rem %~dp0 is the drive and path to the directory containing this
rem   Windows batch script. It includes a trailing backslash:
set script-directory-location=%~dp0

rem %~d0 is the drive containing this Windows batch script:
set script-drive=%~d0

rem To access WideOrbit's XML file, which describes the currently
rem  playing song, customize this network drive letter, if necessary:
set WideOrbit-drive=N:

rem --------------
rem WideOrbit file location, without trailing backslash:
set WideOrbit-file-location=%WideOrbit-drive%

rem Configuration files location, with trailing backslash:
set config-files-location=%script-directory-location%

rem --------------
rem FTP command file location, with trailing backslash:
set FTP-location=%config-files-location%

rem Data files location:
set data-location=%WideOrbit-drive%\QPlaylist

rem Mustache files location:
set mustache-location=%data-location%

rem Airshow files location:
set airshows-location=%data-location%

rem Volatile files location:
set volatiles-location=%config-files-location%\..\var

rem --------------
rem HTML files location:
set html-location=%volatiles-location%

rem Program files location:
set program-location=%volatiles-location%

rem WideOrbit NowPlaying XML input file basename:
set now-playing-basename=NowPlaying.xml

rem QPlaylist-runner location:
set qplaylist-runner-location=%WideOrbit-drive%\QPlaylist-runner

rem --------------
rem Process the FM song stream:

rem Navigate in order to copy files:
%script-drive%
cd %volatiles-location%\

rem Compare the NowPlaying XML input file:
fc /b now_playing.xml %WideOrbit-file-location%\%now-playing-basename% > :NULL

rem Quit this script when the song is still the same:
if %errorlevel% == 0 goto :restore

rem Copy input files (keep WideOrbit's file last):
start /wait cmd /C copy /B /Y  %mustache-location%\NowPlaying.mustache          now_playing.mustache
start /wait cmd /C copy /B /Y  %mustache-location%\LatestFive.mustache          latest_five.mustache
start /wait cmd /C copy /B /Y  %mustache-location%\LatestFiveNew.mustache       latest_five_new.mustache
start /wait cmd /C copy /B /Y  %mustache-location%\LatestFive.json.mustache     latest_five.json.mustache
start /wait cmd /C copy /B /Y  %mustache-location%\RecentSongs.mustache         recent_songs.mustache
start /wait cmd /C copy /B /Y  %WideOrbit-file-location%\%now-playing-basename% now_playing.xml

rem Navigate in order to run the Ruby program:
%script-drive%
cd %program-location%\

rem PATH=C:\Ruby\bin;%PATH%
PATH=C:\Ruby32-x64\bin;%PATH%

rem Run the Ruby program:
start /wait cmd /C ruby playlist.rb

rem Quit this script when the song is still the same:
if not %errorlevel% == 0 goto :restore

rem Navigate in order to upload files:
%script-drive%
cd %volatiles-location%\

rem --------------
rem FTP the output to a webserver computer:
rem start /wait cmd /C ftp -s:%FTP-location%playlist.ftp
rem start /wait cmd /C ruby c:\progra\QPlaylist-ftp\QPlaylist-ftp.rb %FTP-location%playlist.ftp
start /wait cmd /C C:\Windows\System32\ftp.exe -v -s:%FTP-location%playlist.ftp

rem --------------
rem In the parent console, restore the original working location:
:restore
%original-working-drive%
cd %original-working-location%\

rem --------------
rem Close the window (and return):
exit
