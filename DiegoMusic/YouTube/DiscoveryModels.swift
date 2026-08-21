import Foundation

/// Perfil de un canal/artista obtenido del endpoint `channels`.
struct Artist: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let bio: String?
    let thumbnailURL: URL?
}

/// Página de artista: perfil + top tracks + relacionados + discografía/álbumes.
struct ArtistDetail: Equatable, Sendable {
    let artist: Artist
    let topTracks: [MediaItem]
    let related: [MediaItem]
    let albums: [Album]

    init(
        artist: Artist,
        topTracks: [MediaItem],
        related: [MediaItem],
        albums: [Album] = []
    ) {
        self.artist = artist
        self.topTracks = topTracks
        self.related = related
        self.albums = albums
    }
}

/// Álbum/lista obtenido del endpoint `playlistItems`.
struct Album: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let channelTitle: String?
    let thumbnailURL: URL?
    let tracks: [MediaItem]
}

/// Referencia ligera a un artista dentro del feed de descubrimiento.
struct ArtistReference: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let thumbnailURL: URL?
}

/// Feed público de descubrimiento (novedades) mostrado en Inicio.
struct DiscoveryFeed: Equatable, Sendable {
    let novedades: [MediaItem]
    let artistas: [ArtistReference]
}
