import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    // #tunelDevTunnels: Vite rechaza pedidos con un Host que no reconoce -- necesario para
    // ver la app desde afuera de la red local a través de un túnel público (Microsoft Dev
    // Tunnels), que llega con un Host tipo *.devtunnels.ms en vez de localhost/IP privada.
    allowedHosts: ['.devtunnels.ms'],
  },
  preview: {
    host: '0.0.0.0',
    port: 4173,
  },
})
