Pod::Spec.new do |s|
  s.name        = 'LogCollection'
  s.version     = '1.0.1'
  s.summary     = '一个方便使用的日志采集库'
  s.homepage    = 'https://github.com/yechilang/LogCollection'
  s.license    = 'MIT'
  s.author      = { 'YeChiLang' => '371604109@qq.com' }
  s.description = '一个方便使用的信息采集库, 目前只用于公司项目。'

  s.source       = {:git => 'https://github.com/yechilang/LogCollection.git', :tag => "v#{s.version}"}
  # 代码文件, h, m之类 ,mm,c
  s.source_files = 'LogCollection/*.{h,m}'
  # 资源文件, xib、png之类
  s.resource_bundles = {
    'LogCollection' => ['LogCollection/*.{xib,nib,storyboard,png,bundle,xcassets}']
  }
  
  s.ios.frameworks = 'Foundation', 'UIKit'
  s.ios.deployment_target = '12.0' # minimum SDK
  s.requires_arc = true
  
  s.dependency 'SSZipArchive', '~> 2.2.3'
  s.dependency 'Qiniu', '~> 8.0.5'
end
