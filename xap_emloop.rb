#!/usr/bin/env ruby1.9.1
# EventMachine packet transmission loop for the xAP protocol
# (C)2012 Mike Bourgeous

path = File.expand_path(File.dirname(__FILE__))

require 'eventmachine'
require 'logic_system'
require File.join(path, 'parser/parse_xap.rb')

class XapHandler < EM::Connection
	def puts *a
		STDOUT.puts "#{@servername}: #{a.join("\n")}"
	end

	def initialize servername
		@servername = servername
	end

	def post_init
		puts 'post_init'
		EM.add_periodic_timer(1) {
			send_heartbeat 'nl.depth.theater-cam', 'FFABCD00', 1
			send_datagram 'invalid', '255.255.255.255', 3639
		}
	end

	def unbind
		puts 'unbind'
	end

	def receive_data d
		begin
			puts "receive_data(#{d.length}): #{ParseXap.parse(d).blocks}"
		rescue Exception => e
			puts "Error parsing incoming message: #{e}"
			puts "receive_data(#{d.length}) invalid: #{d.inspect}"
		end
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
		# TODO: Use a generic compose_block or compose_xap facility to
		# build messages?
		msg = "xap-hbeat\n" +
			"{\n" +
			"v=12\n" +
			"hop=1\n" +
			"uid=#{src_uid}\n" +
			"class=xap-hbeat.alive\n" +
			"source=#{src_addr}\n" +
			"interval=#{interval}\n" +
			"}\n"

		send_datagram(msg, '255.255.255.255', 3639)
	end
end

if __FILE__ == $0
	EM::run {
		EM.error_handler { |e|
			puts "Error: "
			puts e, e.backtrace.join("\n\t")
		}

		# EventMachine doesn't seem to support using '::' for IP address
		EM.open_datagram_socket '0.0.0.0', 3639, XapHandler, "xAP IPv4"
	}
end
