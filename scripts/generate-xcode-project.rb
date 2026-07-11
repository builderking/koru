#!/usr/bin/env ruby
require "xcodeproj"

project = Xcodeproj::Project.new("Koru.xcodeproj")
project.root_object.attributes["LastSwiftUpdateCheck"] = "2660"
project.root_object.attributes["LastUpgradeCheck"] = "2660"

package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = "."
project.root_object.package_references << package

def add_app(project, package, name, sources, products, plist, bundle_id)
  target = project.new_target(:application, name, :osx, "13.0")
  group = project.main_group.new_group(name)
  sources.each do |path|
    ref = group.new_file(path)
    target.source_build_phase.add_file_reference(ref) if path.end_with?(".swift")
  end
  products.each do |product_name|
    dependency = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dependency.package = package
    dependency.product_name = product_name
    target.package_product_dependencies << dependency
    build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = dependency
    target.frameworks_build_phase.files << build_file
  end
  target.build_configurations.each do |config|
    config.build_settings["PRODUCT_BUNDLE_IDENTIFIER"] = bundle_id
    config.build_settings["INFOPLIST_FILE"] = plist
    config.build_settings["SWIFT_VERSION"] = "6.0"
    config.build_settings["SWIFT_STRICT_CONCURRENCY"] = "complete"
    config.build_settings["CODE_SIGNING_ALLOWED"] = "NO"
    config.build_settings["ARCHS"] = "arm64 x86_64"
    config.build_settings["ONLY_ACTIVE_ARCH"] = config.name == "Debug" ? "YES" : "NO"
    config.build_settings["MACOSX_DEPLOYMENT_TARGET"] = "13.0"
  end
  target
end

add_app(project, package, "Koru", ["App/main.swift"], ["KoruDomain", "KoruPlatform", "KoruUI"], "Config/Koru-Info.plist", "dev.builderking.koru")
add_app(project, package, "KoruIntegrationHarness", ["Harness/main.swift"], ["KoruDomain", "KoruPlatform", "KoruUI"], "Config/Harness-Info.plist", "dev.builderking.koru.harness")
project.save
