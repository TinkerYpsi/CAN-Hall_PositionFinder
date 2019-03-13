import processing.serial.*;

final int SENSOR_COUNT = 4;
final int PX_PER_MM = 5;
  
// This class' objects contain raw and angular data for each hall effect sensor 
// and variables for drawing representations of them on screen.
// Although we can compute angles in all three planes, we're only using the xz plane
class HallSensor {
  // raw sensor data
  int x;
  int y;
  int z;

  // computed angular data
  float xy;
  float xz;
  float yz;

  // vars for drawing
  int centerX;       // Sensor circle x pos
  int centerY;       // Sensor circle y pos
  int diameter;      // Sensor circle diameter
  float pointerLen;  // How long the pointer extending from the sensor circle should be
  int pointerX;
  int pointerY;
  
  float offset;      // The distance between this sensor and the next. Null if this is the last sensor
  
  // References to neighboring sensors. prevSensor is null for first sensor and nextSensor is null for last sensor.
  HallSensor prevSensor;
  HallSensor nextSensor;

  // Sensor's unique ID
  int id;

  // Constructor
  HallSensor(int id, float offset, HallSensor prevSensor, int centerX, int centerY) {
    this.prevSensor = prevSensor;
    this.id = id;
    this.offset = offset;
    this.centerX = centerX;
    this.centerY = centerY;
    this.diameter = 50;

    if (prevSensor != null) {
      prevSensor.nextSensor = this;
    }
  }

  void drawSensor() {

    // Draw the circle
    strokeWeight(2);
    fill(200);
    ellipse(this.centerX, this.centerY, this.diameter, this.diameter);        

    // Get the x/y position of the end of the pointer and draw it
    this.pointerX = (int)(this.centerX + (getPointerLength() * 5) * cos(this.xz));
    this.pointerY = (int)(this.centerY + (getPointerLength() * 5) * sin(this.xz));
    fill(0);
    strokeWeight(4);  
    line(this.centerX, this.centerY, x, y);
    
    // Print the raw data values above the sensor circles    
    text(String.valueOf(this.x), this.centerX, 95);    
    text(String.valueOf(this.y), this.centerX, 130);    
    text(String.valueOf(this.z), this.centerX, 165);
  }

  float getPointerLength() {
    // Use the law of sines to determine the length of the pointer based upon
    // information from one of the neighboring sensors
    if (this.nextSensor != null) {
      this.pointerLen = (float)((Math.sin(Math.PI - nextSensor.xz) * offset) / 
        Math.sin(Math.PI - (Math.PI - nextSensor.xz) - this.xz));
    } else if (this.prevSensor != null) {
      this.pointerLen = (float)((Math.sin(prevSensor.xz) * prevSensor.offset) / 
        Math.sin(Math.PI - prevSensor.xz - (Math.PI - this.xz)));
    }
    return this.pointerLen;
  }
}

// List for holding the sensor objects
ArrayList<HallSensor> Sensors = new ArrayList<HallSensor>();

// Create a serial object
Serial myPort;

void setup () {

  // Set the screen dimensions
  size(800, 600, P3D);
  print("width: ");
  println(width);
  print("height: ");
  println(height);

  // Create the sensor objects
  int pxOffset = 100; // Start drawing the circles at x = 100px
  for (int i = 0; i < SENSOR_COUNT; i++) {
    HallSensor lastSensor = i == 0 ? null : Sensors.get(i - 1);
    float physicalOffset = 35;  // I'm using 35mm as the temporary offset between all the sensors. This will be variable in actuality
    Sensors.add(new HallSensor(i, physicalOffset, lastSensor, (int)pxOffset, height / 3));
    pxOffset += physicalOffset * PX_PER_MM;
  }

  // change port!
  myPort =  new Serial(this, Serial.list()[3], 250000);
  // here we're saying that we need to buffer until 'NEW LINE'
  myPort.bufferUntil('v');
}

void draw () 
{ 
  // Check the serial port for new data
  checkSerial();
  
  // Draw a grey background
  background(100);
  
  // Draw all the sensors and their pointers
  for (int i = 0; i < SENSOR_COUNT; i++) {
    Sensors.get(i).drawSensor();
  }
  
  // Draw the weighted average location of the center of the magnetic field
  drawMagCenter();
}

void drawMagCenter(){
  final int SENSOR_THRESHOLD = 20;
  float aveX = 0;
  float aveY = 0;
  float[] weights = new float[SENSOR_COUNT];
  float totalWeight = 0;
  
  // Get the total for all x/y sensor values
  for (int i = 0; i < SENSOR_COUNT; i++) {
    HallSensor thisSensor = Sensors.get(i);
    float thisWeight = abs(thisSensor.x) + abs(thisSensor.z);
    // Ignore it if it's below the minimum threshold
    if (thisWeight < SENSOR_THRESHOLD) {
      thisWeight = 0;
    }
    totalWeight += thisWeight;
  }
  
  // Determine the weights of the individual sensor readings
  for (int i = 0; i < SENSOR_COUNT; i++) {
    HallSensor thisSensor = Sensors.get(i);
    float thisWeight = abs(thisSensor.x) + abs(thisSensor.z);
    // Ignore it if it's below the minimum threshold
    if (thisWeight < SENSOR_THRESHOLD) {
      thisWeight = 0;
    }
    weights[i] = (thisWeight) / totalWeight;
  }
  
  // Apply those weights in finding the averaged location of the magnetic field center
  for (int i = 0; i < SENSOR_COUNT; i++) {
    HallSensor thisSensor = Sensors.get(i);
    aveX += thisSensor.pointerX * weights[i];
    aveY += thisSensor.pointerY * weights[i];
  }
  
  // Draw the dot
  fill(255);
  ellipse(aveX, aveY, 25, 25);
}

void checkSerial() {
  if ( myPort.available() > 0)
  {  // If data is available,
    delay(20);
    String input = myPort.readStringUntil('\n');         // read it and store it in val
    input = trim(input);
    println(input);
    if (input != null) {      
      int index = input.indexOf(",");
      if (index != -1) {
        // Element 0
        int this_id = Integer.parseInt(input.substring(0, index));
        HallSensor thisSensor = Sensors.get(this_id - 7);

        // Element 1
        input = input.substring(index + 1);
        index = input.indexOf(",");
        float degrees = Float.parseFloat(input.substring(0, index));
        thisSensor.xz = degrees / 180 * PI;

        // Element 2
        input = input.substring(index + 1);
        index = input.indexOf(",");        
        thisSensor.x = Integer.parseInt(input.substring(0, index));
        // Element 3
        input = input.substring(index + 1);
        index = input.indexOf(",");     
        print(input);
        thisSensor.y = Integer.parseInt(input.substring(0, index));        
        // Element 4
        input = input.substring(index + 1);
        index = input.indexOf(",");     
        print(input);
        thisSensor.z = Integer.parseInt(input);

        print(this_id);
        print(": ");
        println(degrees);
      }
    }
  }
}
