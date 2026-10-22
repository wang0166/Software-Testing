// 数据访问层：路径与出入参严格对齐 documents/接口文档.md
// mock 只在 VITE_USE_MOCK（默认 true）时兜底，后端一起来就切真接口，页面不用动
import { request, requestPage, clearTokens, getToken, isMock, setTokens, sleep, type PageData } from './http';
import { labelToCode, statusLabel, statusValue } from '../constants/roles';

export interface UserRow { id: string; username: string; name: string; dept: string; team: string; role: string; status: string }
export interface LogRow { id: string; author: string; date: string; summary: string; status: string; visible: string }
export interface StatsData { submitRate: number; unsubmitted: string[]; total: number; submitted: number }
export interface OrgUnit { id: string; name: string; parentId?: string }
export interface CompanyMatter { id: string; title: string; content: string; sortOrder: number }
export interface AuditRow { id: string; actor: string; action: string; target: string; time: string; result: string }
export interface RolePerm { roleCode: string; label: string; permissions: string[] }

/** POST /auth/login 返回体（第2节） */
export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresIn: number;
  user: { id: string; username: string; realName: string; role: string; departmentId: number | null; teamId: number | null };
}

const USER_KEY = 'pandora-user';
const ROLE_KEY = 'pandora-role';
const PERM_KEY = 'pandora-permissions';

// ---------------- mock 数据（无后端也能演示） ----------------
export const mockUsers: UserRow[] = [
  { id: 'u-01', username: 'founder', name: '创始人', dept: '总部', team: '-', role: '创始人', status: '启用' },
  { id: 'u-02', username: 'laozong_a', name: '老总A', dept: '产品部', team: '-', role: '老总', status: '启用' },
  { id: 'u-03', username: 'laozong_b', name: '老总B', dept: '技术部', team: '-', role: '老总', status: '启用' },
  { id: 'u-04', username: 'zuzhang_a', name: '组长A', dept: '产品部', team: '如来佛组', role: '组长', status: '启用' },
  { id: 'u-05', username: 'zuzhang_b', name: '组长B', dept: '产品部', team: '观音组', role: '组长', status: '启用' },
  { id: 'u-06', username: 'zuzhang_c', name: '组长C', dept: '技术部', team: '平台组', role: '组长', status: '启用' },
  { id: 'u-07', username: 'zuyuan_a', name: '组员A', dept: '产品部', team: '如来佛组', role: '组员', status: '启用' },
  { id: 'u-08', username: 'zuyuan_b', name: '组员B', dept: '产品部', team: '如来佛组', role: '组员', status: '启用' },
  { id: 'u-09', username: 'zuyuan_c', name: '组员C', dept: '技术部', team: '平台组', role: '组员', status: '停用' },
  { id: 'u-10', username: 'zuyuan_d', name: '组员D', dept: '产品部', team: '观音组', role: '组员', status: '启用' },
  { id: 'u-11', username: 'zuyuan_e', name: '组员E', dept: '产品部', team: '观音组', role: '组员', status: '启用' },
  { id: 'u-12', username: 'zuyuan_f', name: '组员F', dept: '技术部', team: '平台组', role: '组员', status: '启用' },
  { id: 'u-13', username: 'zuyuan_g', name: '组员G', dept: '技术部', team: '平台组', role: '组员', status: '启用' },
  { id: 'u-14', username: 'zuyuan_h', name: '组员H', dept: '技术部', team: '架构组', role: '组员', status: '启用' },
  { id: 'u-15', username: 'zuyuan_i', name: '组员I', dept: '产品部', team: '如来佛组', role: '组员', status: '启用' },
  { id: 'u-16', username: 'zuyuan_j', name: '组员J', dept: '产品部', team: '观音组', role: '组员', status: '启用' },
  { id: 'u-17', username: 'zuyuan_k', name: '组员K', dept: '技术部', team: '架构组', role: '组员', status: '停用' },
  { id: 'u-18', username: 'zuyuan_l', name: '组员L', dept: '技术部', team: '架构组', role: '组员', status: '启用' },
  { id: 'u-19', username: 'admin', name: '管理员', dept: '总部', team: '-', role: '管理员', status: '启用' },
  { id: 'u-20', username: 'zuyuan_m', name: '组员M', dept: '产品部', team: '如来佛组', role: '组员', status: '启用' },
];

export const mockLogs: LogRow[] = [
  { id: 'l-01', author: '组员A', date: '当天', summary: '完成首页动效设计，走查 12 处动效清单', status: '已提交', visible: '直接上级可见' },
  { id: 'l-02', author: '组员A', date: '当天', summary: '同步研发验收清单，确认本周交付项', status: '草稿', visible: '直接上级可见' },
  { id: 'l-03', author: '组员B', date: '当天', summary: '用户访谈第 5 场记录，聚焦反馈链路', status: '已提交', visible: '直接上级可见' },
  { id: 'l-04', author: '组员C', date: '当天', summary: '（未提交）', status: '未提交', visible: '-' },
  { id: 'l-05', author: '组员D', date: '当天', summary: '输出周报初稿，汇总完成率与下周三件事', status: '已提交', visible: '直接上级可见' },
  { id: 'l-06', author: '组员E', date: '当天', summary: '回访 3 家重点客户，记录导图反馈', status: '已提交', visible: '直接上级可见' },
  { id: 'l-07', author: '组员F', date: '当天', summary: '直播选品会纪要，确认排期负责人', status: '已提交', visible: '直接上级可见' },
  { id: 'l-08', author: '组员G', date: '当天', summary: '竞品走查笔记，对比三款视图页密度', status: '草稿', visible: '直接上级可见' },
  { id: 'l-09', author: '组员H', date: '当天', summary: '补充空态文案，统一引导语与按钮', status: '已提交', visible: '直接上级可见' },
  { id: 'l-10', author: '组员I', date: '当天', summary: '复盘会记录，整理结论与待办归属', status: '已提交', visible: '直接上级可见' },
  { id: 'l-11', author: '组员J', date: '当天', summary: '客服高频问题 Top10 初筛', status: '草稿', visible: '直接上级可见' },
  { id: 'l-12', author: '组员L', date: '当天', summary: '帮助文档更新，补充日志新建截图', status: '已提交', visible: '直接上级可见' },
  { id: 'l-13', author: '组员M', date: '当天', summary: '用户反馈分类，24 条归为 5 类', status: '已提交', visible: '直接上级可见' },
  { id: 'l-14', author: '组长A', date: '当天', summary: '团队日报汇总，3 人已交 2 人未交', status: '已提交', visible: '直接上级可见' },
  { id: 'l-15', author: '组长B', date: '当天', summary: '观音组排期对齐，确认本周交付', status: '已提交', visible: '直接上级可见' },
  { id: 'l-16', author: '组长C', date: '当天', summary: '平台组联调记录，3 个接口已通', status: '草稿', visible: '直接上级可见' },
  { id: 'l-17', author: '老总A', date: '当天', summary: '部门周会纪要，点评两个团队进展', status: '已提交', visible: '直接上级可见' },
  { id: 'l-18', author: '老总B', date: '当天', summary: '技术评审结论，确认架构方案', status: '已提交', visible: '直接上级可见' },
  { id: 'l-19', author: '创始人', date: '当天', summary: '全公司周报 Ren，确认下周三件大事', status: '已提交', visible: '直接上级可见' },
  { id: 'l-20', author: '组员K', date: '当天', summary: '（未提交）', status: '未提交', visible: '-' },
];

export const mockStats: StatsData = { submitRate: 80, unsubmitted: ['组员C', '组员K'], total: 20, submitted: 16 };
export const mockDepartments: OrgUnit[] = [
  { id: 'd-1', name: '总部', parentId: 'c-1' },
  { id: 'd-2', name: '产品部', parentId: 'c-1' },
  { id: 'd-3', name: '技术部', parentId: 'c-1' },
];
export const mockTeams: OrgUnit[] = [
  { id: 't-1', name: '如来佛组', parentId: 'd-2' },
  { id: 't-2', name: '观音组', parentId: 'd-2' },
  { id: 't-3', name: '平台组', parentId: 'd-3' },
  { id: 't-4', name: '架构组', parentId: 'd-3' },
];
export const mockMatters: CompanyMatter[] = [
  { id: 'm-1', title: 'Sprint2 后端骨架交付', content: '9-24 前完成登录与组织接口联调', sortOrder: 1 },
  { id: 'm-2', title: 'M2 组织管理验收', content: '用户/组织/角色页 Web 侧可用', sortOrder: 2 },
  { id: 'm-3', title: '需求 V1.0 冻结', content: '五项待确认问题闭环后冻结', sortOrder: 3 },
];
export const mockAudits: AuditRow[] = [
  { id: 'a-1', actor: 'admin', action: '创建用户', target: 'zuyuan_m / 组员M', time: '2026-10-18 10:12:00', result: '成功' },
  { id: 'a-2', actor: 'admin', action: '停用账号', target: 'zuyuan_c / 组员C', time: '2026-10-18 09:40:00', result: '成功' },
  { id: 'a-3', actor: 'admin', action: '修改配置', target: 'log_deadline=21:30', time: '2026-10-17 18:05:00', result: '成功' },
  { id: 'a-4', actor: 'admin', action: '删除团队', target: '临时组', time: '2026-10-17 15:22:00', result: '拒绝：40904 仍有成员' },
  { id: 'a-5', actor: 'zuzhang_a', action: '登录', target: '-', time: '2026-10-17 09:01:00', result: '成功' },
];
export const mockRolePerms: RolePerm[] = [
  { roleCode: 'EMPLOYEE', label: '组员', permissions: ['task:execute', 'task:self', 'content:read'] },
  { roleCode: 'TEAM_LEADER', label: '组长', permissions: ['task:dispatch', 'task:execute', 'task:self', 'content:read'] },
  { roleCode: 'DEPT_MANAGER', label: '老总', permissions: ['task:dispatch', 'task:execute', 'task:self', 'content:read'] },
  { roleCode: 'FOUNDER', label: '创始人', permissions: ['task:dispatch', 'task:execute', 'task:self', 'content:read', 'company-task:manage'] },
  { roleCode: 'ADMIN', label: '管理员', permissions: ['content:read', 'company-matter:manage'] },
];
export const mockConfigs: Record<string, string> = { log_deadline: '22:00' };

// ---------------- 接口方法 ----------------
const useMock = isMock;

/** 列表接口兼容：后端可能返回裸数组，也可能返回 {items:[...]}（文档第1.1节分页信封） */
function toItems<T>(d: unknown): T[] {
  if (Array.isArray(d)) return d as T[];
  const items = (d as { items?: T[] } | null)?.items;
  return Array.isArray(items) ? items : [];
}

export const api = {
  // ===== 第2节 认证 =====
  /** POST /auth/login —— 返回 accessToken/refreshToken/tokenType/expiresIn/user */
  async login(username: string, password: string) {
    const clean = username.trim();
    if (!clean) throw new Error('请输入登录账号（username）');
    if (!password.trim()) throw new Error('请输入密码');
    if (!useMock()) {
      const d = await request<LoginResponse>('/auth/login', { method: 'POST', body: JSON.stringify({ username: clean, password }) });
      setTokens(d.accessToken, d.refreshToken);
      localStorage.setItem(USER_KEY, d.user.realName || d.user.username);
      localStorage.setItem(ROLE_KEY, d.user.role);
      return d.user;
    }    await sleep();
    const u = mockUsers.find((x) => x.username === clean);
    if (!u) throw new Error('用户名或密码错误');
    if (u.status === '停用') throw new Error('账号已锁定或停用，请联系管理员'); // 对应 40103
    setTokens('mock-access-token', 'mock-refresh-token');
    localStorage.setItem(USER_KEY, u.name);
    localStorage.setItem(ROLE_KEY, labelToCode(u.role) ?? 'ADMIN');
    return { id: u.id, username: u.username, realName: u.name, role: labelToCode(u.role) ?? 'ADMIN', departmentId: null, teamId: null };
  },
  /** POST /auth/logout —— 幂等 */
  async logout() {
    if (!useMock() && getToken()) {
      try { await request('/auth/logout', { method: 'POST', body: JSON.stringify({ refreshToken: localStorage.getItem('pandora-refresh-token') ?? '' }) }); } catch { /* 幂等，失败也清本地 */ }
    }
    clearTokens();
    localStorage.removeItem(USER_KEY);
    localStorage.removeItem(ROLE_KEY);
  },
  /** GET /auth/me —— 返回权限码数组（api-samples 实测：permissions: [...]），存本地供页面判断 */
  async me() {
    if (useMock()) {
      return { username: localStorage.getItem(USER_KEY) ?? '', role: localStorage.getItem(ROLE_KEY) ?? 'ADMIN', permissions: [] as string[] };
    }
    const d = await request<{ id: number; username: string; realName: string; role: string; permissions?: string[] }>('/auth/me');
    localStorage.setItem(ROLE_KEY, d.role);
    localStorage.setItem(PERM_KEY, JSON.stringify(d.permissions ?? []));
    return d;
  },
  permissions(): string[] {
    try { return JSON.parse(localStorage.getItem(PERM_KEY) ?? '[]') as string[]; } catch { return []; }
  },
  currentUser() { return getToken() ? localStorage.getItem(USER_KEY) ?? '' : ''; },
  currentRole() { return localStorage.getItem(ROLE_KEY) ?? ''; },

  // ===== 第3节 用户/组织/角色权限（管理员） =====
  /** GET /users?keyword=&role=&status=&departmentId=&teamId=&page=&size= */
  async listUsers(params: { keyword?: string; role?: string; status?: string; page?: number; size?: number } = {}): Promise<PageData<UserRow>> {
    const q = new URLSearchParams({ page: String(params.page ?? 1), size: String(params.size ?? 100) });
    if (params.keyword) q.set('keyword', params.keyword);
    if (params.role) q.set('role', params.role);
    if (params.status) q.set('status', params.status);
    if (!useMock()) {
      const d = await requestPage<UserRow>(`/users?${q}`);
      return { ...d, items: d.items.map(mapUser) };
    }
    await sleep();
    const kw = (params.keyword ?? '').trim().toLowerCase();
    const roleCode = params.role ? labelToCode(params.role) : undefined;
    const items = mockUsers.filter((u) => {
      if (params.status && u.status !== params.status) return false;
      if (roleCode && labelToCode(u.role) !== roleCode) return false;
      if (!kw) return true;
      return `${u.username}${u.name}${u.dept}${u.team}${u.role}`.toLowerCase().includes(kw);
    });
    return { items, page: 1, size: 100, total: items.length };
  },
  /** POST /users —— role 传英文码，密码 BCrypt 由后端处理 */
  async createUser(p: { username: string; password: string; realName: string; role: string; departmentId?: number | null; teamId?: number | null }) {
    const role = labelToCode(p.role) ?? p.role;
    if (!useMock()) {
      return request<{ id: string }>('/users', {
        method: 'POST',
        body: JSON.stringify({ username: p.username, password: p.password, realName: p.realName, role, departmentId: p.departmentId ?? null, teamId: p.teamId ?? null }),
      });
    }
    await sleep();
    if (mockUsers.some((u) => u.username === p.username)) throw new Error('该账号已存在');
    if (mockUsers.some((u) => u.name === p.realName)) throw new Error('该姓名已存在');
    return { id: `u-local-${Date.now()}` };
  },
  /** GET /users/{id} —— 不含凭据 */
  async getUser(id: string) {
    if (!useMock()) return request<Record<string, unknown>>(`/users/${id}`);
    await sleep(150);
    const u = mockUsers.find((x) => x.id === id);
    if (!u) throw new Error('资源不存在或不可见');
    return u as unknown as Record<string, unknown>;
  },
  /** PUT /users/{id} */
  async updateUser(id: string, p: { realName?: string; role?: string; departmentId?: number | null; teamId?: number | null }) {
    if (!useMock()) return request<Record<string, unknown>>(`/users/${id}`, { method: 'PUT', body: JSON.stringify(p) });
    await sleep(150);
    return {};
  },
  /** PATCH /users/{id}/status —— 停用后登录返回 40103 */
  async setUserStatus(id: string, enabled: boolean) {
    if (!useMock()) return request<Record<string, unknown>>(`/users/${id}/status`, { method: 'PATCH', body: JSON.stringify({ status: statusValue(enabled ? '启用' : '停用') }) });
    await sleep(150);
    return {};
  },
  /** PUT /users/{id}/password —— 管理员重置密码 */
  async resetPassword(id: string, password: string) {
    if (!useMock()) return request<Record<string, unknown>>(`/users/${id}/password`, { method: 'PUT', body: JSON.stringify({ password }) });
    await sleep(150);
    return {};
  },

  // ===== 第3节 组织 =====
  /** GET /departments */
  async listDepartments(): Promise<OrgUnit[]> {
    if (!useMock()) return toItems<OrgUnit>(await request('/departments'));
    await sleep(150);
    return [...mockDepartments];
  },
  /** GET /teams */
  async listTeams(): Promise<OrgUnit[]> {
    if (!useMock()) return toItems<OrgUnit>(await request('/teams'));
    await sleep(150);
    return [...mockTeams];
  },
  async createDepartment(name: string, companyId: number) {
    if (!useMock()) return request<{ id: number }>('/departments', { method: 'POST', body: JSON.stringify({ name, companyId }) });
    await sleep(150); return { id: Date.now() };
  },
  async createTeam(name: string, departmentId: number) {
    if (!useMock()) return request<{ id: number }>('/teams', { method: 'POST', body: JSON.stringify({ name, departmentId }) });
    await sleep(150); return { id: Date.now() };
  },
  /** DELETE /departments/{id}、/teams/{id} —— 有关联成员返回 40904 */
  async deleteUnit(kind: 'departments' | 'teams', id: string) {
    if (!useMock()) return request<Record<string, never>>(`/${kind}/${id}`, { method: 'DELETE' });
    await sleep(150); return {};
  },

  // ===== 第3节 角色与权限 =====
  async listRoles(): Promise<RolePerm[]> {
    if (!useMock()) {
      const d = await request<{ code: string; permissions?: string[] }[]>('/roles');
      return toItems<{ code: string; permissions?: string[] }>(d).map((r) => ({ roleCode: r.code, label: r.code, permissions: r.permissions ?? [] }));
    }
    await sleep(150);
    return [...mockRolePerms];
  },
  async listPermissions(): Promise<{ code: string; name?: string; module?: string }[]> {
    if (!useMock()) return toItems<{ code: string; name?: string; module?: string }>(await request('/permissions'));
    await sleep(150);
    return ['task:dispatch', 'task:execute', 'task:self', 'content:read', 'company-matter:manage', 'company-task:manage'].map((code) => ({ code }));
  },
  /** PUT /roles/{code}/permissions */
  async setRolePermissions(roleCode: string, permissions: string[]) {
    if (!useMock()) return request<Record<string, never>>(`/roles/${roleCode}/permissions`, { method: 'PUT', body: JSON.stringify({ permissions }) });
    await sleep(150); return {};
  },

  // ===== 第4节 日志（管理员只读） =====
  /** GET /logs?date=&status=&authorId=&page=&size= —— 范围由服务端算，前端只筛不放宽 */
  async listLogs(params: { status?: string; authorId?: string; page?: number; size?: number } = {}): Promise<PageData<LogRow>> {
    const q = new URLSearchParams({ page: String(params.page ?? 1), size: String(params.size ?? 100) });
    if (params.status) q.set('status', params.status);
    if (params.authorId) q.set('authorId', params.authorId);
    if (!useMock()) {
      const d = await requestPage<LogRow>(`/logs?${q}`);
      return { ...d, items: d.items.map((l) => ({ ...l, status: l.status === 'SUBMITTED' ? '已提交' : l.status === 'DRAFT' ? '草稿' : l.status })) };
    }
    await sleep(280);
    const items = mockLogs.filter((l) => (params.status ? l.status === params.status : true));
    return { items, page: 1, size: 100, total: items.length };
  },

  // ===== 第6节 统计 =====
  /** GET /stats/overview —— 应提交人数、已提交人数、提交率、未提交人数 */
  async stats(): Promise<StatsData> {
    if (!useMock()) return request<StatsData>('/stats/overview');
    await sleep();
    return { ...mockStats, unsubmitted: [...mockStats.unsubmitted] };
  },
  /** GET /stats/unsubmitted —— 未提交名单（独立接口） */
  async unsubmitted(): Promise<string[]> {
    if (!useMock()) {
      const d = await request<{ items: { realName?: string; username?: string }[] }>('/stats/unsubmitted');
      return (d.items ?? []).map((x) => x.realName ?? x.username ?? '');
    }
    await sleep(200);
    return [...mockStats.unsubmitted];
  },

  // ===== 第9.2节 公司十大重要事项（仅管理员维护） =====
  /** GET /company-matters —— 实测返回 {items:[...]}，不是裸数组 */
  async listMatters(): Promise<CompanyMatter[]> {
    if (!useMock()) return toItems<CompanyMatter>(await request('/company-matters'));
    await sleep(150);
    return [...mockMatters];
  },
  async createMatter(m: { title: string; content: string; sortOrder: number }) {
    if (!useMock()) return request<{ id: number }>('/company-matters', { method: 'POST', body: JSON.stringify(m) });
    await sleep(150); return { id: Date.now() };
  },
  async updateMatter(id: string, m: { title: string; content: string; sortOrder: number }) {
    if (!useMock()) return request<Record<string, never>>(`/company-matters/${id}`, { method: 'PUT', body: JSON.stringify(m) });
    await sleep(150); return {};
  },

  // ===== 第11节 配置与审计（管理员） =====
  /** GET /configs、PUT /configs/{key} —— log_deadline 形如 21:30 */
  async getConfigs(): Promise<Record<string, string>> {
    if (!useMock()) {
      const d = await request<{ items: { key: string; value: string }[] } | Record<string, string>>('/configs');
      if (Array.isArray((d as { items?: unknown[] }).items)) {
        return Object.fromEntries((d as { items: { key: string; value: string }[] }).items.map((x) => [x.key, x.value]));
      }
      return d as Record<string, string>;
    }
    await sleep(150);
    return { ...mockConfigs };
  },  async setConfig(key: string, value: string) {
    if (!useMock()) return request<Record<string, never>>(`/configs/${key}`, { method: 'PUT', body: JSON.stringify({ value }) });
    await sleep(150); mockConfigs[key] = value; return {};
  },
  /** GET /audits —— 按操作者、动作、时间范围分页，只读 */
  async listAudits(params: { actor?: string; action?: string; page?: number; size?: number } = {}): Promise<PageData<AuditRow>> {
    const q = new URLSearchParams({ page: String(params.page ?? 1), size: String(params.size ?? 20) });
    if (params.actor) q.set('actor', params.actor);
    if (params.action) q.set('action', params.action);
    if (!useMock()) {
      const d = await requestPage<AuditRow>(`/audits?${q}`);
      return d;
    }
    await sleep(180);
    const items = mockAudits.filter((a) => (params.actor ? a.actor.includes(params.actor) : true) && (params.action ? a.action.includes(params.action) : true));
    return { items, page: 1, size: 20, total: items.length };
  },
};

// users 表返回 role 是英文码、status 是 SMALLINT，统一映射成中文展示
function mapUser(u: { realName?: string; username?: string; role?: string; status?: unknown; departmentId?: number | null; teamId?: number | null }): UserRow {
  return {
    id: String(u.username ?? ''),
    username: u.username ?? '',
    name: u.realName ?? '',
    dept: u.departmentId ? `部门${u.departmentId}` : '-',
    team: u.teamId ? `团队${u.teamId}` : '-',
    role: u.role ?? '',
    status: statusLabel(u.status),
  };
}