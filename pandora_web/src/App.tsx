import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Login, Layout, NotFound } from './pages/Login';
import { Users } from './pages/Users';
import { Org } from './pages/Pages';
import { Matters } from './pages/Matters';
import { Debug } from './pages/Debug';
import { Audits } from './pages/Audits';
import { DEVELOPMENT_TOOLS } from './api/http';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/users" element={<Layout><Users /></Layout>} />
        <Route path="/org" element={<Layout><Org /></Layout>} />
        <Route path="/matters" element={<Layout><Matters /></Layout>} />
        <Route path="/audits" element={<Layout><Audits /></Layout>} />
        {DEVELOPMENT_TOOLS && <Route path="/debug" element={<Layout><Debug /></Layout>} />}
        <Route path="/" element={<Navigate to="/login" />} />
        <Route path="*" element={<NotFound />} />
      </Routes>
    </BrowserRouter>
  );
}
