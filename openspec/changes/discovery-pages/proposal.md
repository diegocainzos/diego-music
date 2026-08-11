## Why

DiegoMusic busca y reproduce música pública, pero Inicio es hoy una pantalla estática de presentación y no existe forma de explorar un artista o un álbum: la búsqueda devuelve resultados planos y no hay navegación hacia el contexto (top tracks, discografía, relacionados) que un oyente de streaming espera. El catálogo ya llega por YouTube Data API v3, así que DiegoMusic puede añadir descubrimiento con el mismo origen de datos, sin depender de perfiles ni de ML propietario.

## What Changes

- Convertir `HomeView` en un inicio con descubrimiento: una sección "Descubrir / Novedades" rellena por resultados públicos de YouTube (best-effort, sin personalización de perfil).
- Añadir página de artista (top tracks, discografía, relacionados) navegable por `NavigationStack` como push desde Inicio o Búsqueda.
- Añadir página de álbum (lista de pistas) navegable de igual forma.
- Extender la capa de YouTube con métodos async nuevos (artista/álbum/relacionados) sin alterar la firma existente `search(query:pageToken:)`.
- Mantener el manejo de `apiKey` exactamente como está hoy (nunca loguear URLs ni tokens) y errores sanitizados.

## Capabilities

### New Capabilities

- `discovery-pages`: descubrimiento en la app — Inicio con sección de novedades, página de artista (top tracks, discografía, relacionados) y página de álbum (lista de pistas), alimentadas por YouTube Data API v3 mediante una extensión del servicio existente.

### Modified Capabilities

<!-- No hay baseline archivado (openspec/specs/ no existe aún); el descubrimiento se aporta como capability ADDED nueva. No modifica capabilities en curso. -->

## Impact

- Cliente: `YouTubeDataService`, `YouTubeDTOs`, `YouTubeEndpoint`, `YouTubeMapper` (nuevos métodos async de artista/álbum/relacionados) y `HomeView` (sección Descubrir). Ficheros nuevos: `ArtistView`, `AlbumView`, `HomeViewModel` (y sus DTOs).
- Navegación: push desde Inicio/Búsqueda hacia artista y álbum; `RootView` no se toca.
- Comportamiento: Inicio deja de ser estático y muestra contenido explorable; se puede entrar a contexto de artista y álbum.
- Sin cambios en ResolutionService, persistencia, cola ni `AVPlayer`.
- La accesibilidad existente (labels, reduce motion, contraste) se conserva.
