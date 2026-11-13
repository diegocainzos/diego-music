import assert from 'node:assert/strict'
import { test } from 'node:test'
import { looksLikeSong } from './home.ts'

test('looksLikeSong', () => {
  for (const s of [
    'MEGA REGGAETON - (AÑO 2000  2010) -  MAXI REMIXES',
    'Best of REGGAETON 2010-2015',
    'Reggaeton Old School Mix | Don Omar',
    'REGGAETON 2010 - 2015 (TUMBA LA CASA, 6 AM, AY VAMOS, CHOCA, MORE)',
  ]) assert.equal(looksLikeSong(s), false, s)
  for (const s of [
    'Gente de Zona - La Gozadera (Official Video) ft. Marc Anthony',
    'a-ha - Take On Me (Official Video) [4K]',
    'Mixed Feelings - Song',
    'The Sunclub - Fiesta (Official Video)',
  ]) assert.equal(looksLikeSong(s), true, s)
})
