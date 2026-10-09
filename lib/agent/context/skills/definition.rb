# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require "fileutils"
require_relative "ownership"

module Agent
	module Context
		module Skills
			# Represents a dependency skill declared by a context document and its resources.
			class Definition
				# Initialize a skill from a context document.
				# @parameter name [String] The installed skill name.
				# @parameter description [String] When to use the skill.
				# @parameter path [String | Nil] The companion resource directory.
				# @parameter provider_name [String] The provider gem.
				# @parameter provider_version [String] The provider version.
				# @parameter source_file [String] The source context document.
				# @parameter document [String] Generated skill instructions.
				def initialize(name:, description:, path:, provider_name:, provider_version:, source_file:, document:)
					@name = name
					@description = description
					@path = path
					@provider_name = provider_name
					@provider_version = provider_version
					@source_file = source_file
					@document = document
				end
				
				# @attribute [String] The installed skill name.
				attr_reader :name
				# @attribute [String] When to use the skill.
				attr_reader :description
				# @attribute [String | Nil] The companion resource directory.
				attr_reader :path
				# @attribute [String] The provider gem.
				attr_reader :provider_name
				# @attribute [String] The provider version.
				attr_reader :provider_version
				# @attribute [String] The source context document.
				attr_reader :source_file
				
				# @returns [String] The installed skill instructions.
				def content
					@document
				end
				
				# Write instructions and resources into a staging directory.
				# @parameter destination [String] The staging directory.
				def write_to(destination)
					FileUtils.mkdir_p(destination)
					copy_resources(@path, destination, true) if @path
					File.write(File.join(destination, "SKILL.md"), @document)
					Ownership.write(destination, @provider_name, @provider_version)
				end
				
				private
				
				def copy_resources(source, destination, top_level)
					Dir.children(source).sort.each do |name|
						from = File.join(source, name)
						to = File.join(destination, name)
						metadata = File.lstat(from)
						if metadata.symlink? || (!metadata.file? && !metadata.directory?)
							raise Installer::InvalidSkill, "Skill resources must be regular files or directories: #{from}"
						end
						if top_level && ["skill.md", Ownership::FILE_NAME].include?(name.downcase)
							raise Installer::InvalidSkill, "#{name} is reserved for generated skill files: #{from}"
						end
						if metadata.directory?
							FileUtils.mkdir_p(to)
							copy_resources(from, to, false)
						else
							FileUtils.copy_file(from, to, true)
						end
					end
				end
			end
		end
	end
end
