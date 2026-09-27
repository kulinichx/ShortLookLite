TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ShortLookLitePrefs
ShortLookLitePrefs_FILES = SLLRootListController.m
ShortLookLitePrefs_FRAMEWORKS = UIKit
ShortLookLitePrefs_PRIVATE_FRAMEWORKS = Preferences
ShortLookLitePrefs_INSTALL_PATH = /Library/PreferenceBundles
ShortLookLitePrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ShortLookLitePrefs.plist$(ECHO_END)
