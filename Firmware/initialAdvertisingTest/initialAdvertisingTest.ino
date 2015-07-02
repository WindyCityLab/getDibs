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

#define ARRAY_LENGTH 41

#define BOOL_ROM_ADDRESS 0
#define DEV_ID_ROM_ADDRESS1 1
#define DEV_ID_ROM_ADDRESS2 2
#define DEV_ID_ROM_ADDRESS3 3
#define DEV_ID_ROM_ADDRESS4 4
//int DEV_ID_1;
//int DEV_ID_2;
//int DEV_ID_3;
//int DEV_ID_4;
String DEV_ID_1S;
String DEV_ID_2S;
String DEV_ID_3S;
String DEV_ID_4S;



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
#define NEWPACKET "02-01-06-11-06-E6-29-52-6E-EC-3A-7C-8F-E4-41-BD-88-3F-A8-E9-15-04-FF-"
#define onByte "01"
#define offByte "00"

/* Create the bluefruit object, either software serial... */

SoftwareSerial bluefruitSS = SoftwareSerial(BLUEFRUIT_SWUART_TXD_PIN, BLUEFRUIT_SWUART_RXD_PIN);

Adafruit_BluefruitLE_UART ble(bluefruitSS, BLUEFRUIT_UART_MODE_PIN,
                      BLUEFRUIT_UART_CTS_PIN, BLUEFRUIT_UART_RTS_PIN);

bool connectionState = true;
#define COMMAND_BUFFER_SIZE 32
bool authstate = false;
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
  Wire.begin();
//  rtc.begin();
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

 delay(50);
 ble.println("AT");
 ble.waitForOK();

    DEV_ID_1S = String(EEPROM.read(DEV_ID_ROM_ADDRESS1));
    DEV_ID_2S = String(EEPROM.read(DEV_ID_ROM_ADDRESS2));
    DEV_ID_3S = String(EEPROM.read(DEV_ID_ROM_ADDRESS3));
    DEV_ID_4S = String(EEPROM.read(DEV_ID_ROM_ADDRESS4));
//    Serial.print("Current Device ID: ");
//    Serial.print(DEV_ID_1);
//    Serial.print(DEV_ID_2);
//    Serial.print(DEV_ID_3);
//    Serial.println(DEV_ID_4);
   // ble.println("AT+GAPDEVNAME=Catalyze Equipment");
    ble.println("AT+GAPDEVNAME");
    ble.waitForOK();
    updateManufactureData();

    ble.verbose(false);  // debug info is a little annoying after this point!

}

void updateManufactureData()
{

  String AdvPacket = (NEWPACKET + DEV_ID_1S + DEV_ID_2S + "-" + DEV_ID_3S + DEV_ID_4S + "-");
  if (isOnOffFromEEPROM())
  {
    digitalWrite(13,HIGH);
    AdvPacket = (AdvPacket + onByte);
    Serial.println("Machine is on");
  }
  else
  {
    digitalWrite(13,LOW);
    AdvPacket = (AdvPacket + offByte);
    Serial.println("Machine is off");
  }
  ble.println("AT+GAPSETADVDATA=" + AdvPacket);
  Serial.println(AdvPacket);

  ble.waitForOK();
  ble.println("ATZ");
  ble.waitForOK();
}

void loop()
{
//bool authstate = true;

  while (!ble.isConnected()) {
    if (connectionState)
    {
      Serial.println("STATUS: No device connected");
      connectionState = false;
      authstate = false;
    }
  };
//  Serial.println("got here");
//  while(1);

  if (!connectionState)
  {
    connectionState = true;
    Serial.println("STATUS: device connected");
    authstate = false;
  }


  if (connectionState)
  {
    if (!authstate)
    {
      Authenticate();

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
          String command = GetCommand();
          String simplecommand = (command.substring(0,1));
          if (simplecommand == "1")
          {
            ExecuteToggle(true);
            Serial.println("Turning ON!");
          }
          else if (simplecommand == "0")
          {
            ExecuteToggle(false);
            Serial.println("Turning OFF!");
          }
          else if (simplecommand == "2")
          {
            String  newIDString = command.substring(1,5);
            ExecuteIDChange(newIDString);

          }
        }

//    ble.waitForOK();
    updateManufactureData();
  }
 }


void rememberOnOff(bool isOn)
{
  EEPROM.write(BOOL_ROM_ADDRESS,isOn);
}
bool isOnOffFromEEPROM()
{
  return EEPROM.read(BOOL_ROM_ADDRESS);
}
String MD5input()
{
  DateTime MD5Time = rtc.now();
  char testString[] = "6A2041DB-5942-44D7-844C-8C17D7926107";
  int ddhour = MD5Time.hour();
  String ddminstring = String(MD5Time.minute());
  String ddhourstring = String(MD5Time.hour());
  int ddmin = MD5Time.minute();
  if (ddhour < 10)
  {
    ddhourstring = ("0" + String(ddhour));
  }
  if (ddmin < 10)
  {
    ddminstring = ("0" + String(ddmin));
  }
  Serial.println("Current time: " + ddhourstring + ":" + ddminstring);
  String resultString = String(testString + ddhourstring + ddminstring);
  //Serial.println(resultString);
  return resultString;

}

void Authenticate()
{
  Serial.println();
  // Check for incoming characters from Bluefruit
  ble.println("AT+BLEUARTRX");
  ble.readline(100);  // 100ms timeout
  //Serial.println();
  //Serial.print("BUFFER CONTENTS:");
  //Serial.print(ble.buffer);
  //Serial.println();
  while (strcmp(ble.buffer, "OK") == 0) {
    ble.println("AT+BLEUARTRX");
    ble.readline(100);
  // return;
  }
  Serial.print("Remote Hash:");
  Serial.println(ble.buffer);

  authstate = getAuthFromMD5Hash(ble.buffer);

}

String GetCommand()
{
  ble.println("AT+BLEUARTRX");
  ble.readline(100);  // 100ms timeout
  while (strcmp(ble.buffer, "OK") == 0) {
    //ble.println("AT+GAPDISCONNECT");
    ble.println("AT+BLEUARTRX");
    ble.readline(100);

    }
  String commandString = ble.buffer;
  Serial.print("Numeral Command: ");
  Serial.println(commandString);
  return commandString;
}

void ExecuteToggle(bool ON)
{
  if (ON)
  {
    rememberOnOff(true);
  }
  else
  {
    rememberOnOff(false);
  }

}

bool getAuthFromMD5Hash(char hashReceived[])
{
  char resultArray[ARRAY_LENGTH];
  MD5input().toCharArray(resultArray,ARRAY_LENGTH);
  unsigned char* hash = MD5::make_hash(resultArray);
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

void ExecuteIDChange(String newIDString)
{
    Serial.print("Current Device ID: ");
    Serial.println(DEV_ID_1S + DEV_ID_2S + DEV_ID_3S + DEV_ID_4S);

    Serial.print("Received Device ID: ");
    Serial.println(newIDString);
    DEV_ID_1S = newIDString.substring(0,1);
    DEV_ID_2S = newIDString.substring(1,2);
    DEV_ID_3S = newIDString.substring(2,3);
    DEV_ID_4S = newIDString.substring(3,4);
    EEPROM.write(DEV_ID_ROM_ADDRESS1,DEV_ID_1S.toInt());
    EEPROM.write(DEV_ID_ROM_ADDRESS2,DEV_ID_2S.toInt());
    EEPROM.write(DEV_ID_ROM_ADDRESS3,DEV_ID_3S.toInt());
    EEPROM.write(DEV_ID_ROM_ADDRESS4,DEV_ID_4S.toInt());



}
