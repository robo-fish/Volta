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
#pragma once

#import <VoltaCore/VoltaModelTypes.h>
#import <VoltaCore/VoltaSimulationData.h>
#import "FXString.h"
#include <set>
#include <map>
#include <utility>
#include <memory>
#include <pthread.h>


/// A key-value pair. The first item is the key.
typedef std::pair<FXString,FXString> VoltaPTMetaDataItem;

enum class VoltaPTLabelPosition
{
  None = 0,
  Top,
  Bottom,
  Left,
  Right,
  Center
};


/// A single path. Part of a shape.
struct VoltaPTPath
{
  FXString pathData;
  bool filled;
  float strokeWidth;
  VoltaPTPath() : strokeWidth(1), filled(false) {}
  VoltaPTPath(FXString const & d, bool f = false, float w = 1.0) : pathData(d), filled(f), strokeWidth(w) {}
};


/// A circle. Part of a shape.
struct VoltaPTCircle
{
  float centerX;
  float centerY;
  float radius;
  bool filled;

  VoltaPTCircle() : centerX(0), centerY(0), radius(0), filled(false) {}
  VoltaPTCircle(float x, float y, float r, bool fill = false) : centerX(x), centerY(y), radius(r), filled(fill) {}
};


/// The shape is a collection of paths and circles
struct VoltaPTShape
{
  std::vector<VoltaPTPath> paths;
  std::vector<VoltaPTCircle> circles;
  std::vector<VoltaPTMetaDataItem> metaData;
  float width;
  float height;

  VoltaPTShape() : width(0.0f), height(0.0f) {}
  VoltaPTShape(float w, float h) : VoltaPTShape()
  {
    width = w;
    height = h;
  }
};


/// Pins are used to make a component connectable.
struct VoltaPTPin
{
  FXString name;
  std::vector<VoltaPTMetaDataItem> metaData;
  float posX;
  float posY;

  VoltaPTPin() : posX(0.0f), posY(0.0f) {}
  VoltaPTPin(FXString const & n, float x, float y) : name(n), posX(x), posY(y) {}

  bool operator< (VoltaPTPin const & p) const { return name < p.name; }
  bool operator== (VoltaPTPin const & p) const { return name == p.name; }
  bool operator!= (VoltaPTPin const & p) const { return name != p.name; }
};


/// A property specifies a parameter of a component model.
/// A list of properties is specified both in models and components.
/// In a model the properties specify the allowable parameters and their default values.
/// In a component the properties are used to store the component-specific parameter values.
struct VoltaPTProperty
{
  FXString name;
  FXString value;

  VoltaPTProperty() = default;
  VoltaPTProperty( FXString const & name_, FXString const & value_ = "" ) : name(name_), value(value_) {}

  bool operator< (VoltaPTProperty const & p) const { return name < p.name; }
  bool operator== (VoltaPTProperty const & p) const { return name == p.name; }
  bool operator!= (VoltaPTProperty const & p) const { return name != p.name; }
};

typedef std::vector<VoltaPTProperty> VoltaPTPropertyVector;

/// Defines a class of elements.
/// Contains a list of properties with values that are to be used as the default values of a newly created component.
/// Circuit components (i.e., schematic elements) refer to their model by name and provide the component-specific property values.
/// Revisions start at 1. A revision with a higher value is more recent.
class VoltaPTModel
{
public:
  VoltaModelType type;
  FXString subtype;
  FXString name;
  FXString vendor;
  FXString elementNamePrefix;
  uint64_t revision;
  bool isMutable;
  VoltaPTShape shape;

  /// the default position to draw the label
  VoltaPTLabelPosition labelPosition;

  /// connector pins, listed in the same order as printed to netlist
  std::vector<VoltaPTPin> pins;

  VoltaPTPropertyVector properties;

  /// allowed parameters and their default values
  std::vector<VoltaPTMetaDataItem> metaData;

  /// Where the model comes from (file, network, etc.). Typically a URL.
  /// If this string is empty the model is a built-in model.
  FXString source;

  VoltaPTModel(
    VoltaModelType type_ = VMT_Unknown,
    FXString const & name_ = "",
    FXString const & vendor_ = "",
    FXString const & subtype_ = "",
    bool mutable_ = true,
    uint64_t revision_ = 1
    ) :
    type( type_ ),
    subtype( subtype_ ),
    name( name_ ),
    vendor( vendor_ ),
    revision( revision_ ),
    isMutable( mutable_ ),
    labelPosition( VoltaPTLabelPosition::None )
  {}

  VoltaPTModel( VoltaPTModel const & ) = delete; ///< Instances are not meant to be stored in STL containers. Use VoltaPTModelPtr.

  FXString fullName() const
  {
    if (vendor.empty()) return name;
    else { FXString vendor_ = vendor; vendor_.replaceAll(" ", "."); return vendor_ + "." + name; }
  }

  bool operator< (VoltaPTModel const & m) const { return (type == m.type) ? ( (name == m.name) ? (vendor < m.vendor) : (name < m.name) ) : (type < m.type); }
  bool operator== (VoltaPTModel const & m) const { return (type == m.type) && (name == m.name) && (vendor == m.vendor); }
  bool operator!= (VoltaPTModel const & m) const { return (type != m.type) || (name != m.name) || (vendor != m.vendor); }
};
typedef std::shared_ptr<VoltaPTModel> VoltaPTModelPtr;


template <class T>
class VoltaPTModelPtrContainer : public T
{
public:
  VoltaPTModelPtrContainer()
  {
    if ( pthread_mutex_init(&mLock, NULL) != 0 )
    {
      DebugLog(@"Could not initialize mutex.");
    }
  }

  ~VoltaPTModelPtrContainer()
  {
    if ( pthread_mutex_destroy(&mLock) )
    {
      DebugLog(@"Could not destroy mutex.");
    }
  }

  bool lock()
  {
    return (pthread_mutex_trylock(&mLock) == 0);
  }

  void unlock()
  {
    if ( pthread_mutex_unlock(&mLock) == EPERM )
    {
      DebugLog(@"The current thread tried to unlock VoltaPTModelPtrVector instance %p without locking first.", this);
    }
  }

private:
  pthread_mutex_t mLock;
};

typedef VoltaPTModelPtrContainer< std::vector<VoltaPTModelPtr> > VoltaPTModelPtrVector;
typedef VoltaPTModelPtrContainer< std::set<VoltaPTModelPtr> > VoltaPTModelPtrSet;


/// Defines a collection of models. These can be element models or device models.
class VoltaPTModelGroup
{
public:
  FXString name;
  VoltaPTModelPtrVector models;

  /// The type of all the models in this group.
  /// If VMT_Unknown then the types of the contained models are mixed.
  VoltaModelType modelType;

  // Whether the user is allowed to edit the name or the contents of this group.
  bool isMutable;

  VoltaPTModelGroup(FXString const & name_ = "", VoltaModelType type = VMT_Unknown) : name(name_), modelType(type), isMutable(true) {}
};
typedef std::shared_ptr<VoltaPTModelGroup> VoltaPTModelGroupPtr;
typedef std::vector<VoltaPTModelGroupPtr> VoltaPTModelGroupPtrVector;
typedef std::set<VoltaPTModelGroupPtr> VoltaPTModelGroupPtrSet;


/// A circuit element that references a model for its shape and properties.
/// Instances override the default values of the model with specific values.
/// Note: A 'component' is a special element, that has electrical properties.
class VoltaPTElement
{
public:
  FXString name;
  VoltaModelType type;
  FXString modelName;
  FXString modelVendor;
  VoltaPTPropertyVector properties; ///< element-specific parameter values
  VoltaPTLabelPosition labelPosition; ///< element-specific position for the label
  std::vector<VoltaPTMetaDataItem> metaData;

  float posX;        ///< horizontal location of the center of the shape
  float posY;        ///< vertical location of the center of the shape
  float rotation;    ///< in radian
  bool flipped;      ///< whether the element's shape is flipped horizontally

  VoltaPTElement() :
    posX(0),
    posY(0),
    rotation(0),
    flipped(false),
    type(VMT_Unknown),
    labelPosition(VoltaPTLabelPosition::None)
  {}

  VoltaPTElement(
    FXString const & name_,
    VoltaModelType type_,
    FXString const & modelName_,
    FXString const & modelVendor_
  ) : VoltaPTElement()
  {
    name = name_;
    type = type_;
    modelName = modelName_;
    modelVendor = modelVendor_;
  }

  VoltaPTElement(FXString const & name_, VoltaPTModelPtr model) : VoltaPTElement()
  {
    name = name_;
    if (model.get() != nullptr)
    {
      type = model->type;
      modelName = model->name;
      modelVendor = model->vendor;
    }
  }

  bool operator< (VoltaPTElement const & e) const { return name < e.name; }
  bool operator== (VoltaPTElement const & e) const { return name == e.name; }
  bool operator!= (VoltaPTElement const & e) const { return name != e.name; }
};

typedef std::vector<VoltaPTElement> VoltaPTElementVector;


class VoltaPTElementGroup
{
public:
  FXString name;
  VoltaPTElementVector elements;

  explicit VoltaPTElementGroup(FXString const & groupName = "") : name(groupName) {}

  bool operator< (VoltaPTElementGroup const & g) const { return name < g.name; }
  bool operator== (VoltaPTElementGroup const & g) const { return (name == g.name) && (elements == g.elements); }
  bool operator!= (VoltaPTElementGroup const & g) const { return (name != g.name) || (elements != g.elements); }
};

typedef std::shared_ptr<VoltaPTElementGroup> VoltaPTElementGroupPtr;


typedef std::pair<float,float> VoltaSchematicConnectorJointData;


/// Defines a connector within the schematic representation of a circuit
class VoltaPTConnector
{
public:
  FXString startElementName;
  FXString endElementName;
  FXString startPinName;
  FXString endPinName;
  std::vector<VoltaSchematicConnectorJointData> joints; ///< coordinates of the joint points
  std::vector<VoltaPTMetaDataItem> metaData;

  VoltaPTConnector() = default;

  VoltaPTConnector(
    FXString const & startElement,
    FXString const & startPin,
    FXString const & endElement,
    FXString const & endPin
    ) :
    startElementName(startElement),
    startPinName(startPin),
    endElementName(endElement),
    endPinName(endPin)
  {}
  
  bool operator< (VoltaPTConnector const & c) const
  {
    if ( startElementName == c.startElementName )
    {
      if ( endElementName == c.endElementName )
      {
        return startPinName < c.startPinName;
      }
      return endElementName < c.endElementName;
    }
    return startElementName < c.startElementName;
  };

  bool operator== (VoltaPTConnector const & c) const
  {
    return (startElementName == c.startElementName) &&
      (endElementName == c.endElementName) &&
      (startPinName == c.startPinName) &&
      (endPinName == c.endPinName);
  }

  bool operator!= (VoltaPTConnector const & c) const
  {
    return (startElementName != c.startElementName) ||
      (endElementName != c.endElementName) ||
      (startPinName != c.startPinName) ||
      (endPinName != c.endPinName);
  }
};


/// Defines the schematic representation of a circuit
class VoltaPTSchematic
{
public:
  FXString title;
  std::set<VoltaPTElement> elements;
  std::set<VoltaPTConnector> connectors;
  VoltaPTPropertyVector properties; ///< schematic-wide circuit properties
  std::vector<VoltaPTMetaDataItem> metaData;
};
typedef std::shared_ptr< VoltaPTSchematic > VoltaPTSchematicPtr;


/// The mapping from external pin names to internal nodes.
typedef std::pair<FXString,FXString> VoltaPTSubcircuitExternal;
typedef std::map<FXString,FXString> VoltaPTSubcircuitExternalsMap;

class VoltaPTSubcircuitData
{
public:
  bool enabled;
  FXString name;
  FXString vendor;
  uint64_t revision; ///< Revisions start at 1. A revision with a higher value is more recent.
  VoltaPTShape shape;
  VoltaPTLabelPosition labelPosition;
  std::vector<VoltaPTPin> pins;
  VoltaPTSubcircuitExternalsMap externals; ///< maps pin names to node names
  std::vector<VoltaPTMetaDataItem> metaData;

  VoltaPTSubcircuitData() : labelPosition(VoltaPTLabelPosition::Top), revision(1), enabled(false) {}

  FXString fullName() const { return vendor.empty() ? name : (vendor + "." + name); }
};
typedef std::shared_ptr<VoltaPTSubcircuitData> VoltaPTSubcircuitDataPtr;


/// A collection of elements and models.
/// Usually, these are created from unarchived library files.
class VoltaPTLibrary
{
public:
  FXString title;
  VoltaPTElementGroup elementGroup;
  VoltaPTModelGroupPtr modelGroup;
  std::vector<VoltaPTMetaDataItem> metaData;

  bool operator< (VoltaPTLibrary const & lib) const { return title < lib.title; }
};
typedef std::shared_ptr<VoltaPTLibrary> VoltaPTLibraryPtr;


class VoltaPTCircuit
{
public:
  FXString title;
  VoltaPTSchematicPtr schematicData;
  VoltaPTSubcircuitDataPtr subcircuitData;
  VoltaPTSimulationDataPtr simulationData;
  std::vector<VoltaPTMetaDataItem> metaData;

  bool operator< (VoltaPTCircuit const & c) const { return title < c.title; }
};
typedef std::shared_ptr<VoltaPTCircuit> VoltaPTCircuitPtr;
