/// <reference path="../rules.d.ts" />
// <jig-hcl-helpers>
// Rule files cannot import each other (archgate blocks imports), so this block is
// copied verbatim into every TF-*.rules.ts; tests/archgate-terraform.bats checks they match.
type JigBlock = {
  type: string;
  labels: string[];
  line: number;
  body: string;
  raw: string;
  start: number;
  end: number;
};

// Same-length copy of `src` with comments blanked and string contents blanked (newlines kept).
function jigMask(src: string): string {
  const n = src.length;
  const blank = (s: string) => s.replace(/[^\n]/g, " ");
  const skipStr = (i: number): number => {
    let j = i + 1;
    while (j < n) {
      const x = src[j];
      if (x === "\\") {
        j += 2;
        continue;
      }
      if (x === '"') return j + 1;
      if ((x === "$" || x === "%") && src[j + 1] === x && src[j + 2] === "{") {
        j += 3;
        continue;
      }
      if ((x === "$" || x === "%") && src[j + 1] === "{") {
        j += 2;
        let depth = 1;
        while (j < n && depth) {
          if (src[j] === '"') {
            j = skipStr(j);
            continue;
          }
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
      out +=
        src[end - 1] === '"' && end - i >= 2
          ? '"' + blank(src.slice(i + 1, end - 1)) + '"'
          : blank(src.slice(i, end));
      i = end;
    } else if (c === "<" && d === "<") {
      const h = /^<<-?([A-Za-z_]\w*)[ \t]*\n/.exec(src.slice(i, i + 100));
      const t = h
        ? new RegExp("\\n[ \\t]*" + h[1] + "[ \\t]*(?=\\n|$)").exec(
            src.slice(i + h[0].length - 1),
          )
        : null;
      if (h && t) {
        const j = i + h[0].length - 1 + t.index;
        out += blank(src.slice(i, j));
        i = j;
      } else {
        out += c;
        i++;
      }
    } else {
      out += c;
      i++;
    }
  }
  return out;
}

// Top-level blocks of `raw` (nested blocks: call again on `body`/`raw` of the parent).
function jigBlocks(raw: string, masked: string = jigMask(raw)): JigBlock[] {
  const out: JigBlock[] = [];
  const re =
    /^[ \t]*([A-Za-z_][\w-]*)((?:[ \t]+(?:"[^"\n]*"|[A-Za-z_][\w-]*))*)[ \t]*\{/gm;
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
    const tokens = [...header.matchAll(/"([^"\n]*)"|([A-Za-z_][\w-]*)/g)].map(
      (t) => t[1] ?? t[2],
    );
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

const jigLineOf = (raw: string, offset: number) =>
  raw.slice(0, offset).split("\n").length;
// .tf sources (plus .tfvars when `tfvars`) whose path passes `keep`, read in parallel.
async function jigSources(
  ctx: RuleContext,
  keep: (file: string) => boolean = () => true,
  tfvars = false,
) {
  const files = ctx.scopedFiles
    .filter(
      (f) =>
        (f.endsWith(".tf") || (tfvars && f.endsWith(".tfvars"))) &&
        !/(^|\/)\.terraform\//.test(f) &&
        keep(f),
    )
    .sort();
  const raws = await Promise.all(files.map((f) => ctx.readFile(f)));
  return files.map((file, i) => ({ file, raw: raws[i] }));
}
const jigIsChild = (f: string) =>
  /(^|\/)modules\//.test(f) && !/(^|\/)(examples|tests)\//.test(f);
const jigIsExample = (f: string) => /(^|\/)(examples|tests)\//.test(f);
// </jig-hcl-helpers>

export default {
  rules: {
    "root-module-has-lock-file": {
      description: "Root modules commit .terraform.lock.hcl",
      async check(ctx) {
        const dirs = new Map<string, { file: string; line: number }>();
        for (const { file, raw } of await jigSources(
          ctx,
          (f) => !jigIsChild(f) && !jigIsExample(f),
        )) {
          const dir = file.includes("/")
            ? file.slice(0, file.lastIndexOf("/"))
            : ".";
          for (const b of jigBlocks(raw)) {
            const isRoot =
              b.type === "provider" ||
              (b.type === "terraform" &&
                jigBlocks(b.raw, b.body).some(
                  (n) => n.type === "backend" || n.type === "cloud",
                ));
            if (isRoot && !dirs.has(dir)) dirs.set(dir, { file, line: b.line });
          }
        }
        // glob skips git-ignored files, so an ignored lock file counts as missing
        const locks = new Set(
          (await ctx.glob("**/.terraform.lock.hcl")).map((f) =>
            f.includes("/") ? f.slice(0, f.lastIndexOf("/")) : ".",
          ),
        );
        for (const [dir, at] of dirs) {
          if (!locks.has(dir)) {
            ctx.report.violation({
              message: `Root module ${dir} has no committed .terraform.lock.hcl`,
              file: at.file,
              line: at.line,
              fix: "Run init, then commit .terraform.lock.hcl (terraform providers lock for every platform you use)",
            });
          }
        }
      },
    },
  },
} satisfies RuleSet;
