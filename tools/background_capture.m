#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <stdio.h>

// Capture-only process guard. Keep Godot's normal window out of the desktop;
// its registered SubViewport remains the only rendered output.
static IMP original_policy;
static IMP original_order;

static BOOL background_policy(id app, SEL selector, NSApplicationActivationPolicy policy) {
    return ((BOOL (*)(id, SEL, NSApplicationActivationPolicy))original_policy)(
        app, selector, NSApplicationActivationPolicyProhibited);
}

static void ignore_activation(id app, SEL selector, BOOL ignoring) {}

static void background_order(id window, SEL selector, NSWindowOrderingMode mode, NSInteger relative) {
    ((void (*)(id, SEL, NSWindowOrderingMode, NSInteger))original_order)(
        window, selector, NSWindowOut, relative);
}

__attribute__((constructor)) static void install_background_guard(void) {
    Method policy = class_getInstanceMethod([NSApplication class], @selector(setActivationPolicy:));
    original_policy = method_setImplementation(policy, (IMP)background_policy);
    Method activation = class_getInstanceMethod([NSApplication class], @selector(activateIgnoringOtherApps:));
    method_setImplementation(activation, (IMP)ignore_activation);
    Method order = class_getInstanceMethod([NSWindow class], @selector(orderWindow:relativeTo:));
    original_order = method_setImplementation(order, (IMP)background_order);
    fprintf(stderr, "BACKGROUND GUARD: activation prohibited; native windows suppressed\n");
}
