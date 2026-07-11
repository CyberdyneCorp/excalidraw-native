import { svelte } from "@sveltejs/vite-plugin-svelte";
import { defineConfig } from "vite";

export default defineConfig({
  plugins: [svelte()],
  server: { port: 5180 },
  build: {
    rollupOptions: {
      // The embed page exercises the public embedding API (uiOptions, view
      // mode, theming, slots) the way a third-party client would.
      input: { main: "index.html", embed: "embed.html" },
    },
  },
});
