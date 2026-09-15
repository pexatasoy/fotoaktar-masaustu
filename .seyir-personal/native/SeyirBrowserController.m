#import "SeyirBrowserController.h"
#import "SeyirAddress.h"
#import "SeyirLibrary.h"
#import <AVKit/AVKit.h>

static UIColor *SeyirBackground(void) { return [UIColor colorWithWhite:0.055 alpha:1]; }
static UIColor *SeyirSurface(void) { return [UIColor colorWithWhite:0.115 alpha:1]; }

@interface SeyirBrowserController () <UITextFieldDelegate>
@property(nonatomic,strong) id<SeyirBrowserEngine> engine;
@property(nonatomic,strong) SeyirLibrary *library;
@property(nonatomic,strong) UIView *home;
@property(nonatomic,strong) UIStackView *toolbar;
@property(nonatomic,strong) UIStackView *homeRows;
@property(nonatomic,strong) UITextField *address;
@property(nonatomic,strong) UIButton *backButton;
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
@end

@implementation SeyirBrowserController
- (instancetype)initWithEngine:(id<SeyirBrowserEngine>)engine {
    if ((self=[super init])) {
        _engine=engine;
        _library=[[SeyirLibrary alloc] initWithDefaults:NSUserDefaults.standardUserDefaults];
        _pageTitle=@"";
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
    for(UIButton *button in @[homeButton,self.backButton,self.reloadButton,self.starButton,full]) {
        UIButtonConfiguration *config=button.configuration;config.title=nil;button.configuration=config;
        [button.widthAnchor constraintEqualToConstant:76].active=YES;
    }
    for(UIView *item in @[homeButton,self.backButton,self.address,self.spinner,self.reloadButton,self.starButton,full]) [self.toolbar addArrangedSubview:item];
    UIView *content=self.engine.contentView;content.translatesAutoresizingMaskIntoConstraints=NO;
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
    [self showHome];
}
- (void)showHome {
    [self.engine stop];
    [self.engine pauseMedia];
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
    UILabel *subtitle=[self label:@"Nereye bakalım?" size:28 weight:UIFontWeightRegular];subtitle.textColor=[UIColor colorWithWhite:0.6 alpha:1];[stack addArrangedSubview:subtitle];
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
    [self.address resignFirstResponder];[self setPageLoading:YES];[self.engine navigate:url];[self setNeedsFocusUpdate];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSURL *url=SeyirResolveAddress(textField.text ?: @"");
    if(url) [self openURL:url]; else [self showPageError:@"Bir web adresi veya aramak istediğin kelimeleri yaz."];
    return YES;
}
- (void)goBack { [self.engine goBack]; }
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
    self.currentURL=url;self.pageTitle=title;self.address.text=url.absoluteString;self.backButton.enabled=canGoBack;
    self.starButton.enabled=YES;[self.library recordVisit:url title:title];
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
    if(MAX(fabs(delta.x),fabs(delta.y))<48) return;
    if(fabs(delta.x)>fabs(delta.y)) [self.engine moveFocusX:delta.x>0 ? 1 : -1 y:0];
    else [self.engine moveFocusX:0 y:delta.y>0 ? 1 : -1];
    [gesture setTranslation:CGPointZero inView:self.engine.contentView];
}
- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    if([context.nextFocusedView isDescendantOfView:self.engine.contentView] || context.nextFocusedView==self.engine.contentView) self.focusToolbar=NO;
    else if([context.nextFocusedView isDescendantOfView:self.toolbar]) self.focusToolbar=YES;
}
- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for(UIPress *press in presses) {
        if(self.home.hidden && !self.focusToolbar) {
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
