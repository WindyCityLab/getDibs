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
#define VERBOSE_MODE                    true  // Enables full debug output is 'true'

#define MD5_HASH_SALT "6A2041DB-5942-44D7-844C-8C17D7926107"

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
//git test
//addy git test 6/19/15

String timeAsString()
{
  return "2015-06-14-10-03";
}
/**************************************************************************/
/*!
    @brief  Sets up the HW an the BLE module (this function is called
            automatically on startup)
*/
/**************************************************************************/
void setup(void)
{
  Serial.begin(115200);

//  for (int i = 0; i < 512; i++)
//    EEPROM.write(i, 0);
//  Serial.println("erased eeprom");
//  while(1) {};

  pinMode(13,OUTPUT);
  
  
//  Serial.println(EEPROM.read(0),HEX);
//  while (true) {};
//  
  /* Initialise the module */
  Serial.print(F("Initialising the Bluefruit LE module: "));
  if ( !ble.begin(VERBOSE_MODE) )
  {
    error(F("Couldn't find Bluefruit, make sure it's in CoMmanD mode & check wiring?"));
  }
  Serial.println( F("OK!") );

 ble.println("at+gapdevname=GLD"); //obsolete, now pulls from parse
 delay(100);
  ble.waitForOK();

  updateManufactureData();
  
  
  ble.println("atz");
  ble.waitForOK();
  
  /* Disable command echo from Bluefruit */
  //ble.echo(false);

  Serial.println("Requesting Bluefruit info:");
  /* Print Bluefruit information */
  ble.info();

 // ble.verbose(false);  // debug info is a little annoying after this point!
  
}

void updateManufactureData()
{
  ble.print("at+gapsetadvdata="); 
  ble.print("02-01-06-11-06-E6-29-52-6E-EC-3A-7C-8F-E4-41-BD-88-3F-A8-E9-15-04-FF-00-02-");
  if (isOnOffFromEEPROM())
  {
    digitalWrite(13,HIGH);
    ble.println("01");
  }
  else
  {
    digitalWrite(13,LOW);
    ble.println("00");
  }
  ble.waitForOK();
  
  ble.println("ATZ");
  ble.waitForOK();
}

byte getCommandFromMD5Hash(char hashReceived[])
{
  char testString[]="X6A2041DB-5942-44D7-844C-8C17D79261072015-06-14-10-03";
 
  unsigned char* hash=MD5::make_hash(testString);
  char *md5str = MD5::make_digest(hash, 10);
  free(hash);
 // Serial.println(md5str);
  if (strcmp(hashReceived,md5str) == 0)
  {
    return 'X';
  }
  else
  {
    return '-';
  }
  free(md5str);
}
void loop(void)
{
//  char testString[]="X6A2041DB-5942-44D7-844C-8C17D79261072015-06-14-10-03";
//  getCommandFromMD5Hash(testString);
//  
//  byte command[] = "02129bb861061d1a052c592e2dc6b383";
//  Serial.println(sizeof(command));
//  // Echo received data
  while (! ble.isConnected()) {
    if (connectionState)
    {
      Serial.println("disconnected");
      connectionState = false;
    }
  };
  if (!connectionState)
  {
    connectionState = true;
    Serial.println("connected");
  }
  
  if (connectionState)
  {
    // Check for incoming characters from Bluefruit
    ble.println("AT+BLEUARTRX");
    ble.readline(100);  // 100ms timeout
    if (strcmp(ble.buffer, "OK") == 0) {
      return;
    } 
    
    char command = getCommandFromMD5Hash(ble.buffer);
    Serial.println(command);
    
    if (command == 'X')
    {
      rememberOnOff(true);
    }
    else
    {
      rememberOnOff(false);
    }
    Serial.println(ble.buffer);
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

