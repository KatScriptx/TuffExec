#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// --- UI INTERFACE ---
@interface TuffExecUI : UIView <UITextViewDelegate>
@property (nonatomic, strong) UITextView *codeEditor;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) CGPoint lastPoint;
+ (void)show;
@end

@implementation TuffExecUI

+ (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) window = [[UIApplication sharedApplication].windows firstObject];
        
        TuffExecUI *ui = [[TuffExecUI alloc] initWithFrame:CGRectMake(50, 150, 320, 240)];
        [window addSubview:ui];
        NSLog(@"[TuffExec] UI displayed on screen.");
    });
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.9];
        self.layer.cornerRadius = 12;
        self.layer.borderWidth = 1.5;
        self.layer.borderColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.8 alpha:1.0].CGColor;
        self.clipsToBounds = YES;

        // Title Bar
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 30)];
        self.titleLabel.text = @"  TUFF EXEC PRO v3.0";
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.backgroundColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.3 alpha:1.0];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [self addSubview:self.titleLabel];

        // Code Editor Box
        self.codeEditor = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, 300, 150)];
        self.codeEditor.backgroundColor = [UIColor blackColor];
        self.codeEditor.textColor = [UIColor cyanColor];
        self.codeEditor.font = [UIFont fontWithName:@"Courier-Bold" size:12];
        self.codeEditor.layer.cornerRadius = 5;
        self.codeEditor.text = "-- TuffExec Lua Script\nprint('Hello Roblox!')";
        [self addSubview:self.codeEditor];

        // Play Button (Execute)
        self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.playButton.frame = CGRectMake(10, 200, 300, 30)];
        [self.playButton setTitle:@"▶ EXECUTE / PLAY" forState:UIControlStateNormal];
        [self.playButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.playButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.0 alpha:1.0];
        self.playButton.layer.cornerRadius = 5;
        [self.playButton addTarget:self action:@selector(executeScript) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.playButton];
    }
    return self;
}

// Dragging Logic
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    self.lastPoint = [[touches anyObject] locationInView:self];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGPoint newPoint = [[touches anyObject] locationInView:self.superview];
    self.center = CGPointMake(newPoint.x + (self.frame.size.width/2 - self.lastPoint.x), 
                              newPoint.y + (self.frame.size.height/2 - self.lastPoint.y));
}

// --- CORE EXECUTION LOGIC ---
- (void)executeScript {
    NSString *script = self.codeEditor.text;
    NSLog(@"[TuffExec] Attempting Execution: %@", script);
    
    // Roblox Engine Bridge
    Class gameClass = NSClassFromString(@"RBXGame");
    if (gameClass) {
        id game = [gameClass performSelector:NSSelectorFromString(@"sharedInstance")];
        id players = [game valueForKey:@"Players"];
        id localPlayer = [players valueForKey:@"LocalPlayer"];
        
        if (localPlayer) {
            // Logic for internal property manipulation
            if ([script containsString:@"WalkSpeed"]) {
                [[localPlayer valueForKey:@"Character"] setValue:@(100) forKeyPath:@"Humanoid.WalkSpeed"];
            }
            if ([script containsString:@"Gravity"]) {
                [[game valueForKey:@"Workspace"] setValue:@(0) forKey:@"Gravity"];
            }
        }
    }
    
    // Visual Feedback
    [UIView animateWithDuration:0.2 animations:^{
        self.playButton.backgroundColor = [UIColor whiteColor];
    } completion:^(BOOL finished) {
        self.playButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:0.0 alpha:1.0];
    }];
}

@end

// --- INITIALIZATION ---
%ctor {
    // Wait for Roblox to fully load before showing UI
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [TuffExecUI show];
    });
}
