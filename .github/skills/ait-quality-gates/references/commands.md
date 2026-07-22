# Gate Commands — per stack

Prefer existing repo scripts/CI over these defaults. Use the smallest scope first
(changed package/module) then widen.

## Node / TypeScript
- build: `npm run build` · `pnpm build` · `yarn build`
- lint:  `npm run lint` · `eslint . --max-warnings=0`
- format:`prettier --check .`
- unit:  `npm test` · `vitest run` · `jest`
- e2e:   `playwright test` · `cypress run`
- security: `npm audit --audit-level=high`

## Python
- build: `python -m build` (packaging) or import check
- lint:  `ruff check .` · `flake8`
- format:`black --check .` · `ruff format --check .`
- type:  `mypy .`
- unit:  `pytest -q`
- security: `pip-audit` · `bandit -r .`

## .NET
- build: `dotnet build -warnaserror`
- format:`dotnet format --verify-no-changes`
- unit:  `dotnet test`
- security: `dotnet list package --vulnerable`

## Go
- build: `go build ./...`
- lint:  `go vet ./...` · `golangci-lint run`
- unit:  `go test ./...`
- security: `govulncheck ./...`

## Java
- build: `mvn -q compile` · `gradle build`
- unit:  `mvn test` · `gradle test`
- security: `mvn dependency-check:check` (if plugin present)

## Rust
- build: `cargo build`
- lint:  `cargo clippy -- -D warnings`
- unit:  `cargo test`
- security: `cargo audit`

## Cross‑cutting
- secret scan: `gitleaks detect` (if available), else grep for common key patterns.
- SCA/deps: use the stack's native audit above.
- Mirror `.github/workflows/*` so local gates match CI.
