---
name: mcu-debug
description: 在 Windows 上调试 STM32、Cortex-M 等单片机工程。使用前先探测本机和当前板卡可用的调试后端，再在 J-Link GDB Server、ST-LINK GDB Server、OpenOCD 之间选择最合适的方案，并结合 arm-none-eabi-gdb、ELF 符号、寄存器、内存和串口日志定位 HardFault、DMA 越界、运行库断言、外设异常、程序卡死和无输出等问题。
---

# MCU Debug

## 概览

把“先探测环境，再选调试后端，再抓第一现场”作为默认工作方式。不要假设每台机器都有同样的安装路径，也不要假设用户一定在用 J-Link。

这份 skill 默认支持三类后端：

- `J-Link GDB Server`
- `ST-LINK_gdbserver`
- `OpenOCD`

## 默认流程

每次开始调试前，按下面顺序执行：

1. 找到当前工程的 `.elf`
2. 探测本机已安装的调试工具、GDB 和串口
3. 探测当前连接着哪些探针
4. 根据探针和工具的交集选择调试后端
5. 启动对应的 server
6. 用 `arm-none-eabi-gdb` 连接并抓现场
7. 必要时并行抓串口日志

## 第一步：先做环境探测

优先运行 [detect-debug-backends.ps1](D:\F1_TEST\mcu-debug\scripts\detect-debug-backends.ps1)。

这个脚本会尽量自动探测：

- `JLink.exe`
- `JLinkGDBServerCL.exe`
- `STM32CubeProgrammer` 的 `ST-LINK_gdbserver.exe`
- `openocd.exe`
- `arm-none-eabi-gdb.exe`
- 常见串口
- 常见 USB 调试探针

探测原则：

- 先查 `PATH`
- 再查常见安装目录
- 再对固定磁盘做递归回退搜索
- 最后结合设备枚举结果判断“装了什么”和“当前插了什么”

## 第二步：选择调试后端

优先阅读 [backend-selection-zh.md](D:\F1_TEST\mcu-debug\references\backend-selection-zh.md)。

默认选择策略：

1. 如果插着 `J-Link`，且本机能找到 `JLinkGDBServerCL.exe` 和 `arm-none-eabi-gdb`，优先用 `J-Link GDB Server`
2. 如果插着 `ST-Link`，且本机能找到 `ST-LINK_gdbserver.exe` 和 `arm-none-eabi-gdb`，优先用 `ST-LINK GDB Server`
3. 如果没有 vendor GDB server，但能找到 `openocd.exe` 和对应探针配置，使用 `OpenOCD`
4. 如果同时具备多种工具，优先选“当前探针原生支持的 vendor GDB server”，其次才是 `OpenOCD`

选择时要明确说明：

- 当前检测到了什么探针
- 当前检测到了哪些 server
- 为什么选择这个后端
- 为什么没选其他后端

## 第三步：启动对应后端

### J-Link

使用 `JLink.exe` 先做最小连通性验证，再启动 `JLinkGDBServerCL.exe`。

完整命令模板见 [debug-servers-zh.md](D:\F1_TEST\mcu-debug\references\debug-servers-zh.md)。

### ST-Link

优先使用 `ST-LINK_gdbserver.exe`。如果路径不在 `PATH`，先从常见目录和 `STM32CubeProgrammer` 安装目录里找。

### OpenOCD

当没有 vendor GDB server 或用户明确要求用 OpenOCD 时使用。要先确认：

- 探针类型
- 接口配置文件
- 目标芯片配置文件

如果项目里已有 `.cfg`，优先复用；否则再根据探针和芯片组合生成最小命令。

## 第四步：抓现场

无论后端是谁，GDB 侧默认动作基本一致：

1. `target extended-remote`
2. `monitor reset`
3. `monitor halt`
4. `load`
5. 断 `HardFault_Handler`、`Error_Handler`、`abort`、`__assert_func`
6. `continue`
7. 查看 `bt`、`info registers`、`x/8i $pc`

## 串口策略

如果探针或板卡提供虚拟串口，优先并行抓串口。

典型价值：

- GDB 只能看到停在哪
- 串口能补充断言文本、业务阶段、状态机日志

不要假设 J-Link 一定有 CDC UART，也不要假设 ST-Link 一定映射成某个固定 `COM` 号。必须先枚举当前串口设备。

## 结论纪律

“最后崩掉的函数”不一定就是根因，通常还需要结合更早的现场和调用链一起判断。

当现场落在这些路径时，值得先检查是否存在更早的内存、配置或参数问题：

- `printf`
- `malloc`
- `_dtoa_r`
- `abort`
- `__assert_func`

完成调试后，优先给出：

1. 现象
2. 第一现场
3. 真实根因
4. 证据
5. 为什么表象不是根因

## 资源

- 环境探测脚本：读并优先运行 [detect-debug-backends.ps1](D:\F1_TEST\mcu-debug\scripts\detect-debug-backends.ps1)
- 后端选择规则：读 [backend-selection-zh.md](D:\F1_TEST\mcu-debug\references\backend-selection-zh.md)
- 各类 server 命令模板：读 [debug-servers-zh.md](D:\F1_TEST\mcu-debug\references\debug-servers-zh.md)
- 通用嵌入式定位思路（已整合 `docs` 里的详细排查方法）：读 [embedded-debug-playbook-zh.md](D:\F1_TEST\mcu-debug\references\embedded-debug-playbook-zh.md)
