#!/bin/bash
export ROVER=/Volumes/Work/Projects/lightfield
export ROVER_VIDEO=$ROVER/documentation/video/blackbox_clips

# ffmpeg -i $ROVER_VIDEO/darktrees.mov -filter_complex "
# color=s=3840x1080:c=black [base];
# [0:v] setpts=PTS-STARTPTS, crop=1280:1080 [left];
# [0:v] setpts=PTS-STARTPTS, crop=1280:1080 [center];
# [0:v] setpts=PTS-STARTPTS, crop=1280:1080 [right];
# [base][left] overlay=shortest=1:y=0 [tmp1];
# [tmp1][center] overlay=shortest=1:x=1280:y=0 [tmp2];
# [tmp2][right] overlay=shortest=1:x=2560:y=0 [out]
# " -map '[out]' darktrees_vroom.mp4

ffmpeg -i $ROVER_VIDEO/carkeek_1.mov -i $ROVER_VIDEO/carkeek_2.mov -i $ROVER_VIDEO/carkeek_3.mov -c:v libx264 -crf 12 -filter_complex "
color=s=3840x1080:c=black [base];
[0:v] setpts=PTS-STARTPTS, scale=2130:1160,crop=1280:1080 [left];
[1:v] setpts=PTS-STARTPTS, scale=2130:1160,crop=1280:1080 [center];
[2:v] setpts=PTS-STARTPTS, scale=2130:1160,crop=1280:1080 [right];
[base][left] overlay=shortest=1:y=0 [tmp1];
[tmp1][center] overlay=shortest=1:x=1280:y=0 [tmp2];
[tmp2][right] overlay=shortest=1:x=2560:y=0 [out]
" -map '[out]' carkeek.mp4

# ffmpeg -i $ROVER_VIDEO/m3_a.mov -i $ROVER_VIDEO/m3_b.mov -i $ROVER_VIDEO/m3_c.mov -c:v libx264 -crf 12 -filter_complex "
# color=s=3840x1080:c=black [base];
# [0:v] setpts=PTS-STARTPTS, scale=2130:1160,crop=1280:1080 [left];
# [1:v] setpts=PTS-STARTPTS, scale=2130:1160,crop=1280:1080 [center];
# [2:v] setpts=PTS-STARTPTS, scale=2130:1160,crop=1280:1080 [right];
# [base][left] overlay=shortest=1:y=0 [tmp1];
# [tmp1][center] overlay=shortest=1:x=1280:y=0 [tmp2];
# [tmp2][right] overlay=shortest=1:x=2560:y=0 [out]
# " -map '[out]' mike3.mp4

# ffmpeg -i $ROVER_VIDEO/mike2_3a.mov -i $ROVER_VIDEO/mike2_3b.mov -i $ROVER_VIDEO/mike2_3c.mov -c:v libx264 -crf 12 -filter_complex "
# color=s=3840x1080:c=black [base];
# [0:v] setpts=PTS-STARTPTS, scale=2130:1160,crop=1280:1080 [left];
# [1:v] setpts=PTS-STARTPTS, scale=2130:1160,crop=1280:1080 [center];
# [2:v] setpts=PTS-STARTPTS, scale=2130:1160,crop=1280:1080 [right];
# [base][left] overlay=shortest=1:y=0 [tmp1];
# [tmp1][center] overlay=shortest=1:x=1280:y=0 [tmp2];
# [tmp2][right] overlay=shortest=1:x=2560:y=0 [out]
# " -map '[out]' mike2_3.mp4

# ffmpeg -i $ROVER_VIDEO/darktrees.mov -filter_complex "
# color=s=3840x1080:c=black [base];
# [0:v] setpts=PTS-STARTPTS, crop=1280:,scale=1280x1080 [left];
# [0:v] setpts=PTS-STARTPTS, scale=1280x0 [center];
# [0:v] setpts=PTS-STARTPTS, scale=1280x960 [right];
# [base][left] overlay=shortest=1:y=0 [tmp1];
# [tmp1][center] overlay=shortest=1:x=1280:y=0 [tmp2];
# [tmp2][right] overlay=shortest=1:x=2560:y=0 [out]
# " -map '[out]' darktrees_vroom.mp4