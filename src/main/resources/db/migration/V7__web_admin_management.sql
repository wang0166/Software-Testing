-- 兼容旧账号与展示内容，不为历史记录补造手机号或事项时间。
ALTER TABLE users ADD COLUMN phone VARCHAR(11);
ALTER TABLE users ADD COLUMN gender VARCHAR(2);
ALTER TABLE users ADD COLUMN id_number VARCHAR(18);
ALTER TABLE users ADD COLUMN auth_version INT NOT NULL DEFAULT 0;
ALTER TABLE departments ADD COLUMN description VARCHAR(500);
ALTER TABLE teams ADD COLUMN description VARCHAR(500);
ALTER TABLE company_matters ADD COLUMN start_date TIMESTAMPTZ;
ALTER TABLE company_matters ADD COLUMN deadline TIMESTAMPTZ;
ALTER TABLE company_matters ADD CONSTRAINT chk_company_matters_hours CHECK (
  (start_date IS NULL AND deadline IS NULL) OR
  (start_date IS NOT NULL AND deadline IS NOT NULL AND deadline >= start_date
   AND date_trunc('hour', start_date AT TIME ZONE 'Asia/Shanghai') = start_date AT TIME ZONE 'Asia/Shanghai'
   AND date_trunc('hour', deadline AT TIME ZONE 'Asia/Shanghai') = deadline AT TIME ZONE 'Asia/Shanghai')
);
CREATE INDEX idx_audits_operator ON operation_audits(operator_id, created_at DESC);
