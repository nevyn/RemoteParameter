//
//  Editors.m
//  ParameterServer
//
//  Created by Joachim Bengtsson on 2010-03-04.


#import "Editors.h"
#import "ClientController.h"

NSMutableDictionary *PSEditors;
static NSMutableDictionary *editors() {
	if(!PSEditors) PSEditors = [NSMutableDictionary new];
	return PSEditors;
}

@interface PSEditor ()
-(void)valueChanged:(id)value;
-(void)setup;
@end

@implementation PSEditor

-(id)initForIndex:(NSInteger)idx onObject:(id)object;
{
	if(![super initWithFrame:NSZeroRect]) return nil;
	
	parent = object;
	watchedIndex = idx;
	
	[self performSelector:@selector(setup) withObject:nil afterDelay:0];
	return self;
}
-(void)setup;
{
	[parent addObserver:self forKeyPath:@"values" options:NSKeyValueObservingOptionInitial context:NULL];
}
-(void)dealloc;
{
	[parent removeObserver:self forKeyPath:@"values"];
	[super dealloc];
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(object != parent || ![keyPath isEqual:@"values"])
		return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	
	NSKeyValueChange type = [[change objectForKey:NSKeyValueChangeKindKey] intValue];
	NSIndexSet *idxs = [change objectForKey:NSKeyValueChangeIndexesKey];
	
	if(type == NSKeyValueChangeRemoval) {
		NSUInteger lowerIndices = [idxs countOfIndexesInRange:NSMakeRange(0, watchedIndex)];
		watchedIndex -= lowerIndices;
		return;
	}
	if(type != NSKeyValueChangeReplacement && type != NSKeyValueChangeSetting) return;
	

	int idx = [idxs firstIndex];
	if(idx != watchedIndex && type != NSKeyValueChangeSetting) return;
	
	id value = [[object mutableArrayValueForKey:keyPath] objectAtIndex:watchedIndex];
	
	[self valueChanged:value];
}
-(void)valueChanged:(id)value;
{
	[NSException raise:NSInvalidArgumentException format:@"PSEditor subclasses must implement valueChanged"];
}
@end


@interface PSStringEditor : PSEditor
{
	NSTextField *field;
}
@end
@implementation PSStringEditor
+(void)load;
{
	[editors() setObject:self forKey:[NSString class]];
}
-(void)sendValue:(NSTextField*)sender;
{
	[parent sendChange:[sender stringValue] forKeyIndex:watchedIndex];
}
-(id)initForIndex:(NSInteger)idx onObject:(id)object;
{
	if(![super initForIndex:idx onObject:object]) return nil;
	
	field = [[[NSTextField alloc] initWithFrame:(NSRect){.origin={0,0}, .size=self.frame.size}] autorelease];
	[self addSubview:field];
	[field setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[field setTarget:self];
	[field setAction:@selector(sendValue:)];
	
	
	return self;
}
-(void)valueChanged:(id)value;
{
	field.stringValue = value;
}

@end

@interface PSNumberEditor : PSEditor
{
	NSSlider *slider;
	NSTextField *current;
	NSTextField *max;
	NSTextField *min;
	NSButton *continuous;
}
@end

@implementation PSNumberEditor
+(void)load;
{
	[editors() setObject:self forKey:[NSNumber class]];
}
-(void)sendValue:(id)sender;
{
	[parent sendChange:[NSNumber numberWithDouble:[sender doubleValue]]
		   forKeyIndex:watchedIndex];
}
-(void)setMin:(id)sender;
{
	[slider setMinValue:[sender floatValue]];
}
-(void)setMax:(id)sender;
{
	[slider setMaxValue:[sender floatValue]];
}
-(void)setContinuous:(id)sender;
{
	[slider setContinuous:[sender state]];
}
-(id)initForIndex:(NSInteger)idx onObject:(id)object;
{
	if(![super initForIndex:idx onObject:object]) return nil;
	
	self.frame = (NSRect){.size = {200, 100}};
	
	slider = [[[NSSlider alloc] initWithFrame:NSMakeRect(50, 10, 100, 20)] autorelease];
	[slider setAutoresizingMask:NSViewWidthSizable];
	[self addSubview:slider];
	[slider setTarget:self];
	[slider setAction:@selector(sendValue:)];
	
	current = [[[NSTextField alloc] initWithFrame:NSMakeRect(50, 30, 100, 20)] autorelease];
	[current setAutoresizingMask:NSViewWidthSizable];
	[self addSubview:current];
	[current setTarget:self];
	[current setAction:@selector(sendValue:)];

	min = [[[NSTextField alloc] initWithFrame:NSMakeRect(10, 10, 30, 20)] autorelease];
	[self addSubview:min];
	[min setTarget:self];
	[min setAction:@selector(setMin:)];
	[min setFloatValue:slider.minValue];

	max = [[[NSTextField alloc] initWithFrame:NSMakeRect(160, 10, 30, 20)] autorelease];
	[max setAutoresizingMask:NSViewMinXMargin];
	[self addSubview:max];
	[max setTarget:self];
	[max setAction:@selector(setMax:)];
	[max setFloatValue:slider.maxValue];
	
	continuous = [[[NSButton alloc] initWithFrame:NSMakeRect(50, 50, 100, 20)] autorelease];
	[continuous setButtonType:NSSwitchButton];
	[continuous setTitle:@"Continuous"];
	[self addSubview:continuous];
	[continuous setTarget:self];
	[continuous setAction:@selector(setContinuous:)];
	[continuous setState:[slider isContinuous]];
	
	
	return self;
}
-(void)valueChanged:(id)value;
{
	slider.objectValue = value;
	current.objectValue = value;
}

@end


@interface PSColorEditor : PSEditor
{
	NSColorWell *well;
}
@end
@implementation PSColorEditor
+(void)load;
{
	[editors() setObject:self forKey:[NSColor class]];
}
-(void)sendValue:(NSColorWell*)sender;
{
	[parent sendChange:[sender color] forKeyIndex:watchedIndex];
}
-(id)initForIndex:(NSInteger)idx onObject:(id)object;
{
	if(![super initForIndex:idx onObject:object]) return nil;
	
	well = [[[NSColorWell alloc] initWithFrame:(NSRect){.origin={0,0}, .size=self.frame.size}] autorelease];
	[self addSubview:well];
	[well setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[well setTarget:self];
	[well setAction:@selector(sendValue:)];
	
	
	return self;
}
-(void)valueChanged:(id)value;
{
	well.color = value;
}

@end
