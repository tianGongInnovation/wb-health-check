---
name: wb-health-check
description: WorkBuddy 自身 + 系统健康巡检。检测 WorkBuddy 进程数 / 内存占用、系统 CPU / 内存 / 句柄 / 上线时间、C 盘空间、可选 GPU 状态，输出 GREEN/YELLOW/RED 三色状态 + 具体告警 + 处置建议。触发词：健康检查、检查自身状态、跑下健康检查、wb 还活着吗、内存快爆了吗、WB 是不是挂了、system health、health check。
agent_created: true
version: 1.0.0
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

**第一动作：直接调用本技能随附的 `wb_health_check.ps1` 脚本**——不要重新造轮子。该脚本已经覆盖 90% 的常见健康指标。

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

## 输出解读规则（脚本已算好 status 字段）

`status` 字段三色对照：
- **GREEN**：一切正常，不用动
- **YELLOW**：需要注意（黄色告警中的某项）
- **RED**：必须立刻处置（可能崩 / 已崩 / 资源耗尽）

`warnings` 数组里每条都是"已经超出阈值"的告警。

## 收到 YELLOW 时怎么回应

逐条把 `warnings` 翻译成中文建议，按风险排序：

| 告警关键词 | 白话翻译 | 处置建议 |
|---|---|---|
| `WB total mem > 5GB` | WorkBuddy 吃内存 5GB 了 | 关闭不用的标签页 / 重启 WorkBuddy |
| `WB process count > 15` | WorkBuddy 进程开太多了 | 检查是否开了多个窗口，关掉重复的 |
| `System free mem < 3GB` | 系统内存吃紧 | 关掉吃内存的大软件 / 准备重启 |
| `System uptime > 72h` | 电脑好几天没重启了 | 今晚重启一次 |
| `CPU load > 60%` | CPU 占用高 | 任务管理器看哪个进程，结束它 |
| `Total process count > 250` | 进程太多了（可能有僵尸） | 重启电脑最稳 |
| `Not Responding > 0` | 有程序卡死了 | 任务管理器结束它 |
| `Total handles > 60K` | 句柄爆表 | 重启电脑 |

## 收到 RED 时怎么回应

**最高优先级处理**：
- `CRASH IMMINENT` / `CRASH RISK` → 立刻保存工作 → 主动重启 WorkBuddy / 电脑
- `WB process not running` → WorkBuddy 挂了，提示"是否要重新打开 WorkBuddy？"
- `uptime > 168h`（7 天）→ 必须重启，建议立即做

## 常见场景

以下告警最常见（按频率排序），可据此主动提醒使用者：

1. **`uptime > 168h` 红灯**——电脑长期不重启，系统响应变慢，触发即建议当晚重启
2. **`WB total mem > 5GB` 黄灯**——WorkBuddy 跑久了内存涨，提示"关标签页或重启"
3. **`Total process count > 250` 黄灯**——后台进程堆积，建议每周重启一次

## 进阶用法

### 长期趋势

加 `-Log` 后，脚本会在脚本同目录写 `wb_health_log_YYYY.jsonl`（按年），可结合 Excel / pandas 画趋势图，用于"什么时候开始吃内存"等回溯分析。

### 接入自动巡检

在 WorkBuddy 自动任务里加一条"每 4 小时跑一次 wb_health_check.ps1 -Log"，输出 RED 时给使用者推送通知（飞书 / 微信 / 邮件）。

## 不要做的事

- ❌ 不要在技能里重新实现监控逻辑——脚本已经完整，直接调用
- ❌ 不要给 YELLOW 告警"过度紧张"——脚本阈值已经是经验值，遵守即可
- ❌ 不要在没有看到 JSON 输出前就建议"重启电脑"——先看 status
- ❌ 不要混淆"WorkBuddy 自身问题"和"系统问题"——分清是 A 段（WorkBuddy）还是 B-E 段（系统）的告警
