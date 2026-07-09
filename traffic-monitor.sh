#!/bin/bash

echo "=========================================="
echo "  Debian 12 流量监控 TG 推送一键部署"
echo "  (终极版: 智能网卡 + 多时段 + 强力修复配置)"
echo "=========================================="

# 1. 安装必要组件
echo "⏳ 正在更新软件源并安装 vnstat, jq, curl..."
apt-get update -y >/dev/null 2>&1
apt-get install -y vnstat jq curl >/dev/null 2>&1
echo "✅ 组件安装完毕。"
echo ""

# 2. 收集用户配置 (交互式问答)
echo "📝 请输入配置信息:"
echo ""

read -p "1. 节点名称 (例如 DMIT-HK, 默认: VPS): " NODE_NAME
NODE_NAME=${NODE_NAME:-"VPS"}
echo ""

echo "2. 请选择要监听的网卡 (系统自动检测):"
INTERFACES=$(ls -1 /sys/class/net | grep -E -v '^(lo|docker|veth|br-|tun|tap)')

if [ -z "$INTERFACES" ]; then
    echo "⚠️ 未检测到常规物理网卡，请手动输入网卡名称: "
    read INTERFACE
else
    i=1
    declare -A IFACE_MAP
    for iface in $INTERFACES; do
        echo "   [$i] $iface"
        IFACE_MAP[$i]=$iface
        i=$((i + 1))
    done
    
    echo ""
    read -p "请输入对应数字 (默认 1): " IFACE_CHOICE
    IFACE_CHOICE=${IFACE_CHOICE:-1}
    
    INTERFACE=${IFACE_MAP[$IFACE_CHOICE]}
    
    if [ -z "$INTERFACE" ]; then
        echo "⚠️ 选择无效，将默认尝试使用 eth0"
        INTERFACE="eth0"
    fi
fi
echo "✅ 已选择监听网卡: $INTERFACE"
echo ""

read -p "3. 每月总流量限制 (GB, 仅填数字, 默认 2000): " LIMIT_GB
LIMIT_GB=${LIMIT_GB:-2000}
echo ""

read -p "4. 流量重置日 (1-31, 建议填真实账单日, 默认 1): " RESET_DAY
RESET_DAY=${RESET_DAY:-"1"}
echo ""

read -p "5. Telegram Bot Token: " TG_BOT_TOKEN
read -p "6. Telegram Chat ID: " TG_CHAT_ID
echo ""

read -p "7. 每天推送的小时 (0-23, 多时间用逗号分隔如 8,20, 默认 21): " RAW_CRON_HOUR
CRON_HOUR=$(echo "$RAW_CRON_HOUR" | tr -d ' ')
CRON_HOUR=${CRON_HOUR:-"21"}
echo ""

# 3. 核心修复：强制配置 vnstat
echo "⏳ 正在配置 vnstat 服务..."
vnstat --add -i "$INTERFACE" >/dev/null 2>&1

if [ -f "/etc/vnstat.conf" ]; then
    sed -i '/^[#;[:space:]]*MonthRotate/d' /etc/vnstat.conf
    echo "MonthRotate $RESET_DAY" >> /etc/vnstat.conf
    systemctl restart vnstat
    echo "✅ vnstat 重置日已强制修改为每月 $RESET_DAY 号。"
fi

# 4. 生成核心推送脚本
SCRIPT_PATH="/root/tg_traffic_push.sh"
echo "⏳ 正在生成推送脚本到 $SCRIPT_PATH ..."

cat << EOF > $SCRIPT_PATH
#!/bin/bash

NODE_NAME="$NODE_NAME"
INTERFACE="$INTERFACE"
LIMIT_GB="$LIMIT_GB"
RESET_DAY="$RESET_DAY"
TG_BOT_TOKEN="$TG_BOT_TOKEN"
TG_CHAT_ID="$TG_CHAT_ID"

RX_BYTES=\$(vnstat -i "\$INTERFACE" --json 2>/dev/null | jq -r '.interfaces[0].traffic.month[-1].rx')
TX_BYTES=\$(vnstat -i "\$INTERFACE" --json 2>/dev/null | jq -r '.interfaces[0].traffic.month[-1].tx')

if [ -z "\$RX_BYTES" ] || [ "\$RX_BYTES" = "null" ]; then
    RX_BYTES=0
    TX_BYTES=0
fi

TOTAL_BYTES=\$((RX_BYTES + TX_BYTES))

USED_GB=\$(awk "BEGIN {printf \\"%.2f\\", \$TOTAL_BYTES / 1024 / 1024 / 1024}")
REMAINING_GB=\$(awk "BEGIN {printf \\"%.2f\\", \$LIMIT_GB - \$USED_GB}")
USAGE_PERCENT=\$(awk "BEGIN {printf \\"%.1f\\", (\$USED_GB / \$LIMIT_GB) * 100}")

# 计算下一次重置日期 (处理跨月和跨年逻辑，并防止 08 09 被当做八进制报错)
C_DAY=\$((10#\$(date +%d)))
R_DAY=\$((10#\$RESET_DAY))
C_MONTH=\$((10#\$(date +%m)))
C_YEAR=\$(date +%Y)

if [ "\$C_DAY" -ge "\$R_DAY" ]; then
    # 已经过了重置日，推算到下个月
    N_MONTH=\$((C_MONTH + 1))
    N_YEAR=\$C_YEAR
    if [ "\$N_MONTH" -gt 12 ]; then
        N_MONTH=1
        N_YEAR=\$((C_YEAR + 1))
    fi
else
    # 还没到重置日，就在本月
    N_MONTH=\$C_MONTH
    N_YEAR=\$C_YEAR
fi

# 格式化日期，自动补齐两位数 (如 2026-08-04)
NEXT_RESET_DATE=\$(printf "%04d-%02d-%02d" "\$N_YEAR" "\$N_MONTH" "\$R_DAY")

MESSAGE="📊 *\${NODE_NAME} 流量日报*

🔵 总流量: \${LIMIT_GB}.00 GB
🟠 已使用: \${USED_GB} GB (\${USAGE_PERCENT}%)
🟢 剩余流量: \${REMAINING_GB} GB
🔄 重置日期: \${NEXT_RESET_DATE}"

curl -s -X POST "https://api.telegram.org/bot\${TG_BOT_TOKEN}/sendMessage" \\
    -d "chat_id=\${TG_CHAT_ID}" \\
    -d "parse_mode=Markdown" \\
    -d "text=\${MESSAGE}" > /dev/null
EOF

chmod +x $SCRIPT_PATH

# 5. 配置定时任务 (Cron)
(crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH"; echo "0 $CRON_HOUR * * * $SCRIPT_PATH") | crontab -

echo "=========================================="
echo "🎉 部署完成！"
echo "📌 脚本路径: $SCRIPT_PATH"
echo "⏰ 定时任务: 每天的 $CRON_HOUR 点钟准时执行推送"
echo "=========================================="
