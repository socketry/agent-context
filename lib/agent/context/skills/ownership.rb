# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require "json"

module Agent
	module Context
		module Skills
			# Represents installation ownership recorded in each skill directory.
			class Ownership
				FILE_NAME = "skill.json"
				NAME_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
				
				# Raised when installed ownership cannot be safely interpreted.
				class Invalid < StandardError
				end
				
				# Write ownership into a staged skill directory.
				# @parameter directory [String] The staged skill directory.
				# @parameter package [String] The provider package.
				# @parameter version [String] The provider version.
				# @parameter ecosystem [String] The provider ecosystem.
				def self.write(directory, package, version, ecosystem: "gem")
					owner = {"ecosystem" => ecosystem, "package" => package, "version" => version}
					File.write(File.join(directory, FILE_NAME), JSON.pretty_generate(owner) + "\n")
				end
				
				# Read a skill's installation ownership.
				# @parameter directory [String] The installed skill directory.
				# @returns [Hash | Nil] Ownership when the skill has an installation record.
				def self.load(directory)
					path = File.join(directory, FILE_NAME)
					return unless File.exist?(path) || File.symlink?(path)
					raise Invalid, "Skill ownership must be a regular file: #{path}" unless File.lstat(path).file?
					owner = JSON.parse(File.read(path))
					unless owner.is_a?(Hash) && owner.values_at("ecosystem", "package", "version").all?{|value| value.is_a?(String) && !value.strip.empty?}
						raise Invalid, "Invalid skill ownership: #{path}"
					end
					owner
				rescue JSON::ParserError => error
					raise Invalid, "Invalid skill ownership #{path}: #{error.message}"
				end
				
				# Collect ownership from installed skill directories.
				# @parameter directory [String] The installed skills root.
				# @returns [Hash(String, Hash)] Skill names and their installation records.
				def self.scan(directory)
					return {} unless File.exist?(directory) || File.symlink?(directory)
					raise Invalid, "Skill installation path must be a regular directory: #{directory}" unless File.lstat(directory).directory?
					Dir.children(directory).sort.each_with_object({}) do |name, owners|
						path = File.join(directory, name)
						next unless File.lstat(path).directory?
						next unless owner = load(path)
						unless name.match?(NAME_PATTERN) && name.length <= 64
							raise Invalid, "Invalid installed skill name: #{name.inspect}"
						end
						owners[name] = owner
					end
				end
			end
		end
	end
end
