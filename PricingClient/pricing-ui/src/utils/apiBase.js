// #baseUrlApi: usa el mismo host desde el que se sirve el frontend (útil al entrar
// desde otro dispositivo en la red, ej. celular, donde "localhost" apuntaría al propio dispositivo).
// #tunelDevTunnels: un túnel público le da un subdominio DISTINTO a cada puerto (no es el
// mismo host con :5000 al final, como pasa en red local) -- si el frontend se sirve desde
// un host "*-5173.<region>.devtunnels.ms", la API está en "*-5000.<region>.devtunnels.ms".
const construirApiBaseUrl = () => {
  const { hostname } = window.location
  const matchTunel = hostname.match(/^(.+)-5173\.(.+\.devtunnels\.ms)$/)
  if (matchTunel) return `https://${matchTunel[1]}-5000.${matchTunel[2]}`
  return `http://${hostname}:5000`
}

// #apiEnTiempoDeEjecucion: el ejecutable del Cliente (PricingCliente.exe) inyecta esta
// variable al servir index.html, para poder apuntar a un Motor en otra PC sin recompilar.
export const API_BASE_URL =
  globalThis.__PRICING_API_BASE__ || import.meta.env.VITE_API_BASE_URL || construirApiBaseUrl()
