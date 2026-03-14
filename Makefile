TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TuffExec

$(TWEAK_NAME)_FILES = TuffExec.x
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
$(TWEAK_NAME)_LIBRARIES = dl substrate

$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function

# CORRECTED LINKER FLAGS - No spaces after commas!
$(TWEAK_NAME)_LDFLAGS += -undefined dynamic_lookup
$(TWEAK_NAME)_LDFLAGS += -Wl,-install_name,@executable_path/Frameworks/$(TWEAK_NAME).dylib
$(TWEAK_NAME)_LDFLAGS += -Wl,-rpath,@executable_path/Frameworks/
$(TWEAK_NAME)_LDFLAGS += -Wl,-change,/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate,@executable_path/Frameworks/libsubstrate.dylib

include $(THEOS_MAKE_PATH)/tweak.mk
