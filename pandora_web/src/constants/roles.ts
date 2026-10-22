// 角色与权限唯一真相：对照 documents/接口文档.md 第1.2/1.3节
// 注意：传输层用英文枚举码（文档 POST /users 明确 role:"TEAM_LEADER"），界面显示中文
export type RoleCode = 'EMPLOYEE' | 'TEAM_LEADER' | 'DEPT_MANAGER' | 'FOUNDER' | 'ADMIN';

export interface RoleMeta {
  code: RoleCode;
  label: string;
  icon: string;
  /** 日志可见范围（文档1.2） */
  visible: string;
  /** Web 可做（文档1.2 管理能力列） */
  can: string;
  /** 管理员在 Web 只能读日志和统计，不可提交/点评 */
  webCanEdit: boolean;
  departmentId: '必填' | '必须为空';
  teamId: '必填' | '必须为空';
  note: string;
}

// 顺序即界面展示顺序
export const ROLE_META: RoleMeta[] = [
  { code: 'EMPLOYEE', label: '组员', icon: '✏️', visible: '自己', can: '写日志', webCanEdit: false, departmentId: '必填', teamId: '必填', note: '属于一个部门下的一个团队' },
  { code: 'TEAM_LEADER', label: '组长', icon: '🧭', visible: '本队', can: '看本队', webCanEdit: false, departmentId: '必填', teamId: '必填', note: '必须是该团队的负责人' },
  { code: 'DEPT_MANAGER', label: '老总', icon: '💼', visible: '本部门', can: '看本部门', webCanEdit: false, departmentId: '必填', teamId: '必须为空', note: '一个部门只有一名，不属于任何团队' },
  { code: 'FOUNDER', label: '创始人', icon: '👑', visible: '全公司', can: '看全部', webCanEdit: false, departmentId: '必须为空', teamId: '必须为空', note: '一个公司只有一名' },
  { code: 'ADMIN', label: '管理员', icon: '🛡️', visible: '全公司只读', can: '不可提交/点评', webCanEdit: false, departmentId: '必须为空', teamId: '必须为空', note: '不属于任何部门或团队' },
];

export const ROLES = ROLE_META.map((r) => r.label);
export const ROLE_CODES = ROLE_META.map((r) => r.code);
export const PERMISSIONS: Record<string, { visible: string; can: string; webCanEdit: boolean }> = Object.fromEntries(
  ROLE_META.map((r) => [r.label, { visible: r.visible, can: r.can, webCanEdit: r.webCanEdit }]),
);

/** 中文标签 → 英文码，传给后端用 */
export function labelToCode(label: string): RoleCode | undefined {
  return ROLE_META.find((r) => r.label === label)?.code;
}
/** 英文码 → 中文标签，渲染用；不认识就原样返回 */
export function codeToLabel(code: string): string {
  return ROLE_META.find((r) => r.code === code)?.label ?? code;
}
export const ROLE_ICON: Record<string, string> = Object.fromEntries(ROLE_META.map((r) => [r.label, r.icon]));

// 文档 users.status 是 SMALLINT：1启用 0停用
export const USER_STATUS = ['启用', '停用'] as const;
export function statusLabel(v: unknown): string {
  return Number(v) === 1 || v === '启用' || v === 'ACTIVE' ? '启用' : '停用';
}
export function statusValue(label: string): 0 | 1 {
  return label === '启用' ? 1 : 0;
}

// 日志状态（文档第4节）：DRAFT / SUBMITTED，NOT_SUBMITTED 仅统计派生、不落库
export const LOG_STATUS: Record<string, string> = { DRAFT: '草稿', SUBMITTED: '已提交', NOT_SUBMITTED: '未提交' };
export function logStatusLabel(v: string): string { return LOG_STATUS[v] ?? v; }

// 权限码：来源 documents/接口文档.md 第1.3节 + documents/api-samples/auth.json 实测 /auth/me 返回
export const PERMISSION_CODES = [
  { code: 'user:manage', label: '用户管理', desc: '创建、编辑、停用账号与重置密码', defaults: 'ADMIN' },
  { code: 'org:manage', label: '组织管理', desc: '维护公司、部门、团队', defaults: 'ADMIN' },
  { code: 'role:manage', label: '角色权限管理', desc: '设置角色权限码', defaults: 'ADMIN' },
  { code: 'config:manage', label: '系统配置', desc: '修改提交截止时间等配置', defaults: 'ADMIN' },
  { code: 'audit:read', label: '审计查询', desc: '查询管理操作审计记录', defaults: 'ADMIN' },
  { code: 'log:write', label: '写日志', desc: '新建草稿、提交当日日志', defaults: 'EMPLOYEE、TEAM_LEADER、DEPT_MANAGER、FOUNDER' },
  { code: 'log:comment', label: '点评', desc: '直属上级点评、作者回复', defaults: 'TEAM_LEADER、DEPT_MANAGER、FOUNDER' },
  { code: 'task:dispatch', label: '任务派发', desc: '查询直接下级、派发、编辑任务内容、查看派发列表、检查接收人', defaults: 'TEAM_LEADER、DEPT_MANAGER、FOUNDER' },
  { code: 'task:execute', label: '任务接收', desc: '查看本人接收任务、更新本人进度、发起检查邀约', defaults: 'EMPLOYEE、TEAM_LEADER、DEPT_MANAGER、FOUNDER' },
  { code: 'task:self', label: '自建任务', desc: '新增、查看、编辑本人自建任务', defaults: 'EMPLOYEE、TEAM_LEADER、DEPT_MANAGER、FOUNDER' },
  { code: 'content:read', label: '读取展示内容', desc: '读取公司十大重要事项与公司十大重要任务', defaults: '全部角色' },
  { code: 'company-matter:manage', label: '维护重要事项', desc: '维护公司十大重要事项', defaults: 'ADMIN' },
  { code: 'company-task:manage', label: '维护重要任务', desc: '维护公司十大重要任务', defaults: 'FOUNDER' },
];