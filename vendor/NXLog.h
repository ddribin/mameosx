/*******************************************************************************
	NXLog.h v1.1
		Copyright (c) 2006 Jonathan 'Wolf' Rentzsch: <http://rentzsch.com>
		Some rights reserved: <http://opensource.org/licenses/mit-license.php>

	***************************************************************************/

#import <Foundation/Foundation.h>

//	What you need to remember: Debug > Info > Warn > Error > Fatal.

typedef enum {
	NXLogLevel_UNSET,
    NXLogLevel_Debug,
    NXLogLevel_Info,
    NXLogLevel_Warn,
    NXLogLevel_Error,
    NXLogLevel_Fatal,
	NXLogLevel_Off,
} NXLogLevel;

@interface NSObject (NXLogAdditions)
+ (NXLogLevel)classNXLogLevel;
+ (void)setClassNXLogLevel:(NXLogLevel)level_;

+ (NXLogLevel)defaultNXLogLevel;
+ (void)setDefaultNXLogLevel:(NXLogLevel)level_;
@end

BOOL IsNXLogLevelActive(id self_, NXLogLevel level_);
void NXLog( id self_, NXLogLevel level_, unsigned line_, const char *file_, const char *function_, NSString *format_, ... );

#define NXLOG_CONDITIONALLY(sender,LEVEL,format,...) \
	if(IsNXLogLevelActive(sender,LEVEL)){NXLog(sender,LEVEL,__LINE__,__FILE__,__PRETTY_FUNCTION__,(format),##__VA_ARGS__);}

//
//	Scary macros!
//	The 1st #if is a filter, which you can read "IF any of the symbols are defined, THEN don't log for that level, ELSE do log for that level."
//

#if defined(NXLOGLEVEL_OFF) || defined(NXLOGLEVEL_FATAL) || defined(NXLOGLEVEL_ERROR) || defined(NXLOGLEVEL_WARN) || defined(NXLOGLEVEL_INFO)
	#define NXLogDebug(format,...)
	#define NXCLogDebug(format,...)
#else
	#define NXLogDebug(format,...)		NXLOG_CONDITIONALLY(self, NXLogLevel_Debug, format, ##__VA_ARGS__)
	#define NXCLogDebug(format,...)		NXLOG_CONDITIONALLY(nil, NXLogLevel_Debug, format, ##__VA_ARGS__)
#endif

#if defined(NXLOGLEVEL_OFF) || defined(NXLOGLEVEL_FATAL) || defined(NXLOGLEVEL_ERROR) || defined(NXLOGLEVEL_WARN)
	#define NXLogInfo(format,...)
	#define NXCLogInfo(format,...)
#else
	#define NXLogInfo(format,...)		NXLOG_CONDITIONALLY(self, NXLogLevel_Info, format, ##__VA_ARGS__)
	#define NXCLogInfo(format,...)		NXLOG_CONDITIONALLY(nil, NXLogLevel_Info, format, ##__VA_ARGS__)
#endif

#if defined(NXLOGLEVEL_OFF) || defined(NXLOGLEVEL_FATAL) || defined(NXLOGLEVEL_ERROR)
	#define NXLogWarn(format,...)
	#define NXCLogWarn(format,...)
#else
	#define NXLogWarn(format,...)		NXLOG_CONDITIONALLY(self, NXLogLevel_Warn, format, ##__VA_ARGS__)
	#define NXCLogWarn(format,...)		NXLOG_CONDITIONALLY(nil, NXLogLevel_Warn, format, ##__VA_ARGS__)
#endif

#if defined(NXLOGLEVEL_OFF) || defined(NXLOGLEVEL_FATAL)
	#define NXLogError(format,...)
	#define NXCLogError(format,...)
#else
	#define NXLogError(format,...)		NXLOG_CONDITIONALLY(self, NXLogLevel_Error, format, ##__VA_ARGS__)
	#define NXCLogError(format,...)		NXLOG_CONDITIONALLY(nil, NXLogLevel_Error, format, ##__VA_ARGS__)
#endif

#if defined(NXLOGLEVEL_OFF)
	#define NXLogFatal(format,...)
	#define NXCLogFatal(format,...)
#else
	#define NXLogFatal(format,...)		NXLOG_CONDITIONALLY(self, NXLogLevel_Fatal, format, ##__VA_ARGS__)
	#define NXCLogFatal(format,...)		NXLOG_CONDITIONALLY(nil, NXLogLevel_Fatal, format, ##__VA_ARGS__)
#endif
