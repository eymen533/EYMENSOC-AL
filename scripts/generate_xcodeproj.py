#!/usr/bin/env python3
"""Generate a minimal SOC.xcodeproj that references sources + TeslaBLEKeyKit SPM."""

from __future__ import annotations

import os
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJ = ROOT / "SOC.xcodeproj"
SWIFT_FILES = sorted(p for p in (ROOT / "SOC").rglob("*.swift"))
ASSETS = ROOT / "SOC" / "Resources" / "Assets.xcassets"
INFO = ROOT / "SOC" / "Resources" / "Info.plist"


def hid() -> str:
    return uuid.uuid4().hex[:24].upper()


project_id = hid()
target_id = hid()
sources_phase = hid()
resources_phase = hid()
frameworks_phase = hid()
project_config_list = hid()
target_config_list = hid()
debug_project = hid()
release_project = hid()
debug_target = hid()
release_target = hid()
product_ref = hid()
package_ref = hid()
package_product = hid()
main_group = hid()
products_group = hid()
soc_group = hid()
sources_build_files = {}
file_refs = {}

for path in SWIFT_FILES:
    file_refs[path] = hid()
    sources_build_files[path] = hid()

assets_ref = hid()
assets_build = hid()
info_ref = hid()

# Nested groups by relative parent
groups: dict[str, str] = {"": soc_group}
for path in SWIFT_FILES:
    rel = path.relative_to(ROOT / "SOC")
    parent = str(rel.parent) if str(rel.parent) != "." else ""
    parts = parent.split("/") if parent else []
    accum = []
    for part in parts:
        accum.append(part)
        key = "/".join(accum)
        if key not in groups:
            groups[key] = hid()


def group_children(key: str) -> list[str]:
    kids = []
    prefix = key + "/" if key else ""
    # child groups
    for g in sorted(groups):
        if not g:
            continue
        parent = "/".join(g.split("/")[:-1])
        if parent == key:
            kids.append(groups[g])
    # child files
    for path in SWIFT_FILES:
        rel = path.relative_to(ROOT / "SOC")
        parent = str(rel.parent) if str(rel.parent) != "." else ""
        if parent == key:
            kids.append(file_refs[path])
    if key == "":
        kids.append(assets_ref)
        kids.append(info_ref)
    return kids


lines = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tclasses = {")
lines.append("\t};")
lines.append("\tobjectVersion = 56;")
lines.append("\tobjects = {")
lines.append("")
lines.append("/* Begin PBXBuildFile section */")
for path in SWIFT_FILES:
    rel = path.relative_to(ROOT)
    lines.append(
        f"\t\t{sources_build_files[path]} /* {path.name} in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {file_refs[path]} /* {path.name} */; }};"
    )
lines.append(
    f"\t\t{assets_build} /* Assets.xcassets in Resources */ = "
    f"{{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};"
)
lines.append(
    f"\t\t{hid()} /* TeslaBLEKeyKit in Frameworks */ = "
    f"{{isa = PBXBuildFile; productRef = {package_product} /* TeslaBLEKeyKit */; }};"
)
# Keep product build file id stable-ish by recomputing once
# Actually we need the frameworks build file id. Rebuild carefully:
lines.pop()
frameworks_build = hid()
lines.append(
    f"\t\t{frameworks_build} /* TeslaBLEKeyKit in Frameworks */ = "
    f"{{isa = PBXBuildFile; productRef = {package_product} /* TeslaBLEKeyKit */; }};"
)
lines.append("/* End PBXBuildFile section */")
lines.append("")

lines.append("/* Begin PBXFileReference section */")
lines.append(
    f"\t\t{product_ref} /* SOC.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; "
    f"includeInIndex = 0; path = SOC.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
)
for path in SWIFT_FILES:
    rel = path.relative_to(ROOT / "SOC")
    lines.append(
        f"\t\t{file_refs[path]} /* {path.name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; "
        f"path = {path.name}; sourceTree = \"<group>\"; }};"
    )
lines.append(
    f"\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; "
    f"name = Assets.xcassets; path = Resources/Assets.xcassets; sourceTree = \"<group>\"; }};"
)
lines.append(
    f"\t\t{info_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; "
    f"name = Info.plist; path = Resources/Info.plist; sourceTree = \"<group>\"; }};"
)
lines.append("/* End PBXFileReference section */")
lines.append("")

lines.append("/* Begin PBXFrameworksBuildPhase section */")
lines.append(f"\t\t{frameworks_phase} /* Frameworks */ = {{")
lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append(f"\t\t\t\t{frameworks_build} /* TeslaBLEKeyKit in Frameworks */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXFrameworksBuildPhase section */")
lines.append("")

lines.append("/* Begin PBXGroup section */")
lines.append(f"\t\t{main_group} = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{soc_group} /* SOC */,")
lines.append(f"\t\t\t\t{products_group} /* Products */,")
lines.append("\t\t\t);")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")
lines.append(f"\t\t{products_group} /* Products */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{product_ref} /* SOC.app */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = Products;")
lines.append("\t\t\tsourceTree = \"<group>\";")
lines.append("\t\t};")

# Resource subgroup under SOC/Resources
resources_group = hid()
groups_for_resources_parent = "Resources"
if groups_for_resources_parent not in groups:
    groups[groups_for_resources_parent] = resources_group
else:
    resources_group = groups[groups_for_resources_parent]

for key, gid in sorted(groups.items(), key=lambda kv: kv[0]):
    name = key.split("/")[-1] if key else "SOC"
    path = name
    children = group_children(key)
    # Ensure Resources group includes assets/info even if already added at root of SOC
    lines.append(f"\t\t{gid} /* {name} */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for child in children:
        # annotate
        label = "child"
        for p, fr in file_refs.items():
            if fr == child:
                label = p.name
        if child == assets_ref:
            label = "Assets.xcassets"
        if child == info_ref:
            label = "Info.plist"
        for gkey, ggid in groups.items():
            if ggid == child and gkey:
                label = gkey.split("/")[-1]
        lines.append(f"\t\t\t\t{child} /* {label} */,")
    lines.append("\t\t\t);")
    if key == "":
        lines.append("\t\t\tpath = SOC;")
    else:
        lines.append(f"\t\t\tpath = {name};")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

lines.append("/* End PBXGroup section */")
lines.append("")

lines.append("/* Begin PBXNativeTarget section */")
lines.append(f"\t\t{target_id} /* SOC */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append(f"\t\t\tbuildConfigurationList = {target_config_list} /* Build configuration list for PBXNativeTarget \"SOC\" */;")
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{sources_phase} /* Sources */,")
lines.append(f"\t\t\t\t{frameworks_phase} /* Frameworks */,")
lines.append(f"\t\t\t\t{resources_phase} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tname = SOC;")
lines.append(f"\t\t\tpackageProductDependencies = (")
lines.append(f"\t\t\t\t{package_product} /* TeslaBLEKeyKit */,")
lines.append("\t\t\t);")
lines.append("\t\t\tproductName = SOC;")
lines.append(f"\t\t\tproductReference = {product_ref} /* SOC.app */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
lines.append("\t\t};")
lines.append("/* End PBXNativeTarget section */")
lines.append("")

lines.append("/* Begin PBXProject section */")
lines.append(f"\t\t{project_id} /* Project object */ = {{")
lines.append("\t\t\tisa = PBXProject;")
lines.append("\t\t\tattributes = {")
lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
lines.append("\t\t\t\tLastSwiftUpdateCheck = 1600;")
lines.append("\t\t\t\tLastUpgradeCheck = 1600;")
lines.append("\t\t\t};")
lines.append(f"\t\t\tbuildConfigurationList = {project_config_list} /* Build configuration list for PBXProject \"SOC\" */;")
lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
lines.append("\t\t\tdevelopmentRegion = tr;")
lines.append("\t\t\thasScannedForEncodings = 0;")
lines.append("\t\t\tknownRegions = (")
lines.append("\t\t\t\ten,")
lines.append("\t\t\t\ttr,")
lines.append("\t\t\t\tBase,")
lines.append("\t\t\t);")
lines.append(f"\t\t\tmainGroup = {main_group};")
lines.append(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
lines.append("\t\t\tprojectDirPath = \"\";")
lines.append("\t\t\tprojectRoot = \"\";")
lines.append("\t\t\tpackageReferences = (")
lines.append(f"\t\t\t\t{package_ref} /* XCRemoteSwiftPackageReference \"TeslaBLEKeyKit\" */,")
lines.append("\t\t\t);")
lines.append("\t\t\ttargets = (")
lines.append(f"\t\t\t\t{target_id} /* SOC */,")
lines.append("\t\t\t);")
lines.append("\t\t};")
lines.append("/* End PBXProject section */")
lines.append("")

lines.append("/* Begin PBXResourcesBuildPhase section */")
lines.append(f"\t\t{resources_phase} /* Resources */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
lines.append(f"\t\t\t\t{assets_build} /* Assets.xcassets in Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXResourcesBuildPhase section */")
lines.append("")

lines.append("/* Begin PBXSourcesBuildPhase section */")
lines.append(f"\t\t{sources_phase} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for path in SWIFT_FILES:
    lines.append(f"\t\t\t\t{sources_build_files[path]} /* {path.name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXSourcesBuildPhase section */")
lines.append("")

lines.append("/* Begin XCBuildConfiguration section */")
for cid, name in [(debug_project, "Debug"), (release_project, "Release")]:
    lines.append(f"\t\t{cid} /* {name} */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    lines.append("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
    lines.append("\t\t\t\tCOPY_PHASE_STRIP = NO;")
    if name == "Debug":
        lines.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
        lines.append("\t\t\t\tENABLE_TESTABILITY = YES;")
        lines.append("\t\t\t\tGCC_DYNAMIC_NO_PIC = NO;")
        lines.append("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
        lines.append("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
        lines.append("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
        lines.append("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
        lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    else:
        lines.append("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
        lines.append("\t\t\t\tVALIDATE_PRODUCT = YES;")
        lines.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    lines.append("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
    lines.append("\t\t\t\tSDKROOT = iphoneos;")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tname = {name};")
    lines.append("\t\t};")

for cid, name in [(debug_target, "Debug"), (release_target, "Release")]:
    lines.append(f"\t\t{cid} /* {name} */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;")
    lines.append("\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;")
    lines.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    lines.append("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
    lines.append("\t\t\t\tDEVELOPMENT_TEAM = \"\";")
    lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    lines.append("\t\t\t\tINFOPLIST_FILE = SOC/Resources/Info.plist;")
    lines.append("\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = SOC;")
    lines.append("\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;")
    lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (")
    lines.append("\t\t\t\t\t\"$(inherited)\",")
    lines.append("\t\t\t\t\t\"@executable_path/Frameworks\",")
    lines.append("\t\t\t\t);")
    lines.append("\t\t\t\tMARKETING_VERSION = 1.0.0;")
    lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.eymenisin.soc;")
    lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    lines.append("\t\t\t\tSUPPORTED_PLATFORMS = \"iphoneos iphonesimulator\";")
    lines.append("\t\t\t\tSUPPORTS_MACCATALYST = NO;")
    lines.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    lines.append("\t\t\t\tSWIFT_VERSION = 5.0;")
    lines.append("\t\t\t\tTARGETED_DEVICE_FAMILY = 1;")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tname = {name};")
    lines.append("\t\t};")
lines.append("/* End XCBuildConfiguration section */")
lines.append("")

lines.append("/* Begin XCConfigurationList section */")
lines.append(f"\t\t{project_config_list} /* Build configuration list for PBXProject \"SOC\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{debug_project} /* Debug */,")
lines.append(f"\t\t\t\t{release_project} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append(f"\t\t{target_config_list} /* Build configuration list for PBXNativeTarget \"SOC\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{debug_target} /* Debug */,")
lines.append(f"\t\t\t\t{release_target} /* Release */,")
lines.append("\t\t\t);")
lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
lines.append("\t\t\tdefaultConfigurationName = Release;")
lines.append("\t\t};")
lines.append("/* End XCConfigurationList section */")
lines.append("")

lines.append("/* Begin XCRemoteSwiftPackageReference section */")
lines.append(f"\t\t{package_ref} /* XCRemoteSwiftPackageReference \"TeslaBLEKeyKit\" */ = {{")
lines.append("\t\t\tisa = XCRemoteSwiftPackageReference;")
lines.append("\t\t\trepositoryURL = \"https://github.com/misakatao/TeslaBLEKeyKit.git\";")
lines.append("\t\t\trequirement = {")
lines.append("\t\t\t\tkind = upToNextMajorVersion;")
lines.append("\t\t\t\tminimumVersion = 0.1.0;")
lines.append("\t\t\t};")
lines.append("\t\t};")
lines.append("/* End XCRemoteSwiftPackageReference section */")
lines.append("")

lines.append("/* Begin XCSwiftPackageProductDependency section */")
lines.append(f"\t\t{package_product} /* TeslaBLEKeyKit */ = {{")
lines.append("\t\t\tisa = XCSwiftPackageProductDependency;")
lines.append(f"\t\t\tpackage = {package_ref} /* XCRemoteSwiftPackageReference \"TeslaBLEKeyKit\" */;")
lines.append("\t\t\tproductName = TeslaBLEKeyKit;")
lines.append("\t\t};")
lines.append("/* End XCSwiftPackageProductDependency section */")
lines.append("\t};")
lines.append(f"\trootObject = {project_id} /* Project object */;")
lines.append("}")

PROJ.mkdir(exist_ok=True)
(PROJ / "project.pbxproj").write_text("\n".join(lines) + "\n", encoding="utf-8")
workspace = PROJ / "project.xcworkspace"
workspace.mkdir(exist_ok=True)
(workspace / "contents.xcworkspacedata").write_text(
    """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
""",
    encoding="utf-8",
)
print(f"Wrote {PROJ} with {len(SWIFT_FILES)} swift files")
