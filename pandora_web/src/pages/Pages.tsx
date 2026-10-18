import { useMemo, useState } from 'react';
import { api, type LogRow } from '../api/client';
import { PERMISSIONS, ROLES } from '../constants/roles';
import { useAsync, useDebounce } from '../hooks/hooks';
import { clearOpLog, downloadCSV, readOpLog } from '../utils/export';
import { Empty, Ring, Skeleton, StatCard, useToast } from '../components/ui';

const PAGE_SIZE = 6;
const roleIcon: Record<string, string> = { 创始人: '👑', 老总: '💼', 组长: '🧭', 组员: '✏️', 管理员: '🛡️' };

// ---------------- 组织 / 角色 / 配置 ----------------
export function Org() {
  const [open, setOpen] = useState<string[]>(['潘多拉公司']);
  const toggle = (name: string) => setOpen((o) => (o.includes(name) ? o.filter((x) => x !== name) : [...o, name]));
  const tree = [
    { name: '潘多拉公司', icon: '🏢', count: 2, children: ['总部：创始人、管理员'] },
    { name: '产品部', icon: '📦', count: 10, children: ['如来佛组：老总A、组长A、组员A、组员B、组员I、组员M（6 人）', '观音组：组长B、组员D、组员E、组员J（4 人）'] },
    { name: '技术部', icon: '💻', count: 8, children: ['平台组：老总B、组长C、组员C、组员F、组员G（5 人）', '架构组：组员H、组员K、组员L（3 人）'] },
  ];
  return (
    <div>
      <div className="pd-hero">
        <h2>🏢 组织 / 角色 / 配置</h2>
        <p>公司→部门→团队→员工，一队一个组长，一人一种身份。对照 US-05/28/29。</p>
        <div className="pd-hero-chips">
          <span className="pd-hero-chip">1 公司</span><span className="pd-hero-chip">3 部门</span>
          <span className="pd-hero-chip">4 团队</span><span className="pd-hero-chip">20 成员</span>
        </div>
      </div>
      <div className="pd-stats">
        <StatCard icon="🏢" value={1} label="公司" />
        <StatCard icon="📦" value={3} label="部门（含总部）" tone={2} delay={0.05} />
        <StatCard icon="👨‍👩‍👧" value={4} label="团队" tone={3} delay={0.1} />
        <StatCard icon="🧑‍💻" value={20} label="成员" tone={4} delay={0.15} />
      </div>
      <div className="pd-card">
        <h3 className="pd-sub">🌳 组织结构</h3>
        <p className="pd-hint" style={{ marginTop: 6 }}>静态先行，接真数据后改 GET /api/org，点部门可展开。</p>
        {tree.map((n) => (
          <div className="pd-tree-node" key={n.name}>
            <button className="pd-tree-toggle" onClick={() => toggle(n.name)}>
              <span>{n.icon} {n.name} <span className="pd-pill" style={{ marginLeft: 6 }}>{n.count} 人</span></span>
              <span>{open.includes(n.name) ? '▾' : '▸'}</span>
            </button>
            {open.includes(n.name) && <ul className="pd-tree-list">{n.children.map((c) => <li key={c}>{c}</li>)}</ul>}
          </div>
        ))}
      </div>
      <div className="pd-card">
        <h3 className="pd-sub">🛡️ 角色权限 <span className="pd-pill orange">管理员 Web 只读</span></h3>
        <p className="pd-hint" style={{ marginTop: 6 }}>5 类角色可见范围与可做操作，管理员在 Web 不可提交/点评。</p>
        <div className="pd-role-grid">
          {ROLES.map((r) => (
            <div key={r} className={`pd-role-card ${r === '管理员' ? 'hi' : ''}`}>
              <div className="ico">{roleIcon[r] ?? '👤'}</div>
              <div className="name">{r}</div>
              <div><span className="pd-pill">可见 · {PERMISSIONS[r].visible}</span></div>
              <div style={{ marginTop: 6 }}><span className={`pd-pill ${r === '管理员' ? 'red' : 'green'}`}>可做 · {PERMISSIONS[r].can}</span></div>
            </div>
          ))}
        </div>
      </div>
      <div className="pd-card">
        <h3 className="pd-sub">⚙️ 系统配置 <span className="pd-pill">待 PUT /api/configs · Sprint8</span></h3>
        <p className="pd-hint" style={{ marginTop: 6 }}>提交截止时间默认 22:00，管理员可改。当前本地演示，不可保存。</p>
        <div className="pd-row" style={{ marginBottom: 0 }}>
          <span>截止时间</span>
          <input className="pd-input" defaultValue="22:00" disabled />
          <button className="pd-btn" disabled title="等配置接口">保存（待接口）</button>
        </div>
      </div>
    </div>
  );
}

// ---------------- 日志只读 ----------------
export function Logs() {
  const { data, loading, error } = useAsync(api.listLogs);
  const [q, setQ] = useState('');
  const [statusFilter, setStatusFilter] = useState('全部');
  const [page, setPage] = useState(1);
  const dq = useDebounce(q);
  const toast = useToast();
  const rows: LogRow[] = useMemo(() => {
    const base = data ?? [];
    const key = dq.trim().toLowerCase();
    return base.filter((l) => {
      if (statusFilter !== '全部' && l.status !== statusFilter) return false;
      if (!key) return true;
      return `${l.author}${l.summary}`.toLowerCase().includes(key);
    });
  }, [data, dq, statusFilter]);
  const pages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
  const safePage = Math.min(page, pages);
  const pageRows = rows.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE);
  const all = data ?? [];
  const doneCount = all.filter((l) => l.status === '已提交').length;
  const draftCount = all.filter((l) => l.status === '草稿').length;
  const missCount = all.filter((l) => l.status === '未提交').length;
  const rate = all.length ? Math.round((doneCount / all.length) * 100) : 0;

  if (loading) return <><div className="pd-hero"><h2>📝 日志只读</h2><p>加载中…</p></div><Skeleton rows={5} /></>;
  if (error) return <div className="pd-card">日志加载失败：{error} <button className="pd-btn" onClick={() => location.reload()}>重试</button></div>;

  return (
    <div>
      <div className="pd-hero">
        <h2>📝 日志只读</h2>
        <p>全公司日志 · 当天日期 · 提交后不可改 · 管理员只能看不能改。对照 US-27。</p>
        <div className="pd-hero-chips">
          <span className="pd-hero-chip">共 {all.length} 条</span><span className="pd-hero-chip">已提交 {doneCount}</span>
          <span className="pd-hero-chip">草稿 {draftCount}</span><span className="pd-hero-chip">未提交 {missCount}</span>
        </div>
      </div>
      <div className="pd-stats">
        <StatCard icon="📄" value={all.length} label="总条数" />
        <StatCard icon="✅" value={doneCount} label="已提交" tone={2} delay={0.05} />
        <StatCard icon="✏️" value={draftCount} label="草稿" tone={3} delay={0.1} />
        <StatCard icon="⚠️" value={missCount} label="未提交" tone={4} delay={0.15} />
      </div>
      <div className="pd-card">
        <div className="pd-row" style={{ marginBottom: 0 }}>
          <input className="pd-input pd-grow" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} placeholder="🔍 搜索作者 / 内容" />
          <select className="pd-select" value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}>
            {['全部', '草稿', '已提交', '未提交'].map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
          <button className="pd-btn" onClick={() => { downloadCSV('logs.csv', [['作者', '日期', '内容', '状态', '可见'], ...rows.map((l) => [l.author, l.date, l.summary, l.status, l.visible])]); toast.push('ok', '已导出 logs.csv'); }}>⤓ 导出</button>
        </div>
      </div>
      <div className="pd-card">
        <div className="pd-scroll-x">
          <table className="pd-table">
            <thead><tr><th>作者</th><th>日期</th><th>内容</th><th>状态</th><th>可见范围</th></tr></thead>
            <tbody>
              {pageRows.map((l) => (
                <tr key={l.id}>
                  <td style={{ fontWeight: 700 }}>{l.author}</td><td>{l.date}</td>
                  <td style={{ maxWidth: 340, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{l.summary}</td>
                  <td><span className={`pd-pill ${l.status === '已提交' ? 'green' : l.status === '草稿' ? 'orange' : 'red'}`}>{l.status}</span></td>
                  <td><span className="pd-pill">{l.visible}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {rows.length === 0 && <Empty emoji="🗂️" title="没有匹配的日志" hint="换个关键词试试。" />}
        <div className="pd-row" style={{ marginTop: 14, marginBottom: 0, justifyContent: 'space-between' }}>
          <span className="pd-hint" style={{ margin: 0 }}>第 {safePage}/{pages} 页 · 共 {rows.length} 条</span>
          <span>
            <button className="pd-btn" disabled={safePage <= 1} onClick={() => setPage((p) => p - 1)}>← 上一页</button>{' '}
            <button className="pd-btn" disabled={safePage >= pages} onClick={() => setPage((p) => p + 1)}>下一页 →</button>
          </span>
        </div>
      </div>
      <div className="pd-card"><p className="pd-hint" style={{ margin: 0 }}>提交率参考：{rate}%。更细的统计见「统计只读」。</p></div>
    </div>
  );
}

// ---------------- 统计只读 ----------------
export function Stats() {
  const { data: s, loading, error } = useAsync(api.stats);
  const toast = useToast();
  if (loading) return <><div className="pd-hero"><h2>📊 统计只读</h2><p>加载中…</p></div><Skeleton rows={3} /></>;
  if (error || !s) return <div className="pd-card">统计加载失败：{error} <button className="pd-btn" onClick={() => location.reload()}>重试</button></div>;
  return (
    <div>
      <div className="pd-hero">
        <h2>📊 统计只读</h2>
        <p>口径：当天已提交 / 应提交，成员4用例会对。已提交 {s.submitted}/{s.total}。</p>
        <div className="pd-hero-chips">
          <span className="pd-hero-chip">提交率 {s.submitRate}%</span>
          <span className="pd-hero-chip">未提交 {s.unsubmitted.length} 人</span>
        </div>
      </div>
      <div className="pd-stats">
        <StatCard icon="📊" value={`${s.submitRate}%`} label="提交率" tone={1} />
        <StatCard icon="✅" value={s.submitted} label="已提交" tone={2} delay={0.05} />
        <StatCard icon="⚠️" value={s.unsubmitted.length} label="未提交人数" tone={4} delay={0.1} />
        <StatCard icon="🎯" value={s.total} label="应提交" tone={3} delay={0.15} />
      </div>
      <div className="pd-card">
        <div style={{ display: 'flex', gap: 26, alignItems: 'center', flexWrap: 'wrap' }}>
          <Ring percent={s.submitRate} label="提交率" />
          <div style={{ flex: 1, minWidth: 240 }}>
            <h3 className="pd-sub" style={{ marginBottom: 10 }}>整体进度</h3>
            <div className="pd-bar"><div style={{ width: `${Math.min(100, Math.max(0, s.submitRate))}%` }} /></div>
            <p style={{ marginTop: 12 }}>
              未提交名单（{s.unsubmitted.length} 人）：{s.unsubmitted.length === 0 ? '全部已交 🎉' : s.unsubmitted.map((n) => <span key={n} className="pd-pill red" style={{ marginRight: 6 }}>{n}</span>)}
            </p>
            <button className="pd-btn" onClick={() => { downloadCSV('unsubmitted.csv', [['未提交名单'], ...s.unsubmitted.map((n) => [n])]); toast.push('ok', '已导出未提交名单'); }}>⤓ 导出未提交名单</button>
          </div>
        </div>
      </div>
      <div className="pd-card"><OpLogPanel /></div>
    </div>
  );
}

// 本地操作留痕：新增/删除用户先记在这里，审计时直接截图，接口到了换真审计接口
export function OpLogPanel() {
  const [tick, setTick] = useState(0);
  const toast = useToast();
  const logs = useMemo(() => readOpLog(), [tick]);
  return (
    <div>
      <div className="pd-card-head">
        <h3 className="pd-sub">🧾 本地操作记录 <span className="pd-pill">{logs.length}/100</span></h3>
        {logs.length > 0 && (
          <span>
            <button className="pd-btn" onClick={() => { clearOpLog(); setTick((t) => t + 1); toast.push('info', '已清空记录'); }}>清空</button>{' '}
            <button className="pd-btn" onClick={() => setTick((t) => t + 1)}>刷新</button>
          </span>
        )}
      </div>
      {logs.length === 0 && <Empty emoji="🧾" title="暂无操作记录" hint="去用户页新增/停用/删除一条就有。" />}
      {logs.length > 0 && (
        <ul style={{ margin: 0, paddingLeft: 18, color: '#4a4770' }}>
          {logs.slice(-10).reverse().map((l, i) => (
            <li key={i} style={{ padding: '5px 0' }}><span className="pd-hint" style={{ margin: 0 }}>{l.time}</span> · <b>{l.action}</b> · {l.detail}</li>
          ))}
        </ul>
      )}
    </div>
  );
}
