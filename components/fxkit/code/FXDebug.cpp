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

#import "FXDebug.h"
#include <pthread.h>
#include <assert.h>
#include <stdbool.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/sysctl.h>
#include <execinfo.h> // for stack trace
#include <iostream>


void FXDebug::interrupt()
{
  pthread_kill( pthread_self(), SIGINT );
}


bool FXDebug::amIBeingDebugged()
{
#if VOLTA_DEBUG
  // See Apple Technical Q&A document QA1361: http://developer.apple.com/library/mac/#qa/qa1361/_index.html

  struct kinfo_proc info;
  info.kp_proc.p_flag = 0;

  // Initializing mib to query the information about a specific process ID.
  int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };

  size_t size = sizeof(info);
  int junk = sysctl(mib, sizeof(mib) / sizeof(*mib), &info, &size, NULL, 0);
  assert(junk == 0);

  return ( (info.kp_proc.p_flag & P_TRACED) != 0 );
#else
  return false;
#endif
}


void FXDebug::printStackTrace()
{
  static const int skMaxTraces = 30;
  void* traceBuffer[skMaxTraces];
  int numTraces = backtrace((void**)(&traceBuffer), skMaxTraces);
  char** symbols = backtrace_symbols((void**)(&traceBuffer), numTraces);
  for ( int i = 0; i < numTraces; i++ )
  {
    std::cerr << symbols[i] << std::endl;
  }
}
