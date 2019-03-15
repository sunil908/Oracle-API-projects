create or replace PROCEDURE dijresolve (
                pFromNodeName  IN varchar,
                pToNodeName  IN varchar
  )  
-- declare record variable that represents a row fetched from the employees table
AS
    l_var1 integer;
    vPathID integer;
    vFromNodeID integer;
    vNodeID integer;
    vToNodeID integer;
    TYPE nodepath_type IS RECORD (
                FromRouteNodeID relmap.FromRouteNodeID%TYPE, 
				FromNodeName relmap.FromNodeName%TYPE, 
				ToRouteNodeID relmap.ToRouteNodeID%TYPE,
				ToNodeName relmap.ToNodeName%TYPE, 
				Costs relmap.Costs%TYPE,
				RelationReferenceID relmap.RelationReferenceID%TYPE,
                PathID integer
                );
    nodepath_rec nodepath_type;
    vIter integer;
    vNodeCount integer;
BEGIN
        --set serveroutput on;
        --pFromNodeName:='customers';
        --pToNodeName := 'orderdetails';
        vIter :=0;
        
          EXECUTE IMMEDIATE 'TRUNCATE TABLE relmap';
                
          UPDATE dijnodes SET PathID = NULL,Costs = NULL,Calculated = 0; 
          SELECT NodeID into vFromNodeID FROM dijnodes WHERE NodeName = pFromNodeName; 
          insert into logtable(logmessage) select 'p0: vFromNodeID: ' || vFromNodeID from dual;
          
          IF vFromNodeID IS NULL THEN 
            insert into logtable(logmessage) select 'From node name ' || pFromNodeName || ' not found.' from dual;
          ELSE 
                vNodeID := vFromNodeID;
                SELECT NodeID INTO vToNodeID FROM dijnodes WHERE NodeName = pToNodeName;
                IF vFromNodeID IS NULL THEN 
                    dbms_output.put_line('From node name ' || pFromNodeName || ' not found.' );
                 ELSE 
                    UPDATE dijnodes SET Costs=0 WHERE NodeID = vFromNodeID;

                    WHILE(vNodeID IS NOT NULL) 
                    LOOP
                        UPDATE dijnodes dij SET 
                        (dij.Costs , dij.PathID) = 
                            (SELECT
                                CASE 
                                WHEN dest.Costs IS NULL THEN coalesce(src.Costs,0) + coalesce(paths.Costs,0)
                                WHEN src.Costs + paths.Costs < dest.Costs THEN coalesce(src.Costs,0) + coalesce(paths.Costs,0)
                                ELSE dest.Costs
                              END  FinalCosts,
                                  paths.PathID 
                              FROM
                                         dijnodes  src 
                                    INNER JOIN dijpaths  paths ON paths.FromNodeID = src.NodeID 
                                    INNER JOIN dijnodes  dest ON dest.NodeID = paths.ToNodeID 
                            WHERE  
                                    src.NodeID = vNodeID
                                AND (dest.Costs IS NULL OR (coalesce(src.Costs,0)+coalesce(paths.Costs,0)) < dest.Costs)
                                AND dest.Calculated = 0
                                )
                                WHERE
                                  EXISTS (SELECT dest.NodeID
                                        FROM
                                         dijnodes  src 
                                    INNER JOIN dijpaths  paths ON paths.FromNodeID = src.NodeID 
                                    INNER JOIN dijnodes  dest ON dest.NodeID = paths.ToNodeID 
                                    WHERE  
                                    src.NodeID = vNodeID
                                AND (dest.Costs IS NULL OR (coalesce(src.Costs,0)+coalesce(paths.Costs,0)) < dest.Costs)
                                AND dest.NodeID=dij.NodeID
                                AND dest.Calculated = 0
                                );
                        
                            UPDATE dijnodes SET Calculated = 1 WHERE NodeID = vNodeID;
                            BEGIN
                            SELECT coalesce(NodeID,0) into vNodeID FROM dijnodes WHERE Calculated = 0 AND Costs IS NOT NULL ORDER BY Costs FETCH FIRST 1 ROWS ONLY;
                            EXCEPTION
                                when NO_DATA_FOUND then
                                    dbms_output.put_line('No node found. Exiting dijresolve.');
                                     EXIT;
                                     
                            END;
                            
                            vIter := vIter + 1;
                        END LOOP;
                    END IF; 
          END IF; 

        
        WHILE vFromNodeID <> vToNodeID
        LOOP
                BEGIN 
                SELECT  
                     --ROW_NUMBER() OVER (PARTITION BY paths.PathID ORDER BY paths.PathID) AS ROW_ID,
                     src.NodeID, src.NodeName,dest.NodeID, dest.NodeName,dest.Costs, paths.RelationReferenceID,paths.PathID  INTO nodepath_rec
                     FROM  
                    dijnodes dest
                    JOIN dijpaths paths ON paths.PathID = dest.PathID 
                    JOIN dijnodes src ON src.NodeID = paths.FromNodeID 
                  WHERE dest.NodeID = vToNodeID; 
                   EXCEPTION
                            when NO_DATA_FOUND then
                                     dbms_output.put_line('No nodes found. Exiting dijresolve execution.');
                                     EXIT;
                                     vToNodeID:=NULL;
                            END;
                  INSERT INTO relmap(FromRouteNodeId, FromNodeName,ToRouteNodeID, ToNodeName,Costs,RelationReferenceID) VALUES 
                  (
                    nodepath_rec.FromRouteNodeId ,
                    nodepath_rec.FromNodeName ,
                    nodepath_rec.ToRouteNodeID ,
                    nodepath_rec.ToNodeName ,
                    nodepath_rec.Costs ,
                    nodepath_rec.RelationReferenceID 
                  );
                  
                  BEGIN
                  SELECT FromNodeID INTO vToNodeID FROM dijpaths WHERE PathID = nodepath_rec.PathID;
                  EXCEPTION
                            when NO_DATA_FOUND then
                                     dbms_output.put_line('No nodes found. Exiting dijresolve execution.');
                                     EXIT;
                            END;
        END LOOP;

END;
/

