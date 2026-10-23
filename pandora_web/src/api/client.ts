// 数据访问层依据 documents/后端接口文档.md 与实际控制器实现核对。
// 仅主动开启的演示模式使用 mock；真实模式不兜底，不调用尚未实现的管理接口。
import { request, requestPage, clearTokens, getToken, getRefreshToken, isMock, setTokens, sleep, type PageData } from './http';
import { requireCapability } from './capabilities';
import { labelToCode, codeToLabel, PERMISSION_CODES, statusLabel, statusValue } from '../constants/roles';

export interface UserRow { id: string; username: string; name: string; dept: string; team: string; role: string; status: string; idNumber?: string; gender?: string; phone?: string }
export interface OrgUnit { id: string; name: string; parentId?: string; description?: string }
/** 公司十大事项：title=名字，content=备注，deadline=截止日期（YYYY-MM-DD），派发后全员手机端可见 */
export interface CompanyMatter { id: string; title: string; content: string; sortOrder: number; deadline?: string }
export interface AuditRow { id: string; actor: string; action: string; target: string; time: string; result: string }
export interface RolePerm { roleCode: string; label: string; permissions: string[] }

/** POST /auth/login 返回体（第2节） */
export interface LoginResponse {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  expiresIn: number;
  user: { id: string; username: string; realName: string; role: string; permissions?: string[]; departmentId: number | null; teamId: number | null };
}

const USER_KEY = 'pandora-user';
const ROLE_KEY = 'pandora-role';
const PERM_KEY = 'pandora-permissions';

// ---------------- mock 数据（无后端也能演示） ----------------
export const mockUsers: UserRow[] = [
  { id: 'u-01', username: 'founder', name: '创始人', dept: '总部', team: '-', role: '创始人', status: '启用', gender: '男', phone: '13800000001', idNumber: '110101199001011234' },
  { id: 'u-02', username: 'laozong_a', name: '老总A', dept: '产品部', team: '-', role: '老总', status: '启用', gender: '男', phone: '13800000002', idNumber: '110101199102022345' },
  { id: 'u-03', username: 'laozong_b', name: '老总B', dept: '技术部', team: '-', role: '老总', status: '启用', gender: '女', phone: '13800000003', idNumber: '110101199203033456' },
  { id: 'u-04', username: 'zuzhang_a', name: '组长A', dept: '产品部', team: '如来佛组', role: '组长', status: '启用', gender: '男', phone: '13800000004', idNumber: '110101199304044567' },
  { id: 'u-05', username: 'zuzhang_b', name: '组长B', dept: '产品部', team: '观音组', role: '组长', status: '启用', gender: '女', phone: '13800000005', idNumber: '110101199405055678' },
  { id: 'u-06', username: 'zuzhang_c', name: '组长C', dept: '技术部', team: '平台组', role: '组长', status: '启用', gender: '男', phone: '13800000006', idNumber: '110101199506066789' },
  { id: 'u-07', username: 'zuyuan_a', name: '组员A', dept: '产品部', team: '如来佛组', role: '组员', status: '启用', gender: '男', phone: '13900000001', idNumber: '110101199607077890' },
  { id: 'u-08', username: 'zuyuan_b', name: '组员B', dept: '产品部', team: '如来佛组', role: '组员', status: '启用', gender: '女', phone: '13900000002', idNumber: '110101199708088901' },
  { id: 'u-09', username: 'zuyuan_c', name: '组员C', dept: '技术部', team: '平台组', role: '组员', status: '停用', gender: '男', phone: '13900000003', idNumber: '110101199809099012' },
  { id: 'u-10', username: 'zuyuan_d', name: '组员D', dept: '产品部', team: '观音组', role: '组员', status: '启用', gender: '女', phone: '13900000004', idNumber: '110101199910101123' },
  { id: 'u-11', username: 'zuyuan_e', name: '组员E', dept: '产品部', team: '观音组', role: '组员', status: '启用', gender: '男', phone: '13900000005', idNumber: '110101200001011234' },
  { id: 'u-12', username: 'zuyuan_f', name: '组员F', dept: '技术部', team: '平台组', role: '组员', status: '启用', gender: '女', phone: '13900000006', idNumber: '110101200102022345' },
  { id: 'u-13', username: 'zuyuan_g', name: '组员G', dept: '技术部', team: '平台组', role: '组员', status: '启用', gender: '男', phone: '13900000007', idNumber: '110101200203033456' },
  { id: 'u-14', username: 'zuyuan_h', name: '组员H', dept: '技术部', team: '架构组', role: '组员', status: '启用', gender: '男', phone: '13900000008', idNumber: '110101200304044567' },
  { id: 'u-15', username: 'zuyuan_i', name: '组员I', dept: '产品部', team: '如来佛组', role: '组员', status: '启用', gender: '女', phone: '13900000009', idNumber: '110101200405055678' },
  { id: 'u-16', username: 'zuyuan_j', name: '组员J', dept: '产品部', team: '观音组', role: '组员', status: '启用', gender: '男', phone: '13900000010', idNumber: '110101200506066789' },
  { id: 'u-17', username: 'zuyuan_k', name: '组员K', dept: '技术部', team: '架构组', role: '组员', status: '停用', gender: '男', phone: '13900000011', idNumber: '110101200607077890' },
  { id: 'u-18', username: 'zuyuan_l', name: '组员L', dept: '技术部', team: '架构组', role: '组员', status: '启用', gender: '女', phone: '13900000012', idNumber: '110101200708088901' },
  { id: 'u-19', username: 'admin', name: '管理员', dept: '总部', team: '-', role: '管理员', status: '启用', gender: '男', phone: '13800000000', idNumber: '110101199001010000' },
  { id: 'u-20', username: 'zuyuan_m', name: '组员M', dept: '产品部', team: '如来佛组', role: '组员', status: '启用', gender: '男', phone: '13900000013', idNumber: '110101200809099012' },
];

export const mockDepartments: OrgUnit[] = [
  { id: '1', name: '总部', parentId: '1', description: '公司总部，统筹全局战略与经营管理' },
  { id: '2', name: '产品部', parentId: '1', description: '负责产品设计、需求分析与用户体验' },
  { id: '3', name: '技术部', parentId: '1', description: '负责系统研发、架构设计与运维保障' },
];
export const mockTeams: OrgUnit[] = [
  { id: '1', name: '如来佛组', parentId: '2', description: '主打核心业务功能的产品打磨' },
  { id: '2', name: '观音组', parentId: '2', description: '负责增长与用户运营侧产品' },
  { id: '3', name: '平台组', parentId: '3', description: '负责基础平台与服务端开发' },
  { id: '4', name: '架构组', parentId: '3', description: '负责技术架构选型与攻坚' },
];
export const mockMatters: CompanyMatter[] = [
  { id: 'm-1', title: 'Sprint2 后端骨架交付', content: '完成登录与组织接口联调', sortOrder: 1, deadline: '2026-11-15' },
  { id: 'm-2', title: 'M2 组织管理验收', content: '用户/组织/角色页 Web 侧可用', sortOrder: 2, deadline: '2026-11-30' },
  { id: 'm-3', title: '需求 V1.0 冻结', content: '五项待确认问题闭环后冻结', sortOrder: 3, deadline: '2026-12-10' },
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
  { roleCode: 'ADMIN', label: '管理员', permissions: ['user:manage', 'org:manage', 'role:manage', 'config:manage', 'audit:read', 'content:read', 'company-matter:manage'] },
];
export const mockConfigs: Record<string, string> = { log_deadline: '22:00' };

// ---------------- 接口方法 ----------------
const useMock = isMock;
const mockPerms = () => mockRolePerms.find(r => r.roleCode === localStorage.getItem(ROLE_KEY))?.permissions ?? [];
function saveIdentity(u: CurrentUser) {
  localStorage.setItem(USER_KEY, u.realName || u.username);
  localStorage.setItem(ROLE_KEY, u.role);
  localStorage.setItem(PERM_KEY, JSON.stringify(u.permissions ?? []));
}
export interface CurrentUser {
  id?: number | string; username: string; realName?: string; role: string;
  departmentId?: number | null; teamId?: number | null; permissions?: string[];
}
function pageOf<T>(items: T[], page = 1, size = 20): PageData<T> {
  return { items: items.slice((page - 1) * size, page * size), page, size, total: items.length };
}
export const api = {
  async login(username: string, password: string) {
    clearTokens();
    const clean = username.trim();
    if (!clean || !password.trim()) throw new Error('请输入账号和密码');
    if (!useMock()) {
      const d = await request<LoginResponse>('/auth/login', { method: 'POST', body: JSON.stringify({ username: clean, password }) });
      if (!d?.accessToken || d.user?.role !== 'ADMIN') throw new Error('此管理端仅允许管理员登录，请使用移动端');
      setTokens(d.accessToken, d.refreshToken);
      saveIdentity(d.user);
      return d.user;
    }
    await sleep();
    const u = mockUsers.find(x => x.username === clean);
    if (!u || u.status !== '启用') throw new Error('演示账号不存在或已停用');
    if (labelToCode(u.role) !== 'ADMIN') throw new Error('此管理端仅允许管理员登录');
    setTokens('mock-access-token', 'mock-refresh-token');
    const user = { id: u.id, username: u.username, realName: u.name, role: 'ADMIN',
      permissions: mockRolePerms.find(r => r.roleCode === 'ADMIN')?.permissions ?? [] };
    saveIdentity(user);
    return user;
  },
  async logout() {
    try {
      if (!useMock() && getToken()) await request('/auth/logout', {
        method: 'POST', body: JSON.stringify({ refreshToken: getRefreshToken() }),
      });
    } finally { clearTokens(); }
  },
  async me(): Promise<CurrentUser> {
    if (useMock()) return { username: localStorage.getItem(USER_KEY) ?? '', role: localStorage.getItem(ROLE_KEY) ?? '', permissions: mockPerms() };
    const user = await request<CurrentUser>('/auth/me');
    if (!user || user.role !== 'ADMIN') {
      clearTokens();
      throw new Error('此管理端仅允许管理员登录');
    }
    saveIdentity(user);
    return user;
  },
  permissions(): string[] {
    try { const p: unknown = JSON.parse(localStorage.getItem(PERM_KEY) ?? '[]'); return Array.isArray(p) ? p.filter((x): x is string => typeof x === 'string') : []; }
    catch { return []; }
  },
  currentUser() { return getToken() ? localStorage.getItem(USER_KEY) ?? '' : ''; },
  currentRole() { return localStorage.getItem(ROLE_KEY) ?? ''; },
  async listUsers(params: { keyword?: string; role?: string; status?: string; page?: number; size?: number } = {}): Promise<PageData<UserRow>> {
    requireCapability('users');
    const page = params.page ?? 1, size = params.size ?? 20;
    const q = new URLSearchParams({ page: String(page), size: String(size) });
    if (params.keyword) q.set('keyword', params.keyword);
    if (params.role) q.set('role', labelToCode(params.role) ?? params.role);
    if (params.status) q.set('status', String(statusValue(params.status)));
    if (!useMock()) {
      const d = await requestPage<RawUser>('/users?' + q);
      return { ...d, items: d.items.map(mapUser) };
    }
    await sleep();
    const key = (params.keyword ?? '').trim().toLowerCase();
    return pageOf(mockUsers.filter(u => (!params.role || u.role === params.role) &&
      (!params.status || u.status === params.status) &&
      (!key || (u.username + u.name + u.dept + u.team).toLowerCase().includes(key))), page, size);
  },
  async createUser(p: { username: string; password: string; realName: string; role: string; departmentId?: number | null; teamId?: number | null; idNumber?: string; gender?: string; phone?: string }) {
    requireCapability('users');
    if (!useMock()) return request<{ id: string }>('/users', { method: 'POST', body: JSON.stringify({ ...p, role: labelToCode(p.role) ?? p.role }) });
    await sleep();
    if (mockUsers.some(u => u.username === p.username)) throw new Error('该账号已存在');
    return { id: 'u-local-' + Date.now() };
  },
  async getUser(id: string) {
    requireCapability('users');
    if (!useMock()) return mapUser(await request<RawUser>('/users/' + encodeURIComponent(id)));
    const u = mockUsers.find(x => x.id === id);
    if (!u) throw new Error('用户不存在');
    return { ...u };
  },
  async updateUser(id: string, p: { realName?: string; role?: string; departmentId?: number | null; teamId?: number | null }) {
    requireCapability('users');
    if (!useMock()) return request('/users/' + encodeURIComponent(id), { method: 'PUT', body: JSON.stringify({ ...p, role: p.role ? labelToCode(p.role) ?? p.role : undefined }) });
    await sleep();
  },
  async setUserStatus(id: string, enabled: boolean) {
    requireCapability('users');
    if (!useMock()) return request('/users/' + encodeURIComponent(id) + '/status', { method: 'PATCH', body: JSON.stringify({ status: enabled ? 1 : 0 }) });
    await sleep();
  },
  async resetPassword(id: string, password: string) {
    requireCapability('users');
    if (!useMock()) return request('/users/' + encodeURIComponent(id) + '/password', { method: 'PUT', body: JSON.stringify({ password }) });
    await sleep();
  },
  async listDepartments(): Promise<OrgUnit[]> {
    requireCapability('organization');
    if (!useMock()) return toUnits(await request('/departments'), 'companyId');
    await sleep(); return mockDepartments.map(x => ({ ...x }));
  },
  async listTeams(): Promise<OrgUnit[]> {
    requireCapability('organization');
    if (!useMock()) return toUnits(await request('/teams'), 'departmentId');
    await sleep(); return mockTeams.map(x => ({ ...x }));
  },
  async createDepartment(name: string, companyId: number, description?: string) {
    requireCapability('organization');
    if (!useMock()) return request<{ id: number }>('/departments', { method: 'POST', body: JSON.stringify({ name, companyId, description }) });
    const id = Date.now(); mockDepartments.push({ id: String(id), name, parentId: String(companyId), description }); return { id };
  },
  async createTeam(name: string, departmentId: number, description?: string) {
    requireCapability('organization');
    if (!useMock()) return request<{ id: number }>('/teams', { method: 'POST', body: JSON.stringify({ name, departmentId, description }) });
    const id = Date.now(); mockTeams.push({ id: String(id), name, parentId: String(departmentId), description }); return { id };
  },
  async deleteUnit(kind: 'departments' | 'teams', id: string) {
    requireCapability('organization');
    if (!useMock()) return request('/' + kind + '/' + encodeURIComponent(id), { method: 'DELETE' });
    const units = kind === 'departments' ? mockDepartments : mockTeams;
    const unit = units.find(u => u.id === id);
    if (!unit) throw new Error('组织不存在');
    const hasMembers = mockUsers.some(u => (kind === 'departments' ? u.dept : u.team) === unit.name);
    if (hasMembers || (kind === 'departments' && mockTeams.some(t => t.parentId === id))) throw new Error('组织仍有下属组织或成员，不能删除');
    units.splice(units.indexOf(unit), 1);
  },
  async listRoles(): Promise<RolePerm[]> {
    requireCapability('roles');
    if (!useMock()) return toItems<{ code: string; permissions: string[] }>(await request('/roles')).map(r => ({ roleCode: r.code, label: codeToLabel(r.code), permissions: r.permissions }));
    return mockRolePerms.map(r => ({ ...r, permissions: [...r.permissions] }));
  },
  async listPermissions() {
    requireCapability('roles');
    if (!useMock()) return toItems<{ code: string; name?: string; module?: string }>(await request('/permissions'));
    return PERMISSION_CODES.map(p => ({ code: p.code, name: p.label }));
  },
  async setRolePermissions(roleCode: string, permissions: string[]) {
    requireCapability('roles');
    if (!useMock()) return request('/roles/' + encodeURIComponent(roleCode) + '/permissions', { method: 'PUT', body: JSON.stringify({ permissions }) });
    const r = mockRolePerms.find(x => x.roleCode === roleCode);
    if (r) r.permissions = [...permissions];
  },
  async listMatters(page = 1, size = 20): Promise<PageData<CompanyMatter>> {
    if (!useMock()) {
      const d = await requestPage<CompanyMatter>('/company-matters?page=' + page + '&size=' + size);
      return { ...d, items: d.items.map(x => ({ ...x, id: String(x.id) })) };
    }
    await sleep();
    return pageOf([...mockMatters].sort((a, b) => a.sortOrder - b.sortOrder), page, size);
  },
  async createMatter(m: { title: string; content: string; sortOrder: number; deadline?: string }) {
    requireCapability('matterWrite');
    if (!useMock()) return request<{ id: number }>('/company-matters', { method: 'POST', body: JSON.stringify(m) });
    const id = Date.now(); mockMatters.push({ ...m, id: String(id) }); return { id };
  },
  async updateMatter(id: string, m: { title: string; content: string; sortOrder: number; deadline?: string }) {
    requireCapability('matterWrite');
    if (!useMock()) return request('/company-matters/' + encodeURIComponent(id), { method: 'PUT', body: JSON.stringify(m) });
    const i = mockMatters.findIndex(x => x.id === id);
    if (i < 0) throw new Error('事项不存在');
    mockMatters[i] = { ...m, id };
  },
  async getConfigs(): Promise<Record<string, string>> {
    requireCapability('config');
    if (!useMock()) {
      const d = await request<Record<string, string> | { items: { key: string; value: string }[] }>('/configs');
      if ('items' in d && Array.isArray(d.items)) return Object.fromEntries(d.items.map(x => [x.key, x.value]));
      return d as Record<string, string>;
    }
    return { ...mockConfigs };
  },
  async setConfig(key: string, value: string) {
    requireCapability('config');
    if (!useMock()) return request('/configs/' + encodeURIComponent(key), { method: 'PUT', body: JSON.stringify({ value }) });
    mockConfigs[key] = value;
  },
  async listAudits(params: { actor?: string; action?: string; page?: number; size?: number } = {}): Promise<PageData<AuditRow>> {
    requireCapability('audits');
    const page = params.page ?? 1, size = params.size ?? 20;
    if (!useMock()) {
      const q = new URLSearchParams({ page: String(page), size: String(size) });
      if (params.actor) q.set('actor', params.actor);
      if (params.action) q.set('action', params.action);
      return requestPage<AuditRow>('/audits?' + q);
    }
    return pageOf(mockAudits.filter(a => (!params.actor || a.actor.includes(params.actor)) && (!params.action || a.action.includes(params.action))), page, size);
  },
};
function toItems<T>(d: unknown): T[] {
  if (Array.isArray(d)) return d as T[];
  if (d && typeof d === 'object' && 'items' in d && Array.isArray(d.items)) return d.items as T[];
  throw new Error('列表响应格式不正确');
}
function toUnits(d: unknown, parent: 'companyId' | 'departmentId'): OrgUnit[] {
  return toItems<{ id: number; name: string; description?: string; companyId?: number; departmentId?: number }>(d)
    .map(u => ({ id: String(u.id), name: u.name, description: u.description, parentId: u[parent] == null ? undefined : String(u[parent]) }));
}
interface RawUser {
  id: number | string; username: string; realName: string; role: string; status: unknown;
  departmentId?: number | null; teamId?: number | null; departmentName?: string; teamName?: string;
}
function mapUser(u: RawUser): UserRow {
  return { id: String(u.id), username: u.username, name: u.realName, role: codeToLabel(u.role),
    dept: u.departmentName ?? (u.departmentId == null ? '-' : '部门' + u.departmentId),
    team: u.teamName ?? (u.teamId == null ? '-' : '团队' + u.teamId), status: statusLabel(u.status) };
}
