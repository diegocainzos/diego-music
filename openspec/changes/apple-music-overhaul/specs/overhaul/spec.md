# Spec: Apple Music Overhaul

## MODIFIED Requirements

### Requirement: Authentic Apple Music Aesthetic
La aplicación MUST mostrar la identidad visual de Apple Music con su logotipo, acento `#FA2D48`, variedad de catálogo y soporte para temas Claro/Oscuro.

#### Scenario: Launching the app
- GIVEN la aplicación en ejecución
- WHEN el usuario abre la pantalla de inicio o navegación
- THEN figura el logotipo de Apple Music, la paleta de colores oficial y variedad de artistas.

### Requirement: Interactive Playlist Creation
El botón de creación de playlist MUST abrir un modal interactivo y actualizar el estado global inmediatamente.

#### Scenario: Creating a new playlist
- GIVEN el usuario en la sección de Biblioteca o Playlists
- WHEN pulsa "+ Crear Playlist" e introduce un nombre
- THEN la nueva playlist se guarda en LibraryStore y se muestra en el Sidebar y Biblioteca de inmediato.
