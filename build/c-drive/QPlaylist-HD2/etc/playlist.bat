@echo off

rem Author: Mark D. Blackwell (google me)
rem October 9, 2013 - created
rem October 10, 2013 - comment out firewall-blocked ftp
rem November 8, 2013 - Set variable for server drive
rem April 20, 2016 - Allow Git updating
rem September 24, 2021 - Windows command detects NowPlaying change

rem --------------
rem Description:
rem  This Windows batch file:
rem 1. Compares the NowPlaying XML input file;
rem 2. If unchanged, it exits immediately;
rem 3. Obtains the input files for a certain program;
rem 4. Runs that program;
rem 5. Copies the program's output files to another directory (wherever
rem    desired);
rem 6. Runs an FTP program to upload those output files.

rem This batch file, along with the associated program and its input
rem  and output files, should not reside on a WideOrbit server
rem  computer. The purpose of this recommendation is in order to
rem  minimize this software's drag on WideOrbit's resources.

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
rem Process the HD2 song stream:

rem Navigate in order to copy files:
%script-drive%
cd %volatiles-location%\

rem Compare the NowPlaying XML input file:
fc /b now_playing.xml %WideOrbit-file-location%\NowPlayingHD2.XML > :NULL

rem Quit this script when the song is still the same:
if %errorlevel% == 0 goto :restore

rem Copy input files (keep WideOrbit's file last):
start /wait cmd /C copy /Y  %mustache-location%\NowPlaying.mustache      now_playing.mustache
start /wait cmd /C copy /Y  %mustache-location%\LatestFive.mustache      latest_five.mustache
start /wait cmd /C copy /Y  %mustache-location%\LatestFive.json.mustache latest_five.json.mustache
start /wait cmd /C copy /Y  %mustache-location%\RecentSongs.mustache     recent_songs.mustache
start /wait cmd /C copy /Y  %WideOrbit-file-location%\NowPlayingHD2.XML  now_playing.xml

rem Navigate in order to run the Ruby program:
%script-drive%
cd %program-location%\

rem Run the Ruby program:
start /wait cmd /C ruby playlist.rb

rem Quit this script when the song is still the same:
if not %errorlevel% == 0 goto :restore

rem Navigate in order to copy files:
%script-drive%
cd %volatiles-location%\

rem --------------
rem FTP the output to a webserver computer:
rem start /wait cmd /C ftp -s:%FTP-location%playlist.ftp
start /wait cmd /C ruby c:\progra\QPlaylist-ftp\QPlaylist-ftp.rb %FTP-location%playlist.ftp

rem --------------
rem In the parent console, restore the original working location:
:restore
%original-working-drive%
cd %original-working-location%\

rem --------------
rem Close the window (and return):
exit
