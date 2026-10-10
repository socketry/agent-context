# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "bake"
require "tmpdir"

describe "Agent Context tasks" do
	it "exposes context and skill tasks without the old command namespace" do
		Dir.mktmpdir do |root|
			context = Bake::Context.load(root)
			%w[agent:context:list agent:context:show agent:context:install agent:context:index agent:context:skill:list agent:context:skill:show agent:context:skill:install].each do |name|
				expect(context.lookup(name)).to be_truthy
			end
			expect(context.lookup("agent:context:agents_md")).to be_nil
			expect(context.lookup("agent:skills:install")).to be_nil
			context.call("agent:context:index")
			expect(File).to be(:exist?, File.join(root, ".agents/context/index.md"))
			expect(File).not.to be(:exist?, File.join(root, "agents.md"))
		end
	end
	
	it "runs context and skill tasks against a resolved provider" do
		Dir.mktmpdir do |root|
			provider = File.join(root, "provider")
			FileUtils.mkdir_p(File.join(provider, "context"))
			File.write(File.join(provider, "context/guide.md"), "# Provider Guide\n\nUse the package.\n")
			File.write(File.join(provider, "context/workflow.md"), "---\ntype: skill\ndescription: Run the workflow.\n---\n\n# Workflow\n")
			specification = Gem::Specification.new do |spec|
				spec.name = "provider"
				spec.version = "1.0.0"
				spec.summary = "Provider guidance."
			end
			specification.instance_variable_set(:@full_gem_path, provider)
			mock(Gem::Specification).replace(:each){|&block| [specification].each(&block)}
			output = []
			mock($stdout).replace(:puts){|*messages| output.concat(messages)}
			context = Bake::Context.load(root)
			context.call("agent:context:list")
			context.call("agent:context:list", "--gem", "provider")
			context.call("agent:context:list", "--gem", "missing")
			context.call("agent:context:show", "--gem", "provider", "--file", "guide")
			context.call("agent:context:show", "--gem", "provider", "--file", "missing")
			context.call("agent:context:skill:list")
			context.call("agent:context:skill:list", "--gem", "provider")
			context.call("agent:context:skill:show", "--gem", "provider", "--skill", "provider-workflow")
			expect do
				context.call("agent:context:skill:show", "--gem", "provider", "--skill", "missing")
			end.to raise_exception(ArgumentError)
			context.call("agent:context:skill:install", "--gem", "provider", "--skill", "provider-workflow")
			context.call("agent:context:install", "--gem", "provider")
			context.call("agent:context:index")
			expect(output.join("\n")).to be(:include?, "Provider Guide")
			expect(output.join("\n")).to be(:include?, "provider-workflow (provider@1.0.0)")
			expect(output.join("\n")).to be(:include?, "Installed skills: provider-workflow")
			expect(File).to be(:exist?, File.join(root, ".agents/context/index.md"))
			expect(File).to be(:exist?, File.join(root, ".agents/skills/provider-workflow/SKILL.md"))
			FileUtils.rm_rf(File.join(provider, "context"))
			context.call("agent:context:list")
			context.call("agent:context:skill:list")
			context.call("agent:context:skill:install")
			context.call("agent:context:install")
			expect(output).to be(:include?, "No gems with context found")
			expect(output).to be(:include?, "No dependency skills found")
			expect(output).to be(:include?, "No dependency skills were installed")
			expect(File).not.to be(:exist?, File.join(root, ".agents/skills/provider-workflow"))
		end
	end
end
