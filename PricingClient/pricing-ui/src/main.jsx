import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import './index.css'
import './utils/authFetch.js'
import App from './App.jsx'
import RepositorApp from './components/RepositorApp.jsx'
import LoginGate from './components/LoginGate.jsx'

// #arranqueApp: punto de entrada React; BrowserRouter habilita las rutas de la UI.
// #cargaOperativaRepositor: /repositor/* es un árbol de rutas aparte, sin el layout de
// admin (sidebar/header) ni el login general — tiene su propio login (Usuario+PIN) y
// protege una superficie de endpoints distinta.
// #loginGeneralApp: authFetch.js se importa antes que nada por su efecto lateral (agrega
// el Authorization Bearer a cada fetch contra la API); LoginGate envuelve solo el árbol
// de App, nunca RepositorApp.
createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BrowserRouter>
      <Routes>
        <Route path="/repositor/*" element={<RepositorApp />} />
        <Route
          path="/*"
          element={
            <LoginGate>{(accountMenu) => <App accountMenu={accountMenu} />}</LoginGate>
          }
        />
      </Routes>
    </BrowserRouter>
  </StrictMode>,
)
