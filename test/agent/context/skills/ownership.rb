# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "agent/context/skills/ownership"
require "fileutils"
require "tmpdir"

describe Agent::Context::Skills::Ownership do
	let(:directory) {Dir.mktmpdir}
	let(:skill_path) {File.join(directory, "provider-workflow")}
	
	def around
		FileUtils.mkdir_p(skill_path)
		yield
	ensure
		FileUtils.rm_rf(directory)
	end
	
	it "reads and writes the portable ownership fixture" do
		fixture = File.expand_path("../../../fixtures/skill.json", __dir__)
		FileUtils.copy_file(fixture, File.join(skill_path, "skill.json"))
		expected = JSON.parse(File.read(fixture))
		expect(subject.load(skill_path)).to be == expected
		subject.write(skill_path, expected["package"], expected["version"], ecosystem: expected["ecosystem"])
		expect(JSON.parse(File.read(File.join(skill_path, "skill.json")))).to be == expected
	end
	
	it "scans owned directories alongside project skills and other files" do
		subject.write(skill_path, "provider", "1.0.0")
		FileUtils.mkdir_p(File.join(directory, "project-workflow"))
		File.write(File.join(directory, "readme.md"), "Project skills.")
		File.symlink(skill_path, File.join(directory, "linked-workflow"))
		expect(subject.scan(directory)).to be == {"provider-workflow" => subject.load(skill_path)}
		expect(subject.scan(File.join(directory, "missing"))).to be == {}
	end
	
	it "validates ownership before treating an installation as managed" do
		[
			"{invalid json}",
			[].to_json,
			["gem", "provider", "1.0.0"].to_json,
			{"ecosystem" => "gem", "package" => " ", "version" => "1.0.0"}.to_json,
		].each do |content|
			File.write(File.join(skill_path, "skill.json"), content)
			expect do
				subject.scan(directory)
			end.to raise_exception(subject::Invalid)
		end
	end
	
	it "reports inaccessible ownership files and installation roots" do
		subject.write(skill_path, "provider", "1.0.0")
		File.chmod(0o400, skill_path)
		expect{subject.load(skill_path)}.to raise_exception(Errno::EACCES)
		expect{subject.scan(File.join(skill_path, "skills"))}.to raise_exception(Errno::EACCES)
	ensure
		File.chmod(0o700, skill_path)
	end
	
	it "requires regular ownership files and skill directories" do
		File.symlink("missing.json", File.join(skill_path, "skill.json"))
		expect do
			subject.load(skill_path)
		end.to raise_exception(subject::Invalid)
		File.write(File.join(directory, "blocker"), "Not a directory.")
		expect do
			subject.scan(File.join(directory, "blocker"))
		end.to raise_exception(subject::Invalid)
	end
	
	it "validates the installed directory name" do
		["Bad_Name", "a" * 65].each do |name|
			path = File.join(directory, name)
			FileUtils.mkdir_p(path)
			subject.write(path, "provider", "1.0.0")
			expect do
				subject.scan(directory)
			end.to raise_exception(subject::Invalid)
			FileUtils.rm_rf(path)
		end
	end
end
