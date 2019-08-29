// Portion of code that interacts with glove,
// including parsing, and processing of glove
// data. Also includes app/glove interactions


// class packing glove data, including parsing constructor
class GloveData
{
  //default constructor
  GloveData(String data){
    // remove end lines and other termination chars
    var temp_str = data.trim();
    // split into comma separated strings and process these
    temp_str.split(",").forEach(( String value) {

      // get first character, the identifier
      // and assign members
      switch(value[0])
      {
        case "t": { this.timestamp = int.parse(value.substring(1)); }
        break;

        case "h": { this.heart_rate = int.parse(value.substring(1));}
        break;

        case "s": { this.steps =int.parse(value.substring(1)); }
        break;

        case "c": { this.challenge = bool.fromEnvironment(value.substring(1)); }
        break;

        default: { }
        break;
      }

    });


  }

  int timestamp= -1;
  int heart_rate =-1;
  int steps =-1;
  bool challenge = false;


}

// class maintaining total steps running
// average used for inactivity checking
class ActivityRunningAvg{

  // default constructor
  // use frequency parameter (in seconds) to know
  // how often inactivity is rung
  ActivityRunningAvg(this.frequency, this.glove_ODR);

  //holds amount of inputs
  static int total_data_pts = 0;
  // holds average activity
  double running_avg = 0;
  int frequency;
  int glove_ODR;

  // returns true if running avr is low (compared to threshold)
  // in period frequency (depends on steps sampling rate)
  // which is currently 5 seconds
  bool get_inactivity(int threshold){

    // if we can give a warning
    if( total_data_pts * 5 < frequency){
      return(false);
    }else{
      // reset running average
      total_data_pts = 0;
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
    running_avg += (steps / total_data_pts);
  }



}