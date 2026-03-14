TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TuffExec

$(TWEAK_NAME)_FILES = TuffExec.x
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
$(TWEAK_NAME)_LIBRARIES = dl substrate

$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function

# FIXED FOR MODERN LINKERS: Use -Xlinker to pass flags correctly
$(TWEAK_NAME)_LDFLAGS += -undefined dynamic_lookup
$(TWEAK_NAME)_LDFLAGS += -Xlinker -install_name -Xlinker @executable_path/Frameworks/$(TWEAK_NAME).dylib
$(TWEAK_NAME)_LDFLAGS += -Xlinker -rpath -Xlinker @executable_path/Frameworks/
$(TWEAK_NAME)_LDFLAGS += -Xlinker -change -Xlinker /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate -Xlinker @executable_path/Frameworks/libsubstrate.dylib

include $(THEOS_MAKE_PATH)/tweak.mk
