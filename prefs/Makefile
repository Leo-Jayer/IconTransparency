ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
    ARCHS = arm64e
    _LOCAL_USE_MODULES = 1
    ADDITIONAL_LDFLAGS = -lroothide
endif

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = IconTransparencyPrefs
IconTransparencyPrefs_FILES = IconTransparencyPrefs.mm ITSliderCell.mm
IconTransparencyPrefs_INSTALL_PATH = /Library/PreferenceBundles
IconTransparencyPrefs_FRAMEWORKS = UIKit
IconTransparencyPrefs_PRIVATE_FRAMEWORKS = Preferences
IconTransparencyPrefs_CFLAGS = -fobjc-arc -fmodules -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/bundle.mk
