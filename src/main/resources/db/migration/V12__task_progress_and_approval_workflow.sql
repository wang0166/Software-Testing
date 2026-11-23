-- V12: 移动端任务进度留痕、派发/变更审批与每日待办云端同步。
-- 说明：
--   1. 仅新增列、表和索引，不改动 V1-V11 的历史数据；
--   2. 进度记录独立留痕，task_assignments 只保留最新快照，便于移动端展示；
--   3. 审批申请在通过前不生成 tasks / task_assignments，避免“待审核任务”提前出现在接收人列表。

-- ---------------------------------------------------------------------------
-- 1. 任务类型（移动端用于标签与筛选，旧任务默认 GENERAL）
-- ---------------------------------------------------------------------------
ALTER TABLE tasks ADD COLUMN task_type VARCHAR(32) NOT NULL DEFAULT 'GENERAL';
ALTER TABLE tasks ADD CONSTRAINT chk_tasks_task_type CHECK (
  task_type IN ('GENERAL', 'DEVELOPMENT', 'PRODUCT', 'TESTING',
                'OPERATION', 'SALES', 'ADMINISTRATIVE', 'OTHER')
);

-- 进度记录允许“受阻”状态；已完成任务仍通过审核/退回流程处理。
ALTER TABLE task_assignments DROP CONSTRAINT chk_task_assignments_execution;
ALTER TABLE task_assignments ADD CONSTRAINT chk_task_assignments_execution CHECK (
  execution_status IN ('NOT_STARTED', 'IN_PROGRESS', 'BLOCKED', 'COMPLETED')
);

-- ---------------------------------------------------------------------------
-- 2. 进度记录：每次提交都追加一行，客户端据此展示历史与问题数
-- ---------------------------------------------------------------------------
CREATE TABLE task_progress_updates (
  id               BIGSERIAL PRIMARY KEY,
  assignment_id    BIGINT NOT NULL REFERENCES task_assignments(id) ON DELETE CASCADE,
  author_id        BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  execution_status VARCHAR(16) NOT NULL,
  progress_percent INTEGER NOT NULL,
  note             TEXT NOT NULL DEFAULT '',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_task_progress_status CHECK (
    execution_status IN ('NOT_STARTED', 'IN_PROGRESS', 'BLOCKED', 'COMPLETED')
  ),
  CONSTRAINT chk_task_progress_percent CHECK (progress_percent BETWEEN 0 AND 100),
  CONSTRAINT chk_task_progress_note_length CHECK (char_length(note) <= 1000)
);
CREATE INDEX idx_task_progress_assignment
  ON task_progress_updates(assignment_id, created_at DESC, id DESC);

-- ---------------------------------------------------------------------------
-- 3. 派发申请：申请人提交后进入 PENDING，由上级审核通过才生成任务
-- ---------------------------------------------------------------------------
CREATE TABLE task_dispatch_requests (
  id              BIGSERIAL PRIMARY KEY,
  requester_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  name            VARCHAR(200) NOT NULL,
  details         TEXT NOT NULL,
  start_date      TIMESTAMP NOT NULL,
  deadline        TIMESTAMP NOT NULL,
  urgency         VARCHAR(16) NOT NULL,
  task_type       VARCHAR(32) NOT NULL DEFAULT 'GENERAL',
  status          VARCHAR(12) NOT NULL DEFAULT 'PENDING',
  reviewer_id     BIGINT REFERENCES users(id) ON DELETE SET NULL,
  review_comment  TEXT,
  reviewed_at     TIMESTAMPTZ,
  created_task_id BIGINT REFERENCES tasks(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_task_dispatch_request_name CHECK (btrim(name) <> ''),
  CONSTRAINT chk_task_dispatch_request_details CHECK (btrim(details) <> ''),
  CONSTRAINT chk_task_dispatch_request_range CHECK (deadline > start_date),
  CONSTRAINT chk_task_dispatch_request_urgency CHECK (urgency IN ('URGENT', 'NOT_URGENT')),
  CONSTRAINT chk_task_dispatch_request_type CHECK (
    task_type IN ('GENERAL', 'DEVELOPMENT', 'PRODUCT', 'TESTING',
                  'OPERATION', 'SALES', 'ADMINISTRATIVE', 'OTHER')
  ),
  CONSTRAINT chk_task_dispatch_request_status CHECK (
    status IN ('PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN')
  )
);
CREATE INDEX idx_task_dispatch_request_requester
  ON task_dispatch_requests(requester_id, created_at DESC);
CREATE INDEX idx_task_dispatch_request_status
  ON task_dispatch_requests(status, created_at DESC);

CREATE TABLE task_dispatch_request_assignees (
  request_id  BIGINT NOT NULL REFERENCES task_dispatch_requests(id) ON DELETE CASCADE,
  assignee_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  PRIMARY KEY (request_id, assignee_id)
);

-- ---------------------------------------------------------------------------
-- 4. 变更申请：对已发布任务发起 UPDATE / DELETE，审核通过后才生效
-- ---------------------------------------------------------------------------
CREATE TABLE task_change_requests (
  id              BIGSERIAL PRIMARY KEY,
  task_id         BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  requester_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  action          VARCHAR(8) NOT NULL,
  name            VARCHAR(200),
  details         TEXT,
  start_date      TIMESTAMP,
  deadline        TIMESTAMP,
  urgency         VARCHAR(16),
  task_type       VARCHAR(32),
  status          VARCHAR(12) NOT NULL DEFAULT 'PENDING',
  reviewer_id     BIGINT REFERENCES users(id) ON DELETE SET NULL,
  review_comment  TEXT,
  reviewed_at     TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_task_change_request_action CHECK (action IN ('UPDATE', 'DELETE')),
  CONSTRAINT chk_task_change_request_status CHECK (
    status IN ('PENDING', 'APPROVED', 'REJECTED', 'WITHDRAWN')
  ),
  CONSTRAINT chk_task_change_request_payload CHECK (
    action = 'DELETE'
    OR (btrim(name) <> '' AND btrim(details) <> ''
        AND start_date IS NOT NULL AND deadline IS NOT NULL
        AND deadline > start_date AND urgency IN ('URGENT', 'NOT_URGENT')
        AND task_type IN ('GENERAL', 'DEVELOPMENT', 'PRODUCT', 'TESTING',
                          'OPERATION', 'SALES', 'ADMINISTRATIVE', 'OTHER'))
  )
);
-- 同一任务同时只允许一条待审核变更，避免移动端“重复申请”
CREATE UNIQUE INDEX ux_task_change_request_open
  ON task_change_requests(task_id) WHERE status = 'PENDING';
CREATE INDEX idx_task_change_request_requester
  ON task_change_requests(requester_id, created_at DESC);
CREATE INDEX idx_task_change_request_status
  ON task_change_requests(status, created_at DESC);

CREATE TABLE task_change_request_assignees (
  request_id  BIGINT NOT NULL REFERENCES task_change_requests(id) ON DELETE CASCADE,
  assignee_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  PRIMARY KEY (request_id, assignee_id)
);

-- ---------------------------------------------------------------------------
-- 5. 每日待办：从移动端本地存储升级为用户级云端同步
-- ---------------------------------------------------------------------------
CREATE TABLE daily_items (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_date  DATE NOT NULL,
  title      VARCHAR(200) NOT NULL,
  note       VARCHAR(1000) NOT NULL DEFAULT '',
  completed  BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_daily_items_title CHECK (btrim(title) <> '')
);
CREATE INDEX idx_daily_items_user_date ON daily_items(user_id, item_date, created_at DESC);
