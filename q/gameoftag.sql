DECLARE
    player   VARCHAR2(40);
    input    VARCHAR(20);
    p_c      VARCHAR(30);
    isplayer     VARCHAR(40);
    feb      NUMBER;
    now      NUMBER;
    year    NUMBER;
    last_tag VARCHAR(30);
    winner_row NUMBER;
    winner VARCHAR(40);
    action_player VARCHAR(40) := '%action_player%';
BEGIN
-- these will always change depending on input from sh.
--    action_player := '%action_player%';
    input := '%input%';
-- start
    SELECT
        date_to_unix_ts(systimestamp)
    INTO now
    FROM
        dual;
SELECT
    COUNT(player)
INTO p_c
FROM
    got_p
WHERE
    player = action_player;
    IF input = 'register' THEN                                                                                                   -- register
    IF p_c = '1' THEN
        dbms_output.put_line(action_player||' :Du e allerede registrert');
    ELSE
        INSERT INTO got_p VALUES ( action_player );

        dbms_output.put_line(action_player||' :Du e no registrert.');
    END IF;
ELSIF input = 'unregister' THEN
    IF p_c = '0' THEN
        dbms_output.put_line(action_player||' :Du e ikke registrert tidligere.');
    ELSE
        DELETE FROM got_p WHERE player = action_player;
        dbms_output.put_line(action_player||' :Du vart fjerna fra game of tag.');
    END IF;
    END IF;                                                                                                                      -- register end
    IF input IS NULL THEN
        SELECT
           TO_CHAR(SYSDATE, 'MM')
        INTO feb
        FROM
           dual;
 SELECT player into winner FROM got_tag ORDER BY dtg DESC FETCH FIRST 1 ROW ONLY;
        IF NOT feb = 2 THEN
        SELECT TO_CHAR(SYSDATE, 'YYYY') INTO year FROM dual;
               dbms_output.put_line(action_player||' :IT: '||winner);
               ELSE
               IF p_c = '0' THEN
               dbms_output.put_line(action_player||' :Du e ikke med på leken!!');
               ELSE
               if winner = action_player THEN
               dbms_output.put_line(action_player||' :Du kan ikke gje den ifra deg fleire ganga');
               ELSE
               INSERT into got_tag VALUES (action_player, now);
               dbms_output.put_line('#gruppa :tag has been giveth away by '||action_player);
               END IF;
               END IF;
               END IF;
    END IF;
    END;
.
/
