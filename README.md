# Kapost::Bootstrapper

Used by Kapost apps to get themselves bootstrapped. To enhance developer happiness, every app should have a single command to get it set up (`./bin/setup`) and one command to run the whole thing (`./bin/run`). This gem attempts to help with the first script by encapsulating a useful set of helper functions that makes detecting and installing dependencies simpler.

## Installation

Add a file to your project called `bin/setup` with these contents:

```bash
#!/usr/bin/env bash

set -euvxo pipefail

gem which kapost-bootstrapper || gem install kapost-bootstrapper

./bin/bootstrap
```

Then, use the gem's helper functions in your file called `./bin/bootstrap`. See usage for examples.

## Usage

Example `./bin/bootstrap`:

```ruby
#!/usr/bin/env/ruby

require "pathname"

require "kapost/bootstrapper"

$LOAD_PATH << File.join(__dir__, "..", "lib")
app_root = Pathname.new File.expand_path("../../",  __FILE__)

Kapost::Bootstrapper.new do
  puts "== Checking application dependencies =="

  # only run these commands on this platform. See also `#ubuntu`.
  osx do

    # `check` looks for the command specified by name, and prints the help if
    # it isn't present.
    check "brew", "Homebrew isn't installed. How did you even get this far?"
  end

  # The optional `version` attempts to do a substring match on `{cmd} --version`.
  # Also note the use of HEREDOC for the help string.
  required_ruby_version = File.read(app_root.join(".ruby-version")).strip
  check "ruby", <<~HELP, version: required_ruby_version
    Wrong Ruby version, please install #{required_ruby_version}, and make
    sure it is the current Ruby.  The DevOps team recommends
    [chruby](https://github.com/postmodern/chruby#readme) and
    [ruby-install](https://github.com/postmodern/ruby-install#readme). Both
    are available in Homebrew.
  HELP

  # When `#check` is given a block, it is executed rather than the built-in check.
  # If the block returns true-ish, it is assumed to have worked, and the bootstrap
  # process continues. When false-ish, the help is printed and boostrap is halted.
  check "elasticsearch" do
    # The `#installed?` helper does the same as the default `#check`, and merely checks
    # if the command is available.
    if installed?("elasticsearch")
      true
    else
      # Use `#sh` to execute shell commands.
      osx    { sh "brew install elasticsearch" }
      ubuntu { sh "apt-get install elasticsearch" }
    end
  end

  check "postgresql" do
    if installed?("psql")
      true
    else
      osx    { sh "brew install postgresql" }
      ubuntu { sh "apt-get install postgresql" }
    end
  end

  # `#check_bundler` checks if Bundler is installed, and installs it if not.
  # `#bundle` does exactly what you'd think.
  check_bundler && bundle

  # Test if an environment variable is present
  check "env", <<~HELP do
    You need to load the environment variables located in `.env` into your
    local shell environment.  The DevOps team recommends
    [direnv](http://direnv.net/) (available in homebrew).
  HELP
    !ENV["PORT"].nil?
  end

  # Check different variables, with different instructions.
  check "AWS tokens", <<~HELP do
    You need to set "AWS_REGION", "AWS_ACCESS_KEY_ID" and
    "AWS_SECRET_ACCESS_KEY" in your local shell environment. Contact the
    #devops channel if you don't already have some. The DevOps team recommends
    setting them in a `.env.local` file, and using [direnv](http://direnv.net/)
    (available in homebrew) to load them.
  HELP
    !ENV["AWS_ACCESS_KEY_ID"].nil?
  end

  # At this point, all dependencies are assumed to be installed, and the app should be
  # bootable. Do some further checks and setup, like verifying DB connections and
  # migrating, etc...
  sh "rake setup"
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kapost/kapost-bootstrapper.

