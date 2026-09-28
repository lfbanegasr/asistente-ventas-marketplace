const form = document.getElementById('login-form');
const button = document.getElementById('login-button');
const message = document.getElementById('login-error');
function showError(text) { message.textContent = text; message.hidden = false; }

fetch('/api/session', { credentials: 'same-origin', cache: 'no-store' })
  .then(response => response.json())
  .then(session => {
    if (session.authenticated) location.replace('/');
    else if (!session.configured) { showError('El acceso aún no está configurado. Añade APP_PASSWORD como secreto del Worker en Cloudflare y guárdalo en tu gestor de contraseñas.'); button.disabled = true; }
  })
  .catch(() => showError('No se pudo comprobar el estado del sistema. Recarga la página.'));

form.addEventListener('submit', async event => {
  event.preventDefault();
  if (button.disabled) return;
  message.hidden = true;
  button.disabled = true;
  button.textContent = 'Entrando…';
  try {
    const response = await fetch('/api/login', {
      method: 'POST', credentials: 'same-origin', cache: 'no-store',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: form.elements.password.value })
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(result.error || `Error ${response.status}`);
    form.elements.password.value = '';
    location.replace('/');
  } catch (error) {
    showError(error.message);
    button.disabled = false;
    button.textContent = 'Entrar';
  }
});
