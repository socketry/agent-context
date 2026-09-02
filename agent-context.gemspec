# frozen_string_literal: true

require_relative "lib/agent/context/version"

Gem::Specification.new do |spec|
	spec.name = "agent-context"
	spec.version = Agent::Context::VERSION
	
	spec.summary = "Install and manage context files from Ruby gems."
	spec.authors = ["Samuel Williams", "Shopify Inc."]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/ioquatix/agent-context"
	
	spec.metadata = {
		"bug_tracker_uri" => "https://github.com/ioquatix/agent-context/issues",
		"changelog_uri" => "https://github.com/ioquatix/agent-context/blob/main/releases.md",
		"documentation_uri" => "https://ioquatix.github.io/agent-context/",
		"funding_uri" => "https://github.com/sponsors/ioquatix/",
		"source_code_uri" => "https://github.com/ioquatix/agent-context.git",
	}
	
	spec.files = Dir.glob(["{bake,context,lib}/**/*", "*.md"], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.3"
	
	spec.add_dependency "bake", ">= 0.23"
end
