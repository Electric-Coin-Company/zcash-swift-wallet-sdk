Pod::Spec.new do |s|
    s.name             = 'ZcashLightClientKit'
    s.version          = '0.12.0-beta.6'
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
    s.swift_version = '5.4'
    s.ios.deployment_target = '12.0'
    s.dependency 'gRPC-Swift', '= 1.0.0'
    s.dependency 'SQLite.swift', '~> 0.12.2' 
    s.dependency 'libzcashlc', '0.0.1'
    s.static_framework = true

end
