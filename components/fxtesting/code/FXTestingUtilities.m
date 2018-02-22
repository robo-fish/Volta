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

#import "FXTestingUtilities.h"
#import <ApplicationServices/ApplicationServices.h>

@implementation FXTestingUtilities


+ (NSView*) findViewWithIdentifier:(NSString*)identifier startingAtView:(NSView*)rootView
{
  NSView* result = nil;
  if ( [rootView.identifier isEqualToString:identifier] )
  {
    result = rootView;
  }
  else
  {
    for ( NSView* subview in rootView.subviews )
    {
      result = [self findViewWithIdentifier:identifier startingAtView:subview];
      if ( result != nil )
      {
        break;
      }
    }
  }
  return result;
}


#if 0
+ (AXUIElementRef) findElementWithDescription:(CFStringRef)description startingWithElement:(AXUIElementRef)rootElement
{
  AXUIElementRef result = NULL;
  CFArrayRef attributeNames = NULL;
  AXUIElementCopyAttributeNames(rootElement, &attributeNames);
  CFStringRef role = NULL;
  AXUIElementCopyAttributeValue(rootElement, kAXRoleAttribute, (CFTypeRef*)&role);
  NSLog(@"%@", role);
  if ( CFArrayContainsValue(attributeNames, CFRangeMake(0, CFArrayGetCount(attributeNames)), kAXDescriptionAttribute) )
  {
    CFStringRef elementDescription = NULL;
    AXUIElementCopyAttributeValue(rootElement, kAXDescriptionAttribute, (CFTypeRef*)&elementDescription);
    NSLog(@"  %@", elementDescription);
    CFRelease(elementDescription);
    if ( CFStringCompare(elementDescription, description, 0) == kCFCompareEqualTo )
    {
      result = rootElement;
    }
    CFRelease(elementDescription);
  }

  if ( result == NULL )
  {
    if ( CFArrayContainsValue(attributeNames, CFRangeMake(0, CFArrayGetCount(attributeNames)), kAXChildrenAttribute) )
    {
      CFArrayRef children = NULL;
      AXUIElementCopyAttributeValue(rootElement, kAXChildrenAttribute, (CFTypeRef*)&children);
      CFIndex const numChildren = CFArrayGetCount(children);
      for ( CFIndex currentChildIndex = 0; currentChildIndex < numChildren; currentChildIndex++ )
      {
        AXUIElementRef child = CFArrayGetValueAtIndex(children, currentChildIndex);
        result = [self findElementWithDescription:description startingWithElement:child];
        if ( result != NULL )
        {
          break;
        }
      }
      CFRelease(children);
    }
  }
  CFRelease(attributeNames);
  return result;
}


+ (AXUIElementRef) findElementWithDescription:(NSString*)description
{
  AXUIElementRef applicationElement = AXUIElementCreateApplication(getpid());
  AXUIElementRef result = [self findElementWithDescription:(CFStringRef)description startingWithElement:applicationElement];
  CFRelease(applicationElement);
  return result;
}
#endif


+ (NSObject*) findObjectWithRole:(NSString*)role startingAtObject:(NSObject*)rootObject;
{
  NSObject* result = nil;
  if ( [[rootObject accessibilityAttributeValue:NSAccessibilityRoleAttribute] isEqualToString:role] )
  {
    result = rootObject;
  }
  else
  {
    if ( [[rootObject accessibilityAttributeNames] containsObject:NSAccessibilityChildrenAttribute] )
    {
      NSArray* children = [rootObject accessibilityAttributeValue:NSAccessibilityChildrenAttribute];
      for ( NSObject* child in children )
      {
        result = [self findObjectWithRole:role startingAtObject:child];
        if ( result != nil )
        {
          break;
        }
      }
    }
  }
  return result;
}


@end
