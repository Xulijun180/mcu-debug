# mcu-debug

一个面向 Codex 的 MCU 调试 skill，主要用于在 Windows 环境下调试 STM32、Cortex-M 等单片机工程。

它的目标不是直接猜问题，而是按稳定的调试流程推进：

- 先探测本机可用的调试工具链
- 再判断当前板卡和探针情况
- 然后选择合适的调试后端
- 最后结合 GDB、串口日志、寄存器和内存信息定位根因

## 适用场景

适合排查这类问题：

- 程序卡死
- 只有部分日志输出
- HardFault / BusFault / UsageFault
- ADC / DMA / UART 异常
- 中断不进或进了后死锁
- `printf`、堆、栈、断言相关问题

## 支持的调试后端

- J-Link GDB Server
- ST-LINK GDB Server
- OpenOCD

## 目录结构

```text
mcu-debug/
├─ SKILL.md
├─ agents/
│  └─ openai.yaml
├─ references/
│  ├─ backend-selection-zh.md
│  ├─ debug-servers-zh.md
│  └─ embedded-debug-playbook-zh.md
└─ scripts/
   └─ detect-debug-backends.ps1
```

## 主要内容

- [SKILL.md](./SKILL.md)
  定义这个 skill 的使用方式、默认调试流程和输出要求。

- [scripts/detect-debug-backends.ps1](./scripts/detect-debug-backends.ps1)
  自动探测本机调试工具、串口和常见探针。

- [references/backend-selection-zh.md](./references/backend-selection-zh.md)
  说明什么时候该选 J-Link、ST-Link 或 OpenOCD。

- [references/debug-servers-zh.md](./references/debug-servers-zh.md)
  提供常见调试 server 和 GDB 命令模板。

- [references/embedded-debug-playbook-zh.md](./references/embedded-debug-playbook-zh.md)
  汇总通用嵌入式问题定位思路和典型故障模式。

## 使用方式

在 Codex 中引用这个 skill：

```text
$mcu-debug
```

或者直接在任务里说明你要调试 MCU / STM32 / Cortex-M 工程，Codex 会按 skill 里的流程执行。

## 调试思路

这个 skill 默认强调几件事：

1. 不先猜，先抓第一现场
2. 不默认某个工具一定安装、某个 COM 口一定存在
3. 不把“最后崩掉的位置”直接当成根因
4. 遇到 DMA、堆、栈、中断问题时优先检查是否有更早的破坏

## 说明

当前内容以中文为主，适合本地 Windows + STM32 开发调试场景。
