-- CRM, HR metadata and auditable task handovers required by the mobile V2 client.

INSERT INTO permissions(code, name, module, description) VALUES
  ('crm:read', '客户档案查看', 'crm', '按组织范围查看客户、权益和业务记录'),
  ('crm:write', '客户档案维护', 'crm', '维护客户、业务记录并核销权益'),
  ('crm:sensitive:read', '敏感客户查看', 'crm', '查看标记为敏感的客户'),
  ('crm:revenue:read', '营收概览查看', 'crm', '查看按业务汇总的营收'),
  ('hr:read', '人员档案查看', 'hr', '按管理范围查看人员档案'),
  ('hr:write', '人员档案维护', 'hr', '维护人员档案元数据'),
  ('hr:contract-alert:read', '合同到期提醒查看', 'hr', '查看合同到期日期及提醒'),
  ('hr:contract:read', '合同档案查看', 'hr', '查看合同归档状态')
ON CONFLICT (code) DO NOTHING;

INSERT INTO role_permissions(role_code, permission_code) VALUES
  ('EMPLOYEE', 'crm:read'),
  ('TEAM_LEADER', 'crm:read'),
  ('DEPT_MANAGER', 'crm:read'), ('DEPT_MANAGER', 'crm:write'),
  ('FOUNDER', 'crm:read'), ('FOUNDER', 'crm:write'),
  ('FOUNDER', 'crm:sensitive:read'), ('FOUNDER', 'crm:revenue:read'),
  ('DEPT_MANAGER', 'hr:read'), ('DEPT_MANAGER', 'hr:contract-alert:read'),
  ('FOUNDER', 'hr:read'), ('FOUNDER', 'hr:write'),
  ('FOUNDER', 'hr:contract-alert:read'), ('FOUNDER', 'hr:contract:read')
ON CONFLICT DO NOTHING;

CREATE TABLE crm_customers (
  id                    BIGSERIAL PRIMARY KEY,
  name                  VARCHAR(200) NOT NULL,
  category              VARCHAR(16) NOT NULL,
  business              VARCHAR(64) NOT NULL,
  member_tier           VARCHAR(64) NOT NULL DEFAULT '普通客户',
  member_expires_at     DATE,
  masked_contact        VARCHAR(100) NOT NULL DEFAULT '',
  owner_id              BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  department_id         BIGINT REFERENCES departments(id) ON DELETE RESTRICT,
  team_id               BIGINT REFERENCES teams(id) ON DELETE RESTRICT,
  remark                VARCHAR(1000) NOT NULL DEFAULT '',
  linked_mall_member_id VARCHAR(100),
  linked_ticket_card_id VARCHAR(100),
  sensitive             BOOLEAN NOT NULL DEFAULT false,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_crm_customer_name CHECK (btrim(name) <> ''),
  CONSTRAINT chk_crm_customer_category CHECK (category IN ('PERSON', 'COMPANY')),
  CONSTRAINT fk_crm_customer_team_department FOREIGN KEY (team_id, department_id)
    REFERENCES teams(id, department_id)
);
CREATE UNIQUE INDEX ux_crm_customer_mall_member
  ON crm_customers(linked_mall_member_id) WHERE linked_mall_member_id IS NOT NULL;
CREATE UNIQUE INDEX ux_crm_customer_ticket_card
  ON crm_customers(linked_ticket_card_id) WHERE linked_ticket_card_id IS NOT NULL;
CREATE INDEX idx_crm_customer_scope ON crm_customers(department_id, team_id, owner_id);
CREATE INDEX idx_crm_customer_filters ON crm_customers(category, business, id);

CREATE TABLE crm_benefits (
  id             BIGSERIAL PRIMARY KEY,
  customer_id    BIGINT NOT NULL REFERENCES crm_customers(id) ON DELETE CASCADE,
  title          VARCHAR(200) NOT NULL,
  total_count    INTEGER NOT NULL,
  used_count     INTEGER NOT NULL DEFAULT 0,
  service_status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
  annual_card    BOOLEAN NOT NULL DEFAULT false,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_crm_benefit_title CHECK (btrim(title) <> ''),
  CONSTRAINT chk_crm_benefit_counts CHECK (total_count > 0 AND used_count BETWEEN 0 AND total_count),
  CONSTRAINT chk_crm_benefit_status CHECK (service_status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'))
);
CREATE INDEX idx_crm_benefit_customer ON crm_benefits(customer_id, id);

CREATE TABLE crm_activities (
  id                 BIGSERIAL PRIMARY KEY,
  customer_id        BIGINT NOT NULL REFERENCES crm_customers(id) ON DELETE RESTRICT,
  kind               VARCHAR(32) NOT NULL,
  title              VARCHAR(200) NOT NULL,
  status             VARCHAR(16) NOT NULL,
  activity_date      DATE NOT NULL,
  owner_id           BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  note               VARCHAR(1000) NOT NULL DEFAULT '',
  revenue_amount_fen BIGINT NOT NULL DEFAULT 0,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_crm_activity_kind CHECK (kind IN ('MALL', 'PERFORMANCE', 'BANQUET', 'VISIT', 'SALON', 'SERVICE', 'OTHER')),
  CONSTRAINT chk_crm_activity_status CHECK (status IN ('PENDING', 'IN_PROGRESS', 'COMPLETED', 'PLANNED', 'CANCELLED')),
  CONSTRAINT chk_crm_activity_title CHECK (btrim(title) <> ''),
  CONSTRAINT chk_crm_activity_revenue CHECK (revenue_amount_fen >= 0)
);
CREATE TABLE crm_activity_participants (
  activity_id BIGINT NOT NULL REFERENCES crm_activities(id) ON DELETE CASCADE,
  employee_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  PRIMARY KEY(activity_id, employee_id)
);
CREATE INDEX idx_crm_activity_customer_date ON crm_activities(customer_id, activity_date DESC, id DESC);
CREATE INDEX idx_crm_activity_participant ON crm_activity_participants(employee_id, activity_id);

CREATE TABLE hr_employee_profiles (
  user_id                 BIGINT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  duty                    VARCHAR(500) NOT NULL DEFAULT '',
  contract_end            DATE,
  contract_archive_status VARCHAR(16) NOT NULL DEFAULT 'MISSING',
  updated_by              BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_hr_contract_archive_status CHECK (contract_archive_status IN ('MISSING', 'PENDING', 'ARCHIVED'))
);
CREATE INDEX idx_hr_employee_contract_end ON hr_employee_profiles(contract_end);

CREATE TABLE task_handovers (
  id                     BIGSERIAL PRIMARY KEY,
  original_user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  original_assignment_id BIGINT NOT NULL REFERENCES task_assignments(id) ON DELETE RESTRICT,
  status                 VARCHAR(16) NOT NULL DEFAULT 'PENDING',
  new_assignee_id        BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  new_assignment_id      BIGINT REFERENCES task_assignments(id) ON DELETE RESTRICT,
  note                   VARCHAR(1000),
  deadline               TIMESTAMP,
  completed_by           BIGINT REFERENCES users(id) ON DELETE RESTRICT,
  completed_at           TIMESTAMPTZ,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ux_task_handover_assignment UNIQUE(original_assignment_id),
  CONSTRAINT chk_task_handover_status CHECK (status IN ('PENDING', 'COMPLETED')),
  CONSTRAINT chk_task_handover_completion CHECK (
    (status='PENDING' AND new_assignee_id IS NULL AND new_assignment_id IS NULL AND completed_at IS NULL)
    OR (status='COMPLETED' AND new_assignee_id IS NOT NULL AND new_assignment_id IS NOT NULL AND completed_at IS NOT NULL)
  )
);
CREATE INDEX idx_task_handover_owner_status ON task_handovers(original_user_id, status, created_at DESC);

-- Existing disabled users become visible to the handover inbox after upgrade.
INSERT INTO task_handovers(original_user_id, original_assignment_id)
SELECT a.assignee_id, a.id
FROM task_assignments a JOIN users u ON u.id=a.assignee_id
WHERE u.status='DISABLED' AND a.execution_status<>'COMPLETED'
ON CONFLICT (original_assignment_id) DO NOTHING;
