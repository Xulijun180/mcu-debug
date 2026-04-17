# 调试后端命令模板

## 适用场景

适用于 Windows 上通过下面三类后端调试 Cortex-M、STM32 等 MCU 工程：

- `JLinkGDBServerCL.exe`
- `ST-LINK_gdbserver.exe`
- `openocd.exe`

先探测，再选择，不要硬编码路径。

默认使用两级策略：

1. 快速探测：`PATH` + 常见安装目录
2. 回退探测：对固定磁盘做递归搜索，并按路径质量排序选出最靠谱的命中

## 1. 工具路径探测

优先运行 `scripts/detect-debug-backends.ps1`，不要假设安装路径固定。

建议优先检查：

- `Get-Command JLink.exe,JLinkGDBServerCL.exe,openocd.exe,arm-none-eabi-gdb`
- `C:\Users\<用户名>\tools\xpack-openocd-*\bin\openocd.exe`
- `C:\Program Files (x86)\SEGGER\JLink`
- `C:\Program Files\SEGGER\JLink`
- `C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer`
- `C:\ST\STM32CubeIDE_*`

## 2. J-Link 模板

### 最小连通性测试

```powershell
@'
exit
'@ | & $JLinkExe -device STM32F103C8 -if SWD -speed 4000 -autoconnect 1
```

### 启动 GDB Server

```powershell
Start-Process `
  -FilePath $JLinkGdbServer `
  -ArgumentList '-select','USB','-device','STM32F103C8','-if','SWD','-speed','4000','-port','2331','-swoport','2332','-telnetport','2333','-singlerun' `
  -RedirectStandardOutput $out `
  -RedirectStandardError $err `
  -PassThru
```

## 3. ST-Link 模板

### 常见安装位置

常见位置示例：

- `C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\ST-LINK_gdbserver.exe`
- `C:\ST\STM32CubeIDE_x.y.z\STM32CubeIDE\plugins\...`

### 启动 GDB Server

不同版本参数可能略有区别，开始前先跑 `--help` 或 `-h` 确认。

常见形式类似：

```powershell
Start-Process `
  -FilePath $StLinkGdbServer `
  -ArgumentList '-p','2331','-cp',$CubeProgrammerBin,'-d','STM32F103C8','--swd' `
  -RedirectStandardOutput $out `
  -RedirectStandardError $err `
  -PassThru
```

如果具体参数风格不一致，优先以本机 `--help` 输出为准。

## 4. OpenOCD 模板

### 基本要求

OpenOCD 需要接口配置和目标配置。

优先来源：

1. 项目目录现成 `.cfg`
2. 探针类型对应接口文件
3. 目标芯片或芯片族配置

### 启动示例

```powershell
Start-Process `
  -FilePath $OpenOcdExe `
  -ArgumentList '-f','interface/stlink.cfg','-f','target/stm32f1x.cfg','-c','transport select hla_swd','-c','gdb_port 3333' `
  -RedirectStandardOutput $out `
  -RedirectStandardError $err `
  -PassThru
```

## 5. GDB 通用命令

J-Link 和 ST-Link 通常监听 `2331`，OpenOCD 常见是 `3333`。以实际 server 为准。

```powershell
& arm-none-eabi-gdb -q .\cmake-build-debug\F1_TEST.elf `
  -ex "target extended-remote :2331" `
  -ex "set pagination off" `
  -ex "monitor reset" `
  -ex "monitor halt" `
  -ex "load" `
  -ex "break HardFault_Handler" `
  -ex "break Error_Handler" `
  -ex "break abort" `
  -ex "break __assert_func" `
  -ex "continue"
```

如果后端是 OpenOCD，`monitor` 支持细节可能不同，必要时用 `reset halt` 的等价命令。

## 6. 串口并行抓取

```powershell
$port = New-Object System.IO.Ports.SerialPort $ComPort,115200,'None',8,'one'
$port.ReadTimeout = 250
$port.Open()
$end = (Get-Date).AddSeconds(10)
while ((Get-Date) -lt $end) {
  $data = $port.ReadExisting()
  if ($data) { $data }
  Start-Sleep -Milliseconds 100
}
$port.Close()
```

## 7. 记录要求

无论用哪个后端，都要记录：

- 使用的是哪种探针
- 使用的是哪种 server
- server 路径从哪里探测到
- GDB 连接端口
- 是否同时抓了串口
