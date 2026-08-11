# 03 — Especificación de Pantalla de Artista (Artist Page Spec)

## 1. Visión General
Vista detallada de perfil de artista inspirada al 100% en Apple Music Web, incorporando foto de portada gigante, insignia de artista verificado, catálogo de éxitos populares, discografía completa y artistas similares.

## 2. Estructura de la Vista de Artista (`ArtistView`)

### 2.1 Header de Portada Gigante
- Cabecera con imagen del artista a ancho completo o avatar destacado de 140pt con sombra ambiental.
- Nombre del artista en tipografía gigante bold (36pt) con badge de verificación azul/blanco (`checkmark.seal.fill`).
- Resumen/Bio sutil del artista.

### 2.2 Botones de Acción Prominentes
- **Reproducir**: Botón cápsula gigante en Rojo Apple `#FA2D48` (`play.fill`) para iniciar los top tracks del artista.
- **Aleatorio**: Botón cápsula con borde en Rojo Apple (`shuffle`) para reproducción en modo aleatorio.
- **Seguir / Favorito**: Botón para guardar al artista en la biblioteca local.

### 2.3 Éxitos Populares (Top Canciones)
- Lista numerada (1, 2, 3...) de las canciones más populares del artista.
- Miniatura cuadrada de 48x48pt, título semibold, reproducciones o subtítulo de álbum, duración y menú de 3 puntos (`ellipsis`).

### 2.4 Discografía y Álbumes
- Grid responsivo de álbumes y EPs ordenados cronológicamente con portadas cuadradas de 180x180pt.

### 2.5 Artistas Similares
- Carrusel horizontal de avatares circulares de artistas del mismo género/estilo con navegación fluida entre perfiles.

## 3. Criterios de Aceptación
- [ ] Header visual prominente con foto de portada y nombre en 36pt bold.
- [ ] Botones de acción "Reproducir" y "Aleatorio" en cápsulas rojas.
- [ ] Lista numerada de éxitos populares y discografía.
