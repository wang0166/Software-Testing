-- 演示数据：为四类业务角色各预置一个测试账号，便于联调与验收
-- 统一密码：123456（BCrypt 哈希与 AdminInitializer 使用同一编码器生成）
-- 脚本幂等：已存在的组织/账号会被跳过，可安全地在已有数据的库上执行

-- 公司
INSERT INTO companies (name)
SELECT 'Pandora'
WHERE NOT EXISTS (SELECT 1 FROM companies);

-- 部门
INSERT INTO departments (company_id, name)
SELECT c.id, '研发部'
FROM (SELECT id FROM companies ORDER BY id LIMIT 1) AS c
WHERE NOT EXISTS (SELECT 1 FROM departments WHERE name = '研发部');

-- 团队
INSERT INTO teams (department_id, name)
SELECT d.id, '研发一组'
FROM (SELECT id FROM departments WHERE name = '研发部' ORDER BY id LIMIT 1) AS d
WHERE NOT EXISTS (SELECT 1 FROM teams WHERE name = '研发一组');

-- 四类角色账号（role_code 与组织归属需满足 chk_users_org_alignment）
INSERT INTO users (username, password_hash, real_name, role_code, department_id, team_id, status)
VALUES
    ('founder',  '$2a$10$Se8wRmbvNl.bv.m6M7S9ju2Fgigg2DXJ.CoAVAbumN2dZkRDwzOji', '张创始', 'FOUNDER',      NULL, NULL, 'ACTIVE'),
    ('deptmgr',  '$2a$10$Se8wRmbvNl.bv.m6M7S9ju2Fgigg2DXJ.CoAVAbumN2dZkRDwzOji', '李部门', 'DEPT_MANAGER', (SELECT id FROM departments WHERE name = '研发部' ORDER BY id LIMIT 1), NULL, 'ACTIVE'),
    ('teamlead', '$2a$10$Se8wRmbvNl.bv.m6M7S9ju2Fgigg2DXJ.CoAVAbumN2dZkRDwzOji', '王组长', 'TEAM_LEADER',  (SELECT id FROM departments WHERE name = '研发部' ORDER BY id LIMIT 1), (SELECT id FROM teams WHERE name = '研发一组' ORDER BY id LIMIT 1), 'ACTIVE'),
    ('employee', '$2a$10$Se8wRmbvNl.bv.m6M7S9ju2Fgigg2DXJ.CoAVAbumN2dZkRDwzOji', '赵员工', 'EMPLOYEE',     (SELECT id FROM departments WHERE name = '研发部' ORDER BY id LIMIT 1), (SELECT id FROM teams WHERE name = '研发一组' ORDER BY id LIMIT 1), 'ACTIVE')
ON CONFLICT (username) DO NOTHING;

-- 建立公司/部门/团队的负责人归属（已设置或该用户已担任其他负责人时跳过）
UPDATE companies
SET founder_id = (SELECT id FROM users WHERE username = 'founder')
WHERE founder_id IS NULL
  AND id IN (SELECT company_id FROM departments WHERE name = '研发部')
  AND NOT EXISTS (SELECT 1 FROM companies c WHERE c.founder_id = (SELECT id FROM users WHERE username = 'founder'));

UPDATE departments
SET manager_id = (SELECT id FROM users WHERE username = 'deptmgr')
WHERE manager_id IS NULL
  AND name = '研发部'
  AND NOT EXISTS (SELECT 1 FROM departments d WHERE d.manager_id = (SELECT id FROM users WHERE username = 'deptmgr'));

UPDATE teams
SET leader_id = (SELECT id FROM users WHERE username = 'teamlead')
WHERE leader_id IS NULL
  AND name = '研发一组'
  AND NOT EXISTS (SELECT 1 FROM teams t WHERE t.leader_id = (SELECT id FROM users WHERE username = 'teamlead'));
