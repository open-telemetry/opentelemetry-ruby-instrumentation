---
name: Bug report
about: Notify us of an error or incorrect behavior with opentelemetry-auto-instrumentation
title: ""
labels: "bug"
assignees: ""
---

<!--

NOTE: Please use this form to submit bugs or incorrect behavior specific to the
opentelemetry-auto-instrumentation gem.

-->

## Description of the bug

<!--

Describe what happened and what you expected to happen instead.
Include any relevant error messages or stack traces.

If this is behavior that is not compliant with the OpenTelemetry Specification,
please include a link to the relevant portion of the spec.

-->

## Version information

<!--

Run: `bundle exec gem list opentelemetry-auto-instrumentation`

-->

## Share details about your runtime

<!--

Run the following to collect these values:

  ruby -e 'puts RUBY_ENGINE, RUBY_VERSION, RUBY_DESCRIPTION'

-->

## Environment configuration

<!--

Share any relevant environment variables you have set, e.g.:

  OTEL_SERVICE_NAME=my-service
  OTEL_TRACES_EXPORTER=otlp
  OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
  OTEL_RUBY_INSTRUMENTATION_ENABLED_INSTRUMENTATIONS=net_http,rack

-->

## Share a simplified reproduction if possible

<!--

```rb
require 'bundler/inline'

gemfile(true) do
  source 'https://rubygems.org'

  gem 'opentelemetry-auto-instrumentation'
end

require 'opentelemetry-auto-instrumentation'
```

-->

<sub>**Tip**: [React](https://github.blog/news-insights/product-news/add-reactions-to-pull-requests-issues-and-comments/) with 👍 to help prioritize this issue. Please use comments to provide useful context, avoiding `+1` or `me too`, to help us triage it. Learn more [in our end user docs](https://opentelemetry.io/community/end-user/issue-participation/).</sub>
