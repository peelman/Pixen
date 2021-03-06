//
//  PXTool.h
//  Pixen-XCode
//
//  Created by Joe Osborn on Sat Dec 06 2003.
//  Copyright (c) 2003 Pixen. All rights reserved.
//

#import "PXColor.h"
#import "PXCanvasController.h"

@class PXToolSwitcher, PXToolPropertiesController, PXPattern, PXCanvas;

@interface PXTool : NSObject 
{
  @private
	BOOL isClicking;
	NSBezierPath *path;
	NSBezierPath *wrappedPath;
	PXToolSwitcher *switcher;
	PXToolPropertiesController *propertiesController;
	PXColor color;
	BOOL initialLoad;
}

@property (nonatomic, assign) BOOL isClicking;
@property (nonatomic, retain) NSBezierPath *path;
@property (nonatomic, retain) NSBezierPath *wrappedPath;
@property (nonatomic, assign) PXToolSwitcher *switcher;
@property (nonatomic, assign) PXColor color;

@property (nonatomic, readonly) PXToolPropertiesController *propertiesController;

- (NSString *)name;

- (PXToolPropertiesController *)createPropertiesController;

- (void)mouseDownAt:(NSPoint)aPoint
fromCanvasController:(PXCanvasController *)controller;

- (void)mouseDraggedFrom:(NSPoint)origin
					  to:(NSPoint)destination
	fromCanvasController:(PXCanvasController *)controller;

- (void)mouseUpAt:(NSPoint)point
fromCanvasController:(PXCanvasController *)controller;

- (void)mouseMovedTo:(NSPoint)aPoint
fromCanvasController:(PXCanvasController *)controller;

- (void)keyDown:(NSEvent *)event fromCanvasController:(PXCanvasController *)cc;

- (NSRect)crosshairRectCenteredAtPoint:(NSPoint)aPoint;

- (PXColor)colorForCanvas:(PXCanvas *)canvas;

- (NSCursor *)cursor;

- (BOOL)shiftKeyDown;
- (BOOL)shiftKeyUp;
- (BOOL)optionKeyDown;
- (BOOL)optionKeyUp;
- (BOOL)commandKeyDown;
- (BOOL)commandKeyUp;

- (void)clearBezier;
- (BOOL)shouldUseBezierDrawing;
- (BOOL)supportsPatterns;

- (void)setPattern:(PXPattern *)pattern;

@end
