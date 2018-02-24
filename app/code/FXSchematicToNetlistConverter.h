#import "VoltaPersistentTypes.h"
#import <VoltaCore/VoltaLibraryProtocol.h>


struct FXSchematicToNetlistConversionResult
{
  FXString output; // the resulting netlist (SPICE deck)
  std::vector< FXString > errors; // errors occurring during conversion
};


FXIssue(2)
/// Converts a schematic to a netlist string
class FXSchematicToNetlistConverter
{
public:

  /// Creates a SPICE deck (i.e., netlist and commands)
  static FXSchematicToNetlistConversionResult convert(VoltaPTSchematicPtr schematicData, id<VoltaLibrary> library);

  /// Use this variant if the given schematic belongs to a subcircuit.
  static FXSchematicToNetlistConversionResult convert(VoltaPTSchematicPtr schematicData, VoltaPTSubcircuitDataPtr subcircuitData, id<VoltaLibrary> library);

  /// @param bundle the bundle that contains the conversion error messages strings table
  /// The converter will use the main bundle if no bundle is set.
  /// This method is useful for unit testing.
  static void setConversionErrorMessagesBundle(NSBundle* bundle);

  FXSchematicToNetlistConverter(FXSchematicToNetlistConverter const &) = delete;
  FXSchematicToNetlistConverter& operator= (FXSchematicToNetlistConverter const &) = delete;
};
