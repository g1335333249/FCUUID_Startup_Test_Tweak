TARGET := iphone:clang:latest:15.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FCUUIDStartupTest
FCUUIDStartupTest_FILES = Tweak.xm
FCUUIDStartupTest_CFLAGS = -fobjc-arc
FCUUIDStartupTest_FRAMEWORKS = Foundation UIKit Security

include $(THEOS_MAKE_PATH)/tweak.mk
