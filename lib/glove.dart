// Portion of code that interacts with glove,
// including parsing, and processing of glove
// data. Also includes app/glove interactions



// class packing glove data, including parsing constructor
/* Parameters
bool comfort
bool inact_alarm
bool stress_alarm
bool challenge
int timestamp
int heart_rate
int steps
int stress_level
double acceleration
 */
class GloveData
{
  //default constructor
  GloveData(String data){
    // remove end lines and other termination chars
    var temp_str = data.trim();

    // split into comma separated strings and process these
    temp_str.split(",").forEach(( String value) {
     // if(value.isEmpty) continue;
      // get first character, the identifier
      // and assign members
      if( value.isNotEmpty) {
        switch (value.substring(0, 2)) {
          case "tm": // timestamp
            {
              this.timestamp = int.parse(value.substring(2));
            }
            break;

          case "hr": // heartbeat
            {
              this.heart_rate = int.parse(value.substring(2));
            }
            break;

          case "sl": // stress level 1, 2 and 3
            {
              this.stress_level = int.parse(value.substring(2));
            }
            break;

          case "st": //steps
            {
              this.steps = int.parse(value.substring(2));
            }
            break;

          case "ac": //acceleration modulus
            {
              this.acceleration = double.parse(value.substring(2));
            }
            break;

          case "sa": //stress alarm
            {
              this.stress_alarm = ((value.substring(2)) == "1" )? true : false;
            }
            break;

          case "ir": //inactivity alarm
            {
              this.inact_alarm= ((value.substring(2)) == "1" )? true : false;
            }
            break;
          case "cp": // challenge prompt
            {
              this.challenge = ((value.substring(2)) == "1" )? true : false;
            }
            break;
          case "cs": // comfort signal
            {
              this.comfort = ((value.substring(2)) == "1" )? true : false;
            }
            break;

          default:
            {}
            break;
        }
      }

    });

  }

  // parameters
  bool comfort= false;
  bool inact_alarm= false;
  bool stress_alarm= false;
  bool challenge = false;
  int timestamp= -1;
  int heart_rate =-1;
  int steps =-1;
  double acceleration = -1.0;
  int stress_level = -1;

}

// class maintaining total steps running
// average used for inactivity checking
class ActivityRunningAvg
{

  // default constructor
  // use frequency parameter (in seconds) to know
  // how often inactivity is rung
  ActivityRunningAvg(this.frequency, this.glove_ODR);

  //holds amount of inputs
  static int total_data_pts = 0;
  // holds average activity
  double total_steps = 0.0;
  int frequency;
  int glove_ODR;

  // returns true if running avr is low (compared to threshold)
  // in period frequency (depends on steps sampling rate)
  // which is currently 5 seconds
  bool get_inactivity(double threshold){

    // if we can give a warning
    if( total_data_pts * 5 < frequency){
      return(false);
    }else{
      // reset running average
      double running_avg = total_steps / total_data_pts;
      total_data_pts = 0;
      total_steps = 0;
      if(running_avg < threshold) {
        return(true);
      }
    }

    // by default return false
    return(false);
  }

  void add_data_pt( int steps){
    //increase data pts
    total_data_pts +=1;

    // calculate running average
    total_steps += (steps);
  }



}

// enum type (careful with order)
// order gives the value of enum type
// (starts at zero), up to 3 (for now)
// that has all possible message types
// for sending to the glove
enum GloveProtocol
{
    challenge_detected,
    challenge_vib,
    inactivity_alarm,
    stress_alarm
}