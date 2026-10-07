/**
 * Schema Helpers for Universal Harness & LLM Compatibility
 *
 * Provides type-coercing Zod schemas that transparently handle stringified numbers,
 * stringified booleans, and JSON-stringified arrays/objects sent by various AI harnesses
 * (e.g. commandcode, CLI agents, Qwen Flash, Llama, DeepSeek).
 */

import { z } from "zod";

/**
 * Coerces integer values from number or string ("10" -> 10, 28.8 -> 29).
 * Non-integer floating point numbers are automatically rounded via Math.round.
 */
export const coerceInt = (min?: number, max?: number) => {
  let numSchema = z.coerce.number().int();
  if (min !== undefined) numSchema = numSchema.min(min);
  if (max !== undefined) numSchema = numSchema.max(max);

  return z.preprocess((val) => {
    if (typeof val === "number" && !Number.isNaN(val) && Number.isFinite(val)) {
      return Math.round(val);
    }
    if (typeof val === "string") {
      const trimmed = val.trim();
      const num = Number(trimmed);
      if (!Number.isNaN(num) && Number.isFinite(num)) {
        return Math.round(num);
      }
    }
    return val;
  }, numSchema);
};

/**
 * Coerces float values from number or string ("1.5" -> 1.5).
 */
export const coerceFloat = (min?: number, max?: number) => {
  let schema = z.coerce.number();
  if (min !== undefined) schema = schema.min(min);
  if (max !== undefined) schema = schema.max(max);
  return schema;
};

/**
 * Coerces boolean values from boolean or string ("true"/"false" -> true/false).
 */
export const coerceBool = () =>
  z.preprocess((val) => {
    if (typeof val === "string") {
      const lower = val.trim().toLowerCase();
      if (lower === "true" || lower === "1") return true;
      if (lower === "false" || lower === "0") return false;
    }
    return val;
  }, z.coerce.boolean());

/**
 * Parses JSON strings into arrays if a string is provided by the harness.
 */
export const safeJsonArray = <T extends z.ZodTypeAny>(itemSchema: T, minItems?: number) => {
  let arraySchema = z.array(itemSchema);
  if (minItems !== undefined) {
    arraySchema = arraySchema.min(minItems);
  }
  return z.preprocess((val) => {
    if (typeof val === "string") {
      try {
        const parsed = JSON.parse(val);
        if (Array.isArray(parsed)) return parsed;
      } catch {
        return val;
      }
    }
    return val;
  }, arraySchema);
};

/**
 * Parses JSON strings into objects if a string is provided by the harness.
 */
export const safeJsonObject = <T extends z.ZodRawShape>(shape: T) =>
  z.preprocess((val) => {
    if (typeof val === "string") {
      try {
        const parsed = JSON.parse(val);
        if (typeof parsed === "object" && parsed !== null) return parsed;
      } catch {
        return val;
      }
    }
    return val;
  }, z.object(shape));

/**
 * Validates an array of 2D point objects [{x, y}, ...].
 * - Coerces/rounds finite floats to integers.
 * - Reports exact offending index and context window on non-finite (NaN/Infinity) coordinates.
 * - Accurately differentiates length errors from coordinate type errors.
 */
export const safePointsArray = (minPoints: number = 3) =>
  z.preprocess((val) => {
    if (typeof val === "string") {
      try {
        const parsed = JSON.parse(val);
        if (Array.isArray(parsed)) return parsed;
      } catch {
        return val;
      }
    }
    return val;
  }, z.array(z.any()))
    .superRefine((items, ctx) => {
      if (!Array.isArray(items)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: "Expected an array of point coordinates [{x, y}, ...]",
        });
        return;
      }
      if (items.length < minPoints) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          message: `Expected at least ${minPoints} points, but received ${items.length}.`,
        });
        return;
      }

      for (let i = 0; i < items.length; i++) {
        const pt = items[i];
        if (!pt || typeof pt !== "object") {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: `points[${i}]: Expected an object with {x, y}, received ${typeof pt}`,
          });
          return;
        }

        const rawX = (pt as Record<string, unknown>).x;
        const rawY = (pt as Record<string, unknown>).y;

        const numX = typeof rawX === "number" ? rawX : Number(rawX);
        const numY = typeof rawY === "number" ? rawY : Number(rawY);

        if (rawX === undefined || rawX === null || Number.isNaN(numX) || !Number.isFinite(numX)) {
          const start = Math.max(0, i - 2);
          const end = Math.min(items.length - 1, i + 2);
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: `points[${i}].x: Invalid coordinate '${rawX}'. Expected finite number. Context window indices [${start}..${end}].`,
          });
          return;
        }

        if (rawY === undefined || rawY === null || Number.isNaN(numY) || !Number.isFinite(numY)) {
          const start = Math.max(0, i - 2);
          const end = Math.min(items.length - 1, i + 2);
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            message: `points[${i}].y: Invalid coordinate '${rawY}'. Expected finite number. Context window indices [${start}..${end}].`,
          });
          return;
        }

        // Round finite values in-place
        (pt as Record<string, unknown>).x = Math.round(numX);
        (pt as Record<string, unknown>).y = Math.round(numY);
      }
    });

/**
 * Universal layer handle schema allowing:
 * - 0-based integer layer index (0, 1, 2)
 * - Layer string identifier (UUID or stable ID like "layer_1234")
 * - Layer name ("Sky", "Milky Way", "Cabin Glow")
 */
export const layerHandleSchema = z
  .union([coerceInt(), z.string()])
  .optional()
  .describe("Target layer index (0-based integer), stable layer ID, or layer name (defaults to active layer)");

/**
 * Maximum elements allowed in a single flat pixel array (~100k pixels in stride 3, ~50k in stride 6).
 * Protects Node.js from V8 heap exhaustion / OOM crashes during giant batch calls.
 */
export const MAX_FLAT_PIXEL_ELEMENTS = 300_000;

/**
 * High-performance flat array schema for batch pixel drawing.
 * Validates Array structure in O(1) time without per-element Zod union allocations,
 * and guards against memory exhaustion with an informative limit error.
 */
export const fastFlatArraySchema = z
  .preprocess((val) => {
    if (typeof val === "string") {
      try {
        const parsed = JSON.parse(val);
        if (Array.isArray(parsed)) return parsed;
      } catch {
        return val;
      }
    }
    return val;
  }, z.custom<Array<number | string>>(
    (val) => Array.isArray(val),
    { message: "Expected a flat array of numbers and hex color strings" }
  ))
  .refine(
    (arr) => arr.length <= MAX_FLAT_PIXEL_ELEMENTS,
    (arr) => ({
      message: `Array length (${arr.length}) exceeds the maximum safe batch limit of ${MAX_FLAT_PIXEL_ELEMENTS} elements (~${Math.floor(MAX_FLAT_PIXEL_ELEMENTS / 3)} pixels). Please partition your drawing into batches of at most ${Math.floor(MAX_FLAT_PIXEL_ELEMENTS / 3)} pixels per call.`
    })
  );


