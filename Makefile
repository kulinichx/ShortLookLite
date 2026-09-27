# ShortLook Lite — iOS 16 / RootHide（多巴胺隐根）
TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ShortLookLite
ShortLookLite_FILES = Tweak.x $(wildcard Sources/*.m)
ShortLookLite_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function
ShortLookLite_FRAMEWORKS = UIKit Foundation Contacts QuartzCore
ShortLookLite_LIBRARIES = sqlite3

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += Prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
