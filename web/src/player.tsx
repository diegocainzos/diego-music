import { useEffect, useRef, useState, type PointerEvent } from 'react'
import { artwork } from './api.ts'
import { fetchLyrics, type LyricsResult } from './lyrics.ts'
import { navigate, playback, player, useStore } from './store.ts'
import { FavoriteButton, Icon, Label, Spinner, Title, TrackArt, TrackMenu } from './ui.tsx'

export const formatTime = (s: number) => {
  if (!Number.isFinite(s)) return '0:00'
  const t = Math.max(0, Math.floor(s))
  const h = Math.floor(t / 3600)
  const m = Math.floor((t % 3600) / 60)
  const sec = String(t % 60).padStart(2, '0')
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${sec}` : `${m}:${sec}`
}

const useCurrent = () => useStore(playback, (s) => (s.index == null ? null : s.items[s.index] ?? null))

function PlayPause({ size = 22 }: { size?: number }) {
  const status = useStore(playback, (s) => s.status)
  if (status === 'resolving' || status === 'buffering') return <Spinner />
  return <Icon name={status === 'playing' ? 'pause' : 'play'} size={size} />
}

// MARK: - Mini‑player

export function MiniPlayer({ onExpand }: { onExpand: () => void }) {
  const current = useCurrent()
  const time = useStore(playback, (s) => s.time)
  const duration = useStore(playback, (s) => s.duration)
  const status = useStore(playback, (s) => s.status)
  const error = useStore(playback, (s) => s.error)
  useStore(playback, (s) => s.items)
  if (!current) return null
  const canAdvance = player.canAdvance()
  return (
    <div className="mini">
      <div className="row" style={{ padding: '8px 12px', gap: 12, cursor: 'pointer' }} onClick={onExpand}>
        <TrackArt track={current} size={42} />
        <div className="col grow" style={{ gap: 2 }}>
          <span className="mono ellipsis" style={{ fontSize: 13, textTransform: 'uppercase' }}>{current.title}</span>
          <span className="mono ellipsis muted" style={{ fontSize: 11 }}>{status === 'failed' && error ? error : current.channel}</span>
        </div>
        <button className="icon-btn" onClick={(e) => { e.stopPropagation(); player.toggle() }} aria-label={status === 'playing' ? 'Pausar' : 'Reproducir'}>
          <PlayPause />
        </button>
        <button className="icon-btn" disabled={!canAdvance} onClick={(e) => { e.stopPropagation(); player.next() }} aria-label="Siguiente">
          <Icon name="next" size={20} />
        </button>
      </div>
      <div className="progress"><i style={{ width: `${duration > 0 ? (time / duration) * 100 : 0}%` }} /></div>
    </div>
  )
}

// MARK: - Reproductor expandido (Donda)

export function ExpandedPlayer({ onClose }: { onClose: () => void }) {
  const current = useCurrent()
  const status = useStore(playback, (s) => s.status)
  const error = useStore(playback, (s) => s.error)
  const radioSeed = useStore(playback, (s) => s.radioSeed)
  const [lyrics, setLyrics] = useState(false)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && (lyrics ? setLyrics(false) : onClose())
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [lyrics, onClose])
  if (!current) return null
  if (lyrics) return <Lyrics onClose={() => setLyrics(false)} />
  return (
    <div className="sheet" role="dialog" aria-label="Reproductor">
      <div className="player">
        <div className="row" style={{ width: '100%' }}>
          <div style={{ width: 116 }}>
            <button className="icon-btn" onClick={onClose} aria-label="Cerrar"><Icon name="down" size={22} /></button>
          </div>
          <div className="grow" style={{ textAlign: 'center' }}><Label>{radioSeed ? 'Radio' : 'Reproduciendo'}</Label></div>
          <div className="row" style={{ width: 116, justifyContent: 'flex-end' }}>
            <button className="icon-btn secondary" onClick={() => setLyrics(true)} aria-label="Letras de la canción"><Icon name="quote" /></button>
            <FavoriteButton track={current} />
            <TrackMenu track={current} />
          </div>
        </div>
        <div className={`art ${status === 'playing' ? 'pulse' : ''}`} style={{ width: '100%', aspectRatio: '1' }}>
          <img src={artwork(current)} alt="" />
        </div>
        <div className="col" style={{ alignItems: 'center', gap: 6, textAlign: 'center' }}>
          <Title size={20} className="clamp2">{current.title}</Title>
          <button onClick={() => { onClose(); navigate({ kind: 'artist', id: current.channel, name: current.channel }) }}>
            <Label>{current.channel}</Label>
          </button>
          {status === 'failed' && error && (
            <>
              <Label primary>{error}</Label>
              <button className="btn-outline" onClick={() => player.toggle()}><Label>Reintentar</Label></button>
            </>
          )}
        </div>
        <Scrubber />
        <Controls />
        <button className="btn-outline" style={{ padding: '10px 16px' }} onClick={() => (radioSeed ? player.stopRadio() : player.startRadio())}>
          <Label>{radioSeed ? 'Radio activa · parar' : 'Iniciar radio'}</Label>
        </button>
        <Upcoming />
      </div>
    </div>
  )
}

function Scrubber() {
  const time = useStore(playback, (s) => s.time)
  const duration = useStore(playback, (s) => s.duration)
  const [drag, setDrag] = useState<number | null>(null)
  const ref = useRef<HTMLDivElement>(null)
  const max = Math.max(duration, 1)
  const shown = drag ?? time
  const at = (e: PointerEvent) => {
    const r = ref.current!.getBoundingClientRect()
    return Math.min(Math.max((e.clientX - r.left) / r.width, 0), 1) * max
  }
  return (
    <div className="col" style={{ width: '100%', gap: 6 }}>
      <div
        ref={ref}
        className="scrubber"
        role="slider"
        aria-label="Progreso"
        aria-valuemin={0}
        aria-valuemax={Math.round(max)}
        aria-valuenow={Math.round(shown)}
        onPointerDown={(e) => { e.currentTarget.setPointerCapture(e.pointerId); setDrag(at(e)) }}
        onPointerMove={(e) => drag != null && setDrag(at(e))}
        onPointerUp={(e) => { player.seek(at(e)); setDrag(null) }}
      >
        <div className="progress"><i style={{ width: `${(shown / max) * 100}%` }} /></div>
        <div className="thumb" style={{ left: `${(shown / max) * 100}%` }} />
      </div>
      <div className="row mono muted" style={{ fontSize: 11, justifyContent: 'space-between' }}>
        <span>{formatTime(shown)}</span>
        <span>-{formatTime(Math.max(duration - shown, 0))}</span>
      </div>
    </div>
  )
}

function Controls() {
  const shuffle = useStore(playback, (s) => s.shuffle)
  const repeat = useStore(playback, (s) => s.repeat)
  const time = useStore(playback, (s) => s.time)
  const status = useStore(playback, (s) => s.status)
  useStore(playback, (s) => s.items)
  useStore(playback, (s) => s.index)
  const canAdvance = player.canAdvance()
  const canRetreat = player.canRetreat() || time >= 1
  return (
    <div className="row" style={{ width: '100%', justifyContent: 'space-between' }}>
      <button className={`icon-btn ${shuffle ? '' : 'secondary'}`} style={{ width: 44, height: 44 }} onClick={player.toggleShuffle} aria-label="Barajar"><Icon name="shuffle" size={20} /></button>
      <button className="icon-btn" style={{ width: 44, height: 44 }} disabled={!canRetreat} onClick={player.previous} aria-label="Anterior"><Icon name="previous" size={26} /></button>
      <button className="play-square" onClick={player.toggle} aria-label={status === 'playing' ? 'Pausar' : 'Reproducir'}><PlayPause size={30} /></button>
      <button className="icon-btn" style={{ width: 44, height: 44 }} disabled={!canAdvance} onClick={player.next} aria-label="Siguiente"><Icon name="next" size={26} /></button>
      <button className={`icon-btn ${repeat === 'off' ? 'secondary' : ''}`} style={{ width: 44, height: 44 }} onClick={player.cycleRepeat} aria-label="Repetir">
        <Icon name={repeat === 'one' ? 'repeatOne' : 'repeat'} size={20} />
      </button>
    </div>
  )
}

function Upcoming() {
  const items = useStore(playback, (s) => s.items)
  const index = useStore(playback, (s) => s.index)
  const radioSeed = useStore(playback, (s) => s.radioSeed)
  if (!items.length) return null
  return (
    <div className="col" style={{ width: '100%', gap: 12, marginTop: 12 }}>
      <Label>{radioSeed ? `Radio de “${radioSeed}”` : 'A continuación'}</Label>
      {items.slice(0, 20).map((t, i) => (
        <button key={`${t.id}-${i}`} className="row" style={{ gap: 12, textAlign: 'left' }} onClick={() => player.selectFromQueue(i)}>
          <span className="mono" style={{ width: 12, fontSize: 9 }}>{i === index ? '▶' : ''}</span>
          <TrackArt track={t} size={40} />
          <div className="col grow" style={{ gap: 2 }}>
            <span className="mono ellipsis" style={{ fontSize: 13 }}>{t.title}</span>
            <span className="mono ellipsis muted" style={{ fontSize: 11 }}>{t.channel}</span>
          </div>
          {t.duration ? <span className="mono muted" style={{ fontSize: 11 }}>{formatTime(t.duration)}</span> : null}
        </button>
      ))}
    </div>
  )
}

// MARK: - Letras

function Lyrics({ onClose }: { onClose: () => void }) {
  const current = useCurrent()
  const time = useStore(playback, (s) => s.time)
  const [result, setResult] = useState<LyricsResult | null>(null)
  const listRef = useRef<HTMLDivElement>(null)
  const userScroll = useRef(0)
  useEffect(() => {
    if (!current) return
    setResult(null)
    fetchLyrics({ ...current, duration: current.duration ?? (Math.round(playback.get().duration) || null) }).then(setResult)
  }, [current])
  const lines = result?.kind === 'synced' ? result.lines : []
  let active = -1
  for (let i = 0; i < lines.length && lines[i].start <= time; i++) active = i
  useEffect(() => {
    // Tras un desplazamiento manual, el autoscroll espera 3 s.
    if (active < 0 || Date.now() - userScroll.current < 3000) return
    listRef.current?.querySelector<HTMLElement>(`[data-line="${active}"]`)?.scrollIntoView({ block: 'center', behavior: 'smooth' })
  }, [active])
  if (!current) return null
  return (
    <div className="sheet" role="dialog" aria-label="Letras" ref={listRef} onWheel={() => (userScroll.current = Date.now())} onTouchMove={() => (userScroll.current = Date.now())}>
      <div style={{ position: 'sticky', top: 0, background: 'var(--bg)', padding: '14px 20px', zIndex: 1 }}>
        <button className="body" style={{ fontWeight: 600, fontSize: 16 }} onClick={onClose}>Cerrar</button>
      </div>
      <div style={{ maxWidth: 640, margin: '0 auto', padding: '0 24px' }}>
        {!result && <div className="row" style={{ justifyContent: 'center', padding: 80 }}><Spinner /></div>}
        {result?.kind === 'synced' && (
          <div className="col" style={{ gap: 16, padding: '35vh 0' }}>
            {lines.map((l, i) =>
              l.text.trim() ? (
                <div key={i} data-line={i} className={`lyric ${i === active ? 'on' : ''}`} onClick={() => player.seek(l.start)}>{l.text}</div>
              ) : (
                <div key={i} data-line={i} style={{ height: 24 }} />
              ),
            )}
          </div>
        )}
        {result?.kind === 'plain' && (
          <>
            <Label>Letras sin sincronización</Label>
            <p className="body" style={{ fontSize: 16, lineHeight: '26px', whiteSpace: 'pre-wrap', padding: '32px 0' }}>{result.text}</p>
          </>
        )}
        {(result?.kind === 'instrumental' || result?.kind === 'notFound') && (
          <div className="col" style={{ alignItems: 'center', gap: 16, padding: '120px 0', textAlign: 'center' }}>
            <Title size={18}>{result.kind === 'instrumental' ? 'Instrumental' : 'Letra no disponible'}</Title>
            {result.kind === 'notFound' && <span className="muted" style={{ fontSize: 15 }}>No se encontraron letras para esta canción</span>}
          </div>
        )}
      </div>
    </div>
  )
}

