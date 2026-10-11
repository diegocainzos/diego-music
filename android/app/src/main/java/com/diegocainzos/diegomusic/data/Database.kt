package com.diegocainzos.diegomusic.data

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Upsert

// Mismas entidades y claves únicas que el modelo Core Data de `PersistenceController.swift`.

@Entity(tableName = "favorite_track")
data class FavoriteTrackRecord(
    @PrimaryKey val videoId: String,
    val title: String,
    val channelTitle: String,
    val thumbnailUrl: String?,
    val savedAt: Long,
)

@Entity(tableName = "playlist")
data class PlaylistRecord(@PrimaryKey val id: String, val name: String, val createdAt: Long)

@Entity(tableName = "playlist_entry", indices = [Index(value = ["playlistId", "videoId"], unique = true)])
data class PlaylistEntryRecord(
    @PrimaryKey val id: String,
    val playlistId: String,
    val videoId: String,
    val title: String,
    val channelTitle: String,
    val thumbnailUrl: String?,
    val position: Long,
)

@Entity(tableName = "playback_history")
data class PlaybackHistoryRecord(
    @PrimaryKey val id: String,
    val videoId: String,
    val title: String,
    val channelTitle: String,
    val thumbnailUrl: String?,
    val playedAt: Long,
)

@Entity(tableName = "preference")
data class PreferenceRecord(@PrimaryKey val key: String, val value: String)

@Entity(tableName = "saved_album")
data class SavedAlbumRecord(
    @PrimaryKey val id: String,
    val title: String,
    val channelTitle: String?,
    val thumbnailUrl: String?,
    val savedAt: Long,
)

@Entity(tableName = "downloaded_track")
data class DownloadedTrackRecord(
    @PrimaryKey val videoId: String,
    val title: String,
    val channelTitle: String,
    val thumbnailUrl: String?,
    val localFilePath: String,
    val fileSizeBytes: Long,
    val downloadedAt: Long,
    val contentType: String,
)

@Entity(tableName = "followed_show")
data class FollowedShowRecord(
    @PrimaryKey val channelId: String,
    val title: String,
    val thumbnailUrl: String?,
    val followedAt: Long,
)

@Entity(tableName = "episode_progress")
data class EpisodeProgressRecord(
    @PrimaryKey val videoId: String,
    val channelId: String,
    val title: String,
    val channelTitle: String,
    val thumbnailUrl: String?,
    val positionSeconds: Double,
    val durationSeconds: Double,
    val finished: Boolean,
    val updatedAt: Long,
)

@Dao
interface LibraryDao {
    @Query("SELECT * FROM favorite_track ORDER BY savedAt DESC") fun favorites(): List<FavoriteTrackRecord>
    @Query("SELECT * FROM favorite_track WHERE videoId = :videoId") fun favorite(videoId: String): FavoriteTrackRecord?
    @Upsert fun upsertFavorite(record: FavoriteTrackRecord)
    @Query("DELETE FROM favorite_track WHERE videoId = :videoId") fun deleteFavorite(videoId: String)

    @Query("SELECT * FROM playlist ORDER BY createdAt DESC") fun playlists(): List<PlaylistRecord>
    @Query("SELECT * FROM playlist WHERE name = :name COLLATE NOCASE LIMIT 1") fun playlistNamed(name: String): PlaylistRecord?
    @Upsert fun upsertPlaylist(record: PlaylistRecord)
    @Query("DELETE FROM playlist WHERE id = :id") fun deletePlaylist(id: String)

    @Query("SELECT * FROM playlist_entry ORDER BY position ASC") fun entries(): List<PlaylistEntryRecord>
    @Query("SELECT * FROM playlist_entry WHERE playlistId = :playlistId ORDER BY position ASC") fun entries(playlistId: String): List<PlaylistEntryRecord>
    @Insert(onConflict = OnConflictStrategy.IGNORE) fun insertEntry(record: PlaylistEntryRecord)
    @Upsert fun upsertEntries(records: List<PlaylistEntryRecord>)
    @Query("DELETE FROM playlist_entry WHERE id = :id") fun deleteEntry(id: String)
    @Query("DELETE FROM playlist_entry WHERE playlistId = :playlistId") fun deleteEntries(playlistId: String)

    @Query("SELECT * FROM playback_history ORDER BY playedAt DESC") fun history(): List<PlaybackHistoryRecord>
    @Insert fun insertHistory(record: PlaybackHistoryRecord)
    @Query("DELETE FROM playback_history") fun clearHistory()

    @Query("SELECT value FROM preference WHERE `key` = :key") fun preference(key: String): String?
    @Upsert fun upsertPreference(record: PreferenceRecord)

    @Query("SELECT * FROM saved_album ORDER BY savedAt DESC") fun savedAlbums(): List<SavedAlbumRecord>
    @Query("SELECT * FROM saved_album WHERE id = :id OR title = :id COLLATE NOCASE LIMIT 1") fun savedAlbum(id: String): SavedAlbumRecord?
    @Upsert fun upsertSavedAlbum(record: SavedAlbumRecord)
    @Query("DELETE FROM saved_album WHERE id = :id") fun deleteSavedAlbum(id: String)

    @Query("SELECT * FROM downloaded_track ORDER BY downloadedAt DESC") fun downloads(): List<DownloadedTrackRecord>
    @Query("SELECT * FROM downloaded_track WHERE videoId = :videoId") fun download(videoId: String): DownloadedTrackRecord?
    @Upsert fun upsertDownload(record: DownloadedTrackRecord)
    @Query("DELETE FROM downloaded_track WHERE videoId = :videoId") fun deleteDownload(videoId: String)

    @Query("SELECT * FROM followed_show ORDER BY followedAt DESC") fun followedShows(): List<FollowedShowRecord>
    @Query("SELECT * FROM followed_show WHERE channelId = :channelId") fun followedShow(channelId: String): FollowedShowRecord?
    @Upsert fun upsertFollowedShow(record: FollowedShowRecord)
    @Query("DELETE FROM followed_show WHERE channelId = :channelId") fun deleteFollowedShow(channelId: String)

    @Query("SELECT * FROM episode_progress WHERE videoId = :videoId") fun progress(videoId: String): EpisodeProgressRecord?
    @Upsert fun upsertProgress(record: EpisodeProgressRecord)
    @Query("SELECT * FROM episode_progress WHERE finished = 0 AND positionSeconds > 0 ORDER BY updatedAt DESC LIMIT 1")
    fun latestUnfinishedProgress(): EpisodeProgressRecord?

    @Query("DELETE FROM favorite_track") fun clearFavorites()
    @Query("DELETE FROM playlist") fun clearPlaylists()
    @Query("DELETE FROM playlist_entry") fun clearEntries()
    @Query("DELETE FROM saved_album") fun clearSavedAlbums()
    @Query("DELETE FROM followed_show") fun clearFollowedShows()
    @Query("DELETE FROM episode_progress") fun clearProgress()
}

@Database(
    entities = [
        FavoriteTrackRecord::class, PlaylistRecord::class, PlaylistEntryRecord::class, PlaybackHistoryRecord::class,
        PreferenceRecord::class, SavedAlbumRecord::class, DownloadedTrackRecord::class, FollowedShowRecord::class,
        EpisodeProgressRecord::class,
    ],
    version = 1,
    exportSchema = false,
)
abstract class DiegoMusicDatabase : RoomDatabase() {
    abstract fun dao(): LibraryDao

    companion object {
        // ponytail: consultas en el hilo principal, como el viewContext de Core Data en Swift; base pequeña.
        // Si alguna vez pesa, mover LibraryStore a Dispatchers.IO.
        fun create(context: Context): DiegoMusicDatabase =
            Room.databaseBuilder(context, DiegoMusicDatabase::class.java, "diegomusic.db")
                .allowMainThreadQueries()
                .build()
    }
}
