import { test } from 'node:test'
import assert from 'node:assert/strict'
import { looksLikeSong } from './home.ts'

test('Filtro con tildes: igual que en Swift y Kotlin', () => {
  for (const t of ['Álbum completo 1990', 'Disco - álbum completo', 'ÁLBUM COMPLETO', 'Recopilación 2020', 'Los clásicos del rock']) assert.equal(looksLikeSong(t), false, t)
  for (const t of ['Mixed Feelings - Song', 'Rosalía - Malamente', 'Megan Thee Stallion - Savage']) assert.equal(looksLikeSong(t), true, t)
})
