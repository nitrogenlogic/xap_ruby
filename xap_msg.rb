# xAP message base class definitions
# (C)2012 Mike Bourgeous

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, 'xap.rb')

# Base class for all xAP message types.  Registered subclasses must implement
# a parse method that accepts the Treetop node hierarchy and resulting hash as
# its first two parameters.
class XapMessage
	@@msgtypes = {}

	attr_accessor :src_addr, :target_addr, :version, :hop, :uid, :msgclass, :headername

	# Parses the given data as an xAP message.  If the message type does
	# not have a registered handler, an exception will be raised
	def self.parse data
		raise 'data must be (convertible to) a String' unless data.respond_to? :to_s

		msg = ParseXap.parse data.to_s
		msghash = msg.to_hash

		headername = msg.first_block.downcase
		raise "No handlers defined for #{headername} message headers." unless @@msgtypes[headername]

		classname = msghash[headername]['class']
		raise 'Message lacks a class field in its header.' unless classname || @@msgtypes[headername][nil]
		classname.downcase!

		handler = @@msgtypes[headername][classname] || @@msgtypes[headername][nil]
		raise "No handler defined for #{headername}/#{classname} messages." unless handler

		handler.parse msg, msghash
	end

	# Registers the given klass as the handler for msgclass messages, with
	# the header block called headername ('xap-header' by default).
	#
	# Specify nil for msgclass to register a fallback handler for messages
	# with the given header name that don't have a specific class handler
	# registered.
	def self.register_class klass, msgclass, headername='xap-header'
		unless klass.is_a?(Class) && klass < XapMessage
			raise "klass must be a Class that inherits XapMessage, not #{klass.inspect}"
		end
		raise 'msgclass must be nil or a String' unless msgclass.nil? || msgclass.is_a?(String)

		Xap.log "Registered support for #{headername}/#{msgclass} messages via #{klass.name}"

		# TODO: Support regex for msgclass?
		headername.downcase!
		msgclass.downcase! if msgclass.is_a? String
		@@msgtypes[headername] = @@msgtypes[headername] || {}
		@@msgtypes[headername][msgclass] = klass
	end

	# msgclass - the message's class
	# src_addr - the message's source address
	# src_uid - the message's source UID (TODO: merge with XapAddress?)
	# target_addr - the message's target address, or nil for no target
	def initialize msgclass, src_addr, src_uid, target_addr = nil
		raise 'Do not instantiate XapMessage directly (use a subclass)' if self.class == XapMessage
		raise 'src_addr must be an XapAddress' unless src_addr.is_a? XapAddress
		raise 'target_addr must be nil or an XapAddress' unless target_addr.nil? || target_addr.is_a?(XapAddress)

		@src_addr = src_addr
		@target_addr = target_addr
		@version = 12
		@hop = 1
		@uid = src_uid
		@msgclass = msgclass
		@blocks = {}
	end

	# Returns a string representation of the message suitable for
	# transmission on the network.
	def to_s
		s = "#{headername}\n" +
			"{\n" +
			"v=#{@version}\n" +
			"hop=#{@hop}\n" +
			"uid=#{@uid}\n" +
			"class=#{@msgclass}\n" +
			"source=#{@src_addr}\n"

		s << "target=#{@target_addr}\n" if @target_addr

		if @headers
			@headers.each do |k, v|
				s << "#{k}=#{v}\n"
			end
		end

		s << "}\n"

		if @blocks
			@blocks.each do |name, block|
				s << "#{name}\n{\n"
				block.each do |k, v|
					s << "#{k}=#{v}\n"
				end
				s << "}\n"
			end
		end

		s
	end

	# Returns the last two digits of the UID
	def uid_endpoint
		@uid[-2, 2]
	end

	# Parses standard xAP header information from the given header hash,
	# such as protocol version, hop count, unique ID, message class,
	# message source, and message target.
	#
	# Example usage: parse_header(message_hash['xap-header'])
	protected
	def parse_header header
		# TODO: Mixed-case header field names?
		@src_addr = XapAddress.parse header['source']
		@target_addr = XapAddress.parse header['target']
		@version = header['v']
		@hop = header['hop']
		@uid = header['uid'] # TODO: Parse/validate UID/add UID class/merge with Address?
		@msgclass = header['class']
	end

	# Adds a custom field to the message header.
	def add_header key, value
		@headers ||= {}
		@headers[key] = value
	end

	# Adds the given hash as a block under the given name (TODO: hexadecimal fields)
	# FIXME: multiple blocks can have the same name in xAP according to
	# http://www.xapautomation.org/index.php?title=Protocol_definition#Message_Grammar
	# so the blocks hash and to_hash in the parser need to be replaced with
	# arrays.
	def add_block name, hash
		@blocks ||= {}
		@blocks[name] = hash
	end

	# Sets the block list to the given hash
	def set_blocks hash
		@blocks = hash
	end
end

# A fallback class (or inheritable utility class) for messages not supported by
# a loaded schema.
class XapUnsupportedMessage < XapMessage
	XapMessage.register_class self, nil

	def self.parse msg, hash
		self.new msg, hash, nil
	end

	def initialize msgclass, src_addr, src_uid, target_addr = nil
		@headername ||= 'xap-header'
		if msgclass.is_a?(Treetop::Runtime::SyntaxNode) && src_addr.is_a?(Hash)
			parse_header src_addr[@headername]

			blocks = src_addr.clone
			blocks.delete @headername
			set_blocks blocks
		else
			super msgclass, src_addr, src_uid, target_addr
		end
	end
end

# An xAP heartbeat message.
class XapHeartbeat < XapMessage
	XapMessage.register_class self, 'xap-hbeat.alive', 'xap-hbeat'

	attr_accessor :interval

	def self.parse msg, hash
		self.new msg, hash
	end

	def initialize src_addr, src_uid, interval = 60
		@headername = 'xap-hbeat'
		if src_addr.is_a?(Treetop::Runtime::SyntaxNode) && src_uid.is_a?(Hash)
			parse_header src_uid[@headername]
			interval = src_uid[@headername]['interval'] || interval
		else
			super 'xap-hbeat.alive', src_addr, src_uid
		end
		add_header 'interval', interval
		@interval = interval
	end
end
