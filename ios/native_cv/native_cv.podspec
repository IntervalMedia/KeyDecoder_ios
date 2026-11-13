Pod::Spec.new do |s|
  s.name             = 'native_cv'
  s.version          = '1.0.0'
  s.summary          = 'OpenCV homography warp used by KeyDecoder (called through Dart FFI).'
  s.homepage         = 'https://github.com/IntervalMedia/KeyDecoder'
  s.license          = { :type => 'Aladdin Free Public License v9', :file => '../../LICENSE' }
  s.author           = { 'KeyDecoder' => 'noreply@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.{cpp,h}'
  s.platform         = :ios, '15.0'
  s.dependency 'OpenCV2', '4.3.0'
  s.libraries        = 'c++'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'OTHER_CPLUSPLUSFLAGS' => '-frtti -fexceptions',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
  }
end
