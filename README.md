# 独立共享 MySQL 服务

<div align="center">

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=flat&logo=docker&logoColor=white)](https://www.docker.com/)
[![MySQL](https://img.shields.io/badge/mysql-%2300f.svg?style=flat&logo=mysql&logoColor=white)](https://www.mysql.com/)
[![phpMyAdmin](https://img.shields.io/badge/phpmyadmin-%236C78AF.svg?style=flat&logo=phpmyadmin&logoColor=white)](https://www.phpmyadmin.net/)
[![GitHub issues](https://img.shields.io/github/issues/fzbird/mysql-service)](https://github.com/fzbird/mysql-service/issues)
[![GitHub stars](https://img.shields.io/github/stars/fzbird/mysql-service)](https://github.com/fzbird/mysql-service/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/fzbird/mysql-service)](https://github.com/fzbird/mysql-service/network)

**一个基于 Docker 的独立共享 MySQL 数据库服务，支持多项目共享使用，具备完善的管理界面和监控功能。**

[快速开始](#-快速开始) • [功能特性](#-项目简介) • [文档](#-安装与配置) • [贡献](#-贡献指南)

![MySQL](https://img.shields.io/badge/mysql-%2300f.svg?style=for-the-badge&logo=mysql&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![phpMyAdmin](https://img.shields.io/badge/phpmyadmin-%236C78AF.svg?style=for-the-badge&logo=phpmyadmin&logoColor=white)

</div>

## 🚀 项目简介

这是一个完全独立的 MySQL 数据库服务，专为多项目共享使用而设计。通过 Docker 容器化部署，提供：

- **MySQL 8.0** 数据库服务
- **phpMyAdmin** 可视化管理界面
- **MySQL Exporter** 性能监控
- **自动化脚本** 一键部署和管理
- **多项目支持** 独立数据库和用户隔离
- **数据持久化** 完整的数据备份和恢复

## 📋 目录结构

```
mysql-service/
├── README.md                    # 项目文档
├── docker-compose.mysql.yml     # Docker 编排配置
├── mysql.env                    # 环境变量配置
├── mysql-service.sh             # 服务管理脚本
├── config/
│   ├── mysql.cnf               # MySQL 配置文件
│   └── mysql-exporter.cnf      # 监控配置文件
├── init/
│   └── 01-create-databases.sql # 数据库初始化脚本
├── logs/                       # 日志目录
├── mysql_data/                 # 数据持久化目录
└── mysql_backups/              # 备份文件目录
```

## ⚡ 快速开始

### 方式一：一键快速启动（推荐）

```bash
# 克隆项目
git clone <repository-url>
cd mysql-service

# 给脚本添加执行权限
chmod +x mysql-service.sh

# 一键启动（使用默认配置）
./mysql-service.sh quick-start
```

### 方式二：交互式配置启动

```bash
# 交互式配置并启动
./mysql-service.sh interactive-setup
```

### 方式三：传统命令行启动

```bash
# 启动服务
./mysql-service.sh start

# 查看状态
./mysql-service.sh status
```

## 🔧 系统要求

- **Docker**: 20.10.0 或更高版本
- **Docker Compose**: 1.29.0 或更高版本
- **操作系统**: Linux, macOS, Windows (WSL2)
- **内存**: 至少 2GB 可用内存
- **磁盘**: 至少 5GB 可用空间

## 🛠️ 安装与配置

### 1. 环境准备

```bash
# 检查 Docker 版本
docker --version
docker-compose --version

# 确保 Docker 服务正在运行
docker info
```

### 2. 获取项目

```bash
git clone <repository-url>
cd mysql-service
chmod +x mysql-service.sh
```

### 3. 配置选项

#### 默认配置
项目提供了开箱即用的默认配置：

```bash
# 默认端口配置
MySQL: 3306
phpMyAdmin: 9103
监控端口: 9104

# 默认密码
root 密码: mysql_root_password_2024
```

#### 自定义配置
编辑 `mysql.env` 文件进行自定义配置：

```bash
# 基本配置
MYSQL_ROOT_PASSWORD=your_secure_password
MYSQL_PORT=3306
PHPMYADMIN_PORT=9103

# 性能配置
MYSQL_INNODB_BUFFER_POOL_SIZE=512M
MYSQL_MAX_CONNECTIONS=200
```

## 🎯 核心功能

### 1. 服务管理

```bash
# 启动服务
./mysql-service.sh start

# 停止服务
./mysql-service.sh stop

# 重启服务
./mysql-service.sh restart

# 查看状态
./mysql-service.sh status

# 查看日志
./mysql-service.sh logs
```

### 2. 数据库管理

```bash
# 列出所有数据库
./mysql-service.sh list-dbs

# 添加新项目数据库
./mysql-service.sh add-project myproject

# 连接到 MySQL
./mysql-service.sh connect

# 备份所有数据库
./mysql-service.sh backup
```

### 3. 交互式菜单

```bash
# 显示交互式菜单
./mysql-service.sh
```

## 🗄️ 预配置数据库

服务启动后，会自动创建以下数据库和用户：

| 项目名称 | 数据库名 | 用户名 | 密码 |
|---------|----------|--------|------|
| Gallery | gallery_db | gallery_user | gallery_pass_2024 |
| AuraClass | AuraClass_db | AuraClass_user | AuraClass_pass_2024 |
| CWCC | cwcc_db | cwcc_user | cwcc_pass_2024 |

> 💡 **提示**: 使用 `./mysql-service.sh add-project <项目名>` 可以轻松添加新的项目数据库。

### 系统用户

| 用户类型 | 用户名 | 密码 | 权限 |
|---------|--------|------|------|
| 只读用户 | readonly_user | readonly_pass_2024 | SELECT |
| 备份用户 | backup_user | backup_pass_2024 | SELECT, LOCK TABLES |
| 监控用户 | monitor_user | monitor_pass_2024 | PROCESS, REPLICATION CLIENT |

## 🌐 访问界面

### phpMyAdmin 管理界面
- **地址**: http://localhost:9103
- **用户**: root
- **密码**: mysql_root_password_2024 (默认)

### MySQL 监控指标
- **地址**: http://localhost:9104/metrics
- **说明**: Prometheus 格式的监控指标

## 🔌 连接方式

### 1. 本地连接
```bash
# 命令行连接
mysql -h localhost -P 3306 -u root -p

# 应用连接字符串
mysql://root:mysql_root_password_2024@localhost:3306/database_name
```

### 2. Docker 网络连接
```bash
# 容器内连接
mysql -h mysql_db -P 3306 -u root -p

# 应用连接字符串
mysql://root:mysql_root_password_2024@mysql_db:3306/database_name
```

### 3. 项目连接示例

#### Python (FastAPI)
```python
import asyncio
import aiomysql

async def create_connection():
    connection = await aiomysql.connect(
        host='localhost',  # 或 'mysql_db' (容器内)
        port=3306,
        user='gallery_user',
        password='gallery_pass_2024',
        db='gallery_db',
        charset='utf8mb4',
        autocommit=True
    )
    return connection
```

#### Node.js
```javascript
const mysql = require('mysql2/promise');

const connection = await mysql.createConnection({
    host: 'localhost',  // 或 'mysql_db' (容器内)
    port: 3306,
    user: 'gallery_user',
    password: 'gallery_pass_2024',
    database: 'gallery_db',
    charset: 'utf8mb4'
});
```

#### Java (Spring Boot)
```properties
spring.datasource.url=jdbc:mysql://localhost:3306/gallery_db
spring.datasource.username=gallery_user
spring.datasource.password=gallery_pass_2024
spring.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
```

## 📊 监控与日志

### 1. 容器状态监控
```bash
# 查看容器状态
docker ps

# 查看资源使用情况
docker stats
```

### 2. 日志查看
```bash
# 查看 MySQL 日志
docker logs mysql_db

# 查看 phpMyAdmin 日志
docker logs mysql_admin_panel

# 查看所有服务日志
docker-compose -f docker-compose.mysql.yml logs
```

### 3. 性能监控
- 访问 http://localhost:9104/metrics 查看详细的性能指标
- 可以集成 Prometheus + Grafana 进行可视化监控

## 💾 数据备份与恢复

### 1. 自动备份
```bash
# 备份所有数据库
./mysql-service.sh backup

# 备份文件位置
ls -la mysql_backups/
```

### 2. 手动备份
```bash
# 备份单个数据库
docker exec mysql_db mysqldump -u root -p gallery_db > gallery_backup.sql

# 备份所有数据库
docker exec mysql_db mysqldump -u root -p --all-databases > full_backup.sql
```

### 3. 数据恢复
```bash
# 恢复单个数据库
docker exec -i mysql_db mysql -u root -p gallery_db < gallery_backup.sql

# 恢复所有数据库
docker exec -i mysql_db mysql -u root -p < full_backup.sql
```

## 🔧 高级配置

### 1. 性能优化
编辑 `config/mysql.cnf` 文件：

```ini
[mysqld]
# 内存配置
innodb-buffer-pool-size = 1G
innodb-buffer-pool-instances = 4

# 连接配置
max-connections = 500
max-connect-errors = 10000

# 查询缓存
query-cache-size = 256M
query-cache-type = 1
```

### 2. 安全配置
```bash
# 修改默认密码
docker exec -it mysql_db mysql -u root -p -e "ALTER USER 'root'@'%' IDENTIFIED BY 'new_secure_password';"

# 创建SSL证书
docker exec mysql_db mysql_ssl_rsa_setup
```

### 3. 网络配置
```yaml
# docker-compose.mysql.yml
networks:
  shared-mysql-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

## 📚 故障排除

### 1. 常见问题

#### 端口冲突
```bash
# 检查端口占用
netstat -tulpn | grep 3306

# 修改端口配置
vim mysql.env
# 更改 MYSQL_PORT=3307
```

#### 权限问题
```bash
# 修复数据目录权限
sudo chown -R 999:999 mysql_data/
sudo chmod -R 755 mysql_data/
```

#### 内存不足
```bash
# 调整内存配置
vim mysql.env
# 更改 MYSQL_INNODB_BUFFER_POOL_SIZE=256M
```

### 2. 日志诊断
```bash
# 查看错误日志
docker logs mysql_db | grep ERROR

# 查看慢查询日志
docker exec mysql_db tail -f /var/log/mysql/mysql-slow.log
```

### 3. 完全重置
```bash
# 清理所有数据和配置
./mysql-service.sh cleanup

# 重新初始化
./mysql-service.sh quick-start
```

## 🚀 部署建议

### 1. 开发环境
```bash
# 使用默认配置快速启动
./mysql-service.sh quick-start
```

### 2. 生产环境
```bash
# 1. 自定义安全配置
./mysql-service.sh interactive-setup

# 2. 配置SSL证书
# 3. 设置防火墙规则
# 4. 配置定期备份
```

### 3. 集群部署
```bash
# 配置主从复制
# 设置负载均衡
# 配置高可用
```

## 📝 更新日志

### v2.0.0 (2024-01-XX)
- ✨ 新增交互式配置功能
- 🔧 完善监控和日志功能
- 🛠️ 重构服务管理脚本
- 📚 完善文档和示例

### v1.0.0 (2024-01-XX)
- 🎉 初始版本发布
- 🐳 Docker 容器化部署
- 🗄️ 多项目数据库支持
- 🌐 phpMyAdmin 管理界面

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 支持与反馈

如果您在使用过程中遇到问题或有建议，请通过以下方式联系：

- 📧 邮箱: 36178831@qq.com
- 💬 Issue: [GitHub Issues](https://github.com/your-username/mysql-service/issues)
- 📝 文档: [项目文档](https://your-docs-url.com)

---

<div align="center">
⭐ 如果这个项目对您有帮助，请给它一个星标！
</div> # mysql-service
