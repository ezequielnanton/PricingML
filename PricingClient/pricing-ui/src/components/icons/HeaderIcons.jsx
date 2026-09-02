// #iconosDeColorEnToolbar: a diferencia de los íconos de línea del menú lateral
// (NavIcons.jsx, que heredan currentColor), estos van con color propio fijo -- así lo
// pidió el usuario explícitamente (verde/celeste para Sincronización, azul para la
// cuenta), no son parte de la paleta de la app.

// #iconoSincronizar: dos flechas en círculo (una verde, una celeste) -- el símbolo
// habitual de "sincronizar/actualizar", cada mitad de un color distinto.
export function SyncIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 20 20" aria-hidden="true">
      <path
        d="M16.5 10a6.5 6.5 0 0 0-11-4.7"
        fill="none"
        stroke="#25a55a"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M3.6 3.2v3.9h3.9" fill="none" stroke="#25a55a" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
      <path
        d="M3.5 10a6.5 6.5 0 0 0 11 4.7"
        fill="none"
        stroke="#2fb6d9"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M16.4 16.8v-3.9h-3.9" fill="none" stroke="#2fb6d9" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

// #iconoUsuarioEstiloMsn: círculo azul sólido con una silueta blanca -- el clásico
// "muñequito" de Messenger en vez de un ícono de línea, tal como se pidió.
export function UserBadgeIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 22 22" aria-hidden="true">
      <circle cx="11" cy="11" r="10" fill="#2f7dd1" stroke="#1c5aa8" strokeWidth="1" />
      <circle cx="11" cy="8.7" r="3.1" fill="#ffffff" />
      <path d="M4.3 17.3c0.9-3.2 3.5-4.9 6.7-4.9s5.8 1.7 6.7 4.9" fill="#ffffff" />
    </svg>
  )
}
