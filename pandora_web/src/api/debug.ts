export interface DebugEndpoint {
  id: string;
  group: string;
  name: string;
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';
  path: string;
}

// 自动联调按此清单报告覆盖率；团队成员复用用户列表的筛选接口。
export const DEBUG_ENDPOINTS: readonly DebugEndpoint[] = [
  { id: 'auth-me', group: '登录与会话', name: '当前管理员身份', method: 'GET', path: '/auth/me' },
  { id: 'auth-login', group: '登录与会话', name: '联调账号登录', method: 'POST', path: '/auth/login' },
  { id: 'auth-logout', group: '登录与会话', name: '注销联调账号会话', method: 'POST', path: '/auth/logout' },
  { id: 'users-list', group: '用户与成员', name: '用户列表', method: 'GET', path: '/users' },
  { id: 'team-members', group: '用户与成员', name: '团队成员', method: 'GET', path: '/users' },
  { id: 'users-get', group: '用户与成员', name: '用户详情', method: 'GET', path: '/users/{id}' },
  { id: 'users-create', group: '用户与成员', name: '新建用户', method: 'POST', path: '/users' },
  { id: 'users-update', group: '用户与成员', name: '修改用户资料', method: 'PUT', path: '/users/{id}' },
  { id: 'users-status', group: '用户与成员', name: '启用或停用账号', method: 'PATCH', path: '/users/{id}/status' },
  { id: 'users-password', group: '用户与成员', name: '重置用户密码', method: 'PUT', path: '/users/{id}/password' },
  { id: 'companies-list', group: '组织管理', name: '公司列表', method: 'GET', path: '/companies' },
  { id: 'departments-list', group: '组织管理', name: '部门列表', method: 'GET', path: '/departments' },
  { id: 'departments-create', group: '组织管理', name: '新建部门', method: 'POST', path: '/departments' },
  { id: 'departments-delete', group: '组织管理', name: '删除部门', method: 'DELETE', path: '/departments/{id}' },
  { id: 'teams-list', group: '组织管理', name: '团队列表', method: 'GET', path: '/teams' },
  { id: 'teams-create', group: '组织管理', name: '新建团队', method: 'POST', path: '/teams' },
  { id: 'teams-delete', group: '组织管理', name: '删除团队', method: 'DELETE', path: '/teams/{id}' },
  { id: 'matters-list', group: '事件纪', name: '事件纪列表', method: 'GET', path: '/company-matters' },
  { id: 'matters-create', group: '事件纪', name: '新建事件', method: 'POST', path: '/company-matters' },
  { id: 'matters-update', group: '事件纪', name: '修改事件', method: 'PUT', path: '/company-matters/{id}' },
  { id: 'audits-list', group: '日志与任务操作记录', name: '操作记录列表', method: 'GET', path: '/audits' },
  { id: 'audits-get', group: '日志与任务操作记录', name: '操作记录详情', method: 'GET', path: '/audits/{id}' },
];

const privateKey = /^(?:.*password.*|.*token.*|idnumber|phone|realname|username|actor|authorname|gender)$/i;
export function redactDebugData(value: unknown, secrets: readonly string[] = []): unknown {
  if (Array.isArray(value)) return value.map(item => redactDebugData(item, secrets));
  if (value && typeof value === 'object') {
    const record = value as Record<string, unknown>;
    const privateChange = typeof record.field === 'string' && privateKey.test(record.field.replace(/[_-]/g, ''));
    return Object.fromEntries(Object.entries(record).map(([key, item]) => [key,
      privateKey.test(key.replace(/[_-]/g, '')) || privateChange && ['before', 'after'].includes(key)
        ? item == null ? item : '[已隐藏]' : redactDebugData(item, secrets),
    ]));
  }
  if (typeof value === 'string') {
    let text = value;
    for (const secret of secrets) if (secret) text = text.split(secret).join('[已隐藏]');
    return text.replace(/\b\d{17}[\dXx]\b/g, '[证件已隐藏]').replace(/\b1\d{10}\b/g, '[手机号已隐藏]');
  }
  return value;
}
