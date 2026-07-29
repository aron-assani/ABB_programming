#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# ../ELE610/py3/appImageViewer4.py	(disk)
#
#  Extends appImageViewer2 by adding some more functionality using heritage.
#  Some (skeleton) methods for locating disc in image and finding the
#  angle for rotation to estimate disk speed.
#  Disk menu has actions for: locating disc, finding read sector and its angle, ...
#
# Karl Skretting, UiS, November 2020, June 2022

# Example on how to use file:
# (C:\...\Anaconda3) C:\..\py3> activate py38
# (py38) C:\..\py3> python appImageViewer4.py
# (py38) C:\..\py3> python appImageViewer4.py DarkCrop10ms.bmp

_appFileName = "appImageViewer4R"
_author = "Karl Skretting, UiS" 
_version = "2025.03.28"

import sys
import os.path
#from math import hypot, pi, atan2, cos, sin	# sqrt, cos, sin, tan, log, ceil, floor 
import numpy as np
import cv2
from pyueye import ueye
import math

try:
	from PyQt5.QtCore import Qt, QPoint, QT_VERSION_STR  
	from PyQt5.QtGui import QImage, QPixmap, QTransform, QColor
	from PyQt5.QtWidgets import (QApplication, QAction, QFileDialog, QLabel, 
			QGraphicsPixmapItem, QInputDialog)  # QColorDialog, 
	from pyueye_example_utils import ImageData, ImageBuffer 
except ImportError:
	raise ImportError( f"{_appFileName}: Requires PyQt5." )
#end try, import PyQt5 classes 

from appImageViewer2 import myPath, MainWindow as inheritedMainWindow
from myImageTools import np2qimage 

class MainWindow(inheritedMainWindow):  
	"""MainWindow class for this image viewer is inherited from another image viewer."""
	
# Two initialization methods used when an object is created
	def __init__(self, fName="", parent=None):
		# print( f"File {_appFileName}: (debug) first line in __init__()" ) 
		super().__init__(fName, parent)# use inherited __init__ with extension as follows
		#
		# set appFileName as it should be, it is set wrong in super()...
		self.appFileName = _appFileName 
		if (not self.pixmap.isNull()): 
			self.setWindowTitle( f"{self.appFileName} : {fName}" ) 
		else:
			self.setWindowTitle(self.appFileName)
		# 
		# self.view.rubberBandRectGiven.connect(self.methodUsingRubberbandEnd)  
		# # signal is already connected to cropEnd (appImageViewer1), and can be connected to more
		# self.methodUsingRubberbandActive = False	# using this to check if rubber band is to be used here
		#
		self.initMenu4()
		self.setMenuItems4()
		# print( f"File {_appFileName}: (debug) last line in __init__()" )
		return
	#end function __init__
	
	def initMenu4(self):
		"""Initialize Disk menu."""
		# print( f"File {_appFileName}: (debug) first line in initMenu4()" )
		a = self.qaFindDisk = QAction('Find disk', self)
		a.triggered.connect(self.findDisk)
		a.setToolTip("Find disk using cv2.HoughCircles")
		a = self.qaFindRedSector = QAction('Find red sector', self)
		a.triggered.connect(self.findRedSector)
		a.setToolTip("Find angle for red sector center")
		a = self.qaFindSpeed = QAction('Find speed', self)
		a.triggered.connect(self.findSpeed)
		a.setToolTip("Find speed for rotating disk")
		#
		diskMenu = self.mainMenu.addMenu("Disk")
		diskMenu.addAction(self.qaFindDisk)
		diskMenu.addAction(self.qaFindRedSector)
		diskMenu.addAction(self.qaFindSpeed)
		diskMenu.setToolTipsVisible(True)
		return
	#end function initMenu4
	
# Some methods that may be used by several of the menu actions
	def setMenuItems4(self):
		"""Enable/disable menu items as appropriate."""
		pixmapOK = ((not self.pixmap.isNull()) and isinstance(self.curItem, QGraphicsPixmapItem))
		#
		self.qaFindDisk.setEnabled(True)   
		self.qaFindRedSector.setEnabled(True)   
		self.qaFindSpeed.setEnabled(True)
		return
		
# Methods for actions on the Disk-menu
	def findDisk(self):
		"""Find the large disk in the center of the image using ??."""
		# print("This function is not ready yet.")
		# print("Different approaches may be used, here we sketch one alternative that may (or may not) work.")
		#
		# -- your code may be written in between the comment lines below --
		# find a large circle using HoughCircles
		# perhaps locate center better by locating black center more exact
		# print results, or indicate it on image
		#
		if self.pixmap.isNull():
			print("No image loaded.")
			return
		
		# Convert QPixmap to OpenCV image
		#self.npImage = self.pixmapToCV()
		gray = cv2.cvtColor(self.npImage, cv2.COLOR_BGR2GRAY)
		
		# Apply Gaussian Blur to reduce noise
		blurred = cv2.GaussianBlur(gray, (9, 9), 2)
		
		# Detect circles using Hough Transform
		circles = cv2.HoughCircles(blurred, cv2.HOUGH_GRADIENT, dp=1.2, minDist=30,
									param1=50, param2=30, minRadius=434, maxRadius=450)
		
		if circles is not None:
			circles = np.round(circles[0, :]).astype(int)
			for (x, y, r) in circles:
				cv2.circle(self.npImage, (x, y), r, (0, 255, 0), 4)
				self.disk_center = [x, y]
				print(f"Disk found at: Center=({x}, {y}), Radius={r}")
			self.displayImage(self.npImage)
		else:
			print("No disk detected.")
		return circles

	def pixmapToCV(self):
		"""Convert QPixmap to OpenCV image."""
		self.npImage = self.pixmap.toImage()
		width = self.npImage.width()
		height = self.npImage.height()
		ptr = self.npImage.bits()
		ptr.setsize(height * width * 4)
		arr = np.frombuffer(ptr, np.uint8).reshape((height, width, 4))
		return cv2.cvtColor(arr, cv2.COLOR_BGRA2BGR)

	def displayImage(self, image):
		"""Display the processed image using OpenCV."""
		cv2.imshow("Detected Disk", image)
		cv2.waitKey(0)
		cv2.destroyAllWindows()


	def findRedSector(self):
		"""Find red sector for disc in active image using ??."""
		# print("This function is not ready yet.")
		# print("Different approaches may be used, here we sketch one alternative that may (or may not) work.")
		#
		# -- your code may be written in between the comment lines below --
		# Check color for pixels in a given distance from center [0.75, 0.95]*radius and for all angles [0,1,2, 359]
		# and give 'score' based on how red the pixel is, red > threshold and red > blue and red > green ??
		# (score may be adjusted by position, based on illumination of disk)
		# Find the weighted (based on score) mean position (x,y) for all checked pixels
		# Find, and print perhaps also show on image, the angle of this mean
		"""Find red sector for the disk in the active image."""
		if not hasattr(self, 'disk_center'):
			print("No disk found. Please detect the disk first.")

		# Convert to OpenCV image
		#self.npImage = self.pixmapToCV()
		hsv = cv2.cvtColor(self.npImage, cv2.COLOR_BGR2HSV)
		
		# Define red color range in HSV
		lower_red1 = np.array([0, 100, 100])
		upper_red1 = np.array([10, 255, 255])
		lower_red2 = np.array([170, 100, 100])
		upper_red2 = np.array([180, 255, 255])
		
		# Create masks for red color
		mask1 = cv2.inRange(hsv, lower_red1, upper_red1)
		mask2 = cv2.inRange(hsv, lower_red2, upper_red2)
		mask = cv2.bitwise_or(mask1, mask2)
		
		# Find contours in the mask
		contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
		
		if not contours:
			print("No red sector detected.")
			return
		
		# Find the largest contour (assuming it is the red sector)
		max_contour = max(contours, key=cv2.contourArea)
		M = cv2.moments(max_contour)
		if M['m00'] == 0:
			print("Error calculating red sector position.")
			return
		
		cx = int(M['m10'] / M['m00'])
		cy = int(M['m01'] / M['m00'])
		
		# Calculate angle using atan2
		dx = cx - self.disk_center[0]
		dy = self.disk_center[1] - cy
		arctan = np.arctan2(dy, dx)
		print("ARCTAN2", arctan)
		
		self.angle = arctan
		
		print(f"Red sector detected at angle: {self.angle:.2f} degrees")
		
		# Draw and display results
		cv2.drawContours(self.npImage, [max_contour], -1, (255, 0, 0), 2)
		cv2.circle(self.npImage, (cx, cy), 5, (255, 0, 0), -1)
		self.displayImage(self.npImage)
		return
		
	def findSpeed(self):
		"""Find speed for disk using ??."""
		#hCam = ueye.HIDS(0)
		hCam = self.cam.handle()
		"""
		ret = ueye.is_InitCamera(hCam, None)
		if ret != ueye.IS_SUCCESS:
			print("Failed to initialize camera.")
			return
		
		print("Camera initialized.")
		
		# Set camera parameters
		ueye.is_SetDisplayMode(hCam, ueye.IS_SET_DM_DIB)
		ueye.is_CaptureVideo(hCam, ueye.IS_WAIT)
		
		print("Capturing image...")
		"""
		
		ret = ueye.is_SetExternalTrigger(hCam, ueye.IS_SET_TRIGGER_HI_LO)
		range_exposure = ueye.double()
		min_exposure = ueye.double()
		max_exposure = ueye.double()
		exposure = ueye.double()
		old = ueye.double()
		new = ueye.double()
		retVal = ueye.is_SetFrameRate(hCam, 71, new)
		retVal = ueye.is_Exposure(hCam, ueye.IS_EXPOSURE_CMD_GET_EXPOSURE_DEFAULT, range_exposure, 8)
		retVal = ueye.is_Exposure(hCam, ueye.IS_EXPOSURE_CMD_GET_EXPOSURE_RANGE_MIN, min_exposure, 8)
		retVal = ueye.is_Exposure(hCam, ueye.IS_EXPOSURE_CMD_GET_EXPOSURE_RANGE_MAX, max_exposure, 8)
		print("MAX EXPOSURE:", max_exposure)

		ueye.is_SetAutoParameter(hCam, ueye.IS_SET_ENABLE_AUTO_SENSOR_GAIN_SHUTTER, ueye.double(0), ueye.double(0))

		ueye.is_Exposure(hCam, ueye.IS_EXPOSURE_CMD_SET_EXPOSURE, max_exposure, 8)
  
		if ret != ueye.IS_SUCCESS:
			print("Failed to set external trigger.")
			return
		else:
			if ret != ueye.IS_SUCCESS:
				print("Failed to capture image")
				return

			# Allocate memory for image
			imBuf = ImageBuffer()
			# Wait for the trigger (this is a basic example, more advanced setups may be needed)
			self.cam.freeze_video(True)

			retVal = ueye.is_WaitForNextImage(hCam, 1000, imBuf.mem_ptr, imBuf.mem_id)
			if retVal == ueye.IS_SUCCESS:
				print( f"  ueye.IS_SUCCESS: image buffer id = {imBuf.mem_id}" )
				self.copy_image( ImageData(hCam, imBuf) )  # copy image_data 
				if (self.npImage.size > 0): # ok 
					self.image = np2qimage(self.npImage)
					if (not self.image.isNull()):
						self.pixmap = QPixmap.fromImage(self.image)
						if self.curItem: 
							self.scene.removeItem(self.curItem)
						self.curItem = QGraphicsPixmapItem(self.pixmap)
						self.scene.addItem(self.curItem)
						self.scene.setSceneRect(0, 0, self.pixmap.width(), self.pixmap.height())
						self.setWindowTitle( f"{self.appFileName} : Camera image" )
			self.npImage = cv2.addWeighted(self.npImage, 3, np.zeros(self.npImage.shape, self.npImage.dtype), 0, 100)
			self.findDisk()
			self.findRedSector()

		
		if not hasattr(self, 'angle') or not hasattr(self, 'disk_center'):
			print("No angle or disk data available. Please find the disk and red sector first.")
			return
		
		try:
			td = 0.014 #float(input("Enter trigger delay time (ms): "))
			#te = int(max_exposure)**(-3) #float(input("Enter exposure time (ms): "))
			te = 0.014
		except ValueError:
			print("Invalid input. Please enter numeric values.")
			return
		variable = (td + te / 2)
		print("DENOMINATOR:", variable)
		# Calculate angular velocity using the formula
		omega = ((math.pi/2) - self.angle) / (td + te / 2)
		print("OMEGA:", omega)

		# Convert to RPM
		rpm = (omega * 60) / (2*math.pi)
		print(f"Calculated Speed: {rpm: .2f} RPM")

		
#end class MainWindow

if __name__ == '__main__':
	print( f"{_appFileName}: (version {_version}), path for images is: {myPath}" )
	print( f"{_appFileName}: Using Qt {QT_VERSION_STR}" )
	mainApp = QApplication(sys.argv)
	if (len(sys.argv) >= 2):
		fn = sys.argv[1]
		if not os.path.isfile(fn):
			fn = myPath + os.path.sep + fn   # alternative location
		if os.path.isfile(fn):
			mainWin = MainWindow(fName=fn)
		else:
			mainWin = MainWindow()
	else:
		mainWin = MainWindow()
	mainWin.show()
	sys.exit(mainApp.exec_())
	