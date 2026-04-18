ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:13.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = OffsetDumper

OffsetDumper_FILES = OffsetDumper.x
OffsetDumper_CFLAGS = -fobjc-arc -Wno-unused-variable
OffsetDumper_FRAMEWORKS = UIKit Foundation
OffsetDumper_LIBRARIES = substrate
OffsetDumper_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/library.mk

after-build::
	@echo "✓ OffsetDumper.dylib built"
	@cp $(THEOS_OBJ_DIR)/OffsetDumper.dylib ./

after-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries
	@cp $(THEOS_OBJ_DIR)/OffsetDumper.dylib $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/
	@cp OffsetDumper.plist $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/
