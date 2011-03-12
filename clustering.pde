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
int N_BIG_PARTICLES = 2;//40;
int N_SMALL_PARTICLES = 200;

// DRAWING
int BIG_PARTICLE_RAD = 20;
int SMALL_PARTICLE_RAD = 5;

int BIG_ALPHA = 30;
int BIG_BRIGHTNESS = 80;
int BIG_SATURATION = 80;
int SMALL_BRIGHTNESS = 60;
int SMALL_SATURATION = 80;

// ACTION
int MAX_TIME_TO_DIE_IF_SMALL = 5 * 30;
int MAX_TIME_TO_SPLIT_IF_BIG = 2 * 30;
int TOO_MANY_PARTICLES_IN_CLUSTER = 7;
int TOO_FEW_PARTICLES_IN_CLUSTER = 6;

float RAD_PER_CLUSTER_MEMBER = 4;
int TRAILS = 1;


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

class ParticleGroup {
    ArrayList particles;
    float velDamping, maxVel, maxForce;

    ParticleGroup() {
        particles = new ArrayList();
        velDamping = 0.1;
        maxVel = 1000;
        maxForce = 1000;
    }
    void add(Particle p) {
        particles.add(p);
        p.velDamping = velDamping;
        p.maxVel = maxVel;
        p.maxForce = maxForce;
        p.particleGroup = this;
    }
    Particle get(int ii) {
        return (Particle) particles.get(ii);
    }
    int size() {
        return particles.size();
    }

    void preTick() {}
    void postTick() {}
    void tick() {
        preTick();
        for (int ii=0; ii < particles.size(); ii++) {
            Particle p = (Particle) particles.get(ii);
            p.tick();
        }
        postTick();
    }

    void draw() {
        for (int ii=0; ii < particles.size(); ii++) {
            Particle p = (Particle) particles.get(ii);
            p.draw();
        }
    }

    void kill(Particle p) {
        particles.remove(p);
    }
}



class Particle {
    ParticleGroup particleGroup;
    PVector pos, vel, force;
    color c;
    float rad;
    float velDamping, maxVel, maxForce;

    Particle(float rad_, PVector pos_, PVector vel_, color c_) {
        rad = rad_;
        c = c_;
        pos = pos_;
        vel = vel_;
        force = new PVector(0,0);
        velDamping = 0;
        maxVel = 1000;
        maxForce = 1000;
    }

    void preTick() {}
    void calcForce() {}
    void applyForce() {
        force.limit(maxForce);
        vel.add(force);
        vel.mult(1-velDamping*TIME_SPEED);
        vel.limit(maxVel);
        pos.add(PVector.mult(vel,TIME_SPEED));
        clipToWorld(pos,vel);
    }
    void postTick() {}

    void tick() {
        preTick();
        calcForce();
        applyForce();
        postTick();
    }

    void draw() {
        fill(c);
        noStroke();
        ellipse(pos.x, pos.y, rad, rad);
    }

    void die() {
        particleGroup.kill(this);
    }
}



class BigParticle extends Particle {
    PVector clusterCenter;
    PVector lonelyDestination;
    int numClusterMembers;
    int isLonely;
    int framesTooSmall;
    int framesTooBig;
    float targetRad;
    int frameDivided;

    BigParticle(float rad_, PVector pos_, PVector vel_) {
        super(rad_,pos_,vel_,color(0));
        targetRad = rad;
        c = color(random(0,100), BIG_SATURATION, BIG_BRIGHTNESS, BIG_ALPHA);
        clusterCenter = new PVector(0,0);
        lonelyDestination = new PVector(0,0);
        numClusterMembers = 0;
        isLonely = 0;
        framesTooSmall = int(random(0,MAX_TIME_TO_DIE_IF_SMALL*0.8));
        framesTooBig = int(random(0,MAX_TIME_TO_SPLIT_IF_BIG*0.8));
        frameDivided = FRAME;
    }

    void calcForce() {
        force = PVector.sub(clusterCenter,pos);
    }
    void postTick() {
        rad = rad*(1-RAD_CHANGE_SPEED) + targetRad * RAD_CHANGE_SPEED;

        framesTooSmall += 1;
        if (numClusterMembers > TOO_FEW_PARTICLES_IN_CLUSTER) {
            framesTooSmall = 0;
        }
        framesTooBig += 1;
        if (numClusterMembers < TOO_MANY_PARTICLES_IN_CLUSTER) {
            framesTooBig = 0;
        }

        if (framesTooSmall > MAX_TIME_TO_DIE_IF_SMALL) {
            die();
        }
        //if (numClusterMembers >= TOO_MANY_PARTICLES_IN_CLUSTER && FRAME > frameDivided + MAX_TIME_TO_SPLIT_IF_BIG) {
        if (framesTooBig > MAX_TIME_TO_SPLIT_IF_BIG) {
            framesTooBig = int(random(0,MAX_TIME_TO_SPLIT_IF_BIG*0.8));
            BigParticle clone = new BigParticle(rad,
                                                new PVector(pos.x,pos.y),
                                                new PVector(vel.x,vel.y));
            clone.pos.y += random(-0.3,0.3); 
            clone.pos.x += random(-0.3,0.3); 
            clone.numClusterMembers = 0;
            clone.clusterCenter = new PVector(clusterCenter.x, clusterCenter.y);
            clone.rad = 0;
            frameDivided = FRAME;
            particleGroup.add(clone);
        }
    }


    void resetClusterMembership() {
        clusterCenter.mult(0);
        numClusterMembers = 0;
    }
    void addClusterMember(Particle p) {
        clusterCenter.add(p.pos);
        numClusterMembers += 1;
    }
    void finalizeCluster() {
        if (numClusterMembers == 0) {
            // we've got no points, so let's just go to the middle of the world.
            //clusterCenter = new PVector(WORLD_X/2.0,WORLD_Y/2.0);
            if (isLonely == 0 || PVector.dist(pos,lonelyDestination) < 10) {
                lonelyDestination = new PVector(random(0,WORLD_X),random(0,WORLD_Y));
                isLonely = 1;
            }
            clusterCenter.x = lonelyDestination.x;
            clusterCenter.y = lonelyDestination.y;
            targetRad = RAD_PER_CLUSTER_MEMBER;
        } else {
            clusterCenter.div(numClusterMembers);
            targetRad = numClusterMembers * RAD_PER_CLUSTER_MEMBER;
            isLonely = 0;
        }
    }
}



class SmallParticle extends Particle {
    Particle clusterParent;

    SmallParticle(float rad_, PVector pos_, PVector vel_) {
        super(rad_,pos_,vel_,color(0));
    }

    void calcForce() {
        force = new PVector(0,0);

        // wiggle
        force.x = random(-1,1) * SMALL_WIGGLE_FORCE*0.8;
        force.y = random(-1,1) * SMALL_WIGGLE_FORCE*0.8;

        // form a circle around cluster parent
        if (SMALL_ATTRACTIVE_FORCE != 0) {
            force.add(  PVector.sub(clusterParent.pos,pos)   );
            float dist = force.mag();
            force.normalize();

            if (dist < clusterParent.rad/2.0) {
                force.mult(-1);
            }
        }
    }

    void postTick() {
        c = color(hue(clusterParent.c),SMALL_SATURATION,SMALL_BRIGHTNESS);
    }

    void draw() {
        fill(c);
        noStroke();
        ellipse(pos.x, pos.y, rad, rad);

        stroke(c);
        line(pos.x, pos.y, clusterParent.pos.x, clusterParent.pos.y);
    }
}


//================================================================================
// MAIN

ParticleGroup bigParticles;
ParticleGroup smallParticles;

SoftFullScreen fs;

void setup() {
    frame.setBackground(new java.awt.Color(0,0,0));
    colorMode(HSB,100);
    size(WORLD_X, WORLD_Y);
    frameRate(30);
    smooth();
    background(12);
 
    bigParticles = new ParticleGroup();
    bigParticles.velDamping = VEL_DAMPING;
    bigParticles.maxForce = MAX_FORCE;
    bigParticles.maxVel = 100000;

    smallParticles = new ParticleGroup();
    smallParticles.velDamping = 0;
    smallParticles.maxForce = 10000;
    smallParticles.maxVel = SMALL_MAX_SPEED;

    // set up big particles
    for (int ii=0; ii < N_BIG_PARTICLES; ii++) {
        PVector pos = new PVector(random(0,WORLD_X),random(0,WORLD_Y));
        PVector vel = new PVector(0,0);
        bigParticles.add(  new BigParticle(BIG_PARTICLE_RAD, pos, vel)  );
    }
    // set up small particles
    for (int ii=0; ii < N_SMALL_PARTICLES; ii++) {
        PVector pos = pointInCircle(new PVector(WORLD_X/2.0 * 0.7,WORLD_Y/2.0), WORLD_Y/2.0 * 0.85);
        PVector vel = new PVector(0,0);
        smallParticles.add(  new SmallParticle(SMALL_PARTICLE_RAD, pos, vel)  );
    }
    // set up small particles
    for (int ii=0; ii < N_SMALL_PARTICLES/4; ii++) {
        PVector pos = pointInCircle(new PVector(WORLD_X/2.0 *1.7,WORLD_Y/2.0*0.8), WORLD_Y/2.0 * 0.3);
        PVector vel = new PVector(0,0);
        smallParticles.add(  new SmallParticle(SMALL_PARTICLE_RAD, pos, vel)  );
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
            smallParticles.add(  new SmallParticle(SMALL_PARTICLE_RAD, pos, vel)  );
        }
    }
    if (key == 'b') {
        for (int ii=0; ii < 40; ii++) {
            PVector pos = pointInCircle(new PVector(mouseX,mouseY), 20);
            PVector vel = new PVector(0,0);
            bigParticles.add(  new BigParticle(BIG_PARTICLE_RAD, pos, vel)  );
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
    bigParticles.add(  new BigParticle(BIG_PARTICLE_RAD, pos, vel)  );
}



void draw() {
    FRAME += 1;
    if (TRAILS == 0) {
        background(12);
    }


    for (int ii=0; ii < bigParticles.size(); ii++) {
        BigParticle bp = (BigParticle) bigParticles.get(ii);
        bp.resetClusterMembership();
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
        sp.clusterParent = closestBigParticle;
        closestBigParticle.addClusterMember(sp);
    }
    for (int ii=0; ii < bigParticles.size(); ii++) {
        BigParticle bp = (BigParticle) bigParticles.get(ii);
        bp.finalizeCluster();
    }

    smallParticles.tick();
    bigParticles.tick();

    if (TRAILS == 1) {
        fill(0,1);
        noStroke();
        rect(0,0,WORLD_X,WORLD_X);
    }

    if (TRAILS == 0) {
        smallParticles.draw();
    }
    bigParticles.draw();
}



