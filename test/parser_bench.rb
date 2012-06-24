#!/usr/bin/env ruby1.9.1
# A speed test for the xAP Treetop parser.
# (C)2012 Mike Bourgeous

require 'benchmark'
path = File.expand_path(File.dirname(__FILE__))
require File.join(path, '..', 'parser', 'parse_xap.rb')


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

	node = nil
	bench("ParseXap.parse", count) {
		node = ParseXap.parse(msg)
	}

	str = nil
	bench("node.to_hash", count) {
		str = node.to_hash
	}
end
