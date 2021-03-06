# An XapDevice model of an xAP Basic Status and Control device.
# (C)2012 Mike Bourgeous

module Xap
	module Schema
		# Represents an xAP BSC Device.  See the xAP Basic Status and Control Schema.
		# http://www.xapautomation.org/index.php?title=Basic_Status_and_Control_Schema
		class XapBscDevice < XapDevice
			# Initializes an XapBscDevice with the given address, uid.  Endpoints
			# is an array of hashes containing :State, :Level, :Text, and/or
			# optionally :DisplayText.  :State should be a boolean value or nil,
			# :Level should be an array of [numerator, denominator], and :Text and
			# :DisplayText should be Strings.  Each input and output block must
			# also have an :endpoint key that contains the endpoint name for the
			# given block and may include a :uid key that contains an integer from
			# 1 to 254.  Endpoint names and UIDs must be unique within this device.
			# Output hashes (i.e. those endpoints that can be changed via xAP) are
			# identified by including a :callback key that is a proc to be called
			# with the endpoint hash when any of the output endpoint's attributes
			# are changed by an incoming xAP message.
			#
			# See add_endpoint for a summary of endpoint fields.
			#
			# Example:
			#
			# XapBscDevice.new XapAddress.new('vendor', 'dev', 'hostname'), Xap.random_uid,
			# 	[
			# 	{ :endpoint => 'Input 1', :uid => 1, :State => true },
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
					add_endpoint ep
				end
			end

			# Assigns the handler that owns this device, then sends the initial
			# state of all input and output blocks as xAPBSC.info messages.
			def handler= handler
				super handler
				announce_endpoints
			end

			# Sets the xAP UID of this virtual device, then sends an xAPBSC.info
			# message for all endpoints.
			def uid= uid
				super uid
				announce_endpoints
			end

			# Sets the xAP address of this virtual device, then sends an
			# xAPBSC.info message for all endpoints.
			def set_address address
				super address
				announce_endpoints
			end

			# Called when a message targeting this device's address is received.
			def receive_message msg
				if msg.is_a? XapBscCommand
					Xap.log "Command message for #{self}"

					if @output_count > 0
						eps = []
						if msg.target_addr.wildcard?
							@outputs.each do |out|
								eps << out if msg.target_addr.endpoint_match out[:endpoint]
							end
						else
							ep = @endpoints[msg.target_addr.endpoint.downcase]
							eps << ep if ep
						end

						# For each message block, if ID=*, apply the
						# change to all matched endpoints.  If ID!=*,
						# apply the change to the matching endpoint,
						# iff that endpoint is in the eps list.
						msg.each_block do |blk|
							id = blk.id
							if id == nil || id == '*'
								eps.each do |ep|
									update_endpoint ep, blk
								end
							else
								ep = @uids[id.to_i]
								if ep && eps.include?(ep)
									update_endpoint ep, blk
								end
							end
						end
					end

				elsif msg.is_a? XapBscQuery
					Xap.log "Query message for #{self}, target #{msg.target_addr}, wildcard #{msg.target_addr.wildcard?}"

					if msg.target_addr.wildcard?
						@endpoints.each do |name, ep|
							if msg.target_addr.endpoint_match name
								Xap.log "Matching endpoint found: #{ep[:endpoint]}"
								send_info ep
							end
						end
					elsif msg.target_addr.endpoint
						ep = @endpoints[msg.target_addr.endpoint.to_s.downcase]
						if ep
							Xap.log "Matching endpoint found: #{ep[:endpoint]}"
							send_info ep
						else
							Xap.log "No matching endpoint found"
						end
					else
						Xap.log "Error: No endpoint was given in the query"
					end

				elsif msg.is_a? XapBscInfo
					Xap.log "Info message for #{self}"

				elsif msg.is_a? XapBscEvent
					Xap.log "Event message for #{self}"

				end
			end

			# Adds a new endpoint hash to the list of endpoints, generating an
			# xAPBSC.info message if the addition is successful.  The endpoint's
			# name must be unique.  UID collision will result in an exception being
			# raised.  If the UID is not specified, the lowest available UID will
			# be used.
			#
			# Summary of endpoint fields:
			# :endpoint - Name of endpoint - mandatory, must be unique when downcased, String
			# :uid - UID of endpoint - optional, must be unique, Fixnum 1-254
			# :callback - Output change callback - mandatory for outputs, may be nil
			# :State - On/off/? state - mandatory according to xAP BSC spec
			# :Level - numerator / denominator - optional
			# :Text - Stream text - optional (mutually exclusive with :Level according to xAP BSC spec)
			# :DisplayText - UI display text - optional
			#
			# Example:
			# add_endpoint { :endpoint => 'Input 1', :uid => 4, :State => false, :Level => [ 0, 30 ] }
			def add_endpoint ep
				unless ep.include?(:endpoint) && ep.include?(:State) && (!ep.include?(:uid) || ep[:uid].is_a?(Fixnum))
					raise 'An endpoint is missing one or more required fields (:endpoint, :State).'
				end

				raise "Duplicate endpoint name #{ep[:endpoint]}." if @endpoints.include? ep[:endpoint].downcase

				ep[:uid] ||= find_free_uid
				raise "Duplicate UID #{ep[:uid]}." if @uids[ep[:uid]]

				# TODO: Additional verification of :Level, :Text, and :DisplayText

				if ep.include? :callback
					@output_count = @output_count + 1
					@outputs << ep
				else
					@input_count = @input_count + 1
				end

				@endpoints[ep[:endpoint].downcase] = ep
				@uids[ep[:uid]] = ep

				send_info ep if @handler
			end

			# Removes the given endpoint, which may be the endpoint hash or name.
			# Doesn't verify that the endpoint actually exists.
			def remove_endpoint ep
				if ep.is_a? String
					ep = @endpoints[ep.downcase]
				end
				@endpoints.delete ep[:endpoint].downcase
				@uids[ep[:uid]] = nil
			end

			# Returns the endpoint having the given UID, if any.
			def uid_endpoint uid
				@uids[uid]
			end

			# Finds and returns the lowest-available endpoint UID, or nil if there
			# are no free endpoint IDs.
			def find_free_uid
				for idx in 1..254
					return idx unless @uids[idx]
				end
				nil
			end

			# Returns the UID for the endpoint with the given name, or nil if no
			# such endpoint exists.
			def get_uid endpoint
				@endpoints[endpoint.downcase][:uid]
			end

			# Returns the State field of the endpoint with the given name.
			def get_state endpoint
				@endpoints[endpoint.downcase][:State]
			end

			# Sets the State field of the endpoint with the given name.  If the new
			# state is different from the old state, an event message will be
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
			# checking is not performed on the level parameter.  Pass nil to remove
			# the level from this endpoint.
			def set_level endpoint, level
				ep = @endpoints[endpoint.downcase]

				old = ep[:Level]
				if level != nil
					level = [ level, ep[:Level][1] ] if level.is_a? Fixnum
					ep[:Level] = level
				else
					ep.delete :Level
				end

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
			# state is different from the old state, an event message will be
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
			# the new state is different from the old state, an event message will
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
			# Send an xAPBSC.info message for all endpoints.
			def announce_endpoints
				if @endpoints
					@endpoints.each do |name, ep|
						send_info ep
					end
				end
			end

			# Send an xAPBSC.info message for the given endpoint hash.
			def send_info ep
				# Send info message for endpoint (TODO: Store an info
				# message in the endpoint hash instead of continually
				# creating new info messages?)
				msg = XapBscInfo.new(address.for_endpoint(ep[:endpoint]), uid_for(ep[:uid]), !ep.include?(:callback))
				msg.state = ep[:State] if ep.include? :State
				msg.level = ep[:Level] if ep.include? :Level
				msg.text = ep[:Text] if ep.include? :Text
				msg.display_text = ep[:DisplayText] if ep.include? :DisplayText

				send_message msg
			end

			# Send an xAPBSC.event message for the given endpoint hash.
			def send_event ep
				# Send event message for endpoint (TODO: Store an event
				# message in the endpoint hash instead of continually
				# creating new info messages?)
				msg = XapBscEvent.new(address.for_endpoint(ep[:endpoint]), uid_for(ep[:uid]), !ep.include?(:callback))
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

			# Updates the given endpoint with values from the given XapBscBlock
			def update_endpoint ep, block
				old = ep.clone

				if block.state != nil
					case block.state
					when true
						ep[:State] = true
					when false
						ep[:State] = false
					when 'toggle'
						ep[:State] = !ep[:State]
					end
				end

				if ep.include?(:Level) && block.level
					case block.level[1]
					when '%', Fixnum
						div = block.level[1] == '%' ? 100 : block.level[1]
						ep[:Level][0] = block.level[0] * ep[:Level][1] / div
					when nil
						ep[:Level][0] = block.level[0]
					end
				end

				ep[:Text] = block.text if ep.include?(:Text) && block.text
				ep[:DisplayText] = block.display_text if ep.include?(:DisplayText) && block.display_text

				if ep != old
					send_event ep
					ep[:callback].call(ep)
				else
					send_info ep
				end
			end
		end
	end
end
