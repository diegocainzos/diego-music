import { useEffect, useMemo, useState, type FormEvent } from 'react'
import * as api from './api.ts'
import type { ArtistDetail, Playlist, Track } from './api.ts'
import { login, logout, navigate, player, refreshLibrary, register, session, setTheme, toast, ui, useStore } from './store.ts'
import { ApkButton, BackBar, Carousel, EmptyState, Icon, Label, Loading, Section, Title, TrackArt, TrackMenu, TrackRow } from './ui.tsx'

// MARK: - Puerta de autenticación (no se puede omitir)

export function AuthGate() {
  const [tab, setTab] = useState<'login' | 'register'>('login')
  return (
    <div className="col" style={{ minHeight: '100%', alignItems: 'center', gap: 28, padding: '40px 24px 48px' }}>
      <div className="col" style={{ alignItems: 'center', gap: 8, textAlign: 'center' }}>
        <Title size={24}>DiegoMusic</Title>
        <p className="muted" style={{ margin: 0, fontSize: 15 }}>Inicia sesión para sincronizar tus playlists, favoritos y música.</p>
      </div>
      <div className="segmented" style={{ width: '100%', maxWidth: 420 }}>
        {(['login', 'register'] as const).map((t) => (
          <button key={t} className={tab === t ? 'on' : ''} onClick={() => setTab(t)}>
            <Label primary>{t === 'login' ? 'Iniciar sesión' : 'Crear cuenta'}</Label>
          </button>
        ))}
      </div>
      <div className="card col" style={{ width: '100%', maxWidth: 440, gap: 16 }}>{tab === 'login' ? <LoginForm /> : <RegisterForm />}</div>
      <div className="col" style={{ alignItems: 'center', gap: 10 }}>
        <Label>¿Usas Android?</Label>
        <ApkButton />
      </div>
    </div>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="col" style={{ gap: 6 }}>
      <Label>{label}</Label>
      {children}
    </label>
  )
}

function LoginForm() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!email.trim() || !password || busy) return
    setBusy(true)
    setError(null)
    try {
      await login(email.trim().toLowerCase(), password)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo iniciar sesión.')
    }
    setBusy(false)
  }
  return (
    <form className="col" style={{ gap: 16 }} onSubmit={submit}>
      <Field label="Correo electrónico">
        <input className="field" type="email" autoComplete="email" placeholder="usuario@ejemplo.com" value={email} onChange={(e) => setEmail(e.target.value)} />
      </Field>
      <Field label="Contraseña">
        <input className="field" type="password" autoComplete="current-password" placeholder="••••••••" value={password} onChange={(e) => setPassword(e.target.value)} />
      </Field>
      {error && <span className="muted" style={{ fontSize: 12 }}>⚠ {error}</span>}
      <button className="btn-primary" disabled={!email.trim() || !password || busy}>
        {busy && <span className="spinner" />}
        <Label>Iniciar sesión</Label>
      </button>
    </form>
  )
}

function RegisterForm() {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirm, setConfirm] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const lengthOk = password.length >= 10 && password.length <= 25
  const upperOk = /\p{Lu}/u.test(password)
  const valid = email.trim() !== '' && lengthOk && upperOk && password === confirm
  const submit = async (e: FormEvent) => {
    e.preventDefault()
    if (!valid || busy) return
    setBusy(true)
    setError(null)
    try {
      await register(email.trim().toLowerCase(), password, name.trim() || undefined)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error al registrar usuario.')
    }
    setBusy(false)
  }
  const req = (ok: boolean, text: string) => (
    <span style={{ fontSize: 11, color: ok ? 'var(--text)' : 'var(--text2)' }}>{ok ? '◉' : '○'} {text}</span>
  )
  return (
    <form className="col" style={{ gap: 16 }} onSubmit={submit}>
      <Field label="Nombre completo (opcional)">
        <input className="field" placeholder="Diego Cainzos" value={name} onChange={(e) => setName(e.target.value)} />
      </Field>
      <Field label="Correo electrónico">
        <input className="field" type="email" autoComplete="email" placeholder="usuario@ejemplo.com" value={email} onChange={(e) => setEmail(e.target.value)} />
      </Field>
      <Field label="Contraseña">
        <input className="field" type="password" autoComplete="new-password" placeholder="Entre 10 y 25 caracteres" value={password} onChange={(e) => setPassword(e.target.value)} />
        {req(lengthOk, `Entre 10 y 25 caracteres (${password.length}/25)`)}
        {req(upperOk, 'Al menos una letra mayúscula')}
      </Field>
      <Field label="Confirmar contraseña">
        <input className="field" type="password" autoComplete="new-password" placeholder="Repite tu contraseña" value={confirm} onChange={(e) => setConfirm(e.target.value)} />
        {confirm && req(password === confirm, password === confirm ? 'Las contraseñas coinciden' : 'Las contraseñas no coinciden')}
      </Field>
      {error && <span className="muted" style={{ fontSize: 12 }}>⚠ {error}</span>}
      <button className="btn-primary" disabled={!valid || busy}>
        {busy && <span className="spinner" />}
        <Label>Crear cuenta</Label>
      </button>
    </form>
  )
}

// MARK: - Inicio

// Selecciones rápidas: Mix de YouTube de la pista más reciente (sin ella). Si falla o está vacío, no se muestra.
function QuickPicks({ seed }: { seed: Track }) {
  const [picks, setPicks] = useState<Track[]>([])
  useEffect(() => {
    let alive = true
    setPicks([])
    api.radio(seed.id)
      .then((items) => alive && setPicks(items.filter((t) => t.id !== seed.id).slice(0, 20)))
      .catch(() => undefined)
    return () => {
      alive = false
    }
  }, [seed.id])
  if (!picks.length) return null
  return (
    <section className="section">
      <div className="row" style={{ justifyContent: 'space-between', gap: 12 }}>
        <Label wide>Selecciones rápidas</Label>
        <button className="btn-outline" onClick={() => player.playQueue(picks, 0)}><Label>Reproducir todo</Label></button>
      </div>
      <div className="quick-picks">
        {picks.map((t) => (
          <button key={t.id} className="row" style={{ gap: 12, textAlign: 'left' }} onClick={() => player.play(t)}>
            <TrackArt track={t} size={48} />
            <div className="col grow" style={{ gap: 2 }}>
              <span className="body ellipsis" style={{ fontSize: 16, fontWeight: 600 }}>{t.title}</span>
              <Label className="ellipsis">{t.channel}</Label>
            </div>
          </button>
        ))}
      </div>
    </section>
  )
}

export function Home() {
  const history = useStore(session, (s) => s.history)
  const favorites = useStore(session, (s) => s.favorites)
  const recent = useMemo(() => history.slice(0, 10), [history])
  return (
    <div className="page">
      <div className="wordmark" style={{ paddingTop: 36 }}>DiegoMusic</div>
      {history[0] && <QuickPicks seed={history[0]} />}
      {recent.length > 0 && (
        <Section title="Escuchado hace poco">
          <Carousel items={recent} onPlay={player.play} />
        </Section>
      )}
      {favorites.length > 0 && (
        <Section title="Favoritos">
          <Carousel items={favorites} onPlay={player.play} />
        </Section>
      )}
      {!recent.length && !favorites.length && (
        <EmptyState title="Tu próxima escucha" text="Busca una canción para empezar. Tu historial y favoritos aparecerán aquí." action="Buscar" onAction={() => navigate({ kind: 'search' })} />
      )}
      <Section title="DiegoMusic para Android">
        <div className="card row" style={{ gap: 14, flexWrap: 'wrap' }}>
          <img src="/icon.png" alt="" width={48} height={48} style={{ border: '1px solid var(--hairline)' }} />
          <div className="col grow" style={{ gap: 4, minWidth: 180 }}>
            <span className="body">La misma app, nativa en tu móvil.</span>
            <Label>Segundo plano · pantalla de bloqueo · descargas · podcasts</Label>
          </div>
          <ApkButton />
        </div>
      </Section>
    </div>
  )
}

// MARK: - Buscar

const RECENT_KEY = 'diegomusic.recentQueries'
const loadRecent = (): string[] => {
  try {
    return JSON.parse(localStorage.getItem(RECENT_KEY) ?? '[]')
  } catch {
    return []
  }
}

type SearchState = { kind: 'idle' } | { kind: 'loading' } | { kind: 'loaded'; items: Track[] } | { kind: 'failed'; message: string }

export function Search() {
  const [query, setQuery] = useState('')
  const [state, setState] = useState<SearchState>({ kind: 'idle' })
  const [recent, setRecent] = useState(loadRecent)
  const run = async (q = query) => {
    const normalized = q.trim()
    if (!normalized) return setState({ kind: 'idle' })
    setState({ kind: 'loading' })
    try {
      const items = await api.search(normalized)
      const updated = [normalized, ...recent.filter((r) => r.toLowerCase() !== normalized.toLowerCase())].slice(0, 10)
      localStorage.setItem(RECENT_KEY, JSON.stringify(updated))
      setRecent(updated)
      setState({ kind: 'loaded', items })
    } catch (e) {
      setState({ kind: 'failed', message: e instanceof Error ? e.message : 'No se pudo completar la búsqueda.' })
    }
  }
  return (
    <div className="page">
      <div className="wordmark" style={{ paddingTop: 12, paddingBottom: 14 }}>Buscar</div>
      <form className="row" style={{ gap: 8 }} onSubmit={(e) => { e.preventDefault(); run() }}>
        <div className="row grow" style={{ height: 44, border: '1px solid var(--hairline)', padding: '0 12px', gap: 10 }}>
          <span className="muted"><Icon name="search" size={15} /></span>
          <input
            className="grow mono"
            style={{ border: 0, outline: 'none', fontSize: 13, height: '100%' }}
            placeholder="CANCIONES, ARTISTAS"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            autoCorrect="off"
            enterKeyHint="search"
          />
          {query && (
            <button type="button" className="icon-btn secondary" style={{ width: 28, height: 28 }} onClick={() => { setQuery(''); setState({ kind: 'idle' }) }} aria-label="Borrar búsqueda">
              <Icon name="close" size={14} />
            </button>
          )}
        </div>
        <button className="btn-inverted" style={{ height: 44, padding: '0 14px' }}>
          <Label>Buscar</Label>
        </button>
      </form>
      <div style={{ marginTop: 10 }}>
        {state.kind === 'idle' &&
          (recent.length ? (
            <div className="col" style={{ gap: 6, marginTop: 12 }}>
              <Label wide>Reciente</Label>
              {recent.map((q) => (
                <button key={q} className="row" style={{ border: '1px solid var(--hairline)', padding: '10px 14px', gap: 12 }} onClick={() => { setQuery(q); run(q) }}>
                  <Label className="grow ellipsis" primary>{q}</Label>
                  <span className="muted">↖</span>
                </button>
              ))}
            </div>
          ) : (
            <EmptyState title="Tu próxima escucha" text="Escribe una consulta para explorar canciones y artistas." />
          ))}
        {state.kind === 'loading' && <Loading text="Sintonizando YouTube…" />}
        {state.kind === 'failed' && <EmptyState title="No llegó la señal" text={state.message} action="Reintentar" onAction={() => run()} />}
        {state.kind === 'loaded' &&
          (state.items.length ? (
            state.items.map((t) => <TrackRow key={t.id} track={t} onPlay={() => player.play(t)} />)
          ) : (
            <EmptyState title="Sin resultados" text="Prueba una consulta distinta." />
          ))}
      </div>
    </div>
  )
}

// MARK: - Artista

export function Artist({ id, name }: { id: string; name: string }) {
  const [detail, setDetail] = useState<ArtistDetail | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)
  useEffect(() => {
    setDetail(null)
    setError(null)
    api.artist(id).then(setDetail).catch((e) => setError(e instanceof Error ? e.message : 'No se pudo cargar el artista.'))
  }, [id, attempt])
  return (
    <div>
      <BackBar label="Artista" />
      <div className="page" style={{ paddingTop: 24 }}>
        {!detail && !error && <Loading text={`Cargando perfil de ${name}…`} />}
        {error && <EmptyState title="Error" text={error} action="Reintentar" onAction={() => setAttempt(attempt + 1)} />}
        {detail && (
          <>
            <div className="col" style={{ alignItems: 'center', gap: 16, textAlign: 'center' }}>
              <div className="art" style={{ width: 150, height: 150 }}>
                {detail.artist.thumbnailURL && <img src={detail.artist.thumbnailURL} alt="" />}
              </div>
              <div className="col" style={{ gap: 6, alignItems: 'center' }}>
                <Label>Artista</Label>
                <Title size={26}>{detail.artist.title || name}</Title>
                {detail.artist.bio && <p className="muted clamp2" style={{ margin: 0, fontSize: 12, maxWidth: 520 }}>{detail.artist.bio}</p>}
              </div>
              <div className="row" style={{ gap: 12 }}>
                <button className="btn-inverted" onClick={() => player.playQueue(detail.topTracks, 0)}>
                  <Icon name="play" size={12} />
                  <Label>Reproducir</Label>
                </button>
                <button className="btn-outline" style={{ padding: '10px 20px' }} onClick={() => player.playQueue([...detail.topTracks].sort(() => Math.random() - 0.5), 0)}>
                  <Icon name="shuffle" size={12} />
                  <Label>Aleatorio</Label>
                </button>
              </div>
            </div>
            <Section title="Éxitos populares">
              {detail.topTracks.length ? (
                <div style={{ border: '1px solid var(--hairline)', padding: '0 8px' }}>
                  {detail.topTracks.slice(0, 10).map((t, i) => (
                    <TrackRow key={t.id} track={t} index={i + 1} onPlay={() => player.playQueue(detail.topTracks, i)} />
                  ))}
                </div>
              ) : (
                <span className="muted">No hay canciones populares disponibles.</span>
              )}
            </Section>
            {detail.related.length > 0 && (
              <Section title="Artistas similares">
                <div className="scroll-x">
                  {detail.related.slice(-6).map((t) => (
                    <button key={t.id} className="tile" style={{ width: 110 }} onClick={() => navigate({ kind: 'artist', id: t.channel, name: t.channel })}>
                      <TrackArt track={t} size={110} />
                      <span className="body ellipsis" style={{ fontSize: 13 }}>{t.channel}</span>
                    </button>
                  ))}
                </div>
              </Section>
            )}
          </>
        )}
      </div>
    </div>
  )
}

// MARK: - Biblioteca

type Segment = 'playlists' | 'songs' | 'artists'
const segments: [Segment, string][] = [['playlists', 'Playlists'], ['songs', 'Canciones'], ['artists', 'Artistas']]

export function Library() {
  const [segment, setSegment] = useState<Segment>(() => (sessionStorage.getItem('library.segment') as Segment) || 'playlists')
  useEffect(() => {
    refreshLibrary()
  }, [])
  const pick = (s: Segment) => {
    sessionStorage.setItem('library.segment', s)
    setSegment(s)
  }
  return (
    <div className="page">
      <div className="row" style={{ position: 'relative', justifyContent: 'center', paddingTop: 12, minHeight: 44 }}>
        <div className="wordmark">Biblioteca</div>
        <button className="icon-btn" style={{ position: 'absolute', right: 0, width: 44, height: 44 }} onClick={() => navigate({ kind: 'settings' })} aria-label="Ajustes">
          <Icon name="gear" size={16} />
        </button>
      </div>
      <div className="scroll-x" style={{ gap: 8, margin: '12px 0' }}>
        {segments.map(([s, title]) => (
          <button key={s} className={`chip ${segment === s ? 'on' : ''}`} onClick={() => pick(s)}>
            <Label>{title}</Label>
          </button>
        ))}
      </div>
      {segment === 'playlists' && <Playlists />}
      {segment === 'songs' && <Songs />}
      {segment === 'artists' && <Artists />}
    </div>
  )
}

function Playlists() {
  const playlists = useStore(session, (s) => s.playlists)
  const [name, setName] = useState('')
  const [open, setOpen] = useState<number | null>(null)
  const create = async (e: FormEvent) => {
    e.preventDefault()
    if (!name.trim()) return
    try {
      const p = await api.createPlaylist(name.trim())
      session.set((s) => ({ playlists: [p, ...s.playlists] }))
      setName('')
    } catch {
      toast('No se pudo crear la playlist')
    }
  }
  const remove = async (p: Playlist) => {
    session.set((s) => ({ playlists: s.playlists.filter((x) => x.id !== p.id) }))
    await api.deletePlaylist(p.id).catch(() => refreshLibrary())
  }
  const removeTrack = async (p: Playlist, t: Track) => {
    session.set((s) => ({ playlists: s.playlists.map((x) => (x.id === p.id ? { ...x, tracks: x.tracks.filter((y) => y.id !== t.id) } : x)) }))
    await api.removeFromPlaylist(p.id, t.id).catch(() => refreshLibrary())
  }
  return (
    <div className="col" style={{ gap: 18 }}>
      <Title size={20}>Playlists</Title>
      <form className="row" style={{ gap: 8 }} onSubmit={create}>
        <input className="field grow" placeholder="Nombre de la nueva playlist" value={name} onChange={(e) => setName(e.target.value)} />
        <button className="btn-primary"><Label>Crear</Label></button>
      </form>
      {!playlists.length && <EmptyState title="Sin playlists" text="Crea una mezcla para empezar." />}
      {playlists.map((p) => (
        <div key={p.id} className="card">
          <div className="row" style={{ gap: 12 }}>
            <button className="row grow" style={{ gap: 12, textAlign: 'left' }} onClick={() => setOpen(open === p.id ? null : p.id)}>
              <div className="art" style={{ width: 44, height: 44, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>♪</div>
              <div className="col grow" style={{ gap: 2 }}>
                <span className="body ellipsis" style={{ fontSize: 15 }}>{p.name}</span>
                <Label>{p.tracks.length} elementos</Label>
              </div>
            </button>
            <button className="icon-btn" onClick={() => player.playQueue(p.tracks, 0)} disabled={!p.tracks.length} aria-label="Reproducir playlist"><Icon name="play" size={16} /></button>
            <button className="icon-btn" onClick={() => remove(p)} aria-label="Eliminar playlist"><Icon name="trash" size={16} /></button>
          </div>
          {open === p.id && (
            <div className="col" style={{ gap: 8, marginTop: 12 }}>
              {!p.tracks.length && <span className="muted">Añade elementos desde Búsqueda.</span>}
              {p.tracks.map((t, i) => (
                <div key={t.id} className="row" style={{ gap: 10 }}>
                  <button className="col grow" style={{ gap: 2, textAlign: 'left' }} onClick={() => player.playQueue(p.tracks, i)}>
                    <span className="body ellipsis">{t.title}</span>
                    <Label className="ellipsis">{t.channel}</Label>
                  </button>
                  <button className="icon-btn" onClick={() => removeTrack(p, t)} aria-label="Eliminar de la playlist"><Icon name="trash" size={16} /></button>
                </div>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  )
}

function Songs() {
  const favorites = useStore(session, (s) => s.favorites)
  if (!favorites.length) return <EmptyState title="Sin canciones" text="Guarda canciones desde Búsqueda para verlas aquí." />
  return (
    <div>
      {favorites.map((t, i) => (
        <TrackRow key={t.id} track={t} index={i + 1} onPlay={() => player.playQueue(favorites, i)} />
      ))}
    </div>
  )
}

function Artists() {
  const favorites = useStore(session, (s) => s.favorites)
  const history = useStore(session, (s) => s.history)
  const artists = useMemo(() => {
    const groups = new Map<string, Track[]>()
    for (const t of [...favorites, ...history]) groups.set(t.channel, [...(groups.get(t.channel) ?? []), t])
    return [...groups.entries()].filter(([n]) => n).sort(([a], [b]) => a.localeCompare(b, 'es', { sensitivity: 'base' }))
  }, [favorites, history])
  if (!artists.length) return <EmptyState title="Sin artistas en la biblioteca" text="Guarda o reproduce canciones para organizarlas por artista automáticamente." />
  return (
    <div className="col" style={{ gap: 16 }}>
      <Label wide>Artistas guardados</Label>
      <div className="grid2">
        {artists.map(([name, tracks]) => (
          <button key={name} className="col" style={{ border: '1px solid var(--hairline)', padding: 12, gap: 12, alignItems: 'center' }} onClick={() => navigate({ kind: 'artist', id: name, name })}>
            <TrackArt track={tracks[0]} size="100%" />
            <span className="body ellipsis" style={{ maxWidth: '100%' }}>{name}</span>
            <Label>{tracks.length === 1 ? '1 canción' : `${tracks.length} canciones`}</Label>
          </button>
        ))}
      </div>
    </div>
  )
}

// MARK: - Ajustes

export function Settings() {
  const user = useStore(session, (s) => s.user)
  const theme = useStore(ui, (s) => s.theme)
  return (
    <div>
      <BackBar label="Ajustes" />
      <div className="page col" style={{ gap: 24, maxWidth: 900, paddingTop: 16 }}>
        <Title size={20}>Ajustes</Title>
        <div className="card col" style={{ gap: 14 }}>
          <Label>Cuenta de usuario</Label>
          {user && (
            <div className="row" style={{ gap: 16, flexWrap: 'wrap' }}>
              <div className="art" style={{ width: 44, height: 44, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <span className="title" style={{ fontSize: 16 }}>{(user.full_name || user.email).slice(0, 1)}</span>
              </div>
              <div className="col grow" style={{ gap: 2 }}>
                <span className="body">{user.full_name || 'Usuario DiegoMusic'}</span>
                <Label className="ellipsis">{user.email}</Label>
              </div>
              <button className="btn-primary" onClick={logout}><Label>Cerrar sesión</Label></button>
            </div>
          )}
        </div>
        <div className="card col" style={{ gap: 14 }}>
          <Label>Apariencia</Label>
          <span className="muted" style={{ fontSize: 15 }}>Selecciona la apariencia preferida para la interfaz de la aplicación.</span>
          <div className="segmented">
            {(['black', 'white'] as const).map((t) => (
              <button key={t} className={theme === t ? 'on' : ''} onClick={() => setTheme(t)}>
                <Label primary>{t === 'black' ? 'Negro' : 'Blanco'}</Label>
              </button>
            ))}
          </div>
        </div>
        <div className="card col" style={{ gap: 14 }}>
          <Label>DiegoMusic para Android</Label>
          <span className="muted" style={{ fontSize: 15 }}>App nativa con reproducción en segundo plano, pantalla de bloqueo, podcasts y descargas offline. Android 8 o superior.</span>
          <ApkButton full />
        </div>
        <div className="card col" style={{ gap: 10 }}>
          <Label>Acerca de DiegoMusic</Label>
          <span className="body" style={{ fontSize: 15 }}>Proyecto privado. El audio se resuelve en un VPS propio y se entrega mediante sesiones temporales.</span>
          <span className="muted" style={{ fontSize: 12 }}>No es una aplicación oficial ni está afiliada con YouTube o Google.</span>
        </div>
      </div>
    </div>
  )
}

