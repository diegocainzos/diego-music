# 02 — Rediseño de Home "Listen Now" (Home Spec)

## 1. Visión General y Variedad de Catálogo
Reestructuración completa de la pantalla inicial "Escuchar" (Listen Now) para erradicar la repetición de un solo artista y cargar una rica variedad multicultural de al menos 6-8 artistas destacados con géneros, portadas y álbumes reales.

## 2. Componentes de la Pantalla "Escuchar"

### 2.1 Hero Carousel / Destacados
- Banners promocionales horizontales de 340x220pt con bordes redondeados de 16pt.
- Etiquetas de categoría en `#FA2D48` ("NUEVO ÁLBUM", "DESTACADO", "ESTACIÓN EN VIVO").
- Portadas de alta resolución con degradado dinámico protector y titular gigante bold (24pt).

### 2.2 Tus Artistas Más Escuchados (Top Artistas)
- Fila horizontal de avatares circulares (`Circle()`, 110pt de diámetro) con efecto hover/press.
- Nombres de artistas destacados centrados en negrita debajo (ej. Nas, Karol G, Radiohead, Drake, Kendrick Lamar, Taylor Swift, Eminem, Daft Punk).
- Al pulsar cualquier avatar abre el perfil completo del artista (`ArtistView`).

### 2.3 Recomendaciones para Ti & Novedades
- Grids de tarjetas cuadradas de 180x180pt con portadas de alta resolución, bordes de 12pt, título de álbum/playlist en semibold y subtítulo del artista.
- Sección de "Recién Escuchado" para reanudación rápida.

## 3. Criterios de Aceptación
- [ ] Malla variada de 6-8+ artistas diversos en lugar de un solo artista repetido.
- [ ] Carrusel Hero promocional fluido con degradado.
- [ ] Avatares circulares de artistas interactivos con navegación al perfil.
