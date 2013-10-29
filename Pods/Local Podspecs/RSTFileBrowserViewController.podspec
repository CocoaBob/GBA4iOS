Pod::Spec.new do |s|
  s.name         = 'RSTFileBrowserViewController'
  s.version      = '0.1'
  s.summary      = 'Lightweight, easy-to-use iOS browser'
  s.platform     = :ios, 6.0
  s.license      = 'MIT'
  s.author = {
    'Riley Testut' => 'rileytestut@gmail.com'
  }
  s.source = {
    :git => 'https://github.com/rileytestut/RSTFileBrowserViewController.git',
    :tag => s.version.to_s
  }
  s.source_files = '*.{h,m}'
  s.requires_arc = true
end