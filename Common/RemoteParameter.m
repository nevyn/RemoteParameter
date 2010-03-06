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

#pragma mark 
#pragma mark Common
#pragma mark -

#define $dict(...) [NSDictionary dictionaryWithObjectsAndKeys:__VA_ARGS__, nil]
#define $cmd(commandName, ...) $dict(commandName, CommandName, __VA_ARGS__)

static NSMutableDictionary *_portableClasses;
static NSMutableDictionary *portableClasses() {
	if(!_portableClasses) _portableClasses = [NSMutableDictionary new];
	return _portableClasses;
}

@interface PortableColor : NSObject
	<NSCoding>
{
	CGFloat r, g, b, a;
}
-(id)initWithNativeValue:(id)nativeColor;
-(id)nativeValue;
@end
@implementation PortableColor
+(void)load;
{
#if !TARGET_OS_IPHONE
	[portableClasses() setObject:[PortableColor class] forKey:[NSColor class]];
#else
	[portableClasses() setObject:[PortableColor class] forKey:[UIColor class]];
#endif
}
-(id)initWithNativeValue:(id)nativeColor;
{
#if !TARGET_OS_IPHONE
	NSColor *color = nativeColor;
	[color getRed:&r green:&g blue:&b alpha:&a];
#else
	UIColor *color = nativeColor;
	CGColorRef cgcolor = color.CGColor;
	if(CGColorGetNumberOfComponents(cgcolor) != 4) {
		[self release];
		return nil;
	}
	memcpy(&r, CGColorGetComponents(cgcolor), sizeof(float)*4);
#endif
	return self;
}
-(id)nativeValue;
{
#if !TARGET_OS_IPHONE
	return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
#else
	return [UIColor colorWithRed:r green:g blue:b alpha:a];
#endif
}
- (void)encodeWithCoder:(NSCoder *)coder;
{
	[coder encodeFloat:r forKey:@"r"];
	[coder encodeFloat:g forKey:@"g"];
	[coder encodeFloat:b forKey:@"b"];
	[coder encodeFloat:a forKey:@"a"];
}
- (id)initWithCoder:(NSCoder *)decoder;
{
	r = [decoder decodeFloatForKey:@"r"];
	g = [decoder decodeFloatForKey:@"g"];
	b = [decoder decodeFloatForKey:@"b"];
	a = [decoder decodeFloatForKey:@"a"];
	return self;
}
@end



@interface PortableValue : NSObject
	<NSCoding>
{
#if !TARGET_OS_IPHONE
	NSRect r;
#else
	CGRect r;
#endif
}
-(id)initWithNativeValue:(id)nativeValue;
-(id)nativeValue;
@end
@implementation PortableValue
+(void)load;
{
	[portableClasses() setObject:[PortableValue class] forKey:[NSValue class]];
}
-(id)initWithNativeValue:(id)nativeValue;
{
#if !TARGET_OS_IPHONE
	if(strcmp([nativeValue objCType],@encode(NSRect)) == NSOrderedSame) {
		r = [nativeValue rectValue];
	} else {
		[self release];
		return [nativeValue retain];
	}

#else
	if(strcmp([nativeValue objCType],@encode(CGRect)) == NSOrderedSame) {
		r = [nativeValue CGRectValue];
	} else {
		[self release];
		return [nativeValue retain];
	}

#endif

	return self;
}
-(id)nativeValue;
{
#if !TARGET_OS_IPHONE
	return [NSValue valueWithRect:r];
#else
	return [NSValue valueWithCGRect:r];
#endif
}
- (void)encodeWithCoder:(NSCoder *)coder;
{
	[coder encodeFloat:r.origin.x forKey:@"origin.x"];
	[coder encodeFloat:r.origin.y forKey:@"origin.y"];
	[coder encodeFloat:r.size.width forKey:@"size.width"];
	[coder encodeFloat:r.size.height forKey:@"size.height"];
}
- (id)initWithCoder:(NSCoder *)decoder;
{
	r.origin.x = [decoder decodeFloatForKey:@"origin.x"];
	r.origin.y = [decoder decodeFloatForKey:@"origin.y"];
	r.size.width = [decoder decodeFloatForKey:@"size.width"];
	r.size.height = [decoder decodeFloatForKey:@"size.height"];
	return self;
}
@end






id makePortable(id obj)
{
	for (Class nativeClass in portableClasses().allKeys)
		if([obj isKindOfClass:nativeClass])
			return [[[[portableClasses() objectForKey:nativeClass] alloc] initWithNativeValue:obj] autorelease];
	
	return obj;
}

id makeNative(id obj)
{
	if([obj respondsToSelector:@selector(nativeValue)])
		return [obj nativeValue];
	else
		return obj;
}


#pragma mark 
#pragma mark Server
#pragma mark -

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
	
	id currentValue = makePortable([change objectForKey:NSKeyValueChangeNewKey]);
	
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
			makePortable([vend.object valueForKeyPath:vend.keypath]), CurrentObjectValue
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
		
		id incomingValue = makeNative([worker.command objectForKey:SetObjectValue]);
		
		if(!vend || !incomingValue) return;
		
		[vend.object setValue:incomingValue forKeyPath:vend.keypath];
		
		id newValue = makePortable([vend.object valueForKeyPath:vend.keypath]);
		
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



@implementation NSObject (ParameterConvenience)
-(void)shareKeyPath:(NSString*)path as:(NSString*)objectName;
{
	[[ParameterServer server] shareKeyPath:path ofObject:self named:objectName];
}
-(void)stopSharingKeyPath:(NSString*)path as:(NSString*)objectName;
{
	[[ParameterServer server] stopSharingKeyPath:path ofObject:self named:objectName];
}
@end






#pragma mark
#pragma mark Client
#pragma mark -







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
		id value = makeNative([cmd objectForKey:CurrentObjectValue]);
		
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
		makePortable(value), SetObjectValue
	)];
}


@end


