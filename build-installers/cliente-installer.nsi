; NSIS Installer Script para PricingML Cliente
; Compilar con: makensis cliente-installer.nsi

!include "MUI2.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"

; Configuración General
Name "PricingML Cliente v1.0.0"
OutFile "..\dist\PricingML-Cliente-Setup.exe"
InstallDir "$PROGRAMFILES\PricingML\Cliente"
InstallDirRegKey HKCU "Software\PricingML\Cliente" "InstallDir"

; Permisos
RequestExecutionLevel admin

; Variables
Var NodeFound
Var APIBaseURL

; ============================================================================
; Interface
; ============================================================================

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
Page custom OptionsPage OptionsPageLeave
!insertmacro MUI_PAGE_INSTFILES
Page custom FinishPage
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_RESERVEFILE_LANGDLL

; ============================================================================
; Secciones
; ============================================================================

Section "Instalar Cliente" SectionCliente
  SectionIn RO

  SetOutPath "$INSTDIR"

  DetailPrint "Copiando archivos del Cliente..."

  ; Crear directorios
  CreateDirectory "$INSTDIR\wwwroot"
  CreateDirectory "$INSTDIR\config"
  CreateDirectory "$INSTDIR\logs"

  ; Copiar archivos build de React (dist)
  SetOverwrite on
  File /r "\..\PricingClient\pricing-ui\dist\*.*"

  ; Crear archivo de configuración
  DetailPrint "Configurando Cliente..."
  Call CreateConfig

  ; Crear script de inicio
  Call CreateStartScript

  ; Guardar en registro
  WriteRegStr HKCU "Software\PricingML\Cliente" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\PricingML\Cliente" "Version" "1.0.0"
  WriteRegStr HKCU "Software\PricingML\Cliente" "APIBaseURL" "$APIBaseURL"

  ; Crear menú Inicio
  CreateDirectory "$SMPROGRAMS\PricingML"
  CreateShortcut "$SMPROGRAMS\PricingML\Cliente - Abrir.lnk" "http://localhost:3000"
  CreateShortcut "$SMPROGRAMS\PricingML\Cliente - Iniciar Servidor.lnk" "$INSTDIR\start-server.bat" "" "$INSTDIR\favicon.ico"
  CreateShortcut "$SMPROGRAMS\PricingML\Cliente - Desinstalar.lnk" "$INSTDIR\uninstall.exe"

  ; Crear atajo en Escritorio (opcional)
  CreateShortcut "$DESKTOP\PricingML Cliente.lnk" "http://localhost:3000" "" "$INSTDIR\favicon.ico"

  ; Crear desinstalador
  WriteUninstaller "$INSTDIR\uninstall.exe"

  DetailPrint "Cliente instalado exitosamente"
SectionEnd

Section "Verificar Dependencias" SectionDeps
  DetailPrint "Verificando dependencias..."
  Call VerifyDependencies
SectionEnd

; ============================================================================
; Funciones
; ============================================================================

Function OptionsPage
  nsDialogs::Create 1018
  Pop $0

  ${NSD_CreateLabel} 0 10 100% 20 "Configuración del Cliente"
  Pop $0

  ${NSD_CreateLabel} 10 40 100% 15 "URL del Motor (API):"
  Pop $0

  ${NSD_CreateText} 10 60 100% 12 "http://localhost:5000"
  Pop $0
  ${NSD_OnChange} $0 OnAPIURLChange
  StrCpy $APIBaseURL "http://localhost:5000"

  ${NSD_CreateLabel} 10 85 100% 50 "Ejemplos:$\n- Servidor local: http://localhost:5000$\n- IP remota: http://192.168.1.100:5000$\n- Dominio: http://api.tudominio.com"
  Pop $0

  nsDialogs::Show
FunctionEnd

Function OnAPIURLChange
  Pop $0
  ${NSD_GetText} $0 $APIBaseURL
FunctionEnd

Function OptionsPageLeave
  ; Validar URL
  ${If} $APIBaseURL == ""
    StrCpy $APIBaseURL "http://localhost:5000"
  ${EndIf}
FunctionEnd

Function VerifyDependencies
  DetailPrint "Verificando Motor en: $APIBaseURL..."

  ; Aquí se podría hacer un ping HTTP, pero NSIS no tiene soporte nativo
  ; Se dejará para validar en runtime
  DetailPrint "Validación de conectividad se hará al iniciar"
FunctionEnd

Function CreateConfig
  ; Crear archivo de configuración del cliente
  FileOpen $0 "$INSTDIR\config.json" w
  FileWrite $0 "{$\n"
  FileWrite $0 '  "api": {$\n'
  FileWrite $0 '    "baseUrl": "$APIBaseURL"$\n'
  FileWrite $0 "  },$\n"
  FileWrite $0 '  "port": 3000$\n'
  FileWrite $0 "}"
  FileClose $0
  DetailPrint "config.json creado"
FunctionEnd

Function CreateStartScript
  ; Crear script batch para iniciar servidor HTTP
  FileOpen $0 "$INSTDIR\start-server.bat" w
  FileWrite $0 "@echo off$\n"
  FileWrite $0 "REM Servidor HTTP simple para PricingML Cliente$\n"
  FileWrite $0 "cd /d %~dp0$\n"
  FileWrite $0 "echo Iniciando servidor en puerto 3000...$\n"
  FileWrite $0 "echo Accede a: http://localhost:3000$\n"
  FileWrite $0 "python -m http.server 3000 --directory . 2>nul || (echo Python no encontrado, intentando con Node.js && npx http-server -p 3000)$\n"
  FileClose $0

  ; Crear script PowerShell alternativo
  FileOpen $0 "$INSTDIR\start-server.ps1" w
  FileWrite $0 "# Script para iniciar servidor HTTP en PowerShell$\n"
  FileWrite $0 "cd `$PSScriptRoot$\n"
  FileWrite $0 "Write-Host 'Iniciando servidor en puerto 3000...'$\n"
  FileWrite $0 "Write-Host 'Accede a: http://localhost:3000'$\n"
  FileWrite $0 "python -m http.server 3000 --directory .$\n"
  FileClose $0

  DetailPrint "Scripts de inicio creados"
FunctionEnd

Function FinishPage
  ; Página final con instrucciones
  nsDialogs::Create 1018
  Pop $0

  ${NSD_CreateLabel} 0 10 100% 20 "¡Instalación Completa!"
  Pop $0

  ${NSD_CreateLabel} 10 35 100% 50 "Próximos pasos:$\n1. El Cliente se instaló en: $INSTDIR$\n2. Asegúrate que el Motor está corriendo en: $APIBaseURL$\n3. Abre http://localhost:3000 en tu navegador$\n4. O ejecuta 'start-server.bat' para iniciar el servidor local"
  Pop $0

  ${NSD_CreateCheckbox} 10 100 100% 15 "Abrir Cliente en navegador al terminar"
  Pop $0
  ${NSD_Check} $0

  nsDialogs::Show
FunctionEnd

; ============================================================================
; Desinstalación
; ============================================================================

Section "Uninstall"
  DetailPrint "Desinstalando Cliente..."

  ; Eliminar archivos
  RMDir /r "$INSTDIR"

  ; Eliminar accesos directos
  RMDir /r "$SMPROGRAMS\PricingML"
  Delete "$DESKTOP\PricingML Cliente.lnk"

  ; Eliminar registro
  DeleteRegKey HKCU "Software\PricingML\Cliente"

  DetailPrint "Cliente desinstalado"
SectionEnd

; ============================================================================
; Inicialización
; ============================================================================

Function .onInit
  ${If} ${RunningX64}
    SetRegView 64
  ${Else}
    SetRegView 32
  ${EndIf}
FunctionEnd

Function .onInstSuccess
  MessageBox MB_YESNO "¿Abrir el Cliente ahora en tu navegador?" IDYES OpenBrowser IDNO SkipBrowser

  OpenBrowser:
    ExecShell "open" "http://localhost:3000"

  SkipBrowser:
FunctionEnd
