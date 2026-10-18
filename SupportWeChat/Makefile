TARGET := iphone:clang:16.5:15.0
# App Store WeChat and the supplied WCRefine reference use the arm64 ABI.
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ShortLookSupportWeChat
ShortLookSupportWeChat_FILES = Bridge.m SLWeChatSupportController.m
ShortLookSupportWeChat_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter
ShortLookSupportWeChat_FRAMEWORKS = UIKit Foundation
ShortLookSupportWeChat_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
