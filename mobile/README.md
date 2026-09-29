# Mi mesa de ventas · app móvil

Aplicación Flutter para Android y iPhone conectada a `https://asistente-ventas-marketplace.lfbanegasr126.workers.dev/login`. Abre la interfaz móvil del Worker en una vista integrada, por lo que usa la misma base D1, los mismos productos y consultas, el login propio y Cloudflare Access. No guarda claves ni contraseñas en el código. Necesita conexión a Internet.

La app ofrece recarga, indicador de carga, aviso cuando falla la conexión y exportación CSV mediante el menú de compartir del teléfono. Solo el dominio exacto del Worker y las páginas de Cloudflare Access se abren en la vista integrada; otros enlaces HTTPS se abren fuera. El CSV solo se comparte cuando lo solicita la página del Worker.

## Android

Desde `mobile/`, ejecuta `flutter pub get`, `flutter test`, `flutter analyze` y `flutter build apk --release`. En este equipo Windows, `scripts/build-android.ps1` ubica las cachés de Flutter y Gradle en `D:` para evitar el poco espacio libre de `C:`. El APK se crea en `build/app/outputs/flutter-apk/app-release.apk`. El proyecto generado firma esta compilación con la clave de prueba de Flutter: sirve para instalación privada y pruebas; para distribuir por una tienda hay que configurar una firma de publicación propia.

Al abrir la app, completa primero Cloudflare Access y después el login propio. Si Cloudflare Access sigue mostrando “Cloudflare sign-in is restricted to members of the account”, hay que corregir su política en la cuenta de Cloudflare. La app móvil no elude esa protección. No pegues credenciales en chats ni en este repositorio.

## iPhone

El proyecto iOS está preparado en `ios/`. Para compilarlo e instalarlo se necesita macOS con Xcode y la firma de Apple correspondiente. El código Flutter y la interfaz son los mismos.

Las mejoras de productos, consultas, entregas y Gemini se hacen en el Worker y aparecen en la app móvil sin volver a generar el APK. Una actualización del contenedor Flutter sí requiere instalar una versión nueva.
