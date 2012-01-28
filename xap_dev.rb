# Base class for object model of an xAP device.
# (C)2012 Mike Bourgeous

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, 'xap.rb')

# Classes that want to receive filtered xAP events from the main event loop
# should inherit from this class and override receive_message.
class XapDevice
	attr_accessor :address, :uid, :interval

	# Initializes this superclass with the given address and base UID,
	# which will be used as the source address and UID of messages
	# generated by this device, and the given heartbeat interval.
	#
	# address - a non-wildcarded XapAddress that doesn't contain ':'.
	# uid - eight hexadecimal digits, the first two of which must be FF,
	# the last two 00, and the middle two neither FF nor 00.
	# interval - the number of seconds between xAP heartbeats sent by this
	# device model when added to an XapHandler event loop.
	def initialize address, uid, interval
		set_address address
		set_uid uid
		@interval = interval
	end

	# Sets the XapHandler that manages messages to and from this device.
	# This should typically be called by XapHandler itself.
	def handler= handler
		raise 'handler must be a XapHandler' unless handler.is_a? XapHandler
		@handler = handler
	end

	# Called whenever a matching message is received by the associated
	# handler.
	def receive_message msg
		puts "XXX: You forgot to override receive_message in #{self}: #{msg.inspect.lines.to_a.join("\t")}"
	end

	# Returns a string description of this device.
	def to_s
		"<#{self.class.name}: #{@address} #{@uid}>"
	end

	protected
	# Uses the associated XapHandler to send the given message.
	def send_message message
		@handler.send_message message
	end

	# TODO: Ability to request incoming messages matching a particular
	# source address

	# Changes the address used by this device.  Subclasses should call this
	# if, for example, the user-assigned name of the device is changed.
	def set_address address
		if !address.is_a?(XapAddress) || address.wildcard? || address.endpoint
			raise 'address must be a non-wildcarded XapAddress without ":"'
		end
		@address = address
	end

	# Changes the UID used by this device.  Subclasses should call this if
	# the four-digit reassignable component of the UID is changed.
	def set_uid uid
		unless uid =~ /^FF[0-9A-Z]{4}00$/i && !(uid.slice(2, 4) =~ /(00|FF)/i)
			raise "uid must be eight hex digits of the form FF(01..FE)(01..FE)00, not #{uid}."
		end
		@uid = uid
	end
end
