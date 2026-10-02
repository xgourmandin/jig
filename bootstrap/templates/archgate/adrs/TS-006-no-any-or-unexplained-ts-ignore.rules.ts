/// <reference path="../rules.d.ts" />
// <jig-ts-helpers>
// Rule files cannot import each other (archgate blocks imports), so this block is
// copied verbatim into every TS-*.rules.ts; tests/archgate-typescript.bats checks they match.
// Assumed layout: src/{domain,application,ports,adapters/<name>,bootstrap,main}/... plus the frontend
// directories src/{components,pages,routes,views,features,hooks,composables,stores,ui}/ (layer "ui").
// Any other file under src/ has the layer "other"; files outside src/ are not layer-checked.
// Scanned: ts tsx mts cts js jsx mjs cjs, plus the <script> blocks of .vue .svelte .astro files.
type JigCfg = {
  dir: string[];
  base: string[] | null;
  paths: [string, string[]][];
};
type JigLoc = { layer: string; unit: string; dir: string[]; cfg?: JigCfg };
type JigImport = { line: number; spec: string };

const JIG_LAYERS = [
  "domain",
  "application",
  "ports",
  "adapters",
  "bootstrap",
  "main",
];
const JIG_UI_DIRS = [
  "components",
  "pages",
  "routes",
  "views",
  "features",
  "hooks",
  "composables",
  "stores",
  "ui",
];
const JIG_EXT = /\.(?:[cm]?[jt]sx?|vue|svelte|astro)$/;
const jigLayerOf = (seg: string) =>
  JIG_LAYERS.includes(seg) ? seg : JIG_UI_DIRS.includes(seg) ? "ui" : "other";
// Node built-ins that do I/O; inner layers must not import them (with or without `node:`).
const JIG_NODE_IO = [
  "fs",
  "http",
  "https",
  "http2",
  "net",
  "dgram",
  "dns",
  "tls",
  "child_process",
  "cluster",
  "worker_threads",
  "readline",
];
// I/O clients: libraries that talk to a network, database or cloud service. Forbidden in inner layers and in ui.
const JIG_IO_CLIENTS = [
  "prisma",
  "@prisma/client",
  "typeorm",
  "sequelize",
  "mongoose",
  "mongodb",
  "knex",
  "drizzle-orm",
  "pg",
  "mysql",
  "mysql2",
  "sqlite3",
  "better-sqlite3",
  "redis",
  "ioredis",
  "axios",
  "node-fetch",
  "got",
  "ky",
  "ofetch",
  "undici",
  "superagent",
  "aws-sdk",
  "aws-amplify",
  "@aws-amplify",
  "@aws-sdk",
  "@smithy",
  "@google-cloud",
  "@azure",
  "firebase",
  "@firebase",
  "firebase-admin",
  "@supabase",
  "@apollo/client",
  "urql",
  "@urql",
  "graphql-request",
  "@trpc/client",
  "kafkajs",
  "amqplib",
  "bullmq",
  "bull",
  "@grpc/grpc-js",
  "nodemailer",
  "socket.io",
  "socket.io-client",
  "ws",
];
// Server frameworks and tooling that inner layers must not import. next/nuxt are listed here and in the UI list:
// they are only checked in inner layers (the server/client split of a Next/Nuxt app is not modelled).
const JIG_SERVER_FW = [
  "express",
  "fastify",
  "koa",
  "hono",
  "@hapi/hapi",
  "@nestjs",
  "next",
  "nuxt",
  "@nuxt",
  "#app",
  "#imports",
  "dotenv",
];
// UI frameworks, routers and state/data libraries that inner layers must not import. rxjs is deliberately not
// listed: it is a pure library that application code may use.
const JIG_UI_FW = [
  "react",
  "react-dom",
  "react-native",
  "preact",
  "vue",
  "@vue",
  "@vueuse",
  "svelte",
  "@sveltejs",
  "@angular",
  "solid-js",
  "react-router",
  "react-router-dom",
  "@remix-run",
  "vue-router",
  "@tanstack",
  "redux",
  "@reduxjs",
  "react-redux",
  "zustand",
  "pinia",
  "mobx",
  "mobx-react",
  "mobx-react-lite",
  "jotai",
  "recoil",
  "swr",
  "valtio",
  "nanostores",
];
const JIG_INFRA = [...JIG_IO_CLIENTS, ...JIG_SERVER_FW, ...JIG_UI_FW];

// Same-length copy of `src` with comments (unless `comments`), string contents, template text and regex
// literal contents blanked (newlines kept). Code inside `${...}` stays visible.
function jigMask(src: string, comments = false): string {
  const n = src.length;
  const out = src.split("");
  const blank = (a: number, b: number) => {
    for (let k = a; k < Math.min(b, n); k++) if (out[k] !== "\n") out[k] = " ";
  };
  const skipStr = (i: number): number => {
    const q = src[i];
    let j = i + 1;
    while (j < n && src[j] !== q && src[j] !== "\n")
      j += src[j] === "\\" ? 2 : 1;
    j = Math.min(j, n);
    blank(i + 1, j);
    return src[j] === q ? j + 1 : j;
  };
  const regexAllowed = (i: number): boolean => {
    let j = i - 1;
    while (j >= 0 && /\s/.test(src[j])) j--;
    if (j < 0) return true;
    if ("(,=:[!&|?{;+-*%<>~^".includes(src[j])) return true;
    const w = /([A-Za-z]+)$/.exec(src.slice(Math.max(0, j - 8), j + 1));
    return (
      !!w &&
      [
        "return",
        "typeof",
        "case",
        "in",
        "of",
        "delete",
        "void",
        "throw",
        "yield",
        "await",
      ].includes(w[1])
    );
  };
  const skipRegex = (i: number): number => {
    let j = i + 1;
    let cls = false;
    while (j < n && src[j] !== "\n") {
      const c = src[j];
      if (c === "\\") {
        j += 2;
        continue;
      }
      if (c === "[") cls = true;
      else if (c === "]") cls = false;
      else if (c === "/" && !cls) break;
      j++;
    }
    if (src[j] !== "/") return i + 1;
    blank(i + 1, j);
    return j + 1;
  };
  let scan: (i: number, inTpl: boolean) => number;
  const skipTpl = (i: number): number => {
    let j = i + 1;
    while (j < n && src[j] !== "`") {
      if (src[j] === "\\") {
        blank(j, j + 2);
        j += 2;
        continue;
      }
      if (src[j] === "$" && src[j + 1] === "{") {
        blank(j, j + 2);
        j = scan(j + 2, true);
        blank(j - 1, j);
        continue;
      }
      blank(j, j + 1);
      j++;
    }
    return Math.min(j + 1, n);
  };
  scan = (start: number, inTpl: boolean): number => {
    let i = start;
    let depth = 0;
    while (i < n) {
      const c = src[i];
      if (c === "/" && src[i + 1] === "/") {
        let j = src.indexOf("\n", i);
        if (j < 0) j = n;
        if (!comments) blank(i, j);
        i = j;
      } else if (c === "/" && src[i + 1] === "*") {
        let j = src.indexOf("*/", i + 2);
        j = j < 0 ? n : j + 2;
        if (!comments) blank(i, j);
        i = j;
      } else if (c === '"' || c === "'") i = skipStr(i);
      else if (c === "`") i = skipTpl(i);
      else if (c === "/" && regexAllowed(i)) i = skipRegex(i);
      else if (inTpl && c === "{") {
        depth++;
        i++;
      } else if (inTpl && c === "}") {
        if (depth === 0) return i + 1;
        depth--;
        i++;
      } else i++;
    }
    return n;
  };
  scan(0, false);
  return out.join("");
}

const jigLineOf = (raw: string, offset: number) =>
  raw.slice(0, offset).split("\n").length;
const jigIsTest = (f: string) =>
  /\.(test|spec)\.(?:[cm]?[jt]sx?|vue|svelte|astro)$/.test(f) ||
  /(^|\/)__tests__\//.test(f);

// File contents as code. For .vue/.svelte/.astro only the <script> blocks (and the astro frontmatter) are kept; the
// rest is blanked with newlines preserved, so line numbers stay valid. `ts` tells whether the code is TypeScript.
async function jigRead(
  ctx: RuleContext,
  file: string,
): Promise<{ raw: string; ts: boolean }> {
  const text = await ctx.readFile(file);
  if (!/\.(?:vue|svelte|astro)$/.test(file))
    return { raw: text, ts: /\.[cm]?tsx?$/.test(file) };
  const astro = file.endsWith(".astro");
  let ts = astro;
  const keep: [number, number][] = [];
  if (astro) {
    const fm = /^\uFEFF?---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/.exec(
      text,
    );
    if (fm) {
      const start = fm.index + fm[0].indexOf("\n") + 1;
      keep.push([start, start + fm[1].length]);
    }
  }
  for (const m of text.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)) {
    const start = (m.index ?? 0) + 7 + m[1].length + 1;
    keep.push([start, start + m[2].length]);
    if (/\blang\s*=\s*["']?tsx?\b/i.test(m[1])) ts = true;
  }
  const out = text.split("");
  let k = 0;
  keep.sort((x, y) => x[0] - y[0]);
  for (let i = 0; i < out.length; i++) {
    while (k < keep.length && i >= keep[k][1]) k++;
    if (out[i] !== "\n" && !(k < keep.length && i >= keep[k][0])) out[i] = " ";
  }
  return { raw: out.join(""), ts };
}
// Code files (not tests, declarations or vendored output) whose path passes `keep`, read in parallel. Filtering by
// path first means files of unrelated layers are never read.
async function jigSources(
  ctx: RuleContext,
  keep: (file: string) => boolean = () => true,
) {
  const files = ctx.scopedFiles
    .filter(
      (f) =>
        JIG_EXT.test(f) &&
        !/(^|\/)(node_modules|dist|build|out|coverage|\.next|\.nuxt|\.turbo|\.archgate)\//.test(
          f,
        ) &&
        !/\.d\.[cm]?ts$/.test(f) &&
        !jigIsTest(f) &&
        keep(f),
    )
    .sort();
  const sources = await Promise.all(files.map((f) => jigRead(ctx, f)));
  return files.map((file, i) => ({ file, ...sources[i] }));
}

// Strip // and /* */ comments and trailing commas from tsconfig-style JSON, then parse (null when invalid).
function jigJson(text: string): any {
  let out = "";
  for (let i = 0; i < text.length;) {
    const c = text[i];
    if (c === '"') {
      let j = i + 1;
      while (j < text.length && text[j] !== '"') j += text[j] === "\\" ? 2 : 1;
      out += text.slice(i, j + 1);
      i = j + 1;
    } else if (c === "/" && text[i + 1] === "/") {
      while (i < text.length && text[i] !== "\n") i++;
    } else if (c === "/" && text[i + 1] === "*") {
      const j = text.indexOf("*/", i + 2);
      i = j < 0 ? text.length : j + 2;
    } else {
      out += c;
      i++;
    }
  }
  let res = "";
  for (let i = 0; i < out.length;) {
    if (out[i] === '"') {
      let j = i + 1;
      while (j < out.length && out[j] !== '"') j += out[j] === "\\" ? 2 : 1;
      res += out.slice(i, j + 1);
      i = j + 1;
    } else if (out[i] === "," && /^\s*[}\]]/.test(out.slice(i + 1))) i++;
    else res += out[i++];
  }
  try {
    return JSON.parse(res);
  } catch {
    return null;
  }
}

const jigDirOf = (f: string) => f.split("/").slice(0, -1);
function jigJoin(base: string[], rel: string): string[] {
  const parts = [...base];
  for (const s of rel.split("/")) {
    if (s === "" || s === ".") continue;
    if (s === "..") parts.pop();
    else parts.push(s);
  }
  return parts;
}

// compilerOptions.paths/baseUrl of every tsconfig.json (and tsconfig.app.json); `extends` is not followed.
// Returns the config of the nearest directory above `file` that defines paths or baseUrl.
async function jigConfigs(
  ctx: RuleContext,
): Promise<(file: string) => JigCfg | undefined> {
  const byDir = new Map<string, JigCfg>();
  const files = (
    await Promise.all([
      ctx.glob("**/tsconfig.json"),
      ctx.glob("**/tsconfig.app.json"),
    ])
  )
    .flat()
    .filter((f) => !/(^|\/)node_modules\//.test(f))
    .sort();
  const texts = await Promise.all(
    files.map((f) => ctx.readFile(f).catch(() => null)),
  );
  for (const [n, f] of files.entries()) {
    let json: any;
    try {
      json = jigJson(texts[n]!);
    } catch {
      continue;
    }
    const co = json?.compilerOptions;
    if (!co || (!co.paths && typeof co.baseUrl !== "string")) continue;
    const dir = jigDirOf(f);
    const base =
      typeof co.baseUrl === "string" ? jigJoin(dir, co.baseUrl) : null;
    const paths: [string, string[]][] = Object.entries<unknown>(co.paths ?? {})
      .filter(([, v]) => Array.isArray(v))
      .map(
        ([k, v]) =>
          [
            k,
            (v as unknown[]).filter((x): x is string => typeof x === "string"),
          ] as [string, string[]],
      );
    paths.sort((x, y) => y[0].length - x[0].length);
    const old = byDir.get(dir.join("/"));
    byDir.set(
      dir.join("/"),
      old
        ? { dir, base: old.base ?? base, paths: [...old.paths, ...paths] }
        : { dir, base, paths },
    );
  }
  return (file) => {
    const d = jigDirOf(file);
    for (let n = d.length; n >= 0; n--) {
      const c = byDir.get(d.slice(0, n).join("/"));
      if (c) return c;
    }
    return undefined;
  };
}

function jigLoc(file: string): JigLoc | null {
  const m = /(?:^|\/)src\/(.+)$/.exec(file);
  if (!m) return null;
  const segs = m[1].split("/");
  segs[segs.length - 1] = segs[segs.length - 1].replace(JIG_EXT, "");
  const layer = jigLayerOf(segs[0]);
  return {
    layer,
    unit: segs.length >= 3 ? segs[1] : "",
    dir: segs.slice(0, -1),
  };
}

// import / import type / export ... from / require() / dynamic import(); specifiers are read from `raw`
// at the positions found in `masked`.
function jigImports(raw: string, masked: string): JigImport[] {
  const ws = "[ \\t\\r\\n]*";
  const pats = [
    new RegExp(
      `\\bimport${ws}(?:type[ \\t\\r\\n]+)?(?:[\\w$]+${ws},?${ws})?(?:\\*${ws}as[ \\t\\r\\n]+[\\w$]+|\\{[^}]*\\})?${ws}from${ws}(['"])`,
      "g",
    ),
    new RegExp(`\\bimport${ws}(['"])`, "g"),
    new RegExp(
      `\\bexport${ws}(?:type[ \\t\\r\\n]+)?(?:\\*(?:${ws}as[ \\t\\r\\n]+[\\w$]+)?|\\{[^}]*\\})${ws}from${ws}(['"])`,
      "g",
    ),
    new RegExp(`(?<![\\w$.])(?:import|require)${ws}\\(${ws}(['"])`, "g"),
  ];
  const out: JigImport[] = [];
  for (const re of pats) {
    for (const m of masked.matchAll(re)) {
      const open = (m.index ?? 0) + m[0].length - 1;
      const close = masked.indexOf(m[1], open + 1);
      if (close < 0) continue;
      out.push({
        line: jigLineOf(raw, m.index ?? 0),
        spec: raw.slice(open + 1, close),
      });
    }
  }
  return out.sort((a, b) => a.line - b.line);
}

// Parts below src/ of a repo-relative path, or null when it is outside src.
function jigBelowSrc(parts: string[]): string[] | null {
  const i = parts.indexOf("src");
  return i < 0 ? null : parts.slice(i + 1);
}

// Internal target of a specifier: relative paths, the nearest tsconfig's `paths` (and `baseUrl` for bare layer
// names) and, when those do not match, the aliases `@/`, `~/`, `#/`, `src/` (all mapped to the src root).
// `extends` chains are not followed. Returns null for packages and for paths leaving src.
function jigTarget(
  spec: string,
  loc: JigLoc,
): { layer: string; unit: string } | null {
  let parts: string[] | null = null;
  const alias = /^(?:[@~#]\/|src\/)(.*)$/.exec(spec);
  if (spec.startsWith(".")) {
    parts = [...loc.dir];
    for (const s of spec.split("/")) {
      if (s === "" || s === ".") continue;
      if (s === "..") {
        if (!parts.length) return null;
        parts.pop();
      } else parts.push(s);
    }
  } else {
    const cfg = loc.cfg;
    let matched = false;
    for (const [pat, targets] of cfg?.paths ?? []) {
      const star = pat.indexOf("*");
      let rest: string | null = null;
      if (star < 0) rest = spec === pat ? "" : null;
      else if (
        spec.length >= pat.length - 1 &&
        spec.startsWith(pat.slice(0, star)) &&
        spec.endsWith(pat.slice(star + 1))
      ) {
        rest = spec.slice(star, spec.length - (pat.length - star - 1));
      }
      if (rest === null) continue;
      matched = true;
      for (const tg of targets) {
        parts = jigBelowSrc(
          jigJoin(cfg?.base ?? cfg?.dir ?? [], tg.replace("*", rest)),
        );
        if (parts) break;
      }
      break;
    }
    if (!matched && cfg?.base) {
      const p = jigBelowSrc(jigJoin(cfg.base, spec));
      if (p && p[0] && jigLayerOf(p[0]) !== "other") parts = p;
    }
    if (!matched && !parts && alias)
      parts = alias[1].split("/").filter(Boolean);
  }
  if (!parts || !parts.length) return null;
  parts[parts.length - 1] = parts[parts.length - 1].replace(JIG_EXT, "");
  const layer = jigLayerOf(parts[0]);
  const unit = parts[1] && parts[1] !== "index" ? parts[1] : "";
  return { layer, unit };
}

// Name of the framework/infrastructure package or I/O built-in that `spec` imports, if any.
function jigInfra(spec: string): string | undefined {
  if (spec.startsWith(".")) return undefined;
  const bare = spec.startsWith("node:") ? spec.slice(5) : spec;
  const io = JIG_NODE_IO.find((x) => bare === x || bare.startsWith(x + "/"));
  if (io) return "node:" + io;
  return JIG_INFRA.find((x) => bare === x || bare.startsWith(x + "/"));
}

// Name of the I/O client package or I/O built-in that `spec` imports, if any (used for the ui layer).
function jigIoClient(spec: string): string | undefined {
  if (spec.startsWith(".")) return undefined;
  const bare = spec.startsWith("node:") ? spec.slice(5) : spec;
  const io = JIG_NODE_IO.find((x) => bare === x || bare.startsWith(x + "/"));
  if (io) return "node:" + io;
  return JIG_IO_CLIENTS.find((x) => bare === x || bare.startsWith(x + "/"));
}

// Browser globals in code (comments and strings must be masked). `window`/`document` need a member access or
// `typeof`, `location`/`navigator` a known member (so a domain field named `location` is not flagged), the storage
// objects any use. A name the file declares itself (const/let/function/type/typed parameter) is skipped.
const JIG_BROWSER_MEMBERS: Record<string, string> = {
  window: "[\\w$]+",
  document:
    "(?:getElementById|getElementsBy\\w+|querySelector(?:All)?|createElement\\w*|body|head|cookie|documentElement|addEventListener|removeEventListener|title|referrer|hidden|visibilityState|location|activeElement)",
  navigator:
    "(?:userAgent|language|languages|clipboard|geolocation|onLine|platform|sendBeacon|serviceWorker|mediaDevices|share|vendor)",
  location:
    "(?:href|pathname|search|hash|origin|host|hostname|port|protocol|assign|replace|reload)",
};
function jigBrowserGlobals(masked: string): { offset: number; name: string }[] {
  const out: { offset: number; name: string }[] = [];
  const shadowed = (n: string) =>
    new RegExp(
      `\\b(?:const|let|var|function|class|type|interface|enum)[ \\t]+${n}\\b|[(,{][ \\t\\r\\n]*${n}[ \\t]*\\??:`,
    ).test(masked);
  for (const [name, members] of Object.entries(JIG_BROWSER_MEMBERS)) {
    if (shadowed(name)) continue;
    const idx = name === "window" || name === "document" ? "|\\[" : "";
    const re = new RegExp(
      `(?<![\\w$.#])${name}[ \\t]*(?:\\?\\.[ \\t]*(?=${members})|\\.[ \\t]*(?=${members})${idx})|\\btypeof[ \\t]+${name}\\b`,
      "g",
    );
    for (const m of masked.matchAll(re))
      out.push({ offset: m.index ?? 0, name });
  }
  const store =
    /(?<![\w$.#])(?:globalThis\.)?(localStorage|sessionStorage)\b|\bglobalThis\.(?:document|navigator|location)\b/g;
  for (const m of masked.matchAll(store)) {
    const before = masked.slice(0, m.index ?? 0);
    const after = masked.slice((m.index ?? 0) + m[0].length);
    const lineStart = before.slice(before.lastIndexOf("\n") + 1).trim();
    if (
      /^[ \t]*\??:/.test(after) &&
      (lineStart === "" || /[({,;]$/.test(lineStart))
    )
      continue;
    out.push({ offset: m.index ?? 0, name: m[1] ?? m[0] });
  }
  return out.sort((a, b) => a.offset - b.offset);
}

// Report a violation. `why` is "<problem>; <remedy>": the problem becomes the message and the remedy the `fix`
// shown by `archgate check --verbose`. Exceptions are `archgate-ignore` comments, handled by archgate itself.
function jigReport(ctx: RuleContext, file: string, line: number, why: string) {
  const [problem, ...rest] = why.split("; ");
  const remedy = rest.join("; ");
  ctx.report.violation({
    message: problem,
    file,
    line,
    ...(remedy && { fix: remedy[0].toUpperCase() + remedy.slice(1) }),
  });
}
async function jigCheckImports(
  ctx: RuleContext,
  id: string,
  layers: string[],
  forbid: (spec: string, loc: JigLoc) => string | null,
) {
  const [cfgOf, sources] = await Promise.all([
    jigConfigs(ctx),
    jigSources(ctx, (f) => layers.includes(jigLoc(f)?.layer ?? "")),
  ]);
  for (const { file, raw } of sources) {
    const loc = jigLoc(file)!;
    loc.cfg = cfgOf(file);
    for (const imp of jigImports(raw, jigMask(raw))) {
      const why = forbid(imp.spec, loc);
      if (why) jigReport(ctx, file, imp.line, why);
    }
  }
}
// </jig-ts-helpers>

const ANY_TYPE =
  /(?::[ \t]*|\bas[ \t]+|\bsatisfies[ \t]+|<[ \t]*|,[ \t]*|\|[ \t]*|&[ \t]*|\bextends[ \t]+|=[ \t]*)any\b(?![ \t]*[(.:])/g;
const DIRECTIVE =
  /(?:\/\/|\/\*+)[ \t]*@ts-(ignore|nocheck|expect-error)\b([^\n]*)/g;

export default {
  rules: {
    "no-any-or-unexplained-ts-ignore": {
      description:
        "No `any`; no @ts-ignore/@ts-nocheck; @ts-expect-error needs a description",
      async check(ctx) {
        for (const { file, raw, ts } of await jigSources(ctx)) {
          if (ts) {
            const masked = jigMask(raw);
            const seen = new Set<number>();
            for (const m of masked.matchAll(ANY_TYPE)) {
              const line = jigLineOf(raw, m.index ?? 0);
              if (seen.has(line)) continue;
              seen.add(line);
              jigReport(
                ctx,
                file,
                line,
                "`any` turns off type checking; use `unknown` and narrow, or a precise type",
              );
            }
          }
          for (const m of jigMask(raw, true).matchAll(DIRECTIVE)) {
            const line = jigLineOf(raw, m.index ?? 0);
            const rest = m[2]
              .replace(/\*+\/.*$/, "")
              .replace(/^[\s:\-–]+/, "")
              .trim();
            let why: string | null = null;
            if (m[1] !== "expect-error")
              why = `@ts-${m[1]} hides every error; use @ts-expect-error with a description`;
            else if (!rest)
              why =
                "@ts-expect-error needs a description of the expected error";
            if (why) jigReport(ctx, file, line, why);
          }
        }
      },
    },
  },
} satisfies RuleSet;
