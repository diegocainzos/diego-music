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

export function discoveryQuery(genre?: string | null, vibe?: string | null, decade?: string | null, country?: string | null): string | null {
  const parts = [genre, vibe, decade, country].filter((v): v is string => !!v).map((v) => v.toLowerCase())
  return parts.length ? parts.join(' ') : null
}

const NOT_SONG = /(?<![\p{L}\p{N}_])(mix|mixes|megamix|mega|best of|hits|lo mejor|top \d+|playlist|full album|[aá]lbum completo|recopilaci\p{L}*|enganchados?|cl[aá]sicos|antiguo|old school|\d+\s*(horas?|hours?)|compilation|non ?stop)(?![\p{L}\p{N}_])/u

export function looksLikeSong(title: string): boolean {
  return (title.match(/,/g)?.length ?? 0) < 3 && !NOT_SONG.test(title.toLowerCase())
}
