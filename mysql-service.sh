#!/bin/bash

# ========================================================================
# 独立共享 MySQL 服务管理脚本 (交互式版本)
# ========================================================================
# 
# 此脚本用于管理完全独立的共享 MySQL 数据库服务
# 可为多个项目提供数据库服务，每个项目使用独立的数据库
# 
# 使用方法:
#   ./mysql-service.sh                    - 交互式菜单
#   ./mysql-service.sh start              - 启动服务
#   ./mysql-service.sh stop               - 停止服务
#   ./mysql-service.sh restart            - 重启服务
#   ./mysql-service.sh status             - 查看服务状态
#   ./mysql-service.sh logs               - 查看服务日志
#   ./mysql-service.sh backup             - 备份所有数据库
#   ./mysql-service.sh cleanup            - 清理服务和数据
#   ./mysql-service.sh connect            - 连接到 MySQL
#   ./mysql-service.sh add-project <name> - 添加新项目数据库
#   ./mysql-service.sh list-dbs           - 列出所有数据库
#   ./mysql-service.sh quick-start        - 一键快速启动
#   ./mysql-service.sh interactive-setup  - 交互式配置启动
#
# ========================================================================

set -e

# 配置变量
COMPOSE_FILE="docker-compose.mysql.yml"
ENV_FILE="mysql.env"
SERVICE_NAME="db"
NETWORK_NAME="shared-mysql-network"
CONTAINER_NAME="mysql_db"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

print_header() {
    clear
    echo "=================================================================="
    echo "           独立共享 MySQL 服务管理系统"
    echo "=================================================================="
    echo ""
}

# 统一的配置加载函数
load_config() {
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
        print_info "已加载配置文件: $ENV_FILE"
    else
        print_error "找不到配置文件: $ENV_FILE"
        print_error "请确保 mysql.env 文件存在，或使用 './mysql-service.sh interactive-setup' 创建配置"
        exit 1
    fi
}

# 验证必要的配置参数
validate_config() {
    load_config
    
    # 验证必要的配置项
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        print_error "配置错误: 未设置 MYSQL_ROOT_PASSWORD"
        exit 1
    fi
    
    if [ -z "$MYSQL_PORT" ]; then
        print_error "配置错误: 未设置 MYSQL_PORT"
        exit 1
    fi
    
    if [ -z "$PHPMYADMIN_PORT" ]; then
        print_error "配置错误: 未设置 PHPMYADMIN_PORT"
        exit 1
    fi
    
    print_success "配置验证通过"
}

# 检查系统要求
check_requirements() {
    print_info "检查系统要求..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装或不在 PATH 中"
        echo "请安装 Docker Desktop 或 Docker Engine"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose 未安装或不在 PATH 中"
        echo "请安装 Docker Compose"
        exit 1
    fi
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "找不到配置文件: $COMPOSE_FILE"
        exit 1
    fi
    
    print_success "系统要求检查通过"
}

# 创建必要的目录
create_directories() {
    print_info "创建必要的目录..."
    
    mkdir -p logs/phpmyadmin
    mkdir -p mysql_data
    mkdir -p mysql_backups
    mkdir -p config
    mkdir -p init
    
    # 设置权限
    chmod 755 logs mysql_data mysql_backups config init
    
    print_success "目录创建完成"
}

# 初始化环境
init_environment() {
    print_info "初始化共享MySQL环境..."
    
    create_directories
    
    # 检查网络是否存在
    if docker network ls | grep -q "$NETWORK_NAME"; then
        print_warning "网络 $NETWORK_NAME 已存在"
    else
        print_info "创建共享网络: $NETWORK_NAME"
        docker network create "$NETWORK_NAME" --driver bridge
        print_success "网络创建成功"
    fi
    
    # 加载并验证配置
    validate_config
    
    print_success "环境初始化完成"
}

# 交互式配置
interactive_setup() {
    print_header
    echo "🛠️  交互式配置"
    print_separator
    
    # 加载现有配置
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    fi
    
    # 数据库配置
    echo "📊 数据库配置"
    echo ""
    read -p "MySQL Root 密码 [${MYSQL_ROOT_PASSWORD:-mysql_root_password_2024}]: " ROOT_PASSWORD
    ROOT_PASSWORD=${ROOT_PASSWORD:-${MYSQL_ROOT_PASSWORD:-mysql_root_password_2024}}
    
    read -p "MySQL 端口 [${MYSQL_PORT:-3306}]: " DB_PORT
    DB_PORT=${DB_PORT:-${MYSQL_PORT:-3306}}
    
    echo ""
    echo "🌐 管理界面配置"
    echo ""
    read -p "phpMyAdmin 端口 [${PHPMYADMIN_PORT:-9103}]: " PHPMYADMIN_PORT_INPUT
    PHPMYADMIN_PORT_INPUT=${PHPMYADMIN_PORT_INPUT:-${PHPMYADMIN_PORT:-9103}}
    
    read -p "监控端口 [${MYSQL_EXPORTER_PORT:-9104}]: " MONITOR_PORT
    MONITOR_PORT=${MONITOR_PORT:-${MYSQL_EXPORTER_PORT:-9104}}
    
    echo ""
    echo "⚡ 性能配置"
    echo ""
    read -p "InnoDB 缓冲池大小 [${MYSQL_INNODB_BUFFER_POOL_SIZE:-512M}]: " BUFFER_SIZE
    BUFFER_SIZE=${BUFFER_SIZE:-${MYSQL_INNODB_BUFFER_POOL_SIZE:-512M}}
    
    read -p "最大连接数 [${MYSQL_MAX_CONNECTIONS:-200}]: " MAX_CONN
    MAX_CONN=${MAX_CONN:-${MYSQL_MAX_CONNECTIONS:-200}}
    
    # 更新环境变量文件
    cat > "$ENV_FILE" << EOF
# ========================================================================
# 独立共享 MySQL 服务环境变量配置 (交互式生成)
# ========================================================================

# MySQL 基本配置
MYSQL_ROOT_PASSWORD=$ROOT_PASSWORD
MYSQL_PORT=$DB_PORT

# 管理面板配置
PHPMYADMIN_PORT=$PHPMYADMIN_PORT_INPUT

# 监控配置
MYSQL_EXPORTER_PORT=$MONITOR_PORT

# 性能配置
MYSQL_INNODB_BUFFER_POOL_SIZE=$BUFFER_SIZE
MYSQL_MAX_CONNECTIONS=$MAX_CONN

# 备份配置
BACKUP_RETENTION_DAYS=7
BACKUP_SCHEDULE="0 2 * * *"

# ========================================================================
# 项目数据库配置 (在初始化脚本中创建)
# ========================================================================

# Gallery 项目
GALLERY_DB_NAME=gallery_db
GALLERY_DB_USER=gallery_user
GALLERY_DB_PASSWORD=gallery_pass_2024

# AuraClass 项目
AURACLASS_DB_NAME=AuraClass_db
AURACLASS_DB_USER=AuraClass_user
AURACLASS_DB_PASSWORD=AuraClass_pass_2024

# 信息收集项目
CWCC_DB_NAME=cwcc_db
CWCC_DB_USER=cwcc_user
CWCC_DB_PASSWORD=cwcc_pass_2024

# CMS 项目
# CMS_DB_NAME=cms_db
# CMS_DB_USER=cms_user
# CMS_DB_PASSWORD=cms_pass_2024

# 博客项目
# BLOG_DB_NAME=blog_db
# BLOG_DB_USER=blog_user
# BLOG_DB_PASSWORD=blog_pass_2024

# 商城项目
# SHOP_DB_NAME=shop_db
# SHOP_DB_USER=shop_user
# SHOP_DB_PASSWORD=shop_pass_2024

# ========================================================================
# 系统用户
# ========================================================================

# 只读用户
READONLY_USER=readonly_user
READONLY_PASSWORD=readonly_pass_2024

# 备份用户
BACKUP_USER=backup_user
BACKUP_PASSWORD=backup_pass_2024

# 监控用户
MONITOR_USER=monitor_user
MONITOR_PASSWORD=monitor_pass_2024
EOF
    
    print_success "配置文件已更新: $ENV_FILE"
    
    echo ""
    read -p "是否立即启动服务？ (y/n) [y]: " START_NOW
    START_NOW=${START_NOW:-y}
    
    if [[ "$START_NOW" =~ ^[Yy]$ ]]; then
        start_service
    else
        print_info "配置完成，请使用 './mysql-service.sh start' 启动服务"
    fi
}

# 一键快速启动
quick_start() {
    print_header
    echo "🚀 一键快速启动"
    print_separator
    
    print_info "使用默认配置启动 MySQL 服务..."
    
    check_requirements
    init_environment
    
    # 启动服务
    print_info "启动服务..."
    if [ -f "$ENV_FILE" ]; then
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    else
        print_error "找不到配置文件: $ENV_FILE"
        print_error "请使用 './mysql-service.sh interactive-setup' 创建配置文件"
        exit 1
    fi
    
    print_info "等待服务启动..."
    sleep 10
    
    # 验证启动状态
    if docker ps | grep -q "$CONTAINER_NAME"; then
        print_success "MySQL 服务启动成功！"
        show_service_status
        show_connection_info
    else
        print_error "MySQL 服务启动失败"
        show_logs
        exit 1
    fi
}

# 启动服务
start_service() {
    print_separator
    print_info "启动独立共享 MySQL 服务..."
    
    check_requirements
    init_environment
    
    # 检查服务是否已运行
    if docker ps | grep -q "$CONTAINER_NAME"; then
        print_warning "MySQL 服务已经在运行"
        show_service_status
        return 0
    fi
    
    # 启动服务
    print_info "启动服务..."
    if [ -f "$ENV_FILE" ]; then
        docker-compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d
    else
        print_error "找不到配置文件: $ENV_FILE"
        print_error "请使用 './mysql-service.sh interactive-setup' 创建配置文件"
        exit 1
    fi
    
    print_info "等待服务启动..."
    sleep 30
    
    # 验证启动状态
    if docker ps | grep -q "$CONTAINER_NAME"; then
        print_success "MySQL 服务启动成功！"
        show_service_status
        show_connection_info
    else
        print_error "MySQL 服务启动失败"
        show_logs
        exit 1
    fi
}

# 停止服务
stop_service() {
    print_separator
    print_info "停止独立共享 MySQL 服务..."
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_warning "MySQL 服务未在运行"
        return 0
    fi
    
    docker-compose -f "$COMPOSE_FILE" down
    print_success "MySQL 服务已停止"
}

# 重启服务
restart_service() {
    print_separator
    print_info "重启独立共享 MySQL 服务..."
    
    stop_service
    sleep 5
    start_service
}

# 显示服务状态
show_service_status() {
    print_separator
    print_info "独立共享 MySQL 服务状态："
    
    echo ""
    print_info "容器状态："
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" | grep -E "(mysql|phpmyadmin|monitor)" || echo "没有找到相关容器"
    
    echo ""
    print_info "网络状态："
    if docker network ls | grep -q "$NETWORK_NAME"; then
        print_success "✅ 网络 $NETWORK_NAME 存在"
    else
        print_warning "❌ 网络 $NETWORK_NAME 不存在"
    fi
    
    echo ""
    print_info "数据卷状态："
    if docker volume ls | grep -q "shared_mysql_data"; then
        print_success "✅ 数据卷 shared_mysql_data 存在"
    else
        print_warning "❌ 数据卷 shared_mysql_data 不存在"
    fi
    
    echo ""
    print_info "健康检查："
    if docker inspect "$CONTAINER_NAME" &>/dev/null; then
        HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
        if [ "$HEALTH_STATUS" = "healthy" ]; then
            print_success "✅ MySQL 服务健康"
        else
            print_warning "⚠️ MySQL 服务状态: $HEALTH_STATUS"
        fi
    fi
}

# 显示连接信息
show_connection_info() {
    load_config
    
    print_separator
    print_info "MySQL 服务连接信息："
    
    echo ""
    echo "🔗 数据库连接:"
    echo "  主机: localhost"
    echo "  端口: $MYSQL_PORT"
    echo "  管理员: root / $MYSQL_ROOT_PASSWORD"
    
    echo ""
    echo "🗄️ 预配置项目数据库:"
    echo "  Gallery: $GALLERY_DB_NAME (用户: $GALLERY_DB_USER / $GALLERY_DB_PASSWORD)"
    echo "  AuraClass: $AURACLASS_DB_NAME (用户: $AURACLASS_DB_USER / $AURACLASS_DB_PASSWORD)"
    echo "  CWCC: $CWCC_DB_NAME (用户: $CWCC_DB_USER / $CWCC_DB_PASSWORD)"
    echo ""
    echo "💡 提示: 可以使用 './mysql-service.sh add-project <项目名>' 添加新的项目数据库"
    
    echo ""
    echo "🌐 管理界面:"
    echo "  phpMyAdmin: http://localhost:$PHPMYADMIN_PORT"
    echo "  MySQL 监控: http://localhost:$MYSQL_EXPORTER_PORT/metrics"
    
    echo ""
    echo "💻 连接示例:"
    echo "  mysql -h localhost -P $MYSQL_PORT -u $GALLERY_DB_USER -p $GALLERY_DB_NAME"
    echo "  mysql://$GALLERY_DB_USER:$GALLERY_DB_PASSWORD@localhost:$MYSQL_PORT/$GALLERY_DB_NAME"
    
    echo ""
    echo "🐳 Docker 网络连接 (容器内):"
    echo "  主机: mysql_db"
    echo "  端口: 3306"
    echo "  网络: shared-mysql-network"
}

# 查看服务日志
show_logs() {
    print_separator
    print_info "显示 MySQL 服务日志..."
    
    echo "选择要查看的服务日志："
    echo "1. MySQL 服务器"
    echo "2. phpMyAdmin"
    echo "3. MySQL 监控"
    echo "4. 所有服务"
    echo "5. 实时日志 (所有服务)"
    echo ""
    read -p "请选择 (1-5): " log_choice
    
    case "$log_choice" in
        1)
            docker logs --tail 50 "$CONTAINER_NAME" 2>/dev/null || echo "找不到 MySQL 容器"
            ;;
        2)
            docker logs --tail 50 mysql_admin_panel 2>/dev/null || echo "找不到 phpMyAdmin 容器"
            ;;
        3)
            docker logs --tail 50 mysql_monitor 2>/dev/null || echo "找不到监控容器"
            ;;
        4)
            print_info "显示所有服务日志..."
            docker-compose -f "$COMPOSE_FILE" logs --tail=50
            ;;
        5)
            print_info "显示实时日志 (按 Ctrl+C 退出)..."
            docker-compose -f "$COMPOSE_FILE" logs -f
            ;;
        *)
            print_error "无效选择"
            ;;
    esac
}

# 备份数据库
backup_databases() {
    print_separator
    print_info "备份所有项目数据库..."
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "MySQL 服务未运行，无法备份"
        exit 1
    fi
    
    BACKUP_DIR="mysql_backups"
    BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$BACKUP_DIR"
    
    load_config
    MYSQL_PASSWORD="$MYSQL_ROOT_PASSWORD"
    
    # 备份各个项目数据库
    DATABASES=("gallery_db" "AuraClass_db" "cwcc_db")
    
    for db in "${DATABASES[@]}"; do
        BACKUP_FILE="$BACKUP_DIR/${db}_backup_${BACKUP_DATE}.sql"
        print_info "备份数据库: $db"
        
        docker exec "$CONTAINER_NAME" mysqldump -u root -p"$MYSQL_PASSWORD" \
            --single-transaction --routines --triggers "$db" > "$BACKUP_FILE" 2>/dev/null || {
            print_warning "数据库 $db 可能不存在，跳过备份"
            rm -f "$BACKUP_FILE"
            continue
        }
        
        if [ -f "$BACKUP_FILE" ] && [ -s "$BACKUP_FILE" ]; then
            print_success "✅ $db 备份完成: $BACKUP_FILE"
        else
            print_warning "⚠️ $db 备份失败或文件为空"
        fi
    done
    
    # 创建完整备份
    FULL_BACKUP_FILE="$BACKUP_DIR/full_backup_${BACKUP_DATE}.sql"
    print_info "创建完整备份..."
    
    docker exec "$CONTAINER_NAME" mysqldump -u root -p"$MYSQL_PASSWORD" \
        --all-databases --single-transaction --routines --triggers > "$FULL_BACKUP_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "✅ 完整备份完成: $FULL_BACKUP_FILE"
        ls -lh "$BACKUP_DIR"/*"$BACKUP_DATE"*
    else
        print_error "❌ 完整备份失败"
    fi
}

# 连接到 MySQL
connect_mysql() {
    print_separator
    print_info "连接到 MySQL 服务..."
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "MySQL 服务未运行"
        exit 1
    fi
    
    load_config
    MYSQL_PASSWORD="$MYSQL_ROOT_PASSWORD"
    
    echo "选择连接方式："
    echo "1. root 用户 (管理员)"
    echo "2. 指定用户"
    echo ""
    read -p "请选择 (1-2): " connect_choice
    
    case "$connect_choice" in
        1)
            print_info "使用 root 用户连接到 MySQL..."
            docker exec -it "$CONTAINER_NAME" mysql -u root -p"$MYSQL_PASSWORD"
            ;;
        2)
            read -p "请输入用户名: " username
            read -p "请输入数据库名 (可选): " database
            if [ -n "$database" ]; then
                docker exec -it "$CONTAINER_NAME" mysql -u "$username" -p "$database"
            else
                docker exec -it "$CONTAINER_NAME" mysql -u "$username" -p
            fi
            ;;
        *)
            print_error "无效选择"
            ;;
    esac
}

# 添加新项目数据库
add_project() {
    local project_name="$1"
    
    if [ -z "$project_name" ]; then
        print_error "请提供项目名称"
        echo "使用方法: $0 add-project <项目名称>"
        exit 1
    fi
    
    print_separator
    print_info "为项目 '$project_name' 创建数据库..."
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "MySQL 服务未运行"
        exit 1
    fi
    
    load_config
    MYSQL_PASSWORD="$MYSQL_ROOT_PASSWORD"
    
    # 生成数据库和用户名
    DB_NAME="${project_name}_db"
    DB_USER="${project_name}_user"
    DB_PASS="${project_name}_pass_2024"
    
    # 创建数据库和用户
    print_info "创建数据库: $DB_NAME"
    print_info "创建用户: $DB_USER"
    
    docker exec -i "$CONTAINER_NAME" mysql -u root -p"$MYSQL_PASSWORD" <<-EOSQL
        CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` 
        CHARACTER SET utf8mb4 
        COLLATE utf8mb4_unicode_ci;
        
        CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
        GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
        FLUSH PRIVILEGES;
        
        SELECT 'Database and user created successfully!' AS Result;
EOSQL
    
    if [ $? -eq 0 ]; then
        print_success "✅ 项目 '$project_name' 数据库创建成功"
        echo ""
        echo "连接信息:"
        echo "  数据库: $DB_NAME"
        echo "  用户名: $DB_USER"
        echo "  密码: $DB_PASS"
        echo "  连接字符串: mysql://$DB_USER:$DB_PASS@localhost:3306/$DB_NAME"
    else
        print_error "❌ 数据库创建失败"
    fi
}

# 列出所有数据库
list_databases() {
    print_separator
    print_info "列出所有数据库..."
    
    if ! docker ps | grep -q "$CONTAINER_NAME"; then
        print_error "MySQL 服务未运行"
        exit 1
    fi
    
    load_config
    MYSQL_PASSWORD="$MYSQL_ROOT_PASSWORD"
    
    print_info "数据库列表："
    docker exec "$CONTAINER_NAME" mysql -u root -p"$MYSQL_PASSWORD" -e "SHOW DATABASES;" | grep -v "information_schema\|performance_schema\|mysql\|sys\|Database"
    
    echo ""
    print_info "用户列表："
    docker exec "$CONTAINER_NAME" mysql -u root -p"$MYSQL_PASSWORD" -e "SELECT User, Host FROM mysql.user WHERE User NOT IN ('root', 'mysql.sys', 'mysql.session', 'mysql.infoschema');"
}

# 清理服务
cleanup_service() {
    print_separator
    print_warning "清理独立共享 MySQL 服务..."
    
    echo "⚠️ 这将删除所有数据和容器！"
    echo "包括："
    echo "  - 所有数据库数据"
    echo "  - 所有容器和镜像"
    echo "  - 数据卷和网络"
    echo "  - 配置文件和日志"
    echo ""
    read -p "确认执行清理操作？(输入 'yes' 确认): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "清理操作已取消"
        return 0
    fi
    
    # 停止并删除容器
    docker-compose -f "$COMPOSE_FILE" down --volumes --remove-orphans
    
    # 删除数据卷
    docker volume rm shared_mysql_data 2>/dev/null || true
    
    # 删除网络
    docker network rm "$NETWORK_NAME" 2>/dev/null || true
    
    # 删除数据目录
    if [ -d "mysql_data" ]; then
        rm -rf mysql_data
        print_info "删除数据目录: mysql_data"
    fi
    
    print_success "服务清理完成"
}

# 交互式菜单
show_menu() {
    print_header
    echo "请选择操作："
    echo ""
    echo "🚀 快速操作"
    echo "  1. 一键快速启动"
    echo "  2. 交互式配置启动"
    echo "  3. 启动服务"
    echo "  4. 停止服务"
    echo "  5. 重启服务"
    echo ""
    echo "📊 管理操作"
    echo "  6. 查看服务状态"
    echo "  7. 查看服务日志"
    echo "  8. 连接到 MySQL"
    echo "  9. 列出所有数据库"
    echo ""
    echo "🔧 高级操作"
    echo "  10. 添加新项目数据库"
    echo "  11. 备份所有数据库"
    echo "  12. 清理服务和数据"
    echo ""
    echo "  0. 退出"
    echo ""
    print_separator
    read -p "请选择操作 (0-12): " choice
    
    case "$choice" in
        1) quick_start ;;
        2) interactive_setup ;;
        3) start_service ;;
        4) stop_service ;;
        5) restart_service ;;
        6) 
            check_requirements
            show_service_status
            if docker ps | grep -q "$CONTAINER_NAME"; then
                show_connection_info
            fi
            ;;
        7) show_logs ;;
        8) connect_mysql ;;
        9) list_databases ;;
        10) 
            read -p "请输入项目名称: " project_name
            add_project "$project_name"
            ;;
        11) backup_databases ;;
        12) cleanup_service ;;
        0) 
            print_info "感谢使用 MySQL 服务管理系统！"
            exit 0
            ;;
        *)
            print_error "无效选择，请重试"
            sleep 2
            show_menu
            ;;
    esac
    
    echo ""
    read -p "按回车键继续..."
    show_menu
}

# 主函数
main() {
    case "${1:-}" in
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        "status")
            check_requirements
            show_service_status
            if docker ps | grep -q "$CONTAINER_NAME"; then
                show_connection_info
            fi
            ;;
        "logs")
            show_logs
            ;;
        "backup")
            backup_databases
            ;;
        "connect")
            connect_mysql
            ;;
        "add-project")
            add_project "$2"
            ;;
        "list-dbs")
            list_databases
            ;;
        "cleanup")
            cleanup_service
            ;;
        "quick-start")
            quick_start
            ;;
        "interactive-setup")
            interactive_setup
            ;;
        "")
            show_menu
            ;;
        *)
            print_info "独立共享 MySQL 服务管理脚本"
            print_separator
            echo "使用方法: $0 [命令]"
            echo ""
            echo "🚀 快速命令:"
            echo "  无参数                  - 显示交互式菜单"
            echo "  quick-start            - 一键快速启动"
            echo "  interactive-setup      - 交互式配置启动"
            echo ""
            echo "📊 基本命令:"
            echo "  start                  - 启动服务"
            echo "  stop                   - 停止服务"
            echo "  restart                - 重启服务"
            echo "  status                 - 查看服务状态"
            echo "  logs                   - 查看服务日志"
            echo ""
            echo "🔧 管理命令:"
            echo "  connect                - 连接到 MySQL"
            echo "  add-project <name>     - 添加新项目数据库"
            echo "  list-dbs               - 列出所有数据库"
            echo "  backup                 - 备份所有数据库"
            echo "  cleanup                - 清理服务和数据"
            echo ""
            echo "示例:"
            echo "  $0                     # 显示交互式菜单"
            echo "  $0 quick-start         # 一键启动"
            echo "  $0 add-project myapp   # 为 myapp 项目创建数据库"
            echo "  $0 backup              # 备份所有数据库"
            echo ""
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 