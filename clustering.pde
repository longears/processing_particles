import fullscreen.*;
import japplemenubar.*;
/*


keys:

    s   add small particles at cursor
    b   add big particles at cursor
    c   reset circle of small particles
    r   randomize big particles
    
    click to add a big particle

*/



//================================================================================
// CONSTANTS

int FRAME = 0;

int WORLD_X = 800;
int WORLD_Y = 500;
int N_BIG_PARTICLES = 40;
int N_SMALL_PARTICLES = 200;

// DRAWING
int BIG_PARTICLE_RAD = 20;
int SMALL_PARTICLE_RAD = 5;

int BIG_ALPHA = 30;
int BIG_BRIGHTNESS = 80;
int BIG_SATURATION = 80;
int SMALL_BRIGHTNESS = 60;
int SMALL_SATURATION = 80;

// MOTION
float TIME_SPEED = 0.1;

// BIG MOTION
float VEL_DAMPING = 0.68; // range 0-1; lower is less damping
float MAX_FORCE = 4; // 7
//float CLUSTER_SEEK_SPEED = 0.1;  // range 0-1

float RAD_CHANGE_SPEED = 0.1;


// SMALL MOTION
float SMALL_WIGGLE_FORCE = 1;
float SMALL_MAX_SPEED = 8;

float SMALL_ATTRACTIVE_FORCE = 0; // try 10 or 0

float NOISE_SCALE = 140;
float NOISE_MORPH_SPEED = 1.5;


//================================================================================
// UTILS

PVector pointInCircle(PVector center, float rad) {
    // Return a random point in the circle centered at "center" with radius "rad"
    PVector p = new PVector(100000,100000);
    while (p.mag() > 1) {
        p.x = random(-1,1);
        p.y = random(-1,1);
    }
    p.mult(rad);
    p.add(center);
    return p;
}

void clipToWorld(PVector pos, PVector vel) {
    // If the pos is outside the screen, snap it to the edge of the screen
    //   and set the appropriate element of velocity to zero.
    // Mutates the input vectors.
    // TODO: bouncing
    if (pos.x < 0) { pos.x = 0; vel.x = 0; }
    if (pos.y < 0) { pos.y = 0; vel.y = 0; }
    if (pos.x >= WORLD_X) { pos.x = WORLD_X-1; vel.x = 0; }
    if (pos.y >= WORLD_Y) { pos.y = WORLD_Y-1; vel.y = 0; }
}

//================================================================================
// PARTICLE

class Particle {
    PVector pos, vel;
    color c;
    float rad;

    Particle(float rad_, PVector pos_, PVector vel_, color c_) {
        rad = rad_;
        c = c_;
        pos = pos_;
        vel = vel_;
    }

    void update() {
        pos.add(vel);
        clipToWorld(pos,vel);
    }

    void draw() {
        fill(c);
        noStroke();
        ellipse(pos.x, pos.y, rad, rad);
    }
}

class BigParticle extends Particle {
    PVector clusterCenter;
    PVector lonelyDestination;
    int numClusterMembers;
    int isLonely;
    float targetRad;

    BigParticle(float rad_, PVector pos_, PVector vel_) {
        super(rad_,pos_,vel_,color(0));
        targetRad = rad;
        c = color(random(0,100), BIG_SATURATION, BIG_BRIGHTNESS, BIG_ALPHA);
        clusterCenter = new PVector(0,0);
        lonelyDestination = new PVector(0,0);
        numClusterMembers = 0;
        isLonely = 0;
    }

    void resetCluster() {
        clusterCenter.mult(0);
        numClusterMembers = 0;
    }
    void seeNewClusterMember(Particle p) {
        clusterCenter.add(p.pos);
        numClusterMembers += 1;
    }
    void finishSeeingNewClusterMembers() {
        if (numClusterMembers == 0) {
            // we've got no points, so let's just go to the middle of the world.
            //clusterCenter = new PVector(WORLD_X/2.0,WORLD_Y/2.0);
            if (isLonely == 0 || PVector.dist(pos,lonelyDestination) < 10) {
                lonelyDestination = new PVector(random(0,WORLD_X),random(0,WORLD_Y));
                isLonely = 1;
            }
            clusterCenter.x = lonelyDestination.x;
            clusterCenter.y = lonelyDestination.y;
            targetRad = 10;
        } else {
            clusterCenter.div(numClusterMembers);
            targetRad = numClusterMembers * 10;
            isLonely = 0;
        }
    }

    void update() {
        //pos = PVector.add(  PVector.mult(pos, 1-CLUSTER_SEEK_SPEED),
        //                    PVector.mult(clusterCenter, CLUSTER_SEEK_SPEED)  );

        rad = rad*(1-RAD_CHANGE_SPEED) + targetRad * RAD_CHANGE_SPEED;

        PVector force = PVector.sub(clusterCenter,pos);
        force.limit(MAX_FORCE);

        vel.add(force);
        vel.mult(1-VEL_DAMPING*TIME_SPEED);

        pos.add(PVector.mult(vel,TIME_SPEED));
        clipToWorld(pos,vel);
    }

    void draw() {
        fill(c);
        noStroke();
        ellipse(pos.x, pos.y, rad, rad);
    }
}

class SmallParticle extends Particle {
    PVector bigParticlePos;
    float bigParticleRad;
    SmallParticle(float rad_, PVector pos_, PVector vel_) {
        super(rad_,pos_,vel_,color(0));
        bigParticlePos = new PVector(0,0);
    }
    void update() {
        // wiggle
        vel.x += random(-1,1) * SMALL_WIGGLE_FORCE*0.8;
        vel.y += random(-1,1) * SMALL_WIGGLE_FORCE*0.8;
        //vel.x += (noise(FRAME/30.0*NOISE_MORPH_SPEED, pos.x/NOISE_SCALE, pos.y/NOISE_SCALE)*2-0.94) * SMALL_WIGGLE_FORCE;
        //vel.y += (noise(FRAME/30.0*NOISE_MORPH_SPEED, pos.x/NOISE_SCALE+1700.2, pos.y/NOISE_SCALE+5733.47)*2-0.94) * SMALL_WIGGLE_FORCE;

        if (SMALL_ATTRACTIVE_FORCE != 0) {
            PVector force = PVector.sub(bigParticlePos,pos);
            float dist = force.mag();
            force.normalize();

            if (dist < bigParticleRad/2) {
                force.mult(-1);
            }

            force.mult(SMALL_ATTRACTIVE_FORCE);
            force.limit(MAX_FORCE);
            vel.add(force);
        }

        vel.limit(SMALL_MAX_SPEED);

        pos.add(PVector.mult(vel,TIME_SPEED));
        clipToWorld(pos,vel);
    }
    void draw() {
        fill(c);
        noStroke();
        ellipse(pos.x, pos.y, rad, rad);

        stroke(c);
        line(pos.x, pos.y, bigParticlePos.x, bigParticlePos.y);
    }
}


//================================================================================
// MAIN

ArrayList bigParticles;
ArrayList smallParticles;

SoftFullScreen fs;

void setup() {
    frame.setBackground(new java.awt.Color(0,0,0));
    colorMode(HSB,100);
    size(WORLD_X, WORLD_Y);
    frameRate(30);
    smooth();
 
    bigParticles = new ArrayList();
    smallParticles = new ArrayList();

    // set up big particles
    for (int ii=0; ii < N_BIG_PARTICLES; ii++) {
        PVector pos = new PVector(random(0,WORLD_X),random(0,WORLD_Y));
        PVector vel = new PVector(0,0);
        bigParticles.add(   new BigParticle(BIG_PARTICLE_RAD, pos, vel)   );
    }
    // set up small particles
    for (int ii=0; ii < N_SMALL_PARTICLES; ii++) {
        PVector pos = pointInCircle(new PVector(WORLD_X/2.0 * 0.7,WORLD_Y/2.0), WORLD_Y/2.0 * 0.85);
        PVector vel = new PVector(0,0);
        smallParticles.add(   new SmallParticle(SMALL_PARTICLE_RAD, pos, vel)   );
    }
    // set up small particles
    for (int ii=0; ii < N_SMALL_PARTICLES/4; ii++) {
        PVector pos = pointInCircle(new PVector(WORLD_X/2.0 *1.7,WORLD_Y/2.0*0.8), WORLD_Y/2.0 * 0.3);
        PVector vel = new PVector(0,0);
        smallParticles.add(   new SmallParticle(SMALL_PARTICLE_RAD, pos, vel)   );
    }

    fs = new SoftFullScreen(this);
    fs.enter();
}

void keyPressed() {
    if (key == 's') {
        for (int ii=0; ii < 40; ii++) {
            PVector pos = pointInCircle(new PVector(mouseX,mouseY), 100);
            PVector vel = PVector.sub(pos, new PVector(mouseX,mouseY));
            vel.mult(5);
            smallParticles.add(   new SmallParticle(SMALL_PARTICLE_RAD, pos, vel)   );
        }
    }
    if (key == 'b') {
        for (int ii=0; ii < 40; ii++) {
            PVector pos = pointInCircle(new PVector(mouseX,mouseY), 20);
            PVector vel = new PVector(0,0);
            bigParticles.add(   new BigParticle(BIG_PARTICLE_RAD, pos, vel)   );
        }
    }
    if (key == 'r') {
        for (int ii=0; ii < bigParticles.size(); ii++) {
            BigParticle bp = (BigParticle) bigParticles.get(ii);
            bp.pos = new PVector(random(0,WORLD_X), random(0,WORLD_Y));
            //bp.pos = new PVector(WORLD_X/2.0, WORLD_Y/2.0);
            bp.vel = new PVector(0,0);
        }
    }
    if (key == 'c') {
        for (int ii=0; ii < smallParticles.size(); ii++) {
            SmallParticle sp = (SmallParticle) smallParticles.get(ii);
            sp.pos = pointInCircle(new PVector(WORLD_X/2.0,WORLD_Y/2.0), WORLD_Y/2.0 * 0.9);
            sp.vel = new PVector(0,0);
        }
    }
}

void mousePressed() {
    PVector pos = new PVector(mouseX,mouseY);
    PVector vel = new PVector(0,0);
    bigParticles.add(   new BigParticle(BIG_PARTICLE_RAD, pos, vel)   );
}

void draw() {
    FRAME += 1;

    background(12);



    for (int ii=0; ii < bigParticles.size(); ii++) {
        BigParticle bp = (BigParticle) bigParticles.get(ii);
        bp.resetCluster();
    }
    // each small particle finds its nearest big particle
    // and registers there
    for (int ii=0; ii < smallParticles.size(); ii++) {
        SmallParticle sp = (SmallParticle) smallParticles.get(ii);
        float closestDist = 100000;
        BigParticle closestBigParticle = (BigParticle) bigParticles.get(0);
        for (int jj=0; jj < bigParticles.size(); jj++) {
            BigParticle bp = (BigParticle) bigParticles.get(jj);
            float thisDist = PVector.dist( sp.pos, bp.pos );
            if (thisDist < closestDist) {
                closestDist = thisDist;
                closestBigParticle = bp;
            }
        }
        sp.c = color(hue(closestBigParticle.c),SMALL_SATURATION,SMALL_BRIGHTNESS);
        sp.bigParticlePos = closestBigParticle.pos;
        sp.bigParticleRad = closestBigParticle.rad;
        closestBigParticle.seeNewClusterMember(sp);
    }
    for (int ii=0; ii < bigParticles.size(); ii++) {
        BigParticle bp = (BigParticle) bigParticles.get(ii);
        bp.finishSeeingNewClusterMembers();
    }


    for (int ii=0; ii < smallParticles.size(); ii++) {
        SmallParticle sp = (SmallParticle) smallParticles.get(ii);
        sp.update();
        sp.draw();
    }
    for (int ii=0; ii < bigParticles.size(); ii++) {
        BigParticle bp = (BigParticle) bigParticles.get(ii);
        bp.update();
        bp.draw();
    }
}



