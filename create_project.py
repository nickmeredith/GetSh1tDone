#!/usr/bin/env python3
"""
Script to create a proper Xcode project file for GetSh1tDone
"""
import os
import uuid

def generate_uuid():
    """Generate a 24-character hex string for Xcode UUIDs"""
    return ''.join(uuid.uuid4().hex[:12].upper())

# Generate all UUIDs
project_uuid = generate_uuid()
target_uuid = generate_uuid()
sources_phase = generate_uuid()
resources_phase = generate_uuid()
frameworks_phase = generate_uuid()
main_group = generate_uuid()
products_group = generate_uuid()
app_group = generate_uuid()
root_group = generate_uuid()

# File references
app_ref = generate_uuid()
app_swift = generate_uuid()
content_view = generate_uuid()
reminders_manager = generate_uuid()
eisenhower_view = generate_uuid()
task_quadrant = generate_uuid()
planning_view = generate_uuid()
task_challenge = generate_uuid()
priorities_view = generate_uuid()
assets = generate_uuid()
info_plist = generate_uuid()
entitlements = generate_uuid()

# Build files
bf_app = generate_uuid()
bf_content = generate_uuid()
bf_reminders = generate_uuid()
bf_eisenhower = generate_uuid()
bf_task = generate_uuid()
bf_planning = generate_uuid()
bf_challenge = generate_uuid()
bf_priorities = generate_uuid()
bf_assets = generate_uuid()

# Config lists
project_config = generate_uuid()
target_config = generate_uuid()
debug_config = generate_uuid()
release_config = generate_uuid()
debug_target = generate_uuid()
release_target = generate_uuid()

project_content = f'''// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
		{bf_app} /* GetSh1tDoneApp.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {app_swift} /* GetSh1tDoneApp.swift */; }};
		{bf_content} /* ContentView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {content_view} /* ContentView.swift */; }};
		{bf_reminders} /* RemindersManager.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {reminders_manager} /* RemindersManager.swift */; }};
		{bf_eisenhower} /* EisenhowerMatrixView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {eisenhower_view} /* EisenhowerMatrixView.swift */; }};
		{bf_task} /* TaskQuadrant.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {task_quadrant} /* TaskQuadrant.swift */; }};
		{bf_planning} /* PlanningView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {planning_view} /* PlanningView.swift */; }};
		{bf_challenge} /* TaskChallengeView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {task_challenge} /* TaskChallengeView.swift */; }};
		{bf_priorities} /* PrioritiesView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {priorities_view} /* PrioritiesView.swift */; }};
		{bf_assets} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets} /* Assets.xcassets */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
		{app_ref} /* GetSh1tDone.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = GetSh1tDone.app; sourceTree = BUILT_PRODUCTS_DIR; }};
		{app_swift} /* GetSh1tDoneApp.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = GetSh1tDoneApp.swift; sourceTree = "<group>"; }};
		{content_view} /* ContentView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ContentView.swift; sourceTree = "<group>"; }};
		{reminders_manager} /* RemindersManager.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = RemindersManager.swift; sourceTree = "<group>"; }};
		{eisenhower_view} /* EisenhowerMatrixView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = EisenhowerMatrixView.swift; sourceTree = "<group>"; }};
		{task_quadrant} /* TaskQuadrant.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TaskQuadrant.swift; sourceTree = "<group>"; }};
		{planning_view} /* PlanningView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PlanningView.swift; sourceTree = "<group>"; }};
		{task_challenge} /* TaskChallengeView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = TaskChallengeView.swift; sourceTree = "<group>"; }};
		{priorities_view} /* PrioritiesView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PrioritiesView.swift; sourceTree = "<group>"; }};
		{assets} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};
		{info_plist} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
		{entitlements} /* GetSh1tDone.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = GetSh1tDone.entitlements; sourceTree = "<group>"; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{root_group} = {{
			isa = PBXGroup;
			children = (
				{app_group} /* GetSh1tDone */,
				{products_group} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{app_group} /* GetSh1tDone */ = {{
			isa = PBXGroup;
			children = (
				{app_swift} /* GetSh1tDoneApp.swift */,
				{content_view} /* ContentView.swift */,
				{reminders_manager} /* RemindersManager.swift */,
				{eisenhower_view} /* EisenhowerMatrixView.swift */,
				{task_quadrant} /* TaskQuadrant.swift */,
				{planning_view} /* PlanningView.swift */,
				{task_challenge} /* TaskChallengeView.swift */,
				{priorities_view} /* PrioritiesView.swift */,
				{assets} /* Assets.xcassets */,
				{info_plist} /* Info.plist */,
				{entitlements} /* GetSh1tDone.entitlements */,
			);
			path = GetSh1tDone;
			sourceTree = "<group>";
		}};
		{products_group} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{app_ref} /* GetSh1tDone.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target_uuid} /* GetSh1tDone */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {target_config} /* Build configuration list for PBXNativeTarget "GetSh1tDone" */;
			buildPhases = (
				{sources_phase} /* Sources */,
				{frameworks_phase} /* Frameworks */,
				{resources_phase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = GetSh1tDone;
			productName = GetSh1tDone;
			productReference = {app_ref} /* GetSh1tDone.app */;
			productType = "com.apple.product-type.application";
			supportedPlatforms = (
				iphoneos,
				iphonesimulator,
			);
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project_uuid} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
			}};
			buildConfigurationList = {project_config} /* Build configuration list for PBXProject "GetSh1tDone" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {root_group};
			productRefGroup = {products_group} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target_uuid} /* GetSh1tDone */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{bf_assets} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{bf_app} /* GetSh1tDoneApp.swift in Sources */,
				{bf_content} /* ContentView.swift in Sources */,
				{bf_reminders} /* RemindersManager.swift in Sources */,
				{bf_eisenhower} /* EisenhowerMatrixView.swift in Sources */,
				{bf_task} /* TaskQuadrant.swift in Sources */,
				{bf_planning} /* PlanningView.swift in Sources */,
				{bf_challenge} /* TaskChallengeView.swift in Sources */,
				{bf_priorities} /* PrioritiesView.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{debug_config} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				TARGETED_DEVICE_FAMILY = "1,2";
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		{release_config} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				TARGETED_DEVICE_FAMILY = "1,2";
				SWIFT_COMPILATION_MODE = wholemodule;
			}};
			name = Release;
		}};
		{debug_target} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CODE_SIGN_ENTITLEMENTS = GetSh1tDone/GetSh1tDone.entitlements;
				CODE_SIGN_STYLE = Automatic;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = GetSh1tDone/Info.plist;
				INFOPLIST_KEY_NSRemindersUsageDescription = "GetSh1tDone needs access to your reminders to help you organize tasks in the Eisenhower matrix.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.getsh1tdone.$(USER);
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Debug;
		}};
		{release_target} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CODE_SIGN_ENTITLEMENTS = GetSh1tDone/GetSh1tDone.entitlements;
				CODE_SIGN_STYLE = Automatic;
				DEVELOPMENT_ASSET_PATHS = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = GetSh1tDone/Info.plist;
				INFOPLIST_KEY_NSRemindersUsageDescription = "GetSh1tDone needs access to your reminders to help you organize tasks in the Eisenhower matrix.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.getsh1tdone.$(USER);
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{target_config} /* Build configuration list for PBXNativeTarget "GetSh1tDone" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_target} /* Debug */,
				{release_target} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{project_config} /* Build configuration list for PBXProject "GetSh1tDone" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_config} /* Debug */,
				{release_config} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {project_uuid} /* Project object */;
}}
'''

# Write the project file
project_dir = os.path.dirname(os.path.abspath(__file__))
project_file = os.path.join(project_dir, 'GetSh1tDone.xcodeproj', 'project.pbxproj')

os.makedirs(os.path.dirname(project_file), exist_ok=True)

with open(project_file, 'w') as f:
    f.write(project_content)

print(f"✅ Created Xcode project file at: {project_file}")
print("You can now open GetSh1tDone.xcodeproj in Xcode!")

