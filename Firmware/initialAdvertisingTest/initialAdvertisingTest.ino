#include <Wire.h>

#include <RTClib.h>

#include <EEPROM.h>
#include <string.h>
#include <Arduino.h>
#include <SPI.h>
#include <SoftwareSerial.h>
#include <MD5.h>

#include "Adafruit_BLE.h"
#include "Adafruit_BLE_HWSPI.h"
#include "Adafruit_BluefruitLE_UART.h"

// If you are using Software Serial....
// The following macros declare the pins used for SW serial, you should
// use these pins if you are connecting the UART Friend to an UNO
#define BLUEFRUIT_SWUART_RXD_PIN        9    // Required for software serial!
#define BLUEFRUIT_SWUART_TXD_PIN        10   // Required for software serial!
#define BLUEFRUIT_UART_CTS_PIN          11   // Required for software serial!
#define BLUEFRUIT_UART_RTS_PIN          -1   // Optional, set to -1 if unused

// If you are using Hardware Serial
// The following macros declare the Serial port you are using. Uncomment this
// line if you are connecting the BLE to Leonardo/Micro or Flora
//#define BLUEFRUIT_HWSERIAL_NAME           Serial1

// Other recommended pins!
#define BLUEFRUIT_UART_MODE_PIN         12   // Optional but recommended, set to -1 if unused

// Sketch Settings
#define BUFSIZE                         128   // Read buffer size for incoming data
#define VERBOSE_MODE                    false  // Enables full debug output is 'true'

#define MD5_HASH_SALT "6A2041DB-5942-44D7-844C-8C17D7926107"
#define PACKET "02-01-06-11-06-E6-29-52-6E-EC-3A-7C-8F-E4-41-BD-88-3F-A8-E9-15-04-FF-"
#define DEVID "00-02"
#define onByte "01"
#define offByte "00" 

/* Create the bluefruit object, either software serial... */

SoftwareSerial bluefruitSS = SoftwareSerial(BLUEFRUIT_SWUART_TXD_PIN, BLUEFRUIT_SWUART_RXD_PIN);

Adafruit_BluefruitLE_UART ble(bluefruitSS, BLUEFRUIT_UART_MODE_PIN,
                      BLUEFRUIT_UART_CTS_PIN, BLUEFRUIT_UART_RTS_PIN);

bool connectionState = true;
#define COMMAND_BUFFER_SIZE 32

char commandBuffer[COMMAND_BUFFER_SIZE];

// A small helper
void error(const __FlashStringHelper*err) {
  Serial.println(err);
  while (1);
}


RTC_DS1307 rtc;

void setup()
{
  Serial.begin(115200);
#ifdef AVR
  Wire.begin();
#else
  Wire1.begin(); // Shield I2C pins connect to alt I2C bus on Arduino Due
#endif
  rtc.begin();
  pinMode(13,OUTPUT);
  if (! rtc.isrunning()) {
    Serial.println("RTC is NOT running!");
  }
  

//  
  /* Initialise the module */
  Serial.println(F("Initialising the Bluefruit LE module: "));
  if ( !ble.begin(VERBOSE_MODE) )
  {
    error(F("Couldn't find Bluefruit, make sure it's in CoMmanD mode & check wiring?"));
  }
  Serial.println( F("OK!") );

 ble.println("at+gapdevname=GLD"); //obsolete, now pulls from parse
 delay(50);
 // ble.waitForOK();

  updateManufactureData();
  
  
 

 ble.verbose(false);  // debug info is a little annoying after this point!
 
 MD5input();
 
}

void updateManufactureData()
{
  ble.print("at+gapsetadvdata="); 
  ble.print(PACKET);
  ble.print(DEVID);
  ble.print("-");
  if (isOnOffFromEEPROM())
  {
    digitalWrite(13,HIGH);
    ble.println(onByte);
    Serial.println("Machine is on");
  }
  else
  {
    digitalWrite(13,LOW);
    ble.println(offByte);
    Serial.println("Machine is off");
  }
  ble.waitForOK();
  
  ble.println("ATZ");
  ble.waitForOK();
}

bool getAuthFromMD5Hash(char hashReceived[])
{
  char testString[]="6A2041DB-5942-44D7-844C-8C17D79261072015-06-14-10-03";
 
  unsigned char* hash=MD5::make_hash(testString);
  char *md5str = MD5::make_digest(hash, 10);
  free(hash);
  Serial.print("Local Hash:");
  Serial.println(md5str);
  if (strcmp(hashReceived,md5str) == 0)
  {
    Serial.println("MATCH!");
    return true;
  }
  else
  {
    return false;
  }
  free(md5str);
}
void loop(void)
{
bool authstate;
  
  while (! ble.isConnected()) {
    if (connectionState)
    {
      Serial.println("STATUS: No device connected");
      connectionState = false;
    }
  };
  if (!connectionState)
  {
    connectionState = true;
    Serial.println("STATUS: device connected");
  }
  
  if (connectionState)
  {
    // Check for incoming characters from Bluefruit
    ble.println("AT+BLEUARTRX");
    ble.readline(100);  // 100ms timeout
    if (strcmp(ble.buffer, "OK") == 0) {
      return;
    } 
    Serial.print("Remote Hash:");
    Serial.println(ble.buffer);
    if (! authstate){
    authstate = false;
    authstate = getAuthFromMD5Hash(ble.buffer);
    }
    if (authstate)
    {
      Serial.println("User authorized");
    }
    else {
      Serial.println("User NOT authorized, disconnecting");
      ble.println("AT+GAPDISCONNECT");
    }
    if (authstate) //put actual command code here
    {
      ble.println("AT+BLEUARTRX");
      ble.readline(100);  // 100ms timeout
      if (strcmp(ble.buffer, "OK") == 0) {
        return;
    } 
    Serial.print("Numeral Command: ");
    Serial.println(ble.buffer);
    
    }
    
//    ble.waitForOK();
    updateManufactureData();
  }
}

void rememberOnOff(bool isOn)
{
  EEPROM.write(0,isOn);
}
bool isOnOffFromEEPROM()
{
  return EEPROM.read(0);
}
void MD5input()
{
  DateTime MD5Time = rtc.now();
  
  Serial.println("Current time: " + String(MD5Time.hour()) + ":" + String(MD5Time.minute()));
  
}


