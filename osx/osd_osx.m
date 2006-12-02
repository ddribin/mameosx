/*
 * Copyright (c) 2006 Dave Dribin
 * 
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include "osdepend.h"
#include "render.h"
#import "MameView.h"
#import "MameInputController.h"
#import "MameAudioController.h"
#import "MameTimingController.h"
#import "MameFileManager.h"

#include <unistd.h>


static void mame_did_exit(running_machine * machine);
static void mame_did_pause(running_machine * machine, int pause);
static void error_callback(void *param, const char *format, va_list argptr);
static void warning_callback(void *param, const char *format, va_list argptr);
static void info_callback(void *param, const char *format, va_list argptr);
static void debug_callback(void *param, const char *format, va_list argptr);
static void log_callback(void *param, const char *format, va_list argptr);
 
/******************************************************************************

    Core

******************************************************************************/

static MameView * sController;

void osd_set_controller(MameView * controller)
{
    sController = controller;
    mame_set_output_channel(OUTPUT_CHANNEL_ERROR, error_callback,
                            sController, NULL, NULL);
    mame_set_output_channel(OUTPUT_CHANNEL_WARNING, warning_callback,
                            sController, NULL, NULL);
    mame_set_output_channel(OUTPUT_CHANNEL_INFO, info_callback,
                            sController, NULL, NULL);
    mame_set_output_channel(OUTPUT_CHANNEL_DEBUG, debug_callback,
                            sController, NULL, NULL);
    mame_set_output_channel(OUTPUT_CHANNEL_LOG, log_callback,
                            sController, NULL, NULL);
}

int osd_init(running_machine *machine)
{
    add_exit_callback(machine, mame_did_exit);
    add_pause_callback(machine, mame_did_pause);
    
    return [sController osd_init: machine];
}

static void mame_did_exit(running_machine * machine)
{
    [sController mameDidExit: machine];
}

static void mame_did_pause(running_machine * machine, int pause)
{
    [sController mameDidPause: machine puase: pause];
}

static void error_callback(void *param, const char *format, va_list argptr)
{
    MameView * controller = (MameView *) param;
    [controller osd_output_error: format arguments: argptr];
}

static void warning_callback(void *param, const char *format, va_list argptr)
{
    MameView * controller = (MameView *) param;
    [controller osd_output_warning: format arguments: argptr];
}

static void info_callback(void *param, const char *format, va_list argptr)
{
    MameView * controller = (MameView *) param;
    [controller osd_output_info: format arguments: argptr];
}

static void debug_callback(void *param, const char *format, va_list argptr)
{
    MameView * controller = (MameView *) param;
    [controller osd_output_debug: format arguments: argptr];
}

static void log_callback(void *param, const char *format, va_list argptr)
{
    MameView * controller = (MameView *) param;
    [controller osd_output_log: format arguments: argptr];
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

mame_file_error osd_open(const char *path, UINT32 openflags, osd_file **file,
                         UINT64 *filesize)
{
    return [sFileManager osd_open: path
                            flags: openflags
                             file: file
                         filesize: filesize];
}

mame_file_error osd_close(osd_file *file)
{
    return [sFileManager osd_close: file];
}


mame_file_error osd_read(osd_file *file, void *buffer, UINT64 offset,
                         UINT32 length, UINT32 *actual)
{
    return [sFileManager osd_read: file
                           buffer: buffer
                           offset: offset
                           length: length
                           actual: actual];
}

mame_file_error osd_write(osd_file *file, const void *buffer, UINT64 offset,
                          UINT32 length, UINT32 *actual)
{
    return [sFileManager osd_write: file
                            buffer: buffer
                            offset: offset
                            length: length
                            actual: actual];
}

void *osd_alloc_executable(size_t size)
{
    void * ptr = (void *) malloc(size);
#if 0
    printf("osd_alloc_executable(%d [0x%08x]) = 0x%08x - 0x%08x\n", size, size,
           ptr, ((uint8_t *) ptr) + size);
#endif
    return ptr;
}

void osd_free_executable(void *ptr, size_t size)
{
    free(ptr);
}

void osd_break_into_debugger(const char *message)
{
}

void osd_wait_for_debugger(void)
{
}
