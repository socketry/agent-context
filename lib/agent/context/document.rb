# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "markly"
require "yaml"

module Agent
	module Context
		# Represents metadata extracted from an ordinary context document.
		class Document
			CANONICAL_ORDER = %w[getting-started overview usage configuration migration troubleshooting debugging].freeze
			
			# Initialize a document from its source path.
			# @parameter path [String] The Markdown source file.
			def initialize(path)
				@path = path
				content = File.read(path)
				@metadata = {}
				if match = content.match(/\A---[ \t]*\r?\n(.*?)\r?\n(?:---|\.\.\.)[ \t]*(?:\r?\n|\z)/m)
					@metadata = YAML.safe_load(match[1], aliases: false)
					raise ArgumentError, "Context frontmatter must be a mapping: #{path}" unless @metadata.is_a?(Hash)
					content = content[match.end(0)..]
				end
				@parts = Markly.parse(content).to_a
			end
			
			# @returns [String] The first heading or a filename-derived title.
			def title
				heading = @parts.find{|part| part.type == :header && !plain_text(part).empty?}
				heading ? plain_text(heading) : File.basename(@path, File.extname(@path)).tr("-", " ")
			end
			
			# @returns [String | Nil] Explicit metadata or the first prose sentence.
			def description
				explicit = @metadata["description"]
				raise ArgumentError, "Context description must be a string: #{@path}" if explicit && !explicit.is_a?(String)
				return explicit.strip if explicit && !explicit.strip.empty?
				paragraph = @parts.find{|part| part.type == :paragraph}
				return unless paragraph
				plain_text(paragraph).split(/(?<=[.!?])\s+/, 2).first
			end
			
			# @returns [bool] Whether this document declares a skill.
			def skill?
				@metadata["type"] == "skill"
			end
			
			# Compute stable document ordering.
			# @parameter path [String] The relative document path.
			# @returns [Array] Canonical position, filename, and relative path.
			def self.order(path)
				name = File.basename(path, File.extname(path)).downcase
				[CANONICAL_ORDER.index(name) || CANONICAL_ORDER.length, name, path]
			end
			
			private
			
			def plain_text(node)
				node.to_plaintext.gsub(/\s+/, " ").strip
			end
		end
	end
end
