-- 组织、用户与刷新会话

CREATE TABLE companies (
  id         BIGSERIAL PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  founder_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE departments (
  id         BIGSERIAL PRIMARY KEY,
  company_id BIGINT NOT NULL REFERENCES companies(id) ON DELETE RESTRICT,
  name       VARCHAR(100) NOT NULL,
  manager_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ux_departments_name UNIQUE (company_id, name)
);

CREATE TABLE teams (
  id            BIGSERIAL PRIMARY KEY,
  department_id BIGINT NOT NULL REFERENCES departments(id) ON DELETE RESTRICT,
  name          VARCHAR(100) NOT NULL,
  leader_id     BIGINT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ux_teams_name UNIQUE (department_id, name)
);

CREATE TABLE users (
  id              BIGSERIAL PRIMARY KEY,
  username        VARCHAR(64) NOT NULL UNIQUE,
  password_hash   VARCHAR(100) NOT NULL,
  real_name       VARCHAR(64) NOT NULL,
  role_code       VARCHAR(32) NOT NULL,
  department_id   BIGINT REFERENCES departments(id) ON DELETE RESTRICT,
  team_id         BIGINT REFERENCES teams(id) ON DELETE RESTRICT,
  status          VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
  failed_attempts INT NOT NULL DEFAULT 0,
  locked_until    TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT chk_users_role CHECK (role_code IN ('EMPLOYEE', 'TEAM_LEADER', 'DEPT_MANAGER', 'FOUNDER', 'ADMIN')),
  CONSTRAINT chk_users_status CHECK (status IN ('ACTIVE', 'DISABLED', 'LOCKED')),
  CONSTRAINT chk_users_org_alignment CHECK (
    (role_code IN ('EMPLOYEE', 'TEAM_LEADER') AND department_id IS NOT NULL AND team_id IS NOT NULL)
    OR (role_code = 'DEPT_MANAGER' AND department_id IS NOT NULL AND team_id IS NULL)
    OR (role_code IN ('FOUNDER', 'ADMIN') AND department_id IS NULL AND team_id IS NULL)
  )
);

CREATE TABLE refresh_tokens (
  id         BIGSERIAL PRIMARY KEY,
  user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(64) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE companies ADD CONSTRAINT fk_companies_founder
  FOREIGN KEY (founder_id) REFERENCES users(id);
ALTER TABLE departments ADD CONSTRAINT fk_departments_manager
  FOREIGN KEY (manager_id) REFERENCES users(id);
ALTER TABLE teams ADD CONSTRAINT fk_teams_leader
  FOREIGN KEY (leader_id) REFERENCES users(id);

CREATE UNIQUE INDEX ux_companies_founder ON companies(founder_id) WHERE founder_id IS NOT NULL;
CREATE UNIQUE INDEX ux_departments_manager ON departments(manager_id) WHERE manager_id IS NOT NULL;
CREATE UNIQUE INDEX ux_teams_leader ON teams(leader_id) WHERE leader_id IS NOT NULL;

CREATE INDEX idx_users_role ON users(role_code);
CREATE INDEX idx_users_department ON users(department_id);
CREATE INDEX idx_users_team ON users(team_id);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires ON refresh_tokens(expires_at);
