#include <GUIConstantsEx.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <ColorConstants.au3>
#include <GuiEdit.au3>
#include <Crypt.au3>
#include <Array.au3>
#include <TrayConstants.au3>
#include <ScrollBarsConstants.au3>

Opt("TrayMenuMode", 3)
Opt("GUIOnEventMode", 1)
Opt("TrayOnEventMode", 1)

$configFileDir = @LocalAppDataDir & "\PhasmoPhoto"
$configFilePath = $configFileDir&"\phasmophoto.config"

If FileExists($configFileDir) == 0 Then
   DirCreate(@LocalAppDataDir & "\PhasmoPhoto")
EndIf

$phasmoInstallDir = ""
$photoSaveDir = ""
$defaultInstallDir = "C:\Program Files (x86)\Steam\steamapps\common\Phasmophobia"
$defaultPhotoDir = "Not Set"
$invervalSeconds = 5
$title = "PhasmoPhoto"
$version = "0.1"
$phasmoRunning = False
$confirmHide = False

Dim $photoHashes[12]
For $i = 0 To UBound($photoHashes)-1
   $photoHashes[$i] = "X"
Next

readConfig()

If $phasmoInstallDir == "Not Set" And FileExists($defaultInstallDir) Then
   $prompt = "Phasmophobia looks like it was installed in the default location:"&@CRLF& _
	  $defaultInstallDir & @CRLF & @CRLF & _
	  "Want to save this location as the Phasmophobia Install Directory?"
   $response = MsgBox($MB_YESNO, "Information", $prompt)
   If $response == $IDYES Then
	  IniWrite($configFilePath, "Settings", "PhasmoInstallDir", $defaultInstallDir)
	  $phasmoInstallDir = $defaultInstallDir
   EndIf
EndIf

$showButton = TrayCreateItem("View Settings")
TrayItemSetOnEvent($showButton, "show")
$exitTrayButton = TrayCreateItem("Exit")
TrayItemSetOnEvent($exitTrayButton, "quit")

$gui = GUICreate($title&" "&$version, 300, 360)
GUISetOnEvent($GUI_EVENT_CLOSE, "hide")

GUICtrlCreateGroup("Settings", 10, 10, 280, 160)
GUICtrlCreateLabel("Phasmophobia Install Dir:", 20, 30)
$installDirText = GUICtrlCreateInput($phasmoInstallDir, 20, 50, 200)
$installDirButton = GUICtrlCreateButton("Browse", 230, 47, 50)
GUICtrlSetOnEvent($installDirButton, "findInstallDir")

GUICtrlCreateLabel("Photo Save Dir:", 20, 85)
$photoDirText = GUICtrlCreateInput($photoSaveDir, 20, 105, 200)
$photoDirButton = GUICtrlCreateButton("Browse", 230, 102, 50)
GUICtrlSetOnEvent($photoDirButton, "findPhotoDir")

GUICtrlCreateLabel("Interval in Seconds:", 20, 137)
$intervalText = GUICtrlCreateInput($invervalSeconds, 120, 135, 30, Default, $ES_NUMBER)

$saveSettingsButton = GUICtrlCreateButton("Save Settings", 180, 132, 100)
GUICtrlSetOnEvent($saveSettingsButton, "saveSettings")

GUICtrlCreateGroup("Status", 10, 180, 280, 175)
$phasmoLabel = GUICtrlCreateLabel("Phasmophobia Status: Not Running", 20, 200)
$openPhotoLocationButton = GUICtrlCreateButton("Open Photo Location", 20, 220, 260)
GUICtrlSetOnEvent($openPhotoLocationButton, "openPhotoLocation")
$statusEdit = GUICtrlCreateEdit($title & " v" & $version, 20, 250, 260, 100, BitOR($ES_AUTOVSCROLL,$ES_AUTOHSCROLL,$ES_READONLY,$WS_VSCROLL,$ES_MULTILINE))
GUICtrlSetBkColor($statusEdit, $COLOR_WHITE)
GUICtrlSetFont($statusEdit, 8.5, Default, Default, "Courier New")

GUISetState(@SW_SHOW, $gui)

;Main Loop
While True
   If ProcessExists("Phasmophobia.exe") == 0 Then
	  GUICtrlSetData($phasmoLabel, "Phasmophobia Status: Not Running")
   Else
	  GUICtrlSetData($phasmoLabel, "Phasmophobia Status: Running")
	  checkPhotos()
   EndIf
   Sleep($invervalSeconds*1000)
WEnd

Func checkPhotos()
   Local $fileName = ""
   Local $hash = ""
   Local $newFileName = ""
   Local $count = 0
   Local $changes = False
   Local $timeStr = @YEAR&"_"&@MON&"_"&@MDAY&"_"&@HOUR&"-"&@MIN&"-"&@SEC
   Dim $hashesToAdd[1]
   $hashesToAdd[0] = 0

   ;Get a file search handle
   Local $search = FileFindFirstFile($defaultInstallDir &"/SavedScreen*.png")

   ;If no matches return
   If $search = -1 Then
	  Return
   EndIf

   _Crypt_Startup()

   While True
	  $fileName = FileFindNextFile($search)
	  If @error Then ExitLoop

	  $hash = _Crypt_HashFile($phasmoInstallDir&"\"&$fileName, $CALG_SHA1)

	  If @error Then
		 ContinueLoop
	  EndIf

	  For $i = 0 To UBound($photoHashes)-1
		 If $hash == $photoHashes[$i]Then
			ContinueLoop 2
		 EndIf
	  Next

	  ;If not found, copy the file and add the hash
	  $changes = True
	  $newFileName = $timeStr&"_"&$count&"_"&"Phasmophobia.png"
	  $newFilePath = $photoSaveDir & "\" & $newFileName
	  If FileCopy($phasmoInstallDir&"\"&$fileName, $newFilePath, $FC_OVERWRITE) Then
		 logMsg("New File: " & $newFileName)
	  Else
		 logMsg("Error Copying File: " & $newFileName)
	  EndIf
	  _ArrayAdd($hashesToAdd, $hash)
	  $hashesToAdd[0]+=1
	  $count+=1
   WEnd

   _Crypt_Shutdown()

   ;Update the file hashes
   If $changes Then
	  For $i = 1 To $hashesToAdd[0]
		 _ArrayPush($photoHashes, $hashesToAdd[$i])
	  Next
	  updateConfigHashes()
   EndIf
EndFunc

Func logMsg($msg)
   _GUICtrlEdit_AppendText($statusEdit, @CRLF&$msg)
   Local $caretPos = StringLen(GUICtrlRead($statusEdit))-(StringLen($msg)+1)
   _GUICtrlEdit_SetSel($statusEdit, $caretPos, $caretPos+1)
   _GUICtrlEdit_Scroll($statusEdit, $SB_SCROLLCARET)
   ConsoleWrite($msg&@CRLF)
EndFunc

Func openPhotoLocation()
   ShellExecute($photoSaveDir)
EndFunc

Func saveSettings()
   Global $phasmoInstallDir = GUICtrlRead($installDirText)
   Global $photoSaveDir = GUICtrlRead($photoDirText)
   Global $invervalSeconds = GUICtrlRead($intervalText)
   Global $confirmHide
   IniWrite($configFilePath, "Settings", "PhasmoInstallDir", $phasmoInstallDir)
   IniWrite($configFilePath, "Settings", "PhotoSaveDir", $photoSaveDir)
   IniWrite($configFilePath, "Settings", "IntervalSecs", $invervalSeconds)
   IniWrite($configFilePath, "Settings", "ConfirmHide", $confirmHide)
EndFunc

Func findInstallDir()
   $sel = FileSelectFolder("Phasmophobia Install Dir", @ScriptDir)

   If FileExists($sel) == False Then
	  DirCreate($sel)
   EndIf

   GUICtrlSetData($installDirText, $sel)
EndFunc

Func findPhotoDir()
   $sel = FileSelectFolder("Photo Save Dir", @ScriptDir)

   If FileExists($sel) == False Then
	  DirCreate($sel)
   EndIf

   GUICtrlSetData($photoDirText, $sel)
EndFunc

Func readConfig()
   Global $installDirText, $photoDirText, $intervalText
   Global $phasmoInstallDir = IniRead($configFilePath, "Settings", "PhasmoInstallDir", "Not Set")
   Global $photoSaveDir = IniRead($configFilePath, "Settings", "PhotoSaveDir", "Not Set")
   Global $invervalSeconds = IniRead($configFilePath, "Settings", "IntervalSecs", "5")
   Global $hashes = IniReadSection($configFilePath, "PhotoHashes")
   Global $confirmHide = IniRead($configFilePath, "Settings", "ConfirmHide", False)

   If @error Then
	  Return
   EndIf
   For $i = 1 To $hashes[0][0]
	  $photoHashes[$i-1] = $hashes[$i][1]
   Next
   GUICtrlSetData($installDirText, $phasmoInstallDir)
   GUICtrlSetData($photoDirText, $photoSaveDir)
   GUICtrlSetData($intervalText, $invervalSeconds)
EndFunc

Func writeConfig()
   saveSettings()
   updateConfigHashes()
EndFunc

Func updateConfigHashes()
   For $i = 0 To UBound($photoHashes)-1
	  IniWrite($configFilePath, "PhotoHashes", "Photo"&$i, $photoHashes[$i])
   Next
EndFunc

Func show()
   GUISetState(@SW_SHOW, $gui)
EndFunc

Func hide()
   Global $confirmHide
   If $confirmHide == False Then
	  MsgBox($IDOK, "Info", "PhasmoPhoto is still running in the tray!")
	  $confirmHide = True
	  saveSettings()
   EndIf
   GUISetState(@SW_HIDE, $gui)
EndFunc

Func quit()
   Exit
EndFunc