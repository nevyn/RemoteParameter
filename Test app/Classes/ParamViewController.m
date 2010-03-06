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
	
	[colorView shareKeyPath:@"backgroundColor" as:@"colorView"];
	[colorView shareKeyPath:@"frame" as:@"colorView"];
	[segmented shareKeyPath:@"selectedSegmentIndex" as:@"segment"];
	[label shareKeyPath:@"text" as:@"label"];
	[slider shareKeyPath:@"value" as:@"slider"];
	[slider shareKeyPath:@"frame" as:@"slider"];
	
}

- (void)dealloc {
    [super dealloc];
}

@end
