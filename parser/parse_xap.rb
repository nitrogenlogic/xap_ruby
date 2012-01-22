#!/usr/bin/env ruby1.9.1
# Treetop parser for xAP messages
# (C)2012 Mike Bourgeous
#
# References:
# http://thingsaaronmade.com/blog/a-quick-intro-to-writing-a-parser-using-treetop.html
# http://treetop.rubyforge.org/syntactic_recognition.html
# http://treetop.rubyforge.org/using_in_ruby.html
# http://www.xapautomation.org/index.php?title=Protocol_definition

path = File.expand_path(File.dirname(__FILE__))

require 'treetop'
require File.join(path, 'xap_nodes.rb')

Treetop.load(File.join(path, 'xap.treetop'))
module ParseXap
	@@parser = XapParser.new

	def self.parse(data)
		tree = @@parser.parse(data, :root => :message)

		if !tree
			raise Exception, "Parse error: #{@@parser.failure_reason.inspect} (index #{@@parser.index})"
		end

		tree
	end
end

if File.expand_path(__FILE__) == File.expand_path($0)
	puts ParseXap.parse(<<-EOF).blocks
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
	EOF
end
