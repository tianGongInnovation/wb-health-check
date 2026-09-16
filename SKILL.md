---
name: wb-health-check
description: 给 WorkBuddy 智能体和您的电脑做“体检”的工具。AI 助手连续运行时间太长、一次对话内容太多时，可能会无声无息地突然消失（界面和托盘图标一起不见），使用者还以为是电脑坏了。本技能每次开工前跑一次（约 2 秒，不占资源、不留后台），检查三类关键指标：WorkBuddy 主进程已连续运行多久、当前会话累积了多少对话量、AI 响应是不是越来越慢——三项同时超标就是“随时可能猝死”的信号；另外还检查系统 CPU、内存、句柄数、开机时长、C 盘剩余空间和显卡状态。结果用绿黄红三种颜色告诉您：绿灯不用管，黄灯一句话提醒，红灯提示“保存工作、重启一下”。告警全部用大白话，不带英文术语，不懂电脑也看得懂。特别适合配置不高的老电脑（8G 内存甚至更低）。触发词：健康检查、检查自身状态、跑下健康检查、wb 还活着吗、内存快爆了吗、WB 是不是挂了、system health、health check。
agent_created: true
version: 1.0.2
author: 天工创新坊
license: CC BY 4.0
display_name: "健康检查"
display_name_en: Health Check
trigger: ["健康检查", "检查自身状态", "跑下健康检查", "系统还活着吗", "wb 还活着吗"]
description_zh: "WorkBuddy + 系统健康巡检（三色状态 + 处置建议）"
description_en: "WorkBuddy + system health check with tri-color status and actionable advice"
category: productivity
---

# WorkBuddy 健康检查（WorkBuddy + 系统级）

**首选做法：直接调用本技能随附的 `wb_health_check.ps1` 脚本**，无需重复实现监控逻辑。该脚本已覆盖约 90% 的常见健康指标。

## 路径速查

- **脚本位置**：本技能目录下的 `scripts/wb_health_check.ps1`（随技能一起安装）。
- **找不到脚本时**：提示用户"技能目录里缺少 scripts/wb_health_check.ps1，请重新安装本技能"。

## 调用命令

### 基础（仅输出到屏幕）

```powershell
powershell -ExecutionPolicy Bypass -File "<本技能目录>/scripts/wb_health_check.ps1"
```

### 完整（写日志到 history）

```powershell
powershell -ExecutionPolicy Bypass -File "<本技能目录>/scripts/wb_health_check.ps1" -Log
```

`-Log` 会同时输出当前状态 JSON + 追加一行到 history 日志（用于长期趋势分析）。

## 脚本监控项（已覆盖）

| 段 | 监控项 | 阈值（GREEN → YELLOW → RED） |
|---|---|---|
| A. WorkBuddy 进程 | 进程数 / 总内存 | < 15 / < 5GB → 15-20 / 5-8GB → >20 / >8GB |
| B. 系统资源 | 剩余内存 / 上线时间 | > 3GB / < 72h → 1.5-3GB / 72-168h → < 1.5GB / > 168h |
| C. CPU 负载 | 整体负载 | < 60% → 60-80% → > 80% |
| D. 进程库存 | 总进程数 / Not Responding | < 250 / 0 → 250-350 / 1-3 → > 350 / > 3 |
| E. 句柄 | 系统总句柄 | < 60K → 60K-100K → > 100K |
| F. C 盘 | 剩余空间 | > 10% → 5-10% → < 5% |
| G. GPU（可选） | nvidia-smi 显存 / 温度 | 仅在有 NVIDIA 卡且 nvidia-smi 在 PATH 时采集 |

## 输出解读规则（脚本已计算 status 字段）

`status` 字段三色对照：
- **GREEN**：状态正常，无需处理
- **YELLOW**：需要关注（黄色告警中的某项）
- **RED**：应尽快处置（存在崩溃风险 / 已崩溃 / 资源耗尽）

`warnings` 数组中的每一项均为超出阈值的告警。

## YELLOW 状态的回应方式

将 `warnings` 逐条转为中文建议，并按风险排序：

| 告警关键词 | 含义 | 处置建议 |
|---|---|---|
| `WB total mem > 5GB` | WorkBuddy 内存占用达 5GB | 关闭闲置标签页 / 重启 WorkBuddy |
| `WB process count > 15` | WorkBuddy 进程数偏多 | 检查是否存在多个窗口，关闭重复窗口 |
| `System free mem < 3GB` | 系统可用内存偏低 | 关闭占用内存较大的程序 / 准备重启 |
| `System uptime > 72h` | 系统连续运行时间过长 | 安排一次重启 |
| `CPU load > 60%` | CPU 占用率偏高 | 在任务管理器中查看对应进程并结束 |
| `Total process count > 250` | 进程数偏多（可能存在无响应进程） | 重启电脑 |
| `Not Responding > 0` | 存在无响应程序 | 在任务管理器中结束该进程 |
| `Total handles > 60K` | 句柄数超出阈值 | 重启电脑 |

## RED 状态的回应方式

**优先处置**：
- `CRASH IMMINENT` / `CRASH RISK` → 先保存工作 → 重启 WorkBuddy / 电脑
- `WB process not running` → WorkBuddy 已退出，可提示"是否重新打开 WorkBuddy？"
- `uptime > 168h`（7 天）→ 建议尽快重启

## 常见场景

以下告警出现频率较高（按频率排序），可据此提示使用者：

1. **`uptime > 168h` 红灯**——系统长期未重启，响应速度下降，触发后可建议安排重启
2. **`WB total mem > 5GB` 黄灯**——WorkBuddy 长时间运行后内存上升，可提示关闭标签页或重启
3. **`Total process count > 250` 黄灯**——后台进程累积，可建议每周重启一次

## 进阶用法

### 长期趋势

加 `-Log` 后，脚本会在脚本同目录写 `wb_health_log_YYYY.jsonl`（按年），可结合 Excel / pandas 绘制趋势图，用于回溯内存占用增长的时点等分析。

### 接入自动巡检

在 WorkBuddy 自动任务里加一条"每 4 小时跑一次 wb_health_check.ps1 -Log"，输出 RED 时向使用者推送通知（飞书 / 微信 / 邮件）。

## 不建议的做法

- 不在技能内重新实现监控逻辑——脚本已覆盖完整，直接调用即可
- 对 YELLOW 告警无需过度反应——脚本阈值取自经验值，按其处置即可
- 未查看 JSON 输出前，不宜直接建议重启电脑——先确认 status 字段
- 区分 WorkBuddy 自身问题与系统问题——判断告警属于 A 段（WorkBuddy）还是 B-E 段（系统）
