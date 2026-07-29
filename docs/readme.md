# Applied Robot Technology & Vision Integrations

This repository contains control engineering and computer vision projects developed for the ABB IRB 140 industrial robot and high-speed IDS cameras. The codebase focuses on closed-loop pick-and-place systems, real-time feature extraction, and optimized kinematic routines.

## Usage

Execution depends on the specific module:

*   **Integrated QR Pick and Place:** 
    - load `PandP_robot.mod` onto a FlexPendant/virtual controller
    - RWS API has to be accessible over the network
    - execute `PandP_vision.py` on the host machine
*   **Visual Measurement of Angular Speed:** 
    - connect a compatible IDS camera
    - execute `angSpeed_vision.py`
*   **Simulated Welding Interrupts:** 
    - load `welding_robot.mod` into RobotStudio or onto a FlexPendant and execute

## 1. Integrated QR Pick and Place
Full-Stack Robotics Integration (Python, OpenCV, RAPID, ABB RWS API)

A closed-loop control system that identifies, locates, and manipulates pucks based on QR code data. 

*   **Vision:** for puck detection (`pyzbar` and OpenCV), corner coordinate extraction and orientation calculation
*   **Transformation:** calculation of transformation matrix mapping between 2D image and 3D workspace
*   **Execution:** Python communication with the ABB robot via the Robot Web Services (RWS) API, -> `X`, `Y`, and `Angle` outputs
*   **RAPID Logic:** safe-height approaches, gripper actuation, and rotational stacking based on the incoming Python parameters

## 2. Visual Measurement of Angular Speed
Computer Vision & Hardware Triggering

A system designed to measure the RPM of a high-speed rotating disk using visual references and camera exposure parameters.

*   **Feature Extraction:** Gaussian blurring and Hough Transform (`cv2.HoughCircles`) for reliable the disk boundary identification.
*   **Color Masking:** HSV color space masking (`cv2.inRange`) and contour tracking to isolate a specific red tracking sector
*   **Kinematic Calculation:** sector angle extraction using geometric moments and `atan2`, final angular velocity calculation based on the camera's external trigger delay and active exposure time

## 3. Simulated Welding Routine
RAPID Optimization

An optimized RAPID routine for a simulated spot-welding task across a grid of pegs.

*   **Cycle Optimization:** joint movements (`MoveJ`) and adjusted zone data (`z150`, `z5`) used for smooth, continuous paths
*   **Hardware Interrupts:** welding tool actuation before reaching the target coordinates (`TriggIO`) for mechanical latency compensation.
*   **Performance:** cycle time reduction of a 7-peg routine from 13.559s to 8.716s with tuned time constants (`tAdelay`, `tOpdelay`).

<div align="center">
    <video width="50%" controls>
      <source src="welding_demo.mp4" type="video/mp4">
      <em>Optimized 7-peg routine</em>
    </video>
</div>

## Dependencies

### Hardware
*   ABB IRB 140
*   IDS Camera (e.g., uEye XS, UI-3140CP)

### Software
*   Python 3.x -- `opencv-python`, `numpy`, `pyzbar`, `pyueye`, `rwsuis`
*   RobotStudio & Robot Web Services (RWS)