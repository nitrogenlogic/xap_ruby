#!/usr/bin/env ruby1.9.1
# A test for the xAP Treetop parser.
# (C)2012 Mike Bourgeous

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, '..', 'parser', 'parse_xap.rb')

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
	node = ParseXap.parse(msg)
	puts node.to_hash, node

	s = node.to_s
	if s != msg
		puts "Before and after do not match!"
		before = msg.lines
		after = s.lines

		begin
			loop do
				puts "#{before.next.inspect}\t-\t#{after.next.inspect}"
			end
		rescue StopIteration
		end
	end
end
