#include <EEPROM.h>
#include <Servo.h>
#define DISABLE_LED_FEEDBACK_FOR_RECEIVE
#define DECODE_RC6
#include <IRremote.h>

#define PIN_IRRECV 13
#define PIN_SERVO 9

#define MAX_STEP_SIZE 45
#define SERVO_MAX 180

struct ANIMATIONCONFIG {
  byte step_size;
  unsigned short step_delay;
  unsigned short turnover_wait;
  unsigned short random_wait;
  unsigned short random_wait_time;
};

struct ANIMATIONSTATE {
  bool motion;
  byte direction;
  byte angle;
  byte written_angle;  
  unsigned long last_turnover;
  unsigned long last_adjustment;
};

ANIMATIONCONFIG config;
ANIMATIONSTATE state;

Servo servo;

void init_config() {
 config = {1, 100, 1000}; 
}

void init_state() {
  state = {true, 1, 0, 0, 0, 0};
}

void turnover(bool instant = false) {
  state.direction *= -1;
  if (!instant) {
    state.last_turnover = millis();
  }
}

void save_config() {
  EEPROM.put(0, config);
}

void load_config() {
  EEPROM.get(0, config);
}

void setup()
{
  init_config();
  load_config();
  init_state();
  Serial.begin(115200);
  servo.attach(PIN_SERVO, 544, 2400);
  servo.write(0);
  IrReceiver.begin(PIN_IRRECV);
}

void loop()
{


  // random_turnover
  // random_delay
  // random config.step_size
  // random state.direction


  if (IrReceiver.decode()) {
    if (IrReceiver.decodedIRData.address == 0x46) {
      if (!(IrReceiver.decodedIRData.flags & IRDATA_FLAGS_IS_REPEAT)) {
        switch (IrReceiver.decodedIRData.command) {
          case 0x83: // return
            turnover();
            break;
          case 0x31: // stop
            turnover(true);
            break;
          case 0xC9: // options
            save_config();
            break;
        }
      } else {
        switch (IrReceiver.decodedIRData.command) {
          case 0x21: // previous
            config.step_size -= 1;
            break;
          case 0x20: // next
            config.step_size += 1;
            break;
          case 0x29: // back
            config.step_delay += 10;
            break;
          case 0x28: // forward
            config.step_delay -= 10;
            break;
          case 0x9C: // top menu
            config.turnover_wait -= 100;
            state.last_turnover = millis();
            break;
          case 0x9A: // disc menu
            config.turnover_wait += 100;
            state.last_turnover = millis();
            break;
          case 0xC7: // Power
            init_config();
            init_state();
            break;
          case 0x2C: // play
            state.motion = true;
            break;
          case 0x30: // pause
            state.motion = false;
            break;
          case 0x92: // home
            load_config();
            break;
          case 0x4E: // audio
            state.angle = random(0, SERVO_MAX);
            break;
          case 0x0:
            state.angle = 0;
            break;
          case 0x9:
            state.angle = 90;
            break;
          case 0x8:
            state.angle = SERVO_MAX;
            break;
        }
      }
    }
    IrReceiver.resume();

    if (config.step_size < 1) {
      config.step_size = 1;
    }
    if (config.step_size > MAX_STEP_SIZE) {
      config.step_size = MAX_STEP_SIZE;
    }

    if (config.step_delay < 10) {
      config.step_delay = 10;
    }
    if (config.step_delay > 2000) {
      config.step_delay = 2000;
    }

    if (config.turnover_wait < 100) {
      config.turnover_wait = 100;
    }
    if (config.turnover_wait > 5000) {
      config.turnover_wait = 10000;
    }
  }

  if (state.motion && state.angle == state.written_angle && (millis() - state.last_adjustment > config.step_delay)) {
    state.angle += config.step_size * state.direction;
    if (state.angle > SERVO_MAX) { // turnover
      state.angle = (state.angle > SERVO_MAX - 1 + MAX_STEP_SIZE) ? 0 : SERVO_MAX;
      turnover();
    }
    state.last_adjustment = millis();
  }

  if (millis() - state.last_turnover > config.turnover_wait) {
    servo.write(state.written_angle = state.angle);
  }
}
