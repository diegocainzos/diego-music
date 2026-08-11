# Especificación Técnica de Layout y Navegación (Layout Navigation Spec)

## 1. Visión General
Solución a problemas críticos de maquetación: solapamiento del mini-player con la barra de pestañas (Docker / TabBar), jerarquía de capas (`z-index` y `safeAreaInset`), y gestión correcta del stack de rutas al cambiar de pestaña en la navegación.

## 2. Bugfixes y Reglas de Layout

### 2.1 Jerarquía de Capas y Evitación de Solapamiento (PlayerDock vs TabBar)
- **Problema identificado**: En iPhone, el reproductor Dock flotante o el mini-player tapaba o solapaba los iconos de la barra de pestañas (`TabView`), impidiendo tocar los botones inferiores o cortando el contenido de las listas.
- **Solución técnica**:
  - En `RootView.swift`, estructurar el `PlayerDock` mediante `.safeAreaInset(edge: .bottom)` O dentro de una estructura `VStack(spacing: 0)` donde el `PlayerDock` quede posicionado **estrictamente por encima** de la barra de pestañas (`TabBar`), o dentro del inset seguro de la app.
  - Añadir padding inferior dinámico (`padding(.bottom, playerHeight + tabBarHeight)`) a las vistas contenidas (`ScrollView` / `List`) para asegurar que el último elemento de la lista sea 100% visible y desplazable por encima del player dock.
  - Asegurar un `z-index` controlado:
    - Capa 0: Contenido de la vista activa (ScrollView/List).
    - Capa 1: Player Dock flotante (`PlayerDock`).
    - Capa 2: Barra de navegación inferior (`PhoneTabBar` / `TabView`) o Sidebar en regular.

### 2.2 Reseteo de la Pila de Navegación al Pulsar en el Docker / TabBar
- **Problema identificado**: Al estar dentro de una navegación profunda (ej. resultado de búsqueda -> artista -> álbum), pulsar el icono de Búsqueda o Inicio en la barra inferior no devolvía al usuario a la raíz de esa pestaña.
- **Solución técnica**:
  - Implementar en `NavigationState` / `RootView` un gestor de toque repetido en la pestaña activa:
    ```swift
    func selectTab(_ destination: AppDestination) {
        if selection == destination {
            // Si ya estamos en esta pestaña, reseteamos la pila de navegación a la raíz
            resetToRoot(destination)
        } else {
            selection = destination
        }
    }
    ```
  - Permitir salir de Búsqueda, Biblioteca o Inicio de forma inmediata sin quedar atrapado en sheets o sub-rutas.

## 3. Criterios de Aceptación
- [ ] El mini-player/dock flota perfectamente sobre la barra de pestañas sin tapar los iconos táctiles.
- [ ] Todas las listas (`ScrollView`, `LazyVStack`) se desplazan por completo hasta el final con margen libre para ver la última pista.
- [ ] Tocar el icono de una pestaña activa resetea la pila de navegación a la vista principal de dicha sección.
