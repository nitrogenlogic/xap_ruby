# Basic class and function definitions for the xAP protocol
# (C)2012-2016 Mike Bourgeous

require 'eventmachine'
require_relative 'xap_ruby'

# Basic functions for working with the xAP protocol.
module Xap
	# Generates a random xAP UID of the form 'FF(01..FE)(01..FE)00'.
	def self.random_uid
		a = Random.rand(253) + 1
		b = Random.rand(253) + 1
		sprintf "FF%02X%02X00", a, b
	end

	# Prints a message using the global puts, prefixed with 'xAP: [time]'
        # TODO: Use Logger
	def self.log msg
		puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S.%6N %z')} - xAP - #{msg}"
	end
end

require_relative 'xap/parser'

require_relative 'xap/xap_address'
require_relative 'xap/xap_msg'
require_relative 'xap/xap_dev'
require_relative 'xap/xap_handler'

require_relative 'xap/schema'
