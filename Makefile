TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

# Matches TuffExec.plist exactly
TWEAK_NAME = TuffExec

$(TWEAK_NAME)_FILES = TuffExec.x
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
$(TWEAK_NAME)_LIBRARIES = dl substrate
# This tells the tweak to look for Substrate inside the app's Frameworks folder
$(TWEAK_NAME)_LDFLAGS += -Wl,-install_name,@executable_path/Frameworks/$(TWEAK_NAME).dylib
$(TWEAK_NAME)_LDFLAGS += -Wl,-change,/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate,@executable_path/Frameworks/libsubstrate.dylib
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
$(TWEAK_NAME)_LDFLAGS = -undefined dynamic_lookup


include $(THEOS_MAKE_PATH)/tweak.mk
