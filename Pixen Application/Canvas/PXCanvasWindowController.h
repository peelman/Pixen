//  PXCanvasWindowController.h
//  Pixen
//
//  Created by Joe Osborn on Sat Sep 13 2003.
//  Copyright (c) 2003 Pixen. All rights reserved.
//

#import "PXCanvasResizePrompter.h"

@class PXCanvasController, PXLayerController, PXPaletteController, PXScaleController;
@class PXCanvas, PXCanvasView, PXBackground;

@interface PXCanvasWindowController : NSWindowController < PXCanvasResizePrompterDelegate >
{
  @private
	PXCanvas *canvas;
	
	IBOutlet id zoomPercentageBox;
	IBOutlet id zoomStepper;
	IBOutlet NSView *zoomView;
	
	PXCanvasResizePrompter *_resizePrompter;
	PXScaleController *scaleController;
	PXLayerController *layerController;
	PXPaletteController *paletteController;
	
	NSToolbar *toolbar;
	IBOutlet PXCanvasController *canvasController;
	
	IBOutlet NSSplitView *splitView;
	IBOutlet NSView *sidebarSplit, *layerSplit, *canvasSplit, *paletteSplit;
}

@property (nonatomic, readonly) IBOutlet PXCanvasController *canvasController;

@property (nonatomic, readonly) PXScaleController *scaleController;
@property (nonatomic, readonly) PXCanvasResizePrompter *resizePrompter;

@property (nonatomic, assign) PXCanvas *canvas;

@property (nonatomic, readonly) IBOutlet NSSplitView *splitView;
@property (nonatomic, readonly) IBOutlet NSView *layerSplit, *canvasSplit, *paletteSplit;

- (PXCanvasView *)view;
- (id) initWithWindowNibName:name;
- (void)awakeFromNib;
- (NSView *)layerSplit;
- (NSView *)canvasSplit;
- (void)dealloc;
- (void)windowWillClose:note;
- (void)releaseCanvas;
- (void)setDocument:(NSDocument *)doc;
- (void)windowDidResignMain:note;
- (void)windowDidBecomeMain:(NSNotification *) aNotification;
- (void)prepare;
- (void)updateCanvasSize;
- (void)updateFrameSizes;
@end
