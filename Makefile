.PHONY: build buildSdk buildExamples format swiftLint swiftFormat test testOniOSSimulator testOnMacSimulator lint bootstrap releaseCocoaPods

build: buildSdk buildExamples

# set -o pipefail && xcrun xcodebuild build -scheme Paylisher -destination 'platform=visionOS Simulator,name=Apple Vision Pro' | xcpretty #visionOS
buildSdk:
	set -o pipefail && xcrun xcodebuild -downloadAllPlatforms
	set -o pipefail && xcrun xcodebuild build -scheme Paylisher -destination generic/platform=ios | xcpretty #ios
	set -o pipefail && xcrun swift build --arch arm64 #macOS
	set -o pipefail && xcrun xcodebuild build -scheme Paylisher -destination generic/platform=macos | xcpretty #macOS
	set -o pipefail && xcrun xcodebuild build -scheme Paylisher -destination generic/platform=tvos | xcpretty #tvOS
	set -o pipefail && xcrun xcodebuild build -scheme Paylisher -destination generic/platform=watchos | xcpretty #watchOS

buildExamples:
	set -o pipefail && xcrun xcodebuild -downloadAllPlatforms
	set -o pipefail && xcrun xcodebuild build -scheme PaylisherExample -destination generic/platform=ios | xcpretty #ios
	set -o pipefail && xcrun xcodebuild build -scheme PaylisherObjCExample -destination generic/platform=ios | xcpretty #ObjC
	set -o pipefail && xcrun xcodebuild build -scheme PaylisherExampleMacOS -destination generic/platform=macos | xcpretty #macOS
	set -o pipefail && xcrun xcodebuild build -scheme 'PaylisherExampleWatchOS Watch App' -destination generic/platform=watchos | xcpretty #watchOS
	set -o pipefail && xcrun xcodebuild build -scheme PaylisherExampleTvOS -destination generic/platform=tvos | xcpretty #watchOS
	cd PaylisherExampleWithPods && pod install
	cd ..
	set -o pipefail && xcrun xcodebuild build -workspace PaylisherExampleWithPods/PaylisherExampleWithPods.xcworkspace -scheme PaylisherExampleWithPods -destination generic/platform=ios | xcpretty #CocoaPods
	set -o pipefail && xcrun xcodebuild build -scheme PaylisherExampleWithSPM -destination generic/platform=ios | xcpretty #SPM

format: swiftLint swiftFormat

swiftLint:
	swiftlint --fix

swiftFormat:
	swiftformat . --swiftversion 5.3

testOniOSSimulator:
	set -o pipefail && xcrun xcodebuild test -scheme Paylisher -destination 'platform=iOS Simulator,name=iPhone 15,OS=18.0' | xcpretty

testOnMacSimulator:
	set -o pipefail && xcrun xcodebuild test -scheme Paylisher -destination 'platform=macOS' | xcpretty

test:
	swift test | xcpretty

lint:
	swiftformat . --lint --swiftversion 5.3 && swiftlint

# requires gem and brew
bootstrap:
	gem install xcpretty
	brew install swiftlint
	brew install swiftformat

releaseCocoaPods:
	pod trunk push Paylisher.podspec --allow-warnings
