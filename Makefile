# Target architecture for modern iOS devices 
# Clang is used for the stealth syscall inline assembly [cite: 7]
TARGET := iphone:clang:latest:13.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = TuffExecPro

# Source files [cite: 1]
TuffExecPro_FILES = TuffExec.x
# Required for UI and RakNet implementation [cite: 16, 91, 104]
TuffExecPro_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
# Necessary for dynamic symbol resolution [cite: 1]
TuffExecPro_LIBRARIES = dl

# -fobjc-arc is required for the Objective-C classes used [cite: 11, 29, 91]
TuffExecPro_CFLAGS = -fobjc-arc -Wno-deprecated-declarations

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 RobloxMobile" || true
