target 'SampleChatApp' do
  platform :ios, '10.0'

  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # TODO: Remove git reference when Swift
  pod 'Eureka', '~> 4.0.0'
  pod 'Alamofire', '~> 4.5'
  pod 'MessageKit', '0.8.1'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        if target.name == 'MessageKit'
            target.build_configurations.each do |config|
                config.build_settings['SWIFT_VERSION'] = '3.0'
            end
        end
    end
end
