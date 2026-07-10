# Release History: opentelemetry-auto-instrumentation

## Unreleased

- feat: install instrumentation lazily via a `TracePoint(:end)` as libraries load, replacing the `Bundler::Runtime#require` patch. Libraries loaded after startup are now instrumented and Bundler is no longer required. Removes the `OTEL_RUBY_REQUIRE_BUNDLER` environment variable.

## v0.1.0 / 2026-07-09

Initial release.
