-- V9: 星海数字科技有限公司展示组织数据
-- 目标：建立可用于完整业务演示的 18 人组织结构。
-- 说明：
--   1. 保留 V5 的 Pandora 四个联调账号，不修改、不删除。
--   2. 本迁移创建独立公司“星海数字科技有限公司”。
--   3. 所有展示账号初始密码统一为 123456（沿用 V5 中已验证的 BCrypt 哈希）。
--   4. 业务数据（事项、任务、日志、评论、审核、个人任务）将在 V10 中创建。

-- ---------------------------------------------------------------------------
-- 1. 公司
-- ---------------------------------------------------------------------------

INSERT INTO companies (name)
SELECT '星海数字科技有限公司'
WHERE NOT EXISTS (
    SELECT 1 FROM companies WHERE name = '星海数字科技有限公司'
);

-- ---------------------------------------------------------------------------
-- 2. 部门
-- ---------------------------------------------------------------------------

INSERT INTO departments (company_id, name, description)
SELECT c.id, v.name, v.description
FROM companies c
CROSS JOIN (
    VALUES
      ('产品研发部', '负责产品规划、平台研发、体验设计、质量保障与技术演进。'),
      ('项目交付部', '负责客户项目实施、上线交付、客户成功与持续服务。'),
      ('市场运营部', '负责市场拓展、大客户经营、商务运营与品牌推广。')
) AS v(name, description)
WHERE c.name = '星海数字科技有限公司'
  AND NOT EXISTS (
      SELECT 1
      FROM departments d
      WHERE d.company_id = c.id
        AND d.name = v.name
  );

-- ---------------------------------------------------------------------------
-- 3. 团队
-- ---------------------------------------------------------------------------

INSERT INTO teams (department_id, name, description)
SELECT d.id, v.team_name, v.description
FROM departments d
JOIN companies c ON c.id = d.company_id
JOIN (
    VALUES
      ('产品研发部', '平台研发组', '负责核心后端服务、数据接口、平台能力与质量保障。'),
      ('产品研发部', '产品设计组', '负责产品规划、需求设计、交互体验与视觉设计。'),
      ('项目交付部', '华北交付组', '负责华北区域客户项目实施、联调、上线与验收。'),
      ('项目交付部', '客户成功组', '负责客户使用跟进、问题闭环、续约支持与价值运营。'),
      ('市场运营部', '商务运营组', '负责重点客户拓展、商务方案、市场活动与经营支持。')
) AS v(dept_name, team_name, description)
  ON v.dept_name = d.name
WHERE c.name = '星海数字科技有限公司'
  AND NOT EXISTS (
      SELECT 1
      FROM teams t
      WHERE t.department_id = d.id
        AND t.name = v.team_name
  );

-- ---------------------------------------------------------------------------
-- 4. 18 名核心展示人员
-- ---------------------------------------------------------------------------
-- 用户名采用稳定、易于答辩登录的英文标识。
-- FOUNDER / DEPT_MANAGER 不属于 team；TEAM_LEADER / EMPLOYEE 必须同时属于 department 和 team。

INSERT INTO users
    (username, password_hash, real_name, role_code, department_id, team_id, status, gender)
SELECT
    v.username,
    '$2a$10$Se8wRmbvNl.bv.m6M7S9ju2Fgigg2DXJ.CoAVAbumN2dZkRDwzOji',
    v.real_name,
    v.role_code,
    CASE
      WHEN v.dept_name IS NULL THEN NULL
      ELSE (
        SELECT d.id
        FROM departments d
        JOIN companies c ON c.id = d.company_id
        WHERE c.name = '星海数字科技有限公司'
          AND d.name = v.dept_name
        LIMIT 1
      )
    END,
    CASE
      WHEN v.team_name IS NULL THEN NULL
      ELSE (
        SELECT t.id
        FROM teams t
        JOIN departments d ON d.id = t.department_id
        JOIN companies c ON c.id = d.company_id
        WHERE c.name = '星海数字科技有限公司'
          AND d.name = v.dept_name
          AND t.name = v.team_name
        LIMIT 1
      )
    END,
    'ACTIVE',
    v.gender
FROM (
    VALUES
      ('linzhiyuan',  '林致远', 'FOUNDER',      NULL,         NULL,         '男'),

      ('zhoumingyuan','周明远', 'DEPT_MANAGER', '产品研发部', NULL,         '男'),
      ('chenyu',      '陈宇',   'TEAM_LEADER',  '产品研发部', '平台研发组', '男'),
      ('lihaoran',    '李浩然', 'EMPLOYEE',     '产品研发部', '平台研发组', '男'),
      ('wangchen',    '王晨',   'EMPLOYEE',     '产品研发部', '平台研发组', '男'),
      ('zhaoxinyi',   '赵欣怡', 'EMPLOYEE',     '产品研发部', '平台研发组', '女'),
      ('suwanqing',   '苏婉清', 'TEAM_LEADER',  '产品研发部', '产品设计组', '女'),
      ('tangkexin',   '唐可欣', 'EMPLOYEE',     '产品研发部', '产品设计组', '女'),

      ('xuwenbo',     '许文博', 'DEPT_MANAGER', '项目交付部', NULL,         '男'),
      ('gaozixuan',   '高子轩', 'TEAM_LEADER',  '项目交付部', '华北交付组', '男'),
      ('liusiqi',     '刘思琪', 'EMPLOYEE',     '项目交付部', '华北交付组', '女'),
      ('zhengkai',    '郑凯',   'EMPLOYEE',     '项目交付部', '华北交付组', '男'),
      ('shenjianning','沈佳宁', 'TEAM_LEADER',  '项目交付部', '客户成功组', '女'),
      ('sunyutong',   '孙雨桐', 'EMPLOYEE',     '项目交付部', '客户成功组', '女'),

      ('hanqihang',   '韩启航', 'DEPT_MANAGER', '市场运营部', NULL,         '男'),
      ('gujiacheng',  '顾嘉诚', 'TEAM_LEADER',  '市场运营部', '商务运营组', '男'),
      ('fangruolin',  '方若琳', 'EMPLOYEE',     '市场运营部', '商务运营组', '女'),
      ('luojunjie',   '罗俊杰', 'EMPLOYEE',     '市场运营部', '商务运营组', '男')
) AS v(username, real_name, role_code, dept_name, team_name, gender)
WHERE NOT EXISTS (
    SELECT 1 FROM users u WHERE u.username = v.username
);

-- ---------------------------------------------------------------------------
-- 5. 建立负责人关系
-- ---------------------------------------------------------------------------

UPDATE companies
SET founder_id = (SELECT id FROM users WHERE username = 'linzhiyuan')
WHERE name = '星海数字科技有限公司'
  AND founder_id IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM companies c
      WHERE c.founder_id = (SELECT id FROM users WHERE username = 'linzhiyuan')
  );

UPDATE departments d
SET manager_id = u.id
FROM users u, companies c
WHERE d.company_id = c.id
  AND c.name = '星海数字科技有限公司'
  AND d.manager_id IS NULL
  AND (
      (d.name = '产品研发部' AND u.username = 'zhoumingyuan')
      OR
      (d.name = '项目交付部' AND u.username = 'xuwenbo')
      OR
      (d.name = '市场运营部' AND u.username = 'hanqihang')
  )
  AND NOT EXISTS (
      SELECT 1 FROM departments x WHERE x.manager_id = u.id
  );

UPDATE teams t
SET leader_id = u.id
FROM users u, departments d, companies c
WHERE t.department_id = d.id
  AND d.company_id = c.id
  AND c.name = '星海数字科技有限公司'
  AND t.leader_id IS NULL
  AND (
      (d.name = '产品研发部' AND t.name = '平台研发组' AND u.username = 'chenyu')
      OR
      (d.name = '产品研发部' AND t.name = '产品设计组' AND u.username = 'suwanqing')
      OR
      (d.name = '项目交付部' AND t.name = '华北交付组' AND u.username = 'gaozixuan')
      OR
      (d.name = '项目交付部' AND t.name = '客户成功组' AND u.username = 'shenjianning')
      OR
      (d.name = '市场运营部' AND t.name = '商务运营组' AND u.username = 'gujiacheng')
  )
  AND NOT EXISTS (
      SELECT 1 FROM teams x WHERE x.leader_id = u.id
  );

-- ---------------------------------------------------------------------------
-- 6. 将序列推进到当前最大 ID，便于后续通过页面新增数据
-- ---------------------------------------------------------------------------

SELECT setval(pg_get_serial_sequence('companies', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM companies), 1), 1), true);
SELECT setval(pg_get_serial_sequence('departments', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM departments), 1), 1), true);
SELECT setval(pg_get_serial_sequence('teams', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM teams), 1), 1), true);
SELECT setval(pg_get_serial_sequence('users', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM users), 1), 1), true);
