# Spec: QA — Descargas Offline (app nativa iOS/macOS)

## Entorno de prueba

- Simulador iOS 17+ o dispositivo físico iPhone (preferido para audio real).
- Xcode 15+, `xcodebuild test` para pruebas unitarias.
- Prueba de red: Simulador → Hardware → Network Link Conditioner → 100% Loss,
  o en dispositivo: Modo Avión.

---

## Checklist de Criterios de Aceptación

### A. Descarga individual

- [ ] **A1** Tocar el botón `↓` en una fila de `LibraryTrackRow` inicia la descarga;
       el botón cambia a anillo de progreso animado.
- [ ] **A2** Al completarse, el botón cambia a `arrow.down.circle.fill` verde sin reiniciar la vista.
- [ ] **A3** El progreso numérico (0–100 %) refleja correctamente los bytes descargados.
- [ ] **A4** Si se cancela la descarga a mitad, el fichero temporal se elimina y el estado vuelve a `.notDownloaded`.

### B. Descarga en lote (álbum / playlist)

- [ ] **B1** El botón "Descargar todo" en la cabecera de un álbum encola todas las pistas.
- [ ] **B2** Las pistas se descargan en serie (no en paralelo), visible por el progreso secuencial.
- [ ] **B3** Al completar todas, el botón cambia a estado "todo descargado".
- [ ] **B4** Una pista ya descargada se salta silenciosamente sin redownload.

### C. Reproducción offline

- [ ] **C1** Activar Modo Avión / Loss 100 % → banner `OfflineBanner` aparece en la UI.
- [ ] **C2** Dar play a una pista descargada en Modo Avión reproduce el audio correctamente
       (sin spinner infinito, sin error de red).
- [ ] **C3** `AudioPlayerCoordinator.load` usa la URL `file://` local sin llamar al VPS resolver.
- [ ] **C4** Dar play a una pista NO descargada en Modo Avión muestra el error sanitizado
       y la fila aparece atenuada (opacidad 0.4).
- [ ] **C5** Al recuperar la red, el banner desaparece y las pistas no descargadas vuelven a estar disponibles.

### D. Sección "Descargados" en Biblioteca

- [ ] **D1** La pestaña/sección "Descargados" muestra solo las pistas con `DownloadedTrackRecord` en Core Data.
- [ ] **D2** El tamaño de fichero se muestra en la fila (ej. "3.2 MB").
- [ ] **D3** El toggle "Solo descargados" en Canciones filtra la lista correctamente.

### E. Gestión y limpieza

- [ ] **E1** Pulsar el botón verde `↓` (ya descargado) → `ConfirmationDialog` "Eliminar descarga".
- [ ] **E2** Confirmar la eliminación borra el fichero del disco y el registro Core Data.
- [ ] **E3** En Ajustes → Almacenamiento, se muestra el espacio total ocupado en MB/GB.
- [ ] **E4** "Liberar todo el espacio" → confirmar → borra todos los ficheros y registros.

### F. Pruebas unitarias (XCTest)

- [ ] **F1** `OfflineDownloadManagerTests.testIsDownloaded` — mock FileManager.
- [ ] **F2** `OfflineDownloadManagerTests.testRemoveDownload` — verifica borrado de fichero y Core Data.
- [ ] **F3** `AudioPlayerCoordinatorTests.testUsesLocalURLWhenAvailable` — inyectar stub del manager.
- [ ] **F4** `NetworkMonitorTests.testOfflineBannerAppears` — usar `NWPathMonitor` mock.

---

## Procedimiento QA manual

1. Instalar en Simulador (iPhone 15 Pro, iOS 17).
2. Añadir 2 canciones a favoritos (para que aparezcan en Biblioteca → Canciones).
3. Descargar una canción individual → verificar A1, A2, A3.
4. Abrir un álbum → "Descargar todo" con 3 pistas → verificar B1–B4.
5. Activar Modo Avión → verificar C1, C2, C4.
6. Reproducir la canción descargada → verificar C2, C3 (no debe haber tráfico de red).
7. Desactivar Modo Avión → verificar C5.
8. Abrir Biblioteca → Descargados → verificar D1, D2.
9. Eliminar descarga individual → verificar E1, E2.
10. Ir a Ajustes → Almacenamiento → verificar E3.
11. "Liberar todo" → verificar E4, luego re-verificar D1 (lista vacía).

---

## Herramienta de verificación de secretos

Antes de commit: `./scripts/verify-no-secrets.py` — debe pasar sin advertencias.

## Validación de build

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project DiegoMusic.xcodeproj -scheme DiegoMusic \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO test
```
