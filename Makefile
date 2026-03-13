TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e
TuffExec_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore


include $(THEOS)/makefiles/common.mk

# Updated to match your "Name" and Package info
TWEAK_NAME = TuffExec

$(TWEAK_NAME)_FILES = TuffExec.x
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
$(TWEAK_NAME)_LIBRARIES = dl
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk
