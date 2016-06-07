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

  let(:success)  { instance_spy Process::Status, exitstatus: 0 }
  let(:failure)  { instance_spy Process::Status, exitstatus: 1 }

  subject(:run!) { Kapost::Bootstrapper.new cli: cli, printer: printer, platform: platform, &code }

  describe "#check" do

    context "with a command" do

      let(:code) do
        Proc.new { check "acommand" }
      end

      context "on success" do
        before do
          allow(cli).to receive(:capture2e).and_return(["", success])
          run!
        end

        it "should print the label" do
          expect(printer.output).to include("acommand:      ✓")
        end

        it "should check if the command exists" do
          expect(cli).to have_received(:capture2e).with("type acommand")
        end


      end

    end

  end

end
