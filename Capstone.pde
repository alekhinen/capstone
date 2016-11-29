/*
Nick Alekhine
ARTG 4700 - Interaction Team Degree Project

Notes on KinectPV2:
- Color images always returned in 1920x1080.
- Everything else (depth, skeleton, IR) always returned in 512x424.
*/

// =======
// Imports
// =======

import KinectPV2.KJoint;
import KinectPV2.*;

import oscP5.*;
import netP5.*;

// =======
// Classes
// =======

class SonicColor {
  
  String name;
  color colorValue;
  
  SonicColor(String name, color colorValue) {
    this.name = name;
    this.colorValue = colorValue;
  }
  
  /** 
   * @description: calculates the euclidean distance between this color and a given color.
   */
  double euclideanDistance(color c) {
    float deltaR = red(colorValue) - red(c);
    float deltaG = green(colorValue) - green(c);
    float deltaB = blue(colorValue) - blue(c);
    return Math.sqrt(Math.pow(deltaR, 2) + Math.pow(deltaG, 2) + Math.pow(deltaB, 2));
  }

}

class User {

  color cChest;
  String cChestName;
  PVector chestPosn;
  PVector lHandPosn;
  PVector rHandPosn;
  
  User(color cChest, String cChestName, PVector chestPosn, PVector lHandPosn, PVector rHandPosn) {
    this.cChest = cChest;
    this.cChestName = cChestName;
    this.chestPosn = chestPosn;
    this.lHandPosn = lHandPosn;
    this.rHandPosn = rHandPosn;
  }

}

// ================
// Global Variables
// ================

KinectPV2 kinect;

OscP5 oscP5;
NetAddress myRemoteLocation;

int [] rawDepth;
PImage imgColor;

// static list of colors.
SonicColor [] sonicColors = {
  new SonicColor("red", color(255, 0, 0)), 
  new SonicColor("green", color(0, 255, 0)), 
  new SonicColor("blue", color(0, 0, 255)), 
  new SonicColor("white", color(255, 255, 255)), 
  new SonicColor("black", color(0, 0, 0))
};

// dynamic list of users.
ArrayList<User> users;

// ================
// Global Functions
// ================

// -----
// Setup 
// -----

void setup() {
  size(displayWidth, displayHeight, P3D);

  kinect = new KinectPV2(this);

  kinect.enableDepthImg(true);
  kinect.enableColorImg(true);
  kinect.enableSkeletonColorMap(true);

  kinect.init();
  
  // TODO: generate the list once in the beginning and keep it constant. 
  //       only remove / add if there are new skeletons.
  users = new ArrayList<User>();
  
  /* start oscP5, listening for incoming messages at port 8000 */
  oscP5 = new OscP5(this,12000);
  
  myRemoteLocation = new NetAddress("192.168.1.3", 8000);
}

// ----
// Draw
// ----

void draw() {
  // raw depth contains values [0 - 4500]in a one dimensional 512x424 array.
  rawDepth = kinect.getRawDepthData();
  // color image from the kinect.
  imgColor = kinect.getColorImage();
  // skeletons (aka users)
  ArrayList<KSkeleton> skeletonArray =  kinect.getSkeletonColorMap();

  // reset the screen.
  background(150);
  
  if (skeletonArray.size() != users.size()) {
    // TODO: should we be closing all the users out whenever one comes or leaves?
    closingMessage(users);
    users = new ArrayList<User>();
  }
  
  for (int i = 0; i < skeletonArray.size(); i++) {
    KSkeleton skeleton = (KSkeleton) skeletonArray.get(i);
    if (skeleton.isTracked()) {
      KJoint[] joints = skeleton.getJoints();
      
      boolean userExists = i < users.size();
      User currentUser;
      
      // if the user doesn't already exist, generate.
      if (!userExists) {
        currentUser = generateUser(joints[KinectPV2.JointType_SpineMid],
                                   joints[KinectPV2.JointType_HandLeft],
                                   joints[KinectPV2.JointType_HandRight]);
        // add to beginning of list
        users.add(currentUser);
        drawUser(currentUser);
      } else {
        userExists = true;
        currentUser = users.get(i);
        updateUser(currentUser, joints[KinectPV2.JointType_SpineMid]);
        drawUser(currentUser);
      }

      // draw different color for each hand state
      drawHandState(joints[KinectPV2.JointType_HandRight]);
      drawHandState(joints[KinectPV2.JointType_HandLeft]);
    }
  }
  
  for (int i = 0; i < users.size(); i++) {
    User u = users.get(i);
    sendMessage(u, i);
  }

  fill(255, 0, 0);
  text(frameRate, 50, 50);
}

void drawUser(User u) {
  noStroke();
  
  // draws the depth as a square in the center of the screen.
  pushMatrix();
  translate(displayWidth / 2, displayHeight / 2, 0);
  fill(map(u.chestPosn.z, 0, 4500, 0, 255));
  rect(0, 0, 50, 50);
  popMatrix();
  
  // draws the chest as a circle with the user's color.
  pushMatrix();
  translate(u.chestPosn.x, u.chestPosn.y, 0);
  fill(u.cChest);
  ellipse(0, 0, 70, 70);
  popMatrix();
  
  fill(255, 0, 0);
  text(u.cChestName, 50, 70);
}

// draw hand state
void drawHandState(KJoint joint) {
  noStroke();
  handState(joint.getState());
  pushMatrix();
  PVector mappedJoint = mapDepthToScreen(joint); 
  translate(mappedJoint.x, mappedJoint.y, mappedJoint.z);
  ellipse(0, 0, 70, 70);
  popMatrix();
}

// ----------
// Generators
// ----------

User generateUser(KJoint chest, KJoint lHand, KJoint rHand) {
  // TODO: should be a static function in User class. 
  color jointColor = getColorInRadius(Math.round(chest.getX()), Math.round(chest.getY()), 5);
  String colorName = getClosestNameFromColor(jointColor);
  int z = getDepthFromJoint(chest);
  
  PVector mappedJoint = mapDepthToScreen(chest);
  PVector mappedLeft  = mapDepthToScreen(lHand);
  PVector mappedRight = mapDepthToScreen(rHand);
  
  return new User(jointColor, 
                  colorName, 
                  new PVector(mappedJoint.x, mappedJoint.y, z),
                  mappedLeft,
                  mappedRight);
}

// --------
// Mutators
// --------

void updateUser(User u, KJoint chest) {
  // TODO: should be moved into User class.
  int z = getDepthFromJoint(chest);
  PVector mappedJoint = mapDepthToScreen(chest);
  u.chestPosn = new PVector(mappedJoint.x, mappedJoint.y, z);
}

// -------------
// OSC Messaging
// -------------

/** 
 * @description sends the given user's information over OSC.
 * @arg User u: the user
 * @arg int id: the unique id of the user to use when sending the OSC message.
 */
void sendMessage(User u, int id) {
  String oscId = "/" + str(id) + "/";
  
  // send name of the user's chest color.
  OscMessage colorName = new OscMessage(oscId + "colorName");
  colorName.add(u.cChestName);
  oscP5.send(colorName, myRemoteLocation);
  
  // send rgb value of the user's chest color
  OscMessage rgbColor = new OscMessage(oscId + "rgbColor");
  rgbColor.add(new float [] {red(u.cChest), green(u.cChest), blue(u.cChest)});
  oscP5.send(rgbColor, myRemoteLocation);
  
  // send the (x, y, z) coord of the user's chest.
  OscMessage coordMsg = new OscMessage(oscId + "coord");
  coordMsg.add(new float [] {u.chestPosn.x, u.chestPosn.y, u.chestPosn.z});
  oscP5.send(coordMsg, myRemoteLocation);
  
  OscMessage lHandMsg = new OscMessage(oscId + "lHandCoord");
  lHandMsg.add(new float [] {u.lHandPosn.x, u.lHandPosn.y});
  oscP5.send(lHandMsg, myRemoteLocation);
  
  OscMessage rHandMsg = new OscMessage(oscId + "rHandCoord");
  rHandMsg.add(new float [] {u.rHandPosn.x, u.rHandPosn.y});
  oscP5.send(rHandMsg, myRemoteLocation);
}

/** 
 * @description sends a closing message to OSC for all given users.
 * @arg Listof User users: the users to close out
 */
void closingMessage(ArrayList<User> users) {
  for (int i = 0; i < users.size(); i++) {
    String oscId = "/" + str(i) + "/";
    OscMessage close = new OscMessage(oscId + "close");
    oscP5.send(close, myRemoteLocation);
  }
}

// -----------------
// Utility Functions
// -----------------

/**
 * @description: 
 * @returns integer value between [0 - 4500]
 */
int getDepthFromJoint(KJoint joint) {
  // map the (x, y) from joint from color space to depth space.
  // note 1: this is a rough conversion that does not take into account that the placement
  //         of the depth sensor and camera sensor are different (so it's not a clean mapping).
  // note 2: (x, y) can go negative. workaround is to use the max of either 0 or the coordinate value.
  // note 3: joint.getZ() always returns 0 which is why we need the depth value.
  int x = Math.min(Math.max(Math.round(map(joint.getX(), 0, 1920, 0, 512)), 0), 512); 
  int y = Math.min(Math.max(Math.round(map(joint.getY(), 0, 1080, 0, 424)), 0), 423); 
  return rawDepth[x+(512*y)];
}

/**
 * @description: returns the name of the sonic color which is closest to the given color.
 */
String getClosestNameFromColor(color c) {
  String bestName = "";
  double closestDist = -1;
  for (SonicColor sColor : sonicColors) {
    double dist = sColor.euclideanDistance(c);
    if (closestDist == -1 || dist < closestDist) {
      closestDist = dist;
      bestName = sColor.name;
    }
  }
  return bestName;
};

/** 
 * @description: Gets the average color in a radius for a point from the HD color image.
 * @returns color
 */
color getColorInRadius(int x, int y, int radius) {
  // Ensure these coordinates don't go outside their bounds (e.g. 0-1920, 0-1080).
  int lowerX = Math.max((x - radius), 0);
  int upperX = Math.min((x + radius), 1920);
  
  int lowerY = Math.max((y - radius), 0);
  int upperY = Math.min((y + radius), 1080);
  
  int increment = 1;
  int r = 0;
  int g = 0;
  int b = 0;
  
  // sum the color values.
  while (lowerX < upperX) {
    int newLowerY = lowerY;
    while (newLowerY < upperY) {
      color c = imgColor.get(lowerX, newLowerY);
      r += Math.round(red(c));
      g += Math.round(green(c));
      b += Math.round(blue(c));
      System.out.println(r + " " + g + " " + b);
      increment += 1;
      newLowerY += 1;
    }
    lowerX += 1;
  }
  
  // divide the sum by the increment to get the average values.
  r = Math.round(r / increment);
  g = Math.round(g / increment);
  b = Math.round(b / increment);
  
  return color(r, g, b);
}

PVector mapDepthToScreen(KJoint joint) {
  int x = Math.round(map(joint.getX(), 0, 1920, 0, displayWidth));
  int y = Math.round(map(joint.getY(), 0, 1080, 0, displayHeight));
  int z = Math.round(joint.getZ());
  return new PVector(x, y, z);
}

/*
Different hand state
 KinectPV2.HandState_Open
 KinectPV2.HandState_Closed
 KinectPV2.HandState_Lasso
 KinectPV2.HandState_NotTracked
 */
void handState(int handState) {
  switch(handState) {
  case KinectPV2.HandState_Open:
    fill(0, 255, 0);
    break;
  case KinectPV2.HandState_Closed:
    fill(255, 0, 0);
    break;
  case KinectPV2.HandState_Lasso:
    fill(0, 0, 255);
    break;
  case KinectPV2.HandState_NotTracked:
    fill(255, 255, 255);
    break;
  }
}