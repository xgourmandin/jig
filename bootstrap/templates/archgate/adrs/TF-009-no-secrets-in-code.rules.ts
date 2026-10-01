/// <reference path="../rules.d.ts" />
// <jig-hcl-helpers>
// Rule files cannot import each other (archgate blocks imports), so this block is
// copied verbatim into every TF-*.rules.ts; tests/archgate-terraform.bats checks they match.
type JigBlock = { type: string; labels: string[]; line: number; body: string; raw: string; start: number; end: number };

// Same-length copy of `src` with comments blanked and string contents blanked (newlines kept).
function jigMask(src: string): string {
  const n = src.length;
  const blank = (s: string) => s.replace(/[^\n]/g, " ");
  const skipStr = (i: number): number => {
    let j = i + 1;
    while (j < n) {
      const x = src[j];
      if (x === "\\") { j += 2; continue; }
      if (x === '"') return j + 1;
      if ((x === "$" || x === "%") && src[j + 1] === x && src[j + 2] === "{") { j += 3; continue; }
      if ((x === "$" || x === "%") && src[j + 1] === "{") {
        j += 2;
        let depth = 1;
        while (j < n && depth) {
          if (src[j] === '"') { j = skipStr(j); continue; }
          if (src[j] === "{") depth++;
          else if (src[j] === "}") depth--;
          j++;
        }
        continue;
      }
      j++;
    }
    return n;
  };
  let out = "";
  let i = 0;
  while (i < n) {
    const c = src[i];
    const d = src[i + 1];
    if (c === "#" || (c === "/" && d === "/")) {
      let j = src.indexOf("\n", i);
      if (j < 0) j = n;
      out += blank(src.slice(i, j));
      i = j;
    } else if (c === "/" && d === "*") {
      let j = src.indexOf("*/", i + 2);
      j = j < 0 ? n : j + 2;
      out += blank(src.slice(i, j));
      i = j;
    } else if (c === '"') {
      const end = skipStr(i);
      out += src[end - 1] === '"' && end - i >= 2 ? '"' + blank(src.slice(i + 1, end - 1)) + '"' : blank(src.slice(i, end));
      i = end;
    } else if (c === "<" && d === "<") {
      const h = /^<<-?([A-Za-z_]\w*)[ \t]*\n/.exec(src.slice(i, i + 100));
      const t = h ? new RegExp("\\n[ \\t]*" + h[1] + "[ \\t]*(?=\\n|$)").exec(src.slice(i + h[0].length - 1)) : null;
      if (h && t) {
        const j = i + h[0].length - 1 + t.index;
        out += blank(src.slice(i, j));
        i = j;
      } else { out += c; i++; }
    } else { out += c; i++; }
  }
  return out;
}

// Top-level blocks of `raw` (nested blocks: call again on `body`/`raw` of the parent).
function jigBlocks(raw: string, masked: string = jigMask(raw)): JigBlock[] {
  const out: JigBlock[] = [];
  const re = /^[ \t]*([A-Za-z_][\w-]*)((?:[ \t]+(?:"[^"\n]*"|[A-Za-z_][\w-]*))*)[ \t]*\{/gm;
  let m: RegExpExecArray | null;
  while ((m = re.exec(masked))) {
    const open = m.index + m[0].length - 1;
    let depth = 0;
    let i = open;
    for (; i < masked.length; i++) {
      if (masked[i] === "{") depth++;
      else if (masked[i] === "}" && --depth === 0) break;
    }
    const header = raw.slice(m.index, open);
    const tokens = [...header.matchAll(/"([^"\n]*)"|([A-Za-z_][\w-]*)/g)].map((t) => t[1] ?? t[2]);
    out.push({
      type: tokens[0],
      labels: tokens.slice(1),
      line: raw.slice(0, m.index).split("\n").length,
      body: masked.slice(open + 1, i),
      raw: raw.slice(open + 1, i),
      start: m.index,
      end: i,
    });
    re.lastIndex = i + 1;
  }
  return out;
}

// `# jig:allow <ID> <reason>` on the line before a block or inside it.
// Returns "allowed", "no-reason" (comment present but no reason given) or null.
function jigAllow(raw: string, line: number, endLine: number, id: string): "allowed" | "no-reason" | null {
  const lines = raw.split("\n").slice(Math.max(0, line - 2), endLine);
  for (const l of lines) {
    const m = new RegExp("jig:allow\\s+" + id + "\\b(.*)").exec(l);
    if (m) return m[1].trim() ? "allowed" : "no-reason";
  }
  return null;
}

const jigLineOf = (raw: string, offset: number) => raw.slice(0, offset).split("\n").length;
const jigTf = async (ctx: RuleContext, pattern = "**/*.tf") =>
  (await ctx.glob(pattern)).filter((f) => !/(^|\/)\.terraform\//.test(f));
const jigIsChild = (f: string) => /(^|\/)modules\//.test(f) && !/(^|\/)(examples|tests)\//.test(f);
const jigIsExample = (f: string) => /(^|\/)(examples|tests)\//.test(f);
// </jig-hcl-helpers>

const SECRET_NAME = /(password|passwd|secret|token|api_?key|private_?key|access_?key|credential)/i;
const NOT_A_SECRET = /_(arn|id|name|path|file|url|ttl|seconds|version|ref|enabled)$|^(enable|use|create)_/i;
const looksSecret = (name: string) => SECRET_NAME.test(name) && !NOT_A_SECRET.test(name);
const KEY_MATERIAL = /AKIA[0-9A-Z]{16}|-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----/;

export default {
  rules: {
    "no-secret-values": {
      description: "No secret values in .tfvars or .tf files",
      async check(ctx) {
        const files = [...(await jigTf(ctx)), ...(await jigTf(ctx, "**/*.tfvars"))];
        for (const file of files) {
          const raw = await ctx.readFile(file);
          const lines = raw.split("\n");
          lines.forEach((text, i) => {
            if (/^\s*(#|\/\/)/.test(text)) return;
            const allow = jigAllow(raw, i + 1, i + 1, "TF-009");
            if (allow === "allowed") return;
            if (KEY_MATERIAL.test(text)) {
              ctx.report.violation({ message: "Access key id or private key material in code", file, line: i + 1 });
              return;
            }
            const kv = /^\s*([A-Za-z_][\w-]*)\s*=\s*"([^"]+)"/.exec(text);
            if (file.endsWith(".tfvars") && kv && looksSecret(kv[1]) && !kv[2].includes("${")) {
              ctx.report.violation({
                message: `${kv[1]} looks like a secret value committed in a .tfvars file`,
                file,
                line: i + 1,
                fix: "Pass it from the pipeline's secret store (TF_VAR_*) or read it from a secrets manager at apply time",
              });
            }
          });
        }
      },
    },
    "secret-variables-sensitive": {
      description: "Variables with secret-like names are sensitive and have no default",
      async check(ctx) {
        for (const file of await jigTf(ctx)) {
          const raw = await ctx.readFile(file);
          for (const b of jigBlocks(raw)) {
            if (b.type !== "variable" || !looksSecret(b.labels[0] ?? "")) continue;
            const allow = jigAllow(raw, b.line, jigLineOf(raw, b.end), "TF-009");
            if (allow === "allowed") continue;
            const name = b.labels[0];
            if (allow === "no-reason") {
              ctx.report.violation({ message: `jig:allow TF-009 on variable ${name} needs a reason`, file, line: b.line });
              continue;
            }
            if (!/\b(sensitive|ephemeral)\s*=\s*true\b/.test(b.body)) {
              ctx.report.violation({ message: `variable "${name}" looks like a secret; set sensitive = true`, file, line: b.line });
            }
            if (/^\s*default\s*=/m.test(b.body)) {
              ctx.report.violation({ message: `variable "${name}" looks like a secret; remove its default`, file, line: b.line });
            }
          }
        }
      },
    },
  },
} satisfies RuleSet;
