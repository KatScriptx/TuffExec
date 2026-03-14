TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TuffExec

$(TWEAK_NAME)_FILES = TuffExec.x
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
$(TWEAK_NAME)_LIBRARIES = dl substrate
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable


# Simplify LDFLAGS to stop the 'unknown option' error
$(TWEAK_NAME)_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk

# THIS IS THE NUCLEAR FIX: It runs 'install_name_tool' automatically after the build finishes
after-all::
	@echo "Fixing library paths..."
	@install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @executable_path/Frameworks/libsubstrate.dylib $(THEOS_OBJ_DIR)/$(TWEAK_NAME).dylib
