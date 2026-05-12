Pod::Spec.new do |s|
  s.name = 'AlamofireObjc'
  s.version = '1.0.0'
  s.summary = 'Objective-C bridge for Alamofire.'
  s.homepage = 'https://github.com/xuzeyu/AlamofireObjc'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'XUZY' => 'topy-123@qq.com' }

  s.platform = :ios, '10.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '10.0'
  s.watchos.deployment_target = '2.0'

  s.source = {
    :git => 'https://github.com/xuzeyu/AlamofireObjc.git',
    :tag => s.version.to_s
  }

  s.requires_arc = true
  s.swift_version = '5.0'

  s.source_files = 'AlamofireObjc/**/*.swift'

  s.frameworks = 'Foundation'
  s.module_name = 'AlamofireObjc'

  s.dependency 'Alamofire'
end
