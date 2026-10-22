-- 任务、接收记录、检查历史、自建任务与公司展示内容

CREATE TABLE tasks (
  id         BIGSERIAL PRIMARY KEY,
  sender_id  BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  name       VARCHAR(200) NOT NULL,
  details    TEXT NOT NULL,
  start_date DATE NOT NULL,
  deadline   DATE NOT NULL,
  urgency    VARCHAR(16) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_tasks_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT chk_tasks_details_not_blank CHECK (btrim(details) <> ''),
  CONSTRAINT chk_tasks_date_range CHECK (deadline >= start_date),
  CONSTRAINT chk_tasks_urgency CHECK (urgency IN ('URGENT', 'NOT_URGENT'))
);

CREATE TABLE task_assignments (
  id               BIGSERIAL PRIMARY KEY,
  task_id          BIGINT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  assignee_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  execution_status VARCHAR(16) NOT NULL DEFAULT 'NOT_STARTED',
  review_status    VARCHAR(16) NOT NULL DEFAULT 'NONE',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ux_task_assignments_task_assignee UNIQUE (task_id, assignee_id),
  CONSTRAINT chk_task_assignments_execution CHECK (execution_status IN ('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED')),
  CONSTRAINT chk_task_assignments_review CHECK (review_status IN ('NONE', 'PENDING', 'APPROVED', 'RETURNED'))
);

CREATE TABLE task_reviews (
  id            BIGSERIAL PRIMARY KEY,
  assignment_id BIGINT NOT NULL REFERENCES task_assignments(id) ON DELETE CASCADE,
  action        VARCHAR(16) NOT NULL,
  actor_id      BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  comment       TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_task_reviews_action CHECK (action IN ('INVITED', 'APPROVED', 'RETURNED'))
);

CREATE TABLE personal_tasks (
  id         BIGSERIAL PRIMARY KEY,
  owner_id   BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name       VARCHAR(200) NOT NULL,
  details    TEXT NOT NULL,
  status     VARCHAR(16) NOT NULL DEFAULT 'NOT_STARTED',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_personal_tasks_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT chk_personal_tasks_details_not_blank CHECK (btrim(details) <> ''),
  CONSTRAINT chk_personal_tasks_status CHECK (status IN ('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED'))
);

CREATE TABLE company_matters (
  id         BIGSERIAL PRIMARY KEY,
  title      VARCHAR(200) NOT NULL,
  content    TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  updated_by BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_company_matters_title_not_blank CHECK (btrim(title) <> ''),
  CONSTRAINT chk_company_matters_content_not_blank CHECK (btrim(content) <> '')
);

CREATE TABLE company_important_tasks (
  id         BIGSERIAL PRIMARY KEY,
  title      VARCHAR(200) NOT NULL,
  content    TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  updated_by BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_company_important_tasks_title_not_blank CHECK (btrim(title) <> ''),
  CONSTRAINT chk_company_important_tasks_content_not_blank CHECK (btrim(content) <> '')
);

CREATE INDEX idx_tasks_sender ON tasks(sender_id, created_at DESC);
CREATE INDEX idx_tasks_dates ON tasks(start_date, deadline);
CREATE INDEX idx_task_assignments_assignee ON task_assignments(assignee_id, updated_at DESC);
CREATE INDEX idx_task_assignments_review ON task_assignments(assignee_id, review_status);
CREATE INDEX idx_task_reviews_assignment ON task_reviews(assignment_id, created_at);
CREATE INDEX idx_personal_tasks_owner ON personal_tasks(owner_id, updated_at DESC);
