package com.diegocainzos.diegomusic.core

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

data class QueueState(val items: List<MediaItem>, val currentIndex: Int?, val isShuffled: Boolean) {
    val current: MediaItem? get() = currentIndex?.let { items.getOrNull(it) }

    /** Pista actual y hasta `limit` posteriores, con su índice absoluto en la cola. */
    fun upNextWindow(limit: Int = 20): List<IndexedValue<MediaItem>> {
        val index = currentIndex?.takeIf { it in items.indices } ?: return emptyList()
        return items.withIndex().drop(index).take(limit + 1)
    }
}

/** Port directo de `PlaybackQueue.swift`: la cola vive aquí y el reproductor solo carga la pista actual. */
class PlaybackQueue(items: List<MediaItem> = emptyList(), currentIndex: Int? = null) {
    private var items: List<MediaItem> = items
    private var currentIndex: Int? = when {
        currentIndex != null && currentIndex in items.indices -> currentIndex
        items.isEmpty() -> null
        else -> 0
    }
    private var isShuffled = false
    private var shuffleOrder: List<String> = emptyList()
    private var shufflePosition = 0

    private val _state = MutableStateFlow(QueueState(this.items, this.currentIndex, false))
    val state: StateFlow<QueueState> = _state

    val current: MediaItem? get() = currentIndex?.let { items.getOrNull(it) }
    val snapshot: QueueState get() = _state.value

    val canAdvance: Boolean
        get() = if (isShuffled) shufflePosition + 1 < shuffleOrder.size else currentIndex?.let { it + 1 < items.size } ?: false

    val canRetreat: Boolean
        get() = if (isShuffled) shufflePosition > 0 else currentIndex?.let { it > 0 } ?: false

    private fun publish() {
        _state.value = QueueState(items, currentIndex, isShuffled)
    }

    /** Activa/desactiva shuffle conservando la pista activa. */
    fun setShuffle(enabled: Boolean) {
        if (enabled == isShuffled) return
        isShuffled = enabled
        if (enabled) reshuffleForCurrent() else {
            shuffleOrder = emptyList()
            shufflePosition = 0
        }
        publish()
    }

    private fun reshuffleForCurrent() {
        if (items.isEmpty()) return
        val currentId = current?.id
        shuffleOrder = items.map { it.id }.shuffled()
        shufflePosition = currentId?.let { shuffleOrder.indexOf(it) }?.takeIf { it >= 0 } ?: 0
    }

    private fun rebuildAfterMutation() {
        if (isShuffled) reshuffleForCurrent()
        publish()
    }

    fun play(item: MediaItem) {
        val index = items.indexOfFirst { it.id == item.id }
        if (index >= 0) {
            currentIndex = index
        } else {
            items = items + item
            currentIndex = items.size - 1
        }
        rebuildAfterMutation()
    }

    fun selectTrack(index: Int) {
        if (index !in items.indices) return
        currentIndex = index
        rebuildAfterMutation()
    }

    fun replaceQueue(newItems: List<MediaItem>, startIndex: Int = 0) {
        items = newItems
        currentIndex = when {
            startIndex in newItems.indices -> startIndex
            newItems.isEmpty() -> null
            else -> 0
        }
        rebuildAfterMutation()
    }

    fun enqueue(item: MediaItem) {
        if (items.any { it.id == item.id }) return
        items = items + item
        if (currentIndex == null) currentIndex = 0
        rebuildAfterMutation()
    }

    /** Añade una pista justo después de la actual. */
    fun enqueueNext(item: MediaItem) {
        if (current?.id == item.id) return
        val mutable = items.toMutableList()
        val existing = mutable.indexOfFirst { it.id == item.id }
        if (existing >= 0) {
            mutable.removeAt(existing)
            currentIndex?.let { if (existing < it) currentIndex = it - 1 }
        }
        val idx = currentIndex
        if (idx != null && idx < mutable.size) {
            mutable.add(idx + 1, item)
        } else {
            mutable.add(item)
            if (currentIndex == null) currentIndex = 0
        }
        items = mutable
        rebuildAfterMutation()
    }

    fun enqueueBatch(newItems: List<MediaItem>) {
        val existing = items.map { it.id }.toSet()
        val filtered = newItems.filter { it.id !in existing }
        if (filtered.isEmpty()) return
        items = items + filtered
        if (currentIndex == null) currentIndex = 0
        rebuildAfterMutation()
    }

    /** Sustituye todo lo posterior a la pista activa, sin tocar la actual. */
    fun replaceUpcoming(newUpcoming: List<MediaItem>) {
        val idx = currentIndex ?: return
        if (idx !in items.indices) return
        items = items.take(idx + 1) + newUpcoming
        rebuildAfterMutation()
    }

    fun advance(): MediaItem? {
        if (isShuffled) {
            if (shufflePosition + 1 >= shuffleOrder.size) return null
            shufflePosition += 1
            items.indexOfFirst { it.id == shuffleOrder[shufflePosition] }.takeIf { it >= 0 }?.let { currentIndex = it }
            publish()
            return current
        }
        val idx = currentIndex ?: return null
        if (!canAdvance) return null
        currentIndex = idx + 1
        publish()
        return current
    }

    fun retreat(): MediaItem? {
        if (isShuffled) {
            if (shufflePosition <= 0) return null
            shufflePosition -= 1
            items.indexOfFirst { it.id == shuffleOrder[shufflePosition] }.takeIf { it >= 0 }?.let { currentIndex = it }
            publish()
            return current
        }
        val idx = currentIndex ?: return null
        if (!canRetreat) return null
        currentIndex = idx - 1
        publish()
        return current
    }

    /** Vuelve al principio (repetir todo). */
    fun resetToStart(): MediaItem? {
        if (items.isEmpty()) return null
        currentIndex = 0
        if (isShuffled) {
            shufflePosition = shuffleOrder.indexOf(items.first().id).takeIf { it >= 0 } ?: 0
            items.indexOfFirst { it.id == shuffleOrder[shufflePosition] }.takeIf { it >= 0 }?.let { currentIndex = it }
        }
        publish()
        return current
    }

    fun remove(id: String) {
        val removedIndex = items.indexOfFirst { it.id == id }
        if (removedIndex < 0) return
        val currentId = current?.id
        items = items.toMutableList().also { it.removeAt(removedIndex) }
        if (items.isEmpty()) {
            currentIndex = null
            shuffleOrder = emptyList()
            shufflePosition = 0
            publish()
            return
        }
        val relocated = currentId?.let { cid -> items.indexOfFirst { it.id == cid } } ?: -1
        currentIndex = if (relocated >= 0) relocated else minOf(removedIndex, items.size - 1)
        rebuildAfterMutation()
    }

    fun move(id: String, offset: Int) {
        val source = items.indexOfFirst { it.id == id }
        if (source < 0) return
        val destination = source + offset
        if (destination !in items.indices) return
        val currentId = current?.id
        items = items.toMutableList().also { java.util.Collections.swap(it, source, destination) }
        currentId?.let { cid -> currentIndex = items.indexOfFirst { it.id == cid } }
        rebuildAfterMutation()
    }

    fun clear() {
        items = emptyList()
        currentIndex = null
        shuffleOrder = emptyList()
        shufflePosition = 0
        isShuffled = false
        publish()
    }
}
