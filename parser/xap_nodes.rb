# Treetop node extensions for parsing xAP
# (C)2012 Mike Bourgeous

module Xap
	class Keyword < Treetop::Runtime::SyntaxNode
	end

	# When value in KVP is prefixed by =
	class AsciiValue < Treetop::Runtime::SyntaxNode
		def raw_value
			self.text_value
		end
	end

	# When value in KVP is prefixed by !
	class HexValue < Treetop::Runtime::SyntaxNode
		def raw_value
			[self.text_value].pack 'H*'
		end
	end

	class Value < Treetop::Runtime::SyntaxNode
		def raw_value
			val.raw_value
		end
	end

	class KeyValuePair < Treetop::Runtime::SyntaxNode
		def key
			keyword.text_value
		end

		def val
			value.val.raw_value
		end

		def to_s
			s = "#{key}"
			if value.val.is_a? HexValue
				s << '!'
			else
				s << '='
			end
			s << value.val.text_value
			s
		end

	end

	class Pairs < Treetop::Runtime::SyntaxNode
		def to_hash
			h = {}
			elements.each do |el|
				if el.is_a? KeyValuePair
					h[el.key] = el.val
				end
			end
			h
		end

		def to_s
			s = ''
			elements.each do |el|
				if el.is_a? KeyValuePair
					s << "#{el.to_s}\n"
				end
			end
			s
		end
	end

	class MessageBlock < Treetop::Runtime::SyntaxNode
		def name
			keyword.text_value
		end

		def values
			pairs.to_hash
		end

		def to_s
			s = "#{keyword.text_value}\n{\n"
			s << pairs.to_s
			s << "}\n"
			s
		end
	end

	class Message < Treetop::Runtime::SyntaxNode
		def to_hash
			h = {}
			elements.each do |el|
				if el.is_a? MessageBlock
					h[el.keyword.text_value] = el.values
				end
			end
			h
		end

		def to_s
			s = ""
			elements.each do |el|
				if el.is_a? MessageBlock
					s << el.to_s
				end
			end
			s
		end
	end
end
