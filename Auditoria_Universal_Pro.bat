<# :
@echo off
chcp 65001 >nul
title AUDITORIA UNIVERSAL PRO - TODA GAMA DE LAPTOPS (NUEVAS / USADAS / GAMER / OFICINA)
color 0B

net session >nul 2>&1
if %errorLevel% neq 0 (
    color 0E
    echo ===============================================================================
    echo [AVISO] Ejecutando SIN permisos de Administrador.
    echo Para leer Horas de Uso de discos HDD/SSD, Clave BIOS y Seguridad MDM completa:
    echo Cierra esta ventana -> Clic derecho al archivo -> "Ejecutar como administrador".
    echo ===============================================================================
    echo Presiona una tecla si deseas continuar en modo limitado...
    pause >nul
    color 0B
)

echo Escaneando todos los buses de la laptop (Placa, CPU, GPUs, RAM, HDD/SSD, EDID Pantalla, Puertos, Bateria)...
echo Esto tardara unos 6 a 10 segundos. No cierres la ventana...
echo.

set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:USB_DIR='%SCRIPT_DIR%'; Invoke-Expression ([System.IO.File]::ReadAllText('%~f0'))"

echo.
echo ===============================================================================
echo AUDITORIA TERMINADA.
echo Los reportes (.TXT y Bateria .HTML) se guardaron en la carpeta "Reportes_Tiendas"
echo dentro de la misma ubicacion desde donde ejecutaste este archivo (tu USB).
echo ===============================================================================
pause
exit /b
#>

# ==============================================================================
# MOTOR UNIVERSAL DE AUDITORIA FORENSE PARA CUALQUIER LAPTOP WINDOWS
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"

# Crear carpeta para guardar multiples laptops sin sobrescribirlas
$BaseDir = if ($env:USB_DIR) { $env:USB_DIR } else { [Environment]::GetFolderPath("Desktop") }
$SaveFolder = Join-Path $BaseDir "Reportes_Tiendas"
if (-not (Test-Path $SaveFolder)) { New-Item -ItemType Directory -Path $SaveFolder -Force | Out-Null }

$csTemp = Get-CimInstance Win32_ComputerSystem
$safeModel = (($csTemp.Manufacturer + "_" + $csTemp.Model) -replace '[^a-zA-Z0-9_-]', '_')
$timeStamp = Get-Date -Format "yyyyMMdd_HHmm"
$TxtReport = Join-Path $SaveFolder "Auditoria_${safeModel}_${timeStamp}.txt"
$BatReport = Join-Path $SaveFolder "Bateria_${safeModel}_${timeStamp}.html"

Start-Transcript -Path $TxtReport -Force | Out-Null

function Show-Header($titulo) {
    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host " $titulo" -ForegroundColor Yellow
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

function Translate-Vendor($id) {
    if ($id -match "VEN_10DE") { return "NVIDIA Corporation (Chip Fisico Dedicado)" }
    if ($id -match "VEN_1002" -or $id -match "VEN_1022") { return "AMD / ATI (Radeon Integrada o Dedicada)" }
    if ($id -match "VEN_8086") { return "Intel Corporation (UHD / Iris Xe / Arc)" }
    if ($id -match "VEN_1414") { return "Microsoft Basic Display (FALTA DRIVER DE VIDEO! No muestra Hz ni VRAM reales hasta instalar driver)" }
    if ($id -match "VEN_5143" -or $id -match "QCOM") { return "Qualcomm Adreno (Laptop ARM Snapdragon)" }
    return "Otro Fabricante OEM"
}

function Translate-RAMType($smbiosCode, $wmiCode) {
    switch ($smbiosCode) {
        20 { return "DDR (Muy antigua)" }
        21 { return "DDR2 (Muy antigua)" }
        24 { return "DDR3" }
        26 { return "DDR4" }
        29 { return "LPDDR3 (Soldada en placa)" }
        30 { return "LPDDR4 / LPDDR4X (Soldada en placa, NO ampliable en esa ranura)" }
        34 { return "DDR5" }
        35 { return "LPDDR5 / LPDDR5X (Soldada en placa de alta velocidad)" }
        default { return "Codigo SMBIOS=$smbiosCode / WMI=$wmiCode (Verificar pestaña Memory en CPU-Z)" }
    }
}

function Translate-FormFactor($ff) {
    switch ($ff) {
        8  { return "DIMM (Modulo grande)" }
        12 { return "SODIMM (Modulo extraible estandar de laptop - Reemplazable)" }
        13 { return " Chip Soldado / Integrado en Placa (NO extraible)" }
        default { return "Factor de forma codigo $ff" }
    }
}

function Translate-PanelMaker($mfg) {
    switch ($mfg) {
        "BOE" { return "BOE Technology (Muy comun en Lenovo, HP, ASUS)" }
        "AUO" { return "AU Optronics (Muy comun en Acer, MSI, ASUS)" }
        "LGD" { return "LG Display (Excelente calidad IPS/OLED)" }
        "CMN" { return "Innolux / Chi Mei (Comun en gama entrada y media)" }
        "SDC" { return "Samsung Display (Tipico en paneles AMOLED / OLED o gama alta)" }
        "SHP" { return "Sharp Display (IGZO / Gama alta)" }
        "CSO" { return "CSOT (China Star Optoelectronics - comun en Lenovo LOQ/Legion)" }
        "IVM" { return "InfoVision Optoelectronics" }
        "HKC" { return "HKC Corporation" }
        default { return "Fabricante codigo '$mfg'" }
    }
}

# ------------------------------------------------------------------------------
# 1. IDENTIDAD, BIOS, BLOQUEOS EMPRESARIALES Y REFURBISHED
# ------------------------------------------------------------------------------
Show-Header "1. PLACA BASE, BIOS, NUMERO DE SERIE, LICENCIA Y RIESGO REFURBISHED"
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$board = Get-CimInstance Win32_BaseBoard
$prod = Get-CimInstance Win32_ComputerSystemProduct
$enc = Get-CimInstance Win32_SystemEnclosure
$os = Get-CimInstance Win32_OperatingSystem
$lic = Get-CimInstance SoftwareLicensingService
$sb = Confirm-SecureBootUEFI 2>$null

$sku = "$($cs.SystemSKUNumber)".Trim()
$skuAlert = "(SKU estandar)"
if ($sku -match "R#ABA" -or $sku -match "R$" -or $cs.Model -match "Refurb") {
    $skuAlert = "(ALERTA! Código indica equipo OFICIALMENTE REFURBISHED / Reacondicionado)"
}

$sn = "$($bios.SerialNumber)".Trim()
$snAlert = "(Debe coincidir EXACTO con etiqueta inferior y caja)"
if ($sn -match "Default|O\.E\.M|000000|None|System Serial|123456" -or [string]::IsNullOrWhiteSpace($sn)) {
    $snAlert = "(PELIGRO! Serial borrado/generico: Placa madre cambiada o reprogramada en taller)"
}

# Verificar si pertenece a un dominio o MDM corporativo (Autopilot/Empresa)
$mdmEnroll = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments" -ErrorAction SilentlyContinue | Get-ItemProperty | Where-Object { $_.UPN -or $_.ProviderID }
$domainMsg = if ($cs.PartOfDomain) { "ALERTA ROJA! Unido a dominio empresarial: $($cs.Domain)" }
             elseif ($mdmEnroll) { "POSIBLE GESTION MDM/EMPRESARIAL DETECTADA (Verificar con Internet antes de pagar)" }
             else { "Limpio (Uso personal / Workgroup, sin dominio activo en Windows)" }

Write-Host "Marca y Modelo Comercial : $($cs.Manufacturer) | $($cs.Model)"
Write-Host "Familia / Linea Equipo   : $($cs.SystemFamily)"
Write-Host "Codigo Producto (SKU)    : $sku $skuAlert"
Write-Host "Serial en BIOS (Laptop)  : $sn $snAlert"
Write-Host "Serial en Chasis/Carcasa : $($enc.SerialNumber) (Si difiere del Serial BIOS, armaron 1 laptop usando piezas de 2!)"
Write-Host "Placa Base (Motherboard) : $($board.Manufacturer) | Modelo: $($board.Product) | Serie Placa: $($board.SerialNumber)"
Write-Host "UUID Fisico Placa Base   : $($prod.UUID)"
Write-Host "BIOS y Modo de Arranque  : Version $($bios.SMBIOSBIOSVersion) | Fecha: $($bios.ReleaseDate.ToString('yyyy-MM-dd')) | SecureBoot: $sb"
Write-Host "Sistema Operativo Actual : $($os.Caption) ($($os.OSArchitecture)) - Compilacion $($os.BuildNumber)"
Write-Host "Fecha Instalacion Windows: $($os.InstallDate.ToString('yyyy-MM-dd HH:mm:ss')) | Ultimo Encendido: $($os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Host "Estado Bloqueo Empresa   : $domainMsg"

if ($lic.OA3xOriginalProductKey) {
    Write-Host "Clave OEM en Chip BIOS   : $($lic.OA3xOriginalProductKey) ($($lic.OA3xOriginalProductKeyDescription) - Licencia Original de Fabrica)" -ForegroundColor Green
} else {
    Write-Host "Clave OEM en Chip BIOS   : SIN LICENCIA EN BIOS (Equipo FreeDOS/Linux original o placa reemplazada sin llave OEM)" -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# 2. PROCESADOR (CPU): DETECCION DE ENGAÑOS EN REGISTRO Y CACHES REALES
# ------------------------------------------------------------------------------
Show-Header "2. PROCESADOR (CPU) - SILICIO REAL vs NOMBRE MOSTRADO EN WINDOWS"
$cpus = Get-CimInstance Win32_Processor
foreach ($cpu in $cpus) {
    $regName = (Get-ItemProperty "HKLM:\HARDWARE\Description\System\CentralProcessor\0").ProcessorNameString
    $wmiName = $cpu.Name
    Write-Host "Texto en Registro Windows: $regName"
    Write-Host "Identificador Silicio    : $($cpu.Caption) | CPUID: $($cpu.ProcessorId) (Inalterable por edicion de texto)"
    Write-Host "Socket / Zocalo          : $($cpu.SocketDesignation) | Virtualizacion en Firmware: $($cpu.VirtualizationFirmwareEnabled)"
    Write-Host "Nucleos e Hilos Reales   : $($cpu.NumberOfCores) Nucleos Fisicos / $($cpu.NumberOfLogicalProcessors) Hilos Logicos"
    Write-Host "Frecuencia Base Reloj    : $($cpu.MaxClockSpeed) MHz ($([math]::Round($cpu.MaxClockSpeed/1000, 2)) GHz base sin Turbo)"
    Write-Host "Memoria Cache Fisica     : L2 = $([math]::Round($cpu.L2CacheSize/1024, 2)) MB | L3 = $([math]::Round($cpu.L3CacheSize/1024, 2)) MB"
}

# ------------------------------------------------------------------------------
# 3. TARJETAS GRAFICAS (INTEGRADA + DEDICADA), VRAM 64-BIT Y CODIGOS PCI
# ------------------------------------------------------------------------------
Show-Header "3. TARJETAS DE VIDEO (INTEGRADA Y DEDICADA), VRAM EXACTA Y CHIP PCI"
$regGPUs = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*" -ErrorAction SilentlyContinue
$gpus = Get-CimInstance Win32_VideoController

$gIdx = 1
foreach ($gpu in $gpus) {
    $pnp = $gpu.PNPDeviceID
    $venMeaning = Translate-Vendor $pnp
    $venCode = if ($pnp -match "VEN_([0-9A-F]{4})") { $matches[1] } else { "N/A" }
    $devCode = if ($pnp -match "DEV_([0-9A-F]{4})") { $matches[1] } else { "N/A" }
    $subsys  = if ($pnp -match "SUBSYS_([0-9A-F]{8})") { $matches[1] } else { "N/A" }
    $revCode = if ($pnp -match "REV_([0-9A-F]{2})") { $matches[1] } else { "N/A" }

    $vramBytes = [int64]$gpu.AdapterRAM
    $biosChipType = "No reportado"
    foreach ($rg in $regGPUs) {
        if ($rg.DriverDesc -eq $gpu.Name) {
            if ($rg."HardwareInformation.qwMemorySize") { $vramBytes = [int64]$rg."HardwareInformation.qwMemorySize" }
            elseif ($rg."HardwareInformation.MemorySize" -is [byte[]]) { }
            if ($rg."HardwareInformation.ChipType") { $biosChipType = $rg."HardwareInformation.ChipType" }
            break
        }
    }

    $esDedicada = ($venCode -eq "10DE") -or ($venCode -eq "1002" -and $gpu.Name -match "RX |Radeon PRO|XT|M ") -or ($venCode -eq "8086" -and $gpu.Name -match "Arc ")
    $categoria = if ($esDedicada) { "TARJETA GRAFICA DEDICADA (Chip independiente con VRAM propia)" } else { "GRAFICA INTEGRADA EN EL PROCESADOR (Toma memoria prestada de la RAM)" }
    $vramStr = if ($vramBytes -gt 0) { "$([math]::Round($vramBytes / 1GB, 2)) GB ($([math]::Round($vramBytes / 1MB, 0)) MB)" } else { "Memoria Compartida Dinamica" }

    Write-Host "--- GPU #$gIdx : $($gpu.Name) ---" -ForegroundColor Green
    Write-Host "  Clasificacion          : $categoria"
    Write-Host "  Nombre Interno Chip/DAC: $biosChipType | DAC: $($gpu.AdapterDACType)"
    Write-Host "  Capacidad VRAM Dedicada: $vramStr $(if(-not $esDedicada){'(Reserva asignada de la RAM principal)'})"
    Write-Host "  ID Fisico Completo     : $pnp"
    Write-Host "    -> VEN_$venCode          : ($venMeaning)"
    Write-Host "    -> DEV_$devCode          : (Codigo unico del chip de silicio; buscar 'PCI 10DE $devCode' o '$devCode' en devicehunt.com)"
    Write-Host "    -> SUBSYS_$subsys   : (ID de placa del ensamblador) | Revision: REV_$revCode"
    Write-Host "  Driver Instalado       : Version $($gpu.DriverVersion) (Fecha: $(if($gpu.DriverDate){$gpu.DriverDate.ToString('yyyy-MM-dd')}else{'N/A'})) | Estado: $($gpu.Status)"
    $gIdx++
}

# ------------------------------------------------------------------------------
# 4. MEMORIA RAM: MODULOS EXTRAIBLES vs SOLDADOS, CANALES, VELOCIDAD Y MARCA
# ------------------------------------------------------------------------------
Show-Header "4. MEMORIA RAM (CAPACIDAD TOTAL, RANURAS LIBRES, SOLDADA vs EXTRAIBLE)"
$memArray = Get-CimInstance Win32_PhysicalMemoryArray
$sticks = Get-CimInstance Win32_PhysicalMemory

$totalSlots = ($memArray | Measure-Object -Property MemoryDevices -Sum).Sum
$maxCapGB   = [math]::Round((($memArray | Measure-Object -Property MaxCapacity -Sum).Sum) / 1MB, 0)
$usedSlots  = ($sticks | Measure-Object).Count
$totalRAMGB = [math]::Round(($sticks | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
$canal      = if ($usedSlots -ge 2) { "Posible Dual-Channel Activo ($usedSlots bloques detectados)" } else { "Single-Channel (1 solo bloque activo; menor rendimiento en Ryzen/Graficos integrados)" }

Write-Host "Total RAM Instalada      : $totalRAMGB GB | Configuracion: $canal"
Write-Host "Ranuras en Placa Base    : $usedSlots ocupadas de $totalSlots totales reportadas (Soporte teorico BIOS hasta ~$maxCapGB GB)"
Write-Host ""

$sIdx = 1
foreach ($s in $sticks) {
    $capGB = [math]::Round($s.Capacity / 1GB, 2)
    $ddrType = Translate-RAMType $s.SMBIOSMemoryType $s.MemoryType
    $formFactor = Translate-FormFactor $s.FormFactor
    $mfg = if ([string]::IsNullOrWhiteSpace($s.Manufacturer)) { "Generica / Soldada en Placa" } else { $s.Manufacturer.Trim() }
    $part = if ([string]::IsNullOrWhiteSpace($s.PartNumber)) { "N/A" } else { $s.PartNumber.Trim() }
    $volt = if ($s.ConfiguredVoltage) { "$($s.ConfiguredVoltage / 1000) V" } else { "N/A" }

    Write-Host "  [Bloque RAM #$sIdx - Ubicacion: $($s.DeviceLocator) / $($s.BankLabel)]" -ForegroundColor Green
    Write-Host "    Tamano y Tecnologia  : $capGB GB | $ddrType"
    Write-Host "    Formato Fisico       : $formFactor"
    Write-Host "    Velocidad Activa     : $($s.ConfiguredClockSpeed) MT/s (Chip nominal: $($s.Speed) MT/s) | Voltaje: $volt"
    Write-Host "    Marca y Num. Parte   : Fabricante: $mfg | PartNumber: $part | Serie: $($s.SerialNumber)"
    $sIdx++
}

# ------------------------------------------------------------------------------
# 5. ALMACENAMIENTO UNIVERSAL (SOPORTA HDD MECANICO, SSD SATA, NVMe, eMMC, RAID)
# ------------------------------------------------------------------------------
Show-Header "5. DISCOS DUROS (HDD) Y SOLIDOS (SSD / NVMe / eMMC) - USO Y SALUD"
$phyDisks = Get-PhysicalDisk
$wmiDisks = Get-CimInstance Win32_DiskDrive

if ($phyDisks) {
    foreach ($d in $phyDisks) {
        $rel = $d | Get-StorageReliabilityCounter
        $sizeGB = [math]::Round($d.Size / 1GB, 2)
        
        # Detectar con exactitud si es HDD mecanico (con RPM), SSD, NVMe o eMMC
        $tipoReal = switch ($d.MediaType) {
            "HDD" { "DISCO DURO MECANICO ANTIGUO (HDD - Lento y sensible a golpes! Velocidad giro: $($d.SpindleSpeed) RPM)" }
            "SSD" { "UNIDAD DE ESTADO SOLIDO (SSD - Rapido, sin partes moviles)" }
            "SCM" { "Memoria Storage Class" }
            default {
                if ($d.SpindleSpeed -gt 0 -and $d.SpindleSpeed -lt 20000) { "DISCO DURO MECANICO (HDD - $($d.SpindleSpeed) RPM)" }
                elseif ($d.BusType -eq "SD" -or $d.BusType -eq "MMC") { "MEMORIA eMMC SOLDADA (Gama economica, lenta y NO ampliable)" }
                else { "Unidad Tipo $($d.MediaType) (Revisar Bus abajo)" }
            }
        }

        $busDesc = switch ($d.BusType) {
            "NVMe" { "NVMe PCIe (Maxima velocidad moderna: 2000 a 7000+ MB/s)" }
            "SATA" { "SATA III (Velocidad media: hasta 550 MB/s en SSD o ~120 MB/s en HDD)" }
            "RAID" { "Modo Intel RST / VMD / RAID activo en BIOS (Suele ser NVMe pero el driver RAID oculta datos SMART)" }
            "MMC"  { "Bus eMMC Soldado en placa" }
            "USB"  { "Memoria USB Externa (Probablemente TU propio pendrive)" }
            default { "Bus $($d.BusType)" }
        }

        Write-Host "--- DISCO #$($d.DeviceId) : $($d.FriendlyName) ---" -ForegroundColor Green
        Write-Host "  Que tecnologia tiene?  : $tipoReal"
        Write-Host "  Interfaz de Conexion   : $busDesc"
        Write-Host "  Capacidad Real Total   : $sizeGB GB (Nota: un disco anunciado de '512GB' muestra ~476GB reales; uno de '1TB' muestra ~931GB)"
        Write-Host "  Salud / Serie / Firmw. : Salud: $($d.HealthStatus) ($($d.OperationalStatus)) | Serie: $($d.SerialNumber) | FW: $($d.FirmwareVersion)"

        if ($d.BusType -ne "USB") {
            if ($null -ne $rel.PowerOnHours) {
                $hrs = $rel.PowerOnHours
                $dias = [math]::Round($hrs / 24, 1)
                $msgH = if ($hrs -le 30) { "(NUEVO DE CAJA: Menos de 30h de testeo en fabrica)" }
                        elseif ($hrs -le 250) { "(SEMI-NUEVO / VITRINA: Uso ligero de exhibicion)" }
                        else { "(USADO / SEGUNDA MANO: Equivalente a $dias dias continuos encendido!)" }
                Write-Host "  Horas Totales de Uso   : $hrs horas $msgH" -ForegroundColor Yellow
            } else {
                Write-Host "  Horas Totales de Uso   : Oculto por controlador $($d.BusType) de Windows -> Abre CrystalDiskInfo Portable en tu USB para ver horas y TB escritos" -ForegroundColor Yellow
            }
            Write-Host "  Desgaste y Temperatura : Desgaste SSD: $(if($null -ne $rel.Wear){"$($rel.Wear)%"}else{'N/A'}) | Temp: $(if($null -ne $rel.Temperature){"$($rel.Temperature) C"}else{'N/A'}) | Errores Lectura/Escritura: $($rel.ReadErrorsTotal) / $($rel.WriteErrorsTotal)"
        }
    }
} else {
    # Fallback extremo para Windows antiguos o drivers especiales
    foreach ($wd in $wmiDisks) {
        Write-Host "Disco detectado (Modo WMI): $($wd.Model) | Interfaz: $($wd.InterfaceType) | Tamano: $([math]::Round($wd.Size/1GB,2)) GB | Estado SMART: $($wd.Status)"
    }
}

# Mostrar particiones C:, D:, espacio libre
$vols = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
$partStr = ($vols | ForEach-Object { "$($_.DeviceID) $([math]::Round($_.Size/1GB,1))GB totales ($([math]::Round($_.FreeSpace/1GB,1))GB libres)" }) -join " | "
Write-Host "Particiones Internas     : $partStr"

# ------------------------------------------------------------------------------
# 6. PANTALLA COMPLETA: LECTURA BINARIA EDID, PULGADAS, BITS COLOR, IPS/TN/OLED Y HZ
# ------------------------------------------------------------------------------
Show-Header "6. PANTALLA PROFUNDA (EDID BINARIO, PULGADAS, BITS DE COLOR, HZ Y TIPO PANEL)"
Add-Type -AssemblyName System.Windows.Forms
$scrList = [System.Windows.Forms.Screen]::AllScreens
$vidCtrl = Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution -gt 0 } | Select-Object -First 1

if ($vidCtrl) {
    Write-Host "Modo Activo en Windows   : $($vidCtrl.CurrentHorizontalResolution) x $($vidCtrl.CurrentVerticalResolution) pixeles | Tasa Refresco Actual: $($vidCtrl.CurrentRefreshRate) Hz (Min: $($vidCtrl.MinRefreshRate) Hz / Max driver: $($vidCtrl.MaxRefreshRate) Hz)"
}

# Listar si la laptop soporta 120Hz/144Hz/165Hz/240Hz aunque ahorita este configurada en 60Hz!
$dispModes = Get-CimInstance CIM_VideoControllerResolution | Select-Object -ExpandProperty RefreshRate -Unique | Sort-Object
if ($dispModes) {
    Write-Host "Hercios Soportados Driver: $($dispModes -join ' Hz, ') Hz (Si el vendedor promete 144Hz y el maximo aqui es 60Hz con driver instalado, NO es 144Hz!)" -ForegroundColor Yellow
}

$monIds = Get-CimInstance WmiMonitorID -Namespace root\wmi
$monBasic = Get-CimInstance WmiMonitorBasicDisplayParams -Namespace root\wmi

# Leer EDID crudo de 128/256 bytes desde el Registro para sacar Version EDID, Bits de Color y Codigo Real ASCII (Ej: NV156FHM-N61)
$edidRegs = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY\*\*" -ErrorAction SilentlyContinue

for ($i = 0; $i -lt $monIds.Count; $i++) {
    $m = $monIds[$i]
    $b = if ($monBasic.Count -gt $i) { $monBasic[$i] } else { $null }
    
    $mfgCode = ([System.Text.Encoding]::ASCII.GetString($m.ManufacturerName)).Trim([char]0)
    $prodHex = ([System.Text.Encoding]::ASCII.GetString($m.ProductCodeID)).Trim([char]0)
    $mfgDesc = Translate-PanelMaker $mfgCode

    # Calcular pulgadas reales con teorema de Pitagoras desde centimetros fisicos del EDID
    $inchStr = "No reportado"
    if ($b -and $b.MaxHorizontalImageSize -gt 0 -and $b.MaxVerticalImageSize -gt 0) {
        $diagCm = [math]::Sqrt([math]::Pow($b.MaxHorizontalImageSize, 2) + [math]::Pow($b.MaxVerticalImageSize, 2))
        $inches = [math]::Round($diagCm / 2.54, 1)
        $inchStr = "$inches pulgadas reales ($($b.MaxHorizontalImageSize) cm ancho x $($b.MaxVerticalImageSize) cm alto)"
    }

    # Decodificar EDID Binario Crudo
    $edidVer = "N/A"
    $colorDepth = "No especificado en EDID"
    $internalPartName = ""
    foreach ($er in $edidRegs) {
        if ($er.PSPath -match "$mfgCode$prodHex") {
            $devParam = Join-Path $er.PSPath "Device Parameters"
            $edidBytes = (Get-ItemProperty $devParam -ErrorAction SilentlyContinue).EDID
            if ($edidBytes -and $edidBytes.Length -ge 128) {
                $edidVer = "EDID v$($edidBytes[18]).$($edidBytes[19])"
                # Byte 20 del estandar VESA EDID 1.4 indica profundidad de bits por color primario
                $vidInput = $edidBytes[20]
                if (($vidInput -band 0x80) -ne 0) {
                    $bpcCode = ($vidInput -shr 4) -band 0x07
                    $colorDepth = switch ($bpcCode) {
                        1 { "6-bit por canal (~262k colores / ~45% NTSC - Tipico de pantallas basicas o TN economicas)" }
                        2 { "8-bit nativos por canal (16.7 Millones de colores - Tipico de paneles IPS / OLED de buena calidad)" }
                        3 { "10-bit nativos por canal (1.07 Billones de colores - Panel HDR / OLED / IPS Profesional)" }
                        4 { "12-bit nativos" }
                        default { "Digital estandar (Codigo bits=$bpcCode)" }
                    }
                }
                # Buscar descriptores de texto ASCII en los bloques de 18 bytes (bytes 54 a 125) para hallar el modelo comercial exacto del panel
                for ($offset = 54; $offset -le 108; $offset += 18) {
                    if ($edidBytes[$offset] -eq 0 -and $edidBytes[$offset+1] -eq 0 -and $edidBytes[$offset+3] -in @(0xFE, 0xFC)) {
                        $txt = ([System.Text.Encoding]::ASCII.GetString($edidBytes[($offset+5)..($offset+17)])).Trim()
                        if ($txt) { $internalPartName += "[$txt] " }
                    }
                }
            }
        }
    }

    # Pista inteligente sobre IPS / TN / OLED basada en el numero de parte interno cuando existe
    $pistaTipo = "Verificar codigo en Panelook.com o inclinando la pantalla 45 grados hacia abajo (Si se invierten los colores a negro/negativo = TN; si se ve nitido desde cualquier angulo = IPS/OLED)"
    if ($mfgCode -eq "SDC" -and $internalPartName -match "ATNA|AMS") { $pistaTipo = "PANEL SAMSUNG AMOLED / OLED DETECTADO!" }
    elseif ($internalPartName -match "NV\d+|LP\d+|B\d+HAN|N\d+HCA|NE\d+|MNG") { $pistaTipo = "Nomenclatura tipica de panel IPS / AHVA / WVA (Angulos de vision amplios)" }
    elseif ($internalPartName -match "NT\d+|B\d+HTN|N\d+HGA") { $pistaTipo = "ALERTA! Nomenclatura tipica de panel TN basico (Malos colores y angulos pobres)" }

    Write-Host "--- PANEL INTERNO DETECTADO : $mfgCode$prodHex $internalPartName ---" -ForegroundColor Green
    Write-Host "  Fabricante del LCD     : $mfgCode -> ($mfgDesc)"
    Write-Host "  Version EDID y Tamano  : $edidVer | Diagonal Fisica: $inchStr"
    Write-Host "  Modelo Interno Grabado : $(if($internalPartName){$internalPartName}else{"$mfgCode$prodHex (Sin cadena ASCII extra)"})"
    Write-Host "  Profundidad de Color   : $colorDepth"
    Write-Host "  Deteccion IPS/TN/OLED  : $pistaTipo" -ForegroundColor Yellow
    Write-Host "  Fecha Fabricacion LCD  : Ano $($m.YearOfManufacture), Semana $($m.WeekOfManufacture) (Comparar con el ano de la laptop para detectar cambio de pantalla)"
    Write-Host "  Link Ficha Exacta      : https://www.panelook.com/modelsearch.php?keyword=$mfgCode$prodHex"
}

# ------------------------------------------------------------------------------
# 7. BATERIA COMPLETA (DETECTA SI TIENE BATERIA, SI ESTA MUERTA, CICLOS Y FECHAS)
# ------------------------------------------------------------------------------
Show-Header "7. BATERIA (CAPACIDAD ORIGINAL vs ACTUAL, SALUD %, CICLOS E HISTORIAL)"
$winBat = Get-CimInstance Win32_Battery
if (-not $winBat) {
    Write-Host "NO SE DETECTA BATERIA! (Esta desconectada por dentro, muerta al 100% o es PC de escritorio)" -ForegroundColor Red
} else {
    Write-Host "Estado de Carga Actual   : $($winBat.EstimatedChargeRemaining)% de bateria disponible ahorita"
}

$xmlPath = Join-Path $env:TEMP "bat_univ.xml"
powercfg /batteryreport /xml /output $xmlPath | Out-Null

if (Test-Path $xmlPath) {
    [xml]$batXml = Get-Content $xmlPath
    $bList = $batXml.BatteryReport.Batteries.Battery
    foreach ($b in $bList) {
        $design = [int64]$b.DesignCapacity
        $full   = [int64]$b.FullChargeCapacity
        $cycles = "$($b.CycleCount)".Trim()
        $salud  = if ($design -gt 0) { [math]::Round(($full / $design) * 100, 1) } else { 0 }
        $wear   = [math]::Round(100 - $salud, 1)

        $msgS = if ($salud -ge 98) { "(NUEVA / INTACTA)" }
                elseif ($salud -ge 88) { "(DESGASTE LEVE: Perdio $wear% - Equipo de vitrina o seminuevo)" }
                else { "(BATERIA DEGRADADA: Perdio $wear% de vida util! Pedir rebaja o descartar)" }

        Write-Host "Modelo y Quimica         : $($b.Id) | Fabricante: $($b.Manufacturer) | Quimica: $($b.Chemistry) | Serie: $($b.SerialNumber)"
        Write-Host "Capacidad Fabrica vs Hoy : Diseno = $design mWh | Maxima Actual = $full mWh"
        Write-Host "Porcentaje Salud Bateria : $salud% de vida util restante $msgS" -ForegroundColor Yellow
        Write-Host "Ciclos de Carga Contados : $(if($cycles){"$cycles ciclos"}else{'No expuesto por este modelo (Ver tabla de uso en el HTML)'})" -ForegroundColor Yellow
    }
    # Ver primera fecha historica registrada en el controlador de Windows
    $histNodes = $batXml.BatteryReport.History.HistoryEntry
    if ($histNodes) {
        $firstDate = ($histNodes | Select-Object -First 1).StartDate
        Write-Host "Registro Historico Mas Antiguo en Windows: $firstDate (Si es antigua, no fue formateada desde esa fecha)"
    }
    Remove-Item $xmlPath -Force -ErrorAction SilentlyContinue
}

powercfg /batteryreport /output $BatReport | Out-Null
Start-Process $BatReport

# ------------------------------------------------------------------------------
# 8. PERIFERICOS INTERNOS (WIFI, BLUETOOTH, AUDIO, WEBCAM, TOUCHPAD, BIOMETRIA, USB)
# ------------------------------------------------------------------------------
Show-Header "8. ESCANEO GENERAL DE COMPONENTES RESTANTES (WIFI, CAMARA, AUDIO, TPM, DRIVERS CON FALLA)"

# Red Wi-Fi y Ethernet
$nets = Get-NetAdapter -Physical
foreach ($n in $nets) {
    Write-Host "Red / Wi-Fi Fisico       : [$($n.Name)] $($n.InterfaceDescription) | MAC: $($n.MacAddress) | Estado: $($n.Status)"
}

# Bluetooth
$bt = Get-PnpDevice -Class Bluetooth -Status OK -ErrorAction SilentlyContinue | Where-Object { $_.FriendlyName -notmatch "Enumerator| Enumerador|Service|Protocol|RFCOMM|Generic" } | Select-Object -First 2
if ($bt) { Write-Host "Bluetooth Detectado      : $(($bt.FriendlyName) -join ', ')" } else { Write-Host "Bluetooth Detectado      : No activo o falta driver" -ForegroundColor Yellow }

# Camara Web integrada
$cams = Get-PnpDevice -Class Camera,Image -Status OK -ErrorAction SilentlyContinue
if ($cams) { Write-Host "Camara Web Integrada     : $(($cams.FriendlyName) -join ', ') (OK)" } else { Write-Host "Camara Web Integrada     : NO DETECTADA! (Verificar boton fisico/Fn de bloqueo de camara o cable flex roto)" -ForegroundColor Red }

# Audio / Parlantes / Microfono
$aud = Get-CimInstance Win32_SoundDevice | Where-Object { $_.Status -eq "OK" }
if ($aud) { Write-Host "Chips de Sonido / Audio  : $(($aud.Name | Select-Object -Unique) -join ' | ')" }

# Lector de Huellas / Windows Hello Biometrico
$bio = Get-PnpDevice -Class Biometric -Status OK -ErrorAction SilentlyContinue
if ($bio) { Write-Host "Sensor Biometrico/Huella : $(($bio.FriendlyName) -join ', ')" } else { Write-Host "Sensor Biometrico/Huella : No incluye lector de huellas (o falta driver)" }

# Controladoras USB (Detecta si trae USB4 / Thunderbolt / USB 3.x)
$usbCtrl = Get-CimInstance Win32_USBController | Select-Object -ExpandProperty Name -Unique
Write-Host "Controladoras Puertos USB: $($usbCtrl -join ' | ')"

# Chip TPM 2.0
$tpm = Get-Tpm
if ($tpm) {
    Write-Host "Seguridad TPM (Win 11)   : Presente=$($tpm.TpmPresent) | Listo=$($tpm.TpmReady) | Version Fabricante=$($tpm.ManufacturerVersion)"
}

# ALERTA CRITICA: Dispositivos con signo de exclamacion amarillo o fallando en el Administrador de Dispositivos!
$brokenDevs = Get-PnpDevice | Where-Object { $_.ConfigManagerErrorCode -ne 0 -and $_.Present -eq $true }
if ($brokenDevs) {
    Write-Host ""
    Write-Host "[!] ALERTA DE HARDWARE O DRIVERS CON ERROR EN ADMINISTRADOR DE DISPOSITIVOS:" -ForegroundColor Red
    foreach ($bd in $brokenDevs) {
        Write-Host "    -> FALLA: $($bd.FriendlyName) ($($bd.Class)) - Codigo Error Windows: $($bd.ConfigManagerErrorCode)" -ForegroundColor Red
        if ($bd.ConfigManagerErrorCode -eq 43) {
            Write-Host "       (PELIGRO EXTREMO! 'Error Codigo 43' en una tarjeta grafica dedicada significa CHIP QUEMADO/DESOLDADO o VBIOS FALSA!)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "Salud Drivers Hardware   : PERFECTO (0 dispositivos con errores o triangulos amarillos en el sistema)" -ForegroundColor Green
}

Stop-Transcript | Out-Null