# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
platform :osx, '10.13'

target 'LeetDown' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for LeetDown
  pod 'AFNetworking', '~> 4.0'
end

post_install do |pi|
    pi.pods_project.targets.each do |t|
        t.build_configurations.each do |config|
            config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.13'
        end
    end
end


