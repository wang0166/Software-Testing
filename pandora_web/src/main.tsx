import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { ConfirmProvider, ToastProvider } from './components/ui';
import './theme.css';

createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ToastProvider>
      <ConfirmProvider>
        <App />
      </ConfirmProvider>
    </ToastProvider>
  </React.StrictMode>,
);
