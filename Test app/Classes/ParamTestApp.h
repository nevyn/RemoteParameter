//
//  ParameterClientAppDelegate.h
//  ParameterClient
//
//  Created by Joachim Bengtsson on 2010-03-02.


#import <UIKit/UIKit.h>

@class ParamViewController;

@interface ParamTestApp : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    ParamViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet ParamViewController *viewController;

@end

