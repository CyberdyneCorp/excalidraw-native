import { startRelay } from "./server.js";

// Standalone relay entry point (unconditional start), used by the collab
// orchestrator and for local manual runs: `PORT=4399 node <bundled>`.
const port = Number(process.env.PORT ?? 3001);
const { wss } = startRelay(port);
wss.on("listening", () => console.log(`relay listening on :${port}`));
