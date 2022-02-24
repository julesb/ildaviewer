public class IldaPlayerAsync {
  public IldaFile file;
  public IldaFrame currentFrame;
  public int pointsPerSec = 12000;
  int currentFrameIdx = 0;
  int prevFrameIdx = -1;
  boolean paused = false;
  boolean ended = false;
  boolean repeat = true;
  boolean oscSendEnabled = false;
  boolean highPrecision = false;
  long t_nextframe = 0;
  boolean scrubbing = false;
  
  float[] oscBufferX;
  float[] oscBufferY;
  float[] oscBufferBl;
  float[] oscBufferR;
  float[] oscBufferG;
  float[] oscBufferB;
  public IldaPlayerAsync(IldaFile file, int pps, boolean oscEnabled, boolean repeat) {
    this.file = file;
    if (file == null || file.frameCount == 0) {
      return;
    }
    this.pointsPerSec = pps;
    this.repeat = repeat;
    this.oscSendEnabled = oscEnabled;
    currentFrameIdx = 0;
    this.loadFrame(currentFrameIdx);
  }


  public void play() throws InterruptedException{
    println("IldaPlayerAsync.play(): " + this.file.name);
    while(!this.ended) {
      long t_now = System.nanoTime();
      if ((!this.paused || scrubbing) && t_now >= t_nextframe) {
        double fps = ((double)this.pointsPerSec / currentFrame.pointCount);
        long frameDuration = (long)((1000000000.0 / fps));
        t_nextframe = t_now + frameDuration;

        oscSendFrame(this.currentFrame);

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
    println("IldaPlayerAsync.stop(): ended: "+ this.file.name);
    this.ended = true;
  }

  public void pause(boolean paused) {
    this.paused = paused;
  }

  public void loadFrame(int frameIdx) {
    if (file == null || file.frameCount == 0) {
      return;
    }
    this.currentFrame = file.frames.get(frameIdx);
    this.currentFrameIdx = frameIdx;
  }
  
  public void nextFrame() {
    if (this.file == null || this.file.frameCount == 0) {
      return;
    }
    this.prevFrameIdx = currentFrameIdx;
    this.currentFrameIdx = (this.currentFrameIdx+1) % this.file.frameCount;
    this.loadFrame(this.currentFrameIdx);
  }
  
  public void prevFrame() {
    if (!paused || file == null || file.frameCount == 0) {
      return;
    }
    currentFrameIdx = (currentFrameIdx <= 0)? file.frameCount-1: currentFrameIdx-1;
    this.loadFrame(currentFrameIdx);
  }

  public float getOscFps() {
    if (this.currentFrame == null || this.currentFrame.pointCount == 0) {
      return 0.0;
    }
    return (float)this.pointsPerSec / this.currentFrame.pointCount;
  }

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
}
