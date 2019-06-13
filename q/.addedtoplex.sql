DECLARE
/* payload */
rating_key NUMBER := '%rating_key%';
imdbid VARCHAR(10) := '%imdbid%';
showname VARCHAR(255) := '%showname%';
grandparent_key NUMBER := '%grandparent_key%';
episode_name VARCHAR(255) := '%episode_name%';
season NUMBER := '%season%';
episode NUMBER := '%episode%';
request VARCHAR(40) := '%request%';
status VARCHAR(10) := '%status%';
showtype VARCHAR(10) := '%type%';
filepath VARCHAR(999) := '%path%';
/* end payload */

buffer1 VARCHAR(30);
seq NUMBER;
buffer2 NUMBER;

BEGIN
IF showtype = 'series' THEN
-- Series
        SELECT COUNT(service_id) INTO buffer1 FROM pb WHERE service_id = grandparent_key;
        IF buffer1 = 1 THEN -- exists
                SELECT id INTO seq from pb WHERE service_id = grandparent_key;
                SELECT count(service_id) INTO buffer2 FROM pb_episodes WHERE service_id = rating_key;                
                if buffer2 = 1 THEN -- only update episode data. Episode already present. ignores if more.
                        UPDATE pb_episodes SET id = seq,
                        parent_id = grandparent_key,
                        service_id = rating_key,
                        season = season,
                        episode = episode,
                        episode_name = episode_name
                        WHERE rating_key = buffer2;
                ELSE -- insert only episode
                        INSERT into pb_episodes VALUES (seq, grandparent_key, rating_key, season, episode, episode_name);
                    
                END IF;
                ELSE -- OK, NOT found, update all relevant tables. 
                seq := id_seq.nextval;
                INSERT INTO pb VALUES (seq, imdbid, showtype, grandparent_key, grandparent_key);
                INSERT INTO pb_series VALUES (seq, showname, request, status);
                INSERT into pb_episodes VALUES (seq, grandparent_key, rating_key, season, episode, episode_name);
    
        END IF;
ELSE
        -- Movies
        SELECT COUNT(service_id) into buffer1 FROM pb WHERE service_id = rating_key;
        IF NOT buffer1 = '1' THEN -- skip if movie somehow already exists.
                seq := id_seq.nextval;
                INSERT INTO pb VALUES (seq, imdbid, 'movie', rating_key, rating_key);
                INSERT INTO pb_movies VALUES (seq, showname, filepath, request, 'added');
        END IF;
END IF;
END;
.
/
