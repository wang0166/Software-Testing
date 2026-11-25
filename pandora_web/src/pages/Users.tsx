import { useEffect, useRef, useState } from 'react';
import { api, type UserRow } from '../api/client';
import { ROLE_META, ROLES, USER_STATUS } from '../constants/roles';
import { useAsync, useDebounce } from '../hooks/hooks';
import { useFormValidation } from '../hooks/formValidation';
import { downloadCSV, writeOpLog } from '../utils/export';
import { Empty, Modal, Skeleton, useConfirm, useToast } from '../components/ui';
import { supports } from '../api/capabilities';
import { ApiError, isMock } from '../api/http';
import { Unavailable } from '../components/Unavailable';
import { identityError, normalizeIdentity } from '../utils/identity';
import { Icon } from '../components/Icon';
import { PasswordField } from '../components/PasswordField';
import { duplicateUserMessages, generateStrongPassword, nameError, passwordError } from '../utils/userValidation';

const PAGE_SIZE = 10;
const emptyForm = () => ({ username: '', name: '', password: '', dept: '', team: '', role: '组员', idNumber: '', gender: '', phone: '' });

type UserField = keyof ReturnType<typeof emptyForm>;
type UserErrors = Partial<Record<UserField, string>>;
const fieldOrder: UserField[] = ['phone', 'username', 'name', 'gender', 'idNumber', 'password', 'role', 'dept', 'team'];

export function Users() {
  return supports('users') ? <UsersContent /> : <><div className="pd-hero"><h2>用户管理</h2><p>管理账号、角色与组织归属</p></div><Unavailable feature="用户管理" /></>;
}

function UsersContent() {
  const [q, setQ] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [page, setPage] = useState(1);
  const dq = useDebounce(q);
  // 分页和筛选交给数据层；真实模式完全不读取本地演示补丁。
  const list = useAsync(() => api.listUsers({ keyword: dq.trim(), role: roleFilter, status: statusFilter, page, size: PAGE_SIZE }), [dq, roleFilter, statusFilter, page]);
  const departments = useAsync(() => supports('organization') ? api.listDepartments() : Promise.resolve([]));
  const teams = useAsync(() => supports('organization') ? api.listTeams() : Promise.resolve([]));
  const [editing, setEditing] = useState<UserRow | null>(null);
  const [showAdd, setShowAdd] = useState(false);
  const [form, setForm] = useState(emptyForm);
  const [saving, setSaving] = useState(false);
  const userPending = useRef(false);
  const [usernameEdited, setUsernameEdited] = useState(false);
  const [formErr, setFormErr] = useState('');
  const [serverErrors, setServerErrors] = useState<UserErrors>({});
  const [detail, setDetail] = useState<UserRow | null>(null);
  const [pwTarget, setPwTarget] = useState<UserRow | null>(null);
  const [pwValue, setPwValue] = useState('');
  const [pwError, setPwError] = useState('');
  const resetPending = useRef(false);
  const [actionBusy, setActionBusy] = useState('');
  const toast = useToast();
  const { confirm } = useConfirm();
  const demo = isMock();
  const rows = list.data?.items ?? [];
  const total = list.data?.total ?? 0;
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE));
  const orgReady = supports('organization') && !departments.loading && !teams.loading && !departments.error && !teams.error;
  useEffect(() => { if (!list.loading && !list.error && page > pages) setPage(pages); }, [list.loading, list.error, page, pages]);
  const roleMeta = ROLE_META.find(role => role.label === form.role);
  const deptLocked = roleMeta?.departmentId === '必须为空';
  const teamLocked = roleMeta?.teamId === '必须为空';
  const selectedDepartment = departments.data?.find(d => d.id === form.dept);
  const teamOptions = (teams.data ?? []).filter(t => t.parentId === form.dept);
  const selectedTeam = teamOptions.find(team => team.id === form.team);
  const changesIdentity = !!editing && !!form.idNumber.trim();
  const errors: UserErrors = {
    ...serverErrors,
    name: nameError(form.name) || serverErrors.name,
    role: roleMeta ? serverErrors.role : '请选择有效角色',
    dept: deptLocked ? undefined : !selectedDepartment ? '请选择有效部门'
      : roleMeta?.code === 'DEPT_MANAGER' && selectedDepartment.managerId && selectedDepartment.managerId !== editing?.id
        ? '该部门已有负责人' : serverErrors.dept,
    team: teamLocked || !selectedDepartment ? undefined : !selectedTeam ? '请选择该部门下的团队'
      : roleMeta?.code === 'TEAM_LEADER' && selectedTeam.leaderId && selectedTeam.leaderId !== editing?.id
        ? '该团队已有负责人' : serverErrors.team,
  };
  if (!editing || changesIdentity) errors.idNumber = identityError(form.idNumber) || serverErrors.idNumber;
  if (!editing) {
    if (!/^1\d{10}$/.test(form.phone.trim())) errors.phone = '请输入以 1 开头的 11 位手机号';
    if (!/^[a-z0-9_]{3,20}$/.test(form.username.trim())) errors.username = '账户名需为 3～20 位小写字母、数字或下划线';
    errors.password = passwordError(form.password) || serverErrors.password;
    if (!['', '男', '女'].includes(form.gender)) errors.gender = '请选择有效的性别选项';
  }
  const validation = useFormValidation('user-form', errors);
  const pwValidation = useFormValidation('user-reset-form', { password: passwordError(pwValue) });
  const feedback = (field: UserField) => validation.error(field) && <small id={validation.errorId(field)} className="pd-field-error" role="alert">{validation.error(field)}</small>;

  const openUser = (user: UserRow | null) => {
    setEditing(user); setFormErr(''); setServerErrors({}); setUsernameEdited(false); validation.reset();
    setForm(user ? { username: user.username, name: user.name, password: '', dept: user.departmentId ?? '', team: user.teamId ?? '',
      role: user.role, idNumber: '', gender: user.gender ?? '', phone: user.phone ?? '' } : emptyForm());
    setShowAdd(true);
  };
  const closeUser = () => {
    if (userPending.current) return;
    setShowAdd(false); setEditing(null); setFormErr(''); setForm(emptyForm()); setUsernameEdited(false);
  };
  const changeUser = (patch: Partial<ReturnType<typeof emptyForm>>) => {
    setForm(current => ({ ...current, ...patch }));
    setServerErrors(current => {
      const updated = { ...current };
      for (const field of Object.keys(patch) as UserField[]) delete updated[field];
      return updated;
    });
    setFormErr('');
  };
  const saveUser = async () => {
    if (userPending.current) return;
    validation.showAll();
    const first = fieldOrder.find(field => !!errors[field]);
    if (first) { validation.focus(first); return; }
    const identity = { username: form.username.trim(), phone: form.phone.trim(), idNumber: normalizeIdentity(form.idNumber) };
    userPending.current = true;
    setSaving(true); setFormErr('');
    let errorField: UserField | undefined;
    let updatingIdentity = false;
    try {
      const assignment = { realName: form.name.trim(), role: form.role, departmentId: deptLocked ? null : Number(selectedDepartment!.id), teamId: teamLocked ? null : Number(selectedTeam!.id) };
      const duplicates = !editing ? await api.findDuplicateUserFields(identity)
        : changesIdentity ? await api.findDuplicateUserFields({ idNumber: identity.idNumber }, editing.id) : [];
      if (duplicates.length) {
        setServerErrors(Object.fromEntries(duplicates.map(field => [field, duplicateUserMessages[field]])));
        errorField = fieldOrder.find(field => duplicates.some(duplicate => duplicate === field));
        return;
      }
      if (editing) {
        updatingIdentity = changesIdentity;
        await api.updateUser(editing.id, { ...assignment, idNumber: changesIdentity ? identity.idNumber : undefined });
      }
      else {
        const created = await api.createUser({ ...assignment, ...identity, password: form.password, gender: form.gender });
        if (created?.id == null) throw new Error('创建响应缺少用户编号，请刷新核对结果后再操作');
      }
      if (demo) writeOpLog(editing ? '编辑用户' : '创建用户', '本地演示操作');
      toast.push('ok', demo ? '演示账号已保存' : '账号已保存');
      setShowAdd(false); setEditing(null); setForm(emptyForm()); setUsernameEdited(false); setDetail(null);
      list.reload(); departments.reload(); teams.reload();
    } catch (error) {
      let message = '';
      if (error instanceof ApiError && error.httpStatus === 409) {
        if (error.field === 'username' || error.field === 'phone' || error.field === 'idNumber') errorField = error.field;
        else if (error.code === 40906) errorField = 'username';
        else if (error.code === 40905) errorField = roleMeta?.code === 'DEPT_MANAGER' ? 'dept' : roleMeta?.code === 'TEAM_LEADER' ? 'team' : 'role';
        else if (/手机号|电话号码|phone/i.test(error.message)) errorField = 'phone';
        else if (/身份证|idNumber/i.test(error.message)) errorField = 'idNumber';
      }
      if (updatingIdentity && error instanceof ApiError && error.httpStatus === 400 && (!error.field || error.field === 'idNumber')) {
        errorField = 'idNumber';
        message = '服务器拒绝了这次身份证号修改。请核对号码和后端接口版本。';
      }
      if (errorField) {
        message ||= errorField === 'phone' || errorField === 'idNumber' || errorField === 'username'
          ? duplicateUserMessages[errorField] : '该负责人岗位已有其他用户';
        setServerErrors({ [errorField]: message });
      } else setFormErr(error instanceof Error ? error.message : '保存失败');
    } finally {
      userPending.current = false;
      setSaving(false);
      if (errorField) { const field = errorField; requestAnimationFrame(() => validation.focus(field)); }
    }
  };
  const toggleStatus = async (user: UserRow) => {
    if (actionBusy) return;
    const enabled = user.status !== '启用';
    if (!enabled && !await confirm({ title: '停用此账号？', desc: '停用后，该账号将无法登录。', okText: '停用', danger: true })) return;
    setActionBusy(user.id);
    try {
      await api.setUserStatus(user.id, enabled);
      if (demo) writeOpLog(enabled ? '启用账号' : '停用账号', '本地演示操作');
      toast.push('ok', enabled ? '账号已启用' : '账号已停用'); setDetail(null); list.reload();
    } catch (error) { toast.push('err', error instanceof Error ? error.message : '操作失败'); }
    finally { setActionBusy(''); }
  };
  const remove = async (user: UserRow) => {
    if (!demo || !await confirm({ title: '移除此演示账号？', desc: '仅影响本地演示数据，可通过恢复演示数据重置。', okText: '移除', danger: true })) return;
    api.removeDemoUser(user.id); writeOpLog('移除用户', '本地演示操作'); list.reload(); setDetail(null); toast.push('ok', '演示账号已移除');
  };
  const resetDemo = async () => {
    if (!demo || !await confirm({ title: '恢复演示数据？', desc: '清除本浏览器的演示账号新增、编辑、状态和移除记录。', okText: '恢复', danger: true })) return;
    api.resetDemoUsers(); setQ(''); setRoleFilter(''); setStatusFilter(''); setPage(1); list.reload(); toast.push('ok', '已恢复演示数据');
  };
  const closePassword = () => { if (!resetPending.current) { setPwTarget(null); setPwValue(''); setPwError(''); } };
  const resetPassword = async () => {
    if (!pwTarget || actionBusy || resetPending.current) return;
    pwValidation.showAll();
    if (passwordError(pwValue)) { pwValidation.focus('password'); return; }
    resetPending.current = true;
    setPwError('');
    setActionBusy(pwTarget.id);
    try {
      await api.resetPassword(pwTarget.id, pwValue);
      if (demo) writeOpLog('重置密码', '本地演示操作');
      setPwTarget(null); setPwValue(''); setPwError(''); toast.push('ok', demo ? '演示重置操作已完成，不保存密码' : '密码已重置');
    } catch (error) { setPwError(error instanceof Error ? error.message : '重置失败'); }
    finally { resetPending.current = false; setActionBusy(''); }
  };

  return <div>
    <div className="pd-hero"><div><span className="pd-eyebrow">人员与账号</span><h2>用户管理 <span className="pd-heading-count">{list.loading ? '…' : total}</span></h2><p>维护成员账号和组织归属</p></div><button className="pd-btn primary" disabled={!orgReady} onClick={() => openUser(null)}><Icon name="plus" />新增用户</button></div>
    {!orgReady && <div className="pd-notice">组织信息尚未就绪，暂时无法新增或调整归属。{(departments.error || teams.error) && <button className="pd-btn text" onClick={() => { departments.reload(); teams.reload(); }}>重新加载</button>}</div>}
    <div className="pd-card pd-user-list">
      <div className="pd-card-head pd-list-head"><h3 className="pd-sub">{q || roleFilter || statusFilter ? '筛选结果' : '全部账号'}</h3><div className="pd-actions">
        <button className="pd-btn quiet" disabled={list.loading || !!list.error || !rows.length} onClick={() => downloadCSV('users-page-' + page + '.csv', [['账号', '姓名', '部门', '团队', '角色', '状态'], ...rows.map(user => [user.username, user.name, user.dept, user.team, user.role, user.status])])}><Icon name="download" />导出当前页</button>
        {demo && <button className="pd-btn quiet" onClick={resetDemo}>恢复演示数据</button>}
      </div></div>
      <div className="pd-filter-row"><div className="pd-search-field"><Icon name="search" /><input className="pd-input" aria-label="搜索用户" placeholder="搜索账号或姓名" value={q} onChange={e => { setQ(e.target.value); setPage(1); }} /></div>
        <select className="pd-select" aria-label="筛选角色" value={roleFilter} onChange={e => { setRoleFilter(e.target.value); setPage(1); }}><option value="">全部角色</option>{ROLES.map(role => <option key={role}>{role}</option>)}</select>
        <select className="pd-select" aria-label="筛选状态" value={statusFilter} onChange={e => { setStatusFilter(e.target.value); setPage(1); }}><option value="">全部状态</option>{USER_STATUS.map(status => <option key={status}>{status}</option>)}</select>
        <button className="pd-btn" onClick={() => { setQ(''); setRoleFilter(''); setStatusFilter(''); setPage(1); list.reload(); }}>重置筛选</button>
      </div>
      {list.loading ? <Skeleton rows={5} /> : list.error ? <div className="pd-inline-error" role="alert"><span>{list.error}</span><button className="pd-btn" onClick={list.reload}>重试</button></div> : <>
        <div className="pd-scroll-x"><table className="pd-table"><thead><tr><th>成员</th><th>组织归属</th><th>角色</th><th>状态</th><th>操作</th></tr></thead><tbody>{rows.map(user => <tr key={user.id}>
          <td><button className="pd-member" aria-label={user.username} onClick={() => setDetail(user)}><span className={'pd-member-avatar tone-' + (user.name.charCodeAt(0) % 4)} aria-hidden="true">{user.name.slice(0, 1)}</span><span className="pd-member-copy"><b>{user.name}</b><small>{user.username}</small></span></button></td>
          <td><div className="pd-org-cell"><span>{user.dept}</span><small>{user.team === '-' ? '未归属团队' : user.team}</small></div></td><td><span className="pd-role-tag">{user.role}</span></td><td><span className={'pd-status ' + (user.status === '启用' ? 'enabled' : 'disabled')}><i aria-hidden="true" />{user.status}</span></td>
          <td><div className="pd-table-actions"><button className="pd-btn text" disabled={!orgReady} onClick={() => openUser(user)}>编辑</button><button className="pd-btn text subtle" onClick={() => setDetail(user)}>详情</button></div></td>
        </tr>)}</tbody></table></div>
        {total === 0 && <Empty title="没有匹配的用户" hint="请调整搜索条件或重置筛选" />}
        <div className="pd-pagination"><span>第 {page} / {pages} 页 · 共 {total} 人</span><div className="pd-actions"><button className="pd-btn" disabled={page <= 1} onClick={() => setPage(p => p - 1)}>上一页</button><button className="pd-btn" disabled={page >= pages} onClick={() => setPage(p => p + 1)}>下一页</button></div></div>
      </>}
    </div>
    {showAdd && <Modal title={editing ? '编辑用户' : '新增用户'} onClose={closeUser} footer={<><button className="pd-btn" disabled={saving} onClick={closeUser}>取消</button><button className="pd-btn primary" type="submit" form="user-form" disabled={saving}>{saving ? '保存中…' : '保存'}</button></>}>
      <form id="user-form" className="pd-form" noValidate onSubmit={e => { e.preventDefault(); saveUser(); }}>
        <p className="pd-field-hint">带 <span className="pd-required">*</span> 的信息为必填项，请核对员工资料后保存。</p>
        <fieldset className="pd-form-section" disabled={saving}><legend>账号与身份</legend>
          <div className="pd-form-grid">
            <label>电话号码{!editing && <span className="pd-required">*</span>}<input className="pd-input" {...validation.field('phone')} type="tel" aria-label="电话号码" required={!editing} inputMode="numeric" autoComplete="off" disabled={!!editing} value={form.phone} onChange={e => { const phone = e.target.value; changeUser(usernameEdited ? { phone } : { phone, username: phone.trim() }); }} placeholder="请输入 11 位手机号" />{feedback('phone')}</label>
            <label>账户名{!editing && <span className="pd-required">*</span>}<input className="pd-input" {...validation.field('username')} aria-label="账户名" required={!editing} autoComplete="off" spellCheck={false} disabled={!!editing} value={form.username} onChange={e => { setUsernameEdited(true); changeUser({ username: e.target.value }); }} placeholder="根据手机号自动填入，可修改" />{feedback('username')}</label>
          </div>
          {!editing && <div className="pd-field-hint">{usernameEdited ? '账户名已手动修改。' : '输入手机号后自动填入账户名。'}{usernameEdited && <button className="pd-btn text" type="button" onClick={() => { setUsernameEdited(false); changeUser({ username: form.phone.trim() }); }}>恢复手机号</button>}</div>}
          <div className="pd-form-grid">
            <label>姓名<span className="pd-required">*</span><input className="pd-input" {...validation.field('name')} aria-label="姓名" required value={form.name} onChange={e => changeUser({ name: e.target.value })} placeholder="请输入员工真实姓名" />{feedback('name')}</label>
            <label>性别<select className="pd-select" {...validation.field('gender')} aria-label="性别" disabled={!!editing} value={form.gender} onChange={e => changeUser({ gender: e.target.value })}><option value="">未填写</option>{['男', '女'].map(value => <option key={value}>{value}</option>)}</select>{feedback('gender')}</label>
          </div>
          <label>身份证号{!editing && <span className="pd-required">*</span>}
            <input className="pd-input" {...validation.field('idNumber')} aria-label="身份证号" required={!editing} autoComplete="off" spellCheck={false}
              aria-describedby={[editing ? 'edit-identity-hint' : '', validation.field('idNumber')['aria-describedby']].filter(Boolean).join(' ') || undefined}
              value={form.idNumber} onChange={e => changeUser({ idNumber: e.target.value })} placeholder="请输入 18 位身份证号，末位可为 X" />
            {editing && <small id="edit-identity-hint" className="pd-field-hint">填写新号码，留空保留原号码。</small>}
            {feedback('idNumber')}
          </label>
          {!editing && <PasswordField id="initial-password" label="初始密码" value={form.password} onChange={password => changeUser({ password })} onBlur={validation.field('password').onBlur} error={validation.error('password')} />}
        </fieldset>
        <fieldset className="pd-form-section" disabled={saving}><legend>角色与组织归属</legend>
          <label>角色<span className="pd-required">*</span><select className="pd-select" {...validation.field('role')} aria-label="角色" required value={form.role} onChange={e => changeUser({ role: e.target.value, dept: '', team: '' })}>{ROLES.map(role => <option key={role}>{role}</option>)}</select>{feedback('role')}</label>
          <div className="pd-form-grid">
            <label>部门{!deptLocked && <span className="pd-required">*</span>}<select className="pd-select" {...validation.field('dept')} aria-label="部门" required={!deptLocked} value={deptLocked ? '' : form.dept} disabled={deptLocked} onChange={e => changeUser({ dept: e.target.value, team: '' })}><option value="">{deptLocked ? '无需归属部门' : '选择部门'}</option>{(departments.data ?? []).map(d => <option key={d.id} value={d.id}>{d.name}</option>)}</select>{feedback('dept')}</label>
            <label>团队{!teamLocked && <span className="pd-required">*</span>}<select className="pd-select" {...validation.field('team')} aria-label="团队" required={!teamLocked} value={teamLocked ? '' : form.team} disabled={teamLocked || !selectedDepartment} onChange={e => changeUser({ team: e.target.value })}><option value="">{teamLocked ? '无需归属团队' : '选择团队'}</option>{teamOptions.map(team => <option key={team.id} value={team.id}>{team.name}</option>)}</select>{feedback('team')}</label>
          </div><p className="pd-field-hint">{roleMeta?.note}</p>
        </fieldset>
        {formErr && <p className="pd-inline-error" role="alert">{formErr}</p>}
      </form>
    </Modal>}
    {pwTarget && <Modal title={'重置密码 · ' + pwTarget.name} onClose={closePassword} footer={<><button className="pd-btn" disabled={!!actionBusy} onClick={closePassword}>取消</button><button className="pd-btn primary" disabled={!!actionBusy} type="submit" form="user-reset-form">{actionBusy ? '重置中…' : '确认重置'}</button></>}>
      <form id="user-reset-form" className="pd-form" noValidate onSubmit={e => { e.preventDefault(); resetPassword(); }}>
        <fieldset className="pd-form-section" disabled={!!actionBusy} aria-label="密码设置">
          <PasswordField id="reset-password" label="新密码" value={pwValue} onChange={value => { setPwValue(value); setPwError(''); }} onBlur={pwValidation.field('password').onBlur} error={pwValidation.error('password')} />
        </fieldset>
        {pwError && <p className="pd-inline-error" role="alert">{pwError}</p>}
      </form>
    </Modal>}
    {detail && <Modal title="用户详情" onClose={() => setDetail(null)} footer={<div className="pd-detail-actions"><button className="pd-btn" disabled={!!actionBusy} onClick={() => toggleStatus(detail)}>{detail.status === '启用' ? '停用' : '启用'}</button><button className="pd-btn" disabled={!!actionBusy} onClick={() => { setPwTarget(detail); setPwValue(generateStrongPassword()); setPwError(''); pwValidation.reset(); setDetail(null); }}>重置密码</button>{demo && <button className="pd-btn text danger" onClick={() => remove(detail)}>移除</button>}</div>}><UserProfile key={detail.id} user={detail} /></Modal>}
  </div>;
}

function UserProfile({ user }: { user: UserRow }) {
  const [visible, setVisible] = useState(false);
  const identity = user.idNumber ?? '';
  return <><div className="pd-profile-head"><span className="pd-member-avatar">{user.name.slice(0, 1)}</span><div><h3>{user.name}</h3><p>{user.username}</p></div><span className="pd-role-tag">{user.role}</span></div>
    <dl className="pd-record-details">{[['账户名', user.username], ['姓名', user.name], ['角色', user.role], ['部门', user.dept], ['团队', user.team], ['状态', user.status], ['电话号码', user.phone], ['性别', user.gender]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value || '未提供'}</dd></div>)}
      <div><dt>身份证号</dt><dd>{identity ? <span className="pd-identity-value"><span>{visible ? identity : identity.slice(0, 3) + '***********' + identity.slice(-4)}</span><button className="pd-btn text" aria-pressed={visible} onClick={() => setVisible(value => !value)}>{visible ? '隐藏号码' : '查看号码'}</button></span> : '未提供'}</dd></div>
    </dl></>;
}
