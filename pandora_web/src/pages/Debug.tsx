import { useState } from 'react';
import { API_BASE, getToken, isMock } from '../api/http';
const PROBES = [
  { name: '当前身份', path: '/auth/me', implemented: true, paged: false },
  { name: '公司重要事项', path: '/company-matters?page=1&size=10', implemented: true, paged: true },
  { name: '用户管理', path: '/users', implemented: false, paged: true },
  { name: '组织管理', path: '/departments', implemented: false, paged: false },
  { name: '角色权限', path: '/roles', implemented: false, paged: false },
  { name: '系统配置', path: '/configs', implemented: false, paged: false },
  { name: '审计', path: '/audits', implemented: false, paged: true },
];
type Result = { ok: boolean; message: string };
export function Debug() {
  const [running, setRunning] = useState(false);
  const [results, setResults] = useState<Record<string, Result>>({});
  const run = async (p: typeof PROBES[number]): Promise<Result> => {
    try {
      const res = await fetch(API_BASE + p.path, { headers: { Authorization: 'Bearer ' + getToken() } });
      const body = await res.json();
      if (!res.ok || body.code !== 0) return { ok: false, message: 'HTTP ' + res.status + ' · code=' + (body.code ?? '无') };
      const d = body.data;
      const valid = p.paged ? d && Array.isArray(d.items) && Number.isInteger(d.page) && Number.isInteger(d.size) && Number.isInteger(d.total) : d && d.role === 'ADMIN' && Array.isArray(d.permissions);
      return { ok: !!valid, message: valid ? '响应结构正确' : '响应结构不符合契约' };
    } catch { return { ok: false, message: '网络或 JSON 响应异常' }; }
  };
  const runAll = async () => {
    if (running || isMock()) return;
    setRunning(true); setResults({});
    try { for (const p of PROBES.filter(p => p.implemented)) {
      const r = await run(p); setResults(old => ({ ...old, [p.path]: r }));
    } } finally { setRunning(false); }
  };
  return <div><div className="pd-hero"><h2>🔌 联调自检</h2><p>仅检查已实现的只读接口，不修改业务数据，也不显示令牌或响应中的个人资料。</p></div>
    <div className="pd-card"><p>模式：{isMock() ? '演示（不能作为后端联调证据）' : '真实接口'} · 服务前缀：{API_BASE}</p>
      <button className="pd-btn primary" disabled={running || isMock()} onClick={runAll}>{running ? '检查中…' : '检查已实现接口'}</button>
      <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>模块</th><th>接口</th><th>状态</th></tr></thead><tbody>{PROBES.map(p => <tr key={p.path}><td>{p.name}</td><td>GET {p.path}</td><td>{!p.implemented ? '当前后端未实现，不发请求' : results[p.path] ? <span className={'pd-pill ' + (results[p.path].ok ? 'green' : 'red')}>{results[p.path].message}</span> : '未检查'}</td></tr>)}</tbody></table></div>
      <p className="pd-hint">公司事项写接口尚未实现；日志和统计已从本次 Web 范围移除。切换模式请退出后重新登录。</p>
    </div></div>;
}
