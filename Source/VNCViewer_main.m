#import <AppKit/AppKit.h>

#ifdef DEBUG_MEMORY
#import <Foundation/NSDebug.h>
#endif

int main(int argc, const char *argv[]) {
#ifdef DEBUG_MEMORY
    NSZombieEnabled = YES;
#endif
    return NSApplicationMain(argc, argv);
}
