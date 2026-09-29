import { api, loginApi, checkSession, logout, isTokenValid } from './api.js';
import './style.css';

const $ = selector => document.querySelector(selector);
const state = { products: [], leads: [], aiReady: false, view: 'inicio', pendingLeadId: null, chats: [], chatId: null, chatBusy: false, pendingChatMessage: null };
const labels = { consulta: 'Consulta', interesado: 'Interesado', confirmado: 'Confirmado', comprado: 'Comprado', agendado: 'Agendado', entregado: 'Entregado', cancelado: 'Cancelado' };
const availabilityLabels = { por_confirmar: 'Por confirmar', proveedor_confirmado: 'Proveedor confirmó', en_mano: 'En mano' };
const money = value => `Bs ${Number(value || 0).toLocaleString('es-BO')}`;
const localDate = value => value ? new Intl.DateTimeFormat('es-BO', { dateStyle: 'medium', timeStyle: value.length > 10 ? 'short' : undefined }).format(new Date(value.length > 10 ? value : `${value}T12:00:00`)) : 'Sin fecha';
function element(tag, text, className = '') { const node = document.createElement(tag); node.textContent = text; if (className) node.className = className; return node; }
function notice(message, success = false) { const box = $('#notice'); box.textContent = message; box.className = success ? 'notice success' : 'notice'; box.hidden = false; clearTimeout(notice.timer); notice.timer = setTimeout(() => box.hidden = true, 6500); }

// ── Router ────────────────────────────────────────────────
function router() {
  const hash = window.location.hash;
  if (!isTokenValid() && hash !== '#/login') {
    window.location.hash = '#/login';
    return;
  }
  if (isTokenValid() && (hash === '#/login' || hash === '' || hash === '#' || hash === '#/')) {
    window.location.hash = '#/app';
    return;
  }

  const loginView = $('#login-view');
  const appView = $('#app-view');

  if (hash === '#/login') {
    loginView.hidden = false;
    appView.hidden = true;
    initLogin();
  } else {
    loginView.hidden = true;
    appView.hidden = false;
    initApp();
  }
}

// ── Login ─────────────────────────────────────────────────
function initLogin() {
  const form = $('#login-form');
  const button = $('#login-button');
  const message = $('#login-error');

  function showError(text) { message.textContent = text; message.hidden = false; }

  checkSession()
    .then(session => {
      if (session.authenticated) { window.location.hash = '#/app'; }
      else if (!session.configured) { showError('El acceso aún no está configurado. Añade APP_PASSWORD en el backend.'); button.disabled = true; }
    })
    .catch(() => showError('No se pudo comprobar el estado del sistema. Recarga la página.'));

  // Remove old listener and add fresh one
  const newForm = form.cloneNode(true);
  form.parentNode.replaceChild(newForm, form);

  newForm.addEventListener('submit', async event => {
    event.preventDefault();
    const btn = newForm.querySelector('#login-button');
    const msg = newForm.querySelector('#login-error');
    if (btn.disabled) return;
    msg.hidden = true;
    btn.disabled = true;
    btn.textContent = 'Entrando…';
    try {
      await loginApi(newForm.elements.password.value);
      newForm.elements.password.value = '';
      window.location.hash = '#/app';
    } catch (error) {
      msg.textContent = error.message;
      msg.hidden = false;
      btn.disabled = false;
      btn.textContent = 'Entrar';
    }
  });
}

// ── App ───────────────────────────────────────────────────
let appInitialized = false;

function initApp() {
  if (appInitialized) return;
  appInitialized = true;

  document.querySelectorAll('.tab').forEach(button => button.addEventListener('click', () => switchView(button.dataset.view)));
  document.querySelectorAll('[data-action="new-lead"]').forEach(button => button.addEventListener('click', () => openLead()));
  document.querySelector('[data-action="new-product"]').addEventListener('click', () => openProduct());
  document.querySelectorAll('[data-close]').forEach(button => button.addEventListener('click', () => document.getElementById(button.dataset.close).close()));
  $('#lead-form').addEventListener('submit', saveLead);
  $('#product-form').addEventListener('submit', saveProduct);
  $('#lead-form [name="product_id"]').addEventListener('change', event => { const p = state.products.find(p => p.id === event.target.value); if (p) { const form = $('#lead-form'); form.elements.amount.value = p.price; form.elements.actual_cost.value = p.cost; } });
  $('#search').addEventListener('input', renderLeads);
  $('#status-filter').addEventListener('change', renderLeads);
  $('#refresh').addEventListener('click', refresh);
  $('#export').addEventListener('click', exportCsv);
  $('#logout').addEventListener('click', () => { logout(); appInitialized = false; });
  $('#new-chat').addEventListener('click', newChat);
  $('#chat-form').addEventListener('submit', sendChat);
  $('#delete-chat').addEventListener('click', deleteChatHandler);
  $('#chat-input').addEventListener('keydown', event => { if (event.key === 'Enter' && !event.shiftKey) { event.preventDefault(); $('#chat-form').requestSubmit(); } });
  $('#today').textContent = new Intl.DateTimeFormat('es-BO', { dateStyle: 'full', timeZone: 'America/La_Paz' }).format(new Date());

  refresh();
}

async function refresh() {
  $('#loading').hidden = false;
  try {
    const data = await api('/api/state');
    state.products = data.products;
    state.leads = data.leads;
    state.aiReady = data.ai_ready;
    render();
    await loadChats();
    if (state.chatId) await openChat(state.chatId, true);
  } catch (e) {
    notice(`No se pudo cargar: ${e.message}`);
  } finally {
    $('#loading').hidden = true;
  }
}

function switchView(view) {
  state.view = view;
  document.querySelectorAll('.view').forEach(node => node.classList.toggle('active', node.id === view));
  document.querySelectorAll('.tab').forEach(node => node.classList.toggle('active', node.dataset.view === view));
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function render() { renderHome(); renderLeads(); renderProducts(); renderPickers(); }

function renderHome() {
  const metrics = $('#metrics'); metrics.replaceChildren();
  const open = state.leads.filter(l => !['entregado', 'cancelado'].includes(l.status));
  const confirmed = state.leads.filter(l => ['confirmado', 'comprado', 'agendado'].includes(l.status));
  const delivered = state.leads.filter(l => l.status === 'entregado');
  const margin = delivered.filter(l => l.paid).reduce((sum, l) => sum + l.amount - l.actual_cost - l.expenses, 0);
  [['Consultas activas', open.length], ['Pedidos confirmados', confirmed.length], ['Entregados', delivered.length], ['Margen cobrado¹', money(margin)]].forEach(([label, value]) => { const card = element('div', '', 'metric'); card.append(element('span', label), element('strong', String(value))); metrics.append(card); });
  const upcoming = $('#upcoming'); upcoming.replaceChildren();
  const scheduled = state.leads.filter(l => l.delivery_at && !['entregado', 'cancelado'].includes(l.status)).sort((a, b) => a.delivery_at.localeCompare(b.delivery_at)).slice(0, 5);
  if (!scheduled.length) upcoming.append(element('div', 'Aún no hay entregas agendadas.', 'empty'));
  scheduled.forEach(l => upcoming.append(row(l.alias, `${l.product_name} · ${localDate(l.delivery_at)} · ${l.delivery_place || 'lugar pendiente'}`)));
  const todo = $('#todo'); todo.replaceChildren();
  const unconfirmed = state.leads.filter(l => ['consulta', 'interesado'].includes(l.status)).slice(0, 4);
  const missingDate = state.leads.filter(l => ['confirmado', 'comprado'].includes(l.status) && !l.delivery_at).slice(0, 3);
  if (!unconfirmed.length && !missingDate.length) todo.append(element('div', 'Todo al día. Revisa la disponibilidad antes de cerrar un pedido.', 'empty'));
  unconfirmed.forEach(l => todo.append(row(l.alias, `${l.product_name} · responder o confirmar`)));
  missingDate.forEach(l => todo.append(row(l.alias, `${l.product_name} · falta fecha de entrega`)));
  const foot = element('small', '¹ Precio cobrado menos costo y gastos anotados; no incluye gastos que aún no registres.', 'muted'); todo.append(foot);
}

function row(title, subtitle) { const div = element('div', '', 'row'); const inner = element('div', ''); inner.append(element('strong', title), element('small', subtitle)); div.append(inner); return div; }

function renderLeads() {
  const list = $('#lead-list'); list.replaceChildren();
  const query = $('#search').value.trim().toLowerCase(), filter = $('#status-filter').value;
  const leads = state.leads.filter(l => (!filter || l.status === filter) && (!query || `${l.alias} ${l.product_name}`.toLowerCase().includes(query)));
  if (!leads.length) { list.append(element('div', 'No hay consultas con ese filtro.', 'empty')); return; }
  leads.forEach(l => {
    const card = element('article', '', 'card'); const head = element('div', '', 'card-head'); const info = element('div', '');
    info.append(element('h3', l.alias), element('span', `${l.product_name} · ${l.channel}`, 'muted'));
    head.append(info, element('span', labels[l.status], `badge ${l.status === 'entregado' ? 'done' : ['consulta', 'interesado'].includes(l.status) ? 'warn' : ''}`));
    const meta = element('div', '', 'card-meta');
    meta.append(element('span', `Venta ${money(l.amount)}`), element('span', `Margen estimado ${money(l.amount - l.actual_cost - l.expenses)}`), element('span', l.delivery_at ? `Entrega ${localDate(l.delivery_at)}` : 'Entrega sin agendar'), element('span', l.paid ? 'Pago verificado' : 'Pago pendiente'));
    const button = element('button', 'Abrir / actualizar', 'secondary'); button.addEventListener('click', () => openLead(l));
    card.append(head, meta, button); list.append(card);
  });
}

function renderProducts() {
  const list = $('#product-list'); list.replaceChildren();
  state.products.forEach(p => {
    const card = element('article', '', 'card'); const head = element('div', '', 'card-head'); const info = element('div', '');
    info.append(element('h3', p.name), element('span', availabilityLabels[p.availability], `badge ${p.availability === 'por_confirmar' ? 'warn' : ''}`)); head.append(info, element('div', money(p.price), 'price'));
    const facts = element('p', p.facts || 'Sin datos de producto');
    const meta = element('div', '', 'card-meta'); meta.append(element('span', `Costo ${money(p.cost)}`), element('span', `Mínimo interno ${money(p.min_price)}`), element('span', `En mano: ${p.available_units}`), element('span', `Entrega: ${localDate(p.ready_date)}`), element('span', p.availability_checked_at ? `Verificado: ${localDate(p.availability_checked_at.replace(' ', 'T'))}` : 'Disponibilidad sin verificar'));
    const button = element('button', 'Editar ficha', 'secondary'); button.addEventListener('click', () => openProduct(p)); card.append(head, facts, meta, button); list.append(card);
  });
}

function renderPickers() {
  const pickers = [$('#chat-product'), $('#lead-form [name="product_id"]')];
  pickers.forEach(picker => { const selected = picker.value; picker.replaceChildren(); state.products.forEach(p => { const option = element('option', p.name); option.value = p.id; picker.append(option); }); if (state.products.some(p => p.id === selected)) picker.value = selected; });
}

function openLead(lead) {
  const form = $('#lead-form'); form.reset(); state.pendingLeadId = lead ? null : crypto.randomUUID();
  $('#lead-form-error').hidden = true;
  $('#lead-dialog-title').textContent = lead ? 'Actualizar consulta' : 'Nueva consulta';
  form.elements.id.value = lead?.id || '';
  if (lead) {
    for (const key of ['alias','channel','product_id','status','amount','actual_cost','expenses','delivery_mode','delivery_place','delivery_at','notes']) form.elements[key].value = lead[key] ?? '';
    form.elements.paid.checked = !!lead.paid;
    form.elements.channel.disabled = true; form.elements.product_id.disabled = true;
  } else {
    form.elements.channel.disabled = false; form.elements.product_id.disabled = false;
    form.elements.status.value = 'consulta'; form.elements.delivery_mode.value = 'por_definir'; form.elements.expenses.value = '0';
    const product = state.products.find(p => p.id === form.elements.product_id.value);
    form.elements.amount.value = product?.price || 0; form.elements.actual_cost.value = product?.cost || 0;
  }
  $('#lead-dialog').showModal();
}

function openProduct(product) {
  const form = $('#product-form'); form.reset(); $('#product-dialog-title').textContent = product ? 'Editar producto' : 'Nuevo producto';
  $('#product-form-error').hidden = true;
  form.elements.id.value = product?.id || '';
  if (product) for (const key of ['name','facts','cost','price','min_price','availability','available_units','ready_date']) form.elements[key].value = product[key] ?? '';
  else { form.elements.availability.value = 'por_confirmar'; form.elements.available_units.value = 0; }
  $('#product-dialog').showModal();
}

async function saveLead(event) {
  event.preventDefault(); const form = event.currentTarget, button = $('#save-lead'); if (button.disabled) return;
  const data = Object.fromEntries(new FormData(form)); data.paid = form.elements.paid.checked;
  $('#lead-form-error').hidden = true;
  button.disabled = true; button.textContent = 'Guardando…';
  try {
    if (data.id) await api(`/api/leads/${encodeURIComponent(data.id)}`, 'PATCH', data);
    else await api('/api/leads', 'POST', { ...data, request_id: state.pendingLeadId });
    state.pendingLeadId = null; $('#lead-dialog').close(); await refresh(); notice('Consulta guardada.', true);
  } catch (e) { const box = $('#lead-form-error'); box.textContent = `No se guardó: ${e.message}`; box.hidden = false; }
  finally { button.disabled = false; button.textContent = 'Guardar'; }
}

async function saveProduct(event) {
  event.preventDefault(); const form = event.currentTarget, button = $('#save-product'); if (button.disabled) return;
  const data = Object.fromEntries(new FormData(form)); data.availability_checked = form.elements.availability_checked.checked; $('#product-form-error').hidden = true; button.disabled = true; button.textContent = 'Guardando…';
  try { await api(data.id ? `/api/products/${encodeURIComponent(data.id)}` : '/api/products', data.id ? 'PATCH' : 'POST', data); $('#product-dialog').close(); await refresh(); notice('Producto guardado.', true); }
  catch (e) { const box = $('#product-form-error'); box.textContent = `No se guardó: ${e.message}`; box.hidden = false; }
  finally { button.disabled = false; button.textContent = 'Guardar'; }
}

function chatError(message = '') { const box = $('#chat-error'); box.textContent = message; box.hidden = !message; }

function renderChatList() {
  const list = $('#chat-list'); list.replaceChildren();
  if (!state.chats.length) { list.append(element('div', 'Aún no hay conversaciones.', 'chat-empty')); return; }
  state.chats.forEach(chat => {
    const button = element('button', '', `chat-list-item${chat.id === state.chatId ? ' active' : ''}`);
    button.type = 'button'; button.append(element('strong', chat.title), element('small', chat.product_name));
    button.addEventListener('click', () => openChat(chat.id)); list.append(button);
  });
}

async function loadChats() {
  try { state.chats = (await api('/api/chats')).threads; renderChatList(); }
  catch (e) { $('#chat-list').replaceChildren(element('div', `No se cargaron los chats: ${e.message}`, 'chat-empty')); }
}

function newChat() {
  if (state.chatBusy) return;
  state.chatId = null; state.pendingChatMessage = null; $('#chat-input').value = ''; chatError();
  $('#chat-title').textContent = 'Nueva conversación'; $('#chat-product-name').textContent = 'Elige un producto para empezar';
  $('#chat-product').disabled = false; $('#delete-chat').hidden = true;
  $('#chat-messages').replaceChildren();
  const welcome = element('div', '', 'chat-welcome');
  welcome.append(element('span', '✦', 'chat-spark'), element('h3', '¿Qué necesitas responder?'), element('p', 'Pega una consulta o pregúntame cómo negociar, comprobar disponibilidad o coordinar una entrega. Las respuestas son borradores para revisar y copiar.'));
  $('#chat-messages').append(welcome); renderChatList(); $('#chat-input').focus();
}

function chatBubble(text, role, source = '') {
  const wrap = element('div', '', `chat-row ${role}`); const bubble = element('div', text, 'chat-bubble'); wrap.append(bubble);
  if (role === 'assistant') {
    const tools = element('div', '', 'chat-bubble-tools');
    tools.append(element('small', source === 'base' ? 'Respuesta base' : 'Gemini'));
    const copy = element('button', 'Copiar', 'chat-copy'); copy.type = 'button';
    copy.addEventListener('click', async () => { try { await navigator.clipboard.writeText(text); notice('Texto copiado. Revísalo antes de enviarlo.', true); } catch { notice('No se pudo copiar automáticamente. Selecciona el texto.'); } });
    tools.append(copy); wrap.append(tools);
  }
  return wrap;
}

function renderChat(turns) {
  const messages = $('#chat-messages'); messages.replaceChildren();
  if (!turns.length) { messages.append(element('div', 'Escribe tu primera pregunta para este producto.', 'chat-empty')); return; }
  turns.forEach(turn => { messages.append(chatBubble(turn.user_text, 'user'), chatBubble(turn.assistant_text, 'assistant', turn.source)); });
  messages.scrollTop = messages.scrollHeight;
}

async function openChat(id, force = false) {
  if (state.chatBusy) return;
  if (id === state.chatId && !force) return;
  chatError(); $('#chat-messages').replaceChildren(element('div', 'Cargando conversación…', 'chat-empty'));
  try {
    const data = await api(`/api/chats/${id}`); state.chatId = id;
    if (!force) { state.pendingChatMessage = null; $('#chat-input').value = ''; }
    $('#chat-title').textContent = data.thread.title; $('#chat-product-name').textContent = data.thread.product_name;
    $('#chat-product').value = data.thread.product_id; $('#chat-product').disabled = true; $('#delete-chat').hidden = false;
    renderChat(data.turns); renderChatList();
  } catch (e) { chatError(`No se pudo abrir: ${e.message}`); }
}

async function sendChat(event) {
  event.preventDefault(); if (state.chatBusy) return;
  const input = $('#chat-input'), message = input.value.trim();
  if (!message) { chatError('Escribe una pregunta o pega un mensaje.'); return; }
  if (!$('#chat-product').value) { chatError('Elige un producto.'); return; }
  if (!state.pendingChatMessage || state.pendingChatMessage.text !== message) state.pendingChatMessage = { text: message, requestId: crypto.randomUUID() };
  const pending = state.pendingChatMessage;
  state.chatBusy = true; $('#chat-send').disabled = true; $('#chat-send').textContent = 'Pensando…'; chatError();
  try {
    if (!state.chatId) {
      const id = crypto.randomUUID(); await api('/api/chats', 'POST', { id, product_id: $('#chat-product').value }); state.chatId = id;
      $('#chat-product').disabled = true; $('#delete-chat').hidden = false;
    }
    const messages = $('#chat-messages');
    if (messages.querySelector('.chat-welcome,.chat-empty')) messages.replaceChildren();
    const preview = chatBubble(message, 'user'); const waiting = element('div', 'Preparando respuesta…', 'chat-waiting');
    messages.append(preview, waiting); messages.scrollTop = messages.scrollHeight;
    try {
      const result = await api(`/api/chats/${state.chatId}/turns`, 'POST', { request_id: pending.requestId, message });
      waiting.remove(); preview.replaceWith(chatBubble(result.turn.user_text, 'user'));
      messages.append(chatBubble(result.turn.assistant_text, 'assistant', result.turn.source)); messages.scrollTop = messages.scrollHeight;
      input.value = ''; state.pendingChatMessage = null;
      if (result.warning) chatError(result.warning);
      await loadChats(); const selected = state.chats.find(chat => chat.id === state.chatId);
      if (selected) { $('#chat-title').textContent = selected.title; $('#chat-product-name').textContent = selected.product_name; }
    } catch (e) { waiting.remove(); preview.remove(); throw e; }
  } catch (e) { chatError(`No se envió: ${e.message}. Tu texto sigue aquí; toca Enviar para reintentar.`); }
  finally { state.chatBusy = false; $('#chat-send').disabled = false; $('#chat-send').textContent = 'Enviar'; }
}

async function deleteChatHandler() {
  if (!state.chatId || state.chatBusy || !confirm('¿Eliminar esta conversación guardada?')) return;
  try { await api(`/api/chats/${state.chatId}`, 'DELETE'); await loadChats(); newChat(); notice('Conversación eliminada.', true); }
  catch (e) { chatError(`No se pudo eliminar: ${e.message}`); }
}

function exportCsv() {
  const cols = ['alias','channel','product_name','status','amount','actual_cost','expenses','delivery_mode','delivery_place','delivery_at','paid','notes','created_at'];
  const quote = value => `"${String(value ?? '').replaceAll('"', '""')}"`;
  const csv = '\ufeff' + [cols.join(','), ...state.leads.map(l => cols.map(key => quote(l[key])).join(','))].join('\r\n');
  const fileName = `ventas-${new Date().toISOString().slice(0, 10)}.csv`;
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a'); link.href = url; link.download = fileName; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
}

// ── Init ──────────────────────────────────────────────────
window.addEventListener('hashchange', router);
router();
