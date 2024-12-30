rem Author: Mark D. Blackwell
rem Change dates:
rem November 13, 2013 - created
rem
rem Usage:
rem   live-update.vbs {file path of WideOrbit-generated file, NowPlaying.xml}
rem Usage example:
rem   live-update.vbs "N:\NowPlaying.xml"
rem
rem WideOrbit is a large software system used in radio station automation.
rem
rem==============
rem References:
rem   http://www.devguru.com/technologies/VBScript/14075
rem   http://rosettacode.org/wiki/Here_document#VBScript
rem   http://wiki.mcneel.com/developer/vbsstatements

Const CharSpace = " "
Const CreateIfNotExist = True
Const ErrorExitCodeFileNonexistent = 3
Const ErrorExitCodeFilePathBad = 2
Const ErrorExitCodeMissingArgument = 1
Const FilePathXmlArgumentPosition = 0
Const ForWriting = 2
Const MessageMissing = "The required command-line argument is missing"
Const MessageNonexistent = "Specified by a command-line argument, the file is nonexistent"
Const MessageTerminating = "...terminating."
Const OpenAsAscii = 0
Const PromptPrefix = "Current Song "

Dim artist
Dim artistRaw
Dim filePathXml
Dim n
Dim objFilesys
Dim objOutputTextFileHandleXml
Dim outputStringXml
Dim promptArtist
Dim promptTitle
Dim startupMessage
Dim stringOne
Dim stringThree
Dim stringTwo
Dim title
Dim titleRaw

n = Chr(13) & Chr(10)

startupMessage = _
"Website Playlist Manual Update Program. " & _
"Hit Ctrl-C to end." & n & n & _
"Please enter..." & n

promptArtist = PromptPrefix & "Artist: "
promptTitle  = PromptPrefix &  "Title: "

rem Most of the XML fields below are ignored by the Simple XML parser, but are included here for completeness:

stringOne = _
"<?xml version='1.0' encoding='ISO-8859-1'?>"              & n & _
"<?xml-stylesheet type='text/xsl' href='NowPlaying.xsl'?>" & n & _
"<NowPlaying>"                     & n & _
"<Call>WTMD-FM</Call>"             & n & _
"<Events>"                         & n & _
"<SS32Event pos='0' valid='true'>" & n & _
_
"<CatId>MUS</CatId>"               & n & _
"<CutId>00PB</CutId>"              & n & _
"<Type>SONG</Type>"                & n & _
"<SecondsRemaining>  </SecondsRemaining>"  & n & _
"<Title><![CDATA["

stringTwo = _
"]]></Title>"       & n & _
"<Artist><![CDATA["

stringThree = _
"]]></Artist>"              & n & _
"<Intro>00</Intro>"         & n & _
"<Len>04:57</Len>"          & n & _
"<Raw><![CDATA[ ]]></Raw>"  & n & _
_
"</SS32Event>"              & n & _
"</Events>"                 & n & _
"</NowPlaying>"

If WScript.Arguments.Count < 1 Then
    WScript.StdOut.Write _
    MessageMissing & _
    MessageTerminating & n
    WScript.Quit(ErrorExitCodeMissingArgument)
End If

Set objFilesys = CreateObject("Scripting.FileSystemObject")

filePathXml = WScript.Arguments(FilePathXmlArgumentPosition)

rem Normally, this file will exist, already.
rem (So, this check helps us to validate the argument.):

If Not objFilesys.FileExists(filePathXml) Then
    WScript.StdOut.Write _
    MessageNonexistent & _
    MessageTerminating & n
    WScript.Quit(ErrorExitCodeFileNonexistent)
End If

WScript.StdOut.Write startupMessage

Do While True
    WScript.StdOut.Write promptTitle
    titleRaw = WScript.StdIn.ReadLine

    WScript.StdOut.Write promptArtist
    artistRaw = WScript.StdIn.ReadLine

    artist = Trim(Replace(artistRaw, vbTab, CharSpace))
    title  = Trim(Replace(titleRaw,  vbTab, CharSpace))

    outputStringXml = _
      stringOne    & title  & _
      stringTwo    & artist & _
      stringThree  & n

    Set objOutputTextFileHandleXml    = objFilesys.OpenTextFile(filePathXml,    ForWriting, CreateIfNotExist, OpenAsAscii)

    objOutputTextFileHandleXml.Write    outputStringXml

    objOutputTextFileHandleXml.Close

    WScript.StdOut.Write "Updated." & n & n
Loop
