# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "fluent-plugin-keep-forward"
  s.version     = "0.0.4"
  s.authors     = ["Naotoshi SEO"]
  s.email       = ["sonots@gmail.com"]
  s.homepage    = "https://github.com/sonots/fluent-plugin-keep-forward"
  s.summary     = "out_foward extension to keep forwarding to a node"
  s.description = s.summary

  s.rubyforge_project = "fluent-plugin-keep-forward"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "fluentd"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "pry"
end
