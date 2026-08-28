/**
 * import_universal_asset.js
 * A universal utility to decode any PNG image sheet using pure built-in Node.js modules.
 * Dynamically detects background canvas grid checkerboards, filters out an array of 
 * custom targeted compression colors, and streams pixel-perfect assets directly into Pixelorama.
 * NOTE: All comments are in English only.
 */

const fs = require('fs');
const zlib = require('zlib');

const BRIDGE_URL = "http://127.0.0.1:7373";

// Helper: Paeth Predictor for raw PNG scanline filtering
function paethPredictor(a, b, c) {
    const p = a + b - c;
    const pa = Math.abs(p - a);
    const pb = Math.abs(p - b);
    const pc = Math.abs(p - c);
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

// Custom lightweight PNG parser using only native zlib
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
    // =========================================================================
    // USER CONFIGURATION ZONE: ADJUST IMAGE PATH, BLACKLIST COLORS, & TOLERANCE
    // =========================================================================
    
    // 1. Change your target image file name here
    const IMAGE_PATH = './docs/examples/potato.png';
    
    // 2. Add as many specific RGB colors as you want to destroy/remove
    const bannedColors = [
        { r: 36, g: 231, b: 30 }, // The problematic artifact gray (#FF0000)
        { r: 97, g: 96, b: 91 },
        { r: 180, g: 183, b: 176 },
        { r: 126, g: 127, b: 119 },
        { r: 82, g: 84, b: 79 },
        { r: 111, g: 108, b: 103 },
];

    // 3. Safety buffer padding. Higher = more aggressive edge cleaning, Lower = preserve fine shades , Zero = the exact same picture 
    const TOLERANCE = 20; 

    // =========================================================================

    console.log(`Reading raw image file from: ${IMAGE_PATH}...`);
    
    let fileBuffer;
    try {
        fileBuffer = fs.readFileSync(IMAGE_PATH);
    } catch (e) {
        console.error(`ERROR: Cannot find the file at '${IMAGE_PATH}'. Check path or filename.`);
        process.exit(1);
    }
    
    const img = decodePNG(fileBuffer);
    const { width: W, height: H, bpp, data } = img;

    console.log(`Successfully parsed texture dimensions: ${W}x${H} (${bpp} bpp)`);

    // Dynamic background detection logic (samples the grid colors on the fly)
    const bg1 = { r: data[0], g: data[1], b: data[2] };
    let bg2 = null;

    for (let x = 1; x < W / 2; x++) {
        const idx = x * bpp;
        const r = data[idx];
        const g = data[idx + 1];
        const b = data[idx + 2];
        
        if (colorDistance(r, g, b, bg1.r, bg1.g, bg1.b) > 15) {
            bg2 = { r, g, b };
            break;
        }
    }
    if (!bg2) bg2 = { ...bg1 };

    console.log(`Auto-Sampled Base Grid Tone 1: RGB(${bg1.r}, ${bg1.g}, ${bg1.b})`);
    console.log(`Auto-Sampled Base Grid Tone 2: RGB(${bg2.r}, ${bg2.g}, ${bg2.b})`);
    console.log(`Loaded Custom Blacklisted Colors Count: ${bannedColors.length}`);

    console.log("Allocating production viewport canvas inside Pixelorama...");
    await cmd("create_canvas", { width: W, height: H, name: "Universal Imported Asset" });

    const pixels = [];

    // Core execution loop scanning every single coordinate pixel
    for (let y = 0; y < H; y++) {
        for (let x = 0; x < W; x++) {
            const i = (y * W + x) * bpp;
            const r = data[i];
            const g = data[i + 1];
            const b = data[i + 2];
            const a = (bpp === 4) ? data[i + 3] : 255;

            // Instantly ignore native transparent pixels
            if (a === 0) continue;

            // Calculate Euclidean distance to the two sampled grid background tones
            const distToBg1 = colorDistance(r, g, b, bg1.r, bg1.g, bg1.b);
            const distToBg2 = colorDistance(r, g, b, bg2.r, bg2.g, bg2.b);

            // Check if the current pixel matches any color inside the custom blacklist matrix
            let matchesBanned = false;
            for (const banned of bannedColors) {
                if (colorDistance(r, g, b, banned.r, banned.g, banned.b) <= TOLERANCE) {
                    matchesBanned = true;
                    break;
                }
            }

            // Draw the pixel only if it survives both background and custom color filters
            if (distToBg1 > TOLERANCE && distToBg2 > TOLERANCE && !matchesBanned) {
                pixels.push({ x, y, color: rgbToHex(r, g, b) });
            }
        }
    }

    console.log(`Extracted ${pixels.length} asset pixels. Pumping stream over bridge network...`);
    
    // Stream chunks safely to prevent UI locking inside Godot engine
    const BATCH_SIZE = 2000;
    for (let i = 0; i < pixels.length; i += BATCH_SIZE) {
        const batch = pixels.slice(i, i + BATCH_SIZE);
        await cmd("draw_pixels", { pixels: batch });
        process.stdout.write(`\rProgress: ${Math.min(i + BATCH_SIZE, pixels.length)} / ${pixels.length} pixels drawn...`);
    }
    
    console.log("\nAsset migration complete! Viewport fits successfully with transparent alphas.");
    await cmd("fit_viewport");
}

main();
