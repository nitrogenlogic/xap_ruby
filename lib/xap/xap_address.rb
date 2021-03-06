# Represents an xAP address.
# (C)2012 Mike Bourgeous

module Xap
	# Represents an xAP address.  Matching is case-insensitive.
	#
	# Wildcard characters supported: * and >.  * matches anything within a
	# subsection, but will not match across . or : (e.g. a.*.c will match a.b.c but
	# not a.b.d.c).  * must occur by itself in a subsection (e.g. *.a.b and a.*.b
	# are OK, but ab*.c*d.*e is not).  > matches anything to the end of the section
	# if specified before a :, or anything to the end of an address being tested if
	# at the end of the wildcarded address.
	class XapAddress
		attr_accessor :vendor, :product, :instance, :endpoint, :wildcard, :basewildcard, :epwildcard

		# Parses the given address string into an XapAddress.  If addr is nil,
		# returns nil.
		def self.parse addr
			return nil unless addr
			raise 'addr must be a String' unless addr.is_a? String

			# As far as I can tell, the xAP spec isn't very clear on how
			# long an address can be, whether the subaddress is specified
			# by a colon or a period, etc.
			#
			# This section says that both instance and subaddr can have any depth
			# http://www.xapautomation.org/index.php?title=Protocol_definition#Message_Addressing_Schemes
			#
			# This section has additional information on addresses
			# (including vendor and device length limits of 8 characters,
			# which are broken in many of the xAP BSC examples...)
			# http://www.xapautomation.org/index.php?title=Protocol_definition#Message_Header_Structure
			#
			# This section makes the distinction between : and . less clear
			# http://www.xapautomation.org/index.php?title=Protocol_definition#Wildcarding_of_Addresses_via_Header
			#
			# Here's documentation for an xAP plugin for some other
			# software that ignores the UID rules entirely and uses the >
			# wildcard character in the middle of an address
			# http://www.erspearson.com/xAP/Slim/Manual.html#id616380
			tokens = addr.strip.split ':', 2
			addr = tokens[0].split '.', 3
			subaddr = tokens[1]

			self.new addr[0], addr[1], addr[2], subaddr
		end

		# vendor - xAP-assigned vendor ID (e.g. ACME)
		# product - vendor-assigned product name (e.g. Controller)
		# instance - user-assigned product instance (e.g. Apartment)
		# endpoint - user- or device-assigned name (e.g. Zone1), or nil
		def initialize vendor, product, instance, endpoint=nil
			# This would be a nice application of macros (e.g. "check_type var, String")
			raise 'vendor must be (convertible to) a String' unless vendor.respond_to? :to_s
			raise 'product must be (convertible to) a String' unless product.respond_to? :to_s
			raise 'instance must be (convertible to) a String' unless instance.respond_to? :to_s
			raise 'endpoint must be (convertible to) a String' unless endpoint.respond_to? :to_s

			# TODO: Validate characters in the address

			@vendor = vendor.to_s
			@product = product.to_s
			@instance = instance.to_s
			@endpoint = endpoint ? endpoint.to_s : nil

			# Many of the xAP standard's own examples violate the length limits...
			#raise 'vendor is too long' if @vendor.length > 8
			#raise 'product is too long' if @product.length > 8

			# Build the string representation of this address
			@str = "#{@vendor}.#{@product}.#{@instance}"
			@str << ":#{@endpoint}" if @endpoint

			# Build a regex for matching wildcarded addresses
			raise "Address #{@str} contains * in the middle of a word" if @str =~ /([^.:]\*)|(\*[^.:])/
			raise "Address #{@str} contains > not at the end of a section" if @str =~ />(?!\:|$)/

			@regex, @wildcard = build_regex @str
			@baseregex, @basewildcard = build_regex("#{@vendor}.#{@product}.#{@instance}")
			if @endpoint
				@epregex, @epwildcard = build_regex(@endpoint)
			elsif @str.end_with? '>'
				# FIXME: I believe xAP wildcard addresses are supposed to treat . and : indistinguishably
				@epregex = //
				@epwildcard = true
			else
				@epregex = /^$/
				@epwildcard = false
			end
		end

		# Returns true if all fields are == when converted to lowercase
		def == other
			if other.is_a? XapAddress
				other.to_s.downcase == to_s.downcase
			else
				false
			end
		end

		# Returns true if other == self or self is a wildcard address that
		# matches other (which may either be an XapAddress or anything that can
		# be converted to a String with to_s).  Note that (self =~ other) !=
		# (other =~ self).
		def =~ other
			other == self || (other.to_s =~ @regex) == 0
		end
		alias_method :match, :'=~'

		# Returns an XapAddress that contains the base of this address with no
		# endpoint.  Wildcards in the base address components are preserved.
		def base
			XapAddress.new @vendor, @product, @instance
		end

		# Returns a new XapAddress that contains this address's base components
		# with the given endpoint.
		def for_endpoint ep_name
			XapAddress.new @vendor, @product, @instance, ep_name
		end

		# Returns true if this address's base components (i.e. everything
		# before the colon) match the base components of the given other
		# address.  If matching a wildcarded address, call this on the
		# wildcarded address (e.g. wild.base_match(other) rather than
		# other.base_match(wild).
		def base_match other
			other.base.to_s =~ @baseregex
		end

		# Returns true if this address's endpoint matches the endpoint of the
		# given other address.  If other is a String, then it will be matched
		# as if it were an XapAddress endpoint.
		def endpoint_match other
			if other.is_a? String
				other =~ @epregex
			elsif other.respond_to?(:endpoint)
				other.endpoint =~ @epregex
			else
				false
			end
		end

		# Returns a correctly-formatted string representation of the address,
		# suitable for inclusion in an xAP message.
		def to_s
			@str
		end

		# Whether this address is a wildcard address.
		def wildcard?
			@wildcard
		end

		private
		# Builds a regular expression for a wildcarded xAP string
		def build_regex str
			# FIXME: escape all regex characters with Regexp.escape, without breaking * wildcard
			regex = str.gsub '.', '\\.'
			wildcard = !!(str =~ /[*>]/)
			if wildcard
				regex = regex.gsub /(?<=\\\.|^)\*(?=\\\.|$)/, '\\1[^.:]*'
				regex = regex.gsub />:/, '[^:]*:'
				regex = regex.gsub />$/, '.*'
			end
			return Regexp.new("^#{regex}$", Regexp::IGNORECASE), wildcard
		end
	end
end
