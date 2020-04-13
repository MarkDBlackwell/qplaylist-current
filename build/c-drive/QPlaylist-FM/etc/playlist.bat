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
set WideOrbit-drive=z:

rem --------------
rem WideOrbit file location, without trailing backslash:
set WideOrbit-file-location=%WideOrbit-drive%

rem Configuration files location, with trailing backslash:
set config-files-location=%script-directory-location%

rem --------------
rem FTP command file location, with trailing backslash:
set FTP-location=%config-files-location%

rem Mustache files location:
set mustache-location=%WideOrbit-drive%\Qplaylist

rem Volatile files location:
set volatiles-location=%config-files-location%\..\var

rem --------------
rem HTML files location:
set html-location=%volatiles-location%

rem Program files location:
set program-location=%volatiles-location%

rem --------------
rem Process the FM song stream:

rem Navigate in order to copy files:
%script-drive%
cd %volatiles-location%\

rem Copy input files (keep WideOrbit's file last):
start /wait cmd /C copy /Y  %mustache-location%\NowPlaying.mustache      now_playing.mustache
start /wait cmd /C copy /Y  %mustache-location%\LatestFive.mustache      latest_five.mustache
start /wait cmd /C copy /Y  %mustache-location%\RecentSongs.mustache     recent_songs.mustache
start /wait cmd /C copy /Y  %WideOrbit-file-location%\NowPlaying.XML     now_playing.xml

rem Navigate in order to run the Ruby program:
%script-drive%
cd %program-location%\

rem Run the Ruby program:
start /wait cmd /C ruby playlist.rb

rem Navigate in order to copy files:
%script-drive%
cd %volatiles-location%\

rem Copy output files:
start /wait cmd /C copy /Y  now_playing.html   %html-location%\NowPlaying.html
start /wait cmd /C copy /Y  latest_five.html   %html-location%\LatestFive.html
start /wait cmd /C copy /Y  recent_songs.html  %html-location%\RecentSongs.html

rem --------------
rem FTP the output to a webserver computer:
start /wait cmd /C ftp -s:%FTP-location%playlist.ftp

rem --------------
rem In the parent console, restore the original working location:
%original-working-drive%
cd %original-working-location%\

rem --------------
rem Close the window (and return):
exit
