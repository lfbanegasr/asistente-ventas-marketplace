import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

async function main() {
  console.log('Obteniendo credenciales de GitHub...');
  const credsRaw = execSync('git credential fill', {
    input: 'protocol=https\nhost=github.com\n\n',
    encoding: 'utf8'
  });
  const tokenMatch = credsRaw.match(/password=(.+)/);
  if (!tokenMatch) throw new Error('No se pudo obtener el token de GitHub');
  const token = tokenMatch[1].trim();

  const apkPath = path.resolve('mobile/build/app/outputs/flutter-apk/app-release.apk');
  if (!fs.existsSync(apkPath)) {
    throw new Error('No existe app-release.apk en ' + apkPath);
  }
  const apkStats = fs.statSync(apkPath);
  console.log(`APK encontrado: ${(apkStats.size / (1024 * 1024)).toFixed(2)} MB`);

  const repo = 'lfbanegasr/asistente-ventas-marketplace';
  const tag = 'v2.1.0';

  console.log(`Verificando si release ${tag} existe...`);
  const checkRes = await fetch(`https://api.github.com/repos/${repo}/releases/tags/${tag}`, {
    headers: {
      Authorization: `Bearer ${token}`,
      'User-Agent': 'Node-Release-Script',
      Accept: 'application/vnd.github+json'
    }
  });

  let release;
  if (checkRes.ok) {
    release = await checkRes.json();
    console.log(`Release ${tag} ya existe (id: ${release.id}).`);
  } else {
    console.log(`Creando nuevo release ${tag}...`);
    const createRes = await fetch(`https://api.github.com/repos/${repo}/releases`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'User-Agent': 'Node-Release-Script',
        Accept: 'application/vnd.github+json',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        tag_name: tag,
        name: `Mesa de Ventas ${tag} - Offline-First & Herramientas de Venta`,
        body: '### Novedades de la versión 2.1.0:\n* **Arquitectura Offline-First:** Carga instantánea (< 0.1s) con almacenamiento local y sincronización automática en segundo plano con conciliación de IDs.\n* **Comprobante de Venta Digital:** Generación de recibo visual estilo ticket con captura directa para compartir por WhatsApp.\n* **Entregas y Citas para HOY:** Sección de citas del día con acciones directas para abrir WhatsApp con plantilla o abrir Google Maps con la ubicación de entrega.\n* **Portapapeles Inteligente:** Asistente que analiza consultas copiadas, sugiere respuestas rápidas basadas en el catálogo y permite registrar prospectos con 1 toque.\n* **Backend Keep-Alive & Diagnóstico:** Eliminación del arranque en frío de Render y monitoreo continuo de latencia PostgreSQL.\n* **Refactorización Modular:** Código desacoplado en componentes, vistas y servicios reutilizables.',
        draft: false,
        prerelease: false
      })
    });
    if (!createRes.ok) {
      const err = await createRes.text();
      throw new Error(`Error al crear release: ${createRes.status} ${err}`);
    }
    release = await createRes.json();
    console.log(`Release creado con éxito (id: ${release.id})`);
  }

  // Delete existing asset if it exists with same name
  const assetsRes = await fetch(`https://api.github.com/repos/${repo}/releases/${release.id}/assets`, {
    headers: {
      Authorization: `Bearer ${token}`,
      'User-Agent': 'Node-Release-Script',
      Accept: 'application/vnd.github+json'
    }
  });
  if (assetsRes.ok) {
    const assets = await assetsRes.json();
    for (const a of assets) {
      if (a.name === 'app-release.apk') {
        console.log(`Eliminando asset previo ${a.name}...`);
        await fetch(`https://api.github.com/repos/${repo}/releases/assets/${a.id}`, {
          method: 'DELETE',
          headers: {
            Authorization: `Bearer ${token}`,
            'User-Agent': 'Node-Release-Script'
          }
        });
      }
    }
  }

  console.log('Subiendo app-release.apk a GitHub Releases (esto toma unos segundos)...');
  const fileBuffer = fs.readFileSync(apkPath);
  const uploadUrl = `https://uploads.github.com/repos/${repo}/releases/${release.id}/assets?name=app-release.apk`;
  const uploadRes = await fetch(uploadUrl, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'User-Agent': 'Node-Release-Script',
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Length': apkStats.size.toString()
    },
    body: fileBuffer
  });

  if (!uploadRes.ok) {
    const err = await uploadRes.text();
    throw new Error(`Error al subir APK: ${uploadRes.status} ${err}`);
  }

  const uploaded = await uploadRes.json();
  console.log('✅ ¡APK subido exitosamente a GitHub Releases!');
  console.log(`URL directa del archivo: ${uploaded.browser_download_url}`);
  console.log(`URL fija para siempre: https://github.com/${repo}/releases/latest/download/app-release.apk`);
}

main().catch(err => {
  console.error('Fallo en la publicación:', err);
  process.exit(1);
});
