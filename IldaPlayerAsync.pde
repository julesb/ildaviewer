public class IldaPlayerAsync {
  public static final int MAX_OSC_FPS = 100;
  public IldaFile file;
  public IldaFrame currentFrame;
  public int pointsPerSec = 12000;
  int currentFrameIdx = 0;
  int prevFrameIdx = -1;
  int fileSeed = (int) (random(1.0) * 0xffffffff);
  int currentHash;
  int prevHash;
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

        //if (currentHash != prevHash) {
          oscSendFrameXYRGB(this.currentFrame);
        //}

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
    //println("exiting play() because ended=true");
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
    this.prevHash = currentHash;
    this.currentHash = frameHash(fileSeed, frameIdx);
    this.currentFrame = file.frames.get(frameIdx);
    this.prevFrameIdx = currentFrameIdx;
    this.currentFrameIdx = frameIdx;
  }
  
  public void nextFrame() {
    if (this.file == null || this.file.frameCount == 0) {
      return;
    }
    this.loadFrame((this.currentFrameIdx+1) % this.file.frameCount);
    if (paused) {
      oscSendFrameXYRGB(this.currentFrame);
    }
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
    if (numpoints > 2600) {
      file.droppedFrameCount++;
      return;
    }
    if (oscBufferXYRGBI == null || numpoints != oscBufferXYRGBI.length) {
      oscBufferXYRGBI = new float[numpoints*5];
    }
    for (int i=0; i< numpoints; i++) {
      IldaPoint p = frame.points.get(i);
      float blanknum = p.blank? 0.0 : 1.0;
      int bidx = i * 5;
      oscBufferXYRGBI[bidx+0]  =  p.x / (float)Short.MAX_VALUE * 0x7ff;
      oscBufferXYRGBI[bidx+1]  =  p.y / (float)Short.MAX_VALUE * 0x7ff;
      oscBufferXYRGBI[bidx+2]  =  p.rgb[0] * blanknum;
      oscBufferXYRGBI[bidx+3]  =  p.rgb[1] * blanknum;
      oscBufferXYRGBI[bidx+4]  =  p.rgb[2] * blanknum;
    }

    OscMessage ppsmsg = new OscMessage("/pps");
    ppsmsg.add(this.pointsPerSec);

    OscMessage frameMessage = new OscMessage("/xyrgb");
    frameMessage.add(oscBufferXYRGBI);

    oscP5.send(ppsmsg, network);
    try {
      oscP5.send(frameMessage, network);
    }
    catch(Exception e) {
      e.printStackTrace();
      println("OVERSIZE: " + oscBufferXYRGBI.length);
    }
  }
/*
  void oscSendFrame(IldaFrame frame) {
    if (! this.oscSendEnabled) {
      return;
    }
    int numpoints = frame.points.size();
    if (oscBufferX == null || numpoints != oscBufferX.length) {
      oscBufferX  = new float[numpoints];
      oscBufferY  = new float[numpoints];
      oscBufferBl = new float[numpoints];
      oscBufferR  = new float[numpoints];
      oscBufferG  = new float[numpoints];
      oscBufferB  = new float[numpoints];
    }
    for (int i=0; i< numpoints; i++) {
      IldaPoint p = frame.points.get(i);
      oscBufferX[i]  =  p.x / (float)Short.MAX_VALUE;
      oscBufferY[i]  =  p.y / (float)Short.MAX_VALUE;
      oscBufferBl[i] = p.blank? 1.0 : 0.0;
      oscBufferR[i]  = (float)p.rgb[0] / 255.0;
      oscBufferG[i]  = (float)p.rgb[1] / 255.0;
      oscBufferB[i]  = (float)p.rgb[2] / 255.0;
    }

    OscMessage ppsmsg = new OscMessage("/pps");
    ppsmsg.add(this.pointsPerSec);
  
    OscMessage pointsxMessage = new OscMessage("/pointsx");
    pointsxMessage.add(oscBufferX);
    OscMessage pointsyMessage = new OscMessage("/pointsy");
    pointsyMessage.add(oscBufferY);
    OscMessage blankMessage   = new OscMessage("/blank");
    blankMessage.add(oscBufferBl);
    OscMessage redMessage     = new OscMessage("/red");
    redMessage.add(oscBufferR);
    OscMessage greenMessage   = new OscMessage("/green");
    greenMessage.add(oscBufferG);
    OscMessage blueMessage    = new OscMessage("/blue");
    blueMessage.add(oscBufferB);

    oscP5.send(ppsmsg, network);
    oscP5.send(pointsxMessage, network);
    oscP5.send(pointsyMessage, network);
    oscP5.send(blankMessage, network);
    oscP5.send(redMessage, network);
    oscP5.send(greenMessage, network);
    oscP5.send(blueMessage, network);
  }
*/  
}
