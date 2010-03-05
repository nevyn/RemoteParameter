//
//  ClientController.m
//  ParameterServer
//
//  Created by Joachim Bengtsson on 2010-03-03.


#import "ClientController.h"
#import "Editors.h"


@interface ClientController ()
@property (readwrite, retain) ParameterClient *client;
@end


@implementation ClientController
@synthesize client;

-(id)initWithClient:(ParameterClient*)client_;
{
	if(![super initWithWindowNibName:@"ClientController"])
		return nil;
	keys = [NSMutableArray new];
	values = [NSMutableArray new];
	
	self.client = client_;
	self.client.delegate = self;
	
	oldIndex = -1;
	
	return self;
}
-(void)dealloc;
{
	self.client = nil;
	[keys release]; [values release];
	[super dealloc];
}

-(void)parameterClient:(ParameterClient*)client receivedValue:(id)value forKeyPath:(NSString*)keyPath;
{
	NSMutableArray *keym = [self mutableArrayValueForKey:@"keys"];
	NSMutableArray *valm = [self mutableArrayValueForKey:@"values"];
	
	NSInteger idx = [keym indexOfObject:keyPath];
	if(idx == NSNotFound) {
		[keym addObject:keyPath];
		[valm addObject:value];
	} else {
		[valm replaceObjectAtIndex:idx withObject:value];
	}
}
-(void)parameterClient:(ParameterClient*)client lostKeyPath:(NSString*)keyPath;
{
	NSMutableArray *keym = [self mutableArrayValueForKey:@"keys"];
	NSMutableArray *valm = [self mutableArrayValueForKey:@"values"];
	
	NSInteger idx = [keym indexOfObject:keyPath];
	if(idx == NSNotFound) return;
	[keym removeObjectAtIndex:idx];
	[valm removeObjectAtIndex:idx];	
}
-(void)parameterClientDisconnected:(ParameterClient*)client;
{
	[self close];
}
- (void)tableViewSelectionDidChange:(NSNotification *)notification;
{
	int idx = [tableView selectedRow];
	if(idx == oldIndex) return;
	oldIndex = idx;
	[[editContainer subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	if(idx == -1)
		return;
	
	id val = [values objectAtIndex:idx];
	NSLog(@"%@ %@", [val class], val);
	
	NSView *editor = nil;
	for (Class valClass in PSEditors.allKeys)
		if([val isKindOfClass:valClass])
			editor = [[[[PSEditors objectForKey:valClass] alloc] initForIndex:idx onObject:self] autorelease];
	
	if(!editor) {
		NSTextField *label = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
		[label setStringValue:[val description]];
		[label setEditable:NO];
		[label setDrawsBackground:NO];
		[label setSelectable:YES];
		[label setBordered:YES];
		editor = label;
	}
	editor.frame = (NSRect){.origin={0,0}, .size=editContainer.frame.size};
	[editor setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[editContainer addSubview:editor];
}
-(void)sendChange:(id)newValue forKeyIndex:(NSUInteger)index;
{
	NSString *key = [keys objectAtIndex:index];
	[client setValue:newValue forRemotePath:key];
}
@end
