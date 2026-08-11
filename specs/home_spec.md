# Especificación de Pantalla "Listen Now" (Home Spec)

## 1. Visión General
Rediseño de la pantalla de inicio para igualar la experiencia "Listen Now / Escuchar" de Apple Music Web, ofreciendo banners promocionales Hero, avatares circulares de Top Artistas, recomendaciones personalizadas y carruseles horizontales.

## 2. Estructura de Secciones

### 2.1 Cabecera ("Escuchar / Listen Now")
- Título destacado "Escuchar" (o "Listen Now") en estilo 32pt bold con avatar de perfil en el extremo superior derecho.
- Subtítulo dinámico según la hora del día ("Buenos días", "Buenas tardes", "Buenas noches").

### 2.2 Hero Carousel (Destacados del Día)
- Carrusel horizontal desplazable (`ScrollView(.horizontal)`) de banners promocionales de gran formato (320-380pt de ancho, 220pt de alto).
- Tarjeta de banner con:
  - Eyebrow en rojo acento `#FA2D48` (ej. "NUEVO ÁLBUM", "ESTACIÓN RECOMENDADA").
  - Título principal en 22pt Bold (blanco/legible con degradado protector inferior).
  - Subtítulo descriptivo.
  - Carátula de alta resolución con esquinas redondeadas (16pt).
  - Reproducción inmediata al pulsar la tarjeta.

### 2.3 Top Artistas (Avatares Circulares)
- Sección "Top Artistas" / "Artistas Recomendados".
- Lista horizontal de avatares circulares (diámetro 110pt) con recorte `Circle()`, sombra suave y borde sutil.
- Nombre del artista debajo en negrita centrada (lineLimit 1).
- Tap en la foto abre el perfil completo del artista (`ArtistView`).

### 2.4 Grids de Recomendaciones y Novedades
- Cuadrícula adaptativa (`LazyVGrid`) o lista horizontal de álbumes/playlists recomendados.
- Carátulas cuadradas (160x160pt) con esquinas redondeadas (12pt).
- Título en 14pt semibold (hasta 2 líneas) + Artista en 12pt secundario.

### 2.5 Historial de Escucha Reciente ("Escuchado recientemente")
- Fila horizontal o lista compacta con las últimas pistas o álbumes reproducidos para fácil reanudación.

## 3. Criterios de Aceptación
- [ ] Renderizado responsivo para pantallas compactas (iPhone) y regulares (iPad/macOS).
- [ ] Banners promocionales Hero con desplazamiento horizontal suave.
- [ ] Avatares circulares de artistas con navegación inmediata a su perfil.
- [ ] Soporte completo para Modo Claro y Modo Oscuro.
