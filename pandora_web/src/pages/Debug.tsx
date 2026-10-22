import { useState } from 'react';
import { API_BASE, getToken, isMock, setMockMode } from '../api/http';

interface Probe {
  key: string;
  name: string;
  method: string;
  path: string;
  group: string;
  needAuth?: boolean;
  body?: string;
  /** 期望成功的判定：HTTP 2xx 且 code===0 */
  expect: string;
}

// 覆盖 documents/接口文档.md 里管理员用得到的全部接口
const PROBES: Probe[] = [
  { key: 'login', name: '登录', method: 'POST', path: '/auth/login', group: '认证', body: '{"username":"admin","password":"123456"}', expect: '200 + accessToken' },
  { key: 'me', name: '当前账号', method: 'GET', path: '/auth/me', group: '认证', needAuth: true, expect: '200 + role' },
  { key: 'users', name: '用户列表', method: 'GET', path: '/users?page=1&size=10', group: '用户/组织', needAuth: true, expect: '200 + items[]' },
  { key: 'departments', name: '部门列表', method: 'GET', path: '/departments', group: '用户/组织', needAuth: true, expect: '200' },
  { key: 'teams', name: '团队列表', method: 'GET', path: '/teams', group: '用户/组织', needAuth: true, expect: '200' },
  { key: 'roles', name: '角色列表', method: 'GET', path: '/roles', group: '用户/组织', needAuth: true, expect: '200' },
  { key: 'permissions', name: '权限码清单', method: 'GET', path: '/permissions', group: '用户/组织', needAuth: true, expect: '200' },
  { key: 'logs', name: '日志只读', method: 'GET', path: '/logs?page=1&size=10', group: '日志', needAuth: true, expect: '200 + items[]' },
  { key: 'stats', name: '统计总览', method: 'GET', path: '/stats/overview', group: '统计', needAuth: true, expect: '200 + submitRate' },
  { key: 'unsub', name: '未提交名单', method: 'GET', path: '/stats/unsubmitted', group: '统计', needAuth: true, expect: '200' },
  { key: 'matters', name: '公司重要事项', method: 'GET', path: '/company-matters', group: '展示内容', needAuth: true, expect: '200' },
  { key: 'configs', name: '系统配置', method: 'GET', path: '/configs', group: '配置/审计', needAuth: true, expect: '200' },
  { key: 'audits', name: '审计记录', method: 'GET', path: '/audits?page=1&size=10', group: '配置/审计', needAuth: true, expect: '200 + items[]' },
];

type Result = { status?: number; code?: number; message?: string; ms: number; ok: boolean; raw: string; err?: string };

export function Debug() {
  const [results, setResults] = useState<Record<string, Result>>({});
  const [running, setRunning] = useState(false);
  const [token, setToken] = useState(getToken());
  const [mockNow, setMockNow] = useState(isMock());

  const runOne = async (p: Probe) => {
    const t0 = performance.now();
    try {
      const headers: Record<string, string> = { 'Content-Type': 'application/json' };
      const tk = getToken();
      if (tk && p.needAuth !== false) headers.Authorization = `Bearer ${tk}`;
      const res = await fetch(`${API_BASE}${p.path}`, {
        method: p.method,
        headers,
        body: p.body,
      });
      const ms = Math.round(performance.now() - t0);
      const text = await res.text();
      let code: number | undefined;
      let message: string | undefined;
      try {
        const j = JSON.parse(text) as { code?: number; message?: string };
        code = j.code;
        message = j.message;
      } catch {
        /* 不是 JSON，说明后端没按统一壳返回 */
      }
      const ok = res.ok && (code === undefined ? true : code === 0);
      return { status: res.status, code, message, ms, ok, raw: text.slice(0, 400) } as Result;
    } catch (e) {
      const ms = Math.round(performance.now() - t0);
      return { ms, ok: false, raw: '', err: e instanceof Error ? e.message : '请求失败' } as Result;
    }
  };

  const runAll = async () => {
    setRunning(true);
    setResults({});
    // 顺序跑，登录放最前，避免令牌还没拿到
    for (const p of PROBES) {
      const r = await runOne(p);
      setResults((m) => ({ ...m, [p.key]: r }));
    }
    setRunning(false);
  };

  const runSingle = async (p: Probe) => {
    setResults((m) => ({ ...m, [p.key]: undefined as unknown as Result }));
    const r = await runOne(p);
    setResults((m) => ({ ...m, [p.key]: r }));
  };

  const groups = Array.from(new Set(PROBES.map((p) => p.group)));
  const done = Object.values(results).filter(Boolean);
  const pass = done.filter((r) => r.ok).length;

  return (
    <div>
      <div className="pd-hero">
        <h2>🔌 联调自检</h2>
        <p>点一下把所有接口跑一遍，看哪条通、哪条不通、返回什么。周四联调先跑这个。</p>
        <div className="pd-hero-chips">
          <span className="pd-hero-chip">模式：{mockNow ? 'Mock（未连后端）' : '真接口'}</span>
          <span className="pd-hero-chip">前缀：{API_BASE}</span>
          <span className="pd-hero-chip">已测 {done.length}/{PROBES.length}</span>
          <span className="pd-hero-chip">通过 {pass}</span>
        </div>
      </div>

      {mockNow && (
        <div className="pd-card" style={{ borderColor: '#ffd4d6', background: '#fff8f8' }}>
          <b style={{ color: 'var(--danger)' }}>⚠ 现在是演示模式（Mock），自检页不会真的请求后端。</b>
          <p className="pd-hint" style={{ margin: '6px 0 10px' }}>
            点下面按钮切到真接口模式，再重新登录一次即可。
          </p>
          <button className="pd-btn primary" onClick={() => { setMockMode(false); setMockNow(false); }}>切到真接口模式</button>
        </div>
      )}

      <div className="pd-card">
        <div className="pd-card-head">
          <h3 className="pd-sub">测试项</h3>
          <span>
            <button className="pd-btn primary" onClick={runAll} disabled={running}>{running ? '测试中…' : '▶ 全部跑一遍'}</button>
          </span>
        </div>
        <div className="pd-row">
          <span className="pd-hint" style={{ margin: 0 }}>当前令牌：</span>
          <input className="pd-input pd-grow" value={token} onChange={(e) => setToken(e.target.value)} placeholder="自动从登录态读取" readOnly />
        </div>
        {groups.map((g) => (
          <div key={g} style={{ marginBottom: 14 }}>
            <div className="pd-hint" style={{ fontWeight: 800, margin: '10px 0 6px' }}>{g}</div>
            <div className="pd-scroll-x">
              <table className="pd-table">
                <thead><tr><th>接口</th><th>方法</th><th>路径</th><th>期望</th><th>结果</th><th>耗时</th><th></th></tr></thead>
                <tbody>
                  {PROBES.filter((p) => p.group === g).map((p) => {
                    const r = results[p.key];
                    return (
                      <tr key={p.key}>
                        <td style={{ fontWeight: 700 }}>{p.name}</td>
                        <td><span className="pd-pill">{p.method}</span></td>
                        <td style={{ fontFamily: 'monospace', fontSize: 12.5 }}>{p.path}</td>
                        <td><span className="pd-hint" style={{ margin: 0 }}>{p.expect}</span></td>
                        <td>
                          {!r ? <span className="pd-hint" style={{ margin: 0 }}>未测</span>
                            : r.err ? <span className="pd-pill red">网络错误</span>
                              : r.ok ? <span className="pd-pill green">HTTP {r.status} · code={r.code ?? '无'}</span>
                                : <span className="pd-pill red">HTTP {r.status} · code={r.code ?? '非JSON'}</span>}
                        </td>
                        <td>{r?.ms != null ? `${r.ms}ms` : '-'}</td>
                        <td><button className="pd-btn" onClick={() => runSingle(p)}>单测</button></td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        ))}
      </div>

      {done.length > 0 && (
        <div className="pd-card">
          <h3 className="pd-sub">返回详情（排查用）</h3>
          <p className="pd-hint" style={{ marginTop: 6 }}>哪条红了就看这里，message 一般是后端的报错原因。</p>
          {PROBES.filter((p) => results[p.key]).map((p) => {
            const r = results[p.key];
            return (
              <div key={p.key} style={{ borderTop: '1px solid var(--line)', padding: '10px 0' }}>
                <div style={{ fontWeight: 800, marginBottom: 4 }}>
                  {r.ok ? '✅' : '❌'} {p.method} {p.path}
                  {r.message && <span className="pd-hint" style={{ marginLeft: 8 }}>{r.message}</span>}
                </div>
                {r.err && <div className="pd-err">{r.err}</div>}
                {r.raw && <pre style={{ background: '#f7f6ff', padding: 10, borderRadius: 10, overflow: 'auto', fontSize: 12, margin: 0 }}>{r.raw}</pre>}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}