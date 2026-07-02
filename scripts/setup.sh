#!/bin/bash
# 在 Mac 上运行：生成 Xcode 工程并安装依赖
# 用法: cd 项目根目录 && bash scripts/setup.sh
set -e

MODEL_URL="https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
MODEL_PATH="FaceCapPro/Resources/face_landmarker.task"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "==> 安装 xcodegen"
  brew install xcodegen
fi

if ! command -v pod >/dev/null 2>&1; then
  echo "==> 安装 cocoapods"
  brew install cocoapods
fi

if [ ! -f "$MODEL_PATH" ]; then
  echo "==> 下载 MediaPipe Face Landmarker 模型"
  mkdir -p FaceCapPro/Resources
  curl -L -o "$MODEL_PATH" "$MODEL_URL"
fi

echo "==> 生成 Xcode 工程"
xcodegen generate

echo "==> 安装 Pods"
pod install

echo ""
echo "完成！打开 FaceCapPro.xcworkspace，在 Signing & Capabilities 中选择你的开发者 Team，然后连接真机运行。"
echo "（MediaPipe 不支持模拟器，且应用需要摄像头，必须真机运行）"
