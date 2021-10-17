Option Explicit

Private Const TEMPDIR = "D:\hMailServer\Events"

Function Include(sInstFile)
	Dim f, s, oFSO
	Set oFSO = CreateObject("Scripting.FileSystemObject")
	On Error Resume Next
	If oFSO.FileExists(sInstFile) Then
		Set f = oFSO.OpenTextFile(sInstFile)
		s = f.ReadAll
		f.Close
		ExecuteGlobal s
	End If
	On Error Goto 0
	Set f = Nothing
	Set oFSO = Nothing
End Function

Function Lookup(strRegEx, strMatch) : Lookup = False
	With CreateObject("VBScript.RegExp")
		.Pattern = strRegEx
		.Global = False
		.MultiLine = True
		.IgnoreCase = True
		If .Test(strMatch) Then Lookup = True
	End With
End Function

Function oLookup(strRegEx, strMatch, bGlobal)
	If strRegEx = "" Then strRegEx = StrReverse(strMatch)
	With CreateObject("VBScript.RegExp")
		.Pattern = strRegEx
		.Global = bGlobal
		.MultiLine = True
		.IgnoreCase = True
		Set oLookup = .Execute(strMatch)
	End With
End Function

Function CatchSpam(spamDomain)
	Dim strSQL, oDB : Set oDB = GetDatabaseObject
	strSQL = "INSERT INTO hm_catchspam (domain,hits) VALUES ('" & spamDomain & "',1) ON DUPLICATE KEY UPDATE hits=(hits+1),timestamp=NOW();"
	Call oDB.ExecuteSQL(strSQL)
End Function

Function IsCatchSpam(spamDomain) : IsCatchSpam = False
	Dim m_CountDomain, m_SafeDomain
    Dim oRecord, oConn : Set oConn = CreateObject("ADODB.Connection")
    oConn.Open "Driver={MariaDB ODBC 3.1 Driver}; Server=localhost; Database=hmailserver; User=hmailserver; Password=supersecretpassword;"

    If oConn.State <> 1 Then
		EventLog.Write( "Function IsCatchSpam - ERROR: Could not connect to database" )
        Exit Function
    End If

    Set oRecord = oConn.Execute("SELECT hits,safe FROM hm_catchspam WHERE domain = '" & spamDomain & "'")
    Do Until oRecord.EOF
        m_CountDomain = oRecord("hits")
        m_SafeDomain = oRecord("safe")
        oRecord.MoveNext
    Loop
    oConn.Close
    Set oRecord = Nothing
	If (CInt(m_CountDomain) > 2) And (m_SafeDomain = 0) Then IsCatchSpam = True
End Function

Function GetMainDomain(strDomain)
	Dim strRegEx, Match, Matches
	Dim TestDomain, DomainParts, a, i, PubSuffMatch
	Include("C:\scripts\hmailserver\FWBan\PublicSuffix\public_suffix_list.vbs")
	
	DomainParts = Split(strDomain,".")
	a = UBound(DomainParts)
	If a > 1 Then
		TestDomain = DomainParts(1)
		For i = 2 to a
			TestDomain = TestDomain & "." & DomainParts(i)
		Next
	ElseIf a = 1 Then
		TestDomain = DomainParts(1)
	Else
		Exit Function
	End If

	Set Matches = oLookup(PubSufRegEx, TestDomain, False)
	For Each Match In Matches
		PubSuffMatch = True
	Next

	If PubSuffMatch Then 
		GetMainDomain = DomainParts(0) & "." & TestDomain
	Else
		GetMainDomain = GetMainDomain(TestDomain)
	End If
End Function

Function LockFile(strPath)
	Const Append = 8
	Const Unicode = -1
	Dim i
	On Error Resume Next
	With CreateObject("Scripting.FileSystemObject")
		For i = 0 To 30
			Err.Clear
			Set LockFile = .OpenTextFile(strPath, Append, True, Unicode)
			If (Not Err.Number = 70) Then Exit For
			Wait(1)
		Next
	End With
	If (Err.Number = 70) Then
		EventLog.Write( "ERROR: EventHandlers.vbs" )
		EventLog.Write( "File " & strPath & " is locked and timeout was exceeded." )
		Err.Clear
	ElseIf (Err.Number <> 0) Then
		EventLog.Write( "ERROR: EventHandlers.vbs : Function LockFile" )
		EventLog.Write( "Error       : " & Err.Number )
		EventLog.Write( "Error (hex) : 0x" & Hex(Err.Number) )
		EventLog.Write( "Source      : " & Err.Source )
		EventLog.Write( "Description : " & Err.Description )
		Err.Clear
	End If
	On Error Goto 0
End Function

Function AutoBan(sIPAddress, sReason, iDuration, sType) : AutoBan = False
	'
	'   sType can be one of the following;
	'   "yyyy" Year, "m" Month, "d" Day, "h" Hour, "n" Minute, "s" Second
	'
	Dim oApp : Set oApp = CreateObject("hMailServer.Application")
	Call oApp.Authenticate(ADMIN, hMSPASSWORD)
	With LockFile(TEMPDIR & "\autoban.lck")
		On Error Resume Next
		Dim oSecurityRange : Set oSecurityRange = oApp.Settings.SecurityRanges.ItemByName("(" & sReason & ") " & sIPAddress)
		If Err.Number = 9 Then
			With oApp.Settings.SecurityRanges.Add
				.Name = "(" & sReason & ") " & sIPAddress
				.LowerIP = sIPAddress
				.UpperIP = sIPAddress
				.Priority = 20
				.Expires = True
				.ExpiresTime = DateAdd(sType, iDuration, Now())
				.Save
			End With
			AutoBan = True
		End If
		On Error Goto 0
		.Close
	End With
	Set oApp = Nothing
End Function

Function Disconnect(sIPAddress)
	With CreateObject("WScript.Shell")
		.Run """C:\hMailServer\Events\Disconnect.exe"" " & sIPAddress & "", 0, True
		REM EventLog.Write("Disconnect.exe " & sIPAddress & "")
	End With
End Function

Function GetDatabaseObject()
	Dim oApp : Set oApp = CreateObject("hMailServer.Application")
	Call oApp.Authenticate(ADMIN, hMSPASSWORD)
	Set GetDatabaseObject = oApp.Database
End Function

Function Whitelisted(strIP) : Whitelisted = 0

	Dim a : a = Split(strIP, ".")
	Dim strLookup, strRegEx
	Dim IsWLMailSpike, IsWLHostKarma, IsWLNSZones, IsWLSPFBL, IsWLSpamDonkey, IsWLIPSWhitelisted
	
	With CreateObject("DNSLibrary.DNSResolver")
		strLookup = .DNSLookup(a(3) & "." & a(2) & "." & a(1) & "." & a(0) & ".rep.mailspike.net")
	End With
	strRegEx = "^127\.0\.0\.(18|19|20)$" '18=Good, 19=Very Good, 20=Excellent Reputation
	IsWLMailSpike = Lookup(strRegEx, strLookup)

	With CreateObject("DNSLibrary.DNSResolver")
		strLookup = .DNSLookup(a(3) & "." & a(2) & "." & a(1) & "." & a(0) & ".hostkarma.junkemailfilter.com")
	End With
	strRegEx = "^127\.0\.0\.(1|5)$" '1=Good, 5=NoBL
	IsWLHostKarma = Lookup(strRegEx, strLookup)

	With CreateObject("DNSLibrary.DNSResolver")
		strLookup = .DNSLookup(a(3) & "." & a(2) & "." & a(1) & "." & a(0) & ".wl.nszones.com")
	End With
	strRegEx = "^127\.0\.0\.5$" '5=whitelisted
	IsWLNSZones = Lookup(strRegEx, strLookup)

	With CreateObject("DNSLibrary.DNSResolver")
		strLookup = .DNSLookup(a(3) & "." & a(2) & "." & a(1) & "." & a(0) & ".dnswl.spfbl.net")
	End With
	strRegEx = "^127\.0\.0\.(2|3|4|5)$" '2=excellent rep, 3=indispensable public service, 4=corp email (no marketing), 5=safe bulk mail
	IsWLSPFBL = Lookup(strRegEx, strLookup)

	With CreateObject("DNSLibrary.DNSResolver")
		strLookup = .DNSLookup(a(3) & "." & a(2) & "." & a(1) & "." & a(0) & ".dnsbl.spamdonkey.com")
	End With
	strRegEx = "^126\.0\.0\.0$" '126.0.0.0=whitelisted
	IsWLSpamDonkey = Lookup(strRegEx, strLookup)

	With CreateObject("DNSLibrary.DNSResolver")
		strLookup = .DNSLookup(a(3) & "." & a(2) & "." & a(1) & "." & a(0) & ".ips.whitelisted.org")
	End With
	strRegEx = "^127\.0\.0\.2$" '2=whitelisted
	IsWLIPSWhitelisted = Lookup(strRegEx, strLookup)

	If (IsWLMailSpike OR IsWLHostKarma OR IsWLNSZones OR IsWLSPFBL OR IsWLSpamDonkey OR IsWLIPSWhitelisted) Then Whitelisted = 1

End Function

Function PTRLookup(strIP)
	Dim strLookup, strPTR
	With CreateObject("DNSLibrary.DNSResolver")
		strLookup = .PTR(strIP)
	End With
	If strLookup = Empty Then strPTR = "No.PTR.Record" Else strPTR = strLookup End If
	PTRLookup = strPTR
End Function

Sub OnClientConnect(oClient)

	REM	- Reject on CatchSpam
	Dim spamDomain : spamDomain = GetMainDomain(PTR_Record)
	If IsCatchSpam(spamDomain) Then
		Result.Value = 2
		Result.Message = ". 19 Your access to this mail system has been rejected due to the sending MTA's poor reputation. If you believe that this failure is in error, please contact the intended recipient via alternate means."
		Call Disconnect(oClient.IPAddress)
		Call AutoBan(oClient.IPAddress, "CatchSpam - " & oClient.IpAddress, 1, "h")
		'
		' Anything else you want to do
		'
		Exit Sub
	End If	

End Sub

Sub OnAcceptMessage(oClient, oMessage)

	Dim strRegEx, Match, Matches, PTR_Record

	REM	- Grab PTR-Record
	PTR_Record = PTRLookup(oClient.IPAddress)

	REM - Test Whitelist (0 = Not Listed, 1 = Whitelisted)
	Dim IsWhitelisted : IsWhitelisted = Whitelisted(oClient.IPAddress)

	REM - Record entries for CatchSpam
	Dim spamDomain, SAScore
	If IsWhitelisted = 0 Then
		If oMessage.HeaderValue("X-hMailServer-Reason-Score") <> "" Then 
			strRegEx = "[0-9]{1,3}"
			Set Matches = oLookup(strRegEx, oMessage.HeaderValue("X-hMailServer-Reason-Score"), False)
			For Each Match In Matches
				SAScore = Match.Value
			Next
			
			REM - If SAScore greater than DELETE THRESHOLD - use hMailServer delete threshold score
			REM - CatchSpam should only be applied to messages that should be deleted : its used to reject the client outright
			If (CInt(SAScore) > 6) Then 
				spamDomain = GetMainDomain(PTR_Record)
				' EventLog.Write( "Spam Received: Score = " & CInt(SAScore) & ", PTR = " & PTR_Record & " Domain = " & spamDomain )
				If spamDomain <> "" Then 
					Call CatchSpam(spamDomain)
					'
					' Anything else you want to do
					'
				End If
			End If
		End If
	End If

End Sub
