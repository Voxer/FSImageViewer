Pod::Spec.new do |s|
  s.name         = "FSImageViewer"
  s.version      = "3.2"
  s.summary      = "FSImageViewer is a photo viewer for iOS."
  s.homepage     = "https://github.com/x2on/FSImageViewer"
  s.social_media_url = 'https://twitter.com/x2on'
  s.screenshot   = 'https://raw.github.com/x2on/FSImageViewer/master/screen.png'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Felix Schulze" => "code@felixschulze.de" }
  s.source       = {
    :git => "https://github.com/x2on/FSImageViewer.git",
    :tag => s.version.to_s
  }

  s.platform     = :ios, '7.0'
  s.requires_arc = true

  s.source_files = 'FSImageViewer/FS*.{h,m}'

  s.framework	 = 'Foundation', 'UIKit', 'CoreGraphics', 'QuartzCore', 'Security', 'CFNetwork'

end
