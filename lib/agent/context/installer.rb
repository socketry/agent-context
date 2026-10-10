# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "rubygems"
require "fileutils"
require "pathname"
require "tmpdir"

require_relative "paths"
require_relative "document"
require_relative "index"
require "agent/context/skills/installer"

module Agent
	module Context
		# Installer class for managing context files from Ruby gems.
		# 
		# This class provides methods to find, list, show, and install context files
		# from gems that provide them in a `context/` directory.
		class Installer
			# Initialize a new Installer instance.
			#
			# @parameter root [String] The root directory to work from (default: current directory).
			# @parameter specifications [Gem::Specification] The gem specifications to search (default: all installed gems).
			def initialize(root: Dir.pwd, specifications: ::Gem::Specification)
				@root = File.expand_path(root)
				@context_path = File.join(@root, CONTEXT_PATH)
				@specifications = specifications.to_a
				@skills = Agent::Context::Skills::Installer.new(root: @root, specifications: @specifications)
			end
			
			attr_reader :root
			attr_reader :context_path
			
			# Find all gems that have a context directory
			def find_gems_with_context(skip_local: true)
				gems_with_context = []
				
				@specifications.each do |spec|
					# Skip gems loaded from current working directory if requested:
					next if skip_local && File.expand_path(spec.full_gem_path) == @root
					
					context_path = File.join(spec.full_gem_path, "context")
					if Dir.exist?(context_path)
						gems_with_context << {
							name: spec.name,
							version: spec.version.to_s,
							summary: spec.summary,
							metadata: spec.metadata,
							path: context_path
						}
					end
				end
				
				gems_with_context
			end
			
			# Find a specific gem with context.
			def find_gem_with_context(gem_name)
				spec = @specifications.find{|spec| spec.name == gem_name}
				return nil unless spec
				
				context_path = File.join(spec.full_gem_path, "context")
				
				if Dir.exist?(context_path)
					{
						name: spec.name,
						version: spec.version.to_s,
						summary: spec.summary,
						metadata: spec.metadata,
						path: context_path
					}
				else
					nil
				end
			end
			
			# List context files for a gem.
			def list_context_files(gem_name)
				gem = find_gem_with_context(gem_name)
				return nil unless gem
				
				skill_paths = Array(@skills.list_skills(gem_name)).flat_map{|skill| [skill.source_file, skill.path].compact}
				Dir.glob(File.join(gem[:path], "**/*"), File::FNM_DOTMATCH).select do |file|
					File.file?(file) && !File.symlink?(file) && !skill_paths.any?{|path| file == path || file.start_with?("#{path}/")}
				end
			end
			
			# Show content of a specific context file.
			def show_context_file(gem_name, file_name)
				gem = find_gem_with_context(gem_name)
				return nil unless gem
				
				requested = Pathname.new(file_name)
				if requested.absolute? || requested.each_filename.any?{|part| part == ".."}
					raise ArgumentError, "Context file must be a relative path inside context/"
				end
				candidates = [File.join(gem[:path], file_name)]
				candidates << "#{candidates.first}.md" if File.extname(file_name).empty?
				available = list_context_files(gem_name)
				path = candidates.find{|candidate| available.include?(candidate)}
				path ? File.read(path) : nil
			end
			
			# Install context from a specific gem.
			def install_gem_context(gem_name)
				gem = find_gem_with_context(gem_name)
				return false unless gem
				
				files = list_context_files(gem_name)
				target_path = File.join(@context_path, gem_name)
				FileUtils.mkdir_p(@context_path)
				Dir.mktmpdir(".agent-context-staging-", @context_path) do |stage|
					fresh = File.join(stage, "new")
					backup = File.join(stage, "old")
					FileUtils.mkdir_p(fresh)
					files.each do |source|
						relative = Pathname.new(source).relative_path_from(Pathname.new(gem[:path])).to_s
						destination = File.join(fresh, relative)
						FileUtils.mkdir_p(File.dirname(destination))
						FileUtils.copy_file(source, destination, true)
					end
					previous = File.exist?(target_path) || File.symlink?(target_path)
					File.rename(target_path, backup) if previous
					begin
						File.rename(fresh, target_path)
					rescue
						File.rename(backup, target_path) if previous
						raise
					end
				end
				
				true
			end
			
			# Install context from all gems.
			def install_all_context(skip_local: true)
				gems = find_gems_with_context(skip_local: skip_local)
				installed = []
				
				gems.each do |gem|
					if install_gem_context(gem[:name])
						installed << gem[:name]
					end
				end
				
				installed
			end
			
			# Install context and skills and refresh the generated index.
			# @parameter gem [String | Nil] An optional provider gem.
			# @returns [Hash(Symbol, Array(String))] The installed provider and skill names.
			def install(gem: nil)
				providers = gem ? [find_gem_with_context(gem)].compact : find_gems_with_context
				# Read ordinary document metadata before modifying installed skills:
				providers.each do |provider|
					list_context_files(provider[:name]).each do |path|
						Document.new(path).description if File.extname(path).downcase == ".md"
					end
				end
				installed_skills = @skills.install(gem: gem)
				installed_context = gem ? (install_gem_context(gem) ? [gem] : []) : install_all_context
				Index.new(@context_path, specifications: @specifications).update_index
				{context: installed_context, skills: installed_skills}
			end
			
		end
	end
end
