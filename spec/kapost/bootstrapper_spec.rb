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

  let(:cli)      { class_spy Open3 }
  let(:printer)  { MockPrinter.new }
  let(:platform) { "x86_64-darwin15" } # OSX
  let(:shell)    { class_spy Kernel, exit: nil }

  let(:success)  { instance_spy Process::Status, exitstatus: 0 }
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
          bootstrapper.run { check "acommand" }
        end

        it "should print the label" do
          expect(printer.output).to include("acommand:")
        end

        it "should print the success marker" do
          expect(printer.output).to include("✓")
        end

        it "should check if the command exists" do
          expect(cli).to have_received(:capture2e).with("type acommand")
        end
      end

      context "on missing command" do
        before do
          allow(cli).to receive(:capture2e).and_return(["", error])
          bootstrapper.run { check "acommand" }
        end

        it "should print the label" do
          expect(printer.output).to include("acommand:")
        end

        it "should print the success marker" do
          expect(printer.output).to include("╳")
        end

        it "should exit with an error status" do
          expect(shell).to have_received(:exit).with(1)
        end
      end
    end

    context "with help text" do
      context "on success" do
        before do
          bootstrapper.run { check("test help", "Some help text") { true } }
        end

        it "should not print the help text" do
          expect(printer.output).to_not include "Some help text"
        end
      end

      context "on error" do
        before do
          bootstrapper.run { check("test help", "Some help text") { false } }
        end

        it "should print the help text after the label" do
          expect(printer.output).to include "Some help text"
        end
      end
    end

  end

end
