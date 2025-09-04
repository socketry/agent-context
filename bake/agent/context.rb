# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require_relative "../../lib/agent/context/installer"
require_relative "../../lib/agent/context/index"

include Agent::Context

def initialize(context)
	super(context)
	
	@installer = Installer.new(root: context.root)
end

attr :installer

# List all gems that have context available.
# @parameter gem [String] Optional specific gem name to list context files for.
def list(gem: nil)
	if gem
		files = @installer.list_context_files(gem)
		if files
			puts "Context files for gem '#{gem}':"
			files.each do |file|
				relative_path = Pathname.new(file).relative_path_from(Pathname.new(@installer.find_gem_with_context(gem)[:path]))
				puts "  #{relative_path}"
			end
		else
			puts "No context found for gem '#{gem}'"
		end
	else
		gems = @installer.find_gems_with_context
		if gems.any?
			puts "Gems with context available:"
			gems.each do |gem_info|
				puts "  #{gem_info[:name]} (#{gem_info[:version]})"
			end
		else
			puts "No gems with context found"
		end
	end
end

# Show the content of a specific context file.
# @parameter gem [String] The gem name.
# @parameter file [String] The context file name.
def show(gem:, file:)
	content = @installer.show_context_file(gem, file)
	if content
		puts content
	else
		puts "Context file '#{file}' not found in gem '#{gem}'"
	end
end

# Install context files from gems into the current project.
# @parameter gem [String] Optional specific gem name to install context from.
def install(gem: nil)
	if gem
		if @installer.install_gem_context(gem)
			puts "Installed context from gem '#{gem}'"
		else
			puts "No context found for gem '#{gem}'"
		end
	else
		installed = @installer.install_all_context
		if installed.any?
			puts "Installed context from #{installed.length} gems:"
			installed.each {|gem_name| puts "  #{gem_name}"}
		else
			puts "No gems with context found"
		end
	end
	
	# Update agents.md after installing context
	index = Agent::Context::Index.new(@installer.context_path)
	index.update_agents_md
end

# Update or create AGENTS.md in the project root with context section
# This follows the AGENTS.md specification for agentic coding tools
def agents_md(path = "agents.md")
	index = Agent::Context::Index.new(@installer.context_path)
	index.update_agents_md(path)
end
