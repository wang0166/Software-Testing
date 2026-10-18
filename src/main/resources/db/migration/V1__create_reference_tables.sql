-- 基础引用数据：角色、权限、角色权限映射与系统配置

CREATE TABLE roles (
  code        VARCHAR(32) PRIMARY KEY,
  name        VARCHAR(64) NOT NULL,
  description VARCHAR(255)
);

CREATE TABLE permissions (
  code        VARCHAR(64) PRIMARY KEY,
  name        VARCHAR(64) NOT NULL,
  module      VARCHAR(32) NOT NULL,
  description VARCHAR(255)
);

CREATE TABLE role_permissions (
  role_code       VARCHAR(32) NOT NULL REFERENCES roles(code) ON DELETE CASCADE,
  permission_code VARCHAR(64) NOT NULL REFERENCES permissions(code) ON DELETE CASCADE,
  PRIMARY KEY (role_code, permission_code)
);

CREATE TABLE system_configs (
  key         VARCHAR(64) PRIMARY KEY,
  value       VARCHAR(255) NOT NULL,
  description VARCHAR(255),
  updated_by  BIGINT,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO roles (code, name, description) VALUES
('EMPLOYEE', '员工', '填写并查看个人日志'),
('TEAM_LEADER', '团队长', '查看本团队日志并点评直接下级'),
('DEPT_MANAGER', '部门老总', '查看本部门日志并点评团队长'),
('FOUNDER', '创始人', '查看全公司日志并点评部门老总'),
('ADMIN', '系统管理员', '用户/组织/角色/配置管理与只读查看');

INSERT INTO permissions (code, name, module) VALUES
('user:manage', '用户管理', 'admin'),
('org:manage', '组织管理', 'admin'),
('role:manage', '角色权限管理', 'admin'),
('config:manage', '系统配置管理', 'admin'),
('audit:read', '审计查询', 'admin'),
('log:write', '日志填写', 'log'),
('log:read', '日志查看', 'log'),
('comment:write', '点评与回复', 'comment'),
('stats:read', '统计查看', 'stats'),
('task:dispatch', '任务派发与检查', 'task'),
('task:execute', '任务接收与执行', 'task'),
('task:self', '自建任务', 'task'),
('content:read', '公司展示内容读取', 'content'),
('company-matter:manage', '公司十大重要事项维护', 'content'),
('company-task:manage', '公司十大重要任务维护', 'content');

INSERT INTO role_permissions (role_code, permission_code) VALUES
('EMPLOYEE', 'log:write'), ('EMPLOYEE', 'log:read'), ('EMPLOYEE', 'comment:write'),
('EMPLOYEE', 'stats:read'), ('EMPLOYEE', 'task:execute'), ('EMPLOYEE', 'task:self'),
('EMPLOYEE', 'content:read'),
('TEAM_LEADER', 'log:write'), ('TEAM_LEADER', 'log:read'), ('TEAM_LEADER', 'comment:write'),
('TEAM_LEADER', 'stats:read'), ('TEAM_LEADER', 'task:dispatch'), ('TEAM_LEADER', 'task:execute'),
('TEAM_LEADER', 'task:self'), ('TEAM_LEADER', 'content:read'),
('DEPT_MANAGER', 'log:write'), ('DEPT_MANAGER', 'log:read'), ('DEPT_MANAGER', 'comment:write'),
('DEPT_MANAGER', 'stats:read'), ('DEPT_MANAGER', 'task:dispatch'), ('DEPT_MANAGER', 'task:execute'),
('DEPT_MANAGER', 'task:self'), ('DEPT_MANAGER', 'content:read'),
('FOUNDER', 'log:write'), ('FOUNDER', 'log:read'), ('FOUNDER', 'comment:write'),
('FOUNDER', 'stats:read'), ('FOUNDER', 'task:dispatch'), ('FOUNDER', 'task:execute'),
('FOUNDER', 'task:self'), ('FOUNDER', 'content:read'), ('FOUNDER', 'company-task:manage'),
('ADMIN', 'user:manage'), ('ADMIN', 'org:manage'), ('ADMIN', 'role:manage'),
('ADMIN', 'config:manage'), ('ADMIN', 'audit:read'), ('ADMIN', 'log:read'),
('ADMIN', 'stats:read'), ('ADMIN', 'content:read'), ('ADMIN', 'company-matter:manage');

INSERT INTO system_configs (key, value, description) VALUES
('log_deadline', '22:00', '日志提交截止时间（HH:mm，Asia/Shanghai）'),
('login_max_failures', '5', '连续登录失败锁定阈值'),
('login_lock_minutes', '15', '登录失败锁定分钟数'),
('access_token_ttl_minutes', '120', '访问令牌有效期（分钟）'),
('refresh_token_ttl_days', '7', '刷新令牌有效期（天）');
