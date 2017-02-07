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

import generativedesign.*;

import KinectPV2.KJoint;
import KinectPV2.*;

import oscP5.*;
import netP5.*;

// ================
// Global Variables
// ================

KinectPV2 kinect;
OSC osc;

int FRAME_RATE = 30;
int [] rawDepth;

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
  
  frameRate(FRAME_RATE);

  // initialize kinect stuff. 
  initKinect();
  // initialize users.
  users = new ArrayList<User>();
  // initialize OSC.
  osc = new OSC();
  
  stroke(0, 50);
  background(0);
}

void initKinect() {
  kinect = new KinectPV2(this);

  kinect.enableDepthImg(true);
  kinect.enableSkeletonDepthMap(true);

  kinect.init();
}

// ----
// Draw
// ----

void draw() {
  // raw depth contains values [0 - 4500]in a one dimensional 512x424 array.
  rawDepth = kinect.getRawDepthData();
  // skeletons (aka users)
  ArrayList<KSkeleton> skeletonArray =  kinect.getSkeletonDepthMap();

  // reset the screen.
  fill(0);
  noStroke();
  rect(0,0,width,height);
  
  // reset the users and send a closing message to OSC if users change.
  if (skeletonArray.size() != users.size()) {
    // TODO: should we be closing all the users out whenever one comes or leaves?
    osc.closingMessage(users);
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
        currentUser.draw();
      } else {
        userExists = true;
        currentUser = users.get(i);
        currentUser.update(joints[KinectPV2.JointType_SpineMid], 
                           joints[KinectPV2.JointType_HandLeft],
                           joints[KinectPV2.JointType_HandRight]);
        currentUser.draw();
      }

    }
  }
  
  // send OSC message about User.
  for (int i = 0; i < users.size(); i++) {
    User u = users.get(i);
    osc.sendMessage(u, i);
  }

  fill(255, 0, 0);
  text(frameRate, 50, 50);
}

// ----------
// Generators
// ----------

User generateUser(KJoint chest, KJoint lHand, KJoint rHand) {
  
  int z = getDepthFromJoint(chest);
  PVector mappedJoint = mapDepthToScreen(chest);
  PVector mappedLeft  = mapDepthToScreen(lHand);
  PVector mappedRight = mapDepthToScreen(rHand);
  
  return new User(new PVector(mappedJoint.x, mappedJoint.y, z),
                  mappedLeft,
                  mappedRight);
}

// -------------
// Key Functions
// -------------

void keyReleased() {
  if (key == DELETE || key == BACKSPACE) background(255);
}