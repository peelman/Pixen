//
//  PXCanvas_Modifying.m
//  Pixen
//
//  Created by Joe Osborn on 2005.07.31.
//  Copyright 2005 Pixen. All rights reserved.
//

#import "PXCanvas_Modifying.h"

#import "NSString_DegreeString.h"
#import "PXCanvas_ImportingExporting.h"
#import "PXCanvas_Layers.h"
#import "PXCanvas_Selection.h"
#import "PXLayer.h"
#import "gif_lib.h"

@implementation PXCanvas(Modifying)

NSUInteger PointSizeF (const void *item);

- (BOOL)wraps
{
	return wraps;
}

- (void)setWraps:(BOOL)newWraps suppressRedraw:(BOOL)suppress
{
	wraps = newWraps;
	if (!suppress)
		[self changed];	
}

- (void)setWraps:(BOOL)newWraps
{
	[self setWraps:newWraps suppressRedraw:NO];
}

- (BOOL)containsPoint:(NSPoint)aPoint
{
	return wraps || NSPointInRect(aPoint, canvasRect);
}

- (NSPoint)correct:(NSPoint)aPoint
{
	if(!wraps) { return aPoint; }
	NSPoint corrected = aPoint;
	while(corrected.x < 0)
	{
		corrected.x += [self size].width;
	}
	while(corrected.y < 0)
	{
		corrected.y += [self size].height;
	}
	corrected.x = (int)(corrected.x) % (int)([self size].width);
	corrected.y = (int)(corrected.y) % (int)([self size].height);
	return corrected;	
}

- (void)setColor:(PXColor)color atPoint:(NSPoint)aPoint
{
	if (![self containsPoint:aPoint])
		return;
	
	[self setColor:color atPoint:[self correct:aPoint] onLayer:activeLayer];
}

- (void)setColor:(PXColor)color atPoint:(NSPoint)aPoint onLayer:(PXLayer *)layer
{
	PXColor down = [layer colorAtPoint:aPoint];
	
	if (!PXColorEqualsColor(down, color)) {
		[_minusColors addObject:PXColorToNSColor(down)];
		[_plusColors addObject:PXColorToNSColor(color)];
		
		[layer setColor:color atPoint:aPoint];
	}
}

- (void)setColor:(PXColor)color atIndices:(NSArray *)indices updateIn:(NSRect)bounds onLayer:(PXLayer *)layer
{
	if ([indices count] == 0)
		return;
	
	[self beginColorUpdates];
	
	for (NSNumber *current in indices)
	{
		int val = [current intValue];
		int x = val % (int)[self size].width;
		int y = [self size].height - ((val - x)/[self size].width) - 1;
		PXColor oldColor = [layer colorAtIndex:val];
		NSPoint pt = NSMakePoint(x, y);
		[self bufferUndoAtPoint:pt fromColor:oldColor toColor:color];
		[self setColor:color atPoint:pt onLayer:layer];
	}
	
	[self changedInRect:bounds];
	[self endColorUpdates];
}

- (void)setColor:(PXColor)color atIndices:(NSArray *)indices updateIn:(NSRect)bounds
{
	[self setColor:color atIndices:indices updateIn:bounds onLayer:activeLayer];
}

- (PXColor)mergedColorAtPoint:(NSPoint)aPoint
{
	PXColor currentColor = PXGetClearColor();
	
	for (PXLayer *layer in layers)
	{
		if ([layer visible] && [layer opacity] > 0)
		{
			PXColor layerColor = [layer colorAtPoint:aPoint];
			layerColor.a *= ([layer opacity] / 100.0f);
			
			currentColor = PXColorBlendWithColor(currentColor, layerColor);
		}
	}
	
	return currentColor;
}


- (PXColor)surfaceColorAtPoint:(NSPoint)aPoint
{
	for (PXLayer *layer in [layers reverseObjectEnumerator])
	{
		if ([layer visible] && [layer opacity] > 0)
		{
			PXColor layerColor = [layer colorAtPoint:aPoint];
			
			if (layerColor.a > 0)
			{
				return layerColor;
			}
		}
	}
	
	return PXGetClearColor();
}

- (PXColor)colorAtPoint:(NSPoint)aPoint
{
	if (![self containsPoint:aPoint]) {
		NSAssert(0, @"[PXCanvas colorAtPoint:] - no canvas (this should never execute)");
	}
	
	return [activeLayer colorAtPoint:aPoint];
}

- (void)rotateByDegrees:(int)degrees
{
	[self beginUndoGrouping];
    for (PXLayer *current in layers)
    {
        [self rotateLayer:current byDegrees:degrees];
    }
    [self endUndoGrouping:[NSString stringWithFormat:NSLocalizedString(@"Rotate %d%@", @"Rotate %d%@"), degrees, [NSString degreeString]]];
}

- (void)changed
{
	[self changedInRect:NSMakeRect(0,0,[self size].width,[self size].height)];
}

- (void)changedInRect:(NSRect)rect
{
	if(NSEqualSizes([self size], NSZeroSize) || NSEqualRects(rect, NSZeroRect)) { return; }
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  [NSValue valueWithRect:rect],
						  PXChangedRectKey, 
						  activeLayer, PXActiveLayerKey, 
						  nil];
	
	[nc postNotificationName:PXCanvasChangedNotificationName
					  object:self
					userInfo:dict];
}

- (BOOL)canDrawAtPoint:(NSPoint)aPoint
{
	if ([self hasSelection])
	{
		if (![self pointIsSelected:aPoint])
			return NO;
	}
	
	if (!NSPointInRect(aPoint, canvasRect))
		return NO;
	
	return YES;
}

- (void)flipHorizontally
{
	[self beginUndoGrouping];
    for (PXLayer *current in layers)
    {
        [self flipLayerHorizontally:current];
    }
    [self endUndoGrouping:NSLocalizedString(@"Flip Canvas Horizontally", @"Flip Canvas Horizontally")];
}

- (void)flipVertically
{
	[self beginUndoGrouping];
    for (PXLayer *current in layers)
    {
        [self flipLayerVertically:current];
    }
	[self endUndoGrouping:NSLocalizedString(@"Flip Canvas Vertically", @"Flip Canvas Vertically")];
}

- (void)reduceColorsTo:(int)colors withTransparency:(BOOL)transparency matteColor:(NSColor *)matteColor
{
	[PXCanvas reduceColorsInCanvases:[NSArray arrayWithObject:self] 
						toColorCount:colors
					withTransparency:transparency 
						  matteColor:matteColor];
}

+ (void)reduceColorsInCanvases:(NSArray *)canvases toColorCount:(int)colors withTransparency:(BOOL)transparency matteColor:(NSColor *)matteColor
{
	PXCanvas *first = [canvases objectAtIndex:0];
	unsigned char *red = calloc([first size].width * [first size].height * [canvases count], sizeof(unsigned char));
	unsigned char *green = calloc([first size].width * [first size].height * [canvases count], sizeof(unsigned char));
	unsigned char *blue = calloc([first size].width * [first size].height * [canvases count], sizeof(unsigned char));
	int i;
	int quantizedPixels = 0;
	
	for (id current in canvases)
	{
		if(!NSEqualSizes([first size], [current size]))
		{
			[NSException raise:@"Reduction Exception" format:@"Canvas sizes not equal!"];
		}
		NSImage *image = [[[current displayImage] copy] autorelease];
		id bitmapRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
		unsigned char *bitmapData = [bitmapRep bitmapData];
		
		if ([bitmapRep samplesPerPixel] == 3)
		{
			for (i = 0; i < [image size].width * [image size].height; i++)
			{
				int base = (i * 3);
				red[quantizedPixels + i] = bitmapData[base + 0];
				green[quantizedPixels + i] = bitmapData[base + 1];
				blue[quantizedPixels + i] = bitmapData[base + 2];
			}
			quantizedPixels += [image size].width * [image size].height;
		}
		else
		{
			for (i = 0; i < [image size].width * [image size].height; i++)
			{
				int base = (i * 4);
				if (bitmapData[base + 3] == 0 && transparency) { continue; }
				if (bitmapData[base + 3] < 255 && matteColor)
				{
					NSColor *sourceColor = [NSColor colorWithCalibratedRed:bitmapData[base + 0] / 255.0f green:bitmapData[base + 1] / 255.0f blue:bitmapData[base + 2] / 255.0f alpha:1];
					NSColor *resultColor = [matteColor blendedColorWithFraction:(bitmapData[base + 3] / 255.0f) ofColor:sourceColor];
					red[quantizedPixels] = (int) roundf([resultColor redComponent] * 255);
					green[quantizedPixels] = (int) roundf([resultColor greenComponent] * 255);
					blue[quantizedPixels] = (int) roundf([resultColor blueComponent] * 255);
				}
				else
				{
					red[quantizedPixels] = bitmapData[base + 0];
					green[quantizedPixels] = bitmapData[base + 1];
					blue[quantizedPixels] = bitmapData[base + 2];
				}
				quantizedPixels++;
			}
		}
	}
	
	GifColorType *map = malloc(sizeof(GifColorType) * 256);
	int size = colors - (transparency ? 1 : 0);
	unsigned char *output = malloc(sizeof(unsigned char*) * [first size].width * [first size].height * [canvases count]);
	if (quantizedPixels)
		QuantizeBuffer(quantizedPixels, &size, red, green, blue, output, map);
	//NSLog(@"Quantized to %d colors", size);
	
	PXPalette *palette = [[PXPalette alloc] init];
	for (i = 0; i < size; i++)
	{
		[palette addColor:[NSColor colorWithCalibratedRed:map[i].Red / 255.0f green:map[i].Green / 255.0f blue:map[i].Blue / 255.0f alpha:1]];
	}
	
	if (transparency)
		[palette addColorWithoutDuplicating:[[NSColor clearColor] colorUsingColorSpaceName:NSCalibratedRGBColorSpace]];
	
	for (id current in canvases)
	{
		for (id currentLayer in [current layers])
		{
			[currentLayer adaptToPalette:palette withTransparency:transparency matteColor:matteColor];
		}
		[current refreshWholePalette];
		[current changed];
	}
	
	free(red); free(green); free(blue); free(output); free(map);
	[palette release];
}

NSUInteger PointSizeF (const void *item) {
	return sizeof(NSPoint);
}

- (void)clearUndoBuffers
{
	NSPointerFunctionsOptions options = (NSPointerFunctionsStructPersonality|NSPointerFunctionsMallocMemory|NSPointerFunctionsCopyIn);
	
	NSPointerFunctions *pointF = [NSPointerFunctions pointerFunctionsWithOptions:options];
	[pointF setSizeFunction:&PointSizeF];
	
	[_drawnPoints release];
	_drawnPoints = [[NSPointerArray alloc] initWithPointerFunctions:pointF];
	
	PXColorArrayRelease(_oldColors);
	_oldColors = PXColorArrayCreate();
	
	PXColorArrayRelease(_newColors);
	_newColors = PXColorArrayCreate();
}

- (void)registerForUndo
{
	[self registerForUndoWithDrawnPoints:_drawnPoints
							   oldColors:_oldColors
							   newColors:_newColors
								 inLayer:[self activeLayer] 
								 undoing:NO];
}

- (void)registerForUndoWithDrawnPoints:(NSPointerArray *)points oldColors:(PXColorArrayRef)oldColors
							 newColors:(PXColorArrayRef)newColors inLayer:(PXLayer *)layer
							   undoing:(BOOL)undoing
{
	PXColorArrayRetain(newColors);
	PXColorArrayRetain(oldColors);
	
	[[[self undoManager] prepareWithInvocationTarget:self] registerForUndoWithDrawnPoints:points
																				oldColors:newColors
																				newColors:oldColors
																				  inLayer:layer
																				  undoing:YES];
	
	if (undoing) {
		[self replaceColorsAtPoints:points withColors:newColors inLayer:layer];
		
		PXColorArrayRelease(newColors);
		PXColorArrayRelease(oldColors);
	}
}

- (void)replaceColorsAtPoints:(NSPointerArray *)points withColors:(PXColorArrayRef)colors inLayer:(PXLayer *)layer
{
	NSRect changedRect = NSZeroRect;
	NSPoint point;
	
	if ([points count] > 0) {
		point = *(NSPoint *) [points pointerAtIndex:0];
		changedRect = NSMakeRect(point.x, point.y, 1.0f, 1.0f);
	}
	
	[self beginColorUpdates];
	
	for (NSInteger i = [points count] - 1; i >= 0; i--)
	{
		point = *(NSPoint *) [points pointerAtIndex:i];
		
		PXColor color = PXColorArrayColorAtIndex(colors, i);
		[self setColor:color atPoint:point onLayer:layer];
		
		changedRect = NSUnionRect(changedRect, NSMakeRect(point.x, point.y, 1.0f, 1.0f));
	}
	
	[self changedInRect:changedRect];
	[self endColorUpdates];
}

- (void)bufferUndoAtPoint:(NSPoint)aPoint fromColor:(PXColor)oldColor toColor:(PXColor)newColor
{
	[_drawnPoints addPointer:&aPoint];
	
	PXColorArrayAppendColor(_oldColors, oldColor);
	PXColorArrayAppendColor(_newColors, newColor);
}

- (void)applyImage:(NSImage *)image toLayer:(PXLayer *)layer
{
	[layer applyImage:image];
	[self refreshWholePalette];
}

@end
