## ADDED Requirements

### Requirement: Identidad visual propia
DiegoMusic SHALL usar geometría Bauhaus, primarios cálidos y controles Hi‑Fi propios sin logotipos ni apariencia que sugieran una aplicación oficial de YouTube.

#### Scenario: Pantalla principal
- **WHEN** se muestra Inicio
- **THEN** la jerarquía combina retícula geométrica, superficies crema/carbón y acentos rojo, amarillo y azul

### Requirement: Interfaz informativa equilibrada
La interfaz SHALL priorizar metadatos legibles, densidad equilibrada y un mini reproductor discreto con controles expresivos.

#### Scenario: Resultado de búsqueda
- **WHEN** se muestra un resultado
- **THEN** título, canal y miniatura siguen siendo legibles y las acciones tienen etiquetas accesibles

### Requirement: Movimiento accesible
DiegoMusic SHALL usar animaciones abundantes para transiciones y controles, pero SHALL reducirlas cuando el sistema solicite menos movimiento.

#### Scenario: Reducir movimiento activo
- **WHEN** `accessibilityReduceMotion` está activado
- **THEN** las transformaciones decorativas se sustituyen por cambios breves de opacidad o sin animación

### Requirement: Interacción accesible
Los controles SHALL mantener contraste, foco de teclado, etiquetas de accesibilidad y áreas de interacción adecuadas.

#### Scenario: Control solo con icono
- **WHEN** un botón muestra únicamente un símbolo
- **THEN** proporciona una etiqueta accesible que explica su acción
