#import <AppKit/AppKit.h>

//#define DEBUG_MEMORY 1

#ifdef DEBUG_MEMORY
#import <Foundation/NSDebug.h>
#endif

int main(int argc, const char *argv[]) {
#ifdef DEBUG_MEMORY
    NSZombieEnabled = YES;
    NSDebugEnabled = YES;
    NSDeallocateZombies = NO;
	[NSAutoreleasePool setPoolCountHighWaterMark: 2000];
	[NSAutoreleasePool setPoolCountHighWaterResolution: 2000];
#endif
    return NSApplicationMain(argc, argv);
}
