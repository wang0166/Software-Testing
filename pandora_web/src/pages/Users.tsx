import { useEffect, useState } from 'react';
import { api, type UserRow } from '../api/client';
import { ROLE_META, ROLES, USER_STATUS } from '../constants/roles';
import { useAsync, useDebounce } from '../hooks/hooks';
import { downloadCSV, writeOpLog } from '../utils/export';
import { Empty, Modal, Skeleton, useConfirm, useToast } from '../components/ui';
import { supports } from '../api/capabilities';
import { isMock } from '../api/http';
import { Unavailable } from '../components/Unavailable';
import { Icon } from '../components/Icon';

const PAGE_SIZE = 10;
const emptyForm = () => ({ username: '', name: '', password: '', dept: '', team: '', role: '组员', idNumber: '', gender: '男', phone: '' });

function generateStrongPassword(): string {
  const pools = ['abcdefghijkmnpqrstuvwxyz', 'ABCDEFGHJKLMNPQRSTUVWXYZ', '23456789', '!@#$%^&*'];
  const pick = (pool: string) => pool[crypto.getRandomValues(new Uint32Array(1))[0] % pool.length];
  const chars = pools.map(pick);
  while (chars.length < 16) chars.push(pick(pools.join('')));
  for (let i = chars.length - 1; i > 0; i--) {
    const j = crypto.getRandomValues(new Uint32Array(1))[0] % (i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}

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
  const [usernameEdited, setUsernameEdited] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [formErr, setFormErr] = useState('');
  const [detail, setDetail] = useState<UserRow | null>(null);
  const [pwTarget, setPwTarget] = useState<UserRow | null>(null);
  const [pwValue, setPwValue] = useState('');
  const [pwError, setPwError] = useState('');
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

  const openUser = (user: UserRow | null) => {
    setEditing(user); setFormErr(''); setUsernameEdited(false); setShowPassword(false);
    setForm(user ? { username: user.username, name: user.name, password: '', dept: user.departmentId ?? '', team: user.teamId ?? '',
      role: user.role, idNumber: user.idNumber ?? '', gender: user.gender ?? '男', phone: user.phone ?? '' } : emptyForm());
    setShowAdd(true);
  };
  const closeUser = () => {
    if (saving) return;
    setShowAdd(false); setEditing(null); setFormErr(''); setForm(emptyForm()); setShowPassword(false); setUsernameEdited(false);
  };
  const changePhone = (phone: string) => setForm(current => ({ ...current, phone, username: !editing && !usernameEdited ? phone.trim() : current.username }));
  const copyPassword = async () => {
    try { await navigator.clipboard.writeText(form.password); toast.push('ok', '初始密码已复制，请通过安全渠道交付'); }
    catch { toast.push('err', '无法复制，可点击显示后手动复制'); }
  };
  const saveUser = async () => {
    if (saving) return;
    const username = form.username.trim().toLowerCase(), name = form.name.trim();
    if (!/^[a-z0-9_]{3,20}$/.test(username)) return setFormErr('账户名需为 3～20 位小写字母、数字或下划线');
    if (!name || name.length > 20) return setFormErr('请填写 1～20 字的姓名');
    if (!editing && (form.password.length < 6 || !form.password.trim())) return setFormErr('初始密码至少 6 位且不能全为空格');
    if (form.idNumber && !/^\d{17}[\dXx]$/.test(form.idNumber.trim())) return setFormErr('身份证号应为 18 位，末位可为 X');
    if ((!editing || form.phone) && !/^1\d{10}$/.test(form.phone.trim())) return setFormErr('请输入有效的 11 位手机号');
    const department = departments.data?.find(d => d.id === form.dept);
    const team = teams.data?.find(t => t.id === form.team && t.parentId === form.dept);
    if (!deptLocked && !department) return setFormErr('请选择有效部门');
    if (!teamLocked && !team) return setFormErr('请选择该部门下的团队');
    setSaving(true); setFormErr('');
    try {
      const assignment = { realName: name, role: form.role, departmentId: deptLocked ? null : Number(department!.id), teamId: teamLocked ? null : Number(team!.id) };
      if (editing) await api.updateUser(editing.id, assignment);
      else {
        const created = await api.createUser({ ...assignment, username, password: form.password, phone: form.phone.trim(), idNumber: form.idNumber.trim(), gender: form.gender });
        if (created?.id == null) throw new Error('创建响应缺少用户编号，请刷新核对结果后再操作');
      }
      if (demo) writeOpLog(editing ? '编辑用户' : '创建用户', '本地演示操作');
      toast.push('ok', demo ? '演示账号已保存' : '账号已保存');
      setShowAdd(false); setEditing(null); setForm(emptyForm()); setShowPassword(false); setUsernameEdited(false); setDetail(null); list.reload();
    } catch (error) { setFormErr(error instanceof Error ? error.message : '保存失败'); }
    finally { setSaving(false); }
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
  const closePassword = () => { if (!actionBusy) { setPwTarget(null); setPwValue(''); setPwError(''); } };
  const resetPassword = async () => {
    if (!pwTarget || actionBusy) return;
    if (pwValue.length < 6 || !pwValue.trim()) return setPwError('密码至少 6 位且不能全为空格');
    setActionBusy(pwTarget.id);
    try {
      await api.resetPassword(pwTarget.id, pwValue);
      if (demo) writeOpLog('重置密码', '本地演示操作');
      setPwTarget(null); setPwValue(''); setPwError(''); toast.push('ok', demo ? '演示重置操作已完成，不保存密码' : '密码已重置');
    } catch (error) { setPwError(error instanceof Error ? error.message : '重置失败'); }
    finally { setActionBusy(''); }
  };

  return <div>
    <div className="pd-hero"><div><h2>用户管理 <span className="pd-heading-count">{list.loading ? '…' : total}</span></h2><p>维护成员账号和组织归属</p></div><button className="pd-btn primary" disabled={!orgReady} onClick={() => openUser(null)}><Icon name="plus" />新增用户</button></div>
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
      <form id="user-form" className="pd-form" onSubmit={e => { e.preventDefault(); saveUser(); }}>
        <div className="pd-form-grid"><label>电话号码{!editing && ' *'}<input className="pd-input" type="tel" aria-label="电话号码" inputMode="numeric" autoComplete="off" disabled={!!editing} value={form.phone} onChange={e => changePhone(e.target.value)} placeholder="11 位手机号" maxLength={11} /></label>
          <label>账户名 *<input className="pd-input" aria-label="账户名" autoComplete="off" disabled={!!editing} value={form.username} onChange={e => { setUsernameEdited(true); setForm({ ...form, username: e.target.value }); }} placeholder="手机号自动填入，可修改" /></label></div>
        {!editing && <div className="pd-field-hint">{usernameEdited ? '账户名已手动修改，手机号变化不会覆盖它。' : '输入手机号后自动填入账户名。'}{usernameEdited && <button className="pd-btn text" type="button" onClick={() => { setUsernameEdited(false); setForm({ ...form, username: form.phone.trim() }); }}>恢复手机号</button>}</div>}
        <label>姓名 *<input className="pd-input" aria-label="姓名" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="请输入姓名" maxLength={20} /></label>
        {!editing && <div><label>初始密码 *<div className="pd-password-field"><input className="pd-input" type={showPassword ? 'text' : 'password'} autoComplete="new-password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} placeholder="填写或生成初始密码" /><button className="pd-btn" type="button" aria-pressed={showPassword} onClick={() => setShowPassword(value => !value)}>{showPassword ? '隐藏密码' : '显示密码'}</button></div></label>
          <div className="pd-actions"><button className="pd-btn" type="button" onClick={() => setForm({ ...form, password: generateStrongPassword() })}>生成强密码</button><button className="pd-btn" type="button" disabled={!form.password} onClick={copyPassword}>复制密码</button></div><p className="pd-field-hint">初始密码请通过安全渠道交付。{demo && '演示模式不保存或验证密码。'}</p></div>}
        <div className="pd-form-grid"><label>角色 *<select className="pd-select" aria-label="角色" value={form.role} onChange={e => setForm({ ...form, role: e.target.value })}>{ROLES.map(role => <option key={role}>{role}</option>)}</select></label>
          <label>性别<select className="pd-select" aria-label="性别" disabled={!!editing} value={form.gender} onChange={e => setForm({ ...form, gender: e.target.value })}>{['男', '女'].map(value => <option key={value}>{value}</option>)}</select></label>
          <label>部门{!deptLocked && ' *'}<select className="pd-select" aria-label="部门" value={deptLocked ? '' : form.dept} disabled={deptLocked} onChange={e => setForm({ ...form, dept: e.target.value, team: '' })}><option value="">{deptLocked ? '无需归属部门' : '选择部门'}</option>{(departments.data ?? []).map(d => <option key={d.id} value={d.id}>{d.name}</option>)}</select></label>
          <label>团队{!teamLocked && ' *'}<select className="pd-select" aria-label="团队" value={teamLocked ? '' : form.team} disabled={teamLocked || !selectedDepartment} onChange={e => setForm({ ...form, team: e.target.value })}><option value="">{teamLocked ? '无需归属团队' : '选择团队'}</option>{teamOptions.map(team => <option key={team.id} value={team.id}>{team.name}</option>)}</select></label></div>
        <p className="pd-field-hint">{roleMeta?.note}</p>
        <label>身份证号<input className="pd-input" disabled={!!editing} value={form.idNumber} onChange={e => setForm({ ...form, idNumber: e.target.value })} placeholder="选填" maxLength={18} /></label>
        {formErr && <p className="pd-inline-error" role="alert">{formErr}</p>}
      </form>
    </Modal>}
    {pwTarget && <Modal title={'重置密码 · ' + pwTarget.name} onClose={closePassword} footer={<><button className="pd-btn" disabled={!!actionBusy} onClick={closePassword}>取消</button><button className="pd-btn primary" disabled={!!actionBusy} onClick={resetPassword}>{actionBusy ? '重置中…' : '确认重置'}</button></>}><div className="pd-form"><p className="pd-hint">重置后请通过安全渠道告知账号使用者。</p><label>新密码<input className="pd-input" type="password" autoComplete="new-password" value={pwValue} onChange={e => setPwValue(e.target.value)} /></label>{pwError && <p className="pd-inline-error" role="alert">{pwError}</p>}</div></Modal>}
    {detail && <Modal title="用户详情" onClose={() => setDetail(null)} footer={<div className="pd-detail-actions"><button className="pd-btn" disabled={!!actionBusy} onClick={() => toggleStatus(detail)}>{detail.status === '启用' ? '停用' : '启用'}</button><button className="pd-btn" onClick={() => { setPwTarget(detail); setPwValue(''); setPwError(''); setDetail(null); }}>重置密码</button>{demo && <button className="pd-btn text danger" onClick={() => remove(detail)}>移除</button>}</div>}><div className="pd-profile-head"><span className="pd-member-avatar">{detail.name.slice(0, 1)}</span><div><h3>{detail.name}</h3><p>{detail.username}</p></div><span className="pd-role-tag">{detail.role}</span></div><dl className="pd-record-details">{[['账户名', detail.username], ['姓名', detail.name], ['角色', detail.role], ['部门', detail.dept], ['团队', detail.team], ['状态', detail.status], ['电话号码', detail.phone], ['性别', detail.gender], ['身份证号', detail.idNumber]].map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value || '未提供'}</dd></div>)}</dl></Modal>}
  </div>;
}
