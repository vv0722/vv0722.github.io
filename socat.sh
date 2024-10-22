#!/bin/bash

# 显示主菜单
show_menu() {
    clear
    echo "===================================="
    echo "==欢迎使用maizi制作的socat转发面板=="
    echo "==如遇困难请联系TG:https://t.me/tel_with_maizi_bot=="
    echo "===================================="
    echo "请选择:"
    echo "0. 退出脚本"
    echo "-----------------------------------------------------------------"
    echo "1. 一键部署转发"
    echo "2. 添加转发"
    echo "3. 移除转发"
    echo "4. 查看转发"
    echo "5. 启动服务"
    echo "-----------------------------------------------------------------"
}

handle_error() {
    echo -e "\e[31m发生错误，操作未成功完成。\e[0m"
    exit 1
}

countdown() {
    local SECONDS=3
    echo -e "\e[32m操作成功完成，将在 $SECONDS 秒后返回主菜单...\e[0m"
    while [ $SECONDS -gt 0 ]; do
        echo -n "$SECONDS..."
        sleep 1
        ((SECONDS--))
    done
    echo
}

initialize_socat_start() {
    echo "初始化转发列表文件..."
    > /usr/local/bin/socat-start.sh || handle_error
    chmod +x /usr/local/bin/socat-start.sh || handle_error
}

add_forwarding() {
    # 清除现有的#!/bin/bash和wait
    sed -i '/^#!/d' /usr/local/bin/socat-start.sh
    sed -i '/^wait$/d' /usr/local/bin/socat-start.sh
    while true; do
        read -p "请输入IP地址: " ip
        read -p "请输入端口: " port
        # 验证IP地址和端口格式
        if [[ ! $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ ! $ip =~ ^([0-9a-fA-F:]+)$ ]]; then
            echo "无效的IP地址格式，请重新输入。"
            continue
        fi
        if [[ ! $port =~ ^[0-9]+$ ]] || [ $port -lt 1 ] || [ $port -gt 65535 ]; then
            echo "无效的端口号，请输入1-65535之间的数字。"
            continue
        fi
        # 添加新的转发规则
        echo "/usr/bin/socat TCP6-LISTEN:${port},fork,reuseaddr TCP6:[${ip}]:${port} &" >> /usr/local/bin/socat-start.sh
        echo "转发规则已添加。"
        read -p "是否继续添加(Y/N)? " answer
        if [[ "$answer" != "Y" && "$answer" != "y" ]]; then
            # 用户完成添加，将#!/bin/bash和wait分别添加到文件的首尾
            sed -i '1i#!/bin/bash' /usr/local/bin/socat-start.sh
            echo "wait" >> /usr/local/bin/socat-start.sh
            chmod +x /usr/local/bin/socat-start.sh || handle_error
            countdown
            break
        fi
    done
}

deploy_socat() {
    echo "更新软件源并安装 socat..."
    cat > /etc/apt/sources.list << EOF || handle_error
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free
deb https://security.debian.org/debian-security bullseye-security main contrib non-free
EOF
    apt-get update || handle_error
    apt-get install -y socat || handle_error
    initialize_socat_start
    echo "创建并配置socat服务..."
    cat > /etc/systemd/system/socat.service << EOF || handle_error
[Unit]
Description=Internet Freedom

[Service]
DynamicUser=true
ProtectSystem=true
ProtectHome=true
ExecStart=/usr/local/bin/socat-start.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload || handle_error
    systemctl enable socat.service || handle_error
    echo -e "\e[32m服务已安装完成\e[0m"
    countdown
}

view_forwarding() {
    echo "当前转发规则如下："
    cat /usr/local/bin/socat-start.sh || handle_error
    read -p "按任意键返回主菜单..."
}

start_service() {
    systemctl daemon-reload || handle_error
    systemctl restart socat.service || handle_error
    echo -e "\e[32msocat服务已启动。\e[0m"
    countdown
}

remove_forwarding() {
    echo "当前转发规则如下："
    cat -n /usr/local/bin/socat-start.sh || handle_error
    read -p "请输入要移除的转发规则编号: " line_number
    if [[ ! $line_number =~ ^[0-9]+$ ]]; then
        echo "无效的编号，请输入一个有效的数字。"
        return
    fi
    sed -i "${line_number}d" /usr/local/bin/socat-start.sh || handle_error
    echo "转发规则已移除。"
    countdown
}

while true; do
    show_menu
    read -p "请输入您的选择（0-5）: " choice
    case $choice in
        0)
            echo "退出脚本。"
            break
            ;;
        1)
            deploy_socat
            ;;
        2)
            add_forwarding
            ;;
        3)
            remove_forwarding
            ;;
        4)
            view_forwarding
            ;;
        5)
            start_service
            ;;
        *)
            echo "无效输入，请重新输入。"
            ;;
    esac
done
