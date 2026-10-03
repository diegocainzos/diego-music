## ADDED Requirements

### Requirement: Clave de firma JWT obligatoria
El backend MUST leer `SECRET_KEY` del entorno y MUST NOT incluir una clave por defecto en el código fuente. Si la variable falta o tiene menos de 32 caracteres, el servicio MUST negarse a arrancar con un mensaje que nombre la variable sin revelar ningún valor.

#### Scenario: Arranque sin clave
- **WHEN** el contenedor arranca sin `SECRET_KEY` definida
- **THEN** el proceso termina con un error de configuración que menciona `SECRET_KEY` y no imprime valores de configuración.

#### Scenario: JWT firmado con la antigua clave por defecto
- **WHEN** un cliente presenta un JWT firmado con la clave por defecto que existía antes de este cambio
- **THEN** `require_api_token` y `get_current_user` lo rechazan con `401`.

### Requirement: Datos demo opcionales
El arranque del servicio MUST NOT crear usuarios ni datos de ejemplo salvo que `SEED_DEMO_DATA` sea `true`, `1` o `yes`.

#### Scenario: Primer arranque en producción
- **WHEN** el servicio arranca con una base de datos vacía y sin `SEED_DEMO_DATA`
- **THEN** la base queda sin usuarios hasta el primer registro.

### Requirement: Inspección de Compose sin expandir secretos
Toda documentación y script del repositorio MUST validar la configuración de Compose con `docker compose ... config --quiet` y MUST NOT indicar ejecutar `docker compose config` mostrando su salida.

#### Scenario: Guía de despliegue
- **WHEN** un operador sigue `README.md` o `ResolverService/README.md` para validar Compose
- **THEN** el comando indicado usa `--quiet`.
