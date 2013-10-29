Pod::Spec.new do |s|
  s.name         = 'RSTWebViewController'
  s.version      = '0.1'
  s.summary      = 'Powerful yet beautiful iOS 7 web browser'
  s.platform     = :ios, 7.0
  s.ios.deployment_target = '6.0'
  s.license      = 'MIT'
  s.author = {
    'Riley Testut' => 'riley@rileytestut.com'
  }
  s.source = {
    :git => 'https://github.com/rileytestut/RSTWebViewController.git',
    :tag => s.version.to_s
  }
  s.source_files = '*.{h,m}'
  s.resources = ['Media.xcassets/Back Button.imageset/*.png', 'Media.xcassets/Forward Button.imageset/*.png']
  s.dependency     'NJKWebViewProgress'
  s.requires_arc = true
end