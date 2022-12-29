#!/bin/bash
# script to extract frames from a movie and display them with 
# a specified delay between each frame
# this is a simple bash version of the slow movie player

# generate the help text for the command arguments
function Display_Usage {
cat << EOF
Usage: bash slow-movie-player 
-d | --debug               Show debugging messages 
-h | --help                Displays this text
-f | --frame_interval      Frame extractation time in seconds (default: 1 second) 
-m | --movie_filename      Name of the movie to play (required)
-o | --overlay_frame_num   Overlay the frame number on the displayed frames
-t | --time_delay          Delay in seconds between showing frames (default: 300)
EOF
}

# expand seconds into hours minutes and seconds in human readable form
function Render_Hours_Minutes_Seconds {
   local h m s
   ((h=${1}/3600))
   ((m=(${1}%3600)/60))
   ((s=${1}%60))
   printf "%d hours %d minutes %d seconds\n" $h $m $s
}

# expand seconds into hours minutes and seconds in hh:mm:ss format
function Expand_Seconds {
   local h m s
   ((h=${1}/3600))
   ((m=(${1}%3600)/60))
   ((s=${1}%60))
   printf "%02d:%02d:%02d" $h $m $s
} 

# expand seconds into days hours minutes and seconds in human readable form
function Render_Days_Hours_Mins {
    # convert seconds to Days, Hours, Minutes, Seconds
    # thanks to Nikolay Sidorov and https://www.shellscript.sh/tips/hms/
    local parts seconds D H M S D_TAG H_TAG M_TAG S_TAG
    seconds=${1:-0}
    # all days
    D=$((seconds / 60 / 60 / 24))
    # all hours
    H=$((seconds / 60 / 60))
    H=$((H % 24))
    # all minutes
    M=$((seconds / 60))
    M=$((M % 60))
    # all seconds
    S=$((seconds % 60))

    # set up "x day(s), x hour(s), x minute(s) and x second(s)" language
    [ "$D" -eq "1" ] && D_TAG="day" || D_TAG="days"
    [ "$H" -eq "1" ] && H_TAG="hour" || H_TAG="hours"
    [ "$M" -eq "1" ] && M_TAG="minute" || M_TAG="minutes"
    [ "$S" -eq "1" ] && S_TAG="second" || S_TAG="seconds"

    # put parts from above that exist into an array for sentence formatting
    parts=()
    [ "$D" -gt "0" ] && parts+=("$D $D_TAG")
    [ "$H" -gt "0" ] && parts+=("$H $H_TAG")
    [ "$M" -gt "0" ] && parts+=("$M $M_TAG")
    [ "$S" -gt "0" ] && parts+=("$S $S_TAG")

    # construct the sentence
    result=""
    lengthofparts=${#parts[@]}
    for (( currentpart = 0; currentpart < lengthofparts; currentpart++ )); do
        result+="${parts[$currentpart]}"
        # if current part is not the last portion of the sentence, append a comma
        [ $currentpart -ne $((lengthofparts-1)) ] && result+=", "
    done
    echo "$result"
} # end of function Render_Days_Hours_Mins

# set the initial value for the command line argument for the movie filename
# this may be overridden by the argument parsing
# filename is assumed to include the file type
movie_filename=

# default is not to display debugging messages
# this may be overridden by the argument parsing
DEBUG=:

# default is not to overlay frame numbers on the displayed frames
# this may be overridden by the argument parsing
overlay_frame_num=

# set the initial value for the command line argument for the 
# time delay between display frames
# this may be overridden by the argument parsing
frame_display_delay=300

# set the initial value for the command line argument for the 
# frame extraction time. this is the interval used to seek and extract
# frames from the movie.
frame_interval=1

# parse the argument values
while [ "$1" != "" ]; do
    case $1 in
        -m | --movie_filename )
            shift
            movie_filename=$1
        ;;
        -t | --time_delay )
            shift
            frame_display_delay=$1
        ;;
        -f | --frame_interval )
            shift
            frame_interval=$1
        ;;
        -d | --debug )
            # don't do a shift here because debug doesn't take any arguments
            # shift
            DEBUG="echo"
        ;;
        -o | --overlay_frame_num )
            # don't do a shift here because debug doesn't take any arguments
            # shift
            overlay_frame_num=1
        ;;
        -h | --help )    Display_Usage
            exit
        ;;
        * )
            echo "Invalid argument '$1' specified"
            echo "For help try: ${0##*/} -h"
            exit 1
    esac
    shift
done

# a movie file name must always be specified
if [ -z $movie_filename ]; then
    echo "A movie file name is required, provide it the argument: -m movie_file_name or --movie_filename movie_file_name" >&2
    exit 1
fi

# verify the file exists
if [[ ! -f "$movie_filename" ]] ; then
    echo "error: movie file '$movie_filename' does not exist" >&2; exit 1 
fi

# regular expression to validate that the value in the arguments are positive integers
re='^[0-9]+$'

# validate the frame display delay
if ! [[ $frame_display_delay =~ $re ]] ; then
   echo "error: Delay between displaying frames must be a positive integer" >&2; exit 1 
fi 

# validate the frame display delay
if ! [[ $frame_interval =~ $re ]] ; then
   echo "error: Frame interval must be a positive integer" >&2; exit 1 
fi 

[[ $debug ]] && echo "Debug messages will be displayed"
echo "Movie to be played: $movie_filename"

echo "Frame interval is ${frame_interval} seconds"
echo "Time delay between displaying frames will be $(Render_Hours_Minutes_Seconds $frame_display_delay)"
[[ $overlay_frame_num ]] && echo "Frame numbers will be overlayed on the images"

# determine the movie run time
runtime=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 movies/test.mp4)
runtime=$(printf "%.0f" $runtime)
$DEBUG "DEBUG: Runtime: $runtime seconds"

# display the normal movie playing duration
echo "Normal movie runtime: $(Render_Hours_Minutes_Seconds $runtime)"

# calculate and display the slow movie playing duration
((slow_runtime=${runtime}/${frame_interval}))
((slow_runtime=${slow_runtime}*${frame_display_delay}))
echo "Slow movie runtime: $(Render_Days_Hours_Mins $slow_runtime)"

# loop through the movie
for (( current_frame=frame_interval; current_frame<=runtime; current_frame=current_frame+frame_interval ))
do
    # remove the frame file
    [[ $debug ]] && echo "DEBUG: Removing previous frame"
    rm frame.jpg 2> /dev/null

    # extract the frame from the movie
    $DEBUG "DEBUG: Extracting frame $current_frame"
    
    seek_time=$(Expand_Seconds $current_frame)
    echo "Code to extract current frame at $seek_time would be executed here"
    ffmpeg -ss $seek_time -i $movie_filename -frames:v 1 frame.jpg

    # if specified, overlay the frame number on the image
    if [[ $overlay_frame_num ]]; then
        $DEBUG "DEBUG: Creating frame image with frame number overlay"
        rm frame-with-overlay.jpg 2> /dev/null
        convert frame.jpg -fill khaki -pointsize 60 -gravity center -draw "text 0,150 '$seek_time'" frame-with-overlay.jpg
        $DEBUG "DEBUG: Renaming frame with overlay"
        mv frame-with-overlay.jpg frame.jpg
    fi

    # display the frame
    $DEBUG "DEBUG: Displaying frame $current_frame"
    # feh frame.jpg -F 

    # sleep for the specified time
    $DEBUG "DEBUG: Sleeping for $frame_display_delay seconds"
    sleep $frame_display_delay

done
