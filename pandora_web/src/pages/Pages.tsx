import { useEffect, useRef, useState } from 'react';
import { api, type OrgUnit } from '../api/client';
import { supports } from '../api/capabilities';
import { ApiError, isMock } from '../api/http';
import { useAsync } from '../hooks/hooks';
import { useFormValidation } from '../hooks/formValidation';
import { Empty, Modal, Skeleton, useConfirm, useToast } from '../components/ui';
import { Unavailable } from '../components/Unavailable';
import { Icon } from '../components/Icon';
import { labelToCode } from '../constants/roles';
import { duplicateOrganizationNameMessage, organizationNameExists, organizationTextErrors } from '../utils/organizationValidation';

export function Org() {
  return <div>
    <div className="pd-hero"><div><span className="pd-eyebrow">组织与协作</span><h2>组织管理</h2><p>维护部门和团队，让人员归属清晰有序。</p></div></div>
    {supports('organization') ? <OrgTab /> : <Unavailable feature="组织管理" />}
  </div>;
}

function LoadError({ error, retry }: { error: string; retry: () => void }) {
  return <div className="pd-card" role="alert"><p className="pd-err">{error}</p><button className="pd-btn" onClick={retry}>重试</button></div>;
}

async function departmentManager(department: OrgUnit): Promise<string> {
  if (department.managerId === null) return '未分配';
  if (department.managerId !== undefined) {
    const user = await api.getUser(department.managerId);
    if (user.id !== department.managerId || user.departmentId !== department.id || labelToCode(user.role) !== 'DEPT_MANAGER' || !user.name?.trim()) {
      return '负责人资料不一致';
    }
    return user.name;
  }
  // 兼容部门响应未带 managerId 的版本，按 ID 和角色交叉核对查询结果。
  const users = await api.listUsers({ departmentId: department.id, role: 'DEPT_MANAGER', page: 1, size: 2 });
  if (users.total === 0 && users.items.length === 0) return '未分配';
  const [user] = users.items;
  if (users.total !== 1 || users.items.length !== 1 || user.departmentId !== department.id || labelToCode(user.role) !== 'DEPT_MANAGER' || !user.name?.trim()) {
    return '负责人资料不一致';
  }
  return user.name;
}

function DepartmentIntro({ department, onClose }: { department: OrgUnit; onClose: () => void }) {
  const manager = useAsync(() => departmentManager(department), [department.id, department.managerId]);
  return <Modal title={'部门介绍 · ' + department.name} onClose={onClose}>
    <dl className="pd-record-details">
      <div><dt>负责人</dt><dd>{manager.loading ? '加载中…' : manager.error ? <>读取失败 <button className="pd-btn text" onClick={manager.reload}>重试</button></> : manager.data}</dd></div>
      <div><dt>介绍</dt><dd>{department.description?.trim() || '暂无部门介绍'}</dd></div>
    </dl>
  </Modal>;
}

function OrgTab() {
  const companies = useAsync(() => api.listCompanies());
  const departments = useAsync(() => api.listDepartments());
  const teams = useAsync(() => api.listTeams());
  const [adding, setAdding] = useState<'' | 'department' | 'team'>('');
  const [draft, setDraft] = useState({ name: '', description: '', departmentId: '' });
  const [departmentDetailsId, setDepartmentDetails] = useState<string | null>(null);
  const [selectedTeam, setSelectedTeam] = useState<OrgUnit | null>(null);
  const [departmentFilter, setDepartmentFilter] = useState('');
  const [busy, setBusy] = useState(false);
  const pending = useRef(false);
  const [saveError, setSaveError] = useState('');
  const [nameConflict, setNameConflict] = useState(false);
  const toast = useToast();
  const { confirm } = useConfirm();
  const companyIds = (companies.data ?? []).map(company => company.id);
  const companyId = companyIds.length === 1 ? companyIds[0] : undefined;
  const units = adding === 'department' ? departments.data : teams.data;
  const parentId = adding === 'department' ? companyId : draft.departmentId;
  const textErrors = organizationTextErrors(draft.name, draft.description);
  const errors = {
    name: textErrors.name || (nameConflict || (parentId && organizationNameExists(units ?? [], parentId, draft.name)) ? duplicateOrganizationNameMessage : ''),
    description: textErrors.description,
    departmentId: adding === 'team' && !departments.data?.some(d => d.id === draft.departmentId) ? '请选择有效部门' : '',
  };
  const validation = useFormValidation('organization-form', errors);
  const feedback = (field: keyof typeof errors) => validation.error(field) && <small id={validation.errorId(field)} className="pd-field-error" role="alert">{validation.error(field)}</small>;
  const openCreate = (kind: 'department' | 'team') => {
    validation.reset(); setSaveError(''); setNameConflict(false); setAdding(kind);
    const departmentId = kind === 'team' ? departmentFilter || departments.data?.[0]?.id || '' : '';
    setDraft({ name: '', description: '', departmentId });
  };
  const departmentDetails = departments.data?.find(department => department.id === departmentDetailsId);
  useEffect(() => { if (!departments.loading && departmentFilter && !departments.data?.some(unit => unit.id === departmentFilter)) setDepartmentFilter(''); }, [departments.data, departments.loading, departmentFilter]);
  const visibleTeams = (teams.data ?? []).filter(team => !departmentFilter || team.parentId === departmentFilter);
  const reload = () => { companies.reload(); departments.reload(); teams.reload(); };
  const save = async () => {
    if (pending.current) return;
    validation.showAll();
    const first = (Object.keys(errors) as (keyof typeof errors)[]).find(field => errors[field]);
    if (first) { validation.focus(first); return; }
    if (adding === 'department' && !companyId) return setSaveError('公司归属尚未明确，暂时无法创建部门');
    setSaveError('');
    pending.current = true;
    setBusy(true);
    try {
      const created = adding === 'department'
        ? await api.createDepartment(draft.name, Number(companyId), draft.description)
        : await api.createTeam(draft.name, Number(draft.departmentId), draft.description);
      if (created?.id == null) throw new Error('创建结果缺少组织编号，请刷新核对后再操作');
      toast.push('ok', '已创建'); setAdding(''); reload();
    } catch (e) {
      if ((e instanceof ApiError && e.httpStatus === 409 && e.code === 40907)
        || (e instanceof Error && e.message === duplicateOrganizationNameMessage)) {
        setNameConflict(true);
        requestAnimationFrame(() => validation.focus('name'));
      } else setSaveError(e instanceof Error ? e.message : '创建失败');
    }
    finally { pending.current = false; setBusy(false); }
  };
  const remove = async (kind: 'departments' | 'teams', id: string) => {
    if (!await confirm({ title: '删除该组织？', desc: '仍有成员或下属组织时不能删除。', danger: true })) return;
    try { await api.deleteUnit(kind, id); reload(); toast.push('ok', '已删除'); }
    catch (e) { toast.push('err', e instanceof Error ? e.message : '删除失败'); }
  };
  if (companies.loading || departments.loading || teams.loading) return <Skeleton rows={4} />;
  if (companies.error || departments.error || teams.error) return <LoadError error={companies.error || departments.error || teams.error} retry={reload} />;
  return <>
    <div className="pd-org-workspace"><section className="pd-card pd-departments"><div className="pd-card-head"><h3 className="pd-sub">部门 <span className="pd-count">{departments.data?.length ?? 0}</span></h3><div className="pd-actions"><button className="pd-btn text" onClick={reload}>刷新</button><button className="pd-btn text" disabled={!companyId} onClick={() => openCreate('department')}>新建部门</button></div></div>
      {!companyId && <p className="pd-hint">公司归属信息尚未明确，暂时无法创建部门。</p>}
      <button className={'pd-department-all ' + (!departmentFilter ? 'selected' : '')} aria-pressed={!departmentFilter} onClick={() => setDepartmentFilter('')}><Icon name="org" />全部部门<span>{teams.data?.length ?? 0} 个团队</span></button>
      <div className="pd-department-list">{departments.data?.map(department => <div className={'pd-department-row ' + (departmentFilter === department.id ? 'selected' : '')} key={department.id}>
        <div className="pd-department-main">
          <button className="pd-department-select" title={department.name} aria-pressed={departmentFilter === department.id} onClick={() => setDepartmentFilter(department.id)}><span className="pd-department-glyph"><Icon name="org" /></span><b>{department.name}</b></button>
          <button className="pd-btn text pd-department-intro" type="button" aria-label={`查看${department.name}介绍`} onClick={() => setDepartmentDetails(department.id)}>查看介绍</button>
        </div>
        <button className="pd-btn ghost pd-department-delete" aria-label={'删除部门' + department.name} title="删除部门" onClick={() => remove('departments', department.id)}><Icon name="trash" /></button>
      </div>)}</div>
      {departments.data?.length === 0 && <Empty title="暂无部门" />}
    </section><section className="pd-card pd-teams"><div className="pd-card-head"><div><h3 className="pd-sub">{departments.data?.find(unit => unit.id === departmentFilter)?.name ?? '全部团队'} <span className="pd-count">{visibleTeams.length}</span></h3><p className="pd-hint">选择团队，查看人员与组织归属</p></div><button className="pd-btn primary" disabled={!departments.data?.length} onClick={() => openCreate('team')}><Icon name="plus" />新建团队</button></div>
      <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>团队</th><th>所属部门</th><th>介绍</th><th>操作</th></tr></thead><tbody>{visibleTeams.map(team => <tr key={team.id}><td>{team.name}</td><td>{departments.data?.find(unit => unit.id === team.parentId)?.name ?? '-'}</td><td>{team.description || '-'}</td><td><div className="pd-table-actions"><button className="pd-btn text" onClick={() => setSelectedTeam(team)}>查看人员</button><button className="pd-btn text danger" onClick={() => remove('teams', team.id)}>删除</button></div></td></tr>)}</tbody></table></div>
      {!visibleTeams.length && <Empty title={departmentFilter ? '该部门暂无团队' : '暂无团队'} />}
    </section></div>
    {departmentDetails && <DepartmentIntro key={departmentDetails.id} department={departmentDetails} onClose={() => setDepartmentDetails(null)} />}
    {selectedTeam && <Modal title={'团队人员 · ' + selectedTeam.name} onClose={() => setSelectedTeam(null)}>
      <p className="pd-hint">{departments.data?.find(d => d.id === selectedTeam.parentId)?.name ?? '未提供所属部门'} / {selectedTeam.name}</p>
      {supports('users') ? <TeamMembers key={selectedTeam.id} teamId={selectedTeam.id} /> : <Unavailable feature="团队成员查询" />}
    </Modal>}
    {adding && <Modal title={adding === 'department' ? '新建部门' : '新建团队'} onClose={() => !pending.current && setAdding('')} footer={<button className="pd-btn primary" type="submit" form="organization-form" disabled={busy}>{busy ? '保存中…' : '保存'}</button>}>
      <form id="organization-form" noValidate onSubmit={event => { event.preventDefault(); save(); }}>
        <fieldset className="pd-form-section pd-form" aria-label="组织资料" disabled={busy}>
          <label>名称<input className="pd-input" {...validation.field('name')} aria-label="组织名称" required value={draft.name} onChange={e => { setDraft({ ...draft, name: e.target.value }); setSaveError(''); setNameConflict(false); }} />{feedback('name')}</label>
          <label>介绍<textarea className="pd-input" {...validation.field('description')} aria-label="介绍" value={draft.description} onChange={e => { setDraft({ ...draft, description: e.target.value }); setSaveError(''); }} />{feedback('description')}</label>
          {adding === 'team' && <label>所属部门<select className="pd-select" {...validation.field('departmentId')} aria-label="所属部门" required value={draft.departmentId} onChange={e => { setDraft({ ...draft, departmentId: e.target.value }); setSaveError(''); setNameConflict(false); }}><option value="">选择部门</option>{departments.data?.map(d => <option key={d.id} value={d.id}>{d.name}</option>)}</select>{feedback('departmentId')}</label>}
          {saveError && <p className="pd-inline-error" role="alert">{saveError}</p>}
        </fieldset>
      </form>
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
