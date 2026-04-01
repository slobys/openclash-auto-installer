#!/bin/bash
# 网络诊断工具
# 功能：全面网络检测、问题诊断、修复建议

set -Eeuo pipefail

# 导入库
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
source "${LIB_DIR}/error.sh"
source "${LIB_DIR}/network.sh"

# 设置错误处理
set_error_trap "network-diagnose"
setup_error_logging "/tmp/network-diagnose.log"

# 显示横幅
show_banner() {
    cat <<'EOF'
╔═══════════════════════════════════════════╗
║      OpenClash 网络诊断工具 v1.0         ║
║           智能网络层增强版               ║
╚═══════════════════════════════════════════╝
EOF
}

# 运行完整诊断
full_diagnosis() {
    log INFO "开始完整网络诊断..."
    echo ""
    
    # 1. 基本连通性
    log INFO "1. 基本网络连通性测试"
    test_basic_connectivity
    echo ""
    
    # 2. 服务连通性
    log INFO "2. 关键服务连通性测试"
    test_service_connectivity
    echo ""
    
    # 3. 镜像延迟
    log INFO "3. 镜像站延迟测试"
    test_mirror_latency
    echo ""
    
    # 4. 问题诊断
    log INFO "4. 网络问题诊断"
    diagnose_network_issues
    echo ""
    
    # 5. 生成报告
    local report_file="/tmp/network-diagnosis-$(date +%Y%m%d_%H%M%S).txt"
    generate_network_report "$report_file"
    
    log SUCCESS "诊断完成!"
    echo ""
    log INFO "报告文件: $report_file"
}

# 快速诊断
quick_diagnosis() {
    log INFO "快速网络诊断..."
    
    local tests_passed=0
    local tests_total=4
    
    # 测试互联网连接
    log INFO "1. 测试互联网连接"
    if ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1; then
        log SUCCESS "✓ 互联网连接正常"
        tests_passed=$((tests_passed + 1))
    else
        log ERROR "✗ 互联网连接失败"
    fi
    
    # 测试DNS
    log INFO "2. 测试DNS解析"
    if nslookup github.com >/dev/null 2>&1 || dig github.com +short >/dev/null 2>&1; then
        log SUCCESS "✓ DNS解析正常"
        tests_passed=$((tests_passed + 1))
    else
        log ERROR "✗ DNS解析失败"
    fi
    
    # 测试GitHub
    log INFO "3. 测试GitHub连通性"
    if curl -s --max-time 5 --head https://github.com >/dev/null 2>&1; then
        log SUCCESS "✓ GitHub访问正常"
        tests_passed=$((tests_passed + 1))
    else
        log ERROR "✗ GitHub访问失败"
    fi
    
    # 测试下载
    log INFO "4. 测试文件下载"
    if curl -s --max-time 10 https://raw.githubusercontent.com/hello >/dev/null 2>&1; then
        log SUCCESS "✓ 文件下载正常"
        tests_passed=$((tests_passed + 1))
    else
        log WARN "⚠  文件下载可能受限"
    fi
    
    # 结果汇总
    echo ""
    log INFO "快速诊断结果: $tests_passed/$tests_total 通过"
    
    if [ "$tests_passed" -eq "$tests_total" ]; then
        log SUCCESS "网络状态良好"
    elif [ "$tests_passed" -ge 2 ]; then
        log WARN "网络部分受限，可能影响安装"
    else
        log ERROR "网络连接严重异常"
    fi
}

# 修复常见问题
fix_common_issues() {
    log INFO "尝试修复常见网络问题..."
    
    # 备份 resolv.conf
    if [ -f /etc/resolv.conf ]; then
        cp -f /etc/resolv.conf /etc/resolv.conf.bak.$(date +%s)
    fi
    
    # 1. 修复DNS
    log INFO "1. 修复DNS设置"
    cat > /tmp/resolv.conf.fix <<EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 114.114.114.114
nameserver 223.5.5.5
EOF
    
    if cp -f /tmp/resolv.conf.fix /etc/resolv.conf 2>/dev/null; then
        log SUCCESS "DNS设置已更新"
    else
        log WARN "无法更新/etc/resolv.conf，请手动修改"
    fi
    
    # 2. 清理代理设置
    log INFO "2. 清理代理设置"
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY
    log SUCCESS "代理环境变量已清理"
    
    # 3. 测试修复效果
    echo ""
    log INFO "测试修复效果..."
    quick_diagnosis
    
    # 提供进一步建议
    echo ""
    suggest_fixes
}

# 显示帮助
show_help() {
    cat <<'EOF'
网络诊断工具 v1.0

用法: network-diagnose.sh [选项]

选项:
  --full          完整诊断 (默认)
  --quick         快速诊断
  --fix           尝试自动修复
  --report <文件> 生成报告到文件
  --test <服务>   测试特定服务 (github, raw, sf, jsdelivr)
  --help          显示帮助

命令:
  basic           基本连通性测试
  services        服务连通性测试  
  latency         镜像延迟测试
  diagnose        问题诊断
  stats           网络统计信息

示例:
  ./network-diagnose.sh                  # 完整诊断
  ./network-diagnose.sh --quick          # 快速诊断
  ./network-diagnose.sh --fix            # 尝试修复
  ./network-diagnose.sh --test github    # 测试GitHub
  ./network-diagnose.sh --report my.txt  # 生成报告

环境变量:
  DEBUG=1         启用详细输出
  NO_COLOR=1      禁用颜色输出
  LOG_LEVEL=DEBUG 日志级别

EOF
}

# 测试特定服务
test_specific_service() {
    local service="$1"
    
    case "$service" in
        github)
            log INFO "测试 GitHub 连通性"
            curl -I -s --max-time 10 "https://github.com" | head -1
            ;;
        raw)
            log INFO "测试 GitHub Raw 连通性"
            curl -I -s --max-time 10 "https://raw.githubusercontent.com" | head -1
            ;;
        sf)
            log INFO "测试 SourceForge 连通性"
            curl -I -s --max-time 10 "https://master.dl.sourceforge.net" | head -1
            ;;
        jsdelivr)
            log INFO "测试 jsDelivr 连通性"
            curl -I -s --max-time 10 "https://cdn.jsdelivr.net" | head -1
            ;;
        ghproxy)
            log INFO "测试 ghproxy 连通性"
            curl -I -s --max-time 10 "https://ghproxy.com" | head -1
            ;;
        *)
            log ERROR "未知服务: $service"
            log INFO "可用服务: github, raw, sf, jsdelivr, ghproxy"
            return 1
            ;;
    esac
}

# 主函数
main() {
    local action="full"
    local service=""
    local report_file=""
    
    # 显示横幅
    show_banner
    echo ""
    
    # 检查参数
    if [ $# -eq 0 ]; then
        action="full"
    else
        case "$1" in
            --full|-f)
                action="full"
                ;;
            --quick|-q)
                action="quick"
                ;;
            --fix|-x)
                action="fix"
                ;;
            --test|-t)
                action="test"
                service="$2"
                ;;
            --report|-r)
                action="report"
                report_file="$2"
                ;;
            --help|-h)
                show_help
                return 0
                ;;
            basic|services|latency|diagnose|stats)
                action="$1"
                ;;
            *)
                log ERROR "未知参数: $1"
                show_help
                return 1
                ;;
        esac
    fi
    
    # 执行操作
    case "$action" in
        full)
            full_diagnosis
            ;;
        quick)
            quick_diagnosis
            ;;
        fix)
            fix_common_issues
            ;;
        test)
            if [ -z "$service" ]; then
                log ERROR "请指定要测试的服务"
                show_help
                return 1
            fi
            test_specific_service "$service"
            ;;
        report)
            if [ -z "$report_file" ]; then
                report_file="/tmp/network-report-$(date +%Y%m%d_%H%M%S).txt"
            fi
            generate_network_report "$report_file"
            ;;
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
        stats)
            echo "网络统计信息:"
            echo "IP地址: $(hostname -I 2>/dev/null || ip addr show 2>/dev/null | grep 'inet ' | head -1)"
            echo "网关: $(ip route show default 2>/dev/null | awk '{print $3}' || echo '未知')"
            echo "DNS: $(grep nameserver /etc/resolv.conf 2>/dev/null | head -3)"
            echo "接口: $(ip link show 2>/dev/null | grep 'state UP' | awk -F': ' '{print $2}' | tr '\n' ' ')"
            ;;
    esac
    
    # 显示完成消息
    if [ "$action" != "report" ]; then
        echo ""
        log INFO "诊断工具版本: 1.0"
        log INFO "更多帮助: ./network-diagnose.sh --help"
    fi
}

# 运行主函数
main "$@"

# 优雅退出
graceful_exit 0 "网络诊断完成"