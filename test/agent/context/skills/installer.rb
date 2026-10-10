# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "agent/context/skills/installer"
require "tmpdir"

describe Agent::Context::Skills::Installer do
	let(:consumer_root) {Dir.mktmpdir}
	let(:provider_root) {Dir.mktmpdir}
	let(:specifications) {[build_specification("fake-gem", "1.0.0", provider_root)]}
	let(:installer) {subject.new(root: consumer_root, specifications: specifications)}
	
	def around
		write_skill(provider_root, "ruby-testing", description: "Test Ruby projects with Sus.")
		yield
	ensure
		FileUtils.rm_rf(consumer_root)
		FileUtils.rm_rf(provider_root)
	end
	
	def build_specification(name, version, root)
		specification = Gem::Specification.new do |spec|
			spec.name = name
			spec.version = version
			spec.summary = "A gem providing agent skills."
		end
		specification.instance_variable_set(:@full_gem_path, root)
		specification
	end
	
	def write_skill(root, name, description:, body: "# Instructions\n\nFollow these instructions.\n")
		directory = File.join(root, "context")
		FileUtils.mkdir_p(directory)
		metadata = {"type" => "skill", "description" => description}
		File.write(File.join(directory, "#{name}.md"), "#{metadata.to_yaml}---\n\n#{body}")
	end
	
	it "finds gems which provide skills" do
		gems = installer.find_gems_with_skills
		
		expect(gems.length).to be == 1
		expect(gems.first[:name]).to be == "fake-gem"
		expect(gems.first[:skills].map(&:name)).to be == ["fake-gem-ruby-testing"]
	end
	
	it "lists skills provided by a gem" do
		skills = installer.list_skills("fake-gem")
		
		expect(skills.length).to be == 1
		expect(skills.first).to have_attributes(
			name: be == "fake-gem-ruby-testing",
			description: be == "Test Ruby projects with Sus."
		)
	end
	
	it "shows a skill instruction file" do
		content = installer.show_skill("fake-gem", "fake-gem-ruby-testing")
		
		expect(content).to be(:include?, "name: fake-gem-ruby-testing")
		expect(content).to be(:include?, "# Instructions")
	end
	
	it "returns nil for a gem without skills" do
		expect(installer.find_gem_with_skills("missing-gem")).to be_nil
		expect do
			installer.install(gem: "missing-gem")
		end.to raise_exception(Agent::Context::Skills::Installer::Error)
	end
	
	it "ignores legacy skill bundles and discovers only context metadata" do
		FileUtils.mkdir_p(File.join(provider_root, "skills", "legacy"))
		File.write(File.join(provider_root, "skills/legacy/SKILL.md"), "---\nname: legacy\ndescription: Legacy instructions.\n---\n")
		
		expect(installer.list_skills("fake-gem").map(&:name)).to be == ["fake-gem-ruby-testing"]
		File.delete(File.join(provider_root, "context/ruby-testing.md"))
		expect(installer.find_gems_with_skills).to be == []
	end
	
	it "skips a gem loaded from the consuming project by default" do
		write_skill(consumer_root, "local-development", description: "Develop the local gem.")
		local_specification = build_specification("local-gem", "1.0.0", consumer_root)
		local_installer = subject.new(root: consumer_root, specifications: [local_specification])
		
		expect(local_installer.find_gems_with_skills).to be == []
		expect(local_installer.find_gems_with_skills(skip_local: false).map{|gem| gem[:name]}).to be == ["local-gem"]
	end
	
	with "installation" do
		it "installs skills relative to the consuming project root" do
			installed = installer.install(gem: "fake-gem")
			destination = File.join(consumer_root, ".agents", "skills", "fake-gem-ruby-testing")
			
			expect(installed).to be == ["fake-gem-ruby-testing"]
			expect(File).to be(:exist?, File.join(destination, "SKILL.md"))
		end
		
		it "records ownership beside the installed instructions" do
			installer.install(gem: "fake-gem")
			path = File.join(consumer_root, ".agents", "skills", "fake-gem-ruby-testing")
			
			expect(Agent::Context::Skills::Ownership.load(path)).to be == {
				"ecosystem" => "gem",
				"package" => "fake-gem",
				"version" => "1.0.0",
			}
		end
		
		it "updates a skill owned by the same gem" do
			installer.install(gem: "fake-gem")
			write_skill(provider_root, "ruby-testing", description: "Updated description.", body: "# Updated\n")
			installer.install(gem: "fake-gem")
			
			content = File.read(File.join(consumer_root, ".agents", "skills", "fake-gem-ruby-testing", "SKILL.md"))
			expect(content).to be(:include?, "# Updated")
		end
		
		it "removes skills no longer provided by the same gem" do
			write_skill(provider_root, "documentation", description: "Write documentation.")
			installer.install(gem: "fake-gem")
			File.delete(File.join(provider_root, "context", "documentation.md"))
			installer.install(gem: "fake-gem")
			
			expect(File).not.to be(:exist?, File.join(consumer_root, ".agents", "skills", "fake-gem-documentation"))
		end
		
		it "refuses to overwrite an unmanaged skill" do
			destination = File.join(consumer_root, ".agents", "skills", "fake-gem-ruby-testing")
			FileUtils.mkdir_p(destination)
			File.write(File.join(destination, "SKILL.md"), "project-owned")
			
			expect do
				installer.install(gem: "fake-gem")
			end.to raise_exception(Agent::Context::Skills::Installer::Conflict)
			
			expect(File.read(File.join(destination, "SKILL.md"))).to be == "project-owned"
		end
		
		it "refuses duplicate skill names from different gems before installation" do
			second_root = Dir.mktmpdir
			write_skill(second_root, "ruby-testing", description: "Another implementation.")
			duplicate_specifications = specifications + [build_specification("fake_gem", "1.0.0", second_root)]
			duplicate_installer = subject.new(root: consumer_root, specifications: duplicate_specifications)
			
			expect do
				duplicate_installer.install
			end.to raise_exception(Agent::Context::Skills::Installer::Conflict)
			
			expect(File).not.to be(:exist?, File.join(consumer_root, ".agents", "skills", "fake-gem-ruby-testing"))
		ensure
			FileUtils.rm_rf(second_root) if second_root
		end
		
		it "installs uniquely named skills from multiple gems" do
			second_root = Dir.mktmpdir
			write_skill(second_root, "documentation", description: "Write project documentation.")
			all_specifications = specifications + [build_specification("other-gem", "2.0.0", second_root)]
			all_installer = subject.new(root: consumer_root, specifications: all_specifications)
			
			expect(all_installer.install.sort).to be == ["fake-gem-ruby-testing", "other-gem-documentation"]
			expect(File).to be(:exist?, File.join(consumer_root, ".agents", "skills", "other-gem-documentation", "SKILL.md"))
		ensure
			FileUtils.rm_rf(second_root) if second_root
		end
	end
	
	with "validation" do
		it "uses the package-prefixed filename instead of a source name" do
			file = File.join(provider_root, "context/ruby-testing.md")
			File.write(file, "---\ntype: skill\nname: Different_Name\ndescription: Test projects.\n---\n\n# Instructions\n")
			expect(installer.show_skill("fake-gem", "fake-gem-ruby-testing")).to be(:include?, "name: fake-gem-ruby-testing")
		end
		
		it "does not discover documents without skill metadata" do
			File.write(File.join(provider_root, "context/ruby-testing.md"), "# Plain guidance\n")
			expect(installer.find_gems_with_skills).to be == []
		end
	end
	
	it "installs context-declared skills with metadata and opaque resources" do
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(File.join(context, "workflow/references"))
		File.write(File.join(context, "workflow.md"), "---\ntype: skill\ndescription: Run workflow.\nlicense: MIT\nmetadata:\n  author: Provider\n---\n\n# Workflow\n")
		File.write(File.join(context, "workflow/references/data.md"), "---\nnot valid: [yaml\n---\n")
		expect(installer.install(gem: "fake-gem").sort).to be == ["fake-gem-ruby-testing", "fake-gem-workflow"]
		content = File.read(File.join(consumer_root, ".agents/skills/fake-gem-workflow/SKILL.md"))
		expect(content).to be(:include?, "name: fake-gem-workflow")
		expect(content).to be(:include?, "license: MIT")
		expect(content).to be(:include?, "author: Provider")
		expect(File).to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-workflow/references/data.md"))
	end
	
	it "removes a provider's last skill and cleans disappeared gem providers" do
		installer.install
		FileUtils.rm_rf(File.join(provider_root, "context"))
		expect(installer.install(gem: "fake-gem")).to be == []
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing"))
		write_skill(provider_root, "ruby-testing", description: "Test projects.")
		installer.install
		subject.new(root: consumer_root, specifications: []).install
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing"))
	end
	
	it "preserves Cargo skills during a full Ruby refresh" do
		cargo = File.join(consumer_root, ".agents/skills/cargo-workflow/SKILL.md")
		FileUtils.mkdir_p(File.dirname(cargo))
		File.write(cargo, "Cargo instructions")
		Agent::Context::Skills::Ownership.write(File.dirname(cargo), "fake-gem", "2.0.0", ecosystem: "cargo")
		metadata = File.read(File.join(File.dirname(cargo), "skill.json"))
		installer.install
		expect(File.read(cargo)).to be == "Cargo instructions"
		expect(File.read(File.join(File.dirname(cargo), "skill.json"))).to be == metadata
	end
	
	it "refuses a matching name owned by Cargo even when the package names match" do
		path = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing")
		FileUtils.mkdir_p(path)
		Agent::Context::Skills::Ownership.write(path, "fake-gem", "1.0.0", ecosystem: "cargo")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::Skills::Installer::Conflict)
	end
	
	it "preserves the installed skill and ownership when resource copying fails" do
		installer.install
		ownership_path = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing/skill.json")
		previous = File.read(ownership_path)
		destination = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing/SKILL.md")
		instructions = File.read(destination)
		write_skill(provider_root, "ruby-testing", description: "Updated workflow.", body: "# Updated\n")
		FileUtils.mkdir_p(File.join(provider_root, "context/ruby-testing"))
		File.symlink("missing", File.join(provider_root, "context/ruby-testing/broken"))
		expect do
			installer.install
		end.to raise_exception(Agent::Context::Skills::Installer::InvalidSkill)
		expect(File.read(ownership_path)).to be == previous
		expect(File.read(destination)).to be == instructions
	end
	
	it "preserves unselected skills when installing one named skill" do
		write_skill(provider_root, "documentation", description: "Write docs.")
		installer.install
		File.delete(File.join(provider_root, "context/documentation.md"))
		installer.install(skill: "fake-gem-ruby-testing")
		expect(File).to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-documentation/SKILL.md"))
	end
	
	it "accepts the common metadata limits and rejects overlong descriptions" do
		write_skill(provider_root, "a" * 55, description: "d" * 1024)
		expect(installer.list_skills("fake-gem").length).to be == 2
		expect(installer.list_skills("fake-gem").first.name.length).to be == 64
		write_skill(provider_root, "a" * 55, description: "d" * 1025)
		expect do
			installer.list_skills("fake-gem")
		end.to raise_exception(Agent::Context::Skills::Installer::InvalidSkill)
	end
	
	it "includes the package prefix when validating installed name length" do
		write_skill(provider_root, "a" * 56, description: "Run workflow.")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::Skills::Installer::InvalidSkill)
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing"))
	end
	
	it "rejects nested skill declarations outside a skill resource directory" do
		context = File.join(provider_root, "context/nested")
		FileUtils.mkdir_p(context)
		File.write(File.join(context, "workflow.md"), "---\ntype: skill\ndescription: Run workflow.\n---\n\n# Workflow\n")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::Skills::Installer::InvalidSkill)
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing"))
	end
	
	it "trims descriptions before enforcing the shared character limit" do
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(context)
		metadata = {"type" => "skill", "description" => "  #{"é" * 1024}  "}
		File.write(File.join(context, "workflow.md"), "#{metadata.to_yaml}---\n\n# Workflow\n")
		installer.install
		content = File.read(File.join(consumer_root, ".agents/skills/fake-gem-workflow/SKILL.md"))
		expect(installer.list_skills("fake-gem").find{|skill| skill.name == "fake-gem-workflow"}.description).to be == "é" * 1024
		expect(content).not.to be(:include?, "  é")
	end
	
	it "restores skills, ownership, and exclusions when directory replacement fails" do
		system("git", "init", "--quiet", consumer_root, exception: true)
		write_skill(provider_root, "documentation", description: "Write docs.")
		installer.install
		skill_path = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing")
		ownership_path = File.join(skill_path, "skill.json")
		exclude = File.join(consumer_root, ".git/info/exclude")
		previous_ownership = File.read(ownership_path)
		previous_exclude = File.read(exclude)
		destination = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing/SKILL.md")
		previous_instructions = File.read(destination)
		write_skill(provider_root, "ruby-testing", description: "Updated workflow.", body: "# Updated\n")
		File.delete(File.join(provider_root, "context/documentation.md"))
		write_skill(provider_root, "aardvark", description: "New workflow.")
		mock(File).before(:rename) do |source, target|
			raise Errno::EACCES, "Injected replacement failure" if target == skill_path && source.include?("/new/")
		end
		expect do
			installer.install
		end.to raise_exception(Errno::EACCES)
		expect(File.read(ownership_path)).to be == previous_ownership
		expect(File.read(exclude)).to be == previous_exclude
		expect(File.read(destination)).to be == previous_instructions
		expect(File).to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-documentation/SKILL.md"))
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-aardvark"))
	end
	
	it "keeps plain guides out of skills and rejects invalid context skill metadata" do
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(context)
		guide = File.join(context, "guide.md")
		File.write(guide, "# Plain Guide\n\nOrdinary guidance.\n")
		expect(installer.list_skills("fake-gem").map(&:name)).to be == ["fake-gem-ruby-testing"]
		File.write(guide, "---\ntype: skill\ndescription: [invalid\n---\n")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::Skills::Installer::InvalidSkill)
		write_skill(provider_root, "Bad_Name", description: "Invalid name.")
		File.delete(guide)
		expect do
			installer.install
		end.to raise_exception(Agent::Context::Skills::Installer::InvalidSkill)
	end
	
	it "refuses a reserved SKILL.md resource before changing installed skills" do
		installer.install
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(File.join(context, "workflow"))
		File.write(File.join(context, "workflow.md"), "---\ntype: skill\ndescription: Run workflow.\n---\n")
		File.write(File.join(context, "workflow/SKILL.md"), "Conflicting instructions")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::Skills::Installer::InvalidSkill)
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-workflow"))
		expect(File).to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing/SKILL.md"))
	end
	
	it "reserves ownership resource names for files and directories" do
		installer.install
		resources = File.join(provider_root, "context/workflow")
		FileUtils.mkdir_p(resources)
		write_skill(provider_root, "workflow", description: "Run workflow.")
		["skill.json", "SKILL.JSON", "SKILL.md"].each do |name|
			path = File.join(resources, name)
			[false, true].each do |directory|
				directory ? FileUtils.mkdir_p(path) : File.write(path, "Conflict")
				expect{installer.install}.to raise_exception(Agent::Context::Skills::Installer::InvalidSkill)
				expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-workflow"))
				FileUtils.rm_rf(path)
			end
		end
		FileUtils.mkdir_p(File.join(resources, "references"))
		File.write(File.join(resources, "references/skill.json"), "Opaque resource")
		installer.install
		expect(File.read(File.join(consumer_root, ".agents/skills/fake-gem-workflow/references/skill.json"))).to be == "Opaque resource"
	end
	
	it "retains installed files and exclusions if staged ownership cannot be written" do
		system("git", "init", "--quiet", consumer_root, exception: true)
		installer.install
		skill_path = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing")
		previous = Dir.children(skill_path).to_h{|name| [name, File.read(File.join(skill_path, name))]}
		exclude = File.join(consumer_root, ".git/info/exclude")
		previous_exclude = File.read(exclude)
		write_skill(provider_root, "ruby-testing", description: "Updated workflow.")
		mock(File).before(:write) do |path, *|
			raise Errno::EACCES, "Injected ownership write failure" if path.end_with?("/skill.json") && path.include?("/new/")
		end
		expect{installer.install}.to raise_exception(Errno::EACCES)
		expect(Dir.children(skill_path).to_h{|name| [name, File.read(File.join(skill_path, name))]}).to be == previous
		expect(File.read(exclude)).to be == previous_exclude
	ensure
		mock(File).clear
	end
	
	it "reports inaccessible ownership before changing installed files or exclusions" do
		system("git", "init", "--quiet", consumer_root, exception: true)
		installer.install
		skill_path = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing")
		previous = Dir.children(skill_path).to_h{|name| [name, File.read(File.join(skill_path, name))]}
		exclude = File.join(consumer_root, ".git/info/exclude")
		previous_exclude = File.read(exclude)
		write_skill(provider_root, "ruby-testing", description: "Updated workflow.")
		begin
			File.chmod(0o400, skill_path)
			expect{installer.install}.to raise_exception(Errno::EACCES)
		ensure
			File.chmod(0o700, skill_path)
		end
		expect(Dir.children(skill_path).to_h{|name| [name, File.read(File.join(skill_path, name))]}).to be == previous
		expect(File.read(exclude)).to be == previous_exclude
	end
	
	it "works without Git and refuses malformed generated exclusion blocks" do
		mock(Open3).before(:capture2e){raise Errno::ENOENT, "Git unavailable"}
		expect(installer.install).to be == ["fake-gem-ruby-testing"]
		mock(Open3).clear
		system("git", "init", "--quiet", consumer_root, exception: true)
		File.write(File.join(consumer_root, ".git/info/exclude"), "# BEGIN bake-agent-context\n")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::Skills::Ownership::Invalid)
	end
end
