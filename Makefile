ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
    TARGET = iphone:clang:16.2:15.0
    ARCHS = arm64e
    THEOS_PACKAGE_INSTALL_PREFIX = /var/jb
    _LOCAL_USE_MODULES = 1
    ADDITIONAL_LDFLAGS = -lroothide
else
    TARGET = iphone:clang:16.2:15.0
    ARCHS = arm64e
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IconTransparency
IconTransparency_FILES = Tweak.x
IconTransparency_CFLAGS = -fobjc-arc -fmodules -Wno-deprecated-declarations
IconTransparency_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
