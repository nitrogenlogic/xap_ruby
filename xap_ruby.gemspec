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
  spec.description   = <<-EOF
  This is a Ruby library written from scratch for communicating with a home
  automation network using the xAP protocol.  Supports sending and receiving
  arbitrary xAP messages, triggering callbacks on certain received messages, etc.
  Also includes an implementation of an xAP Basic Status and Control device.
  Incoming xAP messages are parsed using an ad-hoc parser based on Ruby's
  String#split() and Array#map() (a validating Treetop parser is also available).
  Network events are handled using EventMachine.
  EOF
  spec.homepage      = 'https:'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.13'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-byebug'

  spec.add_runtime_dependency 'eventmachine', '>= 0.12.10'
  spec.add_runtime_dependency 'treetop',  '>= 1.4.10'
end
