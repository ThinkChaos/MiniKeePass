# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

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
  pod 'ObjectiveDropboxOfficial'
  pod 'TWMessageBarManager'
  
  pod 'GCDWebServer', '~> 3.0'
  pod 'GCDWebServer/WebUploader', '~> 3.0'
  
  pod 'FTPKit', :git => 'https://github.com/aljlue/FTPKit.git'
  
  pod 'Google-Mobile-Ads-SDK', '~> 7.31.0'
  
  pod 'RMStore', '~> 0.7'
end

target 'KeePass Touch' do
  platform :ios, '9.0'
  shared_pods
  main_pods
end

target 'KeePass Touch Autofill' do
  platform :ios, '12.0'
  shared_pods
end

post_install do |installer_representation|
  installer_representation.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['CLANG_ENABLE_CODE_COVERAGE'] = 'NO'
      if target.name == 'KeePass Touch Autofill'
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
        else
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '10.0'
      end
      
    end
  end
end
