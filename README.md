# Mi mesa de ventas

Aplicación privada y ligera para gestionar consultas de Marketplace y WhatsApp Business desde el celular. Contiene fichas de producto, costos y precios, estado de cada consulta, entregas pendientes, ventas cobradas, exportación CSV y un asistente que propone respuestas con Gemini. El vendedor revisa y copia el texto; la aplicación no lee ni envía mensajes de Facebook o WhatsApp.

## Flujo diario

1. **Productos:** revisa precio y disponibilidad antes de responder. Los tres productos iniciales son PB6010, PB225 y KNUP KP-5501TM. Todos empiezan en **Por confirmar**. Marca **Verifiqué esta disponibilidad ahora** solo después de comprobarla; las fichas antiguas empiezan sin marca de verificación.
2. **Asistente:** pega el mensaje del cliente, elige el producto y el objetivo. Puedes usar una respuesta base sin Gemini o pedir un borrador a Gemini. Revisa el resultado, cópialo y envíalo tú por el chat donde te escribió el cliente.
3. **Consultas:** registra a la persona si eligió producto o requiere seguimiento. Si confirmó precio y modalidad, marca **Confirmado**. Al comprar la unidad, marca **Comprado**. Al fijar hora y lugar, marca **Agendado**.
4. **Entrega:** anota modalidad, lugar y fecha al agendar. Para Yango, cobra el producto antes de despacharlo. Confirma el pago cuando realmente se haya recibido y recién entonces marca **Entregado**. El margen se calcula con precio menos costo y otros gastos registrados.
5. **Copia de datos:** usa **Exportar CSV** con frecuencia; guárdalo en un lugar privado.

En persona: UAGRM (módulos), Cine Center u otro punto público acordado, con pago al recibir. Para Yango: cotizar según barrio, cobrar el producto antes de despacharlo y cotizar el envío aparte. Prefiere martes, jueves y fines de semana al proponer opciones, pero confirma el día concreto antes de prometerlo. Ningún mensaje debe garantizar stock o fecha sin una verificación previa.

## Estructura y prioridades

Un Worker sirve la interfaz y la API privada; D1 guarda productos, consultas, entregas, pagos y el contador de uso de Gemini. Los secretos `APP_PASSWORD` y `GEMINI_API_KEY` quedan solo en el Worker. Messenger y WhatsApp quedan fuera: el vendedor revisa y copia cada borrador.

Esta primera etapa conserva las cuatro secciones actuales. Los datos mínimos de una consulta son alias, canal, producto, estado, precio y costo; entrega, pago, gastos y notas se completan cuando correspondan. La creación de una consulta se hace en una sola operación con identificador de petición para que un reintento no la duplique. En las próximas etapas conviene priorizar seguimiento más visible, control de entrega y margen; no se requieren tienda pública ni variantes.

Aceptación de esta etapa: sin `APP_PASSWORD` no hay acceso a datos; una petición repetida crea una sola consulta completa; las fichas antiguas no se consideran verificadas; una entrega no se marca completada sin pago comprobado; y la respuesta base permanece disponible cuando Gemini falla. Antes de considerar producción lista, comprobar el despliegue real, el secreto, D1 y el acceso desde celular y PC.

## Para ponerla en Internet

Necesitas tu cuenta de Cloudflare y una contraseña única y aleatoria de al menos 16 caracteres guardada en el gestor de contraseñas del celular y la PC. El login propio permite autocompletado y mantiene una sesión durante siete días; normalmente basta desbloquear el gestor con huella, rostro o PIN del dispositivo. Un PIN corto escrito directamente en la web no protege suficientemente esta URL pública. La opción de passkeys requiere alta y recuperación adicionales, por lo que no forma parte de esta primera etapa. **Nunca pegues contraseñas ni claves API en chats o archivos públicos.**

### Despliegue con GitHub y Cloudflare

El repositorio privado contiene solo este proyecto. Cloudflare puede conectarlo desde **Workers & Pages → Create application → Import a repository**. Selecciona el repositorio y configura:

- **Worker name:** `asistente-ventas-marketplace` (igual que en `wrangler.jsonc`).
- **Production branch:** `main`.
- **Root directory:** `/`.
- **Build command:** `npm run build`.
- **Deploy command:** `npx wrangler deploy`.

Cloudflare puede crear la base D1 automáticamente a partir de `wrangler.jsonc`. El esquema inicial y las tres fichas se crean la primera vez que entras. La segunda migración añade la marca de disponibilidad verificada de forma compatible con datos anteriores. En **Workers & Pages → tu Worker → Settings → Variables and Secrets**, comprueba si existe `APP_PASSWORD`; si falta, créalo como **Secret** y guarda el mismo valor directamente en tu gestor. `GEMINI_API_KEY` también debe ser un secreto del Worker. No hace falta revelar ninguno de los valores para comprobar si están configurados.

**Mantén Cloudflare Access activo.** La regla **Cloudflare account** solo admite miembros de la cuenta, por eso puede bloquear tu correo aunque seas propietario de la app. En **Zero Trust → Access → Applications → aplicación de este Worker**, usa una política **Allow** restringida a tu dirección exacta y el método **One-time PIN** para poder entrar y probar el login propio; no uses **Everyone**, dominio de correo completo ni **Bypass**. Activa One-time PIN como método de inicio de sesión si todavía no aparece. Verifica en celular y PC que Access deje pasar, que `/login` muestre el login propio y que los datos no se vean sin sesión. Solo después de confirmar el nuevo despliegue, `APP_PASSWORD`, D1 y el cierre de sesión se puede evaluar quitar Access. `OWNER_EMAIL` ya no se usa.

Si pierdes la contraseña guardada, entra a tu cuenta de Cloudflare por sus propios métodos de recuperación y cambia el secreto `APP_PASSWORD` por uno nuevo; eso invalida las sesiones anteriores. Guarda el nuevo valor en el gestor de ambos dispositivos. Si tampoco tienes acceso a Cloudflare, primero debes recuperar esa cuenta; la app no tiene una vía pública de recuperación que eluda el login.

Después de cada cambio en `main`, GitHub activará un nuevo despliegue. No subas `.dev.vars`, `.config`, `.npm-cache`, `.wrangler` ni `node_modules`: están excluidos por `.gitignore`.

### Alternativa desde la terminal

1. Abre una terminal en esta carpeta e instala las dependencias con `npm install`.
2. Entra a Cloudflare con `npx wrangler login`.
3. Ejecuta `npm run deploy`. Cloudflare creará el Worker y la base D1 definida en `wrangler.jsonc`. El Worker bloqueará los datos hasta que configures la contraseña.
4. La base se inicializa al primer acceso autorizado. `npm run db:remote` también puede aplicar las migraciones manualmente; la segunda es idempotente.
5. Ejecuta `npx wrangler secret put APP_PASSWORD` y escribe una contraseña larga y única. Después ejecuta `npx wrangler secret put GEMINI_API_KEY` y escribe la clave de Gemini. Los valores deben quedar como secretos del Worker, nunca en `wrangler.jsonc` ni en el frontend.
6. Abre la URL `workers.dev`, inicia sesión y comprueba que el panel se muestre. Cierra sesión y comprueba que los datos ya no aparezcan.

La base y el contenido estarán en tu propia cuenta de Cloudflare, separados del panel anterior de `chatgpt.site`. Si Gemini alcanza su cuota o falla, la aplicación sigue funcionando y tienes **Respuesta base**.

## Prueba local

Ejecuta `npm run build`. Copia `.dev.vars.example` a `.dev.vars`, cambia la contraseña ficticia y reemplaza la clave ficticia de Gemini si deseas probar IA. Después ejecuta `npm run db:local` y `npm run dev`. Abre `http://localhost:8787`.

## Límites actuales

- Las consultas se introducen manualmente; no hay integración oficial con chats de un perfil personal de Marketplace o con la app WhatsApp Business.
- Un registro representa una unidad de un producto. Si un cliente pide varias unidades, regístralas por separado para mantener el margen correcto.
- Los gastos se anotan por consulta. El resumen solo cuenta como margen cobrado una venta marcada **Entregado** y con pago verificado.
- La capacidad y algunas características de las powerbanks siguen pendientes de comprobación. Actualiza las fichas cuando verifiques los productos.
- En la capa gratuita de Gemini, Google indica que los datos pueden usarse para mejorar sus productos. Evita pegar nombres completos, números, direcciones exactas y comprobantes de pago. La aplicación elimina patrones comunes de números telefónicos y enlaces antes de enviarlos, pero no sustituye tu revisión.
