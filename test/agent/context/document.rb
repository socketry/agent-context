# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "agent/context/document"
require "tmpdir"
require "fileutils"

describe Agent::Context::Document do
	let(:directory) {Dir.mktmpdir}
	let(:path) {File.join(directory, "guide.md")}
	let(:document) {subject.load(path)}
	
	def around
		yield
	ensure
		FileUtils.rm_rf(directory)
	end
	
	it "reads native front matter with a YAML format hint and standard dates" do
		File.write(path, "--- yaml\ntitle: Metadata title\ndate: 2026-10-09\nupdated: 2026-10-09T12:30:00Z\n---\n\n# Actual Title\n\nFirst sentence. Second sentence.\n")
		expect(document.metadata["date"]).to be == Date.new(2026, 10, 9)
		expect(document.metadata["updated"]).to be == Time.utc(2026, 10, 9, 12, 30)
		expect(document.title).to be == "Actual Title"
		expect(document.description).to be == "First sentence."
	end
	
	it "preserves the body bytes and source file when front matter uses CRLF" do
		body = "\r\n# Guide\r\n\r\nUse  [reference][guide].\r\n\r\n~~~yaml\r\n---\r\nexample: unchanged\r\n---\r\n~~~\r\n\r\n[guide]: https://example.test\r\n"
		content = "---\ndescription: Explicit summary.\n---\n".gsub("\n", "\r\n") + body
		File.binwrite(path, content)
		expect(document.body).to be == body
		expect(document.description).to be == "Explicit summary."
		expect(File.binread(path)).to be == content
	end
	
	it "parses in-memory Markdown with thematic breaks and code examples" do
		content = "# Guide\n\n---\n\n~~~yaml\n---\ntype: skill\n---\n~~~\n"
		parsed = subject.parse(content, path: path)
		expect(parsed.metadata).to be == {}
		expect(parsed.body).to be == content
		expect(parsed).not.to be(:skill?)
	end
	
	it "accepts empty front matter" do
		File.write(path, "---\n---\n# Guide\n")
		expect(document.metadata).to be == {}
		expect(document.title).to be == "Guide"
		expect(document.body).to be == "# Guide\n"
	end
	
	it "rejects non-mapping metadata with the source path" do
		File.write(path, "---\n- invalid\n---\n# Guide\n")
		expect do
			document
		end.to raise_exception(subject::Invalid, message: be(:include?, path))
	end
	
	it "rejects arbitrary Ruby objects in YAML metadata" do
		File.write(path, "---\nobject: !ruby/object:Object {}\n---\n# Guide\n")
		expect do
			document
		end.to raise_exception(subject::Invalid, message: be(:include?, path))
	end
end
