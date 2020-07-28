#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/NSObjCRuntime.h>
#import <Cocoa/Cocoa.h>
#import <libproc.h>

#define RequiredEvent 29
#define RequiredProcName "Google Chrome"
#define RequiredProcNameXcode "Xcode"
// #define RequiredProcNameXcode "Karabiner-EventViewer"

bool needIgnoreNextLeftMouseUp = false;



CGEventRef myCGEventCallback(CGEventTapProxy proxy,
                             CGEventType type,
                             CGEventRef eventRef,
                             void *refcon)
{
@autoreleasepool {

    if(needIgnoreNextLeftMouseUp &&
       (type == kCGEventLeftMouseUp || type == kCGEventLeftMouseDown)){
        return (NULL);
    }
    
    if ((type != RequiredEvent)){
        return eventRef;
    }


    
    NSEvent *event = [NSEvent eventWithCGEvent:eventRef];

    
    if(needIgnoreNextLeftMouseUp && event.stage != 0){
        return (NULL);
    }
    
    if(needIgnoreNextLeftMouseUp){
        needIgnoreNextLeftMouseUp = false;
        return (NULL);
    }
    
    
    char ProcName[PROC_PIDPATHINFO_MAXSIZE];
    if (!proc_name((pid_t)CGEventGetIntegerValueField(eventRef, kCGEventTargetUnixProcessID), ProcName, sizeof(ProcName))){
        return eventRef;
    }
    
    NSString *Target = [NSString stringWithUTF8String: ProcName];
    
    if (![Target isEqualToString: @RequiredProcName] && ![Target isEqualToString: @RequiredProcNameXcode]){
        return eventRef;
    }
    
    if (event.type == NSEventTypePressure && event.stage == 2){
        
        if(event.pressure > 0.000){
            return (NULL);
        }
        

        NSLog(@"Target %@", Target);
        NSLog(@"Deep click");

        if ([Target isEqualToString: @RequiredProcNameXcode]) {
            CGEventSourceRef src = 
                CGEventSourceCreate(kCGEventSourceStateHIDSystemState);

            CGEventRef ctrld = CGEventCreateKeyboardEvent(src, 0x3B, true);
            CGEventRef ctrlu = CGEventCreateKeyboardEvent(src, 0x3B, false);
            CGEventRef cmdd = CGEventCreateKeyboardEvent(src, 0x37, true);
            CGEventRef cmdu = CGEventCreateKeyboardEvent(src, 0x37, false);
            CGEventRef spcd = CGEventCreateKeyboardEvent(src, 0x26, true); //j
            CGEventRef spcu = CGEventCreateKeyboardEvent(src, 0x26, false);

            CGEventSetFlags(spcd, kCGEventFlagMaskCommand | kCGEventFlagMaskControl);
            CGEventSetFlags(spcu, kCGEventFlagMaskCommand | kCGEventFlagMaskControl);
            // CGEventSetFlags(spcd, kCGEventFlagMaskControl);
            // CGEventSetFlags(spcu, kCGEventFlagMaskControl);

            CGEventTapLocation loc = kCGHIDEventTap; // kCGSessionEventTap also works
            CGEventPost(loc, ctrld);
            CGEventPost(loc, cmdd);
            CGEventPost(loc, spcd);
            CGEventPost(loc, spcu);
            CGEventPost(loc, cmdu);
            CGEventPost(loc, ctrlu);

            CFRelease(ctrld);
            CFRelease(ctrlu);
            CFRelease(cmdd);
            CFRelease(cmdu);
            CFRelease(spcd);
            CFRelease(spcu);
            CFRelease(src);  
            return (NULL);
        } else {
            CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);

            CGPoint mouse_pos = CGEventGetLocation(eventRef);
            
            CGEventRef click_down = CGEventCreateMouseEvent(
                                                            src, kCGEventLeftMouseDown,
                                                            mouse_pos,
                                                            kCGMouseButtonLeft
                                                            );
            
            CGEventRef click_up = CGEventCreateMouseEvent(
                                                        src, kCGEventLeftMouseUp,
                                                        mouse_pos,
                                                        kCGMouseButtonLeft
                                                        );
            

            
            CGEventSetFlags(click_down, kCGEventFlagMaskCommand);
            CGEventSetFlags(click_up, kCGEventFlagMaskCommand);

            CGEventPost(kCGHIDEventTap, click_down);
            
            needIgnoreNextLeftMouseUp = true;

            CFRelease(src);
            CFRelease(click_down);


            return click_up;
        }
    }
    
    return eventRef;
}
}

int main(void)
{
    CFMachPortRef      eventTap;
    CGEventMask        eventMask;
    CFRunLoopSourceRef runLoopSource;
    
    eventMask = ((1 << RequiredEvent) | (1 << kCGEventLeftMouseUp) | (1 << kCGEventLeftMouseDown));
    eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0,
                                eventMask, myCGEventCallback, NULL);
    if (!eventTap) {
        fprintf(stderr, "failed to create event tap\n");
        exit(1);
    }
    

    runLoopSource = CFMachPortCreateRunLoopSource(
                                                  kCFAllocatorDefault, eventTap, 0);
    

    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource,
                       kCFRunLoopCommonModes);
    
    CGEventTapEnable(eventTap, true);
    
    NSLog(@"Start handling deep clicks in " RequiredProcName);
    
    CFRunLoopRun();
    
    exit(0);
}
