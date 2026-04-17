$ErrorActionPreference = "SilentlyContinue"

function Find-FirstCommand {
  param(
    [string[]]$Names
  )

  foreach ($name in $Names) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) {
      return $cmd.Source
    }
  }

  return $null
}

function Find-FirstExistingFile {
  param(
    [string[]]$Paths
  )

  foreach ($path in $Paths) {
    if ($path -and (Test-Path $path)) {
      return (Resolve-Path $path).Path
    }
  }

  return $null
}

function Find-ByPattern {
  param(
    [string[]]$Patterns
  )

  foreach ($pattern in $Patterns) {
    $match = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty FullName
    if ($match) {
      return $match
    }
  }

  return $null
}

function Get-RecursiveSearchRoots {
  $roots = New-Object System.Collections.Generic.List[string]
  $drives = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }

  foreach ($drive in $drives) {
    $base = $drive.DeviceID + "\"
    foreach ($candidate in @(
      $base,
      (Join-Path $base "tools"),
      (Join-Path $base "Program Files"),
      (Join-Path $base "Program Files (x86)"),
      (Join-Path $base "ST"),
      (Join-Path $base "Users")
    )) {
      if ((Test-Path $candidate) -and (-not $roots.Contains($candidate))) {
        $roots.Add($candidate)
      }
    }
  }

  return $roots
}

function Find-BestRecursiveMatch {
  param(
    [string[]]$FileNames,
    [string[]]$PreferredPatterns
  )

  $matches = New-Object System.Collections.Generic.List[string]
  $roots = Get-RecursiveSearchRoots

  foreach ($root in $roots) {
    foreach ($fileName in $FileNames) {
      Get-ChildItem -Path $root -Filter $fileName -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
          if (-not $matches.Contains($_.FullName)) {
            $matches.Add($_.FullName)
          }
        }
    }
  }

  if ($matches.Count -eq 0) {
    return $null
  }

  $ranked = $matches | Sort-Object `
    @{ Expression = {
         $path = $_
         $score = 1000
         foreach ($pattern in $PreferredPatterns) {
           if ($path -match $pattern) {
             $score -= 100
           }
         }
         $score
       }
     }, `
    @{ Expression = { $_.Length } }

  return $ranked[0]
}

$jlinkExe = Find-FirstCommand @("JLink.exe")
if (-not $jlinkExe) {
  $jlinkExe = Find-FirstExistingFile @(
    "C:\Program Files (x86)\SEGGER\JLink\JLink.exe",
    "C:\Program Files\SEGGER\JLink\JLink.exe"
  )
}
if (-not $jlinkExe) {
  $jlinkExe = Find-BestRecursiveMatch @("JLink.exe") @("SEGGER", "JLink")
}

$jlinkGdbServer = Find-FirstCommand @("JLinkGDBServerCL.exe")
if (-not $jlinkGdbServer) {
  $jlinkGdbServer = Find-FirstExistingFile @(
    "C:\Program Files (x86)\SEGGER\JLink\JLinkGDBServerCL.exe",
    "C:\Program Files\SEGGER\JLink\JLinkGDBServerCL.exe"
  )
}
if (-not $jlinkGdbServer) {
  $jlinkGdbServer = Find-BestRecursiveMatch @("JLinkGDBServerCL.exe") @("SEGGER", "JLink")
}

$stlinkGdbServer = Find-FirstCommand @("ST-LINK_gdbserver.exe", "ST-LINK_gdbserver")
if (-not $stlinkGdbServer) {
  $stlinkGdbServer = Find-ByPattern @(
    "C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\ST-LINK_gdbserver.exe",
    "C:\ST\STM32CubeIDE_*\STM32CubeIDE\plugins\**\tools\bin\ST-LINK_gdbserver.exe"
  )
}
if (-not $stlinkGdbServer) {
  $stlinkGdbServer = Find-BestRecursiveMatch @("ST-LINK_gdbserver.exe") @("STMicroelectronics", "STM32Cube", "CubeProgrammer", "CubeIDE")
}

$openOcd = Find-FirstCommand @("openocd.exe", "openocd")
if (-not $openOcd) {
  $openOcd = Find-ByPattern @(
    "C:\Users\*\tools\xpack-openocd-*\bin\openocd.exe",
    "C:\OpenOCD\bin\openocd.exe",
    "C:\Program Files\OpenOCD\bin\openocd.exe",
    "C:\ST\STM32CubeIDE_*\STM32CubeIDE\plugins\**\tools\bin\openocd.exe"
  )
}
if (-not $openOcd) {
  $openOcd = Find-BestRecursiveMatch @("openocd.exe") @("xpack-openocd", "OpenOCD", "openocd", "CubeIDE")
}

$gdb = Find-FirstCommand @("arm-none-eabi-gdb.exe", "arm-none-eabi-gdb")
if (-not $gdb) {
  $gdb = Find-ByPattern @(
    "C:\Users\*\tools\arm-gnu-toolchain-*\bin\arm-none-eabi-gdb.exe",
    "C:\Program Files\Arm GNU Toolchain*\bin\arm-none-eabi-gdb.exe",
    "C:\ST\STM32CubeIDE_*\STM32CubeIDE\plugins\**\tools\bin\arm-none-eabi-gdb.exe"
  )
}
if (-not $gdb) {
  $gdb = Find-BestRecursiveMatch @("arm-none-eabi-gdb.exe") @("arm-gnu-toolchain", "GNU Toolchain", "CubeIDE", "toolchain")
}

$serialPorts = @(Get-CimInstance Win32_SerialPort | ForEach-Object {
  [pscustomobject]@{
    device_id = $_.DeviceID
    name = $_.Name
    description = $_.Description
    pnp_device_id = $_.PNPDeviceID
  }
})

$pnpDevices = @(Get-PnpDevice -PresentOnly | Where-Object {
  $_.FriendlyName -match "J-Link|ST-Link|STLink|CMSIS-DAP|DAPLink|WCH-Link|OpenOCD|CMSIS"
} | ForEach-Object {
  [pscustomobject]@{
    status = $_.Status
    class = $_.Class
    friendly_name = $_.FriendlyName
    instance_id = $_.InstanceId
  }
})

$result = [pscustomobject]@{
  tools = [pscustomobject]@{
    jlink_exe = $jlinkExe
    jlink_gdb_server = $jlinkGdbServer
    stlink_gdb_server = $stlinkGdbServer
    openocd = $openOcd
    arm_none_eabi_gdb = $gdb
  }
  probes = $pnpDevices
  serial_ports = $serialPorts
}

$result | ConvertTo-Json -Depth 6
