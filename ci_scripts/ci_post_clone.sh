#!/bin/sh

# Xcode Cloud のクローン直後に実行されるフック。
# このプロジェクトの .xcodeproj と Supporting/Info.plist は XcodeGen の生成物
# （Git 管理外）なので、ここで project.yml から生成する。
# 参考: https://developer.apple.com/documentation/xcode/writing-custom-build-scripts

set -e

# スクリプトは ci_scripts ディレクトリから実行されるため、リポジトリ直下へ移動する。
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "Installing XcodeGen..."
brew install xcodegen

echo "Generating Xcode project from project.yml..."
xcodegen generate

echo "Done. Generated VideoCaption.xcodeproj"
