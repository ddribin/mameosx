/*
 *  osd_osx.h
 *  mameosx
 *
 *  Created by Dave Dribin on 9/4/06.
 *
 */

#if defined(__cplusplus)
extern "C" {
#endif

@class MameController;
@class MameInputController;
@class MameAudioController;

void osd_set_controller(MameController * controller);
void osd_set_input_controller(MameInputController * inputController);
void osd_set_audio_controller(MameAudioController * audioController);

#if defined(__cplusplus)
}
#endif
    