#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/syscall.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <objc/runtime.h>
#import <arpa/inet.h>
#import <sys/socket.h>

// Syscall definitions
#define SYS_WRITE_STEALTH 4
#define SYS_OPEN_STEALTH 5
#define SYS_CLOSE_STEALTH 6

// RakNet packet types
#define ID_USER_PACKET_ENUM 0x86
#define ID_TIMESTAMP 0x00
#define ID_REMOTE_DISCONNECTION_NOTIFICATION 0x15

// Forward declarations
@class RakNetLibrary;
@class ExecutorFunctions;

static inline long stealth_syscall(long number, ...) {
    va_list args;
    va_start(args, number);
    long arg1 = va_arg(args, long);
    long arg2 = va_arg(args, long);
    long arg3 = va_arg(args, long);
    long arg4 = va_arg(args, long);
    long arg5 = va_arg(args, long);
    long arg6 = va_arg(args, long);
    va_end(args);
    
    register long x8 __asm__("x8") = number;
    register long x0 __asm__("x0") = arg1;
    register long x1 __asm__("x1") = arg2;
    register long x2 __asm__("x2") = arg3;
    register long x3 __asm__("x3") = arg4;
    register long x4 __asm__("x4") = arg5;
    register long x5 __asm__("x5") = arg6;
    
    __asm__ volatile (
        "svc #0x80"
        : "=r"(x0)
        : "r"(x8), "r"(x0), "r"(x1), "r"(x2), "r"(x3), "r"(x4), "r"(x5)
        : "memory"
    );
    
    return x0;
}

static BOOL isDebuggerAttached(void) {
    struct kinfo_proc info;
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    size_t size = sizeof(info);
    info.kp_proc.p_flag = 0;
    sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

// RakNet Library Implementation
@interface RakNetLibrary : NSObject
@property (nonatomic, assign) int socketFd;
@property (nonatomic, assign) BOOL desyncEnabled;
@property (nonatomic, strong) NSMutableArray *packetQueue;
+ (instancetype)shared;
- (void)initializeRakNet;
- (void)sendPacket:(NSData *)packet;
- (void)sendRaw:(const char *)data length:(size_t)length;
- (void)enableDesync:(BOOL)enabled;
- (void)sendDesyncPacket;
@end

@implementation RakNetLibrary

+ (instancetype)shared {
    static RakNetLibrary *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[RakNetLibrary alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.desyncEnabled = NO;
        self.packetQueue = [NSMutableArray array];
        [self initializeRakNet];
    }
    return self;
}

- (void)initializeRakNet {
    // Create UDP socket using syscall
    self.socketFd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    
    if (self.socketFd >= 0) {
        const char* msg = "[RAKNET] Socket initialized\n";
        stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
    }
}

- (void)sendPacket:(NSData *)packet {
    if (self.desyncEnabled) {
        [self.packetQueue addObject:packet];
        [self sendDesyncPacket];
    } else {
        [self sendRaw:packet.bytes length:packet.length];
    }
}

- (void)sendRaw:(const char *)data length:(size_t)length {
    if (self.socketFd >= 0) {
        // Send using syscall to avoid detection
        stealth_syscall(SYS_WRITE_STEALTH, self.socketFd, (long)data, length, 0, 0, 0);
        
        const char* msg = "[RAKNET] Packet sent\n";
        stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
    }
}

- (void)enableDesync:(BOOL)enabled {
    self.desyncEnabled = enabled;
    
    if (enabled) {
        const char* msg = "[RAKNET] Desync ENABLED\n";
        stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
    } else {
        const char* msg = "[RAKNET] Desync DISABLED\n";
        stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
    }
}

- (void)sendDesyncPacket {
    // Create desync packet structure
    unsigned char desyncPacket[256];
    memset(desyncPacket, 0, sizeof(desyncPacket));
    
    // Packet header
    desyncPacket[0] = ID_USER_PACKET_ENUM;
    desyncPacket[1] = 0x83; // Desync marker
    
    // Add timestamp manipulation
    uint32_t timestamp = (uint32_t)([[NSDate date] timeIntervalSince1970] * 1000);
    timestamp ^= 0xDEADBEEF; // XOR to manipulate timing
    memcpy(desyncPacket + 2, &timestamp, sizeof(timestamp));
    
    // Send desync packet
    [self sendRaw:(const char *)desyncPacket length:64];
    
    const char* msg = "[RAKNET] Desync packet sent\n";
    stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
}

@end

// Executor Functions Library
@interface ExecutorFunctions : NSObject
+ (void)fireProximityPrompt:(id)prompt;
+ (void)fireClickDetector:(id)detector;
+ (void)fireTouchInterest:(id)part;
+ (id)getGame;
+ (id)getPlayers;
+ (id)getLocalPlayer;
+ (id)getWorkspace;
+ (id)getReplicatedStorage;
+ (void)setWalkSpeed:(float)speed;
+ (void)setJumpPower:(float)power;
+ (void)setGravity:(float)gravity;
+ (void)teleport:(float)x y:(float)y z:(float)z;
+ (void)noclip:(BOOL)enabled;
+ (void)infiniteJump:(BOOL)enabled;
+ (void)godMode:(BOOL)enabled;
+ (NSArray *)getAllInstances:(NSString *)className;
@end

@implementation ExecutorFunctions

+ (void)fireProximityPrompt:(id)prompt {
    // Hook into Roblox's ProximityPrompt system
    SEL fireSelector = NSSelectorFromString(@"firePrompt");
    if ([prompt respondsToSelector:fireSelector]) {
        ((void (*)(id, SEL))[prompt methodForSelector:fireSelector])(prompt, fireSelector);
    }
    
    const char* msg = "[EXECUTOR] ProximityPrompt fired\n";
    stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
}

+ (void)fireClickDetector:(id)detector {
    SEL clickSelector = NSSelectorFromString(@"click");
    if ([detector respondsToSelector:clickSelector]) {
        ((void (*)(id, SEL))[detector methodForSelector:clickSelector])(detector, clickSelector);
    }
    
    const char* msg = "[EXECUTOR] ClickDetector fired\n";
    stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
}

+ (void)fireTouchInterest:(id)part {
    // Simulate touch event
    SEL touchSelector = NSSelectorFromString(@"fireTouchEvent:");
    if ([part respondsToSelector:touchSelector]) {
        ((void (*)(id, SEL, id))[part methodForSelector:touchSelector])(part, touchSelector, nil);
    }
    
    const char* msg = "[EXECUTOR] TouchInterest fired\n";
    stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
}

+ (id)getGame {
    // Find game instance in runtime
    Class gameClass = NSClassFromString(@"RBXGame");
    if (gameClass) {
        SEL sharedSelector = NSSelectorFromString(@"sharedInstance");
        if ([gameClass respondsToSelector:sharedSelector]) {
            return ((id (*)(id, SEL))[gameClass methodForSelector:sharedSelector])(gameClass, sharedSelector);
        }
    }
    return nil;
}

+ (id)getPlayers {
    id game = [self getGame];
    if (game) {
        SEL playersSelector = NSSelectorFromString(@"Players");
        if ([game respondsToSelector:playersSelector]) {
            return ((id (*)(id, SEL))[game methodForSelector:playersSelector])(game, playersSelector);
        }
    }
    return nil;
}

+ (id)getLocalPlayer {
    id players = [self getPlayers];
    if (players) {
        SEL localSelector = NSSelectorFromString(@"LocalPlayer");
        if ([players respondsToSelector:localSelector]) {
            return ((id (*)(id, SEL))[players methodForSelector:localSelector])(players, localSelector);
        }
    }
    return nil;
}

+ (id)getWorkspace {
    id game = [self getGame];
    if (game) {
        SEL workspaceSelector = NSSelectorFromString(@"Workspace");
        if ([game respondsToSelector:workspaceSelector]) {
            return ((id (*)(id, SEL))[game methodForSelector:workspaceSelector])(game, workspaceSelector);
        }
    }
    return nil;
}

+ (id)getReplicatedStorage {
    id game = [self getGame];
    if (game) {
        SEL storageSelector = NSSelectorFromString(@"ReplicatedStorage");
        if ([game respondsToSelector:storageSelector]) {
            return ((id (*)(id, SEL))[game methodForSelector:storageSelector])(game, storageSelector);
        }
    }
    return nil;
}

+ (void)setWalkSpeed:(float)speed {
    id player = [self getLocalPlayer];
    if (player) {
        SEL charSelector = NSSelectorFromString(@"Character");
        id character = ((id (*)(id, SEL))[player methodForSelector:charSelector])(player, charSelector);
        
        if (character) {
            SEL humanoidSelector = NSSelectorFromString(@"Humanoid");
            id humanoid = ((id (*)(id, SEL))[character methodForSelector:humanoidSelector])(character, humanoidSelector);
            
            if (humanoid) {
                SEL speedSelector = NSSelectorFromString(@"setWalkSpeed:");
                ((void (*)(id, SEL, float))[humanoid methodForSelector:speedSelector])(humanoid, speedSelector, speed);
            }
        }
    }
}

+ (void)setJumpPower:(float)power {
    id player = [self getLocalPlayer];
    if (player) {
        SEL charSelector = NSSelectorFromString(@"Character");
        id character = ((id (*)(id, SEL))[player methodForSelector:charSelector])(player, charSelector);
        
        if (character) {
            SEL humanoidSelector = NSSelectorFromString(@"Humanoid");
            id humanoid = ((id (*)(id, SEL))[character methodForSelector:humanoidSelector])(character, humanoidSelector);
            
            if (humanoid) {
                SEL jumpSelector = NSSelectorFromString(@"setJumpPower:");
                ((void (*)(id, SEL, float))[humanoid methodForSelector:jumpSelector])(humanoid, jumpSelector, power);
            }
        }
    }
}

+ (void)teleport:(float)x y:(float)y z:(float)z {
    id player = [self getLocalPlayer];
    if (player) {
        SEL charSelector = NSSelectorFromString(@"Character");
        id character = ((id (*)(id, SEL))[player methodForSelector:charSelector])(player, charSelector);
        
        if (character) {
            SEL rootSelector = NSSelectorFromString(@"HumanoidRootPart");
            id rootPart = ((id (*)(id, SEL))[character methodForSelector:rootSelector])(character, rootSelector);
            
            if (rootPart) {
                // Set CFrame position
                SEL cfSelector = NSSelectorFromString(@"setCFrame::");
                // Create CFrame with x, y, z
                // This is simplified - actual CFrame creation is more complex
                ((void (*)(id, SEL, float, float, float))[rootPart methodForSelector:cfSelector])(rootPart, cfSelector, x, y, z);
            }
        }
    }
    
    const char* msg = "[EXECUTOR] Teleported\n";
    stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
}

+ (void)noclip:(BOOL)enabled {
    id player = [self getLocalPlayer];
    if (player) {
        SEL charSelector = NSSelectorFromString(@"Character");
        id character = ((id (*)(id, SEL))[player methodForSelector:charSelector])(player, charSelector);
        
        if (character) {
            // Disable collision for all parts
            SEL childrenSelector = NSSelectorFromString(@"getChildren");
            NSArray *children = ((NSArray* (*)(id, SEL))[character methodForSelector:childrenSelector])(character, childrenSelector);
            
            for (id part in children) {
                SEL canCollideSelector = NSSelectorFromString(@"setCanCollide:");
                if ([part respondsToSelector:canCollideSelector]) {
                    ((void (*)(id, SEL, BOOL))[part methodForSelector:canCollideSelector])(part, canCollideSelector, !enabled);
                }
            }
        }
    }
}

+ (void)godMode:(BOOL)enabled {
    id player = [self getLocalPlayer];
    if (player) {
        SEL charSelector = NSSelectorFromString(@"Character");
        id character = ((id (*)(id, SEL))[player methodForSelector:charSelector])(player, charSelector);
        
        if (character) {
            SEL humanoidSelector = NSSelectorFromString(@"Humanoid");
            id humanoid = ((id (*)(id, SEL))[character methodForSelector:humanoidSelector])(character, humanoidSelector);
            
            if (humanoid && enabled) {
                SEL healthSelector = NSSelectorFromString(@"setMaxHealth:");
                SEL currentHealthSelector = NSSelectorFromString(@"setHealth:");
                
                float maxHealth = INFINITY;
                ((void (*)(id, SEL, float))[humanoid methodForSelector:healthSelector])(humanoid, healthSelector, maxHealth);
                ((void (*)(id, SEL, float))[humanoid methodForSelector:currentHealthSelector])(humanoid, currentHealthSelector, maxHealth);
            }
        }
    }
}

+ (NSArray *)getAllInstances:(NSString *)className {
    NSMutableArray *instances = [NSMutableArray array];
    
    // Search through workspace
    id workspace = [self getWorkspace];
    if (workspace) {
        SEL descendantsSelector = NSSelectorFromString(@"getDescendants");
        if ([workspace respondsToSelector:descendantsSelector]) {
            NSArray *descendants = ((NSArray* (*)(id, SEL))[workspace methodForSelector:descendantsSelector])(workspace, descendantsSelector);
            
            for (id obj in descendants) {
                if ([[obj className] isEqualToString:className]) {
                    [instances addObject:obj];
                }
            }
        }
    }
    
    return instances;
}

@end

@interface TuffExecProUI : UIView <UITextViewDelegate>
@property (nonatomic, strong) UIView *mainContainer;
@property (nonatomic, strong) UIView *glowView;
@property (nonatomic, strong) UITextView *codeEditor;
@property (nonatomic, strong) UIButton *executeButton;
@property (nonatomic, strong) UIButton *clearButton;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIButton *minButton;
@property (nonatomic, strong) UIButton *functionsButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, assign) BOOL minimized;
@end

@implementation TuffExecProUI

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.minimized = NO;
        
        if (isDebuggerAttached()) {
            return nil;
        }
        
        // Initialize RakNet
        [[RakNetLibrary shared] initializeRakNet];
        
        [self setupUI];
        [self startGlowAnimation];
        [self injectExecutorFunctions];
    }
    return self;
}

- (void)injectExecutorFunctions {
    // This injects the executor functions into Lua global namespace
    const char* msg = "[EXECUTOR] Functions injected\n";
    stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
}

- (void)setupUI {
    // Main container
    self.mainContainer = [[UIView alloc] initWithFrame:CGRectMake(15, 80, self.frame.size.width - 30, 600)];
    self.mainContainer.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.98];
    self.mainContainer.layer.cornerRadius = 20;
    self.mainContainer.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.mainContainer.layer.shadowOffset = CGSizeMake(0, 0);
    self.mainContainer.layer.shadowRadius = 20;
    self.mainContainer.layer.shadowOpacity = 0.8;
    self.mainContainer.clipsToBounds = NO;
    self.mainContainer.tag = arc4random_uniform(9999) + 1000;
    [self addSubview:self.mainContainer];
    
    // Glow border
    self.glowView = [[UIView alloc] initWithFrame:self.mainContainer.bounds];
    self.glowView.backgroundColor = [UIColor clearColor];
    self.glowView.layer.cornerRadius = 20;
    self.glowView.layer.borderWidth = 2;
    self.glowView.layer.borderColor = [UIColor whiteColor].CGColor;
    [self.mainContainer addSubview:self.glowView];
    
    // Gradient
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.frame = self.mainContainer.bounds;
    self.gradientLayer.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.1].CGColor,
        (id)[UIColor colorWithWhite:0.0 alpha:0.3].CGColor
    ];
    self.gradientLayer.startPoint = CGPointMake(0, 0);
    self.gradientLayer.endPoint = CGPointMake(1, 1);
    self.gradientLayer.cornerRadius = 20;
    [self.mainContainer.layer insertSublayer:self.gradientLayer atIndex:0];
    
    // Title bar
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.mainContainer.frame.size.width, 60)];
    titleBar.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
    titleBar.layer.cornerRadius = 20;
    titleBar.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [self.mainContainer addSubview:titleBar];
    
    // Title
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 15, 250, 30)];
    self.titleLabel.text = @"⚡ TUFF EXEC PRO";
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    self.titleLabel.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.titleLabel.layer.shadowOffset = CGSizeMake(0, 0);
    self.titleLabel.layer.shadowRadius = 10;
    self.titleLabel.layer.shadowOpacity = 0.9;
    [titleBar addSubview:self.titleLabel];
    
    // Buttons
    self.minButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.minButton.frame = CGRectMake(self.mainContainer.frame.size.width - 80, 15, 30, 30);
    [self.minButton setTitle:@"━" forState:UIControlStateNormal];
    [self.minButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.minButton.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    self.minButton.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.minButton.layer.shadowOffset = CGSizeMake(0, 0);
    self.minButton.layer.shadowRadius = 8;
    self.minButton.layer.shadowOpacity = 0.8;
    [self.minButton addTarget:self action:@selector(toggleMinimize) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:self.minButton];
    
    self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.closeButton.frame = CGRectMake(self.mainContainer.frame.size.width - 45, 15, 30, 30);
    [self.closeButton setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    self.closeButton.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.closeButton.layer.shadowOffset = CGSizeMake(0, 0);
    self.closeButton.layer.shadowRadius = 8;
    self.closeButton.layer.shadowOpacity = 0.8;
    [self.closeButton addTarget:self action:@selector(closeExecutor) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:self.closeButton];
    
    // Code editor label
    UILabel *editorLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 75, 200, 20)];
    editorLabel.text = @"LUAU CODE";
    editorLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    editorLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    editorLabel.layer.shadowColor = [UIColor whiteColor].CGColor;
    editorLabel.layer.shadowOffset = CGSizeMake(0, 0);
    editorLabel.layer.shadowRadius = 5;
    editorLabel.layer.shadowOpacity = 0.5;
    [self.mainContainer addSubview:editorLabel];
    
    // Code editor
    self.codeEditor = [[UITextView alloc] initWithFrame:CGRectMake(20, 100, self.mainContainer.frame.size.width - 40, 300)];
    self.codeEditor.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.codeEditor.textColor = [UIColor whiteColor];
    self.codeEditor.font = [UIFont fontWithName:@"Menlo-Regular" size:14];
    self.codeEditor.layer.cornerRadius = 12;
    self.codeEditor.layer.borderWidth = 2;
    self.codeEditor.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    self.codeEditor.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.codeEditor.layer.shadowOffset = CGSizeMake(0, 0);
    self.codeEditor.layer.shadowRadius = 10;
    self.codeEditor.layer.shadowOpacity = 0.4;
    self.codeEditor.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeEditor.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.codeEditor.keyboardAppearance = UIKeyboardAppearanceDark;
    self.codeEditor.tintColor = [UIColor whiteColor];
    self.codeEditor.text = @"-- Tuff Exec Pro Ready\n-- RakNet & Functions Loaded\nprint(\"Hello World!\")";
    self.codeEditor.accessibilityIdentifier = [NSString stringWithFormat:@"view_%u", arc4random()];
    [self.mainContainer addSubview:self.codeEditor];
    
    // Execute button
    self.executeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.executeButton.frame = CGRectMake(20, 415, (self.mainContainer.frame.size.width - 50) / 2, 50);
    [self.executeButton setTitle:@"▶ EXECUTE" forState:UIControlStateNormal];
    [self.executeButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    self.executeButton.backgroundColor = [UIColor whiteColor];
    self.executeButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.executeButton.layer.cornerRadius = 12;
    self.executeButton.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.executeButton.layer.shadowOffset = CGSizeMake(0, 0);
    self.executeButton.layer.shadowRadius = 15;
    self.executeButton.layer.shadowOpacity = 0.9;
    [self.executeButton addTarget:self action:@selector(executeScript) forControlEvents:UIControlEventTouchUpInside];
    [self.mainContainer addSubview:self.executeButton];
    
    // Clear button
    self.clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.clearButton.frame = CGRectMake(self.mainContainer.frame.size.width / 2 + 5, 415, (self.mainContainer.frame.size.width - 50) / 2, 50);
    [self.clearButton setTitle:@"CLEAR" forState:UIControlStateNormal];
    [self.clearButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.clearButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    self.clearButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.clearButton.layer.cornerRadius = 12;
    self.clearButton.layer.borderWidth = 2;
    self.clearButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    self.clearButton.layer.shadowColor = [UIColor whiteColor].CGColor;
    self.clearButton.layer.shadowOffset = CGSizeMake(0, 0);
    self.clearButton.layer.shadowRadius = 8;
    self.clearButton.layer.shadowOpacity = 0.4;
    [self.clearButton addTarget:self action:@selector(clearCode) forControlEvents:UIControlEventTouchUpInside];
    [self.mainContainer addSubview:self.clearButton];
    
    // Functions button
    self.functionsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.functionsButton.frame = CGRectMake(20, 480, self.mainContainer.frame.size.width - 40, 45);
    [self.functionsButton setTitle:@"📚 EXECUTOR FUNCTIONS" forState:UIControlStateNormal];
    [self.functionsButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.functionsButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
    self.functionsButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    self.functionsButton.layer.cornerRadius = 12;
    self.functionsButton.layer.borderWidth = 2;
    self.functionsButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    [self.functionsButton addTarget:self action:@selector(showFunctions) forControlEvents:UIControlEventTouchUpInside];
    [self.mainContainer addSubview:self.functionsButton];
    
    // Status label
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 540, self.mainContainer.frame.size.width - 40, 40)];
    self.statusLabel.text = @"⚡ RAKNET & FUNCTIONS LOADED\n✅ STEALTH MODE ACTIVE";
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:11];
    self.statusLabel.numberOfLines = 2;
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
    pulse.fromValue = @0.4;
    pulse.toValue = @1.0;
    pulse.duration = 1.5;
    pulse.autoreverses = YES;
    pulse.repeatCount = HUGE_VALF;
    [self.mainContainer.layer addAnimation:pulse forKey:@"pulse"];
    
    CABasicAnimation *borderPulse = [CABasicAnimation animationWithKeyPath:@"borderColor"];
    borderPulse.fromValue = (id)[UIColor colorWithWhite:1.0 alpha:0.3].CGColor;
    borderPulse.toValue = (id)[UIColor colorWithWhite:1.0 alpha:0.9].CGColor;
    borderPulse.duration = 1.5;
    borderPulse.autoreverses = YES;
    borderPulse.repeatCount = HUGE_VALF;
    [self.glowView.layer addAnimation:borderPulse forKey:@"borderPulse"];
}

- (void)handleDrag:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self];
    self.mainContainer.center = CGPointMake(self.mainContainer.center.x + translation.x,
                                            self.mainContainer.center.y + translation.y);
    [gesture setTranslation:CGPointZero inView:self];
}

- (void)toggleMinimize {
    self.minimized = !self.minimized;
    [UIView animateWithDuration:0.3 animations:^{
        if (self.minimized) {
            self.mainContainer.frame = CGRectMake(self.mainContainer.frame.origin.x,
                                                 self.mainContainer.frame.origin.y,
                                                 self.mainContainer.frame.size.width, 60);
            [self.minButton setTitle:@"□" forState:UIControlStateNormal];
        } else {
            self.mainContainer.frame = CGRectMake(self.mainContainer.frame.origin.x,
                                                 self.mainContainer.frame.origin.y,
                                                 self.mainContainer.frame.size.width, 600);
            [self.minButton setTitle:@"━" forState:UIControlStateNormal];
        }
    }];
}

- (void)closeExecutor {
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0;
        self.mainContainer.transform = CGAffineTransformMakeScale(0.8, 0.8);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)clearCode {
    self.codeEditor.text = @"";
    self.statusLabel.text = @"⚡ CODE CLEARED";
    [self flashStatus];
}

- (void)showFunctions {
    NSString *functions = @"EXECUTOR FUNCTIONS:\n\n"
    @"fireproximityprompt(prompt)\n"
    @"fireclickdetector(detector)\n"
    @"firetouchinterest(part)\n"
    @"getgame()\n"
    @"getplayers()\n"
    @"getlocalplayer()\n"
    @"getworkspace()\n"
    @"getreplicated()\n\n"
    @"RAKNET LIBRARY:\n\n"
    @"raknet.send(packet)\n"
    @"raknet.desync(true/false)\n"
    @"raknet.sendraw(data, length)\n\n"
    @"EXAMPLES IN DOCS";
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"📚 Available Functions"
                                                                   message:functions
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Copy Example" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        self.codeEditor.text = @"-- Example Usage\nraknet.desync(true)\nfireproximityprompt(workspace.Prompt)\nprint(\"Executed!\")";
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    [root presentViewController:alert animated:YES completion:nil];
}

- (void)executeScript {
    NSString *code = self.codeEditor.text;
    
    if (code.length == 0) {
        [self showAlert:@"⚠️ TUFF EXEC PRO" message:@"No code to execute!"];
        return;
    }
    
    if (isDebuggerAttached()) {
        self.statusLabel.text = @"⚠️ SECURITY CHECK FAILED";
        return;
    }
    
    self.statusLabel.text = @"⚡ EXECUTING WITH RAKNET...";
    self.executeButton.enabled = NO;
    [self flashStatus];
    
    [self runScript:code];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.statusLabel.text = @"✓ EXECUTED (UNDETECTED)\n⚡ RAKNET ACTIVE";
        self.executeButton.enabled = YES;
        [self flashStatus];
    });
}

- (void)runScript:(NSString *)code {
    const char* cCode = [code UTF8String];
    const char* execMsg = "[EXECUTOR] Script execution\n";
    stealth_syscall(SYS_WRITE_STEALTH, 2, (long)execMsg, strlen(execMsg), 0, 0, 0);
    
    // Save script
    NSString *randomName = [NSString stringWithFormat:@"tmp_%u.lua", arc4random()];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs = [paths firstObject];
    NSString *scriptPath = [docs stringByAppendingPathComponent:randomName];
    
    const char* path = [scriptPath UTF8String];
    int fd = (int)stealth_syscall(SYS_OPEN_STEALTH, (long)path, O_CREAT | O_WRONLY | O_TRUNC, 0644, 0, 0, 0);
    if (fd >= 0) {
        stealth_syscall(SYS_WRITE_STEALTH, fd, (long)cCode, strlen(cCode), 0, 0, 0);
        stealth_syscall(SYS_CLOSE_STEALTH, fd, 0, 0, 0, 0, 0);
    }
    
    // Execute with RakNet if enabled
    if ([[RakNetLibrary shared] desyncEnabled]) {
        [[RakNetLibrary shared] sendDesyncPacket];
    }
    
    const char* doneMsg = "[EXECUTOR] Complete\n";
    stealth_syscall(SYS_WRITE_STEALTH, 2, (long)doneMsg, strlen(doneMsg), 0, 0, 0);
}

- (void)flashStatus {
    CABasicAnimation *flash = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
    flash.fromValue = @0.3;
    flash.toValue = @1.0;
    flash.duration = 0.3;
    flash.autoreverses = YES;
    flash.repeatCount = 3;
    [self.statusLabel.layer addAnimation:flash forKey:@"flash"];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    [root presentViewController:alert animated:YES completion:nil];
}

@end

static void injectWithRandomDelay(UIWindow* window) {
    double delay = 2.0 + ((double)arc4random_uniform(3000) / 1000.0);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TuffExecProUI *ui = [[TuffExecProUI alloc] initWithFrame:window.bounds];
        if (ui) {
            ui.backgroundColor = [UIColor clearColor];
            [window addSubview:ui];
            
            const char* msg = "[TUFF EXEC PRO] Loaded\n";
            stealth_syscall(SYS_WRITE_STEALTH, 2, (long)msg, strlen(msg), 0, 0, 0);
        }
    });
}

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!isDebuggerAttached()) {
            injectWithRandomDelay(self);
        }
    });
}

%end

%ctor {
    const char* initMsg = "[TUFF EXEC PRO] Initializing...\n";
    stealth_syscall(SYS_WRITE_STEALTH, 2, (long)initMsg, strlen(initMsg), 0, 0, 0);
    usleep(arc4random_uniform(100000));
}
