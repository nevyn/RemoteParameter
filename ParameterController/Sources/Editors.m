//
//  Editors.m
//  ParameterServer
//
//  Created by Joachim Bengtsson on 2010-03-04.


#import "Editors.h"
#import "ClientController.h"
#import <QuartzCore/QuartzCore.h>

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


@interface RectControl : NSControl
{
	CALayer *rect;
	BOOL isMoving;
	
	CALayer *resizeLayer;
	CALayer *tl, *tr, *bl, *br;
}
@end
@implementation RectControl
+ (Class) cellClass { return [NSActionCell class]; }

-(id)initWithFrame:(NSRect)r;
{
	if(![super initWithFrame:r]) return nil;
	
	[self setWantsLayer:YES];
	self.layer = [CALayer layer];
	self.layer.geometryFlipped = YES;
	rect = [CALayer layer];
	rect.frame = CGRectMake(0, 0, 20, 20);
	[self.layer addSublayer:rect];
	rect.backgroundColor = (CGColorRef)[(id)CGColorCreateGenericRGB(.4, .5, .4, .9) autorelease];
	
	tl = [CALayer layer]; tl.frame = CGRectMake(-5, -5, 10, 10);
		[rect addSublayer:tl]; tl.autoresizingMask = kCALayerMaxXMargin|kCALayerMaxYMargin;
	tr = [CALayer layer]; tr.frame = CGRectMake(15, -5, 10, 10);
		[rect addSublayer:tr]; tr.autoresizingMask = kCALayerMinXMargin|kCALayerMaxYMargin;
	bl = [CALayer layer]; bl.frame = CGRectMake(-5, 15, 10, 10);
		[rect addSublayer:bl]; bl.autoresizingMask = kCALayerMaxXMargin|kCALayerMinYMargin;
	br = [CALayer layer]; br.frame = CGRectMake(15, 15, 10, 10);
		[rect addSublayer:br]; br.autoresizingMask = kCALayerMinXMargin|kCALayerMinYMargin;
	tl.backgroundColor = tr.backgroundColor = bl.backgroundColor = br.backgroundColor = 
		(CGColorRef)[(id)CGColorCreateGenericRGB(.4, .4, .6, .9) autorelease];
	
	return self;
}
-(NSRect)rect;
{
	return NSRectFromCGRect(rect.frame);
}
-(void)setRect:(NSRect)r;
{
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	rect.frame = NSRectToCGRect(r);
	[CATransaction commit];
}

-(void)mouseDown:(NSEvent *)evt;
{
	NSPoint win = [evt locationInWindow];
	CGPoint loc = NSPointToCGPoint([self convertPoint:win fromView:nil]);

	isMoving = NO;
	resizeLayer = nil;

	// This must be a bug in hitTest...
	loc.y = self.frame.size.height - loc.y;
	CALayer *hit = [self.layer hitTest:loc];
	if(hit != self.layer) {
		loc.y = self.frame.size.height - loc.y;
		
		if(hit == rect)
			isMoving = YES;
		else {
			resizeLayer = hit;
			return;
		}
			
		CGPoint rel = [self.layer convertPoint:loc toLayer:hit];
		[CATransaction begin];
		[CATransaction setDisableActions:YES];

		hit.anchorPoint = (CGPoint){rel.x/hit.frame.size.width, rel.y/hit.frame.size.height};
		hit.position = loc;
		
		[CATransaction commit];
	}
}
-(void)mouseDragged:(NSEvent*)evt;
{
	
	NSPoint win = [evt locationInWindow];
	CGPoint loc = NSPointToCGPoint([self convertPoint:win fromView:nil]);
	
	BOOL somethingChanged = YES;
	
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	
	if(isMoving)
		rect.position = loc;
	else if(resizeLayer) {
		CGPoint oldLoc = resizeLayer.position;
			oldLoc.x += rect.frame.origin.x; oldLoc.y += rect.frame.origin.y;
			
		CGSize diff = {loc.x - oldLoc.x, loc.y - oldLoc.y};

		CGRect r = rect.frame;
		if(resizeLayer == tl) {
			r.origin = loc;
			r.size = (CGSize){r.size.width - diff.width, r.size.height - diff.height};
		} else if(resizeLayer == br) {
			r.size = (CGSize){r.size.width + diff.width, r.size.height + diff.height};
		} else if(resizeLayer == tr) {
			r.size.width += diff.width;
			r.size.height -= diff.height;
			r.origin.y += diff.height;
		} else if(resizeLayer == bl) {
			r.size.width -= diff.width;
			r.size.height += diff.height;
			r.origin.x += diff.width;
		}
		
		rect.frame = r;
	} else
			somethingChanged = NO;
	
	[CATransaction commit];
	
	if(somethingChanged)
		[self sendAction:self.action to:self.target];
}
-(void)mouseUp:(NSEvent *)evt
{

}
-(BOOL)isFlipped;
{
	return YES;
}
-(BOOL)acceptsFirstMouse:(NSEvent *)theEvent
{
	return YES;
}
@end



@interface PSRectEditor : PSEditor
{
	RectControl *rect;
}
@end
@implementation PSRectEditor
+(void)load;
{
	[editors() setObject:self forKey:NSClassFromString(@"NSConcreteValue")];
}
-(void)sendValue:(RectControl*)sender;
{
	[parent sendChange:[NSValue valueWithRect:[sender rect]] forKeyIndex:watchedIndex];
}
-(id)initForIndex:(NSInteger)idx onObject:(id)object;
{
	if(![super initForIndex:idx onObject:object]) return nil;
	
	rect = [[[RectControl alloc] initWithFrame:(NSRect){.origin={0,0}, .size=self.frame.size}] autorelease];
	[self addSubview:rect];
	[rect setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
	[rect setTarget:self];
	[rect setAction:@selector(sendValue:)];
	
	
	return self;
}
-(void)valueChanged:(id)value;
{
	rect.rect = [value rectValue];
}

@end
