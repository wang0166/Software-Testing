import { useEffect, useState } from 'react';
import { useNavigate, Link, useLocation, Navigate } from 'react-router-dom';
import { api } from '../api/client';
import { isMock, setMockMode } from '../api/http';
import { useToast } from '../components/ui';
import { useAsync } from '../hooks/hooks';

export function Login() {
  const [name, setName] = useState(localStorage.getItem('pandora-remember') ?? 'admin');
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(() => localStorage.getItem('pandora-remember') != null);
  const [demo, setDemo] = useState(isMock());
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const nav = useNavigate();
  const toast = useToast();
  const login = async () => {
    if (busy) return;
    try {
      setErr('');
      setBusy(true);
      // 演示模式 = 用本地假数据，不需要后端
      setMockMode(demo);
      await api.login(name, password);
      if (remember) localStorage.setItem('pandora-remember', name.trim());
      else localStorage.removeItem('pandora-remember');
      toast.push('ok', `欢迎回来，${name.trim()}`);
      nav('/users');
    } catch (e) {
      setErr(e instanceof Error ? e.message : '登录失败');
    } finally {
      setBusy(false);
    }
  };
  return (
    <div className="pd-login">
      <div className="pd-login-card">
        <div className="pd-login-mark">🟣</div>
        <h2 style={{ margin: '0 0 4px', fontSize: 24 }}>潘多拉 Web 管理端</h2>
        <p className="pd-hint">管理员专用后台 · 使用开户时确认的账户名，默认取手机号</p>
        <input className="pd-input" style={{ width: '100%', marginBottom: 10 }} value={name} onChange={(e) => setName(e.target.value)} placeholder="登录账户名（默认手机号，也支持已有账号）" onKeyDown={(e) => e.key === 'Enter' && login()} />
        <input className="pd-input" style={{ width: '100%' }} type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="密码" onKeyDown={(e) => e.key === 'Enter' && login()} />
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 10 }}>
          <label style={{ display: 'flex', gap: 7, alignItems: 'center', fontSize: 13, color: '#5b5880', cursor: 'pointer' }}>
            <input type="checkbox" checked={remember} onChange={(e) => setRemember(e.target.checked)} /> 记住账号
          </label>
          <label style={{ display: 'flex', gap: 7, alignItems: 'center', fontSize: 13, color: demo ? '#b3541e' : '#5b5880', cursor: 'pointer', fontWeight: demo ? 800 : 400 }}>
            <input type="checkbox" checked={demo} onChange={(e) => setDemo(e.target.checked)} /> 演示模式（不连后端）
          </label>
        </div>
        <button className="pd-btn primary" style={{ width: '100%', marginTop: 14, justifyContent: 'center' }} disabled={busy} onClick={login}>
          {busy ? <><span className="pd-spinner" /> 登录中…</> : '登 录'}
        </button>
        {err && <p className="pd-err" style={{ marginBottom: 0 }}>⚠ {err}</p>}
        <p className="pd-hint" style={{ margin: '12px 0 0' }}>
          {demo
            ? '演示模式仅用于界面预览：使用 admin 和任意非空密码，不验证真实密码，不保存到后端。'
            : '真实接口模式：仅管理员可登录，失败时不会切换为模拟成功。'}
        </p>
      </div>
    </div>
  );
}

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
  if (!user) {
    return <Navigate to="/login" replace />;
  }
  if (session.loading) return <div className="pd-card">正在核对登录状态…</div>;
  if (session.error) return <div className="pd-card" role="alert"><p>{session.error}</p><button className="pd-btn" onClick={session.reload}>重试</button><button className="pd-btn" onClick={() => nav('/login')}>重新登录</button></div>;
  if (session.data?.role !== 'ADMIN') return <Navigate to="/login" replace />;
  const link = (to: string, label: string, ico: string) => (
    <Link to={to} className={loc.pathname === to ? 'active' : ''}><span className="ico">{ico}</span>{label}</Link>
  );
  return (
    <div className="pd-layout">
      <nav className="pd-side">
        <div className="pd-brand">
          <div className="mark">🟣</div>
          <div><b>潘多拉</b><small>Web 管理端</small></div>
        </div>
        <p className="me">当前：{user} · 管理员</p>
        <div className="pd-nav">
          {link('/users', '用户管理', '👥')}
          {link('/org', '组织 / 角色 / 配置', '🏢')}
          {link('/debug', '联调自检', '🔌')}
        </div>
        <div className="pd-side-foot">
          <button className="pd-btn" style={{ width: '100%', justifyContent: 'center', background: 'rgba(255,255,255,0.14)', border: 'none', color: '#fff' }} onClick={async () => {
            try { await api.logout(); toast.push('info', '已退出登录'); }
            catch { toast.push('info', '本地登录已退出，服务端注销未确认'); }
            finally { nav('/login', { replace: true }); }
          }}>退出登录</button>
        </div>
      </nav>
      <main className="pd-main">
        {isMock() && <div className="pd-card" role="status">演示模式：本地模拟数据，不代表服务器已保存；组织、权限和事项演示改动刷新后重置。</div>}
        <div key={loc.pathname} className="pd-page">{children}</div>
      </main>
    </div>
  );
}

export function NotFound() {
  const nav = useNavigate();
  return (
    <div className="pd-login">
      <div className="pd-login-card" style={{ textAlign: 'center' }}>
        <div style={{ fontSize: 56 }}>🧭</div>
        <h2 style={{ margin: '8px 0 4px' }}>404 · 页面不存在</h2>
        <p className="pd-hint">地址输错了，回用户管理继续。</p>
        <button className="pd-btn primary" style={{ width: '100%', justifyContent: 'center' }} onClick={() => nav('/users')}>回用户管理</button>
      </div>
    </div>
  );
}
