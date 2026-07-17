# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'simplecov'
SimpleCov.start

require 'rake'
require 'minitest'
require 'minitest/autorun'
require 'net/http'

# Runs the auto-instrumentation loading logic inside a forked subprocess so that
# each test starts from a clean Ruby process with no previously loaded constants,
# initialized providers, or mutated global state.
#
# Loading the gem configures the SDK and enables the TracePoint installer, which
# installs instrumentation for already-loaded libraries immediately and for
# later-loaded ones as their classes are defined.
#
# Five mutually-exclusive execution branches exist to cover distinct scenarios:
#
# Branch 1 – Bundler warning simulation (dep_names: or raise_error: opts)
#   Simulates what happens when the user's Gemfile contains OpenTelemetry gems, or
#   when Bundler itself raises during the gem-list check. The subprocess stubs
#   Bundler.definition so no real bundle resolution occurs, then calls
#   _otel_check_for_bundled_otel_gems directly and captures any stderr warnings.
#
# Branch 2 – Signal data inspection (inspect_signals: true opt)
#   Simulates a fully initialised SDK where real telemetry data is produced and
#   collected in-memory. Registers in-memory exporters for all three signals
#   (traces, metrics, logs), exercises each signal, and returns the captured data
#   so tests can assert on specific span names, counter values, and log bodies.
#
# Branch 3 – Late-loading via TracePoint (late_load: true opt)
#   Registers a fake instrumentation after the installer is enabled, whose present?
#   flips only once a sentinel class is defined. Defining that class fires
#   TracePoint(:end), which must run the sweep and install it. Returns installed?
#   before and after so the test can assert late-loaded libraries get instrumented.
#
# Branch 4 – Repeated install attempts (install_attempts: true opt)
#   Registers a fake instrumentation that is present but can never install, then fires
#   the TracePoint several times. Returns how many install attempts it received so the
#   test can assert an uninstallable instrumentation is retried at most once.
#
# Branch 5 – Default provider class verification (no special opts)
#   Simulates normal application startup. Returns provider class names, resource
#   attributes, and the list of installed instrumentation so tests can assert the
#   SDK wired up the correct implementation classes.
def run_in_subprocess(env_vars = {}, opts = {})
  skip 'fork is not available on this platform' unless Process.respond_to?(:fork)

  dep_names = opts[:dep_names]
  raise_error = opts.fetch(:raise_error, false)

  read_pipe, write_pipe = IO.pipe

  pid = fork do
    SimpleCov.command_name "subprocess-#{Process.pid}"
    read_pipe.close
    env_vars.each { |key, value| ENV[key] = value }

    begin
      load auto_instrumentation_path

      require 'stringio'
      stderr_capture = StringIO.new
      old_stderr = $stderr
      $stderr = stderr_capture

      result = {}

      # Branch 1: Bundler warning simulation
      if !dep_names.nil? || raise_error
        fake_dep = Struct.new(:name)
        fake_deps = (dep_names || []).map { |n| fake_dep.new(n) }

        if raise_error
          # Suppress the Ruby "method redefined" warning that define_singleton_method
          # produces when overwriting Bundler's existing :definition method.
          old_verbose = $VERBOSE
          $VERBOSE = nil
          Bundler.define_singleton_method(:definition) { raise StandardError, 'simulated bundler error' }
        else
          fake_definition = Object.new
          fake_definition.define_singleton_method(:dependencies) { fake_deps }
          old_verbose = $VERBOSE
          $VERBOSE = nil
          Bundler.define_singleton_method(:definition) { fake_definition }
        end
        $VERBOSE = old_verbose

        OTelInitializer._otel_check_for_bundled_otel_gems
      # Branch 2: Signal data inspection
      # it attaches in-memory exporters to the already-configured providers
      # and exercises them with real data.
      elsif opts[:inspect_signals]
        # --- Traces ---
        span_exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
        span_processor = OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(span_exporter)
        OpenTelemetry.tracer_provider.add_span_processor(span_processor)
        tracer = OpenTelemetry.tracer_provider.tracer('test-tracer')
        tracer.in_span('test-span') { |span| span.set_attribute('test.key', 'test.value') }
        result[:spans] = span_exporter.finished_spans.map do |s|
          { name: s.name, attributes: s.attributes.to_h }
        end

        # --- Metrics ---
        metric_exporter = OpenTelemetry::SDK::Metrics::Export::InMemoryMetricPullExporter.new
        OpenTelemetry.meter_provider.add_metric_reader(metric_exporter)
        meter = OpenTelemetry.meter_provider.meter('test-meter')
        counter = meter.create_counter('test.counter', unit: '1', description: 'Test counter')
        counter.add(3, attributes: { 'env' => 'test' })
        metric_exporter.pull
        result[:metrics] = metric_exporter.metric_snapshots.map do |m|
          {
            name: m.name,
            data_points: m.data_points.map { |dp| { value: dp.value, attributes: dp.attributes.to_h } }
          }
        end

        # --- Logs ---
        log_exporter = OpenTelemetry::SDK::Logs::Export::InMemoryLogRecordExporter.new
        log_processor = OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(log_exporter)
        OpenTelemetry.logger_provider.add_log_record_processor(log_processor)
        otel_logger = OpenTelemetry.logger_provider.logger(name: 'test-logger')
        otel_logger.on_emit(severity_text: 'INFO', body: 'test log message')
        result[:logs] = log_exporter.emitted_log_records.map do |lr|
          { body: lr.body, severity_text: lr.severity_text }
        end
      # Branch 3: Late-loading via TracePoint
      elsif opts[:late_load]
        # A fake instrumentation registered after the installer is enabled. present?
        # returns true only once OTelLateLoadSentinel exists, so the initial sweep
        # skips it. Defining that class fires TracePoint(:end), whose sweep must then
        # install it.
        Object.const_set(:OTelLateLoadInstrumentation, Class.new(OpenTelemetry::Instrumentation::Base) do
          present { defined?(OTelLateLoadSentinel) ? true : false }
          install { |_| true }
        end)

        result[:installed_before] = OTelLateLoadInstrumentation.instance.installed?
        eval 'class OTelLateLoadSentinel; end', TOPLEVEL_BINDING, __FILE__, __LINE__
        result[:installed_after] = OTelLateLoadInstrumentation.instance.installed?
      # Branch 4: Repeated install attempts
      elsif opts[:install_attempts]
        # A fake instrumentation whose library is present but which can never install
        # (incompatible). compatible? counts each install attempt. Defining classes
        # fires the TracePoint repeatedly; the installer must attempt it at most once,
        # not on every fire.
        attempts = 0
        Object.const_set(:OTelProbeInstrumentation, Class.new(OpenTelemetry::Instrumentation::Base) do
          present { true }
          compatible do
            attempts += 1
            false
          end
          install { |_| true }
        end)

        3.times { eval 'class OTelProbeTrigger; end', TOPLEVEL_BINDING, __FILE__, __LINE__ }
        result[:install_attempts] = attempts
      # Branch 5: Default provider class verification
      else
        tracer_provider = OpenTelemetry.tracer_provider
        resource = tracer_provider.instance_variable_get(:@resource)
        resource_attributes = resource.instance_variable_get(:@attributes)
        registry = tracer_provider.instance_variable_get(:@registry)
        instrumentation_names = registry.map { |entry| entry.first.name }
        trace_point = OTelInitializer.instance_variable_get(:@_otel_trace_point)

        result.merge!(
          tracer_provider_class: tracer_provider.class.name,
          meter_provider_class: OpenTelemetry.meter_provider.class.name,
          logger_provider_class: OpenTelemetry.logger_provider.class.name,
          resource_attributes: resource_attributes,
          instrumentation_names: instrumentation_names,
          trace_point_enabled: trace_point ? trace_point.enabled? : false
        )
      end

      $stderr = old_stderr
      result[:warning_output] = stderr_capture.string
      write_pipe.write(Marshal.dump(result))
    rescue StandardError => e
      $stderr = old_stderr if defined?(old_stderr)
      error_result = Marshal.dump({ error: e.message, backtrace: e.backtrace,
                                    warning_output: defined?(stderr_capture) ? stderr_capture.string : '' })
      write_pipe.write(error_result)
    ensure
      $stderr = old_stderr if defined?(old_stderr)
      write_pipe.close

      # Store the simplecov result for this process
      SimpleCov::ResultMerger.store_result(SimpleCov::Result.new(Coverage.result)) if SimpleCov.running
      exit!(0)
    end
  end

  write_pipe.close
  result_data = read_pipe.read
  read_pipe.close
  Process.wait(pid)

  # rubocop:disable Security/MarshalLoad
  Marshal.load(result_data)
  # rubocop:enable Security/MarshalLoad
end
