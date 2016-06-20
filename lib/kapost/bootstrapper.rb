require "open3"

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
      installed?(command) and (!version or right_version?(command, version))
    end

    def check(command, help = nil, version: nil)
      say(label(command, version)) do
        begin
          block_given? ? yield : default_check(command, version)
          true
        rescue CommandError => ex
          die help, exception: ex
        end
      end
      true
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
      raise CommandNotFoundError, command unless status.success?
      true
    end

    def right_version?(command, expected_version)
      version, status = cli.capture2e "#{command} --version"
      unless status.success? && version.include?(expected_version)
        raise CommandVersionMismatchError, command, expected_version, version
      end
      true
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
      result = cli.system(*cmd)
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
      run(&block) if os == :macosx
    end

    def docker(&block)
      run(&block) if os == :docker
    end

    def ubuntu(&block)
      run(&block) if os == :ubuntu
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
