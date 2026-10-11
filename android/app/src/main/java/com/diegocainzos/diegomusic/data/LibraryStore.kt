package com.diegocainzos.diegomusic.data

import com.diegocainzos.diegomusic.core.Album
import com.diegocainzos.diegomusic.core.EpisodeProgressValue
import com.diegocainzos.diegomusic.core.LocalArtist
import com.diegocainzos.diegomusic.core.LocalPlaylist
import com.diegocainzos.diegomusic.core.MediaItem
import com.diegocainzos.diegomusic.core.PlaylistEntry
import com.diegocainzos.diegomusic.core.PodcastShow
import com.diegocainzos.diegomusic.core.SavedAlbum
import com.diegocainzos.diegomusic.core.SavedTrack
import com.diegocainzos.diegomusic.core.defaultPodcastShows
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.UUID

/** Port de `LibraryStore.swift`: todo síncrono sobre Room y publicado con `StateFlow`. */
class LibraryStore(private val dao: LibraryDao) {
    private val _favorites = MutableStateFlow<List<SavedTrack>>(emptyList())
    private val _playlists = MutableStateFlow<List<LocalPlaylist>>(emptyList())
    private val _history = MutableStateFlow<List<SavedTrack>>(emptyList())
    private val _savedAlbums = MutableStateFlow<List<SavedAlbum>>(emptyList())
    private val _followedShows = MutableStateFlow<List<PodcastShow>>(emptyList())
    /** Cambia con cada escritura de progreso de episodio, para que la UI se recomponga. */
    private val _progressVersion = MutableStateFlow(0)

    val favorites: StateFlow<List<SavedTrack>> = _favorites
    val playlists: StateFlow<List<LocalPlaylist>> = _playlists
    val history: StateFlow<List<SavedTrack>> = _history
    val savedAlbums: StateFlow<List<SavedAlbum>> = _savedAlbums
    val followedShows: StateFlow<List<PodcastShow>> = _followedShows
    val progressVersion: StateFlow<Int> = _progressVersion

    // Ganchos de sincronización en tiempo real con el backend.
    var onFavoriteToggled: ((MediaItem, Boolean) -> Unit)? = null
    var onTrackAddedToPlaylist: ((MediaItem, LocalPlaylist) -> Unit)? = null
    var onTrackRemovedFromPlaylist: ((PlaylistEntry, LocalPlaylist) -> Unit)? = null
    var onPlaylistCreated: ((LocalPlaylist) -> Unit)? = null
    var onPlaylistDeleted: ((LocalPlaylist) -> Unit)? = null

    init {
        reload()
    }

    private fun now() = System.currentTimeMillis()

    fun isFavorite(item: MediaItem) = _favorites.value.any { it.videoId == item.id }

    fun toggleFavorite(item: MediaItem) {
        val isFav = if (dao.favorite(item.id) != null) {
            dao.deleteFavorite(item.id)
            false
        } else {
            dao.upsertFavorite(FavoriteTrackRecord(item.id, item.title, item.channelTitle, item.artworkUrl, now()))
            true
        }
        reload()
        onFavoriteToggled?.invoke(item, isFav)
    }

    // MARK: - Álbumes guardados

    fun isAlbumSaved(id: String): Boolean {
        val key = id.trim().lowercase()
        return _savedAlbums.value.any { it.id.lowercase() == key || it.title.lowercase() == key }
    }

    fun toggleSaveAlbum(album: Album) = toggleSaveAlbum(album.id, album.title, album.channelTitle, album.thumbnailUrl, album.tracks)

    fun toggleSaveAlbum(id: String, title: String, channelTitle: String?, thumbnailUrl: String?, tracks: List<MediaItem> = emptyList()) {
        val existing = dao.savedAlbum(id)
        if (existing != null) {
            dao.deleteSavedAlbum(existing.id)
        } else {
            dao.upsertSavedAlbum(SavedAlbumRecord(id, title, channelTitle, thumbnailUrl, now()))
            tracks.filterNot { isFavorite(it) }.forEach {
                dao.upsertFavorite(FavoriteTrackRecord(it.id, it.title, it.channelTitle, it.artworkUrl, now()))
            }
        }
        reload()
    }

    fun deleteSavedAlbum(id: String) {
        dao.deleteSavedAlbum(id)
        reload()
    }

    // MARK: - Playlists

    fun createPlaylist(name: String): LocalPlaylist {
        val trimmed = name.trim()
        val record = PlaylistRecord(UUID.randomUUID().toString(), trimmed.ifEmpty { "Nueva playlist" }, now())
        dao.upsertPlaylist(record)
        reload()
        val created = _playlists.value.first { it.id == record.id }
        onPlaylistCreated?.invoke(created)
        return created
    }

    fun add(item: MediaItem, playlist: LocalPlaylist) {
        val current = dao.entries(playlist.id)
        if (current.any { it.videoId == item.id }) return
        dao.insertEntry(
            PlaylistEntryRecord(
                UUID.randomUUID().toString(), playlist.id, item.id, item.title, item.channelTitle, item.artworkUrl,
                (current.maxOfOrNull { it.position } ?: -1) + 1,
            ),
        )
        reload()
        onTrackAddedToPlaylist?.invoke(item, playlist)
    }

    fun remove(entry: PlaylistEntry, playlist: LocalPlaylist) {
        dao.deleteEntry(entry.id)
        normalizePositions(dao.entries(playlist.id))
        reload()
        onTrackRemovedFromPlaylist?.invoke(entry, playlist)
    }

    fun move(entry: PlaylistEntry, playlist: LocalPlaylist, offset: Int) {
        val records = dao.entries(playlist.id).toMutableList()
        val source = records.indexOfFirst { it.id == entry.id }
        val destination = source + offset
        if (source < 0 || destination !in records.indices) return
        java.util.Collections.swap(records, source, destination)
        normalizePositions(records)
        reload()
    }

    fun delete(playlist: LocalPlaylist) {
        dao.deletePlaylist(playlist.id)
        dao.deleteEntries(playlist.id)
        reload()
        onPlaylistDeleted?.invoke(playlist)
    }

    fun rename(playlist: LocalPlaylist, newName: String) {
        val trimmed = newName.trim()
        if (trimmed.isEmpty()) return
        dao.upsertPlaylist(PlaylistRecord(playlist.id, trimmed, playlist.createdAt))
        reload()
    }

    private fun normalizePositions(records: List<PlaylistEntryRecord>) {
        dao.upsertEntries(records.mapIndexed { index, r -> r.copy(position = index.toLong()) })
    }

    // MARK: - Agregación derivada (solo local)

    val songs: List<SavedTrack> get() = _favorites.value

    /** Artistas agrupados por `channelTitle` a partir de favoritos e historial. */
    val artists: List<LocalArtist>
        get() = (_favorites.value + _history.value).groupBy { it.channelTitle }
            .map { LocalArtist(it.key, it.value) }
            .sortedWith(compareBy(String.CASE_INSENSITIVE_ORDER) { it.name })

    // MARK: - Historial

    fun addHistory(item: MediaItem) {
        dao.insertHistory(PlaybackHistoryRecord(UUID.randomUUID().toString(), item.id, item.title, item.channelTitle, item.artworkUrl, now()))
        reload()
    }

    fun clearHistory() {
        dao.clearHistory()
        reload()
    }

    // MARK: - Sincronización y limpieza

    /**
     * Borra los datos de usuario locales. Los podcasts seguidos y su progreso solo viven en el
     * dispositivo, así que la sincronización los conserva; solo el cierre de sesión los borra.
     */
    fun clearAllUserData(keepingPodcasts: Boolean = false) {
        dao.clearFavorites()
        dao.clearPlaylists()
        dao.clearEntries()
        dao.clearHistory()
        dao.clearSavedAlbums()
        if (!keepingPodcasts) {
            dao.clearFollowedShows()
            dao.clearProgress()
        }
        reload()
    }

    fun importFavorite(videoId: String, title: String, channelTitle: String, thumbnailUrl: String?, savedAt: Long = now()) {
        val existing = dao.favorite(videoId)
        dao.upsertFavorite(FavoriteTrackRecord(videoId, title, channelTitle, thumbnailUrl, existing?.savedAt ?: savedAt))
    }

    fun importPlaylist(name: String, entries: List<MediaItem>) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        val playlist = dao.playlistNamed(trimmed)?.also { dao.deleteEntries(it.id) }
            ?: PlaylistRecord(UUID.randomUUID().toString(), trimmed, now()).also { dao.upsertPlaylist(it) }
        entries.distinctBy { it.id }.forEachIndexed { index, item ->
            dao.insertEntry(
                PlaylistEntryRecord(UUID.randomUUID().toString(), playlist.id, item.id, item.title, item.channelTitle, item.thumbnailUrl, index.toLong()),
            )
        }
    }

    fun importHistory(videoId: String, title: String, channelTitle: String, thumbnailUrl: String?, playedAt: Long) {
        dao.insertHistory(PlaybackHistoryRecord(UUID.randomUUID().toString(), videoId, title, channelTitle, thumbnailUrl, playedAt))
    }

    // MARK: - Preferencias

    fun preference(key: String): String? = dao.preference(key)

    fun setPreference(value: String, key: String) = dao.upsertPreference(PreferenceRecord(key, value))

    // MARK: - Podcasts

    fun isFollowing(channelId: String) = _followedShows.value.any { it.channelId == channelId }

    fun follow(show: PodcastShow) {
        val existing = dao.followedShow(show.channelId)
        dao.upsertFollowedShow(FollowedShowRecord(show.channelId, show.title, show.thumbnailUrl, existing?.followedAt ?: now()))
        reload()
    }

    fun unfollow(channelId: String) {
        dao.deleteFollowedShow(channelId)
        reload()
    }

    /** Sigue JRE y The Wild Project una sola vez; un «dejar de seguir» posterior se respeta. */
    fun seedDefaultShowsIfNeeded() {
        val key = "podcasts.defaults.v2"
        if (preference(key) == "true") return
        defaultPodcastShows.filterNot { isFollowing(it.channelId) }.forEach { follow(it) }
        setPreference("true", key)
    }

    fun progress(videoId: String): EpisodeProgressValue? = dao.progress(videoId)?.toValue()

    fun saveProgress(item: MediaItem, channelId: String, position: Double, duration: Double) {
        dao.upsertProgress(
            EpisodeProgressRecord(
                item.id, channelId, item.title, item.channelTitle, item.artworkUrl, position, duration,
                finished = duration - position <= 60, updatedAt = now(),
            ),
        )
        _progressVersion.value += 1
    }

    fun latestUnfinishedEpisodeProgress(): EpisodeProgressValue? = dao.latestUnfinishedProgress()?.toValue()

    private fun EpisodeProgressRecord.toValue() =
        EpisodeProgressValue(videoId, channelId, title, channelTitle, thumbnailUrl, positionSeconds, durationSeconds, finished, updatedAt)

    fun reload() {
        _favorites.value = dao.favorites().map { SavedTrack(it.videoId, it.title, it.channelTitle, it.thumbnailUrl, it.savedAt) }
        _history.value = dao.history().map { SavedTrack(it.videoId, it.title, it.channelTitle, it.thumbnailUrl, it.playedAt) }
        val entries = dao.entries().groupBy { it.playlistId }
        _playlists.value = dao.playlists().map { p ->
            LocalPlaylist(
                p.id, p.name, p.createdAt,
                entries[p.id].orEmpty().map { PlaylistEntry(it.id, it.videoId, it.title, it.channelTitle, it.thumbnailUrl, it.position.toInt()) },
            )
        }
        _savedAlbums.value = dao.savedAlbums().map { SavedAlbum(it.id, it.title, it.channelTitle, it.thumbnailUrl, it.savedAt) }
        _followedShows.value = dao.followedShows().map { PodcastShow(it.channelId, it.title, it.thumbnailUrl) }
        _progressVersion.value += 1
    }
}
