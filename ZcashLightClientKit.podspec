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

    s.public_header_files = 'ZcashLightClientKit/**/*.h'
    s.source_files = 'ZcashLightClientKit/**/*.{swift,h,a}'
    s.module_map = 'ZcashLightClientKit.modulemap'
    s.swift_version = '5.0'
    s.ios.deployment_target = '11.0'
    s.ios.vendored_libraries = 'lib/libzcashlc.a'
    s.prepare_command = <<-CMD
        BASEPATH="${PWD}"
        echo "Building librustzcash library..."
        cargo build && cargo lipo
        
        mkdir -p lib
        cp target/universal/debug/* lib/
        cp -rf target/universal/debug/*  ZcashLightClientKit/zcashlc
            CMD
  end
  