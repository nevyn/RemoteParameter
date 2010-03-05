//
//  ParameterClientViewController.m
//  ParameterClient
//
//  Created by Joachim Bengtsson on 2010-03-02.


#import "ParamViewController.h"
#import "RemoteParameter.h"

@implementation ParamViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	
	[[ParameterServer server] shareKeyPath:@"backgroundColor" ofObject:colorView named:@"colorView"];
	[[ParameterServer server] shareKeyPath:@"text" ofObject:label named:@"label"];
	[[ParameterServer server] shareKeyPath:@"value" ofObject:slider named:@"slider"];
	
}


- (void)dealloc {
    [super dealloc];
}

@end
