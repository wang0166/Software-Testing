-- 日志、点评与审计

CREATE TABLE work_logs (
  id           BIGSERIAL PRIMARY KEY,
  author_id    BIGINT NOT NULL REFERENCES users(id),
  log_date     DATE NOT NULL,
  content      TEXT NOT NULL,
  status       VARCHAR(16) NOT NULL DEFAULT 'DRAFT',
  is_important BOOLEAN NOT NULL DEFAULT FALSE,
  submitted_at TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ux_work_logs_author_date UNIQUE (author_id, log_date),
  CONSTRAINT chk_work_logs_status CHECK (status IN ('DRAFT', 'SUBMITTED')),
  CONSTRAINT chk_work_logs_content_not_blank CHECK (btrim(content) <> '')
);

CREATE TABLE log_comments (
  id           BIGSERIAL PRIMARY KEY,
  log_id       BIGINT NOT NULL REFERENCES work_logs(id) ON DELETE CASCADE,
  commenter_id BIGINT NOT NULL REFERENCES users(id),
  parent_id    BIGINT REFERENCES log_comments(id) ON DELETE CASCADE,
  content      TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_log_comments_content_not_blank CHECK (btrim(content) <> '')
);

CREATE TABLE operation_audits (
  id          BIGSERIAL PRIMARY KEY,
  operator_id BIGINT,
  action      VARCHAR(64) NOT NULL,
  object_type VARCHAR(32),
  object_id   VARCHAR(64),
  detail      TEXT,
  result      VARCHAR(16) NOT NULL,
  ip          VARCHAR(64),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_work_logs_status ON work_logs(status);
CREATE INDEX idx_work_logs_date ON work_logs(log_date);
CREATE INDEX idx_log_comments_log ON log_comments(log_id);
CREATE INDEX idx_audits_created ON operation_audits(created_at);
