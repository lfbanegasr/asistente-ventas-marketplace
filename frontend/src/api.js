// API base URL — in development, Vite proxies /api to the backend.
// In production, this points to the Railway backend URL.
const API_BASE = import.meta.env.VITE_API_URL || '';

function getToken() {
  return localStorage.getItem('ventas_token');
}

function setToken(token, expiresAt) {
  localStorage.setItem('ventas_token', token);
  localStorage.setItem('ventas_token_expires', String(expiresAt));
}

function clearToken() {
  localStorage.removeItem('ventas_token');
  localStorage.removeItem('ventas_token_expires');
}

function isTokenValid() {
  const token = getToken();
  const expires = Number(localStorage.getItem('ventas_token_expires') || 0);
  return !!token && Date.now() < expires;
}

async function api(path, method = 'GET', data) {
  const token = getToken();
  const headers = {};
  if (token) headers['Authorization'] = `Bearer ${token}`;
  if (data) headers['Content-Type'] = 'application/json';

  const response = await fetch(`${API_BASE}${path}`, {
    method,
    headers,
    body: data ? JSON.stringify(data) : undefined
  });

  const result = await response.json().catch(() => ({}));

  if (response.status === 401) {
    clearToken();
    window.location.hash = '#/login';
    throw new Error('La sesión terminó.');
  }

  if (!response.ok) throw new Error(result.error || `Error ${response.status}`);
  return result;
}

async function loginApi(password) {
  const response = await fetch(`${API_BASE}/api/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password })
  });

  const result = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(result.error || `Error ${response.status}`);

  setToken(result.token, result.expiresAt);
  return result;
}

async function checkSession() {
  const response = await fetch(`${API_BASE}/api/session`, {
    headers: getToken() ? { 'Authorization': `Bearer ${getToken()}` } : {}
  });
  return response.json();
}

function logout() {
  clearToken();
  window.location.hash = '#/login';
}

export { api, loginApi, checkSession, logout, isTokenValid, getToken, clearToken };
