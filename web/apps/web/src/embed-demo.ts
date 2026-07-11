// A second entry point that mounts the editor the way a *client* would: with
// custom uiOptions, view mode, theming, and slots — driven by URL parameters
// so the E2E suite can exercise the public embedding API.
import { mount } from "svelte";
import EmbedDemo from "./EmbedDemo.svelte";

mount(EmbedDemo, { target: document.getElementById("app")! });
