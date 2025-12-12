# Uncomment the next line to define a global platform for your project
platform :ios, '15.0'

target 'qcarios' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Supabase
  pod 'Supabase', '~> 2.0'

  # AMap SDK (高德地图)
  pod 'AMapFoundation-NO-IDFA', '~> 1.7.0'
  pod 'AMap3DMap-NO-IDFA', '~> 9.7.0'
  pod 'AMapSearch-NO-IDFA', '~> 9.7.0'
  pod 'AMapNavi-NO-IDFA', '~> 9.7.0'
  pod 'AMapLocation-NO-IDFA', '~> 2.10.0'

  # Networking
  pod 'Alamofire', '~> 5.8'

  # Image Loading
  pod 'Kingfisher', '~> 7.10'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end