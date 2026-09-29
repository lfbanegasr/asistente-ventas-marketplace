FROM node:22-slim

WORKDIR /app

# Copiar migraciones (desde la raíz del proyecto)
COPY migrations/ ./migrations/

# Instalar dependencias de producción
COPY backend/package*.json ./
RUN npm ci --omit=dev

# Copiar código del backend
COPY backend/src/ ./src/

ENV PORT=3001
ENV NODE_ENV=production

EXPOSE 3001

CMD ["node", "src/server.js"]
