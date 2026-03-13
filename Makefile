TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

# MUST match TuffExec.plist filename exactly
TWEAK_NAME = TuffExec

TuffExec_FILES = TuffExec.x
TuffExec_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
TuffExec_LIBRARIES = dl
TuffExec_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 RobloxMobile" || true
