//Copyright 2005-2023 Dominic Yu. Some rights reserved.
//This work is licensed under the Creative Commons
//Attribution-NonCommercial-ShareAlike License. To view a copy of this
//license, visit http://creativecommons.org/licenses/by-nc-sa/2.0/ or send
//a letter to Creative Commons, 559 Nathan Abbott Way, Stanford,
//California 94305, USA.

#import <Cocoa/Cocoa.h>
#import "DYJpegtran.h"

@interface DYJpegtranPanel : NSObject
@property (strong) IBOutlet NSPanel *topLevel;
@property (weak) IBOutlet NSPopUpButton *markersMenu;
@property (weak) IBOutlet NSButton *grayscaleBtn;
@property (weak) IBOutlet NSButton *optimizeBtn;
@property (weak) IBOutlet NSButton *progressiveBtn;
@property (weak) IBOutlet NSPopUpButton *transformMenu;
@property (weak) IBOutlet NSButton *trimBtn;
- (IBAction)convert:(id)sender;
- (IBAction)stopModal:(id)sender;
- (IBAction)transformChanged:(id)sender;
- (BOOL)runOptionsPanel:(DYJpegtranInfo *)i;
@end
