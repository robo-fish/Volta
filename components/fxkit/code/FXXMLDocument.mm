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

#include "FXXMLDocument.h"

#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlreader.h>
#include <libxml/relaxng.h>

#include <stack>
#include <stdio.h>
#include <stdarg.h>
#include <iostream>


class FXXMLTextReaderAutoPtr
{
public:
  explicit FXXMLTextReaderAutoPtr(xmlTextReaderPtr reader) : mReader(reader) {}
  ~FXXMLTextReaderAutoPtr() { if (mReader != NULL) xmlFreeTextReader(mReader); }
private:
  xmlTextReaderPtr mReader;
};


class FXXMLRelaxNGParserAutoPtr
{
public:
  explicit FXXMLRelaxNGParserAutoPtr(xmlRelaxNGParserCtxtPtr parser) : mParser(parser) {}
  ~FXXMLRelaxNGParserAutoPtr() { if (mParser != NULL) xmlRelaxNGFreeParserCtxt(mParser); }  
private:
  xmlRelaxNGParserCtxtPtr mParser;
};


class FXXMLRelaxNGAutoPtr
{
public:
  explicit FXXMLRelaxNGAutoPtr(xmlRelaxNGPtr schema) : mSchema(schema) {}
  ~FXXMLRelaxNGAutoPtr() { if (mSchema != NULL) xmlRelaxNGFree(mSchema); }
private:
  xmlRelaxNGPtr mSchema;
};


FXXMLDocument::FXXMLDocument(FXXMLElementPtr const & root)
{
  mRootElement = root;
}


static FXXMLDocumentPtr coreReader(xmlTextReaderPtr reader) throw (std::runtime_error)
{
  FXXMLDocumentPtr result;
  FXXMLElementPtr lastElement;
  FXXMLElementPtr documentRoot;
    
  std::stack<FXXMLElementPtr> elementStack; // stack of parent elements
  int lastDepth = -1;
  int ret;
  
  LIBXML_TEST_VERSION

  ret = xmlTextReaderRead(reader);
  while (ret == 1)
  {
    const xmlChar *name_ = xmlTextReaderConstLocalName(reader);
    if (name_ != NULL)
    {
      FXString name(reinterpret_cast<const char*>(name_));
      int nodeType = xmlTextReaderNodeType(reader);
      if ( nodeType == XML_READER_TYPE_ELEMENT)
      {
        // This XML item is an element. Add to it to the tree structure.
        int depth = xmlTextReaderDepth(reader);
        
        FXXMLElementPtr element( new FXXMLElement(name) );
        
        if ( !lastElement )
        {
          documentRoot = element;
        }
        
        if ( depth > lastDepth )
        {
          // Put reference to parent on stack
          if ( lastElement )
          {
            // The last element becomes the new parent
            elementStack.push( lastElement );
          }
        }
        else if ( depth < lastDepth )
        {
          for (int n = 0; n < (lastDepth - depth); n++)
          {
            elementStack.pop();
          }
        }
        
        lastElement = element;
        lastDepth = depth;
        
        
        // Add this element to parent, if it exists
        if ( elementStack.size() > 0 )
        {
          elementStack.top()->addChild( element );
        }
                        
        if ( xmlTextReaderHasAttributes(reader) )
        {
          FXXMLAttribute tmpAttribute;
          if ( xmlTextReaderMoveToFirstAttribute(reader) > 0 )
          {
            tmpAttribute.name = FXString( reinterpret_cast<const char *>(xmlTextReaderConstLocalName(reader)) );
            tmpAttribute.value = FXString( reinterpret_cast<const char *>(xmlTextReaderConstValue(reader)) );
            element->addAttribute(tmpAttribute);
            while ( xmlTextReaderMoveToNextAttribute(reader) == 1 )
            {
              tmpAttribute.name = FXString( reinterpret_cast<const char *>(xmlTextReaderConstLocalName(reader)) );
              tmpAttribute.value = FXString( reinterpret_cast<const char *>(xmlTextReaderConstValue(reader)) );
              element->addAttribute(tmpAttribute);
            }
          }
        }
      }
      else if (nodeType == XML_READER_TYPE_TEXT)
      {
        if ( lastElement )
        {
          if ( xmlTextReaderHasValue(reader) )
          {
            const xmlChar* value = xmlTextReaderConstValue(reader);
            if ( value != 0 )
            {
              lastElement->setValue( reinterpret_cast<const char*>(value) );
            }
          }
        }
      }
    }
    ret = xmlTextReaderRead(reader);
  } // while
  
  if (ret != 0)
  {
    throw std::runtime_error("Failed to parse XML");
  }
  else
  {
    result = FXXMLDocumentPtr( new FXXMLDocument( documentRoot ) );
  }

#if 0
  xmlCleanupParser(); FXIssue(120) // causes crash
#endif

  return result;
}


FXXMLDocumentPtr FXXMLDocument::fromString(FXString const & content) throw (std::runtime_error)
{
  FXXMLDocumentPtr result;
  if (!content.empty())
  {
    std::unique_ptr<char[]> documentContent = content.cString();
    // Note: Need to use strlen() because the number of octets is not equal to number of characters in UTF-8.
    xmlTextReaderPtr reader = xmlReaderForMemory(documentContent.get(), (int)strlen(documentContent.get()), "", xmlGetCharEncodingName(XML_CHAR_ENCODING_UTF8), XML_PARSE_NOWARNING);
    FXXMLTextReaderAutoPtr readerAutoPtr(reader);
    
    if (reader)
    {
      result = coreReader(reader);
    }
    else
    {
      throw std::runtime_error("Unable to extract xml content.");
    }
  }
  return result;
}


FXXMLDocumentPtr FXXMLDocument::fromFile(FXString const & filename) throw (std::runtime_error)
{
  std::unique_ptr<char[]> filenameChars = filename.cString();
  xmlTextReaderPtr reader = xmlReaderForFile(filenameChars.get(), xmlGetCharEncodingName(XML_CHAR_ENCODING_UTF8), 0);
  FXXMLTextReaderAutoPtr readerAutoPtr(reader);
  
  if (reader)
  {
    FXXMLDocumentPtr result = coreReader(reader);
    return result;
  }
  else
  {
    std::unique_ptr<char[]> message = ("Unable to open " + filename).cString();
    std::runtime_error anError(message.get());
    throw anError;
  }
}


FXXMLDocument::~FXXMLDocument()
{
}


FXXMLElementPtr const FXXMLDocument::getRootElement() const
{
  return mRootElement;
}


FXXMLElementPtr FXXMLDocument::getRootElement()
{
  return mRootElement;
}


static void validityErrorHandler(void * ctx, const char * msg, ...)
{
#if VOLTA_DEBUG
  va_list s;

  va_start (s, msg); 
  for (const char* g = va_arg (s, const char*); g != 0; g = va_arg (s, const char*))
  {
    std::cout << g; 
  }
  va_end (s);
#endif
}


static void validityWarningHandler(void * ctx, const char * msg, ...)
{
#if VOLTA_DEBUG
  std::cout << msg << std::endl;
#endif
}


bool FXXMLDocument::validate( FXString const & document, FXString const & schema )
{
  // validate RelaxNG schema
  xmlTextReaderPtr reader;
  bool valid = false;

  std::unique_ptr<char[]> documentCharacters = document.cString();
  // Note: Need to use strlen() because the number of octets is not equal to number of characters in UTF-8.
  reader = xmlReaderForMemory( documentCharacters.get(), (int)strlen(documentCharacters.get()), "", xmlGetCharEncodingName(XML_CHAR_ENCODING_UTF8), 0 );
  if (reader == NULL)
  {
    std::cout << "Could not create XML reader for document." << std::endl;
    return false; // Unable to create XML reader object
  }

  FXXMLTextReaderAutoPtr readerAutoPtr(reader);

  std::unique_ptr<char[]> schemaCharacters = schema.cString();
  xmlRelaxNGParserCtxtPtr rngParserContext = xmlRelaxNGNewMemParserCtxt( schemaCharacters.get(), (int)schema.length() );
  if ( rngParserContext == NULL )
  {
    std::cout << "Could not create parser context." << std::endl;
    return false; // Unable to create Relax NG parser context
  }

  FXXMLRelaxNGParserAutoPtr parserAutoPtr( rngParserContext );

	// Set the error handler callback
  xmlRelaxNGSetParserErrors(rngParserContext, validityErrorHandler, validityWarningHandler, NULL );
    
  xmlRelaxNGPtr rngRef = xmlRelaxNGParse( rngParserContext );
  if ( rngRef == NULL )
  {
    std::cout << "Error trying to parse the validation schema." << std::endl;
    return false; // Failed to parse Relax NG schema
  }

  FXXMLRelaxNGAutoPtr rngAutoPtr( rngRef );

  if ( xmlTextReaderRelaxNGSetSchema( reader, rngRef ) == -1 )
  {
    std::cout << "Error trying to use the validation schema for reading the document." << std::endl;
    return false; // Failed to assign validation schema
  }
  else
  {
    int ret = 0;
    do
    {
      ret = xmlTextReaderRead(reader);
    }
    while (ret == 1);
    if (ret == -1)
    {
      std::cout << "Could not read from document while trying to validate." << std::endl;
      return false; // Failed to parse configuration file
    }
    if (xmlTextReaderIsValid(reader) == 1)
    {
      valid = true;
    }
  }

#if 0
  xmlCleanupParser(); FXIssue(120) // causes crash
#endif

  return valid;
}


std::ostream& operator<< (std::ostream& stream, const FXXMLDocument& doc)
{
  if ( doc.getRootElement().get() != nullptr)
  {
    doc.getRootElement()->printTree(stream);
  }
  return stream;
}

