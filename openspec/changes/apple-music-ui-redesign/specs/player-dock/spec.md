## ADDED Requirements

### Requirement: Reproductor Dock Flotante estilo Apple Music Web

La aplicación SHALL disponer de un reproductor dock flotante/superior estilo Apple Music Web con carátula de pista, información de título y canal/artista, scrubber de progreso interactivo con indicación de tiempo (0:00 / 0:00), selector de volumen, botones de control (Anterior, Reproducir/Pausa, Siguiente), aleatorio (shuffle), repetición, letras y cola.

#### Scenario: Interacción con el scrubber de progreso
- **WHEN** el usuario arrastra o toca la barra de progreso en el reproductor dock
- **THEN** la reproducción salta al tiempo seleccionado
- **AND** las etiquetas de tiempo transcrito y restante se actualizan inmediatamente

#### Scenario: Control de volumen interactivo
- **WHEN** el usuario ajusta el deslizador de volumen en el dock del reproductor
- **THEN** el volumen de salida del `AVPlayer` cambia proporcionalmente de 0.0 a 1.0
