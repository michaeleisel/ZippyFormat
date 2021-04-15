Pod::Spec.new do |s|
  s.name             = 'ZippyFormat'
  s.version          = '1.0.1'
  s.summary          = 'A faster version of +[NSString stringWithFormat:]'

  s.description      = <<-DESC
ZippyFormat is a fast drop-in replacement for +[NSString stringWithFormat:]
                       DESC

  s.homepage         = 'https://github.com/michaeleisel/ZippyFormat'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'michaeleisel' => 'michael.eisel@gmail.com' }
  s.source           = { :git => 'https://github.com/michaeleisel/ZippyFormat.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.13'

  s.source_files = 'Sources/**/*.{h,hh,mm,m,c,cpp}'
  s.requires_arc = false

  s.test_spec 'Tests' do |test_spec|
    # test_spec.requires_app_host = true
    test_spec.requires_arc = true
    test_spec.source_files = 'Tests/**/*.{swift,h,m}'
  end
end
