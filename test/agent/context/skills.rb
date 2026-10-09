# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "agent/context"
require "tmpdir"

describe Agent::Context::Installer do
	let(:directory) {Dir.mktmpdir}
	let(:provider) {File.join(directory, "provider")}
	let(:consumer) {File.join(directory, "consumer")}
	let(:specification) do
		specification = Gem::Specification.new do |spec|
			spec.name = "provider"
			spec.version = "1.0.0"
			spec.summary = "Provider guidance."
		end
		specification.instance_variable_set(:@full_gem_path, provider)
		specification
	end
	let(:installer) {subject.new(root: consumer, specifications: [specification])}
	
	def around
		FileUtils.mkdir_p([File.join(provider, "context/workflow/references"), consumer])
		File.write(File.join(provider, "context/guide.md"), "# Guide\n\nUse the provider.")
		File.write(File.join(provider, "context/workflow.md"), "---\ntype: skill\ndescription: Run the workflow.\nlicense: MIT\n---\n\n# Workflow\n")
		File.write(File.join(provider, "context/workflow/references/checklist.md"), "# Checklist\n")
		yield
	ensure
		FileUtils.rm_rf(directory)
	end
	
	it "installs context and skills without duplicating skill documents or assets" do
		agents = File.join(consumer, "agents.md")
		File.write(agents, "Repository-owned instructions")
		result = installer.install
		expect(result).to be == {context: ["provider"], skills: ["provider-workflow"]}
		expect(File.read(agents)).to be == "Repository-owned instructions"
		expect(File).to be(:exist?, File.join(consumer, ".agents/context/provider/guide.md"))
		expect(File).not.to be(:exist?, File.join(consumer, ".agents/context/provider/workflow.md"))
		skill_root = File.join(consumer, ".agents/skills/provider-workflow")
		expect(File.read(File.join(skill_root, "SKILL.md"))).to be(:include?, "license: MIT")
		expect(File).to be(:exist?, File.join(skill_root, "references/checklist.md"))
		expect(File.read(File.join(consumer, ".agents/context/index.md"))).not.to be(:include?, "Workflow")
	end
	
	it "excludes skill instructions and resources from listing and showing context" do
		expect(installer.list_context_files("provider").map{|path| File.basename(path)}).to be == ["guide.md"]
		expect(installer.show_context_file("provider", "workflow")).to be_nil
		expect(installer.show_context_file("provider", "workflow/references/checklist.md")).to be_nil
		expect do
			installer.show_context_file("provider", "../secret")
		end.to raise_exception(ArgumentError)
	end
	
	it "validates ordinary metadata before modifying installed skills" do
		File.write(File.join(provider, "context/guide.md"), "---\ndescription: [broken\n---\n\n# Guide")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::Skills::Installer::InvalidSkill)
		expect(File).not.to be(:exist?, File.join(consumer, ".agents/skills/provider-workflow"))
	end
	
	it "installs native front matter and preserves dates and skill body formatting" do
		guide = "--- yaml\ndate: 2026-10-09\nlayout: guide\n---\n\n# Guide\n\nUse the provider.\n"
		File.write(File.join(provider, "context/guide.md"), guide)
		body = "# Workflow\r\n\r\nUse  [reference][guide].\r\n\r\n~~~yaml\r\n---\r\nexample: unchanged\r\n---\r\n~~~\r\n\r\n[guide]: https://example.test\r\n"
		File.binwrite(File.join(provider, "context/workflow.md"), "--- yaml\r\ntype: skill\r\nname: ignored\r\ndescription: Run the workflow.\r\ndate: 2026-10-09\r\nupdated: 2026-10-09T12:30:00Z\r\n---\r\n\r\n#{body}")
		expect(installer.install).to be == {context: ["provider"], skills: ["provider-workflow"]}
		expect(File.read(File.join(consumer, ".agents/context/provider/guide.md"))).to be == guide
		instructions = File.binread(File.join(consumer, ".agents/skills/provider-workflow/SKILL.md"))
		expect(instructions).to be(:end_with?, body)
		metadata = Agent::Context::Document.new(File.join(consumer, ".agents/skills/provider-workflow/SKILL.md")).metadata
		expect(metadata["name"]).to be == "provider-workflow"
		expect(metadata).not.to be(:key?, "type")
		expect(metadata["date"]).to be == Date.new(2026, 10, 9)
		expect(metadata["updated"]).to be == Time.utc(2026, 10, 9, 12, 30)
		expect(File.read(File.join(consumer, ".agents/context/index.md"))).to be(:include?, "Use the provider.")
	end
	
	it "handles a provider containing only skills" do
		File.delete(File.join(provider, "context/guide.md"))
		installer.install(gem: "provider")
		expect(File.read(File.join(consumer, ".agents/context/index.md"))).to be(:include?, "No context files are installed.")
		expect(File).to be(:exist?, File.join(consumer, ".agents/skills/provider-workflow/SKILL.md"))
	end
	it "restores ordinary context when replacing a provider fails" do
		installer.install
		destination = File.join(consumer, ".agents/context/provider")
		previous = File.read(File.join(destination, "guide.md"))
		File.write(File.join(provider, "context/guide.md"), "# Updated\n")
		mock(File).before(:rename) do |source, target|
			raise Errno::EACCES, "Injected context failure" if File.basename(source) == "new" && target == destination
		end
		expect do
			installer.install_gem_context("provider")
		end.to raise_exception(Errno::EACCES)
		expect(File.read(File.join(destination, "guide.md"))).to be == previous
	end
end
