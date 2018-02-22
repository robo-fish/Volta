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

#include <iostream>
#include <stdexcept>
#include <memory>
#include "FXXMLElement.h"

class FXXMLDocument;
typedef std::shared_ptr<FXXMLDocument> FXXMLDocumentPtr;
  
/// Creates and manages a DOM tree from a given XML file or content string.
/// The tree contains only nodes of type element. Other node types, like
/// comments, are skipped during parsing.
class FXXMLDocument
{
public:
  //! Constructor. Parses the XML document and build an internal tree data structure.
  static FXXMLDocumentPtr fromFile(FXString const & filename) throw (std::runtime_error);

  static FXXMLDocumentPtr fromString(FXString const & content) throw (std::runtime_error);

  explicit FXXMLDocument(FXXMLElementPtr const & root);

  //! Releases memory used for the document tree.
  virtual ~FXXMLDocument();

  FXXMLElementPtr getRootElement();

  FXXMLElementPtr const getRootElement() const;

  //! \return \c true if the document is valid against the given Relax NG schema, \c false otherwise.
  static bool validate( FXString const & document, FXString const & schema );

  friend std::ostream& operator<< (std::ostream& o, const FXXMLDocument&);

protected:
  FXXMLElementPtr mRootElement;
};
