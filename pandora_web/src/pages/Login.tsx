import { useState } from 'react';
import { useNavigate, Link, useLocation } from 'react-router-dom';
import { api } from '../api/client';
import { useToast } from '../components/ui';

export function Login() {
  const [name, setName] = useState(localStorage.getItem('pandora-remember') ?? 'admin');
  const [password, setPassword] = useState('');
  const [remember, setRemember] = useState(() => localStorage.getItem('pandora-remember') != null);
  const [err, setErr] = useState('');
  const [busy, setBusy] = useState(false);
  const nav = useNavigate();
  const toast = useToast();
  const login = async () => {
    if (busy) return;
    try {
      setErr('');
      setBusy(true);
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
        <p className="pd-hint">管理员专用后台 · 账号用 username（英文）</p>
        <input className="pd-input" style={{ width: '100%', marginBottom: 10 }} value={name} onChange={(e) => setName(e.target.value)} placeholder="登录账号 username" onKeyDown={(e) => e.key === 'Enter' && login()} />
        <input className="pd-input" style={{ width: '100%' }} type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="密码（演示任意填）" onKeyDown={(e) => e.key === 'Enter' && login()} />
        <label style={{ display: 'flex', gap: 7, alignItems: 'center', marginTop: 10, fontSize: 13, color: '#5b5880', cursor: 'pointer' }}>
          <input type="checkbox" checked={remember} onChange={(e) => setRemember(e.target.checked)} /> 记住账号
        </label>
        <button className="pd-btn primary" style={{ width: '100%', marginTop: 14, justifyContent: 'center' }} disabled={busy} onClick={login}>
          {busy ? <><span className="pd-spinner" /> 登录中…</> : '登 录'}
        </button>
        {err && <p className="pd-err" style={{ marginBottom: 0 }}>⚠ {err}</p>}
        <p className="pd-hint" style={{ margin: '12px 0 0' }}>演示提示：输 <b>zuyuan_c</b>（停用）会被拦住。</p>
      </div>
    </div>
  );
}

export function Layout({ children }: { children: React.ReactNode }) {
  const nav = useNavigate();
  const loc = useLocation();
  const user = api.currentUser();
  const toast = useToast();
  if (!user) {
    return (
      <div className="pd-login">
        <div className="pd-login-card">
          <p>尚未登录，请先登录。</p>
          <button className="pd-btn primary" style={{ width: '100%', justifyContent: 'center' }} onClick={() => nav('/login')}>去登录</button>
        </div>
      </div>
    );
  }
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
        <p className="me">当前：{user} · 管理员 · 只读日志</p>
        <div className="pd-nav">
          {link('/users', '用户管理', '👥')}
          {link('/org', '组织 / 角色 / 配置', '🏢')}
          {link('/logs', '日志只读', '📝')}
          {link('/stats', '统计只读', '📊')}
          {link('/debug', '联调自检', '🔌')}
        </div>
        <div className="pd-side-foot">
          <button className="pd-btn" style={{ width: '100%', justifyContent: 'center', background: 'rgba(255,255,255,0.14)', border: 'none', color: '#fff' }} onClick={() => { api.logout(); toast.push('info', '已退出登录'); nav('/login'); }}>退出登录</button>
        </div>
      </nav>
      <main className="pd-main">
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
