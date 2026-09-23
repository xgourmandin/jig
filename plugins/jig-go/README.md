# jig-go

Enable in repos that contain Go.

| Component | File | What it does |
|---|---|---|
| LSP | dependency `gopls-lsp@claude-plugins-official` | Official plugin, installed automatically: gopls definitions, references, compile and vet diagnostics after each edit |
| Edit checks (PostToolUse) | `hooks/scripts/go-post-edit.sh` | `goimports -w` (fallback `gofmt -w`) on every edited `.go` file; syntax errors fed back to Claude; records the file for Stop |
| Checks (Stop) | `hooks/scripts/go-stop-check.sh` | For each module edited this session: `golangci-lint run` (repo `.golangci.yml`; `go vet` if golangci-lint is missing), then `go test`, both on the edited packages only; blocks once on failures |
| Tool check (SessionStart) | `hooks/scripts/check-tools.sh` | Tells Claude which binaries are missing |
| Skill | `skills/go-conventions` | Jig conventions, loaded automatically for Go files |

**Why no linter on edit.** golangci-lint loads and type-checks whole packages, which takes seconds per edit in a real repo. gopls already reports compile errors and most `go vet` checks after each edit, so the full lint waits for Stop.

**Modules and side effects.** The module is the nearest directory with `go.mod` (not above the git root), so monorepos and nested modules work; files outside any module are not checked. Stop runs with `-mod=readonly` (`-mod=vendor` when `vendor/modules.txt` exists), so it never changes `go.mod`/`go.sum`. Go's build and test caches live in `GOCACHE`, golangci-lint's in the plugin data dir; nothing is written to the repo. A golangci-lint config it cannot load (for example a v1 config: run `golangci-lint migrate`) only warns.

Requires `go`, `gopls`, `goimports`, `golangci-lint` (v2) and `jq` on PATH (via the repo's `mise.toml`, written by `jig-init`).
