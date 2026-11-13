import assert from 'node:assert/strict'
import { test } from 'node:test'
import type { Track } from './api.ts'
import { DISCOVERY_CHIPS, discoveryQuery, distinctRecent } from './home.ts'

const t = (id: string): Track => ({ id, title: `T ${id}`, channel: 'C' })
const ids = (tracks: Track[]) => tracks.map((x) => x.id)

test('Pistas repetidas: A, B, A, C muestra A, B, C', () => {
  assert.deepEqual(ids(distinctRecent([t('A'), t('B'), t('A'), t('C')])), ['A', 'B', 'C'])
})

test('Escuchado hace poco: como máximo 10 distintas, la más reciente primero', () => {
  const history = Array.from({ length: 15 }, (_, i) => t(`id${i}`))
  assert.deepEqual(ids(distinctRecent(history)), Array.from({ length: 10 }, (_, i) => `id${i}`))
})

test('Sin historial: Escuchado hace poco vacío y sin semillas', () => {
  assert.deepEqual(distinctRecent([]), [])
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
