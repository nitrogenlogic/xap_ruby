# Class definitions for the xAP protocol
# (C)2012 Mike Bourgeous

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, 'parser/parse_xap.rb')

# Represents an xAP address.  Matching is case-insensitive.
class XapAddress
	# vendor - xAP-assigned vendor ID (e.g. ACME)
	# product - vendor-assigned product name (e.g. Controller)
	# instance - user-assigned product instance (e.g. Apartment)
	# subinstance - user- or device-assigned name (e.g. Zone1)
	def initialize vendor, product, instance, subinstance
		# This would be a nice application of macros (e.g. "check_type var, String")
		raise 'vendor must be (convertible to) a String' unless vendor.respond_to? :to_s
		raise 'product must be (convertible to) a String' unless product.respond_to? :to_s
		raise 'instance must be (convertible to) a String' unless instance.respond_to? :to_s
		raise 'subinstance must be (convertible to) a String' unless subinstance.respond_to? :to_s

		@vendor = vendor.to_s
		@product = product.to_s
		@instance = instance.to_s
		@subinstance = subinstance.to_s

		# TODO: wildcard addresses
	end

	# Returns true if all fields are == when converted to lowercase
	def == other
		if other.is_a? XapAddress
			other.vendor.downcase == @vendor.downcase &&
				other.product.downcase == @product.downcase &&
				other.instance.downcase == @instance.downcase &&
				other.subinstance.downcase == @subinstance.downcase
		else
			false
		end
	end

	# Returns true if other == self or self is a wildcard address that
	# matches other.
	def match other
		other == self # TODO: wildcard matching, document format of wildcard address
	end
end

# Base class for all xAP message types.  Registered subclasses should implement an initialize method that accepts a 
class XapMessage
	@@msgtypes = {}

	# TODO: Parses the given data as an xAP message, returning the most
	# specific subclass that has registered its schema with
	# XapMessage.register_class.
	def self.parse data
		raise 'data must be (convertible to) a String' unless data.respond_to? :to_s

		msg = ParseXap.parse data

		headername = msg.first_block
		puts "Header name: #{headername}"
		# TODO
	end

	# src_addr - the message's source address
	# target_addr - the message's target address, or nil for no target
	def initialize src_addr, target_addr = nil
		raise 'src_addr must be an XapAddress' unless src_addr.is_a? XapAddress
		raise 'target_addr must be an XapAddress' unless target_addr.nil? || target_addr.is_a?(XapAddress)

		@src_addr = src_addr
		@target_addr = target_addr
	end

	# Registers the given klass as the handler for msgclass messages, with
	# the header block called headername ('xap-header' by default).
	def self.register_class klass, msgclass, headername='xap-header'
		raise 'klass must be a Class' unless klass.is_a? Class
		raise 'msgclass must be (convertible to) a String' unless msgclass.respond_to? :to_s

		# TODO: Support regex for msgclass?
		headername.downcase!
		msgclass.downcase!
		@@msgtypes[headername] = @@msgtypes[headername] || {}
		@@msgtypes[headername][msgclass.to_s] = klass
		# TODO
	end

	def to_s
		# TODO: header, bodies
		''
	end
end

# An xAP heartbeat message.
class XapHeartbeat < XapMessage
	XapMessage.register_class self, 'xap-hbeat.alive', 'xap-hbeat'
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
