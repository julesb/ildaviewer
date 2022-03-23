import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

import java.util.Arrays;


public class IldaFile {
  String filename;
  String name;
  byte[] bytes;
  ArrayList<IldaFrame> frames = new ArrayList();
  int frameCount = 0;
  int totalPoints = 0;
  int droppedFrameCount = 0;

  public IldaFile(String filename, String name) {
    this.filename = filename;
    this.name = name;
    this.bytes = loadFile();
    int frameOffset = 0;
    IldaFrame frame;
    do {
      frame = new IldaFrame(frameOffset, this.bytes);
      if (frame.header.numRecords == 0) {
        break;
      }
      else {
        frames.add(frame);
        totalPoints += frame.pointCount;
        //println(name + ": " + frame.toString());
        frameOffset += frame.byteCount;
      }
    } while (frame.header.numRecords > 0 && frameOffset < this.bytes.length);

    if (frame.header.numRecords != 0) {
      println(name + ": NO EOF HEADER");
      frames.remove(frames.size()-1);
    }

    this.frameCount = frames.size();
    println(this.toString());
  }

  byte[] loadFile() {
    byte[] bytes = {};
    try{
      bytes = Files.readAllBytes(Paths.get(this.filename));
      //println("FILE: " + this.filename + ": bytes:" + bytes.length);
    } catch(IOException e) {
      e.printStackTrace();
    }  
    return bytes;
  }

  String toString() {
    return this.name + ": frames:" + this.frameCount + ": "
    + (this.frameCount > 0? frames.get(0).toString(): "") ;

  }
}


// ILDA Header ====================================

public class IldaHeader {
  String identifier;
  int formatCode;
  String name;
  String companyName;
  int numRecords;
  int frameNumber;
  int totalFrames;
  int projectorNumber;
  int headerStartOffset = -1;
  
  static final int ILDA_3D_INDEXED    = 0;
  static final int ILDA_2D_INDEXED    = 1;
  static final int ILDA_COLOR_PALETTE = 2;
  static final int ILDA_3D_RGB        = 4;
  static final int ILDA_2D_RGB        = 5;
  
  public IldaHeader(byte[] headerBytes) {
    String id = new String(Arrays.copyOfRange(headerBytes, 0, 4));
    if (! id.equals("ILDA")) {
      println("ERROR: Invalid file identifier: '" + id + "'");
      return;
    }

    this.identifier = id;
    this.formatCode = headerBytes[7];
    this.name = new String(Arrays.copyOfRange(headerBytes, 8, 16));
    name = name.trim();
    this.companyName = new String(Arrays.copyOfRange(headerBytes, 16, 24));
    companyName = companyName.trim();
    this.numRecords  = IldaUtil.bytesToShort(Arrays.copyOfRange(headerBytes, 24, 26));
    this.frameNumber = IldaUtil.bytesToShort(Arrays.copyOfRange(headerBytes, 26, 28));
    this.totalFrames = IldaUtil.bytesToShort(Arrays.copyOfRange(headerBytes, 28, 30));

    //println(this.toString());
  }

  
  public String getFormatString() {
    switch(this.formatCode) {
      case ILDA_3D_INDEXED:    return "ILDA_3D_INDEXED";
      case ILDA_2D_INDEXED:    return "ILDA_2D_INDEXED";
      case ILDA_COLOR_PALETTE: return "ILDA_COLOR_PALETTE";
      case ILDA_3D_RGB:        return "ILDA_3D_RGB";
      case ILDA_2D_RGB:        return "ILDA_2D_RGB";
      default:
        return "UNDEFINED FORMAT: " + this.formatCode;
    }
  }
  public String getFormatName() {
    switch(this.formatCode) {
      case ILDA_3D_INDEXED:    return "3DIDX";
      case ILDA_2D_INDEXED:    return "2DIDX";
      case ILDA_COLOR_PALETTE: return "PALETTE";
      case ILDA_3D_RGB:        return "3DRGB";
      case ILDA_2D_RGB:        return "2DRGB";
      default:
        return "UNDEFINED FORMAT: " + this.formatCode;
    }
  }

  
  public int getFormatRecordSize() {
    switch(this.formatCode) {
      case ILDA_3D_INDEXED:    return 8;
      case ILDA_2D_INDEXED:    return 6;
      case ILDA_COLOR_PALETTE: return 3;
      case ILDA_3D_RGB:        return 10;
      case ILDA_2D_RGB:        return 8;
      default:
        return -1;
    }
  }
  
  
  public String toString() {
    return "  ID:            " + this.identifier + "\n"
         + "  Format:        " + this.getFormatString() + "\n"
         + "  Name:          " + this.name + "\n"
         + "  Company Name:  " + this.companyName + "\n"
         + "  Num Records:   " + this.numRecords + "\n"
         + "  Frame Number:  " + this.frameNumber + "\n"
         + "  Total Frames:  " + this.totalFrames + "\n"
         ;
  }
}


// ILDA Frame ====================================

public class IldaFrame {
  public IldaHeader header;
  public ArrayList<IldaPoint> points = new ArrayList();
  public int byteCount;
  public int pointCount;

  public IldaFrame(int frameOffset, byte[] bytes) {
    parse(frameOffset, bytes);
  }

  void parse(int frameOffset, byte[] bytes) {
    // TODO: Dont copy the bytes. Calculate offsets into main array instead. 
    byte[] headerBytes = Arrays.copyOfRange(bytes, frameOffset, frameOffset+32);
    this.header = new IldaHeader(headerBytes);
    
    int recsize = this.header.getFormatRecordSize();
    int reccount = this.header.numRecords;
    int datalen = recsize * reccount;
    this.byteCount = reccount == 0? 32: 32 + datalen;
    int dataStartIdx = frameOffset + 32;
    
    
    for (int i=dataStartIdx; i < dataStartIdx+datalen; i += recsize) {
      int endOff = i + recsize;
      if (endOff >= bytes.length) {
        println("out of range");
        break;
      }
      byte[] recBytes = Arrays.copyOfRange(bytes, i, i+recsize);
      short x,y,z;
      int status, st_blank, st_last, colIdx;
      int[] rgb;
      IldaPoint p; // = new IldaPoint();

      switch(this.header.formatCode) {
         case IldaHeader.ILDA_3D_INDEXED: {
           x = IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 0, 2));
           y = IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 2, 4));
           z = IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 4, 6));
           status = recBytes[6];
           colIdx = recBytes[7];
           st_last   = (status & (1 << 7)) >> 7;
           st_blank  = (status & (1 << 6)) >> 6;
           rgb = null; //IldaUtil.DEFAULT_PALETTE[colIdx];
           p = new IldaPoint(x, y, z, colIdx, rgb, (st_blank == 1), (st_last == 1));
           this.points.add(p);
           //println(p.toString());
           break;
         }
         case IldaHeader.ILDA_2D_INDEXED: {
           x = IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 0, 2));
           y = IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 2, 4));
           z = 0; //IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 4, 6));
           status = recBytes[4];
           colIdx = recBytes[5];
           st_last   = (status & (1 << 7)) >> 7;
           st_blank  = (status & (1 << 6)) >> 6;
           rgb = null; //IldaUtil.DEFAULT_PALETTE[colIdx];
           p = new IldaPoint(x, y, z, colIdx, rgb, (st_blank == 1), (st_last == 1));
           this.points.add(p);
           break;
         }
         case IldaHeader.ILDA_COLOR_PALETTE: {
           println("NOT IMPLEMENTED: ILDA_COLOR_PALETTE");
           break;
         }
         case IldaHeader.ILDA_3D_RGB: {
           x = IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 0, 2));
           y = IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 2, 4));
           z = IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 4, 6));
           status = recBytes[6];
           st_last   = (status & (1 << 7)) >> 7;
           st_blank  = (status & (1 << 6)) >> 6;
           int b = recBytes[7] & 0xff;
           int g = recBytes[8] & 0xff;
           int r = recBytes[9] & 0xff;
           rgb = new int[3];
           rgb[0] = r;
           rgb[1] = g;
           rgb[2] = b;
           colIdx = -1;
           p = new IldaPoint(x, y, z, colIdx, rgb, (st_blank == 1), (st_last == 1));
           this.points.add(p);
           break;
         }
         case IldaHeader.ILDA_2D_RGB: {
           x = IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 0, 2));
           y = IldaUtil.bytesToShort(Arrays.copyOfRange(recBytes, 2, 4));
           z = 0;
           status = recBytes[4];
           st_last   = (status & (1 << 7)) >> 7;
           st_blank  = (status & (1 << 6)) >> 6;
           int b = recBytes[5] & 0xff;
           int g = recBytes[6] & 0xff;
           int r = recBytes[7] & 0xff;
           rgb = new int[3];
           rgb[0] = r;
           rgb[1] = g;
           rgb[2] = b;
           colIdx = -1;
           p = new IldaPoint(x, y, z, colIdx, rgb, (st_blank == 1), (st_last == 1));
           this.points.add(p);
           break;
         }
      }
    }
    this.pointCount = points.size();
  }

  public String toString() {
    return "frame " + (this.header.frameNumber+1) + "/" + this.header.totalFrames
                    + ": " + this.header.getFormatString() + " "
                    + this.header.numRecords + " points "
                    + "[" + this.header.name + "|" + this.header.companyName + "]";
  }

}


// ILDA Point ====================================

public class IldaPoint {
  short x;
  short y;
  short z;
  int[] rgb = {255,255,255};
  int colorIdx;
  boolean blank;
  boolean last;

  public IldaPoint(short x, short y, short z, int colorIdx, int[] rgb, boolean blank, boolean last) {
    this.x = x;
    this.y = y;
    this.z = z;
    if (rgb != null && rgb.length == 3) {
      this.rgb = rgb;
    }
    else {
      if (colorIdx >= 0 && colorIdx < 64) {
        this.rgb = IldaUtil.DEFAULT_PALETTE[colorIdx];
      }
    }

    this.colorIdx = colorIdx;
    this.blank = blank;
    this.last = last;
  }
  
  public IldaPoint() {}

  public String toString() {
    return "[" + x + " " + y + " " + z + "] "
         + "[b: " + this.blank + ", l: " + this.last + " ] "
         + "[ci: " + this.colorIdx + ", rgb: " + IldaUtil.RGBToHexString(rgb) +"]";
  
  }
}


// ILDA Util ====================================

static class IldaUtil {
  
  public static short bytesToShort(byte[] bytes) {
    return ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN).getShort();
  }
  
  public static byte[] shortToBytes(short value) {
    return ByteBuffer.allocate(2).order(ByteOrder.BIG_ENDIAN).putShort(value).array();
  }
  
  public static String RGBToHexString(int[] rgb) {
    return String.format("#%02x%02x%02x", rgb[0], rgb[1], rgb[2]);
  }
  
  public static final int[][] DEFAULT_PALETTE = {
    {255, 0, 0},
    {255, 16, 0},
    {255, 32, 0},
    {255, 48, 0},
    {255, 64, 0},
    {255, 80, 0},
    {255, 96, 0},
    {255, 112, 0},
    {255, 128, 0},
    {255, 144, 0},
    {255, 160, 0},
    {255, 176, 0},
    {255, 192, 0},
    {255, 208, 0},
    {255, 224, 0},
    {255, 240, 0},
    {255, 255, 0},
    {224, 255, 0},
    {192, 255, 0},
    {160, 255, 0},
    {128, 255, 0},
    {96, 255, 0},
    {64, 255, 0},
    {32, 255, 0},
    {0, 255, 0},
    {0, 255, 36},
    {0, 255, 73},
    {0, 255, 109},
    {0, 255, 146},
    {0, 255, 182},
    {0, 255, 219},
    {0, 255, 255},
    {0, 227, 255},
    {0, 198, 255},
    {0, 170, 255},
    {0, 142, 255},
    {0, 113, 255},
    {0, 85, 255},
    {0, 56, 255},
    {0, 28, 255},
    {0, 0, 255},
    {32, 0, 255},
    {64, 0, 255},
    {96, 0, 255},
    {128, 0, 255},
    {160, 0, 255},
    {192, 0, 255},
    {224, 0, 255},
    {255, 0, 255},
    {255, 32, 255},
    {255, 64, 255},
    {255, 96, 255},
    {255, 128, 255},
    {255, 160, 255},
    {255, 192, 255},
    {255, 224, 255},
    {255, 255, 255},
    {255, 224, 224},
    {255, 192, 192},
    {255, 160, 160},
    {255, 128, 128},
    {255, 96, 96},
    {255, 64, 64},
    {255, 32, 32}
  };
}
