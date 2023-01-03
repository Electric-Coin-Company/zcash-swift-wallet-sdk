Pod::Spec.new do |s|
    s.name             = 'ZcashLightClientKit'
    s.version          = '0.17.5-beta'
    s.summary          = 'Zcash Light Client wallet SDK for iOS'
  
    s.description      = <<-DESC
    Zcash Light Client wallet SDK for iOS 
                         DESC
  
    s.homepage         = 'https://github.com/zcash/ZcashLightClientKit'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 
        'Francisco Gindre' => 'francisco.gindre@gmail.com',
        'Jack Grigg' => 'str4d@electriccoin.co'
     }
    s.source           = { :git => 'https://github.com/zcash/ZcashLightClientKit.git', :tag => s.version.to_s }

    s.source_files = 'Sources/ZcashLightClientKit/**/*.{swift,h}'
    s.resource_bundles = { 'Resources' => 'Sources/ZcashLightClientKit/Resources/*' }
    s.swift_version = '5.6'
    s.ios.deployment_target = '13.0'
    s.dependency 'gRPC-Swift', '~> 1.8.0'
    s.dependency 'SQLite.swift', '~> 0.13.0' 
    s.dependency 'libzcashlc', '0.1.1'
    s.static_framework = true

end
