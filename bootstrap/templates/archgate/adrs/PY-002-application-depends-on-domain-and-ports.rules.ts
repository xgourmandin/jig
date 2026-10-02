/// <reference path="../rules.d.ts" />
// <jig-py-helpers>
// Rule files cannot import each other (archgate blocks imports), so this block is
// copied verbatim into every PY-*.rules.ts; tests/archgate-python.bats checks they match.
// Assumed layout: src/<pkg>/{domain,application,ports,adapters,bootstrap,entrypoints}/...
type JigLoc = { pkg: string; layer: string; unit: string; pkgParts: string[] };
type JigImport = { line: number; mods: string[]; star: boolean };

const JIG_LAYERS = ["domain", "application", "ports", "adapters", "bootstrap", "entrypoints"];
// Frameworks and infrastructure clients that inner layers must not import.
const JIG_INFRA = [
  "fastapi", "starlette", "flask", "django", "sqlalchemy", "sqlmodel", "alembic", "requests", "httpx", "aiohttp",
  "urllib3", "boto3", "botocore", "aioboto3", "psycopg", "psycopg2", "asyncpg", "pymongo", "redis", "celery",
  "kafka", "confluent_kafka", "pika", "grpc", "uvicorn", "gunicorn", "click", "typer", "sqlite3", "smtplib",
  "http.client", "urllib.request",
];

// Same-length copy of `src` with comments and string contents blanked (newlines kept).
function jigMask(src: string): string {
  const n = src.length;
  const blank = (s: string) => s.replace(/[^\n]/g, " ");
  let out = "";
  let i = 0;
  while (i < n) {
    const c = src[i];
    if (c === "#") {
      let j = src.indexOf("\n", i);
      if (j < 0) j = n;
      out += blank(src.slice(i, j));
      i = j;
    } else if (c === '"' || c === "'") {
      const triple = src.startsWith(c.repeat(3), i);
      const q = triple ? c.repeat(3) : c;
      let j = i + q.length;
      while (j < n) {
        if (src[j] === "\\") { j += 2; continue; }
        if (src.startsWith(q, j)) break;
        if (!triple && src[j] === "\n") break;
        j++;
      }
      j = Math.min(j, n);
      const close = src.startsWith(q, j) ? q : "";
      out += q + blank(src.slice(i + q.length, j)) + close;
      i = j + close.length;
    } else { out += c; i++; }
  }
  return out;
}

const jigLineOf = (raw: string, offset: number) => raw.slice(0, offset).split("\n").length;
// Python sources whose path passes `keep`, read in parallel and masked once. Filtering by path first means files
// of unrelated layers are never read.
async function jigSources(ctx: RuleContext, keep: (file: string) => boolean = () => true) {
  const files = ctx.scopedFiles
    .filter((f) => f.endsWith(".py") && !/(^|\/)(\.venv|venv|\.tox|node_modules|site-packages|build|dist)\//.test(f) && keep(f))
    .sort();
  const raws = await Promise.all(files.map((f) => ctx.readFile(f)));
  return files.map((file, i) => ({ file, raw: raws[i], masked: jigMask(raws[i]) }));
}

function jigLoc(file: string): JigLoc | null {
  const m = /(?:^|\/)src\/([A-Za-z_]\w*)\/(domain|application|ports|adapters|bootstrap|entrypoints)\/(.+)\.py$/.exec(file);
  if (!m) return null;
  const rest = m[3].split("/");
  const unit = rest.length === 1 && rest[0] === "__init__" ? "" : rest[0];
  return { pkg: m[1], layer: m[2], unit, pkgParts: [m[1], m[2], ...rest.slice(0, -1)] };
}

// Imports of `masked`; relative imports are resolved against the file location.
// For `from a import b` the candidates are `a` and `a.b` (b may be a submodule).
function jigImports(raw: string, masked: string, loc: JigLoc): JigImport[] {
  const out: JigImport[] = [];
  const first = (s: string) => s.trim().split(/\s+/)[0];
  let m: RegExpExecArray | null;
  const plain = /^[ \t]*import[ \t]+([^\n;]+)/gm;
  while ((m = plain.exec(masked))) {
    const line = jigLineOf(raw, m.index);
    out.push({ line, mods: m[1].split(",").map(first).filter(Boolean), star: false });
  }
  const from = /^[ \t]*from[ \t]+(\.*)([\w.]*)[ \t]+import[ \t]*(\*|\([^)]*\)|[^\n;]*)/gm;
  while ((m = from.exec(masked))) {
    const level = m[1].length;
    const modParts = m[2] ? m[2].split(".") : [];
    const base = level ? loc.pkgParts.slice(0, Math.max(0, loc.pkgParts.length - (level - 1))) : [];
    const full = [...base, ...modParts];
    const star = m[3].trim() === "*";
    const names = star ? [] : m[3].replace(/[()]/g, " ").split(",").map(first).filter(Boolean);
    const line = jigLineOf(raw, m.index);
    out.push({
      line,
      mods: [full.join("."), ...names.map((nm) => [...full, nm].join("."))],
      star,
    });
  }
  return out;
}

// Internal target of a dotted module name (`<pkg>.<layer>[.<unit>]`), else null.
function jigTarget(mod: string, loc: JigLoc): { layer: string; unit: string } | null {
  const p = mod.split(".");
  if (p[0] !== loc.pkg || !JIG_LAYERS.includes(p[1])) return null;
  return { layer: p[1], unit: p[2] ?? "" };
}
const jigInfra = (mod: string) => JIG_INFRA.find((x) => mod === x || mod.startsWith(x + "."));

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

// Report every import in files of `layers` for which `forbid` returns a reason.
async function jigCheckImports(
  ctx: RuleContext,
  id: string,
  layers: string[],
  forbid: (mod: string, loc: JigLoc) => string | null,
) {
  for (const { file, raw, masked } of await jigSources(ctx, (f) => layers.includes(jigLoc(f)?.layer ?? ""))) {
    const loc = jigLoc(file)!;
    for (const imp of jigImports(raw, masked, loc)) {
      const why = imp.mods.map((mod) => forbid(mod, loc)).find((r) => r);
      if (why) jigReport(ctx, file, imp.line, why);
    }
  }
}
// </jig-py-helpers>

export default {
  rules: {
    "application-depends-inward-only": {
      description: "Application and ports import only domain/ports/application, no adapters, entrypoints or frameworks",
      async check(ctx) {
        await jigCheckImports(ctx, "PY-002", ["application", "ports"], (mod, loc) => {
          const infra = jigInfra(mod);
          if (infra) return `${loc.layer} must not import ${infra}; put it behind a port implemented in adapters`;
          const t = jigTarget(mod, loc);
          if (t && ["adapters", "bootstrap", "entrypoints"].includes(t.layer)) {
            return `${loc.layer} must not import ${loc.pkg}.${t.layer}; depend on a port and wire it in bootstrap`;
          }
          return null;
        });
      },
    },
  },
} satisfies RuleSet;
