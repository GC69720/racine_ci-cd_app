import { useEffect, useState } from 'react'

export default function App() {
  const [api, setApi] = useState<string>('...')
  useEffect(() => {
    fetch('/api/healthz', { credentials: 'include' })
      .then(r => r.json())
      .then(d => setApi(JSON.stringify(d)))
      .catch(() => setApi('erreur'))
  }, [])
  return (
    <div style={{ fontFamily: 'system-ui, sans-serif', padding: 24 }}>
      <h1>racine_ci-cd_app — Frontend React</h1>
      <p>Statut API backend: <code>{api}</code></p>
      <p>Ce frontend est servi par Nginx, et l'API est proxifiée sur <code>/api/</code>.</p>
    </div>
  )
}
