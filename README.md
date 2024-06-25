# iPhone-VCAM

A virtual camera based on *Cydia Substrate*.

# What it does

Replaces the iOS camera screen.

## Effective software
- Supports most apps

## Support system version

- The development version is iOS13.3, but we don't have any other version so we can't test it on real machine.
- Theoretically support iOS11.0 or above
- iOS15 may have some problems, and there is no jailbreak program for iOS15.

# Getting Started

## Install

## Use
- The following **-** symbols denote the **volume down button**, **+** denotes the **volume up button**, which is toggled within one second to trigger the

### Full mode
More pop-up windows, some software will pause after the pop-up windows.
- Shortcut + -
- See button description for function
- Download Video
    - *A system mute alert box will pop up every time the download is completed.
    1. video file
        1. online video address, need to make sure that the link points to an accessible video
        2. if the file is corrupted or unplayable or unsupported no change will occur
    2. streaming media (not supported yet)

### Convenient mode
Minimize pop-ups to prevent interrupting the current program's running state  
- Shortcut - + triggers **Select Video**.
- If the **Download Video** function is set, this shortcut key is changed to trigger **Download Video**.
- Continue to use **Select Video** when the connection of **Download Video** is set to null
    - A silent mode popup window will appear when the download is complete
    - If the remote file is not available then disable the replacement

# Frequently Asked Questions
- The following **-** symbols mean **volume down**, **+** means **volume up**, toggle-click within one second to trigger it.

## Q: How do I select the video resolution?
A: After using the camera + -, detailed information will appear. When the width is greater than the height, it means the video direction is rotated, in most cases the rear camera needs to be 90 degrees counterclockwise and the front camera 90 degrees clockwise, sometimes it needs to be rotated and flipped horizontally. Sometimes you need to rotate and flip the video horizontally. The specific direction of the video needs to be observed by yourself due to different software processing. **Replacement preview is always in the right direction**, *If the video width and height are not the same as the prompted one, the screen may be shifted from the recognized result, the preview may be stretched or even flashback*.
- In short, the width and height of the replacement video must be the same as the W, H of the + - shortcut key, and the angle of the replacement video should be adjusted according to the previewed image.

## Q: Is the image rotated after taking a picture?
A: The preview is always oriented correctly, some software will process landscape image directly, but rotate the preview when giving it to the user.
- Simply put, depending on the direction of the rotated image, you can rotate the replacement video once in the opposite direction in advance.



# TODO
- Audio Support
- Fixed the problem that some software's video loops don't work.

Translated with DeepL.com (free version)
