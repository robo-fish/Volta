int main(int argc, char *argv[])
{
#if 0
  setenv("NSZombieEnabled", "YES", 1);
  // Alternatively, we can include <Foundation/NSDebug.h> and set NSZombieEnabled = YES
  NSLog(@"Attention: Zombified session!");
#endif

#if 0
  setenv("EventDebug", "1", 1);
  NSLog(@"Attention: Carbon event debugging turned on!");
#endif

  return NSApplicationMain(argc, (const char **) argv);
}
