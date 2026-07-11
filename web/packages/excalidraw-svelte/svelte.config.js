import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";

export default {
  // The UI components are TypeScript-flavoured Svelte 5 (runes).
  preprocess: vitePreprocess(),
};
