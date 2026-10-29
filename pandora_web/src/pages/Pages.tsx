import { useEffect, useState } from 'react';
import { api, type AuditRow, type OrgUnit } from '../api/client';
import { supports } from '../api/capabilities';
import { isMock } from '../api/http';
import { useAsync } from '../hooks/hooks';
import { Empty, Modal, Skeleton, useConfirm, useToast } from '../components/ui';
import { Unavailable } from '../components/Unavailable';
import { Icon } from '../components/Icon';

export function Org() {
  const [tab, setTab] = useState('org');
  return <div>
    <div className="pd-hero"><div><h2>组织管理</h2><p>维护部门与团队，查看成员及操作记录</p></div></div>
    <div className="pd-tabs" role="tablist" aria-label="组织管理">
      <button role="tab" id="org-tab" aria-controls="org-panel" aria-selected={tab === 'org'} onClick={() => setTab('org')}>组织结构</button>
      <button role="tab" id="audits-tab" aria-controls="audits-panel" aria-selected={tab === 'audits'} onClick={() => setTab('audits')}>审计记录</button>
    </div>
    {tab === 'org' && <div id="org-panel" role="tabpanel" aria-labelledby="org-tab">{supports('organization') ? <OrgTab /> : <Unavailable feature="组织管理" />}</div>}
    {tab === 'audits' && <div id="audits-panel" role="tabpanel" aria-labelledby="audits-tab">{supports('audits') ? <AuditsTab /> : <Unavailable feature="审计查询" />}</div>}
  </div>;
}

function LoadError({ error, retry }: { error: string; retry: () => void }) {
  return <div className="pd-card" role="alert"><p className="pd-err">{error}</p><button className="pd-btn" onClick={retry}>重试</button></div>;
}

function OrgTab() {
  const companies = useAsync(() => api.listCompanies());
  const departments = useAsync(() => api.listDepartments());
  const teams = useAsync(() => api.listTeams());
  const [adding, setAdding] = useState<'' | 'department' | 'team'>('');
  const [draft, setDraft] = useState({ name: '', description: '', departmentId: '' });
  const [selectedTeam, setSelectedTeam] = useState<OrgUnit | null>(null);
  const [departmentFilter, setDepartmentFilter] = useState('');
  const [busy, setBusy] = useState(false);
  const toast = useToast();
  const { confirm } = useConfirm();
  const companyIds = (companies.data ?? []).map(company => company.id);
  const companyId = companyIds.length === 1 ? companyIds[0] : undefined;
  useEffect(() => { if (!departments.loading && departmentFilter && !departments.data?.some(unit => unit.id === departmentFilter)) setDepartmentFilter(''); }, [departments.data, departments.loading, departmentFilter]);
  const visibleTeams = (teams.data ?? []).filter(team => !departmentFilter || team.parentId === departmentFilter);
  const reload = () => { companies.reload(); departments.reload(); teams.reload(); };
  const save = async () => {
    if (busy) return;
    if (!draft.name.trim()) return toast.push('err', '请输入名称');
    if (adding === 'department' && !companyId) return toast.push('err', '公司归属尚未明确，暂时无法创建部门');
    if (adding === 'team' && !departments.data?.some(d => d.id === draft.departmentId)) return toast.push('err', '请选择有效部门');
    setBusy(true);
    try {
      if (adding === 'department') await api.createDepartment(draft.name.trim(), Number(companyId), draft.description.trim());
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
  if (companies.loading || departments.loading || teams.loading) return <Skeleton rows={4} />;
  if (companies.error || departments.error || teams.error) return <LoadError error={companies.error || departments.error || teams.error} retry={reload} />;
  return <>
    <div className="pd-org-workspace"><section className="pd-card pd-departments"><div className="pd-card-head"><h3 className="pd-sub">部门 <span className="pd-count">{departments.data?.length ?? 0}</span></h3><button className="pd-btn text" disabled={!companyId} onClick={() => { setAdding('department'); setDraft({ name: '', description: '', departmentId: '' }); }}>新建部门</button></div>
      {!companyId && <p className="pd-hint">公司归属信息尚未明确，暂时无法创建部门。</p>}
      <button className={'pd-department-all ' + (!departmentFilter ? 'selected' : '')} aria-pressed={!departmentFilter} onClick={() => setDepartmentFilter('')}><Icon name="org" />全部部门<span>{teams.data?.length ?? 0} 个团队</span></button>
      <div className="pd-department-list">{departments.data?.map(department => <div className={'pd-department-row ' + (departmentFilter === department.id ? 'selected' : '')} key={department.id}>
        <button className="pd-department-select" aria-label={department.name} aria-pressed={departmentFilter === department.id} onClick={() => setDepartmentFilter(department.id)}><span className="pd-department-glyph"><Icon name="org" /></span><span><b>{department.name}</b><small title={department.description}>{department.description || '暂无部门介绍'}</small></span></button>
        <button className="pd-btn ghost pd-department-delete" aria-label={'删除部门' + department.name} title="删除部门" onClick={() => remove('departments', department.id)}><Icon name="trash" /></button>
      </div>)}</div>
      {departments.data?.length === 0 && <Empty title="暂无部门" />}
    </section><section className="pd-card pd-teams"><div className="pd-card-head"><div><h3 className="pd-sub">{departments.data?.find(unit => unit.id === departmentFilter)?.name ?? '全部团队'} <span className="pd-count">{visibleTeams.length}</span></h3><p className="pd-hint">选择团队，查看人员与组织归属</p></div><button className="pd-btn primary" disabled={!departments.data?.length} onClick={() => { setAdding('team'); setDraft({ name: '', description: '', departmentId: departmentFilter || departments.data?.[0]?.id || '' }); }}><Icon name="plus" />新建团队</button></div>
      <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>团队</th><th>所属部门</th><th>介绍</th><th>操作</th></tr></thead><tbody>{visibleTeams.map(team => <tr key={team.id}><td>{team.name}</td><td>{departments.data?.find(unit => unit.id === team.parentId)?.name ?? '-'}</td><td>{team.description || '-'}</td><td><div className="pd-table-actions"><button className="pd-btn text" onClick={() => setSelectedTeam(team)}>查看人员</button><button className="pd-btn text danger" onClick={() => remove('teams', team.id)}>删除</button></div></td></tr>)}</tbody></table></div>
      {!visibleTeams.length && <Empty title={departmentFilter ? '该部门暂无团队' : '暂无团队'} />}
    </section></div>
    {selectedTeam && <Modal title={'团队人员 · ' + selectedTeam.name} onClose={() => setSelectedTeam(null)}>
      <p className="pd-hint">{departments.data?.find(d => d.id === selectedTeam.parentId)?.name ?? '未提供所属部门'} / {selectedTeam.name}</p>
      {supports('users') ? <TeamMembers key={selectedTeam.id} teamId={selectedTeam.id} /> : <Unavailable feature="团队成员查询" />}
    </Modal>}
    {adding && <Modal title={adding === 'department' ? '新建部门' : '新建团队'} onClose={() => !busy && setAdding('')} footer={<button className="pd-btn primary" disabled={busy} onClick={save}>{busy ? '保存中…' : '保存'}</button>}>
      <div className="pd-form">
        <label>名称<input className="pd-input" aria-label="组织名称" placeholder="请输入名称" value={draft.name} onChange={e => setDraft({ ...draft, name: e.target.value })} /></label>
        <label>介绍<textarea className="pd-input" value={draft.description} onChange={e => setDraft({ ...draft, description: e.target.value })} /></label>
        {adding === 'team' && <label>所属部门<select className="pd-select" value={draft.departmentId} onChange={e => setDraft({ ...draft, departmentId: e.target.value })}><option value="">选择部门</option>{departments.data?.map(d => <option key={d.id} value={d.id}>{d.name}</option>)}</select></label>}
      </div>
    </Modal>}
  </>;
}

function TeamMembers({ teamId }: { teamId: string }) {
  const [keyword, setKeyword] = useState('');
  const [query, setQuery] = useState('');
  const [page, setPage] = useState(1);
  const members = useAsync(() => api.listTeamMembers(teamId, { keyword: query, page, size: 5 }), [teamId, query, page]);
  return <div className="pd-team-members">
    <form className="pd-row" onSubmit={e => { e.preventDefault(); setPage(1); setQuery(keyword.trim()); members.reload(); }}>
      <input className="pd-input" aria-label="搜索团队人员" placeholder="姓名或账号" value={keyword} onChange={e => setKeyword(e.target.value)} />
      <button className="pd-btn primary" type="submit">查询</button>
      <button className="pd-btn" type="button" onClick={() => { setKeyword(''); setQuery(''); setPage(1); members.reload(); }}>清空</button>
    </form>
    {members.loading ? <Skeleton rows={3} /> : members.error ? <LoadError error={members.error} retry={members.reload} /> : <>
      <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>姓名</th><th>账号</th><th>角色</th><th>状态</th></tr></thead>
        <tbody>{members.data?.items.map(user => <tr key={user.id}><td>{user.name}</td><td>{user.username}</td><td>{user.role}</td><td><span className={'pd-pill ' + (user.status === '启用' ? 'green' : 'red')}>{user.status}</span></td></tr>)}</tbody>
      </table></div>
      {members.data?.total === 0 && <Empty title={query ? '未找到匹配成员' : '该团队暂无成员'} />}
      <div className="pd-row"><span>第 {page} 页 · 共 {members.data?.total ?? 0} 人</span><button className="pd-btn" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>上一页</button><button className="pd-btn" disabled={page * 5 >= (members.data?.total ?? 0)} onClick={() => setPage(p => p + 1)}>下一页</button></div>
    </>}
  </div>;
}

function AuditsTab() {
  const [page, setPage] = useState(1);
  const [actor, setActor] = useState('');
  const [action, setAction] = useState('');
  const [filter, setFilter] = useState({ actor: '', action: '' });
  const [detail, setDetail] = useState<AuditRow | null>(null);
  const audits = useAsync(() => api.listAudits({ ...filter, page, size: 10 }), [page, filter]);
  return <div className="pd-card"><h3 className="pd-sub">操作记录{isMock() && <span className="pd-count">演示样例</span>}</h3>
    <p className="pd-hint">查询操作人、具体动作、操作对象、发生时间和结果。记录只读。</p>
    <form className="pd-row" onSubmit={e => { e.preventDefault(); setPage(1); setFilter({ actor: actor.trim(), action: action.trim() }); }}>
      <input className="pd-input" aria-label="审计操作者" placeholder="操作者" value={actor} onChange={e => setActor(e.target.value)} />
      <input className="pd-input" aria-label="审计动作" placeholder="动作" value={action} onChange={e => setAction(e.target.value)} />
      <button className="pd-btn primary" type="submit">查询</button>
      <button className="pd-btn" type="button" onClick={() => { setActor(''); setAction(''); setPage(1); setFilter({ actor: '', action: '' }); }}>清空</button>
    </form>
    {audits.loading ? <Skeleton rows={3} /> : audits.error ? <LoadError error={audits.error} retry={audits.reload} /> : <>
      <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>操作者</th><th>动作</th><th>对象</th><th>时间</th><th>结果</th><th>操作</th></tr></thead><tbody>{audits.data?.items.map(a => <tr key={a.id}><td>{a.actor}</td><td>{a.action}</td><td>{a.target}</td><td>{a.time}</td><td>{a.result}</td><td><button className="pd-btn" onClick={() => setDetail(a)}>查看详情</button></td></tr>)}</tbody></table></div>
      {audits.data?.total === 0 && <Empty title="暂无审计记录" />}
      <div className="pd-row"><span>第 {page} 页 · 共 {audits.data?.total ?? 0} 条</span><button className="pd-btn" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>上一页</button><button className="pd-btn" disabled={page * 10 >= (audits.data?.total ?? 0)} onClick={() => setPage(p => p + 1)}>下一页</button></div>
    </>}
    {detail && <Modal title="操作记录详情" onClose={() => setDetail(null)}>
      <dl className="pd-record-details">{[['记录编号', detail.id], ['操作者', detail.actor], ['动作', detail.action], ['操作对象', detail.target], ['发生时间', detail.time], ['结果', detail.result]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value || '未提供'}</dd></div>)}</dl>
    </Modal>}
  </div>;
}
