platform :ios, '12.0'

def shared_pods
  pod 'MBProgressHUD'
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'Firebase/Core'
end

def main_pods
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
  # use_frameworks!
  
  # Pods for KeePass Touch
  pod 'TWMessageBarManager'
end

target 'KeePass Touch' do
  shared_pods
  main_pods
end

target 'KeePass Touch Autofill' do
  shared_pods
end

post_install do |installer_representation|
  installer_representation.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CLANG_ENABLE_CODE_COVERAGE'] = 'NO'
    end
  end
end
