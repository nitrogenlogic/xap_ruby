#!/usr/bin/env ruby
# Displays all xAP messages received.
# (C)2012 Mike Bourgeous

require 'bundler/setup'
require 'xap_ruby'

if __FILE__ == $0
	EM::run {
		EM.error_handler { |e|
			puts "Error: "
			puts e, e.backtrace.join("\n\t")
		}

		Xap.start_xap

		cb = proc { |msg|
			Xap.log "\e[1mIncoming message: \e[34m#{msg.class.name}\e[0m\n\t#{msg.inspect.lines.to_a.join("\t")}\n"
		}

		Xap.add_receiver Xap::XapAddress.parse('*.*.>'), cb

		trap "EXIT" do
			Xap.remove_receiver Xap::XapAddress.parse('*.*.>'), cb
			Xap.stop_xap
		end	
	}
end
