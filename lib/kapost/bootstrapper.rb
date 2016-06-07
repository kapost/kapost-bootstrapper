require "open3"

module Kapost
  # Application dependency installer for this Rails application.
  class Bootstrapper
    def initialize(cli: Open3, printer: $stdout, platform: RUBY_PLATFORM, shell: Kernel, &block)
      @cli      = cli
      @printer  = printer
      @platform = platform
      @shell    = shell

      run(&block) if block_given?
    end

    def osx(&block)
      instance_eval(&block) if os == :macosx
    end

    def check(command, help = nil, version: nil, &block)
      success = say(label(command, version)) do
        if block_given?
          yield
        else
          installed?(command) and (!version or right_version?(command, version))
        end
      end

      unless success
        say(help) if help
        shell.exit 1
      end
    end

    def check_bundler
      check "bundler" do
        sh "gem install bundler --conservative", verbose: false
      end
    end

    def bundle
      check "gems" do
        sh "bundle check || bundle install", verbose: false
      end
    end

    def installed?(command)
      _, status = cli.capture2e "type #{command}"
      status.success?
    end

    def right_version?(command, expected_version)
      version, status = cli.capture2e "#{command} --version"
      status.success? && version.include?(expected_version)
    end

    def say(message)
      if block_given?
        # If we're given a block print a label with a success indicator
        printer.print message.to_s
        result = yield
        result ? say("✓") : say("╳")
        result
      else
        # Otherwise, just print the message
        printer.puts message.to_s
      end
    end

    def sh(*cmd)
      options = (Hash === cmd.last) ? cmd.pop : {}
      say(cmd.join(" ")) if options[:verbose]
      result = system(*cmd)
      status = $?
      fail "Command `#{cmd.join(' ')}` failed with status #{status.exitstatus}" unless result
      result
    end

    def run(&code)
      instance_eval(&code)
    end

    private

    attr_reader :cli, :printer, :platform, :shell

    def label(text, version = nil)
      "#{[text, version].compact.join(' ')}:".ljust(15)
    end

    def os
      @os ||= case platform
                when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
                  :windows
                when /darwin|mac os/
                  :macosx
                when /linux/
                  :linux
                else
                  fail "unknown os: #{RUBY_PLATFORM.inspect}"
              end
    end
  end
end
