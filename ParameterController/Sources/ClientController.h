//
//  ClientController.h
//  ParameterServer
//
//  Created by Joachim Bengtsson on 2010-03-03.


#import <Cocoa/Cocoa.h>
#import "RemoteParameter.h"


@interface ClientController : NSWindowController
<ParameterClientDelegate>
{
	ParameterClient *client;
	NSMutableArray *keys;
	NSMutableArray *values;
	IBOutlet NSTableView *tableView;
	IBOutlet NSView *editContainer;
	int oldIndex;
}
@property (readonly, retain) ParameterClient *client;
-(id)initWithClient:(ParameterClient*)client_;
-(void)sendChange:(id)newValue forKeyIndex:(NSUInteger)index;
@end
