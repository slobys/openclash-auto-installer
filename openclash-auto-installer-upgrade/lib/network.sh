#!/bin/bash
# 网络诊断工具 v1.0
# 功能：网络连通性测试、镜像延迟检测、故障诊断

set -Eeuo pipefail

# 导入下载库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/download.sh" 2>/dev/null || true

# 颜色输出
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    BOLD='\033[1m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; NC=''; BOLD=''
fi

# 日志函数
log_info() { printf "%b==>%b %s\n" "${BLUE}" "${NC}" "$*" >&2; }
log_success() { printf "%b✅%b %s\n" "${GREEN}" "${NC}" "$*" >&2; }
log_warn() { printf "%b⚠️ %b %s\n" "${YELLOW}" "${NC}" "$*" >&2; }
log_error() { printf "%b❌%b %s\n" "${RED}" "${NC}" "$*" >&2; }
log_debug() { [ "${DEBUG:-0}" = "1" ] && printf "%b[DEBUG]%b %s\n" "${MAGENTA}" "${NC}" "$*" >&2; }

# 检查命令
need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        log_warn "缺少命令: $1 (部分功能可能受限)"
        return 1
    fi
}

# 测试基本连通性
test_basic_connectivity() {
    log_info "测试基本网络连通性..."
    
    local success=0
    local total=0
    
    # 测试DNS解析
    if command -v nslookup >/dev/null 2>&1 || command -v dig >/dev/null 2>&1; then
        total=$((total + 1))
        if nslookup github.com >/dev/null 2>&1 || dig github.com +short >/dev/null 2>&1; then
            log_success "DNS解析正常"
            success=$((success + 1))
        else
            log_error "DNS解析失败"
        fi
    fi
    
    # 测试ping
    if command -v ping >/dev/null 2>&1; then
        total=$((total + 1))
        if ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1; then
            log_success "网络连通性正常 (ping 8.8.8.8)"
            success=$((success + 1))
        else
            log_warn "网络连通性异常 (可能防火墙阻止ICMP)"
        fi
    fi
    
    # 测试HTTP连接
    total=$((total + 1))
    if curl -s --max-time 5 --head http://connectivitycheck.gstatic.com/generate_204 >/dev/null 2>&1; then
        log_success "HTTP连接正常"
        success=$((success + 1))
    else
        log_warn "HTTP连接失败"
    fi
    
    # 测试HTTPS连接
    total=$((total + 1))
    if curl -s --max-time 5 --head https://www.google.com >/dev/null 2>&1; then
        log_success "HTTPS连接正常"
        success=$((success + 1))
    else
        log_warn "HTTPS连接失败 (可能证书或代理问题)"
    fi
    
    # 输出结果
    if [ $total -gt 0 ]; then
        local percentage=$((success * 100 / total))
        if [ $percentage -ge 80 ]; then
            log_success "基本网络测试: $success/$total 通过 (${percentage}%)"
        elif [ $percentage -ge 50 ]; then
            log_warn "基本网络测试: $success/$total 通过 (${percentage}%) - 部分功能可能受限"
        else
            log_error "基本网络测试: $success/$total 通过 (${percentage}%) - 网络连接严重异常"
        fi
    fi
    
    return $((success == total ? 0 : 1))
}

# 测试特定服务连通性
test_service_connectivity() {
    log_info "测试关键服务连通性..."
    
    # 定义测试目标
    local services=(
        "GitHub API:https://api.github.com"
        "GitHub Raw:https://raw.githubusercontent.com"
        "SourceForge:https://master.dl.sourceforge.net"
        "jsDelivr CDN:https://cdn.jsdelivr.net"
        "GitHub Proxy:https://ghproxy.com"
        "OpenWrt Packages:https://downloads.openwrt.org"
    )
    
    local success=0
    local total=${#services[@]}
    
    for service in "${services[@]}"; do
        local name="${service%%:*}"
        local url="${service#*:}"
        
        if curl -s --max-time 10 --head "$url" >/dev/null 2>&1; then
            log_success "$name: 可达"
            success=$((success + 1))
        else
            log_warn "$name: 不可达"
        fi
    done
    
    local percentage=$((success * 100 / total))
    log_info "服务连通性: $success/$total 通过 (${percentage}%)"
    
    if [ $percentage -lt 60 ]; then
        log_error "多个关键服务不可达，可能影响安装"
        return 1
    fi
    
    return 0
}

# 测试镜像延迟
test_mirror_latency() {
    log_info "测试镜像站延迟 (ping测试)..."
    
    # 常见镜像列表
    local mirrors=(
        "GitHub Raw:raw.githubusercontent.com"
        "jsDelivr CDN:cdn.jsdelivr.net"
        "GitHub Proxy:ghproxy.com"
        "SourceForge:master.dl.sourceforge.net"
        "OpenWrt US:downloads.openwrt.org"
        "OpenWrt CN:mirrors.tuna.tsinghua.edu.cn/openwrt"
    )
    
    if ! command -v ping >/dev/null 2>&1; then
        log_warn "ping命令不可用，跳过延迟测试"
        return 0
    fi
    
    local results=()
    
    for mirror in "${mirrors[@]}"; do
        local name="${mirror%%:*}"
        local host="${mirror#*:}"
        
        # 提取主机名（去掉路径）
        host="${host%%/*}"
        
        log_info "测试 $name ($host)..."
        
        # 执行ping测试
        if ping_output=$(ping -c 3 -W 2 "$host" 2>/dev/null); then
            # 提取平均延迟
            local avg_latency=$(echo "$ping_output" | grep -E '^rtt|^round-trip' | sed -E 's/.* = [^/]+\/([^/]+)\/.*/\1/' | cut -d. -f1)
            
            if [ -n "$avg_latency" ]; then
                results+=("$name: ${avg_latency}ms")
                log_info "  └─ 平均延迟: ${avg_latency}ms"
            else
                results+=("$name: 成功但无法解析延迟")
                log_info "  └─ 可达 (延迟未知)"
            fi
        else
            results+=("$name: 超时")
            log_warn "  └─ 超时"
        fi
    done
    
    # 显示结果摘要
    log_info "镜像延迟测试结果:"
    for result in "${results[@]}"; do
        echo "  $result"
    done
    
    # 推荐最佳镜像
    local best_mirror=""
    local best_latency=99999
    
    for result in "${results[@]}"; do
        local name="${result%%:*}"
        local latency="${result#*:}"
        
        if [[ "$latency" =~ ^[0-9]+ms$ ]]; then
            latency="${latency%ms}"
            if [ "$latency" -lt "$best_latency" ]; then
                best_latency="$latency"
                best_mirror="$name"
            fi
        fi
    done
    
    if [ -n "$best_mirror" ]; then
        log_success "推荐镜像: $best_mirror (延迟: ${best_latency}ms)"
    fi
}

# 诊断网络问题
diagnose_network_issues() {
    log_info "网络问题诊断..."
    
    local issues_found=0
    
    # 检查DNS配置
    log_info "检查DNS配置..."
    if [ -f /etc/resolv.conf ]; then
        local dns_servers=$(grep -E '^nameserver' /etc/resolv.conf | wc -l)
        if [ "$dns_servers" -eq 0 ]; then
            log_error "未配置DNS服务器"
            issues_found=$((issues_found + 1))
        else
            log_info "DNS服务器: $dns_servers 个"
        fi
    else
        log_warn "/etc/resolv.conf 不存在"
    fi
    
    # 检查代理设置
    log_info "检查代理设置..."
    local proxy_vars="http_proxy https_proxy HTTP_PROXY HTTPS_PROXY"
    local has_proxy=0
    
    for var in $proxy_vars; do
        if [ -n "${!var:-}" ]; then
            log_info "检测到代理: $var=${!var}"
            has_proxy=1
        fi
    done
    
    if [ "$has_proxy" -eq 1 ]; then
        log_warn "检测到代理设置，可能影响连接"
        issues_found=$((issues_found + 1))
    fi
    
    # 检查防火墙
    log_info "检查防火墙..."
    if command -v iptables >/dev/null 2>&1; then
        local firewall_rules=$(iptables -L -n 2>/dev/null | wc -l)
        if [ "$firewall_rules" -gt 10 ]; then
            log_info "防火墙规则: $firewall_rules 条 (可能限制连接)"
        fi
    fi
    
    # 检查curl/wget可用性
    log_info "检查下载工具..."
    local tools_missing=0
    for tool in curl wget; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_warn "缺少工具: $tool"
            tools_missing=$((tools_missing + 1))
        fi
    done
    
    if [ "$tools_missing" -eq 2 ]; then
        log_error "缺少curl和wget，无法下载文件"
        issues_found=$((issues_found + 1))
    fi
    
    # 检查系统时间
    log_info "检查系统时间..."
    if command -v date >/dev/null 2>&1; then
        local current_time=$(date +%s)
        local ntp_time=0
        
        # 简单检查时间是否合理（在2020-2030之间）
        if [ "$current_time" -lt 1577836800 ] || [ "$current_time" -gt 1893456000 ]; then
            log_error "系统时间异常: $(date)"
            log_error "证书验证可能失败，请同步时间"
            issues_found=$((issues_found + 1))
        else
            log_info "系统时间正常: $(date)"
        fi
    fi
    
    # 输出诊断结果
    if [ "$issues_found" -eq 0 ]; then
        log_success "未发现明显网络问题"
    else
        log_error "发现 $issues_found 个潜在问题"
        return 1
    fi
}

# 提供修复建议
suggest_fixes() {
    cat <<EOF

${BOLD}🔧 网络问题修复建议:${NC}

${CYAN}1. DNS问题修复:${NC}
   # 临时使用Google DNS
   echo "nameserver 8.8.8.8" > /tmp/resolv.conf
   echo "nameserver 8.8.4.4" >> /tmp/resolv.conf
   cp /tmp/resolv.conf /etc/resolv.conf

${CYAN}2. 代理设置检查:${NC}
   # 查看当前代理设置
   env | grep -i proxy
   
   # 临时取消代理
   unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY

${CYAN}3. 使用镜像加速:${NC}
   # 设置环境变量使用镜像
   export GITHUB_MIRROR="https://ghproxy.com"
   export RAW_MIRROR="https://cdn.jsdelivr.net/gh"

${CYAN}4. 离线模式:${NC}
   # 如果网络完全不通，使用离线安装
   # 1. 在其他机器下载所需文件
   # 2. 复制到U盘或scp到设备
   # 3. 设置缓存目录
   export ENABLE_CACHE=1
   export CACHE_DIR="/path/to/cache"

${CYAN}5. 防火墙临时放行:${NC}
   # 临时允许所有出站（仅测试用）
   iptables -P OUTPUT ACCEPT
   ip6tables -P OUTPUT ACCEPT

${CYAN}6. 时间同步:${NC}
   # 同步系统时间
   ntpdate pool.ntp.org
   # 或安装ntp客户端
   opkg update && opkg install ntpclient

${BOLD}🚀 快速修复脚本:${NC}
运行以下命令尝试自动修复常见问题:
${CYAN}curl -fsSL https://cdn.jsdelivr.net/gh/slobys/openclash-auto-installer/tools/network-fix.sh | sh${NC}
EOF
}

# 生成网络报告
generate_network_report() {
    local report_file="${1:-/tmp/network_report_$(date +%Y%m%d_%H%M%S).txt}"
    
    {
        echo "=== 网络诊断报告 ==="
        echo "生成时间: $(date)"
        echo "主机名: $(hostname 2>/dev/null || echo unknown)"
        echo "IP地址: $(hostname -I 2>/dev/null || ip addr show 2>/dev/null | grep 'inet ' | head -1)"
        echo ""
        
        echo "=== 基本连通性 ==="
        test_basic_connectivity 2>&1 | grep -E '^(==>|✅|⚠️|❌)' || true
        
        echo ""
        echo "=== 服务连通性 ==="
        test_service_connectivity 2>&1 | grep -E '^(==>|✅|⚠️|❌)' || true
        
        echo ""
        echo "=== 镜像延迟 ==="
        test_mirror_latency 2>&1 | grep -E '^(==>|测试|└─|推荐)' || true
        
        echo ""
        echo "=== 问题诊断 ==="
        diagnose_network_issues 2>&1 | grep -E '^(==>|✅|⚠️|❌)' || true
        
        echo ""
        echo "=== 系统信息 ==="
        echo "系统: $(uname -a)"
        echo "内存: $(free -h 2>/dev/null | grep Mem: || true)"
        echo "磁盘: $(df -h / 2>/dev/null | tail -1 || true)"
        
    } > "$report_file"
    
    log_success "网络报告已生成: $report_file"
    echo "报告内容摘要:"
    tail -20 "$report_file"
}

# 主函数
main() {
    local action="full"
    local report_file=""
    
    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            --basic)
                action="basic"
                shift
                ;;
            --services)
                action="services"
                shift
                ;;
            --latency)
                action="latency"
                shift
                ;;
            --diagnose)
                action="diagnose"
                shift
                ;;
            --report)
                action="report"
                report_file="$2"
                shift 2
                ;;
            --help|-h)
                cat <<EOF
网络诊断工具 v1.0
用法: $0 [选项]

选项:
  --basic          仅测试基本连通性
  --services       仅测试服务连通性
  --latency        仅测试镜像延迟
  --diagnose       仅进行问题诊断
  --report <文件>  生成完整报告到文件
  --help           显示帮助

环境变量:
  DEBUG=1         启用详细输出
  NO_COLOR=1      禁用颜色输出

示例:
  $0                    完整诊断
  $0 --basic            基本连通性测试
  $0 --report /tmp/net.txt 生成报告
EOF
                return 0
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 执行请求的操作
    case "$action" in
        basic)
            test_basic_connectivity
            ;;
        services)
            test_service_connectivity
            ;;
        latency)
            test_mirror_latency
            ;;
        diagnose)
            diagnose_network_issues
            ;;
        report)
            generate_network_report "$report_file"
            ;;
        full)
            echo "${BOLD}=== 开始完整网络诊断 ===${NC}"
            test_basic_connectivity
            echo ""
            test_service_connectivity
            echo ""
            test_mirror_latency
            echo ""
            diagnose_network_issues
            echo ""
            
            # 如果发现问题，提供建议
            if [ $? -ne 0 ]; then
                suggest_fixes
            fi
            
            log_success "诊断完成"
            ;;
    esac
}

# 如果直接运行
if [ "$(basename "$0")" = "network.sh" ]; then
    main "$@"
fi