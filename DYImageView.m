//Copyright 2005 Dominic Yu. Some rights reserved.
//This work is licensed under the Creative Commons
//Attribution-NonCommercial-ShareAlike License. To view a copy of this
//license, visit http://creativecommons.org/licenses/by-nc-sa/2.0/ or send
//a letter to Creative Commons, 559 Nathan Abbott Way, Stanford,
//California 94305, USA.

//  DYImageView.m
//  creevey
//  Created by d on 2005.04.01.

#import "DYImageView.h"

@interface DYImageView (Private)
- (void)setZoomAndCenter:(BOOL)center;
@end

@implementation DYImageView

- (float)zoomForFit {
	float tmp;
	NSSize imgSize = [image size];
	NSSize bSize = [self bounds].size;
	if (rotation == 90 || rotation == -90) {
		tmp = bSize.width;
		bSize.width = bSize.height;
		bSize.height = tmp;
	}
	
	if (!scalesUp
		&& imgSize.width <= bSize.width
		&& imgSize.height <= bSize.height)
	{
		return 1;
	} else {
		float w_ratio, h_ratio;
		w_ratio = bSize.width/imgSize.width;
		h_ratio = bSize.height/imgSize.height;
		if (w_ratio < h_ratio) {
			return w_ratio;
		} else {
			return h_ratio;
		}
	}
}

- (void)drawRect:(NSRect)rect {
	if (!image) return; //don't draw if nil
	
	NSRect srcRect, destinationRect;
	float zoom = zoomF;
	NSRect boundsRect = [self bounds]; float tmp;
	float centerX, centerY;
	centerX = boundsRect.size.width/2;
	centerY = boundsRect.size.height/2;
	if (zoomF) {
		srcRect = sourceRect;
		destinationRect.size = destSize;
	} else {
		if (rotation == 90 || rotation == -90) {
			tmp = boundsRect.size.width;
			boundsRect.size.width = boundsRect.size.height;
			boundsRect.size.height = tmp;
		}
		
		srcRect.origin = NSZeroPoint;
		srcRect.size = [image size];
		
		if (!scalesUp
			&& srcRect.size.width <= boundsRect.size.width
			&& srcRect.size.height <= boundsRect.size.height)
		{
			destinationRect.size.width = (int)(srcRect.size.width);
			destinationRect.size.height = (int)(srcRect.size.height);
			zoom = 1;
		} else {
			float w_ratio, h_ratio;
			w_ratio = boundsRect.size.width/srcRect.size.width;
			h_ratio = boundsRect.size.height/srcRect.size.height;
			if (w_ratio < h_ratio) { // the side w/ bigger ratio needs to be shrunk
				destinationRect.size.height = (int)(srcRect.size.height*w_ratio);
				destinationRect.size.width = (int)(boundsRect.size.width);
				zoom = w_ratio;
			} else {
				destinationRect.size.width = (int)(srcRect.size.width*h_ratio);
				destinationRect.size.height = (int)(boundsRect.size.height);
				zoom = h_ratio;
			}
		}
	}
	
	destinationRect.origin.x = (int)(centerX - destinationRect.size.width/2);
	destinationRect.origin.y = (int)(centerY - destinationRect.size.height/2);
	
	if (rotation != 0) {
		NSAffineTransform *transform = [NSAffineTransform transform];
		[transform translateXBy:centerX yBy:centerY];
		[transform rotateByDegrees:rotation];
		[transform translateXBy:-centerX yBy:-centerY];
		[transform concat];
	}

	[[NSColor whiteColor] set]; // make a nice background for transparent gifs, etc.
	[NSBezierPath fillRect:destinationRect];
	
	NSGraphicsContext *cg = [NSGraphicsContext currentContext];
	NSImageInterpolation oldInterp = [cg imageInterpolation];
	[cg setImageInterpolation:zoom > 1 ? NSImageInterpolationNone : NSImageInterpolationLow];
	[image drawInRect:destinationRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1.0];
	[cg setImageInterpolation:oldInterp];
	
	//[transform invert];
	//[transform concat];
	id rep = [[image representations] objectAtIndex:0];
	if ([rep isKindOfClass:[NSBitmapImageRep class]]
		&& [rep valueForProperty:NSImageFrameCount]) {
		if (!gifTimer || [gifTimer userInfo] != image) gifTimer =
			[NSTimer scheduledTimerWithTimeInterval:[[rep valueForProperty:NSImageCurrentFrameDuration] floatValue]
											 target:self selector:@selector(animateGIF:)
										   userInfo:image repeats:NO];
	}
}

- (void)animateGIF:(NSTimer *)t {
	gifTimer = nil;
	if (image != [t userInfo]) return; // stop if image is changed
	
	NSBitmapImageRep *rep = [[[t userInfo] representations] objectAtIndex:0];
	NSNumber *frameCount = [rep valueForProperty:NSImageFrameCount];
	int n = [[rep valueForProperty:NSImageCurrentFrame] intValue];
	if (++n == [frameCount intValue]) n = 0;
	[rep setProperty:NSImageCurrentFrame
		   withValue:[NSNumber numberWithInt:n]];
	[self setNeedsDisplay:YES];
}

- (void)setImage:(NSImage *)anImage {
	[image release];
	image = [anImage retain];
	zoomF = 0;
	rotation = 0;

	[self setNeedsDisplay:YES];
}

- (void)setImage:(NSImage *)anImage zoomIn:(BOOL)zoomIn {
	if (anImage != image) {
		if (!anImage) return; 
		[image release];
		image = [anImage retain];
		[image setScalesWhenResized:YES];
		NSImageRep *rep = [[image representations] objectAtIndex:0]; // ** assume not corrupt
		if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
			[image setSize:NSMakeSize([rep pixelsWide], [rep pixelsHigh])];
		} // ** cat on nsimage?
	}
	zoomF = [self zoomForFit];
	if (zoomIn == 2) { // **
		zoomF = 1;
	} else {
		float n = 2*log2f(zoomF);
		n = zoomIn ? floorf(n)+1 : ceilf(n)-1; // find closest half-power of 2
		zoomF = (int)n%2 ? ldexpf(1.5,(n-1)/2) : ldexpf(1,n/2);
	}
	//rotation = 0;
	[self setZoomAndCenter:YES];
}

- (void)setZoomAndCenter:(BOOL)center {
	if (!image) return; 
	NSSize imgSize = [image size];
	float tmp;
	NSSize bSize = [self bounds].size;
	if (rotation == 90 || rotation == -90) {
		tmp = bSize.height;
		bSize.height = bSize.width;
		bSize.width = tmp;
	}
	destSize = bSize;
	NSPoint oldCenter;
	if (!center) {
		oldCenter.x = sourceRect.origin.x + sourceRect.size.width/2;
		oldCenter.y = sourceRect.origin.y + sourceRect.size.height/2;
	}
	sourceRect.size.width  = (int)(bSize.width/zoomF);
	sourceRect.size.height = (int)(bSize.height/zoomF);
	if (sourceRect.size.width > imgSize.width) {
		sourceRect.size.width = imgSize.width;
		destSize.width = (int)(imgSize.width*zoomF);
		sourceRect.origin.x = 0;
	} else if (center) {
		sourceRect.origin.x = (imgSize.width - sourceRect.size.width)/2;
	} else {
		sourceRect.origin.x = oldCenter.x - sourceRect.size.width/2;
		if (sourceRect.origin.x < 0) {
			sourceRect.origin.x = 0;
		} else if (sourceRect.origin.x > (tmp = imgSize.width - sourceRect.size.width)) {
			sourceRect.origin.x = tmp;
		}
	}
	if (sourceRect.size.height > imgSize.height) {
		sourceRect.size.height = imgSize.height;
		destSize.height = (int)(imgSize.height*zoomF);
		sourceRect.origin.y = 0;
	} else if (center) {
		sourceRect.origin.y = (imgSize.height - sourceRect.size.height)/2;
	} else {
		sourceRect.origin.y = oldCenter.y - sourceRect.size.height/2;
		if (sourceRect.origin.y < 0) {
			sourceRect.origin.y = 0;
		} else if (sourceRect.origin.y > (tmp = imgSize.height - sourceRect.size.height)) {
			sourceRect.origin.y = tmp;
		}
	}
	[self setNeedsDisplay:YES];
}

- (int)rotation { return rotation; }

- (int)addRotation:(int)r {
	rotation += r;
	if (rotation > 180) rotation -=360; else if (rotation < -90) rotation += 360;
	if (zoomF)
		[self setZoomAndCenter:NO];
	else
		[self setNeedsDisplay:YES];
	return rotation;
}

//		float tmp, tmp2; // inner, outer rect insets (tmp > tmp2)
//		if (sourceRect.size.width > sourceRect.size.height) {
//			tmp = sourceRect.size.width;
//			tmp2 = sourceRect.size.height;
//		} else {
//			tmp = sourceRect.size.height;
//			tmp2 = sourceRect.size.width;
//		}
//		
//		float x,y, x2,y2, h,w, h2,w2, cx, cy, hypnus,hypnus2;
//		// center
//		cx = imgSize.width/2;
//		cy = imgSize.height/2;
//		// inner rect
//		h = imgSize.height - tmp;
//		w = imgSize.width -  tmp;
//		// outer rect
//		h2 = imgSize.height - tmp2;
//		w2 = imgSize.width -  tmp2;
//		// hypotenuse
//		hypnus = sqrtf(w*w+h*h);
//		hypnus2 = sqrtf(w2*w2+h2*h2);
//		// original point
//		x = sourceRect.origin.x/(imgSize.width-sourceRect.size.width)*w;
//		y = sourceRect.origin.y/(imgSize.height-sourceRect.size.height)*h;
//		// transformed point, in our criss-cross coord sys
//		x2 = ((h*x/w+h+y)/2-cy)*hypnus/h;
//		y2 = ((h-h*y/w+y)/2-cy)*hypnus/h;
//		// stretch y
//		y2 = y2*hypnus2/hypnus;
//		// untransform
//		// i give up!

- (void)setRotation:(int)n {
	// assume from zero, don't call when zoomed
	rotation = n;
	[self setNeedsDisplay:YES];
}

//- (float)zoom { return zoom; }

- (BOOL)scalesUp { return scalesUp; }
- (void)setScalesUp:(BOOL)b {
	if (scalesUp == b) return;
	scalesUp = b;
	[self setNeedsDisplay:YES];
}

- (void)zoomActualSize { // toggles
	if (zoomF != 1) {
		zoomF = 1;
		[self setZoomAndCenter:NO];
	}
}

- (void)zoomIn {
	if (zoomF == 0) {
		[self setImage:image zoomIn:YES];
		return;
	}
	if (zoomF >= 512) {
		NSBeep();
		return;
	}
	if (!image) return; 
	NSSize imgSize = [image size];

	float tmp;
	NSSize bSize = [self bounds].size;
	if (rotation == 90 || rotation == -90) {
		tmp = bSize.height;
		bSize.height = bSize.width;
		bSize.width = tmp;
	}
	// new size
	NSSize s = destSize = bSize;
	NSLog(@"zoom %f, modf %f", zoomF, modff(log2f(zoomF),&tmp));
	zoomF = fabsf(modff(log2f(zoomF),&tmp)) < 0.000001 ? 1.5*zoomF : zoomF/.75;
		// not precise enough to give 0 // *= M_SQRT2
	s.width  = (int)(s.width/zoomF); // always make dims integral; not nec origins
	s.height = (int)(s.height/zoomF);
	if (s.width > imgSize.width) {
		s.width = imgSize.width;
		destSize.width = (int)(s.width*zoomF);
	}
	if (s.height > imgSize.height) {
		s.height = imgSize.height;
		destSize.height = (int)(s.height*zoomF);
	}
	
	// new x
	if (s.width < imgSize.width) {
		if (sourceRect.size.width == imgSize.width)
			// special case for when smaller than screen becomes larger than screen
			sourceRect.origin.x = (imgSize.width - s.width)/2;
		else if (sourceRect.origin.x == imgSize.width - sourceRect.size.width) // must cast to int, for edge cases
			sourceRect.origin.x = imgSize.width - s.width;
		else if (sourceRect.origin.x > 0)
			// leave 0 if 0
			sourceRect.origin.x += (sourceRect.size.width - s.width)/2.0;
	} else {
		sourceRect.origin.x = 0;
	}
	
	// new y
	if (s.height < imgSize.height) {
		if (sourceRect.size.height == imgSize.height)
			sourceRect.origin.y = (imgSize.height - s.height)/2;
		else if (sourceRect.origin.y == imgSize.height - sourceRect.size.height)
			sourceRect.origin.y = imgSize.height - s.height;
		else if (sourceRect.origin.y > 0)
			sourceRect.origin.y += (sourceRect.size.height - s.height)/2.0;
	} else {
		sourceRect.origin.y = 0;
	}

	sourceRect.size = s;
	[self setNeedsDisplay:YES];
}

- (void)zoomOut {
	if (zoomF == 0) {
		[self setImage:image zoomIn:NO];
		return;
	}
	if (zoomF < 0.002) {
		NSBeep();
		return;
	}
	float tmp;
	zoomF = fabsf(modff(log2f(zoomF),&tmp)) < 0.000001 ? zoomF*.75 : zoomF/1.5;
	[self setZoomAndCenter:NO];
}

- (void)fakeDragX:(float)x y:(float)y {
	x /= zoomF;
	y /= zoomF;
	float xmax,ymax;
	xmax = [image size].width - sourceRect.size.width;
	ymax = [image size].height - sourceRect.size.height;
	if (xmax > 0 || ymax > 0) {
		switch (rotation) {
			case -90:
				sourceRect.origin.y -= x;
				sourceRect.origin.x += y;
				break;
			case 90:
				sourceRect.origin.y += x;
				sourceRect.origin.x -= y;
				break;
			case 180:
				sourceRect.origin.x += x;
				sourceRect.origin.y += y;
				break;
			default:
				sourceRect.origin.x -= x;
				sourceRect.origin.y -= y;
				break;
		}
		if (sourceRect.origin.x > xmax)
			sourceRect.origin.x = xmax;
		else if (sourceRect.origin.x < 0)
			sourceRect.origin.x = 0;
		if (sourceRect.origin.y > ymax)
			sourceRect.origin.y = ymax;
		else if (sourceRect.origin.y < 0)
			sourceRect.origin.y = 0;
		[self setNeedsDisplay:YES];
	}
}

- (void)scrollWheel:(NSEvent *)e {
	if (zoomF)
		[self fakeDragX:[e deltaX]*128 y:-[e deltaY]*128];
}
- (void)mouseDragged:(NSEvent *)e {
	if (zoomF)
		[self fakeDragX:[e deltaX] y:-[e deltaY]]; // y is flipped?
}

- (void)zoomOff {
	if (zoomF) {
		zoomF = 0;
		[self setNeedsDisplay:YES];
	}
}

- (BOOL)zoomMode {return zoomF != 0;}
- (float)zoomF {return zoomF;}
- (NSImage *)image {return image;}
@end
