import cv2
import numpy as np
from pyzbar.pyzbar import decode
from rwsuis import RWS
from time import sleep

#help(RWS)

class ABBRobotController:
    def __init__(self, ip="http://152.94.160.198"):
        self.robot = RWS.RWS(ip)
        self.camera_height = 250  # mm
        self.safe_height = 300    # mm
        self.puck_height = 30     # mm
        
    def get_robot_status(self):
        """Get current robot status"""
        return {
            "WRD": self.robot.get_rapid_variable("numWRD"),
            "WPW": self.robot.get_rapid_variable("numWPW")
        }
    
    def wait_for_robot(self, timeout=500):
        """Wait until robot is ready (WRD=0)"""
        import time
        start_time = time.time()
        while time.time() - start_time < timeout:
            status = self.get_robot_status()
            print("WRD IN RAPID", type(status["WRD"]))
            if int(status["WRD"]) == 0:
                return True
            time.sleep(1)
        return False
    
    def send_task_command(self, task_number):
        """Send task command to robot"""
        #sleep(5)
        if self.wait_for_robot():
            print("NUMWPW VALUE:", task_number)
            self.robot.request_rmmp()
            self.robot.set_rapid_variable("numWPW", task_number)
            print("RETURNING TRUE")
            return True
        return False
    
    def set_puck_position(self, x, y):
        """Set puck position for picking"""
        self.robot.set_rapid_variable("numPuckX", y)
        self.robot.set_rapid_variable("numPuckY", -x)
    
    def set_place_position(self, x, y, angle):
        """Set place position for puck"""
        self.robot.set_rapid_variable("numPlaceX", y)
        self.robot.set_rapid_variable("numPlaceY", -x)
        self.robot.set_rapid_variable("anglePlace", angle)
    
    def move_to_camera_position(self):
        """Command robot to move to camera position"""
        print("MOVING TO CAM POSITION")
        return self.send_task_command(1)
    
    def pick_puck(self, x, y):
        """Command robot to pick puck at (x,y)"""
        self.set_puck_position(x, y)
        return self.send_task_command(2)
    
    def place_puck(self, x, y, angle):
        """Command robot to place puck at (x,y)"""
        self.set_place_position(x, y, angle)
        return self.send_task_command(3)
    
    def go_home(self):
        """Command robot to return to home position"""
        return self.send_task_command(4)

class PuckDetector:
    def __init__(self, camera_index=1):
        self.cap = cv2.VideoCapture(camera_index)
        self.cap.set(3, 1280)  # Width
        self.cap.set(4, 960)   # Height
        self.calibration_points = []  # For coordinate transformation
        
    def capture_image(self):
        """Capture image from camera"""
        sleep(5)
        ret, frame = self.cap.read()
        if ret:
            return frame
        return None
    
    def preprocess_image(self, image):
        """Preprocess image for better QR detection"""
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        contrast = cv2.addWeighted(blurred, 1, np.zeros(blurred.shape, blurred.dtype), 0, 40)
        cv2.imshow("CONTRASTED IMG", contrast)
        cv2.waitKey(0)
        return contrast
    
    def detect_pucks(self, image):
        """Detect pucks with QR codes in image"""
        processed = self.preprocess_image(image)
        decoded_objects = decode(processed)
        
        pucks = []
        for obj in decoded_objects:
            points = obj.polygon
            if len(points) == 4:
                # Calculate center and orientation
                center_x = sum([p.x for p in points]) / 4
                center_y = sum([p.y for p in points]) / 4
                
                # Calculate orientation from QR code corners
                dx = points[1].x - points[0].x
                dy = points[1].y - points[0].y
                angle = np.arctan2(dy, dx) * 180 / np.pi
                
                pucks.append({
                    "id": obj.data.decode("utf-8"),
                    "center": (center_x, center_y),
                    "corners": [(p.x, p.y) for p in points],
                    "angle": angle
                })
        
        return pucks
    
    def calibrate_camera(self, image_points, table_points):
        """Calculate transformation matrix from image to table coordinates"""
        # Add homogeneous coordinate (1)
        img_pts = np.array([(x, y, 1) for x, y in image_points])
        tbl_pts = np.array([(x, y, 1) for x, y in table_points])
        
        # Calculate transformation matrix
        T, _, _, _ = np.linalg.lstsq(img_pts, tbl_pts, rcond=None)
        return T  # Transpose to get correct matrix
    
    def image_to_table(self, image_point, T_matrix):
        """Convert image coordinates to table coordinates"""
        m = 32/72.113155
        img_pt = np.array([image_point[0], image_point[1], 1])
        tbl_pt = np.dot(T_matrix, img_pt) 
        #tbl_pt = tbl_pt - [[m*640], [m*480]]
        #return tbl_pt[0]-m*640-55, tbl_pt[1]-m*480+27.5
        #return tbl_pt[0], tbl_pt[1]
        return ((tbl_pt[0]-m*640)-5), ((tbl_pt[1]-m*480)+45)
        
def main():
    # Initialize components
    robot = ABBRobotController()
    detector = PuckDetector()
    
    # Example calibration (replace with actual calibration points)
    # These are known points on table and their corresponding image 
    m = 32/72.113155
    #T_matrix = [[m * np.cos(np.pi / 2), - m * np.sin(np.pi / 2), 0],
    #            [m * np.sin(np.pi / 2), m * np.cos(np.pi / 2), 0],
    #            [0, 0, 1]]
    T_matrix = [[m, 0, 0],
                [0, m, 0],
                [0, 0, 1]]
    # Calculate transformation matrix
    
    print("Transformation matrix:")
    print(T_matrix)
    
    # Main loop
    try:
        while True:
            input("Press Enter to capture image and detect pucks...")
            
            # Move robot to camera position
            if not robot.move_to_camera_position():
                print("Failed to move robot to camera position")
                continue
            
            # Capture image
            image = detector.capture_image()
            if image is None:
                print("Failed to capture image")
                continue
            
            # Detect pucks
            pucks = detector.detect_pucks(image)
            print(f"Detected {len(pucks)} pucks")
            
            for puck in pucks:
                # Convert to table coordinates
                table_x, table_y = detector.image_to_table(puck["center"], T_matrix)
                print(f"Puck {puck['id']} at table position: ({table_y:.1f}, {-table_x:.1f})")
                print("Puck corners", puck['corners'])
                print("Puck angle", puck['angle'])
                angle = puck['angle']
                print("Final angle", angle)
                # Pick and place puck
                if robot.pick_puck(table_x, table_y):
                    # Place in default position (adjust as needed)
                    print("PUCK BEING PICKED")
                    x_and_y = np.array([0, 0, 1])
                    place_x = 0
                    place_y = 0
                    print("PLACE X AND Y", place_x, place_y)
                    
                    print("IF VALUE:", robot.place_puck(place_x, place_y, angle))
                    if robot.place_puck(place_x, place_y, angle):
                        print("Successfully placed puck")
                    else:
                        print("Failed to place puck")
                else:
                    print("Failed to pick puck")
            
            # Return to home position
            robot.go_home()
            
            
    except KeyboardInterrupt:
        print("Program stopped by user")
    
    # Release camera
    detector.cap.release()

if __name__ == "__main__":
    main()