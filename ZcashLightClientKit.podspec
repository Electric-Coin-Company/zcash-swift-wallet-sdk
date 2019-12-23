Pod::Spec.new do |s|
    s.name             = 'ZcashLightClientKit'
    s.version          = '0.0.1'
    s.summary          = 'Zcash Light Client wallet SDK for iOS'
  
    s.description      = <<-DESC
    Zcash Light Client wallet SDK for iOS 
                         DESC
  
    s.homepage         = 'https://github.com/zcash/ZcashLightClientKit'
    s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
    s.author           = { 
        'Francisco Gindre' => 'francisco.gindre@gmail.com',
        'Jack Grigg' => 'str4d@electriccoin.co'
     }
    s.source           = { :git => 'https://github.com/zcash/ZcashLightClientKit.git', :tag => s.version.to_s }

    s.public_header_files = 'ZcashLightClientKit/ZcashLightClientKit.h'
    s.private_header_files = 'ZcashLightClientKit/zcashlc/zcashlc.h'
    s.source_files = 'ZcashLightClientKit/**/*.{swift,h,a}'
    s.module_map = 'ZcashLightClientKit.modulemap'
    s.swift_version = '5.1'
    s.ios.deployment_target = '12.0'
    s.dependency 'SwiftGRPC'
    s.dependency 'SQLite.swift'    
    s.ios.vendored_libraries = 'lib/libzcashlc.a'
    s.script_phase = {
      :name => 'Build librustzcash',
      :script => 'sh Scripts/build_librustzcash_xcode.sh',
      :execution_position => :before_compile
   }
  end
  
