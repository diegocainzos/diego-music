import { useEffect, useRef, useState, type ReactNode } from 'react'
import { artwork, type Track } from './api.ts'
import { addToPlaylist, goBack, nav, navigate, player, session, toggleFavorite, useStore } from './store.ts'

// Iconos Material (mismos glifos que la app Android).
const paths = {
  play: 'M8 5v14l11-7z',
  pause: 'M6 19h4V5H6v14zm8-14v14h4V5h-4z',
  next: 'M4 18l8.5-6L4 6v12zm9-12v12l8.5-6L13 6z',
  previous: 'M11 18V6l-8.5 6 8.5 6zm.5-6l8.5 6V6l-8.5 6z',
  shuffle: 'M10.59 9.17L5.41 4 4 5.41l5.17 5.17 1.42-1.41zM14.5 4l2.04 2.04L4 18.59 5.41 20 17.96 7.46 20 9.5V4h-5.5zm.33 9.41l-1.41 1.41 3.13 3.13L14.5 20H20v-5.5l-2.04 2.04-3.13-3.13z',
  repeat: 'M7 7h10v3l4-4-4-4v3H5v6h2V7zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4z',
  repeatOne: 'M7 7h10v3l4-4-4-4v3H5v6h2V7zm10 10H7v-3l-4 4 4 4v-3h12v-6h-2v4zm-4-2V9h-1l-2 1v1h1.5v4H13z',
  heart: 'M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z',
  heartOutline: 'M16.5 3c-1.74 0-3.41.81-4.5 2.09C10.91 3.81 9.24 3 7.5 3 4.42 3 2 5.42 2 8.5c0 3.78 3.4 6.86 8.55 11.54L12 21.35l1.45-1.32C18.6 15.36 22 12.28 22 8.5 22 5.42 19.58 3 16.5 3zm-4.4 15.55l-.1.1-.1-.1C7.14 14.24 4 11.39 4 8.5 4 6.5 5.5 5 7.5 5c1.54 0 3.04.99 3.57 2.36h1.87C13.46 5.99 14.96 5 16.5 5c2 0 3.5 1.5 3.5 3.5 0 2.89-3.14 5.74-7.9 10.05z',
  more: 'M6 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm12 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm-6 0c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z',
  down: 'M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z',
  back: 'M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z',
  search: 'M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z',
  gear: 'M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z',
  quote: 'M6 17h3l2-4V7H5v6h3zm8 0h3l2-4V7h-6v6h3z',
  close: 'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z',
  download: 'M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z',
  trash: 'M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z',
  wifiOff: 'M23.64 7c-.45-.34-4.93-4-11.64-4-1.5 0-2.89.19-4.15.48L18.18 13.8 23.64 7zm-6.6 8.22L3.27 1.44 2 2.72l2.05 2.06C1.91 5.76.59 6.82.36 7l11.63 14.49.01.01.01-.01 3.9-4.86 3.32 3.32 1.27-1.27-3.46-3.46z',
}

export type IconName = keyof typeof paths

export function Icon({ name, size = 18 }: { name: IconName; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d={paths[name]} />
    </svg>
  )
}

export const Label = ({ children, primary, wide, className = '', size }: { children: ReactNode; primary?: boolean; wide?: boolean; className?: string; size?: number }) => (
  <span className={`label ${primary ? 'primary' : ''} ${wide ? 'wide' : ''} ${className}`} style={size ? { fontSize: size } : undefined}>
    {children}
  </span>
)

export const Title = ({ children, size = 20, className = '' }: { children: ReactNode; size?: number; className?: string }) => (
  <h1 className={`title ${className}`} style={{ fontSize: size }}>
    {children}
  </h1>
)

/** Carátula cuadrada con borde hairline; sin imagen queda un cuadrado del color de fondo. */
export function Art({ src, size }: { src?: string | null; size: number | string }) {
  const [failed, setFailed] = useState(false)
  return (
    <div className="art" style={{ width: size, height: size }}>
      {src && !failed && <img src={src} alt="" loading="lazy" onError={() => setFailed(true)} />}
    </div>
  )
}

export const TrackArt = ({ track, size }: { track: Track; size: number | string }) => <Art src={artwork(track)} size={size} />

export const Spinner = () => <div className="spinner" role="status" aria-label="Cargando" />

export function Loading({ text }: { text: string }) {
  return (
    <div className="row" style={{ justifyContent: 'center', gap: 12, padding: '60px 0' }}>
      <Spinner />
      <Label>{text}</Label>
    </div>
  )
}

export function EmptyState({ title, text, action, onAction }: { title: string; text: string; action?: string; onAction?: () => void }) {
  return (
    <div className="col" style={{ alignItems: 'center', gap: 14, padding: 32, textAlign: 'center' }}>
      <Title size={18}>{title}</Title>
      <p className="muted" style={{ margin: 0, fontSize: 15, maxWidth: 460 }}>{text}</p>
      {action && onAction && (
        <button className="btn-primary" onClick={onAction}>
          <Label>{action}</Label>
        </button>
      )}
    </div>
  )
}

export function BackBar({ label }: { label: string }) {
  const canGoBack = useStore(nav, (s) => s.stack.length > 0)
  return (
    <div className="back-bar">
      {canGoBack && (
        <button className="btn-outline" onClick={goBack} aria-label="Volver atrás">
          <Icon name="back" size={16} />
          <Label primary>Atrás</Label>
        </button>
      )}
      <Label>{label}</Label>
    </div>
  )
}

export function FavoriteButton({ track, size = 16 }: { track: Track; size?: number }) {
  const fav = useStore(session, (s) => s.favorites.some((f) => f.id === track.id))
  return (
    <button
      className={`icon-btn ${fav ? '' : 'secondary'}`}
      onClick={() => toggleFavorite(track)}
      aria-label={fav ? 'Quitar de favoritos' : 'Añadir a favoritos'}
    >
      <Icon name={fav ? 'heart' : 'heartOutline'} size={size} />
    </button>
  )
}

/** Menú «…» de una pista: cola, artista y playlists. */
export function TrackMenu({ track, showArtist = true }: { track: Track; showArtist?: boolean }) {
  const [open, setOpen] = useState(false)
  const [lists, setLists] = useState(false)
  const playlists = useStore(session, (s) => s.playlists)
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    if (!open) return
    const close = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false)
    document.addEventListener('mousedown', close)
    return () => document.removeEventListener('mousedown', close)
  }, [open])
  const done = () => {
    setOpen(false)
    setLists(false)
  }
  return (
    <div ref={ref} style={{ position: 'relative' }}>
      <button className="icon-btn secondary" onClick={() => setOpen(!open)} aria-label={`Más opciones para ${track.title}`}>
        <Icon name="more" />
      </button>
      {open && (
        <div className="menu">
          <button onClick={() => { player.enqueueNext(track); done() }}>Añadir a la cola</button>
          {showArtist && track.channel && (
            <button onClick={() => { navigate({ kind: 'artist', id: track.channel, name: track.channel }); done() }}>
              Ir al artista ({track.channel})
            </button>
          )}
          {playlists.length > 0 && <button onClick={() => setLists(!lists)}>Añadir a playlist</button>}
          {lists &&
            playlists.map((p) => (
              <button key={p.id} onClick={() => { addToPlaylist(p, track); done() }}>
                <Label primary>— {p.name}</Label>
              </button>
            ))}
        </div>
      )}
    </div>
  )
}

/** Fila de pista estándar (Buscar, Biblioteca, Artista). */
export function TrackRow({ track, onPlay, index }: { track: Track; onPlay: () => void; index?: number }) {
  return (
    <div className="list-row">
      <button className="row grow" style={{ gap: 12, textAlign: 'left' }} onClick={onPlay} aria-label={`Reproducir ${track.title}`}>
        {index != null && <Label className="mono" size={11}>{index}</Label>}
        <TrackArt track={track} size={52} />
        <div className="col grow" style={{ gap: 3 }}>
          <span className="body clamp2" style={{ fontSize: 16 }}>{track.title}</span>
          <Label className="ellipsis">{track.channel}</Label>
        </div>
      </button>
      <button className="icon-btn" onClick={onPlay} aria-label={`Reproducir ${track.title}`}>
        <Icon name="play" size={16} />
      </button>
      <FavoriteButton track={track} />
      <TrackMenu track={track} />
    </div>
  )
}

export function Carousel({ items, onPlay }: { items: Track[]; onPlay: (t: Track) => void }) {
  return (
    <div className="scroll-x">
      {items.map((t) => (
        <button key={t.id} className="tile" onClick={() => onPlay(t)} aria-label={`Reproducir ${t.title}`}>
          <TrackArt track={t} size={128} />
          <span className="body ellipsis" style={{ fontSize: 13 }}>{t.title}</span>
          <Label className="ellipsis">{t.channel}</Label>
        </button>
      ))}
    </div>
  )
}

export const Section = ({ title, children }: { title: string; children: ReactNode }) => (
  <section className="section">
    <Label wide>{title}</Label>
    {children}
  </section>
)

/** «DESCARGAR APK»: el archivo lo publica scripts/publish-apk.sh en /downloads/. */
export function ApkButton({ full }: { full?: boolean }) {
  return (
    <a className="btn-primary" href="/downloads/diegomusic.apk" download style={{ width: full ? '100%' : undefined, textDecoration: 'none' }}>
      <Icon name="download" size={14} />
      <Label>Descargar APK</Label>
    </a>
  )
}

