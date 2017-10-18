source 'https://github.com/CocoaPods/Specs.git'

platform :ios, "9.0"

inhibit_all_warnings!


def all_pods
	pod 'RSTWebViewController', :git => 'https://github.com/rileytestut/RSTWebViewController-Legacy.git'
	pod "AFNetworking", "~> 2.4"
	pod "PSPDFTextView", :git => 'https://github.com/steipete/PSPDFTextView.git'
	pod "ObjectiveDropboxOfficial", "~> 3.3.4"
	pod "CrashlyticsFramework", "~> 2.1.0"
end

target 'GBA4iOS' do
	all_pods
end

target 'GBA4iOS-Simulator' do
	all_pods
end
