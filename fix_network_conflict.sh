#!/bin/bash

# ========================================================================
# Docker 网络冲突修复脚本
# ========================================================================
# 
# 此脚本用于解决 MySQL 集群和共享 MySQL 网络之间的冲突
#
# ========================================================================

set -e

# 颜色输出函数
print_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

print_separator() {
    echo "=================================================================="
}

# 检查网络状态
check_networks() {
    print_separator
    print_info "检查现有 Docker 网络..."
    
    echo ""
    print_info "所有 Docker 网络:"
    docker network ls
    
    echo ""
    print_info "MySQL 相关网络:"
    docker network ls | grep mysql || echo "没有找到 MySQL 相关网络"
    
    echo ""
    print_info "网络地址段使用情况:"
    docker network inspect $(docker network ls -q) 2>/dev/null | grep -A 3 "\"Subnet\"" | grep "Subnet\|Gateway" || echo "无法获取网络详情"
}

# 清理冲突的网络
cleanup_conflicting_networks() {
    print_separator
    print_info "清理可能冲突的网络..."
    
    # 停止所有可能使用冲突网络的容器
    print_info "停止 MySQL 相关容器..."
    
    # 停止集群容器
    if docker ps | grep -q "mysql_master\|mysql_slave\|mysql_proxy\|mysql_monitor"; then
        print_warning "发现运行中的 MySQL 集群容器，正在停止..."
        docker-compose -f docker-compose.mysql-cluster.yml down 2>/dev/null || true
    fi
    
    # 停止共享 MySQL 容器
    if docker ps | grep -q "mysql_db\|mysql_admin_panel\|mysql_monitor"; then
        print_warning "发现运行中的共享 MySQL 容器，正在停止..."
        docker-compose -f docker-compose.mysql.yml down 2>/dev/null || true
    fi
    
    # 删除可能冲突的网络
    print_info "清理冲突的网络..."
    
    # 尝试删除 MySQL 集群网络
    if docker network ls | grep -q "mysql-cluster-network"; then
        print_warning "删除现有的 mysql-cluster-network..."
        docker network rm mysql-cluster-network 2>/dev/null || true
    fi
    
    # 检查是否存在名称包含 gallery 的网络
    GALLERY_NETWORKS=$(docker network ls | grep gallery | awk '{print $2}' || true)
    if [ -n "$GALLERY_NETWORKS" ]; then
        print_warning "发现 Gallery 相关网络，正在清理..."
        for network in $GALLERY_NETWORKS; do
            echo "  删除网络: $network"
            docker network rm "$network" 2>/dev/null || true
        done
    fi
    
    # 如果存在有问题的 shared-mysql-network，重新创建它
    if docker network ls | grep -q "shared-mysql-network"; then
        print_warning "检查现有的 shared-mysql-network..."
        
        # 检查网络是否有正确的标签
        NETWORK_LABELS=$(docker network inspect shared-mysql-network --format '{{json .Labels}}' 2>/dev/null || echo "{}")
        
        if [[ "$NETWORK_LABELS" == "{}" ]] || [[ "$NETWORK_LABELS" == "null" ]]; then
            print_warning "shared-mysql-network 缺少正确的标签，重新创建..."
            docker network rm shared-mysql-network 2>/dev/null || true
            sleep 2
        else
            print_success "shared-mysql-network 状态正常"
        fi
    fi
    
    print_success "网络清理完成"
}

# 重新创建网络
recreate_networks() {
    print_separator
    print_info "创建/验证网络..."
    
    # 创建共享 MySQL 网络（如果不存在）
    if ! docker network ls | grep -q "shared-mysql-network"; then
        print_info "创建共享 MySQL 网络..."
        docker network create shared-mysql-network \
            --driver bridge \
            --subnet=172.23.0.0/16 \
            --gateway=172.23.0.1 \
            --label com.docker.compose.network=shared-mysql-network \
            --label com.docker.compose.project=mysql-service || {
                print_error "创建共享 MySQL 网络失败"
                return 1
            }
        print_success "共享 MySQL 网络创建成功"
    else
        print_success "共享 MySQL 网络已存在"
        
        # 验证网络配置
        NETWORK_SUBNET=$(docker network inspect shared-mysql-network --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "")
        if [[ "$NETWORK_SUBNET" == "172.23.0.0/16" ]]; then
            print_success "网络配置验证通过"
        else
            print_warning "网络配置可能不正确: $NETWORK_SUBNET"
        fi
    fi
    
    # MySQL 集群网络将在启动时自动创建
    print_info "MySQL 集群网络将在启动集群时自动创建"
}

# 验证网络配置
verify_networks() {
    print_separator
    print_info "验证网络配置..."
    
    echo ""
    print_info "当前网络状态:"
    docker network ls | grep -E "(shared-mysql|mysql-cluster)" || echo "没有找到 MySQL 网络"
    
    echo ""
    print_info "验证 Docker Compose 配置..."
    
    # 验证共享 MySQL 配置
    if [ -f "docker-compose.mysql.yml" ]; then
        print_info "检查共享 MySQL 配置..."
        if docker-compose -f docker-compose.mysql.yml config > /dev/null 2>&1; then
            print_success "✅ 共享 MySQL 配置验证通过"
        else
            print_error "❌ 共享 MySQL 配置验证失败"
            echo "尝试显示详细错误信息："
            docker-compose -f docker-compose.mysql.yml config
        fi
    fi
    
    # 验证 MySQL 集群配置
    if [ -f "docker-compose.mysql-cluster.yml" ]; then
        print_info "检查 MySQL 集群配置..."
        if docker-compose -f docker-compose.mysql-cluster.yml config > /dev/null 2>&1; then
            print_success "✅ MySQL 集群配置验证通过"
        else
            print_warning "⚠️ MySQL 集群配置验证失败（可能是文件不存在）"
        fi
    fi
    
    # 验证网络可达性
    print_info "验证网络详情..."
    if docker network ls | grep -q "shared-mysql-network"; then
        echo ""
        print_info "shared-mysql-network 详情:"
        docker network inspect shared-mysql-network --format '{{json .}}' | jq -r '
        "网络名称: " + .Name,
        "驱动: " + .Driver,
        "子网: " + (.IPAM.Config[0].Subnet // "未设置"),
        "网关: " + (.IPAM.Config[0].Gateway // "未设置"),
        "标签: " + ((.Labels // {}) | to_entries | map(.key + "=" + .value) | join(", "))
        ' 2>/dev/null || {
            print_warning "无法获取网络详情（可能需要安装 jq）"
            docker network inspect shared-mysql-network
        }
    fi
}

# 提供解决方案建议
show_solution() {
    print_separator
    print_info "解决方案和后续步骤:"
    
    echo ""
    echo "🔧 网络配置已修复，现在可以："
    echo ""
    echo "1. 启动共享 MySQL 数据库:"
    echo "   ./mysql-service.sh start"
    echo ""
    echo "2. 或者启动 MySQL 集群:"
    echo "   ./mysql-cluster.sh start"
    echo ""
    echo "3. 或者启动主项目 (会自动启动共享 MySQL):"
    echo "   ./deploy.sh"
    echo ""
    echo "📊 网络地址分配:"
    echo "   共享 MySQL:   172.23.0.0/16"
    echo "   MySQL 集群:   172.24.0.0/16"
    echo "   其他项目:     172.25.0.0/16 (可用)"
    echo ""
    echo "🌐 访问地址:"
    echo "   MySQL:        localhost:3306"
    echo "   phpMyAdmin:   http://localhost:9103"
    echo "   监控:         http://localhost:9104/metrics"
    echo ""
    echo "⚠️ 注意: 这两个 MySQL 解决方案是独立的，请根据需要选择使用。"
}

# 测试网络连通性
test_network_connectivity() {
    print_separator
    print_info "测试网络连通性..."
    
    if docker network ls | grep -q "shared-mysql-network"; then
        # 创建测试容器
        print_info "创建测试容器..."
        docker run --rm --network shared-mysql-network alpine:latest ping -c 3 172.23.0.1 > /dev/null 2>&1 && {
            print_success "✅ 网络连通性测试通过"
        } || {
            print_warning "⚠️ 网络连通性测试失败"
        }
    else
        print_error "❌ 无法找到 shared-mysql-network 网络"
    fi
}

# 主函数
main() {
    print_separator
    print_info "Docker 网络冲突修复工具 v2.0"
    print_separator
    
    # 检查 Docker 是否运行
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker 未运行或无权限访问"
        exit 1
    fi
    
    # 检查必要的工具
    if ! command -v docker-compose > /dev/null 2>&1; then
        print_error "Docker Compose 未安装"
        exit 1
    fi
    
    # 执行修复步骤
    check_networks
    
    echo ""
    read -p "是否继续修复网络冲突？这将停止相关容器并重新创建网络 (y/n): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "操作已取消"
        exit 0
    fi
    
    cleanup_conflicting_networks
    sleep 2
    recreate_networks
    sleep 2
    verify_networks
    test_network_connectivity
    show_solution
    
    print_separator
    print_success "🎉 网络冲突修复完成！"
    print_separator
}

# 执行主函数
main "$@" 