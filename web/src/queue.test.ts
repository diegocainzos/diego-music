import assert from 'node:assert/strict'
import { test } from 'node:test'
import type { Track } from './api.ts'
// `store.ts` toca localStorage/window al importarse; la función pura vive en un módulo sin DOM
// y `store.ts` la re-exporta.
import { upNextWindow } from './queue.ts'

const track = (n: number): Track => ({ id: `id${String(n).padStart(9, '0')}`, title: `T${n}`, channel: 'C' })
const list = (count: number) => Array.from({ length: count }, (_, i) => track(i + 1))

test('Historial largo: cola de 30 con la 25 sonando muestra de la 25 a la 30', () => {
  const items = list(30)
  const window = upNextWindow(items, 24)
  assert.deepEqual(window.map((r) => r.index), [24, 25, 26, 27, 28, 29])
  assert.equal(window[0].track, items[24])
  assert.equal(window[5].track, items[29])
})

test('Historial largo: como mucho la actual y 20 posteriores', () => {
  const items = list(30)
  const window = upNextWindow(items, 0)
  assert.equal(window.length, 21)
  assert.equal(window[0].index, 0)
  assert.equal(window[20].index, 20)
  assert.equal(upNextWindow(items, 0, 5).length, 6)
})

test('sin pista actual la vista está vacía', () => {
  assert.deepEqual(upNextWindow(list(3), null), [])
  assert.deepEqual(upNextWindow([], null), [])
})

test('La radio cambia la vista: el Mix aparece tras la actual', () => {
  const current = track(1)
  assert.deepEqual(upNextWindow([current], 0).map((r) => r.track.id), [current.id])
  const mix = [track(50), track(51)]
  const window = upNextWindow([current, ...mix], 0)
  assert.deepEqual(window.map((r) => r.track.id), [current.id, mix[0].id, mix[1].id])
  assert.deepEqual(window.map((r) => r.index), [0, 1, 2])
})

test('Seleccionar desde la vista: la tercera fila es la actual + 2 (índice absoluto)', () => {
  const items = list(10)
  const window = upNextWindow(items, 3)
  assert.equal(window[2].index, 5)
  assert.equal(window[2].track, items[5])
})
