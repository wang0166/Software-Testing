import { useMemo, useState } from 'react';
import { api, type CompanyMatter, type LogRow } from '../api/client';
import { PERMISSION_CODES, ROLE_META } from '../constants/roles';
import { useAsync, useDebounce } from '../hooks/hooks';
import { clearOpLog, downloadCSV, readOpLog } from '../utils/export';
import { Empty, Modal, Ring, Skeleton, StatCard, useConfirm, useToast } from '../components/ui';

const PAGE_SIZE = 6;

// ================= 组织 / 角色 / 配置 =================
export function Org() {
  const [tab, setTab] = useState<'org' | 'roles' | 'matters' | 'config'>('org');
  const tabs = [
    { k: 'org' as const, label: '🏢 组织结构' },
    { k: 'roles' as const, label: '🛡️ 角色权限' },
    { k: 'matters' as const, label: '📌 重要事项' },
    { k: 'config' as const, label: '⚙️ 系统配置' },
  ];
  return (
    <div>
      <div className="pd-hero">
        <h2>🏢 组织 / 角色 / 配置</h2>
        <p>对应 US-05/28/29。公司→部门→团队→员工，一队一个组长，一人一种身份。</p>
        <div className="pd-hero-chips">
          <span className="pd-hero-chip">1 公司</span><span className="pd-hero-chip">4 团队</span>
          <span className="pd-hero-chip">5 角色</span><span className="pd-hero-chip">6 权限码</span>
        </div>
      </div>
      <div className="pd-row" style={{ marginBottom: 16 }}>
        {tabs.map((t) => (
          <button key={t.k} className={`pd-btn ${tab === t.k ? 'primary' : ''}`} onClick={() => setTab(t.k)}>{t.label}</button>
        ))}
      </div>
      {tab === 'org' && <OrgTab />}
      {tab === 'roles' && <RolesTab />}
      {tab === 'matters' && <MattersTab />}
      {tab === 'config' && <ConfigTab />}
    </div>
  );
}

function OrgTab() {
  const depts = useAsync(() => api.listDepartments());
  const teams = useAsync(() => api.listTeams());
  const [adding, setAdding] = useState<'' | 'department' | 'team'>('');
  const [name, setName] = useState('');
  const toast = useToast();
  const { confirm } = useConfirm();

  const del = async (kind: 'departments' | 'teams', id: string, label: string) => {
    const ok = await confirm({ title: `删除「${label}」？`, desc: '仍有成员归属时后端返回 40904，会拒绝删除。', okText: '删除', danger: true });
    if (!ok) return;
    try {
      await api.deleteUnit(kind, id);
      toast.push('ok', `已删除 ${label}`);
      if (kind === 'departments') depts.reload?.(); else teams.reload?.();
    } catch (e) {
      toast.push('err', e instanceof Error ? e.message : '删除失败');
    }
  };

  const submit = async () => {
    const n = name.trim();
    if (!n) return toast.push('err', '请输入名称');
    try {
      if (adding === 'department') { await api.createDepartment(n, 1); depts.reload?.(); toast.push('ok', `已创建部门 ${n}`); }
      else if (adding === 'team') { await api.createTeam(n, 1); teams.reload?.(); toast.push('ok', `已创建团队 ${n}`); }
      setAdding(''); setName('');
    } catch (e) {
      toast.push('err', e instanceof Error ? e.message : '创建失败');
    }
  };

  if (depts.loading || teams.loading) return <Skeleton rows={4} />;

  return (
    <>
      <div className="pd-stats">
        <StatCard icon="🏢" value={1} label="公司" />
        <StatCard icon="📦" value={depts.data?.length ?? 0} label="部门" tone={2} delay={0.05} />
        <StatCard icon="👨‍👩‍👧" value={teams.data?.length ?? 0} label="团队" tone={3} delay={0.1} />
        <StatCard icon="🧑‍💻" value={20} label="成员" tone={4} delay={0.15} />
      </div>
      <div className="pd-card">
        <div className="pd-card-head">
          <h3 className="pd-sub">📦 部门 <span className="pd-pill">GET /departments</span></h3>
          <button className="pd-btn primary" onClick={() => setAdding('department')}>＋ 新建部门</button>
        </div>
        {(depts.data ?? []).length === 0 && <Empty emoji="📦" title="暂无部门" hint="点右上角新建一个。" />}
        {(depts.data ?? []).map((d) => (
          <div className="pd-tree-node" key={d.id}>
            <div className="pd-tree-toggle" style={{ cursor: 'default' }}>
              <span>📦 {d.name} <span className="pd-pill" style={{ marginLeft: 6 }}>{(teams.data ?? []).filter((t) => t.parentId === d.id).length} 队</span></span>
              <button className="pd-btn danger" onClick={() => del('departments', d.id, d.name)}>删除</button>
            </div>
          </div>
        ))}
      </div>
      <div className="pd-card">
        <div className="pd-card-head">
          <h3 className="pd-sub">👨‍👩‍👧 团队 <span className="pd-pill">GET /teams</span></h3>
          <button className="pd-btn primary" onClick={() => setAdding('team')}>＋ 新建团队</button>
        </div>
        <div className="pd-scroll-x">
          <table className="pd-table">
            <thead><tr><th>团队</th><th>所属部门</th><th>操作</th></tr></thead>
            <tbody>
              {(teams.data ?? []).map((t) => {
                const parent = (depts.data ?? []).find((d) => d.id === t.parentId);
                return (
                  <tr key={t.id}>
                    <td style={{ fontWeight: 700 }}>{t.name}</td>
                    <td>{parent?.name ?? '-'}</td>
                    <td><button className="pd-btn danger" onClick={() => del('teams', t.id, t.name)}>删除</button></td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        {(teams.data ?? []).length === 0 && <Empty emoji="👨‍👩‍👧" title="暂无团队" />}
      </div>
      {adding && (
        <Modal title={adding === 'department' ? '新建部门（POST /departments）' : '新建团队（POST /teams）'} onClose={() => setAdding('')}
          footer={<><button className="pd-btn" onClick={() => setAdding('')}>取消</button><button className="pd-btn primary" onClick={submit}>创建</button></>}>
          <input className="pd-input" style={{ width: '100%' }} value={name} onChange={(e) => setName(e.target.value)} placeholder={adding === 'department' ? '部门名称' : '团队名称'} autoFocus />
        </Modal>
      )}
    </>
  );
}

function RolesTab() {
  const roles = useAsync(() => api.listRoles());
  const [editing, setEditing] = useState<{ code: string; label: string; perms: string[] } | null>(null);
  const toast = useToast();
  const save = async () => {
    if (!editing) return;
    try {
      await api.setRolePermissions(editing.code, editing.perms);
      toast.push('ok', `已保存「${editing.label}」权限`);
      roles.reload?.();
      setEditing(null);
    } catch (e) {
      toast.push('err', e instanceof Error ? e.message : '保存失败');
    }
  };
  const toggle = (code: string) => {
    if (!editing) return;
    setEditing({ ...editing, perms: editing.perms.includes(code) ? editing.perms.filter((p) => p !== code) : [...editing.perms, code] });
  };
  if (roles.loading) return <Skeleton rows={4} />;
  return (
    <>
      <div className="pd-card">
        <div className="pd-card-head"><h3 className="pd-sub">📋 权限码清单 <span className="pd-pill">GET /permissions</span></h3></div>
        <div className="pd-scroll-x">
          <table className="pd-table">
            <thead><tr><th>权限码</th><th>含义</th><th>说明</th><th>默认角色</th></tr></thead>
            <tbody>
              {PERMISSION_CODES.map((p) => (
                <tr key={p.code}>
                  <td><span className="pd-pill">{p.code}</span></td>
                  <td style={{ fontWeight: 700 }}>{p.label}</td>
                  <td>{p.desc}</td>
                  <td><span className="pd-pill orange">{p.defaults}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      <div className="pd-card">
        <div className="pd-card-head"><h3 className="pd-sub">🛡️ 角色权限矩阵 <span className="pd-pill">PUT /roles/{'{code}'}/permissions</span></h3></div>
        <div className="pd-role-grid">
          {(roles.data ?? []).map((r) => (
            <div key={r.roleCode} className={`pd-role-card ${r.roleCode === 'ADMIN' ? 'hi' : ''}`}>
              <div className="ico">{ROLE_META.find((m) => m.code === r.roleCode)?.icon ?? '👤'}</div>
              <div className="name">{ROLE_META.find((m) => m.code === r.roleCode)?.label ?? r.roleCode}</div>
              <div style={{ marginBottom: 8 }}><span className="pd-pill">{r.roleCode}</span></div>
              {r.permissions.map((p) => <div key={p} style={{ marginBottom: 4 }}><span className="pd-pill green">{p}</span></div>)}
              <button className="pd-btn" style={{ marginTop: 10, width: '100%', justifyContent: 'center' }} onClick={() => setEditing({ code: r.roleCode, label: ROLE_META.find((m) => m.code === r.roleCode)?.label ?? r.roleCode, perms: [...r.permissions] })}>编辑权限</button>
            </div>
          ))}
        </div>
      </div>
      <div className="pd-card">
        <h3 className="pd-sub">📐 角色归属约束</h3>
        <p className="pd-hint" style={{ marginTop: 6 }}>文档第3节：不合法组合返回 40001，负责人唯一性冲突返回 40905，服务端独立校验。</p>
        <div className="pd-scroll-x">
          <table className="pd-table">
            <thead><tr><th>角色</th><th>编码</th><th>部门</th><th>团队</th><th>说明</th></tr></thead>
            <tbody>
              {ROLE_META.map((r) => (
                <tr key={r.code}>
                  <td style={{ fontWeight: 700 }}>{r.icon} {r.label}</td>
                  <td><span className="pd-pill">{r.code}</span></td>
                  <td>{r.departmentId}</td><td>{r.teamId}</td>
                  <td>{r.note}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
      {editing && (
        <Modal title={`编辑权限 · ${editing.label}`} onClose={() => setEditing(null)}
          footer={<><button className="pd-btn" onClick={() => setEditing(null)}>取消</button><button className="pd-btn primary" onClick={save}>保存</button></>}>
          {PERMISSION_CODES.map((p) => (
            <label key={p.code} style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: '9px 0', cursor: 'pointer', borderBottom: '1px solid var(--line)' }}>
              <input type="checkbox" checked={editing.perms.includes(p.code)} onChange={() => toggle(p.code)} style={{ marginTop: 3 }} />
              <span><b>{p.code}</b>（{p.label}）<br /><span className="pd-hint" style={{ margin: 0 }}>{p.desc}</span></span>
            </label>
          ))}
        </Modal>
      )}
    </>
  );
}

function MattersTab() {
  const { data, loading, reload } = useAsync(() => api.listMatters());
  const [editing, setEditing] = useState<CompanyMatter | null>(null);
  const [draft, setDraft] = useState({ title: '', content: '', sortOrder: 1 });
  const toast = useToast();
  const save = async () => {
    if (!draft.title.trim() || !draft.content.trim()) return toast.push('err', '标题和内容都不能为空');
    try {
      if (editing) await api.updateMatter(editing.id, draft);
      else await api.createMatter(draft);
      toast.push('ok', editing ? '已更新事项' : '已新增事项');
      setEditing(null); setDraft({ title: '', content: '', sortOrder: 1 });
      reload?.();
    } catch (e) {
      toast.push('err', e instanceof Error ? e.message : '保存失败');
    }
  };
  if (loading) return <Skeleton rows={3} />;
  return (
    <div className="pd-card">
      <div className="pd-card-head">
        <h3 className="pd-sub">📌 公司十大重要事项 <span className="pd-pill orange">仅 ADMIN 可维护</span></h3>
        <button className="pd-btn primary" onClick={() => { setEditing(null); setDraft({ title: '', content: '', sortOrder: (data?.length ?? 0) + 1 }); }}>＋ 新增事项</button>
      </div>
      <p className="pd-hint" style={{ marginTop: 0 }}>GET/POST/PUT /company-matters · 按 sortOrder、id 排序 · 当前版本无删除接口 · 名称仅为展示，接口不设条数上限。</p>
      {(data ?? []).length === 0 && <Empty emoji="📌" title="暂无事项" hint="点右上角新增一条。" />}
      {(data ?? []).map((m) => (
        <div key={m.id} className="pd-tree-node">
          <div className="pd-tree-toggle" style={{ cursor: 'default' }}>
            <span><span className="pd-pill" style={{ marginRight: 8 }}>#{m.sortOrder}</span>{m.title}</span>
            <button className="pd-btn" onClick={() => { setEditing(m); setDraft({ title: m.title, content: m.content, sortOrder: m.sortOrder }); }}>编辑</button>
          </div>
          <div style={{ padding: '0 16px 12px 16px', color: '#4a4770' }}>{m.content}</div>
        </div>
      ))}
      {editing !== null || draft.title || draft.content ? (
        <Modal title={editing ? '编辑事项（PUT）' : '新增事项（POST）'} onClose={() => setEditing(null)}
          footer={<><button className="pd-btn" onClick={() => setEditing(null)}>取消</button><button className="pd-btn primary" onClick={save}>保存</button></>}>
          <div style={{ display: 'grid', gap: 10 }}>
            <input className="pd-input" value={draft.title} onChange={(e) => setDraft({ ...draft, title: e.target.value })} placeholder="标题（不能为空）" />
            <textarea className="pd-input" rows={4} value={draft.content} onChange={(e) => setDraft({ ...draft, content: e.target.value })} placeholder="内容（不能为空）" />
            <input className="pd-input" type="number" value={draft.sortOrder} onChange={(e) => setDraft({ ...draft, sortOrder: Number(e.target.value) })} placeholder="排序 sortOrder" />
          </div>
        </Modal>
      ) : null}
    </div>
  );
}

function ConfigTab() {
  const { data, loading, reload } = useAsync(() => api.getConfigs());
  const [deadline, setDeadline] = useState('');
  const toast = useToast();
  useMemo(() => { if (data?.log_deadline && !deadline) setDeadline(data.log_deadline); }, [data]);
  if (loading) return <Skeleton rows={2} />;
  const save = async () => {
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(deadline)) return toast.push('err', '时间格式应为 HH:mm，如 21:30');
    try {
      await api.setConfig('log_deadline', deadline);
      toast.push('ok', `截止时间已改为 ${deadline}`);
      reload?.();
    } catch (e) {
      toast.push('err', e instanceof Error ? e.message : '保存失败');
    }
  };
  return (
    <>
      <div className="pd-card">
        <div className="pd-card-head"><h3 className="pd-sub">⚙️ 系统配置 <span className="pd-pill">GET/PUT /configs</span></h3></div>
        <p className="pd-hint" style={{ marginTop: 0 }}>格式 HH:mm，服务端校验合法时分。到截止时间自动把草稿转为已提交，当天无日志记未提交，截止后不可补交。</p>
        <div className="pd-row" style={{ marginBottom: 0 }}>
          <span style={{ fontWeight: 700 }}>log_deadline</span>
          <input className="pd-input" value={deadline} onChange={(e) => setDeadline(e.target.value)} placeholder="22:00" style={{ width: 120 }} />
          <button className="pd-btn primary" onClick={save}>保存</button>
          <button className="pd-btn" onClick={() => setDeadline(data?.log_deadline ?? '22:00')}>还原</button>
        </div>
      </div>
      <div className="pd-card">
        <div className="pd-card-head"><h3 className="pd-sub">🧾 全部配置项</h3></div>
        <div className="pd-scroll-x">
          <table className="pd-table">
            <thead><tr><th>键</th><th>值</th><th>说明</th></tr></thead>
            <tbody>
              {Object.entries(data ?? {}).map(([k, v]) => (
                <tr key={k}><td><span className="pd-pill">{k}</span></td><td style={{ fontWeight: 800 }}>{v}</td><td>{k === 'log_deadline' ? '每日日志提交截止时间' : '-'}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  );
}

// ================= 日志只读 =================
export function Logs() {
  const { data, loading, error } = useAsync(() => api.listLogs());
  const [q, setQ] = useState('');
  const [statusFilter, setStatusFilter] = useState('全部');
  const [page, setPage] = useState(1);
  const dq = useDebounce(q);
  const toast = useToast();
  const rows: LogRow[] = useMemo(() => {
    const base = data?.items ?? [];
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
  const all = data?.items ?? [];
  const doneCount = all.filter((l) => l.status === '已提交').length;
  const draftCount = all.filter((l) => l.status === '草稿').length;
  const missCount = all.filter((l) => l.status === '未提交').length;

  if (loading) return <><div className="pd-hero"><h2>📝 日志只读</h2><p>加载中…</p></div><Skeleton rows={5} /></>;
  if (error) return <div className="pd-card">日志加载失败：{error} <button className="pd-btn" onClick={() => location.reload()}>重试</button></div>;

  return (
    <div>
      <div className="pd-hero">
        <h2>📝 日志只读</h2>
        <p>对应 US-27。GET /logs 范围由服务端算；管理员可读全公司，不可改不可删。</p>
        <div className="pd-hero-chips">
          <span className="pd-hero-chip">共 {all.length} 条</span><span className="pd-hero-chip">已提交 {doneCount}</span>
          <span className="pd-hero-chip">草稿 {draftCount}</span><span className="pd-hero-chip">未提交 {missCount}</span>
        </div>
      </div>
      <div className="pd-stats">
        <StatCard icon="📄" value={all.length} label="总条数" />
        <StatCard icon="✅" value={doneCount} label="已提交" tone={2} delay={0.05} />
        <StatCard icon="✏️" value={draftCount} label="草稿" tone={3} delay={0.1} />
        <StatCard icon="⚠️" value={missCount} label="未提交（派生）" tone={4} delay={0.15} />
      </div>
      <div className="pd-card">
        <div className="pd-row" style={{ marginBottom: 0 }}>
          <input className="pd-input pd-grow" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} placeholder="🔍 搜索作者 / 内容" />
          <select className="pd-select" value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}>
            {['全部', '草稿', '已提交', '未提交'].map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
          <button className="pd-btn" onClick={() => { downloadCSV('logs.csv', [['作者', '日期', '内容', '状态', '可见范围'], ...rows.map((l) => [l.author, l.date, l.summary, l.status, l.visible])]); toast.push('ok', '已导出 logs.csv'); }}>⤓ 导出</button>
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
    </div>
  );
}

// ================= 统计只读 =================
export function Stats() {
  const { data: s, loading, error } = useAsync(() => api.stats());
  const names = useAsync(() => api.unsubmitted());
  const audits = useAsync(() => api.listAudits({ size: 20 }));
  const toast = useToast();
  if (loading) return <><div className="pd-hero"><h2>📊 统计只读</h2><p>加载中…</p></div><Skeleton rows={3} /></>;
  if (error || !s) return <div className="pd-card">统计加载失败：{error} <button className="pd-btn" onClick={() => location.reload()}>重试</button></div>;
  const unsub = names.data ?? s.unsubmitted;
  return (
    <div>
      <div className="pd-hero">
        <h2>📊 统计只读</h2>
        <p>GET /stats/overview + /stats/unsubmitted。口径：已提交人数 / 应提交人数，管理员不计入应提交。</p>
        <div className="pd-hero-chips">
          <span className="pd-hero-chip">提交率 {s.submitRate}%</span><span className="pd-hero-chip">未提交 {unsub.length} 人</span>
        </div>
      </div>
      <div className="pd-stats">
        <StatCard icon="📊" value={`${s.submitRate}%`} label="提交率" />
        <StatCard icon="✅" value={s.submitted} label="已提交" tone={2} delay={0.05} />
        <StatCard icon="⚠️" value={unsub.length} label="未提交人数" tone={4} delay={0.1} />
        <StatCard icon="🎯" value={s.total} label="应提交" tone={3} delay={0.15} />
      </div>
      <div className="pd-card">
        <div style={{ display: 'flex', gap: 26, alignItems: 'center', flexWrap: 'wrap' }}>
          <Ring percent={s.submitRate} label="提交率" />
          <div style={{ flex: 1, minWidth: 240 }}>
            <h3 className="pd-sub" style={{ marginBottom: 10 }}>整体进度</h3>
            <div className="pd-bar"><div style={{ width: `${Math.min(100, Math.max(0, s.submitRate))}%` }} /></div>
            <p style={{ marginTop: 12 }}>
              未提交名单（{unsub.length} 人）：{unsub.length === 0 ? '全部已交 🎉' : unsub.map((n) => <span key={n} className="pd-pill red" style={{ marginRight: 6 }}>{n}</span>)}
            </p>
            <button className="pd-btn" onClick={() => { downloadCSV('unsubmitted.csv', [['未提交名单'], ...unsub.map((n) => [n])]); toast.push('ok', '已导出未提交名单'); }}>⤓ 导出未提交名单</button>
          </div>
        </div>
      </div>
      <AuditPanel audits={audits.data?.items ?? []} loading={audits.loading} />
      <OpLogPanel />
    </div>
  );
}

// 审计：GET /audits，文档第11节，关键管理操作留痕，只读
export function AuditPanel({ audits, loading }: { audits: { id: string; actor: string; action: string; target: string; time: string; result: string }[]; loading: boolean }) {
  const [q, setQ] = useState('');
  const rows = useMemo(() => {
    const k = q.trim().toLowerCase();
    if (!k) return audits;
    return audits.filter((a) => `${a.actor}${a.action}${a.target}${a.result}`.toLowerCase().includes(k));
  }, [audits, q]);
  const toast = useToast();
  return (
    <div className="pd-card">
      <div className="pd-card-head">
        <h3 className="pd-sub">🧾 审计记录 <span className="pd-pill">GET /audits · 只读</span></h3>
        <button className="pd-btn" onClick={() => { downloadCSV('audits.csv', [['操作者', '动作', '目标', '时间', '结果'], ...rows.map((a) => [a.actor, a.action, a.target, a.time, a.result])]); toast.push('ok', '已导出审计记录'); }}>⤓ 导出</button>
      </div>
      <div className="pd-row">
        <input className="pd-input pd-grow" value={q} onChange={(e) => setQ(e.target.value)} placeholder="🔍 搜索操作者 / 动作 / 目标" />
      </div>
      {loading ? <Skeleton rows={2} /> : rows.length === 0 ? <Empty emoji="🧾" title="暂无审计记录" /> : (
        <div className="pd-scroll-x">
          <table className="pd-table">
            <thead><tr><th>操作者</th><th>动作</th><th>目标</th><th>时间</th><th>结果</th></tr></thead>
            <tbody>
              {rows.map((a) => (
                <tr key={a.id}>
                  <td style={{ fontWeight: 700 }}>{a.actor}</td><td>{a.action}</td><td>{a.target}</td>
                  <td><span className="pd-hint" style={{ margin: 0 }}>{a.time}</span></td>
                  <td><span className={`pd-pill ${a.result === '成功' ? 'green' : 'red'}`}>{a.result}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

// 本地操作留痕：接真审计前顶一下，本地新增/删除会记在这里
export function OpLogPanel() {
  const [tick, setTick] = useState(0);
  const toast = useToast();
  const logs = useMemo(() => readOpLog(), [tick]);
  if (logs.length === 0) return null;
  return (
    <div className="pd-card">
      <div className="pd-card-head">
        <h3 className="pd-sub">📝 本地操作记录 <span className="pd-pill orange">演示用 · 真审计见上表</span></h3>
        <button className="pd-btn" onClick={() => { clearOpLog(); setTick((t) => t + 1); toast.push('info', '已清空'); }}>清空</button>
      </div>
      <ul style={{ margin: 0, paddingLeft: 18, color: '#4a4770' }}>
        {logs.slice(-10).reverse().map((l, i) => (
          <li key={i} style={{ padding: '5px 0' }}><span className="pd-hint" style={{ margin: 0 }}>{l.time}</span> · <b>{l.action}</b> · {l.detail}</li>
        ))}
      </ul>
    </div>
  );
}