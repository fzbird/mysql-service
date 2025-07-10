-- ========================================================================
-- 共享 MySQL 服务 - 多项目数据库初始化
-- ========================================================================
-- 
-- 此脚本在 MySQL 容器启动时自动执行，创建多个项目所需的数据库和用户
-- 每个项目拥有独立的数据库和专用用户，确保数据隔离和安全性
--
-- ========================================================================

-- 设置字符集
SET NAMES utf8mb4;
SET CHARACTER SET utf8mb4;

-- ========================================================================
-- Gallery 项目数据库
-- ========================================================================

-- 创建 Gallery 数据库
CREATE DATABASE IF NOT EXISTS gallery_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- 创建 Gallery 用户
CREATE USER IF NOT EXISTS 'gallery_user'@'%' IDENTIFIED BY 'gallery_pass_2024';

-- 授权 Gallery 用户访问 gallery_db
GRANT ALL PRIVILEGES ON gallery_db.* TO 'gallery_user'@'%';

-- ========================================================================
-- AuraClass 项目数据库
-- ========================================================================

-- 创建 AuraClass 数据库
CREATE DATABASE IF NOT EXISTS AuraClass_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- 创建 AuraClass 用户
CREATE USER IF NOT EXISTS 'AuraClass_user'@'%' IDENTIFIED BY 'AuraClass_pass_2024';

-- 授权 AuraClass 用户访问 AuraClass_db
GRANT ALL PRIVILEGES ON AuraClass_db.* TO 'AuraClass_user'@'%';

-- ========================================================================
-- CWCC 项目数据库
-- ========================================================================

-- 创建 CWCC 数据库
CREATE DATABASE IF NOT EXISTS cwcc_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

-- 创建 CWCC 用户
CREATE USER IF NOT EXISTS 'cwcc_user'@'%' IDENTIFIED BY 'cwcc_pass_2024';

-- 授权 CWCC 用户访问 cwcc_db
GRANT ALL PRIVILEGES ON cwcc_db.* TO 'cwcc_user'@'%';

-- ========================================================================
-- 通用只读用户 (用于报表和分析)
-- ========================================================================

-- 创建只读用户
CREATE USER IF NOT EXISTS 'readonly_user'@'%' IDENTIFIED BY 'readonly_pass_2024';

-- 授权只读用户查看所有数据库
GRANT SELECT ON *.* TO 'readonly_user'@'%';

-- ========================================================================
-- 备份用户 (用于数据备份)
-- ========================================================================

-- 创建备份用户
CREATE USER IF NOT EXISTS 'backup_user'@'%' IDENTIFIED BY 'backup_pass_2024';

-- 授权备份用户
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON *.* TO 'backup_user'@'%';

-- ========================================================================
-- 监控用户 (用于性能监控)
-- ========================================================================

-- 创建监控用户
CREATE USER IF NOT EXISTS 'monitor_user'@'%' IDENTIFIED BY 'monitor_pass_2024';

-- 授权监控用户
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'monitor_user'@'%';

-- 刷新权限
FLUSH PRIVILEGES;

-- 显示创建的数据库
SHOW DATABASES;

-- 显示创建的用户
SELECT User, Host FROM mysql.user WHERE User NOT IN ('root', 'mysql.sys', 'mysql.session', 'mysql.infoschema');

-- 输出成功信息
SELECT 'Multi-project database initialization completed successfully!' AS Message; 