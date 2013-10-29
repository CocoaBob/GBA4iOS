Pod::Spec.new do |s|
  s.name         = 'RSTActionSheet'
  s.version      = '1.0'
  s.summary      = 'Super lightweight UIActionSheet with block support'
  s.platform     = :ios, 6.0
  s.license      = 'MIT'
  s.author = {
    'Riley Testut' => 'rileytestut@gmail.com'
  }
  s.source = {
    :git => 'https://github.com/rileytestut/RSTActionSheet.git',
    :tag => s.version.to_s
  }
  s.source_files = '*.{h,m}'
  s.requires_arc = true
end