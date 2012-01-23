# Support for the xAP Basic Status and Control schema.
# (C)2012 Mike Bourgeous
#
# References:
# http://www.xapautomation.org/index.php?title=Basic_Status_and_Control_Schema

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, '..', 'xap.rb')

class XapBscMessage < XapUnsupportedMessage
	def self.parse *args
		puts "Basic Status and Control"
		super *args
	end
end

class XapBscCommand < XapBscMessage
	register_class self, 'xAPBSC.cmd'
end

class XapBscQuery < XapBscMessage
	register_class self, 'xAPBSC.query'
end

class XapBscEvent < XapBscMessage
	register_class self, 'xAPBSC.event'
end

# The xAP standard seems kind of silly for having separate info and event
# messages, especially since info messages may be sent at device startup, and
# the result of a command message must be an info message if the command
# message didn't change anything, or an event message otherwise.  Overall, the
# xAP protocol is excessively chatty.  But, it seems a lot of DIY home
# automation systems support it, so it's best to use the weak protocol you have
# rather than the perfect one you don't.
class XapBscInfo < XapBscMessage
	register_class self, 'xAPBSC.info'
end
