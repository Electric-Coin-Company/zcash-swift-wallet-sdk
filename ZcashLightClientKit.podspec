Pod::Spec.new do |s|
    s.name             = 'ZcashLightClientKit'
    s.version          = '0.9.1'
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

    s.source_files = 'ZcashLightClientKit/**/*.{swift,h,a}'
    s.swift_version = '5.1'
    s.ios.deployment_target = '12.0'
    s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
    s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
    s.dependency 'gRPC-Swift', '= 1.0.0-alpha.19'
    s.dependency 'SQLite.swift', '~> 0.12.2' 
    s.ios.vendored_libraries = 'lib/libzcashlc.a'
    s.preserve_paths = ['Scripts', 'rust','docs','Cargo.*','ZcashLightClientKit/Stencil']
    s.prepare_command = <<-CMD
      sh Scripts/prepare_zcash_sdk.sh
    CMD

    s.script_phase = {
      :name => 'Build generate constants and build librustzcash',
      :script => 'sh ${PODS_TARGET_SRCROOT}/Scripts/generate_zcashsdk_constants.sh && sh ${PODS_TARGET_SRCROOT}/Scripts/build_librustzcash_xcode.sh',
      :execution_position => :before_compile
   }
   s.test_spec 'Tests' do | test_spec |
      test_spec.source_files = 'ZcashLightClientKitTests/**/*.{swift}'
      test_spec.ios.resources = 'ZcashLightClientKitTests/**/*.{db,params}'
      test_spec.script_phase = {
         :name => 'Build generate constants and build librustzcash',
         :script => 'sh ${PODS_TARGET_SRCROOT}/Scripts/generate_test_constants.sh && ${PODS_TARGET_SRCROOT}/Scripts/build_librustzcash_xcode.sh --testing',
         :execution_position => :before_compile
      }
      test_spec.dependency 'gRPC-Swift', '= 1.0.0-alpha.19'
      test_spec.dependency 'SQLite.swift', '~> 0.12.2'
  end
end
