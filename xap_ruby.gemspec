# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'xap_ruby/version'

Gem::Specification.new do |spec|
  spec.name          = 'xap_ruby'
  spec.version       = XapRuby::VERSION
  spec.authors       = ['Mike Bourgeous']
  spec.email         = ['mike@mikebourgeous.com']

  spec.summary       = %q{A Ruby gem for the xAP home automation protocol.}
  spec.description   = <<-EOF.gsub(/^  /, '')
  This gem provides basic xAP Automation protocol support for EventMachine
  applications.  It was developed for use in Nitrogen Logic controller software.
  There are no automated tests and the code could be improved in many ways, but it
  may still be useful to someone.

  This is a Ruby library written from scratch for communicating with a home
  automation network using the xAP protocol.  Supports sending and receiving
  arbitrary xAP messages, triggering callbacks on certain received messages, etc.
  Also includes an implementation of an xAP Basic Status and Control device.
  Incoming xAP messages are parsed using an ad-hoc parser based on Ruby's
  String#split() and Array#map() (a validating Treetop parser is also available).
  Network events are handled using EventMachine.
  EOF
  spec.homepage      = 'https://github.com/nitrogenlogic/xap_ruby/'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0.3'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'

  spec.add_runtime_dependency 'eventmachine', '>= 0.12.10'
  spec.add_runtime_dependency 'treetop',  '>= 1.4.10'
end
