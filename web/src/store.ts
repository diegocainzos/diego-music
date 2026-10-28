import { useSyncExternalStore } from 'react'
import * as api from './api.ts'
import type { Playlist, Track, User } from './api.ts'

export { upNextWindow } from './queue.ts'

// MARK: - Store mínimo (sin dependencias)

function createStore<T extends object>(initial: T) {
  let state = initial
  const listeners = new Set<() => void>()
  return {
    get: () => state,
    set(patch: Partial<T> | ((s: T) => Partial<T>)) {
      state = { ...state, ...(typeof patch === 'function' ? patch(state) : patch) }
      listeners.forEach((l) => l())
    },
    subscribe(listener: () => void) {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },
  }
}

type Store<T extends object> = ReturnType<typeof createStore<T>>

/** El selector debe devolver valores ya existentes en el estado (no objetos nuevos). */
export function useStore<T extends object, S>(store: Store<T>, select: (s: T) => S): S {
  return useSyncExternalStore(store.subscribe, () => select(store.get()))
}

// MARK: - Tema (`AppThemeMode`: negro por defecto, `light` antiguo → blanco)

export type Theme = 'black' | 'white'
export const migrateTheme = (raw: string | null): Theme => (raw === 'white' || raw === 'light' ? 'white' : 'black')

export const ui = createStore({
  theme: migrateTheme(localStorage.getItem('diegomusic.theme')),
  toast: null as string | null,
  online: navigator.onLine,
})

export function setTheme(theme: Theme) {
  localStorage.setItem('diegomusic.theme', theme)
  ui.set({ theme })
}

let toastTimer: number | undefined
export function toast(message: string) {
  ui.set({ toast: message })
  clearTimeout(toastTimer)
  toastTimer = window.setTimeout(() => ui.set({ toast: null }), 2200)
}

window.addEventListener('online', () => ui.set({ online: true }))
window.addEventListener('offline', () => ui.set({ online: false }))

// MARK: - Navegación (pila de atrás, igual que NavigationState)

export type Destination =
  | { kind: 'home' }
  | { kind: 'search' }
  | { kind: 'library' }
  | { kind: 'artist'; id: string; name: string }
  | { kind: 'settings' }

export const tabs: { kind: 'home' | 'search' | 'library'; title: string }[] = [
  { kind: 'home', title: 'Inicio' },
  { kind: 'search', title: 'Buscar' },
  { kind: 'library', title: 'Biblioteca' },
]

export const nav = createStore({ current: { kind: 'home' } as Destination, stack: [] as Destination[], resetKey: 0 })

export function navigate(to: Destination) {
  const { current, stack } = nav.get()
  if (JSON.stringify(to) === JSON.stringify(current)) return
  nav.set({ current: to, stack: [...stack, current] })
}

export function goBack() {
  const { stack } = nav.get()
  if (!stack.length) return
  nav.set({ current: stack[stack.length - 1], stack: stack.slice(0, -1) })
}

export function selectTab(kind: 'home' | 'search' | 'library') {
  const { current, resetKey } = nav.get()
  if (current.kind === kind) nav.set({ stack: [], resetKey: resetKey + 1 })
  else navigate({ kind })
}

// MARK: - Sesión y biblioteca (vive en el backend)

export const session = createStore({
  status: (api.token.get() ? 'loading' : 'unauthenticated') as 'loading' | 'unauthenticated' | 'authenticated',
  user: null as User | null,
  favorites: [] as Track[],
  history: [] as Track[],
  playlists: [] as Playlist[],
})

export async function bootstrap() {
  if (!api.token.get()) return session.set({ status: 'unauthenticated' })
  try {
    const user = await api.me()
    session.set({ status: 'authenticated', user })
    await refreshLibrary()
  } catch {
    logout()
  }
}

export async function refreshLibrary() {
  const [favorites, history, playlists] = await Promise.all([
    api.favorites().catch(() => session.get().favorites),
    api.history().catch(() => session.get().history),
    api.playlists().catch(() => session.get().playlists),
  ])
  session.set({ favorites, history, playlists })
}

export async function login(email: string, password: string) {
  await api.login(email, password)
  await bootstrap()
}

export async function register(email: string, password: string, name?: string) {
  await api.register(email, password, name)
  await bootstrap()
}

export function logout() {
  api.token.clear()
  player.clear()
  session.set({ status: 'unauthenticated', user: null, favorites: [], history: [], playlists: [] })
}

export const isFavorite = (id: string) => session.get().favorites.some((f) => f.id === id)

export async function toggleFavorite(t: Track) {
  const was = isFavorite(t.id)
  session.set((s) => ({ favorites: was ? s.favorites.filter((f) => f.id !== t.id) : [t, ...s.favorites] }))
  try {
    if (was) await api.removeFavorite(t.id)
    else await api.addFavorite(t)
  } catch {
    session.set((s) => ({ favorites: was ? [t, ...s.favorites] : s.favorites.filter((f) => f.id !== t.id) }))
    toast('No se pudo actualizar favoritos')
  }
}

export async function addToPlaylist(p: Playlist, t: Track) {
  if (p.tracks.some((x) => x.id === t.id)) return toast('Ya está en la playlist')
  try {
    const updated = await api.addToPlaylist(p.id, t)
    session.set((s) => ({ playlists: s.playlists.map((x) => (x.id === p.id ? updated : x)) }))
    toast(`Añadida a ${p.name}`)
  } catch {
    toast('No se pudo añadir a la playlist')
  }
}

// MARK: - Reproductor (port de AudioPlayerCoordinator: un único <audio>, una pista cargada)

export type Status = 'idle' | 'resolving' | 'buffering' | 'playing' | 'paused' | 'ended' | 'failed'
export type Repeat = 'off' | 'all' | 'one'

export const playback = createStore({
  items: [] as Track[],
  index: null as number | null,
  status: 'idle' as Status,
  time: 0,
  duration: 0,
  error: null as string | null,
  shuffle: false,
  repeat: 'off' as Repeat,
  radioSeed: null as string | null,
})

export const currentTrack = (s = playback.get()) => (s.index == null ? null : s.items[s.index] ?? null)

const audio = new Audio()
audio.preload = 'auto'
let generation = 0
let radioGeneration = 0
let retryAvailable = true
let shuffleOrder: string[] = []
let shufflePos = 0
let savedUpcoming: Track[] = []

const shuffled = <T,>(list: T[]) => {
  const a = [...list]
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

function reshuffle() {
  const s = playback.get()
  if (!s.shuffle) return
  const current = currentTrack(s)?.id
  shuffleOrder = shuffled(s.items.map((t) => t.id))
  shufflePos = Math.max(0, current ? shuffleOrder.indexOf(current) : 0)
}

function canAdvance(s = playback.get()) {
  return s.shuffle ? shufflePos + 1 < shuffleOrder.length : s.index != null && s.index + 1 < s.items.length
}

function canRetreat(s = playback.get()) {
  return s.shuffle ? shufflePos > 0 : s.index != null && s.index > 0
}

async function load(track: Track, autoplay: boolean, resetRetry: boolean) {
  if (resetRetry) retryAvailable = true
  const gen = ++generation
  audio.pause()
  audio.removeAttribute('src')
  playback.set({ status: 'resolving', error: null, time: 0, duration: track.duration ?? 0 })
  updateMediaSession(track)
  try {
    const url = await api.resolve(track.id)
    if (gen !== generation) return
    audio.src = url
    playback.set({ status: autoplay ? 'buffering' : 'paused' })
    if (autoplay) await audio.play().catch(() => playback.set({ status: 'paused' }))
    prefetchNext()
  } catch (e) {
    if (gen !== generation) return
    playback.set({ status: 'failed', error: e instanceof api.ApiError ? e.message : 'No se pudo preparar esta canción.' })
  }
}

function prefetchNext() {
  const s = playback.get()
  const next = s.index != null ? s.items[s.index + 1] : undefined
  if (next) window.setTimeout(() => api.resolve(next.id).catch(() => undefined), 150)
}

audio.addEventListener('timeupdate', () => playback.set({ time: audio.currentTime }))
audio.addEventListener('durationchange', () => Number.isFinite(audio.duration) && playback.set({ duration: audio.duration }))
audio.addEventListener('playing', () => playback.set({ status: 'playing', error: null }))
audio.addEventListener('waiting', () => playback.get().status !== 'resolving' && playback.set({ status: 'buffering' }))
audio.addEventListener('pause', () => {
  const st = playback.get().status
  if (st === 'playing' || st === 'buffering') playback.set({ status: 'paused' })
})
audio.addEventListener('ended', () => {
  playback.set({ status: 'ended', time: playback.get().duration })
  const { repeat } = playback.get()
  const cur = currentTrack()
  if (repeat === 'one' && cur) load(cur, true, true)
  else if (repeat === 'all' && !canAdvance()) {
    playback.set({ index: 0 })
    reshuffle()
    const first = currentTrack()
    if (first) load(first, true, true)
  } else player.next()
})
audio.addEventListener('error', () => {
  const cur = currentTrack()
  if (!cur || !audio.getAttribute('src')) return
  if (!retryAvailable) return playback.set({ status: 'failed', error: 'El navegador no pudo abrir la pista entregada por el VPS.' })
  // Un único reintento: invalida la sesión opaca y vuelve a resolver.
  retryAvailable = false
  api.invalidate(cur.id)
  load(cur, true, false)
})

function updateMediaSession(t: Track) {
  if (!('mediaSession' in navigator)) return
  navigator.mediaSession.metadata = new MediaMetadata({
    title: t.title,
    artist: t.channel,
    artwork: [{ src: api.artwork(t), sizes: '480x360', type: 'image/jpeg' }],
  })
}

if ('mediaSession' in navigator) {
  navigator.mediaSession.setActionHandler('play', () => player.toggle())
  navigator.mediaSession.setActionHandler('pause', () => player.toggle())
  navigator.mediaSession.setActionHandler('nexttrack', () => player.next())
  navigator.mediaSession.setActionHandler('previoustrack', () => player.previous())
  navigator.mediaSession.setActionHandler('seekto', (d) => d.seekTime != null && player.seek(d.seekTime))
}

export const player = {
  canAdvance,
  canRetreat,

  /** Reproduce una pista: si ya está en la cola salta a ella; si no, la añade al final. */
  play(t: Track) {
    radioGeneration++
    savedUpcoming = []
    const s = playback.get()
    const existing = s.items.findIndex((x) => x.id === t.id)
    if (existing >= 0) playback.set({ index: existing, radioSeed: null })
    else playback.set({ items: [...s.items, t], index: s.items.length, radioSeed: null })
    reshuffle()
    load(t, true, true)
    recordPlay(t)
    player.startRadio(true)
  },

  /** Sustituye la cola y empieza en `index`. */
  playQueue(items: Track[], index = 0) {
    if (!items.length) return
    radioGeneration++
    savedUpcoming = []
    playback.set({ items, index: Math.min(Math.max(index, 0), items.length - 1), radioSeed: null })
    reshuffle()
    const cur = currentTrack()
    if (cur) {
      load(cur, true, true)
      recordPlay(cur)
    }
  },

  selectFromQueue(index: number) {
    radioGeneration++
    playback.set({ index })
    reshuffle()
    const cur = currentTrack()
    if (cur) load(cur, true, true)
  },

  toggle() {
    const s = playback.get()
    if (s.status === 'playing') return audio.pause()
    const cur = currentTrack(s)
    if (!cur) return
    if (s.status === 'failed' || !audio.getAttribute('src')) return load(cur, true, true)
    audio.play().catch(() => undefined)
  },

  next() {
    const s = playback.get()
    if (!canAdvance(s)) return
    if (s.shuffle) {
      shufflePos++
      playback.set({ index: s.items.findIndex((t) => t.id === shuffleOrder[shufflePos]) })
    } else playback.set({ index: (s.index ?? 0) + 1 })
    const cur = currentTrack()
    if (cur) load(cur, true, true)
  },

  previous() {
    const s = playback.get()
    if (!canRetreat(s)) return player.seek(0)
    if (s.shuffle) {
      shufflePos--
      playback.set({ index: s.items.findIndex((t) => t.id === shuffleOrder[shufflePos]) })
    } else playback.set({ index: (s.index ?? 0) - 1 })
    const cur = currentTrack()
    if (cur) load(cur, true, true)
  },

  seek(seconds: number) {
    const d = playback.get().duration
    const bounded = d > 0 ? Math.min(Math.max(seconds, 0), d) : Math.max(seconds, 0)
    audio.currentTime = bounded
    playback.set({ time: bounded })
  },

  toggleShuffle() {
    playback.set((s) => ({ shuffle: !s.shuffle }))
    reshuffle()
  },

  cycleRepeat() {
    playback.set((s) => ({ repeat: s.repeat === 'off' ? 'all' : s.repeat === 'all' ? 'one' : 'off' }))
  },

  enqueueNext(t: Track) {
    const s = playback.get()
    if (currentTrack(s)?.id === t.id) return
    const items = s.items.filter((x) => x.id !== t.id)
    const curId = currentTrack(s)?.id
    let index = curId ? items.findIndex((x) => x.id === curId) : -1
    if (index < 0) {
      items.push(t)
      index = s.index ?? 0
    } else items.splice(index + 1, 0, t)
    playback.set({ items, index })
    reshuffle()
    toast('Añadida a continuación')
  },

  /** Radio: sustituye solo lo posterior a la pista actual. */
  async startRadio(silent = false) {
    const s = playback.get()
    const cur = currentTrack(s)
    if (!cur || s.index == null) return
    const gen = ++radioGeneration
    const seedId = cur.id
    const seedTitle = cur.title
    const upcoming = s.items.slice(s.index + 1)
    try {
      const items = await api.radio(seedId)
      if (gen !== radioGeneration) return
      const now = playback.get()
      if (currentTrack(now)?.id !== seedId || now.index == null) return
      if (!items.length) {
        if (!silent) toast('Radio no disponible para esta pista.')
        return
      }
      savedUpcoming = upcoming
      playback.set({ items: [...now.items.slice(0, now.index + 1), ...items], radioSeed: seedTitle })
      reshuffle()
    } catch {
      if (gen !== radioGeneration) return
      const now = playback.get()
      if (currentTrack(now)?.id !== seedId || now.index == null) return
      if (!silent) toast('Radio no disponible para esta pista.')
    }
  },

  stopRadio() {
    radioGeneration++
    const s = playback.get()
    if (s.index == null) return
    playback.set({ items: [...s.items.slice(0, s.index + 1), ...savedUpcoming], radioSeed: null })
    savedUpcoming = []
    reshuffle()
  },

  clear() {
    radioGeneration++
    generation++
    audio.pause()
    audio.removeAttribute('src')
    playback.set({ items: [], index: null, status: 'idle', time: 0, duration: 0, error: null, radioSeed: null })
  },
}

function recordPlay(t: Track) {
  session.set((s) => ({ history: [t, ...s.history.filter((h) => h.id !== t.id)].slice(0, 50) }))
  api.recordPlay(t).catch(() => undefined)
}
