/**
This file is part of the Volta project.
Copyright (C) 2007-2013 Kai Berk Oezer
https://robo.fish/wiki/index.php?title=Volta
https://github.com/robo-fish/Volta

Volta is free software. You can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

@interface FXVoltaDocumentWindowController : NSWindowController <NSWindowDelegate, NSSplitViewDelegate>


- (BOOL) circuitProcessorsAreVisible;

- (void) hideCircuitProcessors;

- (void) revealCircuitProcessors;

- (void) toggleCircuitProcessorsPanel:(id)sender;

- (void) selectCircuitProcessorsTabWithTitle:(NSString*)tabTitle;

- (void) revealNetlistEditor;

- (void) revealSimulatorOutput;

- (void) revealSubcircuitEditor:(id)sender;

- (BOOL) plotterIsVisible;

- (void) revealPlotter;

- (void) hidePlotter;

- (void) togglePlotterPanel:(id)sender;


/// These are mainly geometric properties of the window.
/// They are used when no window restoration data is available.
/// This data lives in the Volta file and persists between users while window restoration is per user, per OS.
- (NSDictionary*) collectDocumentSettings;

- (void) applyDocumentSettings:(NSDictionary*)settings;


#if VOLTA_SUPPORTS_AUTOSAVE_AND_VERSIONS
- (void) prepareToRevertToOtherDocument;
#endif


- (void) setNetlistEditorView:(NSView*)view withMinimumSize:(CGSize)minSize;

- (void) setSchematicEditorView:(NSView*)view withMinimumSize:(CGSize)minSize;

- (void) setPlotterView:(NSView*)view withMinimumViewSize:(CGSize)minSize;

- (void) setSubcircuitEditorView:(NSView*)view withMinimumViewSize:(CGSize)minSize;

- (void) setSimulatorView:(NSView*)view withMinimumSize:(CGSize)minSize;


@end


extern NSString* FXVoltaCircuitDocumentWindowIdentifier;
