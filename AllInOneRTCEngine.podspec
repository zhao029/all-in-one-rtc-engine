#
# Be sure to run `pod lib lint AllInOneRTCEngine.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'AllInOneRTCEngine'
  s.version          = '0.1.10'
  s.summary          = 'A short description of AllInOneRTCEngine.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.homepage         = 'https://github.com/zhao029/all-in-one-rtc-engine'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'chengyuzhao' => 'chengyuzhao@tencent.com' }
  s.source           = { :git => 'https://github.com/zhao029/all-in-one-rtc-engine.git', :tag => s.version }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
  
  s.ios.deployment_target = '12.0'
  s.static_framework = true
  
  s.vendored_frameworks = 'AllInOneRTCEngine/AllInOneRTCEngine.xcframework'
  
  # s.resource_bundles = {
  #   'AllInOneRTCEngine' => ['AllInOneRTCEngine/Assets/*.png']
  # }

  # s.frameworks = 'UIKit', 'MapKit'
   s.dependency 'AgoraRtcEngine_iOS/RtcBasic', '~> 4.3.2'
   s.dependency 'TXLiteAVSDK_TRTC', '~> 12.2.16956'
end
