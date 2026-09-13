ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
    TARGET = iphone:clang:16.2:15.0
    ARCHS = arm64e arm64
else
    TARGET = iphone:clang:16.2:14.0
    ARCHS = arm64e arm64
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IconTransparency
IconTransparency_FILES = Tweak.x
IconTransparency_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
IconTransparency_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
