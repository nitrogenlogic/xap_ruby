# Treetop parser for xAP messages
# (C)2012 Mike Bourgeous
#
# References:
# http://thingsaaronmade.com/blog/a-quick-intro-to-writing-a-parser-using-treetop.html
# http://treetop.rubyforge.org/syntactic_recognition.html
# http://treetop.rubyforge.org/using_in_ruby.html
# http://www.xapautomation.org/index.php?title=Protocol_definition

require 'treetop'
require_relative 'xap_nodes'

module Xap
	module Parser
		module ParseXap
			path = File.expand_path(File.dirname(__FILE__))
			Treetop.load(File.join(path, 'xap.treetop'))
			@@parser = XapTreetopParser.new

			# Returns a Treetop node tree for the given xAP message
			def self.parse(data)
				tree = @@parser.parse(data, :root => :message)

				if !tree
					raise Exception, "Parse error: #{@@parser.failure_reason.inspect} (index #{@@parser.index})"
				end

				tree
			end

			# Returns a hash that is equivalent to calling parse(data).to_hash(),
			# but much faster.  However, this method does not do any explicit
			# checking for invalid messages or values.
			def self.simple_parse(data)
				Hash[*data.split(/}\n?/).map {|v|
					bl = v.split("\n{\n")
					bl[1] = Hash[*bl[1].to_s.split("\n").map {|v2|
						pair = v2.split(/[=!]/, 2)
						pair[1] = [pair[1]].pack 'H*' if v2 =~ /^[^=!]+!/
						pair
					}.flatten!]
					bl
				}.flatten!(1)]
			end
		end
	end
end
