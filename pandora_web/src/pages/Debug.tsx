import { useState } from 'react';
import { API_BASE, getToken, isMock, request, requestPage } from '../api/http';
const PROBES = [
  { name: '当前身份', path: '/auth/me', implemented: true, paged: false },
  { name: '公司重要事项', path: '/company-matters?page=1&size=10', implemented: true, paged: true },
  { name: '用户管理', path: '/users', implemented: true, paged: true },
  { name: '公司资料', path: '/companies', implemented: true, paged: false },
  { name: '组织管理', path: '/departments', implemented: true, paged: false },
  { name: '团队管理', path: '/teams', implemented: true, paged: false },
  { name: '审计', path: '/audits', implemented: true, paged: true },
];
type Result = { ok: boolean; message: string };
export function Debug() {
  const [running, setRunning] = useState(false);
  const [results, setResults] = useState<Record<string, Result>>({});
  const run = async (p: typeof PROBES[number]): Promise<Result> => {
    try {
      const d = p.paged ? await requestPage(p.path) : await request<{ role: string; permissions: string[] }>(p.path);
      const valid = p.paged || (p.path === '/auth/me'
        ? !!d && 'role' in d && d.role === 'ADMIN' && 'permissions' in d && Array.isArray(d.permissions)
        : Array.isArray(d));
      return { ok: !!valid, message: valid ? '响应结构正确' : '响应结构不符合契约' };
    } catch (error) { return { ok: false, message: error instanceof Error ? error.message : '请求异常' }; }
  };
  const runAll = async () => {
    if (running || isMock()) return;
    setRunning(true); setResults({});
    try { for (const p of PROBES.filter(p => p.implemented)) {
      const r = await run(p); setResults(old => ({ ...old, [p.path]: r }));
      if (!getToken()) break;
    } } finally { setRunning(false); }
  };
  return <div><div className="pd-hero"><div><h2>联调自检</h2><p>检查已实现的只读接口，不修改业务数据</p></div></div>
    <div className="pd-card"><p>模式：{isMock() ? '演示（不能作为后端联调证据）' : '真实接口'} · 服务前缀：{API_BASE}</p>
      <div className="pd-row"><button className="pd-btn primary" disabled={running || isMock()} onClick={runAll}>{running ? '检查中…' : '检查已实现接口'}</button></div>
      <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>模块</th><th>接口</th><th>状态</th></tr></thead><tbody>{PROBES.map(p => <tr key={p.path}><td>{p.name}</td><td>GET {p.path}</td><td>{!p.implemented ? '当前后端未实现，不发请求' : results[p.path] ? <span className={'pd-pill ' + (results[p.path].ok ? 'green' : 'red')}>{results[p.path].message}</span> : '未检查'}</td></tr>)}</tbody></table></div>
      <p className="pd-hint">仅检查查询接口；写入流程请在对应页面验收。切换模式请退出后重新登录。</p>
    </div></div>;
}
