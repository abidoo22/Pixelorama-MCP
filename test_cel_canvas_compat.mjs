// Regression coverage for Pixelorama 1.2.4's compact PixelCel images.
// Run only against a dedicated Pixelorama test instance: create_canvas replaces
// its active project. This test deliberately does not run as part of npm test.

const BRIDGE_URL = process.env.PIXELORAMA_MCP_URL ?? "http://127.0.0.1:7373";

async function command(tool, params = {}) {
  const response = await fetch(`${BRIDGE_URL}/command`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ tool, params }),
  });
  const result = await response.json();
  if (!result.success) {
    throw new Error(`${tool} failed: ${result.error ?? JSON.stringify(result)}`);
  }
  return result.data;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function pixel(x, y, expected) {
  const result = await command("get_pixel", { x, y });
  assert(
    result.color.toLowerCase() === expected.toLowerCase(),
    `pixel (${x},${y}): expected ${expected}, got ${result.color}`,
  );
}

async function main() {
  const suffix = `${Date.now()}`;

  // New blank cels may internally be 1x1 although the project is 64x64.
  await command("create_canvas", {
    width: 64,
    height: 64,
    name: `cel-compat-empty-${suffix}`,
  });
  const rect = await command("draw_rect", {
    x: 10,
    y: 12,
    width: 4,
    height: 3,
    color: "#e74c3c",
    filled: true,
  });
  assert(rect.pixels_drawn === 12, "draw_rect must draw all 12 pixels in canvas coordinates");
  await pixel(10, 12, "#e74c3cff");
  await pixel(13, 14, "#e74c3cff");
  await pixel(14, 14, "#00000000");

  // The batched fast path must use the same canvas bounds as draw_rect.
  const fast = await command("draw_pixels_fast", {
    data: [0, 63, "#00ffff", 63, 0, "#00ffff", 63, 63, "#00ffff"],
  });
  assert(fast.pixels_drawn === 3, "draw_pixels_fast must accept canvas edge coordinates");
  assert(fast.pixels_clipped === 0, "valid edge coordinates must not be clipped");
  await pixel(0, 63, "#00ffffff");
  await pixel(63, 0, "#00ffffff");
  await pixel(63, 63, "#00ffffff");

  // create_canvas(fill_color) must cover the requested project size even when
  // Pixelorama initialized the new cel with its compact 1x1 empty image.
  await command("create_canvas", {
    width: 64,
    height: 64,
    name: `cel-compat-fill-${suffix}`,
    fill_color: "#123456",
  });
  await pixel(63, 63, "#123456ff");

  // A negative offset with pixels outside the canvas must survive an edit.
  await command("create_canvas", {
    width: 64,
    height: 64,
    name: `cel-compat-negative-offset-${suffix}`,
  });
  const negativeSetup = await command("eval_gdscript", {
    code: `
func run(api, image: Image, project, params: Dictionary) -> Array:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\tcel.change_offset(Vector2i(-2, -3))
\tcel.get_image().set_pixel(0, 0, Color("#aa55cc"))
\treturn [cel.offset.x, cel.offset.y]
`,
  });
  assert(negativeSetup.value[0] === -2 && negativeSetup.value[1] === -3,
    "negative cel offset setup must be retained");
  const negativeDraw = await command("draw_rect", {
    x: 5,
    y: 6,
    width: 2,
    height: 2,
    color: "#ff8800",
    filled: true,
  });
  assert(negativeDraw.pixels_drawn === 4, "draw_rect must use canvas coordinates with a negative cel offset");
  await pixel(5, 6, "#ff8800ff");
  await pixel(4, 6, "#00000000");
  const outsideAfterEdit = await command("eval_gdscript", {
    code: `
func run(api, image: Image, project, params: Dictionary) -> Array:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\tvar color = cel.get_image().get_pixel(0, 0).to_html(true)
\treturn [cel.offset.x, cel.offset.y, color]
`,
  });
  assert(outsideAfterEdit.value[0] < 0 && outsideAfterEdit.value[1] < 0,
    "editing must preserve the negative cel offset");
  assert(outsideAfterEdit.value[2].toLowerCase() === "aa55ccff",
    "editing must preserve image pixels outside the canvas");

  // Positive offsets must map canvas coordinates to the right local pixels;
  // undo/redo must restore both the pixels and the offset-bearing cel state.
  await command("create_canvas", {
    width: 64,
    height: 64,
    name: `cel-compat-positive-offset-${suffix}`,
  });
  const positiveSetup = await command("eval_gdscript", {
    code: `
func run(api, image: Image, project, params: Dictionary) -> Array:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\tcel.change_offset(Vector2i(20, 18))
\tcel.get_image().set_pixel(0, 0, Color("#abcdef"))
\timage.set_pixel(20, 18, Color("#abcdef"))
\treturn [cel.offset.x, cel.offset.y]
`,
  });
  assert(positiveSetup.value[0] === 20 && positiveSetup.value[1] === 18,
    "positive cel offset setup must be retained");
  const positiveDraw = await command("draw_rect", {
    x: 24,
    y: 22,
    width: 2,
    height: 2,
    color: "#00ff00",
    filled: true,
  });
  assert(positiveDraw.pixels_drawn === 4, "draw_rect must translate through a positive cel offset");
  await pixel(20, 18, "#abcdefff");
  await pixel(24, 22, "#00ff00ff");
  await pixel(4, 4, "#00000000");

  await command("undo");
  await pixel(20, 18, "#abcdefff");
  await pixel(24, 22, "#00000000");
  await command("redo");
  await pixel(20, 18, "#abcdefff");
  await pixel(24, 22, "#00ff00ff");

  const fastWithOffset = await command("draw_pixels_fast", {
    data: [0, 63, "#00ffff", 63, 0, "#00ffff", 63, 63, "#00ffff"],
  });
  assert(fastWithOffset.pixels_drawn === 3 && fastWithOffset.pixels_clipped === 0,
    "draw_pixels_fast must honor canvas edges with a positive cel offset");
  await pixel(0, 63, "#00ffffff");
  await pixel(63, 0, "#00ffffff");
  await pixel(63, 63, "#00ffffff");
  await command("draw_pixel", { x: 25, y: 23, color: "#00000000" });
  await pixel(25, 23, "#00000000");


  // Undo/redo must restore the offset itself, not just image data. Here the
  // edit moves the offset (20,18) -> (5,5) because shrink_to_content re-anchors
  // the cel on the new used rect; without offset capture in undo data, undo
  // would leave the restored 1x1 pixel at canvas (5,5) instead of (20,18).
  await command("create_canvas", {
    width: 64,
    height: 64,
    name: `cel-compat-offset-undo-${suffix}`,
  });
  await command("eval_gdscript", {
    code: `
func run(api, image: Image, project, params: Dictionary) -> Array:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\tcel.change_offset(Vector2i(20, 18))
\tcel.get_image().set_pixel(0, 0, Color("#abcdef"))
\treturn [cel.offset.x, cel.offset.y]
`,
  });
  await command("draw_rect", {
    x: 5, y: 5, width: 1, height: 1, color: "#112233", filled: true,
  });
  const offsetAfterDraw = await command("eval_gdscript", {
    code: `
func run(api, image: Image, project, params: Dictionary) -> Array:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\treturn [cel.offset.x, cel.offset.y]
`,
  });
  assert(offsetAfterDraw.value[0] === 5 && offsetAfterDraw.value[1] === 5,
    `draw must re-anchor offset to used rect (5,5), got ${offsetAfterDraw.value}`);
  await pixel(20, 18, "#abcdefff");
  await pixel(5, 5, "#112233ff");
  await command("undo");
  const offsetAfterUndo = await command("eval_gdscript", {
    code: `
func run(api, image: Image, project, params: Dictionary) -> Array:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\treturn [cel.offset.x, cel.offset.y]
`,
  });
  assert(offsetAfterUndo.value[0] === 20 && offsetAfterUndo.value[1] === 18,
    `undo must restore cel offset (20,18), got ${offsetAfterUndo.value}`);
  await pixel(20, 18, "#abcdefff");
  await pixel(5, 5, "#00000000");
  await command("redo");
  const offsetAfterRedo = await command("eval_gdscript", {
    code: `
func run(api, image: Image, project, params: Dictionary) -> Array:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\treturn [cel.offset.x, cel.offset.y]
`,
  });
  assert(offsetAfterRedo.value[0] === 5 && offsetAfterRedo.value[1] === 5,
    `redo must restore cel offset (5,5), got ${offsetAfterRedo.value}`);
  await pixel(20, 18, "#abcdefff");
  await pixel(5, 5, "#112233ff");

  // Erasing every visible pixel must yield full transparency on canvas.
  await command("draw_pixel", { x: 5, y: 5, color: "#00000000" });
  await command("draw_pixel", { x: 20, y: 18, color: "#00000000" });
  await pixel(5, 5, "#00000000");
  await pixel(20, 18, "#00000000");
  await pixel(32, 32, "#00000000");

  // Pixels beyond the right/bottom canvas edges must also survive an edit,
  // and fill_area must operate in canvas coordinates with a positive offset.
  await command("create_canvas", {
    width: 64,
    height: 64,
    name: `cel-compat-fill-offset-${suffix}`,
  });
  await command("eval_gdscript", {
    code: `
func run(api, image: Image, project, params: Dictionary) -> Array:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\tcel.change_offset(Vector2i(10, 10))
\tvar img = cel.get_image()
\timg.resize(70, 70)
\timg.set_pixel(0, 0, Color("#abcdef"))
\timg.set_pixel(60, 60, Color("#fedcba"))
\tcel.update_texture()
\treturn [cel.offset.x, cel.offset.y, img.get_width(), img.get_height()]
`,
  });
  const fill = await command("fill_area", { x: 0, y: 0, color: "#334455" });
  assert(fill.pixels_filled === 64 * 64 - 1,
    `fill_area must fill the transparent canvas around the marker, got ${fill.pixels_filled}`);
  await pixel(0, 0, "#334455ff");
  await pixel(63, 63, "#334455ff");
  await pixel(10, 10, "#abcdefff");
  const beyondAfterFill = await command("eval_gdscript", {
    code: `
func run(api, image: Image, project, params: Dictionary) -> Array:
\tvar cel = project.frames[project.current_frame].cels[project.current_layer]
\tvar img = cel.get_image()
\tvar local = Vector2i(70, 70) - cel.offset
\tvar color = ""
\tif local.x >= 0 and local.y >= 0 and local.x < img.get_width() and local.y < img.get_height():
\t\tcolor = img.get_pixel(local.x, local.y).to_html(true)
\treturn [cel.offset.x, cel.offset.y, color, local.x, local.y]
`,
  });
  assert(beyondAfterFill.value[2].toLowerCase() === "fedcbaff",
    "fill/edit must preserve image pixels beyond the right/bottom canvas edges");

  console.log("Cel canvas compatibility regressions passed.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
