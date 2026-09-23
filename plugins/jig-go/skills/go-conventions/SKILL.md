---
name: go-conventions
description: Jig conventions for writing Go code (tooling, errors, layout, concurrency, tests). Loaded automatically when working on .go files.
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/.golangci.y*ml"
user-invocable: false
---

# Go conventions (Jig)

Company-wide defaults. A repo's own `.claude/rules/` files or ADRs in `.archgate/adrs/` override them.

**Tooling.** The go toolchain and golangci-lint come from the repo's `mise.toml`. goimports formats, golangci-lint lints (config in `.golangci.yml`, v2 format), `go test` tests. The hooks run goimports after every edit and golangci-lint + `go test` on the packages you edited when you stop, so fix what they report instead of silencing it. Add dependencies with `go get <module>@<version>` and tell the user; never hand-edit `go.sum`. Run `go mod tidy` only when asked or after changing dependencies, and show the diff.

**Errors.** Return errors, don't panic (panics only for programmer bugs). Wrap with context: `fmt.Errorf("load config %s: %w", path, err)`. Compare with `errors.Is`/`errors.As`, never by string. Never discard an error with `_` without a comment saying why.

**Design.** Small interfaces, defined where they are used; accept interfaces, return concrete types. `context.Context` is the first parameter of anything that does I/O or may block; don't store it in structs. No package-level mutable state and no `init()` side effects beyond registration.

**Layout.** One module per `go.mod`; `cmd/<binary>/main.go` for binaries, `internal/` for code other modules must not import. Package names are short, lower case, no `util`/`common`. Doc comments on every exported identifier.

**Concurrency.** Every goroutine has an owner that waits for it (`sync.WaitGroup`, `errgroup`) and a way to stop (context). Protect shared state with a mutex or confine it to one goroutine; `go test -race` for concurrent code.

**Tests.** Table-driven tests with `t.Run`, standard `testing` package (no assertion library unless the repo already uses one). `t.Helper()` in helpers, `t.TempDir()` for files. A bug fix starts with a failing test. Don't weaken or skip a failing test, or add `//nolint`, to make the Stop hook pass.

**Security.** No secrets in code or tests. `exec.Command` with argument lists, never a shell with user input. Parameterise SQL. Set timeouts on HTTP clients and servers.

**Finding things.** Use the LSP (go to definition, find references, implementations, hover types) before grepping.
