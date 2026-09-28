const $ = selector => document.querySelector(selector);
const state = { products: [], leads: [], aiReady: false, view: 'inicio', pendingLeadId: null };
const labels = { consulta: 'Consulta', interesado: 'Interesado', confirmado: 'Confirmado', comprado: 'Comprado', agendado: 'Agendado', entregado: 'Entregado', cancelado: 'Cancelado' };
const availability = { por_confirmar: 'Por confirmar', proveedor_confirmado: 'Proveedor confirmó', en_mano: 'En mano' };
const money = value => `Bs ${Number(value || 0).toLocaleString('es-BO')}`;
const localDate = value => value ? new Intl.DateTimeFormat('es-BO', { dateStyle: 'medium', timeStyle: value.length > 10 ? 'short' : undefined }).format(new Date(value.length > 10 ? value : `${value}T12:00:00`)) : 'Sin fecha';
function element(tag, text, className = '') { const node = document.createElement(tag); node.textContent = text; if (className) node.className = className; return node; }
function notice(message, success = false) { const box = $('#notice'); box.textContent = message; box.className = success ? 'notice success' : 'notice'; box.hidden = false; clearTimeout(notice.timer); notice.timer = setTimeout(() => box.hidden = true, 6500); }
async function api(path, method = 'GET', data) {
  const response = await fetch(path, { method, headers: data ? { 'Content-Type': 'application/json' } : undefined, body: data ? JSON.stringify(data) : undefined, credentials: 'same-origin' });
  const result = await response.json().catch(() => ({}));
  if (response.status === 401) { location.replace('/login'); throw new Error('La sesión terminó.'); }
  if (!response.ok) throw new Error(result.error || `Error ${response.status}`);
  return result;
}
async function refresh() {
  $('#loading').hidden = false;
  try { const data = await api('/api/state'); state.products = data.products; state.leads = data.leads; state.aiReady = data.ai_ready; render(); }
  catch (e) { notice(`No se pudo cargar: ${e.message}`); }
  finally { $('#loading').hidden = true; }
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
    info.append(element('h3', p.name), element('span', availability[p.availability], `badge ${p.availability === 'por_confirmar' ? 'warn' : ''}`)); head.append(info, element('div', money(p.price), 'price'));
    const facts = element('p', p.facts || 'Sin datos de producto');
    const meta = element('div', '', 'card-meta'); meta.append(element('span', `Costo ${money(p.cost)}`), element('span', `Mínimo interno ${money(p.min_price)}`), element('span', `En mano: ${p.available_units}`), element('span', `Entrega: ${localDate(p.ready_date)}`), element('span', p.availability_checked_at ? `Verificado: ${localDate(p.availability_checked_at.replace(' ', 'T'))}` : 'Disponibilidad sin verificar'));
    const button = element('button', 'Editar ficha', 'secondary'); button.addEventListener('click', () => openProduct(p)); card.append(head, facts, meta, button); list.append(card);
  });
}
function renderPickers() {
  const pickers = [$('#ai-product'), $('#lead-form [name="product_id"]')];
  pickers.forEach(picker => { const selected = picker.value; picker.replaceChildren(); state.products.forEach(p => { const option = element('option', p.name); option.value = p.id; picker.append(option); }); if (state.products.some(p => p.id === selected)) picker.value = selected; });
  $('#ai-draft').disabled = !state.aiReady;
  $('#ai-draft').title = state.aiReady ? '' : 'Configura la clave de Gemini para activar esta opción';
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
function baseDraft() {
  const product = state.products.find(p => p.id === $('#ai-product').value); if (!product) return;
  const goal = $('#ai-goal').value;
  const firstFact = product.facts.split(/\.\s/)[0].replace(/\.$/, '');
  let text = `¡Hola! ${product.name} está a ${money(product.price)}.${firstFact ? ` ${firstFact}.` : ''}`;
  text += ' Te confirmo disponibilidad y fecha de entrega antes de cerrar el pedido.';
  if (goal.includes('rebaja')) text += ` El precio publicado es ${money(product.price)}. Si me dices qué modalidad de entrega te conviene, reviso qué puedo ofrecerte.`;
  else if (goal.includes('Yango')) text += ' ¿En qué barrio o referencia estás? Te cotizo Yango sin compromiso. El producto se paga antes de despacharlo y el envío se cotiza aparte.';
  else if (goal.includes('entrega')) text += ' Podemos coordinar en la UAGRM (módulos), Cine Center u otro punto público. En persona pagas al recibir. ¿Qué día y punto te convienen?';
  else text += ' ¿Prefieres entrega en persona o envío por Yango?';
  setDraft(text);
}
function setDraft(text) { const box = $('#draft'); box.textContent = text; box.classList.add('ready'); $('#copy-draft').disabled = false; $('#draft-check').hidden = false; }
async function aiDraft() {
  const button = $('#ai-draft'); if (button.disabled) return;
  const message = $('#customer-message').value.trim(); if (!message) { notice('Pega primero el mensaje del cliente.'); return; }
  baseDraft();
  button.disabled = true; button.textContent = 'Preparando…';
  try { const result = await api('/api/ai', 'POST', { product_id: $('#ai-product').value, goal: $('#ai-goal').value, customer_message: message }); setDraft(result.draft); }
  catch (e) { notice(`${e.message} La respuesta base sigue disponible para revisar y copiar.`); }
  finally { button.disabled = !state.aiReady; button.textContent = 'Sugerir con Gemini'; }
}
function exportCsv() {
  const cols = ['alias','channel','product_name','status','amount','actual_cost','expenses','delivery_mode','delivery_place','delivery_at','paid','notes','created_at'];
  const quote = value => `"${String(value ?? '').replaceAll('"', '""')}"`;
  const csv = '\ufeff' + [cols.join(','), ...state.leads.map(l => cols.map(key => quote(l[key])).join(','))].join('\r\n');
  const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  const link = document.createElement('a'); link.href = url; link.download = `ventas-${new Date().toISOString().slice(0, 10)}.csv`; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
}

document.querySelectorAll('.tab').forEach(button => button.addEventListener('click', () => switchView(button.dataset.view)));
document.querySelectorAll('[data-action="new-lead"]').forEach(button => button.addEventListener('click', () => openLead()));
document.querySelector('[data-action="new-product"]').addEventListener('click', () => openProduct());
document.querySelectorAll('[data-close]').forEach(button => button.addEventListener('click', () => document.getElementById(button.dataset.close).close()));
$('#lead-form').addEventListener('submit', saveLead); $('#product-form').addEventListener('submit', saveProduct);
$('#lead-form [name="product_id"]').addEventListener('change', event => { const p = state.products.find(p => p.id === event.target.value); if (p) { const form = $('#lead-form'); form.elements.amount.value = p.price; form.elements.actual_cost.value = p.cost; } });
$('#search').addEventListener('input', renderLeads); $('#status-filter').addEventListener('change', renderLeads);
$('#refresh').addEventListener('click', refresh); $('#export').addEventListener('click', exportCsv);
$('#logout').addEventListener('click', async () => { try { await api('/api/logout', 'POST'); location.replace('/login'); } catch (e) { notice(e.message); } });
$('#base-draft').addEventListener('click', baseDraft); $('#ai-draft').addEventListener('click', aiDraft);
$('#copy-draft').addEventListener('click', async () => { try { await navigator.clipboard.writeText($('#draft').textContent); notice('Texto copiado. Revísalo antes de enviarlo.', true); } catch { notice('No se pudo copiar automáticamente. Selecciona el texto.'); } });
$('#today').textContent = new Intl.DateTimeFormat('es-BO', { dateStyle: 'full', timeZone: 'America/La_Paz' }).format(new Date());
refresh();
