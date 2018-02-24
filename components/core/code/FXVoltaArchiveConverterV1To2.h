#import "FXXMLElement.h"
#import <tuple>

@interface FXVoltaArchiveConverterV1To2 : NSObject

/// @return a tuple containing the resulting element node, a list of warnings, and a list of errors, in that order.
/// The returned node can only be valid if there were no errors.
+ (std::tuple<FXXMLElementPtr, FXStringVector, FXStringVector>) convertRootElement:(FXXMLElementPtr)rootElement;

@end
