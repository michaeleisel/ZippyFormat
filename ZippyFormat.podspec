Pod::Spec.new do |s|
  s.name             = 'ZippyFormat'
  s.version          = '1.0.0'
  s.summary          = 'A 2.5x+ speed, drop-in replacement for +[NSString stringWithFormat:]'

  s.description      = <<-DESC
ZippyFormat is a fast (2.5-4x speed) drop-in replacement for +[NSString stringWithFormat:]
                       DESC

  s.homepage         = 'https://github.com/michaeleisel/ZippyJSON'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'michaeleisel' => 'michael.eisel@gmail.com' }
  s.source           = { :git => 'https://github.com/michaeleisel/ZippyFormat.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.13'

  s.source_files = 'Sources/**/*.{h,hh,mm,m,c,cpp}'
  s.requires_arc = false

  s.test_spec 'Tests' do |test_spec|
    # test_spec.requires_app_host = true
    test_spec.source_files = 'Tests/**/*.{swift,h,m}'
  end
end
