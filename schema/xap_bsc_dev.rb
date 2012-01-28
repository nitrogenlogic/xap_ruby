# An XapDevice model of an xAP Basic Status and Control device.
# (C)2012 Mike Bourgeous

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, '..', 'xap.rb')
require File.join(path, 'xap_bsc.rb')

# Represents an xAP BSC Device.  See the xAP Basic Status and Control Schema.
# http://www.xapautomation.org/index.php?title=Basic_Status_and_Control_Schema
class XapBscDevice < XapDevice
	# Initializes an XapBscDevice with the given address, uid.  Endpoints
	# is an array of hashes containing :State, :Level, :Text, and/or
	# optionally :DisplayText.  :State should be a boolean value or nil,
	# :Level should be an array of [numerator, denominator], and :Text and
	# :DisplayText should be Strings.  Each input and output block must
	# also have an :endpoint key that contains the endpoint name for the
	# given block and a :uid key that contains an integer from 1 to 255.
	# Endpoint names and UIDs must be unique within this device.  TODO: If
	# no :uid is specified, the UID will be assigned incrementally with
	# inputs getting even numbers starting with 2, and outputs getting odd
	# numbers starting with 1.  No check is made for collisions with
	# manually-assigned :uid values.  Output hashes are identified by
	# including a :callback key that is a proc to be called with the
	# endpoint hash when any of the output endpoint's attributes are
	# changed by an incoming xAP message.
	#
	# Summary of endpoint fields:
	# :endpoint - Name of endpoint - mandatory, must be unique when downcased, String
	# :uid - UID of endpoint - mandatory, must be unique, integer 1-254
	# :callback - Output change callback - mandatory for outputs, may be nil
	# :State - On/off/? state - mandatory according to xAP BSC spec
	# :Level - numerator / denominator - optional
	# :Text - Stream text - optional (mutually exclusive with :Level according to xAP BSC spec)
	# :DisplayText - UI display text - optional
	#
	# Example:
	#
	# XapBscDevice.new XapAddress.new('vendor', 'dev', 'hostname'), Xap.random_uid,
	# 	[
	# 	{ :endpoint => 'Input 1', :State => true },
	# 	{ :endpoint => 'Output 1', :State => true, :callback => proc { |ep| puts 'Output 1' } }
	# 	]
	def initialize address, uid, endpoints, interval = 5
		super address, uid, interval

		# TODO: Make endpoints a hash, with what is currently the
		# :endpoint field as the hash key, then store the hash key back
		# into the hash (will simplify calls to XapBscDevice.new, so
		# the user can type => instead of :endpoint)

		@input_count = 0
		@output_count = 0
		@endpoints = {} # Mapping from endpoint name to endpoint hash
		@uids = []
		@outputs = [] # Array containing only output endpoints to simplify handling command messages
		endpoints.each do |ep|
			unless ep.include?(:endpoint) && ep.include?(:State) && ep[:uid].is_a?(Fixnum)
				raise 'An endpoint is missing required fields.'
			end
			raise 'Duplicate endpoint name.' if @endpoints.include? ep[:endpoint]
			# TODO: Additional verification of :Level, :Text, and :DisplayText

			if ep.include? :callback
				@output_count = @output_count + 1
				@outputs << ep
			else
				@input_count = @input_count + 1
			end

			@endpoints[ep[:endpoint].downcase] = ep
		end
	end

	# Assigns the handler that owns this device, then sends the initial
	# state of all input and output blocks as xAPBSC.info messages.
	def handler= handler
		super handler

		@endpoints.each do |name, ep|
			send_info ep
		end
	end

	# Called when a message targeting this device's address is received.
	def receive_message msg
		#puts "TODO: Finish receive_message in #{self}: #{msg.inspect.lines.to_a.join("\t")}"

		# TODO: Add support for endpoint-only wildcard matching to XapAddress

		if msg.is_a? XapBscCommand
			puts "Command message for #{self}"
			# TODO: Do nothing if output_count is 0, use exact match if msg.target_addr.wildcard? is false

		elsif msg.is_a? XapBscQuery
			puts "Query message for #{self}"

			if msg.target_addr.wildcard?
				# TODO: Send info messages for the matching endpoints
			else
				ep = @endpoints[msg.target_addr.endpoint.downcase]
				send_info ep if ep
			end

		elsif msg.is_a? XapBscInfo
			puts "Info message for #{self}"

		elsif msg.is_a? XapBscEvent
			puts "Event message for #{self}"
		end
	end

	# TODO: Ability to add and remove endpoints, with appropriate notice
	# sent to the xAP network

	# Returns the State field of the endpoint with the given name.
	def get_state endpoint
		@endpoints[endpoint.downcase][:State]
	end

	# Sets the State field of the endpoint with the given name.  If the new
	# state is different fron the old state, an event message will be
	# generated.  Otherwise, an info message will be generated.
	def set_state endpoint, state
		raise 'state must be true, false, or nil.' unless state == true || state == false || state == nil

		ep = @endpoints[endpoint.downcase]
		old = ep[:State]
		ep[:State] = state

		if state != old
			send_event ep
		else
			send_info ep
		end
	end

	# Returns the Level field of the endpoint with the given name.
	def get_level endpoint
		@endpoints[endpoint.downcase][:Level]
	end

	# Sets the Level field of the endpoint with the given name.  If level
	# is an array, then both the numerator and denominator are replaced.
	# If level is a Fixnum, only the numerator is replaced.  If the new
	# level is different from the old level, an event message will be
	# generated.  Otherwise, an info message will be generated.  Error
	# checking is not performed on the level parameter.
	def set_level endpoint, level
		ep = @endpoints[endpoint.downcase]

		level = [ level, ep[:Level][1] ] if level.is_a? Fixnum
		old = ep[:Level]
		ep[:Level] = level

		if level != old
			send_event ep
		else
			send_info ep
		end
	end

	# Returns the Text field of the endpoint with the given name.
	def get_text endpoint
		@endpoints[endpoint.downcase][:Text]
	end

	# Sets the Text field of the endpoint with the given name.  If the new
	# state is different fron the old state, an event message will be
	# generated.  Otherwise, an info message will be generated.
	def set_text endpoint, text
		ep = @endpoints[endpoint.downcase]

		old = ep[:Text]
		ep[:Text] = old

		if text != old
			send_event ep
		else
			send_info ep
		end
	end

	# Returns the DisplayText field of the endpoint with the given name.
	def get_display_text endpoint
		@endpoints[endpoint.downcase][:DisplayText]
	end

	# Sets the DisplayText field of the endpoint with the given name.  If
	# the new state is different fron the old state, an event message will
	# be generated.  Otherwise, an info message will be generated.
	def set_display_text endpoint, text
		ep = @endpoints[endpoint.downcase]

		old = ep[:DisplayText]
		ep[:DisplayText] = old

		if text != old
			send_event ep
		else
			send_info ep
		end
	end

	# FIXME: If multiple fields need to change at once, don't send
	# info/event messages until after all the fields are changed.
	private
	# Send an xAPBSC.info message for the given endpoint hash.
	def send_info ep
		puts "XXX: Sending info"

		# Send info message for endpoint (TODO: Store an info
		# message in the endpoint hash instead of continually
		# creating new info messages?)
		msg = XapBscInfo.new(address, uid_for(ep[:uid]), !ep.include?(:callback))
		msg.state = ep[:State] if ep.include? :State
		msg.level = ep[:Level] if ep.include? :Level
		msg.text = ep[:Text] if ep.include? :Text
		msg.display_text = ep[:DisplayText] if ep.include? :DisplayText

		send_message msg
	end

	# Send an xAPBSC.event message for the given endpoint hash.
	def send_event ep
		puts "XXX: Sending event"

		# Send event message for endpoint (TODO: Store an event
		# message in the endpoint hash instead of continually
		# creating new info messages?)
		msg = XapBscEvent.new(address, uid_for(ep[:uid]), !ep.include?(:callback))
		msg.state = ep[:State] if ep.include? :State
		msg.level = ep[:Level] if ep.include? :Level
		msg.text = ep[:Text] if ep.include? :Text
		msg.display_text = ep[:DisplayText] if ep.include? :DisplayText

		send_message msg
	end

	# Generates a UID string for the given integer sub-UID between 1 and 254.
	def uid_for uid
		sprintf "#{@uid.slice(0,6)}%02X", uid
	end
end
