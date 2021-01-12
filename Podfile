# Uncomment the next line to define a global platform for your project
platform :ios, '12.0'

inhibit_all_warnings!
target 'YCLLogCollection' do
  # Comment the next line if you don't want to use dynamic frameworks
  # use_frameworks!
  pod 'SSZipArchive', "~> 2.2.3"
  pod "Qiniu", "~> 8.0.5"
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
        end
    end
end
