import { defineConfig } from 'vite';

// Vite config for the Sistema de Pedidos de Produccion frontend.
// The app is plain HTML/CSS/JS (no framework) - Vite is used only to:
//   1. Bundle ES modules under src/
//   2. Inject VITE_* environment variables safely at build time
//   3. Produce an optimized `dist/` build ready for Vercel static hosting
export default defineConfig({
  root: '.',
  build: {
    outDir: 'dist',
    emptyOutDir: true
  },
  server: {
    port: 5173,
    open: true
  }
});
