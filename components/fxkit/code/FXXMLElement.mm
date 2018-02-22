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

#include <iostream>
#include "FXXMLElement.h"

    
FXXMLElement::FXXMLElement(FXString const & name) :
  m_name(name),
  m_value("")
{
}


bool FXXMLElement::hasAttribute(FXString const & attributeName)
{
  bool result = false;
  for ( FXXMLAttribute const & attribute : m_attributes )
  {
    if ( attribute.name == attributeName )
    {
      result = true;
      break;
    }
  }
  return result;
}


FXString FXXMLElement::valueOfAttribute(const FXString & attributeName) const
{
  FXString result = "";    
  for( FXXMLAttribute const & attribute : m_attributes )
  {
    if ( attribute.name == attributeName )
    {
      result = attribute.value;
      break;
    }
  }
  return result;
}


void FXXMLElement::setValueOfAttribute(FXString const & attributeName, FXString const & newValue)
{
  bool foundAttribute = false;
  for ( FXXMLAttribute & attribute : m_attributes )
  {
    if ( attribute.name == attributeName )
    {
      attribute.value = newValue;
      foundAttribute = true;
      break;
    }
  }
  if (!foundAttribute)
  {
    m_attributes.push_back(FXXMLAttribute(attributeName, newValue));
  }
}


void FXXMLElement::addChild(FXXMLElementPtr const & newElement)
{
  bool alreadyAChild = false;
  for ( FXXMLElementPtr child : m_children )
  {
    if ( child == newElement )
    {
      alreadyAChild = true;
      break;
    }
  }
  if ( !alreadyAChild )
  {
    m_children.push_back(newElement);
  }
}


bool FXXMLElement::removeChild( FXXMLElementPtr child )
{
  bool result = false;
  FXXMLElementPtrVector::iterator it = std::find(m_children.begin(), m_children.end(), child);
  if ( it != m_children.end() )
  {
    m_children.erase(it);
    result = true;
  }
  return result;
}


void FXXMLElement::addAttribute(FXXMLAttribute const & newAttribute)
{
  bool alreadyExists = false;
  for ( FXXMLAttribute & attribute : m_attributes )
  {
    if ( attribute.name == newAttribute.name )
    {
      alreadyExists = true;
      attribute.value = newAttribute.value;
      break;
    }
  }
  if ( !alreadyExists )
  {
    m_attributes.push_back(newAttribute);
  }
}


bool FXXMLElement::removeAttribute( FXString const & attributeName )
{
  bool result = false;
  FXXMLAttributeVector::iterator it = std::find( m_attributes.begin(), m_attributes.end(), FXXMLAttribute(attributeName) );
  if ( it != m_attributes.end() )
  {
    m_attributes.erase(it);
    result = true;
  }
  return result;
}


void FXXMLElement::collectChildrenWithName( FXString const & name, FXXMLElementPtrVector & collection, bool recursive ) const
{
  for( FXXMLElementPtr const & child : m_children )
  {
    if ( recursive )
    {
      child->collectChildrenWithName(name, collection, recursive);
    }
    if ( child->getName() == name )
    {
      collection.push_back( child );
    }
  }
}


FXXMLElementPtr FXXMLElement::copyTree() const
{
  FXXMLElementPtr result( new FXXMLElement(getName())  );
  for ( FXXMLAttribute const & attribute : m_attributes )
  {
    result->addAttribute( attribute );
  }
  for ( FXXMLElementPtr child : m_children )
  {
    FXXMLElementPtr copyOfChild = child->copyTree();
    result->addChild(copyOfChild);
  }
  return result;
}


FXXMLElementPtr FXXMLElement::copyTreeWithElementFilter( void(^filter)(FXXMLElement const & sourceElement, FXXMLElementPtr targetElement) ) const
{
  FXXMLElementPtr result( new FXXMLElement(getName())  );
  for ( FXXMLAttribute const & attribute : m_attributes )
  {
    result->addAttribute( attribute );
  }
  for ( FXXMLElementPtr child : m_children )
  {
    FXXMLElementPtr copyOfChild = child->copyTreeWithElementFilter( filter );
    result->addChild(copyOfChild);
  }
  filter( *this, result );
  return result;
}


void FXXMLElement::printTree(std::ostream& stream, unsigned indentation, FXString const & indentationString) const
{
  for (unsigned i = 0; i < indentation; i++)
  {
    stream << indentationString;
  }
  stream << *this << std::endl;
  for ( FXXMLElementPtr child : m_children )
  {
    child->printTree(stream, indentation+1, indentationString);
  }
}


unsigned FXXMLElement::maxDepth() const
{
  unsigned maxDepth = 0;
  for ( FXXMLElementPtr child : m_children )
  {
    unsigned childDepth = child->maxDepth();
    if ( childDepth > maxDepth )
    {
      maxDepth = childDepth;
    }
  }
  if ( !m_children.empty() )
  {
    maxDepth++;
  }
  return maxDepth;
}


std::ostream& operator<< (std::ostream& stream, FXXMLElement const & element)
{
  stream << element.getName();

  FXXMLAttributeConstIterator ait;
  FXXMLAttributeVector attribs = element.getAttributes();
  size_t const listLength = attribs.size();
  if (listLength > 0)
  {
    stream <<  " [";
    ait = attribs.begin();
    for (int index = 0; index < listLength; index++ )
    {
      stream << (*ait).name << "=" << (*ait).value << ((index < listLength - 1) ? " " : "");
      ait++;
    }
    stream << "]";
  }
    
  return stream;
}

