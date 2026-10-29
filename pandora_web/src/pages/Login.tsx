import { useEffect, useState } from 'react';
import { useNavigate, NavLink, useLocation, Navigate } from 'react-router-dom';
import { api } from '../api/client';
import { isMock, setMockMode } from '../api/http';
import { useToast } from '../components/ui';
import { useAsync } from '../hooks/hooks';
import { Icon } from '../components/Icon';

export function Login() {
  const [name, setName] = useState(localStorage.getItem('pandora-remember') ?? 'admin');
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(() => localStorage.getItem('pandora-remember') != null);
  const [demo, setDemo] = useState(isMock());
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const nav = useNavigate();
  const login = async () => {
    if (busy) return;
    setErr(''); setBusy(true);
    try {
      setMockMode(demo);
      await api.login(name, password);
      if (remember) localStorage.setItem('pandora-remember', name.trim()); else localStorage.removeItem('pandora-remember');
      setPassword(''); nav('/users');
    } catch (error) { setErr(error instanceof Error ? error.message : '登录失败'); }
    finally { setBusy(false); }
  };
  return <div className="pd-login"><div className="pd-login-shell">
    <div className="pd-login-intro"><div className="pd-brand"><span className="mark">P</span><span><b>潘多拉</b><small>管理工作台</small></span></div><div className="pd-login-message"><h1>日常管理，<br />从这里开始。</h1><p>集中维护人员、组织与公司重要事项。</p><ul><li><Icon name="users" />成员与账号</li><li><Icon name="org" />部门与团队</li><li><Icon name="matters" />公司重要事项</li></ul></div><small>仅供系统管理员使用</small></div>
    <main className="pd-login-panel"><form className="pd-login-card pd-form" onSubmit={event => { event.preventDefault(); login(); }}><div><h2>管理员登录</h2><p className="pd-hint">输入你的账号，进入工作台</p></div>
      <label>账户名<input className="pd-input" autoComplete="username" value={name} onChange={event => setName(event.target.value)} placeholder="开户时确认的账户名" /></label>
      <label>密码<input className="pd-input" type="password" autoComplete="current-password" value={password} onChange={event => setPassword(event.target.value)} placeholder="请输入密码" /></label>
      <div className="pd-login-options"><label><input type="checkbox" checked={remember} onChange={event => setRemember(event.target.checked)} />记住账号</label><label><input type="checkbox" checked={demo} onChange={event => setDemo(event.target.checked)} />演示模式</label></div>
      {err && <p className="pd-inline-error" role="alert">{err}</p>}
      <button className="pd-btn primary pd-login-submit" disabled={busy}>{busy ? '登录中…' : '登录'}</button>
      <p className="pd-field-hint">{demo ? '演示模式仅供界面预览。账号 admin，密码任意非空；数据不会写入服务器。' : '管理员专用入口。账户名默认取开户手机号，也支持已有账号。'}</p>
    </form></main>
  </div></div>;
}

const navigation = [
  { to: '/users', label: '用户管理', icon: 'users' },
  { to: '/org', label: '组织管理', icon: 'org' },
  { to: '/matters', label: '公司十大事项', icon: 'matters' },
  { to: '/debug', label: '联调自检', icon: 'tools' },
] as const;

export function Layout({ children }: { children: React.ReactNode }) {
  const nav = useNavigate();
  const loc = useLocation();
  const user = api.currentUser();
  const toast = useToast();
  const session = useAsync(() => api.me());
  useEffect(() => {
    const expired = () => nav('/login', { replace: true });
    window.addEventListener('pandora-session-expired', expired);
    return () => window.removeEventListener('pandora-session-expired', expired);
  }, [nav]);
  useEffect(() => { window.scrollTo(0, 0); }, [loc.pathname]);
  if (!user) return <Navigate to="/login" replace />;
  if (session.loading) return <div className="pd-session-state">正在核对登录状态…</div>;
  if (session.error) return <div className="pd-session-state" role="alert"><p>{session.error}</p><button className="pd-btn" onClick={session.reload}>重试</button><button className="pd-btn" onClick={() => nav('/login')}>重新登录</button></div>;
  if (session.data?.role !== 'ADMIN') return <Navigate to="/login" replace />;
  return <div className="pd-layout">
    <aside className="pd-side"><div className="pd-brand"><span className="mark">P</span><span><b>潘多拉</b><small>管理工作台</small></span></div>
      <p className="pd-nav-label">工作空间</p><nav className="pd-nav" aria-label="主导航">{navigation.map(item => <NavLink end key={item.to} to={item.to} className={({ isActive }) => isActive ? 'active' : ''}><Icon name={item.icon} /><span>{item.label}</span></NavLink>)}</nav>
      <div className="pd-side-foot"><div className="pd-account"><span className="pd-avatar">管</span><span><b>{user}</b><small>系统管理员</small></span></div><button className="pd-btn pd-logout" onClick={async () => {
        try { await api.logout(); } catch { toast.push('info', '本地登录已退出，服务端注销未确认'); }
        finally { nav('/login', { replace: true }); }
      }}><Icon name="logout" />退出登录</button></div>
    </aside>
    <main className="pd-main"><div className="pd-workspace-header"><span>工作空间 <span className="pd-breadcrumb-divider">/</span> {navigation.find(item => item.to === loc.pathname)?.label}</span><span className={'pd-environment ' + (isMock() ? 'demo' : '')}>{isMock() ? '演示环境' : '标准模式'}</span></div>
      {isMock() && <div className="pd-mode-banner" role="status"><span className="pd-mode-dot" />当前为演示预览，所有操作不会写入服务器。</div>}
      <div className="pd-page">{children}</div>
    </main>
  </div>;
}

export function NotFound() {
  const nav = useNavigate();
  return <div className="pd-session-state"><span className="pd-eyebrow">404</span><h1>页面不存在</h1><p className="pd-hint">此页面可能已移除，请返回工作台。</p><button className="pd-btn primary" onClick={() => nav('/users')}>返回用户管理</button></div>;
}
