# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "markly"
require "yaml"
require "date"

module Agent
	module Context
		# Represents a context document parsed into Markdown and metadata.
		class Document
			CANONICAL_ORDER = %w[getting-started overview usage configuration migration troubleshooting debugging].freeze
			
			# Raised when context front matter cannot be safely interpreted.
			class Invalid < ArgumentError
			end
			
			# Initialize a document from its source path.
			# @parameter path [String] The Markdown source file.
			def initialize(path)
				@path = path
				@content = File.read(path)
				@parts = Markly.parse(@content, flags: Markly::FRONT_MATTER).to_a
				@front_matter = @parts.first if @parts.first&.type == :front_matter
				@metadata = @front_matter ? YAML.safe_load(@front_matter.string_content, permitted_classes: [Date, Time], aliases: false, fallback: {}) : {}
				raise Invalid, "Context frontmatter must be a mapping: #{path}" unless @metadata.is_a?(Hash)
			rescue Psych::Exception => error
				raise Invalid, "Invalid YAML frontmatter in #{path}: #{error.message}"
			end
			
			# @attribute [Hash] Decoded context metadata.
			attr_reader :metadata
			
			# @returns [String] The original Markdown body after the front matter node.
			def body
				@front_matter ? @content.lines.drop(@front_matter.source_position[:end_line]).join : @content
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
