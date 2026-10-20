#!/usr/bin/env node
// Mide un registro de combate de WoW (Logs/WoWCombatLog*.txt) para la F0 del addon:
// tamaño y ritmo, compresión, tipos de evento, encuentros, y cada cuánto hay posición de
// cada jugador (Advanced Combat Logging). Uso:
//   node medir-log.mjs <WoWCombatLog.txt>      → informe del archivo
//   node medir-log.mjs --json <archivo>        → lo mismo en JSON
import { createReadStream, statSync } from 'node:fs'
import { createInterface } from 'node:readline'
import { gzipSync } from 'node:zlib'

const args = process.argv.slice(2)
const asJson = args.includes('--json')
const file = args.find((a) => !a.startsWith('--'))
if (!file) { console.error('Uso: node medir-log.mjs [--json] <WoWCombatLog.txt>'); process.exit(1) }

// Separa por comas respetando comillas ("Nombre, con coma") y corchetes (listas de retail).
function split(s) {
  const out = []
  let cur = '', q = false, depth = 0
  for (const ch of s) {
    if (ch === '"') q = !q
    else if (!q && (ch === '[' || ch === '(')) depth++
    else if (!q && (ch === ']' || ch === ')')) depth--
    if (ch === ',' && !q && depth === 0) { out.push(cur); cur = '' } else cur += ch
  }
  out.push(cur)
  return out
}
// "10/20/2026 21:03:11.123-3  EVENTO,..." (algunas versiones sin año o sin zona)
const TS = /^(\d+)\/(\d+)(?:\/(\d+))? (\d+):(\d+):(\d+)\.(\d+)(?:[-+]\d+)?\s\s(.*)$/
const isGuid = (s) => /^(Player|Creature|Pet|Vehicle|GameObject)-/.test(s)
const isDec = (s) => /^-?\d+\.\d+$/.test(s)
const isInt = (s) => /^-?\d+$/.test(s)

// Bloque avanzado: empieza en el GUID de la unidad (índice 9 en SWING_*, 12 en SPELL_*/RANGE_*)
// y la posición queda 11 campos después en Classic y 12 en retail (suma "absorb").
function position(f) {
  for (const start of [9, 12]) {
    if (!isGuid(f[start] ?? '')) continue
    for (const off of [11, 12, 13]) {
      const j = start + off
      const x = f[j], y = f[j + 1], map = f[j + 2], facing = f[j + 3]
      if (isDec(x ?? '') && isDec(y ?? '') && isInt(map ?? '') && isDec(facing ?? '') && +facing >= 0 && +facing <= 6.3) {
        return { guid: f[start], x: +x, y: +y, map: +map }
      }
    }
  }
  return null
}

const size = statSync(file).size
const byType = new Map()
const players = new Map() // guid → nombre
const lastPos = new Map() // guid → ms
const gaps = new Map() // guid → [s]
const encounters = []
let header = null, lines = 0, first = null, last = null, withPos = 0, playerPos = 0, sample = []

const rl = createInterface({ input: createReadStream(file, { encoding: 'utf8' }), crlfDelay: Infinity })
for await (const line of rl) {
  lines++
  if (sample.length < 20000) sample.push(line)
  const m = TS.exec(line)
  if (!m) continue
  const [, mo, d, y, h, mi, s, ms, rest] = m
  const t = Date.UTC(+(y ?? 2000) < 100 ? 2000 + +(y ?? 0) : +(y ?? 2000), +mo - 1, +d, +h, +mi, +s, +ms.padEnd(3, '0').slice(0, 3))
  first ??= t
  last = t
  const f = split(rest)
  const ev = f[0]
  byType.set(ev, (byType.get(ev) ?? 0) + 1)
  // COMBAT_LOG_VERSION,20,ADVANCED_LOG_ENABLED,1,BUILD_VERSION,…,PROJECT_ID,…
  if (ev === 'COMBAT_LOG_VERSION') {
    header = { COMBAT_LOG_VERSION: f[1] }
    for (let i = 2; i + 1 < f.length; i += 2) header[f[i]] = f[i + 1]
    continue
  }
  if (ev === 'ENCOUNTER_START') { encounters.push({ name: f[2]?.replace(/"/g, ''), difficulty: +f[3], size: +f[4], start: t }); continue }
  if (ev === 'ENCOUNTER_END') { const e = [...encounters].reverse().find((x) => !x.end); if (e) { e.end = t; e.kill = f[5] === '1' } continue }
  if (f[1]?.startsWith('Player-')) players.set(f[1], f[2]?.replace(/"/g, ''))
  const p = position(f)
  if (p) {
    withPos++
    if (p.guid.startsWith('Player-')) {
      playerPos++
      const prev = lastPos.get(p.guid)
      if (prev != null) { const g = gaps.get(p.guid) ?? []; g.push((t - prev) / 1000); gaps.set(p.guid, g) }
      lastPos.set(p.guid, t)
    }
  }
}

const mins = first != null ? (last - first) / 60000 : 0
const sampleBytes = Buffer.byteLength(sample.join('\n'))
const ratio = sampleBytes ? gzipSync(sample.join('\n')).length / sampleBytes : 0
const q = (arr, p) => { if (!arr.length) return null; const s = [...arr].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(p * s.length))] }
const allGaps = [...gaps.values()].flat().filter((g) => g >= 0 && g < 600)
const perPlayer = [...gaps.entries()].map(([g, arr]) => ({ name: players.get(g) ?? g, samples: arr.length + 1, medianGap: q(arr, 0.5) }))
  .sort((a, b) => b.samples - a.samples)
const mb = size / 1048576

const report = {
  file, sizeMB: +mb.toFixed(2), lines, minutes: +mins.toFixed(1),
  mbPerHour: mins ? +(mb / mins * 60).toFixed(1) : null,
  linesPerMinute: mins ? Math.round(lines / mins) : null,
  gzipRatio: +ratio.toFixed(3),
  batch3minKB: mins ? Math.round(size / mins * 3 * ratio / 1024) : null,
  header,
  advanced: header?.ADVANCED_LOG_ENABLED === '1',
  topEvents: [...byType.entries()].sort((a, b) => b[1] - a[1]).slice(0, 15),
  encounters: encounters.map((e) => ({ ...e, seconds: e.end ? Math.round((e.end - e.start) / 1000) : null, start: undefined, end: undefined })),
  players: players.size,
  positions: {
    linesWithPosition: withPos, pctOfLines: lines ? +(withPos / lines * 100).toFixed(1) : 0,
    playerSamples: playerPos, playersWithPosition: lastPos.size,
    gapSeconds: { p50: q(allGaps, 0.5), p90: q(allGaps, 0.9), p99: q(allGaps, 0.99) },
  },
  perPlayer: perPlayer.slice(0, 40),
}

if (asJson) { console.log(JSON.stringify(report, null, 2)); process.exit(0) }
const L = (k, v) => console.log(`${k.padEnd(28)} ${v}`)
console.log(`\n== ${file}`)
L('Tamaño', `${report.sizeMB} MB · ${lines.toLocaleString('es-AR')} líneas · ${report.minutes} min`)
L('Ritmo', `${report.mbPerHour ?? '?'} MB/h · ${report.linesPerMinute ?? '?'} líneas/min`)
L('Compresión gzip', `${(ratio * 100).toFixed(1)} % del original → lote de 3 min ≈ ${report.batch3minKB ?? '?'} KB`)
L('Encabezado', header ? Object.entries(header).map(([k, v]) => `${k}=${v}`).join(' ') : 'no encontrado (¿el log se prendió antes de arrancar el archivo?)')
L('Modo avanzado', report.advanced ? 'SÍ' : 'NO ← sin esto no hay posiciones')
L('Jugadores vistos', players.size)
L('Líneas con posición', `${withPos.toLocaleString('es-AR')} (${report.positions.pctOfLines} %)`)
L('Jugadores con posición', `${lastPos.size} · ${playerPos.toLocaleString('es-AR')} muestras`)
const gs = report.positions.gapSeconds
L('Hueco entre posiciones', gs.p50 == null ? 'sin datos' : `mediana ${gs.p50.toFixed(2)} s · p90 ${gs.p90.toFixed(2)} s · p99 ${gs.p99.toFixed(1)} s`)
console.log('\nEncuentros:')
if (!encounters.length) console.log('  (ninguno)')
for (const e of report.encounters) console.log(`  ${e.kill ? '✔' : '✘'} ${e.name} · ${e.seconds ?? '?'} s · dificultad ${e.difficulty} · ${e.size} jugadores`)
console.log('\nEventos más frecuentes:')
for (const [k, v] of report.topEvents) console.log(`  ${k.padEnd(30)} ${v.toLocaleString('es-AR')}`)
console.log('\nPosiciones por jugador (más muestras primero):')
for (const p of report.perPlayer.slice(0, 25)) console.log(`  ${String(p.name).padEnd(28)} ${String(p.samples).padStart(7)} muestras · cada ${p.medianGap?.toFixed(2) ?? '?'} s`)
