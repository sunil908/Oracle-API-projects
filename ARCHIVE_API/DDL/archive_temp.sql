create or replace PROCEDURE dijcreate
IS
BEGIN
        BEGIN
            EXECUTE IMMEDIATE 'TRUNCATE TABLE dijnodes' ;
            EXECUTE IMMEDIATE 'DROP TABLE dijnodes' ;
        EXCEPTION
             WHEN OTHERS THEN 
                dbms_output.put_line('unable to drop the temp table');        
            END;


        BEGIN
          EXECUTE IMMEDIATE 'TRUNCATE TABLE relmap' ;
          EXECUTE IMMEDIATE 'DROP TABLE relmap' ;
        EXCEPTION
             WHEN OTHERS THEN 
                dbms_output.put_line('unable to drop the temp table');        
        END;
 
            
        BEGIN
            EXECUTE IMMEDIATE 'TRUNCATE TABLE dijpaths' ;
            EXECUTE IMMEDIATE 'DROP TABLE dijpaths' ;
         EXCEPTION
             WHEN OTHERS THEN 
                dbms_output.put_line('unable to drop the temp table');        
         END;

     
        
            EXECUTE IMMEDIATE 'CREATE GLOBAL TEMPORARY TABLE  relmap ( 
				ROW_ID NUMBER GENERATED ALWAYS AS IDENTITY,
				FromRouteNodeID INT, 
				FromNodeName VARCHAR(200), 
				ToRouteNodeID INT,
				ToNodeName VARCHAR(200), 
				Costs INT ,
				RelationReferenceID INT
			)ON COMMIT preserve ROWS';

		
        
            EXECUTE IMMEDIATE 'CREATE  GLOBAL TEMPORARY TABLE  dijpaths ( 
			  PathID NUMBER GENERATED ALWAYS AS IDENTITY,  
			  FromNodeID int NOT NULL , 
			  ToNodeID int NOT NULL , 
			  Costs int NOT NULL,
			  RelationReferenceID int NULL
			)ON COMMIT preserve ROWS';

        
            EXECUTE IMMEDIATE 'CREATE GLOBAL TEMPORARY  TABLE  dijnodes ( 
			  NodeID NUMBER GENERATED ALWAYS AS IDENTITY, 
			  Nodename varchar (200) NOT NULL, 
			  Costs int NULL, 
			  PathID int NULL, 
			  Calculated int NULL ,
              studyroot int DEFAULT 0,
              tableorder int NULL
			)ON COMMIT preserve ROWS'; 
        COMMIT;
END;
/


