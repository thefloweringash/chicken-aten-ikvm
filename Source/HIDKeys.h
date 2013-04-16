#import <Foundation/Foundation.h>

#define kHIDKeys_LeftCtrl 0xe0
#define kHIDKeys_LeftShift 0xe1
#define kHIDKeys_LeftAlt 0xe2
#define kHIDKeys_LeftWin 0xe3
#define kHIDKeys_Caps 0x39
#define kHIDKeys_F1 0x3a

void HIDKeys_init();
uint8_t HIDKeys_usageForChar(unichar c);
