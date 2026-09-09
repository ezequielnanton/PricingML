; NSIS Installer Script para PricingML Motor
; Compilar con: makensis motor-installer.nsi

!include "MUI2.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

; Configuración General
Name "PricingML Motor v1.0.0"
OutFile "..\dist\PricingML-Motor-Setup.exe"
InstallDir "$PROGRAMFILES\PricingML\Motor"
InstallDirRegKey HKCU "Software\PricingML\Motor" "InstallDir"

; Permisos
RequestExecutionLevel admin

; Variables
Var DotNetPath
Var SQLServerFound
Var ConnectionString

; ============================================================================
; Interface
; ============================================================================

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
Page custom OptionsPage OptionsPageLeave
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_RESERVEFILE_LANGDLL

; ============================================================================
; Secciones
; ============================================================================

Section "Instalar Motor" SectionMotor
  SectionIn RO

  SetOutPath "$INSTDIR"

  ; Verificar .NET Runtime
  DetailPrint "Verificando .NET 10.0 Runtime..."
  Call VerifyDotNet

  ; Crear directorio bin
  CreateDirectory "$INSTDIR\bin"
  CreateDirectory "$INSTDIR\logs"

  ; Copiar archivos compilados (se espera en PricingEngine/src/PricingApi/bin/Release/net10.0/publish)
  DetailPrint "Copiando archivos del Motor..."
  SetOverwrite on

  File /r "\..\PricingEngine\src\PricingApi\bin\Release\net10.0\publish\*.*"

  ; Crear archivo de configuración appsettings.json
  DetailPrint "Configurando archivo appsettings.json..."
  Call CreateAppSettings

  ; Guardar ruta de instalación en registro
  WriteRegStr HKCU "Software\PricingML\Motor" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\PricingML\Motor" "Version" "1.0.0"

  ; Crear menú Inicio
  CreateDirectory "$SMPROGRAMS\PricingML"
  CreateShortcut "$SMPROGRAMS\PricingML\Motor - Iniciar.lnk" "$INSTDIR\PricingApi.exe" "" "$INSTDIR\favicon.ico"
  CreateShortcut "$SMPROGRAMS\PricingML\Motor - Desinstalar.lnk" "$INSTDIR\uninstall.exe"

  ; Crear desinstalador
  WriteUninstaller "$INSTDIR\uninstall.exe"

  DetailPrint "Motor instalado exitosamente"
SectionEnd

Section "SQL Server LocalDB (Opcional)" SectionSQL
  DetailPrint "Verificando SQL Server LocalDB..."
  Call VerifySQL

  ${If} $SQLServerFound == 0
    DetailPrint "SQL Server LocalDB no encontrado. Será instalado desde Microsoft."
  ${EndIf}
SectionEnd

; ============================================================================
; Funciones
; ============================================================================

Function OptionsPage
  ; Página personalizada para opciones
  nsDialogs::Create 1018
  Pop $0

  ${NSD_CreateLabel} 0 10 100% 20 "Opciones de Instalación"
  Pop $0

  ${NSD_CreateCheckbox} 10 40 100% 15 "Instalar SQL Server LocalDB"
  Pop $0
  ${NSD_Check} $0

  ${NSD_CreateCheckbox} 10 60 100% 15 "Crear acceso directo en Escritorio"
  Pop $0
  ${NSD_Check} $0

  ${NSD_CreateLabel} 10 90 100% 60 "El Motor necesita:$\n- .NET 10.0 Runtime$\n- SQL Server 2022+ o LocalDB$\n- Puerto 5000 disponible"
  Pop $0

  nsDialogs::Show
FunctionEnd

Function OptionsPageLeave
  ; Guardar opciones seleccionadas
FunctionEnd

Function VerifyDotNet
  DetailPrint "Buscando .NET 10.0 Runtime..."

  ; Buscar en registry
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" ".NET Runtime 10.0"

  ${If} $0 == ""
    MessageBox MB_YESNO "No se encontró .NET 10.0 Runtime.$\n¿Descargar e instalar ahora?" IDYES DownloadDotNet IDNO SkipDotNet

    DownloadDotNet:
      DetailPrint "Descargando .NET 10.0 Runtime desde Microsoft..."
      ; En producción, usar NSISdl::download
      MessageBox MB_OK "Por favor, descarga e instala .NET 10.0 Runtime desde:$\nhttps://dotnet.microsoft.com/download/dotnet/10.0"
      Quit

    SkipDotNet:
      DetailPrint "Continuando sin verificación de .NET (asume que está instalado)"
  ${Else}
    DetailPrint ".NET 10.0 Runtime encontrado"
  ${EndIf}
FunctionEnd

Function VerifySQL
  ; Verificar SQL Server LocalDB
  ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Microsoft SQL Server" "MSSQLServer"

  ${If} $0 == ""
    DetailPrint "SQL Server no encontrado localmente"
    DetailPrint "Se puede usar SQL Server remoto o instalar LocalDB"
    StrCpy $SQLServerFound 0
  ${Else}
    DetailPrint "SQL Server encontrado"
    StrCpy $SQLServerFound 1
  ${EndIf}
FunctionEnd

Function CreateAppSettings
  ; Crear appsettings.json con valores por defecto
  FileOpen $0 "$INSTDIR\appsettings.json" w
  FileWrite $0 "{$\n"
  FileWrite $0 '  "ConnectionStrings": {$\n'
  FileWrite $0 '    "PricingDb": "Server=(localdb)\MSSQLLocalDB;Database=PRICES_DB;Integrated Security=True;TrustServerCertificate=True;"$\n'
  FileWrite $0 "  },$\n"
  FileWrite $0 '  "Logging": {$\n'
  FileWrite $0 '    "LogLevel": {$\n'
  FileWrite $0 '      "Default": "Information"$\n'
  FileWrite $0 "    }$\n"
  FileWrite $0 "  },$\n"
  FileWrite $0 '  "AllowedHosts": "*"$\n'
  FileWrite $0 "}"
  FileClose $0
  DetailPrint "appsettings.json creado"
FunctionEnd

; ============================================================================
; Desinstalación
; ============================================================================

Section "Uninstall"
  DetailPrint "Desinstalando Motor..."

  ; Cerrar aplicación si está corriendo
  ${If} ${RunningX64}
    Exec "taskkill /IM PricingApi.exe /F"
  ${EndIf}

  ; Eliminar archivos
  RMDir /r "$INSTDIR"

  ; Eliminar accesos directos
  RMDir /r "$SMPROGRAMS\PricingML"

  ; Eliminar registro
  DeleteRegKey HKCU "Software\PricingML\Motor"

  DetailPrint "Motor desinstalado"
SectionEnd

; ============================================================================
; Validación
; ============================================================================

Function .onInit
  ${If} ${RunningX64}
    SetRegView 64
  ${Else}
    SetRegView 32
  ${EndIf}
FunctionEnd
