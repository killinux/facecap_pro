platform :ios, '16.0'

target 'FaceCapPro' do
  use_frameworks!
  # Google MediaPipe Tasks Vision：Face Landmarker（478 关键点 + 52 blendshapes）
  pod 'MediaPipeTasksVision'
end

post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |c|
      c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
