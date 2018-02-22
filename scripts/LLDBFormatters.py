"""
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

------------------

This file provides LLDB summary formatters for some frequently used
Volta object types.

Add the formatting capability to your current LLDB session by entering
  command script import <path_to_this_file>

You can also place the above command in your .lldbinit file

Examples for summary formatter scripts can be found in LLDB.framework itself.
"""

import lldb

def VoltaPTModelPtr_summary( valueObject, dictionary ):
  error = lldb.SBError()
  pointerIV = valueObject.GetChildMemberWithName('__ptr_')
  return pointerIV.GetSummary()


def VoltaPTModel_summary( valueObject, dictionary ):
  nameIV = valueObject.GetChildMemberWithName('name')
  modelIV = valueObject.GetChildMemberWithName('vendor')
  return 'name = ' + nameIV.GetSummary() + ', vendor = ' + modelIV.GetSummary()


def FXString_summary( valueObject, dictionary ):
  error = lldb.SBError()
  nameIV = valueObject.GetChildMemberWithName('mString')
  summary = nameIV.GetSummary().lstrip('@')
  if summary == "<variable is not NSString>":
    summary = '\"\"'
  return summary


def __lldb_init_module(debugger, init):
  #debugger.HandleCommand('type summary delete FXString')
  debugger.HandleCommand('type summary add FXString -F LLDBFormatters.FXString_summary')
  #debugger.HandleCommand('type summary delete VoltaPTModel')
  debugger.HandleCommand('type summary add VoltaPTModel -F LLDBFormatters.VoltaPTModel_summary')
  #debugger.HandleCommand('type summary delete VoltaPTModelPtr')
  debugger.HandleCommand('type summary add VoltaPTModelPtr -F LLDBFormatters.VoltaPTModelPtr_summary')
