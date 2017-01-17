require 'spec_helper'

describe Kapost::Bootstrapper do

  class MockPrinter
    attr_reader :lines

    def initialize
      @lines = [""]
    end

    def puts(str)
      print str
      lines.push ""
    end

    def print(str)
      last_line << str
    end

    def last_line
      lines.last
    end

    def output
      lines.join("\n")
    end
  end

  let(:cli)      { class_spy Open3, capture2e: ["", success] }
  let(:printer)  { MockPrinter.new }
  let(:platform) { "x86_64-darwin15" } # OSX
  let(:shell)    { class_spy Kernel, exit: nil }

  let(:success)  { instance_spy Process::Status, exitstatus: 0, success?: true  }
  let(:error)    { instance_spy Process::Status, exitstatus: 1, success?: false }

  subject(:bootstrapper) { Kapost::Bootstrapper.new cli: cli,
                                            printer: printer,
                                            platform: platform,
                                            shell: shell }

  describe "#check" do

    context "with a command" do
      context "on success" do
        before do
          allow(cli).to receive(:capture2e).and_return(["", success])
          bootstrapper.instance_eval { check "acommand" }
        end

        it "should print the label" do
          expect(printer.output).to include("acommand:")
        end

        it "should print the success marker" do
          expect(printer.output).to include("✓")
        end

        it "should check if the command exists" do
          expect(cli).to have_received(:capture2e).with("bash -c 'type acommand'")
        end
      end

      context "on missing command" do
        before do
          allow(cli).to receive(:capture2e).and_return(["", error])
          bootstrapper.instance_eval { check "acommand" }
        end

        it "should print the label" do
          expect(printer.output).to include("acommand:")
        end

        it "should print the error marker" do
          expect(printer.output).to include("╳")
        end

        it "should exit with an error status" do
          expect(shell).to have_received(:exit).with(1).at_least(:once)
        end
      end
    end

    context "with help text" do
      context "on success" do
        before do
          bootstrapper.instance_eval { check("test help", "Some help text") { true } }
        end

        it "should not print the help text" do
          expect(printer.output).to_not include "Some help text"
        end
      end

      context "on error" do
        before do
          bootstrapper.instance_eval { check("test help", "Some help text") { false } }
        end

        context "with previous platform success" do
          before do
            bootstrapper.instance_eval { check("test help", "Platform help text") { osx { true } } }
          end

          it "should print the help text after the label" do
            expect(printer.output).to include "Some help text"
          end

          it "should exit" do
            expect(shell).to have_received(:exit).with(1).at_least(:once)
          end
        end
      end
    end

    context "with just a block" do
      context "that returns truthy" do
        before do
          bootstrapper.instance_eval { check("test truthy") { true } }
        end

        it "should pass" do
          expect(shell).to_not have_received(:exit)
        end
      end

      context "that returns falsey" do
        before do
          bootstrapper.instance_eval { check("test truthy") { false } }
        end

        it "should exit" do
          expect(shell).to have_received(:exit).with(1).at_least(:once)
        end
      end
    end

    context "with multiple platform support" do
      before do
        bootstrapper.instance_eval do
          check("test platform") do
            osx    { true }
            ubuntu { false }
          end
        end
      end

      context "when none of the platform blocks are called" do
        let(:platform) { "mswin" } # Windows

        it "should exit" do
          expect(shell).to have_received(:exit).with(1).at_least(:once)
        end
      end

      context "when one of the platform blocks is called" do
        context "and is truthy" do
          let(:platform) { "x86_64-darwin15" } # OSX

          it "should not exit" do
            expect(shell).to_not have_received(:exit)
          end

          it "should print the success marker" do
            expect(printer.output).to include("✓")
          end
        end

        context "and is falsey" do
          let(:platform) { "x86_64-linux" }

          it "should exit" do
            expect(shell).to have_received(:exit).with(1).at_least(:once)
          end

          it "should not print the success marker" do
            expect(printer.output).to_not include("✓")
          end
        end
      end
    end

  end

end
