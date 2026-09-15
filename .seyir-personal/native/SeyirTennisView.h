#import <UIKit/UIKit.h>

// A local, transparent overlay. No network or external model assets.
@interface SeyirTennisView : UIView
@property(nonatomic) BOOL courtBackground;
@property(nonatomic,copy) void (^onClose)(void);
- (void)moveBy:(CGFloat)delta;
- (void)swing;
- (void)togglePause;
@end
