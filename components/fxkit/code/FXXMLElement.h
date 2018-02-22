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

#include <vector>
#include <memory>
#include <ostream>
#import "FXString.h"
    
struct FXXMLAttribute
{
  FXString name;
  FXString value;
  FXXMLAttribute() {};
  FXXMLAttribute( FXString const & n, FXString const & v = "") : name(n), value(v) {}
  bool operator== ( FXXMLAttribute const & attr ) const { return name == attr.name; }
  bool operator!= ( FXXMLAttribute const & attr ) const { return name != attr.name; }
};


class FXXMLElement;
typedef std::shared_ptr<FXXMLElement> FXXMLElementPtr;

typedef std::vector<FXXMLAttribute>           FXXMLAttributeVector;
typedef FXXMLAttributeVector::iterator        FXXMLAttributeIterator;
typedef FXXMLAttributeVector::const_iterator  FXXMLAttributeConstIterator;
typedef std::vector<FXXMLElementPtr>          FXXMLElementPtrVector;
typedef FXXMLElementPtrVector::iterator       FXXMLElementPtrIterator;


class FXXMLElement
{
public:
  FXXMLElement( const FXString& theName );
    
  // attribute list accessor
  FXXMLAttributeVector& getAttributes() { return m_attributes; }
  // child elements accessor
  FXXMLElementPtrVector& getChildren() { return m_children; }
    
  // same accessor methods for constant instances
  FXXMLAttributeVector const & getAttributes() const { return m_attributes; }
  FXXMLElementPtrVector const & getChildren() const { return m_children; }

  /// Note: Sometimes the order of the children is important, so don't replace the collection vector with a set.
  void collectChildrenWithName( FXString const & name, FXXMLElementPtrVector & collection, bool recursive = false ) const;

  FXString const & getName() const { return m_name; }
  FXString getName() { return m_name; }
  FXString const & getValue() const { return m_value; }
  FXString getValue() { return m_value; }
  void setValue(const FXString& value) { m_value = value; }

  /// @return true if the attribute exists, false otherwise.
  bool hasAttribute(FXString const & attributeName);

  /// @return empty string if the attribute does not exist
  FXString valueOfAttribute(FXString const & attributeName) const;

  /// If the attribute exists, its value is overwritten. Otherwise a new attribute with the given value is created.
  void setValueOfAttribute(FXString const & attributeName, FXString const & newValue);

  /// Replaces the existing value if an attribute with the same name already exists.
  void addAttribute(FXXMLAttribute const &);

  /// @return true if the attribute was removed successfully, otherwise false
  /// @param attributeName the name of the attribute to be removed
  bool removeAttribute( FXString const & attributeName );

  void addChild(FXXMLElementPtr const &);

  /// @return true if the child element was removed successfully, otherwise false
  bool removeChild( FXXMLElementPtr child );

  /// @return a deep copy of the element with all its subtree
  FXXMLElementPtr copyTree() const;

  /// @return a deep copy of the element with the given filter applied after copying the properties of each source element to the corresponding target element
  /// The children of the target element will already have been created and filtered when the target element is processed.
  FXXMLElementPtr copyTreeWithElementFilter( void(^)(FXXMLElement const & sourceElement, FXXMLElementPtr targetElement) ) const;

  /// @param indentation the number of leading indentation strings
  /// @param indentationString the string used for marking one level of indentation
  void printTree(std::ostream& stream, unsigned indentation = 0, FXString const & indentationString = "  ") const;

  /// @return the depth of the longest subtree
  unsigned maxDepth() const;

  friend std::ostream& operator<< (std::ostream& stream, const FXXMLElement &);

protected:
  FXXMLAttributeVector m_attributes;
  FXXMLElementPtrVector m_children;
  FXString m_name;
  FXString m_value;
};
