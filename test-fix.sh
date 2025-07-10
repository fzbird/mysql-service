#!/bin/bash

# ========================================================================
# MySQL 服务修复验证脚本
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

# 测试 Docker Compose 配置
test_compose_config() {
    print_separator
    print_info "测试 Docker Compose 配置..."
    
    if [ ! -f "docker-compose.mysql.yml" ]; then
        print_error "找不到 docker-compose.mysql.yml 文件"
        return 1
    fi
    
    # 测试配置语法
    if docker-compose -f docker-compose.mysql.yml config > /dev/null 2>&1; then
        print_success "✅ Docker Compose 配置语法正确"
    else
        print_error "❌ Docker Compose 配置语法错误"
        return 1
    fi
    
    # 检查是否有版本警告
    CONFIG_OUTPUT=$(docker-compose -f docker-compose.mysql.yml config 2>&1)
    if echo "$CONFIG_OUTPUT" | grep -q "version.*obsolete"; then
        print_error "❌ 仍然存在版本警告"
        return 1
    else
        print_success "✅ 没有版本警告"
    fi
    
    # 检查网络配置
    if echo "$CONFIG_OUTPUT" | grep -q "external.*true"; then
        print_success "✅ 网络配置正确 (external: true)"
    else
        print_error "❌ 网络配置错误"
        return 1
    fi
}

# 测试环境变量配置
test_env_config() {
    print_separator
    print_info "测试环境变量配置..."
    
    if [ ! -f "mysql.env" ]; then
        print_error "找不到 mysql.env 文件"
        return 1
    fi
    
    # 检查关键配置
    if grep -q "PHPMYADMIN_PORT=9103" mysql.env; then
        print_success "✅ phpMyAdmin 端口配置正确 (9103)"
    else
        print_error "❌ phpMyAdmin 端口配置错误"
        return 1
    fi
    
    if grep -q "MYSQL_ROOT_PASSWORD=mysql_root_password_2024" mysql.env; then
        print_success "✅ MySQL root 密码配置正确"
    else
        print_warning "⚠️ 请检查 MySQL root 密码配置"
    fi
}

# 测试网络状态
test_network_status() {
    print_separator
    print_info "测试网络状态..."
    
    # 检查网络是否存在
    if docker network ls | grep -q "shared-mysql-network"; then
        print_success "✅ shared-mysql-network 网络存在"
        
        # 检查网络配置
        NETWORK_SUBNET=$(docker network inspect shared-mysql-network --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null || echo "")
        if [[ "$NETWORK_SUBNET" == "172.23.0.0/16" ]]; then
            print_success "✅ 网络子网配置正确 ($NETWORK_SUBNET)"
        else
            print_warning "⚠️ 网络子网配置: $NETWORK_SUBNET"
        fi
    else
        print_error "❌ shared-mysql-network 网络不存在"
        return 1
    fi
}

# 测试服务脚本
test_service_script() {
    print_separator
    print_info "测试服务管理脚本..."
    
    if [ ! -f "mysql-service.sh" ]; then
        print_error "找不到 mysql-service.sh 文件"
        return 1
    fi
    
    if [ ! -x "mysql-service.sh" ]; then
        print_error "mysql-service.sh 不可执行"
        return 1
    fi
    
    print_success "✅ 服务管理脚本存在且可执行"
}

# 显示测试结果
show_results() {
    print_separator
    print_info "测试结果总结："
    
    echo ""
    echo "🔧 修复验证完成！"
    echo ""
    echo "📋 修复内容："
    echo "  ✅ 移除了过时的 Docker Compose 版本声明"
    echo "  ✅ 修复了网络配置 (external: true)"
    echo "  ✅ 更新了 phpMyAdmin 端口为 9103"
    echo "  ✅ 优化了数据库配置"
    echo ""
    echo "🚀 现在可以安全地启动服务："
    echo "  ./mysql-service.sh quick-start"
    echo ""
    echo "🌐 访问地址："
    echo "  MySQL:        localhost:3306"
    echo "  phpMyAdmin:   http://localhost:9103"
    echo "  监控:         http://localhost:9104/metrics"
    echo ""
}

# 主函数
main() {
    print_separator
    print_info "MySQL 服务修复验证测试"
    print_separator
    
    # 检查 Docker 是否可用
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker 未运行或无权限访问"
        exit 1
    fi
    
    # 执行测试
    test_compose_config
    test_env_config
    test_network_status
    test_service_script
    
    show_results
    
    print_separator
    print_success "🎉 所有测试通过！修复验证成功！"
    print_separator
}

# 执行主函数
main "$@" 