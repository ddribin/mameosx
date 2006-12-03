/*******************************************************************************
	NXLog.m v1.1
		Copyright (c) 2006 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import "NXLog.h"

BOOL		gLoadedNXLogSettings = NO;
NXLogLevel	gDefaultNXLogLevel = NXLogLevel_Debug;

static NXLogLevel parseNXLogLevel(NSString *level_) {
	static NSDictionary *levelLookup = nil;
	if (!levelLookup) {
		levelLookup = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:NXLogLevel_Debug], @"debug",
			[NSNumber numberWithInt:NXLogLevel_Info], @"info",
			[NSNumber numberWithInt:NXLogLevel_Warn], @"warn",
			[NSNumber numberWithInt:NXLogLevel_Error], @"error",
			[NSNumber numberWithInt:NXLogLevel_Fatal], @"fatal",
			[NSNumber numberWithInt:NXLogLevel_Off], @"off",
			nil];
	}
	NSNumber *result = [levelLookup objectForKey:[level_ lowercaseString]];
	return result ? [result intValue] : NXLogLevel_UNSET;
}

static void LoadNXLogSettings() {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSMutableDictionary *settings = [NSMutableDictionary dictionary];
	[settings addEntriesFromDictionary:[[NSBundle mainBundle] infoDictionary]];
	[settings addEntriesFromDictionary:[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]];
	
	NSArray *keys = [settings allKeys];
	unsigned keyIndex = 0, keyCount = [keys count];
	for(; keyIndex < keyCount; keyIndex++) {
		NSString *key = [keys objectAtIndex:keyIndex];
		if ([key hasPrefix:@"NXLogLevel"]) {
			NXLogLevel level = parseNXLogLevel([settings objectForKey:key]);
			if (NXLogLevel_UNSET == level) {
				NSLog(@"NXLog: can't parse \"%@\" NXLogLevel value for key \"%@\"", [settings objectForKey:key], key);
			} else {
				NSArray *keyNames = [key componentsSeparatedByString:@"."];
				if ([keyNames count] == 2) {
					//	It's a pseudo-keypath: NXLogLevel.MyClassName.
					Class c = NSClassFromString([keyNames lastObject]);
					if (c) {
						[c setClassNXLogLevel:level];
					} else {
						NSLog(@"NXLog: unknown class \"%@\"", [keyNames lastObject]);
					}
				} else {
					//	Just a plain "NXLogLevel": it's for the default level.
					[NSObject setDefaultNXLogLevel:level];
				}
			}
		}
	}
	
	[pool release];
}

BOOL IsNXLogLevelActive(id self_, NXLogLevel callerLevel_) {
	assert(callerLevel_ >= NXLogLevel_Debug && callerLevel_ <= NXLogLevel_Fatal);
	
	if (!gLoadedNXLogSettings) {
		gLoadedNXLogSettings = YES;
		LoadNXLogSettings();
	}
	
	//	Setting the default level to OFF disables all logging, regardless of everything else.
	if (NXLogLevel_Off == gDefaultNXLogLevel)
		return NO;
	
	NXLogLevel currentLevel;
	if (self_) {
		currentLevel = [[self_ class] classNXLogLevel];
		if (NXLogLevel_UNSET == currentLevel) { 
			currentLevel = gDefaultNXLogLevel;
		}
	} else {
		currentLevel = gDefaultNXLogLevel;
		// TODO It would be cool if we could use the file's name was a symbol to set logging levels for NXCLog... functions.
	}
	
	return callerLevel_ >= currentLevel;
}

	void
NXLog(
	id			self_,
	NXLogLevel	callerLevel_,
	unsigned	line_,
	const char	*file_,
	const char	*function_,
	NSString	*format_,
	...)
{
    assert(callerLevel_ >= NXLogLevel_Debug && callerLevel_ <= NXLogLevel_Fatal);
    assert(file_);
    assert(function_);
    assert(format_);
	
	//	
	va_list args;
	va_start(args, format_);
	NSString *message = [[NSString alloc] initWithFormat:format_ arguments:args];
	va_end(args);
	
	// "MyClass.m:123:  blah blah"
	NSLog(@"%@:%u: %@",
		  [[NSString stringWithUTF8String:file_] lastPathComponent],
		  line_,
		  message);
	
	if (NXLogLevel_Fatal == callerLevel_) {
		exit(0);
	}
}

@implementation NSObject (NXLogAdditions)

NSMapTable *gClassLoggingLevels = NULL;
+ (void)load {
	if (!gClassLoggingLevels) {
		gClassLoggingLevels = NSCreateMapTable(NSIntMapKeyCallBacks, NSIntMapValueCallBacks, 32);
	}
}

+ (NXLogLevel)classNXLogLevel {
	void *mapValue = NSMapGet(gClassLoggingLevels, self);
	if (mapValue) {
		return (NXLogLevel)mapValue;
	} else {
		Class superclass = [self superclass];
		return superclass ? [superclass classNXLogLevel] : NXLogLevel_UNSET;
	}
}

+ (void)setClassNXLogLevel:(NXLogLevel)level_ {
	if (NXLogLevel_UNSET == level_) {
		NSMapRemove(gClassLoggingLevels, self);
	} else {
		NSMapInsert(gClassLoggingLevels, self, (const void*)level_);
	}
}

+ (NXLogLevel)defaultNXLogLevel {
	return gDefaultNXLogLevel;
}

+ (void)setDefaultNXLogLevel:(NXLogLevel)level_ {
	assert(level_ >= NXLogLevel_Debug && level_ <= NXLogLevel_Off);
	gDefaultNXLogLevel = level_;
}

@end
