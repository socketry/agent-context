# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

source "https://rubygems.org"

gemspec

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	gem "bake-releases"
	
	gem "decode"
	
	gem "utopia-project"
end

group :test do
	gem "sus"
	gem "covered"
	gem "rubocop"
	gem "rubocop-socketry"
	gem "rubocop-md"
	
	gem "sus-fixtures-console"
	
	gem "bake-test"
end
