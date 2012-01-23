# Support for the xAP Basic Status and Control schema.
# (C)2012 Mike Bourgeous
#
# References:
# http://www.xapautomation.org/index.php?title=Basic_Status_and_Control_Schema

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, '..', 'xap.rb')

class XapBscMessage < XapUnsupportedMessage
	def self.parse msg, hash
		puts "Basic Status and Control"
		self.new msg, hash, nil, nil
	end

	def initialize msgclass, src_addr, src_uid, target_addr
		puts 'XapBscMessage initialize' # XXX
		super msgclass, src_addr, src_uid, target_addr

		# TODO: Parse blocks into input/output state changes
	end

	# TODO: Yields a hash for each input.* block in the message.
	def each_input &block
		raise 'each_input needs a block.' if !block_given?

		# For each message block, if it is an input block, yield the block.
	end

	# TODO: Yields a hash for each output.* block in the message.
	def each_output &block
		raise 'each_output needs a block.' if !block_given?

		# For each message block, if it is an output block, yield the block.
	end

	#TODO: Decide whether it's best to do iterators as above, and/or have
	#get_input/output(index)/set_input/output(index, value), decide how to
	#handle block-specific target, ID, state, and level, etc.
end

class XapBscCommand < XapBscMessage
	register_class self, 'xAPBSC.cmd'

	# Initializes an xAP BSC command message with the given source address
	# and UID and target address.  Any subsequent arguments are ignored.
	def initialize src_addr, src_uid, target_addr, *args
		if src_addr.is_a?(Treetop::Runtime::SyntaxNode) && src_uid.is_a?(Hash)
			super src_addr, src_uid, nil, nil
		else
			super 'xAPBSC.cmd', src_addr, src_uid, target_addr
		end
		raise 'All xAP BSC command messages must have a target address.' if @target_addr.nil?
	end
end

class XapBscQuery < XapBscMessage
	register_class self, 'xAPBSC.query'

	# Initializes an xAP BSC query message with the given source address
	# and UID and target address.  Any subsequent arguments are ignored.
	def initialize src_addr, src_uid, target_addr, *args
		if src_addr.is_a?(Treetop::Runtime::SyntaxNode) && src_uid.is_a?(Hash)
			super src_addr, src_uid, nil, nil
		else
			super 'xAPBSC.query', src_addr, src_uid, target_addr
		end
		raise 'All xAP BSC query messages must have a target address.' if @target_addr.nil?
	end
end

class XapBscEvent < XapBscMessage
	register_class self, 'xAPBSC.event'

	# Initializes an xAP BSC event message with the given source address
	# and UID.  Any subsequent arguments are ignored.
	def initialize src_addr, src_uid, *args
		if src_addr.is_a?(Treetop::Runtime::SyntaxNode) && src_uid.is_a?(Hash)
			super src_addr, src_uid, nil, nil
		else
			super 'xAPBSC.event', src_addr, src_uid, nil
		end
	end
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

	# Initializes an xAP BSC info message with the given source address and
	# UID.  Any subsequent arguments are ignored.
	def initialize src_addr, src_uid, *args
		if src_addr.is_a?(Treetop::Runtime::SyntaxNode) && src_uid.is_a?(Hash)
			super src_addr, src_uid, nil, nil
		else
			super 'xAPBSC.event', src_addr, src_uid, nil
		end
	end
end
