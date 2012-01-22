#!/usr/bin/env ruby1.9.1
# EventMachine packet transmission loop for the xAP protocol
# (C)2012 Mike Bourgeous

require 'eventmachine'
require 'logic_system'

class XapHandler < EM::Connection
	def post_init
		puts 'post_init'
		EM.add_periodic_timer(1) {
			puts "Timer"
			send_datagram("Test Data\r\n", '255.255.255.255', 3639)
		}
		send_datagram("Test Data\r\n", '255.255.255.255', 3639)
	end

	def connection_completed
		puts 'connection_completed'
	end

	def unbind
		puts 'unbind'
	end

	def receive_data d
		puts "receive_data (#{d.length}): #{d.inspect}"
	end
end

if __FILE__ == $0
	EM::run {
		EM.error_handler { |e|
			puts "Error: "
			puts e, e.backtrace.join("\n\t")
		}

		EM.open_datagram_socket '0.0.0.0', 3639, XapHandler
	}
end
