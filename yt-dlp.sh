#!/bin/bash

# 定义颜色变量
gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_bai='\033[0m'
gl_zi='\033[35m'
gl_kjlan='\033[96m'

# 安装依赖
install_yt_dlp_dependency() {
    local packages=("python3" "python3-pip" "wget" "unzip" "tar" "jq" "grep" "ffmpeg")
    local success=true
    for package in "${packages[@]}"; do
        if ! command -v "$package" &>/dev/null; then
            echo -e "${gl_huang}正在尝试安装 $package...${gl_bai}"
            # 尝试使用 sudo 进行安装
            if command -v dnf &>/dev/null; then
                sudo dnf -y update && sudo dnf install -y epel-release "$package" || success=false
            elif command -v yum &>/dev/null; then
                sudo yum -y update && sudo yum install -y epel-release "$package" || success=false
            elif command -v apt &>/dev/null; then
                sudo apt update -y && sudo apt install -y "$package" || success=false
            elif command -v apk &>/dev/null; then
                sudo apk update && sudo apk add "$package" || success=false
            elif command -v pacman &>/dev/null; then
                sudo pacman -Syu --noconfirm && sudo pacman -S --noconfirm "$package" || success=false
            elif command -v zypper &>/dev/null; then
                sudo zypper refresh && sudo zypper install -y "$package" || success=false
            elif command -v opkg &>/dev/null; then
                sudo opkg update && sudo opkg install "$package" || success=false
            elif command -v pkg &>/dev/null; then
                sudo pkg update && sudo pkg install -y "$package" || success=false
            else
                echo -e "${gl_hong}未知的包管理器，请手动安装 $package。${gl_bai}"
                success=false
            fi
        fi
    done
    
    # 额外安装 yt-dlp
    if ! command -v yt-dlp &>/dev/null; then
        echo -e "${gl_huang}正在安装 yt-dlp...${gl_bai}"
        # pip 安装 yt-dlp 优先尝试用户目录安装，如果失败则尝试全局安装（可能需要 sudo）
        pip3 install --user yt-dlp || sudo pip3 install yt-dlp || success=false
    fi
    return "$success"
}


# 结束操作并等待用户输入
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo "按任意键继续..."
    read -n 1 -s -r -p ""
    echo ""
    clear
}

# 检查或安装 yt-dlp 和 ffmpeg
check_or_install_yt_dlp() {
    local yt_dlp_installed=false
    local ffmpeg_installed=false

    # 检查 yt-dlp 是否存在，如果不存在则尝试安装
    if command -v yt-dlp &>/dev/null; then
        yt_dlp_installed=true
    else
        echo -e "${gl_huang}未检测到 yt-dlp，正在尝试安装...${gl_bai}"
        install_yt_dlp_dependency
        if command -v yt-dlp &>/dev/null; then
            yt_dlp_installed=true
        else
            echo -e "${gl_hong}yt-dlp 安装失败，请检查您的环境或手动安装。${gl_bai}"
            break_end
            return 1
        fi
    fi

    # 检查 ffmpeg 是否存在，如果不存在则尝试安装
    if command -v ffmpeg &>/dev/null; then
        ffmpeg_installed=true
    else
        echo -e "${gl_huang}未检测到 ffmpeg，正在尝试安装...${gl_bai}"
        # 再次调用安装函数，确保 ffmpeg 被包含
        install_yt_dlp_dependency
        if command -v ffmpeg &>/dev/null; then
            ffmpeg_installed=true
        else
            echo -e "${gl_hong}ffmpeg 安装失败，yt-dlp 的某些功能可能受限。请手动安装 ffmpeg。${gl_bai}"
            break_end
            return 0 
        fi
    fi
    
    if "$yt_dlp_installed" && "$ffmpeg_installed"; then
        return 0
    else
        return 1
    fi
}

# 卸载 yt-dlp 及相关文件
uninstall_yt_dlp_function() {
    local SCRIPT_DIR
    SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

    clear
    echo -e "${gl_hong}=== 警告：卸载操作 ===${gl_bai}"
    echo -e "${gl_huang}此操作将执行以下删除：${gl_bai}"
    echo "- ${gl_lv}yt-dlp 程序（通过 pip3 安装的部分）${gl_bai}"
    echo "- ${gl_lv}ffmpeg （如果是由包管理器安装）${gl_bai}"
    echo "- ${gl_lv}本脚本文件 (yt-dlp.sh)${gl_bai}"
    echo "- ${gl_lv}本脚本所在的目录及其所有内容： ${SCRIPT_DIR}/${gl_bai}"
    echo -e "  (这包括所有由 yt-dlp 下载到此目录的视频、音频或其他文件)"
    echo -e "${gl_hong}重要提示：${gl_bai}"
    echo -e "${gl_hong}像 python3, pip3, wget, unzip, tar, jq, grep 等核心系统工具非常重要，不建议自动卸载。${gl_bai}"
    echo -e "${gl_hong}本脚本不会自动卸载它们。如需卸载，请您自行判断并手动使用'sudo apt remove/dnf remove/yum remove'等命令。${gl_bai}"
    echo ""
    read -e -p "您确定要继续卸载吗？(y/N): " confirm_uninstall
    confirm_uninstall=${confirm_uninstall:-N}

    if [[ "$confirm_uninstall" =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}正在尝试卸载 yt-dlp...${gl_bai}"
        # 尝试卸载 yt-dlp，优先卸载用户安装的，如果失败则尝试全局（可能需要 sudo）
        pip3 uninstall -y yt-dlp &>/dev/null || sudo pip3 uninstall -y yt-dlp &>/dev/null || true 
        
        echo -e "${gl_huang}正在尝试卸载 ffmpeg...${gl_bai}"
        # 尝试使用 sudo 卸载 ffmpeg
        if command -v dnf &>/dev/null; then
            sudo dnf -y remove ffmpeg || true
        elif command -v yum &>/dev/null; then
            sudo yum -y remove ffmpeg || true
        elif command -v apt &>/dev/null; then
            sudo apt -y remove ffmpeg || true
        elif command -v apk &>/dev/null; then
            sudo apk del ffmpeg || true
        elif command -v pacman &>/dev/null; then
            sudo pacman -Rs --noconfirm ffmpeg || true
        elif command -v zypper &>/dev/null; then
            sudo zypper -y remove ffmpeg || true
        elif command -v opkg &>/dev/null; then
            sudo opkg remove ffmpeg || true
        elif command -v pkg &>/dev/null; then
            sudo pkg remove ffmpeg || true
        else
            echo -e "${gl_hong}未知的包管理器，无法自动卸载 ffmpeg。请手动卸载。${gl_bai}"
        fi

        echo -e "${gl_huang}正在删除脚本文件和目录：${SCRIPT_DIR}...${gl_bai}"
        rm -rf "$SCRIPT_DIR" &>/dev/null & disown
        echo -e "${gl_lv}yt-dlp 及相关文件已成功删除。${gl_bai}"
        echo -e "${gl_lv}请注意：其他核心系统依赖可能仍然存在，如需卸载请手动操作。${gl_bai}"
        exit 0 
    else
        echo -e "${gl_lv}卸载操作已取消。${gl_bai}"
        break_end
    fi
}


# yt-dlp主菜单
yt_menu_pro() {
    check_or_install_yt_dlp || return 1

    while true; do
        clear
        echo -e "${gl_kjlan}YouTube视频下载器 (yt-dlp) 功能菜单${gl_bai}"
        echo "------------------------------------------------"
        echo "1. 下载视频或音频"
        echo "2. 更新 yt-dlp"
        echo "3. 查看 yt-dlp 版本"
        echo "4. 检查更新"
        echo "5. 卸载 yt-dlp 及相关文件" 
        echo "------------------------------------------------"
        echo "0. 返回主菜单"
        echo "------------------------------------------------"
        read -e -p "请输入你的选择: " choice

        case $choice in
            1)
                echo -e "${gl_huang}下载视频或音频${gl_bai}"
                read -e -p "请输入视频/播放列表URL: " url
                read -e -p "选择下载类型 (video/audio, 默认为video): " type
                type=${type:-video}

                if [ "$type" == "audio" ]; then
                    read -e -p "请输入音频格式 (mp3/m4a/best, 默认为best): " audio_format
                    audio_format=${audio_format:-best}
                    yt-dlp -x --audio-format "$audio_format" "$url"
                else
                    echo -e "${gl_kjlan}请选择视频下载质量优先级:${gl_bai}"
                    echo "1. 优先4K -> 2K -> 1080P (否则最佳可用)"
                    echo "2. 指定视频格式 (例如: best, bestvideo+bestaudio, 22, 137等)"
                    read -e -p "请输入你的选择 (默认为1): " video_quality_choice
                    video_quality_choice=${video_quality_choice:-1}

                    case $video_quality_choice in
                        1)
                            video_format_string="bestvideo[height=2160]+bestaudio/bestvideo[height=1440]+bestaudio/bestvideo[height=1080]+bestaudio/best"
                            echo -e "${gl_lv}将尝试按 4K -> 2K -> 1080P 优先级下载视频...${gl_bai}"
                            yt-dlp -f "$video_format_string" "$url"
                            ;;
                        2)
                            read -e -p "请输入视频格式 (best/bestvideo+bestaudio/22/137等, 默认为best): " video_format
                            video_format=${video_format:-best}
                            yt-dlp -f "$video_format" "$url"
                            ;;
                        *)
                            echo -e "${gl_hong}无效的选择，将使用默认最佳视频格式下载。${gl_bai}"
                            yt-dlp -f "best" "$url"
                            ;;
                    esac
                fi
                break_end
                ;;
            2)
                echo -e "${gl_huang}正在更新 yt-dlp...${gl_bai}"
                # pip 安装 yt-dlp 优先尝试用户目录安装，如果失败则尝试全局安装（可能需要 sudo）
                pip3 install --user --upgrade yt-dlp || sudo pip3 install --upgrade yt-dlp
                break_end
                ;;
            3)
                echo -e "${gl_huang}yt-dlp 版本信息:${gl_bai}"
                yt-dlp --version
                break_end
                ;;
            4)
                echo -e "${gl_huang}正在检查 yt-dlp 更新...${gl_bai}"
                pip3 install --upgrade --no-deps yt-dlp 2>&1 | grep -q 'Requirement already satisfied'
                if [ $? -eq 0 ]; then
                    echo -e "${gl_lv}yt-dlp 已是最新版本。${gl_bai}"
                else
                    echo -e "${gl_huang}yt-dlp 有可用更新，请选择选项2进行更新。${gl_bai}"
                fi
                break_end
                ;;
            5) 
                uninstall_yt_dlp_function
                ;;
            0)
                break
                ;;
            *)
                echo -e "${gl_hong}无效的选择，请重新输入。${gl_bai}"
                break_end
                ;;
        esac
    done
}

# 启动菜单
yt_menu_pro
