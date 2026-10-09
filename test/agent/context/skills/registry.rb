# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "agent/context/skills/registry"
require "tmpdir"

describe Agent::Context::Skills::Registry do
	let(:temporary_directory) {Dir.mktmpdir}
	let(:registry_path) {File.join(temporary_directory, Agent::Context::Skills::Registry::FILE_NAME)}
	
	def around
		yield
	ensure
		FileUtils.rm_rf(temporary_directory)
	end
	
	it "records and reloads skill ownership" do
		registry = subject.new(registry_path)
		registry.claim("ruby-testing", "sus", "1.0.0")
		registry.save
		
		reloaded = subject.new(registry_path)
		expect(reloaded.owner("ruby-testing")).to be == {
			"ecosystem" => "gem",
			"package" => "sus",
			"version" => "1.0.0",
		}
	end
	
	it "lists skills owned by a gem" do
		registry = subject.new(registry_path)
		registry.claim("ruby-testing", "sus", "1.0.0")
		registry.claim("http-server", "falcon", "2.0.0")
		
		expect(registry.skills_for("sus").keys).to be == ["ruby-testing"]
	end
	
	it "releases ownership" do
		registry = subject.new(registry_path)
		registry.claim("ruby-testing", "sus", "1.0.0")
		registry.release("ruby-testing")
		
		expect(registry.owner("ruby-testing")).to be_nil
	end
	
	it "rejects an invalid registry" do
		File.write(registry_path, {"version" => 99, "skills" => {}}.to_json)
		
		expect do
			subject.new(registry_path)
		end.to raise_exception(Agent::Context::Skills::Registry::Invalid)
	end
	it "imports version-one Cargo ownership into the shared format" do
		File.write(registry_path, {"version" => 1, "skills" => {"cargo-workflow" => {"package" => "provider", "version" => "1.0.0"}}}.to_json)
		registry = subject.new(registry_path)
		expect(registry.owner("cargo-workflow")).to be == {"ecosystem" => "cargo", "package" => "provider", "version" => "1.0.0"}
		registry.save
		expect(JSON.parse(File.read(registry_path))["version"]).to be == 2
	end
	
	it "reads and rewrites the portable ownership fixture without changing its owners" do
		fixture = File.expand_path("../../../fixtures/skill-ownership-index.json", __dir__)
		File.write(registry_path, File.read(fixture))
		registry = subject.new(registry_path)
		expected = JSON.parse(File.read(fixture))
		registry.save
		expect(JSON.parse(File.read(registry_path))).to be == expected
	end
	
	it "rejects malformed JSON and invalid shared owner names" do
		["{invalid json}", {"version" => 2, "skills" => {"a" * 65 => {"ecosystem" => "gem", "package" => "provider", "version" => "1.0.0"}}}.to_json].each do |content|
			File.write(registry_path, content)
			expect do
				subject.new(registry_path)
			end.to raise_exception(subject::Invalid)
		end
	end
	
	it "rejects malformed and conflicting legacy Ruby ownership" do
		legacy = File.join(temporary_directory, ".agent-skills.yaml")
		[
			"invalid: [yaml",
			{"version" => 99, "skills" => {}}.to_yaml,
			{"version" => 1, "skills" => {"workflow" => {"gem" => nil, "version" => "1.0.0"}}}.to_yaml,
		].each do |content|
			File.write(legacy, content)
			expect do
				subject.new(registry_path)
			end.to raise_exception(subject::Invalid)
		end
		File.write(registry_path, {"version" => 2, "skills" => {"workflow" => {"ecosystem" => "cargo", "package" => "provider", "version" => "1.0.0"}}}.to_json)
		File.write(legacy, {"version" => 1, "skills" => {"workflow" => {"gem" => "provider", "version" => "1.0.0"}}}.to_yaml)
		expect do
			subject.new(registry_path)
		end.to raise_exception(subject::Invalid)
	end
end
