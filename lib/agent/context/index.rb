# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.
# Copyright, 2025, by Shopify Inc.

require_relative "version"
require "fileutils"
require "yaml"

# @namespace
module Agent
	# @namespace
	module Context
		# Represents an index for managing and generating agents.md files from context files.
		# 
		# This class provides functionality to update or create AGENTS.md files following
		# the AGENTS.md specification for agentic coding tools. It can parse existing
		# agents.md files, update the context section, and generate new files when needed.
		class Index
			# Initialize a new index instance.
			# @parameter context_path [String] The path to the context directory (default: ".context").
			def initialize(context_path = ".context")
				@context_path = context_path
			end
			
			attr :context_path
			
			# Update or create an AGENTS.md file in the project root with context section
			# This follows the AGENTS.md specification for agentic coding tools
			def update_agents_md(agents_md_path = "agents.md")
				context_content = generate_context_section
				
				if File.exist?(agents_md_path)
					update_existing_agents_md(agents_md_path, context_content)
				else
					create_new_agents_md(agents_md_path, context_content)
				end
				
				Console.debug("Updated agents.md: #{agents_md_path}")
			end
			
			# Generate just the context section content (without top-level headers)
			def generate_context_section
				sections = []
				
				sections << "This section provides links to documentation from installed packages. It is automatically generated and may be updated by running `bake agent:context:install`."
				sections << ""
				sections << "**Important:** Before performing any code, documentation, or analysis tasks, always read and apply the full content of any relevant documentation referenced in the following sections. These context files contain authoritative standards and best practices for documentation, code style, and project-specific workflows. **Do not proceed with any actions until you have read and incorporated the guidance from relevant context files.**"
				sections << ""
				sections << "**Setup Instructions:** If the referenced files are not present or if dependencies have been updated, run `bake agent:context:install` to install the latest context files."
				sections << ""
				
				gem_contexts = collect_gem_contexts
				
				if gem_contexts.empty?
					sections << "No context files found. Run `bake agent:context:install` to install context from gems."
					sections << ""
				else
					gem_contexts.each do |gem_name, files|
						sections << "### #{gem_name}"
						sections << ""
						
						# Get gem directory and load index
						gem_directory = File.join(@context_path, gem_name)
						index = load_gem_index(gem_name, gem_directory)
						
						# Add gem description from index
						if index["description"]
							sections << index["description"]
							sections << ""
						end
						
						# Use files from index if available, otherwise fall back to parsing
						if index["files"] && !index["files"].empty?
							index["files"].each do |file_info|
								sections << "#### [#{file_info['title']}](.context/#{gem_name}/#{file_info['path']})"
								sections << ""
								sections << file_info["description"] if file_info["description"] && !file_info["description"].empty?
								sections << ""
							end
						else
							# Fallback to parsing files directly
							files.each do |file_path|
								if File.exist?(file_path)
									title, description = extract_content(file_path)
									relative_path = file_path.sub("#{@context_path}/", "")
									sections << "#### [#{title}](.context/#{relative_path})"
									sections << ""
									sections << description if description && !description.empty?
									sections << ""
								end
							end
						end
					end
				end
				
				sections.join("\n")
			end
			
			private
			
			def update_existing_agents_md(agents_md_path, context_content)
				content = File.read(agents_md_path)
				
				# Find the # Agent heading
				agent_heading_line = find_agent_heading_line(content)
				
				if agent_heading_line
					# Find or create the ## Context section
					context_section = find_context_section_under_agent(content, agent_heading_line)
					
					if context_section
						# Replace existing context section
						updated_content = replace_context_section(content, context_section, context_content)
					else
						# Insert new context section after agent heading
						updated_content = insert_context_section_after_agent(content, agent_heading_line, context_content)
					end
				else
					# No # Agent heading found, prepend it with context
					updated_content = prepend_agent_with_context(content, context_content)
				end
				
				# Write the updated content back to file
				File.write(agents_md_path, updated_content)
			end
			
			def create_new_agents_md(agents_md_path, context_content)
				content = [
					"# Agent",
					"",
					"## Context",
					"",
					context_content,
				].join("\n")
				File.write(agents_md_path, content)
			end
			
			def find_agent_heading_line(content)
				lines = content.lines
				lines.each_with_index do |line, index|
					if line.strip.start_with?("# ") && line.strip.downcase == "# agent"
						return index
					end
				end
				nil
			end
			
			def find_context_section_under_agent(content, agent_line_index)
				lines = content.lines
				
				# Look for ## Context after the agent heading
				(agent_line_index + 1).upto(lines.length - 1) do |index|
					line = lines[index]
					if line.strip == "## Context"
						return index
					elsif line.strip.start_with?("# ") && line.strip != "# Agent"
						# We've hit another top-level heading, stop searching
						break
					end
				end
				
				nil
			end
			
			def replace_context_section(content, context_line_index, context_content)
				lines = content.lines
				
				# Find the end of the context section
				end_index = find_section_end(lines, context_line_index, 2)
				
				# Build the new content
				new_lines = []
				new_lines.concat(lines[0...context_line_index])
				new_lines << "## Context\n"
				new_lines << "\n"
				new_lines.concat(context_content.lines)
				new_lines.concat(lines[end_index..-1])
				
				new_lines.join
			end
			
			def insert_context_section_after_agent(content, agent_line_index, context_content)
				lines = content.lines
				
				# Build the new content
				new_lines = []
				new_lines.concat(lines[0..agent_line_index])
				new_lines << "\n"
				new_lines << "## Context\n"
				new_lines << "\n"
				new_lines.concat(context_content.lines)
				new_lines.concat(lines[agent_line_index + 1..-1])
				
				new_lines.join
			end
			
			def prepend_agent_with_context(content, context_content)
				agent_context = [
					"# Agent",
					"",
					"## Context",
					"",
					context_content,
					""
				].join("\n")
				agent_context + content
			end
			
			def find_section_end(lines, start_index, heading_level)
				index = start_index + 1
				
				while index < lines.length
					line = lines[index]
					
					if line.strip.start_with?("#")
						level = line.strip.match(/^(#+)/)[1].length
						if level <= heading_level
							break
						end
					end
					
					index += 1
				end
				
				index
			end
			
			def collect_gem_contexts
				gem_contexts = {}
				
				return gem_contexts unless Dir.exist?(@context_path)
				
				Dir.glob(File.join(@context_path, "*")).each do |gem_directory|
					next unless File.directory?(gem_directory)
					gem_name = File.basename(gem_directory)
					
					markdown_files = Dir.glob(File.join(gem_directory, "**", "*.md")).sort
					gem_contexts[gem_name] = markdown_files if markdown_files.any?
				end
				
				gem_contexts
			end
			
			# Load a gem's index file
			def load_gem_index(gem_name, gem_directory)
				index_path = File.join(gem_directory, "index.yaml")
				
				if File.exist?(index_path)
					YAML.load_file(index_path)
				else
					# Return a fallback index if no index.yaml exists
					{
						"description" => "Context files for #{gem_name}",
						"files" => []
					}
				end
			rescue => error
				Console.debug("Error loading index for #{gem_name}: #{error.message}")
				# Return a fallback index
				{
					"description" => "Context files for #{gem_name}",
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
				header_line = lines.find {|line| line.start_with?("#")}
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
				if description.length > 197
					description = description[0..196] + "..."
				end
				
				description
			end
		end
	end
end
