MODULE E458GripperTest
    ! Module for testing gripper with Python communication
    ! Adapted for puck handling with QR codes

    ! wobj in the middle of the table
    TASK PERS wobjdata wobjTableN:=[FALSE,TRUE,"",[[150,-500,8],[0.707106781,0,0,-0.707106781]],[[0,0,0],[1,0,0,0]]];
    
    ! Variables for Python communication
    VAR num numWPW := 0;        ! What Python Wants
    VAR num numWRD := 0;        ! What RAPID Does
    VAR num numPuckX := 0;      ! Puck X position (from Python)
    VAR num numPuckY := 0;      ! Puck Y position (from Python)
    VAR num anglePlace := 0;    ! Puck angle position (from Python)
    VAR num numPlaceX := 0;     ! Place X position (from Python)
    VAR num numPlaceY := 0;     ! Place Y position (from Python)
    VAR num heightPlace := 0;   ! Place Z position (from Python)
    VAR string strPuckID := ""; ! Puck ID from QR code
    VAR num sideOffset := -50;
    
    ! Tool definitions
    ! TASK PERS tooldata tGripper:=[TRUE,[[0,0,114.25],[1,0,0,0]],[0.1,[0,0,0.1],[1,0,0,0],0,0,0]];
    TASK PERS tooldata tCamera:=[TRUE,[[0,0,114.25],[1,0,0,0]],[0.1,[0,0,0.1],[1,0,0,0],0,0,0]];
    
    ! Positions and speeds
    CONST robtarget p0:=[[0,0,250],[0,1,0,0],[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]]; ! Home position
    VAR robtarget aux := p0;
    CONST speeddata vFast:=v1000;
    CONST speeddata vSlow:=v5;
    CONST num puckHeight:=-240;
    CONST num safeHeight:=250;
    CONST num cameraHeight:=300;
    
    ! Puck positions (default place positions)
    VAR robtarget pPlace1:=[[0,0,250],[0,1,0,0],[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
    VAR robtarget pPlace2:=[[200,0,0],[0,1,0,0],[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
    VAR robtarget pPlace3:=[[200,200,0],[0,1,0,0],[0,0,0,0],[9E9,9E9,9E9,9E9,9E9,9E9]];
    
    PROC main()
        CloseGripper(FALSE); ! Open gripper
        MoveJ Offs(p0,0,0,safeHeight), vFast, z20, tGripper\WObj:=wobjTableN;
        
        ! Start main loop or test
        MainLoop;
        ! TestMove; ! Uncomment for testing without Python
    ENDPROC
    
    PROC MainLoop()
        TPWrite "MainLoop starts - Waiting for Python commands";
        numWRD := 0;
        WHILE TRUE DO ! Robot does nothing, waits
            
            WaitUntil (numWPW <> 0);
            TPWrite "Python wants to do task WPW = "\Num:=numWPW;
            numWRD := numWPW;
            TPWrite "RAPID DOES task WRD = "\Num:=numWRD;
            numWPW := 0;
        
            TEST numWRD
            CASE -1: 
                TPWrite "Exiting MainLoop";
                RETURN;
                
    !            CASE 0: 
    !                TPWrite "CASE 0";
    !                WaitTime 0.1;
                
            CASE 1:
                TPWrite "Moving to camera position";
                MoveToCameraPosition;
                
            CASE 2: 
                TPWrite "Picking puck at (" + NumToStr(numPuckX, 1) + "," + NumToStr(numPuckY, 1) + ")";
                PickPuck numPuckX, numPuckY;
                
            CASE 3: 
                TPWrite "Placing puck at (" + NumToStr(numPlaceX, 1) + "," + NumToStr(numPlaceY, 1) + ")";
                PlacePuck numPlaceX, numPlaceY;
                
            CASE 4: 
                TPWrite "Moving to home position";
                MoveJ Offs(p0,0,0,safeHeight), vFast, z20, tGripper\WObj:=wobjTableN;
                
            DEFAULT:
                TPWrite "Unknown task number "\Num:=numWRD;
                WaitTime 0.1;
            ENDTEST
        ENDWHILE
    ENDPROC
    
    PROC MoveToCameraPosition()
        ! Move to position for capturing image
        TPWrite "Moving to camera position FUNCTION";
        MoveJ Offs(p0,0,0,cameraHeight), vFast, fine, tCamera\WObj:=wobjTableN;
        WaitTime 0.5; ! Time for camera to stabilize
    ENDPROC
    
    PROC PickPuck(num x, num y)
        ! Approach puck from safe height
        MoveJ Offs(p0,x + sideOffset, y, safeHeight), vFast, z0, tGripper\WObj:=wobjTableN;
        ! Go down on the side
        MoveL Offs(p0,x + sideOffset, y, puckHeight), vFast, z0, tGripper\WObj:=wobjTableN;
        WaitTime 0.5;
        ! Take the puck
        MoveJ Offs(p0, x, y, puckHeight), v10, z0, tGripper\WObj:=wobjTableN;
        WaitTime 1;
        closeGripper(TRUE);
        
        ! Move down to puck
        !MoveL Offs(p0,x,y,-230), vSlow, z10, tGripper\WObj:=wobjTableN;
        
        ! Close gripper
        !CloseGripper(TRUE);
        WaitTime 0.5;
        
        ! Lift puck
        MoveL Offs(p0,x,y,safeHeight), vFast, z0, tGripper\WObj:=wobjTableN;
        numWRD := 0;
    ENDPROC
    
    
    PROC PlacePuck(num x, num y)
        ! Approach place position from safe height
        !aux.rot := [qxPlace, qyPlace, qzPlace, qwPlace];
        MoveJ Offs(aux,x,y,0), vFast, z10, tGripper\WObj:=wobjTableN;
        
        MoveJ RelTool(aux, 0, 0, 0, \Rz:=-anglePlace), vFast, z10, tGripper\WObj:=wobjTableN;
        
        ! Move down to place position
        MoveL Offs(pPlace1,x,y, puckHeight+heightPlace), v50, fine, tGripper\WObj:=wobjTableN;
        
        WaitTime 1;
        ! Open gripper
        CloseGripper(FALSE);
        WaitTime 0.5;
        
        ! Lift up
        MoveL Offs(aux,x,y,safeHeight), vFast, fine, tGripper\WObj:=wobjTableN;
        numWRD := 0;
    ENDPROC

ENDMODULE
