//
//  Editors.h
//  ParameterServer
//
//  Created by Joachim Bengtsson on 2010-03-04.


#import <Cocoa/Cocoa.h>

extern NSMutableDictionary *PSEditors;

@interface PSEditor : NSView
{
	NSInteger watchedIndex;
	id parent;
}
-(id)initForIndex:(NSInteger)idx onObject:(id)object;
@end
