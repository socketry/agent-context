# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require "fileutils"
require "rubygems"
require "yaml"
require "tmpdir"

require_relative "definition"
require_relative "ownership"
require_relative "exclusion"
require_relative "../document"

module Agent
	module Context
		module Skills
			# Represents discovery and installation of skills from resolved gems.
			class Installer
				NAME_PATTERN = Ownership::NAME_PATTERN
				MAXIMUM_NAME_LENGTH = 64
				MAXIMUM_DESCRIPTION_LENGTH = 1024
				
				# Raised when a skill cannot be installed.
				class Error < StandardError
				end
				
				# Raised when skill metadata or resources are invalid.
				class InvalidSkill < Error
				end
				
				# Raised when a destination has ambiguous or foreign ownership.
				class Conflict < Error
				end
				
				# Initialize discovery from the project's gem specifications.
				# @parameter root [String] The consuming project root.
				# @parameter specifications [Enumerable] The resolved gem specifications.
				def initialize(root: Dir.pwd, specifications: ::Gem::Specification)
					@root = File.expand_path(root)
					@skills_path = File.join(@root, ".agents", "skills")
					@specifications = specifications
				end
				
				# @attribute [String] The consuming project root.
				attr_reader :root
				
				# @attribute [String] The installed skill directory.
				attr_reader :skills_path
				
				# Find skill providers.
				# @parameter skip_local [bool] Whether to exclude the consuming gem.
				# @returns [Array(Hash)] The discovered providers.
				def find_gems_with_skills(skip_local: true)
					@specifications.filter_map do |specification|
						next if skip_local && File.expand_path(specification.full_gem_path) == @root
						
						information = build_gem_information(specification)
						information unless information[:skills].empty?
					end
				end
				
				# Find a skill provider by gem name.
				# @parameter gem_name [String] The provider gem.
				# @returns [Hash | Nil] The discovered provider.
				def find_gem_with_skills(gem_name)
					specification = find_specification(gem_name)
					return unless specification
					
					information = build_gem_information(specification)
					information unless information[:skills].empty?
				end
				
				# List a gem's skills.
				# @parameter gem_name [String] The provider gem.
				# @returns [Array(Definition) | Nil] The provided skills.
				def list_skills(gem_name)
					find_gem_with_skills(gem_name)&.fetch(:skills)
				end
				
				# Read a skill's generated instruction file.
				# @parameter gem_name [String] The provider gem.
				# @parameter skill_name [String] The installed skill name.
				# @returns [String | Nil] The instructions.
				def show_skill(gem_name, skill_name)
					list_skills(gem_name)&.find{|skill| skill.name == skill_name}&.content
				end
				
				# Install selected skills and reconcile only the corresponding ownership scope.
				# @parameter gem [String | Nil] An optional provider gem.
				# @parameter skill [String | Nil] An optional installed skill name.
				# @parameter skip_local [bool] Whether to exclude the consuming gem.
				# @returns [Array(String)] The installed skill names.
				def install(gem: nil, skill: nil, skip_local: true)
					if gem
						specification = find_specification(gem)
						raise Error, "No gem found: #{gem}" unless specification
						providers = [build_gem_information(specification)]
					else
						providers = find_gems_with_skills(skip_local: skip_local)
					end
					
					definitions = providers.flat_map{|provider| provider[:skills]}
					if skill
						definitions.select!{|definition| definition.name == skill}
						raise Error, "No dependency skill found: #{skill}" if definitions.empty?
					end
					
					install_definitions(definitions, package: gem, reconcile: !skill)
				end
				
				private
				
				def find_specification(name)
					matches = @specifications.select{|specification| specification.name == name}
					raise Conflict, "Multiple resolved versions provide gem #{name.inspect}" if matches.length > 1
					
					matches.first
				end
				
				def build_gem_information(specification)
					context_root = File.join(specification.full_gem_path, "context")
					skills = discover_context_skills(context_root, specification)
					
					{
						name: specification.name,
						version: specification.version.to_s,
						skills: skills.sort_by(&:name),
					}
				end
				
				def discover_context_skills(root, specification)
					return [] unless File.directory?(root)
					raise InvalidSkill, "Context provider must be a regular directory: #{root}" if File.symlink?(root)
					
					# Discover root-level skills before inspecting their resource directories:
					files = Dir.glob(File.join(root, "**", "*")).sort_by do |file|
						[File.dirname(file) == root ? 0 : 1, file]
					end
					
					skills = []
					files.each do |file|
						next if skills.any?{|skill| skill.path && file.start_with?("#{skill.path}/")}
						next unless File.file?(file) && !File.symlink?(file)
						next unless File.extname(file).downcase == ".md"
						
						source = parse_document(file)
						type = source.metadata["type"]
						next unless type
						
						unless type == "skill"
							raise InvalidSkill, "Unsupported context type in #{file}: #{type.inspect}"
						end
						
						unless File.dirname(file) == root
							raise InvalidSkill, "Skill documents must be directly inside context/: #{file}"
						end
						
						skills << build_definition(file, source, specification)
					end
					
					skills
				end
				
				def build_definition(file, source, specification)
					local_name = File.basename(file, File.extname(file))
					installed_name = "#{specification.name.downcase.tr("_", "-")}-#{local_name}"
					validate_name(local_name, file)
					
					metadata = source.metadata.merge("name" => installed_name)
					metadata.delete("type")
					validate_metadata(metadata, file)
					
					assets = File.join(File.dirname(file), local_name)
					if File.exist?(assets) || File.symlink?(assets)
						unless File.lstat(assets).directory?
							raise InvalidSkill, "Skill resources must be a regular directory: #{assets}"
						end
					else
						assets = nil
					end
					
					front_matter = YAML.dump(metadata).delete_prefix("---\n")
					body = source.body.sub(/\A\r?\n/, "")
					document = "---\n#{front_matter}---\n\n#{body}"
					document += "\n" unless document.end_with?("\n")
					
					Definition.new(
						name: installed_name,
						description: metadata["description"],
						path: assets,
						source_file: file,
						document: document,
						provider_name: specification.name,
						provider_version: specification.version.to_s,
					)
				end
				
				def parse_document(file)
					Document.load(file)
				rescue Document::Invalid => error
					raise InvalidSkill, error.message
				end
				
				def validate_name(name, file)
					unless name.is_a?(String) && name.match?(NAME_PATTERN) && name.length <= MAXIMUM_NAME_LENGTH
						raise InvalidSkill, "Invalid skill name in #{file}: #{name.inspect}"
					end
				end
				
				def validate_metadata(metadata, file)
					validate_name(metadata["name"], file)
					
					description = metadata["description"]
					unless description.is_a?(String)
						raise InvalidSkill, "Invalid skill description in #{file}"
					end
					
					description = description.strip
					if description.empty? || description.length > MAXIMUM_DESCRIPTION_LENGTH
						raise InvalidSkill, "Invalid skill description in #{file}"
					end
					
					metadata["description"] = description
				end
				
				def install_definitions(definitions, package:, reconcile:)
					duplicates = definitions.group_by(&:name).select{|_name, matches| matches.length > 1}
					raise Conflict, "Multiple providers supply skills: #{duplicates.keys.join(", ")}" unless duplicates.empty?
					
					if File.exist?(@skills_path) || File.symlink?(@skills_path)
						unless File.lstat(@skills_path).directory?
							raise Conflict, "Skill installation path must be a regular directory: #{@skills_path}"
						end
					end
					
					owners = Ownership.scan(@skills_path)
					validate_destinations(definitions, owners)
					
					names = definitions.map(&:name)
					owned = owners.select do |_name, owner|
						owner["ecosystem"] == "gem" && (!package || owner["package"] == package)
					end
					stale = reconcile ? owned.keys - names : []
					exclusion = Exclusion.prepare(@root, (owners.keys - stale + names).uniq)
					
					FileUtils.mkdir_p(@skills_path)
					Dir.mktmpdir(".agent-context-staging-", @skills_path) do |stage|
						staged = File.join(stage, "new")
						backups = File.join(stage, "backups")
						FileUtils.mkdir_p([staged, backups])
						
						definitions.each do |definition|
							definition.write_to(File.join(staged, definition.name))
						end
						
						replace_skills(staged, backups, names, stale, exclusion)
					end
					
					names
				end
				
				def validate_destinations(definitions, owners)
					definitions.each do |definition|
						owner = owners[definition.name]
						destination = File.join(@skills_path, definition.name)
						
						if owner && owner.values_at("ecosystem", "package") != ["gem", definition.provider_name]
							raise Conflict, "Skill #{definition.name.inspect} belongs to #{owner["ecosystem"]}:#{owner["package"]}"
						end
						
						if (File.exist?(destination) || File.symlink?(destination)) && !owner
							raise Conflict, "Skill #{definition.name.inspect} is not managed by Agent Context"
						end
					end
				end
				
				def replace_skills(staged, backups, names, stale, exclusion)
					changes = []
					begin
						exclusion&.apply
						
						(names + stale).each do |name|
							destination = File.join(@skills_path, name)
							backup = File.join(backups, name)
							previous = File.exist?(destination) || File.symlink?(destination)
							
							File.rename(destination, backup) if previous
							changes << [name, previous]
							File.rename(File.join(staged, name), destination) if names.include?(name)
						end
					rescue
						changes.reverse_each do |name, previous|
							destination = File.join(@skills_path, name)
							FileUtils.rm_rf(destination)
							File.rename(File.join(backups, name), destination) if previous
						end
						
						exclusion&.restore
						raise
					end
				end
			end
		end
	end
end
