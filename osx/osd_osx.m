#include "osdepend.h"
#include "render.h"
#import "MameView.h"
#import "MameInputController.h"
#import "MameAudioController.h"
#import "MameTimingController.h"
#import "MameFileManager.h"

#include <unistd.h>


static void mame_did_exit(running_machine * machine);

/******************************************************************************

    Core

******************************************************************************/

static MameView * sController;

void osd_set_controller(MameView * controller)
{
    sController = controller;
}

int osd_init(running_machine *machine)
{
    add_exit_callback(machine, mame_did_exit);
    return [sController osd_init: machine];
}

static void mame_did_exit(running_machine * machine)
{
    [sController mameDidExit: machine];
}

/******************************************************************************

    Sound

******************************************************************************/

static MameAudioController * sAudioController;

void osd_set_audio_controller(MameAudioController * audioController)
{
    sAudioController = audioController;
}

int osd_start_audio_stream(int stereo)
{
    return [sAudioController osd_start_audio_stream: stereo];
}

int osd_update_audio_stream(INT16 *buffer)
{
     return [sAudioController osd_update_audio_stream: buffer];
}

void osd_stop_audio_stream(void)
{
    [sAudioController osd_stop_audio_stream];
}

void osd_set_mastervolume(int attenuation)
{
    [sAudioController osd_set_mastervolume: attenuation];
}

int osd_get_mastervolume(void)
{
    return [sAudioController osd_get_mastervolume];
}

void osd_sound_enable(int enable)
{
    [sAudioController osd_sound_enable: enable];
}


/******************************************************************************

    Locking

******************************************************************************/

osd_lock * osd_lock_alloc(void)
{
    NSRecursiveLock * lock = [[NSRecursiveLock alloc] init];;
    return (osd_lock *) lock;
}

void osd_lock_acquire(osd_lock * mame_lock)
{
    NSRecursiveLock * lock = (NSRecursiveLock *) mame_lock;
    [lock lock];
}

int osd_lock_try(osd_lock * mame_lock)
{
    NSRecursiveLock * lock = (NSRecursiveLock *) mame_lock;
    return [lock tryLock];
}

void osd_lock_release(osd_lock * mame_lock)
{
    NSRecursiveLock * lock = (NSRecursiveLock *) mame_lock;
    [lock unlock];
}

void osd_lock_free(osd_lock * mame_lock)
{
    NSRecursiveLock * lock = (NSRecursiveLock *) mame_lock;
    [lock release];
}


/******************************************************************************

    Timing

******************************************************************************/

static MameTimingController * sTimingController;

void osd_set_timing_controller(MameTimingController * timingController)
{
    sTimingController = timingController;
}

cycles_t osd_cycles(void)
{
    return [sTimingController osd_cycles];
}

cycles_t osd_cycles_per_second(void)
{
    return [sTimingController osd_cycles_per_second];
}

cycles_t osd_profiling_ticks(void)
{
    return [sTimingController osd_profiling_ticks];
}


/******************************************************************************

    Controls

******************************************************************************/

static MameInputController * sInputController;

void osd_set_input_controller(MameInputController * inputController)
{
    sInputController = inputController;
}

const os_code_info *osd_get_code_list(void)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    const os_code_info * rc = [sInputController osd_get_code_list];
    [pool release];
    return rc;
}

INT32 osd_get_code_value(os_code code)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    INT32 rc = [sInputController osd_get_code_value: code];
    [pool release];
    return rc;
}

int osd_readkey_unicode(int flush)
{
    return 0;
}

void osd_customize_inputport_list(input_port_default_entry *defaults)
{
}

int osd_joystick_needs_calibration(void)
{
    return 0;
}

void osd_joystick_start_calibration(void)
{
}

const char *osd_joystick_calibrate_next(void)
{
    return 0;
}

void osd_joystick_calibrate(void)
{
}

void osd_joystick_end_calibration(void)
{
}


/******************************************************************************

    Display

******************************************************************************/

int osd_update(mame_time emutime)
{
    return [sController osd_update: emutime];
}

const char *osd_get_fps_text(const performance_info *performance)
{
    static char buffer[1024];
    sprintf(buffer, "%4d%%%4d/%d fps",
            (int)(performance->game_speed_percent + 0.5),
            (int)(performance->frames_per_second + 0.5),
            (int)(Machine->screen[0].refresh + 0.5));
    return buffer;
}


/******************************************************************************

    File I/O

******************************************************************************/

static MameFileManager * sFileManager = nil;

void osd_set_file_manager(MameFileManager * fileManager)
{
    sFileManager = fileManager;
}

#if 1
const char * osd_pathtype_string(int pathtype)
{
    switch(pathtype)
    {
        case FILETYPE_RAW: return "FILETYPE_RAW";
        case FILETYPE_ROM: return "FILETYPE_ROM";
        case FILETYPE_IMAGE: return "FILETYPE_IMAGE";
        case FILETYPE_IMAGE_DIFF: return "FILETYPE_IMAGE_DIFF";
        case FILETYPE_SAMPLE: return "FILETYPE_SAMPLE";
        case FILETYPE_ARTWORK: return "FILETYPE_ARTWORK";
        case FILETYPE_NVRAM: return "FILETYPE_NVRAM";
        case FILETYPE_HIGHSCORE: return "FILETYPE_HIGHSCORE";
        case FILETYPE_HIGHSCORE_DB: return "FILETYPE_HIGHSCORE_DB";
        case FILETYPE_CONFIG: return "FILETYPE_CONFIG";
        case FILETYPE_INPUTLOG: return "FILETYPE_INPUTLOG";
        case FILETYPE_STATE: return "FILETYPE_STATE";
        case FILETYPE_MEMCARD: return "FILETYPE_MEMCARD";
        case FILETYPE_SCREENSHOT: return "FILETYPE_SCREENSHOT";
        case FILETYPE_MOVIE: return "FILETYPE_MOVIE";
        case FILETYPE_HISTORY: return "FILETYPE_HISTORY";
        case FILETYPE_CHEAT: return "FILETYPE_CHEAT";
        case FILETYPE_LANGUAGE: return "FILETYPE_LANGUAGE";
        case FILETYPE_CTRLR: return "FILETYPE_CTRLR";
        case FILETYPE_INI: return "FILETYPE_INI";
        case FILETYPE_COMMENT: return "FILETYPE_COMMENT";
        case FILETYPE_DEBUGLOG: return "FILETYPE_DEBUGLOG";
        case FILETYPE_HASH: return "FILETYPE_HASH";
        case FILETYPE_FONT: return "FILETYPE_FONT";
        default: return "FILETYPE uknown";
    }
}

/* Return the number of paths for a given type */
int osd_get_path_count(int pathtype)
{
    return [sFileManager osd_get_path_count: pathtype];
}

/* Get information on the existence of a file */
int osd_get_path_info(int pathtype, int pathindex, const char *filename)
{
    return [sFileManager osd_get_path_info: pathtype
                                 pathindex: pathindex
                                  filename: filename];
}

/* Create a directory if it doesn't already exist */
int osd_create_directory(int pathtype, int pathindex, const char *dirname)
{
    printf("osd_create_directory(%s, %d, %s)\n", osd_pathtype_string(pathtype), pathindex, dirname);
    return 0;
}

/* Attempt to open a file with the given name and mode using the specified path type */
osd_file *osd_fopen(int pathtype, int pathindex, const char *filename, const char *mode, osd_file_error *error)
{
    return [sFileManager osd_fopen: pathtype
                         pathindex: pathindex
                          filename: filename
                              mode: mode
                             error: error];
}

/* Seek within a file */
int osd_fseek(osd_file *file, INT64 offset, int whence)
{
    return [sFileManager osd_fseek: file
                            offset: offset
                            whence: whence];
}

/* Return current file position */
UINT64 osd_ftell(osd_file *file)
{
    return [sFileManager osd_ftell: file];
}    

/* Return 1 if we're at the end of file */
int osd_feof(osd_file *file)
{
    return [sFileManager osd_feof: file];
}

/* Read bytes from a file */
UINT32 osd_fread(osd_file *file, void *buffer, UINT32 length)
{
    return [sFileManager osd_fread: file
                            buffer: buffer
                            length: length];
}

/* Write bytes to a file */
UINT32 osd_fwrite(osd_file *file, const void *buffer, UINT32 length)
{
    return [sFileManager osd_fwrite: file
                             buffer: buffer
                             length: length];
}

/* Close an open file */
void osd_fclose(osd_file *file)
{
    [sFileManager osd_fclose: file];
}

//============================================================
//	osd_display_loading_rom_message
//============================================================

// called while loading ROMs. It is called a last time with name == 0 to signal
// that the ROM loading process is finished.
// return non-zero to abort loading
int osd_display_loading_rom_message(const char *name, rom_load_data *romdata)
{
#if 0
	if (name)
		fprintf(stdout, "loading %-12s\r", name);
	else
		fprintf(stdout, "                    \r");
	fflush(stdout);
#endif
    
	return 0;
}

#endif

void osd_break_into_debugger(const char *message)
{
}

void osd_wait_for_debugger(void)
{
}
