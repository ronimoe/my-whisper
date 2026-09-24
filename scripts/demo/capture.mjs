// Renders scripts/demo/demo.html frame by frame in one headless Chrome (driven
// over the DevTools protocol) and writes PNGs. Used by make-gif.sh.
// usage: node capture.mjs <outDir> <fps> <seconds> [scale]
import { spawn } from "node:child_process";
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const [outDir, fps, duration, scale] = [process.argv[2], +process.argv[3], +process.argv[4], +(process.argv[5] || 2)];
mkdirSync(outDir, { recursive: true });
const port = 9333;
const chrome = spawn("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome", [
  "--headless=new", `--remote-debugging-port=${port}`, `--user-data-dir=${outDir}/.chrome-profile`,
  "--no-first-run", "--hide-scrollbars", "about:blank"], { stdio: "ignore" });

try {
  let target;
  for (let i = 0; i < 50 && !target; i++) {
    try { target = (await (await fetch(`http://127.0.0.1:${port}/json/list`)).json()).find(t => t.type === "page"); }
    catch { await new Promise(r => setTimeout(r, 200)); }
  }
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise(r => ws.addEventListener("open", r, { once: true }));
  let id = 0; const pending = new Map();
  ws.addEventListener("message", e => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } });
  const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });

  await send("Emulation.setDeviceMetricsOverride", { width: 960, height: 600, deviceScaleFactor: scale, mobile: false });
  await send("Page.enable");
  await send("Page.navigate", { url: `file://${here}/demo.html#t=0` });
  await new Promise(r => setTimeout(r, 1500));

  const times = Array.from({ length: Math.round(fps * duration) }, (_, i) => i / fps);
  for (const [i, t] of times.entries()) {
    await send("Runtime.evaluate", { expression: `render(${t})` });
    const shot = await send("Page.captureScreenshot", { format: "png" });
    const name = `f${String(i).padStart(4, "0")}.png`;
    writeFileSync(`${outDir}/${name}`, Buffer.from(shot.result.data, "base64"));
  }
  console.log(`captured ${times.length} frames -> ${outDir}`);
  ws.close();
} finally { chrome.kill(); }
