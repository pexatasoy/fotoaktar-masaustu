#import "SeyirTennisView.h"

@interface SeyirTennisView ()
@property(nonatomic,strong) CADisplayLink *clock;
@property(nonatomic) CFTimeInterval lastTime;
@property(nonatomic) CGFloat playerX, opponentX, ballX, ballY, velocityX, velocityY;
@property(nonatomic) CGFloat swingTime, pointDelay;
@property(nonatomic) NSInteger playerPoints, opponentPoints, playerGames, opponentGames;
@property(nonatomic) BOOL gamePaused;
@property(nonatomic,copy) NSString *notice;
@end

@implementation SeyirTennisView
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.opaque=NO;self.backgroundColor=UIColor.clearColor;
        self.accessibilityLabel=@"Mini tenis";
        _playerX=.5;_opponentX=.5;_notice=@"Servis için tıkla";_pointDelay=-1;
        _ballX=.5;_ballY=.84;
        UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        pan.allowedTouchTypes=@[@(UITouchTypeIndirect)];[self addGestureRecognizer:pan];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(suspendGame) name:UIApplicationWillResignActiveNotification object:nil];
    }
    return self;
}
- (BOOL)canBecomeFocused { return YES; }
- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self.clock invalidate];self.clock=nil;self.lastTime=0;
    if(self.window){self.clock=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];self.clock.preferredFramesPerSecond=30;[self.clock addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];self.clock.paused=self.gamePaused || self.pointDelay<0;}
}
- (void)dealloc { [self.clock invalidate];[[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)suspendGame { self.gamePaused=YES;self.clock.paused=YES;[self setNeedsDisplay]; }
- (void)setCourtBackground:(BOOL)value { _courtBackground=value;[self setNeedsDisplay]; }
- (void)moveBy:(CGFloat)delta { if(!self.gamePaused) self.playerX=MAX(.1,MIN(.9,self.playerX+delta));[self setNeedsDisplay]; }
- (void)pan:(UIPanGestureRecognizer *)gesture { CGPoint p=[gesture translationInView:self];[self moveBy:p.x/MAX(1,self.bounds.size.width)];[gesture setTranslation:CGPointZero inView:self]; }
- (void)swing {
    if(self.gamePaused){[self togglePause];return;}
    if(self.pointDelay<0){self.pointDelay=0;self.ballX=self.playerX;self.ballY=.82;self.velocityY=-.49;self.velocityX=.13;self.notice=@"";self.lastTime=0;self.clock.paused=NO;}
    else self.swingTime=.28;
}
- (void)togglePause { self.gamePaused=!self.gamePaused;self.lastTime=0;self.clock.paused=self.gamePaused || self.pointDelay<0;[self setNeedsDisplay]; }
- (NSString *)score:(NSInteger)points other:(NSInteger)other {
    if(points>=3 && other>=3) return points==other ? @"40" : points>other ? @"AD" : @"40";
    return @[@"0",@"15",@"30",@"40"][MIN(3,points)];
}
- (void)awardPlayer:(BOOL)player {
    if(player)self.playerPoints++;else self.opponentPoints++;
    self.notice=player ? @"Güzel vuruş" : @"Rakibin sayısı";
    if(MAX(self.playerPoints,self.opponentPoints)>=4 && labs(self.playerPoints-self.opponentPoints)>=2){
        if(self.playerPoints>self.opponentPoints)self.playerGames++;else self.opponentGames++;
        self.notice=player ? @"Oyun senin" : @"Oyun rakibin";self.playerPoints=0;self.opponentPoints=0;
        if(MAX(self.playerGames,self.opponentGames)>=3){self.notice=self.playerGames>self.opponentGames ? @"Maçı kazandın!" : @"Yeni maç, yeni şans";self.playerGames=0;self.opponentGames=0;}
    }
    self.pointDelay=1.6;self.velocityX=0;self.velocityY=0;
}
- (void)tick:(CADisplayLink *)clock {
    if(!self.lastTime){self.lastTime=clock.timestamp;return;}
    CGFloat dt=MIN(.05,clock.timestamp-self.lastTime);self.lastTime=clock.timestamp;
    if(self.gamePaused)return;
    self.swingTime=MAX(0,self.swingTime-dt);
    if(self.pointDelay>0){self.pointDelay-=dt;if(self.pointDelay<=0){self.pointDelay=-1;self.notice=@"Servis için tıkla";self.ballX=self.playerX;self.ballY=.84;self.clock.paused=YES;}[self setNeedsDisplay];return;}
    if(self.pointDelay<0){self.ballX=self.playerX;[self setNeedsDisplay];return;}
    CGFloat target=MAX(.12,MIN(.88,self.ballX));
    self.opponentX+=MAX(-dt*.31,MIN(dt*.31,target-self.opponentX));
    CGFloat previousY=self.ballY;
    self.ballX+=self.velocityX*dt;self.ballY+=self.velocityY*dt;
    // Outside the singles lines is out; no arcade wall bounces.
    if(self.ballX<.055 || self.ballX>.945){[self awardPlayer:self.velocityY>0];}
    else if(self.velocityY>0 && previousY<.84 && self.ballY>=.84){
        CGFloat offset=self.ballX-self.playerX;
        if(fabs(offset)<.115 && self.swingTime>0){self.velocityY=-MIN(.78,fabs(self.velocityY)+.035);self.velocityX=offset*3;self.swingTime=0;}
        else [self awardPlayer:NO];
    } else if(self.velocityY<0 && previousY>.16 && self.ballY<=.16){
        if(fabs(self.ballX-self.opponentX)<.10){self.velocityY=MIN(.78,fabs(self.velocityY)+.025);self.velocityX=(.5-self.ballX)*.36+sin(clock.timestamp*1.7)*.14;}
        else [self awardPlayer:YES];
    }
    [self setNeedsDisplay];
}
- (void)text:(NSString *)text rect:(CGRect)rect size:(CGFloat)size color:(UIColor *)color {
    NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];style.alignment=NSTextAlignmentCenter;
    [text drawInRect:rect withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:size weight:UIFontWeightSemibold],NSForegroundColorAttributeName:color,NSParagraphStyleAttributeName:style}];
}
- (void)drawRect:(CGRect)rect {
    CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    CGContextRef c=UIGraphicsGetCurrentContext();
    CGRect field=CGRectMake(12,78,w-24,h-146);
    if(self.courtBackground){[[UIColor colorWithRed:.045 green:.23 blue:.18 alpha:1] setFill];[[UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:24] fill];}
    // Only the scoreboard has a small backing in transparent mode.
    [[UIColor colorWithWhite:.035 alpha:.84] setFill];[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(8,8,w-16,58) cornerRadius:16] fill];
    NSString *score=[NSString stringWithFormat:@"SEN  %@   ·   %@  RAKİP",[self score:self.playerPoints other:self.opponentPoints],[self score:self.opponentPoints other:self.playerPoints]];
    [self text:score rect:CGRectMake(12,15,w-24,26) size:18 color:UIColor.whiteColor];
    [self text:[NSString stringWithFormat:@"%ld — %ld  ·  3 oyun",(long)self.playerGames,(long)self.opponentGames] rect:CGRectMake(12,41,w-24,20) size:12 color:[UIColor colorWithWhite:.8 alpha:1]];
    CGContextSaveGState(c);CGContextTranslateCTM(c,field.origin.x,field.origin.y);CGContextScaleCTM(c,field.size.width,field.size.height);
    CGContextSetShadowWithColor(c,CGSizeZero,3,UIColor.blackColor.CGColor);
    CGContextSetStrokeColorWithColor(c,[UIColor colorWithWhite:1 alpha:.7].CGColor);CGContextSetLineWidth(c,.004);
    CGContextStrokeRect(c,CGRectMake(.06,.05,.88,.90));CGContextStrokeRect(c,CGRectMake(.15,.05,.70,.90));
    CGContextStrokeRect(c,CGRectMake(.15,.28,.70,.44));CGContextMoveToPoint(c,.5,.28);CGContextAddLineToPoint(c,.5,.72);CGContextStrokePath(c);
    CGContextSetLineWidth(c,.008);CGContextMoveToPoint(c,.035,.5);CGContextAddLineToPoint(c,.965,.5);CGContextStrokePath(c);
    for(int i=0;i<2;i++){
        CGFloat x=i ? self.playerX : self.opponentX,y=i ? .88 : .12;
        UIColor *color=i ? [UIColor colorWithRed:.6 green:.95 blue:.78 alpha:1] : [UIColor colorWithRed:1 green:.65 blue:.43 alpha:1];
        CGContextSetFillColorWithColor(c,color.CGColor);CGContextFillEllipseInRect(c,CGRectMake(x-.032,y-.025,.064,.05));
        CGContextSetStrokeColorWithColor(c,color.CGColor);CGContextSetLineWidth(c,.009);
        CGFloat rx=x+(i && self.swingTime>0 ? .065 : .045);
        CGContextStrokeEllipseInRect(c,CGRectMake(rx-.025,y-.055,.05,.065));
        CGContextMoveToPoint(c,rx,y+.01);CGContextAddLineToPoint(c,x,y+.03);CGContextStrokePath(c);
    }
    CGContextSetFillColorWithColor(c,[UIColor colorWithRed:.9 green:1 blue:.35 alpha:1].CGColor);
    CGContextFillEllipseInRect(c,CGRectMake(self.ballX-.013,self.ballY-.01,.026,.02));CGContextRestoreGState(c);
    NSString *notice=self.gamePaused ? @"Duraklatıldı · Tıkla ve devam et" : self.notice;
    if(notice.length){[[UIColor colorWithWhite:.02 alpha:.82] setFill];[[UIBezierPath bezierPathWithRoundedRect:CGRectMake(18,h/2-20,w-36,40) cornerRadius:12] fill];[self text:notice rect:CGRectMake(20,h/2-12,w-40,28) size:16 color:UIColor.whiteColor];}
    [self text:@"Kaydır: hareket  ·  Tıkla: vur" rect:CGRectMake(8,h-53,w-16,24) size:14 color:UIColor.whiteColor];
    [self text:@"↑ Kort / şeffaf   ↓ Duraklat   Geri: kapat" rect:CGRectMake(8,h-29,w-16,22) size:11 color:[UIColor colorWithWhite:.8 alpha:1]];
}
- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for(UIPress *press in presses) switch(press.type){
        case UIPressTypeLeftArrow:[self moveBy:-.055];return;
        case UIPressTypeRightArrow:[self moveBy:.055];return;
        case UIPressTypeSelect:[self swing];return;
        case UIPressTypeUpArrow:self.courtBackground=!self.courtBackground;return;
        case UIPressTypeDownArrow:[self togglePause];return;
        case UIPressTypeMenu:if(self.onClose)self.onClose();return;
        default:break;
    }
    [super pressesBegan:presses withEvent:event];
}
@end
