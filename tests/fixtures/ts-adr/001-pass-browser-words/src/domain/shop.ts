import { Observable } from "rxjs";
import { helper } from "@lib/helper";
import { react } from "reactive-utils";
import { Money } from "@/domain/money";
import { Money as M2 } from "domain/money";

// window.localStorage and document.cookie and localStorage are only words here
const doc = "use localStorage or window.location.href in the adapter";
export interface Store {
  location: string;
  navigator?: string;
  localStorage: Map<string, string>;
}
export function near(location: { href: string }, other: Store) {
  return location.href === other.location;
}
export function win(window: number[]) {
  return window.length;
}
export const o: Observable<number> | undefined = undefined;
export const h = [helper, react, Money, M2, doc];
