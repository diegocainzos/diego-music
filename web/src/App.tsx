import { useEffect, useState } from 'react'
import { ExpandedPlayer, MiniPlayer } from './player.tsx'
import { Artist, AuthGate, Home, Library, Search, Settings } from './screens.tsx'
import { bootstrap, goBack, nav, playback, selectTab, session, tabs, ui, useStore } from './store.ts'
import { Icon, Label, Spinner } from './ui.tsx'

export default function App() {
  const theme = useStore(ui, (s) => s.theme)
  const status = useStore(session, (s) => s.status)
  useEffect(() => {
    document.documentElement.dataset.theme = theme
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', theme === 'white' ? '#ffffff' : '#000000')
  }, [theme])
  useEffect(() => {
    bootstrap()
  }, [])
  if (status === 'loading') {
    return (
      <div className="col" style={{ height: '100%', alignItems: 'center', justifyContent: 'center', gap: 16 }}>
        <div className="wordmark">DiegoMusic</div>
        <Spinner />
      </div>
    )
  }
  return status === 'authenticated' ? <Shell /> : <AuthGate />
}

/** Barra lateral en escritorio y tres pestañas en móvil, con el mini‑player flotante encima. */
function Shell() {
  const current = useStore(nav, (s) => s.current)
  const resetKey = useStore(nav, (s) => s.resetKey)
  const hasTrack = useStore(playback, (s) => s.index != null)
  const toast = useStore(ui, (s) => s.toast)
  const online = useStore(ui, (s) => s.online)
  const [expanded, setExpanded] = useState(false)
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Backspace' && e.altKey && goBack()
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])
  const tabButtons = tabs.map((t) => (
    <button key={t.kind} className={current.kind === t.kind ? 'on' : ''} onClick={() => selectTab(t.kind)} aria-label={t.title}>
      <Label primary={current.kind === t.kind}>{t.title}</Label>
    </button>
  ))
  return (
    <div className="shell">
      <nav className="sidebar">
        <div className="wordmark" style={{ padding: '8px 0 20px' }}>DiegoMusic</div>
        {tabButtons}
      </nav>
      <div className="main">
        {!online && (
          <div className="offline row" style={{ justifyContent: 'center', gap: 8 }}>
            <Icon name="wifiOff" size={12} />
            <Label primary>Sin conexión</Label>
          </div>
        )}
        <main className="content" style={{ ['--inset' as string]: hasTrack ? '72px' : '0px' }} key={`${JSON.stringify(current)}-${resetKey}`}>
          {current.kind === 'home' && <Home />}
          {current.kind === 'search' && <Search />}
          {current.kind === 'library' && <Library />}
          {current.kind === 'artist' && <Artist id={current.id} name={current.name} />}
          {current.kind === 'settings' && <Settings />}
        </main>
        <div style={{ position: 'relative' }}>{hasTrack && <MiniPlayer onExpand={() => setExpanded(true)} />}</div>
        <nav className="tabbar">{tabButtons}</nav>
      </div>
      {expanded && hasTrack && <ExpandedPlayer onClose={() => setExpanded(false)} />}
      {toast && (
        <div className="toast" role="status">
          <Label>{toast}</Label>
        </div>
      )}
    </div>
  )
}
