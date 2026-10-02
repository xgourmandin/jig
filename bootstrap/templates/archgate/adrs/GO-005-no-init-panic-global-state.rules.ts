/// <reference path="../rules.d.ts" />
// <jig-go-helpers>
// Rule files cannot import each other (archgate blocks imports), so this block is
// copied verbatim into every GO-*.rules.ts; tests/archgate-go.bats checks they match.
// Layout assumed: internal/{domain,app,ports,adapters/<name>}/ and cmd/<binary>/.

// Same-length copy of `src` with comments blanked and, unless keepStrings, string/rune contents blanked.
function jigMask(src: string, keepStrings = false): string {
  const n = src.length;
  const blank = (s: string) => s.replace(/[^\n]/g, " ");
  let out = "";
  let i = 0;
  while (i < n) {
    const c = src[i];
    const d = src[i + 1];
    if (c === "/" && d === "/") {
      let j = src.indexOf("\n", i);
      if (j < 0) j = n;
      out += blank(src.slice(i, j));
      i = j;
    } else if (c === "/" && d === "*") {
      let j = src.indexOf("*/", i + 2);
      j = j < 0 ? n : j + 2;
      out += blank(src.slice(i, j));
      i = j;
    } else if (c === '"' || c === "`" || c === "'") {
      let j = i + 1;
      while (j < n && src[j] !== c) {
        if (c !== "`" && src[j] === "\\") j++;
        else if (c !== "`" && src[j] === "\n") break;
        j++;
      }
      j = Math.min(j, n);
      const closed = j < n && src[j] === c;
      const end = closed ? j + 1 : j;
      if (keepStrings) out += src.slice(i, end);
      else out += closed ? c + blank(src.slice(i + 1, j)) + c : blank(src.slice(i, end));
      i = end;
    } else { out += c; i++; }
  }
  return out;
}

const jigLineOf = (raw: string, offset: number) => raw.slice(0, offset).split("\n").length;

// Index of the `}` matching the `{` at `open` in masked source (or the end).
function jigClose(masked: string, open: number): number {
  let depth = 0;
  for (let i = open; i < masked.length; i++) {
    if (masked[i] === "{") depth++;
    else if (masked[i] === "}" && --depth === 0) return i;
  }
  return masked.length;
}

// Non-test, non-vendored Go sources whose path passes `keep`, read in parallel. Filtering by path first means files
// of unrelated layers are never read.
async function jigGoSources(ctx: RuleContext, keep: (file: string) => boolean = () => true) {
  const files = ctx.scopedFiles
    .filter((f) => f.endsWith(".go") && !/(^|\/)(vendor|testdata|node_modules|\.git)\//.test(f) && !/_test\.go$/.test(f) && keep(f))
    .sort();
  const raws = await Promise.all(files.map((f) => ctx.readFile(f)));
  return files.map((file, i) => ({ file, raw: raws[i] }));
}

// Layer of a file under internal/: domain | app | ports | adapters (+ adapter name).
function jigFileLayer(file: string): { layer: string; sub?: string } | null {
  const m = /(?:^|\/)internal\/(domain|app|ports|adapters)(?:\/([^/]+))?\//.exec(file);
  return m ? { layer: m[1], sub: m[2] } : null;
}
const jigInCmd = (file: string) => /(^|\/)cmd\//.test(file);

// Layer of an import path (same shape as jigFileLayer, plus "cmd").
function jigImportLayer(path: string): { layer: string; sub?: string } | null {
  if (/(^|\/)cmd(\/|$)/.test(path)) return { layer: "cmd" };
  const m = /(?:^|\/)internal\/(domain|app|ports|adapters)(?:\/([^/]+))?(?:\/|$)/.exec(path);
  return m ? { layer: m[1], sub: m[2] } : null;
}

// Infrastructure and framework packages the inner layers must not import. Extend as needed.
const JIG_INFRA_EXACT = new Set(["net", "os"]);
const JIG_INFRA_PREFIX = [
  "net/http", "database/sql", "os/exec", "os/signal",
  "gorm.io/", "github.com/jmoiron/sqlx", "github.com/jackc/pgx", "github.com/lib/pq", "github.com/go-sql-driver/",
  "github.com/mattn/go-sqlite3", "github.com/aws/aws-sdk-go", "cloud.google.com/go", "google.golang.org/grpc",
  "google.golang.org/api", "github.com/Azure/azure-sdk-for-go", "github.com/gin-gonic/", "github.com/labstack/echo",
  "github.com/go-chi/chi", "github.com/gorilla/", "github.com/gofiber/", "github.com/redis/", "github.com/go-redis/",
  "go.mongodb.org/", "github.com/segmentio/kafka-go", "github.com/IBM/sarama", "github.com/nats-io/", "github.com/spf13/cobra",
];
const jigIsInfra = (path: string) =>
  JIG_INFRA_EXACT.has(path) || JIG_INFRA_PREFIX.some((p) => (p.endsWith("/") ? path.startsWith(p) : path === p || path.startsWith(p + "/")));

// Imports of a Go file with their line numbers (comments ignored).
function jigGoImports(raw: string): { path: string; line: number }[] {
  const out: { path: string; line: number }[] = [];
  let inBlock = false;
  jigMask(raw, true).split("\n").forEach((l, idx) => {
    let m: RegExpExecArray | null;
    if (inBlock) {
      if (/^\)/.test(l)) inBlock = false;
      else if ((m = /^\s*(?:[\w.]+\s+)?"([^"]+)"/.exec(l))) out.push({ path: m[1], line: idx + 1 });
    } else if (/^import\s*\(/.test(l)) {
      inBlock = !/\)\s*$/.test(l);
      if (!inBlock) for (const s of l.matchAll(/"([^"]+)"/g)) out.push({ path: s[1], line: idx + 1 });
    } else if ((m = /^import\s+(?:[\w.]+\s+)?"([^"]+)"/.exec(l))) out.push({ path: m[1], line: idx + 1 });
  });
  return out;
}

// Report a violation. Exceptions are `archgate-ignore` comments, handled by archgate itself.
function jigReport(ctx: RuleContext, file: string, line: number, message: string, fix: string) {
  ctx.report.violation({ message, file, line, fix });
}
// </jig-go-helpers>

// Library code: non-test files that are not `package main`.
const isLibrary = (masked: string) => !/^package[ \t]+main\b/m.test(masked);
const SENTINEL = /^[Ee]rr[A-Z]\w*$|^_$/;

export default {
  rules: {
    "no-init": {
      description: "Library code has no init() functions",
      async check(ctx) {
        for (const { file, raw } of await jigGoSources(ctx)) {
          const masked = jigMask(raw);
          if (!isLibrary(masked)) continue;
          for (const m of masked.matchAll(/^func[ \t]+init[ \t]*\(\)/gm)) {
            const line = jigLineOf(raw, m.index);
            jigReport(ctx, file, line, "init() hides side effects at import time",
              "Do the work in an explicit constructor called from cmd/");
          }
        }
      },
    },
    "no-panic": {
      description: "Library code returns errors instead of calling panic()",
      async check(ctx) {
        for (const { file, raw } of await jigGoSources(ctx)) {
          const masked = jigMask(raw);
          if (!isLibrary(masked)) continue;
          for (const m of masked.matchAll(/(?<![\w.])panic[ \t]*\(/g)) {
            const line = jigLineOf(raw, m.index);
            jigReport(ctx, file, line, "panic() in library code crashes the caller",
              "Return an error");
          }
        }
      },
    },
    "no-global-mutable-state": {
      description: "Library code has no package-level variables except error sentinels, regexp/errors constructors and go:embed",
      async check(ctx) {
        for (const { file, raw } of await jigGoSources(ctx)) {
          const masked = jigMask(raw);
          if (!isLibrary(masked)) continue;
          const rawLines = raw.split("\n");
          const lines = masked.split("\n");
          let inBlock = false;
          lines.forEach((l, idx) => {
            let name: string | undefined;
            if (inBlock) {
              if (/^\)/.test(l)) inBlock = false;
              else name = /^\t([A-Za-z_]\w*)\b/.exec(l)?.[1];
            } else if (/^var[ \t]*\(/.test(l)) inBlock = true;
            else name = /^var[ \t]+([A-Za-z_]\w*)\b/.exec(l)?.[1];
            if (!name || SENTINEL.test(name)) return;
            if (/\b(?:errors\.New|regexp\.MustCompile|template\.Must)\(/.test(rawLines[idx])) return;
            if (/^\s*\/\/go:embed\b/.test(rawLines[idx - 1] ?? "")) return;
            jigReport(ctx, file, idx + 1, `Package-level variable ${name} is shared mutable state`,
              "Make it a field of a struct built in a constructor, or a const");
          });
        }
      },
    },
  },
} satisfies RuleSet;
