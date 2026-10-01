---
name: wb-health-check
description: 给 WorkBuddy 智能体和您的电脑做“体检”的工具。电脑越用越慢时，过去只能打开任务管理器看占用、猜着清理可疑任务，很费劲，多数人只能等死机失去响应后重启、甚至硬关机；本技能让智能体在每次开工前花约 2 秒跑一次体检（不占资源、不留后台），把隐患挡在死机之前：检查 WorkBuddy 主进程已连续运行多久、当前会话累积了多少对话量、AI 响应是不是越来越慢——三项同时超标就是“随时可能无声消失”的信号；同时检查系统 CPU、内存、句柄数、开机时长、C 盘剩余空间和显卡状态，发现某个软件拖累系统时提示有针对性的关闭它，而不是笼统地重启了事——曾有使用者在体检中发现一个视频播放软件长期运行产生了大量内存垃圾，关掉重开即恢复正常，以后对这类软件问题心里就有数了。结果用绿黄红三种颜色告诉您：绿灯不用管，黄灯一句话提醒，红灯提示“保存工作、重启一下”。告警全部用大白话，不带英文术语，不懂电脑也看得懂。特别适合配置不高的老电脑（8G 内存甚至更低）。触发词：健康检查、检查自身状态、跑下健康检查、wb 还活着吗、内存快爆了吗、WB 是不是挂了、system health、health check。
agent_created: true
version: 1.0.6
author: 天工创新坊
license: CC BY 4.0
display_name: "电脑运行状态健康检查"
display_name_en: PC Health Status Check
trigger: ["健康检查", "检查自身状态", "跑下健康检查", "系统还活着吗", "wb 还活着吗", "health check", "check system status", "run a health check", "is the system still alive"]
description_zh: "电脑越用越慢，过去只能开任务管理器猜，甚至硬关机；现在开工前花 2 秒跑一次体检：智能体运行太久、对话太多会无声消失，电脑内存、C 盘空间也一并检查，哪个软件在拖累、该不该重启，绿黄红三色告诉您。"
description_en: "A slow computer used to mean guessing in Task Manager or even a hard power-off; now a 2-second health check before work watches how long the agent has run, how large the session has grown, and how fast it responds, plus system memory and drive space — green, yellow or red tells you whether to carry on or save work and restart"
category: productivity
---

# 电脑运行状态健康检查（WorkBuddy + 系统级）

## 为什么需要它

- **过去**：对 Windows 的内存使用情况不了解，系统变缓慢时只能打开任务管理器，看内存占用、CPU 占用，手动清理可疑任务，很费劲；一般使用者连这一步都做不到，只能等死机、失去响应后重启，甚至硬关机。
- **现在**：可以让智能体分析内存与系统状态——发现某个软件问题严重，及时提示有针对性的关闭它，或提示尽快重启一次电脑。系统可控、受控、有预警，不再被动。
- **WorkBuddy 自身也是例子**：连续一个话题长时间对话，系统会越来越慢，什么时候该重启一下？在软件自身还不能解决这类问题之前，先用体检规避意外发生。
- **真实案例**：一位使用者的电脑长期运行一个视频播放软件，体检时发现该软件产生了大量内存垃圾——出乎意料；关掉它、必要时重新打开，内存情况随即好转。类似软件问题，以后就能心里有数。

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

## 使用反馈（内置反馈提交模块）

本技能持续改进中。使用时遇到问题、感到不方便，或有任何建议与期待，欢迎反馈——每条反馈都会进入改进清单，感谢您花时间提出。

### 两条反馈通道（任选其一）

1. **让智能体直接发送（最方便，推荐）**：对本技能说「提交反馈」，按提示说几句即可完成，详见下方执行指引
2. **手动提交**：电子邮箱 gouzhongwu@vip.qq.com，或微信公众号「东方恒源技术创新」留言

### 反馈提交执行指引（智能体处理「提交反馈」时照此执行）

1. **收集**：向使用者收集反馈类型（问题/建议/其它）、具体描述、可选联系方式（留了便于回访，不填则匿名）
2. **组装反馈卡**（纯文本，中文）：
   - 邮件主题：[技能反馈] wb-health-check v1.0.5
   - 正文依次包含：技能与版本 → 反馈类型 → 具体描述 → 使用环境（如 Windows 版本、智能体版本）→ 联系方式（如有）
3. **自动发送（优先路径）**：若本会话可使用智能体邮箱能力（如 agent-mail），将反馈卡发送至 gouzhongwu@vip.qq.com；发送前必须把反馈卡全文展示给使用者，确认后再发
4. **落盘备用（无邮箱能力时）**：把反馈卡保存到工作目录 `反馈\wb-health-check-反馈-<日期>.md`，并展示通道 2，请使用者完成提交
5. **收尾**：告知使用者反馈已提交（或已保存待发），说明反馈将进入改进清单，重要问题优先处理

## 关于我们

本技能由**天工创新坊**开发并免费开放使用。

天工创新坊是一个开放的技术创新小站，专注把成熟、廉价的技术组合起来，解决那些"解决不了、解决不好"的实际问题。所有技能都遵循同一原则：**把事情讲清楚，让不懂技术的人也能用起来。**

- 空间主页（技能包 / 命令清单 / 更多工具）：在 WorkBuddy 开放平台搜索「天工创新坊」，可找到我们的技能包、命令清单与更多工具。
- 使用中遇到问题、有改进建议，或希望定制类似工具，欢迎通过空间主页留言联系我们。

本技能以 CC BY 4.0 协议开放，可自由使用、修改与再分发，请保留来源署名。
