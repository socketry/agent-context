# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "rubygems"
require "fileutils"
require "pathname"
require "yaml"

module Agent
	module Context
		# Installer class for managing context files from Ruby gems.
		# 
		# This class provides methods to find, list, show, and install context files
		# from gems that provide them in a `context/` directory.
		class Installer
			CANONICAL_ORDER = [
				"getting-started",
				"overview",
				"usage",
				"configuration",
				"migration",
				"troubleshooting",
				"debugging"
			]
			
			# Initialize a new Installer instance.
			#
			# @parameter root [String] The root directory to work from (default: current directory).
			# @parameter specifications [Gem::Specification] The gem specifications to search (default: all installed gems).
			def initialize(root: Dir.pwd, specifications: ::Gem::Specification)
				@root = root
				@context_path = ".context"
				@specifications = specifications
			end
			
			attr_reader :context_path
			
			# Find all gems that have a context directory
			def find_gems_with_context(skip_local: true)
				gems_with_context = []
				
				@specifications.each do |spec|
					# Skip gems loaded from current working directory if requested:
					next if skip_local && spec.full_gem_path == @root
					
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
				
				Dir.glob(File.join(gem[:path], "**/*")).select{|f| File.file?(f)}
			end
			
			# Show content of a specific context file.
			def show_context_file(gem_name, file_name)
				gem = find_gem_with_context(gem_name)
				return nil unless gem
				
				# Try to find the file with or without extension:
				possible_paths = [
					File.join(gem[:path], file_name),
					File.join(gem[:path], "#{file_name}.md"),
					File.join(gem[:path], "#{file_name}.md")
				]
				
				file_path = possible_paths.find{|path| File.exist?(path)}
				return nil unless file_path
				
				File.read(file_path)
			end
			
			# Install context from a specific gem.
			def install_gem_context(gem_name)
				gem = find_gem_with_context(gem_name)
				return false unless gem
				
				target_path = File.join(@context_path, gem_name)
				
				# Remove old package directory if it exists to ensure clean install
				FileUtils.rm_rf(target_path) if Dir.exist?(target_path)
				
				FileUtils.mkdir_p(target_path)
				
				# Copy all files from the gem's context directory:
				FileUtils.cp_r(File.join(gem[:path], "."), target_path)
				
				# Generate index.yaml if it doesn't exist, passing the full gem hash
				ensure_gem_index(gem, target_path)
				
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
			
			private
			
			# Generate a dynamic index from gemspec when no index.yaml is present
			def generate_dynamic_index(gem, gem_directory)
				# Collect all markdown files
				markdown_files = Dir.glob(File.join(gem_directory, "**", "*.md")).sort
				
				# Sort files: canonical first, then alpha
				files_sorted = markdown_files.sort_by do |file_path|
					base_filename = File.basename(file_path, ".md").downcase
					canonical_index = CANONICAL_ORDER.index(base_filename)
					[canonical_index ? CANONICAL_ORDER.index(base_filename) : CANONICAL_ORDER.length, base_filename]
				end
				
				files = []
				files_sorted.each do |file_path|
					next if File.basename(file_path) == "index.yaml" # Skip the index file itself
					title, description = extract_content(file_path)
					relative_path = file_path.sub("#{gem_directory}/", "")
					files << {
						"path" => relative_path,
						"title" => title,
						"description" => description
					}
				end
				
				{
					"description" => gem[:summary] || "Context files for #{gem[:name]}",
					"metadata" => gem[:metadata],
					"files" => files
				}
			end
			
			# Check if a gem has an index.yaml file, generate one if not
			def ensure_gem_index(gem, gem_directory)
				index_path = File.join(gem_directory, "index.yaml")
				
				unless File.exist?(index_path)
					# Generate dynamic index from gemspec
					index = generate_dynamic_index(gem, gem_directory)
					
					# Write the generated index
					File.write(index_path, index.to_yaml)
					Console.debug("Generated dynamic index for #{gem[:name]}: #{index_path}")
				end
				
				# Load and return the index
				YAML.load_file(index_path)
			rescue => error
				Console.debug("Error generating index for #{gem[:name]}: #{error.message}")
				# Return a fallback index
				{
					"description" => gem[:summary] || "Context files for #{gem[:name]}",
					"metadata" => gem[:metadata],
					"files" => []
				}
			end
			
			def extract_content(file_path)
				content = File.read(file_path)
				lines = content.lines.map(&:strip)
				
				title = extract_title(lines)
				description = extract_description(lines)
				
				[title, description]
			end
			
			def extract_title(lines)
				# Look for the first markdown header
				header_line = lines.find{|line| line.start_with?("#")}
				if header_line
					# Remove markdown header syntax and clean up
					header_line.sub(/^#+\s*/, "").strip
				else
					# If no header found, use a default
					"Documentation"
				end
			end
			
			def extract_description(lines)
				# Skip empty lines and headers to find the first paragraph
				content_start = false
				description_lines = []
				
				lines.each do |line|
					# Skip headers
					next if line.start_with?("#")
					
					# Skip empty lines until we find content
					if !content_start && line.empty?
						next
					end
					
					# Mark that we've found content
					content_start = true
					
					# If we hit an empty line after finding content, we've reached the end of the first paragraph
					if line.empty?
						break
					end
					
					description_lines << line
				end
				
				# Join the lines and truncate if too long
				description = description_lines.join(" ").strip
				
				description
			end
		end
	end
end
