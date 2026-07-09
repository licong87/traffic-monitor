# 📊 VPS 流量监控与 Telegram 推送助手

[![Platform](https://img.shields.io/badge/Platform-Debian%20%7C%20Ubuntu-blue.svg)]()
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)]()

一个极其轻量的一键部署脚本，利用 `vnstat` 监控 VPS 本地网卡流量，并每天定时推送流量日报到你的 Telegram 机器人。

无需常驻后台程序，零内存泄漏风险，专为强迫症和流量焦虑患者打造。

## ✨ 核心特性

- **🚀 真正的一键部署：** 自动安装依赖（vnstat, jq, curl），向导式配置，零门槛上手。
- **🤖 智能网卡识别：** 自动过滤本地环回和容器网卡，列出真实物理网卡供你敲数字选择，告别手动查找网卡名称。
- **📅 账单日精准对齐：** 强制修复并修改 `vnstat` 的重置日期 (`MonthRotate`)，让本地统计与你的探针面板及真实账单日完全同步。
- **⏰ 多时段定时推送：** 支持原生 Cron 语法，输入 `8,20` 即可实现早晚两次自动推送。
- **🛡️ 极致轻量：** 纯 Bash 脚本 + 系统自带定时任务，跑完即走，绝不浪费 1KB 内存。

## 📸 推送效果预览

每天到达设定时间，你的 Telegram 将收到如下播报：

> 📊 **VPS 流量日报**
> 
> 🔹 总流量: 2000.00 GB
> 🔸 已使用: 1899.49 GB (95.0%)
> ✅ 剩余流量: 100.51 GB
> 📅 重置日期: 2026-07-07

## 🛠️ 安装与使用

连接到你的服务器 SSH，直接运行以下命令即可启动可视化配置向导：

```bash
# 请将下方的 URL 替换为你 GitHub 仓库中该脚本的真实 Raw 链接
bash <(curl -sL [https://raw.githubusercontent.com/licong8/traffic-monitor/traffic-monitor.sh](https://raw.githubusercontent.com/licong87/traffic-monitor/traffic-monitor.sh))
```

### 配置向导将询问你以下信息：

1. **节点名称** (如: `DMIT-HK`，默认: `VPS`)
2. **监听网卡** (智能列表按数字选择)
3. **每月总流量限制** (如: `2000`)
4. **流量重置日** (1-31 的数字，请填写你真实的账单日)
5. **Telegram Bot Token** (通过 [@BotFather](https://t.me/BotFather) 获取)
6. **Telegram Chat ID** (通过 [@userinfobot](https://t.me/userinfobot) 获取)
7. **推送时间** (如: `21` 代表晚上9点，`8,20` 代表早八晚八)

## 💡 进阶技巧

### 1. 立即测试推送
部署完成后，无需等待定时任务，直接在终端输入以下命令可立即发送一条状态测试：

```bash
/root/tg_traffic_push.sh
```

### 2. vnstat 数据初始化说明
如果脚本刚安装完成，测试推送显示为 `0 GB`，请不要慌张。`vnstat` 需要几分钟的时间来收集网卡的初始数据，稍等片刻后再次运行即可看到真实数据。

## 📝 卸载说明

如果你需要卸载，只需两步即可清理干净：

1. 移除定时任务：输入 `crontab -e`，删除带有 `/root/tg_traffic_push.sh` 的那一行。
2. 删除脚本与依赖：

```bash
rm -f /root/tg_traffic_push.sh
apt-get purge -y vnstat jq
```
