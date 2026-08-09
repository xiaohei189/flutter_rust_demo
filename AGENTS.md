# Repository Guidelines

## Project Structure & Module Organization

This repository is an OpenIM instant messaging client built with Flutter + Rust (`flutter_rust_bridge`).

- `lib/` - Flutter UI and Dart services: screens, widgets, Riverpod providers, and models.
- `rust/` - Rust SDK core, layered as `api/` (FFI) -> `sdk/` -> `core/` -> `domain/` + `infra/`.
- `rust/tests/` - Rust integration suites and JSON fixtures used by offline mock tests.
- `test/` and `integration_test/` - Flutter unit/widget and integration tests.
- `docs/` - Documentation entry point (`docs/README.md`), SDK specs in `docs/sdk-spec/`, and conventions in `docs/conventions.md`.
- `scripts/` and `rust/scripts/` - Device and test-tier helper scripts.

## Build, Test, and Development Commands

- `flutter pub get` - Install Dart dependencies.
- `flutter run -d <device>` - Run the app.
- `flutter analyze` - Static analysis for Dart.
- `flutter test test` - Run Flutter unit/widget tests.
- `cargo test --lib` / `cargo clippy --all-targets` - Fast Rust unit tests and lint checks.
- `rust/scripts/test-fast.ps1` - Fast Rust checks: unit tests, hermetic tests, and clippy.
- `rust/scripts/test-integration.ps1 -Mode Smoke` - Real OpenIM server smoke tests; `-Suite message_tests` runs one suite. Requires Docker OpenIM (ports 10001/10002/10008).
- `flutter_rust_bridge_codegen generate` - Regenerate FFI bindings after Rust API changes.
- `dart run build_runner build` - Regenerate Freezed/JSON models after model changes.

## Coding Style & Naming Conventions

- Dart files are `snake_case.dart`; classes are `PascalCase`, members `camelCase`, globals `kCamelCase`; prefer single quotes and `const`.
- Rust files/functions are `snake_case`, structs/enums `PascalCase`, constants `SCREAMING_SNAKE_CASE`; `rustfmt.toml` sets `max_width = 200`.
- Use `AppTheme` for colors, `appLog.i('[Module] description')` for logging, Chinese error messages, `SdkError` in core, and `anyhow::Error` at the FFI boundary.
- Details: `docs/conventions.md`.

## Testing Guidelines

Tests are layered; real-server suites are `#[ignore]`d and run only via scripts.

- Contract tests: verify Rust HTTP/API behavior against a real OpenIM server.
- Hermetic tests: replay `rust/tests/fixtures/` JSON with wiremock for offline logic tests; fixtures must match real server responses.
- Integration tests: end-to-end against the real server, always serial with `--test-threads=1`.
- Unit tests live next to the code (`#[cfg(test)]`); integration suites use `*_tests.rs` naming.
- Run `test-fast.ps1` before every commit; run contract tests after server/protocol changes.

## Commit & Pull Request Guidelines

- Commit messages follow `type: Chinese description` (e.g., `fix: 历史消息排序对齐 Go 策略`).
- Allowed types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `debug`, `log`, `optimize`.
- Branch from `main` as `feat/xxx` or `fix/xxx` for non-trivial changes.
- PRs should describe the change, reference the Go SDK contract where relevant, note real-server test results, and include screenshots for UI changes.
