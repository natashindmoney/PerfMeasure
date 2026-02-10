Pod::Spec.new do |s|
  s.name         = 'INDProfiler'
  s.version      = '0.1.0'
  s.summary      = 'Lightweight, zero-dependency performance profiling for iOS.'
  s.description  = <<-DESC
    INDProfiler measures wall-clock time, memory, CPU, thermal state, and
    UI frame rate.  Results are routed to pluggable destinations (console,
    JSONL, NewRelic, custom analytics).  When disabled via feature flags,
    every measurement call reduces to a single boolean check.
  DESC
  s.homepage     = 'https://github.com/natashindmoney/ios-INDProfiler'
  s.license      = { :type => 'Proprietary', :text => 'Internal – INDmoney' }
  s.author       = { 'Natash Bangera' => 'natash.bangera@indmoney.com' }
  s.source       = { :git => 'https://github.com/natashindmoney/ios-INDProfiler.git', :branch => 'feature/indprofiler' }

  s.ios.deployment_target = '17.0'
  s.swift_version = '5.9'

  s.source_files = 'Sources/INDProfiler/**/*.swift'
  s.frameworks   = 'Foundation', 'QuartzCore'
end
