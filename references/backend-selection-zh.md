# 调试后端选择规则

## 原则

先看“当前插着什么探针”，再看“本机装了什么工具”，最后选“交集里最直接的一条路”。

不要反过来做。

## 推荐优先级

### 1. J-Link 在场

满足条件：

- 枚举到 `J-Link` 设备
- 能找到 `JLinkGDBServerCL.exe`
- 能找到 `arm-none-eabi-gdb`

默认选择：

- `J-Link GDB Server`

原因：

- 与探针原生匹配
- 一般连接稳定
- 命令行和日志能力比较完整

### 2. ST-Link 在场

满足条件：

- 枚举到 `ST-Link` 设备
- 能找到 `ST-LINK_gdbserver.exe`
- 能找到 `arm-none-eabi-gdb`

默认选择：

- `ST-LINK GDB Server`

原因：

- 与探针原生匹配
- 比 OpenOCD 少一层兼容风险

### 3. 只有 OpenOCD 可用

满足条件：

- 能找到 `openocd.exe`
- 能确认接口配置
- 能确认目标配置
- 能找到 `arm-none-eabi-gdb`

默认选择：

- `OpenOCD`

原因：

- 适合没有 vendor GDB server 的情况
- 适合用户明确指定 OpenOCD 的情况

## 多后端同时可用时怎么选

按这个顺序：

1. 探针原生 vendor server
2. 用户显式指定的工具链
3. OpenOCD

举例：

- 插着 J-Link，同时机器也装了 OpenOCD：优先 `J-Link GDB Server`
- 插着 ST-Link，同时机器也装了 J-Link 工具：优先 `ST-LINK GDB Server`
- 没有 vendor server，但项目里已有 OpenOCD `.cfg`：优先 `OpenOCD`

## 什么时候不要硬选

下面这些情况要先停下来说明，而不是盲跑：

- 识别到探针，但本机没有对应 server
- 有多个探针同时插着，且目标不明确
- 找到 OpenOCD，但没有接口或 target 配置
- 找到多个 ELF，无法判断当前要调哪个

## 选择后要说明的内容

结论里至少说明：

1. 检测到了哪些探针
2. 检测到了哪些可执行工具
3. 最终选了哪个后端
4. 为什么这个后端是当前最合适的
