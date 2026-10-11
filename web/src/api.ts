// Cliente del backend y del resolutor. Todo va con el JWT del usuario: el navegador no lleva claves.

export interface Track {
  id: string
  title: string
  channel: string
  thumb?: string | null
  duration?: number | null
}

export interface User {
  id: number
  email: string
  full_name?: string | null
}

export interface Playlist {
  id: number
  name: string
  tracks: Track[]
}

export interface ArtistDetail {
  artist: { id: string; title: string; bio?: string | null; thumbnailURL?: string | null }
  topTracks: Track[]
  related: Track[]
}

const TOKEN_KEY = 'diegomusic.token'

export const token = {
  get: () => localStorage.getItem(TOKEN_KEY),
  set: (value: string) => localStorage.setItem(TOKEN_KEY, value),
  clear: () => localStorage.removeItem(TOKEN_KEY),
}

export class ApiError extends Error {
  status: number
  constructor(status: number, message: string) {
    super(message)
    this.status = status
  }
}

/** Igual que Swift: un vídeo sin carátula usa la miniatura pública de YouTube. */
export const artwork = (t: Track) => t.thumb || `https://i.ytimg.com/vi/${t.id}/hqdefault.jpg`

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers)
  const jwt = token.get()
  if (jwt) headers.set('Authorization', `Bearer ${jwt}`)
  if (init.body && typeof init.body === 'string') headers.set('Content-Type', 'application/json')
  let response: Response
  try {
    response = await fetch(path, { ...init, headers })
  } catch {
    throw new ApiError(0, 'No se pudo conectar con el servidor.')
  }
  if (!response.ok) {
    let detail: string | undefined
    try {
      const body = await response.json()
      if (typeof body.detail === 'string') detail = body.detail
    } catch {
      /* cuerpo vacío */
    }
    throw new ApiError(response.status, detail ?? `Error en el servidor (${response.status}).`)
  }
  return response.status === 204 ? (undefined as T) : response.json()
}

// MARK: - Autenticación

export async function login(email: string, password: string) {
  const body = new URLSearchParams({ username: email, password })
  try {
    const r = await request<{ access_token: string }>('/api/v1/auth/login', { method: 'POST', body })
    token.set(r.access_token)
  } catch (e) {
    if (e instanceof ApiError && e.status === 401) throw new ApiError(401, 'Correo electrónico o contraseña incorrectos.')
    throw e
  }
}

export async function register(email: string, password: string, fullName?: string) {
  try {
    const r = await request<{ access_token: string }>('/api/v1/auth/register', {
      method: 'POST',
      body: JSON.stringify({ email, password, full_name: fullName || undefined }),
    })
    token.set(r.access_token)
  } catch (e) {
    if (e instanceof ApiError && e.status === 400 && e.message.includes('registrado')) {
      throw new ApiError(400, 'El correo electrónico ya está registrado.')
    }
    throw e
  }
}

export const me = () => request<User>('/api/v1/auth/me')

// MARK: - Biblioteca (backend)

interface BackendTrack {
  id: number
  title: string
  duration_seconds?: number
  youtube_video_id?: string | null
  artist?: { name: string } | null
  album?: { cover_url?: string | null } | null
}

const fromBackend = (t: BackendTrack): Track => ({
  id: t.youtube_video_id ?? String(t.id),
  title: t.title,
  channel: t.artist?.name ?? '',
  thumb: t.album?.cover_url,
  duration: t.duration_seconds || null,
})

const payload = (t: Track) => ({
  youtube_video_id: t.id,
  title: t.title,
  channel_title: t.channel,
  thumbnail_url: artwork(t),
  duration_seconds: t.duration ?? undefined,
})

export async function favorites(): Promise<Track[]> {
  const list = await request<{ track?: BackendTrack }[]>('/api/v1/users/me/favorites?entity_type=track')
  return list.flatMap((f) => (f.track ? [fromBackend(f.track)] : []))
}

export const addFavorite = (t: Track) =>
  request('/api/v1/users/me/favorites', { method: 'POST', body: JSON.stringify({ entity_type: 'track', ...payload(t) }) })

export const removeFavorite = (id: string) => request(`/api/v1/users/me/favorites/track/${encodeURIComponent(id)}`, { method: 'DELETE' })

export async function history(): Promise<Track[]> {
  const list = await request<{ track?: BackendTrack }[]>('/api/v1/users/me/history?limit=50&offset=0')
  return list.flatMap((h) => (h.track ? [fromBackend(h.track)] : []))
}

export const recordPlay = (t: Track) =>
  request('/api/v1/users/me/history', {
    method: 'POST',
    body: JSON.stringify({ ...payload(t), played_seconds: 0, completed: true, skipped: false }),
  })

interface BackendPlaylist {
  id: number
  name: string
  tracks: { track?: BackendTrack; order: number }[]
}

const toPlaylist = (p: BackendPlaylist): Playlist => ({
  id: p.id,
  name: p.name,
  tracks: [...p.tracks].sort((a, b) => a.order - b.order).flatMap((pt) => (pt.track ? [fromBackend(pt.track)] : [])),
})

export async function playlists(): Promise<Playlist[]> {
  const list = await request<BackendPlaylist[]>('/api/v1/playlists/me')
  return Promise.all(list.map(async (p) => toPlaylist(await request<BackendPlaylist>(`/api/v1/playlists/${p.id}`).catch(() => p))))
}

export const createPlaylist = (name: string) =>
  request<BackendPlaylist>('/api/v1/playlists/', { method: 'POST', body: JSON.stringify({ name, is_public: false }) }).then(toPlaylist)

export const deletePlaylist = (id: number) => request(`/api/v1/playlists/${id}`, { method: 'DELETE' })

export const addToPlaylist = (id: number, t: Track) =>
  request<BackendPlaylist>(`/api/v1/playlists/${id}/tracks`, { method: 'POST', body: JSON.stringify(payload(t)) }).then(toPlaylist)

export const removeFromPlaylist = (id: number, videoId: string) =>
  request(`/api/v1/playlists/${id}/tracks/${encodeURIComponent(videoId)}`, { method: 'DELETE' })

// MARK: - Resolutor (/v1)

interface VpsTrack {
  id: string
  title: string
  channelTitle: string
  thumbnailURL?: string | null
}

const fromVps = (t: VpsTrack): Track => ({ id: t.id, title: t.title, channel: t.channelTitle, thumb: t.thumbnailURL })

const searchCache = new Map<string, { at: number; items: Track[] }>()

/** «Coldplay - Yellow  » → «coldplay - yellow» (misma normalización que la caché de Swift y Android). */
export const normalizeQuery = (q: string) =>
  q.normalize('NFD').replace(/\p{Mn}+/gu, '').toLowerCase().trim().replace(/\s+/g, ' ')

export async function search(q: string): Promise<Track[]> {
  const key = normalizeQuery(q)
  const cached = searchCache.get(key)
  if (cached && Date.now() - cached.at < 24 * 3600_000) return cached.items
  const r = await request<{ items: VpsTrack[] }>(`/v1/search?q=${encodeURIComponent(q.trim())}`)
  const items = r.items.map(fromVps)
  searchCache.set(key, { at: Date.now(), items })
  return items
}

export async function artist(id: string): Promise<ArtistDetail> {
  const r = await request<{ artist: ArtistDetail['artist']; topTracks: VpsTrack[]; related: VpsTrack[] }>(`/v1/artist/${encodeURIComponent(id)}`)
  return { artist: r.artist, topTracks: r.topTracks.map(fromVps), related: r.related.map(fromVps) }
}

export async function radio(seed: string): Promise<Track[]> {
  const r = await request<{ items: { id: string; title: string; channel: string; duration_seconds?: number | null }[] }>(`/v1/radio/${seed}`)
  return r.items.map((i) => ({ id: i.id, title: i.title, channel: i.channel, duration: i.duration_seconds }))
}

let recommendationsKey = ''
let recommendationsItems: Track[] = []

export async function recommendations(seeds: Track[]): Promise<Track[]> {
  const tracks = seeds.slice(0, 20)
  if (!tracks.length) return []
  const key = tracks.map((t) => t.id).join(',')
  if (key === recommendationsKey && recommendationsItems.length) return recommendationsItems
  const r = await request<{ items: VpsTrack[] }>('/v1/recommendations', {
    method: 'POST',
    body: JSON.stringify({ tracks: tracks.map((t) => ({ title: t.title.slice(0, 200), channel: t.channel.slice(0, 200) })) }),
  })
  const ids = new Set(tracks.map((t) => t.id))
  recommendationsKey = key
  recommendationsItems = r.items.map(fromVps).filter((t) => !ids.has(t.id))
  return recommendationsItems
}

export const isValidVideoId = (id: string) => /^[A-Za-z0-9_-]{11}$/.test(id)

const descriptors = new Map<string, { url: string; expires: number }>()
const inFlight = new Map<string, Promise<string>>()

/** Sesión opaca del resolutor, cacheada hasta 90 s antes de caducar y con una sola petición por vídeo. */
export async function resolve(videoId: string): Promise<string> {
  if (!isValidVideoId(videoId)) throw new ApiError(0, 'La canción no contiene un identificador de YouTube válido.')
  const cached = descriptors.get(videoId)
  if (cached && cached.expires - Date.now() > 90_000) return cached.url
  const pending = inFlight.get(videoId)
  if (pending) return pending
  const task = request<{ streamURL: string; expiresAt: string; contentType: string }>('/v1/audio/resolve', {
    method: 'POST',
    body: JSON.stringify({ videoId }),
  })
    .then((r) => {
      if (!r.streamURL.startsWith('https://') && !r.streamURL.startsWith('/')) throw new ApiError(0, 'El servicio privado devolvió una respuesta no válida.')
      descriptors.set(videoId, { url: r.streamURL, expires: Date.parse(r.expiresAt) })
      return r.streamURL
    })
    .catch((e) => {
      if (e instanceof ApiError && e.status === 401) throw new ApiError(401, 'Sesión no válida o expirada.')
      if (e instanceof ApiError && e.status === 422) throw e
      throw new ApiError(0, 'El servicio privado de audio no está disponible.')
    })
    .finally(() => inFlight.delete(videoId))
  inFlight.set(videoId, task)
  return task
}

export const invalidate = (videoId: string) => descriptors.delete(videoId)
