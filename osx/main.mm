#import <Cocoa/Cocoa.h>
#include "GLGame.h"
#include "GLRenderer.h"
#include "GLResources.h"

@interface GameView : NSOpenGLView
{
    NSTimer *renderTimer_;
    GL::Game *game_;
}

- (void)setGame:(GL::Game *)game;

@end

@interface AppController : NSObject <NSApplicationDelegate>
{
    GL::Game *game_;
    NSWindow *window_;
    NSMenuItem *newGame_;
    NSMenuItem *endGame_;
    GameView *gameView_;
}

- (IBAction)newGame:(id)sender;
- (void)handleGameEvent:(GL::Game::Event)event;

@end

static void callback(GL::Game::Event event, void *context)
{
    [(AppController*)context handleGameEvent:event];
}

@implementation AppController

- (void)setupMenuBar:(NSString *)appName
{
    NSMenu *menubar = [[[NSMenu alloc] init] autorelease];
    [NSApp setMainMenu:menubar];
    NSMenuItem *item;
    
    NSMenu *appMenu = [[[NSMenu alloc] initWithTitle:appName] autorelease];
    NSMenuItem *appMenuItem = [[[NSMenuItem alloc] init] autorelease];
    NSMenu *gameMenu = [[[NSMenu alloc] initWithTitle:@"Game"] autorelease];
    [gameMenu setAutoenablesItems:NO];
    NSMenuItem *gameMenuItem = [[[NSMenuItem alloc] init] autorelease];
    [appMenuItem setSubmenu:appMenu];
    [gameMenuItem setSubmenu:gameMenu];
    [menubar addItem:appMenuItem];
    [menubar addItem:gameMenuItem];
    
    item = [appMenu addItemWithTitle:[NSString stringWithFormat:@"About %@", appName] action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [item setTarget:NSApp];
    [appMenu addItem:[NSMenuItem separatorItem]];
    NSString *quitText = [NSString stringWithFormat:@"Quit %@", appName];
    item = [appMenu addItemWithTitle:quitText action:@selector(terminate:) keyEquivalent:@"q"];
    [item setTarget:NSApp];
    newGame_ = [gameMenu addItemWithTitle:@"New Game" action:@selector(newGame:) keyEquivalent:@"n"];
    [newGame_ setTarget:self];
    endGame_ = [gameMenu addItemWithTitle:@"End Game" action:@selector(endGame:) keyEquivalent:@"e"];
    [endGame_ setTarget:self];
    [endGame_ setEnabled:NO];
}

- (id)init
{
    self = [super init];
    if (self != nil) {
        NSString *appName = [NSString stringWithUTF8String:GL::kGameName];
        NSUInteger style = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask;
        window_ = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 460) styleMask:style backing:NSBackingStoreBuffered defer:NO];
        [window_ setTitle:appName];
        gameView_ = [[GameView alloc] initWithFrame:[[window_ contentView] frame]];
        [[window_ contentView] addSubview:gameView_];
        [self setupMenuBar:appName];
        game_ = new GL::Game(callback, self);
        [gameView_ setGame:game_];
    }
    return self;
}

- (void)applicationDidFinishLaunching:(__unused NSNotification*)note
{
    // Center the window, then set the autosave name. If the frame already has been saved, it'll override the centering.
    [window_ center];
    [window_ setFrameAutosaveName:@"MainWindow"];
    
    // Show the window only after its frame has been adjusted.
    [window_ makeKeyAndOrderFront:nil];
}

- (IBAction)newGame:(__unused id)sender
{
    game_->newGame();
}

- (IBAction)endGame:(__unused id)sender
{
    game_->endGame();
}

- (void)handleGameEvent:(GL::Game::Event)event
{
    switch (event) {
        case GL::Game::EventStarted:
            [newGame_ setEnabled:NO];
            [endGame_ setEnabled:YES];
            break;
        case GL::Game::EventEnded:
            [newGame_ setEnabled:YES];
            [endGame_ setEnabled:NO];
            break;
    }
}

@end

@implementation GameView

- (id)initWithFrame:(NSRect)frameRect
{
    NSOpenGLPixelFormatAttribute attr[] = {NSOpenGLPFAAccelerated, NSOpenGLPFADoubleBuffer, NSOpenGLPFADepthSize, 24, 0};
    NSOpenGLPixelFormat *format = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attr] autorelease];
    return [super initWithFrame:frameRect pixelFormat:format];
}

- (void)setGame:(GL::Game *)game
{
    game_ = game;
}

- (void)prepareOpenGL
{
    // Synchronize buffer swaps with vertical refresh rate
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval]; 

    // Start the timer, and add it to other run loop modes so it redraws when a modal dialog is up or during event loops.
    renderTimer_ = [[NSTimer scheduledTimerWithTimeInterval:1/60.0 target:self selector:@selector(renderTimer) userInfo:nil repeats:YES] retain];
    [[NSRunLoop currentRunLoop] addTimer:renderTimer_ forMode:NSEventTrackingRunLoopMode];
    [[NSRunLoop currentRunLoop] addTimer:renderTimer_ forMode:NSModalPanelRunLoopMode];
}

- (void)renderTimer
{
	[self setNeedsDisplay:YES];
}

- (void)reshape
{
	NSRect bounds = [self bounds];
    game_->renderer()->resize(bounds.size.width, bounds.size.height);
	[[self openGLContext] update];
}

- (void)drawRect:(__unused NSRect)rect
{
    if (!game_) {
        return;
    }
    NSOpenGLContext *ctx = [self openGLContext];
	[ctx makeCurrentContext];
	game_->run();
	[ctx flushBuffer];
}

- (void)mouseDown:(NSEvent *)event
{
    NSPoint mouseLoc = [self convertPoint:[event locationInWindow] fromView:nil];
    GL::Point point(mouseLoc.x, game_->renderer()->bounds().height() - mouseLoc.y);
    game_->handleMouseDownEvent(point);
}

- (void)doKey:(NSEvent *)event up:(BOOL)up
{
    NSString *chars = [event characters];
    for (NSUInteger i = 0; i < [chars length]; ++i) {
        unichar ch = [chars characterAtIndex:i];
        GL::Game::Key key;
        switch (ch) {
            case ' ':
                key = GL::Game::KeySpacebar;
                break;
            case NSDownArrowFunctionKey:
                key = GL::Game::KeyDownArrow;
                break;
            case NSLeftArrowFunctionKey:
                key = GL::Game::KeyLeftArrow;
                break;
            case NSRightArrowFunctionKey:
                key = GL::Game::KeyRightArrow;
                break;
            case 'a':
                key = GL::Game::KeyA;
                break;
            case 's':
                key = GL::Game::KeyS;
                break;
            case ';':
                key = GL::Game::KeyColon;
                break;
            case '"':
                key = GL::Game::KeyQuote;
                break;
            default:
                key = GL::Game::KeyNone;
                break;
        }
        if (up) {
            game_->handleKeyUpEvent(key);
        } else {
            game_->handleKeyDownEvent(key);
        }
    }
}

- (void)keyDown:(NSEvent *)event
{
    [self doKey:event up:NO];
}

- (void)keyUp:(NSEvent *)event
{
    [self doKey:event up:YES];
}

- (BOOL)canBecomeKeyView
{
    return YES;
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

@end

int main(int argc, char *argv[])
{
    NSApplication *app = [NSApplication sharedApplication];
    AppController *controller = [[[AppController alloc] init] autorelease];
    app.delegate = controller;
    return NSApplicationMain(argc, (const char **)argv);
}
