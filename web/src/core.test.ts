import assert from 'node:assert/strict'
import { test } from 'node:test'
import { isValidVideoId, normalizeQuery } from './api.ts'
import { cleanChannel, extract, parseLrc, selectBest } from './lyrics.ts'

test('normalización de búsqueda igual que iOS/Android', () => {
  assert.equal(normalizeQuery('  Coldplay  -   Yellow '), 'coldplay - yellow')
  assert.equal(normalizeQuery('Rosalía'), 'rosalia')
})

test('validación de videoId', () => {
  assert.ok(isValidVideoId('dQw4w9WgXcQ'))
  assert.ok(!isValidVideoId('https://x.y'))
})

test('limpieza de metadatos para LRCLIB', () => {
  assert.deepEqual(extract({ id: 'x', title: 'Lady Gaga - Abracadabra (Official Music Video)', channel: 'LadyGagaVEVO' }), ['Lady Gaga', 'Abracadabra'])
  assert.equal(cleanChannel('Coldplay - Topic'), 'Coldplay')
})

test('parser LRC y puntuación', () => {
  const lines = parseLrc('[00:12.50] Hola\n[01:02.123]Adiós\nbasura')
  assert.equal(lines.length, 2)
  assert.equal(lines[1].start, 62.123)
  const far = { trackName: 'Yellow', artistName: 'Coldplay', duration: 400, instrumental: false, syncedLyrics: '[00:01.00] a' }
  const close = { ...far, duration: 268 }
  assert.equal(selectBest([far, close], 'Coldplay', 'Yellow', 266), close)
})
