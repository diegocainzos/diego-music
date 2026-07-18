## 1. Servicio resolutor

- [x] 1.1 Crear la aplicación FastAPI, configuración validada, modelos API y dependencias fijadas.
- [x] 1.2 Implementar el adaptador `yt-dlp` sin shell con validación de ID, selección M4A/AAC y errores sanitizados.
- [x] 1.3 Implementar autenticación Bearer, almacén de sesiones opacas con TTL y endpoint de resolución.
- [x] 1.4 Implementar proxy GET/HEAD con reenvío de Range y cabeceras multimedia permitidas.
- [x] 1.5 Cubrir autenticación, validación, expiración, resolución y rangos con pruebas pytest aisladas de YouTube.

## 2. Despliegue VPS

- [x] 2.1 Añadir Dockerfile reproducible con yt-dlp, componentes EJS/runtime JavaScript y FFmpeg.
- [x] 2.2 Añadir Docker Compose, health check y Caddy HTTPS sin publicación directa del puerto interno ni access logs.
- [x] 2.3 Documentar configuración, despliegue, actualización, rotación de token y diagnóstico sin secretos.

## 3. Cliente resolutor y configuración

- [x] 3.1 Extender la configuración local, Info.plist y escáner de secretos para URL/token del resolutor sin romper instalaciones no configuradas.
- [x] 3.2 Implementar `AudioResolverClient`, contrato Codable, errores localizados e inyección para pruebas.
- [x] 3.3 Añadir pruebas Swift para validación de configuración, request autenticada, respuestas y errores sanitizados.

## 4. Reproductor nativo

- [x] 4.1 Implementar `AudioPlayerCoordinator` sobre una única instancia AVPlayer con cancelación de resolución, progreso, seek y avance de cola.
- [x] 4.2 Configurar AVAudioSession/background audio y controles/metadatos de MPRemoteCommandCenter en iOS.
- [x] 4.3 Sustituir el dock de vídeo por la interfaz musical compacta/ampliada conservando cola y accesibilidad.
- [x] 4.4 Integrar el reproductor en AppEnvironment y Ajustes, retirando WKWebView y PrivacyShield del flujo activo.

## 5. Seguridad y validación

- [x] 5.1 Actualizar instrucciones del proyecto para permitir exclusivamente el resolutor privado en esta rama y prohibir fugas de URLs/tokens.
- [x] 5.2 Regenerar el proyecto, ejecutar pruebas Python/Swift, escáner de secretos y validación OpenSpec estricta.
- [ ] 5.3 Validar reproducción, bloqueo de pantalla y controles remotos en un iPhone con Xcode/SDK iOS 17 o posterior.
- [x] 5.4 Actualizar README raíz con arquitectura, configuración local y procedimiento de instalación en iPhone.
