-- 旧 DATE 代表整天，升级为北京时间的开始零点/截止 23:59，不丢失原日期覆盖范围。
ALTER TABLE tasks DROP CONSTRAINT chk_tasks_date_range;
ALTER TABLE tasks ALTER COLUMN start_date TYPE TIMESTAMP USING start_date::timestamp;
ALTER TABLE tasks ALTER COLUMN deadline TYPE TIMESTAMP USING deadline::timestamp + interval '23 hours 59 minutes';
ALTER TABLE tasks ADD CONSTRAINT chk_tasks_date_range CHECK (deadline > start_date);
ALTER TABLE tasks ADD CONSTRAINT chk_tasks_minute_precision CHECK (
  start_date = date_trunc('minute', start_date) AND deadline = date_trunc('minute', deadline)
);

CREATE TABLE password_requests (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind VARCHAR(10) NOT NULL CHECK (kind IN ('CHANGE','RESET')),
  status VARCHAR(12) NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING','APPROVED','REJECTED','CONSUMED','EXPIRED','CANCELLED')),
  auth_version INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  reviewer_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  identity_verified BOOLEAN NOT NULL DEFAULT false,
  token_hash VARCHAR(64) UNIQUE,
  CONSTRAINT chk_password_request_expiry CHECK (expires_at > created_at)
);
CREATE UNIQUE INDEX ux_password_request_open ON password_requests(user_id,kind)
  WHERE status IN ('PENDING','APPROVED');
CREATE INDEX idx_password_request_status ON password_requests(status,created_at DESC);

-- 仅保存带密钥的摘要，避免限流数据暴露账号/IP；与审批事务分开计数。
CREATE TABLE password_request_limits (
  bucket_key VARCHAR(64) PRIMARY KEY,
  window_started_at TIMESTAMPTZ NOT NULL,
  attempts INTEGER NOT NULL CHECK (attempts > 0)
);
