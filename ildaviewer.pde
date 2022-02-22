import oscP5.*;
import netP5.*;
import java.io.File;
import java.util.Collections;

OscP5 oscP5;
NetAddress network;
OscProperties oscProps;
PFont font;


String ildaPath;
String ildaFilename;
IldaPlayerAsync player;

File[] dataFiles;
ArrayList<String> ildaFilenames = new ArrayList();
int currentFileIdx = 0;
int prevFileChangeTime = 0;
int fileLoopCount = 0;

//int fixedFrameRate = 60;

int pointsPerSec = 30000;
int autoChangeInterval = 2000; // ms
boolean autoChangeEnabled = false;
boolean autoChangeRandom = true;
boolean previewMode = false;
boolean constantPPS = false;
boolean showInfo = true;
boolean showBlankLines = true;
boolean oscSendEnabled = false;
boolean paused = false;


void setup() {
  size(1200, 1200);
  frameRate(60);

  oscProps = new OscProperties();
  network = new NetAddress("127.0.0.1", 12000);
  oscProps.setRemoteAddress(network);
  oscProps.setDatagramSize(4096);
  oscP5 = new OscP5(this, oscProps);

  if (args != null && args.length == 1) {
    ildaFilename = args[0];
    ildaFilenames.add(ildaFilename);
    autoChangeEnabled = false;
    previewMode = true;
    constantPPS = false;
    oscSendEnabled = false;
    println("arg filename:" + ildaFilename);
  } else {
    File datadir = new File(dataPath(""));
    ildaPath = datadir.getAbsolutePath();
    println("ilda path:" + ildaPath);
    dataFiles = datadir.listFiles();
    for (int i = 0; i < dataFiles.length; i++) {
      String baseName = dataFiles[i].getName();
      if (baseName.endsWith(".ild")) {
        println(baseName);
        ildaFilenames.add(baseName);
      }
    }
    Collections.sort(ildaFilenames);
    ildaFilename = ildaFilenames.get(0);
  }

  println("sketchpath: " + sketchPath());
  IldaFile file;
  if (previewMode) {
    file  = new IldaFile(ildaFilename, ildaFilename);
  } else {
    file = new IldaFile(dataPath(ildaFilename), ildaFilename);
  }
  
  player = new IldaPlayerAsync(file, this.pointsPerSec, this.oscSendEnabled, true);
  thread("playerThread");
  prevFileChangeTime = millis();

  blendMode(ADD); 
  font = loadFont("Courier-Bold-64.vlw");
  textFont(font);
  textSize(24);
  
}



void draw() {
  background(0);
  int t = millis();


  if (player != null && player.file != null && player.currentFrame != null) {
    drawFrame(player.currentFrame);
    
    if (autoChangeEnabled
      && fileLoopCount > 0
      && t - prevFileChangeTime > autoChangeInterval) {
      if (autoChangeRandom) {
        loadRandom();
      } else {
        loadNext();
      }
      prevFileChangeTime = t;
    }
    
  }

  if (showInfo) {
    drawInfo(2, 24);
  }

}


void keyPressed() {
  if (previewMode) {
    return;
  }
  if (key == CODED) {
    switch (keyCode) {
      case LEFT:
        loadPrev();
        break;
      case RIGHT:
        loadNext();
        break;
    }
  }
  if (paused) {
    redraw();
  }
}

void keyTyped() {
  println("key: " + key);
  switch(key) {
    case 'a':
      autoChangeEnabled = !autoChangeEnabled;
      println("auto change: " + autoChangeEnabled);
      break;
    case 'c':
      constantPPS = !constantPPS;
      if (!constantPPS) {
        //(fixedFrameRate);
      }
      println("constant PPS: " + constantPPS);
      break;
    case 'i':
      showInfo = !showInfo;
      break;
    case 'b':
      showBlankLines = !showBlankLines;
      break;
    case 'o':
      oscSendEnabled = !oscSendEnabled;
      if(player != null) {
        player.oscSendEnabled = oscSendEnabled;
      }
      break;
    case ' ':
      paused = !paused;
      player.pause(paused);
      if (paused) {
        noLoop();
      }
      else {
        loop();
      }
      break;
    case ',':
      if (paused) {
        prevFrame();
      }
      break;
    case '.':
      if (paused) {
        nextFrame();
      }
      break;
    case 'p':
      if (player != null && !player.ended) {
        player.stop();
      }
      else {
          thread("playerThread");
      }
      break;
    case '-':
      if (pointsPerSec > 1000) {
        pointsPerSec -= 1000;
      }
      player.pointsPerSec = pointsPerSec;
      break;
    case '=':
      pointsPerSec += 1000;
      player.pointsPerSec = pointsPerSec;
      break;
  }
  if (paused) {
    redraw();
  }
}

String makeShortName(String filename, int maxlen) {
  if (filename.length() <= maxlen) {
    return filename;
  }
  int extidx = filename.toLowerCase().indexOf(".ild");
  String s1;
  if (extidx < 0) {
    s1 = filename;
  }
  else {
    s1 = filename.substring(0, extidx);
  }
  String shortname = s1.substring(0, min(s1.length()-1, maxlen));
  return shortname;
}

void nextFrame() {
  if (player  == null || player.file == null) {
    return;
  }
  player.pause(true);
  player.nextFrame();
}
void prevFrame() {
  if (player  == null || player.file == null) {
    return;
  }
  player.pause(true);
  player.prevFrame();
}

void load(int fileIdx) {
  thread("playerThread");
}
void loadNext() {
  currentFileIdx++;
  currentFileIdx %= ildaFilenames.size();
  load(currentFileIdx);
}
void loadPrev() {
  currentFileIdx--;
  currentFileIdx = currentFileIdx < 0? ildaFilenames.size()-1: currentFileIdx;
  load(currentFileIdx);
}
void loadRandom() {
  currentFileIdx = (int)(random(1.0)*ildaFilenames.size());
  load(currentFileIdx);
}


void drawInfo(int x, int y) {  
  int lineheight = 24;
  int pps = 0;
  String fname = "";
  int frameidx = 0;
  int framecount = 0;
  int numpoints = 0;
  float oscfps = 0;
  String name = "", cname = "", formatname = "";
  if (player != null && player.currentFrame != null && player.currentFrame.header != null) {
    fname = player.file.name;
    pps = player.pointsPerSec;
    frameidx = player.currentFrameIdx;
    framecount = player.file.frameCount;
    name = player.currentFrame.header.name;
    cname = player.currentFrame.header.companyName;
    numpoints = player.currentFrame.pointCount;
    formatname = player.currentFrame.header.getFormatName();
    oscfps = player.getOscFps();
  }
  
  fill(192);
  text(String.format("%d/%d |%s |F:%04d/%04d |P:%4d |%s |%s%s" ,
       currentFileIdx+1,
       ildaFilenames.size(),
       fname,
       frameidx+1,
       framecount,
       numpoints,
       formatname,
       name,
       cname),
       x, y + lineheight*0);

  fill(128);
  text("PPS:     " + pps, x, y + lineheight*2);
  text("OSC FPS: " + String.format("%.1f", oscfps), x, y + lineheight*3);
  text("FPS:     " + String.format("%.1f", frameRate), x, y + lineheight*4);
  text("Auto:    " + autoChangeEnabled, x, y + lineheight*5);

  if (oscSendEnabled) {
    fill(240, 0, 0);
  } else {
    fill(128);
  }
  text("OSC:     " + oscSendEnabled, x, y + lineheight*6);

  drawProgress(0, 0, width, 2);
}

void drawFrame(IldaFrame frame) {
  if (frame == null) {
    println("ERROR: frame is null");
    return;
  }
  if (frame.points == null) {
    println("ERROR: frame.points is null");
    return;
  }

  if (frame.points.size() == 0) {
    return;
  }

  pushMatrix();
  translate(width/2, height/2);

  int npoints = frame.points.size();
  for (int i = 0; i < npoints; i++) {
    int pidx1 = i;
    int pidx2 = (i+1) % npoints;
    IldaPoint p1 =frame.points.get(pidx1);
    IldaPoint p2 =frame.points.get(pidx2);
    float x1 = (float)p1.x / Short.MAX_VALUE * (width/2);
    float y1 = (float)p1.y / Short.MAX_VALUE * (height/2) * -1;
    float x2 = (float)p2.x / Short.MAX_VALUE * (width/2);
    float y2 = (float)p2.y / Short.MAX_VALUE * (height/2) * -1;

    noFill();
    if (p1.blank) {
      if (showBlankLines) {
        strokeWeight(1);
        stroke(64, 64, 64);
      } else {
        noStroke();
      }
    } else {
      int[] rgb = rgbIntensity(p1.rgb, 0.4);
      strokeWeight(6);
      stroke(rgb[0], rgb[1], rgb[2]);
      //stroke(255);
    }

    line(x1, y1, x2, y2);
  }
  popMatrix();
}


void drawProgress(int x, int y, int w, int h) {
  if (player == null || player.file == null) {
    return;
  }
  int numFrames = player.file.frameCount;
  if (numFrames == 0) {
    return;
  }
  strokeWeight(h);
  stroke(64);
  float t = ((float) (1+player.currentFrameIdx)) / numFrames;
  float x2 = x + t * w;
  stroke(0, 255, 0);
  line(x, y, x2, y);
}


int[] rgbIntensity(int[] rgb, float intensity) {
  int[] ret = {
    (int)(rgb[0]*intensity), 
    (int)(rgb[1]*intensity), 
    (int)(rgb[2]*intensity)
  };
  return ret;
}


void playerThread() throws InterruptedException {
  if (player != null) {
    player.stop();
  }
  String filename = ildaFilenames.get(currentFileIdx);
  ildaFilename = ildaPath + "/" + filename;
  String shortname = makeShortName(filename, 20);
  IldaFile file  = new IldaFile(ildaFilename, shortname);

  if (file == null || file.frameCount == 0) {
    println("NO DATA: " + filename);
  }
  else {
    fileLoopCount = 0;
    player = new IldaPlayerAsync(file, this.pointsPerSec, this.oscSendEnabled, true);
    player.play();
  }
}

void endOfFileCallback() {
  fileLoopCount++;
  println("end of file: " + fileLoopCount);
}

void timingTest() throws InterruptedException {
  long t_prev = 0;
  long t_now = 0;
  double dt = 0.0;
  int iter = 0;
  while(true) {
    if (!paused) {
      t_now = System.nanoTime();
      dt = (t_now-t_prev) / 1000000.0;
      t_prev = t_now;
      iter++;
      if (iter % 10000 == 0) {
        println(String.format("delta: %.5f ms", dt));
      }
    }
    //Thread.sleep(200);
  }
}
