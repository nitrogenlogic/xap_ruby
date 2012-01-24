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

		raise 'xAP BSC messages must have at least one block' if @blocks.length == 0
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

class XapBscOutgoing < XapBscMessage
	attr_accessor :state, :level, :text, :display_text

	# Initializes an xAP BSC event or info message with the given source
	# address and UID.  If is_input is truthy, this will be an input.state
	# message; if is_input is falsy, this will be an output.state message.
	# Any subsequent arguments are ignored.
	def initialize src_addr, src_uid, is_input, *args
		puts "XapBscOutgoing initialize"
		if src_addr.is_a?(Treetop::Runtime::SyntaxNode) && src_uid.is_a?(Hash)
			super src_addr, src_uid, nil, nil

			@is_input = @blocks.keys[0].downcase.start_with? 'input'
			@blocks[blockname] ||= @blocks.values[0] || {}

			# TODO: Extract block/state/level/text/etc. processing
			# code for use by all XapBsc* classes
			@blocks.values[0].clone.each do |k, v|
				case k.downcase
				when 'state'
					set_state v
				when 'level'
					set_level v
				when 'text'
					self.text = v
				when 'displaytext'
					self.display_text = v
				end

				# TODO: ID/subID
			end
		else
			super 'xAPBSC.event', src_addr, src_uid, nil
			@is_input = !!is_input
		end
	end

	# Sets the State field in the message's (input|output).status block.
	# Once the state is set, it cannot be unset, only changed.  Pass true
	# for 'ON', false for 'OFF', nil for '?'.
	def state= s
		@blocks[blockname]['State'] = case s
					      when true
						      'ON'
					      when false
						      'OFF'
					      when nil
						      '?'
					      end
		@state = s
	end

	# Sets the Level field in the message's (input|output).status block.
	# Once the level is set, it cannot be unset, only changed.  Examples:
	# pass [ 1, 5 ] to specify '1/5'.  Pass [ 35, '%' ] to specify '35%'.
	def level= num_denom_array
		raise 'num_denom_array must be an Array' unless num_denom_array.is_a? Array
		numerator, denominator = num_denom_array
		@level = [ numerator, denominator ]
		if denominator == '%'
			@blocks[blockname]['Level'] = "#{numerator.to_i}%"
		else
			@blocks[blockname]['Level'] = "#{numerator.to_i}/#{denominator.to_i}"
		end
	end

	# Sets the Text field in the message's (input|output).status block.
	# Once the text is set, it cannot be unset, only changed.
	def text= t
		raise 'Text must not include newlines' if t.include? "\n"
		@text = t
		@blocks[blockname]['Text'] = t
	end

	# Sets the Text field in the message's (input|output).status block.
	# Once the text is set, it cannot be unset, only changed.
	def display_text= t
		raise 'Display text must not include newlines' if t.include? "\n"
		@display_text = t
		@blocks[blockname]['DisplayText'] = t
	end

	protected
	# Returns 'input.state' for input messages, 'output.state' for output messages
	def blockname
		@is_input ? 'input.state' : 'output.state'
	end

	# Sets state based on the state text: "ON", "OFF", or "?"
	def set_state s
		case s.upcase
		when 'ON'
			self.state = true
		when 'OFF'
			self.state = false
		when '?'
			self.state = nil
		else
			# Don't set state for anything else
		end
	end

	# Sets level based on the level text: "x%", "y/z"
	def set_level l
		if l.include? '/'
			self.level = l.split('/').map { |v| v.to_i }
		elsif l.end_with? '%'
			self.level = [ l.to_i, '%' ]
		else
			raise "Invalid format for level: #{l}"
		end
	end
end

class XapBscEvent < XapBscOutgoing
	register_class self, 'xAPBSC.event'
end

# The xAP standard seems kind of silly for having separate info and event
# messages, especially since info messages may be sent at device startup, and
# the result of a command message must be an info message if the command
# message didn't change anything, or an event message otherwise.  Overall, the
# xAP protocol is excessively chatty.  But, it seems a lot of DIY home
# automation systems support it, so it's best to use the weak protocol you have
# rather than the perfect one you don't.
class XapBscInfo < XapBscOutgoing
	register_class self, 'xAPBSC.info'
end
