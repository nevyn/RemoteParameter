//
//  ParameterClientAppDelegate.m
//  ParameterClient
//
//  Created by Joachim Bengtsson on 2010-03-02.


#import "ParamTestApp.h"
#import "ParamViewController.h"

@implementation ParamTestApp

@synthesize window;
@synthesize viewController;


- (void)applicationDidFinishLaunching:(UIApplication *)application {    
    
    // Override point for customization after app launch    
    [window addSubview:viewController.view];
    [window makeKeyAndVisible];
}


- (void)dealloc {
    [viewController release];
    [window release];
    [super dealloc];
}


@end
