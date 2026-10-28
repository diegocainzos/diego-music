import type { Track } from './api.ts'

/**
 * Ventana deslizante de la cola: la pista actual y hasta `limit` posteriores.
 * Si el índice es nulo o está fuera de rango, devuelve una lista vacía.
 */
export function upNextWindow(
  items: Track[],
  index: number | null,
  limit = 20,
): { index: number; track: Track }[] {
  if (index == null || index < 0 || index >= items.length) return []
  const end = Math.min(items.length, index + 1 + Math.max(0, limit))
  const result: { index: number; track: Track }[] = []
  for (let i = index; i < end; i++) {
    result.push({ index: i, track: items[i] })
  }
  return result
}
