# frozen_string_literal: true

require_relative "lib/payhub/version"

Gem::Specification.new do |spec|
  spec.name = "payhub"
  spec.version = Payhub::VERSION
  spec.authors = ["SafwaTech"]
  spec.email = ["sdk@payhub.ly"]

  spec.summary = "Official PayHub SDK for Ruby."
  spec.description = "Idempotent client + webhook verifier for the PayHub v1 payment hub. Targets Libyan PSPs (Sadad, Moamalat, Mobicash, T-Lync, Adfali)."
  spec.homepage = "https://payhub.ly"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/safwatech/payhub"
  spec.metadata["changelog_uri"] = "https://github.com/safwatech/payhub/blob/main/sdks/ruby/CHANGELOG.md"

  spec.files = Dir.glob("{lib,LICENSE,README.md}/**/*") + ["LICENSE", "README.md", "payhub.gemspec"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "webmock", "~> 3.23"
  spec.add_development_dependency "standard", "~> 1.40"
end
