-- V6: 数据完整性约束增强

-- 1. 用户角色必须存在于角色字典
ALTER TABLE users
ADD CONSTRAINT fk_users_role
FOREIGN KEY (role_code)
REFERENCES roles(code);

-- 2. 支持团队与部门的复合外键
ALTER TABLE teams
ADD CONSTRAINT uq_teams_id_department
UNIQUE (id, department_id);

-- 3. 用户的团队必须属于其指定部门
ALTER TABLE users
ADD CONSTRAINT fk_users_team_department
FOREIGN KEY (team_id, department_id)
REFERENCES teams(id, department_id);

-- 4. 支持父评论与所属日志的复合外键
ALTER TABLE log_comments
ADD CONSTRAINT uq_log_comments_id_log
UNIQUE (id, log_id);

-- 5. 评论回复只能引用同一日志的父评论
ALTER TABLE log_comments
ADD CONSTRAINT fk_log_comments_parent_same_log
FOREIGN KEY (parent_id, log_id)
REFERENCES log_comments(id, log_id);

-- 6. 已提交日志必须有提交时间，草稿不能有提交时间
ALTER TABLE work_logs
ADD CONSTRAINT chk_work_logs_submission_consistency
CHECK (
    (status = 'DRAFT' AND submitted_at IS NULL)
    OR
    (status = 'SUBMITTED' AND submitted_at IS NOT NULL)
);