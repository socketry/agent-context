# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "agent/context/skills/installer"

# List dependency skills from all gems or one provider.
# @parameter gem [String | Nil] An optional provider gem.
def list(gem: nil)
	installer = Agent::Context::Skills::Installer.new(root: context.root)
	skills = if gem
		Array(installer.list_skills(gem))
	else
		installer.find_gems_with_skills.flat_map{|provider| provider[:skills]}
	end
	
	skills.each do |skill|
		puts "#{skill.name} (#{skill.provider_name}@#{skill.provider_version}) — #{skill.description}"
	end
	
	puts "No dependency skills found" if skills.empty?
end

# Show a dependency skill's installed instructions.
# @parameter gem [String] The provider gem.
# @parameter skill [String] The installed skill name.
def show(gem:, skill:)
	installer = Agent::Context::Skills::Installer.new(root: context.root)
	content = installer.show_skill(gem, skill)
	raise ArgumentError, "No skill #{skill.inspect} in gem #{gem.inspect}" unless content
	
	puts content
end

# Install dependency skills and reconcile only the selected scope.
# @parameter gem [String | Nil] An optional provider gem.
# @parameter skill [String | Nil] An optional installed skill name.
def install(gem: nil, skill: nil)
	installer = Agent::Context::Skills::Installer.new(root: context.root)
	names = installer.install(gem: gem, skill: skill)
	
	puts names.empty? ? "No dependency skills were installed" : "Installed skills: #{names.join(", ")}"
end
