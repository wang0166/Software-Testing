-- V10: 星海数字科技有限公司经营沙盘数据
-- 依赖：V9__seed_showcase_organization.sql
-- 目标：
--   1. 建立三条真实业务主线；
--   2. 覆盖公司事项、公司重点任务、层级派发任务、执行/审核状态；
--   3. 生成约 3 周的工作日志、今日提交差异、评论/回复和个人任务；
--   4. 为 Stats / Calendar / Task Map 页面提供可直接展示的数据。
--
-- 说明：
--   - 所有业务人员均引用 V9 中的稳定 username，不依赖固定自增 ID。
--   - 日期围绕执行本迁移时的 CURRENT_DATE 生成，方便首次启动立即展示。
--   - 旧 Pandora 测试数据保持不变。

-- ============================================================================
-- 1. 公司事项：过去、当前、未来均有，便于 Calendar / 首页展示
-- ============================================================================

INSERT INTO company_matters
    (title, content, sort_order, updated_by, start_date, deadline, created_at, updated_at)
SELECT
    m.title,
    m.content,
    m.sort_order,
    u.id,
    ((CURRENT_DATE + m.start_offset) + m.start_time) AT TIME ZONE 'Asia/Shanghai',
    ((CURRENT_DATE + m.deadline_offset) + m.deadline_time) AT TIME ZONE 'Asia/Shanghai',
    now(),
    now()
FROM (
    VALUES
      ('云栖商业中心数字化升级项目二期启动',
       '二期进入正式推进阶段，重点完成订单结算、经营数据同步、门店终端联调和上线保障。',
       10, -14, TIME '09:00', 14, TIME '18:00'),
      ('星云企业协同平台 2.3 发布冲刺',
       '完成工作台体验优化、移动端视觉规范补齐、关键缺陷修复和发布前回归。',
       20, -10, TIME '09:00', 7, TIME '18:00'),
      ('2026 华北商业客户拓展专项',
       '围绕华远商业等重点客户推进方案沟通、案例材料、商务报价和签约准备。',
       30, -7, TIME '10:00', 21, TIME '18:00'),
      ('云栖一期项目验收复盘',
       '复盘一期上线过程中的数据迁移、门店联调和客户培训问题，形成二期改进清单。',
       40, -21, TIME '14:00', -15, TIME '17:00'),
      ('数据安全与权限专项检查',
       '检查客户数据访问、账号权限分配、接口日志和高权限操作记录，完成整改闭环。',
       50, -3, TIME '09:00', 4, TIME '18:00'),
      ('月度经营复盘会',
       '复盘本月研发、交付、客户成功和市场拓展核心指标，确认下阶段资源优先级。',
       60, 3, TIME '09:00', 3, TIME '12:00'),
      ('客户成功集中回访周',
       '针对云栖项目上线商户开展集中回访，整理高频问题、优化建议和续约风险。',
       70, 7, TIME '09:00', 11, TIME '18:00'),
      ('年度预算与人员规划',
       '根据项目储备和产品路线评估下一年度研发、交付和市场团队人员与预算需求。',
       80, 14, TIME '09:00', 30, TIME '18:00')
) AS m(title, content, sort_order, start_offset, start_time, deadline_offset, deadline_time)
JOIN users u ON u.username = 'linzhiyuan';

-- ============================================================================
-- 2. 公司重点任务
-- ============================================================================

INSERT INTO company_important_tasks
    (title, content, sort_order, updated_by, created_at, updated_at)
SELECT x.title, x.content, x.sort_order, u.id, now(), now()
FROM (
    VALUES
      ('云栖二期上线保障',
       '研发与交付联合保障订单结算、数据同步、终端联调和客户现场问题处理。',
       10),
      ('星云 2.3 版本按期发布',
       '确保核心功能、移动端体验和回归测试按计划完成，控制高优先级缺陷数量。',
       20),
      ('华北重点客户突破',
       '集中推进华远商业等重点客户二轮方案、商务条款和决策链沟通。',
       30),
      ('数据安全专项整改',
       '完成账号权限、客户数据访问和关键操作日志检查，形成整改记录。',
       40),
      ('客户成功回访与问题闭环',
       '对上线客户反馈进行分级处理，明确责任人、预计完成时间和复盘结论。',
       50),
      ('月度经营复盘',
       '围绕项目进度、交付风险、产品质量和销售机会形成月度经营结论。',
       60)
) AS x(title, content, sort_order)
JOIN users u ON u.username = 'linzhiyuan';

-- ============================================================================
-- 3. 层级派发任务
--    Founder -> Department Manager -> Team Leader -> Employee
-- ============================================================================

WITH task_seed(
    sender_username, task_name, details,
    start_offset, start_time, deadline_offset, deadline_time, urgency,
    assignee_username, execution_status, review_status
) AS (
    VALUES
      ('linzhiyuan',
       '【云栖】平台研发与联调总体推进',
       '统筹云栖二期平台研发、接口联调和质量保障，重点跟踪结算链路与经营数据同步风险。',
       -7, TIME '09:00', 7, TIME '18:00', 'URGENT',
       'zhoumingyuan', 'IN_PROGRESS', 'NONE'),

      ('linzhiyuan',
       '【云栖】现场交付与上线准备',
       '统筹门店现场部署、历史数据核验、上线窗口和客户培训准备，确保二期按计划切换。',
       -5, TIME '09:30', 10, TIME '18:00', 'URGENT',
       'xuwenbo', 'IN_PROGRESS', 'NONE'),

      ('linzhiyuan',
       '【华北拓展】重点客户签约推进',
       '推进华远商业等重点客户方案确认、商务条款和关键决策人沟通，形成阶段签约预测。',
       -3, TIME '10:00', 14, TIME '18:00', 'NOT_URGENT',
       'hanqihang', 'IN_PROGRESS', 'NONE'),

      ('linzhiyuan',
       '【星云2.3】版本发布总推进',
       '统筹 2.3 版本范围、质量门槛、发布窗口和跨团队依赖，完成发布前最终确认。',
       -14, TIME '09:00', 4, TIME '18:00', 'URGENT',
       'zhoumingyuan', 'COMPLETED', 'PENDING'),

      ('linzhiyuan',
       '【云栖】一期验收问题闭环',
       '完成一期验收遗留问题复盘，确认责任人、整改结果和二期预防措施。',
       -14, TIME '09:00', -2, TIME '17:00', 'NOT_URGENT',
       'xuwenbo', 'COMPLETED', 'APPROVED'),

      ('zhoumingyuan',
       '【云栖】订单结算服务联调',
       '完成订单结算核心接口、异常场景和跨服务联调，输出问题清单并跟踪关闭。',
       -6, TIME '09:00', 3, TIME '18:00', 'URGENT',
       'chenyu', 'IN_PROGRESS', 'NONE'),

      ('zhoumingyuan',
       '【星云2.3】工作台交互优化',
       '完成新版工作台信息层级、关键操作路径和异常状态交互优化，并配合研发验收。',
       -8, TIME '09:00', 2, TIME '18:00', 'NOT_URGENT',
       'suwanqing', 'COMPLETED', 'PENDING'),

      ('xuwenbo',
       '【云栖】门店现场部署与数据核验',
       '组织重点门店部署、配置核验、历史数据抽查和现场异常处理。',
       -4, TIME '08:30', 5, TIME '18:00', 'URGENT',
       'gaozixuan', 'IN_PROGRESS', 'NONE'),

      ('xuwenbo',
       '【云栖】上线后客户反馈闭环',
       '建立上线后反馈台账，按影响范围和紧急程度分级，推动责任团队按时闭环。',
       0, TIME '09:00', 8, TIME '18:00', 'NOT_URGENT',
       'shenjianning', 'NOT_STARTED', 'NONE'),

      ('hanqihang',
       '【华北拓展】重点客户方案与商务材料',
       '整理重点客户行业痛点、解决方案、案例和报价材料，支撑第二轮商务沟通。',
       -5, TIME '09:30', 6, TIME '18:00', 'NOT_URGENT',
       'gujiacheng', 'IN_PROGRESS', 'NONE'),

      ('chenyu',
       '【云栖】结算接口异常场景处理',
       '补齐退款、重复请求、金额边界和网络重试等异常场景，并完成联调验证。',
       -3, TIME '09:00', 1, TIME '18:00', 'URGENT',
       'lihaoran', 'IN_PROGRESS', 'NONE'),

      ('chenyu',
       '【云栖】经营数据同步任务',
       '完成经营数据增量同步、失败重试和监控告警，核对关键指标口径。',
       -2, TIME '09:00', 2, TIME '18:00', 'URGENT',
       'wangchen', 'IN_PROGRESS', 'RETURNED'),

      ('chenyu',
       '【云栖】结算模块回归测试',
       '覆盖核心结算链路、退款场景、异常重试和权限边界，输出回归报告。',
       -1, TIME '09:30', 4, TIME '18:00', 'NOT_URGENT',
       'zhaoxinyi', 'NOT_STARTED', 'NONE'),

      ('suwanqing',
       '【星云2.3】移动端视觉规范补齐',
       '补齐移动端图标、间距、状态色和异常页面规范，并完成交付标注。',
       -4, TIME '10:00', 1, TIME '18:00', 'NOT_URGENT',
       'tangkexin', 'COMPLETED', 'APPROVED'),

      ('gaozixuan',
       '【云栖】历史会员数据清洗',
       '完成会员基础信息、等级、积分和手机号异常数据清洗，并输出核验结果。',
       -4, TIME '09:00', 1, TIME '18:00', 'URGENT',
       'liusiqi', 'COMPLETED', 'APPROVED'),

      ('gaozixuan',
       '【云栖】门店终端联调',
       '完成收银终端、打印设备和门店网络环境联调，记录阻塞问题并推进解决。',
       -2, TIME '08:30', 3, TIME '18:00', 'URGENT',
       'zhengkai', 'IN_PROGRESS', 'NONE'),

      ('shenjianning',
       '【云栖】商户问题清单跟进',
       '汇总商户上线后的使用反馈，区分操作问题、产品建议和缺陷并跟进处理。',
       0, TIME '09:30', 5, TIME '18:00', 'NOT_URGENT',
       'sunyutong', 'NOT_STARTED', 'NONE'),

      ('gujiacheng',
       '【华北拓展】华远商业二轮方案沟通',
       '准备客户二轮沟通材料，重点确认多门店经营数据汇总、权限和实施周期。',
       -1, TIME '10:00', 2, TIME '18:00', 'URGENT',
       'fangruolin', 'IN_PROGRESS', 'NONE'),

      ('gujiacheng',
       '【华北拓展】案例材料与活动页面更新',
       '更新零售行业案例、客户价值数据和活动页面内容，为后续线索转化提供支持。',
       -3, TIME '09:00', 4, TIME '18:00', 'NOT_URGENT',
       'luojunjie', 'COMPLETED', 'PENDING')
),
inserted_tasks AS (
    INSERT INTO tasks
        (sender_id, name, details, start_date, deadline, urgency, created_at, updated_at)
    SELECT
        sender.id,
        ts.task_name,
        ts.details,
        (CURRENT_DATE + ts.start_offset) + ts.start_time,
        (CURRENT_DATE + ts.deadline_offset) + ts.deadline_time,
        ts.urgency,
        now(),
        now()
    FROM task_seed ts
    JOIN users sender ON sender.username = ts.sender_username
    RETURNING id, name
)
INSERT INTO task_assignments
    (task_id, assignee_id, execution_status, review_status, created_at, updated_at)
SELECT
    it.id,
    assignee.id,
    ts.execution_status,
    ts.review_status,
    now(),
    now()
FROM inserted_tasks it
JOIN task_seed ts ON ts.task_name = it.name
JOIN users assignee ON assignee.username = ts.assignee_username;

-- ============================================================================
-- 4. 审核历史
-- ============================================================================

INSERT INTO task_reviews
    (assignment_id, action, actor_id, comment, created_at)
SELECT
    ta.id,
    rs.action,
    actor.id,
    rs.comment,
    now() + rs.created_offset
FROM (
    VALUES
      ('【星云2.3】版本发布总推进', 'zhoumingyuan', 'INVITED',  'linzhiyuan',
       '版本范围与质量门槛已确认，请提交最终完成情况供审核。', INTERVAL '-8 hours'),

      ('【云栖】一期验收问题闭环', 'xuwenbo', 'INVITED', 'linzhiyuan',
       '请提交一期遗留问题闭环结果。', INTERVAL '-5 days'),
      ('【云栖】一期验收问题闭环', 'xuwenbo', 'APPROVED', 'linzhiyuan',
       '问题闭环完整，二期预防措施清晰，同意通过。', INTERVAL '-4 days'),

      ('【星云2.3】工作台交互优化', 'suwanqing', 'INVITED', 'zhoumingyuan',
       '交互稿已进入研发验收，请提交最终设计说明。', INTERVAL '-6 hours'),

      ('【云栖】经营数据同步任务', 'wangchen', 'INVITED', 'chenyu',
       '请提交数据同步与失败重试验证结果。', INTERVAL '-2 days'),
      ('【云栖】经营数据同步任务', 'wangchen', 'RETURNED', 'chenyu',
       '失败重试场景仍缺少超时告警验证，请补齐后重新提交。', INTERVAL '-1 day'),

      ('【星云2.3】移动端视觉规范补齐', 'tangkexin', 'INVITED', 'suwanqing',
       '请提交最终视觉规范与标注链接。', INTERVAL '-2 days'),
      ('【星云2.3】移动端视觉规范补齐', 'tangkexin', 'APPROVED', 'suwanqing',
       '规范完整，关键异常页面已经补齐，通过。', INTERVAL '-1 day'),

      ('【云栖】历史会员数据清洗', 'liusiqi', 'INVITED', 'gaozixuan',
       '请提交清洗结果和异常数据统计。', INTERVAL '-2 days'),
      ('【云栖】历史会员数据清洗', 'liusiqi', 'APPROVED', 'gaozixuan',
       '抽样核验无明显问题，可以进入正式导入。', INTERVAL '-1 day'),

      ('【华北拓展】案例材料与活动页面更新', 'luojunjie', 'INVITED', 'gujiacheng',
       '案例材料已完成，请提交最终版本供商务审核。', INTERVAL '-7 hours')
) AS rs(task_name, assignee_username, action, actor_username, comment, created_offset)
JOIN tasks t ON t.name = rs.task_name
JOIN users assignee ON assignee.username = rs.assignee_username
JOIN task_assignments ta
  ON ta.task_id = t.id
 AND ta.assignee_id = assignee.id
JOIN users actor ON actor.username = rs.actor_username;

-- ============================================================================
-- 5. 约三周历史工作日志
--    每位核心人员在过去 20 天的工作日中按规则生成约 5 条已提交日志，
--    总量约 80~100 条；内容按真实岗位区分。
-- ============================================================================

WITH showcase_users(username) AS (
    VALUES
      ('linzhiyuan'), ('zhoumingyuan'), ('chenyu'), ('lihaoran'), ('wangchen'),
      ('zhaoxinyi'), ('suwanqing'), ('tangkexin'), ('xuwenbo'), ('gaozixuan'),
      ('liusiqi'), ('zhengkai'), ('shenjianning'), ('sunyutong'), ('hanqihang'),
      ('gujiacheng'), ('fangruolin'), ('luojunjie')
),
dates AS (
    SELECT gs::date AS log_date
    FROM generate_series(
        CURRENT_DATE - 20,
        CURRENT_DATE - 1,
        INTERVAL '1 day'
    ) gs
    WHERE EXTRACT(ISODOW FROM gs) BETWEEN 1 AND 5
),
seed AS (
    SELECT u.id AS author_id, u.username, d.log_date
    FROM showcase_users su
    JOIN users u ON u.username = su.username
    CROSS JOIN dates d
    WHERE mod(u.id + EXTRACT(DOY FROM d.log_date)::int, 3) = 0
)
INSERT INTO work_logs
    (author_id, log_date, content, status, is_important, submitted_at, created_at, updated_at)
SELECT
    s.author_id,
    s.log_date,
    CASE s.username
      WHEN 'linzhiyuan' THEN
        '复盘公司三条业务线推进情况，重点确认云栖交付风险、星云 2.3 发布节奏和华北重点客户机会。'
      WHEN 'zhoumingyuan' THEN
        '跟进研发任务与版本风险，协调平台研发和产品设计资源，确认关键接口与发布节点。'
      WHEN 'chenyu' THEN
        '推进订单结算与数据接口开发，处理联调问题并检查异常场景和服务日志。'
      WHEN 'lihaoran' THEN
        '完成后端接口开发与自测，补充边界条件处理并根据联调反馈修复问题。'
      WHEN 'wangchen' THEN
        '推进经营数据同步模块，核对增量同步、失败重试和监控告警逻辑。'
      WHEN 'zhaoxinyi' THEN
        '执行核心功能回归测试，记录缺陷复现步骤并跟进研发修复结果。'
      WHEN 'suwanqing' THEN
        '梳理产品需求与交互方案，评审工作台关键流程并同步研发实现细节。'
      WHEN 'tangkexin' THEN
        '完善移动端视觉稿与组件规范，补充异常状态和交付标注。'
      WHEN 'xuwenbo' THEN
        '跟进项目交付总体进度，协调现场资源并处理客户侧阻塞问题。'
      WHEN 'gaozixuan' THEN
        '推进门店部署与数据核验，汇总现场问题并协调研发和客户资源处理。'
      WHEN 'liusiqi' THEN
        '完成历史业务数据清洗与抽样核验，记录异常数据并更新导入清单。'
      WHEN 'zhengkai' THEN
        '进行门店终端和网络环境联调，排查设备连接问题并更新现场记录。'
      WHEN 'shenjianning' THEN
        '整理客户反馈和问题优先级，协调责任团队并更新客户沟通计划。'
      WHEN 'sunyutong' THEN
        '跟进商户使用反馈，整理常见操作问题、产品建议和待确认事项。'
      WHEN 'hanqihang' THEN
        '复盘华北重点客户机会，检查商务推进节奏并确认下一轮客户沟通重点。'
      WHEN 'gujiacheng' THEN
        '完善重点客户解决方案与商务材料，协调案例、报价和活动内容准备。'
      WHEN 'fangruolin' THEN
        '跟进重点客户需求和决策链信息，更新沟通纪要与下一步行动计划。'
      WHEN 'luojunjie' THEN
        '更新行业案例与市场活动内容，整理客户价值数据并配合线索运营。'
    END || '（' || to_char(s.log_date, 'MM-DD') || '）',
    'SUBMITTED',
    (
      s.username IN ('linzhiyuan', 'zhoumingyuan', 'chenyu', 'xuwenbo', 'hanqihang')
      AND mod(EXTRACT(DOY FROM s.log_date)::int, 2) = 0
    ),
    ((s.log_date + TIME '18:10') AT TIME ZONE 'Asia/Shanghai'),
    ((s.log_date + TIME '09:00') AT TIME ZONE 'Asia/Shanghai'),
    ((s.log_date + TIME '18:10') AT TIME ZONE 'Asia/Shanghai')
FROM seed s;

-- ============================================================================
-- 6. 今日工作日志
--    13 已提交 + 3 草稿 + 2 未填写
--    未填写：唐可欣、孙雨桐
-- ============================================================================

INSERT INTO work_logs
    (author_id, log_date, content, status, is_important, submitted_at, created_at, updated_at)
SELECT
    u.id,
    CURRENT_DATE,
    x.content,
    x.status,
    x.is_important,
    CASE WHEN x.status = 'SUBMITTED' THEN now() ELSE NULL END,
    now(),
    now()
FROM (
    VALUES
      ('linzhiyuan', 'SUBMITTED', true,
       '召开经营进度碰头会，确认云栖二期上线风险、星云 2.3 发布门槛和华北重点客户下一步动作。'),
      ('zhoumingyuan', 'SUBMITTED', true,
       '协调平台研发与产品设计资源，确认结算联调阻塞项和 2.3 版本发布前必须关闭的问题。'),
      ('chenyu', 'SUBMITTED', true,
       '完成订单结算接口联调排查，定位两个异常重试问题，并安排数据同步任务补充告警验证。'),
      ('suwanqing', 'SUBMITTED', false,
       '完成工作台关键流程交互复核，整理移动端视觉规范验收意见并同步研发。'),
      ('xuwenbo', 'SUBMITTED', true,
       '核对云栖项目现场部署计划和数据迁移准备情况，明确上线窗口与客户侧负责人。'),
      ('gaozixuan', 'SUBMITTED', false,
       '完成重点门店部署检查，跟进历史会员数据导入结果，并整理终端联调阻塞项。'),
      ('shenjianning', 'SUBMITTED', false,
       '建立上线后客户反馈台账模板，划分操作问题、产品建议和缺陷三级处理流程。'),
      ('hanqihang', 'SUBMITTED', true,
       '复盘华北重点客户机会，确认华远商业二轮沟通目标和本周商务推进优先级。'),
      ('gujiacheng', 'SUBMITTED', false,
       '完善华远商业方案与报价材料，补充零售行业案例数据并安排客户沟通分工。'),
      ('lihaoran', 'SUBMITTED', false,
       '处理结算接口退款和重复请求边界场景，完成本地自测并提交联调版本。'),
      ('liusiqi', 'SUBMITTED', false,
       '完成会员数据清洗结果抽样复核，整理异常手机号与积分记录并提交核验清单。'),
      ('fangruolin', 'SUBMITTED', false,
       '与华远商业进行需求确认，客户重点关注多门店经营汇总、权限管理和实施周期。'),
      ('luojunjie', 'SUBMITTED', false,
       '更新零售行业案例材料和活动页面文案，补充两个客户价值数据点。'),

      ('wangchen', 'DRAFT', false,
       '经营数据同步任务已完成主体开发，正在补充失败重试和超时告警验证，待验证完成后提交。'),
      ('zhaoxinyi', 'DRAFT', false,
       '已完成结算模块主流程回归，退款与异常重试场景仍在执行，缺陷结果待汇总。'),
      ('zhengkai', 'DRAFT', false,
       '完成两家门店终端联调，第三家门店网络环境存在波动，正在继续排查。')
) AS x(username, status, is_important, content)
JOIN users u ON u.username = x.username;

-- ============================================================================
-- 7. 日志评论与回复
-- ============================================================================

INSERT INTO log_comments
    (log_id, commenter_id, parent_id, content, created_at)
SELECT
    wl.id,
    commenter.id,
    NULL,
    c.content,
    now()
FROM (
    VALUES
      ('lihaoran', 'chenyu',
       '异常场景覆盖得比较完整，明天联调时重点再观察重复请求下的幂等结果。'),
      ('liusiqi', 'gaozixuan',
       '数据清洗结果可以，正式导入前再做一次会员积分总量核对。'),
      ('fangruolin', 'gujiacheng',
       '客户关注点抓得很准，下一版方案把多门店权限模型放到更靠前的位置。'),
      ('luojunjie', 'gujiacheng',
       '案例数据有支撑，活动页面再补一个项目实施周期的客户证言。'),
      ('gaozixuan', 'xuwenbo',
       '现场风险控制得不错，网络问题请提前准备备用方案，避免影响上线窗口。'),
      ('chenyu', 'zhoumingyuan',
       '结算链路是当前最高优先级，告警验证补齐后再提交数据同步任务复审。'),
      ('suwanqing', 'zhoumingyuan',
       '工作台交互可以进入最终验收，注意保持移动端和 Web 端状态定义一致。'),
      ('hanqihang', 'linzhiyuan',
       '本周重点聚焦两家高意向客户，方案资源优先支持有明确决策时间的机会。')
) AS c(log_username, commenter_username, content)
JOIN users log_user ON log_user.username = c.log_username
JOIN work_logs wl
  ON wl.author_id = log_user.id
 AND wl.log_date = CURRENT_DATE
JOIN users commenter ON commenter.username = c.commenter_username;

INSERT INTO log_comments
    (log_id, commenter_id, parent_id, content, created_at)
SELECT
    parent.log_id,
    replier.id,
    parent.id,
    r.reply_content,
    now()
FROM (
    VALUES
      ('异常场景覆盖得比较完整，明天联调时重点再观察重复请求下的幂等结果。',
       'lihaoran', '收到，我会把重复请求和网络重试一起纳入明天的联调检查项。'),
      ('数据清洗结果可以，正式导入前再做一次会员积分总量核对。',
       'liusiqi', '好的，我会在导入前补充总量对账结果。'),
      ('客户关注点抓得很准，下一版方案把多门店权限模型放到更靠前的位置。',
       'fangruolin', '明白，今晚我会调整方案结构并补充权限示意。'),
      ('现场风险控制得不错，网络问题请提前准备备用方案，避免影响上线窗口。',
       'gaozixuan', '已联系客户 IT 准备备用网络，并安排明早提前到场验证。'),
      ('结算链路是当前最高优先级，告警验证补齐后再提交数据同步任务复审。',
       'chenyu', '了解，我会先盯结算联调，同时让王晨补齐告警验证后重新提交。')
) AS r(parent_content, replier_username, reply_content)
JOIN log_comments parent ON parent.content = r.parent_content
JOIN users replier ON replier.username = r.replier_username;

-- ============================================================================
-- 8. 个人任务：与派发任务共同组成 Task Map
-- ============================================================================

INSERT INTO personal_tasks
    (owner_id, name, details, status, created_at, updated_at)
SELECT u.id, p.name, p.details, p.status, now(), now()
FROM (
    VALUES
      ('linzhiyuan', '准备月度经营复盘提纲',
       '整理三条业务线的关键进展、风险和资源决策项。', 'IN_PROGRESS'),
      ('linzhiyuan', '确认年度招聘优先级',
       '根据项目储备与产品路线梳理研发、交付和市场岗位需求。', 'NOT_STARTED'),

      ('zhoumingyuan', '整理技术风险清单',
       '汇总云栖联调、星云 2.3 发布和数据安全专项中的技术风险。', 'IN_PROGRESS'),
      ('chenyu', '更新结算接口设计文档',
       '补充异常重试、幂等和监控告警设计说明。', 'IN_PROGRESS'),
      ('chenyu', '准备周五技术分享',
       '整理服务幂等与重试机制的案例材料。', 'NOT_STARTED'),
      ('lihaoran', '整理接口联调问题记录',
       '把本周结算联调问题按已解决、待确认和风险项分类。', 'IN_PROGRESS'),
      ('wangchen', '补充数据同步监控指标',
       '整理同步延迟、失败次数、重试次数和告警阈值。', 'NOT_STARTED'),
      ('zhaoxinyi', '更新回归测试用例',
       '补充退款、超时和重复请求场景。', 'IN_PROGRESS'),
      ('suwanqing', '整理 2.3 版本需求变更',
       '汇总版本周期内的需求调整和最终决策。', 'COMPLETED'),
      ('tangkexin', '归档移动端设计组件',
       '整理本次版本新增和调整的组件资源。', 'NOT_STARTED'),

      ('xuwenbo', '更新项目风险周报',
       '整理上线窗口、客户资源和现场部署风险。', 'IN_PROGRESS'),
      ('gaozixuan', '确认现场值守名单',
       '确认上线日前后交付、研发和客户侧值守人员。', 'NOT_STARTED'),
      ('liusiqi', '归档数据清洗脚本说明',
       '记录清洗规则、异常数据处理和核验方式。', 'COMPLETED'),
      ('zhengkai', '整理门店网络检查表',
       '形成门店上线前网络与终端环境检查模板。', 'IN_PROGRESS'),
      ('shenjianning', '设计客户反馈分级规则',
       '明确紧急问题、普通问题和产品建议的响应时限。', 'IN_PROGRESS'),
      ('sunyutong', '整理客户常见问题 FAQ',
       '汇总近期商户高频操作问题和标准回复。', 'NOT_STARTED'),

      ('hanqihang', '更新重点客户预测',
       '根据最新沟通情况调整本月客户签约概率。', 'IN_PROGRESS'),
      ('gujiacheng', '整理商务报价模板',
       '统一实施服务、订阅和增值服务报价表达。', 'IN_PROGRESS'),
      ('fangruolin', '更新华远商业客户画像',
       '补充组织结构、决策链、核心需求和竞争信息。', 'IN_PROGRESS'),
      ('luojunjie', '整理本月市场内容排期',
       '规划案例文章、活动页面和客户故事发布时间。', 'NOT_STARTED')
) AS p(username, name, details, status)
JOIN users u ON u.username = p.username;

-- ============================================================================
-- 9. 将本迁移涉及表的序列推进到最大 ID
-- ============================================================================

SELECT setval(pg_get_serial_sequence('company_matters', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM company_matters), 1), 1), true);
SELECT setval(pg_get_serial_sequence('company_important_tasks', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM company_important_tasks), 1), 1), true);
SELECT setval(pg_get_serial_sequence('tasks', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM tasks), 1), 1), true);
SELECT setval(pg_get_serial_sequence('task_assignments', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM task_assignments), 1), 1), true);
SELECT setval(pg_get_serial_sequence('task_reviews', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM task_reviews), 1), 1), true);
SELECT setval(pg_get_serial_sequence('work_logs', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM work_logs), 1), 1), true);
SELECT setval(pg_get_serial_sequence('log_comments', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM log_comments), 1), 1), true);
SELECT setval(pg_get_serial_sequence('personal_tasks', 'id'),
              GREATEST(COALESCE((SELECT MAX(id) FROM personal_tasks), 1), 1), true);
