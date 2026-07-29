MODULE MainModule
    ! made by KS November 2023
    ! (based on how RWS and JAMR adapted template program from ABB spring 2023)
    ! 
    ! main module for simulation using TATEM tool and a test board with pegs attached
    
    ! position of tool point is relative to tool0, translated so the Tool Center Point (TCP) is
    ! between the two fingers at level of the gap for the front LED, it is rotated -60 degrees around x-axis to make z-axis
    ! point 'forward' from the tool, the 180 degrees around the z-axis so y-axis points into the widest finger, 
    ! and x-axis points to the 'right'.
    ! PERS tooldata TatemTool1:=[TRUE,[[0,-48.3,153.5],[0,0,-0.5,0.866025404]],[0.3,[0,0,1],[1,0,0,0],0,0,0]];
    PERS tooldata TatemTool1:=[TRUE,[[0,-48.3,153.5],[0,0,-0.5,0.866025404]],[0.3,[0,0,1],[1,0,0,0],0,0,0]];
    
    ! the center of the table (not used), relative to robot coordinate system (not world)
    TASK PERS wobjdata wobjTableR:=[FALSE,TRUE,"",[[150,500,8],[1,0,0,0]],[[0,0,0],[1,0,0,0]]];
    
    ! the work object used with test board on table                 x                     y                     z
    TASK PERS wobjdata wobjTestBoardOnTable := [FALSE,TRUE,"",[[0,544,146],[0.965928085,0.258810616,0,0]],[[0,0,0],[1,0,0,0]]];
    ! the one used with test board on conveyer belt         x      y      z
    TASK PERS wobjdata wobjTestBoardOnBelt  := [FALSE,TRUE,"",[[599.763,-318.75,282.622],[0.265084,0.0713605,-0.252646,-0.927797]],[[0,0,0],[1,0,0,0]]];
    ! the work object to use or used last time
    TASK PERS wobjdata wobjTestBoard :=        [FALSE,TRUE,"",[[0,544,146],[0.965928,0.258811,0,0]],[[0,0,0],[1,0,0,0]]];
    
    ! speeddata that are fixed
    CONST speeddata vVeryFast  := [5000,500,5000,1000];
    CONST speeddata vFast      := [1000,500,5000,1000];
    CONST speeddata vSlow      := [ 200,500,5000,1000];
    CONST speeddata vVerySlow  := [ 100,500,5000,1000];
    
    VAR NUM tA         := 0.1;          ! The time it takes to activate the tool
    VAR NUM tAdelay    := 0.08;         ! The amount of time before entering the point that the DO signal will be turned on (should be less than tA) !! CHANGED FROM 0.06 to 0.08
    VAR NUM tAdiff     := 0.02;         ! Amount of time the robot will stand still in its position before executing the spotwelding (MUST be tA-tA_Delay) !! CHANGED FROM 0.04 to 0.02
    ! note that tO is a reserved word, i.e. TO as used in FOR-loops, and gives error when used otherwise    
    ! RAPID identifieres (names) are case-insensitive, see Rapid Overview (on Help) Basic RAPID programming - Program structure - Basic elements 
    VAR NUM tOp        := 0.3;          ! The execution time of the task
    VAR NUM tOpdelay   := 0.05;         ! Extra time to make sure the task is finished before retracting the tool !! CHANGED FROM 0.1 to 0.05
    VAR NUM tR         := 0.1;          ! The time it takes to retract the tool
    VAR NUM tRdelay    := 0.025;        ! Extra time to make sure that the tool has been retracted before exiting the point !! CHANGED FROM 0.05 to 0.025
    VAR num tWait      := 0.495;        ! tWait, == (tAdiff + tOp + tOpdelay + tR + tRdelay) !! CHANGED FROM 0.59 to 0.495

    CONST robtarget AboveTestBoard:= [[90,90,100],[0,1,0,0],[1,0,-1,1],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    ! pegs at the 4 corners of the test board
    CONST num nPegs := 16; ! number of different pegs
    CONST robtarget Peg00:=[[0,0,0],[0,1,0,0],[1,0,-1,1],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget Peg03:=[[0,180,0],[0,1,0,0],[1,0,-1,1],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget Peg30:=[[180,0,0],[0,1,0,0],[0,-1,0,1],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST robtarget Peg33:=[[180,180,0],[0,1,0,0],[0,-1,0,1],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    
    VAR num row;
    VAR num col;
     
    VAR intnum igun_on;   
    VAR triggdata PGunOn;
    CONST jointtarget jCalibPosL:=[[60,30,0,0,-10,90],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST jointtarget jCalibPos0:=[[0,0,0,0,0,0],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    CONST jointtarget jCalibPosR:=[[-15,15,0,0,-10,90],[9E+09,9E+09,9E+09,9E+09,9E+09,9E+09]];
    VAR jointtarget jCalibPos;
    
    VAR bool doSlow := FALSE;
    VAR bool useFlexPendant := TRUE;
    VAR bool useBoardOnTable := TRUE;
    VAR num rows{4} := [0, 60, 120, 180];
    VAR num cols{4} := [0, 60, 120, 180];
    

    PROC main() 
        VAR num peg2Test; VAR num rot_z;
        
        MoveAbsJ jCalibPos0,v1000,z10,tool0;
        IF useBoardOnTable THEN 
            wobjTestBoard := wobjTestBoardOnTable;
            jCalibPos := jCalibPosL;
        ELSE
            wobjTestBoard := wobjTestBoardOnBelt;
            jCalibPos := jCalibPosR;
        ENDIF
        
        IF useFlexPendant THEN
            TPErase;
            reg1 := 0;
        ELSE
            reg1 := 2;
        ENDIF
        
!       While loop to choose the task
        WHILE reg1 < 5 DO
            TEST reg1
            CASE 1:
                TPReadNum peg2Test, "Which peg do you want to test? (1 - 16):";
                IF ((peg2Test >= 1) AND (peg2Test <= 16)) THEN
                    TPReadNum rot_z, "Add a rotation angle (-180 - +180 in 45º steps):";
                    IF (((rot_z MOD 45) = 0) AND (-180 <= rot_z) AND (rot_z <= 180)) THEN
            			IF rot_z = 135 THEN
            				rot_z := -45;
                        ELSEIF peg2Test = 16 AND Abs(rot_z) = 180 THEN
                            rot_z := 0;
			            ENDIF
                        testPeg peg2Test, rot_z;
                    ELSE
                        TPWrite "Invalid number, it must be between -180 and 180 and in 45º steps.";
                    ENDIF
                ELSE
                    TPWrite "Invalid number, it must be between 1 and 16.";
                ENDIF
            CASE 2:
                test4corners;
            CASE 3:
    		    test7pegs;
    	    CASE 4:
    		    options;
            CASE 5:
                TPWrite "Exiting the program";
            DEFAULT:
                WaitTime 0.1;
            ENDTEST
            IF useFlexPendant THEN
                TPReadFK reg1, "Select a task:",
                    "Test a peg",
                    "Test 4 corners",
                    "Test 7 pegs",
                    "Options",
                    "Quit";
            ELSE
                reg1 := 5;
            ENDIF
        ENDWHILE
        
        MoveAbsJ jCalibPos0,v1000,z10,tool0;    
    ENDPROC
       
    FUNC string mapUserChoiceToGrid (num userChoice)
        VAR string value;
        VAR string row_string;
        VAR string col_string;
        col := (userChoice - 1) DIV 4; ! X Value
        row := (userChoice - 1) MOD 4; ! Y Value
        col_string := ValToStr(col);
        row_string := ValToStr(row);
        value :=  col_string + row_string;
        RETURN value;
    ENDFUNC
    
    FUNC num GetPegPosition(num gridPos)
        VAR num position;
        ! Compute the position value
        position := 60 * gridPos;
        RETURN position;
    ENDFUNC
    
    PROC testPeg (num pegIndex, num rot_z)
        VAR num numTime := 0;
        VAR string gridPos; VAR string gridPos2;
        VAR bool a; VAR bool b;
        VAR robtarget newPeg;
        VAR num pos_x; VAR num pos_y;
	
        
        IF useFlexPendant THEN
            TPWrite "test4corners() started";
            WHILE ((1 <= pegIndex) AND (pegIndex <= 16) AND ((rot_z MOD 45) = 0) AND (-180 <= rot_z) AND (rot_z <= 180)) DO
                IF rot_z = 135 THEN
                    rot_z := -45;
                ENDIF
                
                
                gridPos := mapUserChoiceToGrid(pegIndex);
                gridPos2 := StrPart(gridPos, 1, 1);
                a := StrToVal(gridPos2, col);
                gridPos2 := StrPart(gridPos, 2, 1);
                b := StrToVal(gridPos2, row);
                
                MoveAbsJ jCalibPos,vFast,z10,tool0;     
                ClkReset clock1;  
                ClkStart clock1;
        
                initTatemTool;
                pos_x := GetPegPosition(col);
                pos_y := GetPegPosition(row);
                IF pos_y = 0 THEN
                    rot_z := 180;
                ENDIF
                doPeg00 pos_x, pos_y, rot_z;
        
                MoveAbsJ jCalibPos,vFast,z10,tool0;     
                numTime := ClkRead(clock1);
                TPWrite "Time used on testPeg() [s] = " \Num:=numTime;
                TPReadNum pegIndex, "Which peg do you want to test? (1 - 16):";
		        IF ((1 <= pegIndex) AND (pegIndex <= 16)) THEN
                	TPReadNum rot_z, "Add a rotation angle (-180 - +180 in 45º steps):";
		        ENDIF
            ENDWHILE
        ELSE
            TPWrite "Invalid value. Exiting the task.";
            RETURN; 
        ENDIF
    ENDPROC
       
    PROC test4corners()  
        VAR num numTime := 0;
        
        IF useFlexPendant THEN 
            TPWrite "test4corners() started";
        ENDIF
        MoveAbsJ jCalibPos,vFast,z10,tool0;     
        ClkReset clock1;  
        ClkStart clock1;
        
        initTatemTool;
        doPeg00 0, 0, 180;
        doPeg00 180, 0, 0;
        doPeg00 180, 180, 0;
        doPeg00 0, 180, 0;
        
        MoveAbsJ jCalibPos,vFast,z10,tool0;     
        numTime := ClkRead(clock1);
        IF useFlexPendant THEN
            TPWrite "Time used on test4corners() [s] = " \Num:=numTime;
        ENDIF
    ENDPROC

    PROC test7pegs()  
        VAR num numTime := 0;
        
        IF useFlexPendant THEN 
            TPWrite "test7pegs() started";
        ENDIF
        MoveAbsJ jCalibPos,vFast,z10,tool0;     
        ClkReset clock1;  
        ClkStart clock1;
        
        initTatemTool;
        doPeg00 0, 180, 90;
        doPeg00 0, 0, 180;
        doPeg00 180, 0, -90;
        doPeg00 60, 180, -45;
        doPeg00 60, 60, 45;
        doPeg00 120, 120, 0;
        doPeg00 180, 120, -45;
        
        MoveAbsJ jCalibPos,vVeryFast,z10,tool0;     
        numTime := ClkRead(clock1);
        IF useFlexPendant THEN
            TPWrite "Time used on test7pegs() [s] = " \Num:=numTime;
        ENDIF
    ENDPROC

    PROC options()  
      	VAR num useBoardOnTable_userOption := 2;
	    VAR num doSlow_userOption := 2;

        IF useFlexPendant THEN 
            TPWrite "options() started";
        ENDIF
                
    	WHILE ((useBoardOnTable_userOption <> 0) AND (useBoardOnTable_userOption <> 1)) DO
            TPReadNum useBoardOnTable_userOption, "Do you want to use the Board on the table? (1 True, 0 False):";
        ENDWHILE
        IF useBoardOnTable_userOption = 1 THEN
    		useBoardOnTable := TRUE;
        ELSEIF useBoardOnTable_userOption = 0 THEN
    		useBoardOnTable := FALSE;
        ENDIF
            
    	WHILE (doSlow_userOption <> 1 AND doSlow_userOption <> 0) DO
            TPReadNum doSlow_userOption, "Do you want to go fast or slow? (1 Slow, 0 Fast):";
        ENDWHILE
        IF doSlow_userOption = 1 THEN
    		doSlow := TRUE;
        ELSEIF doSlow_userOption = 0 THEN
    		doSlow := FALSE;
        ENDIF

    ENDPROC

    
    PROC doPeg00(num dx, num dy, num rotz)
        ! arguments here should be given relative to work object
        ! but RelTool adjust position reltive to tool coordinate system 
        ! Below sign of dx is kept, sign of dy (and dz) and rotation around z-axis are reversed,
        ! this will, for the cases here, make arguments dx, dy, and rotz as if they were 
        ! related to the work object. 
        ! 
        VAR num t1 := 0.025;   ! at peg wait t1 and the activate tool
        VAR num t2 := 0.450;   ! then wait t2, staying calm on peg 
        VAR num t3 := 0.125;   ! deactivate tool, and wait t3 until moving from peg
        !
        IF doSlow THEN
            MoveJ RelTool(Peg00, dx, -dy, -50, \Rz:= -rotz), vVeryFast, z5,  TatemTool1\WObj:=wobjTestBoard;
            MoveJ RelTool(Peg00, dx, -dy,   0, \Rz:= -rotz), vSlow, fine, TatemTool1\WObj:=wobjTestBoard;
            WaitTime t1;
            SetDO AirValve, 1;  ! activate tool
            WaitTime t2;
            SetDO AirValve, 0;  ! deactivate tool
            WaitTime t3;
            MoveJ RelTool(Peg00, dx, -dy, -85, \Rz:= -rotz), vSlow, z5,  TatemTool1\WObj:=wobjTestBoard;

        ELSE
            ! Here try to do a faster 'weld simulation', using TriggL
            ! Moving to above wanted position (dx, dy) from Peg00 and tool rotated rotz degrees clockwise
            MoveJ RelTool(Peg00, dx, -dy, -85, \Rz:= -rotz), vVeryFast, z150,  TatemTool1\WObj:=wobjTestBoard;
            MoveJ RelTool(Peg00, dx, -dy, -50, \Rz:= -rotz), vFast, z150, TatemTool1\WObj:=wobjTestBoard;
            ! The signal is turned on tAdelay second before (=above) the target point 
            TriggJ RelTool(Peg00, dx, -dy,  0, \Rz:= -rotz),  vFast, PGunOn, fine, TatemTool1\WObj:=wobjTestBoard; 
            WaitTime tWait;   ! should be the minimum time to wait
            ! Move up again
            MoveJ RelTool(Peg00, dx, -dy, -50, \Rz:= -rotz), vFast, z150,  TatemTool1\WObj:=wobjTestBoard;
            MoveJ RelTool(Peg00, dx, -dy, -85, \Rz:= -rotz), vVeryFast, z150,  TatemTool1\WObj:=wobjTestBoard;
        ENDIF
    ENDPROC
    
    ! The last two functions for using trigger to activate and and interrupt to deactivate tool
    PROC initTatemTool()   
        ! just return IF doSlow
        IF NOT doSlow THEN
            ! initialize the TATEM tool, for using trigger and interrupt
            ! Connect the triggdata variable PGunOn to the DO signal AirValve
            ! and set the startup time of the tool as tA_dalay seconds before reaching the point
            ! the last argument, 1, is the value to assign to the DO signal when triggered.
            TriggIO PGunOn, tAdelay\Time \DOp:=AirValve, 1;   
            IDelete igun_on;
            CONNECT igun_on WITH resetSignal;
            ISignalDO AirValve, 1, igun_on;
       ENDIF
    ENDPROC
    
    TRAP resetSignal
        TEST INTNO    
        CASE igun_on:
            ISleep igun_on;
            SetDO \SDelay:=tA+tOp+tOpdelay, AirValve, 0; ! Triggering DO off
            IWatch igun_on;
        ENDTEST
    ENDTRAP
    
ENDMODULE