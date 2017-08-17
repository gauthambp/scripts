'==============================================================================
'
' HP OMW 9.0 Automatic Del Action Script by xMatters, Inc.
' All rights reserved.
' Original Version, June 2007
'
'==============================================================================
' Modification History
'
' Version 1.0  AlarmPoint Systems, Inc., June 2007
' Version 2.0  AlarmPoint Systems, Inc., September 2007
' Version 2.1  AlarmPoint Systems, Inc., November 2007
' Version 2.2  AlarmPoint Systems, Inc., January 2009
' Version 3.0  xMatters, Inc., May 2012
'==============================================================================
'
' Purpose:
'
'	To identify OMW Events that have been forwarded to xMatters for
'	notification, so that they can be deleted within xMatters when they
'	are Acknowledged in the OMW console.
'
'	This script should be called from a WMI Policy that triggers on
'	Events that have been acknowledged.
'
' Parameters:
'	This script requires the Message GUID
'
'==============================================================================

Option Explicit

On Error Resume Next

'------ Globals
Dim logText
Dim oArgs, messageGuid
Dim MsgPath, OV_Message
Dim i, Annotation, AnnoObj, AnnotationText
Dim apomwEnviromentVar
Set OV_Message = Nothing

' Specifies the host name/host ip of the Integration Agent
Const integrationAgentIP = "10.128.15.46"
' Const integrationAgentIP = "172.16.114.107"

' AnnoString must reflect a distinct annotation string from xMatters
' this is used to identify OM-W events that have been forwarded to
' xMatters for notification.
Const AnnoString = "[xMatters-ODP]"
messageGuid = Null

' Debug Parameters
' --------------------------------------------------------------------------------------------
' debugLogLevel  - default is false; shows critical logging only - excludes INFO logging
' (true, false)  - when set to true, shows all messages, including INFO logging
'                - note that INFO messages contain a lot of data and can cause large log files
Dim debugLogLevel
debugLogLevel = true

' Max File Size in bytes (5MB)
Const maxFileSize = 5242880

' This gets the value for the XMOMW enviroment variable set on the host OMW computer (local computer)
' This value is later used for logging the vbs logs into the correct output folder

Dim strComputer, objWMIService, colItems, objItem
strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

Set colItems = objWMIService.ExecQuery("Select VariableValue from Win32_Environment where Name = 'XMOMW'")

For Each objItem in colItems
      apomwEnviromentVar = objItem.VariableValue
Next

logText = "[ INFO ]  XM OMW Enviroment Varraible used for the log directory = " & apomwEnviromentVar
logType = "toFile"
WriteLog


' --------------------------------------------------------------------------
' Check arguments. The message GUID is mandatory.
' --------------------------------------------------------------------------

Set oArgs=WScript.Arguments

If oArgs.Count <> 1 Then
  Usage
Else
  messageGuid = oArgs.Item( 0 )
End If

If Not IsNull(messageGuid) Then
  Const WMIMsg = "WinMgmts:{impersonationLevel=impersonate}!root/HewlettPackard/OpenView/Data:OV_Message.Id="
  MsgPath = WMIMsg & """" & messageGuid & """"
  Set OV_Message = GetObject( MsgPath )

  If Err.Number <> 0 Then
    logText = "[ FATAL ] Unable to find OV_Message Object: " & messageGuid & vbCrLf _
			& "Error Number: " & Err.Number & vbCrLf _
			& "No xMatters Message was sent."
	WriteLog
	Err.clear
	WScript.Quit -1
  Else
    If ( OV_Message.NumberofAnnotations > 0 ) Then
	  logText = "[ INFO ] Number of Annotations: " & OV_Message.NumberofAnnotations
      WriteLog

      For i = 1 to OV_Message.NumberofAnnotations
        Annotation = OV_Message.GetAnnotation( i, AnnoObj ) ' Retrieve individual Annotation Objects from OV_Message Object.
        If Err.Number <> 0 Then
          logText = "[ FATAL ] Unable to retrieve Annotation Object: " & messageGuid & vbCrLf _
		          & "Annotation Number: " & i & vbCrLf _
			      & "Error Number: " & Err.Number & vbCrLf _
			      & "No xMatters Message was sent."
	      WriteLog
		  Err.clear
	      WScript.Quit -1
        Else
		  AnnotationText = AnnoObj.Text
          logText = "[ INFO ] Annotation #" & i & " of " & OV_Message.NumberofAnnotations & " for Message ID: " & messageGuid & " is: " & AnnotationText
          WriteLog

	      If Left( AnnotationText, Len(AnnoString) ) = AnnoString Then
            ' Send Del Event to xMatters for this Event
            logText = " [ INFO ] Sending Del Action to xMatters for Message ID: " & messageGuid
            WriteLog
            injectEvent

			' Remove the AnnoString prefix from Annotation which triggers the submission of Del Events. (Fixes Infinite Looping of Del)
			AnnotationText = Replace( AnnotationText, AnnoString, "[ xMatters-Del ]")
			logText = "[ INFO ] Replaced AnnoString to halt submission of Del Events." & vbCrLf _
			        & "New Annotation String: " & AnnotationText
			WriteLog

			Annotation = OV_Message.ModifyAnnotation( i, AnnotationText)
			If Err.Number <> 0 Then
			  logText = "[ FATAL ] Unable to Modify Annotation for: " & messageGuid & vbCrLf _
					  & "Annotation Number: " & i & vbCrLf _
					  & "Error Number: " & Err.Number & vbCrLf _
			          & "xMatters AnnoString Not Replaced."
	          WriteLog
		      Err.clear
	          WScript.Quit -1
			Else
			  logText = "[ INFO ] Replaced AnnoString to halt submission of Del Events." & vbCrLf _
			          & "Annotation: " & AnnoObj.Text & vbCrLf _
			    	  & "Replaced with: " & AnnotationText
			  WriteLog
			  WScript.Quit(0)
			End If
		  End If
        End If
      Next
    End If
  End If

  logText = "[ INFO ] Message ID: " & messageGuid & " does not appear to have been submitted to xMatters for Notification"
  WriteLog
Else
  logText = "[ FATAL ] Message ID does not exist, Can't retrieve OV_Message Object."
  WriteLog
End If

Set OV_Message = Nothing
Wscript.Quit(0)

'----------------------------------------------------------------------------
' Inject Event - Inject the event's map data into APAgent using the HTTP api.

Sub injectEvent()
    On Error Resume Next

    Dim APAgentURI
    APAgentURI = "http://" & integrationAgentIP & ":2030/agent?"
    Dim MapData

    MapData = "transactionid=" & Int(Timer*Rnd*(Weekday(Date))) & "&mapdata=applications|hpomw&mapdata=del&mapdata=" & messageGuid

    Dim retry, noRetry
    retry = 0
    noRetry = true


    logText = "[ INFO ] HTTP Post: " & APAgentURI & MapData
    logType = "toFile"
    WriteLog

    Do
        ' Create the WinHTTPRequest ActiveX Object.
        Dim HttpReq
        Set HttpReq =  CreateObject("WinHttp.WinHttpRequest.5.1")

        If Err.number <> 0 Then
            noRetry = false
            retry = retry + 1
            exitStatus = Err.number
            logText = "[ FATAL ] Can't Load WinHttp.WinHttpRequest.5.1 Object [" _
                & retry & "] (" & messageGuid & "): " & Err.description
            WriteLog
            Err.clear
        Else
            ' Open an HTTP connection.
            HttpReq.Open "POST", APAgentURI
            HttpReq.setRequestHeader "Content-type", "application/x-www-form-urlencoded"
            If Err.number <> 0 Then
                noRetry = false
                retry = retry + 1
                exitStatus = Err.number
                logText = "[ FATAL ] Can't Open HTTP Connection Object [" _
                    & retry & "] (" & messageGuid & "): " & Err.description
                WriteLog
                Err.clear
            Else
                ' Send the HTTP Request.
                HttpReq.Send MapData
                HttpReq.WaitForResponse

                ' Get all response text.
                Dim Text
                Text = HttpReq.ResponseText
                If Err.number <> 0 Then
                    noRetry = false
                    retry = retry + 1
                    exitStatus = Err.number
                    logText = "[ FATAL ] Failed to perform HTTP request [" _
                        & retry & "] (" & messageGuid & "): " & Err.description
                    WriteLog
                    Err.clear
                End If
            End If
        End If

        Set HttpReq = Nothing

        If retry >= 5 Then
            noRetry = true
        End If

        Err.clear
    Loop Until noRetry

    End Sub

'----------------------------------------------------------------------------
' Write log entry to file.

Sub WriteLog()
  On Error Resume Next

  If (debugLogLevel = true OR (debugLogLevel = false And (Left(logText,8) <> "[ INFO ]") ) ) Then

      Dim strDirectory, strFile, strRollFile
      Dim objFSO, fileSys
      Dim sFile,  objTextFile

      ' Log file roll number
      Dim logNumber
      Dim logCreated

      ' OpenTextFile Method needs a Const value
      ' ForAppending = 8 ForReading = 1, ForWriting = 2
      Const ForAppending = 8
      Const OverwriteExisting = True

      strDirectory = apomwEnviromentVar & "\logs"
      strFile = strDirectory & "\XMOD-Prod-OMW-Forwarded.log"
      strRollFile = strDirectory & "\XMOD-Prod-OMW-Forwarded.log."

      ' Create the File System Objects
      Set objFSO = CreateObject("Scripting.FileSystemObject")
      Set fileSys = CreateObject("Scripting.FileSystemObject")

      ' Check that the strDirectory folder exists
      If Not objFSO.FolderExists(strDirectory) Then
        objFSO.CreateFolder(strDirectory)
      End If

      If Not objFSO.FileExists(strFile) Then
        objFSO.CreateTextFile(strFile)
      End If

      Set sFile = fileSys.GetFile(strFile)

      ' Roll Log if exceeding Max File Size
      If sFile.Size > maxFileSize Then
        logNumber = 0
        logCreated = False

        ' Format the log name to include the current date (mm_dd_yyyy_hh_mm_ss_AM/PM)
        Dim currentDate, currentTime, dateString
        currentDate = FormatDateTime(Date(), 2)
        currentTime = FormatDateTime(Now(), 3)
        dateString = Replace(currentDate,"/","_")
        dateString = dateString & "_" & Replace(currentTime,":","_")
        dateString = Replace(dateString," ","_")

        strRollFile = strRollFile & dateString

        objFSO.CopyFile strFile, strRollFile, True

        ' Delete log file and recreate it.
        objFSO.DeleteFile(strFile)
        objFSO.CreateTextFile(strFile)
      End If

      Set objTextFile = objFSO.OpenTextFile (strFile, ForAppending, True)

      objTextFile.WriteLine("[ " & date() & " " & time() & " ] [ xMatters-ODP ] " & logText)
      objTextFile.Close

  End If

End Sub

'----------------------------------------------------------------------------
' Print Usage Message

Sub Usage ()
  logText = "Usage: omw-forwarded.vbs <Id>" & vbCrLf & vbCrLf &_
            "       <Id> = Id of the OV_Message instance " & vbCrLf

  Wscript.Echo logText
  WriteLog
  WScript.Quit( 1 )
End Sub
