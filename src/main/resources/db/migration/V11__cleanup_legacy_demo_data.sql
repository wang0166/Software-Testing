-- V11: 清理 V5 遗留 Demo 组织与四个旧业务账号
-- 依赖：V10__seed_showcase_business.sql
--
-- 清理对象：
--   founder  / 张创始
--   deptmgr  / 李部门
--   teamlead / 王组长
--   employee / 赵员工
--   旧团队：研发一组
--   旧部门：研发部
--   旧公司：承载上述研发部的旧 Demo 公司（通常为 Pandora）
--
-- 保留对象：
--   admin / 系统管理员
--   V9 创建的“星海数字科技有限公司”及其 18 名核心人员
--   V10 创建的全部经营沙盘数据
--
-- 说明：
--   已执行过的 V5/V9/V10 不修改；通过新增迁移清理旧 Demo，符合 Flyway 版本管理习惯。

-- ============================================================================
-- 0. 锁定 V5 遗留对象 ID
-- ============================================================================

CREATE TEMP TABLE _v11_legacy_users AS
SELECT id
FROM users
WHERE username IN ('founder', 'deptmgr', 'teamlead', 'employee');

CREATE TEMP TABLE _v11_legacy_departments AS
SELECT DISTINCT d.id, d.company_id
FROM departments d
WHERE d.name = '研发部'
  AND (
      d.manager_id IN (SELECT id FROM _v11_legacy_users)
      OR EXISTS (
          SELECT 1
          FROM users u
          WHERE u.department_id = d.id
            AND u.id IN (SELECT id FROM _v11_legacy_users)
      )
  );

CREATE TEMP TABLE _v11_legacy_teams AS
SELECT DISTINCT t.id, t.department_id
FROM teams t
WHERE t.name = '研发一组'
  AND (
      t.leader_id IN (SELECT id FROM _v11_legacy_users)
      OR EXISTS (
          SELECT 1
          FROM users u
          WHERE u.team_id = t.id
            AND u.id IN (SELECT id FROM _v11_legacy_users)
      )
  );

CREATE TEMP TABLE _v11_legacy_companies AS
SELECT DISTINCT c.id
FROM companies c
WHERE c.id IN (
    SELECT company_id FROM _v11_legacy_departments
)
AND c.name <> '星海数字科技有限公司';

-- ============================================================================
-- 1. 清理旧账号相关会话、密码申请和审计
-- ============================================================================

DELETE FROM refresh_tokens
WHERE user_id IN (SELECT id FROM _v11_legacy_users);

DELETE FROM password_requests
WHERE user_id IN (SELECT id FROM _v11_legacy_users)
   OR reviewer_id IN (SELECT id FROM _v11_legacy_users);

-- operation_audits.operator_id 没有外键，但旧 Demo 审计记录也一并清理，
-- 避免后台审计页面继续出现已经删除的旧账号 ID。
DELETE FROM operation_audits
WHERE operator_id IN (SELECT id FROM _v11_legacy_users);

-- ============================================================================
-- 2. 清理日志与评论
-- ============================================================================

-- 先删除旧账号在其他人日志下留下的评论；其子回复会因 ON DELETE CASCADE 删除。
DELETE FROM log_comments
WHERE commenter_id IN (SELECT id FROM _v11_legacy_users);

-- 再删除旧账号自己的日志；该日志下全部评论会随日志级联删除。
DELETE FROM work_logs
WHERE author_id IN (SELECT id FROM _v11_legacy_users);

-- ============================================================================
-- 3. 清理任务、任务分配和审核记录
-- ============================================================================

-- 旧账号作为审核人留下的审核记录。
DELETE FROM task_reviews
WHERE actor_id IN (SELECT id FROM _v11_legacy_users);

-- 旧账号作为任务接收人的 assignment。
-- 对应 task_reviews 会通过 assignment_id 的 ON DELETE CASCADE 一并删除。
DELETE FROM task_assignments
WHERE assignee_id IN (SELECT id FROM _v11_legacy_users);

-- 旧账号作为发送人的任务。
-- 对应 task_assignments / task_reviews 会随 task ON DELETE CASCADE 删除。
DELETE FROM tasks
WHERE sender_id IN (SELECT id FROM _v11_legacy_users);

-- 个人任务本身已定义 ON DELETE CASCADE，但这里显式清理，迁移意图更清晰。
DELETE FROM personal_tasks
WHERE owner_id IN (SELECT id FROM _v11_legacy_users);

-- ============================================================================
-- 4. 清理旧账号维护的公司展示内容
-- ============================================================================

DELETE FROM company_matters
WHERE updated_by IN (SELECT id FROM _v11_legacy_users);

DELETE FROM company_important_tasks
WHERE updated_by IN (SELECT id FROM _v11_legacy_users);

-- ============================================================================
-- 5. 解除组织负责人外键，避免删除用户时受到 RESTRICT/普通 FK 阻挡
-- ============================================================================

UPDATE teams
SET leader_id = NULL
WHERE leader_id IN (SELECT id FROM _v11_legacy_users);

UPDATE departments
SET manager_id = NULL
WHERE manager_id IN (SELECT id FROM _v11_legacy_users);

UPDATE companies
SET founder_id = NULL
WHERE founder_id IN (SELECT id FROM _v11_legacy_users);

-- ============================================================================
-- 6. 删除 V5 的四个旧业务账号
-- ============================================================================

DELETE FROM users
WHERE id IN (SELECT id FROM _v11_legacy_users);

-- ============================================================================
-- 7. 删除旧团队、旧部门、旧公司
-- ============================================================================

DELETE FROM teams
WHERE id IN (SELECT id FROM _v11_legacy_teams);

DELETE FROM departments
WHERE id IN (SELECT id FROM _v11_legacy_departments);

-- 仅在公司已经没有任何部门时删除旧 Demo 公司。
-- 这样即使用户曾经手工往该公司加过其他正式部门，也不会误删。
DELETE FROM companies c
WHERE c.id IN (SELECT id FROM _v11_legacy_companies)
  AND NOT EXISTS (
      SELECT 1 FROM departments d WHERE d.company_id = c.id
  )
  AND c.name <> '星海数字科技有限公司';

-- ============================================================================
-- 8. 迁移后保护性校验
-- ============================================================================

DO $$
DECLARE
    legacy_user_count INTEGER;
    showcase_user_count INTEGER;
    showcase_company_count INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO legacy_user_count
      FROM users
     WHERE username IN ('founder', 'deptmgr', 'teamlead', 'employee');

    IF legacy_user_count <> 0 THEN
        RAISE EXCEPTION
            'V11 cleanup failed: % legacy V5 business users still exist',
            legacy_user_count;
    END IF;

    SELECT COUNT(*)
      INTO showcase_user_count
      FROM users
     WHERE username IN (
        'linzhiyuan',
        'zhoumingyuan', 'chenyu', 'lihaoran', 'wangchen', 'zhaoxinyi',
        'suwanqing', 'tangkexin',
        'xuwenbo', 'gaozixuan', 'liusiqi', 'zhengkai',
        'shenjianning', 'sunyutong',
        'hanqihang', 'gujiacheng', 'fangruolin', 'luojunjie'
     );

    IF showcase_user_count <> 18 THEN
        RAISE EXCEPTION
            'V11 safety check failed: expected 18 showcase users, found %',
            showcase_user_count;
    END IF;

    SELECT COUNT(*)
      INTO showcase_company_count
      FROM companies
     WHERE name = '星海数字科技有限公司';

    IF showcase_company_count <> 1 THEN
        RAISE EXCEPTION
            'V11 safety check failed: expected exactly one showcase company, found %',
            showcase_company_count;
    END IF;
END $$;
