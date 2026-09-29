# Mi Mesa de Ventas — Arquitectura Desacoplada (Backend + Frontend + Móvil)

Sistema privado para la gestión de consultas de Facebook Marketplace y WhatsApp Business en Bolivia. Permite controlar fichas de productos (costos, precios, disponibilidad), registrar consultas y pedidos de clientes, agendar entregas (en persona o por Yango), verificar cobros, exportar respaldos en CSV y generar borradores de respuestas inteligentes con IA (Google Gemini 2.5 Flash Lite) o respuestas base offline.

---

## 🏛️ Arquitectura del Proyecto

El proyecto está 100% desacoplado en tres capas independientes:

```
┌────────────────────────────────────────────────────────┐
│                   BASE DE DATOS CLOUD                  │
│       PostgreSQL en la Nube (Neon / Supabase)          │
│   (100% Gratuito · Persistente · Sin Volúmenes de Disco)│
└───────────────────────────▲────────────────────────────┘
                            │
                            │ (DATABASE_URL con SSL)
                            │
┌───────────────────────────┴────────────────────────────┐
│                    BACKEND (REST API)                  │
│               Node.js · Express · JWT Auth             │
│    (Desplegable gratis en Render, Koyeb o Railway)     │
└───────────────▲────────────────────────▲───────────────┘
                │                        │
                │                        │
   (HTTPS / JSON con JWT)   (HTTPS / JSON con JWT)
                │                        │
┌───────────────┴────────┐      ┌────────┴───────────────┐
│     FRONTEND (WEB)     │      │    APP MÓVIL (FLUTTER) │
│     Vite · HTML · CSS  │      │     Android & iOS      │
│  (Vercel o Netlify)    │      │  (Conexión directa API)│
└────────────────────────┘      └────────────────────────┘
```

---

## ☁️ Dónde Alojar la Base de Datos Gratis (Persistencia Real y Fácil Migración)

Para evitar problemas con volúmenes de disco en servidores (que cobran, no se pueden migrar con facilidad y complican los respaldos), el backend utiliza **PostgreSQL Cloud**. El backend es **100% sin estado (stateless)**: puedes apagar, reiniciar o mover el servidor a otro proveedor y tus datos **nunca se pierden**.

### Opción 1: Neon Serverless Postgres (⭐⭐⭐⭐⭐ La más recomendada)
- **Capa Gratuita:** 0.5 GB de almacenamiento permanente, sin tarjeta de crédito.
- **Ventaja clave:** Es "serverless". Cuando no hay consultas se suspende a costo cero, y cuando llega una consulta de la web o el celular se despierta en milisegundos. **Nunca se archiva ni se pausa por inactividad semanal**.
- **Migración y Backups:** Compatible con `pg_dump`, DBeaver, TablePlus y tiene consola SQL web.
- **Cómo crearla:**
  1. Entra a [neon.tech](https://neon.tech) e inicia sesión con Google o GitHub.
  2. Crea un proyecto nuevo (ejemplo: `ventas-db`).
  3. Copia la cadena de conexión que te da en pantalla (empieza con `postgresql://...`).
  4. Pégala en tu backend como variable `DATABASE_URL`.

### Opción 2: Supabase (⭐⭐⭐⭐⭐ Ideal si te gusta ver y editar datos en tablas)
- **Capa Gratuita:** 500 MB de base de datos PostgreSQL, sin tarjeta de crédito.
- **Ventaja clave:** Tiene una interfaz visual web tipo Excel/Airtable (Table Editor). Puedes entrar desde cualquier navegador, ver tus productos y clientes, editar cualquier celda con un clic y descargar en CSV o SQL en 1 clic.
- **Nota:** En su plan gratuito, si pasa una semana completa sin ninguna consulta se pausa (se reactiva con 1 clic en su panel).
- **Cómo crearla:**
  1. Entra a [supabase.com](https://supabase.com) y crea una cuenta.
  2. Crea una nueva organización y proyecto.
  3. En **Project Settings → Database → Connection String**, copia la URI (usa el modo *Session* o *Pooled* en el puerto 6543 o 5432).
  4. Pégala en tu backend como `DATABASE_URL`.

### Opción 3: Turso (LibSQL / SQLite en la Nube)
- **Capa Gratuita:** 9 GB de almacenamiento y 500 bases de datos gratis.
- Motor SQLite distribuido a nivel global.

---

## 🚀 Dónde Alojar el Backend Gratis

El backend vive en la carpeta [`backend/`](file:///d:/1%20VENTAS/Ventas%20Marketplace/asistente-ventas/backend). Solo requiere Node.js 20+ y se ejecuta sin volúmenes persistentes.

### Opción 1: Render (Web Service Gratis)
1. Ve a [render.com](https://render.com) y crea un nuevo **Web Service**.
2. Conecta tu repositorio de GitHub.
3. Configura:
   - **Root Directory:** `backend`
   - **Environment:** `Node`
   - **Build Command:** `npm install`
   - **Start Command:** `npm start`
4. En **Environment Variables**, agrega:
   - `APP_PASSWORD`: Contraseña secreta para entrar (mínimo 16 caracteres).
   - `JWT_SECRET`: Cadena aleatoria de 32+ caracteres.
   - `DATABASE_URL`: La URL de conexión de Neon o Supabase.
   - `CORS_ORIGINS`: La URL donde esté tu frontend (ej: `https://tu-frontend.vercel.app,http://localhost:5173`).
   - `GEMINI_API_KEY`: Tu API key gratuita de Google AI Studio (opcional).

### Opción 2: Koyeb (Eco Service Gratis)
1. Ve a [koyeb.com](https://koyeb.com).
2. Crea un servicio gratuito con origen GitHub.
3. Apunta a la subcarpeta `backend` o usa el `Dockerfile` incluido (`backend/Dockerfile`).
4. Añade las mismas variables de entorno.

### Opción 3: Railway
- Si prefieres Railway, ahora puedes desplegar el backend **sin necesidad de crear ningún volumen persistente**, ya que los datos viven en Neon o Supabase.

---

## 🌐 Dónde Alojar el Frontend Web Gratis

El frontend vive en [`frontend/`](file:///d:/1%20VENTAS/Ventas%20Marketplace/asistente-ventas/frontend) y es una Single Page Application moderna con Vite.

### Opción 1: Vercel (Recomendado)
1. Ve a [vercel.com](https://vercel.com) y haz clic en **Add New Project**.
2. Importa tu repositorio.
3. En **Root Directory**, selecciona `frontend`.
4. En **Environment Variables**, añade:
   - `VITE_API_URL`: La URL pública de tu backend (ej: `https://mi-backend.onrender.com`).
5. Haz clic en **Deploy**. Tendrás HTTPS automático y CDN global gratis.

---

## 📱 App Móvil (Flutter)

La aplicación nativa para Android y iOS se encuentra en [`mobile/`](file:///d:/1%20VENTAS/Ventas%20Marketplace/asistente-ventas/mobile).

- **Sin intermediarios:** Se conecta directamente a la API REST del backend mediante llamadas HTTPS seguras con tokens JWT almacenados en el enclave seguro (`flutter_secure_storage`).
- **Selector de Servidor en Login:** La pantalla de inicio de sesión incluye un selector expandible para configurar la URL del backend (por ejemplo: `https://mi-backend.onrender.com`), por lo que no es necesario recompilar la app si cambias de servidor.
- **Compilación:**
  ```bash
  cd mobile
  flutter pub get
  flutter build apk --release
  ```

---

## 💾 Respaldo y Migración de Datos (1 Clic)

Tus datos nunca quedan atrapados:
1. **Desde la App Web o Móvil:** En la sección *Consultas*, toca el botón **Exportar CSV** para descargar un archivo con todos los clientes, fechas, montos y estados.
2. **Desde el Backend (Script automático):**
   ```bash
   cd backend
   npm run backup
   ```
   Genera instantáneamente en `backend/backups/`:
   - Un archivo `.json` con todas las tablas completas (productos, verificaciones de stock, consultas, chats y mensajes).
   - Un archivo `.csv` estructurado con el historial de ventas y pedidos.
3. **Desde PostgreSQL:** Puedes usar herramientas estándar como `pg_dump` o la consola de Supabase/Neon para exportar e importar en cualquier momento.

---

## 💻 Desarrollo Local

### 1. Iniciar el Backend
```bash
cd backend
npm install
# Inicia con PostgreSQL en memoria temporal si no configuras DATABASE_URL
npm run dev
```
Para ejecutar las pruebas automáticas del backend:
```bash
npm test
```

### 2. Iniciar el Frontend
```bash
cd frontend
npm install
npm run dev
```
Abre en tu navegador: `http://localhost:5173`.

### 3. Ejecutar la App Móvil
```bash
cd mobile
flutter run
```
