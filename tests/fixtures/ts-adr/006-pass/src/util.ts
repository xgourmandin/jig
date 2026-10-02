// Any value is fine here; "any" in prose and strings is ignored.
const doc = "x: any // @ts-ignore";
export const company: unknown = Promise.any([Promise.resolve(1)]);
export const m = new Map<string, unknown>();
const x: number = 1;
// @ts-expect-error: legacy typings, see SHOP-12
export const y: string = x;
/* @ts-expect-error - widened by the vendor SDK */
export const z: string = x;
// archgate-ignore TS-006/no-any-or-unexplained-ts-ignore vendor payload is untyped, validated at the edge
export const raw = JSON.parse("1") as any;
export { doc };
