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
    # 增加了 ffmpeg 到依赖列表中
    local packages=("python3" "python3-pip" "wget" "unzip" "tar" "jq" "grep" "ffmpeg")
    local success=true
    for package in "${packages[@]}"; do
        if ! command -v "$package" &>/dev/null; then
            echo -e "${gl_huang}正在安装 $package...${gl_bai}"
            if command -v dnf &>/dev/null; then
                dnf -y update
                dnf install -y epel-release "$package"
            elif command -v yum &>/dev/null; then
                yum -y update
                yum install -y epel-release "$package"
            elif command -v apt &>/dev/null; then
                apt update -y
                apt install -y "$package"
            elif command -v apk &>/dev/null; then
                apk update
                apk add "$package"
            elif command -v pacman &>/dev/null; then
                pacman -Syu --noconfirm
                pacman -S --noconfirm "$package"
            elif command -v zypper &>/dev/null; then
                zypper refresh
                zypper install -y "$package"
            elif command -v opkg &>/dev/null; then
                opkg update
                opkg install "$package"
            elif command -v pkg &>/dev/null; then
                pkg update
                pkg install -y "$package"
            else
                echo -e "${gl_hong}未知的包管理器，请手动安装 $package。${gl_bai}"
                success=false
            fi
        fi
    done
    
    # 额外安装 yt-dlp
    if ! command -v yt-dlp &>/dev/null; then
        echo -e "${gl_huang}正在安装 yt-dlp...${gl_bai}"
        pip3 install yt-dlp || success=false
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
            # 注意：这里返回0允许脚本继续运行，但用户已被警告功能受限。
            # 如果希望强制 ffmpeg 存在才能继续，这里可以返回1。
            # 当前设置为返回0，即警告后仍可使用部分功能。
            return 0 
        fi
    fi
    
    # 如果两个都安装成功，则返回0
    if "$yt_dlp_installed" && "$ffmpeg_installed"; then
        return 0
    else
        return 1
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
                            # yt-dlp 格式代码：优先4K -> 2K -> 1080P，如果都不支持则选择最佳。
                            # 这里的逻辑是：尝试找2160p (4K) 的视频流和最佳音频，如果不行，
                            # 则尝试1440p (2K) 的视频流和最佳音频，如果还不行，
                            # 则尝试1080p 的视频流和最佳音频，最后退回到yt-dlp认为的“最佳”格式。
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
                pip3 install --upgrade yt-dlp
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