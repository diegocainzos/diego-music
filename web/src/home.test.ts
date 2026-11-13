import assert from 'node:assert/strict'
import { test } from 'node:test'
import type { Track } from './api.ts'
import { DISCOVERY_CHIPS, discoveryQuery, distinctRecent, mergeMixes, quickPickSeeds } from './home.ts'

const t = (id: string): Track => ({ id, title: `T ${id}`, channel: 'C' })
const ids = (tracks: Track[]) => tracks.map((x) => x.id)

// Deterministic LCG in [0, 1).
const seeded = (seed: number) => {
  let s = seed >>> 0
  return () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0
    return s / 2 ** 32
  }
}

test('Pistas repetidas: A, B, A, C muestra A, B, C', () => {
  assert.deepEqual(ids(distinctRecent([t('A'), t('B'), t('A'), t('C')])), ['A', 'B', 'C'])
})

test('Escuchado hace poco: como máximo 10 distintas, la más reciente primero', () => {
  const history = Array.from({ length: 15 }, (_, i) => t(`id${i}`))
  assert.deepEqual(ids(distinctRecent(history)), Array.from({ length: 10 }, (_, i) => `id${i}`))
})

test('Sin historial: Escuchado hace poco vacío y sin semillas', () => {
  assert.deepEqual(distinctRecent([]), [])
  assert.deepEqual(quickPickSeeds([], seeded(1)), [])
})

test('Varias semillas: A siempre primera, máximo 3, sin repetir, solo entre las 10 recientes', () => {
  const history = [t('A'), t('B'), t('A'), t('C'), t('D')]
  for (let seed = 0; seed < 50; seed++) {
    const seeds = quickPickSeeds(history, seeded(seed))
    assert.equal(seeds[0], 'A')
    assert.equal(seeds.length, 3)
    assert.equal(new Set(seeds).size, seeds.length)
    for (const id of seeds) assert.ok(['A', 'B', 'C', 'D'].includes(id))
  }
  const long = Array.from({ length: 20 }, (_, i) => t(`id${i}`))
  const allowed = new Set(Array.from({ length: 10 }, (_, i) => `id${i}`))
  for (let seed = 0; seed < 50; seed++) {
    const seeds = quickPickSeeds(long, seeded(seed))
    assert.equal(seeds[0], 'id0')
    assert.equal(seeds.length, 3)
    for (const id of seeds) assert.ok(allowed.has(id), id)
  }
})

test('Con historial: una sola pista da una sola semilla', () => {
  assert.deepEqual(quickPickSeeds([t('A'), t('A')], seeded(3)), ['A'])
})

test('Varias semillas: mezcla alterna, sin semillas ni duplicados', () => {
  const merged = mergeMixes(['A', 'B'], [[t('a1'), t('a2'), t('A')], [t('b1'), t('a1'), t('b2')]], 20)
  assert.deepEqual(ids(merged), ['a1', 'b1', 'a2', 'b2'])
})

test('Varias semillas: como máximo 20 filas (límite respetado)', () => {
  const mix = (p: string) => Array.from({ length: 30 }, (_, i) => t(`${p}${i}`))
  assert.equal(mergeMixes(['A', 'B', 'C'], [mix('a'), mix('b'), mix('c')]).length, 20)
  assert.deepEqual(ids(mergeMixes(['A'], [mix('a')], 3)), ['a0', 'a1', 'a2'])
})

test('Con historial: Mix de A sin A', () => {
  assert.deepEqual(ids(mergeMixes(['A'], [[t('A'), t('x'), t('y')]])), ['x', 'y'])
})

test('Componer la búsqueda: reggaetón 2010s colombia', () => {
  assert.equal(discoveryQuery('Reggaetón', null, '2010s', 'Colombia'), 'reggaetón 2010s colombia')
  assert.equal(discoveryQuery(null, 'Chill', null, null), 'chill')
})

test('Nada seleccionado: sin consulta', () => {
  assert.equal(discoveryQuery(null, null, null, null) ?? null, null)
})

test('Chips de Descubrimiento idénticos en todos los clientes', () => {
  assert.deepEqual(Object.values(DISCOVERY_CHIPS), [
    ['Pop', 'Rock', 'Hip hop', 'Reggaetón', 'Reggae', 'Electrónica', 'House', 'Techno', 'Drum and bass', 'Dubstep', 'Trance', 'Indie', 'R&B', 'Jazz', 'Flamenco', 'Clásica'],
    ['Chill', 'Fiesta', 'Triste', 'Energía', 'Romántica', 'Concentración'],
    ['70s', '80s', '90s', '2000s', '2010s', '2020s'],
    ['España', 'Galicia', 'México', 'Argentina', 'Colombia', 'USA', 'UK', 'Brasil', 'Corea', 'Japón', 'Francia'],
  ])
})

test('Flujo: historial con repetidas → semillas → mezcla de Mixes', () => {
  const history = [t('A'), t('B'), t('A'), t('C')]
  const recent = distinctRecent(history)
  assert.deepEqual(ids(recent), ['A', 'B', 'C'])
  const seeds = quickPickSeeds(history, seeded(7))
  assert.equal(seeds[0], 'A')
  const mixes = seeds.map((s) => [t(`${s}1`), t('shared'), t(seeds[0]), t(`${s}2`)])
  const merged = ids(mergeMixes(seeds, mixes))
  for (const s of seeds) assert.ok(!merged.includes(s))
  assert.equal(new Set(merged).size, merged.length)
  assert.deepEqual(merged.slice(0, seeds.length), seeds.map((s) => `${s}1`))
  assert.ok(merged.includes('shared'))
})
