//
//  ParameterControllerAppDelegate.h
//  ParameterController
//
//  Created by Joachim Bengtsson on 2010-03-02.


#import <Cocoa/Cocoa.h>
#import "RemoteParameter.h"

@interface ParameterControllerAppDelegate : NSObject
	<NSApplicationDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate>
{
    NSWindow *window;
	NSNetServiceBrowser *browser;
	NSMutableArray *foundServices; // <NSNetService>
	IBOutlet NSTableView *tableView;
}

@property (assign) IBOutlet NSWindow *window;

-(IBAction)connect:(NSTableView*)sender;

@end
