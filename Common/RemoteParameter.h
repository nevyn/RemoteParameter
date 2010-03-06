//
//  ParameterServer.h
//  ParameterClient
//
//  Created by Joachim Bengtsson on 2010-03-02.


#import <Foundation/Foundation.h>
#import "AsyncSocket.h"

const extern int ParameterServerPort;

@interface ParameterServer : NSObject {
	NSNetService *publisher;
	AsyncSocket *listenSocket;
	NSMutableArray *workers;
	NSMutableDictionary *vendedObjects;
}
+(id)server;
-(void)shareKeyPath:(NSString*)path ofObject:(id)object named:(NSString*)name;
-(void)stopSharingKeyPath:(NSString*)path ofObject:(id)object named:(NSString*)name;
@end

@interface NSObject (ParameterConvenience)
-(void)shareKeyPath:(NSString*)path as:(NSString*)objectName;
-(void)stopSharingKeyPath:(NSString*)path as:(NSString*)objectName;
@end


@class ParameterClient;
@protocol ParameterClientDelegate
-(void)parameterClient:(ParameterClient*)client receivedValue:(id)value forKeyPath:(NSString*)keyPath;
-(void)parameterClient:(ParameterClient*)client lostKeyPath:(NSString*)keyPath;
-(void)parameterClientDisconnected:(ParameterClient*)client;
@end


@interface ParameterClient : NSObject {
	id<NSObject, ParameterClientDelegate> delegate;
	AsyncSocket *socket;
	int commandLength;
}
@property (assign) id<NSObject, ParameterClientDelegate> delegate;
+(void)performSearchOnBrowser:(NSNetServiceBrowser*)browser;
-(id)initWithService:(NSNetService*)service;

-(void)setValue:(id)value forRemotePath:(NSString*)path;
@end