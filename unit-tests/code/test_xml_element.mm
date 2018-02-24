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

#import <XCTest/XCTest.h>
#import "FXXMLElement.h"
#import <sstream>

@interface test_xml_element : XCTestCase
@end


@implementation test_xml_element


- (void) test_add_remove_attributes
{
  FXXMLElement element( "e" );
  FXUTAssert( element.getAttributes().empty() );
  element.addAttribute( FXXMLAttribute("att1") );
  FXUTAssertEqual( element.getAttributes().size(), (size_t)1 );
  element.addAttribute( FXXMLAttribute("att2") );
  FXUTAssertEqual( element.getAttributes().size(), (size_t)2 );
  FXUTAssert(element.hasAttribute("att2"));
  FXUTAssert(element.removeAttribute("att2"));
  FXUTAssertEqual(element.getAttributes().size(), (size_t)1 );
  FXUTAssert(!element.hasAttribute("att2"));
}


- (void) test_add_remove_children
{
  FXXMLElement element( "parent" );
  FXUTAssert( element.getChildren().empty() );
  FXXMLElementPtr child1(new FXXMLElement("child1"));
  element.addChild( child1 );
  FXUTAssertEqual( element.getChildren().size(), (size_t)1 );
  FXXMLElementPtr child2(new FXXMLElement("child2"));
  element.addChild( child2 );
  FXUTAssertEqual( element.getChildren().size(), (size_t)2 );
  FXUTAssert( std::find(element.getChildren().begin(), element.getChildren().end(), child2) != element.getChildren().end() );
  element.removeChild( child2 );
  FXUTAssert( std::find(element.getChildren().begin(), element.getChildren().end(), child2) == element.getChildren().end() );
  FXUTAssertEqual( element.getChildren().size(), (size_t)1 );
  element.removeChild( child1 );
  FXUTAssert( element.getChildren().empty() );
}


- (void) test_depth_calculation
{
  FXXMLElementPtr root( new FXXMLElement("root") );
  FXXMLElementPtr child_1(new FXXMLElement("child_1"));
  FXXMLElementPtr child_1_1(new FXXMLElement("child_1_1"));
  FXXMLElementPtr child_1_1_1(new FXXMLElement("child_1_1_1"));
  FXXMLElementPtr child_2(new FXXMLElement("child_2"));
  FXXMLElementPtr child_2_1(new FXXMLElement("child_2_1"));
  FXXMLElementPtr child_2_2(new FXXMLElement("child_2_2"));
  FXXMLElementPtr child_2_2_1(new FXXMLElement("child_2_2_1"));
  FXXMLElementPtr child_2_2_1_1(new FXXMLElement("child_2_2_1_1"));
  root->addChild( child_1 );
  FXUTAssertEqual( root->maxDepth(), 1u );
  child_1->addChild(child_1_1);
  FXUTAssertEqual( root->maxDepth(), 2u );
  child_1_1->addChild(child_1_1_1);
  FXUTAssertEqual( root->maxDepth(), 3u );
  root->addChild(child_2);
  FXUTAssertEqual( root->maxDepth(), 3u );
  child_2->addChild(child_2_1);
  FXUTAssertEqual( root->maxDepth(), 3u );
  child_2->addChild(child_2_2);
  FXUTAssertEqual( root->maxDepth(), 3u );
  child_2_2->addChild(child_2_2_1);
  FXUTAssertEqual( root->maxDepth(), 3u );
  child_2_2_1->addChild(child_2_2_1_1);
  FXUTAssertEqual( root->maxDepth(), 4u );
}


- (void) test_print_tree
{
  FXXMLElementPtr root( new FXXMLElement("root") );
  FXXMLElementPtr child_1( new FXXMLElement("child_1") );
  FXXMLElementPtr child_1_1(new FXXMLElement("child_1_1"));
  FXXMLElementPtr child_1_2(new FXXMLElement("child_1_2"));
  FXXMLElementPtr child_2( new FXXMLElement("child_2") );
  child_2->addAttribute( FXXMLAttribute("x", "5") );
  FXXMLElementPtr child_2_1( new FXXMLElement("child_2_1") );
  FXXMLElementPtr child_2_1_1( new FXXMLElement("child_2_1_1") );
  root->addChild(child_1);
  root->addChild(child_2);
  child_1->addChild(child_1_1);
  child_1->addChild(child_1_2);
  child_2->addChild(child_2_1);
  child_2_1->addChild(child_2_1_1);

  {
    std::ostringstream oss1;
    child_2->printTree(oss1);
    FXUTAssert(oss1.str() == "child_2 [x=5]\n  child_2_1\n    child_2_1_1\n");
  }

  {
    std::ostringstream oss2;
    root->printTree(oss2, 1, "+-");
    FXUTAssert( oss2.str() == "+-root\n+-+-child_1\n+-+-+-child_1_1\n+-+-+-child_1_2\n+-+-child_2 [x=5]\n+-+-+-child_2_1\n+-+-+-+-child_2_1_1\n" );
  }

}


- (void) test_tree_copy
{
  FXXMLElementPtr root( new FXXMLElement("root") );
  FXXMLElementPtr child_1( new FXXMLElement("child_1") );
  FXXMLElementPtr child_2( new FXXMLElement("child_2") );
  FXXMLElementPtr child_2_1( new FXXMLElement("child_2_1") );
  root->addChild(child_1);
  root->addChild(child_2);
  child_2->addChild(child_2_1);

  {
    FXXMLElementPtr rootCopy = root->copyTree();
    FXUTAssert( root.get() != rootCopy.get() );
    FXUTAssertEqual( root->maxDepth(), rootCopy->maxDepth() );
    FXUTAssertEqual(root->getChildren().size(), rootCopy->getChildren().size());
    FXUTAssertEqual(root->getChildren().size(), (size_t)2);
    FXUTAssert( root->getChildren().at(0).get() != rootCopy->getChildren().at(0).get() );
    FXUTAssert( root->getChildren().at(1).get() != rootCopy->getChildren().at(1).get() );
    FXUTAssertEqual( root->getChildren().at(1)->getChildren().size(), (size_t)1 );
    FXUTAssert( root->getChildren().at(1)->getChildren().at(0).get() != rootCopy->getChildren().at(1)->getChildren().at(0).get() );
    std::ostringstream oss1;
    std::ostringstream oss2;
    root->printTree(oss1);
    rootCopy->printTree(oss2);
    FXUTAssert( oss1.str() == oss2.str() );
  }

  {
    FXXMLElementPtr filteredCopy = root->copyTreeWithElementFilter( ^(FXXMLElement const & source, FXXMLElementPtr target) {
      target->addAttribute( FXXMLAttribute("att", "bla") );
    });
    FXUTAssertEqual( filteredCopy->maxDepth(), root->maxDepth() );
    FXUTAssert( filteredCopy.get() != root.get() );
    std::ostringstream oss;
    filteredCopy->printTree(oss);
    FXUTAssert( oss.str() == "root [att=bla]\n  child_1 [att=bla]\n  child_2 [att=bla]\n    child_2_1 [att=bla]\n" );
  }
}


- (void) test_collecting_child_elements_by_name
{
  FXXMLElementPtr root( new FXXMLElement("root") );
  FXXMLElementPtr child_1( new FXXMLElement("coffee") );
  FXXMLElementPtr child_1_1(new FXXMLElement("cocoa"));
  FXXMLElementPtr child_1_2(new FXXMLElement("coffee"));
  FXXMLElementPtr child_2( new FXXMLElement("coffee") );
  FXXMLElementPtr child_2_1( new FXXMLElement("cocoa") );
  FXXMLElementPtr child_2_1_1( new FXXMLElement("coffee") );
  root->addChild(child_1);
  root->addChild(child_2);
  child_1->addChild(child_1_1);
  child_1->addChild(child_1_2);
  child_2->addChild(child_2_1);
  child_2_1->addChild(child_2_1_1);

  FXXMLElementPtrVector collection;
  root->collectChildrenWithName("coffee", collection);
  FXUTAssertEqual( collection.size(), (size_t)2 );
  collection.clear();
  root->collectChildrenWithName("coffee", collection, true);
  FXUTAssertEqual( collection.size(), (size_t)4 );
  collection.clear();
  root->collectChildrenWithName("cocoa", collection);
  FXUTAssert( collection.empty() );
  root->collectChildrenWithName("cocoa", collection, true);
  FXUTAssertEqual( collection.size(), (size_t)2 );
}


@end
