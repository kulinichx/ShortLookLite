TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

SUBPROJECTS = Tweak IMD FloraSettings ShortLookSettings Plugins/ShortLook-WeChat Plugins/ShortLook-QQ

include $(THEOS_MAKE_PATH)/aggregate.mk
