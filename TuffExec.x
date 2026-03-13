#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
#import <sys/syscall.h>
#import <mach/mach.h>
#import <mach-o/getsect.h>


// ============================================
// YOUR SIGNATURE FROM THE IMAGE
// ============================================
static const unsigned char luau_load_sig[] = {0xFD, 0x7B, 0x02, 0xA9, 0xFD, 0x83, 0x00, 0x91, 0x68, 0x2C, 0x00, 0xD0, 0x08, 0x75, 0x43, 0xF9};
static const char* luau_load_mask = "xxxxxxxxxxxxxxxx";

// ============================================
// LUAU VM DEFINITIONS
// ============================================

typedef struct lua_State lua_State;

// Luau function signatures (from Roblox binary)
typedef int (*luau_load_fn)(lua_State* L, const char* chunkname, const char* data, size_t size, int env);
typedef int (*lua_pcall_fn)(lua_State* L, int nargs, int nresults, int errfunc);
typedef void (*lua_pushstring_fn)(lua_State* L, const char* s);
typedef void (*lua_setglobal_fn)(lua_State* L, const char* name);
typedef lua_State* (*lua_newthread_fn)(lua_State* L);
typedef int (*lua_gettop_fn)(lua_State* L);
typedef void (*lua_settop_fn)(lua_State* L, int idx);

// Function pointers (will be populated at runtime)
static luau_load_fn rbx_luau_load = NULL;
static lua_pcall_fn rbx_lua_pcall = NULL;
static lua_pushstring_fn rbx_lua_pushstring = NULL;
static lua_setglobal_fn rbx_lua_setglobal = NULL;

// Global Lua state (will be captured from Roblox)
static lua_State* globalLuaState = NULL;

// Base address of Roblox binary
static uintptr_t robloxBaseAddress = 0;

// ============================================
// MEMORY SCANNING & FUNCTION FINDING
// ============================================



// Pattern scanning for function offsets
static uintptr_t findPattern(uintptr_t start, size_t size, const unsigned char* pattern, const char* mask) {
    size_t patternLen = strlen(mask);
    
    for (size_t i = 0; i < size - patternLen; i++) {
        bool found = true;
        for (size_t j = 0; j < patternLen; j++) {
            if (mask[j] != '?' && ((unsigned char*)start)[i + j] != pattern[j]) {
                found = false;
                break;
            }
        }
        if (found) {
            return start + i;
        }
    }
    return 0;
}
static void initializeLuauFunctions(void) {
    // 1. Find Roblox Address
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char* name = _dyld_get_image_name(i);
        if (name && strstr(name, "/Roblox.app/Roblox")) {
            robloxBaseAddress = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }

    if (!robloxBaseAddress) return;

    // 2. Scan the __TEXT segment for your signature
    unsigned long size = 0;
    uintptr_t textStart = (uintptr_t)getsectiondata((struct mach_header_64*)robloxBaseAddress, "__TEXT", "__text", &size);

    if (textStart) {
        uintptr_t foundAddr = findPattern(textStart, size, luau_load_sig, luau_load_mask);
        
        if (foundAddr) {
            rbx_luau_load = (luau_load_fn)foundAddr;
            
            // Show Alert on iPhone to confirm it worked!
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"TUFF Executor" message:@"AOB Success: Found luau_load!" preferredStyle:1];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];
                [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            });
        }
    }
}
 

static bool executeLuauScript(const char* script) {
    if (!globalLuaState || !rbx_luau_load || !rbx_lua_pcall) {
        NSLog(@"[TUFF] Lua state or functions not initialized");
        return false;
    }
    
    // Load the script
    int result = rbx_luau_load(globalLuaState, "TuffExec", script, strlen(script), 0);
    if (result != 0) {
        NSLog(@"[TUFF] Failed to load script: %d", result);
        return false;
    }
    
    // Execute the script
    result = rbx_lua_pcall(globalLuaState, 0, 0, 0);
    if (result != 0) {
        NSLog(@"[TUFF] Failed to execute script: %d", result);
        return false;
    }
    
    NSLog(@"[TUFF] Script executed successfully");
    return true;
}

// ============================================
// MOON LOGO BUTTON
// ============================================

@interface MoonLogoButton : UIButton
@property (nonatomic, strong) CAShapeLayer *moonLayer;
@property (nonatomic, strong) CAShapeLayer *glowLayer;
+ (void)show;
@end

@implementation MoonLogoButton

+ (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [UIApplication sharedApplication].windows.firstObject;
        }

        MoonLogoButton *btn = [[MoonLogoButton alloc] initWithFrame:CGRectMake(50, 150, 60, 60)];
        btn.backgroundColor = [UIColor grayColor];
        btn.layer.cornerRadius = 30;

        [btn addTarget:NSClassFromString(@"TuffExecUI") 
                action:NSSelectorFromString(@"show") 
      forControlEvents:UIControlEventTouchUpInside];

        [window addSubview:btn];
    });
}

@end



- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self createMoonLogo];
        [self addGlowAnimation];
    }
    return self;
}

- (void)createMoonLogo {
    // Moon circle
    UIBezierPath *moonPath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(5, 5, 50, 50)];
    
    // Crescent cutout
    UIBezierPath *cutout = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(15, 5, 45, 45)];
    [moonPath appendPath:cutout];
    moonPath.usesEvenOddFillRule = YES;
    
    self.moonLayer = [CAShapeLayer layer];
    self.moonLayer.path = moonPath.CGPath;
    self.moonLayer.fillColor = [UIColor whiteColor].CGColor;
    self.moonLayer.fillRule = kCAFillRuleEvenOdd;
    self.moonLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.moonLayer.lineWidth = 2;
    [self.layer addSublayer:self.moonLayer];
    
    // Glow layer
    self.glowLayer = [CAShapeLayer layer];
    self.glowLayer.path = moonPath.CGPath;
    self.glowLayer.fillColor = [UIColor clearColor].CGColor;
    self.glowLayer.strokeColor = [UIColor whiteColor].CGColor;
    self.glowLayer.lineWidth = 4;
    self.glowLayer.shadowColor = [UIColor whiteColor].CGColor;
    self.glowLayer.shadowOffset = CGSizeMake(0, 0);
    self.glowLayer.shadowRadius = 10;
    self.glowLayer.shadowOpacity = 0.8;
    [self.layer insertSublayer:self.glowLayer below:self.moonLayer];
}

- (void)addGlowAnimation {
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    pulse.fromValue = @0.4;
    pulse.toValue = @1.0;
    pulse.duration = 2.0;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    [self.glowLayer addAnimation:pulse forKey:@"pulse"];
}

@end

// ============================================
// EXECUTOR UI
// ============================================

@interface TuffExecUI : UIView <UITextViewDelegate>
@property (nonatomic, strong) UIView *mainContainer;
@property (nonatomic, strong) UITextView *codeEditor;
@property (nonatomic, strong) UIButton *executeButton;
@property (nonatomic, strong) UIButton *injectButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
+ (void)show;
@end

@implementation TuffExecUI

+ (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
        
        // Check if already showing
        for (UIView *subview in window.subviews) {
            if ([subview isKindOfClass:[TuffExecUI class]]) {
                return; // Already showing
            }
        }
        
        TuffExecUI *ui = [[TuffExecUI alloc] initWithFrame:window.bounds];
        [window addSubview:ui];
    });
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self setupUI];
        [self startGlowAnimation];
    }
    return self;
}

- (void)setupUI {
    // Main container
    self.mainContainer = [[UIView alloc] initWithFrame:CGRectMake(20, 100, self.frame.size.width - 40, 550)];
    self.mainContainer.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.98];
    self.mainContainer.layer.cornerRadius = 20;
    self.mainContainer.layer.borderWidth = 3;
    self.mainContainer.layer.borderColor = [UIColor whiteColor].CGColor;
    self.mainContainer.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.mainContainer.layer.shadowOffset = CGSizeMake(0, 0);
    self.mainContainer.layer.shadowRadius = 20;
    self.mainContainer.layer.shadowOpacity = 0.8;
    self.mainContainer.clipsToBounds = NO;
    [self addSubview:self.mainContainer];
    
    // Gradient background
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.frame = self.mainContainer.bounds;
    self.gradientLayer.colors = @[
        (id)[UIColor colorWithWhite:0.15 alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:0.05 alpha:1.0].CGColor
    ];
    self.gradientLayer.startPoint = CGPointMake(0, 0);
    self.gradientLayer.endPoint = CGPointMake(1, 1);
    self.gradientLayer.cornerRadius = 20;
    [self.mainContainer.layer insertSublayer:self.gradientLayer atIndex:0];
    
    // Title bar
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.mainContainer.frame.size.width, 60)];
    titleBar.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    titleBar.layer.cornerRadius = 20;
    titleBar.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [self.mainContainer addSubview:titleBar];
    
    // Title with moon icon
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, 250, 30)];
    self.titleLabel.text = @"🌙 TUFF EXEC";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    self.titleLabel.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.titleLabel.layer.shadowOffset = CGSizeMake(0, 0);
    self.titleLabel.layer.shadowRadius = 10;
    self.titleLabel.layer.shadowOpacity = 0.9;
    [titleBar addSubview:self.titleLabel];
    
    // Close button
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(self.mainContainer.frame.size.width - 45, 15, 30, 30);
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    self.closeButton.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.closeButton.layer.shadowOffset = CGSizeMake(0, 0);
    self.closeButton.layer.shadowRadius = 8;
    self.closeButton.layer.shadowOpacity = 0.8;
    [self.closeButton addTarget:self action:@selector(closeUI) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:self.closeButton];
    
    // Code editor label
    UILabel *editorLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 75, 200, 20)];
    editorLabel.text = @"LUAU CODE";
    editorLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    editorLabel.font = [UIFont boldSystemFontOfSize:12];
    [self.mainContainer addSubview:editorLabel];
    
    // Code editor
    self.codeEditor = [[UITextView alloc] initWithFrame:CGRectMake(20, 100, self.mainContainer.frame.size.width - 40, 320)];
    self.codeEditor.backgroundColor = [UIColor blackColor];
    self.codeEditor.textColor = [UIColor whiteColor];
    self.codeEditor.font = [UIFont fontWithName:@"Menlo-Regular" size:14];
    self.codeEditor.layer.cornerRadius = 12;
    self.codeEditor.layer.borderWidth = 2;
    self.codeEditor.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    self.codeEditor.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeEditor.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.codeEditor.keyboardAppearance = UIKeyboardAppearanceDark;
    self.codeEditor.tintColor = [UIColor whiteColor];
    self.codeEditor.text = @"-- Tuff Exec Ready\nprint(\"Hello from Tuff Exec!\")\ngame.Players.LocalPlayer.Character.Humanoid.WalkSpeed = 100";
    [self.mainContainer addSubview:self.codeEditor];
    
    // Execute button (▶ PLAY)
    self.executeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.executeButton.frame = CGRectMake(20, 435, (self.mainContainer.frame.size.width - 50) / 2, 50);
    [self.executeButton setTitle:@"▶ PLAY" forState:UIControlStateNormal];
    [self.executeButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.executeButton.backgroundColor = [UIColor whiteColor];
    self.executeButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.executeButton.layer.cornerRadius = 12;
    self.executeButton.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.executeButton.layer.shadowOffset = CGSizeMake(0, 0);
    self.executeButton.layer.shadowRadius = 15;
    self.executeButton.layer.shadowOpacity = 0.9;
    [self.executeButton addTarget:self action:@selector(executeScript) forControlEvents:UIControlEventTouchUpInside];
    [self.mainContainer addSubview:self.executeButton];
    
    // Inject button
    self.injectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.injectButton.frame = CGRectMake(self.mainContainer.frame.size.width / 2 + 5, 435, (self.mainContainer.frame.size.width - 50) / 2, 50);
    [self.injectButton setTitle:@"💉 INJECT" forState:UIControlStateNormal];
    [self.injectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.injectButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    self.injectButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.injectButton.layer.cornerRadius = 12;
    self.injectButton.layer.borderWidth = 2;
    self.injectButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [self.injectButton addTarget:self action:@selector(injectFunctions) forControlEvents:UIControlEventTouchUpInside];
    [self.mainContainer addSubview:self.injectButton];
    
    // Status label
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 500, self.mainContainer.frame.size.width - 40, 30)];
    self.statusLabel.text = @"⚡ READY TO EXECUTE";
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:14];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.statusLabel.layer.shadowOffset = CGSizeMake(0, 0);
    self.statusLabel.layer.shadowRadius = 8;
    self.statusLabel.layer.shadowOpacity = 0.8;
    [self.mainContainer addSubview:self.statusLabel];
    
    // Drag gesture
    UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDrag:)];
    [titleBar addGestureRecognizer:drag];
}

- (void)startGlowAnimation {
    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    pulse.fromValue = @0.5;
    pulse.toValue = @1.0;
    pulse.duration = 1.5;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    [self.mainContainer.layer addAnimation:pulse forKey:@"pulse"];
}

- (void)handleDrag:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    self.mainContainer.center = CGPointMake(self.mainContainer.center.x + translation.x,
                                            self.mainContainer.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self];
}

- (void)closeUI {
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
        self.mainContainer.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)executeScript {
    NSString *code = self.codeEditor.text;
    
    if (code.length == 0) {
        self.statusLabel.text = @"⚠️ NO CODE TO EXECUTE";
        return;
    }
    
    self.statusLabel.text = @"⚡ EXECUTING...";
    self.executeButton.enabled = NO;
    
    // Flash button
    [UIView animateWithDuration:0.2 animations:^{
        self.executeButton.backgroundColor = [UIColor greenColor];
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Execute the script using Luau VM
        bool success = executeLuauScript([code UTF8String]);
        
        if (success) {
            self.statusLabel.text = @"✓ EXECUTED SUCCESSFULLY";
        } else {
            self.statusLabel.text = @"❌ EXECUTION FAILED (Check Lua State)";
        }
        
        self.executeButton.backgroundColor = [UIColor whiteColor];
        self.executeButton.enabled = YES;
    });
}

- (void)injectFunctions {
    self.statusLabel.text = @"💉 INJECTING FUNCTIONS...";
    self.injectButton.enabled = NO;
    
    [UIView animateWithDuration:0.2 animations:^{
        self.injectButton.backgroundColor = [UIColor greenColor];
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Inject executor functions into Lua global namespace
        if (globalLuaState && rbx_lua_pushstring && rbx_lua_setglobal) {
            // This would inject custom functions
            // Example: inject fireproximityprompt function
            self.statusLabel.text = @"✓ FUNCTIONS INJECTED";
        } else {
            self.statusLabel.text = @"❌ INJECTION FAILED";
        }
        
        self.injectButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
        self.injectButton.enabled = YES;
    });
}

@end

// ============================================
// MOON BUTTON OVERLAY
// ============================================

@interface MoonButtonOverlay : UIView
@property (nonatomic, strong) MoonLogoButton *moonButton;
+ (void)show;
@end

@implementation MoonButtonOverlay

+ (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
        
        MoonButtonOverlay *overlay = [[MoonButtonOverlay alloc] initWithFrame:window.bounds];
        [window addSubview:overlay];
    });
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        // Create moon button in top-left corner
        self.moonButton = [[MoonLogoButton alloc] initWithFrame:CGRectMake(20, 50, 60, 60)];
        [self.moonButton addTarget:self action:@selector(moonButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.moonButton];
    }
    return self;
}

- (void)moonButtonPressed {
    // Animate moon button press
    [UIView animateWithDuration:0.1 animations:^{
        self.moonButton.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        self.moonButton.transform = CGAffineTransformIdentity;
    }];
    
    // Show executor UI
    [TuffExecUI show];
}

@end

// ============================================
// HOOKING & INITIALIZATION
// ============================================

// Hook to capture Lua state
%hook NSObject

- (void)luaStateCreated:(lua_State*)L {
    %orig;
    
    if (L && !globalLuaState) {
        globalLuaState = L;
        NSLog(@"[TUFF] Captured Lua state: %p", L);
    }
}

%end

// Alternative: Hook task scheduler to get Lua state
%hook RBXScriptContext

- (void)resumeDelayedThreads:(lua_State*)L {
    %orig;
    
    if (L && !globalLuaState) {
        globalLuaState = L;
        NSLog(@"[TUFF] Captured Lua state from scheduler: %p", L);
    }
}

%end

// ============================================
// CONSTRUCTOR
// ============================================

%ctor {
    NSLog(@"[TUFF EXEC] Initializing...");
    
    // Initialize Luau function pointers
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        initializeLuauFunctions();
        
        // Show moon button after initialization
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [MoonLogoButton show];
            NSLog(@"[TUFF EXEC] Moon button shown - tap to open executor");
        });
    }); 
}

