//
//  ParameterServer.m
//  ParameterClient
//
//  Created by Joachim Bengtsson on 2010-03-02.


#import "RemoteParameter.h"
#import <TargetConditionals.h>
#if !TARGET_OS_IPHONE
#import <SystemConfiguration/SystemConfiguration.h>
#endif


#define $dict(...) [NSDictionary dictionaryWithObjectsAndKeys:__VA_ARGS__, nil]
#define $cmd(commandName, ...) $dict(commandName, CommandName, __VA_ARGS__)

static ParameterServer *singleton = nil;
const int ParameterServerPort = 19437;
static NSString *BonjourType = @"_remoteprop._tcp.";

typedef enum {
	WaitForCommandLength,
	WaitForCommand,
} States;

static const NSString *CommandName = @"CommandName";

// Things sent from client to server
static NSString *SetValueOfObject = @"SetValueOfObject"; // => AvailableObject
	static NSString *SetObjectKeypath = @"ObjectKeypath";
	static NSString *SetObjectValue = @"ObjectValue";

// Things sent from server to client
static NSString *AvailableObject = @"AvailableObject";
	// Also sent on connect, and when a new object is added
	static NSString *ObjectKeypath = @"ObjectKeypath";
	static NSString *CurrentObjectValue = @"ObjectValue";
static NSString *UnavailableObject = @"UnavailableObject";
	static NSString *RemovedKeypath = @"ObjectKeypath";

@interface ParamServerWorker : NSObject
{
	ParameterServer *server;
	AsyncSocket *socket;
	
	int commandLength;
	NSDictionary *command;
}
-(id)initWithSocket:(AsyncSocket*)socket_ server:(ParameterServer*)server_;
@property (retain) AsyncSocket *socket;
@property (retain) NSDictionary *command;
-(void)sendReply:(id<NSCoding>)replyObject;
@end

@interface ParamVendedObject : NSObject
{
	id object;
	NSString *name;
	NSString *keypath;
}
@property (retain) id object;
@property (copy) NSString *name;
@property (copy) NSString *keypath;
@property (readonly) NSString *fullPath;
@end




@implementation ParameterServer
+(id)server;
{
	@synchronized(self) {
		if(!singleton)
			singleton = [[ParameterServer alloc] init];
	}
	return singleton;
}

-(id)init;
{
	vendedObjects = [NSMutableDictionary new];
	
	listenSocket = [[AsyncSocket alloc] initWithDelegate:self];
	[listenSocket setRunLoopModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	NSError *err;
	// TODO: Just find a free port and use that. Doesn't matter which.
	if(![listenSocket acceptOnPort:ParameterServerPort error:&err])
		NSLog(@"%@", err);
	
	workers = [[NSMutableArray alloc] init];
	
	NSString *deviceName = nil;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
		deviceName = [UIDevice currentDevice].name;
#else
		deviceName = [(id)SCDynamicStoreCopyComputerName(NULL,NULL) autorelease];
#endif
	
	NSString *name = [NSString stringWithFormat:@"%@: %@ <%d>",
		deviceName,
		[NSProcessInfo processInfo].processName,
		[NSProcessInfo processInfo].processIdentifier
	];

	publisher = [[NSNetService alloc] initWithDomain:@"" type:BonjourType name:name port:ParameterServerPort];
	[publisher publish];
	
	
	return self;
}

-(void)shareKeyPath:(NSString*)path ofObject:(id)object named:(NSString*)name;
{
	ParamVendedObject *vend = [[ParamVendedObject new] autorelease];
	vend.name = name;
	vend.object = object;
	vend.keypath = path;
	[vendedObjects setObject:vend forKey:vend.fullPath];
	
	[object addObserver:self
			 forKeyPath:path
				options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial
				context:NULL];
}
-(void)stopSharingKeyPath:(NSString*)path ofObject:(id)object named:(NSString*)name;
{
	NSString *fullPath = [name stringByAppendingFormat:@".%@", path];
	[vendedObjects setObject:nil forKey:fullPath];
	
	for (ParamServerWorker *worker in workers)
		[worker sendReply:$cmd(UnavailableObject,
			fullPath, RemovedKeypath
		)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	ParamVendedObject *found = nil;
	for (ParamVendedObject *vend in vendedObjects.allValues)
		if([vend.keypath isEqual:keyPath] && vend.object == object) {
			found = vend;
			break;
		}
	if(!found) {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
		return;
	}
	
	id currentValue = [change objectForKey:NSKeyValueChangeNewKey];
	
	for (ParamServerWorker *worker in workers)
		[worker sendReply:$cmd(AvailableObject, 
			found.fullPath, ObjectKeypath,
			currentValue, CurrentObjectValue
		)];
}



- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
	[newSocket setRunLoopModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
	ParamServerWorker *worker = [[[ParamServerWorker alloc] initWithSocket:newSocket server:self] autorelease];
	[workers addObject:worker];
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	NSLog(@"ParameterServer: listen socket error: %@", [err localizedDescription]);
}
-(void)newWorkerAvailable:(ParamServerWorker*)worker;
{
	for (ParamVendedObject *vend in vendedObjects.allValues)
		[worker sendReply:$cmd(AvailableObject,
			vend.fullPath, ObjectKeypath,
			[vend.object valueForKeyPath:vend.keypath], CurrentObjectValue
		)];
}
-(void)workerDied:(ParamServerWorker*)worker;
{
	[workers removeObject:worker];
}

-(void)handlePendingCommandOnWorker:(ParamServerWorker*)worker;
{
	NSString *command = [worker.command objectForKey:CommandName];
	if([command isEqual:SetValueOfObject]) {
		NSString *fullPath = [worker.command objectForKey:SetObjectKeypath];
		ParamVendedObject *vend = [vendedObjects objectForKey:fullPath];
		
		id incomingValue = [worker.command objectForKey:SetObjectValue];
		
		if(!vend || !incomingValue) return;
		
		[vend.object setValue:incomingValue forKeyPath:vend.keypath];
		
		id newValue = [vend.object valueForKeyPath:vend.keypath];
		
		for (ParamServerWorker *worker in workers)
			[worker sendReply:$cmd(AvailableObject,
				vend.fullPath, ObjectKeypath,
				newValue, CurrentObjectValue
			)];
	}
}
@end

@implementation ParamVendedObject
@synthesize object, name, keypath;
-(void)dealloc;
{
	self.object = self.name = self.keypath = nil;
	[super dealloc];
}
-(NSString*)fullPath;
{
	return [self.name stringByAppendingFormat:@".%@", keypath];
}

@end


@implementation ParamServerWorker
@synthesize command, socket;
-(id)initWithSocket:(AsyncSocket*)socket_ server:(ParameterServer*)server_;
{
	self.socket = socket_;
	socket.delegate = self;
	server = server_;
	
	return self;
}
-(void)dealloc;
{
	self.socket = nil;
	self.command = nil;
	[super dealloc];
}
- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	[server workerDied:self];
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	NSLog(@"ParameterServerWorker: server socket error: %@", [err localizedDescription]);
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	[server newWorkerAvailable:self];
	[sock readDataToLength:4 withTimeout:-1 tag:WaitForCommandLength];
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	switch (tag) {
		case WaitForCommandLength:
			[data getBytes:&commandLength length:4];
			commandLength = ntohl(commandLength);
			[sock readDataToLength:commandLength withTimeout:-1 tag:WaitForCommand];
			break;
		case WaitForCommand:
			self.command = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			[server handlePendingCommandOnWorker:self];
			self.command = nil;
			[sock readDataToLength:4 withTimeout:-1 tag:WaitForCommandLength];
			break;
	}
}
-(void)sendReply:(id<NSCoding>)replyObject;
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:replyObject];
	int length = [data length];
	length = htonl(length);
	[socket writeData:[NSData dataWithBytes:&length length:4] withTimeout:-1 tag:0];
	[socket writeData:data									  withTimeout:-1 tag:0];
}


@end
















@interface ParameterClient ()
@property (retain) AsyncSocket *socket;
-(void)sendReply:(id<NSCoding>)replyObject;
-(void)handleCommand:(NSDictionary*)cmd;
@end




@implementation ParameterClient
@synthesize delegate, socket;
+(void)performSearchOnBrowser:(NSNetServiceBrowser*)browser;
{
	[browser searchForServicesOfType:BonjourType inDomain:@""];
}
-(id)initWithService:(NSNetService*)service;
{
	self.socket = [[[AsyncSocket alloc] initWithDelegate:self] autorelease];
	[self.socket setRunLoopModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];

	NSError *err;
	if(![socket connectToAddress:[service.addresses objectAtIndex:0] error:&err]) {
		//[NSApp presentError:err];
		[self release];
		return nil;
	}
	
	return self;
}
-(void)dealloc;
{
	self.socket = nil;
	[super dealloc];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	[delegate parameterClientDisconnected:self];
	self.socket = nil;
}
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err;
{
	NSLog(@"ParameterClient: client socket error: %@", [err localizedDescription]);
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	[socket readDataToLength:4 withTimeout:-1 tag:WaitForCommandLength];
}
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	switch (tag) {
		case WaitForCommandLength:
			[data getBytes:&commandLength length:4];
			commandLength = ntohl(commandLength);
			[socket readDataToLength:commandLength withTimeout:-1 tag:WaitForCommand];
			break;
		case WaitForCommand: {
			NSDictionary *command = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			[self handleCommand:command];
			[socket readDataToLength:4 withTimeout:-1 tag:WaitForCommandLength];
			break;
		}
	}
}
-(void)sendReply:(id<NSCoding>)replyObject;
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:replyObject];
	int length = [data length];
	length = htonl(length);
	[socket writeData:[NSData dataWithBytes:&length length:4] withTimeout:-1 tag:0];
	[socket writeData:data									  withTimeout:-1 tag:0];
}

-(void)handleCommand:(NSDictionary*)cmd;
{
	NSString *command = [cmd objectForKey:CommandName];

	if([command isEqual:AvailableObject]) {
		NSString *fullPath = [cmd objectForKey:ObjectKeypath];
		id value = [cmd objectForKey:CurrentObjectValue];
		
		[delegate parameterClient:self receivedValue:value forKeyPath:fullPath];
	} else if([command isEqual:UnavailableObject]) {
		NSString *fullPath = [cmd objectForKey:RemovedKeypath];
		
		[delegate parameterClient:self lostKeyPath:fullPath];		
	}
}

-(void)setValue:(id)value forRemotePath:(NSString*)path;
{
	[self sendReply:$cmd(SetValueOfObject,
		path, SetObjectKeypath,
		value, SetObjectValue
	)];
}


@end


