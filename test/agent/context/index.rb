# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Samuel Williams.
# Copyright, 2025, by Shopify Inc.

require "agent/context/index"
require "tmpdir"

describe Agent::Context::Index do
	let(:directory) {Dir.mktmpdir}
	let(:context_path) {File.join(directory, ".agents", "context")}
	let(:index) {subject.new(context_path)}
	
	def around
		FileUtils.mkdir_p(context_path)
		yield
	ensure
		FileUtils.rm_rf(directory)
	end
	
	def write(path, content)
		target = File.join(context_path, path)
		FileUtils.mkdir_p(File.dirname(target))
		File.write(target, content)
	end
	
	it "generates an empty index without creating agents.md" do
		index.update_index
		expect(File.read(File.join(context_path, "index.md"))).to be(:include?, "No context files are installed.")
		expect(File).not.to be(:exist?, File.join(directory, "agents.md"))
	end
	
	it "preserves repository-owned agent instructions exactly" do
		agents = File.join(directory, "agents.md")
		File.write(agents, "# Agent\n\n## Context\n\nHandwritten guidance.\n")
		index.update_index
		expect(File.read(agents)).to be == "# Agent\n\n## Context\n\nHandwritten guidance.\n"
	end
	
	it "extracts a real heading and first prose sentence while skipping code" do
		write("example/guide.md", "```ruby\n# False heading\n```\n\n# Real Title\n\nFirst sentence. Second sentence.\n")
		content = index.generate_index
		expect(content).to be(:include?, "### [Real Title](example/guide.md)")
		expect(content).to be(:include?, "First sentence.")
		expect(content).not.to be(:include?, "Second sentence.")
		expect(content).not.to be(:include?, "False heading")
	end
	
	it "prefers custom index ordering and metadata and appends unlisted guides" do
		write("example/getting-started.md", "# Getting Started\n\nDefault description.")
		write("example/configuration.md", "---\ndescription: Front matter description.\ntitle: Unrelated metadata\n---\n\n# Configuration\n\nIgnored prose.")
		write("example/unlisted.md", "# Unlisted\n")
		write("example/index.yaml", {"description" => "Provider description", "files" => [{"path" => "configuration.md", "title" => "Custom Configuration", "description" => "Custom description."}, {"path" => "missing.md"}]}.to_yaml)
		content = index.generate_index
		expect(content).to be(:include?, "Provider description")
		expect(content).to be(:include?, "Custom description.")
		expect(content.index("Custom Configuration")).to be < content.index("Getting Started")
		expect(content).to be(:include?, "Unlisted")
		expect(content).not.to be(:include?, "missing.md")
	end
	
	it "uses front matter descriptions and filename-derived fallback titles" do
		write("example/notes-file.md", "---\ndescription: Explicit summary.\nlayout: guide\n---\n\nOrdinary prose.")
		expect(index.generate_index).to be(:include?, "### [notes file](example/notes-file.md)")
		expect(index.generate_index).to be(:include?, "Explicit summary.")
	end
	
	it "escapes titles and percent-encodes relative links" do
		write("example/a [file] #.md", "# [Title](https://example.test)\n\nUse <code> safely.")
		content = index.generate_index
		expect(content).to be(:include?, "(example/a%20%5Bfile%5D%20%23.md)")
		expect(content).not.to be(:include?, "](https://example.test)")
	end
	
	it "excludes skill documents and resources even when a custom index lists them" do
		write("example/workflow.md", "---\ntype: skill\ndescription: Run workflow.\n---\n\n# Workflow\n")
		write("example/workflow/references/checklist.md", "---\ninvalid: [yaml\n---\n\n# Checklist\n")
		write("example/guide.md", "# Guide\n")
		write("example/index.yaml", {"files" => [{"path" => "workflow.md"}, {"path" => "workflow/references/checklist.md"}]}.to_yaml)
		content = index.generate_index
		expect(content).to be(:include?, "Guide")
		expect(content).not.to be(:include?, "Workflow")
		expect(content).not.to be(:include?, "Checklist")
	end
	
	it "falls back when provider index YAML is malformed" do
		write("example/guide.md", "# Guide\n")
		write("example/index.yaml", "invalid: yaml: [")
		expect(index.generate_index).to be(:include?, "Guide")
	end
	
	it "maintains local exclusions without hiding project-owned instructions or skills" do
		system("git", "init", "--quiet", directory, exception: true)
		exclude = File.join(directory, ".git", "info", "exclude")
		File.write(exclude, "user-rule\n")
		registry = Agent::Context::Skills::Registry.new(File.join(directory, ".agents", "skills", Agent::Context::Skills::Registry::FILE_NAME))
		registry.claim("cargo-workflow", "provider", "1.0", ecosystem: "cargo")
		registry.save
		index.update_index
		first = File.read(exclude)
		index.update_index
		expect(File.read(exclude)).to be == first
		expect(first).to be(:include?, "user-rule")
		expect(first).to be(:include?, "/.agents/skills/cargo-workflow/")
		expect(first.lines).not.to be(:include?, "/.agents/\n")
		expect(first.lines).not.to be(:include?, "/.agents/skills/\n")
	end
end
