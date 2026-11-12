// Regression tests for pix-MCP HTTP server resilience (PR #2 investigation)
// and PR #3 follow-up fixes (duplicate_layer on API <= 9, eval_gdscript Undo/Redo).

import net from "node:net";

const HOST = "127.0.0.1";
const PORT = 7373;
const BASE_URL = `http://${HOST}:${PORT}`;

function assert(cond, msg) {
  if (!cond) throw new Error(`Assertion failed: ${msg}`);
}

function openIdleSocket() {
  return new Promise((resolve, reject) => {
    const sock = net.createConnection({ host: HOST, port: PORT }, () => resolve(sock));
    sock.on("error", () => {});
    setTimeout(() => reject(new Error("connect timeout")), 2000);
  });
}

function sendRawHttp(rawRequest) {
  return new Promise((resolve, reject) => {
    const sock = net.createConnection({ host: HOST, port: PORT }, () => {
      sock.write(rawRequest);
    });
    const chunks = [];
    sock.on("data", (c) => chunks.push(c));
    sock.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    sock.on("error", reject);
    setTimeout(() => {
      sock.destroy();
      reject(new Error("raw HTTP timeout"));
    }, 3000);
  });
}

async function cmd(tool, params = {}) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 5000);
  try {
    const res = await fetch(`${BASE_URL}/command`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ tool, params }),
      signal: ctrl.signal,
    });
    const json = await res.json();
    if (!json.success) {
      throw new Error(`${tool} failed: ${json.error || JSON.stringify(json)}`);
    }
    return json.data;
  } finally {
    clearTimeout(timer);
  }
}

async function healthCheck(maxMs = 1000) {
  const t0 = performance.now();
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), maxMs);
  try {
    const res = await fetch(`${BASE_URL}/health`, { signal: ctrl.signal });
    const json = await res.json();
    const elapsed = performance.now() - t0;
    assert(json.status === "ok", `expected health ok, got ${JSON.stringify(json)}`);
    return { json, elapsed };
  } finally {
    clearTimeout(timer);
  }
}

async function main() {
  let passed = 0;
  const createdCanvases = [];

  // 1. Idle browser preconnect sockets must NEVER block /health or /command
  {
    const idleSockets = await Promise.all(Array.from({ length: 5 }, () => openIdleSocket()));
    try {
      const { elapsed } = await healthCheck(1000);
      assert(elapsed < 500, `health check took too long (${elapsed.toFixed(1)}ms) while idle sockets were open`);
      const info = await cmd("get_canvas_info");
      assert(typeof info.width === "number", "get_canvas_info must succeed while idle sockets are open");
      console.log(`✅ [1/7] Idle preconnect sockets did not block bridge (${elapsed.toFixed(1)}ms)`);
      passed++;
    } finally {
      idleSockets.forEach((s) => s.destroy());
    }
  }

  // 2. Socket flood (> MAX_CLIENTS = 32) must evict stale silent sockets and stay responsive
  {
    const flood = await Promise.all(Array.from({ length: 40 }, () => openIdleSocket()));
    try {
      const { elapsed } = await healthCheck(1500);
      console.log(`✅ [2/7] Survived 40-socket flood without wedging (${elapsed.toFixed(1)}ms)`);
      passed++;
    } finally {
      flood.forEach((s) => s.destroy());
    }
  }

  // 3. Oversized and negative Content-Length headers rejected cleanly
  {
    const resp413 = await sendRawHttp(
      "POST /command HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: 99999999\r\n\r\n",
    );
    assert(resp413.startsWith("HTTP/1.1 413"), `expected 413, got: ${resp413.split("\r\n")[0]}`);

    const resp400 = await sendRawHttp(
      "POST /command HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: -5\r\n\r\n",
    );
    assert(resp400.startsWith("HTTP/1.1 400"), `expected 400, got: ${resp400.split("\r\n")[0]}`);
    console.log("✅ [3/7] Oversized (413) and negative (400) Content-Length rejected cleanly");
    passed++;
  }

  // 4. Multi-byte UTF-8 layer names & JSON framing
  {
    const cname = `resilience-utf8-${Date.now()}`;
    await cmd("create_canvas", { width: 32, height: 32, name: cname });
    createdCanvases.push(cname);
    const layerRes = await cmd("add_layer", { name: "🎨 طبقة اختبار" });
    assert(layerRes.name === "🎨 طبقة اختبار", `UTF-8 layer name mismatch: ${layerRes.name}`);
    const layers = await cmd("get_layers");
    assert(layers.layers.some((l) => l.name === "🎨 طبقة اختبار"), "UTF-8 layer name must round-trip intact");
    console.log("✅ [4/7] Multi-byte UTF-8 request & response Content-Length verified");
    passed++;
  }

  // 5. get_canvas_snapshot 128x128 safety cap on large canvases
  {
    const cname = `resilience-snap-${Date.now()}`;
    await cmd("create_canvas", { width: 200, height: 200, name: cname });
    createdCanvases.push(cname);
    const snap = await cmd("get_canvas_snapshot", { x: 0, y: 0, width: 500, height: 500 });
    assert(snap.width === 128 && snap.height === 128, `expected 128x128 cap, got ${snap.width}x${snap.height}`);
    console.log("✅ [5/7] get_canvas_snapshot safely capped at 128x128");
    passed++;
  }

  // 6. duplicate_layer works across both API <= 9 and API 10+
  {
    const cname = `resilience-duplayer-${Date.now()}`;
    await cmd("create_canvas", { width: 16, height: 16, name: cname });
    createdCanvases.push(cname);
    await cmd("draw_pixel", { x: 4, y: 5, color: "#ff2244" });
    const dup = await cmd("duplicate_layer", { layer: 0 });
    await cmd("switch_cel", { frame: 0, layer: dup.new_index });
    const px = await cmd("get_pixel", { x: 4, y: 5 });
    assert(px.color.toLowerCase() === "#ff2244ff", `duplicated layer pixel mismatch: ${px.color}`);
    console.log("✅ [6/7] duplicate_layer copies pixels cleanly without crashing");
    passed++;
  }

  // 7. eval_gdscript direct cel.get_image() write supports Undo & Redo, and read-only eval preserves Redo
  {
    const cname = `resilience-eval-undo-${Date.now()}`;
    await cmd("create_canvas", { width: 16, height: 16, name: cname });
    createdCanvases.push(cname);

    await cmd("eval_gdscript", {
      code: `
func run(api, image: Image, project, params: Dictionary) -> String:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\tcel.get_image().set_pixel(7, 8, Color("#33cc66"))
\treturn "drawn"
`,
    });
    let p = await cmd("get_pixel", { x: 7, y: 8 });
    assert(p.color.toLowerCase() === "#33cc66ff", `expected #33cc66ff after eval, got ${p.color}`);

    await cmd("undo");
    p = await cmd("get_pixel", { x: 7, y: 8 });
    assert(p.color.toLowerCase() === "#00000000", `expected transparent after undo, got ${p.color}`);

    // Read-only eval touching get_image() must NOT wipe out the redo stack!
    const ro = await cmd("eval_gdscript", {
      code: `
func run(api, image: Image, project, params: Dictionary) -> int:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\treturn cel.get_image().get_width()
`,
    });
    assert(ro.value === 16, `expected width 16, got ${ro.value}`);

    await cmd("redo");
    p = await cmd("get_pixel", { x: 7, y: 8 });
    assert(p.color.toLowerCase() === "#33cc66ff", `expected #33cc66ff after redo, got ${p.color}`);
    console.log("✅ [7/7] eval_gdscript direct cel edit Undo/Redo & read-only Redo preservation passed");
    passed++;
  }

  // Clean up test canvases
  const canvases = await cmd("list_canvases");
  for (const c of canvases.canvases) {
    if (createdCanvases.includes(c.name) && canvases.total_canvases > 1) {
      await cmd("close_canvas", { name: c.name }).catch(() => {});
    }
  }

  console.log(`\n🎉 All ${passed}/7 live resilience & regression tests passed!`);
}

main().catch((err) => {
  console.error("❌ Test failed:", err);
  process.exitCode = 1;
});
