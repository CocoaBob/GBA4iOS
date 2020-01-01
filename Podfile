source 'https://cdn.cocoapods.org/'

platform :ios, "9.0"

use_frameworks!


def all_pods
	pod 'RSTWebViewController', :git => 'https://github.com/rileytestut/RSTWebViewController-Legacy.git'
	pod "AFNetworking", "~> 3.2"
	pod "PSPDFTextView", :git => 'https://github.com/steipete/PSPDFTextView.git'
	pod "ObjectiveDropboxOfficial", "~> 3.10.0"
	pod "CrashlyticsFramework"
end

target 'GBA4iOS' do
	all_pods
end

target 'GBA4iOS-Simulator' do
	all_pods
end
