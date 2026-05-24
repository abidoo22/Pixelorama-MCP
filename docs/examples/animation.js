/**
 * generate_procedural_idle.js
 * Reads a transparent or green-screen sprite, processes its pixels,
 * and procedurally generates a 6-frame "Idle Breathing" animation 
 * inside Pixelorama via sinusoidal vertex stretching.
 * NOTE: All comments are in English only.
 */

const fs = require('fs');
const zlib = require('zlib');

const BRIDGE_URL = "http://127.0.0.1:7373";

function paethPredictor(a, b, c) {
    const p = a + b - c;
    const pa = Math.abs(p - a);
    const pb = Math.abs(p - b);
    const pc = Math.abs(p - c);
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

function decodePNG(buffer) {
    const signature = buffer.subarray(0, 8).toString('hex');
    if (signature !== '89504e470d0a1a0a') throw new Error("Not a valid PNG file.");

    let offset = 8;
    let width, height, colorType, bpp;
    const idatBuffers = [];

    while (offset < buffer.length) {
        const length = buffer.readUInt32BE(offset);
        const type = buffer.subarray(offset + 4, offset + 8).toString('ascii');
        const data = buffer.subarray(offset + 8, offset + 8 + length);
        offset += length + 12;

        if (type === 'IHDR') {
            width = data.readUInt32BE(0);
            height = data.readUInt32BE(4);
            colorType = data.readUInt8(9);
            bpp = (colorType === 6) ? 4 : (colorType === 2) ? 3 : 0;
            if (bpp === 0) throw new Error("Only standard RGB/RGBA PNGs are supported.");
        } else if (type === 'IDAT') {
            idatBuffers.push(data);
        } else if (type === 'IEND') {
            break;
        }
    }

    const compressed = Buffer.concat(idatBuffers);
    const inflated = zlib.inflateSync(compressed);

    const out = Buffer.alloc(width * height * bpp);
    const rowSize = width * bpp;
    let pos = 0;

    for (let y = 0; y < height; y++) {
        const filter = inflated[pos++];
        for (let x = 0; x < rowSize; x++) {
            const raw = inflated[pos++];
            const left = (x >= bpp) ? out[y * rowSize + x - bpp] : 0;
            const up = (y > 0) ? out[(y - 1) * rowSize + x] : 0;
            const upLeft = (x >= bpp && y > 0) ? out[(y - 1) * rowSize + x - bpp] : 0;

            let val = raw;
            if (filter === 1) val += left;
            else if (filter === 2) val += up;
            else if (filter === 3) val += Math.floor((left + up) / 2);
            else if (filter === 4) val += paethPredictor(left, up, upLeft);
            
            out[y * rowSize + x] = val & 0xff;
        }
    }
    return { width, height, bpp, data: out };
}

async function cmd(tool, params = {}) {
    const res = await fetch(`${BRIDGE_URL}/command`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ tool, params }),
    });
    return await res.json();
}

function rgbToHex(r, g, b) {
    return "#" + (1 << 24 | r << 16 | g << 8 | b).toString(16).slice(1);
}

function colorDistance(r1, g1, b1, r2, g2, b2) {
    return Math.hypot(r1 - r2, g1 - g2, b1 - b2);
}

async function main() {
    // Target configuration
    const IMAGE_PATH = './bodybuilder.png'; 
    const TOTAL_FRAMES = 6; // Number of animation frames to generate
    const TOLERANCE = 25;

    console.log(`Decoding ${IMAGE_PATH} for animation processing...`);
    let fileBuffer;
    try {
        fileBuffer = fs.readFileSync(IMAGE_PATH);
    } catch (e) {
        console.error(`ERROR: Cannot find '${IMAGE_PATH}'. Please check file name.`);
        process.exit(1);
    }

    const img = decodePNG(fileBuffer);
    const { width: W, height: H, bpp, data } = img;

    // Detect background colors from top-left corner (Chroma Green isolation)
    const bg1 = { r: data[0], g: data[1], b: data[2] };

    console.log("Setting up Pixelorama canvas environment...");
    await cmd("create_canvas", { width: W, height: H, name: "Procedural Idle Animation" });

    // Step 1: Extract only clean character pixels first
    const basePixels = [];
    for (let y = 0; y < H; y++) {
        for (let x = 0; x < W; x++) {
            const i = (y * W + x) * bpp;
            const r = data[i];
            const g = data[i + 1];
            const b = data[i + 2];
            const a = (bpp === 4) ? data[i + 3] : 255;

            if (a === 0) continue;

            // Strict check to dump the chroma green background
            if (colorDistance(r, g, b, bg1.r, bg1.g, bg1.b) > TOLERANCE) {
                basePixels.push({ x, y, color: rgbToHex(r, g, b) });
            }
        }
    }

    console.log(`Extracted ${basePixels.length} base character pixels.`);
    console.log(`Generating ${TOTAL_FRAMES} procedural breathing frames...`);

    const originX = W / 2;
    const originY = H * 0.85; // Fixed ground pivot point near feet

    // Step 2: Loop to build each frame mathematically
    for (let f = 0; f < TOTAL_FRAMES; f++) {
        // Create an animation frame inside Pixelorama if it's not the first frame
        if (f > 0) {
            await cmd("add_frame"); 
        }

        // Sinusoidal scaling factors (Breathing cycle formula)
        const angle = (f / TOTAL_FRAMES) * Math.PI * 2;
        const scaleY = 1.0 + Math.sin(angle) * 0.03; // Gentle 3% vertical stretch
        const scaleX = 1.0 - Math.sin(angle) * 0.015; // Inverse horizontal compression to preserve mass

        const framePixels = [];

        for (const p of basePixels) {
            // Calculate coordinates relative to the feet pivot point
            const relX = p.x - originX;
            const relY = p.y - originY;

            // Apply squash and stretch transformation matrix
            const newX = Math.round(originX + relX * scaleX);
            const newY = Math.round(originY + relY * scaleY);

            if (newX >= 0 && newX < W && newY >= 0 && newY < H) {
                framePixels.push({ x: newX, y: newY, color: p.color });
            }
        }

        // Stream the current frame payload over the REST bridge
        const BATCH_SIZE = 2500;
        for (let i = 0; i < framePixels.length; i += BATCH_SIZE) {
            const batch = framePixels.slice(i, i + BATCH_SIZE);
            await cmd("draw_pixels", { pixels: batch });
        }
        console.log(`-> Frame [${f + 1}/${TOTAL_FRAMES}] generated and committed.`);
    }

    console.log("\nProcedural Idle Animation generated successfully! Press Play in Pixelorama.");
    await cmd("fit_viewport");
}

main();
