#!/usr/bin/env ruby
# A test for the xAP parser.
# (C)2012 Mike Bourgeous

require 'bundler/setup'
require 'xap_ruby'

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
	node = Xap::Parser::ParseXap.parse(msg)
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

		exit -1
	end

	hash = Xap::Parser::ParseXap.simple_parse(msg)
	puts hash
	if hash != node.to_hash
		puts "Simple parsed hash and node hash do not match!"
		puts "Node hash: #{node.to_hash}"
		puts "Simple parse: #{hash}"

		exit -1
	end
end
