import type { Track } from './api.ts'

export const DISCOVERY_CHIPS = {
  genre: ['Pop', 'Rock', 'Hip hop', 'Reggaetón', 'Reggae', 'Electrónica', 'House', 'Techno', 'Drum and bass', 'Dubstep', 'Trance', 'Indie', 'R&B', 'Jazz', 'Flamenco', 'Clásica'],
  vibe: ['Chill', 'Fiesta', 'Triste', 'Energía', 'Romántica', 'Concentración'],
  decade: ['70s', '80s', '90s', '2000s', '2010s', '2020s'],
  country: ['España', 'Galicia', 'México', 'Argentina', 'Colombia', 'USA', 'UK', 'Brasil', 'Corea', 'Japón', 'Francia'],
}

export function distinctRecent(history: Track[], limit = 10): Track[] {
  const seen = new Set<string>()
  const out: Track[] = []
  for (const t of history) {
    if (out.length >= limit) break
    if (!seen.has(t.id)) {
      seen.add(t.id)
      out.push(t)
    }
  }
  return out
}

export function quickPickSeeds(history: Track[], random: () => number): string[] {
  const d = distinctRecent(history, 10)
  if (!d.length) return []
  const rest = d.slice(1).map((t) => t.id)
  const picked: string[] = []
  while (picked.length < 2 && rest.length) picked.push(rest.splice(Math.min(Math.floor(random() * rest.length), rest.length - 1), 1)[0])
  return [d[0].id, ...picked]
}

export function mergeMixes(seeds: string[], mixes: Track[][], limit = 20): Track[] {
  const taken = new Set(seeds)
  const out: Track[] = []
  const max = Math.max(0, ...mixes.map((m) => m.length))
  for (let i = 0; i < max && out.length < limit; i++) {
    for (const mix of mixes) {
      const t = mix[i]
      if (t && !taken.has(t.id) && out.length < limit) {
        taken.add(t.id)
        out.push(t)
      }
    }
  }
  return out
}

export function discoveryQuery(genre?: string | null, vibe?: string | null, decade?: string | null, country?: string | null): string | null {
  const parts = [genre, vibe, decade, country].filter((v): v is string => !!v).map((v) => v.toLowerCase())
  return parts.length ? parts.join(' ') : null
}

const NOT_SONG = /(?<![\p{L}\p{N}_])(mix|mixes|megamix|mega|best of|hits|lo mejor|top \d+|playlist|full album|[aá]lbum completo|recopilaci\p{L}*|enganchados?|cl[aá]sicos|antiguo|old school|\d+\s*(horas?|hours?)|compilation|non ?stop)(?![\p{L}\p{N}_])/u

export function looksLikeSong(title: string): boolean {
  return (title.match(/,/g)?.length ?? 0) < 3 && !NOT_SONG.test(title.toLowerCase())
}
