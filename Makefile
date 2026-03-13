# Target and Architectures
TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

# TWEAK_NAME must match your TuffExec.plist filename exactly
TWEAK_NAME = TuffExec

$(TWEAK_NAME)_FILES = TuffExec.x
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
$(TWEAK_NAME)_LIBRARIES = dl
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk

# Removed after-install because GitHub Actions only handles the build
