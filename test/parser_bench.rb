#!/usr/bin/env ruby
# A speed test for the xAP parser.
# (C)2012 Mike Bourgeous

require 'bundler/setup'
require 'benchmark'
require 'xap_ruby'

def bench name, count, &block
	puts "Running #{count} iterations of #{name}"
	result = Benchmark.measure do
		count.times &block
	end
	puts result.format("#{count} iterations: cpu=%t clock=%r")
	puts "#{count / result.real} per second"
	puts
end

if File.expand_path(__FILE__) == File.expand_path($0)
	msg = <<-EOF
xap-header
{
v=12
hop=1
uid=FF345600
class=AClass.AClassType
source=AVendor.ADevice.AnInstance
}
ASchema.ASchemaType
{
mybinary!68656C6C6F
}
Another.Block
{
mytext=6/3
}
	EOF

	count = ARGV[0] || 10000
	count = count.to_i

	hash = nil
	bench("ParseXap.simple_parse", count) {
		 hash = Xap::Parser::ParseXap.simple_parse(msg)
	}

	node = nil
	bench("ParseXap.parse", count) {
		node = Xap::Parser::ParseXap.parse(msg)
	}

	bench("node.to_hash", count) {
		hash = node.to_hash
	}
end
