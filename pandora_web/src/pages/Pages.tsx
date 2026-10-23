import { useEffect, useState } from 'react';
import { api, type CompanyMatter } from '../api/client';
import { supports } from '../api/capabilities';
import { isMock } from '../api/http';
import { ROLE_META, PERMISSION_CODES } from '../constants/roles';
import { useAsync } from '../hooks/hooks';
import { Empty, Modal, Skeleton, StatCard, useConfirm, useToast } from '../components/ui';
import { Unavailable } from '../components/Unavailable';

export function Org() {
  const [tab, setTab] = useState('org');
  const tabs = [['org', '🏢 组织结构'], ['roles', '🛡️ 角色权限'], ['matters', '📌 重要事项'], ['config', '⚙️ 系统配置'], ['audits', '🧾 审计记录']];
  return <div>
    <div className="pd-hero"><h2>🏢 组织 / 角色 / 配置</h2><p>维护公司、部门、团队、角色权限与系统设置。</p></div>
    <div className="pd-row">{tabs.map(([key, label]) => <button key={key} className={'pd-btn ' + (tab === key ? 'primary' : '')} onClick={() => setTab(key)}>{label}</button>)}</div>
    {tab === 'org' && (supports('organization') ? <OrgTab /> : <Unavailable feature="组织管理" />)}
    {tab === 'roles' && (supports('roles') ? <RolesTab /> : <Unavailable feature="角色权限管理" />)}
    {tab === 'matters' && <MattersTab />}
    {tab === 'config' && (supports('config') ? <ConfigTab /> : <Unavailable feature="系统配置" />)}
    {tab === 'audits' && (supports('audits') ? <AuditsTab /> : <Unavailable feature="审计查询" />)}
  </div>;
}

function LoadError({ error, retry }: { error: string; retry: () => void }) {
  return <div className="pd-card" role="alert"><p className="pd-err">{error}</p><button className="pd-btn" onClick={retry}>重试</button></div>;
}

function OrgTab() {
  const departments = useAsync(() => api.listDepartments());
  const teams = useAsync(() => api.listTeams());
  const [adding, setAdding] = useState<'' | 'department' | 'team'>('');
  const [draft, setDraft] = useState({ name: '', description: '', departmentId: '' });
  const [busy, setBusy] = useState(false);
  const toast = useToast();
  const { confirm } = useConfirm();
  const reload = () => { departments.reload(); teams.reload(); };
  const save = async () => {
    if (busy) return;
    if (!draft.name.trim()) return toast.push('err', '请输入名称');
    if (adding === 'team' && !departments.data?.some(d => d.id === draft.departmentId)) return toast.push('err', '请选择有效部门');
    setBusy(true);
    try {
      if (adding === 'department') await api.createDepartment(draft.name.trim(), 1, draft.description.trim());
      else await api.createTeam(draft.name.trim(), Number(draft.departmentId), draft.description.trim());
      toast.push('ok', '已创建'); setAdding(''); reload();
    } catch (e) { toast.push('err', e instanceof Error ? e.message : '创建失败'); }
    finally { setBusy(false); }
  };
  const remove = async (kind: 'departments' | 'teams', id: string) => {
    if (!await confirm({ title: '删除该组织？', desc: '仍有成员或下属组织时不能删除。', danger: true })) return;
    try { await api.deleteUnit(kind, id); reload(); toast.push('ok', '已删除'); }
    catch (e) { toast.push('err', e instanceof Error ? e.message : '删除失败'); }
  };
  if (departments.loading || teams.loading) return <Skeleton rows={4} />;
  if (departments.error || teams.error) return <LoadError error={departments.error || teams.error} retry={reload} />;
  return <>
    <div className="pd-stats"><StatCard icon="📦" value={departments.data?.length ?? 0} label="部门" /><StatCard icon="👥" value={teams.data?.length ?? 0} label="团队" tone={2} /></div>
    {(['department', 'team'] as const).map(kind => <div className="pd-card" key={kind}>
      <div className="pd-card-head"><h3 className="pd-sub">{kind === 'department' ? '📦 部门' : '👥 团队'}</h3><button className="pd-btn primary" onClick={() => { setAdding(kind); setDraft({ name: '', description: '', departmentId: departments.data?.[0]?.id ?? '' }); }}>＋ 新建</button></div>
      <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>名称</th><th>所属组织</th><th>介绍</th><th>操作</th></tr></thead>
        <tbody>{(kind === 'department' ? departments.data : teams.data)?.map(unit => <tr key={unit.id}>
          <td>{unit.name}</td><td>{kind === 'department' ? '公司' : departments.data?.find(d => d.id === unit.parentId)?.name ?? '-'}</td>
          <td>{unit.description || '-'}</td><td><button className="pd-btn danger" onClick={() => remove(kind === 'department' ? 'departments' : 'teams', unit.id)}>删除</button></td>
        </tr>)}</tbody></table></div>
      {(kind === 'department' ? departments.data : teams.data)?.length === 0 && <Empty title="暂无数据" />}
    </div>)}
    {adding && <Modal title={adding === 'department' ? '新建部门' : '新建团队'} onClose={() => !busy && setAdding('')} footer={<button className="pd-btn primary" disabled={busy} onClick={save}>{busy ? '保存中…' : '保存'}</button>}>
      <div style={{ display: 'grid', gap: 12 }}>
        <input className="pd-input" aria-label="组织名称" placeholder="名称" value={draft.name} onChange={e => setDraft({ ...draft, name: e.target.value })} />
        <textarea className="pd-input" placeholder="介绍" value={draft.description} onChange={e => setDraft({ ...draft, description: e.target.value })} />
        {adding === 'team' && <select className="pd-select" aria-label="所属部门" value={draft.departmentId} onChange={e => setDraft({ ...draft, departmentId: e.target.value })}><option value="">选择部门</option>{departments.data?.map(d => <option key={d.id} value={d.id}>{d.name}</option>)}</select>}
      </div>
    </Modal>}
  </>;
}

function RolesTab() {
  const roles = useAsync(() => api.listRoles());
  const permissions = useAsync(() => api.listPermissions());
  const [editing, setEditing] = useState<{ code: string; permissions: string[] } | null>(null);
  const [busy, setBusy] = useState(false);
  const toast = useToast();
  const save = async () => {
    if (!editing || busy) return;
    setBusy(true);
    try { await api.setRolePermissions(editing.code, editing.permissions); roles.reload(); setEditing(null); toast.push('ok', '已保存演示权限'); }
    catch (e) { toast.push('err', e instanceof Error ? e.message : '保存失败'); }
    finally { setBusy(false); }
  };
  if (roles.loading || permissions.loading) return <Skeleton rows={4} />;
  if (roles.error || permissions.error) return <LoadError error={roles.error || permissions.error} retry={() => { roles.reload(); permissions.reload(); }} />;
  return <>
    <div className="pd-card"><h3 className="pd-sub">🛡️ 角色权限</h3><div className="pd-role-grid">{roles.data?.map(role => <div key={role.roleCode} className="pd-role-card">
      <h3>{role.label}</h3><p>{ROLE_META.find(r => r.code === role.roleCode)?.note}</p>
      {role.permissions.map(code => <div key={code}><span className="pd-pill">{code}</span></div>)}
      <button className="pd-btn" onClick={() => setEditing({ code: role.roleCode, permissions: [...role.permissions] })}>编辑权限</button>
    </div>)}</div></div>
    <div className="pd-card"><h3 className="pd-sub">权限码清单</h3><table className="pd-table"><thead><tr><th>权限码</th><th>含义</th></tr></thead><tbody>{permissions.data?.map(p => <tr key={p.code}><td>{p.code}</td><td>{p.name ?? PERMISSION_CODES.find(x => x.code === p.code)?.label ?? '-'}</td></tr>)}</tbody></table></div>
    {editing && <Modal title={'编辑权限 · ' + editing.code} onClose={() => !busy && setEditing(null)} footer={<button className="pd-btn primary" disabled={busy} onClick={save}>保存</button>}>
      {permissions.data?.map(p => <label key={p.code} style={{ display: 'flex', gap: 10, padding: 8 }}><input type="checkbox" checked={editing.permissions.includes(p.code)} onChange={e => setEditing({ ...editing, permissions: e.target.checked ? [...editing.permissions, p.code] : editing.permissions.filter(c => c !== p.code) })} />{p.name ?? p.code}</label>)}
    </Modal>}
  </>;
}

function MattersTab() {
  const [page, setPage] = useState(1);
  const list = useAsync(() => api.listMatters(page, 10), [page]);
  const [dialog, setDialog] = useState(false);
  const [editing, setEditing] = useState<CompanyMatter | null>(null);
  const [draft, setDraft] = useState({ title: '', content: '', sortOrder: 1, deadline: '' });
  const [busy, setBusy] = useState(false);
  const toast = useToast();
  const canWrite = supports('matterWrite');
  const open = (matter: CompanyMatter | null) => {
    setEditing(matter);
    setDraft({ title: matter?.title ?? '', content: matter?.content ?? '', sortOrder: matter?.sortOrder ?? 1, deadline: matter?.deadline ?? '' });
    setDialog(true);
  };
  const save = async () => {
    if (busy || !canWrite) return;
    if (!draft.title.trim() || !draft.content.trim()) return toast.push('err', '名字和备注不能为空');
    if (!Number.isInteger(draft.sortOrder)) return toast.push('err', '排序必须为整数');
    setBusy(true);
    try {
      const value = { ...draft, title: draft.title.trim(), content: draft.content.trim() };
      if (editing) await api.updateMatter(editing.id, value); else await api.createMatter(value);
      setDialog(false); list.reload(); toast.push('ok', '已保存演示事项');
    } catch (e) { toast.push('err', e instanceof Error ? e.message : '保存失败'); }
    finally { setBusy(false); }
  };
  if (list.loading) return <Skeleton rows={3} />;
  if (list.error) return <LoadError error={list.error} retry={list.reload} />;
  return <div className="pd-card">
    <div className="pd-card-head"><h3 className="pd-sub">📌 公司十大重要事项</h3><button className="pd-btn primary" disabled={!canWrite} onClick={() => open(null)}>＋ 新建事项</button></div>
    {!canWrite && <p role="status" className="pd-hint">当前后端仅支持查询，尚无新增、编辑、删除接口，也未提供截止日期字段；本页只读。事项独立于任务派发。</p>}
    {list.data?.items.map(m => <div className="pd-tree-node" key={m.id}><div className="pd-tree-toggle" style={{ cursor: 'default' }}><span><span className="pd-pill">#{m.sortOrder}</span> {m.title}{m.deadline && <span className="pd-pill orange">截止 {m.deadline}</span>}</span><button className="pd-btn" disabled={!canWrite} onClick={() => open(m)}>编辑</button></div><p style={{ padding: '0 16px 12px', whiteSpace: 'pre-wrap' }}>{m.content}</p></div>)}
    {list.data?.total === 0 && <Empty title="暂无事项" />}
    <div className="pd-row"><span>第 {page} 页 · 共 {list.data?.total ?? 0} 条</span><button className="pd-btn" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>上一页</button><button className="pd-btn" disabled={page * 10 >= (list.data?.total ?? 0)} onClick={() => setPage(p => p + 1)}>下一页</button></div>
    {dialog && <Modal title={editing ? '编辑演示事项' : '新建演示事项'} onClose={() => !busy && setDialog(false)} footer={<><button className="pd-btn" disabled={busy} onClick={() => setDialog(false)}>取消</button><button className="pd-btn primary" disabled={busy} onClick={save}>{busy ? '保存中…' : '保存'}</button></>}>
      <div style={{ display: 'grid', gap: 12 }}>
        <input className="pd-input" aria-label="事项名字" placeholder="名字" value={draft.title} onChange={e => setDraft({ ...draft, title: e.target.value })} />
        <textarea className="pd-input" aria-label="事项备注" placeholder="备注" value={draft.content} onChange={e => setDraft({ ...draft, content: e.target.value })} />
        <label>截止日期（仅演示，可选） <input className="pd-input" type="date" value={draft.deadline} onChange={e => setDraft({ ...draft, deadline: e.target.value })} /></label>
        <label>排序 <input className="pd-input" type="number" value={draft.sortOrder} onChange={e => setDraft({ ...draft, sortOrder: Number(e.target.value) })} /></label>
      </div>
    </Modal>}
  </div>;
}

function ConfigTab() {
  const configs = useAsync(() => api.getConfigs());
  const [deadline, setDeadline] = useState('');
  const [busy, setBusy] = useState(false);
  const toast = useToast();
  useEffect(() => { if (configs.data) setDeadline(configs.data.log_deadline ?? ''); }, [configs.data]);
  const save = async () => {
    if (busy) return;
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(deadline)) return toast.push('err', '请输入合法时间 HH:mm');
    setBusy(true);
    try { await api.setConfig('log_deadline', deadline); configs.reload(); toast.push('ok', '已保存'); }
    catch (e) { toast.push('err', e instanceof Error ? e.message : '保存失败'); }
    finally { setBusy(false); }
  };
  if (configs.loading) return <Skeleton rows={2} />;
  if (configs.error) return <LoadError error={configs.error} retry={configs.reload} />;
  return <div className="pd-card"><h3 className="pd-sub">⚙️ 系统配置</h3><p>每日日志提交截止时间</p><div className="pd-row"><input className="pd-input" aria-label="提交截止时间" type="time" value={deadline} onChange={e => setDeadline(e.target.value)} /><button className="pd-btn primary" disabled={busy} onClick={save}>保存</button><button className="pd-btn" onClick={() => setDeadline(configs.data?.log_deadline ?? '')}>还原</button></div></div>;
}

function AuditsTab() {
  const [page, setPage] = useState(1);
  const [actor, setActor] = useState('');
  const [action, setAction] = useState('');
  const [filter, setFilter] = useState({ actor: '', action: '' });
  const audits = useAsync(() => api.listAudits({ ...filter, page, size: 10 }), [page, filter]);
  return <div className="pd-card"><h3 className="pd-sub">🧾 审计记录{isMock() && '（演示）'}</h3>
    <div className="pd-row"><input className="pd-input" placeholder="操作者" value={actor} onChange={e => setActor(e.target.value)} /><input className="pd-input" placeholder="动作" value={action} onChange={e => setAction(e.target.value)} /><button className="pd-btn" onClick={() => { setPage(1); setFilter({ actor, action }); }}>查询</button></div>
    {audits.loading ? <Skeleton rows={3} /> : audits.error ? <LoadError error={audits.error} retry={audits.reload} /> : <>
      <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>操作者</th><th>动作</th><th>目标</th><th>时间</th><th>结果</th></tr></thead><tbody>{audits.data?.items.map(a => <tr key={a.id}><td>{a.actor}</td><td>{a.action}</td><td>{a.target}</td><td>{a.time}</td><td>{a.result}</td></tr>)}</tbody></table></div>
      {audits.data?.total === 0 && <Empty title="暂无审计记录" />}
      <div className="pd-row"><span>第 {page} 页 · 共 {audits.data?.total ?? 0} 条</span><button className="pd-btn" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>上一页</button><button className="pd-btn" disabled={page * 10 >= (audits.data?.total ?? 0)} onClick={() => setPage(p => p + 1)}>下一页</button></div>
    </>}
  </div>;
}
