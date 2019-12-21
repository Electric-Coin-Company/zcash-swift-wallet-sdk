Pod::Spec.new do |s|
    s.name             = 'ZcashLightClientKit-Testnet'
    s.version          = '0.0.1'
    s.summary          = 'Zcash Testnet Light Client wallet SDK for iOS'
  
    s.description      = <<-DESC
    Zcash Testnet Light Client wallet SDK for iOS 
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
    s.exclude_files = 'ZcashLightClientKit/Mainnet/**/*'
    s.module_map = 'ZcashLightClientKit-Testnet.modulemap'
    s.swift_version = '5.1'
    s.ios.deployment_target = '12.0'
    s.dependency 'SwiftGRPC'
    s.dependency 'SQLite.swift'    
    s.ios.vendored_libraries = 'lib/testnet/libzcashlc.a'
    s.prepare_command = <<-CMD
       sh build_librustzcash.sh --testnet
    CMD
    
    s.test_spec 'Tests' do | test_spec |
        test_spec.source_files = 'ZcashLightClientKitTests/**/*.{swift}'
        test_spec.ios.resources = 'ZcashLightClientKitTests/**/*.{db,params}'
        test_spec.dependency 'SwiftGRPC'
        test_spec.dependency 'SQLite.swift'
    end
  end
  
