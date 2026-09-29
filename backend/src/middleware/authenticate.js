import { extractToken, verifyToken, passwordReady } from '../auth.js';

export function authenticate(req, res, next) {
  if (!passwordReady()) {
    return res.status(401).json({ error: 'Acceso no configurado.' });
  }

  const token = extractToken(req);
  if (!token || !verifyToken(token)) {
    return res.status(401).json({ error: 'Inicia sesión para continuar.' });
  }

  next();
}
