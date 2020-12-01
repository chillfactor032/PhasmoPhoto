#include <GUIConstantsEx.au3>
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <EditConstants.au3>
#include <WindowsConstants.au3>
#include <ColorConstants.au3>
#include <UpDownConstants.au3>
#include <FontConstants.au3>
#include <ListViewConstants.au3>
#include <WinAPIGdi.au3>
#include <GuiListBox.au3>
#include <GDIPlus.au3>
#include <GuiEdit.au3>
#include <Crypt.au3>
#include <Array.au3>
#include <TrayConstants.au3>
#include <ScrollBarsConstants.au3>
#include <Misc.au3>

enforceSingleton()

Opt("TrayMenuMode", 3)
Opt("GUIOnEventMode", 1)
Opt("TrayOnEventMode", 1)

$configFileDir = @LocalAppDataDir & "\PhasmoPhoto"
$configFilePath = $configFileDir&"\phasmophoto.config"

If FileExists($configFileDir) == 0 Then
   DirCreate(@LocalAppDataDir & "\PhasmoPhoto")
EndIf

; Title and Version
$title = "PhasmoPhoto"
$version = "0.2.1"

;Constants
$GUI_HEIGHT = 500
$GUI_WIDTH = 600

; Variables
$phasmoInstallDir = ""
$photoSaveDir = ""
$defaultInstallDir = "C:\Program Files (x86)\Steam\steamapps\common\Phasmophobia"
$defaultPhotoDir = "Not Set"
$invervalSeconds = 5
$minimizeOnClose = False
$phasmoRunning = False
$previewImgHwd = ""
$previewImgThumbHwd = ""
$previewImgGraphic = ""
$maxNumberPhotos = 200

Dim $photoHashes[12]
For $i = 0 To UBound($photoHashes)-1
   $photoHashes[$i] = "X"
Next

;Tray GUI
$showButton = TrayCreateItem("View GUI")
TrayItemSetOnEvent($showButton, "show")
$exitTrayButton = TrayCreateItem("Exit")
TrayItemSetOnEvent($exitTrayButton, "quit")

;GUI Creation
$gui = GUICreate($title&" "&$version, $GUI_WIDTH, $GUI_HEIGHT)
GUISetOnEvent($GUI_EVENT_CLOSE, "hide")

;TAB Control
$tabControl = GUICtrlCreateTab(5, 5, $GUI_WIDTH-10, $GUI_HEIGHT-10)
GUICtrlSetOnEvent($tabControl, "tabClick")

;Settings Tab
$settingsTab = GUICtrlCreateTabItem("Settings")
GUICtrlCreateLabel("Phasmophobia Install Directory:", 20, 50)
$installDirText = GUICtrlCreateInput($phasmoInstallDir, 20, 70, $GUI_WIDTH-100)
$installDirButton = GUICtrlCreateButton("Browse", $GUI_WIDTH-70, 67, 50)
GUICtrlSetOnEvent($installDirButton, "findInstallDir")

GUICtrlCreateLabel("Photo Save Directory:", 20, 105)
$photoDirText = GUICtrlCreateInput($photoSaveDir, 20, 125, $GUI_WIDTH-100)
$photoDirButton = GUICtrlCreateButton("Browse", $GUI_WIDTH-70, 122, 50)
GUICtrlSetOnEvent($photoDirButton, "findPhotoDir")

GUICtrlCreateLabel("Interval in Seconds:", 20, 165)
$intervalText = GUICtrlCreateInput($invervalSeconds, 120, 163, 40, Default, $ES_NUMBER)
$intervalSpinner = GUICtrlCreateUpdown($intervalText)

$minimizeOnCloseCheckBox = GUICtrlCreateCheckbox("Minimize to Tray on Close", 20, 195)
GUICtrlCreateLabel("Maximum Number of Photos to Save: ", 345, 165)
$maxNumberPhotosText = GUICtrlCreateInput("200", 530, 162, 50, Default, $ES_NUMBER)

$saveSettingsButton = GUICtrlCreateButton("Save Settings", $GUI_WIDTH-120, $GUI_HEIGHT-40, 100)
GUICtrlSetOnEvent($saveSettingsButton, "saveSettings")

;Photos Tab - Photo List Area
$photoTab = GUICtrlCreateTabItem("Photos")
GUICtrlCreateLabel("Saved Photos:", 20, 40)
$photoList = GUICtrlCreateList("No Photos Saved", 20, 60, ($GUI_WIDTH/2)-20, $GUI_HEIGHT-100, BitOR($WS_BORDER, $WS_VSCROLL))
GUICtrlSetOnEvent($photoList, "photoList")
GUICtrlSetOnEvent($photoTab, "photoList")
$openPhotoLocationButton = GUICtrlCreateButton("Open Photo Location", 20, $GUI_HEIGHT-40, ($GUI_WIDTH/2)-20)
GUICtrlSetOnEvent($openPhotoLocationButton, "openPhotoLocation")

;Photos Tab - Preview Area
$previewObjX = ($GUI_WIDTH/2)+20
$previewObjY = 60
$previewObjWidth = ($GUI_WIDTH/2)-40
$previewObjHeight = $previewObjWidth * 0.5625
GUICtrlCreateLabel("Preview:", ($GUI_WIDTH/2)+20, 40)
$previewObj = GUICtrlCreateLabel("", $previewObjX, $previewObjY, $previewObjWidth, $previewObjHeight)
GUICtrlSetBkColor($previewObj, $COLOR_GRAY)

$copyPhotoButton = GUICtrlCreateButton("Copy to Clipboard", $previewObjX, $previewObjY+$previewObjHeight+15, $previewObjWidth, 30)
$archivePhotoButton = GUICtrlCreateButton("Archive Photo", $previewObjX, $previewObjY+$previewObjHeight+50, $previewObjWidth, 30)
$separator = GUICtrlCreateLabel("", $previewObjX, $previewObjY+$previewObjHeight+85, $previewObjWidth, 5)
GUICtrlSetBkColor($separator, 0x999999)
$deletePhotoButton = GUICtrlCreateButton("Delete Photo", $previewObjX, $previewObjY+$previewObjHeight+95, $previewObjWidth, 30)
GUICtrlSetOnEvent($copyPhotoButton, "copyPhotoButton")
GUICtrlSetOnEvent($archivePhotoButton, "archivePhotoButton")
GUICtrlSetOnEvent($deletePhotoButton, "deletePhotoButton")

;Status Tab
$statusTab = GUICtrlCreateTabItem("Status")
GUICtrlCreateLabel("PhasmoPhobia Status: ", 20, 40)
$phasmoLabel = GUICtrlCreateLabel("Not Running", 130, 40)
GUICtrlSetFont($phasmoLabel, Default, $FW_BOLD)
GUICtrlSetColor($phasmoLabel, $COLOR_RED)

$statusEdit = GUICtrlCreateEdit($title & " v" & $version, 20, 60, $GUI_WIDTH-40, $GUI_HEIGHT-70, BitOR($ES_AUTOVSCROLL,$ES_AUTOHSCROLL,$ES_READONLY,$WS_VSCROLL,$ES_MULTILINE))
GUICtrlSetBkColor($statusEdit, $COLOR_WHITE)
GUICtrlSetFont($statusEdit, 8.5, Default, Default, "Courier New")

;End of Tab Control
GUICtrlCreateTabItem("")

;Read the settings from the config file
readConfig()

;If Phasmo Install Dir not set, check for default location
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

;Update the GUI to reflect the settings
refreshSettings()
refreshPhotoList()

;Trim Number of Photos to Max
trimToMaxPhotos()

;Start GDI Plus
_GDIPlus_StartUp()

;Show the GUI
GUISetState(@SW_SHOW, $gui)

;Main Loop
While True
   If ProcessExists("Phasmophobia.exe") == 0 Then
	  setPhasmoRunning(False)
   Else
	  setPhasmoRunning(True)
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
   Local $timeStr = @YEAR&@MON&@MDAY&"_"&@HOUR&"-"&@MIN&"-"&@SEC
   Dim $hashesToAdd[1]
   $hashesToAdd[0] = 0

   ;Get a file search handle
   Local $search = FileFindFirstFile($phasmoInstallDir &"/SavedScreen*.png")

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
			;Hash Matches, we already have this photo
			ContinueLoop 2
		 EndIf
	  Next

	  ;No hashes matched, this must be a new file
	  $newFileName = $timeStr&"_"&"Phasmophobia"& $count &".png"
	  $newFilePath = $photoSaveDir & "\" & $newFileName
	  If FileCopy($phasmoInstallDir&"\"&$fileName, $newFilePath, $FC_OVERWRITE) Then
		 logMsg("New File: " & $newFileName)
		 _ArrayPush($photoHashes, $hash)
		 $count+=1
		 updateConfigHashes()
		 refreshPhotoList()
	  Else
		 logMsg("Error Copying File: " & $newFileName)
	  EndIf
   WEnd

   _Crypt_Shutdown()
EndFunc

Func deletePhotoButton()
   Global $gui
   Local $filePath = getSelectedPhoto()
   Local $split = StringSplit($filePath, "\")
   Local $fileName = $split[$split[0]]
   clearPhotoPreview()
   If FileDelete($filePath) == 0 Then
	  ;Delete Failed
	  MsgBox($MB_ICONERROR, "Error", "There was an error deleting the file:"&@CRLF&@CRLF&$filePath)
	  logMsg("Error Deleting File: "&$fileName)
   Else
	  _WinAPI_RedrawWindow ($gui)
	  refreshPhotoList(False)
	  logMsg("File Deleted: "&$fileName)
   EndIf
EndFunc

Func archivePhotoButton()
   Global $photoSaveDir
   Local $filePath = getSelectedPhoto()
   Local $split = StringSplit($filePath, "\")
   Local $fileName = $split[$split[0]]
   $res = FileCopy($filePath, $photoSaveDir & "\Archived\" & $fileName, $FC_OVERWRITE + $FC_CREATEPATH)
   If $res == 1 Then
	  MsgBox($MB_ICONINFORMATION, "Success", "The Photo has been archived for long-term storage."&@CRLF&@CRLF&"Location: "&$photoSaveDir & "\Archived\" & $fileName)
	  logMsg("Error Archiving File: "&$fileName)
   Else
	  MsgBox($MB_ICONERROR, "Error", "There was a problem archiving the file.")
	  logMsg("File Archived: "&$fileName)
   EndIf
EndFunc

Func copyPhotoButton()
   Local $filePath = getSelectedPhoto()
   Local $msg = ""
   _ClipPutFile($filePath)
   Switch @error
	  Case 0
		 MsgBox($MB_ICONINFORMATION, "Success", "The file was successfully copied to the clipboard")
		 Return
	  Case 1
		 $msg = "Unable to Open Clipboard"
	  Case 2
		 $msg = "Unable to Empty Cipboard"
	  Case 3
		 $msg = "GlobalAlloc Failed"
	  Case 4
		 $msg = "GlobalLock Failed"
	  Case 5
		 $msg = "Unable to Create H_DROP"
	  Case 6
		 $msg = "Unable to Update Clipboard"
	  Case 7
		 $msg = "Unable to Close Clipboard"
	  Case 8
		 $msg = "GlobalUnlock Failed"
	  Case 9
		 $msg = "GlobalFree Failed "
	  Case Else
		 $msg = "Unknown Error"
   EndSwitch
   MsgBox($MB_ICONERROR, "Error", "An error occured copying file to clipboard." &@CRLF&@CRLF&"Message: "&$msg)
EndFunc

Func trimToMaxPhotos()
   Global $maxNumberPhotos
   Local $count = 0

   ;Get a file search handle
   Local $search = FileFindFirstFile($photoSaveDir &"/*.png")

   ;If no matches return
   If $search = -1 Then
	  Return
   EndIf

   While True
	  $fileName = FileFindNextFile($search)
	  If @error Then ExitLoop
	  $count += 1
	  If $count > $maxNumberPhotos Then
		 FileDelete($photoSaveDir & "\" & $fileName)
		 logMsg("Max Photo Count Exceeded: File Deleted: " & $fileName)
	  EndIf
   WEnd
EndFunc

Func tabClick()
   Global $tabControl
   $tab = GUICtrlRead($tabControl)
   If $tab == 1 Then
	  photoList()
   EndIf
EndFunc

Func setPreviewImage($filePath)
   If FileExists($filePath) == False Then Return
   clearPhotoPreview()
   Global $previewObj, $previewObjX, $previewObjY, $previewObjWidth, $previewObjHeight
   Global $previewImgHwd, $previewImgThumbHwd, $previewImgGraphic
   Local $handle = GUICtrlGetHandle($previewObj)
   $previewImgHwd   = _GDIPlus_ImageLoadFromFile($filePath)
   $previewImgThumbHwd = _GDIPlus_ImageResize($previewImgHwd, $previewObjWidth, $previewObjHeight)
   $previewImgGraphic = _GDIPlus_GraphicsCreateFromHWND($handle)
   _GDIPlus_GraphicsDrawImage($previewImgGraphic, $previewImgThumbHwd, 0, 0)
EndFunc

Func getSelectedPhoto()
   Global $photoSaveDir
   Local $selectedPhoto = GUICtrlRead($photoList)
   Local $filePath = $photoSaveDir & "\" & $selectedPhoto
   Return $filePath
EndFunc

Func photoList()
   Local $filePath = getSelectedPhoto()
   setPreviewImage($filePath)
EndFunc

Func refreshPhotoList($selectTopAfterRefresh=True)
   Global $photoList
   Local $curSel = _GUICtrlListBox_GetCurSel($photoList)
   Local $maxIndex = 0
   GUICtrlSetData($photoList, "")
   Local $search = FileFindFirstFile($photoSaveDir&"\*.png")
   Dim $photosArr[1]
   $photosArr[0] = 0
   Local $listString = ""

   If $search = -1 Then
	  Return False
   EndIf

   Local $fileName = "", $iResult = 0

   While 1
	  $fileName = FileFindNextFile($search)
	  ; If there is no more file matching the search.
	  If @error Then ExitLoop

	  _ArrayAdd($photosArr, $fileName)
	  $photosArr[0] += 1
   WEnd

   FileClose($search)

   For $i = $photosArr[0] To 1 Step -1
	  $listString = $listString&"|"&$photosArr[$i]
   Next

   GUICtrlSetData($photoList, $listString)
   If $selectTopAfterRefresh Then
	  _GUICtrlListBox_SetCurSel($photoList, 0)
   Else
	  If $maxIndex >= 0 Then ;List is empty
		 $maxIndex = _GUICtrlListBox_GetCount($photoList)-1
		 If $curSel > $maxIndex Then $curSel = $maxIndex
		 _GUICtrlListBox_SetCurSel($photoList, $curSel)
	  EndIf
   EndIf
   photoList()
EndFunc

Func clearPhotoPreview()
   Global $previewImgHwd, $previewImgGraphic, $previewImgThumbHwd
   _GDIPlus_GraphicsDispose($previewImgGraphic)
   _GDIPlus_ImageDispose($previewImgHwd)
   _GDIPlus_ImageDispose($previewImgThumbHwd)
EndFunc

Func setPhasmoRunning($running)
   If $running == True Then
	  GUICtrlSetColor($phasmoLabel, $COLOR_GREEN)
	  GUICtrlSetData($phasmoLabel, "Running")
   Else
	  GUICtrlSetColor($phasmoLabel, $COLOR_RED)
	  GUICtrlSetData($phasmoLabel, "Not Running")
   EndIf
EndFunc

Func refreshSettings()
   Global $installDirText, $photoDirText, $intervalText, $minimizeOnCloseCheckBox, $maxNumberPhotosText
   Global $phasmoInstallDir, $invervalSeconds, $minimizeOnClose, $maxNumberPhotos

   GUICtrlSetData($installDirText, $phasmoInstallDir)
   GUICtrlSetData($photoDirText, $photoSaveDir)
   GUICtrlSetData($intervalText, $invervalSeconds)
   GUICtrlSetData($maxNumberPhotosText, $maxNumberPhotos)

   If $minimizeOnClose == True Then
	  GUICtrlSetState($minimizeOnCloseCheckBox, $GUI_CHECKED)
   Else
	  GUICtrlSetState($minimizeOnCloseCheckBox, $GUI_UNCHECKED)
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
   Local $minimizedOnCloseChecked = GUICtrlRead($minimizeOnCloseCheckBox)
   Global $phasmoInstallDir = GUICtrlRead($installDirText)
   Global $photoSaveDir = GUICtrlRead($photoDirText)
   Global $invervalSeconds = GUICtrlRead($intervalText)
   Global $maxNumberPhotos = GUICtrlRead($maxNumberPhotosText)
   Global $minimizeOnClose
   If $minimizedOnCloseChecked == $GUI_CHECKED Then
	  $minimizeOnClose = True
   Else
	  $minimizeOnClose = False
   EndIf

   IniWrite($configFilePath, "Settings", "PhasmoInstallDir", $phasmoInstallDir)
   IniWrite($configFilePath, "Settings", "PhotoSaveDir", $photoSaveDir)
   IniWrite($configFilePath, "Settings", "IntervalSecs", $invervalSeconds)
   IniWrite($configFilePath, "Settings", "MaxNumberPhotos", $maxNumberPhotos)
   IniWrite($configFilePath, "Settings", "MinimizeOnClose", $minimizeOnClose)
   MsgBox($MB_ICONINFORMATION, "Save Settings", "Settings have been saved.")
   logMsg("Settings have been saved")
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
   Global $phasmoInstallDir = IniRead($configFilePath, "Settings", "PhasmoInstallDir", "Not Set")
   Global $photoSaveDir = IniRead($configFilePath, "Settings", "PhotoSaveDir", "Not Set")
   Global $invervalSeconds = IniRead($configFilePath, "Settings", "IntervalSecs", "5")
   Global $minimizeOnClose = IniRead($configFilePath, "Settings", "MinimizeOnClose", False)
   Global $maxNumberPhotos = IniRead($configFilePath, "Settings", "MaxNumberPhotos", 200)
   Global $hashes = IniReadSection($configFilePath, "PhotoHashes")

   If @error Then
	  ;Error Reading Hashes from Config File
   Else
	  For $i = 1 To $hashes[0][0]
		 $photoHashes[$i-1] = $hashes[$i][1]
	  Next
   EndIf
EndFunc

Func writeConfig()
   saveSettings()
   updateConfigHashes()
EndFunc

Func updateConfigHashes()
   For $i = 0 To UBound($photoHashes)-1
	  IniWrite($configFilePath, "PhotoHashes", "Photo"&($i+1), $photoHashes[$i])
   Next
EndFunc

Func show()
   GUISetState(@SW_SHOW, $gui)
EndFunc

Func hide()
   Global $minimizeOnClose
   If $minimizeOnClose == True Then
	  GUISetState(@SW_HIDE, $gui)
   Else
	  quit()
   EndIf
EndFunc

Func quit()
   Global $previewImgHwd, $previewImgGraphic, $previewImgThumbHwd
   _GDIPlus_GraphicsDispose($previewImgGraphic)
   _GDIPlus_ImageDispose($previewImgHwd)
   _GDIPlus_ImageDispose($previewImgThumbHwd)
   _GDIPlus_ShutDown()
   ;Trim Number of Photos to Max
   trimToMaxPhotos()
   Exit
EndFunc

Func enforceSingleton()
   Local $procList = ProcessList("phasmophoto.exe")
   If $procList[0][0] > 1 Then
	  MsgBox($MB_ICONWARNING, "PhasmoPhoto", "An instance of PhasmoPhoto is already running. Exiting.")
	  Exit
   EndIf
EndFunc