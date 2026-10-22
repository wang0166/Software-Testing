import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Login, Layout, NotFound } from './pages/Login';
import { Users } from './pages/Users';
import { Org, Logs, Stats } from './pages/Pages';
import { Debug } from './pages/Debug';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/users" element={<Layout><Users /></Layout>} />
        <Route path="/org" element={<Layout><Org /></Layout>} />
        <Route path="/logs" element={<Layout><Logs /></Layout>} />
        <Route path="/stats" element={<Layout><Stats /></Layout>} />
        <Route path="/debug" element={<Layout><Debug /></Layout>} />
        <Route path="/" element={<Navigate to="/login" />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  );
}