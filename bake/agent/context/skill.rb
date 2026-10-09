# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "agent/skills/installer"

# List dependency skills from all gems or one provider.
# @parameter gem [String | Nil] An optional provider gem.
def list(gem: nil)
	installer = Agent::Skills::Installer.new(root: context.root)
	skills = gem ? Array(installer.list_skills(gem)) : installer.find_gems_with_skills.flat_map{|provider| provider[:skills]}
	skills.each{|skill| puts "#{skill.name} (#{skill.provider_name}@#{skill.provider_version}) — #{skill.description}"}
	puts "No dependency skills found" if skills.empty?
end

# Show a dependency skill's installed instructions.
# @parameter gem [String] The provider gem.
# @parameter skill [String] The installed skill name.
def show(gem:, skill:)
	content = Agent::Skills::Installer.new(root: context.root).show_skill(gem, skill)
	raise ArgumentError, "No skill #{skill.inspect} in gem #{gem.inspect}" unless content
	puts content
end

# Install dependency skills and reconcile only the selected scope.
# @parameter gem [String | Nil] An optional provider gem.
# @parameter skill [String | Nil] An optional installed skill name.
def install(gem: nil, skill: nil)
	names = Agent::Skills::Installer.new(root: context.root).install(gem: gem, skill: skill)
	puts names.empty? ? "No dependency skills were installed" : "Installed skills: #{names.join(", ")}"
end
