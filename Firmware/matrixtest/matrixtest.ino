#include <Adafruit_GFX.h>
#include <Adafruit_NeoMatrix.h>
#include <Adafruit_NeoPixel.h>
#include <Wire.h>
#include "Adafruit_Trellis.h"

#ifndef PSTR
 #define PSTR // Make Arduino Due happy
#endif

#define PIN 6

Adafruit_NeoMatrix matrix = Adafruit_NeoMatrix(8, 16, PIN,
  NEO_MATRIX_TOP     + NEO_MATRIX_RIGHT +
  NEO_MATRIX_COLUMNS + NEO_MATRIX_PROGRESSIVE,
  NEO_GRB            + NEO_KHZ800);

Adafruit_Trellis matrix0 = Adafruit_Trellis();
Adafruit_TrellisSet trellis =  Adafruit_TrellisSet(&matrix0);

#define NUMTRELLIS 1

#define numKeys (NUMTRELLIS * 16)

uint8_t buttons[] = {1,4,5,6,9};

// Connect Trellis Vin to 5V and Ground to ground.
// Connect the INT wire to pin #A2 (can change later!)
#define INTPIN A2

const uint16_t colors[] = {
  matrix.Color(255, 0, 0), matrix.Color(0, 255, 0), matrix.Color(0, 0, 255) };

void setup() {
  
  Serial.begin(115200);
  
  matrix.begin();
  matrix.setBrightness(50);
  
  trellis.begin(0x70);  // only one
  for (uint8_t i=0; i<numKeys; i++) {
    trellis.setLED(i);
    trellis.writeDisplay();    
    delay(50);
  }
  // then turn them off
  for (uint8_t i=0; i<numKeys; i++) {
    trellis.clrLED(i);
    trellis.writeDisplay();    
    delay(20);
  }
  
  for (int i=0; i<sizeof(buttons); i++)
  {
    trellis.setLED(buttons[i]);
  }
    trellis.writeDisplay();
}

int pixelNumber(int x, int y)
{
  return y*8+x;
}

void loop() {
  delay(30);
  
  if (trellis.readSwitches())
  {
    Serial.println("Trellis button tapped");
    for (uint8_t i=0; i<numKeys; i++)
    {
      if (trellis.justPressed(i))
      {
        trellis.setLED(i);
      }
      if (trellis.justReleased(i))
      {
        trellis.clrLED(i);
      }
    }
    trellis.writeDisplay();
  }
  
  matrix.setPixelColor(pixelNumber(5,10),0x00ff00);
  matrix.setPixelColor(pixelNumber(3,5),0xff0000);
  matrix.setPixelColor(pixelNumber(6,2),0x0000ff);
  matrix.show();

//  for (int x = 0; x < 8; x++)
//  {
//    for (int y=0; y < 16; y++)
//    {
//      matrix.setPixelColor(pixelNumber(x,y),0xff0000);
//      matrix.show();
//      delay(10);
//    }
//  }
}
