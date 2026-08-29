/**
 * Schema Helpers for Universal Harness & LLM Compatibility
 *
 * Provides type-coercing Zod schemas that transparently handle stringified numbers,
 * stringified booleans, and JSON-stringified arrays/objects sent by various AI harnesses
 * (e.g. commandcode, CLI agents, Qwen Flash, Llama, DeepSeek).
 */

import { z } from "zod";

/**
 * Coerces integer values from number or string ("10" -> 10).
 */
export const coerceInt = (min?: number, max?: number) => {
  let schema = z.coerce.number().int();
  if (min !== undefined) schema = schema.min(min);
  if (max !== undefined) schema = schema.max(max);
  return schema;
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
