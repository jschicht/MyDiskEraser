#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Comment=My Disk eraser
#AutoIt3Wrapper_Res_Description=Automatically erase all local fixed disks from a bootdisk
#AutoIt3Wrapper_Res_Fileversion=2.0.0.0
#AutoIt3Wrapper_Res_LegalCopyright=Joakim Schicht
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
; A sample automatic disk eraser for fixed drives, to be used in a bootdisk
; Needs DISKERASER set as boot option (found in registry under SystemStartOptions)
; Configure your BCD by; "bcdedit /set {GUID} loadoptions DISKERASER"
; by Joakim Schicht
; 02.04.2012
#include <winapi.au3>
#Include <WinAPIEx.au3>
#Include <APIConstants.au3>
Global Const $StorageDeviceProperty = 0
Global Const $StorageAdapterProperty  = 1
Global $tagSTORAGE_PROPERTY_QUERY = "byte PropertyId;byte QueryType;byte AdditionalParameters[10]"
Global $tagSTORAGE_DEVICE_DESCRIPTOR  = "dword Version;dword Size;byte DeviceType;byte DeviceTypeModifier;boolean RemovableMedia;boolean CommandQueueing;dword VendorIdOffset;dword ProductIdOffset;dword ProductRevisionOffset;dword SerialNumberOffset;byte BusType;dword RawPropertiesLength;byte RawDeviceProperties"
Global $tagDISK_GEOMETRY = "int64 Cylinders;byte MediaType;dword TracksPerCylinder;dword SectorsPerTrack;dword BytesPerSector"
Global const $block = 16777216 ; The size in bytes by which each block of 00's are written to disk
Global $nBytes, $tBuffer, $sDrivePath = '\\.\PhysicalDrive'
$regtest = RegRead("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control", "SystemStartOptions")
If @error Then
	ConsoleWrite("Error: Could not find SystemStartOptions in registry" & @CRLF)
	Exit
EndIf
$StartOptions = StringSplit($regtest," ")
$DISKERASER = 0
For $i = 1 To $StartOptions[0]
	If $StartOptions[$i] = "" Then ContinueLoop
	ConsoleWrite("Found SystemStartOption: " & $StartOptions[$i] & @CRLF)
	If $StartOptions[$i] = "DISKERASER" Then
		$DISKERASER = 1
		ConsoleWrite("Found wanted SystemStartOption" & @CRLF)
		ExitLoop
	EndIf
Next
If $DISKERASER = 0 Then
	ConsoleWrite("DISKERASER not configured. Exiting." & @CRLF)
	Exit
EndIf

$FixedDrives = DriveGetDrive("FIXED")
If @error Then
	ConsoleWrite("Error detecting fixed drives. Exiting." & @CRLF)
	Exit
EndIf
$SystemVol = StringLeft(@WindowsDir,2)
$ProgDir = StringLeft(@AutoItExe,2)
For $i = 1 To $FixedDrives[0]
	ConsoleWrite("Fixed drive found: " & $FixedDrives[$i] & @CRLF)
	If $ProgDir = $FixedDrives[$i] Then
		ConsoleWrite("Will not try dismounting the drive that this program is run from.." & @crlf)
		ContinueLoop
	EndIf
	If $SystemVol = $FixedDrives[$i] Then
		ConsoleWrite("Will not dismount the current system drive.." & @crlf)
		ContinueLoop
	EndIf
If @OSBuild >= 6000 Then
 	ConsoleWrite("Trying to force dismount volume: " & $FixedDrives[$i] & @CRLF)
	$dismount = _WinAPI_DismountVolumeMod($FixedDrives[$i])
	If $dismount = 0 Then
		ConsoleWrite("Error when force dismounting " & $FixedDrives[$i] & @CRLF)
		ContinueLoop
	EndIf
	ConsoleWrite("Successfully force dismounted " & $FixedDrives[$i] & @CRLF)
	$IsDismounted = 1
ElseIf @OSBuild < 6000 Then
	; Not really needed as we can write to physical disk without lock/dismount in nt5.x
EndIf
Next

$DiskSizeAcc = 0
$begin = TimerInit()
For $i = 0 To 30 ; Stops at \\.\PhysicalDrive30
	ConsoleWrite("Now trying: \\.\PhysicalDrive" & $i & @CRLF)
	$StorageProperty = _WinAPI_STORAGE_QUERY_PROPERTY("PhysicalDrive"&$i)
	If @error Then
		ConsoleWrite("Error in STORAGE_QUERY_PROPERTY: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		ContinueLoop
	EndIf
	$RemovableMedia = DllStructGetData($StorageProperty,"RemovableMedia")
	$BusType = DllStructGetData($StorageProperty,"BusType")
	If $BusType = 7 Then
		ConsoleWrite("Will not touch this disk since it is USB attached" & @crlf)
		ContinueLoop
	EndIf
	If $RemovableMedia = 1 Then
		ConsoleWrite("Will not touch this disk since it is a removable media" & @crlf)
		ContinueLoop
	EndIf
	$DiskInfo = _WinAPI_GetDriveGeometryEx($i)
	If @error Then
		ConsoleWrite("Error in GetDriveGeometryEx: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		ContinueLoop
	ElseIf $DiskInfo[1] <> 12 Then
		ConsoleWrite("Error wrong media type:" & $DiskInfo[1] & @CRLF)
		ContinueLoop
	ElseIf $DiskInfo[5] = 0 Then
		ConsoleWrite("Error retrieving DiskSize" & @crlf)
		ContinueLoop
	EndIf
	$DiskSize = $DiskInfo[5]
	ConsoleWrite("Total DiskSize: " & $DiskSize & @crlf)
	$hFile0 = _WinAPI_CreateFile($sDrivePath & $i,2,4,4)
	If $hFile0 = 0 Then
		ConsoleWrite("Error in CreateFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		ContinueLoop
	EndIf
	$remainder = 0
	$sizediff = $DiskSize/$block
	$maxblocks = Ceiling($sizediff)
	$maxblocks_low = Floor($sizediff)
	$sizediff2 = $sizediff-$maxblocks_low
	$remainder = $sizediff2 * $block
	$block_mod = $block
	_WinAPI_SetFilePointerEx($hFile0, 0)
	If @error Then
		ConsoleWrite("SetFilePointerEx: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		ContinueLoop
	EndIf
	$DiskSizeAcc += $DiskSize
	ProgressOn("My lame disk eraser in progress", "Writing lots of 00's", "", -1, -1, 16)
	For $j = 1 To $maxblocks+1
		If $j = $maxblocks+1 Then
			$block_mod = $remainder
		EndIf
		$tBuffer=DllStructCreate("byte[" & $block_mod & "]") ; If something more fancy than 00's, then do so with DllStructSetData from here
		$write = _WinAPI_WriteFile($hFile0, DllStructGetPtr($tBuffer), $block_mod, $nBytes)
		If $write = 0 then
			ConsoleWrite("Error when writing at block: " & $j & @crlf)
			ConsoleWrite("WriteFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
			_WinAPI_CloseHandle($hFile0)
			ExitLoop
		EndIf
		If @error Then ConsoleWrite("WriteFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		ProgressSet(Round((($j/$maxblocks)*100), 1),Round(($j/$maxblocks)*100, 1) & "  % finished overwriting \\.\PhysicalDrive" & $i, "")
		If $j = $maxblocks+1 Then
			_WinAPI_FlushFileBuffers($hFile0)
			ExitLoop
		EndIf
		_WinAPI_SetFilePointerEx($hFile0, $j*$block_mod)
		If @error Then
			ConsoleWrite("Error in SetFilePointerEx: " & _WinAPI_GetLastErrorMessage() & @CRLF)
			_WinAPI_CloseHandle($hFile0)
			ExitLoop
		EndIf
	Next
	_WinAPI_CloseHandle($hFile0)
Next
ProgressOff()
$diff = TimerDiff($begin)
$diff = Round(($diff/1000),2)
$BytesPerSec = Round(($DiskSizeAcc/$diff),0)
$DiskSizeKB = $DiskSizeAcc/1024
$KBPerSec = Round(($DiskSizeKB/$diff),0)
$DiskSizeMB = $DiskSizeAcc/1024/1024
$MBPerSec = Round(($DiskSizeMB/$diff),1)
$MBPerMin = $MBPerSec * 60
ConsoleWrite("Timer: Disk eraser took: " & $diff & " seconds" & @crlf)
ConsoleWrite("Timer: Processed: " & $BytesPerSec & " bytes per second" & @crlf)
ConsoleWrite("Timer: Processed: " & $KBPerSec & " KB per second" & @crlf)
ConsoleWrite("Timer: Processed: " & $MBPerSec & " MB per second" & @crlf)
ConsoleWrite("Timer: Processed: " & $MBPerMin & " MB per minute" & @crlf)
;MsgBox(0,"Finished erasing disk","Job took: " & $diff & " seconds" & @crlf _
;& "Performed " & $MBPerMin & " MB per minute",10)
Exit

Func _WinAPI_DismountVolumeMod($iVolume)
	$hFile = _WinAPI_CreateFileEx('\\.\' & $iVolume, 3, BitOR($GENERIC_READ,$GENERIC_WRITE), 0x7)
	If Not $hFile Then
		ConsoleWrite("Error in _WinAPI_CreateFileEx when dismounting." & @CRLF)
		Return SetError(1, 0, 0)
	EndIf
	Local $Ret = DllCall('kernel32.dll', 'int', 'DeviceIoControl', 'ptr', $hFile, 'dword', $FSCTL_DISMOUNT_VOLUME, 'ptr', 0, 'dword', 0, 'ptr', 0, 'dword', 0, 'dword*', 0, 'ptr', 0)
	If (@error) Or (Not $Ret[0]) Then
		Return SetError(3, 0, 0)
;		$Ret = 0
	EndIf
	If Not IsArray($Ret) Then
		Return SetError(2, 0, 0)
	EndIf
;	Return $Ret[0]
	Return $hFile
EndFunc   ;==>_WinAPI_DismountVolumeMod

Func _WinAPI_STORAGE_QUERY_PROPERTY($iVolume)
	$hFile = _WinAPI_CreateFileEx('\\.\' & $iVolume, 3, BitOR($GENERIC_READ,$GENERIC_WRITE), 0x7)
	If Not $hFile Then
;		ConsoleWrite("CreateFileEx: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		Return SetError(1, 0, 0)
	EndIf
	Local $tbuffer = DllStructCreate($tagSTORAGE_PROPERTY_QUERY)
	DllStructSetData($tbuffer,"PropertyId",$StorageDeviceProperty)
	DllStructSetData($tbuffer,"QueryType",0)
	Local $tbuffer1 = DllStructCreate($tagSTORAGE_DEVICE_DESCRIPTOR)
	Local $Ret = DllCall('kernel32.dll', 'int', 'DeviceIoControl', 'ptr', $hFile, 'dword', $IOCTL_STORAGE_QUERY_PROPERTY, 'ptr', DllStructGetPtr($tbuffer), 'dword', DllStructGetSize($tbuffer), 'ptr', DllStructGetPtr($tbuffer1), 'dword', DllStructGetSize($tbuffer1), 'dword*', 0, 'ptr', 0)
	If (@error) Or (Not $Ret[0]) Then
;		ConsoleWrite("Error in IOCTL_DISK_GET_DRIVE_GEOMETRY: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		_WinAPI_CloseHandle($hFile)
		Return SetError(3, 0, 0)
	EndIf
	If Not IsArray($Ret) Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(2, 0, 0)
	EndIf
	_WinAPI_CloseHandle($hFile)
	Return $tbuffer1
EndFunc
