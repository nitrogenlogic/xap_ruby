# EventMachine packet transmission and receipt handler for the xAP protocol.
# (C)2012 Mike Bourgeous

require 'eventmachine'

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, 'xap.rb')

XAP_PORT=3639
BCAST_ADDR='255.255.255.255'

class XapHandler < EM::Connection
	@@instance = nil

	def self.instance
		@@instance
	end

	def puts *a
		STDOUT.puts "#{@servername}: #{a.join("\n")}"
	end

	def initialize servername
		@@instance = self
		@servername = servername
		@devices = []
		@timers = {}
	end

	def unbind
		@@instance = nil if @@instance == self

		@devices.each do |d|
			d.handler = nil
		end
	end

	def receive_data d
		handled = false
		begin
			msg = XapMessage.parse(d)
		rescue Exception => e
			Xap.log "Error parsing incoming message: #{e}\n\t#{e.backtrace.join("\n\t")}"
			Xap.log "receive_data(#{d.length}) invalid: #{d.inspect}"
			return
		end

		if msg.target_addr
			@devices.each do |d|
				begin
					if msg.target_addr.base =~ d.address
						d.receive_message msg
						handled = true
					end
				rescue RuntimeError => e
					Xap.log "Error processing message with device #{d}: #{e}\n\t#{e.backtrace.join("\n\t")}"
				end
			end
		end

		if !handled && $DEBUG
			Xap.log "Received a #{msg.class.name} message (#{msg.src_addr.inspect} => #{msg.target_addr.inspect})"
		end
	end

	# Adds a device object to the list of devices.  The device will be
	# notified about incoming messages with a target matching the device's
	# address.  If the device's heartbeat interval is non-nil and greater
	# than 0 then a periodic heartbeat will automatically be transmitted
	# for the device,
	def add_device device
		raise 'device must be an XapDevice' unless device.is_a? XapDevice
		raise 'device is already in this XapHandler' if @devices.include? device

		@devices << device
		if device.interval && device.interval > 0
			@timers[device] = EM.add_periodic_timer(device.interval) {
				send_heartbeat device.address, device.uid, device.interval
			}
		end

		device.handler = self
	end

	# Removes the given device from message notifications.  Cancels its
	# heartbeat timer if it has one.
	def remove_device device
		@devices.delete device
		timer = @timers.delete device
		timer.cancel if timer
		device.handler = nil
	end

	# Sends an XapMessage to the network.
	def send_message message
		raise 'message must be an XapMessage' unless message.is_a? XapMessage
		send_datagram(message.to_s, BCAST_ADDR, XAP_PORT)
	end

	# Broadcasts an xAP heartbeat from the given address and UID.
	#
	# src_addr and src_uid should be convertible to the exact strings that
	# should go into the packet.  interval is how often other devices
	# should expect the heartbeat, in seconds.
	#
	# http://www.xapautomation.org/index.php?title=Protocol_definition#Device_Monitoring_-_Heartbeats
	#
	# The resulting packet will look like this:
	# xap-hbeat
	# {
	# v=12
	# hop=1
	# uid=[src_uid]
	# class=xap-hbeat.alive
	# source=[src_addr]
	# interval=[interval]
	# }
	def send_heartbeat src_addr, src_uid, interval = 60
		msg = "xap-hbeat\n" +
			"{\n" +
			"v=12\n" +
			"hop=1\n" +
			"uid=#{src_uid}\n" +
			"class=xap-hbeat.alive\n" +
			"source=#{src_addr}\n" +
			"interval=#{interval}\n" +
			"}\n"

		send_datagram(msg, BCAST_ADDR, XAP_PORT)
	end
end

module Xap
	@@connection = nil

	# Opens a UDP socket for sending and receiving xAP messages.  The
	# EventMachine event loop must be running.
	def self.start_xap
		# EventMachine doesn't seem to support using '::' for IP address
		@@connection ||= EM.open_datagram_socket '0.0.0.0', XAP_PORT, XapHandler, "xAP Server" unless @@connection
		@@connection

		# TODO: xAP hub support
	end

	# Closes the xAP server UDP socket, if one exists.
	def self.stop_xap
		@@connection.close_after_writing if @@connection
		@@connection = nil
	end

	# Returns true if the xAP handler is connected to its UDP socket, false
	# otherwise.
	def self.xap_running?
		!!XapHandler.instance
	end

	# Adds the given XapDevice to the current xAP socket server.
	def self.add_device device
		raise 'The xAP server is not running.  Call start_xap first.' unless @@connection
		XapHandler.instance.add_device device
	end

	# Removes the given XapDevice from the current xAP socket server.
	def self.remove_device device
		raise 'The xAP server is not running.  Call start_xap first.' unless @@connection
		XapHandler.instance.remove_device device
	end
end

