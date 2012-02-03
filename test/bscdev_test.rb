#!/usr/bin/env ruby1.9.1
# Test of a single xAP BSC virtual device.
# (C)2012 Mike Bourgeous

require 'eventmachine'

path = File.expand_path(File.dirname(__FILE__))
require File.join(path, '..', 'xap.rb')
require File.join(path, '..', 'schema', 'xap_bsc.rb')
require File.join(path, '..', 'schema', 'xap_bsc_dev.rb')

if __FILE__ == $0
	EM::run {
		EM.error_handler { |e|
			puts "Error: "
			puts e, e.backtrace.join("\n\t")
		}

		Xap.start_xap

		bscdev = XapBscDevice.new(XapAddress.parse('ACME.Lighting.apartment'), Xap.random_uid, [
			       { :endpoint => 'Input 1', :uid => 1, :State => false },
			       { :endpoint => 'Output 1', :uid => 2, :State => true, :callback => proc { |ep| puts "Output 1 cb: #{ep}" } },
			       { :endpoint => 'Output 2', :uid => 3, :State => false, :Level => [37, 924], :callback => proc { |ep| puts "Output 2 cb: #{ep}" } }
		])

		Xap.add_device bscdev

		EM.add_timer(2) do
			bscdev.add_endpoint({ :endpoint => 'Output 3', :State => false, :Level => [ 0, 30 ], :callback => proc {|e|} })
		end

		EM.add_timer(5) do
			bscdev.remove_endpoint 'Output 1'
		end
	}
end
