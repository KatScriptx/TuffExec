#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>

// ============================================
// iOS ROBLOX OFFSET DUMPER
// ============================================
// Scans Roblox binary for Lua VM functions
// Copies results to clipboard automatically!
// ============================================

@interface OffsetDumper : NSObject
+ (void)dumpOffsets;
@end

@implementation OffsetDumper

+ (uintptr_t)findRobloxBase {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "RobloxPlayer")) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

+ (NSArray*)scanForFunctionStarts:(uintptr_t)baseAddr {
    NSMutableArray *functions = [NSMutableArray array];
    
    // Scan from 0x0 to 0x2000000 (32MB range)
    // Looking for ARM64 function prologues
    for (uintptr_t offset = 0; offset < 0x2000000; offset += 4) {
        uintptr_t addr = baseAddr + offset;
        uint32_t *instruction = (uint32_t*)addr;
        
        // Check for common function starts
        // FD 7B ?? A9 = stp x29, x30, [sp, #??]
        if ((*instruction & 0xFFC003FF) == 0xA9007BFD) {
            [functions addObject:@{
                @"offset": [NSString stringWithFormat:@"0x%08lX", offset],
                @"address": [NSString stringWithFormat:@"0x%016lX", addr],
                @"bytes": [NSString stringWithFormat:@"%08X", *instruction]
            }];
        }
    }
    
    return functions;
}

+ (NSString*)searchForString:(uintptr_t)baseAddr pattern:(NSString*)searchStr {
    const char* search = [searchStr UTF8String];
    size_t searchLen = strlen(search);
    
    // Search in data section (usually 0x3000000 - 0x5000000)
    for (uintptr_t offset = 0x3000000; offset < 0x5000000; offset++) {
        uintptr_t addr = baseAddr + offset;
        if (memcmp((void*)addr, search, searchLen) == 0) {
            return [NSString stringWithFormat:@"0x%08lX", offset];
        }
    }
    
    return @"NOT FOUND";
}

+ (void)dumpOffsets {
    NSLog(@"[OFFSET DUMPER] Starting scan...");
    
    uintptr_t base = [self findRobloxBase];
    if (!base) {
        NSLog(@"[OFFSET DUMPER] Failed to find Roblox base!");
        return;
    }
    
    NSLog(@"[OFFSET DUMPER] Roblox base: 0x%lx", base);
    
    // Results string
    NSMutableString *results = [NSMutableString string];
    [results appendFormat:@"=== ROBLOX iOS OFFSET DUMP ===\n"];
    [results appendFormat:@"Base Address: 0x%016lX\n", base];
    [results appendFormat:@"Date: %@\n\n", [NSDate date]];
    
    // Search for key strings
    [results appendString:@"=== STRING LOCATIONS ===\n"];
    
    NSArray *searchStrings = @[
        @"luau_load",
        @"lua_pcall",
        @"lua_pushstring",
        @"lua_setglobal",
        @"lua_newthread",
        @"lua_gettop",
        @"lua_settop",
        @"bad binary signature",
        @"truncated bytecode",
        @"invalid bytecode",
        @"RBLuaStartupManager"
    ];
    
    for (NSString *str in searchStrings) {
        NSString *offset = [self searchForString:base pattern:str];
        [results appendFormat:@"\"%@\": %@\n", str, offset];
    }
    
    [results appendString:@"\n=== FUNCTION CANDIDATES ===\n"];
    [results appendString:@"(First 50 ARM64 function prologues)\n\n"];
    
    NSArray *functions = [self scanForFunctionStarts:base];
    
    for (int i = 0; i < MIN(50, functions.count); i++) {
        NSDictionary *func = functions[i];
        [results appendFormat:@"Function #%d: Offset %@, Address %@, Bytes %@\n",
            i + 1,
            func[@"offset"],
            func[@"address"],
            func[@"bytes"]];
    }
    
    [results appendString:@"\n=== YOUR 10 CANDIDATES ===\n"];
    [results appendString:@"0000E3B0\n"];
    [results appendString:@"0000E420\n"];
    [results appendString:@"0000E590\n"];
    [results appendString:@"0000E5A8\n"];
    [results appendString:@"0000E5F8\n"];
    [results appendString:@"0000E710\n"];
    [results appendString:@"0000E7C0\n"];
    [results appendString:@"0000E928\n"];
    [results appendString:@"0000E950\n"];
    
    [results appendString:@"\n=== USAGE ===\n"];
    [results appendString:@"#define LUAU_LOAD_OFFSET 0x????????\n"];
    [results appendString:@"#define LUA_PCALL_OFFSET 0x????????\n"];
    [results appendString:@"\nrbx_luau_load = (luau_load_fn)(base + LUAU_LOAD_OFFSET);\n"];
    
    NSLog(@"[OFFSET DUMPER] Scan complete! Results:\n%@", results);
    
    // Copy to clipboard!
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = results;
    
    NSLog(@"[OFFSET DUMPER] ✅ Results copied to clipboard!");
    
    // Show alert
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"Offset Dump Complete!" 
            message:@"Results copied to clipboard!\n\nPaste into Notes app to view." 
            preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction 
            actionWithTitle:@"OK" 
            style:UIAlertActionStyleDefault 
            handler:nil]];
        
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

@end

// ============================================
// HOOK TO AUTO-RUN ON ROBLOX LAUNCH
// ============================================

%hook RBXAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    // Run offset dumper after 5 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [OffsetDumper dumpOffsets];
    });
    
    return result;
}

%end

%ctor {
    NSLog(@"[OFFSET DUMPER] Loaded! Will dump offsets 5s after Roblox launches.");
}
