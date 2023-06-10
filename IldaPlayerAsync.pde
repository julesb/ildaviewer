import java.util.zip.Deflater;

public class IldaPlayerAsync {
  public static final int MAX_OSC_FPS = 100;
  public IldaFile file;
  public IldaFrame currentFrame;
  public int pointsPerSec = 12000;
  int currentFrameIdx = 0;
  int prevFrameIdx = -1;
  int fileSeed = (int) (random(1.0) * 0xffffffff);
  boolean paused = false;
  boolean ended = false;
  boolean repeat = true;
  boolean oscSendEnabled = false;
  boolean highPrecision = false;
  long t_nextframe = 0;
  boolean scrubbing = false;
  
  float[] oscBufferXYRGBI;

  public IldaPlayerAsync(IldaFile file, int pps, boolean oscEnabled, boolean repeat) {
    this.file = file;
    if (file == null || file.frameCount == 0) {
      return;
    }
    this.pointsPerSec = pps;
    this.repeat = repeat;
    this.oscSendEnabled = oscEnabled;
    currentFrameIdx = -1;
    this.nextFrame();
  }


  public void play() throws InterruptedException{
    println("IldaPlayerAsync.play(): " + this.file.name);
    while(!this.ended) {
      long t_now = System.nanoTime();
      if ((!this.paused || scrubbing) && t_now >= t_nextframe) {
        double fps = ((double)this.pointsPerSec / currentFrame.pointCount);
        fps = (fps < MAX_OSC_FPS)? fps : MAX_OSC_FPS;
        long frameDuration = (long)((1000000000.0 / fps));
        t_nextframe = t_now + frameDuration;

        if (scrubbing) {
          loadFrame(currentFrameIdx);
          continue;
        }

        if (!this.repeat && this.currentFrameIdx >= this.file.frameCount) {
          this.ended = true;
          break;
        }

        if (this.currentFrameIdx >= this.file.frameCount-1
            && this.prevFrameIdx != currentFrameIdx) {
          file.droppedFrameCount = 0;
          endOfFileCallback();
        }

        this.nextFrame();

        if (!highPrecision) {
          Thread.sleep(1);
        }
      }
      else {
        Thread.sleep(50);
      }
    }
  }
  
  public void stop() {
    println("IldaPlayerAsync.stop(): "+ this.file.name);
    this.ended = true;
  }

  public void pause(boolean paused) {
    println("IldaPlayerAsync.paused(): "+ paused);
    this.paused = paused;
  }

  public void loadFrame(int frameIdx) {
    if (file == null || file.frameCount == 0) {
      return;
    }
    this.currentFrame = file.frames.get(frameIdx);
    this.prevFrameIdx = currentFrameIdx;
    this.currentFrameIdx = frameIdx;
    oscSendFrameXYRGB(this.currentFrame);
  }
  
  public void nextFrame() {
    if (this.file == null || this.file.frameCount == 0) {
      return;
    }
    int newFrameIdx = currentFrameIdx + 1;
    if (newFrameIdx == file.frameCount && this.file.frameCount == 1) {
      return;
    }
    this.loadFrame((this.currentFrameIdx+1) % this.file.frameCount);
  }
  
  public void prevFrame() {
    if (!paused || file == null || file.frameCount == 0) {
      return;
    }
    currentFrameIdx = (currentFrameIdx <= 0)? file.frameCount-1: currentFrameIdx-1;
    this.loadFrame(currentFrameIdx);
    oscSendFrameXYRGB(this.currentFrame);
  }

  public float getOscFps() {
    if (this.currentFrame == null || this.currentFrame.pointCount == 0) {
      return 0.0;
    }
    float fps = (float)this.pointsPerSec / this.currentFrame.pointCount;
    fps = (fps < MAX_OSC_FPS)? fps : MAX_OSC_FPS;
    return fps;
  }

  public int frameHash(int seed, int frameIdx) {
    return seed * 10000 + frameIdx;
  }




  void oscSendFrameXYRGB(IldaFrame frame) {
    if (! this.oscSendEnabled) {
      return;
    }

    int numpoints = frame.points.size();
    if (numpoints == 0) {
      return;
    }
    byte[] packedData = new byte[numpoints * 7]; // 7 bytes for each point

    for (int i = 0; i < numpoints; i++) {
      IldaPoint p = frame.points.get(i);
      int blanknum = p.blank? 0: 1;

      int offset = i * 7;
      int x = p.x + 0x8000;
      int y = p.y + 0x8000;
      int r = p.rgb[0] * blanknum;
      int g = p.rgb[1] * blanknum;
      int b = p.rgb[2] * blanknum;

      packUInt16(packedData, offset + 0, x);
      packUInt16(packedData, offset + 2, y);
      packUInt8(packedData, offset + 4, r);
      packUInt8(packedData, offset + 5, g);
      packUInt8(packedData, offset + 6, b);
    }

    Deflater deflater = new Deflater();
    deflater.setInput(packedData);
    deflater.finish();
    byte[] compressedData = new byte[packedData.length];
    int compressedDataLength = deflater.deflate(compressedData);

    OscMessage msg = new OscMessage("/f");
    msg.add(compressedData);
    oscP5.send(msg, network);
  }

  void packUInt16(byte[] bytes, int offset, int value) {
    bytes[offset] = (byte) (value & 0xFF);
    bytes[offset + 1] = (byte) ((value >> 8) & 0xFF);
  }
  
  void packUInt8(byte[] bytes, int offset, int value) {
    bytes[offset] = (byte) (value & 0xFF);
  }

}
