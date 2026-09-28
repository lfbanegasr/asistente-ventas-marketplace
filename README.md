# Mi mesa de ventas

Aplicación privada y ligera para gestionar consultas de Marketplace y WhatsApp Business desde el celular. Contiene fichas de producto, costos y precios, estado de cada consulta, entregas pendientes, ventas cobradas, exportación CSV y un asistente que propone respuestas con Gemini. El vendedor revisa y copia el texto; la aplicación no lee ni envía mensajes de Facebook o WhatsApp.

## Flujo diario

1. **Productos:** mantén precio, costo, precio mínimo interno y disponibilidad reales. Los tres productos iniciales son PB6010, PB225 y KNUP KP-5501TM. Todos empiezan en **Por confirmar**; cambia eso después de verificar al proveedor o tener unidades en mano.
2. **Asistente:** pega el mensaje del cliente, elige el producto y el objetivo. Puedes usar una respuesta base sin Gemini o pedir un borrador a Gemini. Revisa el resultado, cópialo y envíalo tú por el chat donde te escribió el cliente.
3. **Consultas:** registra a la persona si eligió producto o requiere seguimiento. Si confirmó precio y modalidad, marca **Confirmado**. Al comprar la unidad, marca **Comprado**. Al fijar hora y lugar, marca **Agendado**.
4. **Entrega:** confirma el pago cuando realmente se haya recibido. Marca **Entregado** para que la venta aparezca en el resumen. El margen se calcula con precio menos costo y otros gastos registrados.
5. **Copia de datos:** usa **Exportar CSV** con frecuencia; guárdalo en un lugar privado.

En persona: UAGRM (módulos), Cine Center u otro punto público acordado, con pago al recibir. Para Yango: cotizar según barrio, cobrar el producto antes de despacharlo y cotizar el envío aparte. Ningún mensaje debe garantizar stock o fecha sin una verificación previa.

## Para ponerla en Internet

Necesitas una cuenta propia de Cloudflare, una contraseña privada de al menos 16 caracteres y una clave gratuita de Gemini creada en Google AI Studio. **No pegues ninguna clave ni contraseña en un chat ni en archivos públicos.** No se necesita comprar un dominio; Cloudflare asigna una dirección `workers.dev`.

### Despliegue con GitHub y Cloudflare

El repositorio privado contiene solo este proyecto. Cloudflare puede conectarlo desde **Workers & Pages → Create application → Import a repository**. Selecciona el repositorio y configura:

- **Worker name:** `asistente-ventas-marketplace` (igual que en `wrangler.jsonc`).
- **Production branch:** `main`.
- **Root directory:** `/`.
- **Build command:** `npm run build`.
- **Deploy command:** `npx wrangler deploy`.

Cloudflare puede crear la base D1 automáticamente a partir de `wrangler.jsonc`. El esquema inicial y las tres fichas se crean la primera vez que entras. Antes de abrirla, configura en el Worker los secretos `APP_PASSWORD` (una contraseña única y larga) y `GEMINI_API_KEY` (clave nueva de AI Studio). La aplicación muestra su propio inicio de sesión, limita los intentos de contraseña y mantiene una sesión durante siete días. La clave que se haya compartido en un chat debe revocarse y reemplazarse.

Si antes configuraste Cloudflare Access, mantenlo activo mientras publicas esta versión y agregas `APP_PASSWORD`. Luego desactiva **Access** para este Worker. El sistema seguirá cerrado con su propia contraseña; si el secreto no está configurado, no dará acceso a los datos. `OWNER_EMAIL` ya no se usa y puede eliminarse después de comprobar el nuevo inicio de sesión.

Después de cada cambio en `main`, GitHub activará un nuevo despliegue. No subas `.dev.vars`, `.config`, `.npm-cache`, `.wrangler` ni `node_modules`: están excluidos por `.gitignore`.

### Alternativa desde la terminal

1. Abre una terminal en esta carpeta e instala las dependencias con `npm install`.
2. Entra a Cloudflare con `npx wrangler login`.
3. Ejecuta `npm run deploy`. Cloudflare creará el Worker y la base D1 definida en `wrangler.jsonc`. El Worker bloqueará los datos hasta que configures la contraseña.
4. La base se inicializa al primer acceso autorizado. `npm run db:remote` también está disponible si prefieres aplicar el archivo de migración manualmente.
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
