TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ShortLook-Telegram

ShortLook-Telegram_FILES = TelegramContactPhotoProvider.m TGSFolderFinder.m TGSInitialsPictureGenerator.m
ShortLook-Telegram_CFLAGS = -fobjc-arc -I../Common
ShortLook-Telegram_FRAMEWORKS = Foundation UIKit CoreGraphics
ShortLook-Telegram_LIBRARIES = sqlite3
ShortLook-Telegram_INSTALL_PATH = /Library/Dynastic/ShortLook/Plugins/ContactPhotoProviders

include $(THEOS_MAKE_PATH)/bundle.mk
