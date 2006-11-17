/*
 * Copyright (c) 2006 Dave Dribin <http://www.dribin.org/dave/>
 *
 * Some rights reserved: <http://opensource.org/licenses/mit-license.php>
 * 
 */

#if defined(__cplusplus)
extern "C" {
#endif

@class MameController;
@class MameInputController;
@class MameAudioController;
@class MameTimingController;
@class MameFileManager;

void osd_set_controller(MameView * controller);
void osd_set_input_controller(MameInputController * inputController);
void osd_set_audio_controller(MameAudioController * audioController);
void osd_set_timing_controller(MameTimingController * timingController);
void osd_set_file_manager(MameFileManager * fileManager);
const char * osd_pathtype_string(int pathtype);

#if defined(__cplusplus)
}
#endif
    
