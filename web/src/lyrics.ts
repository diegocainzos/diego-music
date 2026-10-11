// Port de LRCLibProvider.swift / Lyrics.kt: limpieza de metadatos, cascada de 5 niveles y puntuación.
import type { Track } from './api.ts'

export interface LyricsLine { text: string; start: number }
export type LyricsResult =
  | { kind: 'synced'; lines: LyricsLine[] }
  | { kind: 'plain'; text: string }
  | { kind: 'instrumental' }
  | { kind: 'notFound' }

interface LrcLibResponse {
  trackName: string
  artistName: string
  duration: number
  instrumental: boolean
  plainLyrics?: string | null
  syncedLyrics?: string | null
}

export function parseLrc(lrc: string): LyricsLine[] {
  const out: LyricsLine[] = []
  for (const raw of lrc.split('\n')) {
    const m = /\[(\d{2}):(\d{2})\.(\d{2,3})\]\s?(.*)/.exec(raw.trim())
    if (!m) continue
    const fraction = m[3].length === 3 ? Number(m[3]) / 1000 : Number(m[3]) / 100
    out.push({ start: Number(m[1]) * 60 + Number(m[2]) + fraction, text: m[4] })
  }
  return out.sort((a, b) => a.start - b.start)
}

/** «Coldplay - Topic» → «Coldplay», «LadyGagaVEVO» → «Lady Gaga». */
export function cleanChannel(channel: string): string {
  let r = channel.trim().replace(/\s*-\s*Topic$/i, '').replace(/\s+Topic$/i, '').replace(/(VEVO|Official|Music|Channel)$/i, '').trim()
  if (!r.includes(' ') && r.length > 3) r = r.replace(/([a-z])([A-Z])/g, '$1 $2')
  return r.trim()
}

export function cleanTitle(title: string): string {
  return title
    .trim()
    .replace(/["'“”‘’]/g, '')
    .replace(
      /[([{][^)\]}]*(?:official|oficial|video|audio|lyric|letra|remaster|videoclip|visuali[sz]er|live|en\s*vivo|directo|4k|8k|hd|hq|1080p|60fps|prod\.?|feat\.?|ft\.?|with)[^)\]}]*[)\]}]/gi,
      '',
    )
    .replace(/\s+(?:feat|ft|with)\.?\s+.*$/i, '')
    .replace(/\s+/g, ' ')
    .trim()
}

export function extract(t: Track): [string, string] {
  const channel = cleanChannel(t.channel)
  const title = cleanTitle(t.title)
  const m = /\s+(?:[-—–|•]|\/\/)\s+/.exec(title)
  if (m) {
    const artist = cleanTitle(cleanChannel(title.slice(0, m.index)))
    const track = cleanTitle(title.slice(m.index + m[0].length))
    if (artist && track) return [artist, track]
  }
  return [channel || t.channel, title || t.title]
}

export function selectBest(results: LrcLibResponse[], artist: string | null, track: string, duration?: number | null) {
  const t = track.toLowerCase()
  const a = artist?.toLowerCase()
  let best: [LrcLibResponse, number] | null = null
  for (const c of results) {
    let score: number
    if (c.syncedLyrics) score = 100
    else if (c.plainLyrics) score = 30
    else if (c.instrumental) score = 10
    else continue
    const ct = c.trackName.toLowerCase()
    score += ct === t ? 40 : ct.includes(t) || t.includes(ct) ? 20 : 0
    if (a) {
      const ca = c.artistName.toLowerCase()
      score += ca === a ? 40 : ca.includes(a) || a.includes(ca) ? 20 : 0
    }
    if (duration && duration > 0) {
      const diff = Math.abs(c.duration - duration)
      score += diff <= 3 ? 30 : diff <= 8 ? 15 : diff > 60 ? -40 : 0
    }
    if (!best || score > best[1]) best = [c, score]
  }
  return best && best[1] >= 20 ? best[0] : null
}

async function get(path: string, params: Record<string, string>): Promise<unknown> {
  try {
    const r = await fetch(`https://lrclib.net/api/${path}?${new URLSearchParams(params)}`, { signal: AbortSignal.timeout(10_000) })
    return r.ok ? r.json() : null
  } catch {
    return null
  }
}

function process(r: LrcLibResponse): LyricsResult {
  if (r.instrumental) return { kind: 'instrumental' }
  if (r.syncedLyrics) {
    const lines = parseLrc(r.syncedLyrics)
    if (lines.length) return { kind: 'synced', lines }
  }
  if (r.plainLyrics) return { kind: 'plain', text: r.plainLyrics }
  return { kind: 'notFound' }
}

const cache = new Map<string, { at: number; result: LyricsResult }>()

export async function fetchLyrics(t: Track): Promise<LyricsResult> {
  const hit = cache.get(t.id)
  if (hit && Date.now() - hit.at < 30 * 60_000) return hit.result
  const [artist, track] = extract(t)
  const d = t.duration ?? undefined
  const search = async (params: Record<string, string>, a: string | null) => {
    const list = (await get('search', params)) as LrcLibResponse[] | null
    return list?.length ? selectBest(list, a, track, d) : null
  }
  const stages: (() => Promise<LrcLibResponse | null>)[] = [
    async () => (d ? ((await get('get', { artist_name: artist, track_name: track, duration: String(d) })) as LrcLibResponse | null) : null),
    async () => (await get('get', { artist_name: artist, track_name: track })) as LrcLibResponse | null,
    () => search({ track_name: track, artist_name: artist }, artist),
    () => search({ q: `${artist} ${track}` }, artist),
    async () => (track !== t.title ? search({ track_name: track }, null) : null),
  ]
  let result: LyricsResult = { kind: 'notFound' }
  for (const stage of stages) {
    const r = await stage()
    if (!r) continue
    const processed = process(r)
    if (processed.kind !== 'notFound') {
      result = processed
      break
    }
  }
  cache.set(t.id, { at: Date.now(), result })
  return result
}
