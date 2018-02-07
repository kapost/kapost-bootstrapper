require "open3"
require "semantic"

module Kapost
  # Application dependency installer for this Rails application.
  class Bootstrapper

    class CommandError < StandardError
      attr_reader :command

      def initialize(command)
        @command = command
      end
    end

    class CommandNotFoundError < CommandError
      def message
        "command `%s` not found" % command
      end
    end

    class CommandVersionMismatchError < CommandError
      attr_reader :expected_version, :actual_version

      def initialize(command, expected_version, actual_version)
        super(command)
        @expected_version, @actual_version = expected_version, actual_version
      end

      def message
        "command `%s` has incorrect version. I expected %s, but you have %s" % [command, expected_version, actual_version]
      end
    end

    class CommandFailedError < CommandError
      attr_reader :status
      def initialize(command, status)
        super(command)
        @status = status
      end

      def message
        "Command `#{command}` failed with status #{status}"
      end
    end

    def initialize(cli: Open3, printer: $stdout, platform: RUBY_PLATFORM, shell: Kernel, &block)
      @cli      = cli
      @printer  = printer
      @platform = platform
      @shell    = shell

      instance_eval(&block) if block_given?
    end

    def default_check(command, version)
      installed?(command) or raise CommandNotFoundError, command
      if version
        actual_version = right_version?(command, version) or raise CommandVersionMismatchError.new(command, version, actual_version)
      end
      true
    end

    def check(command, help = nil, version: nil)
      say(label(command, version)) do
        begin
          @platform_result = false
          result = block_given? ? yield : default_check(command, version)
          @platform_result || result
        rescue CommandError => ex
          die help, exception: ex
        end
      end or die(help)
    end

    def check_bundler
      check "bundler" do
        sh "gem install bundler --conservative &>/dev/null", verbose: false
      end
    end

    def bundle
      check "gems" do
        sh "bundle check &>/dev/null || bundle install &>/dev/null", verbose: false
      end
    end

    def installed?(command)
      _, status = cli.capture2e "bash -c 'type #{command}'"
      status.success?
    end

    def right_version?(command, expected_version)
      version, status = get_version(command)
      if expected_version[0] == "^"
        next_major = (expected_version[1].to_i + 1).to_s
        Gem::Version.new(version) >= Gem::Version.new(expected_version[1..-1]) && Gem::Version.new(version) < Gem::Version.new(next_major)
      elsif expected_version[0] == "="
        Gem::Version.new(version) == Gem::Version.new(expected_version[1..-1])
      else
        local_version = Semantic::Version.new(version)
        local_version.satisfies?(expected_version)
      end
    end

    def get_version(command)
      version, status = cli.capture2e "#{command} --version"
      if version[0] == "v"
        version = version[1..-1]
      elsif version.include?("ruby")
        version.slice! "ruby "
        version = version[0..4]
      else
        version
      end
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
      result = shell.system(*cmd)
      status = $?
      raise CommandFailedError.new(cmd.join(" "), status.exitstatus) unless result
      result
    end

    def die(help, exception: nil)
      say(exception.message) if exception
      say(help) if help
      shell.exit 1
    end

    def osx(&block)
      @platform_result = run(&block) if os == :macosx
    end

    def docker(&block)
      @platform_result = run(&block) if os == :docker
    end

    def ubuntu(&block)
      @platform_result = run(&block) if os == :ubuntu
    end

    def run(&code)
      instance_eval(&code) or raise CommandError, code
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
                  if File.exist?("/.dockerenv")
                    :docker
                  elsif installed?("apt-get")
                    :ubuntu
                  else
                    :linux
                  end
                else
                  fail "unknown os: #{RUBY_PLATFORM.inspect}"
              end
    end
  end
end
