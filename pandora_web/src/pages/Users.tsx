import { useMemo, useState } from 'react';
import { api, type UserRow } from '../api/client';
import { ROLE_ICON, ROLE_META, ROLES, USER_STATUS } from '../constants/roles';
import { useAsync, useDebounce, useLocalStorage } from '../hooks/hooks';
import { downloadCSV, writeOpLog } from '../utils/export';
import { Empty, Modal, Skeleton, StatCard, useConfirm, useToast } from '../components/ui';

const PAGE_SIZE = 6;
const DEPT_OPTS = ['产品部', '技术部', '总部'];
const TEAM_OPTS = ['如来佛组', '观音组', '平台组', '架构组'];

export function Users() {
  const { data, loading, error } = useAsync(() => api.listUsers());
  const [local, setLocal] = useLocalStorage<UserRow[]>('pandora-web-users-local', []);
  const [removed, setRemoved] = useLocalStorage<string[]>('pandora-web-users-removed', []);
  const [statusPatch, setStatusPatch] = useLocalStorage<Record<string, string>>('pandora-web-users-status', {});
  const [q, setQ] = useState('');
  const [roleFilter, setRoleFilter] = useState('全部');
  const [statusFilter, setStatusFilter] = useState('全部');
  const [page, setPage] = useState(1);
  const [showAdd, setShowAdd] = useState(false);
  const [form, setForm] = useState({ username: '', name: '', password: '123456', dept: '产品部', team: '如来佛组', role: '组员' });
  const [formErr, setFormErr] = useState('');
  const [detail, setDetail] = useState<UserRow | null>(null);
  const [pwTarget, setPwTarget] = useState<UserRow | null>(null);
  const [pwValue, setPwValue] = useState('');
  const dq = useDebounce(q);
  const toast = useToast();
  const { confirm } = useConfirm();

  const rows = useMemo(() => {
    const base = [...(data?.items ?? []), ...local]
      .filter((u) => !removed.includes(u.id))
      .map((u) => (statusPatch[u.id] ? { ...u, status: statusPatch[u.id] } : u));
    const key = dq.trim().toLowerCase();
    return base.filter((u) => {
      if (roleFilter !== '全部' && u.role !== roleFilter) return false;
      if (statusFilter !== '全部' && u.status !== statusFilter) return false;
      if (!key) return true;
      return `${u.username}${u.name}${u.dept}${u.team}${u.role}${u.status}`.toLowerCase().includes(key);
    });
  }, [data, local, removed, statusPatch, dq, roleFilter, statusFilter]);

  const pages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
  const safePage = Math.min(page, pages);
  const pageRows = rows.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE);
  const enabledCount = rows.filter((u) => u.status === '启用').length;

  // 文档第3节：角色与组织归属必须同时合法，前端先拦一道，服务端还会再校验
  const roleMeta = ROLE_META.find((r) => r.label === form.role);
  const deptLocked = roleMeta?.departmentId === '必须为空';
  const teamLocked = roleMeta?.teamId === '必须为空';

  const add = async () => {
    const username = form.username.trim().toLowerCase();
    const name = form.name.trim();
    if (!username) return setFormErr('请输入登录账号（username，英文）');
    if (!/^[a-z0-9_]{3,20}$/.test(username)) return setFormErr('账号 3~20 位英文小写/数字/下划线');
    if (!name) return setFormErr('请输入姓名');
    if (name.length > 20) return setFormErr('姓名最多 20 字');
    if (!form.password.trim()) return setFormErr('请设置初始密码');
    if (rows.some((u) => u.username === username)) return setFormErr('该账号已存在，换一个');
    if (rows.some((u) => u.name === name)) return setFormErr('该姓名已存在，换一个');
    setFormErr('');
    try {
      const r = await api.createUser({
        username,
        password: form.password,
        realName: name,
        role: form.role,
        departmentId: deptLocked ? null : 1,
        teamId: teamLocked ? null : 1,
      });
      setLocal((v) => [...v, { id: String(r?.id ?? `u-local-${Date.now()}`), username, name, dept: deptLocked ? '总部' : form.dept, team: teamLocked ? '-' : form.team, role: form.role, status: '启用' }]);
      writeOpLog('创建用户', `${name}(${username})`);
      toast.push('ok', `已创建账号 ${name}`);
      setForm({ username: '', name: '', password: '123456', dept: '产品部', team: '如来佛组', role: '组员' });
      setShowAdd(false);
    } catch (e) {
      setFormErr(e instanceof Error ? e.message : '创建失败');
    }
  };

  const toggleStatus = async (u: UserRow) => {
    const next = u.status === '启用' ? '停用' : '启用';
    try {
      await api.setUserStatus(u.id, next === '启用');
      writeOpLog(next === '启用' ? '启用账号' : '停用账号', `${u.name}(${u.username})`);
      if (u.id.startsWith('u-local-')) setLocal((v) => v.map((x) => (x.id === u.id ? { ...x, status: next } : x)));
      else setStatusPatch((m) => ({ ...m, [u.id]: next }));
      toast.push(next === '启用' ? 'ok' : 'info', `已${next} ${u.name}`);
    } catch (e) {
      toast.push('err', e instanceof Error ? e.message : '操作失败');
    }
  };

  const remove = async (u: UserRow) => {
    const ok = await confirm({ title: `删除用户「${u.name}」？`, desc: '本地演示删除，接真接口后走真删除。', okText: '删除', danger: true });
    if (!ok) return;
    writeOpLog('删除用户', u.name);
    if (u.id.startsWith('u-local-')) setLocal((v) => v.filter((x) => x.id !== u.id));
    else setRemoved((v) => (v.includes(u.id) ? v : [...v, u.id]));
    if (detail?.id === u.id) setDetail(null);
    toast.push('ok', `已删除 ${u.name}`);
  };

  const doResetPw = async () => {
    if (!pwTarget) return;
    if (pwValue.length < 6) return toast.push('err', '密码至少 6 位');
    try {
      await api.resetPassword(pwTarget.id, pwValue);
      writeOpLog('重置密码', pwTarget.name);
      toast.push('ok', `已重置 ${pwTarget.name} 的密码`);
      setPwTarget(null); setPwValue('');
    } catch (e) {
      toast.push('err', e instanceof Error ? e.message : '重置失败');
    }
  };

  const resetLocal = async () => {
    const ok = await confirm({ title: '回到 mock 基线？', desc: '清空本地新增/删除/停用状态。' });
    if (!ok) return;
    setLocal([]); setRemoved([]); setStatusPatch({}); setPage(1);
    toast.push('info', '已回到基线');
  };

  if (loading) return <><div className="pd-hero"><h2>👥 用户管理</h2><p>加载中…</p></div><Skeleton rows={5} /></>;
  if (error) return <div className="pd-card">用户加载失败：{error} <button className="pd-btn" onClick={() => location.reload()}>重试</button></div>;

  return (
    <div>
      <div className="pd-hero">
        <h2>👥 用户管理</h2>
        <p>对应 US-03/04/26。账号由管理员创建，无自助注册；停用后登录返回 40103。</p>
        <div className="pd-hero-chips">
          <span className="pd-hero-chip">总人数 {rows.length}</span>
          <span className="pd-hero-chip">启用 {enabledCount}</span>
          <span className="pd-hero-chip">停用 {rows.length - enabledCount}</span>
        </div>
      </div>

      <div className="pd-stats">
        <StatCard icon="👥" value={rows.length} label="总人数" />
        <StatCard icon="✅" value={enabledCount} label="启用中" tone={2} delay={0.05} />
        <StatCard icon="🚫" value={rows.length - enabledCount} label="已停用" tone={4} delay={0.1} />
        <StatCard icon="✏️" value={rows.filter((u) => u.role === '组员').length} label="组员" tone={3} delay={0.15} />
      </div>

      <div className="pd-card">
        <div className="pd-row" style={{ marginBottom: 0 }}>
          <input className="pd-input pd-grow" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} placeholder="🔍 搜索账号 / 姓名 / 部门 / 团队 / 角色" />
          <select className="pd-select" value={roleFilter} onChange={(e) => { setRoleFilter(e.target.value); setPage(1); }}>
            {['全部', ...ROLES].map((r) => <option key={r} value={r}>{r}</option>)}
          </select>
          <select className="pd-select" value={statusFilter} onChange={(e) => { setStatusFilter(e.target.value); setPage(1); }}>
            {['全部', ...USER_STATUS].map((s) => <option key={s} value={s}>{s}</option>)}
          </select>
          <button className="pd-btn primary" onClick={() => setShowAdd(true)}>＋ 新增用户</button>
          <button className="pd-btn" onClick={() => { downloadCSV('users.csv', [['账号', '姓名', '部门', '团队', '角色', '状态'], ...rows.map((u) => [u.username, u.name, u.dept, u.team, u.role, u.status])]); toast.push('ok', '已导出 users.csv'); }}>⤓ 导出</button>
          <button className="pd-btn" onClick={resetLocal}>↺ 回到基线</button>
        </div>
      </div>

      <div className="pd-card">
        <div className="pd-scroll-x">
          <table className="pd-table">
            <thead><tr><th>账号</th><th>姓名</th><th>部门</th><th>团队</th><th>角色</th><th>状态</th><th>操作</th></tr></thead>
            <tbody>
              {pageRows.map((u) => (
                <tr key={u.id}>
                  <td><a href="#" onClick={(e) => { e.preventDefault(); setDetail(u); }}>{u.username}</a></td>
                  <td>{ROLE_ICON[u.role] ?? ''} {u.name}</td>
                  <td>{u.dept}</td><td>{u.team}</td><td><span className="pd-pill">{u.role}</span></td>
                  <td><span className={`pd-pill ${u.status === '启用' ? 'green' : 'red'}`}><span className="pd-dot" style={{ background: u.status === '启用' ? '#17b58b' : '#e5484d' }} />{u.status}</span></td>
                  <td>
                    <button className="pd-btn" onClick={() => toggleStatus(u)}>{u.status === '启用' ? '停用' : '启用'}</button>{' '}
                    <button className="pd-btn" onClick={() => setPwTarget(u)}>重置密码</button>{' '}
                    <button className="pd-btn danger" onClick={() => remove(u)}>删除</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {rows.length === 0 && <Empty emoji="🔍" title="没有匹配的用户" hint="换个关键词，或点“回到基线”。" />}
        <div className="pd-row" style={{ marginTop: 14, marginBottom: 0, justifyContent: 'space-between' }}>
          <span className="pd-hint" style={{ margin: 0 }}>第 {safePage}/{pages} 页 · 共 {rows.length} 条</span>
          <span>
            <button className="pd-btn" disabled={safePage <= 1} onClick={() => setPage((p) => p - 1)}>← 上一页</button>{' '}
            <button className="pd-btn" disabled={safePage >= pages} onClick={() => setPage((p) => p + 1)}>下一页 →</button>
          </span>
        </div>
      </div>

      {showAdd && (
        <Modal title="新增用户（POST /users）" onClose={() => { setShowAdd(false); setFormErr(''); }}
          footer={<><button className="pd-btn" onClick={() => { setShowAdd(false); setFormErr(''); }}>取消</button><button className="pd-btn primary" onClick={add}>保存</button></>}>
          <div style={{ display: 'grid', gap: 10 }}>
            <input className="pd-input" value={form.username} onChange={(e) => setForm({ ...form, username: e.target.value })} placeholder="账号 username（必填，英文 3~20 位）" />
            <input className="pd-input" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} placeholder="姓名 realName（必填，最多 20 字）" />
            <input className="pd-input" type="password" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} placeholder="初始密码（服务端 BCrypt 存储）" />
            <div className="pd-row" style={{ marginBottom: 0 }}>
              <select className="pd-select" value={form.role} onChange={(e) => setForm({ ...form, role: e.target.value })}>
                {ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
              </select>
              <select className="pd-select" value={form.dept} disabled={deptLocked} onChange={(e) => setForm({ ...form, dept: e.target.value })}>
                {(deptLocked ? ['-'] : DEPT_OPTS).map((d) => <option key={d} value={d}>{d}</option>)}
              </select>
              <select className="pd-select" value={form.team} disabled={teamLocked} onChange={(e) => setForm({ ...form, team: e.target.value })}>
                {(teamLocked ? ['-'] : TEAM_OPTS).map((t) => <option key={t} value={t}>{t}</option>)}
              </select>
            </div>
            <p className="pd-hint" style={{ margin: 0 }}>
              角色归属规则：{roleMeta?.note}（部门 {roleMeta?.departmentId} / 团队 {roleMeta?.teamId}）
            </p>
            {formErr && <p className="pd-err" style={{ margin: 0 }}>⚠ {formErr}</p>}
          </div>
        </Modal>
      )}

      {pwTarget && (
        <Modal title={`重置密码 · ${pwTarget.name}`} onClose={() => setPwTarget(null)}
          footer={<><button className="pd-btn" onClick={() => setPwTarget(null)}>取消</button><button className="pd-btn primary" onClick={doResetPw}>确认重置</button></>}>
          <p className="pd-hint">PUT /users/{"{id}"}/password · 至少 6 位，服务端 BCrypt 存储，审计会留痕。</p>
          <input className="pd-input" style={{ width: '100%' }} type="password" value={pwValue} onChange={(e) => setPwValue(e.target.value)} placeholder="新密码" />
        </Modal>
      )}

      {detail && (
        <Modal title={`用户详情 · ${detail.name}`} onClose={() => setDetail(null)} footer={<button className="pd-btn" onClick={() => setDetail(null)}>关闭</button>}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
            {[['账号', detail.username], ['姓名', detail.name], ['部门', detail.dept], ['团队', detail.team], ['角色', detail.role], ['状态', detail.status]].map(([k, v]) => (
              <div key={k} className="pd-card" style={{ margin: 0, padding: 14 }}>
                <div className="pd-hint" style={{ margin: 0 }}>{k}</div>
                <div style={{ fontWeight: 900, fontSize: 16 }}>{v}</div>
              </div>
            ))}
          </div>
          <p className="pd-hint" style={{ margin: '12px 0 0' }}>详情来自 GET /users/{"{id}"}（不含凭据），关联日志与点评待联调展示。</p>
        </Modal>
      )}
    </div>
  );
}