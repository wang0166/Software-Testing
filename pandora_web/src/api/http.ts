// 统一响应壳：对齐组内 design.md 约定 —— JSON、{ code, message, data }
// 服务端权威：身份/角色/组织范围/日志日期/截止/直属上级一律以后端为准，前端筛选不越权
// mock 与真接口一键切换：设 VITE_USE_MOCK=false 即走真后端（默认 mock，保证无后端也能演示）
export interface Envelope<T> { code: number; message: string; data: T }
export interface PageData<T> { list: T[]; total: number; page: number; pageSize: number }

// 分页信封约定（design.md Open Question：字段名待组内 review，这里先用 list/total/page/pageSize）
export const API_BASE = (import.meta.env.VITE_API_BASE as string | undefined) ?? '/api';
export const USE_MOCK = (import.meta.env.VITE_USE_MOCK as string | undefined) !== 'false';

const TOKEN_KEY = 'pandora-token';

export function getToken() {
  return localStorage.getItem(TOKEN_KEY) ?? '';
}

export function setToken(token: string) {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else localStorage.removeItem(TOKEN_KEY);
}

/**
 * 真接口请求：自动带 Bearer，解包 { code, message, data }
 * code === 0 视为成功；其余抛 message（比如 403 越权、409 冲突）
 * 401 清 token 并抛“登录已过期”，由页面守卫处理
 */
export async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json', ...(init.headers as Record<string, string> | undefined) };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(`${API_BASE}${path}`, { ...init, headers });
  let body: Envelope<T> | null = null;
  try {
    body = (await res.json()) as Envelope<T>;
  } catch {
    body = null;
  }
  if (res.status === 401) {
    setToken('');
    throw new Error(body?.message || '登录已过期，请重新登录');
  }
  if (!res.ok || (body && body.code !== 0)) {
    throw new Error(body?.message || `请求失败（HTTP ${res.status}）`);
  }
  return (body as Envelope<T>).data;
}

export const sleep = (ms = 200) => new Promise((r) => setTimeout(r, ms));
