'==============================================================================
'
' HP OMW 9.0 Enrichment Script by xMatters, Inc.
' All rights reserved.
' Original Version, August 2006
'
'==============================================================================
' Modification History
'
' Version 1.0  AlarmPoint Systems, Inc., August 2006
' Version 1.1  AlarmPoint Systems, Inc., March 2007
' Version 2.0  AlarmPoint Systems, Inc., September 2007
' Version 2.1  AlarmPoint Systems, Inc., November 2007
' Version 2.2  AlarmPoint Systems, Inc., January 2009
' Version 2.3  AlarmPoint Systems, Inc., September 2010
' Version 2.4  AlarmPoint Systems, Inc., November 2010
' Version 3.0  xMatters, Inc., May 2012
'==============================================================================
'
' Purpose:
'
'    HP Operations Manager does not have access to the Node name that was the source
'    of the event in need of resolution via xMatters.
'
'    The purpose of this script is to enrich the data coming from the HP/OM
'    for Windows policy to include the events primary node. All other
'    enrichment. is performed by the Input Action Scripting to limit the scope
'    of this script.
'
'    This script handles event injection only.
'
'==============================================================================

Option Explicit

On Error Resume Next

'------ Globals
Dim apdt_agent_client_id
Dim apdt_situation
Dim apdt_severity
Dim apdt_incident_id
Dim apdt_msg_text
Dim apdt_message_group
Dim apdt_application
Dim apdt_msg_object
Dim apdt_msg_time_created
Dim apdt_msg_time_received
Dim apdt_msg_service_id
Dim apdt_msg_source
Dim apdt_node_id
Dim apdt_node
Dim apdt_node_text
Dim apdt_node_groups
Dim apdt_fyi
Dim messageGuid
Dim apomwEnviromentVar
messageGuid = Null
Dim args, argNum, exitStatus
Const list_item_delimiter = ","

' Specifies the host name/host ip of the Integration Agent
Const integrationAgentIP = "10.128.15.46"
' Const integrationAgentIP = "172.16.114.107"

' Debug Parameters
' When calling the WriteLog Method the logType should be specified,
' "toFile" - Log text to Log File
' "toEvent" - Log text as annotate on original OM-W Event
' "toBoth" - Log text to File and annotate original OM-W Event
' Anything else disables logging behaviour.
' --------------------------------------------------------------------------------------------
' debugLogLevel  - default is false; shows critical logging only - excludes INFO logging
' (true, false)  - when set to true, shows all messages, including INFO logging
'                - note that INFO messages contain a lot of data and can cause large log files
Dim logType, logText, debugLogLevel
logType = "toFile"
debugLogLevel = true

' Max File Size in bytes (5MB)
Const maxFileSize = 5242880


exitStatus = 0
Set args = WScript.Arguments
argNum = args.Count

'----------------------------------------------------------------------------
' Regular Expression to get rid of newlines
' re.Pattern = "[^\r\n\t\x20-\x7e]"
' Alter as required to preserve formatting of source messages
'----------------------------------------------------------------------------
Dim re
Set re = new regexp
re.Pattern = "[^\r\n\t\x20-\x7e]"
' The above pattern allows all valid XML ASCII character through
re.IgnoreCase = True
re.Global = True
'----------------------------------------------------------------------------

'------ Start Main Exectution
Main
WSScript.Echo(exitStatus)
WScript.Quit exitStatus

'----------------------------------------------------------------------------
' Main

Sub Main()
    On Error Resume Next
    getEnviromentVar
    processArguments
    retrieveNodeAndNodeGroups
    injectEvent
	logText = "Event submitted to xMatters OnDemand for Notification"
	logType = "toBoth"
	WriteLog
End Sub

' This function gets the value for the XMOMW enviroment variable set on the host OMW computer (local computer)
' This value is later used for logging the vbs logs into the correct output folder
Sub getEnviromentVar()

  Dim strComputer, objWMIService, colItems, objItem
  strComputer = "."
  Set objWMIService = GetObject("winmgmts:" _
      & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

  Set colItems = objWMIService.ExecQuery("Select VariableValue from Win32_Environment where Name = 'XMOMW'")

  For Each objItem in colItems
      	apomwEnviromentVar = objItem.VariableValue
  Next

  logText = "[ INFO ]  AP OMW Environment Variable used for the log directory = " & apomwEnviromentVar
  logType = "toBoth"
  WriteLog

End Sub

'----------------------------------------------------------------------------
' Process Arguments - extract the data map values
'
' The expected policy command for this sub is:
'
' cmd /c cscript.exe /NoLogo "C:\APAgent\omw-xmod-prod.vbs"
'     	"hpomw"
'     	"OPERATIONS MANAGER EVENT"
'     	fyi [yes, no]
'     	"<$WBEM:TargetInstance.Severity>"
'     	"<$WBEM:TargetInstance.Id>"
'     	"<$WBEM:TargetInstance.MessageGroup>"
'     	"<$WBEM:TargetInstance.NodeName>"
'     	"<$WBEM:TargetInstance.Application>"
'     	"<$WBEM:TargetInstance.Object>"
'     	"<$WBEM:TargetInstance.TimeCreated>"
'     	"<$WBEM:TargetInstance.TimeReceived>"
'     	"<$WBEM:TargetInstance.ServiceId>"
'     	"<$WBEM:TargetInstance.Source>"


Sub ProcessArguments()
    On Error Resume Next

    apdt_agent_client_id    = Trim( args.Item( 0 ) )
    apdt_situation          = Trim( args.Item( 1 ) )
    apdt_fyi				= Trim( args.Item( 2 ) )
    apdt_severity           = Trim( Left(args.Item( 3 ), 2 ) )
    apdt_incident_id        = Trim( args.Item( 4 ) )
    apdt_message_group      = Trim( args.Item( 5 ) )
    apdt_node_id            = Trim( args.Item( 6 ) )
    apdt_application        = Trim( args.Item( 7 ) )
    apdt_msg_object         = Trim( args.Item( 8 ) )
    apdt_msg_time_created   = Trim( args.Item( 9 ) )
    apdt_msg_time_received  = Trim( args.Item( 10 ) )
    apdt_msg_service_id     = Trim( args.Item( 11 ) )
    apdt_msg_source         = Trim( args.Item( 12 ) )


    logText = "[ INFO ] Arguments sent from OMW Policy to omw-xmod-prod.vbs: " & _
    "Arg0 = " & Trim( args.Item( 0 ) ) & _
    " Arg1 = " & Trim( args.Item( 1 ) ) & _
    " Arg2 = " & Trim( args.Item( 2 ) ) & _
    " Arg3 = " & Trim( Left(args.Item( 3 ), 2 ) ) & _
    " Arg4 = " & Trim( args.Item( 4 ) ) & _
    " Arg5 = " & Trim( args.Item( 5 ) ) & _
    " Arg6 = " & Trim( args.Item( 6 ) ) & _
    " Arg7 = " & Trim( args.Item( 7 ) ) & _
    " Arg8 = " & Trim( args.Item( 8 ) ) & _
    " Arg9 = " & Trim( args.Item( 9 ) ) & _
    " Arg10 = " & Trim( args.Item( 10 ) ) & _
    " Arg11 = " & Trim( args.Item( 11 ) ) & _
    " Arg12 = " & Trim( args.Item( 12 ) )

    logType = "toEvent"
    WriteLog

	messageGuid = apdt_incident_id

    If Err.number <> 0 Then
        exitStatus = Err.number
        logText = "[ FATAL ]  Not enough arguments (" & apdt_incident_id & _
            " - " & apdt_msg_time_created & " - " & apdt_message_group & " - " & _
            apdt_application & "): " & Err.description
		logType = "toBoth"
        WriteLog
        Err.clear
    End If

    ' Map the numeric severity to a meaningful value
    Select Case apdt_severity
    Case 2
    	apdt_severity = "normal"
    Case 4
    	apdt_severity = "warning"
    Case 8
    	apdt_severity = "minor"
    Case 16
    	apdt_severity = "major"
    Case 32
    	apdt_severity = "critical"
    Case Else	' Handle unknown values
     	apdt_severity = "critical"
    End Select

End Sub

'----------------------------------------------------------------------------
' Retrieve Primary Node Name and List of Associated Node Groups
' - This Loads WMI Objects to obtain the primary node name (the source of the event).
' - Also retrieves the list of associated node groups from the WMI Objects.

Sub retrieveNodeAndNodeGroups()
    On Error Resume Next

    Const HPWMIMoniker = "WinMgmts:{impersonationLevel=impersonate}!root/HewlettPackard/OpenView/Data"
    Dim HPWMIMessageMoniker
    HPWMIMessageMoniker = HPWMIMoniker & ":OV_Message.Id="
    Dim HPWMINodeMoniker
    HPWMINodeMoniker = HPWMIMoniker & ":OV_ManagedNode.Name="
    Dim HPWMIExternalNodeMoniker
    HPWMIExternalNodeMoniker = HPWMIMoniker & ":OV_ExternalNode.Name="

    Dim HPWMIMessagePath, HPWMINodePath, HPWMIExternalNodePath
    Dim HPWMIMessageObject, HPWMINodeObject, HPWMIExternalNode
    Dim nodeGuid
    HPWMIExternalNode = false

	Dim HPWMINodeAssociators, HPWMIAssociator, NodeGroupNames

    Dim retry, noRetry
    retry = 0
    noRetry = true

    Do
	    ' Clear error and retry
		  Err.clear
	    noRetry = True

        ' Load HP WMI Message Object
        HPWMIMessagePath = HPWMIMessageMoniker & """" & messageGuid & """"
        Set HPWMIMessageObject = GetObject(HPWMIMessagePath)
        If Err.number <> 0 Then
            noRetry = false
            retry = retry + 1
            exitStatus = Err.number
            logText = "[ FATAL ]  Can't Load HP OMW WMI Message Object [" & retry _
                & "] (" & apdt_incident_id & " - " & apdt_msg_time_created & _
                " - " & apdt_message_group & " - " & apdt_application & _
                "): " & Err.description
			logType = "toBoth"
            WriteLog
            Err.clear
            apdt_node = "unknown0"
			apdt_node_groups = "unknown0"
        Else
            ' Get original message text and use RegExp to get rid of carriage return/line feed characters
            apdt_msg_text = re.replace( Trim( HPWMIMessageObject.Text ), " " )
			logText = "[ INFO ] Injected Event Message: " & apdt_msg_text
			logType = "toFile"
			WriteLog

			' Load HP WMI Node or External Node Object
      nodeGuid = HPWMIMessageObject.NodeName
      HPWMINodePath = HPWMINodeMoniker & """" & nodeGuid & """"
      Set HPWMINodeObject = GetObject(HPWMINodePath)
      If Err.number <> 0 Then
        ' If the Node fails to load see if it is an External Node
        Err.clear
        HPWMIExternalNodePath = HPWMIExternalNodeMoniker & """" & nodeGuid & """"
        Set HPWMINodeObject = GetObject(HPWMIExternalNodePath)

        If Err.number <> 0 Then
          noRetry = false
          retry = retry + 1
          exitStatus = Err.number
          logText = "[ FATAL ]  Can't Load HP OMW WMI Node or External Node Object [" & _
              retry & "] ("  & nodeGuid & " - " & apdt_incident_id & " - " & _
              apdt_msg_time_created & " - " & apdt_message_group & " - " & _
              apdt_application & "): " & Err.description
          logType = "toBoth"
          WriteLog
          Err.clear
          apdt_node = "unknown0"
          apdt_node_groups = "unknown0"
        Else
          apdt_node = HPWMINodeObject.Caption
          apdt_node_text = HPWMINodeObject.Description
          If (apdt_node_text Is Nothing) Then  ' Description is not required, if it is not set use the Node Caption
            apdt_node_text = apdt_node
          End If
          HPWMIExternalNode = true
          logText = "[ INFO ] Associated External Node: " & apdt_node & " Associated External Node Text: " & apdt_node_text
          logType = "toFile"
          WriteLog
        End If
      Else
        apdt_node = HPWMINodeObject.PrimaryNodeName
        apdt_node_text = HPWMINodeObject.Caption
        logText = "[ INFO ] Associated Node: " & apdt_node & " Associated Node Text: " & apdt_node_text
        logType = "toFile"
        WriteLog
      End If
      If HPWMIExternalNode = false Then


			' Retrieve Associated Node Groups
			Set NodeGroupNames = ""
			Set HPWMINodeAssociators = HPWMINodeObject.Associators_
			For Each HPWMIAssociator In HPWMINodeAssociators
				' only evaluate nodegroup associators
				If InStr(HPWMIAssociator.path_,"NodeGroup.Name") Then
        			If HPWMIAssociator.Caption <> "null" And HPWMIAssociator.Caption <> "" Then
					    logText = "[ INFO ] Associated Node Group Name: " & HPWMIAssociator.Caption
						logType = "toFile"
						WriteLog
						If NodeGroupNames = "" Then
							NodeGroupNames = HPWMIAssociator.Caption
						Else
							NodeGroupNames = NodeGroupNames & list_item_delimiter & HPWMIAssociator.Caption
						End If
					End If
				End If
			Next
        If Err.number <> 0 Then
            noRetry = false
            retry = retry + 1
            exitStatus = Err.number
            logText = "[ FATAL ]  Can't Load HP OMW WMI Node Group Associators [" & _
                retry & "] (" & apdt_incident_id & " - " & _
                apdt_msg_time_created & " - " & apdt_message_group & " - " & _
                apdt_application & "): " & Err.description

            logType = "toBoth"
            WriteLog
            Err.clear
            apdt_node_groups = "unknown0"
          Else
            logText = "[ INFO ] Associated Node Group List: " & NodeGroupNames
            WriteLog
            logType = "toFile"
            apdt_node_groups = NodeGroupNames
          End If
      Else
          apdt_node_groups = "External Node"
          apdt_msg_source = "unknown0"
          apdt_msg_service_id = ""
      End If
    End If

    Set HPWMIMessageObject = Nothing
    Set HPWMINodeObject = Nothing
    Set HPWMINodeAssociators = Nothing
    Set HPWMIExternalNodeObject = Nothing

    If retry >= 5 Then
        noRetry = true
    End If

    Loop Until noRetry

    End Sub

'----------------------------------------------------------------------------
' Inject Event - Inject the event's map data into APAgent using the HTTP api.

Sub injectEvent()
    On Error Resume Next
    Dim APAgentURI
    APAgentURI = "http://" & integrationAgentIP & ":2030/agent?"
    Const MapDataURI = "mapdata="

    Dim MapData

    ' The actual agent client id map must follow this order
    MapData = "transactionid=" & Int(Timer*Rnd*(Weekday(Date)))
    MapData = MapData & "&" & MapDataURI & "applications|" & apdt_agent_client_id
    MapData = MapData & "&" & MapDataURI & "add"
    MapData = MapData & "&" & MapDataURI & Escape( apdt_incident_id )
    MapData = MapData & "&" & MapDataURI & Escape( apdt_situation )
	  ' Node Name must be repeated 4 times, as it is required in 4 different apdt variables for the custom subscription panel
    MapData = MapData & "&" & MapDataURI & Escape( apdt_node )			' Derived Node Name, if we were able to retrieve it
    MapData = MapData & "&" & MapDataURI & Escape( apdt_node_text )			' Derived Node Name, if we were able to retrieve it
    MapData = MapData & "&" & MapDataURI & Escape( apdt_node_groups )	' Derived Node Groups List, if we were able to retrieve it
    MapData = MapData & "&" & MapDataURI & Escape( list_item_delimiter )' The delimiter separating the values of the Node Groups List
    MapData = MapData & "&" & MapDataURI & Escape( apdt_node_groups )	' Derived Node Groups List, if we were able to retrieve it
    MapData = MapData & "&" & MapDataURI & Escape( list_item_delimiter )' The delimiter separating the values of the Node Groups List
    MapData = MapData & "&" & MapDataURI & Escape( apdt_severity )
    MapData = MapData & "&" & MapDataURI & Escape( apdt_msg_text )
    MapData = MapData & "&" & MapDataURI & Escape( apdt_message_group ) ' xMatters Recipient targeted using associated message group
    MapData = MapData & "&" & MapDataURI & Escape( apdt_message_group ) ' Message Group used for subscriptions to match against
    MapData = MapData & "&" & MapDataURI & Escape( apdt_node_id )
    MapData = MapData & "&" & MapDataURI & Escape( apdt_application )
    MapData = MapData & "&" & MapDataURI & Escape( apdt_msg_object )
    MapData = MapData & "&" & MapDataURI & Escape( apdt_msg_time_created )
    MapData = MapData & "&" & MapDataURI & Escape( apdt_msg_time_received )
    MapData = MapData & "&" & MapDataURI & Escape( apdt_msg_service_id )
    MapData = MapData & "&" & MapDataURI & Escape( apdt_msg_source )
    MapData = MapData & "&" & MapDataURI & Escape( apdt_fyi )


    logText = "[ INFO ] Arguments sent to APJC via HTTP Post: " & _
    " event_type = " & "add" & _
    " apdt_incident_id = " & apdt_incident_id & _
    " apdt_situation = " & apdt_situation & _
    " apdt_node = " & apdt_node & _
    " apdt_node_text = " & apdt_node_text & _
    " apdt_node_groups = " & apdt_node_groups & _
    " list_item_delimiter = " & list_item_delimiter & _
    " apdt_node_groups = " & apdt_node_groups & _
    " apdt_node_groups = " & apdt_node_groups & _
    " list_item_delimiter = " & list_item_delimiter & _
    " apdt_severity = " & apdt_severity & _
    " apdt_msg_text = " & apdt_msg_text & _
    " apdt_message_group = " & apdt_message_group & _
    " apdt_message_group = " & apdt_message_group & _
    " apdt_node_id = " & apdt_node_id & _
    " apdt_application = " & apdt_application & _
    " apdt_msg_object = " & apdt_msg_object & _
    " apdt_msg_time_created = " & apdt_msg_time_created & _
    " apdt_msg_time_received = " & apdt_msg_time_received & _
    " apdt_msg_service_id = " & apdt_msg_service_id & _
    " apdt_msg_source = " & apdt_msg_source & _
    " apdt_fyi = " & apdt_fyi
    logType = "toFile"
    WriteLog

    logText = "[ INFO ] HTTP Post: " & APAgentURI & MapData
    logType = "toFile"
    WriteLog

    Dim retry, noRetry
    retry = 0
    noRetry = true

    Do
	    ' Clear error and retry
       Err.clear
		   noRetry = True

        ' Create the WinHTTPRequest ActiveX Object.
        Dim HttpReq
        Set HttpReq =  CreateObject("WinHttp.WinHttpRequest.5.1")

        If Err.number <> 0 Then
            noRetry = false
            retry = retry + 1
            exitStatus = Err.number
            logText = "[ FATAL ]  Can't Load WinHttp.WinHttpRequest.5.1 Object [" _
                & retry & "] (" & apdt_incident_id & " - " & apdt_node & _
                apdt_msg_time_created & " - " & apdt_message_group & " - " & _
                apdt_application & "): " & Err.description
			logType = "toBoth"
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
                logText = "[ FATAL ]  Can't Open HTTP Connection Object [" _
                    & retry & "] (" & apdt_incident_id & " - " & apdt_node _
                    & apdt_msg_time_created & " - " & apdt_message_group & " - " & _
                    apdt_application & "): " & Err.description
				logType = "toBoth"
                WriteLog
                Err.clear
            Else
                ' Send the HTTP Request.
                HttpReq.Send MapData
                HttpReq.WaitForResponse

				        If Err.number <> 0 Then
                    noRetry = False
                    retry = retry + 1
                    exitStatus = Err.number
                    logText = "[ FATAL ]  Failed to send HTTP request [" _
                        & retry & "] (" & apdt_incident_id & " - " & _
                        apdt_node & apdt_msg_time_created & " - " & _
                        apdt_message_group & " - " & apdt_application & "): " _
                        & Err.description
					          logType = "toBoth"
                    WriteLog
                    Err.clear
                Else
                ' Get all response text.
                Dim Text
                Text = HttpReq.ResponseText
                If Err.number <> 0 Then
                    noRetry = false
                    retry = retry + 1
                    exitStatus = Err.number
						logText = "[ FATAL ]  Failed to get HTTP response [" _
                        & retry & "] (" & apdt_incident_id & " - " & _
                        apdt_node & apdt_msg_time_created & " - " & _
                        apdt_message_group & " - " & apdt_application & "): " _
                        & Err.description
					logType = "toBoth"
                    WriteLog
                    Err.clear
                End If
            End If
        End If
        End If

        Set HttpReq = Nothing

        If retry >= 5 Then
            noRetry = true
        End If

    Loop Until noRetry

    End Sub

'----------------------------------------------------------------------------
' Determine Logging Behaviour

Sub WriteLog()
  On Error Resume Next
  If (debugLogLevel = true OR (debugLogLevel = false And (Left(logText,8) <> "[ INFO ]") ) ) Then
      Select Case logType

        Case "toFile"
          LogtoFile

        Case "toEvent"
          AnnotateLog

        Case "toBoth"
          LogtoFile
          AnnotateLog

        Case Else
          'Logging disabled

      End Select
  End If

End Sub

'----------------------------------------------------------------------------
' Write log entry to file.

Sub LogtoFile()
  On Error Resume Next

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

  strFile = strDirectory & "\XMOD-Prod-OMW-Inject.log"
  strRollFile = strDirectory & "\XMOD-Prod-OMW-Inject.log."

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
    objFSO.CreateTextFile(strRollFile)

    objFSO.CopyFile strFile, strRollFile, True

    ' Delete log file and recreate it.
    objFSO.DeleteFile(strFile)
    objFSO.CreateTextFile(strFile)
  End If

  Set objTextFile = objFSO.OpenTextFile (strFile, ForAppending, True)

  objTextFile.WriteLine("[ " & date() & " " & time() & " ] [ xMatters-ODP ] " & logText)
  objTextFile.Close

End Sub

'----------------------------------------------------------------------------
' Annotate log message to originating Event.

Sub AnnotateLog()
  On Error Resume Next

  Dim AnnotationMessage
  AnnotationMessage = "[xMatters-ODP] " & logText & " on " & date() & " at " & time()

  If Not IsNull(messageGuid) Then
    Const HPWMIMessageMoniker = "WinMgmts:{impersonationLevel=impersonate}!root/HewlettPackard/OpenView/Data:OV_Message.Id="
    Dim HPWMIMessagePath, HPWMIMessageObject

    ' Load HP WMI Message Object
    HPWMIMessagePath = HPWMIMessageMoniker & """" & messageGuid & """"
    Set HPWMIMessageObject = GetObject(HPWMIMessagePath)
    ' Annotate the Event in OMW with the error message
    HPWMIMessageObject.AddAnnotation( AnnotationMessage )
  Else
    logText = "[ ERROR ] Attempt to Annotate Log Message Failed, messageGuid is NULL." _
	          & "  Original Message: " & AnnotationMessage
	logType = "toFile"
	WriteLog
  End If
End Sub
