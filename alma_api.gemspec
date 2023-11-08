# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'alma_api/version'

Gem::Specification.new do |spec|
  spec.name          = "alma_api"
  spec.version       = AlmaApi::VERSION
  spec.authors       = ["René Sprotte"]
  spec.summary       = %q{A Ruby wrapper for the Ex Libris Alma REST APIs}
  spec.homepage      = "http://github.com/ubpb/alma_api"

  spec.files          = Dir['lib/**/*.rb']
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", "> 6"
  spec.add_dependency "faraday", "~> 2.7"
  spec.add_dependency "oj", "~> 3.11"
  spec.add_dependency "hashie", "~> 5.0"
  spec.add_dependency "nokogiri", "~> 1.11"
end
