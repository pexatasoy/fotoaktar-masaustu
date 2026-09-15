#import "SeyirBrowserController.h"
#import "SeyirAddress.h"
#import "SeyirLibrary.h"
#import <AVKit/AVKit.h>

static UIColor *SeyirBackground(void) { return [UIColor colorWithWhite:0.055 alpha:1]; }
static UIColor *SeyirSurface(void) { return [UIColor colorWithWhite:0.115 alpha:1]; }

@interface SeyirTab : NSObject
@property(nonatomic,strong) id<SeyirBrowserEngine> engine;
@property(nonatomic,strong) NSURL *url;
@property(nonatomic,copy) NSString *title;
@property(nonatomic) BOOL privateMode;
@end
@implementation SeyirTab
@end

@interface SeyirBrowserController () <UITextFieldDelegate>
@property(nonatomic,strong) id<SeyirBrowserEngine> engine;
@property(nonatomic,strong) SeyirLibrary *library;
@property(nonatomic,strong) UIView *home;
@property(nonatomic,strong) UIStackView *toolbar;
@property(nonatomic,strong) UIStackView *homeRows;
@property(nonatomic,strong) UITextField *address;
@property(nonatomic,strong) UIButton *backButton;
@property(nonatomic,strong) UIButton *forwardButton;
@property(nonatomic,strong) UIButton *reloadButton;
@property(nonatomic,strong) UIButton *starButton;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,strong) NSLayoutConstraint *toolbarHeight;
@property(nonatomic,strong,nullable) NSURL *currentURL;
@property(nonatomic,copy) NSString *pageTitle;
@property(nonatomic) BOOL loading;
@property(nonatomic) BOOL fullscreen;
@property(nonatomic) BOOL focusToolbar;
@property(nonatomic,strong) AVPlayerViewController *mediaController;
@property(nonatomic,strong) UIView *engineHost;
@property(nonatomic,strong) UIView *cursor;
@property(nonatomic,strong) UIButton *cursorButton;
@property(nonatomic) BOOL cursorMode;
@property(nonatomic) CGPoint cursorPosition;
@property(nonatomic) NSTimeInterval lastPointerUpdate;
@property(nonatomic,strong) NSMutableArray<SeyirTab *> *tabs;
@property(nonatomic) NSUInteger tabIndex;
@end

@implementation SeyirBrowserController
- (instancetype)initWithEngine:(id<SeyirBrowserEngine>)engine {
    if ((self=[super init])) {
        _engine=engine;
        _library=[[SeyirLibrary alloc] initWithDefaults:NSUserDefaults.standardUserDefaults];
        _pageTitle=@"";
        _tabs=[NSMutableArray array];
        SeyirTab *tab=[SeyirTab new];tab.engine=engine;tab.title=@"Yeni sekme";[_tabs addObject:tab];
        NSArray *saved=[NSUserDefaults.standardUserDefaults arrayForKey:@"seyir.tabs"];
        for(id item in saved) {
            if(_tabs.count>=8) break;
            if(![item isKindOfClass:NSDictionary.class] || ![item[@"url"] isKindOfClass:NSString.class]) continue;
            NSURL *url=SeyirResolveAddress(item[@"url"]);
            if(!url) continue;
            SeyirTab *restored=[SeyirTab new];restored.url=url;restored.title=[item[@"title"] isKindOfClass:NSString.class] ? item[@"title"] : url.host;
            [_tabs addObject:restored];
        }
        engine.controller=self;
    }
    return self;
}
- (UIButton *)button:(NSString *)title symbol:(NSString *)symbol action:(SEL)action {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *config=[UIButtonConfiguration plainButtonConfiguration];
    config.title=title;
    config.image=symbol.length ? [UIImage systemImageNamed:symbol] : nil;
    config.imagePadding=14;
    config.contentInsets=NSDirectionalEdgeInsetsMake(18,22,18,22);
    config.baseForegroundColor=UIColor.whiteColor;
    button.configuration=config;
    button.accessibilityLabel=title;
    [button addTarget:self action:action forControlEvents:UIControlEventPrimaryActionTriggered];
    return button;
}
- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label=[UILabel new];label.text=text;label.textColor=UIColor.whiteColor;
    label.font=[UIFont systemFontOfSize:size weight:weight];
    return label;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
    self.view.backgroundColor=SeyirBackground();
    self.toolbar=[[UIStackView alloc] init];self.toolbar.axis=UILayoutConstraintAxisHorizontal;
    self.toolbar.alignment=UIStackViewAlignmentCenter;self.toolbar.spacing=14;
    self.toolbar.layoutMargins=UIEdgeInsetsMake(12,54,12,54);self.toolbar.layoutMarginsRelativeArrangement=YES;
    self.toolbar.backgroundColor=SeyirBackground();
    self.backButton=[self button:@"Geri" symbol:@"chevron.backward" action:@selector(goBack)];
    self.backButton.enabled=NO;
    self.forwardButton=[self button:@"İleri" symbol:@"chevron.forward" action:@selector(goForward)];self.forwardButton.enabled=NO;
    UIButton *homeButton=[self button:@"Ana sayfa" symbol:@"house" action:@selector(showHome)];
    self.reloadButton=[self button:@"Yenile" symbol:@"arrow.clockwise" action:@selector(reloadPage)];
    self.starButton=[self button:@"Favori" symbol:@"star" action:@selector(toggleFavorite)];
    self.starButton.enabled=NO;
    self.address=[UITextField new];self.address.delegate=self;self.address.placeholder=@"Ara veya adres yaz";
    self.address.font=[UIFont systemFontOfSize:24];self.address.textColor=UIColor.whiteColor;
    self.address.backgroundColor=SeyirSurface();self.address.borderStyle=UITextBorderStyleRoundedRect;
    self.address.keyboardType=UIKeyboardTypeWebSearch;self.address.returnKeyType=UIReturnKeyGo;
    self.address.autocorrectionType=UITextAutocorrectionTypeNo;self.address.autocapitalizationType=UITextAutocapitalizationTypeNone;
    self.address.accessibilityLabel=@"Web adresi veya Google araması";
    [self.address.heightAnchor constraintEqualToConstant:60].active=YES;
    [self.address setContentHuggingPriority:UILayoutPriorityDefaultLow-1 forAxis:UILayoutConstraintAxisHorizontal];
    self.spinner=[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    UIButton *full=[self button:@"Tam ekran" symbol:@"arrow.up.left.and.arrow.down.right" action:@selector(expandVideo)];
    self.cursorButton=[self button:@"İmleç" symbol:@"cursorarrow" action:@selector(toggleCursor)];
    UIButton *tabs=[self button:@"Sekmeler" symbol:@"square.on.square" action:@selector(showTabs)];
    UIButton *options=[self button:@"Seçenekler" symbol:@"ellipsis" action:@selector(showOptions)];
    for(UIButton *button in @[homeButton,self.backButton,self.forwardButton,self.reloadButton,self.starButton,full,self.cursorButton,tabs,options]) {
        UIButtonConfiguration *config=button.configuration;config.title=nil;button.configuration=config;
        [button.widthAnchor constraintEqualToConstant:76].active=YES;
    }
    for(UIView *item in @[homeButton,self.backButton,self.forwardButton,self.address,self.spinner,self.reloadButton,self.starButton,self.cursorButton,full,tabs,options]) [self.toolbar addArrangedSubview:item];
    UIView *content=[UIView new];self.engineHost=content;content.translatesAutoresizingMaskIntoConstraints=NO;
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.allowedTouchTypes=@[@(UITouchTypeIndirect)];[content addGestureRecognizer:pan];
    self.toolbar.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:content];[self.view addSubview:self.toolbar];
    self.toolbarHeight=[self.toolbar.heightAnchor constraintEqualToConstant:108];
    [NSLayoutConstraint activateConstraints:@[
        [self.toolbar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],self.toolbarHeight,
        [content.topAnchor constraintEqualToAnchor:self.toolbar.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]]];
    self.cursor=[[UIView alloc] initWithFrame:CGRectMake(0,0,28,36)];self.cursor.userInteractionEnabled=NO;
    CAShapeLayer *shape=[CAShapeLayer layer];UIBezierPath *path=[UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(2,2)];[path addLineToPoint:CGPointMake(2,27)];[path addLineToPoint:CGPointMake(9,21)];[path addLineToPoint:CGPointMake(15,33)];[path addLineToPoint:CGPointMake(20,30)];[path addLineToPoint:CGPointMake(14,19)];[path addLineToPoint:CGPointMake(26,19)];[path closePath];
    shape.path=path.CGPath;shape.fillColor=UIColor.whiteColor.CGColor;shape.strokeColor=UIColor.blackColor.CGColor;shape.lineWidth=2;
    [self.cursor.layer addSublayer:shape];self.cursor.layer.shadowOpacity=.5;self.cursor.layer.shadowRadius=3;self.cursor.layer.shadowOffset=CGSizeMake(0,2);
    [self.engineHost addSubview:self.cursor];self.cursor.hidden=YES;self.cursorPosition=CGPointMake(.5,.5);
    [self installEngineView];[self showHome];
}
- (void)installEngineView {
    for(UIView *view in self.engineHost.subviews.copy) if(view!=self.cursor) [view removeFromSuperview];
    UIView *view=self.engine.contentView;view.translatesAutoresizingMaskIntoConstraints=NO;
    [self.engineHost insertSubview:view atIndex:0];
    [NSLayoutConstraint activateConstraints:@[[view.topAnchor constraintEqualToAnchor:self.engineHost.topAnchor],[view.leadingAnchor constraintEqualToAnchor:self.engineHost.leadingAnchor],[view.trailingAnchor constraintEqualToAnchor:self.engineHost.trailingAnchor],[view.bottomAnchor constraintEqualToAnchor:self.engineHost.bottomAnchor]]];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews];[self updateCursor]; }
- (void)updateCursor {
    self.cursor.hidden=!self.cursorMode || !self.home.hidden || self.focusToolbar;
    self.cursor.frame=CGRectMake(self.cursorPosition.x*self.engineHost.bounds.size.width,self.cursorPosition.y*self.engineHost.bounds.size.height,28,36);
}
- (void)toggleCursor {
    self.cursorMode=!self.cursorMode;self.cursorButton.accessibilityValue=self.cursorMode ? @"Açık" : @"Kapalı";
    if(self.home.hidden){self.focusToolbar=NO;[self setNeedsFocusUpdate];}
    [self updateCursor];
}
- (void)moveCursorX:(double)x y:(double)y {
    CGFloat width=MAX(1,self.engineHost.bounds.size.width),height=MAX(1,self.engineHost.bounds.size.height);
    if((self.cursorPosition.y>.94 && y>0) || (self.cursorPosition.y<.03 && y<0)) [self.engine scrollPageX:0 y:y];
    self.cursorPosition=CGPointMake(MAX(.005,MIN(.98,self.cursorPosition.x+x/width)),MAX(.005,MIN(.97,self.cursorPosition.y+y/height)));
    [self updateCursor];
    NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;
    if(now-self.lastPointerUpdate>1.0/30.0){self.lastPointerUpdate=now;[self.engine pointerMoveX:self.cursorPosition.x y:self.cursorPosition.y];}
}
- (void)showHome {
    [self.engine stop];
    [self.engine pauseMedia];
    self.cursor.hidden=YES;
    [self setPageFullscreen:NO];
    [self.home removeFromSuperview];
    self.home=[UIView new];self.home.backgroundColor=SeyirBackground();self.home.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:self.home];
    [NSLayoutConstraint activateConstraints:@[[self.home.topAnchor constraintEqualToAnchor:self.toolbar.bottomAnchor],[self.home.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],[self.home.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],[self.home.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]]];
    UIStackView *stack=[UIStackView new];self.homeRows=stack;stack.axis=UILayoutConstraintAxisVertical;stack.spacing=30;stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.home addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.topAnchor constraintEqualToAnchor:self.home.topAnchor constant:54],[stack.leadingAnchor constraintEqualToAnchor:self.home.leadingAnchor constant:84],[stack.trailingAnchor constraintEqualToAnchor:self.home.trailingAnchor constant:-84]]];
    UILabel *brand=[self label:@"seyir" size:64 weight:UIFontWeightSemibold];
    [stack addArrangedSubview:brand];
    UILabel *subtitle=[self label:self.tabs[self.tabIndex].privateMode ? @"Gizli sekme" : @"Nereye bakalım?" size:28 weight:UIFontWeightRegular];subtitle.textColor=[UIColor colorWithWhite:0.6 alpha:1];[stack addArrangedSubview:subtitle];
    UIStackView *quick=[UIStackView new];quick.axis=UILayoutConstraintAxisHorizontal;quick.spacing=20;quick.distribution=UIStackViewDistributionFillEqually;
    [quick addArrangedSubview:[self button:@"Google’da ara" symbol:@"magnifyingglass" action:@selector(editAddress)]];
    [quick addArrangedSubview:[self button:@"YouTube" symbol:@"play.rectangle" action:@selector(openYouTube)]];
    [quick addArrangedSubview:[self button:@"Geçmiş" symbol:@"clock" action:@selector(showHistory)]];
    [stack addArrangedSubview:quick];
    if (self.library.favorites.count) {
        [stack addArrangedSubview:[self label:@"Favoriler" size:24 weight:UIFontWeightMedium]];
        UIStackView *favorites=[UIStackView new];favorites.axis=UILayoutConstraintAxisHorizontal;favorites.spacing=18;favorites.distribution=UIStackViewDistributionFillEqually;
        NSArray *items=self.library.favorites;
        for (NSUInteger i=0;i<MIN((NSUInteger)4,items.count);i++) {
            UIButton *button=[self button:items[i][@"title"] symbol:@"globe" action:@selector(openFavorite:)];button.tag=i;[favorites addArrangedSubview:button];
        }
        [stack addArrangedSubview:favorites];
        if(items.count>4) [stack addArrangedSubview:[self button:@"Tüm favoriler" symbol:@"star" action:@selector(showFavorites)]];
    }
    UILabel *hint=[self label:@"Geri tuşuyla araç çubuğuna geçebilirsin." size:20 weight:UIFontWeightRegular];hint.textColor=[UIColor colorWithWhite:0.45 alpha:1];[stack addArrangedSubview:hint];
    self.focusToolbar=NO;[self setNeedsFocusUpdate];
}
- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    if (self.home && !self.home.hidden) return @[self.home];
    return self.focusToolbar ? @[self.address] : @[self.engine.contentView];
}
- (void)editAddress { self.focusToolbar=YES;[self.address becomeFirstResponder]; }
- (void)openYouTube { [self openURL:[NSURL URLWithString:@"https://www.youtube.com"]]; }
- (void)openFavorite:(UIButton *)button { if(button.tag<self.library.favorites.count) [self openURL:[NSURL URLWithString:self.library.favorites[button.tag][@"url"]]]; }
- (void)openURL:(NSURL *)url {
    if (!url) return;
    self.home.hidden=YES;self.address.text=url.absoluteString;self.focusToolbar=NO;
    self.tabs[self.tabIndex].url=url;self.currentURL=url;[self updateCursor];
    [self.address resignFirstResponder];[self setPageLoading:YES];[self.engine navigate:url];[self setNeedsFocusUpdate];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSURL *url=SeyirResolveAddress(textField.text ?: @"");
    if(url) [self openURL:url]; else [self showPageError:@"Bir web adresi veya aramak istediğin kelimeleri yaz."];
    return YES;
}
- (void)goBack { [self.engine goBack]; }
- (void)goForward { [self.engine goForward]; }
- (void)expandVideo { if(self.home.hidden) { [self.engine enterVideoFullscreen];[self setPageFullscreen:YES];self.focusToolbar=NO;[self setNeedsFocusUpdate]; } }
- (void)reloadPage { if(self.loading) [self.engine stop]; else [self.engine reload]; }
- (void)toggleFavorite {
    if (!self.currentURL) return;
    [self.library toggleFavorite:self.currentURL title:self.pageTitle];
    UIButtonConfiguration *config=self.starButton.configuration;
    config.image=[UIImage systemImageNamed:[self.library isFavorite:self.currentURL] ? @"star.fill" : @"star"];
    self.starButton.configuration=config;
}
- (void)didNavigateToURL:(NSURL *)url title:(NSString *)title canGoBack:(BOOL)canGoBack {
    if(![@[@"http",@"https"] containsObject:url.scheme.lowercaseString]) return;
    self.currentURL=url;self.pageTitle=title;self.address.text=url.absoluteString;self.backButton.enabled=canGoBack;
    self.forwardButton.enabled=self.engine.canGoForward;
    self.tabs[self.tabIndex].url=url;self.tabs[self.tabIndex].title=title;
    self.starButton.enabled=YES;if(!self.tabs[self.tabIndex].privateMode) [self.library recordVisit:url title:title];
    [self saveTabs];
    UIButtonConfiguration *config=self.starButton.configuration;config.image=[UIImage systemImageNamed:[self.library isFavorite:url] ? @"star.fill" : @"star"];self.starButton.configuration=config;
}
- (void)setPageLoading:(BOOL)loading {
    self.loading=loading;
    if(loading) [self.spinner startAnimating];else [self.spinner stopAnimating];
    UIButtonConfiguration *config=self.reloadButton.configuration;config.image=[UIImage systemImageNamed:loading ? @"xmark" : @"arrow.clockwise"];self.reloadButton.configuration=config;
    self.reloadButton.accessibilityLabel=loading ? @"Durdur" : @"Yenile";
}
- (void)setPageFullscreen:(BOOL)fullscreen {
    self.fullscreen=fullscreen;self.toolbar.hidden=fullscreen;self.toolbarHeight.constant=fullscreen ? 0 : 108;
    [self.view layoutIfNeeded];
}
- (void)showPageError:(NSString *)message {
    [self setPageLoading:NO];
    if(self.presentedViewController) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Sayfa açılamadı" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)requestTextInput:(NSString *)value secure:(BOOL)secure {
    if(self.presentedViewController) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:secure ? @"Şifre" : @"Metin yaz" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.secureTextEntry=secure;field.text=value;field.autocapitalizationType=UITextAutocapitalizationTypeNone; }];
    __weak typeof(self) weakSelf=self;
    __weak UIAlertController *weakAlert=alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [weakSelf.engine setFocusedText:weakAlert.textFields.firstObject.text ?: @""]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Vazgeç" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)playMediaURL:(NSURL *)url {
    if(self.presentedViewController || ![@[@"https",@"http"] containsObject:url.scheme.lowercaseString]) return;
    [self.engine pauseMedia];[self setPageLoading:NO];
    self.mediaController=[AVPlayerViewController new];
    self.mediaController.player=[AVPlayer playerWithURL:url];
    [self presentViewController:self.mediaController animated:YES completion:^{[self.mediaController.player play];}];
}
- (NSDictionary *)mediaDiagnostics {
    AVPlayer *player=self.mediaController.player;
    if(!player) return @{};
    double seconds=CMTimeGetSeconds(player.currentTime);
    return @{@"time":@(isfinite(seconds) ? seconds : 0),@"status":@(player.currentItem.status),@"rate":@(player.rate),@"error":player.currentItem.error.localizedDescription ?: @""};
}
- (void)prepareDiagnosticPage { self.home.hidden=YES;self.focusToolbar=NO;[self setNeedsFocusUpdate]; }
- (NSDictionary *)privacyDiagnostics {
    NSUInteger original=self.tabIndex;
    [self newTabPrivate:YES];
    NSURL *privateURL=[NSURL URLWithString:@"https://private.example.test/never-persist"];
    [self didNavigateToURL:privateURL title:@"Private sentinel" canGoBack:NO];
    BOOL privateHistory=NO,privateRestoration=NO;
    for(NSDictionary *entry in self.library.history) if([entry[@"url"] isEqualToString:privateURL.absoluteString]) privateHistory=YES;
    for(NSDictionary *entry in [NSUserDefaults.standardUserDefaults arrayForKey:@"seyir.tabs"]) if([entry[@"url"] isEqualToString:privateURL.absoluteString]) privateRestoration=YES;
    [self closeCurrentTab];[self switchToTab:MIN(original,self.tabs.count-1)];
    return @{@"historyExcluded":@(!privateHistory),@"restorationExcluded":@(!privateRestoration)};
}
- (void)showEntries:(NSArray<NSDictionary *> *)entries title:(NSString *)title history:(BOOL)history {
    UIAlertController *list=[UIAlertController alertControllerWithTitle:title message:entries.count ? nil : @"Henüz bir şey yok." preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;
    for (NSDictionary *entry in entries) [list addAction:[UIAlertAction actionWithTitle:entry[@"title"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[weakSelf openURL:[NSURL URLWithString:entry[@"url"]]];}]];
    if(history && entries.count) [list addAction:[UIAlertAction actionWithTitle:@"Geçmişi temizle" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){[weakSelf.library clearHistory];}]];
    [list addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:list animated:YES completion:nil];
}
- (void)showHistory { [self showEntries:self.library.history title:@"Geçmiş" history:YES]; }
- (void)showFavorites { [self showEntries:self.library.favorites title:@"Favoriler" history:NO]; }
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if(!self.home.hidden || self.focusToolbar) return;
    CGPoint delta=[gesture translationInView:self.engine.contentView];
    if(self.cursorMode){[self moveCursorX:delta.x*1.7 y:delta.y*1.7];[gesture setTranslation:CGPointZero inView:self.engine.contentView];return;}
    if(MAX(fabs(delta.x),fabs(delta.y))<48) return;
    if(fabs(delta.x)>fabs(delta.y)) [self.engine moveFocusX:delta.x>0 ? 1 : -1 y:0];
    else [self.engine moveFocusX:0 y:delta.y>0 ? 1 : -1];
    [gesture setTranslation:CGPointZero inView:self.engine.contentView];
}
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    if([context.nextFocusedView isDescendantOfView:self.engine.contentView] || context.nextFocusedView==self.engine.contentView) self.focusToolbar=NO;
    else if([context.nextFocusedView isDescendantOfView:self.toolbar]) self.focusToolbar=YES;
    [self updateCursor];
}
- (void)saveTabs {
    NSMutableArray *saved=[NSMutableArray array];
    for(SeyirTab *tab in self.tabs) if(!tab.privateMode && [@[@"http",@"https"] containsObject:tab.url.scheme.lowercaseString]) [saved addObject:@{@"url":tab.url.absoluteString,@"title":tab.title ?: tab.url.host ?: @""}];
    [NSUserDefaults.standardUserDefaults setObject:saved forKey:@"seyir.tabs"];
}
- (void)switchToTab:(NSUInteger)index {
    if(index>=self.tabs.count) return;
    [self.engine stop];[self.engine pauseMedia];self.engine.controller=nil;
    SeyirTab *tab=self.tabs[index];BOOL needsLoad=tab.engine==nil;
    if(!tab.engine) tab.engine=[self.engine newEnginePrivate:tab.privateMode];
    self.engine=tab.engine;self.engine.controller=self;self.tabIndex=index;
    [self installEngineView];self.currentURL=tab.url;self.pageTitle=tab.title ?: @"";
    [self setPageLoading:NO];
    self.backButton.enabled=self.engine.canGoBack;self.forwardButton.enabled=self.engine.canGoForward;
    self.starButton.enabled=tab.url!=nil;
    UIButtonConfiguration *star=self.starButton.configuration;
    star.image=[UIImage systemImageNamed:tab.url && [self.library isFavorite:tab.url] ? @"star.fill" : @"star"];self.starButton.configuration=star;
    self.address.placeholder=tab.privateMode ? @"Gizli · Ara veya adres yaz" : @"Ara veya adres yaz";
    self.address.accessibilityLabel=tab.privateMode ? @"Gizli sekme adresi" : @"Web adresi veya Google araması";
    if(tab.url) {
        self.home.hidden=YES;self.address.text=tab.url.absoluteString;self.focusToolbar=NO;
        if(needsLoad) [self openURL:tab.url];
    } else {self.address.text=@"";self.starButton.enabled=NO;[self showHome];}
    // Keep at most the active page and one other page resident. The remaining
    // tabs retain only URL/title and reload when explicitly selected.
    NSUInteger kept=1;
    for(NSUInteger i=0;i<self.tabs.count;i++) if(i!=index && self.tabs[i].engine) {
        if(kept++>=2){[self.tabs[i].engine stop];[self.tabs[i].engine pauseMedia];self.tabs[i].engine=nil;}
    }
    [self updateCursor];[self setNeedsFocusUpdate];[self saveTabs];
}
- (void)newTabPrivate:(BOOL)privateMode {
    if(self.tabs.count>=8){[self showNotice:@"Sekme sınırı" message:@"Yeni bir sekme açmak için mevcut sekmelerden birini kapat."];return;}
    SeyirTab *tab=[SeyirTab new];tab.privateMode=privateMode;tab.title=privateMode ? @"Gizli sekme" : @"Yeni sekme";
    [self.tabs addObject:tab];[self switchToTab:self.tabs.count-1];
}
- (void)closeCurrentTab {
    [self.engine stop];[self.engine pauseMedia];self.engine.controller=nil;
    [self.tabs removeObjectAtIndex:self.tabIndex];
    if(!self.tabs.count) [self newTabPrivate:NO];
    else [self switchToTab:MIN(self.tabIndex,self.tabs.count-1)];
}
- (void)showTabs {
    UIAlertController *list=[UIAlertController alertControllerWithTitle:@"Sekmeler" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;
    for(NSUInteger i=0;i<self.tabs.count;i++) {
        SeyirTab *tab=self.tabs[i];NSString *title=[NSString stringWithFormat:@"%@%@%@",i==self.tabIndex ? @"✓ " : @"",tab.privateMode ? @"Gizli · " : @"",tab.title ?: tab.url.host ?: @"Yeni sekme"];
        [list addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[weakSelf switchToTab:i];}]];
    }
    [list addAction:[UIAlertAction actionWithTitle:@"Yeni sekme" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[weakSelf newTabPrivate:NO];}]];
    [list addAction:[UIAlertAction actionWithTitle:@"Yeni gizli sekme" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[weakSelf newTabPrivate:YES];}]];
    [list addAction:[UIAlertAction actionWithTitle:@"Bu sekmeyi kapat" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){[weakSelf closeCurrentTab];}]];
    [list addAction:[UIAlertAction actionWithTitle:@"Vazgeç" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:list animated:YES completion:nil];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    for(NSUInteger i=0;i<self.tabs.count;i++) if(i!=self.tabIndex) { [self.tabs[i].engine stop];[self.tabs[i].engine pauseMedia];self.tabs[i].engine=nil; }
}
- (void)showNotice:(NSString *)title message:(NSString *)message {
    if(self.presentedViewController) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tamam" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)showZoom {
    UIAlertController *list=[UIAlertController alertControllerWithTitle:@"Yakınlaştırma" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;
    for(NSNumber *level in @[@.75,@1,@1.25,@1.5,@2]) [list addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"%%%d",(int)(level.doubleValue*100)] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[weakSelf.engine setPageZoom:level.doubleValue];}]];
    [list addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:list animated:YES completion:nil];
}
- (void)findOnPage {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Sayfada bul" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.placeholder=@"Aranacak metin";}];
    __weak typeof(self) weakSelf=self;__weak UIAlertController *weakAlert=alert;
    [alert addAction:[UIAlertAction actionWithTitle:@"Bul" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *text=weakAlert.textFields.firstObject.text ?: @"";
        if(text.length) [weakSelf.engine findText:text completion:^(BOOL found){if(!found) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,.5*NSEC_PER_SEC),dispatch_get_main_queue(),^{[weakSelf showNotice:@"Sonuç yok" message:@"Bu metin sayfada bulunamadı."];});}];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Vazgeç" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:alert animated:YES completion:nil];
}
- (void)confirmClearSiteData {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Site verileri temizlensin mi?" message:@"Sitelerdeki oturumların kapanır. Favoriler korunur." preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Temizle" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action){[weakSelf.engine clearWebsiteData:^{[weakSelf showNotice:@"Temizlendi" message:@"Çerezler ve site verileri silindi."];}];}]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Vazgeç" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:alert animated:YES completion:nil];
}
- (void)showOptions {
    UIAlertController *list=[UIAlertController alertControllerWithTitle:@"Seçenekler" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf=self;
    NSDictionary *actions=@{@"Sayfada bul":NSStringFromSelector(@selector(findOnPage)),@"Yakınlaştır":NSStringFromSelector(@selector(showZoom)),@"Favoriler":NSStringFromSelector(@selector(showFavorites)),@"Geçmiş":NSStringFromSelector(@selector(showHistory)),@"Site verilerini temizle":NSStringFromSelector(@selector(confirmClearSiteData))};
    for(NSString *title in @[@"Sayfada bul",@"Yakınlaştır",@"Favoriler",@"Geçmiş",@"Site verilerini temizle"]) [list addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,.4*NSEC_PER_SEC),dispatch_get_main_queue(),^{
            SEL selector=NSSelectorFromString(actions[title]);
            IMP implementation=[weakSelf methodForSelector:selector];
            if(weakSelf && implementation) ((void (*)(id,SEL))implementation)(weakSelf,selector);
        });
    }]];
    [list addAction:[UIAlertAction actionWithTitle:@"Kapat" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:list animated:YES completion:nil];
}
- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for(UIPress *press in presses) {
        if(self.home.hidden && !self.focusToolbar) {
            if(self.cursorMode) {
                switch(press.type) {
                    case UIPressTypeUpArrow:[self moveCursorX:0 y:-35];return;
                    case UIPressTypeDownArrow:[self moveCursorX:0 y:35];return;
                    case UIPressTypeLeftArrow:[self moveCursorX:-35 y:0];return;
                    case UIPressTypeRightArrow:[self moveCursorX:35 y:0];return;
                    case UIPressTypeSelect:[self.engine pointerClickX:self.cursorPosition.x y:self.cursorPosition.y];return;
                    default:break;
                }
            }
            switch(press.type) {
                case UIPressTypeUpArrow:[self.engine moveFocusX:0 y:-1];return;
                case UIPressTypeDownArrow:[self.engine moveFocusX:0 y:1];return;
                case UIPressTypeLeftArrow:[self.engine moveFocusX:-1 y:0];return;
                case UIPressTypeRightArrow:[self.engine moveFocusX:1 y:0];return;
                case UIPressTypeSelect:[self.engine activateFocusedElement];return;
                default:break;
            }
        }
        if(press.type==UIPressTypePlayPause && self.home.hidden) { [self.engine togglePlayback];return; }
        if(press.type==UIPressTypeMenu && self.home.hidden) {
            if(self.fullscreen) { [self setPageFullscreen:NO];self.focusToolbar=YES; }
            else if(!self.focusToolbar) self.focusToolbar=YES;
            else { [self showHome];return; }
            [self setNeedsFocusUpdate];return;
        }
    }
    [super pressesBegan:presses withEvent:event];
}
@end
