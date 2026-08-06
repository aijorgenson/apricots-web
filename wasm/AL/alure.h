#ifndef ALCURE_H
#define ALCURE_H

#include <AL/al.h>
#include <AL/alc.h>

#ifdef __cplusplus
extern "C" {
#endif

ALCdevice *alureInitDevice(const ALCchar *deviceName, const ALCint *attrList);
void alureShutdownDevice(void);
ALuint alureCreateBufferFromFile(const char *filename);

#ifdef __cplusplus
}
#endif

#endif