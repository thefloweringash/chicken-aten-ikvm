#import <Cocoa/Cocoa.h>
#import "HIDKeys.h"

static struct keymap_t {
    unichar unichar;
    uint8_t hid;
} keymap[] = {
    { 'a', 0x04 },
    { 'b', 0x05 },
    { 'c', 0x06 },
    { 'd', 0x07 },
    { 'e', 0x08 },
    { 'f', 0x09 },
    { 'g', 0x0a },
    { 'h', 0x0b },
    { 'i', 0x0c },
    { 'j', 0x0d },
    { 'k', 0x0e },
    { 'l', 0x0f },
    { 'm', 0x10 },
    { 'n', 0x11 },
    { 'o', 0x12 },
    { 'p', 0x13 },
    { 'q', 0x14 },
    { 'r', 0x15 },
    { 's', 0x16 },
    { 't', 0x17 },
    { 'u', 0x18 },
    { 'v', 0x19 },
    { 'w', 0x1a },
    { 'x', 0x1b },
    { 'y', 0x1c },
    { 'z', 0x1d },
    { '1', 0x1e },
    { '2', 0x1f },
    { '3', 0x20 },
    { '4', 0x21 },
    { '5', 0x22 },
    { '6', 0x23 },
    { '7', 0x24 },
    { '8', 0x25 },
    { '9', 0x26 },
    { '0', 0x27 },

    { '\r', 0x28 },
    { '\033', 0x29 },
    { '\x7f', 0x2a },
    { '\t', 0x2b },
    { ' ', 0x2c },
    { '-', 0x2d },
    { '=', 0x2e },
    { '[', 0x2f },
    { ']', 0x30 },
    { '\\', 0x31 },
    { ';', 0x33 },
    { '\'', 0x34 },
    { '`', 0x35 },
    { ',', 0x36 },
    { '.', 0x37 },
    { '/', 0x38 },

    // this is a bit ugly. We have the result of os x applying our local keyboard layout,
    // and we only have to combined key. We undo this mapping by picking an arbitrary layout that
    // might have resulted in the input we see
    { '<', 0x36 }, // ,
    { '>', 0x37 }, // .
    { '!', 0x1e }, // 1
    { '@', 0x1f }, // 2
    { '#', 0x20 }, // 3
    { '$', 0x21 }, // 4
    { '%', 0x22 }, // 5
    { '^', 0x23 }, // 6
    { '&', 0x24 }, // 7
    { '*', 0x25 }, // 8
    { '(', 0x26 }, // 9
    { ')', 0x27 }, // 0
    { '_', 0x2d }, // -
    { '|', 0x31 }, // backslash
    { '"', 0x34 }, // '
    { '~', 0x35 }, // `

    // and the alphabet
    { 'A', 0x04 },
    { 'B', 0x05 },
    { 'C', 0x06 },
    { 'D', 0x07 },
    { 'E', 0x08 },
    { 'F', 0x09 },
    { 'G', 0x0A },
    { 'H', 0x0B },
    { 'I', 0x0C },
    { 'J', 0x0D },
    { 'K', 0x0E },
    { 'L', 0x0F },
    { 'M', 0x10 },
    { 'N', 0x11 },
    { 'O', 0x12 },
    { 'P', 0x13 },
    { 'Q', 0x14 },
    { 'R', 0x15 },
    { 'S', 0x16 },
    { 'T', 0x17 },
    { 'U', 0x18 },
    { 'V', 0x19 },
    { 'W', 0x1A },
    { 'X', 0x1B },
    { 'Y', 0x1C },
    { 'Z', 0x1D },

    {NSF1FunctionKey, 0x3a},
    {NSF2FunctionKey, 0x3b},
    {NSF3FunctionKey, 0x3c},
    {NSF4FunctionKey, 0x3d},
    {NSF5FunctionKey, 0x3e},
    {NSF6FunctionKey, 0x3f},
    {NSF7FunctionKey, 0x40},
    {NSF8FunctionKey, 0x41},
    {NSF9FunctionKey, 0x42},
    {NSF10FunctionKey, 0x43},
    {NSF11FunctionKey, 0x44},
    {NSF12FunctionKey, 0x45},

    {NSPrintScreenFunctionKey, 0x46},
    {NSScrollLockFunctionKey, 0x47},
    {NSPauseFunctionKey, 0x48},
    {NSInsertFunctionKey, 0x49},
    {NSHomeFunctionKey, 0x4a},
    {NSPageUpFunctionKey, 0x4b},
    {NSDeleteFunctionKey, 0x4c},
    {NSEndFunctionKey, 0x4d},
    {NSPageDownFunctionKey, 0x4e},
    {NSRightArrowFunctionKey, 0x4f},
    {NSLeftArrowFunctionKey, 0x50},
    {NSDownArrowFunctionKey, 0x51},
    {NSUpArrowFunctionKey, 0x52},
};

static int compare_unichar(const void *lv, const void *rv) {
    const struct keymap_t *left = (const struct keymap_t*) lv;
    const struct keymap_t *right = (const struct keymap_t*) rv;
    return left->unichar - right->unichar;
}

void HIDKeys_init() {
    qsort(&keymap[0], sizeof(keymap) / sizeof(*keymap), sizeof(*keymap),
          compare_unichar);
}

uint8_t HIDKeys_usageForChar(unichar c) {
    const struct keymap_t *mapping =
    bsearch(&c, &keymap[0], sizeof(keymap) / sizeof(*keymap), sizeof(*keymap),
            compare_unichar);
    if (mapping) {
        return mapping->hid;
    }
    else {
        return 0;
    }
}

