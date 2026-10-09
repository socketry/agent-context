# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require "fileutils"
require "json"
require "tempfile"

module Agent
	module Context
		module Skills
			# Represents the shared ownership index for dependency-installed skills.
			class Registry
				FILE_NAME = ".agent-context-skills.json"
				FORMAT_VERSION = 2
				NAME_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
				
				# Raised when ownership cannot be safely interpreted.
				class Invalid < StandardError
				end
				
				# Load shared skill ownership.
				# @parameter path [String] The shared ownership index.
				def initialize(path)
					@path = path
					@data = load_data
				end
				
				# @attribute [String] The path of the shared ownership index.
				attr_reader :path
				
				# @attribute [Hash] The recorded skill owners.
				def owners
					@data["skills"]
				end
				
				# Find a skill's owner.
				# @parameter name [String] The installed skill name.
				# @returns [Hash | Nil] The recorded owner.
				def owner(name)
					owners[name]
				end
				
				# Find skills owned by an ecosystem and optional package.
				# @parameter package [String | Nil] The selected provider.
				# @parameter ecosystem [String] The provider ecosystem.
				# @returns [Hash] Matching skill owners.
				def skills_for(package = nil, ecosystem: "gem")
					owners.select do |_name, owner|
						owner["ecosystem"] == ecosystem && (!package || owner["package"] == package)
					end
				end
				
				# Record dependency ownership.
				# @parameter name [String] The installed skill name.
				# @parameter package [String] The provider package.
				# @parameter version [String] The provider version.
				# @parameter ecosystem [String] The provider ecosystem.
				def claim(name, package, version, ecosystem: "gem")
					owners[name] = {"ecosystem" => ecosystem, "package" => package, "version" => version}
				end
				
				# Release skill ownership.
				# @parameter name [String] The installed skill name.
				def release(name)
					owners.delete(name)
				end
				
				# Persist shared ownership using an atomic rename.
				def save
					FileUtils.mkdir_p(File.dirname(@path))
					Tempfile.create([".agent-context-registry-", ".json"], File.dirname(@path)) do |file|
						file.write(JSON.pretty_generate({"version" => FORMAT_VERSION, "skills" => owners.sort.to_h}) + "\n")
						file.flush
						File.rename(file.path, @path)
					end
				end
				
				private
				
				def load_data
					return {"version" => FORMAT_VERSION, "skills" => {}} unless File.exist?(@path) || File.symlink?(@path)
					raise Invalid, "Skill ownership index must be a regular file: #{@path}" unless File.lstat(@path).file?
					data = JSON.parse(File.read(@path))
					unless data.is_a?(Hash) && [1, FORMAT_VERSION].include?(data["version"]) && data["skills"].is_a?(Hash)
						raise Invalid, "Invalid skill ownership index: #{@path}"
					end
					if data["version"] == 1
						data["skills"].each_value{|owner| owner["ecosystem"] = "cargo" if owner.is_a?(Hash)}
					end
					data["version"] = FORMAT_VERSION
					validate_owners(data["skills"])
					data
				rescue JSON::ParserError => error
					raise Invalid, "Invalid skill ownership index #{@path}: #{error.message}"
				end
				
				def validate_owners(owners)
					owners.each do |name, owner|
						unless name.is_a?(String) && name.match?(NAME_PATTERN) && name.length <= 64 && owner.is_a?(Hash) && owner.values_at("ecosystem", "package", "version").all?{|value| value.is_a?(String) && !value.empty?}
							raise Invalid, "Invalid owner for skill #{name.inspect}"
						end
					end
				end
			end
		end
	end
end
