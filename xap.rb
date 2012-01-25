# Class definitions for the xAP protocol
# (C)2012 Mike Bourgeous

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, 'parser/parse_xap.rb')

# Represents an xAP address.  Matching is case-insensitive.
#
# Wildcard characters supported: * and >.  * matches anything within a
# subsection, but will not match across . or : (e.g. a.*.c will match a.b.c but
# not a.b.d.c).  * must occur by itself in a subsection (e.g. *.a.b and a.*.b
# are OK, but ab*.c*d.*e is not).  > matches anything to the end of the section
# if specified before a :, or anything to the end of an address being tested if
# at the end of the wildcarded address.
class XapAddress
	attr_accessor :vendor, :product, :instance, :endpoint, :wildcard

	# Parses the given address string into an XapAddress.  If addr is nil,
	# returns nil.
	def self.parse addr
		return nil unless addr
		raise 'addr must be a String' unless addr.is_a? String

		# As far as I can tell, the xAP spec isn't very clear on how
		# long an address can be, whether the subaddress is specified
		# by a colon or a period, etc.
		#
		# This section says that both instance and subaddr can have any depth
		# http://www.xapautomation.org/index.php?title=Protocol_definition#Message_Addressing_Schemes
		#
		# This section has additional information on addresses
		# (including vendor and device length limits of 8 characters,
		# which are broken in many of the xAP BSC examples...)
		# http://www.xapautomation.org/index.php?title=Protocol_definition#Message_Header_Structure
		#
		# This section makes the distinction between : and . less clear
		# http://www.xapautomation.org/index.php?title=Protocol_definition#Wildcarding_of_Addresses_via_Header
		#
		# Here's documentation for an xAP plugin for some other
		# software that ignores the UID rules entirely and uses the >
		# wildcard character in the middle of an address
		# http://www.erspearson.com/xAP/Slim/Manual.html#id616380
		tokens = addr.split ':', 2
		addr = tokens[0].split '.', 3
		subaddr = tokens[1]

		self.new addr[0], addr[1], addr[2], subaddr
	end

	# vendor - xAP-assigned vendor ID (e.g. ACME)
	# product - vendor-assigned product name (e.g. Controller)
	# instance - user-assigned product instance (e.g. Apartment)
	# endpoint - user- or device-assigned name (e.g. Zone1), or nil
	def initialize vendor, product, instance, endpoint=nil
		# This would be a nice application of macros (e.g. "check_type var, String")
		raise 'vendor must be (convertible to) a String' unless vendor.respond_to? :to_s
		raise 'product must be (convertible to) a String' unless product.respond_to? :to_s
		raise 'instance must be (convertible to) a String' unless instance.respond_to? :to_s
		raise 'endpoint must be (convertible to) a String' unless endpoint.respond_to? :to_s

		# TODO: Validate characters in the address

		@vendor = vendor.to_s
		@product = product.to_s
		@instance = instance.to_s
		@endpoint = endpoint.to_s if endpoint

		# Many of the xAP standard's own examples violate the length limits...
		#raise 'vendor is too long' if @vendor.length > 8
		#raise 'product is too long' if @product.length > 8

		# Build the string representation of this address
		@str = "#{@vendor}.#{@product}.#{@instance}"
		@str << ":#{@endpoint}" if @endpoint

		# Build a regex for matching wildcarded addresses
		raise "Address #{@str} contains * in the middle of a word" if @str =~ /([^.]\*)|(\*[^.])/
		raise "Address #{@str} contains > not at the end of a section" if @str =~ />(?!\:|$)/

		@regex = @str.gsub '.', '\\.'
		@wildcard = !!(@str =~ /[*>]/)
		if @wildcard
			@regex = @regex.gsub /(?<=\\\.|^)\*(?=\\\.|$)/, '\\1[^.:]*'
			@regex = @regex.gsub />:/, '[^:]*:'
			@regex = @regex.gsub />$/, '.*'
		end
		@regex = Regexp.new "^#{@regex}$", Regexp::IGNORECASE

		puts "XXX: Regex #{@regex}, wildcarded: #{@wildcard}"
	end

	# Returns true if all fields are == when converted to lowercase
	def == other
		if other.is_a? XapAddress
			other.vendor.downcase == @vendor.downcase &&
				other.product.downcase == @product.downcase &&
				other.instance.downcase == @instance.downcase &&
				other.endpoint.downcase == @endpoint.downcase
		else
			false
		end
	end

	# Returns true if other == self or self is a wildcard address that
	# matches other (which may either be an XapAddress or anything that can
	# be converted to a String with to_s).  Note that (self =~ other) !=
	# (other =~ self).
	def =~ other
		other == self || (other.to_s =~ @regex) == 0
	end
	alias_method :match, :'=~'

	# Returns a correctly-formatted string representation of the address,
	# suitable for inclusion in an xAP message.
	def to_s
		@str
	end
end

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

		puts "Registered support for #{headername}/#{msgclass} messages via #{klass.name}"

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
	# FIXME: can multiple blocks have the same name in xAP?
	def add_block name, hash
		@blocks ||= {}
		@blocks[name] = hash
	end

	# Sets the block list to the given hash
	def set_blocks hash
		@blocks = hash
	end
end

# A fallback class (or inheritable utility class) for unsupported messages.
class XapUnsupportedMessage < XapMessage
	XapMessage.register_class self, nil

	def self.parse msg, hash
		puts "Fallback"
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
		puts "Heartbeat"
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

# Classes that want to receive filtered xAP events from the main event loop
# should inherit from this class and override message_received.
class XapDevice
	attr_accessor :address

	# Initializes this superclass with the given address
	def initialize address
		raise 'address must be an instance of XapAddress' unless address.is_a? XapAddress
		@address = address
	end

	def receive_message msg
		puts "XXX: You forgot to override receive_message: #{msg}"
	end
end
