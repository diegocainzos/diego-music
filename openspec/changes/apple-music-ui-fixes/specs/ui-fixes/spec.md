# Spec: UI Fixes & Theme System

## MODIFIED Requirements

### Requirement: Theme Mode Support
La aplicación MUST ofrecer soporte adaptativo dinámico para Modo Claro y Modo Oscuro según el `colorScheme` del sistema o la configuración seleccionada.

#### Scenario: Switching color scheme
- GIVEN la aplicación en ejecución
- WHEN se conmuta el tema entre Modo Claro y Oscuro
- THEN los colores de fondo, tarjetas, textos e iconos se ajustan dinámicamente preservando el acento rojo `#FA2D48`.

### Requirement: Non-Overlapping Player Dock
El reproductor flotante (`PlayerDock`) MUST NOT solapar los botones del `TabBar` ni tapar el final de los listados desplazables.

#### Scenario: Scroll list to bottom
- GIVEN una lista larga en Búsqueda o Biblioteca
- WHEN el usuario hace scroll hacia el final
- THEN el último elemento es 100% visible por encima del reproductor.
