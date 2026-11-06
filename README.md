# OpenTelemetry Ruby Instrumentation

[![Slack channel](https://img.shields.io/badge/slack-@cncf/otel--ruby-brightgreen.svg?logo=slack)](https://cloud-native.slack.com/archives/C01NWKKMKMY)
[![Apache License](https://img.shields.io/badge/license-Apache_2.0-green.svg?style=flat)](https://github.com/open-telemetry/opentelemetry-ruby-instrumentation/blob/main/LICENSE)

The `opentelemetry-auto-instrumentation` gem provides automatic loading and initialization of the OpenTelemetry Ruby SDK for zero-code instrumentation of your applications.

- [Getting Started](#getting-started)
- [Telemetry Signals](#telemetry-signals)
- [Usage](#usage)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [OpenTelemetry Operator Image](#opentelemetry-operator-image)
- [Example](#example)
- [Contributing](#contributing)
- [Versioning](#versioning)
- [Useful links](#useful-links)
- [License](#license)

## Getting Started

Install the gem:

```console
gem install opentelemetry-auto-instrumentation
```

> **Note:** Install via `gem install` rather than adding to your Gemfile, as this gem needs to load before your application starts.

Then instrument any Ruby application:

```console
RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

For Rails (which calls `Bundler.require` automatically):

```console
RUBYOPT="-r opentelemetry-auto-instrumentation" rails server
```

For other frameworks (Sinatra, Rackup, etc.) that don't call `Bundler.require` automatically:

```console
OTEL_RUBY_REQUIRE_BUNDLER=true RUBYOPT="-r opentelemetry-auto-instrumentation" rackup config.ru
```

### What gets installed?

Installing `opentelemetry-auto-instrumentation` automatically includes:

```text
opentelemetry-sdk
opentelemetry-api
opentelemetry-instrumentation-all
opentelemetry-exporter-otlp
opentelemetry-exporter-otlp-metrics
opentelemetry-exporter-otlp-logs
opentelemetry-helpers-mysql
opentelemetry-helpers-sql-processor
opentelemetry-resource-detector-azure
opentelemetry-resource-detector-container
opentelemetry-resource-detector-aws
```

## Telemetry Signals

By default, this gem sets up **traces, metrics, and logs** and exports all three to an OTLP endpoint (`http://localhost:4318`). Each signal can be configured or disabled independently via standard OpenTelemetry environment variables.

### Traces

Traces are enabled by default using the OTLP exporter. See the [opentelemetry-sdk README][otel-sdk-readme] for full configuration options.

**Disable traces:**

```console
OTEL_TRACES_EXPORTER=none RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

**Custom endpoint:**

```console
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://my-collector:4318/v1/traces \
  RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

### Metrics

Metrics are enabled by default using the OTLP metrics exporter. See the [opentelemetry-metrics-sdk README][otel-metrics-sdk-readme] for full configuration options.

**Disable metrics:**

```console
OTEL_METRICS_EXPORTER=none RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

**Custom endpoint:**

```console
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=http://my-collector:4318/v1/metrics \
  RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

### Logs

Logs are enabled by default using the OTLP logs exporter. See the [opentelemetry-logs-sdk README][otel-logs-sdk-readme] for full configuration options.

**Disable logs:**

```console
OTEL_LOGS_EXPORTER=none RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

**Custom endpoint:**

```console
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://my-collector:4318/v1/logs \
  RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

### Disable all signals except traces

```console
OTEL_METRICS_EXPORTER=none OTEL_LOGS_EXPORTER=none \
  RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

## Usage

**Send all signals to a collector with a service name:**

```console
export OTEL_EXPORTER_OTLP_ENDPOINT="http://my-collector:4318"
export OTEL_SERVICE_NAME="my-service"
RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

**Enable only specific instrumentations:**

```console
OTEL_RUBY_ENABLED_INSTRUMENTATIONS="mysql2,redis" \
  RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

**Disable a specific instrumentation:**

```console
OTEL_RUBY_INSTRUMENTATION_SINATRA_ENABLED=false \
  RUBYOPT="-r opentelemetry-auto-instrumentation" ruby application.rb
```

**Preload gems that need to be instrumented but aren't in your Gemfile:**

```console
RUBYOPT="-r faraday -r opentelemetry-auto-instrumentation" ruby application.rb
```

**Using with `bundle exec`** (when the gem is installed outside the bundle):

```console
RUBYOPT="-r $(gem which opentelemetry-auto-instrumentation)" bundle exec rails server
```

## Configuration

The following environment variables are specific to this gem (not standard OpenTelemetry variables):

| Environment Variable | Description | Example |
| -------------------- | ----------- | ------- |
| `OTEL_RUBY_REQUIRE_BUNDLER` | Set to `true` to automatically call `Bundler.require` during initialization. Required for frameworks that don't call it automatically (e.g., Sinatra). | `true` |
| `OTEL_RUBY_RESOURCE_DETECTORS` | Comma-separated list of resource detectors. Supported: `container`, `azure`, `aws`. | `container,azure,aws` |
| `OTEL_RUBY_ENABLED_INSTRUMENTATIONS` | Only load specific instrumentations (comma-separated). Omit to load all available. | `redis,mysql2,faraday` |
| `OTEL_RUBY_ADDITIONAL_GEM_PATH` | Custom gem installation path for OpenTelemetry Operator environments. | `/custom/gem/path` |
| `DISALLOWED_LIB_PATH` | Comma-separated list of non-OpenTelemetry helper gems to exclude from additional load-path injection. Supported values: `googleapis-common-protos-types`, `google-protobuf`. | `google-protobuf` |
| `OTEL_RUBY_AUTO_INSTRUMENTATION_DEBUG` | Set to `true` for debug output during initialization. | `true` |

### Additional Gem Allowlist

The loader always injects OpenTelemetry gems from `OTEL_RUBY_ADDITIONAL_GEM_PATH` into `$LOAD_PATH`. For non-OpenTelemetry helper dependencies, it uses an internal allowlist:

- `googleapis-common-protos-types`
- `google-protobuf`

This internal list is implemented as `ADDITIONAL_LIB_GEM_ALLOWLIST` in [lib/opentelemetry-auto-instrumentation.rb](lib/opentelemetry-auto-instrumentation.rb). Use `DISALLOWED_LIB_PATH` if you need to exclude one or more entries for compatibility reasons.

### Standard OpenTelemetry Environment Variables

This gem fully supports all standard OpenTelemetry environment variables. Examples:

- `OTEL_EXPORTER_OTLP_ENDPOINT` — OTLP receiver endpoint (default: `http://localhost:4318`)
- `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` — traces-specific endpoint
- `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` — metrics-specific endpoint
- `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` — logs-specific endpoint
- `OTEL_SERVICE_NAME` — service name resource attribute
- `OTEL_RESOURCE_ATTRIBUTES` — comma-separated key=value pairs for resource attributes
- `OTEL_TRACES_EXPORTER` — trace exporter (default: `otlp`; use `console` or `none`)
- `OTEL_METRICS_EXPORTER` — metrics exporter (default: `otlp`; use `console` or `none`)
- `OTEL_LOGS_EXPORTER` — logs exporter (default: `otlp`; use `console` or `none`)
- `OTEL_TRACES_SAMPLER` — sampling strategy (e.g., `always_on`, `always_off`, `traceidratio`)

For a complete list, refer to the SDK READMEs: [opentelemetry-sdk (traces)][otel-sdk-readme], [opentelemetry-metrics-sdk (metrics)][otel-metrics-sdk-readme], [opentelemetry-logs-sdk (logs)][otel-logs-sdk-readme].

## Troubleshooting

### How Auto-Instrumentation Works

The gem patches `Bundler::Runtime#require` to inject OpenTelemetry initialization when gems are loaded. Rails calls `Bundler.require` automatically during boot; other frameworks need `OTEL_RUBY_REQUIRE_BUNDLER=true`.

### Instrumentation Timing Issues

Instrumentation is only applied to libraries loaded through `Bundler.require`. If you require a library after `Bundler.require` has already been called, it won't be instrumented. Preload it via `RUBYOPT` instead:

```console
RUBYOPT="-r faraday -r opentelemetry-auto-instrumentation" ruby application.rb
```

### Dependency Version Conflicts

This gem loads OpenTelemetry components and allowlisted helper dependencies (for example `google-protobuf` and `googleapis-common-protos-types`) directly into `$LOAD_PATH`. If your Gemfile pins different versions of these gems, you may encounter conflicts. Remove them from your Gemfile and let this gem manage them, or use `DISALLOWED_LIB_PATH` to exclude specific helper dependencies.

## OpenTelemetry Operator Image

The `autoinstrumentation-ruby` image for the [OpenTelemetry Operator](https://github.com/open-telemetry/opentelemetry-operator/blob/main/internal/config/testdata/config.yaml) is published by [publish-autoinstrumentation-ruby.yml](.github/workflows/publish-autoinstrumentation-ruby.yml). This workflow can only be triggered manually (`workflow_dispatch`) and is the way to publish a new image. The image tag is read from [docker/version.txt](docker/version.txt).

### Supported Application Containers

The image's gems are copied into the application's container and run on the application's Ruby. Only `google-protobuf` has a native extension, so it must match the application's C library, CPU architecture and Ruby version:

- **C library:** the image includes a glibc build of `google-protobuf` in `gems/` and a musl build in `musl/gems/`. The loader uses the musl build when `RbConfig::CONFIG['host_os']` contains `musl` (e.g. Alpine), and the glibc build otherwise. Images without either C library (e.g. static/scratch-based) are not supported.
- **Architecture:** the image is multi-arch (`linux/amd64`, `linux/arm64`, `linux/s390x`, `linux/ppc64le`). The container runtime pulls the variant that matches the node. See [Platform Support](#platform-support) for the Ruby versions supported on each architecture.
- **Ruby version:** Bundler resolves the gems for the builder's Ruby (3.3), so the image targets applications on Ruby 3.3 or later; the current OpenTelemetry gems require Ruby >= 3.3. The gems are added to `$LOAD_PATH` directly, so RubyGems does not enforce `required_ruby_version`, and an older application Ruby fails at runtime instead of at install time. Keep the builder Ruby at the lowest Ruby version the image supports, and keep the glibc and musl build stages on the same Ruby version.
- **Gems removed from the default gems:** `logger` is a bundled gem since Ruby 4.0, so it can't be required unless the application's Gemfile lists it. On Ruby 4.0 or later, add `gem 'logger'` to the application's Gemfile, otherwise the application fails to start with `cannot load such file -- logger`.

#### Platform Support

| Platform | C library | `google-protobuf` native extension | Application Ruby versions |
| -------- | --------- | ---------------------------------- | ------------------------- |
| `linux/amd64` | glibc, musl | Precompiled gem (`x86_64-linux-gnu`, `x86_64-linux-musl`) with binaries for each supported Ruby version | 3.3 to 4.0 |
| `linux/arm64` | glibc, musl | Precompiled gem (`aarch64-linux-gnu`, `aarch64-linux-musl`) with binaries for each supported Ruby version | 3.3 to 4.0 |
| `linux/s390x` | glibc, musl | Compiled from source for the builder's Ruby (3.3) | 3.3 only |
| `linux/ppc64le` | glibc, musl | Compiled from source for the builder's Ruby (3.3) | 3.3 only |

On `s390x` and `ppc64le`, `google-protobuf` doesn't publish a precompiled gem, so the extension is compiled during the image build and links against the builder's Ruby 3.3. Applications on any other Ruby version fail to load `google/protobuf_c`. The upper bound on `amd64` and `arm64` follows the Ruby versions that the bundled `google-protobuf` ships binaries for (3.2 to 4.0 for 4.36.x).

## Example

See [example/README.md](example/README.md)

## Contributing

We'd love your help! Use tags [good first issue](https://github.com/open-telemetry/opentelemetry-ruby-instrumentation/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) and [help wanted](https://github.com/open-telemetry/opentelemetry-ruby-instrumentation/issues?q=is%3Aissue+is%3Aopen+label%3A%22help+wanted%22) to get started with the project.

Please review the [contribution instructions](CONTRIBUTING.md) for important information on setting up your environment, running the tests, and opening pull requests.

The Ruby special interest group (SIG) meets regularly. See the OpenTelemetry [community page](https://github.com/open-telemetry/community#ruby-sig) repo for information on this and other language SIGs.

### Maintainers

- [Kayla Reopelle](https://github.com/kaylareopelle), New Relic
- [Xuan Cao](https://github.com/xuan-cao-swi), Solarwinds

For more information about the maintainer role, see the [community repository](https://github.com/open-telemetry/community/blob/main/guides/contributor/membership.md#maintainer).

### Approvers

For more information about the approver role, see the [community repository](https://github.com/open-telemetry/community/blob/main/guides/contributor/membership.md#approver).

### Emeritus

For more information about the emeritus role, see the [community repository](https://github.com/open-telemetry/community/blob/main/guides/contributor/membership.md#emeritus-maintainerapprovertriager).

## Versioning

OpenTelemetry Ruby follows the [versioning and stability document](https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/versioning-and-stability.md) in the OpenTelemetry specification. Notably, we adhere to the outlined version numbering exception, which states that experimental signals may have a `0.x` version number.

### Compatibility

OpenTelemetry Ruby ensures compatibility with the current supported versions of the [Ruby language](https://www.ruby-lang.org/en/downloads/branches/).

## Useful links

- For more information on OpenTelemetry, visit: <https://opentelemetry.io/>
- For help or feedback on this project, join us in [GitHub Discussions](https://github.com/open-telemetry/opentelemetry-ruby-instrumentation/discussions)

## License

Apache 2.0 - See [LICENSE](LICENSE) for more information.

[otel-sdk-readme]: https://github.com/open-telemetry/opentelemetry-ruby/tree/main/sdk
[otel-metrics-sdk-readme]: https://github.com/open-telemetry/opentelemetry-ruby/tree/main/metrics_sdk
[otel-logs-sdk-readme]: https://github.com/open-telemetry/opentelemetry-ruby/tree/main/logs_sdk
