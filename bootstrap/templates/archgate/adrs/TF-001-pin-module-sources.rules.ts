/// <reference path="../rules.d.ts" />
export default {
  rules: {
    "git-source-has-ref": {
      description: "Git module sources must pin ?ref=",
      async check(ctx) {
        const matches = await ctx.grepFiles(
          /source\s*=\s*"git::[^"]*"/,
          "**/*.tf",
        );
        for (const m of matches) {
          if (!m.content.includes("?ref=")) {
            ctx.report.violation({
              message:
                "Git module source is not pinned; add ?ref=<tag or commit>",
              file: m.file,
              line: m.line,
              fix: "Append ?ref=<tag or commit SHA> to the source",
            });
          }
        }
      },
    },
  },
} satisfies RuleSet;
