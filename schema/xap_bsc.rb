# Support for the xAP Basic Status and Control schema.
# (C)2012 Mike Bourgeous
#
# References:
# http://www.xapautomation.org/index.php?title=Basic_Status_and_Control_Schema

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, '..', 'xap.rb')

class XapBscBlock
	attr_accessor :state, :level, :text, :display_text, :id

	# is_input - Whether this is an input block or an output block
	# index - If not nil, the block's index (0-based)
	# hash - The block's hash of key-value pairs from @blocks -- this will
	# be modified to
	def initialize is_input, index, hash
		@is_input = is_input
		@index = index
		@hash = hash

		@hash.clone.each do |k, v|
			case k.downcase
			when 'state'
				@hash.delete k
				set_state v
			when 'level'
				@hash.delete k
				set_level v
			when 'text'
				@hash.delete k
				self.text = v
			when 'displaytext'
				@hash.delete k
				self.display_text = v
			when 'id'
				@hash.delete k
				self.id = v.upcase
			end

			# TODO: ID/subID
		end
	end

	# Sets this block's State field.  Once the state is set, it cannot be
	# unset, only changed.  Pass true for 'ON', false for 'OFF', nil or any
	# other value for '?'.
	def state= s
		@state = s
		@hash['State'] = case s
				 when true
					 'ON'
				 when false
					 'OFF'
				 else
					 @state = '?'
					 '?'
				 end
	end

	# Sets this block's Level field.  Once the level is set, it cannot be
	# unset, only changed.  Examples: pass [ 1, 5 ] to specify '1/5'.  Pass
	# [ 35, '%' ] to specify '35%'.
	def level= num_denom_array
		raise 'num_denom_array must be an Array.' unless num_denom_array.is_a? Array
		numerator, denominator = num_denom_array
		@level = [ numerator, denominator ]
		if denominator == '%'
			@hash['Level'] = "#{numerator.to_i}%"
		else
			@hash['Level'] = "#{numerator.to_i}/#{denominator.to_i}"
		end
	end

	# Sets this block's Text field.  Once the text is set, it cannot be
	# unset, only changed.
	def text= t
		raise 'Text must not include newlines.' if t.include? "\n"
		@text = t
		@hash['Text'] = t
	end

	# Sets this block's DisplayText field.  Once the display text is set,
	# it cannot be unset, only changed.
	def display_text= t
		raise 'Display text must not include newlines.' if t.include? "\n"
		@display_text = t
		@hash['DisplayText'] = t
	end

	# Sets this block's ID field.  The given ID must be a String containing
	# either two uppercase hex digits or a single asterisk.  Once the ID is
	# set, it cannot be unset, only changed.
	def id= i
		raise 'ID must be two uppercase hex digits or *.' unless i =~ /^([0-9A-Z][0-9A-Z]|\*)$/
		@id = i
		@hash['ID'] = i
	end

	# Returns 'input.state(.nn)' for input messages, 'output.state(.nn)' for output messages
	def blockname
		s = @is_input ? 'input.state' : 'output.state'
		s << ".#{@index + 1}" if @index
		s
	end

	# Returns a human-readable string description of this block.
	def inspect
		"Name: #{blockname} ID: #{id} State: #{state} Level: #{level} Text: #{text} DisplayText: #{display_text}"
	end

	protected
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

class XapBscMessage < XapUnsupportedMessage
	def self.parse msg, hash
		self.new msg, hash, nil, nil, nil
	end

	def initialize msgclass, src_addr, src_uid, target_addr, is_input
		super msgclass, src_addr, src_uid, target_addr

		if msgclass.is_a?(Treetop::Runtime::SyntaxNode) && src_addr.is_a?(Hash)
			raise 'xAP BSC messages must have at least one block' if @blocks.length == 0
			@is_input = @blocks.keys[0].downcase.start_with? 'input'
		else
			@is_input = is_input
		end

		@bsc_blocks = []
		idx = 0
		@blocks.each do |k, v|
			kdown = k.downcase
			if kdown.start_with?('input') || kdown.start_with?('output')
				@bsc_blocks << XapBscBlock.new(@is_input, idx, v)
			end
			idx += 1 if idx
		end
	end

	# Returns a human-readable string description of this message.
	def inspect
		s = "XapBscMessage: #{@bsc_blocks.length} blocks recognized, #{@blocks.length} total\n"
		s << "Blocks: \n"
		@bsc_blocks.each do |blk|
			s << "\t#{blk.inspect}\n"
		end
		s << "Regenerated message:\n\t"
		s << super.lines.to_a.join("\t")
	end

	# Yields each XapBscBlock in sequence.
	def each_block &block
		@bsc_blocks.each do |b|
			yield b
		end
	end
end

class XapBscCommand < XapBscMessage
	register_class self, 'xAPBSC.cmd'

	# Initializes an xAP BSC command message with the given source address
	# and UID and target address.  Any subsequent arguments are ignored.
	def initialize src_addr, src_uid, target_addr, *args
		if src_addr.is_a?(Treetop::Runtime::SyntaxNode) && src_uid.is_a?(Hash)
			super src_addr, src_uid, nil, nil, nil
		else
			super 'xAPBSC.cmd', src_addr, src_uid, target_addr, false
		end
		raise 'All xAP BSC command messages must have a target address.' if @target_addr.nil?
		check_block 0
	end

	# Gets the State value of the index-th block (0-based).  Returns true
	# for 'ON', false for 'OFF', '?' for '?' or any other value, and nil
	# for undefined.  Throws an error if index is out of range.
	def get_state index
		@bsc_blocks[index].state
	end

	# Sets the State value of the index-th block (0-based).  Pass true for
	# 'ON', false for 'OFF', any other value for '?'.  The block will be
	# created if it is not present.  It is up to the caller to avoid
	# creating gaps in the block indexes.
	def set_state index, value
		check_block index
		@bsc_blocks[index].state = value
	end

	# Gets the Level value of the index-th block (0-based).  Returns a
	# two-element array with the numerator and '%' if the message contains
	# a percentage level, or the numerator and denominator if the message
	# contains a ranged level.  Throws an error if index is out of range.
	def get_level index
		@bsc_blocks[index].level
	end

	# Sets the Level value of the index-th block (0-based).  The value
	# parameter must be a two-element array containing the numerator and
	# '%' for a percentage level, or the numerator and the denominator for
	# a ranged level.  The block will be created if it is not present.  It
	# is up to the caller to avoid creating gaps in the block indexes.
	def set_level index, value
		check_block index
		@bsc_blocks[index].level = value
	end

	# Gets the Text value of the index-th block (0-based).  Throws an error
	# if index is out of range.
	def get_text index
		@bsc_blocks[index].text
	end

	# Sets the Text value of the index-th block (0-based).  The block will
	# be created if it is not present.  It is up to the caller to avoid
	# creating gaps in the block indexes.
	def set_text index, value
		check_block index
		@bsc_blocks[index].text = value
	end

	# Gets the DisplayText value of the index-th block (0-based).  Throws an error
	# if index is out of range.
	def get_display_text index
		@bsc_blocks[index].display_text
	end

	# Sets the DisplayText value of the index-th block (0-based).  The block will
	# be created if it is not present.  It is up to the caller to avoid
	# creating gaps in the block indexes.
	def set_display_text index, value
		check_block index
		@bsc_blocks[index].display_text = value
	end

	# Gets the ID value of the index-th block (0-based).  Throws an error
	# if index is out of range.
	def get_id index
		@bsc_blocks[index].id
	end

	# Sets the ID value of the index-th block (0-based).  The ID given must
	# be either two uppercase hex digits or a single asterisk.  The block
	# will be created if it is not present.  It is up to the caller to
	# avoid creating gaps in the block indexes.
	def set_id index, value
		check_block index
		@bsc_blocks[index].id = value
	end

	private
	def check_block index
		unless @bsc_blocks[index]
			h = {}
			blk = XapBscBlock.new @is_input, index, h
			@bsc_blocks[index] = blk
			@blocks[blk.blockname] = h
		end
	end
end

class XapBscQuery < XapBscMessage
	register_class self, 'xAPBSC.query'

	# Initializes an xAP BSC query message with the given source address
	# and UID and target address.  Any subsequent arguments are ignored.
	def initialize src_addr, src_uid, target_addr, *args
		if src_addr.is_a?(Treetop::Runtime::SyntaxNode) && src_uid.is_a?(Hash)
			super src_addr, src_uid, nil, nil, nil
		else
			super 'xAPBSC.query', src_addr, src_uid, target_addr
			@blocks['request'] = {}
		end
		raise 'All xAP BSC query messages must have a target address.' if @target_addr.nil?
	end
end

# Shared functionality between info and event messages.
class XapBscResponse < XapBscMessage
	attr_accessor :state, :level, :text, :display_text

	# Initializes an xAP BSC event or info message with the given source
	# address and UID.  If is_input is truthy, this will be an input.state
	# message; if is_input is falsy, this will be an output.state message.
	# Any subsequent arguments are ignored.
	def initialize src_addr, src_uid, is_input, *args
		if src_addr.is_a?(Treetop::Runtime::SyntaxNode) && src_uid.is_a?(Hash)
			super src_addr, src_uid, nil, nil, nil
		else
			super self.class.classname, src_addr, src_uid, nil, is_input
			@is_input = !!is_input

			h = {}
			blk = XapBscBlock.new @is_input, nil, h
			@bsc_blocks[0] = blk
			@blocks[blk.blockname] = h
		end
	end

	# Sets the State field in the message's (input|output).status block.
	# Once the state is set, it cannot be unset, only changed.  Pass true
	# for 'ON', false for 'OFF', nil for '?'.
	def state= s
		@bsc_blocks[0].state = s
	end

	# Sets the Level field in the message's (input|output).status block.
	# Once the level is set, it cannot be unset, only changed.  Examples:
	# pass [ 1, 5 ] to specify '1/5'.  Pass [ 35, '%' ] to specify '35%'.
	def level= num_denom_array
		@bsc_blocks[0].level = num_denom_array
	end

	# Sets the Text field in the message's (input|output).status block.
	# Once the text is set, it cannot be unset, only changed.
	def text= t
		@bsc_blocks[0].text = t
	end

	# Sets the DisplayText field in the message's (input|output).status
	# block.  Once the display text is set, it cannot be unset, only
	# changed.
	def display_text= t
		@bsc_blocks[0].display_text = t
	end

	# Gets the message's State value.  Returns true for 'ON', false for
	# 'OFF', '?' for '?' or any other value, and nil for undefined.
	def state
		@bsc_blocks[0].state
	end

	# Gets the Level value, if any.  Returns a two-element array with the
	# numerator and '%' if the message contains a percentage level, or the
	# numerator and denominator if the message contains a ranged level.
	def level
		@bsc_blocks[0].level
	end

	# Gets the message's Text value, if any.
	def text
		@bsc_blocks[0].text
	end

	# Gets the message's DisplayText value, if any.
	def display_text
		@bsc_blocks[0].display_text
	end
end

class XapBscEvent < XapBscResponse
	@@classname = 'xAPBSC.event'
	register_class self, @@classname

	def self.classname
		@@classname
	end
end

# The xAP standard seems kind of silly for having separate info and event
# messages, especially since info messages may be sent at device startup, and
# the result of a command message must be an info message if the command
# message didn't change anything, or an event message otherwise.  Overall, the
# xAP protocol is excessively chatty.  But, it seems a lot of DIY home
# automation systems support it, so it's best to use the weak protocol you have
# rather than the perfect one you don't.
class XapBscInfo < XapBscResponse
	@@classname = 'xAPBSC.info'
	register_class self, @@classname

	def self.classname
		@@classname
	end
end
