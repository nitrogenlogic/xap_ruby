# Model of an xAP device

# Classes that want to receive filtered xAP events from the main event loop
# should inherit from this class and override receive_message.
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
