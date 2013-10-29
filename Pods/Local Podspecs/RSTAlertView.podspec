Pod::Spec.new do |s|
  s.name         = 'RSTAlertView'
  s.version      = '1.0'
  s.summary      = 'Super lightweight UIAlertView with block support'
  s.platform     = :ios, 6.0
  s.license      = 'MIT'
  s.author = {
    'Riley Testut' => 'rileytestut@gmail.com'
  }
  s.source = {
    :git => 'https://github.com/rileytestut/RSTAlertView.git',
    :tag => s.version.to_s
  }
  s.source_files = '*.{h,m}'
  s.requires_arc = true
end