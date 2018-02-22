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

class FXDebug
{
public:
  static void interrupt();

  /// @return true if the current process is running in the debugger or if a debugger is attached.
  static bool amIBeingDebugged();

  static void printStackTrace();
};

#if 1

  // http://cocoawithlove.com/2008/03/break-into-debugger.html
  #define FXDEBUG_BREAK if (FXDebug::amIBeingDebugged()) { __asm__("int $3\n" : : ); }

#else

  // Supposedly also supports ARM devices but caused EXC_BAD_INSTRUCTION.
  // http://iphone.m20.nl/wp/2010/10/xcode-iphone-debugger-halt-assertions/
  #if TARGET_CPU_ARM
    #define DEBUGSTOP(signal) __asm__ __volatile__ ("mov r0, %0\nmov r1, %1\nmov r12, #37\nswi 128\n" : : "r" (getpid ()), "r" (signal) : "r12", "r0", "r1", "cc");
    #define FXDEBUG_BREAK do { int trapSignal = FXDebug::amIBeingDebugged() ? SIGINT : SIGSTOP; DEBUGSTOP(trapSignal); if (trapSignal == SIGSTOP) { DEBUGSTOP (SIGINT); } } while (false);
  #else
    #define FXDEBUG_BREAK do { int trapSignal = FXDebug::amIBeingDebugged() ? SIGINT : SIGSTOP; __asm__ __volatile__ ("pushl %0\npushl %1\npush $0\nmovl %2, %%eax\nint $0x80\nadd $12, %%esp" : : "g" (trapSignal), "g" (getpid ()), "n" (37) : "eax", "cc"); } while (false);
  #endif

#endif

