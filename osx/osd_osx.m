#include "osdepend.h"
#include "render.h"
#import "MameController.h"
#import "MameInputController.h"
#import "MameAudioController.h"

#include <unistd.h>

static MameController * sController;

void osd_set_controller(MameController * controller)
{
    sController = controller;
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
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    int rc = [sAudioController osd_start_audio_stream: stereo];
    [pool release];
    return rc;
}

int osd_update_audio_stream(INT16 *buffer)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    int rc = [sAudioController osd_update_audio_stream: buffer];
    [pool release];
    return rc;
}

void osd_stop_audio_stream(void)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    [sAudioController osd_stop_audio_stream];
    [pool release];
}

void osd_set_mastervolume(int attenuation)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    [sAudioController osd_set_mastervolume: attenuation];
    [pool release];
}

int osd_get_mastervolume(void)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    int rc = [sAudioController osd_get_mastervolume];
    [pool release];
    return rc;
}

void osd_sound_enable(int enable)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    [sAudioController osd_sound_enable: enable];
    [pool release];
}

// locking stubs

osd_lock *osd_lock_alloc(void)
{
    return (osd_lock *)1;
}

void osd_lock_acquire(osd_lock *lock)
{
}

int osd_lock_try(osd_lock *lock)
{
        return TRUE;
}

void osd_lock_release(osd_lock *lock)
{
}

void osd_lock_free(osd_lock *lock)
{
}


/******************************************************************************

    Timing

******************************************************************************/

cycles_t osd_cycles(void)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    cycles_t rc = [sController osd_cycles];
    [pool release];
    return rc;
}

cycles_t osd_cycles_per_second(void)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    cycles_t rc = [sController osd_cycles_per_second];
    [pool release];
    return rc;
}

cycles_t osd_profiling_ticks(void)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    cycles_t rc = [sController osd_profiling_ticks];
    [pool release];
    return rc;
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
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    int rc = [sController osd_update: emutime];
    [pool release];
    return rc;
}

const char *osd_get_fps_text(const performance_info *performance)
{
    return "DLD FPS: 0";
}

/******************************************************************************

    Core

******************************************************************************/


int osd_init(void)
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    int rc = [sController osd_init];
    [pool release];
    return rc;
}
