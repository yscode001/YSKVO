Pod::Spec.new do |s|

s.name         = "YSKVO"

s.version      = "1.0.0"

s.summary      = "YSKVO自定义KVO功能"

s.homepage     = "https://github.com/yscode001/YSKVO"

s.license      = "MIT"

s.author       = { "ys" => "yscode@126.com" }

s.platform     = :ios, "11.0"

s.source       = { :git => "https://github.com/yscode001/YSKVO.git", :tag => "#{s.version}" }

s.source_files  = "YSKVO/YSKVO/YSKVO/*.{h,m}"

s.frameworks = "UIKit"

end
