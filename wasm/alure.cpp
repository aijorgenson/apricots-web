#include "AL/alure.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>

static ALCdevice *gDevice = nullptr;
static ALCcontext *gContext = nullptr;

// Minimal RIFF/WAVE reader: walks the chunk list so it works with 'fmt ',
// 'data', and any interleaved chunks (LIST, fact, ...) that some files have.
static char *readWave(const char *filename, unsigned int *dataSizeOut,
                      ALenum *formatOut, ALsizei *rateOut) {
  FILE *f = fopen(filename, "rb");
  if (!f) return nullptr;

  char tag[5] = {0};
  unsigned int sz;
  if (fread(tag, 1, 4, f) != 4 || fread(&sz, 4, 1, f) != 1 ||
      fread(tag, 1, 4, f) != 4) {
    fclose(f);
    return nullptr;
  }
  if (memcmp(tag, "WAVE", 4) != 0) {
    fclose(f);
    return nullptr;
  }

  unsigned short audioFormat = 0, channels = 0, bits = 0;
  unsigned int rate = 0;
  char *data = nullptr;
  unsigned int dataLen = 0;

  while (fread(tag, 1, 4, f) == 4) {
    if (fread(&sz, 4, 1, f) != 1) break;
    if (memcmp(tag, "fmt ", 4) == 0) {
      unsigned char fmt[40] = {0};
      unsigned int toread = sz < sizeof(fmt) ? sz : sizeof(fmt);
      if (fread(fmt, 1, toread, f) != toread) break;
      if (toread >= 2) audioFormat = fmt[0] | (fmt[1] << 8);
      if (toread >= 4) channels = fmt[2] | (fmt[3] << 8);
      if (toread >= 8) rate = fmt[4] | (fmt[5] << 8) | (fmt[6] << 16) | (fmt[7] << 24);
      if (toread >= 16) bits = fmt[14] | (fmt[15] << 8);
      if ((sz & 1) && sz >= toread) fseek(f, 1, SEEK_CUR);
    } else if (memcmp(tag, "data", 4) == 0) {
      dataLen = sz;
      data = (char *)malloc(dataLen ? dataLen : 1);
      if (!data) { fclose(f); return nullptr; }
      if (fread(data, 1, dataLen, f) != dataLen) {
        free(data);
        fclose(f);
        return nullptr;
      }
      if (sz & 1) fseek(f, 1, SEEK_CUR);
    } else {
      if (fseek(f, sz + (sz & 1), SEEK_CUR) != 0) break;
    }
  }
  fclose(f);

  if (!data) return nullptr;

  ALenum format;
  if (channels == 1) format = (bits == 8) ? AL_FORMAT_MONO8 : (bits == 16) ? AL_FORMAT_MONO16 : AL_NONE;
  else if (channels == 2) format = (bits == 8) ? AL_FORMAT_STEREO8 : (bits == 16) ? AL_FORMAT_STEREO16 : AL_NONE;
  else format = AL_NONE;

  if (format == AL_NONE || audioFormat != 1) { free(data); return nullptr; }

  *dataSizeOut = dataLen;
  *formatOut = format;
  *rateOut = (ALsizei)rate;
  return data;
}

ALCdevice *alureInitDevice(const ALCchar *deviceName, const ALCint *attrList) {
  if (!gDevice) {
    gDevice = alcOpenDevice(deviceName);
    if (gDevice) {
      gContext = alcCreateContext(gDevice, attrList);
      if (gContext) alcMakeContextCurrent(gContext);
    }
  }
  return gDevice;
}

void alureShutdownDevice(void) {
  if (gContext) {
    alcMakeContextCurrent(nullptr);
    alcDestroyContext(gContext);
    gContext = nullptr;
  }
  if (gDevice) {
    alcCloseDevice(gDevice);
    gDevice = nullptr;
  }
}

ALuint alureCreateBufferFromFile(const char *filename) {
  unsigned int dataSize = 0;
  ALenum format = AL_NONE;
  ALsizei rate = 0;

  char *data = readWave(filename, &dataSize, &format, &rate);
  if (!data) return AL_NONE;

  ALuint buffer = AL_NONE;
  alGenBuffers(1, &buffer);
  if (buffer == AL_NONE) {
    free(data);
    return AL_NONE;
  }
  alBufferData(buffer, format, data, (ALsizei)dataSize, rate);
  free(data);
  return buffer;
}

// Used by sampleio on _WIN32; harmless stub for wasm.
extern "C" int alureLoadWAVFile(const char *filename, ALenum *format, void **data, ALsizei *size, ALsizei *freq,
                                ALboolean *loop) {
  unsigned int dataSize = 0;
  char *p = readWave(filename, &dataSize, format, freq);
  if (!p) return 0;
  *data = p;
  *size = (ALsizei)dataSize;
  *loop = AL_FALSE;
  return 1;
}